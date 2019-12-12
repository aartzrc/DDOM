package ddom.db;

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
class DDOMDBProcessor extends Processor implements IProcessor implements ISelectable {
    var c:sys.db.Connection;
    var cache:Map<String, Map<String, DataNode>> = [];
    var selectGroupCache:Map<String, Array<DataNode>> = [];

	/**
	 * Pass standard Haxe DB connection settings, see ddomdb.sql for a MySql starter database
	 * @param params 
	 * @param useCache 
	 */
	public function new(params : {
		host : String,
		?port : Int,
		user : String,
		pass : String,
		?socket : String,
		database : String
	}) {
        c = Mysql.connect(params);
        // TODO: auto-gen the DB tables?
    }

    public function dispose() {
        if(c != null) c.close();
    }

    public function select(selector:Selector = null):DDOM {
        return new DDOMInst([this], selector);
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
        var sql = buildSQL(type, filters);
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

    function toDataNode(row:Dynamic):DataNode {
        function checkCache(node:DataNode) {
            var type = node.type;
            var id = node.fields["id"];
            if(id == null) return node; // Cannot cache without id
            if(!cache.exists(type)) cache.set(type, new Map<String, DataNode>());
            if(!cache[type].exists(id)) {
                cache[type][id] = node;
                return node;
            }
            return cache[type][id];
        }
        var dn = new DataNode(row.type);
        dn.fields = [ for(f in Reflect.fields(row)) f => Std.string(Reflect.field(row, f)) ];
        return checkCache(dn);
    }

    function buildSQL(type:String, filters:Array<TokenFilter>) {
        var sql = "SELECT id, type, name, val FROM datanode JOIN fields ON datanode.id = fields.datanode_id";
        var where:Array<String> = [];
        if(type != "." && type != "*") { // Check for get EVERYTHING - this should be blocked?
            where.push("type=" + c.quote(type));
        }
        var limits:{lower:Null<Int>, upper:Null<Int>} = {lower:null,upper:null};
        var orderby:Array<String> = [];
        for(filter in filters) {
            switch(filter) {
                case Id(id):
                    where.push("id=" + c.quote(id));
                case Pos(pos):
                    limits.upper = pos;
                    limits.lower = pos;
                case Gt(pos):
                    limits.lower = pos+1;
                case Lt(pos):
                    limits.upper = pos;
                case ValEq(name, val):
                    where.push("(name = " + c.quote(name) + " and val = " + c.quote(val) + ")");
                case ValNE(name, val):
                    where.push("(name = " + c.quote(name) + " and val != " + c.quote(val) + ")");
                case OrderBy(name):
                    orderby.push(name);
            }
        }
        if(where.length > 0)
            sql += " WHERE " + where.join(" AND ");

        if(orderby.length > 0)
            sql += " ORDER BY " + orderby.join(",");

        if(limits.lower != null && limits.upper != null) {
            sql += " LIMIT " + limits.lower + "," + (limits.lower-limits.upper);
        } else if(limits.lower != null) {
            sql += " LIMIT " + limits.lower + ",18446744073709551615";
        } else if(limits.upper != null) {
            sql += " LIMIT " + limits.upper;
        }

        return sql;
    }
}
