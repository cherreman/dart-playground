import 'package:web_ui/web_ui.dart';
    
class Button extends WebComponent {
    
  String size = "default";
  String disabled = "false";
  String _text = "";
  
  
  String get buttonClass {
    var result = "btn";
    
    if (size == "large") {
      result = "${result} btn-large";
    }
    
    if (disabled == "true") {
      result = "${result} disabled";
    }
    
    return result;
  }
    
  
  inserted() {
    //print("inserted");
  }
  
  created() {
    print("created");
    _text = text;
    text = "";
    size = attributes["size"];
    disabled = attributes["disabled"];
    if (disabled != null && disabled.isEmpty) {
      disabled = "true";
    }
    
    print("disabled: $disabled");
  }
}