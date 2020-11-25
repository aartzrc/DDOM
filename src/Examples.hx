import haxe.macro.Context;
using Lambda;
using LambdaExt;

using ddom.DDOM;
using ddom.SelectorListener;
import ddom.Selector;
import ddom.DataNode;
import ddom.Processor;
using User;

@:access(ddom.DDOMInst,ddom.DataNode, ddom.db.DataNode_T)
class Examples {
	static function main() {
        // These aren't really tests yet, just sample code

        //basicTests();

        //childTests();

        //selectorTests();

        //chainTests();

        //castTests();

        //attachDetachTests();

        readmeSample();

    }
    
    static function readmeSample() {
        var session = DDOM.create("session"); // DDOM.create will return a DDOM using the default `Processor` with a single root `DataNode` of the specified type
        session.id = "home-server"; // `id` is special, and can be used for lookups
        var homeSession = session.select("#home-server"); // Search for any node with the id of 'home-server' and return a new DDOM
        trace(homeSession); // {*#home-server} = [{type:session,id:home-server}]
        var notFound = session.select("#badid"); // Search for #badid - this returns an empty result
        trace(notFound); // {*#badid} = []

        // Add a 'user' with a 'cart' as a child of the 'session'
        var user = DDOM.create("user");
        user.name = "new person";
        var cart = DDOM.create("cart");
        user.append(cart);
        session.append(user);

        // Find all carts - {* cart} means 'select all at current level, then find all descendants of type cart'
        trace(session.select("* cart")); // {* cart} = [{type:cart}]
        
        // Select children of type 'user' from the current level (session)
        var users = session.select("> user");
        trace(users); // {* > user} = [{type:user => name:new person}]
        // Chain a new selector, the previous selector and processor are remembered
        trace(users.select("> cart")); // {* > user > cart} = [{type:cart}]

        var userDataNode = users.nodesOfType("user")[0]; // Get the first instance of a 'user' DataNode
        var detachFunc = userDataNode.on((e) -> { trace(e); }); // On change event: FieldSet({type:user => name:new person,email:someone@email.com},email,someone@email.com)
        users.email = "someone@email.com"; // Results in a trace event
        detachFunc(); // Remove the listener
        users.email = "newemail@email.com"; // Not traced

        // Type safety
        var u = User.create(1234, "person a");
        trace(u);
        session.append(u);
        trace(users); // Note that the previous 'users' DDOM instance retains the original data set - this is intentional
        trace(users.select()); // This will return the new data set
    }

    static function attachDetachTests() {
        var session = DDOM.create("session");
        var d = session.select("> user");
        d.attach((ddom) -> trace(ddom));
        session.append(DDOM.create("user")); // This results in an update
        d.name = "name changed"; // This is ignored by the listener - only structure changes are handled
    }

    static function castTests() {
        var cache = DDOM.create("cache");

        // Listen for users being added to the cache
        cache.children(User.type).attach((cacheUpdate) -> {
            trace(cacheUpdate);
        }, false);

        var u1 = User.create(1234, "person a");
        cache.append(u1);

        var u2 = DDOM.create(User.type);
        u2.name = "person b";
        u2.id = u2.name;
        cache.append(u2);

        var users = cache.select(">").users();
        for(user in users) {
            user.onChange("name", (newName) -> trace(user + " : " + newName)); // Listen to the user "name" property change
            //user.name = "new guy?";
        }
        cache.select(">").name = "new guy?"; // Update all children at once

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

        trace(session.select()); // Grab everything at the current DDOM level
        //trace(session.select("#home-server")); // Get by ID
        trace(session.children());
        //trace(session.select("> user")); // 'user' Children
        //trace(session.select("> user,> cart")); // Get children type - should be all users, no carts
        
        
        
        
        // TODO: descendants call is not working
        //trace(session.select("* cart")); // All carts
        //trace(session.select("* cart < user")); // Users assigned to carts
        //trace(session[1]); // Array access
        //trace(session.select("*:lt(2)")); // Range select
        //trace(session.select("session cart")); // Carts in session
        trace(session.select("user")); // This selects 'user's from the root session DDOM - no users at the root level
        trace(session.select("> user")); // Select 'user' children
        trace(session.select("> user").select("> cart")); // Test sub-select
        trace(session.select("> user > cart"));
    }

    //@:access(ddom.Processor)
    static function basicTests() {
        // Create a new DDOM with a single 'session' node as the root
		var session = DDOM.create("session");
        trace(session);
        /*var t:DDOMInst = cast session; // Cast to DDOMInst to break out of DDOM field read/write!
        trace(t._nodes);
        trace(t.nodes);
        var p:Processor = cast t.processor;
        trace(p.rootNodes());*/
        session.id = "home-server";
        var s2 = session.select();
        trace(s2);
        // Get it by id
        var homeSession = session.select("#home-server");
        trace(homeSession);

        var notFound = session.select("#badid");
        trace(notFound);

        // Example that all DDOM instances are an array
        for(s in homeSession) {
            trace(s);
            trace(s.id);
        }
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
