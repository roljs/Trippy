export 'picked_attachment_file.dart';
export 'attachment_picker_stub.dart'
    if (dart.library.js_interop) 'attachment_picker_web.dart'
    if (dart.library.io) 'attachment_picker_io.dart';
