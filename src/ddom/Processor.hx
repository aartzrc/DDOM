package ddom;

using Lambda;
import ddom.Selector;
import ddom.DDOM;

@:allow(ddom.SelectorListener)
interface IProcessor {
    private function process(selector:Selector):Array<DataNode>;
    private function rootNodes():Array<DataNode>;
    private function listen(select:Selector, callback:()->Void):()->Void;
}
    
/**
 * Base Processor, extend this to create a custom processor
 */
class Processor {
    // Cache + listen/event callback system
    var cacheMap:Map<String, Array<DataNode>> = null;
    var listenerMap:Map<String, ListenerGroup> = null;

    function process(selector:Selector):Array<DataNode> {
        var cache = getCache(selector);
        if(cache != null) return cache;

        var results:Array<DataNode> = [];

        var groups:Array<SelectorGroup> = selector;
        if(groups.length == 0) return rootNodes(); // Empty selector returns all data
        for(group in groups)
            for(n in processGroup(group)) // Process each group/batch of tokens
                if(results.indexOf(n) == -1) results.push(n); // Merge results of all selector groups

        cacheMap.set(selector, results);

        return results;
    }

    function rootNodes():Array<DataNode> {
        return [];
    }

    function getCache(selStr:String):Array<DataNode> {
        if(cacheMap == null) {
            cacheMap = [];
            attachNodes(); // Verify node change events are handled, cache is reset on all changes
        }
        if(!cacheMap.exists(selStr)) cacheMap.set(selStr, null);
        return cacheMap[selStr];
    }

    function listen(selector:Selector, callback:()->Void):()->Void {
        var selStr:String = selector;
        if(listenerMap == null) listenerMap = [];
        if(!listenerMap.exists(selStr)) listenerMap.set(selStr, {callbacks:[],lastResult:null});
        var l = listenerMap[selStr];
        l.callbacks.push(callback);
        // This is a bit tricky, to avoid a redundant update we assume a select+process has already happened and set lastResult to the cache
        if(l.lastResult == null) l.lastResult = process(selector);
        return () -> {
            l.callbacks.remove(callback);
            if(l.callbacks.length == 0) {
                listenerMap.remove(selStr);
                if(!listenerMap.keys().hasNext())
                    listenerMap = null;
            }
        }
    }

    var nodeDetachFuncs:Map<DataNode, ()->Void>;
    function attachNodes() {
        if(nodeDetachFuncs != null) return;
        nodeDetachFuncs = [];
        function recurseNode(n:DataNode) {
            if(!nodeDetachFuncs.exists(n)) {
                n.on(handleEvent);
                nodeDetachFuncs.set(n, n.off.bind(handleEvent));
                for(nn in n.children.concat(n.parents))
                    recurseNode(nn);
            }
        }
        for(n in rootNodes())
            recurseNode(n);
    }

    function detachNodes() {
        for(f in nodeDetachFuncs) f();
        nodeDetachFuncs = null;
    }

    function handleEvent(e:Event) {
        cacheMap = null; // Reset cache

        var structChanges = false;
        function checkForStructChanges(e:Event) {
            if(structChanges) return; // Change already detected, ignore further tests
            switch(e) {
                case Created(_) | FieldSet(_): // Ignore
                case ChildAdded(_) | ChildRemoved(_) | ParentAdded(_) | ParentRemoved(_):
                    structChanges = true;
                case Batch(events):
                    for(e in events) checkForStructChanges(e);
            }
        }

        checkForStructChanges(e);

        if(structChanges) {
            // Detach/reattach all listeners
            // TODO: make this more efficient, it is crazy to rebuild the whole listener chain each time - just getting it working for now
            detachNodes();
            attachNodes();
        }

        // Rerun listening selectors and determine if any output changes have occurred
        for(s => l in listenerMap) {
            if(l.callbacks.length > 0) {
                var newNodes = process(s);
                var changed = l.lastResult == null || newNodes.length != l.lastResult.length;
                if(!changed) {
                    var i = 0;
                    while(!changed && i < newNodes.length) {
                        changed = l.lastResult[i] != newNodes[i];
                        i++;
                    }
                }
                if(changed) {
                    l.lastResult = newNodes;
                    for(c in l.callbacks) c();
                }
            }
        }
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

typedef ListenerGroup = {
    callbacks:Array<()->Void>,
    lastResult:Array<DataNode>
}