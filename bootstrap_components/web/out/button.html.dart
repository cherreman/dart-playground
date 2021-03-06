// Auto-generated from button.html.
// DO NOT EDIT.

library x_button;

import 'dart:html' as autogenerated_html;
import 'dart:web_audio' as autogenerated_audio;
import 'dart:svg' as autogenerated_svg;
import 'package:web_ui/web_ui.dart' as autogenerated;

import 'package:web_ui/web_ui.dart';

class Button extends WebComponent {
  
  /** Autogenerated from the template. */
  
  /**
  * Shadow root for this component. We use 'var' to allow simulating shadow DOM
  * on browsers that don't support this feature.
  */
  var _root;
  autogenerated_html.ButtonElement __e19;
  
  List<autogenerated.WatcherDisposer> __stoppers1;
  
  var __binding18;
  
  Button.forElement(e) : super.forElement(e);
  
  void created_autogenerated() {
    _root = createShadowRoot();
    
    _root.innerHtml = '''
    
    <button class="" id="__e-19"></button>
    ''';
    __e19 = _root.query('#__e-19');
    __binding18 = new autogenerated_html.Text('');
    __e19.nodes.add(__binding18);
    __stoppers1 = [];
    
  }
  
  void inserted_autogenerated() {
    __stoppers1.add(autogenerated.bindCssClasses(__e19, () => buttonClass));
    
    __stoppers1.add(autogenerated.watchAndInvoke(() => '${label}', (__e) {
      __binding18 = autogenerated.updateBinding(label, __binding18, __e.newValue);
    }));
    
  }
  
  void removed_autogenerated() {
    _root = null;
    
    (__stoppers1..forEach((s) => s())).clear();
    
    __e19 = null;
    
    __binding18 = null;
    
  }
  
  void composeChildren() {
    super.composeChildren();
    if (_root is! autogenerated_html.ShadowRoot) _root = this;
  }
  
  /** Original code from the component. */
  
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

