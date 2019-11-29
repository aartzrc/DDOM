package ddom;

import ddom.DDOM.DDOMInst;
import ddom.DDOM.DataNode;
import ddom.Selector;

using Lambda;
using Reflect;
using StringTools;

@:allow(ddom.DDOMInst, ddom.Selector)
class SelectorProcessor {
    static function process(selectables:Array<ISelectable>, selector:Selector):Array<DataNode> {
        var results:Array<DataNode> = [];

        //trace(selectables); // Never try to call DDOM.toString, causes an infinite loop/stack overflow
        //trace(selector);
        
        var groups:Array<SelectorGroup> = selector;
        for(group in groups)
            for(n in processGroup(group, selectables)) // Process each group/batch of tokens
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups

        return results;
    }

    static function processGroup(group:SelectorGroup, selectables:Array<ISelectable>):Array<DataNode> {
        var newGroup = group.copy();
        var token = newGroup.pop();

        //trace(token);

        if(token == null) { // End of the line, return the nodes of the current selectables
            var sourceNodes:Array<DataNode> = [];
            for(s in selectables) {
                var inst:DDOMInst = cast s;
                for(n in inst.nodes) if(sourceNodes.indexOf(n) == -1) sourceNodes.push(n); // Add unique nodes
            }
            return sourceNodes;
        } else {
            var sourceNodes:Array<DataNode> = [];
            for(s in selectables) {
                var inst:DDOMInst = cast s.select([newGroup]); // Get 'parent select' data from the ISelectable and then cast down to break out of the DDOM field modifier abstract
                for(n in inst.nodes) if(sourceNodes.indexOf(n) == -1) sourceNodes.push(n); // Add unique nodes
            }
            
            var results:Array<DataNode>;
            // TODO: allow multiple filters so can do orderBy/etc within this loop
            function processFilter(nodes:Array<DataNode>, filter:TokenFilter) {
                switch(filter) {
                    case All:
                        // Pass through
                    case Eq(pos):
                        if(pos >= nodes.length) nodes = [];
                            else nodes = [ nodes[pos] ];
                    case Gt(pos):
                        if(pos > nodes.length) nodes = [];
                            else nodes = [ for(i in pos+1 ... nodes.length) nodes[i] ];
                    case Lt(pos):
                        if(pos > 0) {
                            if(pos > nodes.length) pos = nodes.length;
                            nodes = [ for(i in 0 ... pos) nodes[i] ];
                        } else {
                            nodes = [];
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

            switch(token) {
                case All(filter):
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
                    results = processFilter(getDescendants(sourceNodes, type, [], []), filter);
            }

            return results;
        }
    }
}
