library components;

import 'package:web_ui/web_ui.dart';
import 'dart:mirrors';
import 'dart:html';

class AbstractListComponent extends WebComponent {
  
  List wrappedItems;
  
  AbstractListComponent() : super();
  
  AbstractListComponent.forElement(Element element) : super.forElement(element);
  
  
  String _labelfield;
  String get labelfield => _labelfield;
  set labelfield (String value) {
    if (_labelfield != value) {
      _labelfield = value;
      
      if (wrappedItems != null) {
        wrappedItems.forEach((item) {
          item.labelfield = _labelfield;
          item.stringify();
        });
      }
    }
  }
  
  Function _labelfunction;
  Function get labelfunction => _labelfunction;
  set labelfunction (Function value) {
    if (_labelfunction != value) {
      _labelfunction = value;
      
      if (wrappedItems != null) {
        wrappedItems.forEach((ComboBoxItemWrapper item) {
          item.labelFunction = _labelfunction;
          item.stringify();
        });
      }
    }
  }
  
  List _items;
  List get items => _items;
  set items(List value) {
    _items = value;
    wrappedItems = new List();
    value.forEach((item) {
      var wrappedItem = new ComboBoxItemWrapper(item, _labelfield, _labelfunction);
      wrappedItem.stringify();
      wrappedItems.add(wrappedItem);
    });
  }
  
  inserted() {
    super.inserted();
  }
  
  created() {
    super.created();
    
    if (attributes["labelfield"] != null) {
      //labelfield = attributes["labelfield"];
      labelfield = new String.fromCharCodes(attributes["labelfield"].charCodes);
    }
  }
  
}

class ComboBoxItemWrapper {
  var item;
  String labelField;
  String stringValue;
  Function labelFunction;
  
  ComboBoxItemWrapper(this.item, this.labelField, this.labelFunction);
  
  stringify() {
    if (labelField != null && !labelField.isEmpty) {
      InstanceMirror im = reflect(item);
      im.getField(labelField).then((InstanceMirror value) {
        print("got labelfield via mirror");
        stringValue = value.reflectee;
      });
    } else if (labelFunction != null) {
      print("labelfunction");
      stringValue = Function.apply(labelFunction, [item]);
    } else {
      print("no labelfield and labelfunction");
      stringValue = item.toString();
    }
  }
  
}
