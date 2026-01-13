import Cocoa
import CoreVideo
import FlutterMacOS
import Foundation

@_silgen_name("engine_poll_frame_ready")
private func engine_poll_frame_ready(_ engineHandle: UnsafeMutableRawPointer?) -> Bool

private final class RustCanvasTexture: NSObject, FlutterTexture {
  private let pixelBuffer: CVPixelBuffer
  private var frameCounter: UInt32 = 0

  init(width: Int, height: Int) {
    var buffer: CVPixelBuffer?

    let attributes: [CFString: Any] = [
      kCVPixelBufferIOSurfacePropertiesKey: [:],
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &buffer
    )

    guard status == kCVReturnSuccess, let resolved = buffer else {
      fatalError("Failed to create CVPixelBuffer: \(status)")
    }

    pixelBuffer = resolved
    super.init()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    renderTestPattern()
    return Unmanaged.passRetained(pixelBuffer)
  }

  private func renderTestPattern() {
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      return
    }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

    let frame = frameCounter
    frameCounter &+= 1

    let background: UInt32 = 0xFF202020
    let foreground: UInt32 = 0xFFFFFFFF
    let lineX = Int(frame % UInt32(width))

    for y in 0..<height {
      let rowPointer = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(
        to: UInt32.self
      )
      for x in 0..<width {
        rowPointer[x] = background
      }
      rowPointer[lineX] = foreground
    }
  }
}

private func rustCanvasDisplayLinkCallback(
  displayLink: CVDisplayLink,
  inNow: UnsafePointer<CVTimeStamp>,
  inOutputTime: UnsafePointer<CVTimeStamp>,
  flagsIn: CVOptionFlags,
  flagsOut: UnsafeMutablePointer<CVOptionFlags>,
  displayLinkContext: UnsafeMutableRawPointer?
) -> CVReturn {
  guard let displayLinkContext else {
    return kCVReturnError
  }
  autoreleasepool {
    let plugin = Unmanaged<RustLibMisaRinPlugin>.fromOpaque(displayLinkContext).takeUnretainedValue()
    plugin.onDisplayLinkTick()
  }
  return kCVReturnSuccess
}

public final class RustLibMisaRinPlugin: NSObject, FlutterPlugin {
  private static let channelName = "misarin/rust_canvas_texture"
  private static var didRegister = false

  private let textureRegistry: FlutterTextureRegistry
  private let texture: RustCanvasTexture
  private let textureId: Int64

  private var engineHandle: UnsafeMutableRawPointer?
  private var displayLink: CVDisplayLink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    if didRegister {
      return
    }
    didRegister = true

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    let instance = RustLibMisaRinPlugin(textureRegistry: registrar.textures)
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.startDisplayLink()
  }

  private init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
    self.texture = RustCanvasTexture(width: 512, height: 512)
    self.textureId = textureRegistry.register(texture)
    self.engineHandle = nil
    super.init()
  }

  deinit {
    if let displayLink {
      CVDisplayLinkStop(displayLink)
    }
    textureRegistry.unregisterTexture(textureId)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTextureId":
      result(textureId)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startDisplayLink() {
    var link: CVDisplayLink?
    let status = CVDisplayLinkCreateWithActiveCGDisplays(&link)
    guard status == kCVReturnSuccess, let link else {
      return
    }

    displayLink = link
    CVDisplayLinkSetOutputCallback(
      link,
      rustCanvasDisplayLinkCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )
    CVDisplayLinkStart(link)
  }

  fileprivate func onDisplayLinkTick() {
    if engine_poll_frame_ready(engineHandle) {
      textureRegistry.textureFrameAvailable(textureId)
    }
  }
}
