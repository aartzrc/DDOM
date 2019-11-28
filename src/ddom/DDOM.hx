package ddom;

import ddom.SelectorProcessor;

using Lambda;
using Reflect;
using Type;

@:allow(ddom.DDOM, ddom.DDOMIterator, ddom.SelectorProcessor)
class DDOMInst implements ISelectable {
    var selector:Selector; // The selector for this DDOM instance
    var selectables:Array<ISelectable>; // Selectables that will be called to generate the nodes array
    var nodes(get,never):Array<DataNode>;
    var _nodes:Array<DataNode>; // Nodes that have been 'selected' via the data cascade
    var _coreNodes:Array<DataNode>; // Nodes that have been 'created' - these are a true data instance

    /**
     * selectables array can include any external data sources or other DDOM instances, selector operates on the data set of the of all the selectables
     * @param selectables 
     * @param selector 
     */
    function new(selectables:Array<ISelectable> = null, selector:Selector = null) {
        this.selectables = selectables != null ? selectables : [];
        this.selector = selector != null ? selector : "*";
    }

    function get_nodes() {
        // Lazy-load the nodes, for efficiency but also so data can be 'injected' before first call to get_nodes (create() method relies on this)
        if(_nodes == null) _nodes = _coreNodes != null ? _coreNodes.concat(SelectorProcessor.process(selectables, selector)) : SelectorProcessor.process(selectables, selector);
        return _nodes;
    }

    /**
     * Create a new 'detached' DDOM instance
     * @param type 
     * @return DDOM
     */
    public static function create(type:String):DDOM {
        var ddom = new DDOMInst();
        ddom._coreNodes = [new DataNode(type)];
        return ddom;
    }

    /**
     * Helper to get children - maps directly to "* > *" selector
     * @return DDOM
     */
    public function children(type:String = "*"):DDOM {
        return select("* > " + type); // Get all direct children of nodes in this DDOM
    }

    /**
     * Helper to get parents - maps directly to "* < *" selector
     * @return DDOM
     */
    public function parents(type:String = "*"):DDOM {
        return select("* < " + type); // Get all parents of nodes in this DDOM
    }

    /**
     * Append all nodes within the provided DDOM to all nodes within this DDOM
     * @param child 
     */
    public function append(child:DDOM) {
        var coreChild:DDOMInst = cast child;
        for(node in nodes) {
            for(cn in coreChild.nodes) {
                if(node.children.indexOf(cn) == -1) {
                    cn.parents.push(node);
                    node.children.push(cn);
                }
            }
        }
        return this;
    }

    /**
     * Remove/detach all the children in the provided DDOM from all nodes in this DDOM, if child is null then remove THIS DDOM from it's parents
     * @param child 
     */
    public function remove(child:DDOM = null) {
        if(child == null) { // Detach myself from all parents
            for(node in nodes) {
                for(pn in node.parents)
                    pn.children.remove(node);
                node.parents = [];
            }
            selectables = []; // No parents to request data from
            _nodes = null; // Reset the cache
         } else { // Detach a child batch
            var coreChild:DDOMInst = cast child;
            for(node in nodes) {
                for(cn in coreChild.nodes) {
                    node.children.remove(cn);
                    cn.parents.remove(node);
                }
            }
            coreChild.selectables.remove(this); // Remove myself from the child lookup
            coreChild._nodes = null; // Reset the child cache
        }
        return this;
    }

    public inline function size() {
        return nodes.length;
    }

    /**
     * Updates all nodes in this DDOM with the name.value
     * @param name 
     * @param value 
     */
    function fieldWrite<T>(name:String, value:T) {
        for(node in nodes) node.fields.setField(name, value);
    }

    /**
     * Gets first node and returns the field value (or null if no data available)
     * @param name 
     * @return T
     */
    function fieldRead<T>(name:String):T {
        if(nodes.length == 0) return null;
        return nodes[0].fields.field(name);
    }

    function arrayRead(n:Int):DDOM {
        return new DDOMInst([this], "*:eq(" + n + ")"); // Get all, then choose the 'n'th item
    }

    public function iterator():Iterator<DDOM> {
        return new DDOMIterator(this);
    }

    public function toString() {
        return Std.string(nodes);
    }

    public function select(selector:Selector):DDOM {
        return new DDOMInst([this], selector);
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

@:forward(iterator, append, children, parents, size, remove, select)
abstract DDOM(DDOMInst) from DDOMInst to DDOMInst {
    @:op(a.b)
    public function fieldWrite<T>(name:String, value:T) this.fieldWrite(name, value);
    @:op(a.b)
    public function fieldRead<T>(name:String):T return this.fieldRead(name);
    @:op([]) 
    public function arrayRead(n:Int) return this.arrayRead(n);

    public static function create(type:String):DDOM return DDOMInst.create(type);
}

// This is the actual data item, DDOM wraps this
@:allow(ddom.DDOMInst, ddom.SelectorProcessor)
class DataNode {
    var type:String;
    var fields = {};
    var children:Array<DataNode> = [];
    var parents:Array<DataNode> = [];
    
	function new(type:String) {
        this.type = type;
    }

    public function toString() {
        var id = fields.field("id");
        return "{type:" + type + (id != null ? ",id:" + id : "") + "}";
    }
}
