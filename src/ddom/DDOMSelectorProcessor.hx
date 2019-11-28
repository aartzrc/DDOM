package ddom;

import ddom.DDOM.DDOMInst;
import ddom.DDOM.DataNode;
import ddom.DDOMSelector;

using Lambda;
using Reflect;
using StringTools;

@:allow(ddom.DDOMInst, ddom.DDOMSelector)
class DDOMSelectorProcessor {
    static function process(store:DDOMStore, selector:DDOMSelector, parent:DDOMInst = null):Array<DataNode> {
        if(parent == null) { // null parent means use all data
            parent = new DDOMInst(store, "");
            parent.nodes = store.dataByType.flatten();
        }

        var results:Array<DataNode> = [];
        
        var groups:Array<SelectorGroup> = selector;
        for(group in groups)
            for(n in processGroup(group, parent.nodes)) // Process each group/batch of tokens
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups

        return results;
    }

    static function processGroup(group:SelectorGroup, allNodes:Array<DataNode>):Array<DataNode> {
        // TODO: allow multiple filters so can do orderBy/etc within this loop
        function processFilter(nodes:Array<DataNode>, filter:TokenFilter) {
            switch(filter) {
                case All:
                    // Pass through
                case Eq(pos):
                    if(pos > nodes.length) nodes = [];
                        else nodes = [ nodes[pos] ];
                case Gt(pos):
                    if(pos > nodes.length) nodes = [];
                        else nodes = [ for(i in pos ... nodes.length) nodes[i] ];
                case Lt(pos):
                    if(pos > 0) {
                        if(pos > nodes.length) pos = nodes.length;
                        nodes = [ for(i in 0 ... pos) nodes[i] ];
                    }
            }
            return nodes;
        }

        function getDescendants(nodes:Array<DataNode>, type:String, found:Array<DataNode>, searched:Array<DataNode>):Array<DataNode> {
            for(n in nodes) {
                if(searched.indexOf(n) == -1) {
                    searched.push(n);
                    if(n.type == type) if(found.indexOf(n) == -1) found.push(n);
                    getDescendants(n.children, type, found, searched);
                }
            }
            return found;
        }

        // This handles in-memory data only - a SQL backed system could/should generate a query instead to request data
        // Each token pass will filter/update the allNodes array with the current data set
        var tokenQueue = group.tokens.copy();
        while(tokenQueue.length > 0 && allNodes.length > 0) {
            var token = tokenQueue.shift();
            switch(token) {
                case All(filter):
                    allNodes = processFilter(allNodes, filter);
                case Id(id):
                    allNodes = [ allNodes.find((n) -> n.fields.field("id") == id) ];
                case OfType(type, filter):
                    allNodes = processFilter(allNodes.filter((n) -> n.type == type), filter);
                case Children(type, filter):
                    var childNodes:Array<DataNode> = [];
                    if(type == "*")
                        for(n in allNodes) for(c in n.children) if(childNodes.indexOf(c) == -1) childNodes.push(c);
                    else
                        for(n in allNodes) for(c in n.children.filter((c) -> c.type == type)) if(childNodes.indexOf(c) == -1) childNodes.push(c);
                    allNodes = processFilter(childNodes, filter);
                case Parents(type, filter):
                    var parentNodes:Array<DataNode> = [];
                    if(type == "*")
                        for(n in allNodes) for(p in n.parents) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                    else
                        for(n in allNodes) for(p in n.parents.filter((p) -> p.type == type)) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                    allNodes = processFilter(parentNodes, filter);
                case Descendants(type, filter):
                    allNodes = processFilter(getDescendants(allNodes, type, [], []), filter);
            }
        }

        return allNodes;
    }

    static function processSubToken(subToken:String, nodes:Array<DataNode>) {
        switch(subToken.charAt(0)) {
            case ":": // query selector
                var q = subToken.substr(1);
                var m = [ "eq", "gt", "lt" ].find((t) -> q.indexOf(t) == 0);
                switch(m) {
                    case "eq":
                        q = q.substr(3);
                        var pos = Std.parseInt(q);
                        if(pos > nodes.length) nodes = [];
                            else nodes = [ nodes[pos] ];
                    case "gt":
                        q = q.substr(3);
                        var pos = Std.parseInt(q);
                        if(pos > nodes.length) nodes = [];
                            else nodes = [ for(i in pos ... nodes.length) nodes[i] ];
                    case "lt":
                        q = q.substr(3);
                        var pos = Std.parseInt(q) - 1;
                        if(pos > 0) {
                            if(pos > nodes.length) pos = nodes.length;
                            nodes = [ for(i in 0 ... pos) nodes[i] ];
                        }
                }
            case "[": // attribute/field selector
                trace("TODO: attribute selector");
        }
        return nodes;
    }
}
