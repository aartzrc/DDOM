import ddom.DDOM;
import ddom.Selector;

@:access(ddom.DDOMInst)
class Main {
	static function main() {
        //basicTests();
        selectorTests();

        //tokenizerTests();
	}

    static function tokenizerTests() {
        var selector:Selector = "session *:gt(2) > product[name=paper]";
        trace(selector);
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
        trace(session.select("*"));
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
        cache.append(session).append(session2);
        // Get all objects of this type
        var sessions = cache.children().select("session");
        for(s in sessions) trace(s);

        // Create a new obj type
        var user = DDOM.create("user");
        // This will append to both session instances
        sessions.append(user);

        // Only one child will come back even though 'sessions' is two instances
        for(c in sessions.children())
            trace(c);

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
    }
}
