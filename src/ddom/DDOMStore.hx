package ddom;

import ddom.DDOM;
import ddom.DDOM.DataNode;

/**
 * This is the root level repository of data, it provides some basic lookups and events. Extend/override to handle backing data sources.
 */
@:allow(ddom.DDOMInst, ddom.DDOMSelectorProcessor)
class DDOMStore extends DDOMEventManager {
    // Lookup maps, for speed mostly - this could be handled with one large Array
    var dataByType:Map<String, Array<DataNode>> = [];
    var dataById:Map<String, Array<DataNode>> = [];

    /* 
    Note: selector consolidation might work, but the cascade effects of appending each parent selector group with all child selector groups gets pretty heavy (or not.. they're just comma separated strings?)
    The biggest problem is 'detached' nodes that use a sub() to get selections, there is no way to register them at the root level of DDOMStore without an id
    For now, make the client/server sync and selector consolidation system totally isolated from DDOMStore and only operate on events fired
    An event for 'select' will need to happen
    
    Any way to drill up the chain during sub() and see if it was original a Store.select() and then auto-attach?
    Any way to auto-attach if a sub chain becomes attached? 
    Sort of.. whenever create() is called the Store will attach to events which can be passed off to the server
    If the client has assigned an 'id' to the DDOM instance, then it can be attached
    If the server assigns an 'id' it can be mapped back to the DDOM instance which allows it to be attached
    If 2 instances of the same type and id are sent to the server, they would 'merge' and become a single instance - any way to handle that?

    */

    public function new() {
        // New/empty repo, extend DDOMStore to attach to alternate backing data
        super();
    }

	public function create(type:String):DDOM {
        var dn = new DataNode(type);
        if(!dataByType.exists(type)) dataByType[type] = [];
        dataByType[type].push(dn);
        // A bit of trickery to maintain ctor consistency - empty selector returns an empty nodes result, then we populate with the single item that was just created
        var ddom = new DDOMInst(this, "");
        ddom.nodes.push(dn);
        fire(Created(ddom));
        // TODO: attach to the new ddom and forward events
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
