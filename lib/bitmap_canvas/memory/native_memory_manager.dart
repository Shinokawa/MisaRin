export 'native_memory_manager_stub.dart'
    if (dart.library.ffi) 'native_memory_manager_io.dart'
    if (dart.library.js_interop) 'native_memory_manager_web.dart';
