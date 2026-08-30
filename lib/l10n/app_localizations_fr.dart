// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'Pas trouvé';

  @override
  String get openFailedGeneral =>
      'Impossible d\'ouvrir cet emplacement. Vérifiez les autorisations et réessayez.';

  @override
  String get macosMenuLanguageRestartHint =>
      'La langue de la barre de menus peut nécessiter le redémarrage de l\'application pour s\'appliquer pleinement.';

  @override
  String pathNotFound(Object path) {
    return 'Le chemin n’existe pas : $path';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsSearchHint => 'Paramètres de recherche';

  @override
  String get settingsSearchNoResults =>
      'Aucun paramètre ne correspond à cette recherche.';

  @override
  String get settingsSearchPageLabel => 'Pages';

  @override
  String get settingsSearchSectionLabel => 'Section';

  @override
  String get settingsSearchSettingLabel => 'Paramètre';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count résultats';
  }

  @override
  String get feeds => 'Flux';

  @override
  String get saved => 'Enregistrés';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get themeMode => 'Mode thème';

  @override
  String get system => 'Système';

  @override
  String get light => 'Lumière';

  @override
  String get dark => 'Sombre';

  @override
  String get dynamicColor => 'Couleurs dynamiques';

  @override
  String get dynamicColorSubtitle =>
      'Suivez la dynamique du système ou les couleurs d\'accentuation lorsqu\'elles sont disponibles';

  @override
  String get seedColorPreset => 'Couleur d\'accentuation';

  @override
  String get seedColorPresetSubtitle =>
      'Utilisé lorsque les couleurs dynamiques sont désactivées/indisponibles';

  @override
  String get seedColorBlue => 'Bleu';

  @override
  String get seedColorGreen => 'Vert';

  @override
  String get seedColorPurple => 'Violet';

  @override
  String get seedColorOrange => 'Orange';

  @override
  String get seedColorPink => 'Rose';

  @override
  String get language => 'Langue';

  @override
  String get systemLanguage => 'Langue du système';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Lecture';

  @override
  String get fontSize => 'Taille de la police';

  @override
  String get lineHeight => 'Hauteur de ligne';

  @override
  String get horizontalPadding => 'Rembourrage horizontal';

  @override
  String get applicationAppearance => 'Apparence de l\'application';

  @override
  String get readerAppearance => 'Apparence du lecteur';

  @override
  String get codeAppearance => 'Apparence du code';

  @override
  String get custom => 'Personnalisé';

  @override
  String get back => 'Retour';

  @override
  String get forward => 'En avant';

  @override
  String get fontSettings => 'Polices';

  @override
  String get advancedFontSettings => 'Paramètres de police avancés';

  @override
  String get fontsAndCode => 'Polices et code';

  @override
  String get customFontStack => 'Pile de polices personnalisée';

  @override
  String get codeTypography => 'Typographie des codes';

  @override
  String get fontSizeExtraSmall => 'Très petit';

  @override
  String get fontSizeSmall => 'Petit';

  @override
  String get fontSizeMediumRecommended => 'Moyen (recommandé)';

  @override
  String get fontSizeLarge => 'Grand';

  @override
  String get fontSizeExtraLarge => 'Très grand';

  @override
  String get minimumFontSize => 'Taille de police minimale';

  @override
  String get lineHeightCompact => 'Compacte';

  @override
  String get lineHeightStandard => 'Norme';

  @override
  String get lineHeightRelaxed => 'Détendu';

  @override
  String get appearancePreview => 'Aperçu';

  @override
  String get appearancePreviewTitle =>
      'Une surface de lecture plus silencieuse';

  @override
  String get appearancePreviewMeta => 'Aperçu · Aujourd\'hui';

  @override
  String get appearancePreviewBody =>
      'Accordez le lecteur une fois, puis laissez chaque article s\'ouvrir avec le même rythme calme.';

  @override
  String get appearancePreviewQuote =>
      'Les paramètres lisibles doivent être visibles avant d’être configurables.';

  @override
  String get appearancePreviewLink => 'Exemple de lien';

  @override
  String get appearancePreviewCode => 'exemple de code';

  @override
  String get readerFontFamily => 'Famille de polices';

  @override
  String get readerFontSystem => 'Système';

  @override
  String get readerFontSerif => 'Serif';

  @override
  String get readerFontSans => 'Sans';

  @override
  String get readerFontMono => 'Mono';

  @override
  String get readerFontStack => 'Pile de polices de lecture';

  @override
  String get standardFont => 'Police standard';

  @override
  String get serifFont => 'Police Serif';

  @override
  String get sansSerifFont => 'Police sans empattement';

  @override
  String get fixedWidthFont => 'Police à largeur fixe';

  @override
  String get mathFont => 'Police mathématique';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'Style de lecture';

  @override
  String get readerThemeDefault => 'Par défaut';

  @override
  String get readerThemePaper => 'Papier';

  @override
  String get readerThemeSepia => 'Sépia';

  @override
  String get readerThemeDim => 'Gris doux';

  @override
  String get readingWidth => 'Largeur de lecture';

  @override
  String get readingWidthNarrow => 'Étroit';

  @override
  String get readingWidthStandard => 'Norme';

  @override
  String get readingWidthWide => 'Large';

  @override
  String get codeFontFamily => 'Police de code';

  @override
  String get codeFontSystemMono => 'Police à chasse fixe du système';

  @override
  String get codeFontStack => 'Pile de polices de code';

  @override
  String get codeFontSize => 'Taille de la police du code';

  @override
  String get codeFontSizeFollowReader => 'Suivre la taille du texte';

  @override
  String get codeFontSizeOneStepDown => 'Un pas en bas';

  @override
  String get codeLineHeight => 'Hauteur de la ligne de code';

  @override
  String get codeSoftWrap => 'Envelopper les lignes de code';

  @override
  String get storage => 'Stockage';

  @override
  String get clearImageCache => 'Vider le cache des images';

  @override
  String get clearImageCacheSubtitle =>
      'Supprimer les images mises en cache utilisées pour la lecture hors ligne';

  @override
  String get cacheCleared => 'Cache vidé';

  @override
  String get subscriptions => 'Flux';

  @override
  String get defaultsGroup => 'Mondial';

  @override
  String get folders => 'Dossiers';

  @override
  String get globalDefaults => 'Valeurs par défaut globales';

  @override
  String get allSubscriptions => 'Tous les abonnements';

  @override
  String get manage => 'Gérer';

  @override
  String get overview => 'Aperçu';

  @override
  String get categoriesLabel => 'Catégories';

  @override
  String get globalDefaultsDescription =>
      'Appliqué lorsqu\'un dossier ou un abonnement ne remplace pas un paramètre.';

  @override
  String get allSubscriptionsDescription =>
      'Passez en revue la structure globale de l\'abonnement et choisissez un abonnement à modifier.';

  @override
  String get uncategorizedDescription =>
      'Les abonnements sans dossier héritent des valeurs par défaut globales jusqu\'à ce qu\'ils soient remplacés.';

  @override
  String get tags => 'Balises';

  @override
  String get all => 'Tous les articles';

  @override
  String get uncategorized => 'Non classé';

  @override
  String get refreshAll => 'Actualiser les sources';

  @override
  String get refreshFeed => 'Actualiser le flux';

  @override
  String get refreshCategory => 'Actualiser la catégorie';

  @override
  String get refreshFeedAndSync => 'Actualiser le flux et synchroniser';

  @override
  String get refreshCategoryAndSync =>
      'Actualiser la catégorie et synchroniser';

  @override
  String get refreshSourcesAndSync => 'Actualiser les sources et synchroniser';

  @override
  String get accountSync => 'Synchronisation du compte';

  @override
  String get accountSyncSubtitle =>
      'Synchronisez ce compte distant en arrière-plan.';

  @override
  String get syncAccount => 'Synchroniser le compte';

  @override
  String get syncingAccount => 'Synchronisation du compte...';

  @override
  String get syncedAccount => 'Compte synchronisé';

  @override
  String get refreshSelected => 'Actualiser la sélection';

  @override
  String get importOpml => 'Importer OPML';

  @override
  String get opmlParseFailed => 'Fichier OPML invalide';

  @override
  String get exportOpml => 'Exporter OPML';

  @override
  String get addSubscription => 'Ajouter un abonnement';

  @override
  String get selectCategory => 'Sélectionnez une catégorie';

  @override
  String get loadingCategories => 'Chargement des catégories...';

  @override
  String get creatingCategory => 'Création d\'une catégorie...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Les comptes Fever ne prennent pas en charge l\'ajout d\'abonnements. Veuillez gérer les abonnements sur le serveur.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'Cette action nécessite une connectivité au service distant.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'Le service distant a rejeté les informations d\'identification du compte actuel. Vérifiez les paramètres du compte et réessayez.';

  @override
  String get remoteCommandNeedsRefresh =>
      'Le service distant n\'a pas pu correspondre au flux ou à la catégorie actuelle. Synchronisez et réessayez.';

  @override
  String get remoteCommandRejected =>
      'Le service distant a rejeté cette action. Examinez la demande et réessayez.';

  @override
  String get remoteCommandUnavailable =>
      'Le service distant n\'a pas pu terminer cette action pour le moment. Réessayez plus tard.';

  @override
  String get remoteCommandNotSupported =>
      'Ce compte distant ne prend pas en charge cette action.';

  @override
  String get remoteCommandRequiresCategory =>
      'Ce compte distant nécessite une catégorie côté serveur pour l\'abonnement.';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get articles => 'Articles';

  @override
  String get unread => 'Non lu';

  @override
  String get refreshConcurrency => 'Actualiser la concurrence';

  @override
  String refreshingProgress(int current, int total) {
    return 'Actualisation $current/$total...';
  }

  @override
  String get markAllRead => 'Marquer tout comme lu';

  @override
  String get fullText => 'Texte intégral';

  @override
  String get fullTextRetry =>
      'Échec de récupération du texte intégral, réessayer';

  @override
  String get readerSettings => 'Paramètres du lecteur';

  @override
  String get done => 'Terminé';

  @override
  String get more => 'Plus';

  @override
  String get showAll => 'Afficher tout';

  @override
  String get unreadOnly => 'Non lu uniquement';

  @override
  String get selectAnArticle => 'Sélectionnez un article';

  @override
  String get readerEmptySubtitle =>
      'Ouvrez un article de la liste pour le lire ici.';

  @override
  String get searchReaderEmptyTitle => 'Sélectionnez un résultat de recherche';

  @override
  String get searchReaderEmptySubtitle =>
      'Saisissez un mot-clé, puis ouvrez un résultat dans la liste.';

  @override
  String errorMessage(String error) {
    return 'Erreur : $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Échec de récupération du nombre d’articles non lus : $error';
  }

  @override
  String get refreshed => 'Actualisé';

  @override
  String get refreshedAll => 'Tout rafraîchi';

  @override
  String get refreshedAndSynced => 'Actualisé et synchronisé';

  @override
  String get add => 'Ajouter';

  @override
  String get cancel => 'Annuler';

  @override
  String get create => 'Créer';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleted => 'Supprimé';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'URL du flux ou du site web';

  @override
  String get feedOrWebsiteUrlHint => 'Collez une URL de site web ou RSS';

  @override
  String get findFeeds => 'Rechercher des flux';

  @override
  String get discoveringFeeds => 'Recherche de flux...';

  @override
  String get addingSubscription => 'Ajout d\'un abonnement...';

  @override
  String get selectFeed => 'Sélectionner un flux';

  @override
  String get noFeedsFound => 'Aucun flux trouvé';

  @override
  String get noFeedsFoundHint =>
      'Collez directement le RSS/Atom URL ou essayez une autre page du site.';

  @override
  String get subscriptionPreview => 'Aperçu des sources';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources d’abonnement trouvées',
      one: '1 source d’abonnement trouvée',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'Aucun élément d\'aperçu récent disponible';

  @override
  String get feedSourceDirect => 'URL RSS/Atom';

  @override
  String get feedSourceAlternate => 'Détecté sur la page';

  @override
  String get feedSourceCommonPath => 'Chemin de flux courant';

  @override
  String get name => 'Nom';

  @override
  String get addedAndSynced => 'Ajouté et synchronisé';

  @override
  String get subscriptionAddedTitle => 'Abonnement ajouté';

  @override
  String get subscriptionAddedMessage =>
      'L\'abonnement a été ajouté. Vous pouvez l\'ouvrir maintenant ou continuer à en ajouter d\'autres.';

  @override
  String get subscriptionRefreshWarning =>
      'L\'abonnement a été ajouté, mais la première actualisation a échoué. Vous pouvez réessayer d\'actualiser plus tard.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Déjà abonné';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'Ce flux est déjà dans vos abonnements. Aucun changement de catégorie n\'a été apporté.';

  @override
  String get viewSubscription => 'Voir l\'abonnement';

  @override
  String get continueAddingSubscription => 'Continuer à ajouter';

  @override
  String get moveToCurrentCategory => 'Passer à la catégorie actuelle';

  @override
  String get deleteSubscription => 'Supprimer l\'abonnement';

  @override
  String get deleteSubscriptionConfirmTitle => 'Supprimer l\'abonnement ?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'Cela supprimera également ses articles en cache.';

  @override
  String get makeAvailableOffline => 'Rendre disponible hors connexion';

  @override
  String get deleteCategory => 'Supprimer la catégorie';

  @override
  String get deleteCategoryConfirmTitle => 'Supprimer la catégorie ?';

  @override
  String get deleteCategoryConfirmContent =>
      'Les flux de cette catégorie seront déplacés vers Non classé.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Supprimez cette catégorie sur le service distant, puis réconciliez le miroir local.';

  @override
  String get remoteWritableTaxonomyTitle => 'Catégories distantes';

  @override
  String get remoteWritableTaxonomyDescription =>
      'Les modifications de catégorie sont appliquées sur le service distant, puis reflétées localement.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Groupes distants en lecture seule';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'Ces catégories reflètent les groupes distants en lecture seule. Renommez, supprimez ou déplacez des éléments dans le service distant.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => 'Catégorie gérée à distance';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'La catégorie de ce flux provient d\'un miroir de groupe distant en lecture seule.';

  @override
  String get deleteTagConfirmTitle => 'Supprimer la balise ?';

  @override
  String get deleteTagConfirmContent =>
      'Cela le supprimera de tous les articles.';

  @override
  String get categoryDeleted => 'Catégorie supprimée';

  @override
  String get refresh => 'Actualiser';

  @override
  String get moveToCategory => 'Passer à la catégorie';

  @override
  String get noFeedsFoundInOpml => 'Aucun flux trouvé dans OPML';

  @override
  String importedFeeds(int count) {
    return '$count flux importés';
  }

  @override
  String get exportedOpml => 'OPML exporté';

  @override
  String fullTextFailed(String error) {
    return 'Impossible de récupérer le texte intégral : $error';
  }

  @override
  String get scrollToLoadMore => 'Faites défiler pour charger plus';

  @override
  String get noArticles => 'Aucun article';

  @override
  String get noUnreadArticles => 'Aucun article non lu';

  @override
  String get articleListEmptySubtitle =>
      'Ajoutez un abonnement ou actualisez les sources et les articles apparaîtront ici.';

  @override
  String get unreadEmptySubtitle => 'Tout dans le périmètre actuel a été lu.';

  @override
  String get star => 'Marquer comme favori';

  @override
  String get unstar => 'Retirer des favoris';

  @override
  String get starred => 'Favoris';

  @override
  String get readLater => 'Liste de lecture';

  @override
  String get removeReadLater => 'Retirer de la liste de lecture';

  @override
  String get openArticle => 'Ouvrir l\'article';

  @override
  String get markRead => 'Marquer comme lu';

  @override
  String get markUnread => 'Marquer comme non lu';

  @override
  String get collapse => 'Réduire';

  @override
  String get expand => 'Développer';

  @override
  String get openInBrowser => 'Ouvrir dans le navigateur';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get share => 'Partager';

  @override
  String get autoMarkRead => 'Marquer automatiquement comme lu une fois ouvert';

  @override
  String get search => 'Rechercher';

  @override
  String get searchInContent => 'Rechercher dans le contenu';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get searchStartTitle => 'Commencer la recherche';

  @override
  String get searchStartSubtitle =>
      'Saisissez des mots-clés pour rechercher des titres, des résumés et du contenu.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'Aucun article ne correspond à « $query ».';
  }

  @override
  String get articleNotFoundSubtitle =>
      'Cet article a peut-être été supprimé ou n\'est plus disponible localement.';

  @override
  String get findInPage => 'Rechercher dans la page';

  @override
  String get previousMatch => 'Occurrence précédente';

  @override
  String get nextMatch => 'Occurrence suivante';

  @override
  String get caseSensitive => 'Sensible à la casse';

  @override
  String get close => 'Fermer';

  @override
  String get groupingAndSorting => 'Regroupement et tri';

  @override
  String get groupBy => 'Regrouper par';

  @override
  String get groupNone => 'Aucun';

  @override
  String get groupByDay => 'Jour';

  @override
  String get sortOrder => 'Ordre de tri';

  @override
  String get sortNewestFirst => 'Le plus récent en premier';

  @override
  String get sortOldestFirst => 'Le plus ancien en premier';

  @override
  String get enabled => 'Activé';

  @override
  String get rename => 'Renommer';

  @override
  String get edit => 'Modifier';

  @override
  String get nameAlreadyExists => 'Le nom existe déjà';

  @override
  String get lastChecked => 'Dernière vérification';

  @override
  String get lastSynced => 'Dernière synchronisation';

  @override
  String get never => 'Jamais';

  @override
  String get cleanupReadArticles => 'Articles de lecture de nettoyage';

  @override
  String get cleanupNow => 'Exécuter le nettoyage';

  @override
  String cachingArticles(int count) {
    return 'Mise en cache de $count articles...';
  }

  @override
  String get manageTags => 'Gérer les balises';

  @override
  String get newTag => 'Nouvelle balise';

  @override
  String get tagColor => 'Couleur de l\'étiquette';

  @override
  String get autoColor => 'Automatique';

  @override
  String get tagsLoadingError => 'Erreur lors du chargement des balises';

  @override
  String cleanedArticles(int count) {
    return '$count articles nettoyés';
  }

  @override
  String days(int days) {
    return '$days jours';
  }

  @override
  String get services => 'Prestations';

  @override
  String get account => 'Compte';

  @override
  String get connection => 'Connexion';

  @override
  String get addOrRegisterAccount => 'Ajouter ou enregistrer un compte';

  @override
  String get local => 'Local';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Ajouter un local';

  @override
  String get addLocalAccount => 'Ajouter un compte local';

  @override
  String get addMiniflux => 'Ajouter Miniflux';

  @override
  String get addGoogleReaderApi => 'Ajouter Google Reader API';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Compatible avec Google Reader';

  @override
  String get addFever => 'Ajouter Fever';

  @override
  String get minifluxStrategy => 'Miniflux stratégie';

  @override
  String get minifluxStrategySubtitle =>
      'Contrôle la quantité de données récupérées/préchargées pendant la synchronisation.';

  @override
  String get remoteSyncStrategy => 'Stratégie de synchronisation à distance';

  @override
  String get remoteSyncStrategySubtitle =>
      'Contrôle la fenêtre de l\'article distant extraite pendant la synchronisation.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux peut parcourir les entrées distantes jusqu\'à cette fenêtre par synchronisation.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Les services compatibles avec Google Reader parcourent les entrées du flux distant jusqu’à cette limite à chaque synchronisation.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever synchronise les éléments non lus et enregistrés, limités par cette fenêtre par synchronisation.';

  @override
  String get remoteEntriesLimit => 'Entrées par synchronisation';

  @override
  String get remoteFetchConcurrency => 'Concurrence de récupération à distance';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Contrôle les demandes par lots d\'articles distants simultanés pendant la synchronisation du compte.';

  @override
  String get minifluxWebFetchMode => 'Récupération de pages Web';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'Lorsque « Télécharger des pages Web pendant la synchronisation » est activé.';

  @override
  String get minifluxWebFetchModeClient => 'Client (Readability)';

  @override
  String get minifluxWebFetchModeServer =>
      'Serveur (Miniflux récupérer le contenu)';

  @override
  String get maxNetworkResponseBytes => 'Taille maximale des réponses réseau';

  @override
  String get maxNetworkResponseBytesSubtitle =>
      'Limite les réponses mises en mémoire tampon pour la synchronisation, les flux, les pages web et les autres requêtes réseau. Une limite haute reste appliquée.';

  @override
  String get retryQuarantined => 'Réessayer';

  @override
  String get clearQuarantined => 'Effacer';

  @override
  String get unlimited => 'Illimité';

  @override
  String get fieldName => 'Nom';

  @override
  String get nameRequired => 'Entrez un nom';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Saisissez la base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Saisir le jeton API';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Saisir la touche API';

  @override
  String get authenticationMethod => 'Méthode d\'authentification';

  @override
  String get usernamePassword => 'Nom d\'utilisateur et mot de passe';

  @override
  String get minifluxAuthHint =>
      'Utilisez un token API (recommandé) ou un nom d\'utilisateur/mot de passe.';

  @override
  String get feverAuthHint =>
      'Utilisez une clé API (recommandé) ou un nom d\'utilisateur/mot de passe.';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get usernameRequired => 'Entrez le nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordRequired => 'Entrez le mot de passe';

  @override
  String get defaultModel => 'Modèle par défaut';

  @override
  String get savedApiKeyClearHint =>
      'Laissez vide pour effacer la clé API enregistrée.';

  @override
  String get savedCredentialsClearHint =>
      'Laissez vide pour effacer les informations d\'identification enregistrées.';

  @override
  String get aiServicesEmptyState =>
      'Aucun service d’IA ajouté pour le moment.';

  @override
  String modelSummary(String model) {
    return 'Modèle : $model';
  }

  @override
  String get show => 'Afficher';

  @override
  String get hide => 'Masquer';

  @override
  String get missingRequiredFields => 'Champs obligatoires manquants';

  @override
  String get invalidBaseUrl => 'Base URL invalide';

  @override
  String get onlySupportedInLocalAccount =>
      'Uniquement pris en charge dans le compte local';

  @override
  String get autoRefresh => 'Actualisation automatique de la source';

  @override
  String get autoRefreshSubtitle =>
      'Actualisez les sources d\'abonnement à l\'intervalle sélectionné. L\'actualisation en arrière-plan mobile est planifiée par le système, généralement pas plus souvent que toutes les 15 minutes, et peut ne pas s\'exécuter exactement à l\'heure.';

  @override
  String get off => 'Désactivé';

  @override
  String everyMinutes(int minutes) {
    return 'Toutes les $minutes min';
  }

  @override
  String get appPreferences => 'Préférences de l’app';

  @override
  String get about => 'À propos';

  @override
  String get dataDirectory => 'Répertoire de données';

  @override
  String get copyPath => 'Copier le chemin';

  @override
  String get openFolder => 'Ouvrir le dossier';

  @override
  String get logDirectory => 'Répertoire des journaux';

  @override
  String get openLog => 'Ouvrir le journal';

  @override
  String get openLogFolder => 'Ouvrir le dossier des journaux';

  @override
  String get exportLogs => 'Exporter les journaux';

  @override
  String get exportedLogs => 'Journaux exportés';

  @override
  String get noLogsFound => 'Aucun fichier journal trouvé';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Numéro de build';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return 'Version $version · Build $buildNumber';
  }

  @override
  String get checkForUpdates => 'Rechercher des mises à jour';

  @override
  String get checkingForUpdates => 'Recherche...';

  @override
  String get updateAvailable => 'Mise à jour';

  @override
  String get upToDate => 'Vous êtes à jour';

  @override
  String get updateCheckFailed => 'Impossible de rechercher des mises à jour.';

  @override
  String newVersionAvailable(Object version) {
    return 'Nouvelle version $version disponible';
  }

  @override
  String get releaseNotes => 'Notes de version';

  @override
  String get goToOfficialUpdate => 'Ouvrir la page de la version';

  @override
  String get openSourceLicense => 'Licence open source';

  @override
  String get viewLicense => 'Afficher la licence';

  @override
  String get thirdPartyLicenses => 'Licences tierces';

  @override
  String get viewThirdPartyLicenses =>
      'Afficher toutes les licences open source';

  @override
  String get licenseLoadFailed => 'Échec du chargement de la licence.';

  @override
  String get mitLicenseName => 'Licence MIT';

  @override
  String get shortcutNextPreviousArticle => 'J/K : Article suivant/précédent';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + → ; macOS Cmd + [ / ] : historique arrière/avant';

  @override
  String get shortcutRefreshCurrentSelection =>
      'R : Actualiser (sélection actuelle)';

  @override
  String get shortcutToggleUnreadOnly => 'U : afficher uniquement les non-lus';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M : basculer entre lecture/non lecture pour l\'article sélectionné';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S : basculer l\'étoile pour l\'article sélectionné';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F : Rechercher des articles (liste) ; focus Rechercher dans la page (lecteur)';

  @override
  String get filter => 'Filtrer';

  @override
  String get filterKeywordsHint =>
      'Ajoutez des mots-clés réservés (séparez par \";\", connectez-en plusieurs avec \"+\")';

  @override
  String get sync => 'Synchronisation';

  @override
  String get enableSync => 'Activer la synchronisation';

  @override
  String get enableFilter => 'Activer le filtre';

  @override
  String get syncAlwaysEnabled =>
      'Toujours activé (Paramètres - Sync - Le mode de synchronisation est \"Tout\")';

  @override
  String get syncImages => 'Télécharger des images pendant la synchronisation';

  @override
  String get syncWebPages =>
      'Télécharger des pages Web pendant la synchronisation';

  @override
  String get syncStatusSyncing => 'Synchronisation';

  @override
  String get syncStatusSyncingFeeds => 'Synchronisation des flux';

  @override
  String get syncStatusSyncingSubscriptions =>
      'Synchronisation des abonnements';

  @override
  String get syncStatusSyncingUnreadArticles =>
      'Synchronisation des articles non lus';

  @override
  String get syncStatusUploadingChanges => 'Téléchargement des modifications';

  @override
  String get syncStatusCompleted => 'Synchronisation terminée';

  @override
  String get syncStatusFailed => 'La synchronisation a échoué';

  @override
  String get showAiSummary => 'Afficher le résumé';

  @override
  String get summary => 'Résumé';

  @override
  String get showImageTitle => 'Afficher le titre de l\'image';

  @override
  String get showAttachedImage => 'Afficher l\'image jointe';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'Hériter';

  @override
  String get auto => 'Automatique';

  @override
  String get autoOn => 'Automatique (activé)';

  @override
  String get autoOff => 'Désactivé';

  @override
  String get defaultValue => 'Valeur par défaut';

  @override
  String get defaultOption => 'Par défaut';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint =>
      'Utilisé lors de la récupération des flux RSS/Atom.';

  @override
  String get userAgentWebHint =>
      'Utilisé lors de la récupération de pages Web complètes (Readability).';

  @override
  String get resetToDefault => 'Réinitialiser aux valeurs par défaut';

  @override
  String get notificationNewArticleTitle => 'Nouvel article';

  @override
  String get notificationNewArticlesTitle => 'Nouveaux articles';

  @override
  String notificationNewArticlesBody(int count) {
    return '$count nouveaux articles trouvés';
  }

  @override
  String get notificationNewArticlesChannelName => 'Nouveaux articles';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Notifications pour les nouveaux articles trouvés lors de la synchronisation';

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Maximiser';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String get windowClose => 'Fermer';

  @override
  String get translationAndAiServices => 'Traduction et IA';

  @override
  String get translation => 'Traduction';

  @override
  String get translationProvider => 'Fournisseur de traduction';

  @override
  String get aiServices => 'Services d’IA';

  @override
  String get addAiService => 'Ajouter un service d’IA';

  @override
  String get aiService => 'Service d’IA';

  @override
  String get aiSummary => 'Résumé par IA';

  @override
  String get aiSummaryService => 'AI prestation récapitulative';

  @override
  String get targetLanguage => 'Langue cible';

  @override
  String get followAppLanguage => 'Suivre la langue de l’app';

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
    return 'IA : $name';
  }

  @override
  String get translationProviderBaiduApiSubtitle =>
      'Configurer App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => 'Gratuit';

  @override
  String get deepLEndpointPro => 'Pro';

  @override
  String get setAsDefault => 'Définir par défaut';

  @override
  String get defaultAlreadySet => 'Par défaut (déjà défini)';

  @override
  String get aiSummaryPrompt => 'AI invite récapitulative';

  @override
  String get aiTranslationPrompt => 'Prompt de traduction par IA';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Résume cet article en $language (titre : $title) : $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Traduis cet extrait d’article en $language (titre : $title) : $content';
  }

  @override
  String get promptVariables => 'Variables disponibles';

  @override
  String get promptVariableContentDescription => 'Contenu de l\'article';

  @override
  String get promptVariableLanguageDescription => 'Langue cible';

  @override
  String get promptVariableTitleDescription => 'Titre de l\'article';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 signifie illimité ; les demandes seront mises en file d’attente en cas de dépassement.';

  @override
  String get aiSummaryAction => 'Résumé par IA';

  @override
  String get translateAction => 'Traduire';

  @override
  String get translationMode => 'Mode de traduction';

  @override
  String get immersiveTranslation => 'Traduction immersive';

  @override
  String get traditionalTranslation => 'Traduction traditionnelle';

  @override
  String get generating => 'Générer…';

  @override
  String get queued => 'En file d\'attente';

  @override
  String get regenerate => 'Régénérer';

  @override
  String get cachedPromptOutdated =>
      'Prompt mis à jour ; régénérer pour rafraîchir.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Contenu probablement en $source ; la langue cible est $target.';
  }

  @override
  String get dontRemindThisLanguage => 'Ne pas rappeler cette langue';

  @override
  String get autoAiSummary => 'Sommaire automatique AI';

  @override
  String get autoTranslate => 'Traduction automatique';

  @override
  String get aiNotConfigured => 'Service AI non configuré.';

  @override
  String get translationNotAvailable =>
      'La traduction n\'est pas disponible pour le fournisseur sélectionné.';

  @override
  String get clearTranslation => 'Effacer la traduction';

  @override
  String get dbRecoveryTitle => 'Récupération de base de données';

  @override
  String get dbRecoveryDescription =>
      'L\'application a détecté un problème de base de données et effectué une récupération. Vos données ont été conservées sur disque (sauvegarde / fichier déplacé).';

  @override
  String get dbRecoveryTimeLabel => 'Temps';

  @override
  String get dbRecoveryDbNameLabel => 'Nom de la base de données';

  @override
  String get dbRecoveryOpenedAsLabel => 'Ouvert comme';

  @override
  String get dbRecoveryBackupPathLabel => 'Sauvegarde';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Original déplacé';

  @override
  String get dbRecoveryErrorLabel => 'Erreur';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Astuce : utilisez les boutons de copie pour copier les chemins à des fins de dépannage ou d\'assistance.';

  @override
  String get provider => 'Fournisseur';

  @override
  String get googleReaderConnectionTitle => 'Connexion Google Reader';

  @override
  String get keepExistingPasswordHint =>
      'Laisser vide pour conserver le mot de passe actuel';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get googleReaderConnectionFailed =>
      'Échec de la connexion à Google Reader.';

  @override
  String googleReaderConnectedWith(String profile) {
    return 'Connecté : $profile';
  }

  @override
  String googleReaderConnectedAs(String profile, String user) {
    return 'Connecté : $profile - $user';
  }

  @override
  String get googleReaderConnectionSaveFailed =>
      'Échec de l\'enregistrement de la connexion Google Reader.';
}
