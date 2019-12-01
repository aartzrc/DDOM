package ddom;

using Lambda;
using Reflect;
using Type;

import ddom.Selector;

/**
 * The core immutable instance. Once created and 'nodes' are accessed it becomes a cached data set. Use select() without an argument to re-run the selector.
 */
@:allow(ddom.DDOM, ddom.DDOMIterator, ddom.SelectorProcessor)
class DDOMInst extends Processor implements ISelectable {
    var selector:Selector; // the selector for this DDOM instance
    var processors:Array<ISelectable>; // processors that will be called to generate the nodes array
    var nodes(get,never):Array<DataNode>; // nodes will be lazy created when needed
    var _nodes:Array<DataNode>; // cached array of result nodes for the selector - this should NEVER be reset - a DDOM instance, once created and accessed, should always return the same set - to access data changes, a new select should occur

    /**
     * processors array can include any external data sources or other DDOM instances, the selector is called on all processor instances and the unique results are combined
     * @param processors 
     * @param selector 
     */
    function new(processors:Array<ISelectable> = null, selector:Selector = null) {
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
                    if(_nodes.indexOf(n) == -1) _nodes.push(n);
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
        for(node in nodes) {
            for(cn in coreChild.nodes) {
                if(node.children.indexOf(cn) == -1) {
                    cn.parents.push(node);
                    node.children.push(cn);
                }
            }
        }
        return new DDOMInst(processors, selector);
    }

    /**
     * Remove/detach all the children in the provided DDOM from all nodes in this DDOM, if child is null then remove THIS DDOM nodes from their parents
     * @param child 
     */
    public function remove(child:DDOM = null):DDOM {
        if(child == null) { // Detach myself from all parents
            for(node in nodes) {
                for(pn in node.parents)
                    pn.children.remove(node);
                node.parents = [];
            }
            var ddom = new DDOMInst();
            ddom._nodes = nodes;
            return ddom;
         } else { // Detach a child batch
            var coreChild:DDOMInst = cast child;
            for(node in nodes) {
                for(cn in coreChild.nodes) {
                    node.children.remove(cn);
                    cn.parents.remove(node);
                }
            }
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
        var ddom = new DDOMInst(processors, selector.concat(".:pos(" + n + ")")); // Get all, then choose the 'n'th item
        // :pos selector works but results in a full select each time, 'faking' it by injecting into _nodes cache
        if(n < 0 || n >= _nodes.length) ddom._nodes = [];
            ddom._nodes = [_nodes[n]];
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
@:allow(ddom.DDOMInst, ddom.Processor)
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
        var fnames = fields.fields();
        fnames.remove("id");
        var out = fnames.map((n) -> n + ":" + fields.field(n)).join(",");
        return "{type:" + type + (id != null ? ",id:" + id : "") + (out.length > 0 ? " " + out : "") + "}";
    }
}


/**
 * Helper for DDOMInst
 */
class Processor {
    function process(selector:Selector):Array<DataNode> {
        var results:Array<DataNode> = [];

        var groups:Array<SelectorGroup> = selector;
        if(groups.length == 0) return rootNodes(); // Empty selector returns all data
        for(group in groups)
            for(n in processGroup(group)) // Process each group/batch of tokens
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups

        return results;
    }

    function rootNodes():Array<DataNode> {
        return [];
    }

    function processGroup(group:SelectorGroup):Array<DataNode> {
        // This recursively drills down the data nodes and selector tokens to find results
        var newGroup = group.copy();
        var token = newGroup.pop();
        if(token == null) return rootNodes(); // End of the chain, start with root data nodes

        var sourceNodes:Array<DataNode> = processGroup(newGroup); // Drill up the selector stack to get 'parent' data
                 
        var results:Array<DataNode>;

        switch(token) {
            case OfType(type, filters):
                results = selectOfType(type, filters, sourceNodes);
            case Children(type, filter):
                var childNodes:Array<DataNode> = [];
                if(type == "*") {
                    for(n in sourceNodes) for(c in n.children) if(childNodes.indexOf(c) == -1) childNodes.push(c);
                } else {
                    for(n in sourceNodes)
                        for(c in n.children.filter((c) -> c.type == type)) 
                            if(childNodes.indexOf(c) == -1) childNodes.push(c);
                }
                results = processFilter(childNodes, filter);
            case Parents(type, filter):
                var parentNodes:Array<DataNode> = [];
                if(type == "*") {
                    for(n in sourceNodes) for(p in n.parents) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                } else {
                    for(n in sourceNodes)
                        for(p in n.parents.filter((p) -> p.type == type)) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
                }
                results = processFilter(parentNodes, filter);
            case Descendants(type, filter):
                results = processFilter(getDescendants(sourceNodes, type, [], []), filter);
        }

        // Debug trace to watch data chain process
        trace(sourceNodes + " => " + token + " => " + results);

        return results;
    }

    // Override methods below for custom processor

    function selectOfType(type:String, filters:Array<TokenFilter>, nodes:Array<DataNode> = null) {
        if(nodes == null) return [];
        if(type != "*" && type != ".") nodes = nodes.filter((n) -> n.type == type);
        return processFilter(nodes, filters);
    }

    function processFilter(nodes:Array<DataNode>, filters:Array<TokenFilter>) {
        for(filter in filters) {
            switch(filter) {
                case Id(id):
                    nodes = nodes.filter((n) -> n.fields.hasField("id") && n.fields.field("id") == id);
                case Pos(pos):
                    if(pos >= nodes.length) nodes = [];
                        else nodes = [ nodes[pos] ];
                case Gt(pos):
                    if(pos > nodes.length) nodes = [];
                        else nodes = [ for(i in pos+1 ... nodes.length) nodes[i] ];
                case Lt(pos):
                    if(pos > 0) {
                        if(pos > nodes.length) pos = nodes.length;
                        nodes = [ for(i in 0 ... pos) nodes[i] ];
                    } else {
                        nodes = [];
                    }
                case ValEq(name, val):
                    nodes = nodes.filter((n) -> n.fields.hasField(name) && n.fields.field(name) == val);
                case ValNE(name, val):
                    nodes = nodes.filter((n) -> !n.fields.hasField(name) || n.fields.field(name) != val);
                case OrderBy(name):
                    nodes.sort((n1,n2) -> {
                        var a = n1.fields.hasField(name) ? n1.fields.field(name) : "";
                        var b = n2.fields.hasField(name) ? n2.fields.field(name) : "";
                        if (a < b) return -1;
                        if (a > b) return 1;
                        return 0;
                    });
            }
        }
        return nodes;
    }

    function getDescendants(nodes:Array<DataNode>, type:String, found:Array<DataNode>, searched:Array<DataNode>):Array<DataNode> {
        for(n in nodes) {
            if(searched.indexOf(n) == -1) {
                searched.push(n);
                if(n.type == type) if(found.indexOf(n) == -1) found.push(n);
                getDescendants(n.children, type, found, searched);
            }
        }
        return found;
    }
}
