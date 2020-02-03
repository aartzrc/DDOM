package tests;

import haxe.iterators.StringIterator;
import ddom.DDOM;
import ddom.html.HtmlProcessor;
import sys.io.File;
using StringTools;

class HtmlProcessorTests {
	static function main() {
        var className = "DOMFuncs";
        var lines:Array<String> = [];

        lines.push('import js.html.*;');
        lines.push('import js.Browser.document;');
        lines.push('');
        lines.push('class $className {');

        var h = new HtmlProcessor(File.getContent("./src/tests/blog-page.htm"));

        lines.push('static function header() {');

        lines = lines.concat(h.toDOMFuncs("html div[class~=card]:pos(0)"));

        lines.push('}');
        lines.push('}');

        File.saveContent('$className.hx', formatLines(lines).join("\n"));
    }

    static function formatLines(lines:Array<String>) {
        var tabs = 0;
        for(i in 0 ... lines.length) {
            var l = lines[i];
            for(c in new StringIterator(l)) if(c == '}'.code) tabs--;
            l = [for(i in 0 ... tabs) "\t"].join("") + l.trim();
            for(c in new StringIterator(l)) if(c == '{'.code) tabs++;
            lines[i] = l;
        }
        return lines;
    }
}
