import 'dart:typed_data';

class PickedAttachmentFile {
  final String name;
  final Uint8List bytes;

  const PickedAttachmentFile({
    required this.name,
    required this.bytes,
  });
}
