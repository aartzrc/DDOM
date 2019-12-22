package ddom;

using ddom.LambdaExt;

import ddom.Selector;
import ddom.Processor.IProcessor;

// private function listen(selector:Selector, callback:(ddom:DDOM) -> Void):()->Void;

/**
 * The core instance. Once created and 'nodes' are accessed it becomes a cached data set. Use select() without an argument to re-run the selector.
 */
@:allow(ddom.DDOM, ddom.DDOMIterator, ddom.Processor, ddom.SelectorListener, ddom.Transaction)
class DDOMInst extends Processor implements ISelectable implements IProcessor {
    var selector:Selector; // the selector for this DDOM instance
    var processors:Array<IProcessor>; // processors that will be called to generate the nodes array
    var nodes(get,never):Array<DataNode>; // nodes will be lazy created when needed
    var _nodes:Array<DataNode>; // cached array of result nodes for the selector - this should NEVER be reset - a DDOM instance, once created and accessed, should always return the same set - to access data changes, a new select should occur

    /**
     * processors array can include any external data sources or other DDOM instances, the selector is called on all processor instances and the unique results are combined
     * @param processors 
     * @param selector 
     */
    function new(processors:Array<IProcessor> = null, selector:Selector = null) {
        this.processors = processors != null ? processors : [this]; // null processors means this is a 'stand-alone' instance, manually populate the _nodes cache and assign 'this' as a processor so sub-selects work
        this.selector = selector != null ? selector : []; // a null selector means this is a 'root' data source
    }

    function get_nodes() {
        // Lazy-load the nodes, for efficiency but also so data can be 'injected' before first call to get_nodes (create() method relies on this)
        if(_nodes == null) {
            _nodes = [];

            // Get all unique nodes from the available processors
            for(processor in processors) {
                for(n in processor.process(selector))
                    _nodes.pushUnique(n);
            }
        }
        return _nodes;
    }

    override function rootNodes():Array<DataNode> {
        return nodes;
    }

    /**
     * Create a new 'detached' DDOM instance
     * @param type 
     * @return DDOM
     */
    public static function create(type:String):DDOM {
        var ddom = new DDOMInst();
        ddom._nodes = [new DataNode(type)];
        return ddom;
    }

    /**
     * Helper to get children - maps directly to "> *" selector
     * @return DDOM
     */
    public function children(type:String = "*"):DDOM {
        return select("> " + type); // Get all direct children of nodes in this DDOM
    }

    /**
     * Helper to get parents - maps directly to "< *" selector
     * @return DDOM
     */
    public function parents(type:String = "*"):DDOM {
        return select("< " + type); // Get all parents of nodes in this DDOM
    }

    /**
     * Append all nodes within the provided DDOM to all nodes within this DDOM and return a new DDOM
     * @param child 
     */
    public function append(child:DDOM):DDOM {
        var coreChild:DDOMInst = cast child;
        var batch = DataNode.createBatch();
        for(node in nodes) {
            for(cn in coreChild.nodes) {
                node.addChild(cn, batch);
            }
        }
        batch.fire();
        return new DDOMInst(processors, selector);
    }

    /**
     * Remove/detach all the children in the provided DDOM from all nodes in this DDOM, if child is null then remove THIS DDOM nodes from their parents
     * @param child 
     */
    public function remove(child:DDOM = null):DDOM {
        if(child == null) { // Detach myself from all parents
            var batch = DataNode.createBatch();
            for(node in nodes)
                node.remove(batch);
            batch.fire();
            var ddom = new DDOMInst();
            ddom._nodes = nodes;
            return ddom;
         } else { // Detach a child batch
            var coreChild:DDOMInst = cast child;
            var batch = DataNode.createBatch();
            for(node in nodes) {
                for(cn in coreChild.nodes) {
                    node.removeChild(cn, batch);
                }
            }
            batch.fire();
            return new DDOMInst(processors, selector);
        }
    }

    public inline function size() {
        return nodes.length;
    }

    /**
     * Updates all nodes in this DDOM with the name.value
     * @param name 
     * @param value 
     */
    function fieldWrite(name:String, value:String) {
        var batch = DataNode.createBatch();
        for(node in nodes) node.setField(name, value, batch);
        batch.fire();
    }

    /**
     * Gets first node and returns the field value (or null if no data available)
     * @param name 
     * @return T
     */
    function fieldRead(name:String):String {
        if(nodes.length == 0) return null;
        return nodes[0].getField(name);
    }

    function arrayRead(n:Int):DDOM {
        var ddom = new DDOMInst(processors, selector.concat(".:pos(" + n + ")")); // Get all, then choose the 'n'th item
        // :pos selector works but results in a full select each time, 'faking' it by injecting into _nodes cache
        if(n < 0 || n >= nodes.length) ddom._nodes = [];
            ddom._nodes = [nodes[n]];
        return ddom;
    }

    public function iterator():Iterator<DDOM> {
        return new DDOMIterator(this);
    }

    public function toString() {
        return "{"+selector+"}" + " = " + Std.string(nodes);
    }

    /**
     * Create a new DDOM using the processors attached to this DDOM and appending the selector
     * @param selector 
     * @return DDOM
     */
    public function select(selector:Selector = null):DDOM {
        if(selector == null && this.selector.length == 0) return this; // Ignore re-select on a root node
        return new DDOMInst(processors, this.selector.concat(selector));
    }

    /**
     * Extension method that provides access to DataNodes based on type
     * @param ddom
     * @param type 
     */
    public static function nodesOfType(ddom:DDOMInst, type:String) {
        return ddom.nodes.filter((dn) -> dn.type == type);
    }
}

@:allow(ddom.DDOMInst)
class DDOMIterator {
    var i:Int = 0;
    var ddom:DDOMInst;
    function new(ddom:DDOMInst) {
        this.ddom = ddom;
    }
    public function hasNext() {
        return i < ddom.nodes.length;
    }
    public function next() {
        return ddom.arrayRead(i++);
    }
}

@:forward(iterator, append, children, parents, size, remove, select, attach, toString)
abstract DDOM(DDOMInst) from DDOMInst #if debug to DDOMInst #end {
    @:op(a.b)
    public function fieldWrite(name:String, value:String) this.fieldWrite(name, value);
    @:op(a.b)
    public function fieldRead(name:String):String return this.fieldRead(name);
    @:op([]) 
    public function arrayRead(n:Int) return this.arrayRead(n);

    public static function create(type:String):DDOM return DDOMInst.create(type);
}

// This is the actual data item, DDOM wraps this
@:allow(ddom.DDOMInst, ddom.Processor, ddom.SelectorListener)
class DataNode {
    var type:String;
    var fields:Map<String,String> = [];
    var children:Array<DataNode> = [];
    var parents:Array<DataNode> = [];

    var listeners:Array<(Event)->Void> = [];

    var events:Array<{event:Event,time:Float}> = [];
    
	function new(type:String, batch:EventBatch = null) {
        this.type = type;
        if(batch != null) batch.events.push(Created(type));
        else fire(Created(type));
    }

    function remove(batch:EventBatch = null) {
        var fireBatch = batch == null;
        batch = buildBatch(batch);
        for(p in parents)
            removeParent(p, batch);
        batch.events.push(Removed(this));
        if(fireBatch) batch.fire();
    }

    function setField(name:String, val:String, batch:EventBatch = null) {
        if(fields[name] != val) {
            fields[name] = val;
            if(batch != null) {
                batch = buildBatch(batch);
                batch.events.push(FieldSet(name, val));
            } else {
                fire(FieldSet(name, val));
            }
        }
    }

    function getField(name:String) {
        return fields[name];
    }

    function addChild(child:DataNode, batch:EventBatch = null) {
        if(children.pushUnique(child)) {
            var fireBatch = batch == null;
            batch = buildBatch(batch);
            batch.events.push(ChildAdded(child));
            child.addParent(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function removeChild(child:DataNode, batch:EventBatch = null) {
        if(children.remove(child)) {
            var fireBatch = batch == null;
            batch = buildBatch(batch);
            batch.events.push(ChildRemoved(child));
            child.removeParent(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function addParent(parent:DataNode, batch:EventBatch = null) {
        if(parents.pushUnique(parent)) {
            var fireBatch = batch == null;
            batch = buildBatch(batch);
            batch.events.push(ParentAdded(parent));
            parent.addChild(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function removeParent(parent:DataNode, batch:EventBatch = null) {
        if(parents.remove(parent)) {
            var fireBatch = batch == null;
            batch = buildBatch(batch);
            batch.events.push(ParentRemoved(parent));
            parent.removeChild(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function on(callback:(Event)->Void) {
        listeners.pushUnique(callback);
    }

    function off(callback:(Event)->Void) {
        listeners.remove(callback);
    }
    
    function fire(event:Event) {
        events.push({event:event,time:Date.now().getTime()});
        for(l in listeners) l(event);
    }

    public function toString() {
        var id = fields["id"];
        var fnames = [ for(n in fields.keys()) n ];
        fnames.remove("id");
        var out = fnames.map((n) -> n + ":" + fields[n]).join(",");
        return "{type:" + type + (id != null ? ",id:" + id : "") + (out.length > 0 ? " => " + out : "") + "}";
    }

    function buildBatch(batch:EventBatch = null):EventBatch {
        if(batch == null) batch = createBatch();
        for(l in listeners)
            batch.listeners.pushUnique(l);
        return batch;
    }

    static function createBatch() {
        var events:Array<Event> = [];
        var listeners:Array<(Event)->Void> = [];
        return { 
            events:events,
            listeners:listeners,
            fire: () -> {
                var batch = Batch(events);
                for(l in listeners) l(batch);
            } 
        };
    }
}

enum Event {
    Batch(events:Array<Event>);
    Created(type:String);
    Removed(node:DataNode);
    ChildAdded(child:DataNode);
    ChildRemoved(child:DataNode);
    ParentAdded(parent:DataNode);
    ParentRemoved(parent:DataNode);
    FieldSet(name:String,val:String);
}

typedef EventBatch = {
    events:Array<Event>,
    listeners:Array<(Event)->Void>,
    fire:Void -> Void
}