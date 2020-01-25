package ddom;

using Lambda;

@:forward(detach, keys, set)
abstract DetachManager(DetachBatch) from DetachBatch to DetachBatch {
    public function new() {
        return new DetachBatch();
    }

    @:op(A += B)
    public static function pushDetachFunc(lhs:DetachManager, rhs:()->Void):DetachManager {
        (lhs:DetachBatch).push(rhs);
        return lhs;
    }
}

class DetachBatch {
#if debug
    public static var attachTotal(get,null):Int;
    static var managers:Array<DetachBatch> = [];

    static function get_attachTotal() {
        var total = 0;
        for(m in managers) {
            total += m.detachFuncs.length;
            if(m.detachMap != null)
                total += m.detachMap.count();
        }
        return total;
    }

    public static function traceLiveManagers() {
        trace(managers.filter((m) -> m.detachFuncs.length > 0));
    }
#end

    var detachFuncs = new Array<()->Void>();
    var detachMap:Map<String, ()->Void>;

    public var length(get, never):Int;

    public function new() {
    #if debug
        helpers.push(this);
    #end
    }

    public inline function push(fnc:()->Void) {
		detachFuncs.push(fnc);
    }
    
    public inline function detach() {
		for (f in detachFuncs) f();
		detachFuncs = [];
        if(detachMap != null) {
            for (f in detachMap) f();
            detachMap = null;
        }
	}

	function get_length() {
		return detachFuncs.length + ((detachMap == null) ? 0 : detachMap.count());
    }
    
    @:arrayAccess
	public inline function get(key:String) {
        if(detachMap == null) return null;
		return detachMap.get(key);
	}

	@:arrayAccess
	public inline function set(k:String, v:()->Void):()->Void {
        if(detachMap == null)
            detachMap = new Map<String, ()->Void>();
		detachMap.set(k, v);
		return v;
    }
    
    public inline function remove(k:String):Bool {
		if(detachMap == null) return false;
		var detachFunc = detachMap[k];
		if(detachFunc != null) detachFunc();
		return detachMap.remove(k);
	}

	public inline function exists(k:String):Bool {
		if(detachMap == null) return false;
		return detachMap.exists(k);
	}

	public inline function keys():Iterator<String> {
		if(detachMap == null) return { hasNext: () -> false, next: () -> null };
		return detachMap.keys();
	}
}
