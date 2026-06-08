// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String get openFailedGeneral =>
      'Dieser Standort konnte nicht geöffnet werden. Überprüfen Sie die Berechtigungen und versuchen Sie es erneut.';

  @override
  String get macosMenuLanguageRestartHint =>
      'Um die Sprache der Menüleiste vollständig anzuwenden, ist möglicherweise ein Neustart der App erforderlich.';

  @override
  String pathNotFound(Object path) {
    return 'Pfad existiert nicht: $path';
  }

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsSearchHint => 'Sucheinstellungen';

  @override
  String get settingsSearchNoResults =>
      'Keine Einstellungen stimmen mit dieser Suche überein.';

  @override
  String get settingsSearchPageLabel => 'Seite';

  @override
  String get settingsSearchSectionLabel => 'Abschnitt';

  @override
  String get settingsSearchSettingLabel => 'Einstellung';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count Ergebnisse';
  }

  @override
  String get feeds => 'Abonnements';

  @override
  String get saved => 'Gespeichert';

  @override
  String get comingSoon => 'Kommt bald';

  @override
  String get appearance => 'Aussehen';

  @override
  String get theme => 'Thema';

  @override
  String get themeMode => 'Themenmodus';

  @override
  String get system => 'System';

  @override
  String get light => 'Licht';

  @override
  String get dark => 'Dunkel';

  @override
  String get dynamicColor => 'Dynamische Farben';

  @override
  String get dynamicColorSubtitle =>
      'Folgen Sie den Systemdynamik- oder Akzentfarben, sofern verfügbar';

  @override
  String get seedColorPreset => 'Akzentfarbe';

  @override
  String get seedColorPresetSubtitle =>
      'Wird verwendet, wenn dynamische Farben deaktiviert/nicht verfügbar sind';

  @override
  String get seedColorBlue => 'Blau';

  @override
  String get seedColorGreen => 'Grün';

  @override
  String get seedColorPurple => 'Lila';

  @override
  String get seedColorOrange => 'Orange';

  @override
  String get seedColorPink => 'Rosa';

  @override
  String get language => 'Sprache';

  @override
  String get systemLanguage => 'Systemsprache';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Lesen';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get lineHeight => 'Zeilenhöhe';

  @override
  String get horizontalPadding => 'Horizontale Polsterung';

  @override
  String get applicationAppearance => 'App-Erscheinungsbild';

  @override
  String get readerAppearance => 'Aussehen des Lesers';

  @override
  String get codeAppearance => 'Code-Erscheinungsbild';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get back => 'Zurück';

  @override
  String get forward => 'Vorwärts';

  @override
  String get fontSettings => 'Schriftarten';

  @override
  String get advancedFontSettings => 'Erweiterte Schriftarteinstellungen';

  @override
  String get fontsAndCode => 'Schriftarten und Code';

  @override
  String get customFontStack => 'Benutzerdefinierter Schriftartenstapel';

  @override
  String get codeTypography => 'Code-Typografie';

  @override
  String get fontSizeExtraSmall => 'Extra klein';

  @override
  String get fontSizeSmall => 'Klein';

  @override
  String get fontSizeMediumRecommended => 'Mittel (empfohlen)';

  @override
  String get fontSizeLarge => 'Groß';

  @override
  String get fontSizeExtraLarge => 'Extra groß';

  @override
  String get minimumFontSize => 'Mindestschriftgröße';

  @override
  String get lineHeightCompact => 'Kompakt';

  @override
  String get lineHeightStandard => 'Standard';

  @override
  String get lineHeightRelaxed => 'Entspannt';

  @override
  String get appearancePreview => 'Vorschau';

  @override
  String get appearancePreviewTitle => 'Eine ruhigere Leseoberfläche';

  @override
  String get appearancePreviewMeta => 'Vorschau · Heute';

  @override
  String get appearancePreviewBody =>
      'Stimmen Sie den Leser einmal ein und lassen Sie dann jeden Artikel im gleichen ruhigen Rhythmus beginnen.';

  @override
  String get appearancePreviewQuote =>
      'Lesbare Einstellungen sollten sichtbar sein, bevor sie sich konfigurierbar anfühlen.';

  @override
  String get appearancePreviewLink => 'Beispiellink';

  @override
  String get appearancePreviewCode => 'Codebeispiel';

  @override
  String get readerFontFamily => 'Schriftfamilie';

  @override
  String get readerFontSystem => 'System';

  @override
  String get readerFontSerif => 'Serife';

  @override
  String get readerFontSans => 'Ohne';

  @override
  String get readerFontMono => 'Mono';

  @override
  String get readerFontStack => 'Schriftstapel lesen';

  @override
  String get standardFont => 'Standardschriftart';

  @override
  String get serifFont => 'Serifenschrift';

  @override
  String get sansSerifFont => 'Serifenlose Schriftart';

  @override
  String get fixedWidthFont => 'Schriftart mit fester Breite';

  @override
  String get mathFont => 'Mathe-Schriftart';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'Textur lesen';

  @override
  String get readerThemeDefault => 'Standard';

  @override
  String get readerThemePaper => 'Papier';

  @override
  String get readerThemeSepia => 'Sepia';

  @override
  String get readerThemeDim => 'Sanftes Grau';

  @override
  String get readingWidth => 'Lesebreite';

  @override
  String get readingWidthNarrow => 'Schmal';

  @override
  String get readingWidthStandard => 'Standard';

  @override
  String get readingWidthWide => 'Breit';

  @override
  String get codeFontFamily => 'Codeschriftart';

  @override
  String get codeFontSystemMono => 'System-Mono';

  @override
  String get codeFontStack => 'Code-Schriftartenstapel';

  @override
  String get codeFontSize => 'Code-Schriftgröße';

  @override
  String get codeFontSizeFollowReader => 'Folge dem Körper';

  @override
  String get codeFontSizeOneStepDown => 'Einen Schritt nach unten';

  @override
  String get codeLineHeight => 'Höhe der Codezeile';

  @override
  String get codeSoftWrap => 'Codezeilen umbrechen';

  @override
  String get storage => 'Lagerung';

  @override
  String get clearImageCache => 'Bildcache leeren';

  @override
  String get clearImageCacheSubtitle =>
      'Entfernen Sie zwischengespeicherte Bilder, die zum Offline-Lesen verwendet werden';

  @override
  String get cacheCleared => 'Cache geleert';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get defaultsGroup => 'Global';

  @override
  String get folders => 'Abonnements';

  @override
  String get globalDefaults => 'Globale Standardwerte';

  @override
  String get allSubscriptions => 'Alle Abonnements';

  @override
  String get manage => 'Verwalten';

  @override
  String get overview => 'Übersicht';

  @override
  String get categoriesLabel => 'Kategorien';

  @override
  String get globalDefaultsDescription =>
      'Wird angewendet, wenn ein Ordner oder ein Abonnement eine Einstellung nicht überschreibt.';

  @override
  String get allSubscriptionsDescription =>
      'Überprüfen Sie die gesamte Abonnementstruktur und wählen Sie ein Abonnement zum Bearbeiten aus.';

  @override
  String get uncategorizedDescription =>
      'Abonnements ohne Ordner übernehmen die globalen Standardeinstellungen, bis sie überschrieben werden.';

  @override
  String get tags => 'Schlagworte';

  @override
  String get all => 'Alle Artikel';

  @override
  String get uncategorized => 'Nicht kategorisiert';

  @override
  String get refreshAll => 'Quellen aktualisieren';

  @override
  String get refreshFeed => 'Feed aktualisieren';

  @override
  String get refreshCategory => 'Kategorie aktualisieren';

  @override
  String get refreshFeedAndSync => 'Feed aktualisieren und synchronisieren';

  @override
  String get refreshCategoryAndSync =>
      'Kategorie aktualisieren und synchronisieren';

  @override
  String get refreshSourcesAndSync =>
      'Quellen aktualisieren und synchronisieren';

  @override
  String get accountSync => 'Kontosynchronisierung';

  @override
  String get accountSyncSubtitle =>
      'Synchronisieren Sie dieses Remote-Konto im Hintergrund.';

  @override
  String get syncAccount => 'Konto synchronisieren';

  @override
  String get syncingAccount => 'Konto wird synchronisiert...';

  @override
  String get syncedAccount => 'Konto synchronisiert';

  @override
  String get refreshSelected => 'Ausgewählte aktualisieren';

  @override
  String get importOpml => 'Importieren Sie OPML';

  @override
  String get opmlParseFailed => 'Ungültige OPML-Datei';

  @override
  String get exportOpml => 'Exportieren OPML';

  @override
  String get addSubscription => 'Abonnement hinzufügen';

  @override
  String get selectCategory => 'Wählen Sie eine Kategorie aus';

  @override
  String get loadingCategories => 'Kategorien werden geladen...';

  @override
  String get creatingCategory => 'Kategorie wird erstellt...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Fever-Konten unterstützen das Hinzufügen von Abonnements nicht. Bitte verwalten Sie Abonnements auf dem Server.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'Für diese Aktion ist eine Verbindung zum Remotedienst erforderlich.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'Der Remote-Dienst hat die Anmeldeinformationen des aktuellen Kontos abgelehnt. Überprüfen Sie die Kontoeinstellungen und versuchen Sie es erneut.';

  @override
  String get remoteCommandNeedsRefresh =>
      'Der Remote-Dienst konnte nicht mit dem aktuellen Feed oder der aktuellen Kategorie übereinstimmen. Synchronisieren Sie und versuchen Sie es erneut.';

  @override
  String get remoteCommandRejected =>
      'Der Remote-Dienst hat diese Aktion abgelehnt. Überprüfen Sie die Anfrage und versuchen Sie es erneut.';

  @override
  String get remoteCommandUnavailable =>
      'Der Remotedienst konnte diese Aktion derzeit nicht abschließen. Versuchen Sie es später noch einmal.';

  @override
  String get remoteCommandNotSupported =>
      'Dieses Remote-Konto unterstützt diese Aktion nicht.';

  @override
  String get remoteCommandRequiresCategory =>
      'Dieses Remote-Konto erfordert eine serverseitige Kategorie für das Abonnement.';

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get articles => 'Artikel';

  @override
  String get unread => 'Ungelesen';

  @override
  String get refreshConcurrency => 'Parallelität aktualisieren';

  @override
  String refreshingProgress(int current, int total) {
    return '$current/$total wird aktualisiert...';
  }

  @override
  String get markAllRead => 'Alles als gelesen markieren';

  @override
  String get fullText => 'Volltext';

  @override
  String get fullTextRetry =>
      'Volltext konnte nicht abgerufen werden, erneut versuchen';

  @override
  String get readerSettings => 'Reader-Einstellungen';

  @override
  String get done => 'Fertig';

  @override
  String get more => 'Mehr';

  @override
  String get showAll => 'Alle anzeigen';

  @override
  String get unreadOnly => 'Nur ungelesen';

  @override
  String get selectAnArticle => 'Wählen Sie einen Artikel aus';

  @override
  String get readerEmptySubtitle =>
      'Öffnen Sie einen Artikel aus der Liste, um ihn hier zu lesen.';

  @override
  String get savedReaderEmptyTitle =>
      'Wählen Sie einen gespeicherten Artikel aus';

  @override
  String get savedReaderEmptySubtitle =>
      'Öffnen Sie einen Artikel über „Gespeichert“ oder „Später lesen“.';

  @override
  String get searchReaderEmptyTitle => 'Wählen Sie ein Suchergebnis aus';

  @override
  String get searchReaderEmptySubtitle =>
      'Geben Sie ein Schlüsselwort ein und öffnen Sie dann ein Ergebnis aus der Liste.';

  @override
  String errorMessage(String error) {
    return 'Fehler: $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Fehler beim Abrufen der Ungelesen-Zahl: $error';
  }

  @override
  String get refreshed => 'Erfrischt';

  @override
  String get refreshedAll => 'Alles aufgefrischt';

  @override
  String get refreshedAndSynced => 'Aktualisiert und synchronisiert';

  @override
  String get add => 'Hinzufügen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Erstellen';

  @override
  String get delete => 'Löschen';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'Feed- oder Website-URL';

  @override
  String get feedOrWebsiteUrlHint => 'Website- oder RSS-URL einfügen';

  @override
  String get findFeeds => 'Feeds suchen';

  @override
  String get discoveringFeeds => 'Feeds werden gesucht...';

  @override
  String get addingSubscription => 'Abonnement wird hinzugefügt...';

  @override
  String get selectFeed => 'Feed auswählen';

  @override
  String get noFeedsFound => 'Keine Feeds gefunden';

  @override
  String get noFeedsFoundHint =>
      'Fügen Sie RSS/Atom URL direkt ein oder versuchen Sie es mit einer anderen Seite der Website.';

  @override
  String get subscriptionPreview => 'Quellenvorschau';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Abonnementquellen gefunden',
      one: '1 Abonnementquelle gefunden',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'Keine aktuellen Vorschauelemente verfügbar';

  @override
  String get feedSourceDirect => 'RSS/Atom-URL';

  @override
  String get feedSourceAlternate => 'Auf Seite gefunden';

  @override
  String get feedSourceCommonPath => 'Üblicher Feed-Pfad';

  @override
  String get name => 'Name';

  @override
  String get addedAndSynced => 'Hinzugefügt und synchronisiert';

  @override
  String get subscriptionAddedTitle => 'Abonnement hinzugefügt';

  @override
  String get subscriptionAddedMessage =>
      'Das Abonnement wurde hinzugefügt. Sie können es jetzt öffnen oder weitere hinzufügen.';

  @override
  String get subscriptionRefreshWarning =>
      'Das Abonnement wurde hinzugefügt, aber die erste Aktualisierung ist fehlgeschlagen. Sie können die Aktualisierung später erneut versuchen.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Bereits abonniert';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'Dieser Feed ist bereits in Ihren Abonnements enthalten. Es wurden keine Kategorieänderungen vorgenommen.';

  @override
  String get viewSubscription => 'Abonnement ansehen';

  @override
  String get continueAddingSubscription => 'Weiter hinzufügen';

  @override
  String get moveToCurrentCategory => 'Zur aktuellen Kategorie wechseln';

  @override
  String get deleteSubscription => 'Abonnement löschen';

  @override
  String get deleteSubscriptionConfirmTitle => 'Abonnement löschen?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'Dadurch werden auch die zwischengespeicherten Artikel gelöscht.';

  @override
  String get makeAvailableOffline => 'Offline verfügbar machen';

  @override
  String get deleteCategory => 'Kategorie löschen';

  @override
  String get deleteCategoryConfirmTitle => 'Kategorie löschen?';

  @override
  String get deleteCategoryConfirmContent =>
      'Feeds in dieser Kategorie werden nach „Nicht kategorisiert“ verschoben.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Löschen Sie diese Kategorie im Remotedienst und gleichen Sie dann den lokalen Spiegel ab.';

  @override
  String get remoteWritableTaxonomyTitle => 'Remote-Kategorien';

  @override
  String get remoteWritableTaxonomyDescription =>
      'Kategorieänderungen werden auf den Remotedienst angewendet und dann lokal gespiegelt.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Schreibgeschützte Remote-Gruppen';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'Diese Kategorien spiegeln schreibgeschützte Remote-Gruppen wider. Benennen, löschen oder verschieben Sie Elemente im Remote-Dienst.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle =>
      'Kategorie wird aus der Ferne verwaltet';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'Die Kategorie dieses Feeds stammt von einem schreibgeschützten Remote-Gruppenspiegel.';

  @override
  String get deleteTagConfirmTitle => 'Tag löschen?';

  @override
  String get deleteTagConfirmContent =>
      'Dadurch wird es aus allen Artikeln entfernt.';

  @override
  String get categoryDeleted => 'Kategorie gelöscht';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get moveToCategory => 'Zur Kategorie wechseln';

  @override
  String get noFeedsFoundInOpml => 'Keine Feeds in OPML gefunden';

  @override
  String importedFeeds(int count) {
    return '$count Feeds importiert';
  }

  @override
  String get exportedOpml => 'Exportiert OPML';

  @override
  String fullTextFailed(String error) {
    return 'Volltext konnte nicht abgerufen werden: $error';
  }

  @override
  String get scrollToLoadMore => 'Scrollen Sie, um mehr zu laden';

  @override
  String get noArticles => 'Keine Artikel';

  @override
  String get noStarredArticles => 'Noch keine markierten Artikel';

  @override
  String get noReadLaterArticles => 'Noch keine Artikel zum späteren Lesen';

  @override
  String get noUnreadArticles => 'Keine ungelesenen Artikel';

  @override
  String get articleListEmptySubtitle =>
      'Fügen Sie ein Abonnement hinzu oder aktualisieren Sie die Quellen. Die Artikel werden hier angezeigt.';

  @override
  String get unreadEmptySubtitle => 'Alles im aktuellen Umfang wurde gelesen.';

  @override
  String get savedSearchEmptySubtitle =>
      'Zu dieser Suche passen keine gespeicherten Artikel.';

  @override
  String get star => 'Markieren';

  @override
  String get unstar => 'Markierung entfernen';

  @override
  String get starred => 'Markiert';

  @override
  String get readLater => 'Leseliste';

  @override
  String get removeReadLater => 'Aus Leseliste entfernen';

  @override
  String get openArticle => 'Artikel öffnen';

  @override
  String get markRead => 'Mark hat gelesen';

  @override
  String get markUnread => 'Als ungelesen markieren';

  @override
  String get collapse => 'Zusammenbruch';

  @override
  String get expand => 'Erweitern';

  @override
  String get openInBrowser => 'Im Browser öffnen';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get share => 'Teilen';

  @override
  String get autoMarkRead => 'Beim Öffnen automatisch als gelesen markieren';

  @override
  String get search => 'Suchen';

  @override
  String get searchInContent => 'Suche im Inhalt';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get searchStartTitle => 'Beginnen Sie mit der Suche';

  @override
  String get searchStartSubtitle =>
      'Geben Sie Schlüsselwörter ein, um nach Titeln, Zusammenfassungen und Inhalten zu suchen.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'Keine Artikel stimmen mit „$query“ überein.';
  }

  @override
  String get articleNotFoundSubtitle =>
      'Dieser Artikel wurde möglicherweise gelöscht oder ist lokal nicht mehr verfügbar.';

  @override
  String get findInPage => 'Auf der Seite finden';

  @override
  String get previousMatch => 'Vorheriges Spiel';

  @override
  String get nextMatch => 'Nächstes Spiel';

  @override
  String get caseSensitive => 'Groß- und Kleinschreibung beachten';

  @override
  String get close => 'Schließen';

  @override
  String get groupingAndSorting => 'Gruppieren und Sortieren';

  @override
  String get groupBy => 'Gruppieren nach';

  @override
  String get groupNone => 'Keine';

  @override
  String get groupByDay => 'Tag';

  @override
  String get sortOrder => 'Sortierreihenfolge';

  @override
  String get sortNewestFirst => 'Das Neueste zuerst';

  @override
  String get sortOldestFirst => 'Älteste zuerst';

  @override
  String get enabled => 'Aktiviert';

  @override
  String get rename => 'Umbenennen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get nameAlreadyExists => 'Name existiert bereits';

  @override
  String get lastChecked => 'Zuletzt überprüft';

  @override
  String get lastSynced => 'Zuletzt synchronisiert';

  @override
  String get never => 'Niemals';

  @override
  String get cleanupReadArticles => 'Bereinigen Sie gelesene Artikel';

  @override
  String get cleanupNow => 'Führen Sie die Bereinigung durch';

  @override
  String cachingArticles(int count) {
    return '$count Artikel werden zwischengespeichert...';
  }

  @override
  String get manageTags => 'Tags verwalten';

  @override
  String get newTag => 'Neuer Tag';

  @override
  String get tagColor => 'Tag-Farbe';

  @override
  String get autoColor => 'Automatisch';

  @override
  String get tagsLoadingError => 'Fehler beim Laden der Tags';

  @override
  String cleanedArticles(int count) {
    return '$count Artikel bereinigt';
  }

  @override
  String days(int days) {
    return '$days Tage';
  }

  @override
  String get services => 'Dienstleistungen';

  @override
  String get account => 'Konto';

  @override
  String get addOrRegisterAccount => 'Konto hinzufügen oder registrieren';

  @override
  String get local => 'Lokal';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Lokal hinzufügen';

  @override
  String get addLocalAccount => 'Lokales Konto hinzufügen';

  @override
  String get addMiniflux => 'Miniflux hinzufügen';

  @override
  String get addGoogleReaderApi => 'Fügen Sie Google Reader API hinzu';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Fever hinzufügen';

  @override
  String get minifluxStrategy => 'Miniflux Strategie';

  @override
  String get minifluxStrategySubtitle =>
      'Steuert, wie viele Daten während der Synchronisierung abgerufen/vorab abgerufen werden.';

  @override
  String get remoteSyncStrategy => 'Remote-Synchronisierungsstrategie';

  @override
  String get remoteSyncStrategySubtitle =>
      'Steuert das Remote-Artikelfenster, das während der Synchronisierung gezogen wird.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux kann bis zu diesem Pro-Sync-Fenster durch Remote-Einträge blättern.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Google Reader kompatible Dienste blättern durch Remote-Stream-Einträge bis zu diesem Fenster pro Synchronisierung.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever synchronisiert ungelesene und gespeicherte Elemente, begrenzt durch dieses Fenster pro Synchronisierung.';

  @override
  String get remoteEntriesLimit => 'Einträge pro Synchronisierung';

  @override
  String get remoteFetchConcurrency => 'Parallelität beim Fernabruf';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Steuert gleichzeitige Remote-Artikel-Batch-Anfragen während der Kontosynchronisierung.';

  @override
  String get minifluxWebFetchMode => 'Abrufen einer Webseite';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'Wenn „Webseiten während der Synchronisierung herunterladen“ aktiviert ist.';

  @override
  String get minifluxWebFetchModeClient => 'Kunde (Readability)';

  @override
  String get minifluxWebFetchModeServer => 'Server (Miniflux fetch-content)';

  @override
  String get unlimited => 'Unbegrenzt';

  @override
  String get fieldName => 'Name';

  @override
  String get nameRequired => 'Geben Sie einen Namen ein';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Geben Sie die Basis URL ein';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Geben Sie das Token API ein';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Geben Sie die Taste API ein';

  @override
  String get authenticationMethod => 'Authentifizierungsmethode';

  @override
  String get usernamePassword => 'Benutzername und Passwort';

  @override
  String get minifluxAuthHint =>
      'Verwenden Sie ein API-Token (empfohlen) oder einen Benutzernamen/ein Passwort.';

  @override
  String get feverAuthHint =>
      'Verwenden Sie einen API-Schlüssel (empfohlen) oder einen Benutzernamen/ein Passwort.';

  @override
  String get username => 'Benutzername';

  @override
  String get usernameRequired => 'Geben Sie den Benutzernamen ein';

  @override
  String get password => 'Passwort';

  @override
  String get passwordRequired => 'Passwort eingeben';

  @override
  String get defaultModel => 'Standardmodell';

  @override
  String get savedApiKeyClearHint =>
      'Lassen Sie das Feld leer, um den gespeicherten Schlüssel API zu löschen.';

  @override
  String get savedCredentialsClearHint =>
      'Lassen Sie das Feld leer, um die gespeicherten Anmeldeinformationen zu löschen.';

  @override
  String get aiServicesEmptyState =>
      'Es wurden noch keine AI-Dienste hinzugefügt.';

  @override
  String modelSummary(String model) {
    return 'Modell: $model';
  }

  @override
  String get show => 'Zeigen';

  @override
  String get hide => 'Verstecken';

  @override
  String get missingRequiredFields => 'Fehlende Pflichtfelder';

  @override
  String get invalidBaseUrl => 'Ungültige Basis URL';

  @override
  String get onlySupportedInLocalAccount =>
      'Wird nur im lokalen Konto unterstützt';

  @override
  String get autoRefresh => 'Automatische Quellenaktualisierung';

  @override
  String get autoRefreshSubtitle =>
      'Aktualisieren Sie die Abonnementquellen im ausgewählten Intervall. Die Aktualisierung des mobilen Hintergrunds ist vom System geplant, normalerweise nicht öfter als alle 15 Minuten, und wird möglicherweise nicht genau pünktlich ausgeführt.';

  @override
  String get off => 'Aus';

  @override
  String everyMinutes(int minutes) {
    return 'Alle $minutes Minuten';
  }

  @override
  String get appPreferences => 'App-Einstellungen';

  @override
  String get about => 'Über';

  @override
  String get dataDirectory => 'Datenverzeichnis';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get openFolder => 'Ordner öffnen';

  @override
  String get logDirectory => 'Protokollverzeichnis';

  @override
  String get openLog => 'Protokoll öffnen';

  @override
  String get openLogFolder => 'Log-Ordner öffnen';

  @override
  String get exportLogs => 'Protokolle exportieren';

  @override
  String get exportedLogs => 'Protokolle exportiert';

  @override
  String get noLogsFound => 'Keine Protokolldateien gefunden';

  @override
  String get keyboardShortcuts => 'Tastaturkürzel';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Build-Nummer';

  @override
  String get openSourceLicense => 'Open-Source-Lizenz';

  @override
  String get viewLicense => 'Lizenz anzeigen';

  @override
  String get thirdPartyLicenses => 'Lizenzen von Drittanbietern';

  @override
  String get viewThirdPartyLicenses => 'Alle Open-Source-Lizenzen anzeigen';

  @override
  String get licenseLoadFailed => 'Die Lizenz konnte nicht geladen werden.';

  @override
  String get mitLicenseName => 'MIT-Lizenz';

  @override
  String get shortcutNextPreviousArticle => 'J/K: Nächster/vorheriger Artikel';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: Verlauf zurück/vorwärts';

  @override
  String get shortcutRefreshCurrentSelection =>
      'R: Aktualisieren (aktuelle Auswahl)';

  @override
  String get shortcutToggleUnreadOnly => 'U: Schreibgeschützt umschalten';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: Gelesen/ungelesen für den ausgewählten Artikel umschalten';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S: Stern für ausgewählten Artikel umschalten';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Strg/Befehl+F: Artikel durchsuchen (Liste); Fokus Auf Seite finden (Leser)';

  @override
  String get filter => 'Filtern';

  @override
  String get filterKeywordsHint =>
      'Reservierte Schlüsselwörter hinzufügen (mit „;“ trennen, mehrere mit „+“ verbinden)';

  @override
  String get sync => 'Synchronisierung';

  @override
  String get enableSync => 'Aktivieren Sie die Synchronisierung';

  @override
  String get enableFilter => 'Filter aktivieren';

  @override
  String get syncAlwaysEnabled =>
      'Immer aktiviert (Einstellungen – Synchronisierung – Synchronisierungsmodus ist „Alle“).';

  @override
  String get syncImages =>
      'Laden Sie Bilder während der Synchronisierung herunter';

  @override
  String get syncWebPages =>
      'Laden Sie Webseiten während der Synchronisierung herunter';

  @override
  String get syncStatusSyncing => 'Synchronisierung';

  @override
  String get syncStatusSyncingFeeds => 'Feeds synchronisieren';

  @override
  String get syncStatusSyncingSubscriptions =>
      'Abonnements werden synchronisiert';

  @override
  String get syncStatusSyncingUnreadArticles =>
      'Ungelesene Artikel synchronisieren';

  @override
  String get syncStatusUploadingChanges => 'Änderungen hochladen';

  @override
  String get syncStatusCompleted => 'Synchronisierung abgeschlossen';

  @override
  String get syncStatusFailed => 'Die Synchronisierung ist fehlgeschlagen';

  @override
  String get showAiSummary => 'Zusammenfassung anzeigen';

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get showImageTitle => 'Bildtitel anzeigen';

  @override
  String get showAttachedImage => 'Angehängtes Bild anzeigen';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'Erben';

  @override
  String get auto => 'Automatisch';

  @override
  String get autoOn => 'Auto (Ein)';

  @override
  String get autoOff => 'Aus';

  @override
  String get defaultValue => 'Standardwert';

  @override
  String get defaultOption => 'Standard';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint =>
      'Wird beim Abrufen von RSS/Atom-Feeds verwendet.';

  @override
  String get userAgentWebHint =>
      'Wird beim Abrufen vollständiger Webseiten verwendet (Readability).';

  @override
  String get resetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get notificationNewArticleTitle => 'Neuer Artikel';

  @override
  String get notificationNewArticlesTitle => 'Neue Artikel';

  @override
  String notificationNewArticlesBody(int count) {
    return '$count neue Artikel gefunden';
  }

  @override
  String get notificationNewArticlesChannelName => 'Neue Artikel';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Benachrichtigungen für neue Artikel, die während der Synchronisierung gefunden wurden';

  @override
  String get windowMinimize => 'Minimieren';

  @override
  String get windowMaximize => 'Maximieren';

  @override
  String get windowRestore => 'Wiederherstellen';

  @override
  String get windowClose => 'Schließen';

  @override
  String get translationAndAiServices => 'Übersetzung & KI';

  @override
  String get translation => 'Übersetzung';

  @override
  String get translationProvider => 'Übersetzungsanbieter';

  @override
  String get aiServices => 'AI Dienstleistungen';

  @override
  String get addAiService => 'AI-Dienst hinzufügen';

  @override
  String get aiService => 'AI Dienst';

  @override
  String get aiSummary => 'KI-Zusammenfassung';

  @override
  String get aiSummaryService => 'AI zusammenfassender Dienst';

  @override
  String get targetLanguage => 'Zielsprache';

  @override
  String get followAppLanguage => 'App-Sprache folgen';

  @override
  String get translationProviderGoogleWeb => 'Google Translate (web)';

  @override
  String get translationProviderBingWeb => 'Bing Translate (web)';

  @override
  String get translationProviderBaiduApi => 'Baidu Translate (API)';

  @override
  String get translationProviderDeepLApi => 'DeepL (API)';

  @override
  String get translationProviderDeepLX => 'DeepLX';

  @override
  String translationProviderAiService(Object name) {
    return 'KI: $name';
  }

  @override
  String get translationProviderBaiduApiSubtitle =>
      'Konfigurieren Sie App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => 'Kostenlos';

  @override
  String get deepLEndpointPro => 'Profi';

  @override
  String get setAsDefault => 'Als Standard festlegen';

  @override
  String get defaultAlreadySet => 'Standard (bereits festgelegt)';

  @override
  String get aiSummaryPrompt => 'AI Zusammenfassungsaufforderung';

  @override
  String get aiTranslationPrompt => 'KI-Übersetzungsprompt';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Bitte fasse diesen Artikel auf $language zusammen (Titel: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Bitte übersetze diesen Artikelausschnitt auf $language (Titel: $title): $content';
  }

  @override
  String get promptVariables => 'Verfügbare Variablen';

  @override
  String get promptVariableContentDescription => 'Artikelinhalt';

  @override
  String get promptVariableLanguageDescription => 'Zielsprache';

  @override
  String get promptVariableTitleDescription => 'Titel des Artikels';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 bedeutet unbegrenzt; Bei Überschreitung werden Anfragen in die Warteschlange gestellt.';

  @override
  String get aiSummaryAction => 'KI-Zusammenfassung';

  @override
  String get translateAction => 'Übersetzen';

  @override
  String get translationMode => 'Übersetzungsmodus';

  @override
  String get immersiveTranslation => 'Immersive Übersetzung';

  @override
  String get traditionalTranslation => 'Traditionelle Übersetzung';

  @override
  String get generating => 'Generieren…';

  @override
  String get queued => 'In der Warteschlange';

  @override
  String get regenerate => 'Regenerieren';

  @override
  String get cachedPromptOutdated =>
      'Prompt aktualisiert; regenerieren, um zu erfrischen.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Inhalt vermutlich $source; Zielsprache ist $target.';
  }

  @override
  String get dontRemindThisLanguage => 'Für diese Sprache nicht erinnern';

  @override
  String get autoAiSummary => 'Automatische AI Zusammenfassung';

  @override
  String get autoTranslate => 'Automatische Übersetzung';

  @override
  String get aiNotConfigured => 'AI Dienst nicht konfiguriert.';

  @override
  String get translationNotAvailable =>
      'Für den ausgewählten Anbieter ist keine Übersetzung verfügbar.';

  @override
  String get clearTranslation => 'Klare Übersetzung';

  @override
  String get dbRecoveryTitle => 'Datenbankwiederherstellung';

  @override
  String get dbRecoveryDescription =>
      'Die App hat ein Datenbankproblem erkannt und eine Wiederherstellung durchgeführt. Ihre Daten wurden auf der Festplatte gespeichert (Backup/verschobene Datei).';

  @override
  String get dbRecoveryTimeLabel => 'Zeit';

  @override
  String get dbRecoveryDbNameLabel => 'DB-Name';

  @override
  String get dbRecoveryOpenedAsLabel => 'Geöffnet als';

  @override
  String get dbRecoveryBackupPathLabel => 'Sicherung';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Original verschoben';

  @override
  String get dbRecoveryErrorLabel => 'Fehler';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Tipp: Verwenden Sie die Kopierschaltflächen, um Pfade zur Fehlerbehebung oder zum Support zu kopieren.';
}
