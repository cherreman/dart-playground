import 'package:web_ui/web_ui.dart';
import 'tablecolumn.dart';
    
class Table extends WebComponent {

  bool striped = false;
  bool bordered = false;
  bool hover = false;
  bool condensed = false;
  List items;
  List<Tablecolumn> columns;
  
  String get tableClass {
    var result = "table";
    
    if (striped) {
      result = result.concat(" table-striped");
    }
    if (bordered) {
      result = result.concat(" table-bordered");
    }
    if (hover) {
      result = result.concat(" table-hover");
    }
    if (condensed) {
      result = result.concat(" table-condensed");
    }
    
    return result;
  }
  
  inserted() {
    //print("inserted");
  }
  
  created() {
    if (attributes["striped"] != null) {
      striped = (attributes["striped"] == "true");
    }
    if (attributes["bordered"] != null) {
      bordered = (attributes["bordered"] == "true");
    }
    if (attributes["hover"] != null) {
      hover = (attributes["hover"] == "true");
    }
    if (attributes["condensed"] != null) {
      condensed = (attributes["condensed"] == "true");
    }
  }
}