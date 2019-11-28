package ddom;

import ddom.DDOM;
import ddom.DDOM.DataNode;

/**
 * A data cache that provides a general purpose repository and handles node creation and root-level selection.
 * TODO: Add an event log here that can be used for async updates and event generation (DDOMInst doesn't do events directly)
 */
@:allow(ddom.DDOMInst, ddom.DDOMSelectorProcessor)
class Cache implements ISelectable {
    // Lookup maps, for speed mostly - this could be handled with one large Array
    var dataByType:Map<String, Array<DataNode>> = [];
    var dataById:Map<String, Array<DataNode>> = [];
    /*
    ... start dropping the DDOM at the beginning
    allow new DDOM(selector) instead of DDOMCache.create

    Another idea:
    change this to DDOMCache - it is only used to allow immediate responses on all selects
    incoming data gets pushed into it via messages/events that are batches
    then selectors are re-run and data is pushed to listening endpoints
    event management would be simplified
    a DDOMConnector would do the work of getting new data based on what selectors are currently running on the DDOMCache
    the DDOMConnector could then be made async easily
    a default DDOMConnector would replace DDOMSelectorProcessor, which would always be available on the DDOMCache if the regular connector is async

    create a ISelectable interface which gets applied to DDOMCache and DDOM to keep things lined up
    should a field be assignable to a DDOM instance? this would essentially 'name' the DDOM group and add it as a child, but I think that gets too complex, probably better to use a field to denote the child name
    ISelectables can be 'chained', provide an array of ISelectable to a new DDOM and it will call up the stack
    This would allow things like DDOMCache to be backed by an application logic layer, then a database back-end layer (IOC on the data system, just stick more ISelectables in between to add functionality )
    
    attach/detach manager should be an extension method of ISelectable? 
    it would take the DDOMCache and selector and respond to events that modify it (re-run selector and check for changes)
    for detached/unselectable items it would not do anything until the DDOM was selectable from the root
    */
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

    public function new() {}

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

    /**
     * Select from the root data set
     * @param selector 
     * @return DDOM
     */
    public function select(selector:String):DDOM {
        return new DDOMInst(this, selector);
    }
}
