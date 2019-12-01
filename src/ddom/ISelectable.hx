package ddom;

import ddom.Selector;
import ddom.DDOM.DataNode;

/**
 * Use this interface to allow an backing data source to become selectable, an null selector means 'refresh' the DDOM
 */
interface ISelectable {
    public function select(selector:Selector = null):DDOM;
    private function process(selector:Selector):Array<DataNode>;
}
