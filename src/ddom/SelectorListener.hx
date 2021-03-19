package ddom;

import ddom.DDOM;

class SelectorListener {
    /**
     * Begin 'listening' to a DDOM, this will only respond with structure changes, field value changes that do not effect the structure are ignored
     * @param ddom 
     * @param callback 
     * @return ->Void):()->Void
     */
    public static function attach(ddom:DDOM, callback:(DDOM)->Void, immediate:Bool = true):()->Void {
        var l:Listener = {
            ddom:ddom,
            callback:callback,
            listenDetachFuncs:new DetachManager()
        }
        attachToProcessor(l);

        // Return the current result immediately
        if(immediate) handleChange(l);

        return detach.bind(l);
    }

    static function detach(l:Listener) {
        l.listenDetachFuncs.detach();
        l.listenDetachFuncs = null;
    }

    public static function then(ddom:DDOM, callback:(DDOM)->Void) {
        var detach:()->Void = null;
        detach = attach(ddom, (val) -> {
            detach();
            callback(val);
        }, false);
    }

    static function handleChange(l:Listener) {
        l.ddom = l.ddom.select();
        l.callback(l.ddom);
    }

    static function attachToProcessor(l:Listener) {
        var handler = handleChange.bind(l);
        var ddi = cast(l.ddom, DDOMInst);
        l.listenDetachFuncs += ddi.processor.listen(ddi.selector, handler);
    }
}

typedef Listener = {
    ddom:DDOM,
    callback:(DDOM)->Void,
    listenDetachFuncs:DetachManager
}