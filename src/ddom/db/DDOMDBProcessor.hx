package ddom.db;

import ddom.DataNode.Event;
import ddom.DataNode.EventBatch;
import haxe.Timer;
using Lambda;
using ddom.LambdaExt;

import ddom.DDOM;
import ddom.Selector;
import ddom.Processor;

import sys.db.Mysql;

/**
 * A 'catch-all' processor, throw any DataNodes at it and it can handle any selector
 */
@:access(ddom.DDOMInst, ddom.DataNode)
class DDOMDBProcessor extends Processor implements IProcessor {
    var c:sys.db.Connection;
    var cache:Map<String, Map<Int, DataNode>> = [];
    var selectGroupCache:Map<String, Array<DataNode>> = [];

	/**
	 * Pass standard Haxe DB connection settings, see ddomdb.sql for a MySql starter database
	 * @param params 
	 */
	public function new(params : {
		host : String,
		?port : Int,
		user : String,
		pass : String,
		?socket : String,
		database : String
	}) {
        super([]);
        c = Mysql.connect(params);
        // TODO: auto-gen the DB tables?
    }

    public function dispose() {
        if(c != null) c.close();
    }

    public function processEventBatch(batch:EventBatch) {
        trace(batch);
        c.startTransaction();
        try {
            function handleEvents(events:Array<Event>) {
                for(e in events) {
                    switch(e) {
                        case Batch(newEvents):
                            handleEvents(newEvents);
                        case Created(node):
                            c.request("INSERT INTO datanode (type) VALUES (" + c.quote(node.type) + ")");
                            node.setField("id", Std.string(c.lastInsertId()));
                        case FieldSet(node, name, val):
                            if(name != "id") {
                                if(val == null) c.request("DELETE FROM fields WHERE datanode_id=" + node.getField("id") + " AND name=" + c.quote(name));
                                    else c.request("INSERT INTO fields (datanode_id,name,val) VALUES (" + node.getField("id") + "," + c.quote(name) + "," + c.quote(val) + ") ON DUPLICATE KEY UPDATE val=" + c.quote(val));
                            }
                        case Removed(node):
                            c.request("DELETE FROM fields WHERE datanode_id=" + node.getField("id"));
                            c.request("DELETE FROM datanode WHERE id=" + node.getField("id"));
                        case ChildAdded(node, child):
                            c.request("INSERT INTO parent_child (parent_id, child_id) VALUES (" + node.getField("id") + "," + child.getField("id") + ") ON DUPLICATE KEY UPDATE child_id=child_id");
                        case ParentAdded(node, parent):
                            c.request("INSERT INTO parent_child (child_id, parent_id) VALUES (" + node.getField("id") + "," + parent.getField("id") + ") ON DUPLICATE KEY UPDATE child_id=child_id");
                        case ChildRemoved(node, child):
                            c.request("DELETE FROM parent_child WHERE parent_id=" + node.getField("id") + " AND child_id=" + child.getField("id"));
                        case ParentRemoved(node, parent):
                            c.request("DELETE FROM parent_child WHERE parent_id=" + parent.getField("id") + " AND child_id=" + node.getField("id"));
                    }
                }
            }
            handleEvents(batch.events);
        } catch (e:Dynamic) {
            c.rollback();
            throw e;
        }
        c.commit();
        batch.events = [];
        cache.clear();
        selectGroupCache.clear();
    }

    public function select(selector:Selector = null):DDOM {
        return new DDOMInst(this, selector);
    }

    override function processGroup(group:SelectorGroup):Array<DataNode> {
        // Simple cache here to improve response speeds, it would be better to do this via query select/filter
        var sel:Selector = [group];
        if(!selectGroupCache.exists(sel))
            selectGroupCache.set(sel, super.processGroup(group));
        return selectGroupCache[sel];
    }

    override function selectOfType(type:String, filters:Array<TokenFilter>):Array<DataNode> {
        //var t = Timer.stamp();
        var results:Array<DataNode> = [];
        var sql = "SELECT id, type, name, val FROM datanode LEFT JOIN fields ON datanode.id = fields.datanode_id";
        if(type != "." && type != "*") // Check for get EVERYTHING - this should be blocked?
            sql += " WHERE type=" + c.quote(type);
        //trace(sql);
        try {
            var result = c.request(sql);
            for(row in result) results.push(toDataNode(row));
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        //trace(Timer.stamp() - t);
        return processFilter(results, filters);
    }

    override function selectChildren(parentNodes:Array<DataNode>, childType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var childNodes:Array<DataNode> = [];
        var parentIds = parentNodes.map((n) -> n.getField("id"));
        var sql = "SELECT id, type, name, val FROM datanode JOIN fields ON datanode.id = fields.datanode_id JOIN parent_child ON parent_child.child_id = datanode.id WHERE parent_child.parent_id IN (" + parentIds.join(",") + ")";
        if(childType != "." && childType != "*")
            sql += " AND type=" + c.quote(childType);
        //trace(sql);
        try {
            var result = c.request(sql);
            for(row in result) childNodes.push(toDataNode(row));
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        return processFilter(childNodes, filters);
    }

    override function selectParents(childNodes:Array<DataNode>, parentType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var parentNodes:Array<DataNode> = [];
        var childIds = childNodes.map((n) -> n.getField("id"));
        var sql = "SELECT id, type, name, val FROM datanode JOIN fields ON datanode.id = fields.datanode_id JOIN parent_child ON parent_child.parent_id = datanode.id WHERE parent_child.child_id IN (" + childIds.join(",") + ")";
        if(parentType != "." && parentType != "*")
            sql += " AND type=" + c.quote(parentType);
        //trace(sql);
        try {
            var result = c.request(sql);
            for(row in result) parentNodes.push(toDataNode(row));
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        return processFilter(parentNodes, filters);
    }

    function toDataNode(row:Dynamic):DataNode {
        function checkCache(type:String, id:Int) {
            if(!cache.exists(type)) cache.set(type, new Map<Int, DataNode>());
            if(!cache[type].exists(id)) {
                var node = new DataNode(type, ["id" => Std.string(id)]);
                cache[type][id] = node;
                return node;
            }
            return cache[type][id];
        }
        var node = checkCache(row.type, row.id);
        node.setField(row.name, row.val);
        return node;
    }
}

class DataNode_T extends DataNode {
    static var transactionBatch:EventBatch = null;
    static var dbProcessor:DDOMDBProcessor = null;
    public static function startTransaction(processor:DDOMDBProcessor) {
        if(transactionBatch != null) throw "Only one Transaction allowed";
        transactionBatch = DataNode.createBatch();
        dbProcessor = processor;
    }

    public static function commitTransaction() {
        dbProcessor.processEventBatch(transactionBatch);
        clearTransaction();
    }

    public static function clearTransaction() {
        transactionBatch = null;
        dbProcessor = null;
    }

    function new(type:String, fields:Map<String,String>) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        super(type, fields, transactionBatch);
    }

    override function remove(batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        super.remove(transactionBatch);
    }

    override function setField(name:String, val:String, batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        super.setField(name, val, transactionBatch);
    }

    override function addChild(child:DataNode, batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(child, DataNode_T)) throw "child must be a DataNode_T";
        return super.addChild(child, transactionBatch);
    }

    override function removeChild(child:DataNode, batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(child, DataNode_T)) throw "child must be a DataNode_T";
        return super.removeChild(child, transactionBatch);
    }

    override function addParent(parent:DataNode, batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(parent, DataNode_T)) throw "parent must be a DataNode_T";
        return super.addParent(parent, transactionBatch);
    }

    override function removeParent(parent:DataNode, batch:EventBatch = null) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(parent, DataNode_T)) throw "parent must be a DataNode_T";
        return super.removeParent(parent, transactionBatch);
    }
}