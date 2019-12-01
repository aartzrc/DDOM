using Lambda;

import ddom.DDOM;
import ddom.Selector;
//import proctrack.ProcTrackSelector;

@:access(ddom.DDOMInst)
class Main {
	static function main() {
        //basicTests();
        //childTests();
        //selectorTests();

        //tokenizerTests();

        //selectorAppendTests();

        //chainTests();

        dbTests();
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

    static function dbTests() {
        /*var dbConn = new ProcTrackSelector();

        // direct query mostly working (lots of custom logic to build that defines parent/child system, but it works...)
        var items = dbConn.select("customer#6 > item");
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

        //dbConn.dispose();
    }

    static function tokenizerTests() {
        /*var selector:Selector = "session *:gt(2) > product[name=paper]";
        trace(selector);*/
        /*var s:Selector = "session#home-server:pos(0)";
        trace(s);*/
        var s:Selector = "> session";
        s = s.concat("> user");
        trace(s);
        s = s.concat(".:pos(0)");
        trace(s);
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
        trace(sessions.children().size());

        // Verify the user is available
        trace(user);

        // But it has no parents
        trace(user.parents());

        cache.append(user);
        trace(cache.children());
        trace(user.parents());
    }
}
