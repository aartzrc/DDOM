package ddom;

import ddom.Selector;
import ddom.DDOM.DataNode;

/**
 * Use this interface to allow a backing data source to become selectable, a null selector means 'refresh' the DDOM
 */
interface ISelectable {
    public function select(selector:Selector = null):DDOM;
    private function listen(selector:Selector, callback:(ddom:DDOM) -> Void):()->Void;
    private function process(selector:Selector):Array<DataNode>;
}
