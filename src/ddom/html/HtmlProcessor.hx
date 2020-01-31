package ddom.html;

import haxe.Timer;
using Lambda;
using ddom.LambdaExt;

import ddom.DDOM;
import ddom.Selector;
import ddom.Processor;

import htmlparser.HtmlDocument;
import htmlparser.HtmlNodeElement;

@:access(ddom.DDOMInst, ddom.DataNode)
class HtmlProcessor extends Processor implements IProcessor {
    
    var htmlDoc:HtmlDocument;

	public function new(html:String) {
        htmlDoc = new HtmlDocument(html);
        super(htmlDoc.children.map((hn) -> htmlNodeToDataNode(hn)));
    }

    public function select(selector:Selector):DDOM {
        return new DDOMInst(this, selector);
    }

    var nodeMap:Map<HtmlNodeElement, DataNode> = [];
    function htmlNodeToDataNode(hn:HtmlNodeElement):DataNode {
        if(!nodeMap.exists(hn)) {
            var dn = new DataNode(hn.name, [ for(a in hn.attributes) a.name => a.value ]);
            nodeMap.set(hn, dn);
            for(c in hn.children)
                dn.addChild(htmlNodeToDataNode(c));
        }
        return nodeMap[hn];
    }
}
