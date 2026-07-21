import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract final class FleurIconMetrics {
  const FleurIconMetrics._();

  static const double compact = 18;
  static const double standard = 20;
  static const double large = 24;
}

abstract final class FleurIcons {
  const FleurIcons._();

  // Fleur's controls are mostly 18-20 px. Lucide 500 keeps their strokes near
  // two physical pixels on a 1x desktop display while retaining Lucide's shape.
  static const IconData feeds = LucideIcons.rss500;
  static const IconData feedsSelected = LucideIcons.rss600;
  static const IconData saved = LucideIcons.bookmark500;
  static const IconData savedSelected = LucideIcons.bookmark600;
  static const IconData search = LucideIcons.search500;
  static const IconData searchSelected = LucideIcons.search600;
  static const IconData settings = LucideIcons.settings500;
  static const IconData settingsSelected = LucideIcons.settings600;
  static const IconData back = LucideIcons.arrowLeft500;
  static const IconData forward = LucideIcons.arrowRight500;
  static const IconData sidebarCollapse = LucideIcons.panelLeftClose500;
  static const IconData sidebarExpand = LucideIcons.panelLeftOpen500;

  static const IconData translate = LucideIcons.languages500;
  static const IconData fullText = LucideIcons.fileText500;
  static const IconData refresh = LucideIcons.refreshCw500;
  static const IconData markAllRead = LucideIcons.checkCheck500;
  static const IconData filter = LucideIcons.funnel500;
  static const IconData filterActive = LucideIcons.funnel600;
  static const IconData clear = LucideIcons.x500;
  static const IconData close = LucideIcons.x500;
  static const IconData article = LucideIcons.fileText500;
  static const IconData brokenImage = LucideIcons.imageOff500;
  static const IconData star = LucideIcons.star500;
  static const IconData starActive = LucideIcons.star600;
  static const IconData markRead = LucideIcons.mailOpen500;
  static const IconData markUnread = LucideIcons.mail500;
  static const IconData openExternal = LucideIcons.externalLink500;
  static const IconData moreHorizontal = LucideIcons.ellipsis500;
  static const IconData readerSettings = LucideIcons.aLargeSmall500;
  static const IconData aiSummary = LucideIcons.sparkles500;
  static const IconData readLater = LucideIcons.clock500;
  static const IconData readLaterActive = LucideIcons.clock600;
  static const IconData tag = LucideIcons.tag500;
  static const IconData copy = LucideIcons.copy500;
  static const IconData share = LucideIcons.share500;
  static const IconData previousMatch = LucideIcons.chevronUp500;
  static const IconData nextMatch = LucideIcons.chevronDown500;
  static const IconData caseSensitive = LucideIcons.caseSensitive500;
  static const IconData check = LucideIcons.check500;
  static const IconData autoScroll = LucideIcons.chevronsUpDown500;
  static const IconData statusOk = LucideIcons.check500;
  static const IconData statusError = LucideIcons.circleAlert500;
  static const IconData syncUpload = LucideIcons.cloudUpload500;
  static const IconData syncWarning = LucideIcons.cloudAlert500;
  static const IconData accountSwitcher = LucideIcons.chevronsUpDown500;

  static const IconData allArticles = LucideIcons.inbox500;
  static const IconData feed = LucideIcons.rss500;
  static const IconData category = LucideIcons.folder500;
  static const IconData categoryOpen = LucideIcons.folderOpen500;
  static const IconData expand = LucideIcons.chevronRight500;
  static const IconData collapse = LucideIcons.chevronDown500;
  static const IconData moreVertical = LucideIcons.ellipsisVertical500;
  static const IconData add = LucideIcons.plus500;
  static const IconData addCategory = LucideIcons.folderPlus500;
  static const IconData lock = LucideIcons.lock500;
  static const IconData subscriptionDefaults = LucideIcons.slidersHorizontal500;
  static const IconData rename = LucideIcons.pencil500;
  static const IconData delete = LucideIcons.trash500;
  static const IconData offlineCache = LucideIcons.download500;
  static const IconData moveToCategory = LucideIcons.folderOpen500;
  static const IconData importOpml = LucideIcons.upload500;
  static const IconData exportOpml = LucideIcons.download500;
  static const IconData chevronRight = LucideIcons.chevronRight500;
  static const IconData dropdown = LucideIcons.chevronDown500;
  static const IconData inherit = LucideIcons.rotateCcw500;
  static const IconData reset = LucideIcons.rotateCcw500;
  static const IconData localAccount = LucideIcons.rss500;
  static const IconData minifluxAccount = LucideIcons.cloud500;
  static const IconData feverAccount = LucideIcons.flame500;
  static const IconData googleReaderAccount = LucideIcons.cloudCog500;
  static const IconData activeAccount = LucideIcons.circleCheck500;
  static const IconData themeSystem = LucideIcons.monitor500;
  static const IconData themeLight = LucideIcons.sun500;
  static const IconData themeDark = LucideIcons.moon500;
  static const IconData colorPicker = LucideIcons.pipette500;
  static const IconData download = LucideIcons.download500;
  static const IconData document = LucideIcons.fileText500;

  static const IconData appPreferences = LucideIcons.settings500;
  static const IconData appPreferencesSelected = LucideIcons.settings600;
  static const IconData appearance = LucideIcons.palette500;
  static const IconData appearanceSelected = LucideIcons.palette600;
  static const IconData grouping = LucideIcons.list500;
  static const IconData groupingSelected = LucideIcons.list600;
  static const IconData services = LucideIcons.cloud500;
  static const IconData servicesSelected = LucideIcons.cloud600;
  static const IconData translationAi = LucideIcons.languages500;
  static const IconData translationAiSelected = LucideIcons.languages600;
  static const IconData about = LucideIcons.info500;
  static const IconData aboutSelected = LucideIcons.info600;
  static const IconData aiChat = LucideIcons.messageCircle500;
  static const IconData aiResponses = LucideIcons.zap500;
  static const IconData aiGemini = LucideIcons.sparkles500;
  static const IconData aiAnthropic = LucideIcons.brain500;
  static const IconData language = LucideIcons.globe500;
  static const IconData prompt = LucideIcons.notebookPen500;
  static const IconData speed = LucideIcons.gauge500;
}
