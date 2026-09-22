export 'file_upload_stub.dart'
    if (dart.library.html) 'file_upload_web.dart'
    if (dart.library.io) 'file_upload_io.dart';
