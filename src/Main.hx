using Lambda;

using ddom.DDOM;
using ddom.SelectorListener;
import ddom.Selector;
import ddom.DataNode;
import ddom.db.DBProcessor;
import ddom.db.DDOMDBProcessor;

@:access(ddom.DDOMInst,ddom.DataNode, ddom.db.DataNode_T)
class Main {
	static function main() {
        //basicTests();
        //childTests();
        //selectorTests();

        tokenizerTests();

        //selectorAppendTests();

        //chainTests();

        //dbTests();

        //castTests();

        //attachDetachTests();

        //ddomDBTests();

        //transactionTests(); // Transactions are beyond the scope of DDOM - each processor has it's own way to create a transaction so it became too complex
	}

    static function ddomDBTests() {
        var ddomConn = new DDOMDBProcessor({user:"om", pass:"om", host:"127.0.0.1", database:"ddom"});

        // Saving data must be more 'precise' - all changes get wrapped in an EventBatch and saved in a transaction
        // It's easy to forget to append 'batch' to all the calls, any easy way to do a global batch?
        // A batch must be used to maintain event order (timestamp isn't precise enough to re-create the order)
        // DataNode would need to be extended/overridden? done via DataNode_T - not great but it'll work to keep things consistent
        /*DataNode_T.startTransaction(ddomConn);
        var user = new DataNode_T("user");
        user.setField("name", "new user");
        var session = new DataNode_T("session");
        session.addParent(user);
        session.setField("startTime", Std.string(Sys.time()));
        DataNode_T.commitTransaction();*/

        trace(ddomConn.select("user#16 > session < *"));

        //trace(user);

        //user.remove(batch);
        //trace(batch);
        //ddomConn.processEventBatch(batch);

        // DataNodes store all 'events', this can be used to create a transaction after all changes are made
        // ddomConn.cache contains all DataNodes that had some interaction

        // for new data, does it work to create an in-memory DDOM then 'add' to DDOMDBProcessor? 
        // it would add all DataNodes to the cache which would make them part of the current transaction, a 'flush' call would send them to the database
        // once some data is in, most new data would be 'appended'

        // DDOMDBProcessor needs to overwrite the 'id' field - ignore if a user has supplied an id? better to try parsing as int and load original node, then merge all fields to create the event log

        // ISelectable: DDOMs can be 'selected'
        // IProcessor: Selectors can be 'processed' and updates 'listened' to
        // IStore: DDOMs can be 'added', changes viewed as a 'transaction', and changes saved via 'commit'
        // IStore is just a DDOM 'cache' ? yes, and that can be used as a generic tool to build up a transaction
        // Then the DB backing stores can have a method to take an IStore and save it via a 'commit' call or something - this would be application specific

        // IStore seems like a good idea
        // Data convert/transfer for example: a source DB gets 'selected' from, a DDOM results. 'add' to an IStore and all create/etc events come through with the DataNodes. 'commit' the IStore to a new database and it can re-create the operations for storing the DataNodes
        // Load data/modify/commit example: 'select' some data, store the timestamp, make some changes, 'commit' back to DB with only changes after the timestamp. only update events will be logged.
        // Some events would be exceptions, such as a 'create' event even though a datanode already exists

        // A client would use the same system: create DDOMs, move stuff around/etc. 'add' to a client-side IStore, then 'commit' to the server source.
        // 'commit' could respond via callback to notify that data has been saved and ids generated etc. original datanodes would have been updated by the time the callback is executed.

        // Does IStore need to isolate the nodes?
        // not on server because each pass would be single threaded and stateless, no other events/threads would be modifying things.
        // on the client it could happen that a user modifies some data, then the server sends and update which reverts the data because the user modification is committed
        // if client commits are single-thread and small this isn't a problem, but an IStore might be used for a dialog instance where all changes are tracked and only committed at the end - this would require a 'clone' of the origin DataNodes
        // how about this: when a server poll comes back with update data, compare the previous response timestamp to any change events, if events have occurred between the last pass and current pass, those events are 'correct' for the current client
        // no.. there's a potential for the client to get stuck in a state that will never be correct relative to the server. if data is never 'committed' it will always appear different on the client compared to the actual server data
        // has to be a transaction system that clones the data nodes
        // the transaction would mark it's creation time, and when nodes get added...

        // this seems like the best option so far:
        // make a transaction that is 'ISelectable', provide it with a starting DDOM?
        // only the 'selected' data would become isolated, so multiple selects would be required to build up the cloned data
        // the cloned/selected items would point back to their parents/children directly so care would need to be taken to not interact with the DataNodes incorrectly
        // an extension method on DDOM would look good. like DDOM.select("> customer#2 > items").beginTransaction();
        // beginTransaction would return a new DDOM with '_nodes' being isolated so modifications could happen.
        // a select on the original transaction would need to continue the isolation process, could the transaction become the processor for all future selects?
        // maybe that is all beginTransaction does, simply wrap the original DDOM processor in a new processor that caches and isolates data
        // any backing processor (DB/etc) would automatically get called, but then pass-thru data becomes part of the transaction. DataNodes get cloned, but stripped of all events so only events within the transaction scope are logged.
        // cloned nodes would need pointers back to origin nodes so a commit could occur even without id/etc mappings (like client-side only data management)
        // a database store would take the transaction and pull all events/updates and send to the DB

        // during a save/write operation, the DB would overwrite any 'id' field. as long as the data goes back to the client to keep things in sync this should be ok.

        // direct changes (outside of a transaction) should also be monitored on the client side, so simple updates are quick
        // more complex updates should be handled within a transaction
        // all updates could be handled within a transaction on the server side

        // 12/24/2019: the 'isolate on select' transaction doesn't work once any structure changes happen because the processor would need to know all nodes in the select chain to work properly
        // A DB processor could possibly create a 'transaction' using this method, but an in-memory transaction quickly gets too difficult
        // Rather than use transactions at all, just store the changes that need to occur and wrap them all in an EventBatch which simulates the transaction
        // in the end - NO TRANSACTION SYSTEM
        
        ddomConn.dispose();
    }

    static function attachDetachTests() {
        var cache = DDOM.create("cache");
        var u1 = DDOM.create("user");
        u1.name = "person a";
        cache.append(u1);
        var u2 = DDOM.create("user");
        u2.name = "person b";
        cache.append(u2);

        var d = cache.select("> user");
        d.attach((ddom) -> trace(ddom));
        d.name = "name changed"; // This should be ignored by the listener
        var u3 = DDOM.create("user");
        trace("append");
        cache.append(u3); // This should result in an update
    }

    static function castTests() {
        var cache = DDOM.create("cache");
        var u1 = DDOM.create("user");
        u1.name = "person a";
        cache.append(u1);
        var u2 = DDOM.create("user");
        u2.name = "person b";
        cache.append(u2);

        var users:Array<User> = cache.select("> user").nodesOfType("user");
        for(user in users) {
            trace(user.name);
            user.onChange("name", (newName) -> trace(newName));
            user.name = "new guy?";
        }

        trace(cache.select("> user"));
    }

    static function childTests() {
        var cache = DDOM.create("cache");
        var session = DDOM.create("session");
        var user = DDOM.create("user");
        cache = cache.append(session);
        session.append(user);

        var sessions = cache.children("session");
        trace(sessions);
        var users = sessions.children();
        trace(users);
    }

    static function chainTests() {
        var customer = DDOM.create("customer");
        customer.id = "randomCustomer";
        var item = DDOM.create("item");
        item.id = "item1";
        customer.append(item);
        var item = DDOM.create("item");
        item.id = "item2";
        customer.append(item);
        var prod = DDOM.create("product");
        item.append(prod);

        var s1 = customer.select("> item");
        trace(s1);
        var s2 = s1.select("> *");
        trace(s2);
    }

    static function selectorConcatTests() {
        var sel:Selector = "customer#2,customer#3";
        trace(sel);
        var sel2 = sel.concat("> item");
        trace(sel2);
        var sel3 = sel.concat("> item:pos(2)");
        trace(sel3);
        var sel4 = sel2.concat("> *:pos(2),> item");
        trace(sel4);
    }

    @:access(ddom.DataNode)
    static function dbTests() {
        var typeMap:Array<TypeMap> = [
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
        ];

        var dbConn = new DBProcessor({user:"bgp", pass:"bgp", host:"127.0.0.1", database:"proctrack"}, typeMap, false);

        //var items = dbConn.select("customer#60 > item, customer#61");
        //trace(items.select(".customer")); // This doesn't work yet
        var retail = dbConn.select("customer[name=Retail]");
        var retailItems = retail.select("> item:orderby(cdate)");
        var last5 = retailItems.select(".:gt(" + (retailItems.size()-5) + ")");
        var last5history = last5.select("history");
        for(i in last5history) {
            trace(i);
        }

        var lastHistory = retail.select("history:orderby(udate)");
        for(i in 0 ... 5) trace(lastHistory[i]);
        //var history = customers.select("history");
        //trace(history);
        
        /*for(c in customersDDOM) {
            trace(c.name);
        }*/
        var items = dbConn.select("item");
        trace(items.size());
        var customers = items.select("< *");

        trace(customers.size());
        /*for(c in customers) {
            var ddi:DDOMInst = c;
            trace(ddi.nodes[0].type + " : " + c.name);
        }*/
        
        /*var customer = items.toCustomerList();
        trace(customer);*/

        //trace(items.parents());


        /*var items = dbConn.select("item[approx_value=160]");
        trace(items.size());
        for(i in items) {
            trace(i);
        }*/

        // direct query mostly working (lots of custom logic to build that defines parent/child system, but it works...)
        /*var items = dbConn.select("customer#6 > item");
        for(i in items) {
            trace(i.orderitem + " : " + i.desc);
        }*/

        // TODO: get re-select working - looks like the full token chain needs to be created and passed down?
        //var customer2 = dbConn.select("customer#6");
        //trace(customer2.id);
        //trace(customer2.name);

        /*var items = customer2.select("> item");
        for(i in items) {
            trace(i.orderitem + " : " + i.desc);
        }*/

        /*var customers = dbConn.select("customer#2,customer#3");
        trace(customers);

        var items = customer2.select("> item");
        trace(items);*/

        dbConn.dispose();
    }

    static function tokenizerTests() {
        var s:Selector = "customer[name=jon doe]";
        trace(s);


        /*var selector:Selector = "session *:gt(2) > product[name=paper]";
        trace(selector);*/
        /*var s:Selector = "session#home-server:pos(0)";
        trace(s);*/
        /*var s:Selector = "> session";
        s = s.concat("> user");
        trace(s);
        s = s.concat(".:pos(0)");
        trace(s);*/
        //var selector:Selector = "session#2 > customer[lastname=artz][firstname!=andy]:orderby(firstname):pos(0)";
        //trace(selector);
        /*trace(DDOMSelectorProcessor.tokenize("session cart:gt(2)"));
        trace(DDOMSelectorProcessor.tokenize("*"));
        trace(DDOMSelectorProcessor.tokenize("*:gt(2)"));*/
    }

    static function selectorTests() {
        // Create some objects
        var session = DDOM.create("session");
        session.id = "home-server";
        var user = DDOM.create("user");
        user.id = "user-with-id";
        session.append(user);
        var cart = DDOM.create("cart");
        user.append(cart);
        var user = DDOM.create("user");
        session.append(user);
        var cart = DDOM.create("cart");
        user.append(cart);
        var user = DDOM.create("user");
        session.append(user);
        user.id = "user-without-cart";
        var cart = DDOM.create("cart");
        cart.id = "cart-without-user";

        // Test recursive loops
        cart.append(session);

        //trace(session.select("*")); // Grab everything
        //trace(session.select("#home-server")); // Get by ID
        //trace(session.children("user"));
        //trace(session.select("> user")); // 'user' Children
        //trace(session.select("> user,> cart")); // Get children type - should be all users, no carts
        
        
        
        
        // TODO: descendants call is not working
        //trace(session.select("* cart")); // All carts
        //trace(session.select("* cart < user")); // Users assigned to carts
        //trace(session[1]); // Array access
        //trace(session.select("*:lt(2)")); // Range select
        //trace(session.select("session cart")); // Carts in session
        trace(session.select("user")); // This selects 'user's from the session DDOM (no users, so this is empty)
        trace(session.select("> user")); // Select 'user' children
        trace(session.select("> user").select("> cart")); // Test sub-select
        trace(session.select("> user > cart"));
    }

    static function basicTests() {
        // Create an obj
		var session = DDOM.create("session");
        trace(session);
        /*var t:DDOMInst = cast session; // Cast to DDOMInst to break out of DDOM field read/write!
        trace(t._nodes);
        trace(t.nodes);*/
        session.id = "home-server";
        var s2 = session.select();
        trace(s2);
        // Get it by id
        var homeSession = session.select("#home-server");
        trace(homeSession);

        var notFound = session.select("#badid");
        trace(notFound);

        // Example that all DDOM instances are an array
        for(s in homeSession)
            trace(s.id);
        // Default to index 0 of array on direct field access
        trace(homeSession.id);

        // Create a 'root' DDOM for cache usage
        var cache = DDOM.create("cache");
        // Create another obj of same type
        var session2 = DDOM.create("session");
        // Add both sessions to cache
        //cache.append(session).append(session2);
        trace(cache.append(session).append(session2));
        // Get all objects of this type
        var sessions = cache.children("session");
        trace(sessions);
        for(s in sessions) trace(s);

        // Create a new obj type
        var user = DDOM.create("user");
        // This will append to both session instances
        sessions = sessions.append(user);

        // Only one child will come back even though 'sessions' is two instances
        var ddi:DDOMInst = cast sessions;
        trace(ddi.selector);
        var ddi:DDOMInst = cast sessions.children();
        trace(ddi.selector);
        for(c in sessions.children())
            trace(c);

        // Descendants check
        trace(cache.select("* user"));

        // length is a property of the instance, not the length of DDOM
        trace(sessions.length);
        // use size() instead
        trace(sessions.children().size());

        // detach the user from the sessions
        user.remove();

        // No children
        trace(sessions.children());

        // Verify the user is available
        trace(user);

        // But it has no parents
        trace(user.parents());

        cache.append(user);
        trace(cache.children());
        trace(user.parents());
    }
}

@:access(ddom.DataNode)
abstract User(DataNode) from DataNode {
    public var name(get,set):String;

    function get_name() {
        return this.getField("name");
    }

    function set_name(name:String) {
        this.setField("name", name);
        return name;
    }

    public function onChange(field:String, callback:(String)->Void):()->Void {
        function handleEvent(e) {
            switch(e) {
                case FieldSet(node, name, val):
                    if(name == field) callback(val);
                case _:
                    // Not handled here
            }
        }
        this.on(handleEvent);
        return this.off.bind(handleEvent);
    }
}