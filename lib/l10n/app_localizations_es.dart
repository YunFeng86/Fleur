// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'No encontrado';

  @override
  String get openFailedGeneral =>
      'No se pudo abrir esta ubicación. Verifique los permisos y vuelva a intentarlo.';

  @override
  String get macosMenuLanguageRestartHint =>
      'Es posible que sea necesario reiniciar la aplicación para que el idioma de la barra de menú se aplique por completo.';

  @override
  String pathNotFound(Object path) {
    return 'La ruta no existe: $path';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsSearchHint => 'Configuración de búsqueda';

  @override
  String get settingsSearchNoResults =>
      'Ninguna configuración coincide con esta búsqueda.';

  @override
  String get settingsSearchPageLabel => 'Página';

  @override
  String get settingsSearchSectionLabel => 'Sección';

  @override
  String get settingsSearchSettingLabel => 'Configuración';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count resultados';
  }

  @override
  String get feeds => 'Fuentes';

  @override
  String get saved => 'Guardados';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get themeMode => 'Modo tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Luz';

  @override
  String get dark => 'oscuro';

  @override
  String get dynamicColor => 'Colores dinámicos';

  @override
  String get dynamicColorSubtitle =>
      'Siga los colores dinámicos o de acento del sistema cuando estén disponibles';

  @override
  String get seedColorPreset => 'Color de acento';

  @override
  String get seedColorPresetSubtitle =>
      'Se utiliza cuando los colores dinámicos están desactivados o no disponibles';

  @override
  String get seedColorBlue => 'azul';

  @override
  String get seedColorGreen => 'Verde';

  @override
  String get seedColorPurple => 'Púrpura';

  @override
  String get seedColorOrange => 'naranja';

  @override
  String get seedColorPink => 'rosa';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma del sistema';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Lectura';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get lineHeight => 'altura de la línea';

  @override
  String get horizontalPadding => 'Acolchado horizontal';

  @override
  String get applicationAppearance => 'Apariencia de la aplicación';

  @override
  String get readerAppearance => 'Apariencia del lector';

  @override
  String get codeAppearance => 'Apariencia del código';

  @override
  String get custom => 'personalizado';

  @override
  String get back => 'Atrás';

  @override
  String get forward => 'Adelante';

  @override
  String get fontSettings => 'Fuentes';

  @override
  String get advancedFontSettings => 'Configuración de fuente avanzada';

  @override
  String get fontsAndCode => 'Fuentes y código';

  @override
  String get customFontStack => 'Pila de fuentes personalizadas';

  @override
  String get codeTypography => 'tipografía de código';

  @override
  String get fontSizeExtraSmall => 'extrapequeño';

  @override
  String get fontSizeSmall => 'pequeño';

  @override
  String get fontSizeMediumRecommended => 'Medio (recomendado)';

  @override
  String get fontSizeLarge => 'Grande';

  @override
  String get fontSizeExtraLarge => 'Extra grande';

  @override
  String get minimumFontSize => 'Tamaño mínimo de fuente';

  @override
  String get lineHeightCompact => 'Compacto';

  @override
  String get lineHeightStandard => 'Estándar';

  @override
  String get lineHeightRelaxed => 'Relajado';

  @override
  String get appearancePreview => 'Vista previa';

  @override
  String get appearancePreviewTitle =>
      'Una superficie de lectura más silenciosa';

  @override
  String get appearancePreviewMeta => 'Vista previa · Hoy';

  @override
  String get appearancePreviewBody =>
      'Sintonice al lector una vez y luego deje que cada artículo se abra con el mismo ritmo tranquilo.';

  @override
  String get appearancePreviewQuote =>
      'Las configuraciones legibles deben parecer visibles antes de que parezcan configurables.';

  @override
  String get appearancePreviewLink => 'Enlace de muestra';

  @override
  String get appearancePreviewCode => 'muestra de código';

  @override
  String get readerFontFamily => 'Familia de fuentes';

  @override
  String get readerFontSystem => 'Sistema';

  @override
  String get readerFontSerif => 'Serifa';

  @override
  String get readerFontSans => 'sin';

  @override
  String get readerFontMono => 'monocromático';

  @override
  String get readerFontStack => 'Lectura de pila de fuentes';

  @override
  String get standardFont => 'Fuente estándar';

  @override
  String get serifFont => 'fuente serifa';

  @override
  String get sansSerifFont => 'fuente sans-serif';

  @override
  String get fixedWidthFont => 'Fuente de ancho fijo';

  @override
  String get mathFont => 'fuente matemática';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'textura de lectura';

  @override
  String get readerThemeDefault => 'Predeterminado';

  @override
  String get readerThemePaper => 'papel';

  @override
  String get readerThemeSepia => 'sepia';

  @override
  String get readerThemeDim => 'Gris suave';

  @override
  String get readingWidth => 'Ancho de lectura';

  @override
  String get readingWidthNarrow => 'Estrecho';

  @override
  String get readingWidthStandard => 'Estándar';

  @override
  String get readingWidthWide => 'ancho';

  @override
  String get codeFontFamily => 'Fuente de código';

  @override
  String get codeFontSystemMono => 'Sistema mono';

  @override
  String get codeFontStack => 'Pila de fuentes de código';

  @override
  String get codeFontSize => 'Tamaño de fuente del código';

  @override
  String get codeFontSizeFollowReader => 'seguir el cuerpo';

  @override
  String get codeFontSizeOneStepDown => 'un paso hacia abajo';

  @override
  String get codeLineHeight => 'Altura de la línea de código';

  @override
  String get codeSoftWrap => 'Ajustar líneas de código';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get clearImageCache => 'Borrar caché de imágenes';

  @override
  String get clearImageCacheSubtitle =>
      'Eliminar imágenes en caché utilizadas para lectura sin conexión';

  @override
  String get cacheCleared => 'Caché borrada';

  @override
  String get subscriptions => 'Fuentes';

  @override
  String get defaultsGroup => 'Mundial';

  @override
  String get folders => 'Suscripciones';

  @override
  String get globalDefaults => 'Valores predeterminados globales';

  @override
  String get allSubscriptions => 'Todas las suscripciones';

  @override
  String get manage => 'Administrar';

  @override
  String get overview => 'Descripción general';

  @override
  String get categoriesLabel => 'Categorías';

  @override
  String get globalDefaultsDescription =>
      'Se aplica cuando una carpeta o suscripción no anula una configuración.';

  @override
  String get allSubscriptionsDescription =>
      'Revise la estructura general de la suscripción y elija una suscripción para editarla.';

  @override
  String get uncategorizedDescription =>
      'Las suscripciones sin carpeta heredan los valores predeterminados globales hasta que se anulan.';

  @override
  String get tags => 'Etiquetas';

  @override
  String get all => 'Todos los artículos';

  @override
  String get uncategorized => 'Sin categoría';

  @override
  String get refreshAll => 'Actualizar fuentes';

  @override
  String get refreshFeed => 'Actualizar feed';

  @override
  String get refreshCategory => 'Actualizar categoría';

  @override
  String get refreshFeedAndSync => 'Actualizar feed y sincronizar';

  @override
  String get refreshCategoryAndSync => 'Actualizar categoría y sincronizar';

  @override
  String get refreshSourcesAndSync => 'Actualizar fuentes y sincronizar';

  @override
  String get accountSync => 'Sincronización de cuenta';

  @override
  String get accountSyncSubtitle =>
      'Sincroniza esta cuenta remota en segundo plano.';

  @override
  String get syncAccount => 'Sincronizar cuenta';

  @override
  String get syncingAccount => 'Sincronizando cuenta...';

  @override
  String get syncedAccount => 'Cuenta sincronizada';

  @override
  String get refreshSelected => 'Actualizar seleccionado';

  @override
  String get importOpml => 'Importar OPML';

  @override
  String get opmlParseFailed => 'Archivo OPML no válido';

  @override
  String get exportOpml => 'Exportar OPML';

  @override
  String get addSubscription => 'Agregar suscripción';

  @override
  String get selectCategory => 'Selecciona una categoría';

  @override
  String get loadingCategories => 'Cargando categorías...';

  @override
  String get creatingCategory => 'Creando categoría...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Las cuentas Fever no admiten la adición de suscripciones. Administre las suscripciones en el servidor.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'Esta acción requiere conectividad con el servicio remoto.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'El servicio remoto rechazó las credenciales de la cuenta actual. Verifique la configuración de la cuenta e inténtelo nuevamente.';

  @override
  String get remoteCommandNeedsRefresh =>
      'El servicio remoto no pudo coincidir con la fuente o categoría actual. Sincroniza y vuelve a intentarlo.';

  @override
  String get remoteCommandRejected =>
      'El servicio remoto rechazó esta acción. Revise la solicitud y vuelva a intentarlo.';

  @override
  String get remoteCommandUnavailable =>
      'El servicio remoto no pudo completar esta acción en este momento. Vuelve a intentarlo más tarde.';

  @override
  String get remoteCommandNotSupported =>
      'Esta cuenta remota no admite esta acción.';

  @override
  String get remoteCommandRequiresCategory =>
      'Esta cuenta remota requiere una categoría del lado del servidor para la suscripción.';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get articles => 'Artículos';

  @override
  String get unread => 'No leído';

  @override
  String get refreshConcurrency => 'Actualizar simultaneidad';

  @override
  String refreshingProgress(int current, int total) {
    return 'Actualizando $current/$total...';
  }

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String get fullText => 'Texto completo';

  @override
  String get fullTextRetry =>
      'No se pudo obtener el texto completo. Reintentar';

  @override
  String get readerSettings => 'Configuración del lector';

  @override
  String get done => 'hecho';

  @override
  String get more => 'Más';

  @override
  String get showAll => 'Mostrar todo';

  @override
  String get unreadOnly => 'Sólo sin leer';

  @override
  String get selectAnArticle => 'Seleccione un artículo';

  @override
  String get readerEmptySubtitle =>
      'Abra un artículo de la lista para leerlo aquí.';

  @override
  String get savedReaderEmptyTitle => 'Seleccione un artículo guardado';

  @override
  String get savedReaderEmptySubtitle =>
      'Abra un artículo guardado o leído más tarde.';

  @override
  String get searchReaderEmptyTitle => 'Seleccione un resultado de búsqueda';

  @override
  String get searchReaderEmptySubtitle =>
      'Ingrese una palabra clave y luego abra un resultado de la lista.';

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Error al obtener el recuento de no leídos: $error';
  }

  @override
  String get refreshed => 'renovado';

  @override
  String get refreshedAll => 'Actualizado todo';

  @override
  String get refreshedAndSynced => 'Actualizado y sincronizado';

  @override
  String get add => 'Añadir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'crear';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleted => 'Eliminado';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'URL de fuente o sitio web';

  @override
  String get feedOrWebsiteUrlHint => 'Pega una URL de sitio web o RSS';

  @override
  String get findFeeds => 'Buscar fuentes';

  @override
  String get discoveringFeeds => 'Buscando fuentes...';

  @override
  String get addingSubscription => 'Agregando suscripción...';

  @override
  String get selectFeed => 'Seleccionar fuente';

  @override
  String get noFeedsFound => 'No se encontraron fuentes';

  @override
  String get noFeedsFoundHint =>
      'Pegue RSS/Atom URL directamente o pruebe con otra página del sitio.';

  @override
  String get subscriptionPreview => 'Vista previa de la fuente';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se encontraron $count fuentes de suscripción',
      one: 'Se encontró 1 fuente de suscripción',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'No hay elementos de vista previa recientes disponibles';

  @override
  String get feedSourceDirect => 'URL RSS/Atom';

  @override
  String get feedSourceAlternate => 'Detectada en la página';

  @override
  String get feedSourceCommonPath => 'Ruta común de fuente';

  @override
  String get name => 'Nombre';

  @override
  String get addedAndSynced => 'Agregado y sincronizado';

  @override
  String get subscriptionAddedTitle => 'Suscripción agregada';

  @override
  String get subscriptionAddedMessage =>
      'La suscripción fue agregada. Puedes abrirlo ahora o seguir agregando más.';

  @override
  String get subscriptionRefreshWarning =>
      'Se agregó la suscripción, pero falló la primera actualización. Puede volver a intentar actualizar más tarde.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Ya suscrito';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'Este feed ya está en tus suscripciones. No se realizaron cambios de categoría.';

  @override
  String get viewSubscription => 'Ver suscripción';

  @override
  String get continueAddingSubscription => 'Continuar agregando';

  @override
  String get moveToCurrentCategory => 'Mover a la categoría actual';

  @override
  String get deleteSubscription => 'Eliminar suscripción';

  @override
  String get deleteSubscriptionConfirmTitle => '¿Eliminar suscripción?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'Esto también eliminará sus artículos almacenados en caché.';

  @override
  String get makeAvailableOffline => 'Hacer disponible sin conexión';

  @override
  String get deleteCategory => 'Eliminar categoría';

  @override
  String get deleteCategoryConfirmTitle => '¿Eliminar categoría?';

  @override
  String get deleteCategoryConfirmContent =>
      'Los feeds de esta categoría se moverán a Sin categoría.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Elimine esta categoría en el servicio remoto y luego concilie el espejo local.';

  @override
  String get remoteWritableTaxonomyTitle => 'Categorías remotas';

  @override
  String get remoteWritableTaxonomyDescription =>
      'Los cambios de categoría se aplican en el servicio remoto y luego se reflejan localmente.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Grupos remotos de solo lectura';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'Estas categorías reflejan grupos remotos de solo lectura. Cambie el nombre, elimine o mueva elementos en el servicio remoto.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle =>
      'Categoría gestionada de forma remota';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'La categoría de este feed proviene de un espejo de grupo remoto de solo lectura.';

  @override
  String get deleteTagConfirmTitle => '¿Eliminar etiqueta?';

  @override
  String get deleteTagConfirmContent =>
      'Esto lo eliminará de todos los artículos.';

  @override
  String get categoryDeleted => 'Categoría eliminada';

  @override
  String get refresh => 'Actualizar';

  @override
  String get moveToCategory => 'Mover a categoría';

  @override
  String get noFeedsFoundInOpml => 'No se encontraron feeds en OPML';

  @override
  String importedFeeds(int count) {
    return 'Se importaron $count feeds';
  }

  @override
  String get exportedOpml => 'Exportado OPML';

  @override
  String fullTextFailed(String error) {
    return 'No se pudo obtener el texto completo: $error';
  }

  @override
  String get scrollToLoadMore => 'Desplácese para cargar más';

  @override
  String get noArticles => 'Sin artículos';

  @override
  String get noStarredArticles => 'Aún no hay artículos destacados';

  @override
  String get noReadLaterArticles => 'Aún no hay artículos para leer más tarde';

  @override
  String get noUnreadArticles => 'No hay artículos sin leer';

  @override
  String get articleListEmptySubtitle =>
      'Agregue una suscripción o actualice las fuentes y los artículos aparecerán aquí.';

  @override
  String get unreadEmptySubtitle =>
      'Se ha leído todo lo que está en el alcance actual.';

  @override
  String get savedSearchEmptySubtitle =>
      'Ningún artículo guardado coincide con esta búsqueda.';

  @override
  String get star => 'Marcar con estrella';

  @override
  String get unstar => 'Quitar estrella';

  @override
  String get starred => 'Con estrella';

  @override
  String get readLater => 'Lista de lectura';

  @override
  String get removeReadLater => 'Quitar de Lista de lectura';

  @override
  String get openArticle => 'Abrir artículo';

  @override
  String get markRead => 'marcar leído';

  @override
  String get markUnread => 'Marcar como no leído';

  @override
  String get collapse => 'Colapso';

  @override
  String get expand => 'Expandir';

  @override
  String get openInBrowser => 'Abrir en el navegador';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get share => 'Compartir';

  @override
  String get autoMarkRead => 'Marcar automáticamente como leído cuando se abre';

  @override
  String get search => 'Buscar';

  @override
  String get searchInContent => 'Buscar en contenido';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get searchStartTitle => 'Empezar a buscar';

  @override
  String get searchStartSubtitle =>
      'Ingrese palabras clave para buscar títulos, resúmenes y contenido.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'Ningún artículo coincide con “$query”.';
  }

  @override
  String get articleNotFoundSubtitle =>
      'Es posible que este artículo se haya eliminado o que ya no esté disponible localmente.';

  @override
  String get findInPage => 'Buscar en la pagina';

  @override
  String get previousMatch => 'Partido anterior';

  @override
  String get nextMatch => 'Próximo partido';

  @override
  String get caseSensitive => 'Distingue entre mayúsculas y minúsculas';

  @override
  String get close => 'Cerrar';

  @override
  String get groupingAndSorting => 'Agrupar y ordenar';

  @override
  String get groupBy => 'Agrupar por';

  @override
  String get groupNone => 'Ninguno';

  @override
  String get groupByDay => 'dia';

  @override
  String get sortOrder => 'orden de clasificación';

  @override
  String get sortNewestFirst => 'Lo nuevo primero';

  @override
  String get sortOldestFirst => 'El más viejo primero';

  @override
  String get enabled => 'Habilitado';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get edit => 'Editar';

  @override
  String get nameAlreadyExists => 'El nombre ya existe';

  @override
  String get lastChecked => 'Última comprobación';

  @override
  String get lastSynced => 'Última sincronización';

  @override
  String get never => 'nunca';

  @override
  String get cleanupReadArticles => 'Artículos de lectura de limpieza';

  @override
  String get cleanupNow => 'Ejecutar limpieza';

  @override
  String cachingArticles(int count) {
    return 'Guardando $count artículos en caché...';
  }

  @override
  String get manageTags => 'Administrar etiquetas';

  @override
  String get newTag => 'Nueva etiqueta';

  @override
  String get tagColor => 'Color de etiqueta';

  @override
  String get autoColor => 'Automático';

  @override
  String get tagsLoadingError => 'Error al cargar etiquetas';

  @override
  String cleanedArticles(int count) {
    return 'Se limpiaron $count artículos';
  }

  @override
  String days(int days) {
    return '$days días';
  }

  @override
  String get services => 'Servicios';

  @override
  String get account => 'cuenta';

  @override
  String get connection => 'Conexión';

  @override
  String get addOrRegisterAccount => 'Agregar o registrar cuenta';

  @override
  String get local => 'locales';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Agregar local';

  @override
  String get addLocalAccount => 'Agregar cuenta local';

  @override
  String get addMiniflux => 'Añadir Miniflux';

  @override
  String get addGoogleReaderApi => 'Añadir Google Reader API';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Añadir Fever';

  @override
  String get minifluxStrategy => 'Miniflux estrategia';

  @override
  String get minifluxStrategySubtitle =>
      'Controla la cantidad de datos que se obtienen o se obtienen previamente durante la sincronización.';

  @override
  String get remoteSyncStrategy => 'Estrategia de sincronización remota';

  @override
  String get remoteSyncStrategySubtitle =>
      'Controla la ventana del artículo remoto que se abre durante la sincronización.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux puede desplazarse por entradas remotas hasta esta ventana por sincronización.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Google Reader página de servicios compatibles a través de entradas de transmisión remota hasta esta ventana por sincronización.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever sincroniza elementos guardados y no leídos, limitados por esta ventana por sincronización.';

  @override
  String get remoteEntriesLimit => 'Entradas por sincronización';

  @override
  String get remoteFetchConcurrency => 'Simultaneidad de recuperación remota';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Controla las solicitudes remotas simultáneas de lotes de artículos durante la sincronización de la cuenta.';

  @override
  String get minifluxWebFetchMode => 'Búsqueda de páginas web';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'Cuando \"Descargar páginas web durante la sincronización\" está habilitado.';

  @override
  String get minifluxWebFetchModeClient => 'Cliente (Readability)';

  @override
  String get minifluxWebFetchModeServer =>
      'Servidor (Miniflux buscar contenido)';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String get fieldName => 'Nombre';

  @override
  String get nameRequired => 'Introduce un nombre';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Introduzca la base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.ejemplo.com';

  @override
  String get feverBaseUrlHint => 'https://ejemplo.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Ingrese el token API';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Ingrese la clave API';

  @override
  String get authenticationMethod => 'Método de autenticación';

  @override
  String get usernamePassword => 'Nombre de usuario y contraseña';

  @override
  String get minifluxAuthHint =>
      'Utilice un token API (recomendado) o nombre de usuario/contraseña.';

  @override
  String get feverAuthHint =>
      'Utilice una clave API (recomendada) o nombre de usuario/contraseña.';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get usernameRequired => 'Ingrese el nombre de usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordRequired => 'Introduce la contraseña';

  @override
  String get defaultModel => 'Modelo predeterminado';

  @override
  String get savedApiKeyClearHint =>
      'Déjelo en blanco para borrar la clave API guardada.';

  @override
  String get savedCredentialsClearHint =>
      'Déjelo en blanco para borrar las credenciales guardadas.';

  @override
  String get aiServicesEmptyState => 'Aún no se han agregado servicios AI.';

  @override
  String modelSummary(String model) {
    return 'Modelo: $model';
  }

  @override
  String get show => 'Mostrar';

  @override
  String get hide => 'Ocultar';

  @override
  String get missingRequiredFields => 'Faltan campos obligatorios';

  @override
  String get invalidBaseUrl => 'Base no válida URL';

  @override
  String get onlySupportedInLocalAccount => 'Solo admitido en cuenta local';

  @override
  String get autoRefresh => 'Actualización automática de fuente';

  @override
  String get autoRefreshSubtitle =>
      'Actualizar las fuentes de suscripción en el intervalo seleccionado. La actualización en segundo plano del dispositivo móvil está programada por el sistema, normalmente no más de cada 15 minutos, y es posible que no se ejecute exactamente a tiempo.';

  @override
  String get off => 'Apagado';

  @override
  String everyMinutes(int minutes) {
    return 'Cada $minutes minutos';
  }

  @override
  String get appPreferences => 'Preferencias de la app';

  @override
  String get about => 'Acerca de';

  @override
  String get dataDirectory => 'Directorio de datos';

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String get logDirectory => 'Directorio de registro';

  @override
  String get openLog => 'Abrir registro';

  @override
  String get openLogFolder => 'Abrir carpeta de registro';

  @override
  String get exportLogs => 'Exportar registros';

  @override
  String get exportedLogs => 'Registros exportados';

  @override
  String get noLogsFound => 'No se encontraron archivos de registro';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get version => 'Versión';

  @override
  String get buildNumber => 'Número de compilación';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return 'Versión $version · Compilación $buildNumber';
  }

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get checkingForUpdates => 'Buscando...';

  @override
  String get updateAvailable => 'Actualización';

  @override
  String get upToDate => 'Ya tienes la versión más reciente';

  @override
  String get updateCheckFailed => 'No se pudieron buscar actualizaciones.';

  @override
  String newVersionAvailable(Object version) {
    return 'Nueva versión $version disponible';
  }

  @override
  String get releaseNotes => 'Notas de la versión';

  @override
  String get goToOfficialUpdate => 'Abrir la página de la versión';

  @override
  String get openSourceLicense => 'Licencia de código abierto';

  @override
  String get viewLicense => 'Ver licencia';

  @override
  String get thirdPartyLicenses => 'Licencias de terceros';

  @override
  String get viewThirdPartyLicenses =>
      'Ver todas las licencias de código abierto';

  @override
  String get licenseLoadFailed => 'No se pudo cargar la licencia.';

  @override
  String get mitLicenseName => 'Licencia MIT';

  @override
  String get shortcutNextPreviousArticle => 'J/K: Artículo siguiente/anterior';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: Historial de avance/retroceso';

  @override
  String get shortcutRefreshCurrentSelection =>
      'R: Actualizar (selección actual)';

  @override
  String get shortcutToggleUnreadOnly => 'U: alternar solo sin lectura';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: alternar leído/no leído para el artículo seleccionado';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S: alternar estrella para el artículo seleccionado';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: Buscar artículos (lista); foco Buscar en la página (lector)';

  @override
  String get filter => 'Filtrar';

  @override
  String get filterKeywordsHint =>
      'Agregue palabras clave reservadas (sepárelas con \";\", conecte varias con \"+\")';

  @override
  String get sync => 'Sincronización';

  @override
  String get enableSync => 'Habilitar sincronización';

  @override
  String get enableFilter => 'Habilitar filtro';

  @override
  String get syncAlwaysEnabled =>
      'Siempre habilitado (Configuración - Sincronización - Modo de sincronización es \"Todo\")';

  @override
  String get syncImages => 'Descargar imágenes durante la sincronización';

  @override
  String get syncWebPages => 'Descargar páginas web durante la sincronización';

  @override
  String get syncStatusSyncing => 'Sincronización';

  @override
  String get syncStatusSyncingFeeds => 'Sincronización de feeds';

  @override
  String get syncStatusSyncingSubscriptions =>
      'Sincronización de suscripciones';

  @override
  String get syncStatusSyncingUnreadArticles =>
      'Sincronizar artículos no leídos';

  @override
  String get syncStatusUploadingChanges => 'Subiendo cambios';

  @override
  String get syncStatusCompleted => 'Sincronización completa';

  @override
  String get syncStatusFailed => 'Error de sincronización';

  @override
  String get showAiSummary => 'Mostrar resumen';

  @override
  String get summary => 'Resumen';

  @override
  String get showImageTitle => 'Mostrar título de imagen';

  @override
  String get showAttachedImage => 'Mostrar imagen adjunta';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'heredar';

  @override
  String get auto => 'Automático';

  @override
  String get autoOn => 'Automático (activado)';

  @override
  String get autoOff => 'Apagado';

  @override
  String get defaultValue => 'Valor predeterminado';

  @override
  String get defaultOption => 'Predeterminado';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint => 'Se utiliza al recuperar feeds RSS/Atom.';

  @override
  String get userAgentWebHint =>
      'Se utiliza al recuperar páginas web completas (Readability).';

  @override
  String get resetToDefault => 'Restablecer los valores predeterminados';

  @override
  String get notificationNewArticleTitle => 'Nuevo artículo';

  @override
  String get notificationNewArticlesTitle => 'Nuevos artículos';

  @override
  String notificationNewArticlesBody(int count) {
    return 'Se encontraron $count artículos nuevos';
  }

  @override
  String get notificationNewArticlesChannelName => 'Nuevos artículos';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Notificaciones de nuevos artículos encontrados durante la sincronización';

  @override
  String get windowMinimize => 'minimizar';

  @override
  String get windowMaximize => 'maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Cerrar';

  @override
  String get translationAndAiServices => 'Traducción e IA';

  @override
  String get translation => 'Traducción';

  @override
  String get translationProvider => 'Proveedor de traducción';

  @override
  String get aiServices => 'AI servicios';

  @override
  String get addAiService => 'Añadir servicio AI';

  @override
  String get aiService => 'AI servicio';

  @override
  String get aiSummary => 'Resumen con IA';

  @override
  String get aiSummaryService => 'AI servicio de resumen';

  @override
  String get targetLanguage => 'Idioma de destino';

  @override
  String get followAppLanguage => 'Seguir idioma de la app';

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
    return 'IA: $name';
  }

  @override
  String get translationProviderBaiduApiSubtitle =>
      'Configurar App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => 'Gratis';

  @override
  String get deepLEndpointPro => 'profesional';

  @override
  String get setAsDefault => 'Establecer como predeterminado';

  @override
  String get defaultAlreadySet => 'Predeterminado (ya configurado)';

  @override
  String get aiSummaryPrompt => 'AI mensaje de resumen';

  @override
  String get aiTranslationPrompt => 'Prompt de traducción con IA';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Resume este artículo en $language (título: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Traduce este fragmento del artículo a $language (título: $title): $content';
  }

  @override
  String get promptVariables => 'Variables disponibles';

  @override
  String get promptVariableContentDescription => 'Contenido del artículo';

  @override
  String get promptVariableLanguageDescription => 'Idioma de destino';

  @override
  String get promptVariableTitleDescription => 'Título del artículo';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 significa ilimitado; las solicitudes se pondrán en cola cuando se superen.';

  @override
  String get aiSummaryAction => 'Resumen con IA';

  @override
  String get translateAction => 'Traducir';

  @override
  String get translationMode => 'Modo de traducción';

  @override
  String get immersiveTranslation => 'Traducción inmersiva';

  @override
  String get traditionalTranslation => 'Traducción tradicional';

  @override
  String get generating => 'Generando…';

  @override
  String get queued => 'En cola';

  @override
  String get regenerate => 'regenerar';

  @override
  String get cachedPromptOutdated =>
      'Prompt actualizado; regenerar para refrescar.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Se detectó contenido en $source; el idioma de destino es $target.';
  }

  @override
  String get dontRemindThisLanguage => 'No recordar para este idioma';

  @override
  String get autoAiSummary => 'Resumen automático AI';

  @override
  String get autoTranslate => 'traducción automática';

  @override
  String get aiNotConfigured => 'AI servicio no configurado.';

  @override
  String get translationNotAvailable =>
      'La traducción no está disponible para el proveedor seleccionado.';

  @override
  String get clearTranslation => 'Traducción clara';

  @override
  String get dbRecoveryTitle => 'Recuperación de base de datos';

  @override
  String get dbRecoveryDescription =>
      'La aplicación detectó un problema en la base de datos y realizó la recuperación. Sus datos se conservaron en el disco (copia de seguridad/archivo movido).';

  @override
  String get dbRecoveryTimeLabel => 'tiempo';

  @override
  String get dbRecoveryDbNameLabel => 'nombre de base de datos';

  @override
  String get dbRecoveryOpenedAsLabel => 'Abierto como';

  @override
  String get dbRecoveryBackupPathLabel => 'Copia de seguridad';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Original movido';

  @override
  String get dbRecoveryErrorLabel => 'error';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Consejo: Utilice los botones de copiar para copiar rutas para solucionar problemas o recibir asistencia.';
}
