package examples;

import ddom.db.DDOMDBProcessor;
using ddom.SelectorListener;
using ddom.DDOM;
import ddom.DataNode;

@:access(ddom.DataNode)
class DBTest {
    public static function main() {
        var db = new ddom.db.DBProcessor({user:"ddom", pass:"ddom", host:"127.0.0.1", database:"proctrack"}, 
            [
                {
                    type:"customer",
                    table:"customer",
                    idCol:"id",
                    children: [{
                        type:"item",
                        table:"item",
                        parentIdCol:"customer_id",
                        childIdCol: "id"
                    }]
                },
                {
                    type:"item",
                    table:"item",
                    idCol:"id",
                    children: [{
                        type:"history",
                        table:"item_history",
                        parentIdCol:"item_id"
                    }]
                },
                {
                    type:"history",
                    table:"item_history"
                }
            ]);
        
        // Get a DDOM instance associated with a selector string - this does not actually run a query!
        var mythCustomers = db.select('customer[name*=myth]'); // Find a customer by name
        var mythItems = mythCustomers.select(' > item'); // Get all items for the customer (chaining selector)
        trace(mythItems); // Trace out query results, this runs the query and iterates over output
        trace(mythItems.size()); // 'length' can be a property of the result so size() function is used to determine length/count of results
        for(c in mythCustomers) trace(c); // Iterate over result set

        var idCustomer = db.select('customer#${mythCustomers.id}'); // Use the first result 'id' value as a new selector, this will improve performance as selectors are chained
        trace(idCustomer);

        var mythAll = db.select('*[name*=Myth]'); // Search ALL tables
        trace(mythAll);

        var mythAll = db.select('*[desc*=myth]'); // Search ALL tables, special MySql keyword used 'desc' but it is escaped during query
        trace(mythAll.desc); // If no results, this will be null but not throw exception

        trace(db.log); // View queries and filters during processing

        // DB Processor does not always have all data available in memory, so the listener system does not work yet (in-memory DDOM works)
        mythCustomers.attach((mythChanges) -> {
            trace(mythChanges);
        }, false);
        mythCustomers.name = "newly mythic";

        // Create an EventBatch (transaction) and perform a database change
        var editBatch = DataNode.createBatch();
        var mythCustomer = mythCustomers.nodesOfType("customer")[0];
        mythCustomer.setField("name", "mythically renamed", editBatch);
        trace(editBatch); // Change event is stored, ready to be committed
        // DBProcessor is not ready to handle commits, see DDOMDBProcessor.processEventBatch for implementation example
    }
}