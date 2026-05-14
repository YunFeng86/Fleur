import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let defaultTrafficLightTargetCenterY: CGFloat = 24

  private var localeChannel: FlutterMethodChannel?
  private var windowControlsChannel: FlutterMethodChannel?
  private var trafficLightTargetCenterY = MainFlutterWindow.defaultTrafficLightTargetCenterY
  private var trafficLightAlignmentScheduled = false
  private var originalWindowButtonXCoordinates: [NSWindow.ButtonType: CGFloat] = [:]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupLocaleChannel(controller: flutterViewController)
    setupWindowControlsChannel(controller: flutterViewController)
    setupTrafficLightAlignmentObservers()

    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func setupLocaleChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.cloudwind.fleur/app_locale",
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

  private func setupWindowControlsChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.cloudwind.fleur/window_controls",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "alignTrafficLights":
        guard let self else {
          result(
            FlutterError(
              code: "window_unavailable",
              message: "The macOS window is no longer available.",
              details: nil
            )
          )
          return
        }
        let args = call.arguments as? [String: Any]
        let targetCenterY =
          Self.cgFloatArgument(args?["targetCenterY"]) ?? Self.defaultTrafficLightTargetCenterY
        self.trafficLightTargetCenterY = targetCenterY
        self.alignTrafficLights(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowControlsChannel = channel
  }

  private func setupTrafficLightAlignmentObservers() {
    let notifications: [NSNotification.Name] = [
      NSWindow.willStartLiveResizeNotification,
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didChangeScreenNotification,
      NSWindow.didChangeBackingPropertiesNotification,
    ]
    for notification in notifications {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidNeedTrafficLightAlignment(_:)),
        name: notification,
        object: self
      )
    }
  }

  @objc private func windowDidNeedTrafficLightAlignment(_ notification: Notification) {
    scheduleTrafficLightAlignment()
  }

  private func scheduleTrafficLightAlignment() {
    if trafficLightAlignmentScheduled {
      return
    }

    trafficLightAlignmentScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.trafficLightAlignmentScheduled = false
      _ = self.applyTrafficLightAlignment()
    }
  }

  private func alignTrafficLights(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "The macOS window is no longer available.",
            details: nil
          )
        )
        return
      }

      result(self.applyTrafficLightAlignment())
    }
  }

  private func applyTrafficLightAlignment() -> Bool {
    let buttonTypes: [NSWindow.ButtonType] = [
      .closeButton,
      .miniaturizeButton,
      .zoomButton,
    ]
    var alignedCount = 0

    for buttonType in buttonTypes {
      guard let button = self.standardWindowButton(buttonType),
            let buttonSuperview = button.superview else {
        continue
      }
      if self.originalWindowButtonXCoordinates[buttonType] == nil {
        self.originalWindowButtonXCoordinates[buttonType] = button.frame.origin.x
      }
      guard let originalX = self.originalWindowButtonXCoordinates[buttonType] else {
        continue
      }

      var frame = button.frame
      let nextOrigin = CGPoint(
        x: originalX,
        y: Self.windowButtonOriginY(
          targetCenterY: trafficLightTargetCenterY,
          buttonHeight: frame.height,
          buttonSuperview: buttonSuperview,
          windowContentSuperview: self.contentView?.superview
        )
      )
      if abs(frame.origin.x - nextOrigin.x) > 0.5 ||
        abs(frame.origin.y - nextOrigin.y) > 0.5 {
        frame.origin = nextOrigin
        button.setFrameOrigin(frame.origin)
      }
      alignedCount += 1
    }

    return alignedCount == buttonTypes.count
  }

  private static func windowButtonOriginY(
    targetCenterY: CGFloat,
    buttonHeight: CGFloat,
    buttonSuperview: NSView,
    windowContentSuperview: NSView?
  ) -> CGFloat {
    let referenceView = windowContentSuperview ?? buttonSuperview
    let centerYInReference: CGFloat
    if referenceView.isFlipped {
      centerYInReference = targetCenterY
    } else {
      centerYInReference = referenceView.bounds.height - targetCenterY
    }
    let centerInButtonSuperview = buttonSuperview.convert(
      CGPoint(x: 0, y: centerYInReference),
      from: referenceView
    )

    return centerInButtonSuperview.y - (buttonHeight / 2)
  }

  private static func cgFloatArgument(_ value: Any?) -> CGFloat? {
    if let number = value as? NSNumber {
      return CGFloat(number.doubleValue)
    }
    return nil
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
