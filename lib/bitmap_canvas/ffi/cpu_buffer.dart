export 'cpu_buffer_stub.dart'
    if (dart.library.ffi) 'cpu_buffer_io.dart'
    if (dart.library.js_interop) 'cpu_buffer_web.dart';
