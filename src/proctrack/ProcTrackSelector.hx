package proctrack;

using Reflect;

import ddom.DDOM;
import ddom.Selector;
import ddom.ISelectable;

import sys.db.Mysql;

@:access(ddom.DDOMInst, ddom.DataNode)
class ProcTrackSelector implements ISelectable {
    static var defaultDB = {user:"bgp", pass:"bgp", host:"127.0.0.1", database:"proctrack"};
    var c:sys.db.Connection;
	public function new(params : {
		host : String,
		?port : Int,
		user : String,
		pass : String,
		?socket : String,
		database : String
	} = null) {
        if(params == null) params = defaultDB;
        c = Mysql.connect(params);
    }

    public function dispose() {
        if(c != null) c.close();
    }

    public function select(selector:Selector):DDOM {
        return process(selector);
    }

    function process(selector:Selector):DDOM {
        var results:Array<DataNode> = [];

        var groups:Array<SelectorGroup> = selector;
        for(group in groups)
            for(n in processGroup(group)) // Process each group/batch of tokens
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups
        
        var ddom = new DDOMInst();
        ddom._coreNodes = results;
        return ddom;
    }

    function processGroup(group:SelectorGroup):Array<DataNode> {
        var newGroup = group.copy();
        var token = newGroup.pop();
        if(token == null) return [];

        var sourceNodes:Array<DataNode> = processGroup(newGroup); // Get 'parent' data
        
        var results:Array<DataNode>;

        trace(token);

        switch(token) {
            case OfType(type, filter):
                results = selectOfType(type, filter);
            /*case All(filter):
                results = processFilter(sourceNodes, filter);
            case Id(id, filter):
                results = processFilter(sourceNodes.filter((n) -> n.fields.field("id") == id), filter);
            case OfType(type, filter):
                results = processFilter(sourceNodes.filter((n) -> n.type == type), filter);
            case Children(type, filter):
                var childNodes:Array<DataNode> = [];
                if(type == "*") {
                    for(n in sourceNodes) for(c in n.children) if(childNodes.indexOf(c) == -1) childNodes.push(c);
                } else {
                    for(n in sourceNodes)
                        for(c in n.children.filter((c) -> c.type == type)) 
                            if(childNodes.indexOf(c) == -1) childNodes.push(c);
                }
                results = processFilter(childNodes, filter);
            case Parents(type, filter):
                var parentNodes:Array<DataNode> = [];
                if(type == "*") {
                    for(n in sourceNodes) for(p in n.parents) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                } else {
                    for(n in sourceNodes)
                        for(p in n.parents.filter((p) -> p.type == type)) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                }
                results = processFilter(parentNodes, filter);
            case Descendants(type, filter):
                results = processFilter(getDescendants(sourceNodes, type, [], []), filter);*/
            case _:
                trace(token);
                results = [];
        }

        //trace(results);

        return results;
    }

    function selectOfType(type:String, filter:TokenFilter):Array<DataNode> {
        var results:Array<DataNode> = [];
        switch(type) {
            case "customer":
                var sql = "select * from customer";
                switch(filter) {
                    case All: // pass thru
                    case Id(id):
                        sql += " where id = '" + id + "'";
                    case _: // Ignore for now
                }
                var result = c.request(sql);
                for(row in result) {
                    var dn = new DataNode(type);
                    dn.fields = row;
                    results.push(dn);
                }
            case _:
                trace(type);
        }
        return results;
    }
}
