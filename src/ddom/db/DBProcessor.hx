package ddom.db;

import haxe.Timer;
import haxe.Serializer;
import haxe.Unserializer;
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
    var useCache:Bool;
    var selectGroupCache:Map<String, Array<DataNode>> = [];
	public function new(params : {
		host : String,
		?port : Int,
		user : String,
		pass : String,
		?socket : String,
		database : String
	}, typeMaps:Array<TypeMap> = null, useCache:Bool = true) {
        if(typeMaps != null) {
            for(t in typeMaps) {
                typeMap.set(t.type, t);
            }
        }
        this.useCache = useCache;
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
        var t = Timer.stamp();
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
        trace(Timer.stamp() - t);
        return processFilter(results, filters);
    }

    override function selectChildren(parentNodes:Array<DataNode>, childType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var t = Timer.stamp();
        var childNodes:Array<DataNode> = [];
        var childTypeMaps:Array<TypeMap> = [];
        if(childType == "*" || childType == ".") {
            for(ptm in parentNodes.map((pn) -> typeMap[pn.type]).filter((ptm) -> ptm != null && ptm.children != null))
                childTypeMaps = childTypeMaps.concat(ptm.children.map((cm) -> typeMap[cm.type]).filter((ctm) -> ctm != null && childTypeMaps.indexOf(ctm) == -1));
        } else {
            if(typeMap.exists(childType)) childTypeMaps = [typeMap[childType]];
        }
        
        for(childTypeMap in childTypeMaps) {
            var idMap:Map<TypeMap, Array<String>> = [];
            // Find all children that map back to this parent type and consolidate the lookups
            for(cn in childNodes) {
                var childMap = parentTypeMap.children.find((cm) -> cm.type == cn.type && cm.childIdCol != null);
                if(childMap != null) {
                    if(!idMap.exists(childMap)) idMap.set(childMap, []);
                    idMap[childMap].push(c.quote(cn.fields["id"]));
                }
            }
            for(childMap => ids in idMap) {
                var sql = "select * from " + parentTypeMap.table + " where " + parentTypeMap.idCol + " in (select " + childMap.parentIdCol + " from " + childMap.table + " where " + childMap.childIdCol + " in (" + ids.join(",") + "))";
                var result = c.request(sql);
                for(row in result) {
                    var parentNode = toDataNode(parentTypeMap, row);
                    if(parentNodes.indexOf(parentNode) == -1)
                        parentNodes.push(parentNode);
                }
            }
        }

        /*if(childType == "*" || childType == ".") {
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
                                sql = "select * from " + childTypeMap.table + " where " + childTypeMap.idCol + " in (select " + childMap.childIdCol + " from " + childMap.table + " where " + childMap.parentIdCol + " = " + c.quote(pn.fields["id"]) + ")";
                            } else {
                                sql = "select * from " + childTypeMap.table + " where " + childMap.parentIdCol + " = " + c.quote(pn.fields["id"]);
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
        }*/
        trace("children: " + (Timer.stamp() - t));
        return processFilter(childNodes, filters);
    }

    override function selectParents(childNodes:Array<DataNode>, parentType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var t = Timer.stamp();
        var parentNodes:Array<DataNode> = [];
        var parentTypeMaps:Array<TypeMap> = [];
        if(parentType == "*" || parentType == ".") {
            for(cn in childNodes)
                parentTypeMaps = parentTypeMaps.concat(typeMap.filter((tm) -> tm.children != null && tm.children.exists((c) -> c.type == cn.type)).filter((pt) -> parentTypeMaps.indexOf(pt) == -1));
        } else {
            if(typeMap.exists(parentType)) parentTypeMaps = [typeMap[parentType]];
        }
        for(parentTypeMap in parentTypeMaps) {
            var idMap:Map<ChildTypeMap, Array<String>> = [];
            // Find all children that map back to this parent type and consolidate the lookups
            for(cn in childNodes) {
                var childMap = parentTypeMap.children.find((cm) -> cm.type == cn.type && cm.childIdCol != null);
                if(childMap != null) {
                    if(!idMap.exists(childMap)) idMap.set(childMap, []);
                    idMap[childMap].push(c.quote(cn.fields["id"]));
                }
            }
            for(childMap => ids in idMap) {
                var sql = "select * from " + parentTypeMap.table + " where " + parentTypeMap.idCol + " in (select " + childMap.parentIdCol + " from " + childMap.table + " where " + childMap.childIdCol + " in (" + ids.join(",") + "))";
                var result = c.request(sql);
                for(row in result) {
                    var parentNode = toDataNode(parentTypeMap, row);
                    if(parentNodes.indexOf(parentNode) == -1)
                        parentNodes.push(parentNode);
                }
            }
        }
        trace("parents: " + (Timer.stamp() - t));

        return processFilter(parentNodes, filters);
    }

    function toDataNode(t:TypeMap, row:Dynamic):DataNode {
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
        var dn = new DataNode(t.type);
        dn.fields = [ for(f in Reflect.fields(row)) f => Std.string(Reflect.field(row, f)) ];
        if(t.idCol != "id") dn.fields.set("id", dn.fields[t.idCol]); // Make sure 'id' field is available
        return useCache ? checkCache(dn) : dn;
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
