#include "include/rust_lib_misa_rin/rust_lib_misa_rin_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter_plugin_registrar.h>
#include <flutter_texture_registrar.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

extern "C" {
uint64_t engine_create(uint32_t width, uint32_t height);
void engine_dispose(uint64_t handle);
void* engine_create_present_dxgi_surface(uint64_t handle,
                                         uint32_t width,
                                         uint32_t height);
uint8_t engine_resize_canvas(uint64_t handle,
                             uint32_t width,
                             uint32_t height,
                             uint32_t layer_count,
                             uint32_t background_color_argb);
void engine_reset_canvas_with_layers(uint64_t handle,
                                     uint32_t layer_count,
                                     uint32_t background_color_argb);
bool engine_poll_frame_ready(uint64_t handle);
}  // extern "C"

namespace rust_lib_misa_rin {

namespace {

constexpr char kChannelName[] = "misarin/rust_canvas_texture";
constexpr int kFallbackSize = 512;
constexpr int kFallbackLayerCount = 1;
constexpr uint32_t kFallbackBackground = 0xFFFFFFFF;
constexpr int kMaxDimension = 16384;
constexpr int kMaxLayerCount = 1024;

std::optional<int64_t> GetIntValue(const flutter::EncodableValue& value) {
  if (const auto* int32_value = std::get_if<int32_t>(&value)) {
    return *int32_value;
  }
  if (const auto* int64_value = std::get_if<int64_t>(&value)) {
    return *int64_value;
  }
  if (const auto* double_value = std::get_if<double>(&value)) {
    return static_cast<int64_t>(*double_value);
  }
  return std::nullopt;
}

int GetClampedInt(const flutter::EncodableMap& args,
                  const char* key,
                  int fallback,
                  int min_value,
                  int max_value) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return std::clamp(fallback, min_value, max_value);
  }
  const auto value = GetIntValue(it->second);
  if (!value.has_value()) {
    return std::clamp(fallback, min_value, max_value);
  }
  return std::clamp(static_cast<int>(*value), min_value, max_value);
}

uint32_t GetBackgroundColor(const flutter::EncodableMap& args) {
  const auto it = args.find(flutter::EncodableValue("backgroundColorArgb"));
  if (it == args.end()) {
    return kFallbackBackground;
  }
  const auto value = GetIntValue(it->second);
  if (!value.has_value()) {
    return kFallbackBackground;
  }
  return static_cast<uint32_t>(*value);
}

std::string GetSurfaceId(const flutter::EncodableMap& args) {
  const auto it = args.find(flutter::EncodableValue("surfaceId"));
  if (it == args.end()) {
    return "default";
  }
  if (const auto* str = std::get_if<std::string>(&it->second)) {
    if (!str->empty()) {
      return *str;
    }
  }
  if (const auto value = GetIntValue(it->second); value.has_value()) {
    return std::to_string(*value);
  }
  return "default";
}

struct GpuSurfaceBinding {
  explicit GpuSurfaceBinding(void* handle, size_t width, size_t height) {
    descriptor.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    descriptor.handle = handle;
    descriptor.width = width;
    descriptor.height = height;
    descriptor.visible_width = width;
    descriptor.visible_height = height;
    descriptor.format = kFlutterDesktopPixelFormatBGRA8888;
    descriptor.release_callback = nullptr;
    descriptor.release_context = nullptr;
  }

  const FlutterDesktopGpuSurfaceDescriptor* GetDescriptor() const {
    return &descriptor;
  }

  static const FlutterDesktopGpuSurfaceDescriptor* Callback(size_t,
                                                            size_t,
                                                            void* user_data) {
    const auto* binding = static_cast<GpuSurfaceBinding*>(user_data);
    if (!binding) {
      return nullptr;
    }
    return binding->GetDescriptor();
  }

  FlutterDesktopGpuSurfaceDescriptor descriptor{};
};

void ReleaseBinding(void* user_data) {
  auto* keepalive = static_cast<std::shared_ptr<GpuSurfaceBinding>*>(user_data);
  delete keepalive;
}

}  // namespace

class RustLibMisaRinPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopPluginRegistrarRef raw_registrar);

  explicit RustLibMisaRinPlugin(
      FlutterDesktopTextureRegistrarRef texture_registrar);

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

struct RustLibMisaRinPlugin::Impl {
  struct SurfaceState {
    std::string surface_id;
    int width = 0;
    int height = 0;
    int layer_count = kFallbackLayerCount;
    uint32_t background_color_argb = kFallbackBackground;
    uint64_t engine_handle = 0;
    int64_t texture_id = -1;
    std::shared_ptr<GpuSurfaceBinding> binding;
    std::mutex mutex;

    int64_t RefreshFrame() {
      std::lock_guard<std::mutex> lock(mutex);
      if (engine_handle == 0 || texture_id < 0) {
        return -1;
      }
      if (!engine_poll_frame_ready(engine_handle)) {
        return -1;
      }
      return texture_id;
    }
  };

  explicit Impl(FlutterDesktopTextureRegistrarRef texture_registrar)
      : texture_registrar_(texture_registrar), running_(true) {
    frame_thread_ = std::thread([this]() { FrameLoop(); });
  }

  ~Impl() {
    running_.store(false);
    if (frame_thread_.joinable()) {
      frame_thread_.join();
    }
    DisposeAll();
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name() == "getTextureInfo") {
      const auto* args =
          std::get_if<flutter::EncodableMap>(method_call.arguments());
      flutter::EncodableMap empty_args;
      HandleGetTextureInfo(args ? *args : empty_args, std::move(result));
      return;
    }
    if (method_call.method_name() == "disposeTexture") {
      const auto* args =
          std::get_if<flutter::EncodableMap>(method_call.arguments());
      flutter::EncodableMap empty_args;
      HandleDisposeTexture(args ? *args : empty_args, std::move(result));
      return;
    }
    result->NotImplemented();
  }

  void HandleGetTextureInfo(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string surface_id = GetSurfaceId(args);
    const int width =
        GetClampedInt(args, "width", kFallbackSize, 1, kMaxDimension);
    const int height =
        GetClampedInt(args, "height", kFallbackSize, 1, kMaxDimension);
    const int layer_count = GetClampedInt(
        args, "layerCount", kFallbackLayerCount, 1, kMaxLayerCount);
    const uint32_t background_color = GetBackgroundColor(args);

    std::shared_ptr<SurfaceState> surface;
    {
      std::lock_guard<std::mutex> lock(surfaces_mutex_);
      auto it = surfaces_.find(surface_id);
      if (it != surfaces_.end()) {
        surface = it->second;
      } else {
        surface = std::make_shared<SurfaceState>();
        surface->surface_id = surface_id;
        surfaces_.emplace(surface_id, surface);
      }
    }

    bool needs_resize = false;
    bool layer_count_changed = false;
    {
      std::lock_guard<std::mutex> lock(surface->mutex);
      if (surface->engine_handle != 0 && surface->texture_id >= 0 &&
          surface->width == width && surface->height == height &&
          surface->layer_count == layer_count) {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("textureId")] =
            flutter::EncodableValue(surface->texture_id);
        response[flutter::EncodableValue("engineHandle")] =
            flutter::EncodableValue(
                static_cast<int64_t>(surface->engine_handle));
        response[flutter::EncodableValue("width")] =
            flutter::EncodableValue(surface->width);
        response[flutter::EncodableValue("height")] =
            flutter::EncodableValue(surface->height);
        response[flutter::EncodableValue("isNewEngine")] =
            flutter::EncodableValue(false);
        result->Success(flutter::EncodableValue(response));
        return;
      }
      needs_resize =
          surface->engine_handle != 0 &&
          (surface->width != width || surface->height != height);
      layer_count_changed =
          surface->engine_handle != 0 && surface->layer_count != layer_count;
    }

    std::lock_guard<std::mutex> lock(surface->mutex);
    uint64_t handle = surface->engine_handle;
    bool engine_created = false;
    if (handle == 0) {
      handle = engine_create(static_cast<uint32_t>(width),
                             static_cast<uint32_t>(height));
      engine_created = true;
    } else if (needs_resize) {
      if (engine_resize_canvas(handle, static_cast<uint32_t>(width),
                               static_cast<uint32_t>(height),
                               static_cast<uint32_t>(layer_count),
                               background_color) == 0) {
        engine_dispose(handle);
        handle = engine_create(static_cast<uint32_t>(width),
                               static_cast<uint32_t>(height));
        engine_created = true;
      }
    }

    if (handle == 0) {
      result->Error("engine_create_failed",
                    "engine_create returned 0",
                    flutter::EncodableValue());
      return;
    }

    surface->engine_handle = handle;
    surface->width = width;
    surface->height = height;
    surface->layer_count = layer_count;
    surface->background_color_argb = background_color;

    if (needs_resize || surface->texture_id < 0) {
      UnregisterTextureLocked(surface);
      void* shared_handle = engine_create_present_dxgi_surface(
          handle, static_cast<uint32_t>(width), static_cast<uint32_t>(height));
      if (!shared_handle) {
        result->Error("engine_create_present_failed",
                      "engine_create_present_dxgi_surface returned null",
                      flutter::EncodableValue());
        return;
      }

      auto binding =
          std::make_shared<GpuSurfaceBinding>(shared_handle,
                                              static_cast<size_t>(width),
                                              static_cast<size_t>(height));

      FlutterDesktopTextureInfo texture_info{};
      texture_info.type = kFlutterDesktopGpuSurfaceTexture;
      texture_info.gpu_surface_config.struct_size =
          sizeof(FlutterDesktopGpuSurfaceTextureConfig);
      texture_info.gpu_surface_config.type =
          kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle;
      texture_info.gpu_surface_config.callback = GpuSurfaceBinding::Callback;
      texture_info.gpu_surface_config.user_data = binding.get();

      const int64_t texture_id =
          FlutterDesktopTextureRegistrarRegisterExternalTexture(
              texture_registrar_, &texture_info);
      if (texture_id < 0) {
        result->Error("register_texture_failed",
                      "RegisterExternalTexture returned < 0",
                      flutter::EncodableValue());
        return;
      }

      surface->binding = std::move(binding);
      surface->texture_id = texture_id;
    }

    if (engine_created || needs_resize || layer_count_changed) {
      engine_reset_canvas_with_layers(handle,
                                      static_cast<uint32_t>(layer_count),
                                      background_color);
    }

    flutter::EncodableMap response;
    response[flutter::EncodableValue("textureId")] =
        flutter::EncodableValue(surface->texture_id);
    response[flutter::EncodableValue("engineHandle")] =
        flutter::EncodableValue(static_cast<int64_t>(surface->engine_handle));
    response[flutter::EncodableValue("width")] =
        flutter::EncodableValue(surface->width);
    response[flutter::EncodableValue("height")] =
        flutter::EncodableValue(surface->height);
    response[flutter::EncodableValue("isNewEngine")] =
        flutter::EncodableValue(engine_created || needs_resize);
    result->Success(flutter::EncodableValue(response));
  }

  void HandleDisposeTexture(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string surface_id = GetSurfaceId(args);
    std::shared_ptr<SurfaceState> surface;
    {
      std::lock_guard<std::mutex> lock(surfaces_mutex_);
      auto it = surfaces_.find(surface_id);
      if (it != surfaces_.end()) {
        surface = it->second;
        surfaces_.erase(it);
      }
    }

    if (surface) {
      std::lock_guard<std::mutex> lock(surface->mutex);
      UnregisterTextureLocked(surface);
      if (surface->engine_handle != 0) {
        engine_dispose(surface->engine_handle);
        surface->engine_handle = 0;
      }
    }
    result->Success();
  }

  void DisposeAll() {
    std::vector<std::shared_ptr<SurfaceState>> entries;
    {
      std::lock_guard<std::mutex> lock(surfaces_mutex_);
      for (const auto& entry : surfaces_) {
        entries.push_back(entry.second);
      }
      surfaces_.clear();
    }

    for (const auto& surface : entries) {
      if (!surface) {
        continue;
      }
      std::lock_guard<std::mutex> lock(surface->mutex);
      UnregisterTextureLocked(surface);
      if (surface->engine_handle != 0) {
        engine_dispose(surface->engine_handle);
        surface->engine_handle = 0;
      }
    }
  }

  void FrameLoop() {
    while (running_.load()) {
      std::vector<std::shared_ptr<SurfaceState>> entries;
      {
        std::lock_guard<std::mutex> lock(surfaces_mutex_);
        for (const auto& entry : surfaces_) {
          entries.push_back(entry.second);
        }
      }
      for (const auto& surface : entries) {
        if (!surface) {
          continue;
        }
        const int64_t texture_id = surface->RefreshFrame();
        if (texture_id >= 0) {
          FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(
              texture_registrar_, texture_id);
        }
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(8));
    }
  }

  void UnregisterTextureLocked(const std::shared_ptr<SurfaceState>& surface) {
    if (!surface || surface->texture_id < 0) {
      return;
    }
    const int64_t texture_id = surface->texture_id;
    surface->texture_id = -1;

    auto binding = surface->binding;
    surface->binding.reset();
    if (!binding) {
      return;
    }

    auto* keepalive = new std::shared_ptr<GpuSurfaceBinding>(binding);
    FlutterDesktopTextureRegistrarUnregisterExternalTexture(
        texture_registrar_, texture_id, ReleaseBinding, keepalive);
  }

  FlutterDesktopTextureRegistrarRef texture_registrar_;
  std::mutex surfaces_mutex_;
  std::unordered_map<std::string, std::shared_ptr<SurfaceState>> surfaces_;
  std::atomic<bool> running_;
  std::thread frame_thread_;
};

// static
void RustLibMisaRinPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar,
    FlutterDesktopPluginRegistrarRef raw_registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<RustLibMisaRinPlugin>(
      FlutterDesktopRegistrarGetTextureRegistrar(raw_registrar));

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

RustLibMisaRinPlugin::RustLibMisaRinPlugin(
    FlutterDesktopTextureRegistrarRef texture_registrar)
    : impl_(std::make_unique<Impl>(texture_registrar)) {}

RustLibMisaRinPlugin::~RustLibMisaRinPlugin() = default;

void RustLibMisaRinPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  impl_->HandleMethodCall(method_call, std::move(result));
}

}  // namespace rust_lib_misa_rin

void RustLibMisaRinPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  rust_lib_misa_rin::RustLibMisaRinPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar),
      registrar);
}
