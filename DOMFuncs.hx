import js.html.*;
import js.Browser.document;

class DOMFuncs {
	static function header() {
		var div_1 = document.createElement("div");
		div_1.className = "card flex-md-row mb-4 box-shadow h-md-250";
		var div_2 = document.createElement("div");
		div_1.appendChild(div_2);
		div_2.className = "card-body d-flex flex-column align-items-start";
		var strong_1 = document.createElement("strong");
		div_2.appendChild(strong_1);
		strong_1.className = "d-inline-block mb-2 text-primary";
		strong_1.innerText = "World";
		var h3_1 = document.createElement("h3");
		div_2.appendChild(h3_1);
		h3_1.className = "mb-0";
		var a_1 = document.createElement("a");
		h3_1.appendChild(a_1);
		a_1.className = "text-dark";
		a_1.innerText = "Featured post";
		var div_3 = document.createElement("div");
		div_2.appendChild(div_3);
		div_3.className = "mb-1 text-muted";
		div_3.innerText = "Nov 12";
		var p_1 = document.createElement("p");
		div_2.appendChild(p_1);
		p_1.className = "card-text mb-auto";
		p_1.innerText = "This is a wider card with supporting text below as a natural lead-in to additional content.";
		var a_2 = document.createElement("a");
		div_2.appendChild(a_2);
		a_2.innerText = "Continue reading";
		var img_1 = document.createElement("img");
		div_1.appendChild(img_1);
		img_1.className = "card-img-right flex-auto d-none d-md-block";
	}
}