#ifndef FLUTTER_PLUGIN_RUST_LIB_MISA_RIN_PLUGIN_H_
#define FLUTTER_PLUGIN_RUST_LIB_MISA_RIN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <memory>

namespace rust_lib_misa_rin {

class RustLibMisaRinPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit RustLibMisaRinPlugin(flutter::TextureRegistrar* texture_registrar);

  ~RustLibMisaRinPlugin() override;

  RustLibMisaRinPlugin(const RustLibMisaRinPlugin&) = delete;
  RustLibMisaRinPlugin& operator=(const RustLibMisaRinPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace rust_lib_misa_rin

#endif  // FLUTTER_PLUGIN_RUST_LIB_MISA_RIN_PLUGIN_H_
