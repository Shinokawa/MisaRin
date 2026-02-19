import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIPencilInteractionDelegate {
  private var tabletChannel: FlutterMethodChannel?
  private var pencilInteraction: UIPencilInteraction?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      tabletChannel = FlutterMethodChannel(
        name: "misarin/tablet_input",
        binaryMessenger: controller.binaryMessenger
      )
      if #available(iOS 12.1, *) {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        controller.view.addInteraction(interaction)
        pencilInteraction = interaction
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 12.1, *)
  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    tabletChannel?.invokeMethod("pencilDoubleTap", arguments: nil)
  }
}
