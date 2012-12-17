import 'dart:html';
import 'dart:math';
import 'tablecolumn.dart';

String progressBarValue = "50";
bool tableStriped = false;
bool tableBordered = true;
bool tableHover = true;
bool tableCondensed = false;
List<User> users = new List<User>();
List<Tablecolumn> tableColumns = new List<Tablecolumn>();

Random _random = new Random();



void main() {
  users.add(new User("Christophe", "Herreman", "christophe@stackandheap.com"));
  users.add(new User("Roland", "Zwaga", "roland@stackandheap.com"));
  
  tableColumns.add(new Tablecolumn("Firstname", "firstname"));
  tableColumns.add(new Tablecolumn("Lastname", "lastname"));
  tableColumns.add(new Tablecolumn("E-mail", "email"));
}

clickHandler() {
  progressBarValue = _random.nextInt(100).toString();
}

addRow() {
  users.add(new User("test", "test", "test@stackandheap.com"));
}

removeRow() {
  users.removeLast();
}

class User {
  String firstname;
  String lastname;
  String email;
  User(this.firstname, this.lastname, this.email);
}