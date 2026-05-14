import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSToolbarDelegate {
  private static let defaultTrafficLightCenterY: CGFloat = 24
  private static let defaultTrafficLightSafeInset: CGFloat = 72
  private static let trafficLightSafeGap: CGFloat = 8
  private static let titlebarToolbarIdentifier = NSToolbar.Identifier("FleurTitlebarToolbar")
  private static let titlebarToolbarItemIdentifier = NSToolbarItem.Identifier("FleurTitlebarToolbarItem")

  private var localeChannel: FlutterMethodChannel?
  private var windowControlsChannel: FlutterMethodChannel?
  private var titlebarToolbar: NSToolbar?
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

    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unified
    }

    let toolbar = titlebarToolbar ?? NSToolbar(identifier: Self.titlebarToolbarIdentifier)
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.sizeMode = .regular
    toolbar.showsBaselineSeparator = false

    if titlebarToolbar == nil {
      self.toolbar = toolbar
      titlebarToolbar = toolbar
    }
    updateTitlebarToolbarVisibility(isFullScreen: self.styleMask.contains(.fullScreen))
    return titlebarChromeMetrics()
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
        selector: #selector(windowDidNeedTitlebarToolbarUpdate(_:)),
        name: notification,
        object: self
      )
    }
  }

  @objc private func windowDidNeedTitlebarToolbarUpdate(_ notification: Notification) {
    switch notification.name {
    case NSWindow.willEnterFullScreenNotification,
         NSWindow.didEnterFullScreenNotification:
      updateTitlebarToolbarVisibility(isFullScreen: true)
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.willExitFullScreenNotification:
      updateTitlebarToolbarVisibility(isFullScreen: true)
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.didExitFullScreenNotification:
      updateTitlebarToolbarVisibility(isFullScreen: false)
      notifyTitlebarChromeMetrics(isFullScreen: false)
    default:
      scheduleTitlebarChromeMetricsNotification()
    }
  }

  private func updateTitlebarToolbarVisibility(isFullScreen: Bool) {
    titlebarToolbar?.isVisible = !isFullScreen
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
        isFullScreen: true
      )
    }

    guard let referenceView = self.contentView else {
      return fallbackTitlebarChromeMetrics()
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

    return Self.chromeMetrics(
      trafficLightsVisible: true,
      centerY: centerY,
      safeInset: safeInset,
      isFullScreen: false
    )
  }

  private func fallbackTitlebarChromeMetrics() -> [String: Any] {
    Self.chromeMetrics(
      trafficLightsVisible: true,
      centerY: Self.defaultTrafficLightCenterY,
      safeInset: Self.defaultTrafficLightSafeInset,
      isFullScreen: false
    )
  }

  private static func chromeMetrics(
    trafficLightsVisible: Bool,
    centerY: CGFloat,
    safeInset: CGFloat,
    isFullScreen: Bool
  ) -> [String: Any] {
    [
      "trafficLightsVisible": trafficLightsVisible,
      "centerY": Double(centerY),
      "safeInset": Double(safeInset),
      "isFullScreen": isFullScreen,
    ]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.titlebarToolbarItemIdentifier]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.titlebarToolbarItemIdentifier]
  }

  func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    []
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard itemIdentifier == Self.titlebarToolbarItemIdentifier else {
      return nil
    }

    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    let view = NSView(frame: .zero)
    view.isHidden = true
    view.alphaValue = 0
    item.view = view
    item.minSize = view.frame.size
    item.maxSize = view.frame.size
    item.label = ""
    item.paletteLabel = ""
    item.toolTip = ""
    item.isEnabled = false
    return item
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
