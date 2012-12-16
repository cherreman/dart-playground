import 'package:web_ui/web_ui.dart';
import 'dart:html';
    
class HBox extends WebComponent {
  String padding = "5";
  String gap = "";
  
  List<Element> _e;
  
  created() {
    _e = new List<Element>.from(elements);
  }
  
  inserted() {
    var div = elements[0];
    
    applyStyleFromAttribute(div, "padding", true);
    applyStyleFromAttribute(div, "border-style");
    applyStyleFromAttribute(div, "border-color");
    applyStyleFromAttribute(div, "border-width", true);
    
    var gap;
    if (attributes["gap"] != null) {
      gap = attributes["gap"];
    }
    
    for (var i = 0; i<_e.length; i++) {
      DivElement divElement = new DivElement();
      divElement.style.display = "inline-block";
      if (gap != null && i > 0) {
        divElement.style.marginLeft = "${gap}px";
      }
      divElement.append(_e[i]);
      div.append(divElement);
    }
  }

  applyStyleFromAttribute(Element element, String name, [bool inPixels = false]) {
    if (attributes[name] != null) {
      var value = attributes[name];
      if (inPixels) {
        value = "${value}px";
      }
      element.style.setProperty(name, value);
    }
  }
}