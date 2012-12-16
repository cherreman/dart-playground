import 'dart:html';
import 'dart:json';
import 'package:web_ui/watcher.dart' as watchers;

// Make sure to initialize this var to an empty string to prevent
// a runtime error at startup.
String searchTerm = "";
List<Tweet> tweets = new List();

void main() {
  // Listen for incoming "message" events on the main window.
  // This is needed because the window will inform us when the JSON data is loaded.
  window.on.message.add(_window_messageHandler);
}

_window_messageHandler(MessageEvent event) {
  // Parse the incoming JSON data
  var searchResult = JSON.parse(event.data);
  
  // Clear the previous tweets
  tweets.clear();
  
  // Loop through the results and create a new Tweet instance for each tweet
  // The Tweet objects are created to enable us to databind to the properties,
  // because binding to values on a Map does not seem to work.
  for (Map t in searchResult["results"]) {
    tweets.add(new Tweet(t["from_user_name"], t["text"], t["created_at"]));
  }
  
  // Invoke the bindings by calling dispatch on the watcher.
  // We need to do this because the bindings are not triggered when the data
  // is changed from within an event handler.
  // Note: This is most likely an issue with the current version of Web Components
  // and should normally not be needed.
  watchers.dispatch();
}

searchButton_clickHandler(MouseEvent event) {
  // Add a script tag to load the JSONP data.
  // This is described here: http://blog.sethladd.com/2012/03/jsonp-with-dart.html
  //
  // Notice the $searchTerm part in the URL. Dart will replace this part with the
  // actual value of the searchTerm variable.
  //
  // The callback parameter is needed to receive the incoming data.
  // The name of the callback "jsonpCallback" refers to the name of the function
  // in the twittersearch_simple.html script.
  var script = new Element.tag("script");
  script.src = "http://search.twitter.com/search.json?q=$searchTerm&callback=jsonpCallback";
  document.body.elements.add(script);
}

class Tweet {
  String username;
  String text;
  String createdAt;
  
  Tweet(this.username, this.text, this.createdAt);
}