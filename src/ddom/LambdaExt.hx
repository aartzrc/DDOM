package ddom;

class LambdaExt {
    /**
     * Merge newArray into currentArray
     * This call will modify currentArray during the update, array index is not matched and positions may change, currentArray contents will match newArray contents when completed
     * @param currentArray
     * @param newArray
     * @param removeCallback
     * @param addCallback
     * @return Bool
     */
    public static function merge<T>(currentArray:Array<T>, newArray:Array<T>, ?removeCallback:T -> Void, ?addCallback:T -> Void):Bool {
        var removeList = currentArray.filter((v) -> newArray.indexOf(v) == -1);
        var addList = newArray.filter((v) -> currentArray.indexOf(v) == -1);

        if(removeList.length > 0 || addList.length > 0) { // Any changes?
            for(v in removeList) {
                currentArray.remove(v);
                if(removeCallback != null) removeCallback(v);
            }
            for(v in addList) {
                currentArray.push(v);
                if(addCallback != null) addCallback(v);
            }

            return true;
        }

        return false;
    }

    /**
     * Merge newArray into currentArray
     * This call will modify currentArray during the update, array index IS matched and positions of newArray will stay the same, currentArray will match newArray index and contents when completed
     * @param currentArray
     * @param newArray
     * @param removeCallback
     * @param addCallback
     * @return Bool
     */
    public static function mergei<T>(currentArray:Array<T>, newArray:Array<T>, ?setCallback:Int -> T -> Void, ?removeCallback:Int -> T -> Void, ?appendCallback:Int -> T -> Void):Bool {
        var changed = false;

        if(newArray.length < currentArray.length) { // Trim off end of array to match newArray.length and remove those items
            var removed = currentArray.splice(newArray.length, currentArray.length);
            if(removeCallback != null && removed.length > 0) {
                var i = newArray.length;
                for(t in removed) {
                    removeCallback(i, t); // Remove previous
                    i++;
                }
            }
            changed = true;
        }

        for(i in 0 ... newArray.length) {
            var curItem = currentArray.length > i ? currentArray[i] : null;
            var newItem = newArray.length > i ? newArray[i] : null;
            // Check for a changed item
            if(curItem != newItem) {
                changed = true;
                if(currentArray.length <= i) {
                    if(appendCallback != null) appendCallback(i, newItem);
                    currentArray.push(newItem); // Add new value
                } else {
                    if(setCallback != null) setCallback(i, newItem);
                    currentArray[i] = newItem; // Set new value
                }
            }
        }

        return changed;
    }

    public static function first<T>(array:Array<T>, func:T -> Bool) {
        for (i in 0...array.length) {
            if(func(array[i])) return i;
        }
        return -1;
    }

    /**
     * Shallow compare 2 arrays, must have same values in the same order!
     * @param l1 
     * @param l2 
     */
    public static function hasSameElements<T>(a:Array<T>, b:Array<T>):Bool {
        if(a.length != b.length) return false;
        //for(i in a) if(b.indexOf(i) == -1) return false;
        for(pos in 0 ... a.length) if(b[pos] != a[pos]) return false;
        return true;
    }

    /**
     * Shallow compare 2 arrays, can be in any order
     * @param l1 
     * @param l2 
     */
    public static function hasSameElementsUnordered<T>(a:Array<T>, b:Array<T>):Bool {
        if(a.length != b.length) return false;
        for(i in a) if(b.indexOf(i) == -1) return false;
        return true;
    }

    public static function mapFind<K,V>(map:Map<K,V>, val:V):K {
        for(k in map.keys())
            if(map[k] == val) return k;
        return null;
    }

    public static function unique<T>(a:Array<T>):Array<T> {
        var res:Array<T> = [];

        for(i in a)
            if(null != i && res.indexOf(i) == -1)
                res.push(i);

        return res;
    }

    public static function uniqueNoAlloc<T>(a:Array<T>):Array<T> {
        var i = 0;
        while(i < a.length) {
            var v = a[i];
            if(a.indexOf(v) != a.lastIndexOf(v)) a.remove(v);
                else i++;
        }
        return a;
    }

    /**
     * Append items in l2 to l1 that are not already found in l1, modifies l1 in place
     * @param l 
     * @param l2 
     */
    public static function appendUnique<T>(l1:Array<T>, l2:Iterable<T>):Void {
        for(i2 in l2)
            pushUnique(l1, i2);
    }

    public static inline function pushUnique<T>(a:Array<T>, v:T):Bool {
        if(a.indexOf(v) == -1) {
            a.push(v);
            return true;
        }
        return false;
    }

    public static function isNullOrWhitespace(s:String) {
        if(s == null) return true;
        if(StringTools.trim(s).length == 0) return true;
        return false;
    }
}