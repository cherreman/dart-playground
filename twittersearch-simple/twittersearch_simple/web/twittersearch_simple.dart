import 'dart:html';
import 'dart:json';

void main() {
  window.on.message.add(_window_messageHandler);
  query("#searchButton").on.click.add(_searchButton_clickHandler);
}

_window_messageHandler(MessageEvent event) {
  var searchResult = JSON.parse(event.data);
  var tableBody = query("#tableBody") as TableSectionElement;
  tableBody.elements.clear();
  
  for (Map t in searchResult["results"]) {
    var row = _createRow(t["from_user_name"], t["text"], t["created_at"]);
    tableBody.elements.add(row);
  }
}

_searchButton_clickHandler(MouseEvent event) {
  var searchTerm = query("#searchInput").value;
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