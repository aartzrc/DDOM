package ddom;

import ddom.Selector;
import ddom.Processor.IProcessor;

/**
 * The core instance. Once created and 'nodes' are accessed it becomes a cached data set. Use select() without an argument to re-run the selector.
 */
@:allow(ddom.DDOM, ddom.DDOMIterator, ddom.Processor, ddom.SelectorListener)
class DDOMInst {
    // TODO: isolate Processor from DDOM - things are getting too complex, and it will make Transactions easier to implement having things cleaned up
    var selector:Selector; // the selector for this DDOM instance
    var processor:IProcessor; // processor that will be called to generate the nodes array
    var nodes(get,never):Array<DataNode>; // nodes will be lazy created when needed
    var _nodes:Array<DataNode>; // cached array of result nodes for the selector - this should NEVER be reset - a DDOM instance, once created and accessed, should always return the same set - to access data changes, a new select should occur

    function new(processor:IProcessor, selector:Selector) {
        this.processor = processor;
        this.selector = selector;
    }

    function get_nodes() {
        // Lazy-load the nodes, for efficiency but also so data can be 'injected' before first call to get_nodes (create() method relies on this)
        if(_nodes == null)
            _nodes = processor.process(selector);
        return _nodes;
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
        return new DDOMInst(processor, selector);
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
         } else { // Detach a child batch
            var coreChild:DDOMInst = cast child;
            var batch = DataNode.createBatch();
            for(node in nodes) {
                for(cn in coreChild.nodes)
                    node.removeChild(cn, batch);
            }
            batch.fire();
        }
        return new DDOMInst(processor, selector);
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
        var ddom = new DDOMInst(processor, selector.concat(".:pos(" + n + ")")); // Get all, then choose the 'n'th item
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
     * Create a new DDOM using the processor attached to this DDOM and appending the selector
     * @param selector 
     * @return DDOM
     */
    public function select(selector:Selector = null):DDOM {
        return new DDOMInst(processor, this.selector.concat(selector));
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

@:forward(iterator, append, children, parents, size, remove, select, toString)
abstract DDOM(DDOMInst) from DDOMInst #if debug to DDOMInst #end {
    @:op(a.b)
    public function fieldWrite(name:String, value:String) this.fieldWrite(name, value);
    @:op(a.b)
    public function fieldRead(name:String):String return this.fieldRead(name);
    @:op([]) 
    public function arrayRead(n:Int) return this.arrayRead(n);

    public static function create(type:String):DDOM return Processor.create(type);
}
