class Main {
	static function main() {
        //basicTests();
        selectorTests();
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

        trace(DDOM.select("*")); // Grab everything
        /*trace(DDOM.select("#home-server")); // Get by ID
        trace(DDOM.select("user,cart")); // Get by type
        trace(DDOM.select("user > cart")); // Carts assigned to users
        trace(DDOM.select("cart < user")); // Users assigned to carts
        trace(DDOM.select("*")[1]); // Array access*/
        trace(DDOM.select("*:gt(2)")); // Range select
        trace(DDOM.select("session cart")); // Carts in session
    }

    static function basicTests() {
        // Create an obj
		var session = DDOM.create("session");
        session.id = "home-server";
        // Get it by id
        var homeSession = DDOM.getById("home-server");
        // Example that all DDOM instances are an array
        for(s in homeSession)
            trace(s.id);
        // Default to index 0 of array on direct field access
        trace(homeSession.id);

        // Create another obj of same type
        DDOM.create("session");
        // Get all objects of this type
        var sessions = DDOM.getByType("session");
        for(s in sessions) trace(s.id);

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
        for(s in sessions)
            s.remove(user);

        // No children
        trace(sessions.children().size());

        // Verify the user is available
        trace(DDOM.getByType("user").size());
        
        // Add back to verify delete works
        homeSession.append(user);

        trace(homeSession.children());
        
        // Fully delete the user
        user.delete();

        // Child user is gone
        trace(homeSession.children());

        // User is not longer available
        trace(DDOM.getByType("user").size());
    }
}
