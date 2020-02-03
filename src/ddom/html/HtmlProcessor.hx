package ddom.html;

import htmlparser.HtmlNodeElement;
import haxe.Timer;
using Lambda;
using ddom.LambdaExt;
using StringTools;

import ddom.DDOM;
import ddom.Selector;
import ddom.Processor;

import htmlparser.HtmlDocument;
import htmlparser.HtmlNode;

@:access(ddom.DDOMInst, ddom.DataNode)
class HtmlProcessor extends Processor implements IProcessor {
    
    var htmlDoc:HtmlDocument;

	public function new(html:String) {
        htmlDoc = new HtmlDocument(html);
        super(htmlDoc.children.map((hn) -> htmlNodeToDataNode(hn)));
    }

    var nodeMap:Map<HtmlNode, DataNode> = [];
    function htmlNodeToDataNode(hn:HtmlNode):DataNode {
        if(!nodeMap.exists(hn)) {
            var dn:DataNode;
            if(Type.getClass(hn) == HtmlNodeElement) {
                var hne:HtmlNodeElement = cast hn;
                dn = new DataNode(hne.name, [ for(a in hne.attributes) a.name => a.value ]);
                for(c in hne.nodes)
                    dn.addChild(htmlNodeToDataNode(c));
            } else {
                var text = hn.toText();
                dn = new DataNode("text", !LambdaExt.isNullOrWhitespace(text) ? ["text" => hn.toText()] : []);
            }
            nodeMap.set(hn, dn);
        }
        return nodeMap[hn];
    }

    var castTypes = [
        "div" => "DivElement"
    ];
    public function toDOMFuncs(selector:Selector) {
        var ddom = new DDOMInst(this, selector);
        var lines:Array<String> = [];
        var eNames:Map<String, Int> = [];
        var vars:Map<String, String> = [];

        function toF(ddom:DDOM, pName:String = null) {
            if(ddom.size() == 0) return;
            var type = ddom.types()[0];
            var fields = ddom.fields();
            if(fields.indexOf("ddom-skip") != -1 && ddom.fieldRead("ddom-skip") == "true") return;

            if(type == "text") {
                if(fields.indexOf("text") != -1)
                    lines.push('$pName.innerText = "${ddom.text.trim()}";');
            } else {
                if(!eNames.exists(type)) eNames.set(type, 0);
                eNames[type]++;
                var name = '${type}_${eNames[type]}';
                var castType = castTypes[type];
                lines.push('var $name${castType == null ? " =" : ':$castType = cast'} document.createElement("${type}");');
                if(pName != null)
                    lines.push('$pName.appendChild($name);');

                for(f in [ "class", "title", "name", "placeholder", "style" ].filter((f) -> fields.indexOf(f) != -1)) {
                    lines.push('$name.setAttribute("$f", "${ddom.fieldRead(f)}");'); 
                }

                if(fields.indexOf("ddom-var") != -1) {
                    vars.set(ddom.fieldRead("ddom-var"), name);
                }

                if(fields.indexOf("ddom-skipchildren") != -1 && ddom.fieldRead("ddom-skipchildren") == "true") return;
                for(c in ddom.children()) toF(c, name);
            }
        }

        for(n in ddom) toF(n);

        return {lines:lines, vars:vars};
    }
}
