import 'package:web_ui/web_ui.dart';
    
class Button extends WebComponent {
    
  String size = "default";
  String label = "";
  
  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (value) {
      elements[0].attributes.remove("disabled");
    } else {
      elements[0].attributes["disabled"] = "disabled";
    }
  }
  
  String get buttonClass {
    var result = "btn";
    if (size == "large") {
      result = result.concat(" btn-large");
    }
    return result;
  }
  
  inserted() {
    label = attributes["label"];
    size = attributes["size"];
    if (attributes["enabled"] != null) {
      enabled = (attributes["enabled"] == "true");
    }
  }
  
  created() {
  }
}