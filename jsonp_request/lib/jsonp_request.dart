library jsonp_request;

import 'dart:html';
import 'dart:json';
import 'dart:async';

/**
 * Executes a JSONP request.
 * 
 * Returns a [Future] with the result of the request.
 * 
 * The callback attribute is automatically added. By default, the name
 * of the callback attribute is "callback". Another name can be specified via
 * the [callbackParam] parameter.
 */
Future<Map> jsonpRequest(String url, [String callbackParam = "callback"]) {
  return new _JsonpRequest()._get(url, callbackParam);
}

class _JsonpRequest {

  static int _requestCounter = 0;
  String _callbackName;
  ScriptElement _callbackScript;

  Future<Map> _get(String url, [String callbackParam = "callback"]) {
    var completer = new Completer<Map>();
    _callbackName = "jsonpCallback_${_requestCounter++}";
    url = url.concat("&$callbackParam=$_callbackName");

    _listenForCallback(completer);
    _addCallbackScript();
    _doRequest(url);

    return completer.future;
  }
  
  _listenForCallback(Completer completer) {
    window.onMessage.listen((MessageEvent event) {
      Map result = parse(event.data);
      if (result["callbackName"] == _callbackName) {
        _callbackScript.remove();
        completer.complete(result["data"]);
      }
    });
  }
  
  _addCallbackScript() {
    _callbackScript = new ScriptElement()
    ..text = """function $_callbackName(value) {         
      window.postMessage('{"callbackName":"$_callbackName","data":' + JSON.stringify(value) + '}', '*');
    }""";
    document.body.children.add(_callbackScript);
  }
  
  _doRequest(String url) {
    var script = new ScriptElement()
    ..src = url;
    document.body.children.add(script);
    script.remove();
  }
  
}