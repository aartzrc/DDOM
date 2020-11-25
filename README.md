# Data Document Object Model (DDOM)  

DDOM uses selectors to access data in an agnostic way. It is similar to DOM/CSS/JQuery selectors, but has some unique aspects due to how data can be managed and the potentially circular nature of data references.  

DDOM also has event listeners and can batch events which allows for asynchronous client-server communication and 'event-based' updates.  

### DDOM Structure

`DataNode` instances hold parent/child data and a map/dictionary of strings. In general you do not access the `DataNode` directly, instead use the `DDOM` returned from another `DDOM` or a `Processor`.    
The `Processor` handles finding and filtering `DataNode` instances based on a `Selector` and wrapping them in a `DDOM` for use. The `Processor` is the main extension point when adding a new type of data handler (see DDOM-DB for example).  
A `Selector` is a string that provides the search path to the data needed. They are formatted similar to a CSS or JQuery selector.  
A `DDOM` will never be null, and all operations on it will not fail or throw exceptions.  
The `DataNode` type and properties are all strings, this is intentional to keep the data as simple as possible. See below for type safety considerations in dealing with DDOM.  
During a 'select' on a `DDOM` the data is not actually requested, only when the data is needed does the `Processor` get called to provide a result. Once the results are provided they are cached in the `DDOM` instance, this is done for speed and so iterating on the `DDOM` is stable. To refresh the data set a new `DDOM` is needed, which can be done by calling `select()`.

### Usage examples (see Examples.hx):  

Note: tracing out a DDOM will show the current `Selector` and result data, this is a quick way to view what data is available

```haxe
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
```

### Extending DDOM

On its own DDOM is not very useful, but by extending the `Processor` class access to other data sources becomes easier and more consistent. For example, the DDOM-DB project provides a starting point for a standard MySql database processor while DDOM-HTML accesses an HTML DOM tree - both provide the same interface for data access.  

### DDOM Events

Structure changes can be monitored using the `SelectorListener` class. By tracking a specific `Selector` on the `Processor` the event system can notify a callback about changes.

``` haxe
var session = DDOM.create("session");
var d = session.select("> user");
d.attach((ddom) -> trace(ddom)); // {* > user} = []
session.append(DDOM.create("user")); // This results in an update to {* > user} = [{type:user}]
d.name = "name changed"; // This is ignored by the listener - only structure changes are handled
```

The `DDOM` instance can have multiple `DataNode` types and properties, so monitoring property changes requires direct access to the `DataNode` instance. `DDOM.nodesOfType` is the most direct way to access the `DataNode` instances. Once a `DataNode` instance is available the `on` and `off` functions can be used to add/remove event listeners. As a convenience the `on` function returns a function that is bound to the `off` function.    

``` haxe
var userDataNode = users.nodesOfType("user")[0]; // Get the first instance of a 'user' DataNode
var detachFunc = userDataNode.on((e) -> { trace(e); }); // On change event: FieldSet({type:user => name:new person,email:someone@email.com},email,someone@email.com)
users.email = "someone@email.com"; // Results in a trace event
detachFunc(); // Remove the listener
users.email = "newemail@email.com"; // Not traced
```

### Type Safety

DDOM reduces the complexity of data access, but also removes all type safety (oh no!) To recover type safety it is recommended to wrap the `DataNode` instances in an abstract that can validate and provide simpler access to data. See `User.hx` and `Examples.hx` files.  

### Selector examples

`customer#1234` - get customer with id 1234  
`customer#1234 > cart:pos(0) > cartitems` - get cartitems from the first cart for customer 1234  
`customer#1234 cartitems` - get all cartitems for customer 1234  
.. much more to document - see `TokenizerTests` and `Selector`  