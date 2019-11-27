import ddom.DDOMStore;
import ddom.DDOMSelectorProcessor;

class Main {
	static function main() {
        var store = new DDOMStore();
        var count = 0;
        store.on((e) -> {
            trace(e);
            count++;
            if(count > 2) store.off();
        });
        basicTests(store);
        selectorTests(store);

        //tokenizerTests();
	}

    static function tokenizerTests() {
        var selector:DDOMSelector = "session *:gt(2) > product[name=paper]";
        trace(selector);
        /*trace(DDOMSelectorProcessor.tokenize("session cart:gt(2)"));
        trace(DDOMSelectorProcessor.tokenize("*"));
        trace(DDOMSelectorProcessor.tokenize("*:gt(2)"));*/
    }

    static function selectorTests(store:DDOMStore) {
        // Create some objects
        var session = store.create("session");
        session.id = "home-server";
        var user = store.create("user");
        user.id = "user-with-id";
        session.append(user);
        var cart = store.create("cart");
        user.append(cart);
        var user = store.create("user");
        session.append(user);
        var cart = store.create("cart");
        user.append(cart);
        var user = store.create("user");
        session.append(user);
        user.id = "user-without-cart";
        var cart = store.create("cart");
        cart.id = "cart-without-user";

        // Test recursive loops
        cart.append(session);

        trace(store.select("*")); // Grab everything
        /*trace(store.select("#home-server")); // Get by ID
        trace(store.select("user,cart")); // Get by type
        trace(store.select("user > cart")); // Carts assigned to users
        trace(store.select("cart < user")); // Users assigned to carts
        trace(store.select("*")[1]); // Array access*/
        trace(store.select("*:gt(2)")); // Range select
        trace(store.select("session cart")); // Carts in session
        trace(store.select("user").sub("cart")); // Test sub-select
    }

    static function basicTests(store:DDOMStore) {
        // Create an obj
		var session = store.create("session");
        session.id = "home-server";
        // Get it by id
        var homeSession = store.getById("home-server");
        // Example that all DDOM instances are an array
        for(s in homeSession)
            trace(s.id);
        // Default to index 0 of array on direct field access
        trace(homeSession.id);

        // Create another obj of same type
        store.create("session");
        // Get all objects of this type
        var sessions = store.getByType("session");
        for(s in sessions) trace(s.id);

        // Create a new obj type
        var user = store.create("user");
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
        for(s in sessions)
            s.remove(user);

        // No children
        trace(sessions.children().size());

        // Verify the user is available
        trace(store.getByType("user").size());
        
        // Add back to verify delete works
        homeSession.append(user);

        trace(homeSession.children());
        
        // Fully delete the user
        user.delete();

        // Child user is gone
        trace(homeSession.children());

        // User is not longer available
        trace(store.getByType("user").size());
    }
}
