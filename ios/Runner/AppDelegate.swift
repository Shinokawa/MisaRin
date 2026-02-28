import Flutter
import UIKit

private final class PencilMotionCaptureRecognizer: UIGestureRecognizer {
  var packetHandler: (([String: Any]) -> Void)?

  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
    false
  }

  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
    false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    emitPacket(for: touches, with: event, phase: "began")
    state = .began
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    emitPacket(for: touches, with: event, phase: "moved")
    state = .changed
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    emitPacket(for: touches, with: event, phase: "ended")
    state = .ended
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    emitPacket(for: touches, with: event, phase: "cancelled")
    state = .cancelled
  }

  private func emitPacket(for touches: Set<UITouch>, with event: UIEvent?, phase: String) {
    guard let hostView = view else {
      return
    }
    guard let touch = touches.first(where: { $0.type == .pencil }) else {
      return
    }

    let point = touch.location(in: hostView)
    let rawCoalesced = event?.coalescedTouches(for: touch) ?? []
    let rawPredicted = event?.predictedTouches(for: touch) ?? []
    let rawCoalescedPencilCount = rawCoalesced.reduce(0) { partial, item in
      partial + (item.type == .pencil ? 1 : 0)
    }
    let rawPredictedPencilCount = rawPredicted.reduce(0) { partial, item in
      partial + (item.type == .pencil ? 1 : 0)
    }
    let coalesced = serialize(touches: rawCoalesced, in: hostView)
    let predicted = serialize(touches: rawPredicted, in: hostView)
    let inContact = phase == "began" || phase == "moved"
    let payload: [String: Any] = [
      "phase": phase,
      "touchId": touch.hash,
      "x": point.x,
      "y": point.y,
      "pressure": normalizedPressure(for: touch),
      "inContact": inContact,
      "coalesced": coalesced,
      "predicted": predicted,
      "rawCoalescedCount": rawCoalesced.count,
      "rawPredictedCount": rawPredicted.count,
      "rawCoalescedPencilCount": rawCoalescedPencilCount,
      "rawPredictedPencilCount": rawPredictedPencilCount,
    ]
    packetHandler?(payload)
  }

  private func serialize(touches: [UITouch]?, in hostView: UIView) -> [[String: Any]] {
    guard let touches else {
      return []
    }
    var items: [[String: Any]] = []
    items.reserveCapacity(min(touches.count, 24))
    for touch in touches.prefix(24) where touch.type == .pencil {
      let point = touch.location(in: hostView)
      items.append([
        "x": point.x,
        "y": point.y,
        "pressure": normalizedPressure(for: touch),
      ])
    }
    return items
  }

  private func normalizedPressure(for touch: UITouch) -> Double {
    let force = max(0.0, Double(touch.force))
    let maxForce = max(0.0001, Double(touch.maximumPossibleForce))
    if !force.isFinite || !maxForce.isFinite {
      return 0.0
    }
    return min(max(force / maxForce, 0.0), 1.0)
  }
}

private final class PencilMotionObserver {
  private weak var hostView: UIView?
  private var recognizer: PencilMotionCaptureRecognizer?

  init(hostView: UIView, packetHandler: @escaping ([String: Any]) -> Void) {
    self.hostView = hostView
    let recognizer = PencilMotionCaptureRecognizer()
    recognizer.packetHandler = packetHandler
    hostView.addGestureRecognizer(recognizer)
    self.recognizer = recognizer
  }

  deinit {
    if let recognizer, let hostView {
      hostView.removeGestureRecognizer(recognizer)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, UIPencilInteractionDelegate {
  private var tabletChannel: FlutterMethodChannel?
  private var pencilInteraction: UIPencilInteraction?
  private var pencilMotionObserver: PencilMotionObserver?

  private func findFlutterViewController(
    in controller: UIViewController?
  ) -> FlutterViewController? {
    guard let controller else {
      return nil
    }
    if let flutterController = controller as? FlutterViewController {
      return flutterController
    }
    if let navigation = controller as? UINavigationController {
      for child in navigation.viewControllers {
        if let flutterController = findFlutterViewController(in: child) {
          return flutterController
        }
      }
    }
    if let tabs = controller as? UITabBarController {
      for child in tabs.viewControllers ?? [] {
        if let flutterController = findFlutterViewController(in: child) {
          return flutterController
        }
      }
    }
    for child in controller.children {
      if let flutterController = findFlutterViewController(in: child) {
        return flutterController
      }
    }
    if let presented = controller.presentedViewController {
      if let flutterController = findFlutterViewController(in: presented) {
        return flutterController
      }
    }
    return nil
  }

  private func resolveFlutterViewController() -> FlutterViewController? {
    if let controller = findFlutterViewController(in: window?.rootViewController) {
      return controller
    }
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else {
          continue
        }
        for candidate in windowScene.windows {
          if let controller = findFlutterViewController(in: candidate.rootViewController) {
            return controller
          }
        }
      }
    } else {
      if let controller = findFlutterViewController(
        in: UIApplication.shared.keyWindow?.rootViewController
      ) {
        return controller
      }
    }
    return nil
  }

  private func installPencilBridgeIfNeeded() {
    guard let controller = resolveFlutterViewController() else {
      return
    }
    if tabletChannel == nil {
      tabletChannel = FlutterMethodChannel(
        name: "misarin/tablet_input",
        binaryMessenger: controller.binaryMessenger
      )
    }
    if #available(iOS 12.1, *) {
      if pencilInteraction == nil {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        controller.view.addInteraction(interaction)
        pencilInteraction = interaction
      }
    }
    if pencilMotionObserver == nil {
      pencilMotionObserver = PencilMotionObserver(hostView: controller.view) { [weak self] payload in
        self?.tabletChannel?.invokeMethod("pencilMotion", arguments: payload)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    installPencilBridgeIfNeeded()
    GeneratedPluginRegistrant.register(with: self)
    installPencilBridgeIfNeeded()
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    DispatchQueue.main.async { [weak self] in
      self?.installPencilBridgeIfNeeded()
    }
    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    installPencilBridgeIfNeeded()
  }

  @available(iOS 12.1, *)
  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    tabletChannel?.invokeMethod("pencilDoubleTap", arguments: nil)
  }
}
