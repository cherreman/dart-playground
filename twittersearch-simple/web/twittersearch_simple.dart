import 'dart:html';
import 'dart:json';

void main() {
  // Listen for incoming "message" events on the main window.
  // This is needed because the window will inform us when the JSON data is loaded.
  window.on.message.add(_window_messageHandler);
  
  // Listen for "click" events on the search button
  query("#searchButton").on.click.add(_searchButton_clickHandler);
}

_window_messageHandler(MessageEvent event) {
  // Parse the incoming JSON data
  var searchResult = JSON.parse(event.data);
  
  // Get a reference to the table where we will show the results.
  // Also make sure to clear the table so new search results replace the previous ones.
  var table = query("#resultsTable") as TableElement;
  table.elements.clear();
  
  // Loop through the results and create a row in the table for each tweet.
  for (Map t in searchResult["results"]) {
    var row = _createRow(t["from_user_name"], t["text"], t["created_at"]);
    table.elements.add(row);
  }
}

_searchButton_clickHandler(MouseEvent event) {
  // Get search term that the user entered.
  var searchTerm = query("#searchInput").value;
  
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

TableRowElement _createRow(String author, String message, String date) {
  var result = new TableRowElement();
  result.elements.add(_createCell(author));
  result.elements.add(_createCell(message));
  result.elements.add(_createCell(date));
  return result;
}

TableCellElement _createCell(String text) {
  var result = new TableCellElement();
  result.text = text;
  return result;
}