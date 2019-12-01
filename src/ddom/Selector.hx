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
        # id - multiple instances with same id are possible, type selector eg: "session#id", this is needed for databases which can have duplicate ids across different types
        < parent - eg: "user < *" will get all parents of the user type, "user < session" will get the sessions of all users - css uses ! token, but it's wacky so I decided on < instead
        > direct child - eg: "user > session" will get sessions of all users, "user > cart > product[name=paper]" will get users with a cart that have products with name "paper"
        * all - eg: "*[name=paper]" will get any type with a name "paper"
        ' ' (space) all descendents - eg: "user product" will get all products for all users
        ~ TODO: get siblings - eg: "user ~ employee" will get all employees that are data-siblings of users
        :pos(x) get at position - eg: "cart > product:pos(0)" get the first product in the cart
        multiple 'filters' are possible per token - eg: user[firstname=joe]:order(lastname):pos(0) would get users with firstname of 'joe', order by lastname field, and get the first item

        TODO: store the selector within the DDOM and make DDOM 'observable', when a data update occurs re-run the selector and notify any listeners
    */
    static function tokenize(selector:String):Selector {
        function processGroup(sel:String) {
            var tokens:Array<SelectorToken> = [];

            function multiSplit(str:String, delimiters:Array<String>) {
                var result:Array<String> = [];
                var splitPos:Array<Int> = [];
                for(i => c in str) if(delimiters.indexOf(String.fromCharCode(c)) != -1) splitPos.push(i);
                var prevPos = 0;
                for(nextPos in splitPos) {
                    result.push(str.substring(prevPos, nextPos));
                    prevPos = nextPos;
                }
                result.push(str.substring(prevPos));
                return result;
            }
            function splitType(sel:String) {
                var filters = multiSplit(sel, ["#", "[", ":"]);
                var type = filters.shift();
                if(type == null || type.length == 0) type = "*";

                return {type:type,filters:filters};
            }
            function processFilters(filters:Array<String>) {
                var tokenFilters:Array<TokenFilter> = [];
                for(filter in filters) {
                    switch(filter.charAt(0)) {
                        case ":": // query selector
                            var q = filter.substr(1);
                            var m = [ "pos", "gt", "lt", "orderby" ].find((t) -> q.indexOf(t) == 0);
                            var v = q.substr(m.length+1);
                            switch(m) {
                                case "pos":
                                    tokenFilters.push(Pos(Std.parseInt(v)));
                                case "gt":
                                    tokenFilters.push(Gt(Std.parseInt(v)));
                                case "lt":
                                    tokenFilters.push(Lt(Std.parseInt(v)));
                                case "orderby":
                                    tokenFilters.push(OrderBy(v.substr(0, v.length-1)));
                            }
                        case "[": // attribute/field selector
                            var q = filter.substr(1, filter.length-2);
                            var m = [ "!=", "=" ].find((t) -> q.indexOf(t) != -1);
                            var p = q.split(m);
                            switch(m) {
                                case "!=":
                                    tokenFilters.push(ValNE(p[0], p[1]));
                                case "=":
                                    tokenFilters.push(ValEq(p[0], p[1]));
                            }
                        case "#": // id selector
                            tokenFilters.push(Id(filter.substr(1)));
                    }
                }

                return tokenFilters;
            }

            var tokenChunks = multiSplit(sel, [">","<"," "]).map((s) -> s.trim()).filter((s) -> s.length>0);

            var lastFilters:Array<TokenFilter> = null;
            while(tokenChunks.length > 0) {
                var t = tokenChunks.shift();    
                switch(t) {
                    case ">": // direct children selector
                        // get child type, the next token
                        var type = splitType(tokenChunks.shift());
                        if(type.type == ".") type.type = "*"; // 'append' selector not available, switch to 'all' selector
                        lastFilters = processFilters(type.filters);
                        tokens.push(Children(type.type, lastFilters));
                    case "<": // parent selector
                        // get parent type
                        var type = splitType(tokenChunks.shift());
                        if(type.type == ".") type.type = "*"; // 'append' selector not available, switch to 'all' selector
                        lastFilters = processFilters(type.filters);
                        tokens.push(Parents(type.type, lastFilters));
                    case _: // Default to type selection
                        var type = splitType(t);
                        var filters = processFilters(type.filters);
                        if(type.type == ".") { // Append to last filters
                            if(lastFilters == null) {
                                lastFilters = filters;
                                tokens.push(OfType(type.type, lastFilters));
                            } else {
                                for(f in filters) lastFilters.push(f);
                            }
                        } else {
                            if(tokens.length == 0) { // First token in chain, assume a 'child' selection
                                lastFilters = filters;
                                tokens.push(OfType(type.type, lastFilters));
                            } else { // Not parent or child selector, fall back to descendants filter
                                lastFilters = filters;
                                tokens.push(Descendants(type.type, lastFilters));
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

        function detokenizeFilters(filters:Array<TokenFilter>) {
            var filterDetokenized = "";
            for(filter in filters) {
                switch(filter) {
                    case Id(id):
                        filterDetokenized += "#" + id;
                    case Pos(pos):
                        filterDetokenized += ":pos(" + pos + ")";
                    case Gt(pos):
                        filterDetokenized += ":gt(" + pos + ")";
                    case Lt(pos):
                        filterDetokenized += ":lt(" + pos + ")";
                    case ValEq(name, val):
                        filterDetokenized += "[" + name + "=" + val + "]";
                    case ValNE(name, val):
                        filterDetokenized += "[" + name + "!=" + val + "]";
                    case OrderBy(name):
                        filterDetokenized += ":orderby(" + name + ")";
                }
            }
            return filterDetokenized;
        }

        var detokenized:Array<String> = [];
        for(group in groups) {
            var groupDetokenized:Array<String> = [];
            for(token in group) {
                switch(token) {
                    case OfType(type, filter):
                        groupDetokenized.push(type + detokenizeFilters(filter));
                    case Children(type, filter):
                        groupDetokenized.push("> " + type + detokenizeFilters(filter));
                    case Parents(type, filter):
                        groupDetokenized.push("< " + type + detokenizeFilters(filter));
                    case Descendants(type, filter):
                        groupDetokenized.push(type + detokenizeFilters(filter));
                }
            }
            detokenized.push(groupDetokenized.join(" "));
        }
        return detokenized.join(",");
    }

    public function concat(selector:Selector):Selector {
        if(selector == null) return this;
        if(this.length == 0) return selector; // Detect append on a 'root' selector

        // Append the passed selector groups to all groups to create a new 'chain'
        // Convert to/from string to perform cleanup/append operations
        var out:Array<String> = [];
        var parentStrs:Array<String> = (this:Selector).toString().split(",");
        var appendStrs:Array<String> = selector.toString().split(",");
        for(parentStr in parentStrs) {
            for(appendStr in appendStrs) {
                out.push(parentStr + " " + appendStr);
            }
        }
        return out.join(",");
    }
}

typedef SelectorGroup = Array<SelectorToken>;

enum SelectorToken {
    OfType(type:String, filters:Array<TokenFilter>);
    Children(type:String, filters:Array<TokenFilter>);
    Parents(type:String, filters:Array<TokenFilter>);
    Descendants(type:String, filters:Array<TokenFilter>);
}

enum TokenFilter {
    Id(id:String);
    Pos(pos:Int);
    Gt(pos:Int);
    Lt(pos:Int);
    ValEq(name:String,val:String);
    ValNE(name:String,val:String);
    OrderBy(name:String);
}