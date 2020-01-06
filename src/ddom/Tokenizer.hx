package ddom;

import ddom.Selector;

class Tokenizer {
	static function main() {
        // Rebuild of Selector.tokenize
        
        // TODO: tests
        trace(tokenize('customer[name=joe, doe]:pos(0) > session#2,customer[name=some guy],customer[name=mynameis\\]],* > user'));
    }
    
    public static function tokenize(selector:String):Selector {
        var out:Array<SelectorGroup> = [];
        var mode:Mode = OfType(0);
        //var modeChanges:Array<{c:String, m:Mode}> = [];
        var group:Array<SelectorToken> = [];
        var filters:Array<TokenFilter> = [];

        function next(i:Int, c:Int) {
            switch(mode) {
                case FilterScan:
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            mode = FieldFilter(i);
                        case ":".code:
                            mode = PropFilter(i);
                        case "#".code:
                            mode = IdFilter(i);
                        case " ".code:
                            mode = Descendants(i);
                        case ",".code:
                            mode = NewGroup;
                    }
                case OfType(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = FieldFilter(i);
                        case ":".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = PropFilter(i);
                        case "#".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = IdFilter(i);
                        case " ".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = Descendants(i);
                            filters = [];
                        case ",".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = NewGroup;
                    }
                case Descendants(start):
                    switch(c) {
                        case ">".code:
                            mode = Children(i);
                            filters = [];
                        case "<".code:
                            mode = Parents(i);
                            filters = [];
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            group.push(Descendants(selector.substring(start+1, i), filters));
                            mode = FieldFilter(i);
                        case ":".code:
                            group.push(Descendants(selector.substring(start+1, i), filters));
                            mode = PropFilter(i);
                        case "#".code:
                            group.push(Descendants(selector.substring(start+1, i), filters));
                            mode = IdFilter(i);
                        case " ".code:
                            mode = Descendants(i);
                            filters = [];
                        case ",".code:
                            group.push(Descendants(selector.substring(start+1, i), filters));
                            mode = NewGroup;

                    }
                case Children(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            group.push(Children(selector.substring(start+1, i), filters));
                            mode = FieldFilter(i);
                        case ":".code:
                            group.push(Children(selector.substring(start+1, i), filters));
                            mode = PropFilter(i);
                        case "#".code:
                            group.push(Children(selector.substring(start+1, i), filters));
                            mode = IdFilter(i);
                        case " ".code:
                            mode = Children(i);
                        case ",".code:
                            group.push(Children(selector.substring(start+1, i), filters));
                            mode = NewGroup;

                    }
                case Parents(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            group.push(Parents(selector.substring(start+1, i), filters));
                            mode = FieldFilter(i);
                        case ":".code:
                            group.push(Parents(selector.substring(start+1, i), filters));
                            mode = PropFilter(i);
                        case "#".code:
                            group.push(Parents(selector.substring(start+1, i), filters));
                            mode = IdFilter(i);
                        case " ".code:
                            mode = Parents(i);
                        case ",".code:
                            group.push(Parents(selector.substring(start+1, i), filters));
                            mode = NewGroup;

                    }
                case IdFilter(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            filters.push(Id(selector.substring(start+1, i)));
                            mode = FieldFilter(i);
                        case ":".code:
                            filters.push(Id(selector.substring(start+1, i)));
                            mode = PropFilter(i);
                        case " ".code:
                            filters.push(Id(selector.substring(start+1, i)));
                            mode = Descendants(i);
                        case ",".code:
                            filters.push(Id(selector.substring(start+1, i)));
                            mode = NewGroup;
                    }
                case FieldFilter(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "]".code:
                            var str = selector.substring(start+1, i);
                            var eqPos = str.indexOf("=");
                            if(eqPos > 0) filters.push(ValEq(str.substr(0, eqPos), str.substr(eqPos+1)));
                            mode = FilterScan;
                    }
                case PropFilter(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case ")".code:
                            var str = selector.substring(start+1, i);
                            var sPos = str.indexOf("(");
                            if(sPos > 0) {
                                var type = str.substr(0, sPos);
                                var val = str.substring(sPos+1, i-1);
                                switch(type) {
                                    case "pos":
                                        filters.push(Pos(Std.parseInt(val)));
                                    case "gt":
                                        filters.push(Gt(Std.parseInt(val)));
                                    case "lt":
                                        filters.push(Lt(Std.parseInt(val)));
                                    case "orderby":
                                        filters.push(OrderBy(val));
                                }
                            }
                            mode = FilterScan;
                    }
                case NewGroup:
                    out.push(group);
                    group = [];
                    filters = [];
                    mode = OfType(i);
                case Escape(prevMode):
                    // Ignore the next character and revert to previous mode
                    mode = prevMode;
            }
            //modeChanges.push({c:selector.substr(i, 1), m:mode});
        }

        for(i in 0 ... selector.length)
            next(i, selector.charCodeAt(i));

        next(selector.length+1, ",".code);
        out.push(group);
        
        /*for(i in modeChanges)
            trace(i);*/

        return out;
    }
}

enum Mode {
    Escape(prevMode:Mode);
    FilterScan;

    OfType(start:Int);
    Children(start:Int);
    Parents(start:Int);
    Descendants(start:Int);

    IdFilter(start:Int);
    FieldFilter(start:Int);
    PropFilter(start:Int);

    NewGroup;
}
