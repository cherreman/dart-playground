Dart jsonp_request library
==========================

This library makes it easy to work with JSONP requests in Dart.

It hides the complexity of adding a script to handle the callback. It also adds a callback attribute to the request string so the user does not need to specify this himself. The default callback attribute name is "callback", which can be overwritten by specifying the optional callbackParam parameter of the jsonpRequest() call.

Example
-------

    import 'packages/jsonp_request/jsonp_request.dart';
	
	main() {
	  var url = "http://search.twitter.com/search.json?q=dartlang";
      jsonpRequest(url).then((Map result) {
        // "result" contains the request result object
      });
	}

Example with custom callback attribute
--------------------------------------

    import 'packages/jsonp_request/jsonp_request.dart';
	
	main() {
	  var url = "http://search.twitter.com/search.json?q=dartlang";
      jsonpRequest(url, "jsonp").then((Map result) {
        // "result" contains the request result object
      });
	}
	
Download
--------

http://pub.dartlang.org/packages/jsonp_request

Resources
---------

This library was inspired by the work from Seth Ladd and Chris Buckett

* http://blog.sethladd.com/2012/03/jsonp-with-dart.html
* https://github.com/chrisbu/DartJSONP
