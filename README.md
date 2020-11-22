# Data Document Object Model (DDOM)  

DDOM uses selectors to access data in an agnostic way. It is similar to DOM/CSS/JQuery selectors, but has some unique aspects due to how data can be managed and the potentially circular nature of data references.  

DDOM also allows for data event listeners and update transactions which allow for asynchronous client-server communication and data 'event-based' updates.  

The general concept of DDOM is a `DDOM` instance which is an anonymous set of data. It can contain nothing, or a wide range of data types and fields. A `DDOM` will never be null, and all operations on it will not fail or throw exceptions.  

Usage examples:  

Access an existing database:  

Given a relational database structure such as:

```sql
CREATE TABLE `customer` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `item` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `customer_id` int(10) unsigned NOT NULL,
  `orderitem` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `desc` text COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `item_history` (
  `item_id` int(10) unsigned NOT NULL,
  `status_id` int(10) unsigned NOT NULL,
  `udate` bigint(20) unsigned NOT NULL
);
```

Use DDOM to access the data:  

```haxe
var db = new ddom.db.DBProcessor({user:"db_user", pass:"db_pass", host:"db_host", database:"db_db"}, 
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
    trace(mythItems.size()); // 'length' can be a property of the result so DDOM has a size() function used to determine length/count of results
    for(c in mythCustomers) trace(c); // Iterate over result set

    var idCustomer = db.select('customer#${mythCustomers.id}'); // Use the first result 'id' value as a new selector
    trace(idCustomer);

    var mythAll = db.select('*[name*=Myth]'); // Search ALL tables - this will iterate over all tables defined and run the query
    trace(mythAll);

    var mythAll = db.select('*[desc*=myth]'); // Search ALL tables, special MySql keyword used 'desc' but it is escaped during query
    trace(mythAll.desc); // If no results, this will be null but not throw exception

    trace(db.log); // View queries and filters during processing

```

Output from this code will look like:
```
trace(mythItems) => {customer[name*=myth] > item} = [{type:item,id:32911 => udate:1561407989,customer_id:121,desc:mythic part}
trace(mythItems.size()) => 1
for(c in mythCustomers) => {customer[name*=myth]:pos(0)} = [{type:customer,id:121 => name:Mythic}]
trace(idCustomer) => {customer#121} = [{type:customer,id:121 => name:Mythic}]
trace(mythAll) => {*[name*=Myth]} = [{type:customer,id:121 => name:Mythic}]
trace(mythAll.desc) => null
trace(db.log) => [query: select * from customer WHERE `name` like '%myth%',query: select * from item where id in (select id from item where customer_id in ('121')),query: select * from customer WHERE `id`='121',query: select * from item_history WHERE `name` like '%Myth%',query: select * from item WHERE `name` like '%Myth%',query: select * from customer WHERE `name` like '%Myth%',processFilter- start: 1 nodes, filters: [Contains(name,Myth)], result count: 1,query: select * from item_history WHERE `desc` like '%myth%',query: select * from item WHERE `desc` like '%myth%',query: select * from customer WHERE `desc` like '%myth%']
```