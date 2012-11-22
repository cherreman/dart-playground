import 'dart:html';
import 'dart:json';
import 'dart:math';

// VARIABLES

String inputSearchTerm = "";
String activeSearchTerm = "";
List<String> searchTerms = new List();
List<Tweet> tweets = new List();

TwitterService _twitterService = new JSONTwitterAPIService(); // new StubTwitterService(); 

// MAIN

void main() {}

// EVENT HANDLERS

searchButton_clickHandler(e) {
  inputSearchTerm = inputSearchTerm.trim();
  if (inputSearchTerm.length > 0) {
    search(inputSearchTerm);
    inputSearchTerm = "";
  }
}

searchTerm_clickHandler(MouseEvent e) {
  var node = e.toElement;
  if (node is AnchorElement) {
    node = node.parent;
  }
  search(node.text.trim());
}

removeSearchTerm_clickHandler(MouseEvent event) {
  var searchTerm = event.toElement.parent.parent.text.trim();
  var index = searchTerms.indexOf(searchTerm);
  searchTerms.removeAt(index);
  if (searchTerm == activeSearchTerm) {
    activeSearchTerm = "";
  }
}

search(String searchTerm) {
  print("Search for '$searchTerm'");
  activeSearchTerm = searchTerm;
  
  if (!searchTerms.contains(searchTerm)) {
    searchTerms.add(activeSearchTerm);
  }
    
  _twitterService.search(searchTerm).then((List<Tweet> result) {
    tweets = result;
  });
}

// CLASSES

class Tweet {
  String username;
  String text;
  String createdAt;
  
  Tweet(this.username, this.text, this.createdAt);
}

abstract class TwitterService{
  Future<List<Tweet>> search(String searchTerm);
}

class StubTwitterService extends TwitterService {
  Future<List<Tweet>> search(String searchTerm){
    List<Tweet> tweets = new List();
    Random random = new Random();
    int numItems = random.nextInt(20);
    for (int i = 0; i<numItems; i++) {
      tweets.add(new Tweet("user $i", "Tweet about $searchTerm $i", "2012-11-20 $i"));
    }
    print("Created ${tweets.length} random tweets");
    return new Future.immediate(tweets);
  }
}

class JSONTwitterAPIService extends TwitterService {
  Function handler;
  
  Future<List<Tweet>> search(String searchTerm) {
    var completer = new Completer();
    
    var script = new Element.tag("script");
    script.src = "http://search.twitter.com/search.json?q=$activeSearchTerm&callback=jsonpCallback";
    document.body.elements.add(script);
    
    handler = (MessageEvent e) {
      window.on.message.remove(handler);
      
      var searchResult = JSON.parse(e.data);
      var tweets = new List<Tweet>();
      
      for (Map t in searchResult["results"]) {
        tweets.add(new Tweet(t["from_user_name"], t["text"], t["created_at"]));
      }
      
      print("Received ${tweets.length} tweets from server");
      completer.complete(tweets);
    };
    
    window.on.message.add(handler);
    
    return completer.future;
  }
}
