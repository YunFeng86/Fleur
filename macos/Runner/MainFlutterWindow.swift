import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var localeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupLocaleChannel(controller: flutterViewController)

    super.awakeFromNib()
  }

  private func setupLocaleChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "flutter_reader/app_locale",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setPreferredLanguage":
        let args = call.arguments as? [String: Any]
        let tag = args?["localeTag"] as? String
        let normalized = Self.normalizeLocaleTag(tag)
        if let language = normalized {
          UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
          UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    localeChannel = channel
  }

  private static func normalizeLocaleTag(_ tag: String?) -> String? {
    guard let raw = tag?.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
      return nil
    }
    let normalized = raw.replacingOccurrences(of: "_", with: "-")
    let lower = normalized.lowercased()
    if lower.hasPrefix("zh") {
      let parts = lower.split(separator: "-").map { String($0) }
      if parts.contains("hant") || parts.contains("tw") || parts.contains("hk") || parts.contains("mo") {
        return "zh-Hant"
      }
      if parts.contains("hans") || parts.contains("cn") || parts.contains("sg") || parts.contains("my") {
        return "zh-Hans"
      }
      return "zh-Hans"
    }
    if lower.hasPrefix("en") {
      return "en"
    }
    return normalized
  }
}
