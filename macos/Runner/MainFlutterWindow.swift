import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let defaultTrafficLightCenterY: CGFloat = 24
  private static let defaultTrafficLightSafeInset: CGFloat = 72
  private static let defaultClickSafeTopInset: CGFloat = 0
  private static let defaultFullscreenClickSafeTopInset: CGFloat = 8
  private static let defaultTitlebarDragHeight: CGFloat = 48
  private static let trafficLightSafeGap: CGFloat = 8
  private static let trafficLightVisualLockTolerance: CGFloat = 0.5

  private var localeChannel: FlutterMethodChannel?
  private var windowControlsChannel: FlutterMethodChannel?
  private var titlebarMetricsNotificationScheduled = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupLocaleChannel(controller: flutterViewController)
    setupWindowControlsChannel(controller: flutterViewController)
    setupTitlebarChromeObservers()

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
      case "configureTitlebarChrome":
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
        result(self.configureTitlebarChrome())
      case "getTitlebarChromeMetrics":
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
        result(self.titlebarChromeMetrics())
      case "performWindowDrag":
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
        self.performWindowDrag()
        result(nil)
      case "performWindowZoom":
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
        self.performZoom(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowControlsChannel = channel
  }

  private func configureTitlebarChrome() -> [String: Any] {
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.toolbar = nil

    let metrics = titlebarChromeMetrics()
    scheduleTitlebarChromeMetricsNotification()
    return metrics
  }

  private func setupTitlebarChromeObservers() {
    let notifications: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.willEnterFullScreenNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didChangeScreenNotification,
      NSWindow.didChangeBackingPropertiesNotification,
    ]
    for notification in notifications {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidNeedTitlebarChromeUpdate(_:)),
        name: notification,
        object: self
      )
    }
  }

  @objc private func windowDidNeedTitlebarChromeUpdate(_ notification: Notification) {
    switch notification.name {
    case NSWindow.willEnterFullScreenNotification,
         NSWindow.didEnterFullScreenNotification:
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.willExitFullScreenNotification:
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.didExitFullScreenNotification:
      notifyTitlebarChromeMetrics(isFullScreen: false)
      scheduleTitlebarChromeMetricsNotification()
    default:
      scheduleTitlebarChromeMetricsNotification()
    }
  }

  private func scheduleTitlebarChromeMetricsNotification() {
    if titlebarMetricsNotificationScheduled {
      return
    }
    titlebarMetricsNotificationScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.titlebarMetricsNotificationScheduled = false
      self.notifyTitlebarChromeMetrics()
    }
  }

  private func notifyTitlebarChromeMetrics(isFullScreen: Bool? = nil) {
    windowControlsChannel?.invokeMethod(
      "titlebarChromeMetricsChanged",
      arguments: titlebarChromeMetrics(isFullScreen: isFullScreen)
    )
  }

  private func titlebarChromeMetrics(isFullScreen: Bool? = nil) -> [String: Any] {
    let currentlyFullScreen = isFullScreen ?? self.styleMask.contains(.fullScreen)
    if currentlyFullScreen {
      return Self.chromeMetrics(
        trafficLightsVisible: false,
        centerY: Self.defaultTrafficLightCenterY,
        safeInset: 0,
        isFullScreen: true,
        clickSafeTopInset: Self.defaultFullscreenClickSafeTopInset,
        titlebarDragHeight: Self.defaultTitlebarDragHeight,
        contentLayoutTopInset: 0
      )
    }

    guard let referenceView = self.contentView else {
      return fallbackTitlebarChromeMetrics()
    }
    if applyTrafficLightVisualLock(in: referenceView) {
      scheduleTitlebarChromeMetricsNotification()
    }

    let buttonTypes: [NSWindow.ButtonType] = [
      .closeButton,
      .miniaturizeButton,
      .zoomButton,
    ]
    var buttonRects: [NSRect] = []

    for buttonType in buttonTypes {
      guard let button = self.standardWindowButton(buttonType),
            let buttonSuperview = button.superview,
            !button.isHidden else {
        return fallbackTitlebarChromeMetrics()
      }
      buttonRects.append(buttonSuperview.convert(button.frame, to: referenceView))
    }

    guard buttonRects.count == buttonTypes.count else {
      return fallbackTitlebarChromeMetrics()
    }

    let centers = buttonRects.map { rect in
      referenceView.isFlipped ? rect.midY : referenceView.bounds.height - rect.midY
    }
    let centerY = centers.reduce(0, +) / CGFloat(centers.count)
    let safeInset = (buttonRects.map(\.maxX).max() ?? Self.defaultTrafficLightSafeInset) +
      Self.trafficLightSafeGap
    let layoutTopInset = contentLayoutTopInset(in: referenceView)

    return Self.chromeMetrics(
      trafficLightsVisible: true,
      centerY: centerY,
      safeInset: safeInset,
      isFullScreen: false,
      clickSafeTopInset: Self.defaultClickSafeTopInset,
      titlebarDragHeight: max(Self.defaultTitlebarDragHeight, layoutTopInset),
      contentLayoutTopInset: layoutTopInset
    )
  }

  private func fallbackTitlebarChromeMetrics() -> [String: Any] {
    Self.chromeMetrics(
      trafficLightsVisible: true,
      centerY: Self.defaultTrafficLightCenterY,
      safeInset: Self.defaultTrafficLightSafeInset,
      isFullScreen: false,
      clickSafeTopInset: Self.defaultClickSafeTopInset,
      titlebarDragHeight: Self.defaultTitlebarDragHeight,
      contentLayoutTopInset: 0
    )
  }

  private func applyTrafficLightVisualLock(in referenceView: NSView) -> Bool {
    if self.styleMask.contains(.fullScreen) {
      return false
    }

    let targetCenterYInReference = referenceView.isFlipped
      ? Self.defaultTrafficLightCenterY
      : referenceView.bounds.height - Self.defaultTrafficLightCenterY
    let buttonTypes: [NSWindow.ButtonType] = [
      .closeButton,
      .miniaturizeButton,
      .zoomButton,
    ]
    var didUpdate = false

    for buttonType in buttonTypes {
      guard let button = self.standardWindowButton(buttonType),
            let buttonSuperview = button.superview,
            !button.isHidden else {
        continue
      }

      let buttonRectInReference = buttonSuperview.convert(button.frame, to: referenceView)
      let currentCenterY = referenceView.isFlipped
        ? buttonRectInReference.midY
        : referenceView.bounds.height - buttonRectInReference.midY
      if abs(currentCenterY - Self.defaultTrafficLightCenterY) <= Self.trafficLightVisualLockTolerance {
        continue
      }

      let targetCenter = referenceView.convert(
        NSPoint(x: buttonRectInReference.midX, y: targetCenterYInReference),
        to: buttonSuperview
      )
      var frame = button.frame
      frame.origin.y = targetCenter.y - frame.height / 2
      button.frame = frame
      didUpdate = true
    }

    return didUpdate
  }

  private func contentLayoutTopInset(in referenceView: NSView) -> CGFloat {
    let layoutRect = referenceView.convert(self.contentLayoutRect, from: nil)
    if referenceView.isFlipped {
      return max(0, layoutRect.minY)
    }
    return max(0, referenceView.bounds.height - layoutRect.maxY)
  }

  private func performWindowDrag() {
    guard let event = self.currentEvent else {
      return
    }
    self.performDrag(with: event)
  }

  private static func chromeMetrics(
    trafficLightsVisible: Bool,
    centerY: CGFloat,
    safeInset: CGFloat,
    isFullScreen: Bool,
    clickSafeTopInset: CGFloat,
    titlebarDragHeight: CGFloat,
    contentLayoutTopInset: CGFloat
  ) -> [String: Any] {
    [
      "trafficLightsVisible": trafficLightsVisible,
      "centerY": Double(centerY),
      "safeInset": Double(safeInset),
      "isFullScreen": isFullScreen,
      "clickSafeTopInset": Double(clickSafeTopInset),
      "titlebarDragHeight": Double(titlebarDragHeight),
      "contentLayoutTopInset": Double(contentLayoutTopInset),
    ]
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
