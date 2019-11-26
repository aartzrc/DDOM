package ddom;

import ddom.DDOM;
import ddom.DDOM.DataNode;

/**
 * This is the root level repository of data, it provides some basic lookups and events. Extend/override to handle backing data sources.
 */
@:allow(ddom.DDOMInst, ddom.DDOMSelectorProcessor)
class DDOMStore {
    // Lookup maps, for speed mostly - this could be handled with one large Array
    var dataByType:Map<String, Array<DataNode>> = [];
    var dataById:Map<String, DataNode> = [];

    var listeners:Map<Int, Array<(event:DDOMEvent)->Void>> = [];

    public function new() {
        // New/empty repo, extend DDOMStore to attach to alternate backing data
    }

    /**
     * Add a listener for the specified event (or null for all events). Use null values in event constructor. return is a function that can be used for detaching the callback - or use 'off'
     * @param event 
     * @param callback 
     * @return ()->Void
     */
    public function on(event:DDOMEvent, callback:(event:DDOMEvent)->Void) {
        var index = event == null ? 0 : event.getIndex();
        if(!listeners.exists(index)) listeners[index] = [];
        var cbs = listeners[index];
        if(cbs.indexOf(callback) == -1)
            cbs.push(callback);
        return off.bind(event, callback);
    }

    /**
     * Remove a listener, or ALL listeners for an event by passing a null callback function
     * @param event 
     * @param callback 
     * @return ->Void)
     */
    public function off(event:DDOMEvent, callback:(event:DDOMEvent)->Void) {
        var index = event == null ? 0 : event.getIndex();
        if(!listeners.exists(index)) return false;
        if(callback == null) { // null callback, remove all associated listeners
            if(index > 0) return listeners.remove(index);
            // null callback and index == 0, remove ALL listeners
            listeners = [];
            return true;
        }
        var cbs = listeners[index];
        return cbs.remove(callback);
    }

    function fire(event:DDOMEvent) {
        if(event == null) return;
        var index = event.getIndex();
        if(listeners.exists(0)) // Check for listeners that want all events
            for(cb in listeners[0])
                cb(event);
        if(!listeners.exists(index)) return;
        for(cb in listeners[index])
            cb(event);
    }

	public function create(type:String):DDOM {
        var dn = new DataNode(type);
        if(!dataByType.exists(type)) dataByType[type] = [];
        dataByType[type].push(dn);
        // A bit of trickery to maintain ctor consistency - empty selector returns an empty nodes result, then we populate with the single item that was just created
        var ddom = new DDOMInst(this, "");
        ddom.nodes.push(dn);
        fire(Created(ddom));
        return ddom;
    }

    public function getById(id:String):DDOM {
        return new DDOMInst(this, "#" + id);
    }

    public function getByType(type:String):DDOM {
        return new DDOMInst(this, type);
    }

    /**
     * Select from the root data set
     * @param selector 
     * @return DDOM
     */
    public function select(selector:String):DDOM {
        return new DDOMInst(this, selector);
    }
}
