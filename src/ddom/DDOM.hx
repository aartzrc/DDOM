package ddom;

import haxe.PosInfos;
using Lambda;
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
                node.addChild(cn);
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
                    pn.removeChild(node);
            }
            var ddom = new DDOMInst();
            ddom._nodes = nodes;
            return ddom;
         } else { // Detach a child batch
            var coreChild:DDOMInst = cast child;
            for(node in nodes) {
                for(cn in coreChild.nodes) {
                    node.removeChild(cn);
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
    function fieldWrite(name:String, value:String) {
        for(node in nodes) node.setField(name, value);
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

    public function attach(callback:(ddom:DDOM) -> Void):()->Void {
        var detachFuncs:Array<()->Void> = [];
        for(p in processors)
            detachFuncs.push(p.listen(selector, callback));

        return () -> {
            for(f in detachFuncs) f();
        }
    }

    function listen(selector:Selector, callback:(ddom:DDOM) -> Void):()->Void {
        function fire() {
            trace("HERE");
        }
        var attachNode = rootNodes.length > 0 ? rootNodes[0] : null;

        if(attachNode != null) attachNode.on(fire);
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

@:forward(iterator, append, children, parents, size, remove, select)
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
@:allow(ddom.DDOMInst, ddom.Processor)
class DataNode {
    var type:String;
    var fields:Map<String,String> = [];
    var children:Array<DataNode> = [];
    var parents:Array<DataNode> = [];

    var listeners:Array<()->Void> = [];
    
	function new(type:String) {
        this.type = type;
    }

    function setField(name:String, val:String) {
        if(fields[name] != val) {
            fields[name] = val;
            fire();
        }
    }

    function getField(name:String) {
        return fields[name];
    }

    function addChild(child:DataNode) {
        var mod = false;
        if(children.indexOf(child) == -1) {
            children.push(child);
            mod = true;
        }
        if(child.parents.indexOf(this) == -1) {
            child.parents.push(this);
            mod = true;
        }
        if(mod) {
            if(listeners.length > 0) child.on(fire);
            fire();
        }
    }

    function removeChild(child:DataNode) {
        if(children.remove(child) || child.parents.remove(this)) {
            child.off(fire);
            fire();
        }
    }

    function addParent(parent:DataNode) {
        var mod = false;
        if(parents.indexOf(parent) == -1) {
            parents.push(parent);
            mod = true;
        }
        if(parent.children.indexOf(this) == -1) {
            parent.children.push(this);
            mod = true;
        }
        if(mod) {
            if(listeners.length > 0) parent.on(fire);
            fire();
        }
    }

    function removeParent(parent:DataNode) {
        if(parents.remove(parent) || parent.children.remove(this)) {
            parent.off(fire);
            fire();
        }
    }

    function on(callback:()->Void) {
        if(listeners.indexOf(callback) == -1)
            listeners.push(callback);
    }

    function off(callback:()->Void) {
        listeners.remove(callback);
    }
    
    var handleListeners:Array<()->Void> = null;
    function fire() {
        if(listeners.length == 0) return; // No one listening
        if(handleListeners == null) // Tell listeners and parents+children
            handleListeners = listeners.concat([for(p in parents) p.fire]).concat([for(c in children) c.fire]);
        handleFire();
    }
    function handleFire() {
        while(handleListeners != null && handleListeners.length > 0)
            handleListeners.shift()();
        handleListeners = null;
    }

    public function toString() {
        var id = fields["id"];
        var fnames = [ for(n in fields.keys()) n ];
        fnames.remove("id");
        var out = fnames.map((n) -> n + ":" + fields[n]).join(",");
        return "{type:" + type + (id != null ? ",id:" + id : "") + (out.length > 0 ? " => " + out : "") + "}";
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
        trace(token);
        switch(token) {
            case OfType(type, filters):
                results = selectOfType(type, filters);
            case Children(type, filters):
                results = selectChildren(sourceNodes, type, filters);
            case Parents(type, filter):
                results = selectParents(sourceNodes, type, filter);
            case Descendants(type, filter):
                results = processFilter(getDescendants(sourceNodes, type, [], []), filter);
        }

        // Debug trace to watch data chain process
        //trace(sourceNodes + " => " + token + " => " + results);

        return results;
    }

    // Override 'select' methods below for custom processor
    function selectOfType(type:String, filters:Array<TokenFilter>):Array<DataNode> {
        var nodes = rootNodes(); // OfType is always at the start of the chain, use rootNodes() for default
        if(type != "*" && type != ".") nodes = nodes.filter((n) -> n.type == type);
        return processFilter(nodes, filters);
    }

    function selectChildren(parentNodes:Array<DataNode>, childType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var childNodes:Array<DataNode> = [];
        if(childType == "*" || childType == ".") {
            for(n in parentNodes) for(c in n.children) if(childNodes.indexOf(c) == -1) childNodes.push(c);
        } else {
            for(n in parentNodes)
                for(c in n.children.filter((c) -> c.type == childType)) 
                    if(childNodes.indexOf(c) == -1) childNodes.push(c);
        }
        return processFilter(childNodes, filters);
    }

    function selectParents(childNodes:Array<DataNode>, parentType:String, filters:Array<TokenFilter>):Array<DataNode> {
        var parentNodes:Array<DataNode> = [];
        if(parentType == "*" || parentType == ".") {
            for(n in childNodes) for(p in n.parents) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
        } else {
            for(n in childNodes)
                for(p in n.parents.filter((p) -> p.type == parentType)) if(parentNodes.indexOf(p) == -1) parentNodes.push(p);
        }
        return processFilter(parentNodes, filters);
    }
    
    // selectDescendants runs via selectChildren and doesn't need to be overridden, but should be overridden for efficiency
    function selectDescendants(parentNodes:Array<DataNode>, descType:String, filters:Array<TokenFilter>):Array<DataNode> {
        return processFilter(getDescendants(parentNodes, descType, [], []), filters);
    }

    function getDescendants(nodes:Array<DataNode>, type:String, found:Array<DataNode>, searched:Array<DataNode>):Array<DataNode> {
        for(n in nodes) {
            if(searched.indexOf(n) == -1) {
                searched.push(n);
                if(n.type == type) if(found.indexOf(n) == -1) found.push(n);
                getDescendants(selectChildren([n], "*", []), type, found, searched);
            }
        }
        return found;
    }
    
    // use processFilter as a 'fallback' filter, it would be better to do this work during query generation
    function processFilter(nodes:Array<DataNode>, filters:Array<TokenFilter>):Array<DataNode> {
        for(filter in filters) {
            switch(filter) {
                case Id(id):
                    nodes = nodes.filter((n) -> n.fields["id"] == id);
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
                    nodes = nodes.filter((n) -> n.fields[name] == val);
                case ValNE(name, val):
                    nodes = nodes.filter((n) -> n.fields[name] != val);
                case OrderBy(name):
                    nodes.sort((n1,n2) -> {
                        var a = n1.fields.exists(name) ? n1.fields[name] : "";
                        var b = n2.fields.exists(name) ? n2.fields[name] : "";
                        if (a < b) return -1;
                        if (a > b) return 1;
                        return 0;
                    });
            }
        }
        return nodes;
    }
}
