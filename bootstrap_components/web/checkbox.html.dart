import 'package:web_ui/web_ui.dart';
    
class Checkbox extends WebComponent {
  String label = "";
  bool checked = false;
  
  inserted() {
  }
  
  created() {
    if (attributes["label"] != null) {
      label = attributes["label"];
    }
    if (attributes["checked"] != null) {
      checked = (attributes["checked"] == "true");
    }
  }
}