#include "flutter_window.h"

#include <optional>

#include <windows.h>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const wchar_t kTabletBridgeProp[] = L"MISARIN_TABLET_BRIDGE";
constexpr double kPenPressureMax = 1024.0;

double Clamp01(double value) {
  if (value < 0.0) {
    return 0.0;
  }
  if (value > 1.0) {
    return 1.0;
  }
  return value;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetupTabletChannel();

  flutter_view_hwnd_ = flutter_controller_->view()->GetNativeWindow();
  if (flutter_view_hwnd_ != nullptr) {
    SetPropW(flutter_view_hwnd_, kTabletBridgeProp, this);
    flutter_view_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
        flutter_view_hwnd_, GWLP_WNDPROC,
        reinterpret_cast<LONG_PTR>(FlutterWindow::FlutterViewSubclassProc)));
    RegisterPointerInputTarget(flutter_view_hwnd_, PT_PEN);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_view_hwnd_ != nullptr && flutter_view_proc_ != nullptr) {
    SetWindowLongPtr(flutter_view_hwnd_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(flutter_view_proc_));
    RemovePropW(flutter_view_hwnd_, kTabletBridgeProp);
    flutter_view_hwnd_ = nullptr;
    flutter_view_proc_ = nullptr;
  }
  tablet_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_POINTERDOWN || message == WM_POINTERUP ||
      message == WM_POINTERUPDATE) {
    HandlePointerMessage(message, wparam, lparam);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupTabletChannel() {
  if (tablet_channel_ || flutter_controller_ == nullptr) {
    return;
  }
  tablet_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "misarin/tablet_input",
          &flutter::StandardMethodCodec::GetInstance());
}

void FlutterWindow::HandlePointerMessage(UINT message,
                                         WPARAM wparam,
                                         LPARAM lparam) {
  if (!tablet_channel_) {
    return;
  }
  const UINT32 pointer_id = GET_POINTERID_WPARAM(wparam);
  POINTER_INFO pointer_info;
  if (!GetPointerInfo(pointer_id, &pointer_info)) {
    return;
  }
  if (pointer_info.pointerType != PT_PEN) {
    return;
  }
  POINTER_PEN_INFO pen_info;
  if (!GetPointerPenInfo(pointer_id, &pen_info)) {
    return;
  }
  double pressure = 0.0;
  if (pen_info.penMask & PEN_MASK_PRESSURE) {
    pressure = Clamp01(pen_info.pressure / kPenPressureMax);
  }
  const bool in_contact =
      (pointer_info.pointerFlags & POINTER_FLAG_INCONTACT) != 0;
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("tag")] =
      flutter::EncodableValue("winPointer");
  payload[flutter::EncodableValue("device")] =
      flutter::EncodableValue(static_cast<int>(pointer_id));
  payload[flutter::EncodableValue("pressure")] =
      flutter::EncodableValue(pressure);
  payload[flutter::EncodableValue("pressureMin")] =
      flutter::EncodableValue(0.0);
  payload[flutter::EncodableValue("pressureMax")] =
      flutter::EncodableValue(1.0);
  payload[flutter::EncodableValue("inContact")] =
      flutter::EncodableValue(in_contact);
  tablet_channel_->InvokeMethod(
      "tabletEvent",
      std::make_unique<flutter::EncodableValue>(std::move(payload)));
}

LRESULT CALLBACK FlutterWindow::FlutterViewSubclassProc(HWND window,
                                                        UINT message,
                                                        WPARAM wparam,
                                                        LPARAM lparam) {
  if (message == WM_POINTERDOWN || message == WM_POINTERUP ||
      message == WM_POINTERUPDATE) {
    auto* that = reinterpret_cast<FlutterWindow*>(
        GetPropW(window, kTabletBridgeProp));
    if (that != nullptr) {
      that->HandlePointerMessage(message, wparam, lparam);
    }
  }
  auto* that = reinterpret_cast<FlutterWindow*>(
      GetPropW(window, kTabletBridgeProp));
  if (that != nullptr && that->flutter_view_proc_ != nullptr) {
    return CallWindowProc(that->flutter_view_proc_, window, message, wparam,
                          lparam);
  }
  return DefWindowProc(window, message, wparam, lparam);
}
