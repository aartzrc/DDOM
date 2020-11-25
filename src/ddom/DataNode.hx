package ddom;

using LambdaExt;

// This is the actual data item, DDOM wraps this
@:allow(ddom.DDOMInst, ddom.DDOM, ddom.Processor, ddom.SelectorListener)
class DataNode {
    var type:String;
    var fields:Map<String,String> = [];
    var children:Array<DataNode> = [];
    var parents:Array<DataNode> = [];

    var listeners:Array<(Event)->Void> = [];
    
	function new(type:String, fields:Map<String,String>, batch:EventBatch = null) {
        this.type = type;
        if(batch != null) {
            batch.events.push({event: Created(this), listeners: listeners});
        } else {
            fire(Created(this));
        }
        for(f => v in fields) setField(f, v, batch);
    }

    function remove(batch:EventBatch = null) {
        var fireBatch = batch == null;
        if(batch == null) batch = createBatch();
        while(parents.length > 0)
            removeParent(parents[0], batch);
        batch.events.push({event:Removed(this), listeners: listeners});
        if(fireBatch) batch.fire();
    }

    function setField(name:String, val:String, batch:EventBatch = null, force:Bool = false) {
        if(force || fields[name] != val) {
            fields[name] = val;
            if(batch != null) {
                batch.events.push({event:FieldSet(this, name, val), listeners: listeners});
            } else {
                fire(FieldSet(this, name, val));
            }
        }
    }

    inline function getField(name:String) {
        return fields[name];
    }

    function addChild(child:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(force || children.pushUnique(child)) {
            var fireBatch = batch == null;
            if(batch == null) batch = createBatch();
            batch.events.push({event: ChildAdded(this, child), listeners: listeners});
            child.addParent(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function removeChild(child:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(force || children.remove(child)) {
            var fireBatch = batch == null;
            if(batch == null) batch = createBatch();
            batch.events.push({event: ChildRemoved(this, child), listeners: listeners});
            child.removeParent(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function addParent(parent:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(force || parents.pushUnique(parent)) {
            var fireBatch = batch == null;
            if(batch == null) batch = createBatch();
            batch.events.push({event: ParentAdded(this, parent), listeners: listeners});
            parent.addChild(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    function removeParent(parent:DataNode, batch:EventBatch = null, force:Bool = false) {
        if(force || parents.remove(parent)) {
            var fireBatch = batch == null;
            if(batch == null) batch = createBatch();
            batch.events.push({event: ParentRemoved(this, parent), listeners: listeners});
            parent.removeChild(this, batch);
            if(fireBatch) batch.fire();
            return true;
        }
        return false;
    }

    public function on(callback:(Event)->Void) {
        listeners.pushUnique(callback);
        return off.bind(callback);
    }

    public function off(callback:(Event)->Void) {
        listeners.remove(callback);
    }
    
    function fire(event:Event) {
        for(l in listeners) l(event);
    }

    public function toString() {
        var id = fields["id"];
        var fnames = [ for(n in fields.keys()) n ];
        fnames.remove("id");
        var out = fnames.map((n) -> n + ":" + fields[n]).join(",");
        return "{type:" + type + (id != null ? ",id:" + id : "") + (out.length > 0 ? " => " + out : "") + "}";
    }

    static function createBatch():EventBatch {
        var events:Array<{event:Event, listeners:Array<(Event)->Void>}> = [];
        return { 
            events:events,
            fire: () -> {
                for(e in events) {
                    for(l in e.listeners) l(e.event);
                }
            } 
        };
    }

    @:keep
    function hxSerialize(s:haxe.Serializer) {
        s.serialize(type);
        s.serialize(fields);
    }

    @:keep
    function hxUnserialize(u:haxe.Unserializer) {
        type = u.unserialize();
        fields = u.unserialize();
        children = [];
        parents = [];
        listeners = [];
    }
}

enum Event {
    //Batch(events:Array<Event>);
    Created(node:DataNode);
    Removed(node:DataNode);
    ChildAdded(node:DataNode, child:DataNode);
    ChildRemoved(node:DataNode, child:DataNode);
    ParentAdded(node:DataNode, parent:DataNode);
    ParentRemoved(node:DataNode, parent:DataNode);
    FieldSet(node:DataNode, name:String,val:String);
}

typedef EventBatch = {
    events:Array<{event:Event, listeners:Array<(Event)->Void>}>,
    fire:Void -> Void
}