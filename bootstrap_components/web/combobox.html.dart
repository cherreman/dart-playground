import 'abstract_list_component.dart';
import 'dart:html';
    
class Combobox extends AbstractListComponent {
  
  int size = 2;
  int selectedIndex = 0;
  var selectedItem;
  
  changeHandler(Event event) {
    selectedIndex = (event.target as SelectElement).selectedIndex;
    selectedItem = items[selectedIndex];
  }
  
  
  created () {
    super.created();
  }
  
  inserted() {
    super.inserted();
    
    if (attributes["selected-index"] != null) {
      selectedIndex = int.parse(attributes["selected-index"]);
    }
    
  }
  
}