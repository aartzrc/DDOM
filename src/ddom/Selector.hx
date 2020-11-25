package ddom;

using Lambda;
using StringTools;

@:forward(length)
abstract Selector(Array<SelectorGroup>) from Array<SelectorGroup> to Array<SelectorGroup> {
    @:from
    static public function fromString(selector:String):Selector return Tokenizer.tokenize(selector);
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
    */

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
                    case ContainsWord(name, val):
                        filterDetokenized += "[" + name + "~=" + val + "]";
                    case StartsWith(name, val):
                        filterDetokenized += "[" + name + "^=" + val + "]";
                    case Contains(name, val):
                        filterDetokenized += "[" + name + "*=" + val + "]";
                    case OrderAsc(name):
                        filterDetokenized += ":orderasc(" + name + ")";
                    case OrderDesc(name):
                        filterDetokenized += ":orderdesc(" + name + ")";
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
        var out:Array<SelectorGroup> = [];
        for(parentGroup in this) {
            for(childGroup in (selector:Array<SelectorGroup>)) {
                if(parentGroup.length == 1) { // Detect append on a 'root' selector
                    switch(parentGroup[0]) {
                        case OfType(type, filters):
                            if(type == ".") { // Root selector, check if the childGroup is OfType and adjust to select at current node level
                                parentGroup = [OfType("*", filters)];
                                if(childGroup.length > 0) {
                                    switch(childGroup[0]) {
                                        case OfType(_):
                                            parentGroup = [];
                                        case _: // Ignored
                                    }
                                }
                            }
                        case _: // Ignored
                    }
                }
                out.push(parentGroup.concat(childGroup));
            }
        }
        // Run through tokenizer to 'clean up'
        return Tokenizer.tokenize((out:Selector).toString());
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
    ContainsWord(name:String,val:String);
    StartsWith(name:String,val:String);
    Contains(name:String, val:String);
    OrderAsc(name:String);
    OrderDesc(name:String);
}