import 'package:web_ui/web_ui.dart';
    
class ProgressBar extends WebComponent {
  String striped = "false";
  String animated = "false";
  String value = "0";
    
  String get progressClass {
    var result = "progress";
    
    if (striped == "true") {
      result = "${result} progress-striped";
      if (animated == "true") {
        result = "${result} active";
      }
    }
    return result;
  }
    
  created() {
    value = attributes["value"];
    striped = attributes["striped"];
    animated = attributes["animated"];
  }
}