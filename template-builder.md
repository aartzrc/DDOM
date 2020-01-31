Instead of building/copying template html into Haxe DOM code by hand, create a compile step that does it.

For example:

wwwroot/templates/products.htm is a 'sample/template' page
a build script would use DDOM.htmlProcessor (not made yet, this would be a tool that provides 'tokenized' access to the html via HtmlParser/etc)
this build script would select the chunk of html to parse out of the template and pass it to a converter
the converter would change it to a Haxe function that builds the DOM calls
the function created needs to be able to take arguments - html data properties can be detected to pass the arguments through? by default it would put the innerHtml found in the template in-line

1. create a DDOM html processor
2. create a DDOM object to Haxe DOM function output converter