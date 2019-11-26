package ddom;

import ddom.DDOM.DDOMInst;
import ddom.DDOM.DataNode;

using Lambda;
using Reflect;
using Type;
using StringTools;

@:allow(ddom.DDOMInst)
class DDOMSelectorProcessor {
    /* Notes:
        selectors groups are comma separated, white space is required as a token separator
        selectors can be chained (not sure how yet...)
        # id
        < parent - eg: "user < *" will get all parents of the user type, "user < session" will get the sessions of all users - css uses ! token, but it's wacky so I decided on < instead
        > direct child - eg: "user > session" will get sessions of all users, "user! > cart! > product[name=paper]" will get users with a cart that have products with name "paper"
        * all - eg: "*[name=paper]" will get any type with a name "paper"
        ' ' (space) all descendents - eg: "user product" will get all products for all users
        ~ get siblings - eg: "user ~ employee" will get all employees that are data-siblings of users
        :eq(x) get at position - eg: "cart > product:eq(0)" get the first product in the cart

        TODO: store the selector within the DDOM and make DDOM 'observable', when a data update occurs re-run the selector and notify any listeners
    */
    static function process(store:DDOMStore, selector:String, parent:DDOMInst = null):Array<DataNode> {
        if(parent == null) { // null parent means use all data
            parent = new DDOMInst(store, "");
            parent.nodes = store.dataByType.flatten();
        }

        var results:Array<DataNode> = [];

        for(sel in selector.split(",")) { // Break into selector groups
            for(n in processTokens(sel.split(" "), parent.nodes)) // Break selector into tokens and process
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups
        }

        return results;
    }

    static function processTokens(tokens:Array<String>, allNodes:Array<DataNode>):Array<DataNode> {
        var resultNodes:Array<DataNode> = [];
        var prevType = null;
        for(t in tokens) {
            t = t.trim();
            // Ignore empties
            if(t.length > 0) {
                // First char is the main token
                switch(t.charAt(0)) {
                    case "*": // all selector
                        resultNodes = [];
                        for(n in allNodes)
                            if(resultNodes.indexOf(n) == -1) resultNodes.push(n);
                        allNodes = resultNodes;
                        t = t.substr(1);
                    case "#": // id selector
                        resultNodes = [];
                        var id = t.substr(1);
                        var n = allNodes.find((n) -> n.fields.field("id") == id );
                        if(n != null && resultNodes.indexOf(n) == -1) resultNodes.push(n);
                        allNodes = resultNodes;
                        t = t.substr(id.length + 1);
                    case ">": // direct children selector
                        allNodes = [];
                        for(n in resultNodes) for(c in n.children) if(allNodes.indexOf(c) == -1) allNodes.push(c);
                        resultNodes = [];
                        t = t.substr(1);
                    case "<": // parent selector
                        allNodes = [];
                        for(n in resultNodes) for(p in n.parents) if(allNodes.indexOf(p) == -1) allNodes.push(p);
                        resultNodes = [];
                        t = t.substr(1);
                    case _: // Default to type selection
                        var type = t;
                        // Check for sub tokens
                        var st1 = t.indexOf("[");
                        var st2 = t.indexOf(":");
                        if(st1 > 0) {
                            type = type.substr(0, st1);
                        } else if(st2 > 0) {
                            type = type.substr(0, st2);
                        }
                        if(prevType != null) {
                            resultNodes = recurseChildrenByType(allNodes, type, [], []);
                        } else {
                            resultNodes = [];
                            for(n in allNodes.filter((n) -> n.type == type))
                                if(resultNodes.indexOf(n) == -1) resultNodes.push(n);
                            allNodes = resultNodes;
                        }
                        t = t.substr(type.length);

                        prevType = type;
                }
                // Check for 'sub' tokens
                if(t.length > 0)
                    resultNodes = processSubToken(t, resultNodes);
            }
        }
        return resultNodes;
    }

    static function recurseChildrenByType(allNodes:Array<DataNode>, type:String, found:Array<DataNode>, searched:Array<DataNode>):Array<DataNode> {
        for(n in allNodes) {
            if(searched.indexOf(n) == -1) {
                if(n.type == type)
                    if(found.indexOf(n) == -1) found.push(n);
                recurseChildrenByType(n.children, type, found, searched);
            }
        }
        return found;
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
