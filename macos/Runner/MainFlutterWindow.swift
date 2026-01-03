import Cocoa
import FlutterMacOS

private final class LoggingFlutterViewController: FlutterViewController {
  private var tabletChannel: FlutterMethodChannel?
  private var systemFontsChannel: FlutterMethodChannel?

  override func viewDidLoad() {
    super.viewDidLoad()
    configureTabletChannel()
    configureSystemFontsChannel()
  }

  private func configureTabletChannel() {
    if tabletChannel != nil {
      return
    }
    let engine = self.engine
    tabletChannel = FlutterMethodChannel(
      name: "misarin/tablet_input",
      binaryMessenger: engine.binaryMessenger
    )
  }

  private func configureSystemFontsChannel() {
    if systemFontsChannel != nil {
      return
    }
    let engine = self.engine
    let channel = FlutterMethodChannel(
      name: "misarin/system_fonts",
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getFamilies":
        let families = NSFontManager.shared.availableFontFamilies.sorted {
          $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        result(families)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    systemFontsChannel = channel
  }

  private func dispatchPointerEvent(tag: String, event: NSEvent, inContact: Bool) {
    if tabletChannel == nil {
      configureTabletChannel()
    }
    guard let channel = tabletChannel else {
      return
    }
    let payload: [String: Any] = [
      "tag": tag,
      "device": Int(event.deviceID),
      "pressure": Double(event.pressure),
      "pressureMin": 0.0,
      "pressureMax": 1.0,
      "inContact": inContact,
      "deviceType": Int(event.pointingDeviceType.rawValue),
    ]
    channel.invokeMethod("tabletEvent", arguments: payload)
  }

  override func tabletPoint(with event: NSEvent) {
    dispatchPointerEvent(tag: "tabletPoint", event: event, inContact: event.pressure > 0)
    super.tabletPoint(with: event)
  }

  override func tabletProximity(with event: NSEvent) {
    dispatchPointerEvent(tag: "tabletProximity", event: event, inContact: false)
    super.tabletProximity(with: event)
  }

  override func mouseMoved(with event: NSEvent) {
    dispatchPointerEvent(tag: "mouseMoved", event: event, inContact: false)
    super.mouseMoved(with: event)
  }

  override func mouseDragged(with event: NSEvent) {
    dispatchPointerEvent(tag: "mouseDragged", event: event, inContact: true)
    super.mouseDragged(with: event)
  }

  override func mouseDown(with event: NSEvent) {
    dispatchPointerEvent(tag: "mouseDown", event: event, inContact: true)
    super.mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    dispatchPointerEvent(tag: "mouseUp", event: event, inContact: false)
    super.mouseUp(with: event)
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = LoggingFlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
