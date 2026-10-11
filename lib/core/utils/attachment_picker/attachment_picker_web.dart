import 'dart:async';
import 'dart:js_interop';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;
import 'picked_attachment_file.dart';

Future<PickedAttachmentFile?> pickAttachmentFilePlatform() async {
  // Ensure FilePickerWeb is registered in case the running web session started before plugin registration
  try {
    if (FilePickerPlatform.instance is! FilePickerWeb) {
      FilePickerWeb.registerWith(webPluginRegistrar);
    }
  } catch (_) {}

  try {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file != null) {
      final bytes = await file.readAsBytes();
      return PickedAttachmentFile(name: file.name, bytes: bytes);
    }
    return null;
  } catch (e) {
    // If FilePicker still throws UnimplementedError or any error, fall back to direct HTML5 input
    return _pickFileDirectWeb();
  }
}

Future<PickedAttachmentFile?> _pickFileDirectWeb() async {
  final completer = Completer<PickedAttachmentFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '*/*'
    ..style.display = 'none';

  input.onchange = (web.Event e) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = (web.Event e) {
      final result = reader.result;
      if (result != null) {
        final arrayBuffer = result as JSArrayBuffer;
        final bytes = arrayBuffer.toDart.asUint8List();
        if (!completer.isCompleted) {
          completer.complete(PickedAttachmentFile(name: file.name, bytes: bytes));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    }.toJS;
    reader.onerror = (web.Event e) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  web.document.body?.appendChild(input);
  input.click();
  input.remove();

  return completer.future;
}
