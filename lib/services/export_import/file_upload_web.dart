// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as String?);
      });
      reader.onError.listen((e) {
        completer.complete(null);
      });
      reader.readAsText(files[0]);
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
