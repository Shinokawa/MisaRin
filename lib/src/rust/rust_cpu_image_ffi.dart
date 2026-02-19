export 'rust_cpu_image_ffi_stub.dart'
    if (dart.library.ffi) 'rust_cpu_image_ffi_io.dart'
    if (dart.library.js_interop) 'rust_cpu_image_ffi_web.dart';
