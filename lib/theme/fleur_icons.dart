import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

abstract final class FleurIcons {
  const FleurIcons._();

  static const IconData feeds = PhosphorIconsRegular.newspaperClipping;
  static const IconData feedsSelected = PhosphorIconsBold.newspaperClipping;
  static const IconData saved = PhosphorIconsRegular.bookmarkSimple;
  static const IconData savedSelected = PhosphorIconsFill.bookmarkSimple;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData searchSelected = PhosphorIconsBold.magnifyingGlass;
  static const IconData settings = PhosphorIconsRegular.gearSix;
  static const IconData settingsSelected = PhosphorIconsBold.gearSix;

  static const IconData translate = PhosphorIconsRegular.translate;
  static const IconData fullText = PhosphorIconsRegular.article;
  static const IconData refresh = PhosphorIconsRegular.arrowClockwise;
  static const IconData star = PhosphorIconsRegular.star;
  static const IconData starActive = PhosphorIconsFill.star;
  static const IconData markRead = PhosphorIconsRegular.envelopeSimpleOpen;
  static const IconData markUnread = PhosphorIconsRegular.envelopeSimple;
  static const IconData openExternal = PhosphorIconsRegular.arrowSquareOut;
  static const IconData moreHorizontal = PhosphorIconsRegular.dotsThree;
  static const IconData readerSettings = PhosphorIconsRegular.textT;
  static const IconData aiSummary = PhosphorIconsRegular.sparkle;
  static const IconData readLater = PhosphorIconsRegular.clockCountdown;
  static const IconData readLaterActive = PhosphorIconsFill.clockCountdown;
  static const IconData tag = PhosphorIconsRegular.tagSimple;
  static const IconData copy = PhosphorIconsRegular.copySimple;
  static const IconData share = PhosphorIconsRegular.share;

  static const IconData allArticles = PhosphorIconsRegular.tray;
  static const IconData feed = PhosphorIconsRegular.rssSimple;
  static const IconData category = PhosphorIconsRegular.folder;
  static const IconData categoryOpen = PhosphorIconsRegular.folderOpen;
  static const IconData expand = PhosphorIconsRegular.caretRight;
  static const IconData collapse = PhosphorIconsRegular.caretDown;
  static const IconData moreVertical = PhosphorIconsRegular.dotsThreeVertical;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData addCategory = PhosphorIconsRegular.folderPlus;
  static const IconData lock = PhosphorIconsRegular.lockSimple;
  static const IconData subscriptionDefaults =
      PhosphorIconsRegular.slidersHorizontal;
  static const IconData rename = PhosphorIconsRegular.pencilSimple;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData offlineCache = PhosphorIconsRegular.downloadSimple;
  static const IconData moveToCategory = PhosphorIconsRegular.folderOpen;
  static const IconData importOpml = PhosphorIconsRegular.uploadSimple;
  static const IconData exportOpml = PhosphorIconsRegular.downloadSimple;

  static const IconData appPreferences = PhosphorIconsRegular.gearSix;
  static const IconData appPreferencesSelected = PhosphorIconsBold.gearSix;
  static const IconData grouping = PhosphorIconsRegular.listBullets;
  static const IconData groupingSelected = PhosphorIconsBold.listBullets;
  static const IconData services = PhosphorIconsRegular.cloud;
  static const IconData servicesSelected = PhosphorIconsBold.cloud;
  static const IconData translationAi = PhosphorIconsRegular.translate;
  static const IconData translationAiSelected = PhosphorIconsBold.translate;
  static const IconData about = PhosphorIconsRegular.info;
  static const IconData aboutSelected = PhosphorIconsBold.info;
}
