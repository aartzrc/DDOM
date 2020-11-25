# Data Document Object Model (DDOM)  

DDOM uses selectors to access data in an agnostic way. It is similar to DOM/CSS/JQuery selectors, but has some unique aspects due to how data can be managed and the potentially circular nature of data references.  

DDOM also has event listeners and can batch events which allows for asynchronous client-server communication and 'event-based' updates.  

The general concept of DDOM is a `DDOM` instance which is an anonymous set of data. It can contain nothing, or a wide range of data types and fields. A `DDOM` will never be null, and all operations on it will not fail or throw exceptions.  

Usage examples:  

### Selector examples

`customer#1234` - get customer with id 1234  
`customer#1234 > cart:pos(0) > cartitems` - get cartitems from the first cart for customer 1234  
`customer#1234 cartitems` - get all cartitems for customer 1234
.. much more to document - see `TokenizerTests` and `Selector`  