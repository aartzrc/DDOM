package ddom;

import ddom.Selector;

class Tokenizer {
	
    public static function tokenize(selector:String):Array<SelectorGroup> {
        var out:Array<SelectorGroup> = [];
        var mode:Mode = OfType(0);
#if tokenizerdebug
        var modeChanges:Array<{c:String, m:Mode}> = [];
#end
        var group:Array<SelectorToken> = [];
        var lastFilters:Array<TokenFilter>;
        var filters:Array<TokenFilter> = [];
        
        // Check for parent/child as first char and prepend space to fix logic
        var firstCode = selector.charCodeAt(0);
        if(firstCode == "<".code || firstCode == ">".code)
            selector = " " + selector;

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
                            lastFilters = filters;
                            filters = [];
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
                            lastFilters = filters;
                            filters = [];
                        case ",".code:
                            group.push(OfType(selector.substring(start, i), filters));
                            mode = NewGroup;
                    }
                case Descendants(start):
                    switch(c) {
                        case ">".code:
                            mode = Children(i);
                            if(i-start > 1) {
                                lastFilters = filters;
                                filters = [];
                            }
                        case "<".code:
                            mode = Parents(i);
                            if(i-start > 1) {
                                lastFilters = filters;
                                filters = [];
                            }
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Descendants(t, filters));
                            }
                            mode = FieldFilter(i);
                        case ":".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Descendants(t, filters));
                            }
                            mode = PropFilter(i);
                        case "#".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Descendants(t, filters));
                            }
                            mode = IdFilter(i);
                        case " ".code:
                            mode = Descendants(i);
                            lastFilters = filters;
                            filters = [];
                        case ",".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Descendants(t, filters));
                            }
                            mode = NewGroup;

                    }
                case Children(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Children(t, filters));
                            }
                            mode = FieldFilter(i);
                        case ":".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Children(t, filters));
                            }
                            mode = PropFilter(i);
                        case "#".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Children(t, filters));
                            }
                            mode = IdFilter(i);
                        case " ".code:
                            if(i - start < 2) {
                                mode = Children(i);
                            } else {
                                mode = Descendants(i);
                                lastFilters = filters;
                                filters = [];
                                group.push(Children(selector.substring(start+1, i), filters));
                            }
                        case ",".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Children(t, filters));
                            }
                            mode = NewGroup;

                    }
                case Parents(start):
                    switch(c) {
                        case "\\".code:
                            mode = Escape(mode);
                        case "[".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Parents(t, filters));
                            }
                            mode = FieldFilter(i);
                        case ":".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Parents(t, filters));
                            }
                            mode = PropFilter(i);
                        case "#".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Parents(t, filters));
                            }
                            mode = IdFilter(i);
                        case " ".code:
                            if(i - start < 2) {
                                mode = Parents(i);
                            } else {
                                mode = Descendants(i);
                                lastFilters = filters;
                                filters = [];
                                group.push(Parents(selector.substring(start+1, i), filters));
                            }
                        case ",".code:
                            var t = selector.substring(start+1, i);
                            if(t == "." && lastFilters != null) {
                                filters = lastFilters;
                            } else {
                                group.push(Parents(t, filters));
                            }
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
                            lastFilters = filters;
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
                    lastFilters = null;
                    filters = [];
                    mode = OfType(i);
                case Escape(prevMode):
                    // Ignore the next character and revert to previous mode
                    mode = prevMode;
            }
#if tokenizerdebug
            modeChanges.push({c:selector.substr(i, 1), m:mode});
#end
        }

        for(i in 0 ... selector.length)
            next(i, selector.charCodeAt(i));

        next(selector.length+1, ",".code);
        out.push(group);

#if tokenizerdebug
        for(i in modeChanges)
            trace(i);
#end
        function cleanFilters(filters:Array<TokenFilter>) {
            var prevPos:TokenFilter = null;
            var prevId:TokenFilter = null;
            for(f in filters.copy()) {
                switch(f) {
                    case Id(_):
                        if(prevId != null) filters.remove(prevId);
                        prevId = f;
                    case Pos(_):
                        if(prevPos != null) filters.remove(prevPos);
                        prevPos = f;
                    case _:
                }
            }
        }

        // Clean up/merge filters
        for(group in out) {
            for(token in group) {
                switch(token) {
                    case OfType(type, filters):
                        cleanFilters(filters);
                    case Children(type, filters):
                        cleanFilters(filters);
                    case Parents(type, filters):
                        cleanFilters(filters);
                    case Descendants(type, filters):
                        cleanFilters(filters);
                }
            }
        }

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
