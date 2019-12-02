package ddom.db;

import haxe.Serializer;
import haxe.Unserializer;
using Reflect;
using Lambda;

import ddom.DDOM;
import ddom.Selector;
import ddom.ISelectable;

import sys.db.Mysql;

@:access(ddom.DDOMInst, ddom.DataNode)
class DBProcessor extends Processor implements ISelectable {
    var c:sys.db.Connection;
    var typeMap:Map<String, TypeMap> = [];
    var cache:Map<String, Map<String, DataNode>> = [];
    var selectGroupCache:Map<String, Array<DataNode>> = [];
	public function new(params : {
		host : String,
		?port : Int,
		user : String,
		pass : String,
		?socket : String,
		database : String
	}, typeMaps:Array<TypeMap> = null) {
        if(typeMaps != null) {
            for(t in typeMaps) {
                typeMap.set(t.type, t);
            }
        }
        c = Mysql.connect(params);
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
        var results:Array<DataNode> = [];
        if(type == "." || type == "*") { // Get EVERYTHING - this should be optionally blocked?
            for(t in typeMap)
                results = results.concat(selectOfType(t.type, filters));
        } else {
            var t = typeMap[type];
            if(t == null) t = { type:type, table:type } // Nothing defined? try a default table
            var sql:String = null;
            try {
                sql = "select * from " + t.table;
                var result = c.request(sql);
                for(row in result) results.push(toDataNode(t, row));
            } catch (e:Dynamic) {
#if debug
                trace(sql);
                trace(e);
#end
            }
        }
        return processFilter(results, filters);
    }

    override function selectChildren(parentNodes:Array<DataNode>, childType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var childNodes:Array<DataNode> = [];
        if(childType == "*" || childType == ".") {
            for(pn in parentNodes) {
                var parentType = typeMap[pn.type];
                if(parentType != null && parentType.children != null && parentType.children.length > 0) {
                    for(ct in parentType.children) {
                        for(cn in selectChildren([pn], ct.type, filters))
                            if(childNodes.indexOf(cn) == -1) childNodes.push(cn);
                    }
                }
            }
        } else {
            for(pn in parentNodes) {
                var parentType = typeMap[pn.type];
                if(parentType != null && parentType.children != null && parentType.children.length > 0) {
                    var childMap = parentType.children.find((c) -> c.type == childType );
                    var childTypeMap = childMap != null ? typeMap[childMap.type] : null;
                    if(childMap != null && childTypeMap != null) {
                        try {
                            var sql:String;
                            if(childMap.childIdCol != null) {
                                sql = "select * from " + childTypeMap.table + " where " + childTypeMap.idCol + " in (select " + childMap.childIdCol + " from " + childMap.table + " where " + childMap.parentIdCol + " = " + c.quote(pn.fields.field("id")) + ")";
                            } else {
                                sql = "select * from " + childTypeMap.table + " where " + childMap.parentIdCol + " = " + c.quote(pn.fields.field("id"));
                            }
                            var result = c.request(sql);
                            for(row in result) {
                                var childNode = toDataNode(childTypeMap, row);
                                if(childNodes.indexOf(childNode) == -1)
                                    childNodes.push(childNode);
                            }
                        } catch (e:Dynamic) {
#if debug
                            trace(pn);
                            trace(e);
#end
                        }
                    } else {
#if debug
                        trace("Unable to find parent to child mapping for: " + parentType.type + " => " + childType + " - check spelling and verify top level mapping exists");
#end
                    }
                }
            }
        }
        return processFilter(childNodes, filters);
    }

    override function selectParents(childNodes:Array<DataNode>, parentType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var parentNodes:Array<DataNode> = [];
        if(parentType == "*" || parentType == ".") {
            for(cn in childNodes) {
                var parentTypes = typeMap.filter((tm) -> tm.children != null && tm.children.exists((c) -> c.type == cn.type));
                for(parentType in parentTypes) {
                    for(pn in selectParents([cn], parentType.type, filters))
                        if(parentNodes.indexOf(pn) == -1) parentNodes.push(pn);
                }
            }
        } else {
            for(cn in childNodes) {
                var parentTypeMap = typeMap.find((tm) -> tm.type == parentType && tm.children.exists((c) -> c.type == cn.type && c.childIdCol != null));
                if(parentTypeMap != null) {
                    var childMap = parentTypeMap.children.find((cm) -> cm.type == cn.type);
                    var sql = "select * from " + parentTypeMap.table + " where " + parentTypeMap.idCol + " in (select " + childMap.parentIdCol + " from " + childMap.table + " where " + childMap.childIdCol + "=" + c.quote(cn.fields.field("id")) + ")";
                    var result = c.request(sql);
                    for(row in result) {
                        var parentNode = toDataNode(parentTypeMap, row);
                        if(parentNodes.indexOf(parentNode) == -1)
                            parentNodes.push(parentNode);
                    }
                }
            }
        }

        return processFilter(parentNodes, filters);
    }

    function toDataNode(t:TypeMap, row:Dynamic):DataNode {
        function checkCache(node:DataNode) {
            var type = node.type;
            var id = node.fields.field("id");
            if(id == null) return node; // Cannot cache without id
            if(!cache.exists(type)) cache.set(type, new Map<String, DataNode>());
            if(!cache[type].exists(id)) {
                cache[type][id] = node;
                return node;
            }
            return cache[type][id];
        }
        var dn = new DataNode(t.type);
        var cleanRow = Unserializer.run(Serializer.run(row)); // Isolate the row, lots of 'quirks' with using row directly for some reason...
        for(f in Reflect.fields(cleanRow)) dn.fields.setField(f, Std.string(Reflect.field(cleanRow, f))); // Clean/convert all to strings so comparison operations work
        if(t.idCol != "id") dn.fields.setField("id", dn.fields.field(t.idCol)); // Make sure 'id' field is available
        return checkCache(dn);
    }
}

typedef TypeMap = {
    type:String,
    table:String,
    ?idCol:String,
    ?children:Array<ChildTypeMap>
}

typedef ChildTypeMap = {
    type:String,
    table:String,
    parentIdCol:String,
    ?childIdCol:String
}
