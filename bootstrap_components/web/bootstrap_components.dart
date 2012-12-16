import 'dart:html';
import 'dart:math';

String progressBarValue = "50";
Random _random = new Random();

void main() {

}

clickHandler() {
  progressBarValue = _random.nextInt(100).toString();
}