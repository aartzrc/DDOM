package ddom;

import ddom.DDOM.DDOMInst;
using ddom.LambdaExt;

import ddom.Selector;
import ddom.Processor.IProcessor;

class Transaction extends Processor implements IProcessor implements ISelectable {
    var selector:Selector; // the 'default' selector, pulled from the passed DDOM instance
    var processors:Array<IProcessor>; // processors that will be called to generate the nodes array

    function new(processors:Array<IProcessor>, selector:Selector) {
        this.processors = processors;
    }

    public function select(selector:Selector = null):DDOM {
        
        // TODO: this would run the selector (or default selector) and isolate/clone the nodes into a new DDOM inst and return that
    }

    /**
     * Start a new transaction scope using DDOM data - note that only DDOM operations should be used after this, any direct DataNode manipulations can corrupt the transaction
     * @param ddom 
     */
    public static function beginTransaction(ddom:DDOM):Transaction {
        var inst:DDOMInst = ddom;
        return new Transaction(inst.processors, inst.selector);
    }

    public function toString() {
        return "TODO: this should show 'events' that have occurred within the transaction";
    }
}
