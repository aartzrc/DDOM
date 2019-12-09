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
    public static function attach(ddom:DDOMInst, callback:(DDOM)->Void):()->Void {
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
        for(p in l.ddom.processors)
            p.listen(l.ddom.selector, handler);
    }
}

typedef Listener = {
    ddom:DDOMInst,
    callback:(DDOM)->Void,
    listenDetachFuncs:Array<()->Void>
}