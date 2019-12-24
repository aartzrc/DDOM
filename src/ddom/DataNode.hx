package ddom;

using ddom.LambdaExt;

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
        while(parents.length > 0)
            removeParent(parents[0], batch);
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