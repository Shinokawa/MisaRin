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

@_silgen_name("engine_reset_canvas_with_layers")
private func engine_reset_canvas_with_layers(
  _ engineHandle: UInt64,
  _ layerCount: UInt32,
  _ backgroundColorArgb: UInt32
)

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

private final class RustCanvasSurfaceState {
  let surfaceId: String
  var texture: RustCanvasTexture
  var textureId: Int64?
  var textureWidth: Int
  var textureHeight: Int
  var engineHandle: UInt64
  var textureCache: CVMetalTextureCache?
  var presentTexture: CVMetalTexture?
  var initInProgress: Bool
  var pendingTextureInfoResults: [FlutterResult]

  init(surfaceId: String, width: Int, height: Int) {
    self.surfaceId = surfaceId
    self.texture = RustCanvasTexture(width: width, height: height)
    self.textureId = nil
    self.textureWidth = width
    self.textureHeight = height
    self.engineHandle = 0
    self.textureCache = nil
    self.presentTexture = nil
    self.initInProgress = false
    self.pendingTextureInfoResults = []
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
  private let engineStateLock = NSLock()
  private var surfaces: [String: RustCanvasSurfaceState] = [:]
  private var displayLink: CVDisplayLink?
  private let engineInitQueue = DispatchQueue(label: "misarin.canvas.engine-init", qos: .userInitiated)

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
    super.init()
  }

  deinit {
    if let displayLink {
      CVDisplayLinkStop(displayLink)
    }
    var handlesToDispose: [UInt64] = []
    var texturesToUnregister: [Int64] = []
    engineStateLock.lock()
    for entry in surfaces.values {
      if entry.engineHandle != 0 {
        handlesToDispose.append(entry.engineHandle)
      }
      if let id = entry.textureId {
        texturesToUnregister.append(id)
      }
    }
    surfaces.removeAll()
    engineStateLock.unlock()

    for id in texturesToUnregister {
      textureRegistry.unregisterTexture(id)
    }
    for handle in handlesToDispose {
      engine_dispose(handle)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTextureInfo":
      let requested = parseRequestedTextureInfo(arguments: call.arguments)
      getTextureInfo(
        surfaceId: requested.surfaceId,
        width: requested.width,
        height: requested.height,
        layerCount: requested.layerCount,
        backgroundColor: requested.backgroundColor,
        result: result
      )
    case "disposeTexture":
      let surfaceId = parseSurfaceId(arguments: call.arguments)
      disposeSurface(surfaceId: surfaceId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func parseRequestedTextureInfo(
    arguments: Any?
  ) -> (surfaceId: String, width: Int, height: Int, layerCount: Int, backgroundColor: UInt32) {
    let fallbackWidth = 512
    let fallbackHeight = 512
    let fallbackSurfaceId = "default"
    let fallbackLayerCount = 1
    let fallbackBackground: UInt32 = 0xFFFFFFFF
    guard let dict = arguments as? [String: Any] else {
      return (fallbackSurfaceId, fallbackWidth, fallbackHeight, fallbackLayerCount, fallbackBackground)
    }
    let w = (dict["width"] as? NSNumber)?.intValue ?? fallbackWidth
    let h = (dict["height"] as? NSNumber)?.intValue ?? fallbackHeight
    let layerCountRaw = (dict["layerCount"] as? NSNumber)?.intValue ?? fallbackLayerCount
    let layerCount = max(1, min(layerCountRaw, 1024))
    let backgroundRaw = (dict["backgroundColorArgb"] as? NSNumber)?.uint64Value ?? UInt64(fallbackBackground)
    let backgroundColor = UInt32(truncatingIfNeeded: backgroundRaw)
    let surfaceIdValue = dict["surfaceId"]
    let surfaceId: String
    if let str = surfaceIdValue as? String, !str.isEmpty {
      surfaceId = str
    } else if let num = surfaceIdValue as? NSNumber {
      surfaceId = num.stringValue
    } else {
      surfaceId = fallbackSurfaceId
    }
    return (
      surfaceId,
      max(1, min(w, 16384)),
      max(1, min(h, 16384)),
      layerCount,
      backgroundColor
    )
  }

  private func parseSurfaceId(arguments: Any?) -> String {
    let fallbackSurfaceId = "default"
    guard let dict = arguments as? [String: Any] else {
      return fallbackSurfaceId
    }
    let surfaceIdValue = dict["surfaceId"]
    if let str = surfaceIdValue as? String, !str.isEmpty {
      return str
    }
    if let num = surfaceIdValue as? NSNumber {
      return num.stringValue
    }
    return fallbackSurfaceId
  }

  private func getTextureInfo(
    surfaceId: String,
    width: Int,
    height: Int,
    layerCount: Int,
    backgroundColor: UInt32,
    result: @escaping FlutterResult
  ) {
    engineStateLock.lock()
    let entry: RustCanvasSurfaceState
    if let existing = surfaces[surfaceId] {
      entry = existing
    } else {
      let created = RustCanvasSurfaceState(surfaceId: surfaceId, width: width, height: height)
      surfaces[surfaceId] = created
      entry = created
    }
    if entry.engineHandle != 0 && entry.textureWidth == width && entry.textureHeight == height {
      if entry.textureId == nil {
        entry.textureId = textureRegistry.register(entry.texture)
      }
      let currentTextureId = entry.textureId!
      let currentWidth = entry.textureWidth
      let currentHeight = entry.textureHeight
      engineStateLock.unlock()
      result([
        "textureId": currentTextureId,
        "engineHandle": NSNumber(value: entry.engineHandle),
        "width": currentWidth,
        "height": currentHeight,
        "isNewEngine": false,
      ])
      return
    }
    if entry.initInProgress {
      entry.pendingTextureInfoResults.append(result)
      engineStateLock.unlock()
      return
    }
    entry.initInProgress = true
    entry.pendingTextureInfoResults.append(result)
    let handleToDispose = entry.engineHandle
    let needsResize = entry.textureWidth != width || entry.textureHeight != height
    let oldTextureId = needsResize ? entry.textureId : nil
    let existingTexture = entry.texture
    entry.engineHandle = 0
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
        : existingTexture

      let resolvedWidth = CVPixelBufferGetWidth(targetTexture.pixelBuffer)
      let resolvedHeight = CVPixelBufferGetHeight(targetTexture.pixelBuffer)

      let handle = engine_create(UInt32(resolvedWidth), UInt32(resolvedHeight))
      if handle == 0 {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            surfaceId: surfaceId,
            response: FlutterError(code: "engine_create_failed", message: "engine_create returned 0", details: nil)
          )
        }
        return
      }

      guard let devicePtr = engine_get_mtl_device(handle) else {
        DispatchQueue.main.async {
          self.completePendingTextureInfoRequests(
            surfaceId: surfaceId,
            response: FlutterError(
              code: "engine_get_mtl_device_failed",
              message: "engine_get_mtl_device returned null",
              details: nil
            )
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
            surfaceId: surfaceId,
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
            surfaceId: surfaceId,
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
            surfaceId: surfaceId,
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
      let resolvedLayerCount = max(1, layerCount)
      engine_reset_canvas_with_layers(
        handle,
        UInt32(resolvedLayerCount),
        backgroundColor
      )

      DispatchQueue.main.async {
        self.engineStateLock.lock()
        guard let entry = self.surfaces[surfaceId] else {
          self.engineStateLock.unlock()
          self.engineInitQueue.async {
            engine_dispose(handle)
          }
          return
        }
        if needsResize {
          if let oldTextureId {
            self.textureRegistry.unregisterTexture(oldTextureId)
          }
          entry.texture = targetTexture
          entry.textureWidth = resolvedWidth
          entry.textureHeight = resolvedHeight
        } else if entry.textureWidth != resolvedWidth || entry.textureHeight != resolvedHeight {
          entry.textureWidth = resolvedWidth
          entry.textureHeight = resolvedHeight
        }
        if entry.textureId == nil || needsResize {
          entry.textureId = self.textureRegistry.register(entry.texture)
        }
        let resolvedTextureId = entry.textureId ?? self.textureRegistry.register(entry.texture)
        entry.textureId = resolvedTextureId
        entry.engineHandle = handle
        entry.textureCache = resolvedCache
        entry.presentTexture = resolvedCvTexture
        self.engineStateLock.unlock()
        self.completePendingTextureInfoRequests(surfaceId: surfaceId, response: [
          "textureId": resolvedTextureId,
          "engineHandle": NSNumber(value: handle),
          "width": resolvedWidth,
          "height": resolvedHeight,
          "isNewEngine": true,
        ])
      }
    }
  }

  private func disposeSurface(surfaceId: String, result: @escaping FlutterResult) {
    var handleToDispose: UInt64 = 0
    var textureIdToUnregister: Int64?
    var pendingResults: [FlutterResult] = []
    engineStateLock.lock()
    if let entry = surfaces.removeValue(forKey: surfaceId) {
      handleToDispose = entry.engineHandle
      textureIdToUnregister = entry.textureId
      pendingResults = entry.pendingTextureInfoResults
      entry.pendingTextureInfoResults.removeAll()
      entry.initInProgress = false
    }
    engineStateLock.unlock()

    if let id = textureIdToUnregister {
      textureRegistry.unregisterTexture(id)
    }
    if handleToDispose != 0 {
      engineInitQueue.async {
        engine_dispose(handleToDispose)
      }
    }
    for callback in pendingResults {
      callback(
        FlutterError(
          code: "surface_disposed",
          message: "surface disposed",
          details: nil
        )
      )
    }
    result(nil)
  }

  private func completePendingTextureInfoRequests(surfaceId: String, response: Any?) {
    engineStateLock.lock()
    guard let entry = surfaces[surfaceId] else {
      engineStateLock.unlock()
      return
    }
    let callbacks = entry.pendingTextureInfoResults
    entry.pendingTextureInfoResults.removeAll()
    entry.initInProgress = false
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
    var entries: [(UInt64, Int64)] = []
    engineStateLock.lock()
    for entry in surfaces.values {
      if entry.engineHandle != 0, let textureId = entry.textureId {
        entries.append((entry.engineHandle, textureId))
      }
    }
    engineStateLock.unlock()
    for (handle, textureId) in entries {
      if engine_poll_frame_ready(handle) {
        textureRegistry.textureFrameAvailable(textureId)
      }
    }
  }
}
