using Lambda;
using Reflect;
using Type;
using StringTools;

@:allow(DDOM, DDOMIterator)
class DDOMCore {
    static var dataByType:Map<String, Array<DataNode>> = [];
    static var dataById:Map<String, DataNode> = [];

	static function create(type:String):DDOM {
        var dn = new DataNode(type);
        if(!dataByType.exists(type)) dataByType[type] = [];
        dataByType[type].push(dn);
        return new DDOMCore(null, dn);
    }

    static function getById(id:String):DDOM {
        return new DDOMCore("#" + id);
    }

    static function getByType(type:String):DDOM {
        return new DDOMCore(type);
    }
    
    var nodes:Array<DataNode>;
    var selector:String;
    function new(selector:String, dataNode:DataNode = null) {
        this.selector = selector;
        if(selector != null) {
            this.nodes = processSelector(selector);
        } else {
            nodes = dataNode != null ? [dataNode] : [];
        }
    }
    /**
     * attaches a callback, any data changes will result in callback being called, return value function is a detach method
     * @param callback 
     * @return ->Void):()->Void
     */
    /*public function attach(callback:(DDOM)->Void):()->Void {

    }*/

    /**
     * Returns all unique children of the nodes available in this DDOM
     * @return DDOM
     */
    public function children():DDOM {
        var childNodes:Array<DataNode> = [];
        for(node in nodes) {
            for(cn in node.children) {
                trace(cn);
                if(childNodes.indexOf(cn) == -1) childNodes.push(cn);
            }
        }
        return new DDOMCore(childNodes);
    }

    public function parents():DDOM {
        var parentNodes:Array<DataNode> = [];
        for(node in nodes) {
            for(pn in node.parents) {
                if(parentNodes.indexOf(pn) == -1) parentNodes.push(pn);
            }
        }
        return new DDOMCore(parentNodes);
    }

    /**
     * Append all nodes within the provided DDOM to all nodes within this DDOM
     * @param child 
     */
    public function append(child:DDOM) {
        var coreChild:DDOMCore = cast child;
        // Verify the children are part of the data set
        if(coreChild.nodes.exists((n) -> dataByType[n.type].indexOf(n) == -1)) throw "Detached DDOM, unable to appendChild";
        for(node in nodes) {
            for(cn in coreChild.nodes) {
                if(node.children.indexOf(cn) == -1) {
                    cn.parents.push(node);
                    node.children.push(cn);
                }
            }
        }
    }

    /**
     * Remove/detach all the children in the provided DDOM from all nodes in this DDOM - does NOT delete the child
     * @param child 
     */
    public function remove(child:DDOM) {
        var coreChild:DDOMCore = cast child;
        for(node in nodes) {
            for(cn in coreChild.nodes) {
                trace(cn);
                node.children.remove(cn);
            }
        }
    }

    /**
     * Detach from all parents and remove from the lookup tables - this becomes a detached DDOM and cannot be used again!
     */
    public inline function delete() {
        for(pn in parents()) pn.remove(this);
        for(node in nodes) {
            var id = node.fields.field("id");
            if(id != null) dataById.remove(id);
            dataByType[node.type].remove(node);
        }
    }

    public inline function size() {
        return nodes.length;
    }

    function fieldWrite<T>(name:String, value:T) {
        if(nodes.length == 0) return;
        var node = nodes[0];
        // Lock down `id` value, must be a String and non-duplicate in the current data set
        if(name == "id") {
            if(!Std.is(value, String)) throw "`DDOM.id` must be a `String`";
            var newId:String = cast value;
            var prevId:String = cast nodes.fields.field("id");
            if(newId != prevId) {
                if(dataById.exists(newId)) throw "Unable to set `DDOM.id`, duplicate id value found";
                if(prevId != null) dataById.remove(prevId);
                dataById.set(newId, node);
            }
        }
        // Verify type remains the same
        var f = node.fields.field(name);
        if(f != null && !Std.is(value, Type.getClass(f))) throw "Data type must remain the same for field `" + name + "` : " + f + " (" + Type.getClass(f).getClassName() + ") != " + value + " (" + Type.getClass(value).getClassName() + ")";
        node.fields.setField(name, value);
    }

    function fieldRead<T>(name:String):T {
        if(nodes.length == 0) return null;
        return nodes[0].fields.field(name);
    }

    function arrayRead(n:Int):DDOM {
        return new DDOMCore([nodes[n]]);
    }

    public function iterator():Iterator<DDOM> {
        return new DDOMIterator(nodes);
    }

    public function toString() {
        return Std.string(nodes);
    }

    static function select(selector:String):DDOM {
        return new DDOMCore(null, selector);
    }

    static function processSelector(selector:String):Array<DataNode> {
        /* Notes:
        selectors groups are comma separated, white space is ignored but is recommended
        selectors can be chained (not sure how yet...)
        # id
        ! parent - eg: "*! > user" will get all parents of the user type, "session! > user" will get the sessions of all users
        > direct child - eg: "user > session" will get sessions of all users, "user! > cart! > product[name=paper]" will get users with a cart that have products with name "paper"
        * all - eg: "*[name=paper]" will get any type with a name "paper"
        ' ' (space) all descendents - eg: "user product" will get all products for all users
        ~ get siblings - eg: "user ~ employee" will get all employees that are data-siblings of users

        TODO: store the selector within the DDOM and make DDOM 'observable', when a data update occurs re-run the selector and notify any listeners
        */

        // Selectors are not working fully yet, this is just to get some data moving around
        // NEVER use processSelector() within this, children/parent calls use processSelector() so it can result in an infinite loop

        // All selector
        if(selector == "*") return dataByType.flatten();

        var results:Array<DataNode> = [];

        for(sel in selector.split(",")) {
            if(sel.charAt(0) == '#') { // ID selector
                var core:DDOMCore = getById(sel.substr(1));
                for(n in core.nodes)
                    if(results.indexOf(n) == -1) results.push(n);
            } else {
                if(sel.indexOf(" ") == -1) { // Type selector
                    var core:DDOMCore = getByType(sel);
                    for(n in core.nodes)
                        if(results.indexOf(n) == -1) results.push(n);
                } else {
                    if(sel.indexOf(">") != -1) { // Direct child selector
                        var s = sel.split(">");
                        var parents:DDOMCore = getByType(s[0].trim());
                        var childType = s[1].trim();
                        for(p in parents.nodes) {
                            for(c in p.children)
                                if(c.type == childType && results.indexOf(c) == -1) results.push(c);
                        }
                    } else if(sel.indexOf("<") != -1) { // Direct parent selector (change to !)
                        var s = sel.split("<");
                        var children:DDOMCore = getByType(s[0].trim());
                        var parentType = s[1].trim();
                        for(c in children.nodes) {
                            for(p in c.parents)
                                if(p.type == parentType && results.indexOf(c) == -1) results.push(p);
                        }
                    }
                }
            }
        }

        return results;
    }
}

@:allow(DDOMCore)
class DDOMIterator {
    var i:Int = 0;
    var nodes:Array<DataNode>;
    function new(nodes:Array<DataNode>) {
        this.nodes = nodes;
    }
    public function hasNext() {
        return i < nodes.length;
    }
    public function next() {
        return new DDOMCore([nodes[i++]]);
    }
}

@:forward(iterator, append, children, size, delete, remove)
abstract DDOM(DDOMCore) from DDOMCore to DDOMCore {
    @:op(a.b)
    public function fieldWrite<T>(name:String, value:T) this.fieldWrite(name, value);
    @:op(a.b)
    public function fieldRead<T>(name:String):T return this.fieldRead(name);
    @:op([]) 
    public function arrayRead(n:Int) return this.arrayRead(n);

    // @:forward doesn't work on static funcs?
    public static function create(type:String) return DDOMCore.create(type);
    public static function getById(id:String) return DDOMCore.getById(id);
    public static function getByType(type:String) return DDOMCore.getByType(type);
    public static function select(selector:String) return DDOMCore.select(selector);
}

// This is the actual data item, DDOM wraps this
@:allow(DDOMCore)
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
