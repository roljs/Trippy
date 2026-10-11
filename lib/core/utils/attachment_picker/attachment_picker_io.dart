import 'package:file_picker/file_picker.dart';
import 'picked_attachment_file.dart';

Future<PickedAttachmentFile?> pickAttachmentFilePlatform() async {
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedAttachmentFile(name: file.name, bytes: bytes);
}
