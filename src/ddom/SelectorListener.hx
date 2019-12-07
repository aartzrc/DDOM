package ddom;

import ddom.DDOM;
import ddom.Processor.IProcessor;

class SelectorListener {
    /**
     * Begin 'listening' to a DDOM, this will only respond with structure changes, field value changes that do not effect the structure are ignored
     * @param ddom 
     * @param callback 
     * @return ->Void):()->Void
     */
    public static function attach(ddom:DDOMInst, callback:(DDOM)->Void):()->Void {
        var l:Listener = {
            ddom: ddom,
            callback: callback,
            lastResult: ddom.nodes,
            lastEvent: null,
            detachFuncs: []
        };

        // Recurse through all processor trees and attach to all DataNode events
        attachToProcessors(l);

        // Return the current result immediately
        l.callback(ddom);

        return detach.bind(l);
    }

    static function detach(l:Listener) {
        for(f in l.detachFuncs) f();
        l.detachFuncs = [];
    }

    static function attachToProcessors(l:Listener) {
        var handler = handleEvent.bind(l);
        function recurseNode(n:DataNode) {
            if(!l.detachFuncs.exists(n)) {
                n.on(handler);
                l.detachFuncs.set(n, n.off.bind(handler));
                for(nn in n.children.concat(n.parents))
                    recurseNode(nn);
            }
        }
        function attachToProcessor(p:IProcessor) {
            for(n in p.rootNodes())
                recurseNode(n);
        }
        for(p in l.ddom.processors)
            attachToProcessor(p);
    }

    static function handleEvent(l:Listener, e:Event) {
        if(l.lastEvent == e) return; // Ignore repeats - this can happen during a child add/remove, the parent and child will both fire the same event batch
        
        l.lastEvent = e;
        trace(e);

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
            detach(l);
            attachToProcessors(l);
        }

        // Rerun selector and determine if any output changes have occurred
        var newDDOM = l.ddom.select();
        var newNodes = cast(newDDOM, DDOMInst).nodes;
        if(newNodes.length != l.lastResult.length) {
            l.lastResult = newNodes;
            l.callback(newDDOM);
        } else {
            for(i in 0 ... newNodes.length) {
                if(l.lastResult[i] != newNodes[i]) {
                    l.lastResult = newNodes;
                    l.callback(newDDOM);
                    return;
                }
            }
        }
    }
}

typedef Listener = {
    ddom:DDOMInst,
    callback:(DDOM)->Void,
    lastResult:Array<DataNode>,
    lastEvent:Event,
    detachFuncs:Map<DataNode, ()->Void>
}