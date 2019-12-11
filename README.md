# Data Document Object Model (DDOM)  

Basic map of data to DOM-style syntax for basic read/write operations. All data is stored as `Any` type, but can be flagged as a specific class and throw exceptions on cast. All endpoints can be 'observable'. All operations return a DDOM instance (this is similar to how JQuery works), field access is forwarded through the DDOM instance.  

DOM operations:  
static getById(id:String)  
static getByType(type:String)  
static create(type:String)  
append(node:DDOM)  
remove(node:DDOM)  
delete()  

most other operations become combinations of these basic calls

it looks like field access can be overridden: @:op(a.b) - https://haxe.org/manual/types-abstract-operator-overloading.html

11/26/2019:  
coming along well, things to build out:  
DDOM to typedef (or graphql), and have the typedefs provide code completion and type safety  
An async client side updater that can call to a server  
A server sync reader that can pull from a standard database  
Allow multiple filters per token?  
Quick way to generated unit tests for to/from string tokenization, iterate over all enums combinations and verify the go to/from string properly  

12/1/2019:
mostly stable, and DB access is working (although very slow, but just needs to be reworked/optimized)
things to figure out:
type safety via cast, it looks like casting away from DDOM breaks field read/write so an abstract on top of DDOM then a typedef cast? yikes...
async client to server system - extension methods attach/detach that use a base `Processor` system that responds with cached data if available and notifies a server about the attached `Selector`. The server can then respond with updates and the attached callbacks will be fired. The server needs to be smart enough to determine which selectors have real data updates, then the client just pushes them along? attached endpoint would receive new DDOMs.  
all `DataNodes` should track their changes (events) so they can be reviewed as a transaction and sent to a data source as an update.

12/7/2019:
Create a 'SelectorListener' class that takes a DDOM and uses the selector+processors to return any node list changes.
Field changes are ignored (unless they effect the node list in some way). A 'FieldListener' would work the same but attach to all DataNodes in the DDOM.
'SelectorListener' would need to listen to ALL data nodes in the pool (and add/remove listeners when parents/children are changed), and re-run all selectors.
It would be best to make it so IProcessors and Selectors can be added/removed, so it becomes a reusable instance.
Ended up with a static extension that stores everything needed within a typedef

Options for client to server polling:
A) Have the client register selectors with the server. Each poll cycle the server would check for updates and respond.
B) Have the client re-send selectors to the server, so the client maintains the attach/detach list. When the server responds with an update, the client could choose to adjust the selector to provide only more recent data

I think option B for now. Items come back from the server, the selector gets adjusted to be like [id>_x_] so only new results are returned from the server after that.
How would option B handle an item being deleted? Maybe the server could have an event log that could be selected against. To avoid having to add to 'old' systems, the client would need to occassionally refresh the original selector.
Example:
1. Customer page selected, create DOM
2. Start listening to any customers added to a cache instance: cache.select("> customer").attach(...)
3. Get a customer list from the server: "> customer" - this should be a central polling loop that detects the attach?
4. Response contains ALL customers, put them in the cache (update will fire to attached endpoint, which can update display) - TODO: add a 'transaction' system to avoid redundant events
5. Next poll cycle, request from the server: "> customer[id>1234]"
6. Server probably contains no new results, but any new results can be appended, which fires to endpoint again
7. After a few poll cycles, refresh the whole customer list to catch any deleted items
8. Customer page closed, detach from selector, polling system drops the selector

12/10/2019:
Basic client-server system built, client keeps track of 'attached' selectors and polls for updates.
New issues related to this:
How to modify a client DataNode and send to server? All DataNodes on client should be 'listened' to and updates sent to server. Server can reply with sync data/etc.
TODO: create a 'catch all' style database that can store anything a selector/update can throw at it
DataNodes would need to be stored a bit differently to help optimize selector lookups
id, type, fields (serialized Map<String,String>)
parent/child assoc table