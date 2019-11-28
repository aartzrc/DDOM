package ddom;

import ddom.DDOM;
import ddom.DDOM.DataNode;

/**
 * Provides a standard interface to 'break out' of the DDOM system. Any outside data source can implement the ISelectable and 'inject' itself into DDOM.
 * DDOM only handles what is already in memory, an 'external' ISelectable cannot be injected into the middle of the DDOM system
 */
interface ISelectable {
    public function select(selector:Selector):DDOM;
}
