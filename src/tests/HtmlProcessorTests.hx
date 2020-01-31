package tests;

import haxe.iterators.StringIterator;
import ddom.DDOM;
import ddom.DataNode;
import ddom.Selector;
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
        var header = h.select("html header[class~=blog-header]");
        trace(header);

        lines.push('static function header() {');

        lines = lines.concat(toDOMFunc(header));

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

    @:access(ddom.DDOMInst, ddom.DataNode)
    static function toDOMFunc(ddom:DDOMInst) {
        var lines:Array<String> = [];
        var eNames:Map<String, Int> = [];

        function toF(n:DataNode, pName:String = null) {
            if(!eNames.exists(n.type)) eNames.set(n.type, 0);
            eNames[n.type]++;
            var name = '${n.type}_${eNames[n.type]}';
            lines.push('var $name = document.createElement("${n.type}");');
            if(pName != null)
                lines.push('$pName.appendChild($name);');
            if(n.fields.exists("class"))
                lines.push('$name.className = "${n.fields["class"]}";');
            for(c in n.children) toF(c, name);
        }

        for(n in ddom.nodes) toF(n);

        return lines;
    }
}
