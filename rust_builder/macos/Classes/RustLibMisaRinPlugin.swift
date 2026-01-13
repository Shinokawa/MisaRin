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
  private let texture: RustCanvasTexture
  private let textureId: Int64

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
    self.texture = RustCanvasTexture(width: 512, height: 512)
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
      getTextureInfo(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getTextureInfo(result: @escaping FlutterResult) {
    engineStateLock.lock()
    let existingHandle = engineHandle
    if existingHandle != 0 {
      engineStateLock.unlock()
      result([
        "textureId": textureId,
        "engineHandle": NSNumber(value: existingHandle),
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
    engineStateLock.unlock()

    engineInitQueue.async { [weak self] in
      guard let self else {
        return
      }

      let width = CVPixelBufferGetWidth(self.texture.pixelBuffer)
      let height = CVPixelBufferGetHeight(self.texture.pixelBuffer)

      let handle = engine_create(UInt32(width), UInt32(height))
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
      let bytesPerRow = CVPixelBufferGetBytesPerRow(self.texture.pixelBuffer)
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
        self.texture.pixelBuffer,
        textureAttributes as CFDictionary,
        .bgra8Unorm,
        width,
        height,
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
        UInt32(width),
        UInt32(height),
        UInt32(bytesPerRow)
      )

      DispatchQueue.main.async {
        self.engineStateLock.lock()
        self.engineHandle = handle
        self.engineInitInProgress = false
        self.engineStateLock.unlock()
        self.textureCache = resolvedCache
        self.presentTexture = resolvedCvTexture
        self.completePendingTextureInfoRequests(response: [
          "textureId": self.textureId,
          "engineHandle": NSNumber(value: handle),
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
    engineStateLock.lock()
    handle = engineHandle
    engineStateLock.unlock()
    if handle != 0 && engine_poll_frame_ready(handle) {
      textureRegistry.textureFrameAvailable(textureId)
    }
  }
}
