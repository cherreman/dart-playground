import 'dart:html';
import 'dart:json';
import 'packages/jsonp_request/jsonp_request.dart';

void main() {
  query("#searchButton").onClick.listen(_searchButton_clickHandler);
}

_searchButton_clickHandler(MouseEvent event) {
  var searchInput = query("#searchInput") as InputElement;
  var searchTerm = searchInput.value;
  var url = "http://search.twitter.com/search.json?q=$searchTerm";
  
  jsonpRequest(url).then((Map result) {
    var table = query("#resultsTable") as TableElement;
    table.children.clear();

    for (Map t in result["results"]) {
      var row = _createRow(t["from_user_name"], t["text"], t["created_at"]);
      table.children.add(row);
    }
  });
}

TableRowElement _createRow(String author, String message, String date) {
  var result = new TableRowElement();
  result.children.add(_createCell(author));
  result.children.add(_createCell(message));
  result.children.add(_createCell(date));
  return result;
}

TableCellElement _createCell(String text) {
  var result = new TableCellElement();
  result.text = text;
  return result;
}