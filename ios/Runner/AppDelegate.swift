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
    let storageChannel = FlutterMethodChannel(
      name: "com.codefrog.fpvmanager/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "publicCachePath" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        result(try Self.publicCachePath())
      } catch {
        result(FlutterError(code: "public-cache-path",
                            message: "Unable to open local map and public-data storage",
                            details: nil))
      }
    }
  }

  private static func publicCachePath() throws -> String {
    let files = FileManager.default
    let support = try files.url(for: .applicationSupportDirectory,
                                in: .userDomainMask, appropriateFor: nil, create: true)
    var cache = support.appendingPathComponent("FPVManagerPublicCache", isDirectory: true)
    try files.createDirectory(at: cache, withIntermediateDirectories: true)
    var options = URLResourceValues()
    options.isExcludedFromBackup = true
    try cache.setResourceValues(options)

    let name = "fpvmanager_osint_cache.sqlite"
    let destination = cache.appendingPathComponent(name)
    let documents = try files.url(for: .documentDirectory,
                                  in: .userDomainMask, appropriateFor: nil, create: true)
    let legacy = documents.appendingPathComponent(name)
    if !files.fileExists(atPath: destination.path) && files.fileExists(atPath: legacy.path) {
      // Open SQLite only after moving the main file. If an earlier attempt
      // moved only a journal, leave it in place and resume the other moves.
      for suffix in ["-wal", "-shm", "-journal", ""] {
        let source = documents.appendingPathComponent(name + suffix)
        if files.fileExists(atPath: source.path) {
          try files.moveItem(at: source, to: cache.appendingPathComponent(name + suffix))
        }
      }
    }
    return destination.path
  }
}
