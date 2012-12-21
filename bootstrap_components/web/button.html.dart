import 'package:web_ui/web_ui.dart';
    
class Button extends WebComponent {
  
  bool enabled = true;
  String size = "default";
  String label = "";
  
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