Dart Playground
===============

This is a repo where I keep experimental Dart code while in the process of learning Dart. If you have any suggestions or remarks, feel free to send them.

Examples
--------

* **Twitter Search Simple**: allows you to search for a keyword on Twitter. The results are shown in a table that is dynamically updated. This example contains code that queries and manipulates the DOM, invokes the Twitter JSON(P) API and parses the incoming JSON data.

* **Twitter Search Simple with Web Components**: this is basically the same example as Twitter Search Simple, but uses Web Components with data binding and templating.

* **Twitter Search**: allows you to search for keywords on Twitter. This is a more elaborate version than the Twitter Search Simple examples.
  
  Main features:

  * It keeps a list of previous searches.
  * Uses Web Components with templating and data binding.
  * A service is introduced to fetch the tweets. This service consist of a pure abstract class forming the interface of the service and two implementations: the first one connects to the Twitter API, the second one is a stub that generates random data. The latter is useful during development. This choice of service is now decided in the main() method, but would potentially be injected in the appropriate place.
  * Futures are used to respond to the asynchronous loading of tweets.

Resources
---------

* Dart Homepage: http://www.dartlang.org/
* Dart API Reference: http://api.dartlang.org/docs/bleeding_edge/
* Seth Ladd's Blog: http://blog.sethladd.com/
* Dart Web Components: http://www.dartlang.org/articles/dart-web-components
* Tools for Dart Web Components: http://www.dartlang.org/articles/dart-web-components/tools.html
* Dart Web Components Test by Seth Ladd: https://github.com/sethladd/dart-web-components-tests