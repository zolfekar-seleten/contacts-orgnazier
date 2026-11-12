import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudFiles") {
      ICloudFiles.register(with: registrar)
    }
  }
}

/// Files in the app's iCloud Drive container, for backups and sync.
/// Paths are relative to the container ("Documents/Backups/…" shows in the
/// Files app; "Sync/…" stays hidden). All file work runs off the main thread.
final class ICloudFiles: NSObject {
  private let queue = DispatchQueue(label: "contacts-organizer.icloud", qos: .utility)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "contacts_organizer/icloud",
      binaryMessenger: registrar.messenger()
    )
    let instance = ICloudFiles()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    objc_setAssociatedObject(registrar, "ICloudFiles", instance, .OBJC_ASSOCIATION_RETAIN)
  }

  private func container() -> URL? {
    guard FileManager.default.ubiquityIdentityToken != nil else { return nil }
    return FileManager.default.url(forUbiquityContainerIdentifier: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      do {
        let value = try self.perform(call.method, args)
        DispatchQueue.main.async { result(value) }
      } catch let error as ICloudError {
        DispatchQueue.main.async {
          result(FlutterError(code: error.code, message: error.message, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func perform(_ method: String, _ args: [String: Any]) throws -> Any? {
    if method == "isAvailable" { return container() != nil }
    guard let root = container() else {
      throw ICloudError(code: "unavailable", message: "Sign in to iCloud with iCloud Drive turned on.")
    }
    func url(_ key: String) throws -> URL {
      guard let path = args[key] as? String, !path.contains("..") else {
        throw ICloudError(code: "args", message: "Missing \(key)")
      }
      return root.appendingPathComponent(path)
    }
    let fm = FileManager.default
    switch method {
    case "upload":
      let local = URL(fileURLWithPath: args["localPath"] as? String ?? "")
      let target = try url("remotePath")
      try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try coordinate(writing: target) { dest in
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: local, to: dest)
      }
      return nil

    case "list":
      let dir = try url("dir")
      guard let items = try? fm.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
        options: []
      ) else { return [] }
      return items.compactMap { item -> [String: Any]? in
        var name = item.lastPathComponent
        var downloaded = true
        // Not yet downloaded files appear as ".name.icloud" placeholders.
        if name.hasPrefix("."), name.hasSuffix(".icloud") {
          name = String(name.dropFirst().dropLast(".icloud".count))
          downloaded = false
        } else if name.hasPrefix(".") {
          return nil
        }
        let values = try? item.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return [
          "name": name,
          "size": values?.fileSize ?? 0,
          "modified": Int((values?.contentModificationDate ?? Date()).timeIntervalSince1970 * 1000),
          "downloaded": downloaded,
        ]
      }

    case "download":
      let source = try url("remotePath")
      let local = URL(fileURLWithPath: args["localPath"] as? String ?? "")
      try waitForDownload(source)
      try coordinate(reading: source) { src in
        if fm.fileExists(atPath: local.path) { try fm.removeItem(at: local) }
        try fm.copyItem(at: src, to: local)
      }
      return nil

    case "delete":
      let target = try url("remotePath")
      try coordinate(writing: target) { dest in
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
      }
      return nil

    default:
      throw ICloudError(code: "method", message: "Unknown method \(method)")
    }
  }

  /// Asks iCloud for a file that only exists as a placeholder, then waits
  /// (up to a minute) for it to arrive.
  private func waitForDownload(_ url: URL) throws {
    let fm = FileManager.default
    try? fm.startDownloadingUbiquitousItem(at: url)
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
      let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        .ubiquitousItemDownloadingStatus
      if status == .current || (status == nil && fm.fileExists(atPath: url.path)) { return }
      Thread.sleep(forTimeInterval: 0.3)
    }
    throw ICloudError(code: "timeout", message: "The file didn’t finish downloading from iCloud.")
  }

  private func coordinate(writing url: URL, _ body: (URL) throws -> Void) throws {
    var coordError: NSError?
    var bodyError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) {
      do { try body($0) } catch { bodyError = error }
    }
    if let e = coordError ?? bodyError { throw e }
  }

  private func coordinate(reading url: URL, _ body: (URL) throws -> Void) throws {
    var coordError: NSError?
    var bodyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) {
      do { try body($0) } catch { bodyError = error }
    }
    if let e = coordError ?? bodyError { throw e }
  }
}

struct ICloudError: Error {
  let code: String
  let message: String
}
