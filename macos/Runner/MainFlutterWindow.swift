import Cocoa
import FlutterMacOS

private enum TrafficLightButtonRole: CaseIterable {
  case close
  case miniaturize
  case zoom

  var buttonType: NSWindow.ButtonType {
    switch self {
    case .close:
      return .closeButton
    case .miniaturize:
      return .miniaturizeButton
    case .zoom:
      return .zoomButton
    }
  }
}

private final class TrafficLightsProxy {
  private final class ConstraintSet {
    weak var button: NSButton?
    weak var superview: NSView?
    var left: NSLayoutConstraint?
    var top: NSLayoutConstraint?
    var previousTranslatesAutoresizingMaskIntoConstraints: Bool?

    func reset() {
      NSLayoutConstraint.deactivate([left, top].compactMap { $0 })
      if let previousTranslatesAutoresizingMaskIntoConstraints {
        button?.translatesAutoresizingMaskIntoConstraints = previousTranslatesAutoresizingMaskIntoConstraints
      }
      button = nil
      superview = nil
      left = nil
      top = nil
      previousTranslatesAutoresizingMaskIntoConstraints = nil
    }
  }

  private let closeButtonCenterX: CGFloat
  private let centerY: CGFloat
  private let tolerance: CGFloat
  private var constraintSets: [TrafficLightButtonRole: ConstraintSet] = [:]
  private var suspendedForFullScreen = false

  init(closeButtonCenterX: CGFloat, centerY: CGFloat, tolerance: CGFloat) {
    self.closeButtonCenterX = closeButtonCenterX
    self.centerY = centerY
    self.tolerance = tolerance
  }

  func suspendForFullScreen() {
    suspendedForFullScreen = true
    resetConstraints()
  }

  func resumeAfterFullScreen() {
    suspendedForFullScreen = false
  }

  @discardableResult
  func applyIfNeeded(window: NSWindow, referenceView: NSView) -> Bool {
    if suspendedForFullScreen || window.styleMask.contains(.fullScreen) {
      return false
    }

    guard let closeButton = window.standardWindowButton(.closeButton),
          let closeButtonSuperview = closeButton.superview,
          !closeButton.isHidden else {
      return false
    }

    let closeButtonRectInReference = closeButtonSuperview.convert(
      closeButton.frame,
      to: referenceView
    )
    let horizontalDelta = closeButtonCenterX - closeButtonRectInReference.midX
    let targetCenterYInReference = referenceView.isFlipped
      ? centerY
      : referenceView.bounds.height - centerY
    var didUpdate = false
    var affectedSuperviews = Set<ObjectIdentifier>()
    var superviewsToLayout: [NSView] = []

    for role in TrafficLightButtonRole.allCases {
      guard let button = window.standardWindowButton(role.buttonType),
            let buttonSuperview = button.superview,
            !button.isHidden,
            button.frame.width > 0,
            button.frame.height > 0 else {
        continue
      }

      let buttonRectInReference = buttonSuperview.convert(button.frame, to: referenceView)
      let targetCenterInSuperview = referenceView.convert(
        NSPoint(
          x: buttonRectInReference.midX + horizontalDelta,
          y: targetCenterYInReference
        ),
        to: buttonSuperview
      )
      let left = targetCenterInSuperview.x - button.frame.width / 2
      let top = topConstant(
        for: targetCenterInSuperview,
        buttonHeight: button.frame.height,
        in: buttonSuperview
      )

      if updateConstraints(
        role: role,
        button: button,
        superview: buttonSuperview,
        left: left,
        top: top
      ) {
        didUpdate = true
        let identifier = ObjectIdentifier(buttonSuperview)
        if !affectedSuperviews.contains(identifier) {
          affectedSuperviews.insert(identifier)
          superviewsToLayout.append(buttonSuperview)
        }
      }
    }

    for superview in superviewsToLayout {
      superview.needsLayout = true
      superview.layoutSubtreeIfNeeded()
    }
    return didUpdate
  }

  private func topConstant(
    for center: NSPoint,
    buttonHeight: CGFloat,
    in superview: NSView
  ) -> CGFloat {
    if superview.isFlipped {
      return center.y - buttonHeight / 2
    }
    return superview.bounds.height - (center.y + buttonHeight / 2)
  }

  private func constraintSet(for role: TrafficLightButtonRole) -> ConstraintSet {
    if let set = constraintSets[role] {
      return set
    }
    let set = ConstraintSet()
    constraintSets[role] = set
    return set
  }

  private func resetConstraints() {
    var affectedSuperviews = Set<ObjectIdentifier>()
    var superviewsToLayout: [NSView] = []

    for set in constraintSets.values {
      if let superview = set.superview {
        let identifier = ObjectIdentifier(superview)
        if !affectedSuperviews.contains(identifier) {
          affectedSuperviews.insert(identifier)
          superviewsToLayout.append(superview)
        }
      }
      set.reset()
    }
    constraintSets.removeAll()

    for superview in superviewsToLayout {
      superview.needsUpdateConstraints = true
      superview.needsLayout = true
      superview.layoutSubtreeIfNeeded()
    }
  }

  private func updateConstraints(
    role: TrafficLightButtonRole,
    button: NSButton,
    superview: NSView,
    left: CGFloat,
    top: CGFloat
  ) -> Bool {
    let set = constraintSet(for: role)
    if set.button !== button || set.superview !== superview ||
        set.left == nil || set.top == nil {
      set.reset()
      set.previousTranslatesAutoresizingMaskIntoConstraints =
        button.translatesAutoresizingMaskIntoConstraints
      button.translatesAutoresizingMaskIntoConstraints = false
      let leftConstraint = NSLayoutConstraint(
        item: button,
        attribute: .left,
        relatedBy: .equal,
        toItem: superview,
        attribute: .left,
        multiplier: 1,
        constant: left
      )
      let topConstraint = NSLayoutConstraint(
        item: button,
        attribute: .top,
        relatedBy: .equal,
        toItem: superview,
        attribute: .top,
        multiplier: 1,
        constant: top
      )
      NSLayoutConstraint.activate([leftConstraint, topConstraint])
      set.button = button
      set.superview = superview
      set.left = leftConstraint
      set.top = topConstraint
      return true
    }

    var didUpdate = false
    if let leftConstraint = set.left,
       abs(leftConstraint.constant - left) > tolerance {
      leftConstraint.constant = left
      didUpdate = true
    }
    if let topConstraint = set.top,
       abs(topConstraint.constant - top) > tolerance {
      topConstraint.constant = top
      didUpdate = true
    }
    return didUpdate
  }
}

class MainFlutterWindow: NSWindow {
  private static let defaultTrafficLightCloseButtonCenterX: CGFloat = 23
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
  private let trafficLightsProxy = TrafficLightsProxy(
    closeButtonCenterX: MainFlutterWindow.defaultTrafficLightCloseButtonCenterX,
    centerY: MainFlutterWindow.defaultTrafficLightCenterY,
    tolerance: MainFlutterWindow.trafficLightVisualLockTolerance
  )

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
      NSWindow.didMoveNotification,
      NSWindow.didBecomeMainNotification,
      NSWindow.didResignMainNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
      NSWindow.willEnterFullScreenNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didDeminiaturizeNotification,
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
      trafficLightsProxy.suspendForFullScreen()
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.willExitFullScreenNotification:
      notifyTitlebarChromeMetrics(isFullScreen: true)
    case NSWindow.didExitFullScreenNotification:
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          return
        }
        self.trafficLightsProxy.resumeAfterFullScreen()
        self.applyTrafficLightsProxyIfNeeded()
        self.notifyTitlebarChromeMetrics(isFullScreen: false)
      }
    default:
      applyTrafficLightsProxyIfNeeded()
      scheduleTitlebarChromeMetricsNotification()
    }
  }

  @discardableResult
  private func applyTrafficLightsProxyIfNeeded() -> Bool {
    guard let referenceView = self.contentView else {
      return false
    }
    return trafficLightsProxy.applyIfNeeded(window: self, referenceView: referenceView)
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
    if trafficLightsProxy.applyIfNeeded(window: self, referenceView: referenceView) {
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
