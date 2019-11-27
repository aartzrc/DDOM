package ddom;

using Lambda;

import ddom.DDOM;
import ddom.DDOM.DataNode;
import ddom.DDOMSelectorProcessor;

/**
 * This is the root level repository of data, it provides some basic lookups and events. Extend/override to handle backing data sources.
 */
 @:allow(ddom.DDOMInst)
class DDOMEventManager {
    var listeners:Map<String, Map<Int, Array<(event:DDOMEvent)->Void>>> = [];

    public function new() {}

    /**
     * Add a listener for the specified event (or null for all events). Use null values in event constructor. return is a function that can be used for detaching the callback - or use 'off'
     * @param event 
     * @param callback 
     * @return ()->Void
     */
    public function on(selector:DDOMSelector = null, event:DDOMEvent = null, callback:(event:DDOMEvent)->Void) {
        var selString:String = selector == null ? "*" : selector;
        var index = event == null ? -1 : event.getIndex();
        if(!listeners.exists(selString)) listeners.set(selString, []);
        var lmap = listeners[selString];
        if(!lmap.exists(index)) lmap.set(index, []);
        var cbs = lmap[index];
        if(cbs.indexOf(callback) == -1)
            cbs.push(callback);
        return off.bind(selector, event, callback);
    }

    /**
     * Remove a listener, or ALL listeners for an event by passing a null callback function
     * @param event 
     * @param callback 
     * @return ->Void)
     */
    public function off(selector:DDOMSelector = null, event:DDOMEvent = null, callback:(event:DDOMEvent)->Void = null) {
        // TODO: add an event when on/off is called - the backing async store can use those events to attach/detach from server
        var selString:String = selector == null ? null : selector;
        var index = event == null ? -1 : event.getIndex();
        var seekListeners:Map<String, Map<Int, Array<(event:DDOMEvent)->Void>>> = null;
        // Filter what listener groups to search
        if(selString != null) {
            if(!listeners.exists(selString)) return false;
            seekListeners = [];
            seekListeners.set(selString, listeners[selString]);
        } else {
            seekListeners = listeners.copy();
        }
        var larrays:Array<Array<(event:DDOMEvent)->Void>> = [];
        if(index >= 0) {
            for(sl in seekListeners.filter((lmap) -> lmap.exists(index)))
                larrays.push(sl[index]);
        } else {
            for(sl in seekListeners)
                for(lmap in sl)
                    larrays.push(lmap);
        }
        if(larrays.length == 0) return false;
        if(callback != null) {
            var found = false;
            for(la in larrays)
                if(la.remove(callback)) found = true;
            return true;
        } else {
            for(la in larrays)
                la.splice(0, la.length);
            return true;
        }
        return true;
    }

    function fire(event:DDOMEvent) {
        if(event == null) return;
        var index = event.getIndex();
        if(listeners.exists("*")) { // Check for listeners that want all events
            var lmap = listeners["*"];
            if(lmap.exists(-1))
                for(cb in lmap[-1]) cb(event);
            if(lmap.exists(index))
                for(cb in lmap[index]) cb(event);
        }
    }
}
