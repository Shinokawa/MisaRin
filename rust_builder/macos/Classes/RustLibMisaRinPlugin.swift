import Cocoa
import CoreVideo
import FlutterMacOS
import Foundation
import Metal

@_silgen_name("engine_create")
private func engine_create(_ width: UInt32, _ height: UInt32) -> UInt64

@_silgen_name("engine_get_mtl_device")
private func engine_get_mtl_device(_ engineHandle: UInt64) -> UnsafeMutableRawPointer?

@_silgen_name("engine_attach_present_texture")
private func engine_attach_present_texture(
  _ engineHandle: UInt64,
  _ mtlTexturePtr: UnsafeMutableRawPointer?,
  _ width: UInt32,
  _ height: UInt32,
  _ bytesPerRow: UInt32
)

@_silgen_name("engine_dispose")
private func engine_dispose(_ engineHandle: UInt64)

@_silgen_name("engine_poll_frame_ready")
private func engine_poll_frame_ready(_ engineHandle: UInt64) -> Bool

private final class RustCanvasTexture: NSObject, FlutterTexture {
  fileprivate let pixelBuffer: CVPixelBuffer

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
    return Unmanaged.passRetained(pixelBuffer)
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
  private var texture: RustCanvasTexture
  private var textureId: Int64
  private var textureWidth: Int
  private var textureHeight: Int

  private let engineStateLock = NSLock()
  private var engineHandle: UInt64 = 0
  private var textureCache: CVMetalTextureCache?
  private var presentTexture: CVMetalTexture?
  private var displayLink: CVDisplayLink?
  private let engineInitQueue = DispatchQueue(label: "misarin.canvas.engine-init", qos: .userInitiated)
  private var engineInitInProgress = false
  private var pendingTextureInfoResults: [FlutterResult] = []

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
    let initialWidth = 512
    let initialHeight = 512
    self.textureWidth = initialWidth
    self.textureHeight = initialHeight
    self.texture = RustCanvasTexture(width: initialWidth, height: initialHeight)
    self.textureId = textureRegistry.register(texture)
    super.init()
  }

  deinit {
    if let displayLink {
      CVDisplayLinkStop(displayLink)
    }
    let handleToDispose: UInt64
    engineStateLock.lock()
    handleToDispose = engineHandle
    engineHandle = 0
    engineStateLock.unlock()
    if handleToDispose != 0 {
      engine_dispose(handleToDispose)
    }
    textureRegistry.unregisterTexture(textureId)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTextureInfo":
      let requested = parseRequestedTextureSize(arguments: call.arguments)
      getTextureInfo(width: requested.width, height: requested.height, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func parseRequestedTextureSize(arguments: Any?) -> (width: Int, height: Int) {
    let fallbackWidth = 512
    let fallbackHeight = 512
    guard let dict = arguments as? [String: Any] else {
      return (fallbackWidth, fallbackHeight)
    }
    let w = (dict["width"] as? NSNumber)?.intValue ?? fallbackWidth
    let h = (dict["height"] as? NSNumber)?.intValue ?? fallbackHeight
    return (max(1, min(w, 16384)), max(1, min(h, 16384)))
  }

  private func getTextureInfo(width: Int, height: Int, result: @escaping FlutterResult) {
    engineStateLock.lock()
    let existingHandle = engineHandle
    if existingHandle != 0 && textureWidth == width && textureHeight == height {
      let currentTextureId = textureId
      let currentWidth = textureWidth
      let currentHeight = textureHeight
      engineStateLock.unlock()
      result([
        "textureId": currentTextureId,
        "engineHandle": NSNumber(value: existingHandle),
        "width": currentWidth,
        "height": currentHeight,
      ])
      return
    }
    if engineInitInProgress {
      pendingTextureInfoResults.append(result)
      engineStateLock.unlock()
      return
    }
    engineInitInProgress = true
    pendingTextureInfoResults.append(result)
    let handleToDispose = engineHandle
    engineHandle = 0
    let oldTextureId = textureId
    let needsResize = (textureWidth != width || textureHeight != height)
    engineStateLock.unlock()

    engineInitQueue.async { [weak self] in
      guard let self else {
        return
      }

      if handleToDispose != 0 {
        engine_dispose(handleToDispose)
      }

      let targetTexture: RustCanvasTexture = needsResize
        ? RustCanvasTexture(width: width, height: height)
        : self.texture

      let resolvedWidth = CVPixelBufferGetWidth(targetTexture.pixelBuffer)
      let resolvedHeight = CVPixelBufferGetHeight(targetTexture.pixelBuffer)

      let handle = engine_create(UInt32(resolvedWidth), UInt32(resolvedHeight))
      if handle == 0 {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            response: FlutterError(code: "engine_create_failed", message: "engine_create returned 0", details: nil)
          )
        }
        return
      }

      guard let devicePtr = engine_get_mtl_device(handle) else {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            response: FlutterError(code: "engine_get_mtl_device_failed", message: "engine_get_mtl_device returned null", details: nil)
          )
        }
        return
      }

      let mtlDevice = Unmanaged<AnyObject>.fromOpaque(devicePtr).takeUnretainedValue() as! MTLDevice

      var cache: CVMetalTextureCache?
      let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, mtlDevice, nil, &cache)
      guard cacheStatus == kCVReturnSuccess, let resolvedCache = cache else {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            response: FlutterError(
              code: "cv_metal_texture_cache_failed",
              message: "CVMetalTextureCacheCreate failed: \(cacheStatus)",
              details: nil
            )
          )
        }
        return
      }

      var cvTexture: CVMetalTexture?
      let bytesPerRow = CVPixelBufferGetBytesPerRow(targetTexture.pixelBuffer)
      let textureAttributes: [CFString: Any] = [
        kCVMetalTextureUsage: NSNumber(
          value: MTLTextureUsage.shaderRead.rawValue
            | MTLTextureUsage.shaderWrite.rawValue
            | MTLTextureUsage.renderTarget.rawValue
        )
      ]

      let texStatus = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        resolvedCache,
        targetTexture.pixelBuffer,
        textureAttributes as CFDictionary,
        .bgra8Unorm,
        resolvedWidth,
        resolvedHeight,
        0,
        &cvTexture
      )

      guard texStatus == kCVReturnSuccess, let resolvedCvTexture = cvTexture else {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            response: FlutterError(
              code: "cv_metal_texture_failed",
              message: "CVMetalTextureCacheCreateTextureFromImage failed: \(texStatus)",
              details: nil
            )
          )
        }
        return
      }

      guard let mtlTexture = CVMetalTextureGetTexture(resolvedCvTexture) else {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            response: FlutterError(
              code: "cv_metal_texture_get_failed",
              message: "CVMetalTextureGetTexture returned null",
              details: nil
            )
          )
        }
        return
      }

      let texturePtr = Unmanaged.passRetained(mtlTexture as AnyObject).toOpaque()
      engine_attach_present_texture(
        handle,
        texturePtr,
        UInt32(resolvedWidth),
        UInt32(resolvedHeight),
        UInt32(bytesPerRow)
      )

      DispatchQueue.main.async {
        self.engineStateLock.lock()
        if needsResize {
          if oldTextureId != 0 {
            self.textureRegistry.unregisterTexture(oldTextureId)
          }
          self.texture = targetTexture
          self.textureId = self.textureRegistry.register(targetTexture)
          self.textureWidth = resolvedWidth
          self.textureHeight = resolvedHeight
        }
        self.engineHandle = handle
        self.engineInitInProgress = false
        self.engineStateLock.unlock()
        self.textureCache = resolvedCache
        self.presentTexture = resolvedCvTexture
        self.completePendingTextureInfoRequests(response: [
          "textureId": self.textureId,
          "engineHandle": NSNumber(value: handle),
          "width": resolvedWidth,
          "height": resolvedHeight,
        ])
      }
    }
  }

  private func completePendingTextureInfoRequests(response: Any?) {
    engineStateLock.lock()
    let callbacks = pendingTextureInfoResults
    pendingTextureInfoResults.removeAll()
    engineInitInProgress = false
    engineStateLock.unlock()

    for callback in callbacks {
      callback(response)
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
    let handle: UInt64
    let currentTextureId: Int64
    engineStateLock.lock()
    handle = engineHandle
    currentTextureId = textureId
    engineStateLock.unlock()
    if handle != 0 && currentTextureId != 0 && engine_poll_frame_ready(handle) {
      textureRegistry.textureFrameAvailable(currentTextureId)
    }
  }
}
