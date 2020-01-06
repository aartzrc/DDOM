package tests;

import ddom.Selector;

class TokenizerTests {
	static function main() {
        var tests:Array<SelectorTest> = [];

        var t1:SelectorTest = {
            sel:"customer[name=jon doe]",
            res:[[OfType("customer", [ValEq("name", "jon doe")])]]
        };
        tests.push(t1);
        var t2:SelectorTest = {
            sel:t1.sel.concat(".:pos(0)"),
            res:[[OfType("customer", [ValEq("name", "jon doe"), Pos(0)])]]
        }
        tests.push(t2);
        var t3:SelectorTest = {
            sel:t2.sel.concat(" > item"),
            res:[[OfType("customer", [ValEq("name", "jon doe"), Pos(0)]), Children("item", [])]]
        }
        tests.push(t3);
        var t4:SelectorTest = {
            sel:t3.sel.concat(".:pos(0)"),
            res:[[OfType("customer", [ValEq("name", "jon doe"), Pos(0)]), Children("item", [Pos(0)])]]
        }
        tests.push(t4);

        for(t in tests) {
            if(!isSame(t.sel, t.res)) {
                trace("FAIL: " + t.sel + " != " + t.res);
            }
        }

        trace(tests.length + " tests run");
    }
    
    static function isSame(sel:Selector, res:Array<SelectorGroup>) {
        var groups:Array<SelectorGroup> = sel;
        if(groups.length != res.length) return false;
        for(i in 0 ... groups.length) {
            if(!isSame_Group(groups[i], res[i])) return false;
        }
        return true;
    }

    static function isSame_Group(a:SelectorGroup, b:SelectorGroup) {
        if(a.length != b.length) return false;
        for(i in 0 ... a.length) {
            switch(a[i]) {
                case OfType(type_a, filters_a):
                    switch(b[i]) {
                        case OfType(type_b, filters_b):
                            if(type_a != type_b) return false;
                            if(!isSame_Filters(filters_a, filters_b)) return false;
                        case _:
                            return false;
                    }
                case Children(type_a, filters_a):
                    switch(b[i]) {
                        case Children(type_b, filters_b):
                            if(type_a != type_b) return false;
                            if(!isSame_Filters(filters_a, filters_b)) return false;
                        case _:
                            return false;
                    }
                case Parents(type_a, filters_a):
                    switch(b[i]) {
                        case Parents(type_b, filters_b):
                            if(type_a != type_b) return false;
                            if(!isSame_Filters(filters_a, filters_b)) return false;
                        case _:
                            return false;
                    }
                case Descendants(type_a, filters_a):
                    switch(b[i]) {
                        case Descendants(type_b, filters_b):
                            if(type_a != type_b) return false;
                            if(!isSame_Filters(filters_a, filters_b)) return false;
                        case _:
                            return false;
                    }
            }
        }
        return true;
    }

    static function isSame_Filters(a:Array<TokenFilter>, b:Array<TokenFilter>) {
        if(a.length != b.length) return false;
        for(i in 0 ... a.length) {
            switch(a[i]) {
                case Id(id_a):
                    switch(b[i]) {
                        case Id(id_b):
                            if(id_a != id_b) return false;
                        case _:
                            return false;
                    }
                case Pos(p_a):
                    switch(b[i]) {
                        case Pos(p_b):
                            if(p_a != p_b) return false;
                        case _:
                            return false;
                    }
                case Gt(v_a):
                    switch(b[i]) {
                        case Gt(v_b):
                            if(v_a != v_b) return false;
                        case _:
                            return false;
                    }
                case Lt(v_a):
                    switch(b[i]) {
                        case Lt(v_b):
                            if(v_a != v_b) return false;
                        case _:
                            return false;
                    }
                case ValEq(n_a, v_a):
                    switch(b[i]) {
                        case ValEq(n_b, v_b):
                            if(n_a != n_b || v_a != v_b) return false;
                        case _:
                            return false;
                    }
                case ValNE(n_a, v_a):
                    switch(b[i]) {
                        case ValNE(n_b, v_b):
                            if(n_a != n_b || v_a != v_b) return false;
                        case _:
                            return false;
                    }
                case OrderBy(v_a):
                    switch(b[i]) {
                        case OrderBy(v_b):
                            if(v_a != v_b) return false;
                        case _:
                            return false;
                    }
            }
        }
        return true;
    }
}

typedef SelectorTest = {sel:Selector,res:Array<SelectorGroup>};