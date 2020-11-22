package ddom.db;

import ddom.DataNode.Event;
import ddom.DataNode.EventBatch;
import haxe.Timer;
using Lambda;

import ddom.DDOM;
import ddom.Selector;
import ddom.Processor;

import sys.db.Mysql;

/**
 * A 'catch-all' processor, throw any DataNodes at it and it can handle any selector - this uses a special database structure (see ddomdb.sql)
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

    public function processEventBatch(batch:EventBatch, clearCache:Bool = true) {
        //trace(batch);
        c.startTransaction();
        try {
            function handleEvents(events:Array<Event>) {
                for(e in events) {
                    switch(e) {
                        case Batch(newEvents):
                            handleEvents(newEvents);
                        case Created(node):
                            var sql = "INSERT INTO datanode (type) VALUES (" + c.quote(node.type) + ")";
                            log.push(sql);
                            c.request(sql);
                            node.setField("id", Std.string(c.lastInsertId()));
                            log.push(node.getField("id"));
                        case FieldSet(node, name, val):
                            if(name != "id") {
                                if(val == null) {
                                    var sql = "DELETE FROM fields WHERE datanode_id=" + node.getField("id") + " AND name=" + c.quote(name);
                                    log.push(sql);
                                    c.request(sql);
                                } else {
                                    var sql = "INSERT INTO fields (datanode_id,name,val) VALUES (" + node.getField("id") + "," + c.quote(name) + "," + c.quote(val) + ") ON DUPLICATE KEY UPDATE val=" + c.quote(val);
                                    log.push(sql);
                                    c.request(sql);
                                }
                            }
                        case Removed(node):
                            var sql = "DELETE FROM parent_child WHERE parent_id=" + node.getField("id") + " OR child_id=" + node.getField("id");
                            log.push(sql);
                            c.request(sql);
                            var sql = "DELETE FROM fields WHERE datanode_id=" + node.getField("id");
                            log.push(sql);
                            c.request(sql);
                            var sql = "DELETE FROM datanode WHERE id=" + node.getField("id");
                            log.push(sql);
                            c.request(sql);
                        case ChildAdded(node, child):
                            var sql = "INSERT INTO parent_child (parent_id, child_id) VALUES (" + node.getField("id") + "," + child.getField("id") + ") ON DUPLICATE KEY UPDATE child_id=child_id";
                            log.push(sql);
                            c.request(sql);
                        case ParentAdded(node, parent):
                            var sql = "INSERT INTO parent_child (child_id, parent_id) VALUES (" + node.getField("id") + "," + parent.getField("id") + ") ON DUPLICATE KEY UPDATE child_id=child_id";
                            log.push(sql);
                            c.request(sql);
                        case ChildRemoved(node, child):
                            var sql = "DELETE FROM parent_child WHERE parent_id=" + node.getField("id") + " AND child_id=" + child.getField("id");
                            log.push(sql);
                            c.request(sql);
                        case ParentRemoved(node, parent):
                            var sql = "DELETE FROM parent_child WHERE parent_id=" + parent.getField("id") + " AND child_id=" + node.getField("id");
                            log.push(sql);
                            c.request(sql);
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
        if(clearCache) {
            cache.clear();
            selectGroupCache.clear();
        }
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

    function filtersToSql(filters:Array<TokenFilter>) {
        var sqlAnd:Array<String> = [];
        var unhandledFilters:Array<TokenFilter> = [];
        for(filter in filters) {
            switch(filter) {
                case Id(id):
                    sqlAnd.push('id = ${c.quote(id)}');
                case ValEq(name, val):
                    sqlAnd.push('id in (select datanode_id from fields where name = ${c.quote(name)} and val = ${c.quote(val)})');
                case ValNE(name, val):
                    sqlAnd.push('id not in (select datanode_id from fields where name = ${c.quote(name)} and val = ${c.quote(val)})');
                case _:
                    unhandledFilters.push(filter);
            }
        }

        return {sql:sqlAnd, filters:unhandledFilters};
    }

    override function selectOfType(type:String, filters:Array<TokenFilter>):Array<DataNode> {
        //var t = Timer.stamp();
        var results:Array<DataNode> = [];
        var sql = "SELECT id, type, name, val FROM datanode LEFT JOIN fields ON datanode.id = fields.datanode_id";
        var sql2 = filtersToSql(filters);
        if(type != "." && type != "*") // Check for get EVERYTHING - this should be blocked?
            sql2.sql.push('type=${c.quote(type)}');
        if(sql2.sql.length > 0)
            sql = sql + " WHERE " + sql2.sql.join(" AND ");
        log.push(sql);
        try {
            var result = c.request(sql);
            var resultMap:Map<String, DataNode> = [];
            for(row in result) {
                var dn = toDataNode(row);
                resultMap.set(dn.getField("id"), dn);
            }
            results = resultMap.array();
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        //trace(Timer.stamp() - t);
        return processFilter(results, sql2.filters);
    }

    override function selectChildren(parentNodes:Array<DataNode>, childType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var childNodes:Array<DataNode> = [];
        var parentIds = parentNodes.map((n) -> n.getField("id"));
        var sql = "SELECT id, type, name, val FROM datanode LEFT JOIN fields ON datanode.id = fields.datanode_id JOIN parent_child ON parent_child.child_id = datanode.id WHERE parent_child.parent_id IN (" + parentIds.join(",") + ")";
        var sql2 = filtersToSql(filters);
        if(childType != "." && childType != "*")
            sql2.sql.push('type=${c.quote(childType)}');
        if(sql2.sql.length > 0)
            sql = sql + " AND " + sql2.sql.join(" AND ");
        log.push(sql);
        try {
            var result = c.request(sql);
            var resultMap:Map<String, DataNode> = [];
            for(row in result) {
                var dn = toDataNode(row);
                resultMap.set(dn.getField("id"), dn);
            }
            childNodes = resultMap.array();
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        return processFilter(childNodes, sql2.filters);
    }

    override function selectParents(childNodes:Array<DataNode>, parentType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var parentNodes:Array<DataNode> = [];
        var childIds = childNodes.map((n) -> n.getField("id"));
        var sql = "SELECT id, type, name, val FROM datanode LEFT JOIN fields ON datanode.id = fields.datanode_id JOIN parent_child ON parent_child.parent_id = datanode.id WHERE parent_child.child_id IN (" + childIds.join(",") + ")";
        var sql2 = filtersToSql(filters);
        if(parentType != "." && parentType != "*")
            sql2.sql.push('type=${c.quote(parentType)}');
        if(sql2.sql.length > 0)
            sql = sql + " AND " + sql2.sql.join(" AND ");
        log.push(sql);
        try {
            var result = c.request(sql);
            var resultMap:Map<String, DataNode> = [];
            for(row in result) {
                var dn = toDataNode(row);
                resultMap.set(dn.getField("id"), dn);
            }
            parentNodes = resultMap.array();
        } catch (e:Dynamic) {
#if debug
            trace(sql);
            trace(e);
#end
        }
        return processFilter(parentNodes, sql2.filters);
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

    override function setField(name:String, val:String, batch:EventBatch = null, force:Bool = false) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        super.setField(name, val, transactionBatch, force);
    }

    override function addChild(child:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(child, DataNode_T)) throw "child must be a DataNode_T";
        return super.addChild(child, transactionBatch, force);
    }

    override function removeChild(child:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(child, DataNode_T)) throw "child must be a DataNode_T";
        return super.removeChild(child, transactionBatch, force);
    }

    override function addParent(parent:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(parent, DataNode_T)) throw "parent must be a DataNode_T";
        return super.addParent(parent, transactionBatch, force);
    }

    override function removeParent(parent:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(transactionBatch == null) throw "DataNode_T only works within a Transaction";
        if(!Std.is(parent, DataNode_T)) throw "parent must be a DataNode_T";
        return super.removeParent(parent, transactionBatch, force);
    }
}