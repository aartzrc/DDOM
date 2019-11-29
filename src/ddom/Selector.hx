package ddom;

import ddom.DDOM.DDOMInst;
import ddom.DDOM.DataNode;

using Lambda;
using Reflect;
using StringTools;

@:forward(length)
abstract Selector(Array<SelectorGroup>) from Array<SelectorGroup> to Array<SelectorGroup> {
    @:from
    static public function fromString(selector:String) return tokenize(selector);
    @:to
    public function toString() return detokenize(this);

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
    static function tokenize(selector:String):Selector {
        function processGroup(sel:String) {
            var tokens:Array<SelectorToken> = [];
            var tokenChunks = sel.split(" ");

            function splitType(sel:String) {
                var type = sel;
                var filter = null;
                // Check for filters
                var st1 = sel.indexOf("[");
                var st2 = sel.indexOf(":");
                var stid = sel.indexOf("#");
                if(st1 > 0) {
                    type = sel.substr(0, st1);
                    filter = sel.substr(st1);
                } else if(st2 > 0) {
                    type = sel.substr(0, st2);
                    filter = sel.substr(st2);
                } else if(stid > 0) {
                    type = sel.substr(0,stid);
                    filter = sel.substr(stid);
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
                    case "#": // id selector
                        return Id(filter.substr(1));
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
                            if(tokenChunks[0] != null && getCleanTokenType(tokenChunks[0]) == null) { // Check for 'descendants' selector
                                var descType = splitType(tokenChunks.shift());
                                tokens.push(Descendants(descType.type, processFilter(descType.filter)));
                            }
                        case "#": // id selector
                            var idSplit = splitType(t.substr(1));
                            tokens.push(Id(idSplit.type, processFilter(idSplit.filter)));
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
        return selector.split(",").map((sel) -> processGroup(sel)).filter((sel) -> sel.length > 0);
    }

    static function detokenize(selector:Selector):String {
        var groups:Array<SelectorGroup> = selector;

        function detokenizeFilter(filter:TokenFilter) {
            var filterDetokenized = "";
            switch(filter) {
                case All:
                    // Pass through
                case Id(id):
                    filterDetokenized += "#" + id;
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
            for(token in group) {
                switch(token) {
                    case All(filter):
                        groupDetokenized.push("*" + detokenizeFilter(filter));
                    case Id(id, filter):
                        groupDetokenized.push("#" + id + detokenizeFilter(filter));
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
}

typedef SelectorGroup = Array<SelectorToken>;

enum SelectorToken {
    All(filter:TokenFilter);
    Id(id:String, filter:TokenFilter);
    OfType(type:String, filter:TokenFilter);
    Children(type:String, filter:TokenFilter);
    Parents(type:String, filter:TokenFilter);
    Descendants(type:String,filter:TokenFilter);
}

enum TokenFilter {
    All;
    Id(id:String);
    Eq(pos:Int);
    Gt(pos:Int);
    Lt(pos:Int);
}