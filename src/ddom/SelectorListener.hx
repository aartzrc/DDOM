package ddom;

import ddom.DDOM;
import ddom.Processor.IProcessor;

class SelectorListener {
    /**
     * Begin 'listening' to a DDOM, this will only respond with structure changes, field value changes that do not effect the structure are ignored
     * @param ddom 
     * @param callback 
     * @return ->Void):()->Void
     */
    public static function attach(ddom:DDOM, callback:(DDOM)->Void):()->Void {
        var l:Listener = {
            ddom:ddom,
            callback:callback,
            listenDetachFuncs:[]
        }
        attachToProcessors(l);

        // Return the current result immediately
        handleChange(l);

        return detach.bind(l);
    }

    static function detach(l:Listener) {
        for(f in l.listenDetachFuncs) f();
        l.listenDetachFuncs = [];
    }

    static function handleChange(l:Listener) {
        l.ddom = l.ddom.select();
        l.callback(l.ddom);
    }

    static function attachToProcessors(l:Listener) {
        var handler = handleChange.bind(l);
        var ddi = cast(l.ddom, DDOMInst);
        for(p in ddi.processors)
            l.listenDetachFuncs.push(p.listen(ddi.selector, handler));
    }
}

typedef Listener = {
    ddom:DDOM,
    callback:(DDOM)->Void,
    listenDetachFuncs:Array<()->Void>
}