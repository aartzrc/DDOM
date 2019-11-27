package ddom;

import ddom.DDOM.DDOMInst;
import ddom.DDOM.DataNode;

using Lambda;
using Reflect;
using StringTools;

@:allow(ddom.DDOMInst, ddom.DDOMSelector)
class DDOMSelectorProcessor {
    /* Notes:
        selectors groups are comma separated, white space is required as a token separator
        selectors can be chained (not sure how yet...)
        # id - TODO: allow multiple instances with same id and add type selector eg: "session#id", this is needed for databases which can have duplicate ids across different types
        < parent - eg: "user < *" will get all parents of the user type, "user < session" will get the sessions of all users - css uses ! token, but it's wacky so I decided on < instead
        > direct child - eg: "user > session" will get sessions of all users, "user! > cart! > product[name=paper]" will get users with a cart that have products with name "paper"
        * all - eg: "*[name=paper]" will get any type with a name "paper"
        ' ' (space) all descendents - eg: "user product" will get all products for all users
        ~ get siblings - eg: "user ~ employee" will get all employees that are data-siblings of users
        :eq(x) get at position - eg: "cart > product:eq(0)" get the first product in the cart

        TODO: store the selector within the DDOM and make DDOM 'observable', when a data update occurs re-run the selector and notify any listeners
    */
    static function tokenize(selector:String):DDOMSelector {
        function processGroup(sel:String) {
            var tokens:Array<SelectorToken> = [];
            var tokenChunks = sel.split(" ");

            function splitType(sel:String) {
                var type = sel;
                var filter = null;
                // Check for filters
                var st1 = sel.indexOf("[");
                var st2 = sel.indexOf(":");
                if(st1 > 0) {
                    type = sel.substr(0, st1);
                    filter = sel.substr(st1);
                } else if(st2 > 0) {
                    type = sel.substr(0, st2);
                    filter = sel.substr(st2);
                }
                return {type:type,filter:filter};
            }
            function processFilter(filter:String) {
                if(filter == null || filter.length == 0) return All;
                switch(filter.charAt(0)) {
                    case ":": // query selector
                        var q = filter.substr(1);
                        var m = [ "eq", "gt", "lt" ].find((t) -> q.indexOf(t) == 0);
                        switch(m) {
                            case "eq":
                                return Eq(Std.parseInt(q.substr(3)));
                            case "gt":
                                return Gt(Std.parseInt(q.substr(3)));
                            case "lt":
                                return Lt(Std.parseInt(q.substr(3)));
                        }
                    case "[": // attribute/field selector
                        trace("TODO: attribute selector");
                }

                // Unknown filter, return All
                return All;
            }

            inline function getCleanTokenType(q:String) {
                // Check for beginning token return match - this just standardizes the lookup, a null means no match and default to 'type' lookup
                return q == null ? null : [ "*", "#", ">", "<" ].find((t) -> q.indexOf(t) == 0);
            }

            while(tokenChunks.length > 0) {
                var t = tokenChunks.shift();
                t = t.trim();
                // Ignore empties
                if(t.length > 0) {
                    switch(getCleanTokenType(t)) {
                        case "*": // all selector
                            tokens.push(All(processFilter(t.substr(1))));
                        case "#": // id selector
                            tokens.push(Id(t.substr(1)));
                        case ">": // direct children selector
                            // get child type
                            var type = splitType(tokenChunks.shift());
                            tokens.push(Children(type.type, processFilter(type.filter)));
                        case "<": // parent selector
                            // get parent type
                            var type = splitType(tokenChunks.shift());
                            tokens.push(Parents(type.type, processFilter(type.filter)));
                        case _: // Default to type selection
                            var type = splitType(t);
                            tokens.push(OfType(type.type, processFilter(type.filter)));
                            if(tokenChunks[0] != null && getCleanTokenType(tokenChunks[0]) == null) { // Check for 'descendants' selector
                                var descType = splitType(tokenChunks.shift());
                                tokens.push(Descendants(descType.type, processFilter(descType.filter)));
                            }
                    }
                }
            }
            return tokens;
        }
        return selector.split(",").map((sel) -> {tokens:processGroup(sel)}).filter((sel) -> sel.tokens.length > 0);
    }

    static function detokenize(selector:DDOMSelector):String {
        var groups:Array<SelectorGroup> = selector;

        function detokenizeFilter(filter:TokenFilter) {
            var filterDetokenized = "";
            switch(filter) {
                case All:
                    // Pass through
                case Eq(pos):
                    filterDetokenized += ":eq(" + pos + ")";
                case Gt(pos):
                    filterDetokenized += ":gt(" + pos + ")";
                case Lt(pos):
                    filterDetokenized += ":lt(" + pos + ")";
            }
            return filterDetokenized;
        }

        var detokenized:Array<String> = [];
        for(group in groups) {
            var groupDetokenized:Array<String> = [];
            for(token in group.tokens) {
                switch(token) {
                    case All(filter):
                        groupDetokenized.push("*" + detokenizeFilter(filter));
                    case Id(id):
                        groupDetokenized.push("#" + id);
                    case OfType(type, filter):
                        groupDetokenized.push(type + detokenizeFilter(filter));
                    case Children(type, filter):
                        groupDetokenized.push("> " + type + detokenizeFilter(filter));
                    case Parents(type, filter):
                        groupDetokenized.push("< " + type + detokenizeFilter(filter));
                    case Descendants(type, filter):
                        groupDetokenized.push(type + detokenizeFilter(filter));
                }
            }
            detokenized.push(groupDetokenized.join(" "));
        }
        return detokenized.join(",");
    }

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

@:forward(length)
abstract DDOMSelector(Array<SelectorGroup>) from Array<SelectorGroup> to Array<SelectorGroup> {
    @:from
    static public function fromString(selector:String) return DDOMSelectorProcessor.tokenize(selector);
    @:to
    public function toString() return DDOMSelectorProcessor.detokenize(this);
}

typedef SelectorGroup = {
    tokens:Array<SelectorToken>
}

enum SelectorToken {
    All(filter:TokenFilter);
    Id(id:String);
    OfType(type:String, filter:TokenFilter);
    Children(type:String, filter:TokenFilter);
    Parents(type:String, filter:TokenFilter);
    Descendants(type:String,filter:TokenFilter);
}

enum TokenFilter {
    All;
    Eq(pos:Int);
    Gt(pos:Int);
    Lt(pos:Int);
}