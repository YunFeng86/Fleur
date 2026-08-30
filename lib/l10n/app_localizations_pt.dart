// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'Não encontrado';

  @override
  String get openFailedGeneral =>
      'Não foi possível abrir este local. Verifique as permissões e tente novamente.';

  @override
  String get macosMenuLanguageRestartHint =>
      'O idioma da barra de menu pode exigir a reinicialização do aplicativo para ser totalmente aplicado.';

  @override
  String pathNotFound(Object path) {
    return 'O caminho não existe: $path';
  }

  @override
  String get settings => 'Configurações';

  @override
  String get settingsSearchHint => 'Configurações de pesquisa';

  @override
  String get settingsSearchNoResults =>
      'Nenhuma configuração corresponde a esta pesquisa.';

  @override
  String get settingsSearchPageLabel => 'Página';

  @override
  String get settingsSearchSectionLabel => 'Seção';

  @override
  String get settingsSearchSettingLabel => 'Configuração';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count resultados';
  }

  @override
  String get feeds => 'Feeds';

  @override
  String get saved => 'Salvos';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get appearance => 'Aparência';

  @override
  String get theme => 'Tema';

  @override
  String get themeMode => 'Modo tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Luz';

  @override
  String get dark => 'Escuro';

  @override
  String get dynamicColor => 'Cores dinâmicas';

  @override
  String get dynamicColorSubtitle =>
      'Siga as cores dinâmicas ou de destaque do sistema quando disponíveis';

  @override
  String get seedColorPreset => 'Cor de destaque';

  @override
  String get seedColorPresetSubtitle =>
      'Usado quando as cores dinâmicas estão desativadas/indisponíveis';

  @override
  String get seedColorBlue => 'Azul';

  @override
  String get seedColorGreen => 'Verde';

  @override
  String get seedColorPurple => 'Roxo';

  @override
  String get seedColorOrange => 'Laranja';

  @override
  String get seedColorPink => 'Rosa';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma do sistema';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Leitura';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get lineHeight => 'Altura da linha';

  @override
  String get horizontalPadding => 'Preenchimento horizontal';

  @override
  String get applicationAppearance => 'Aparência do aplicativo';

  @override
  String get readerAppearance => 'Aparência do leitor';

  @override
  String get codeAppearance => 'Aparência do código';

  @override
  String get custom => 'Personalizado';

  @override
  String get back => 'Voltar';

  @override
  String get forward => 'Avançar';

  @override
  String get fontSettings => 'Fontes';

  @override
  String get advancedFontSettings => 'Configurações avançadas de fonte';

  @override
  String get fontsAndCode => 'Fontes e código';

  @override
  String get customFontStack => 'Pilha de fontes personalizadas';

  @override
  String get codeTypography => 'Tipografia de código';

  @override
  String get fontSizeExtraSmall => 'Extra pequeno';

  @override
  String get fontSizeSmall => 'Pequeno';

  @override
  String get fontSizeMediumRecommended => 'Médio (recomendado)';

  @override
  String get fontSizeLarge => 'Grande';

  @override
  String get fontSizeExtraLarge => 'Extra grande';

  @override
  String get minimumFontSize => 'Tamanho mínimo da fonte';

  @override
  String get lineHeightCompact => 'Compacto';

  @override
  String get lineHeightStandard => 'Padrão';

  @override
  String get lineHeightRelaxed => 'Descontraído';

  @override
  String get appearancePreview => 'Visualização';

  @override
  String get appearancePreviewTitle =>
      'Uma superfície de leitura mais silenciosa';

  @override
  String get appearancePreviewMeta => 'Visualização · Hoje';

  @override
  String get appearancePreviewBody =>
      'Sintonize o leitor uma vez e deixe cada artigo abrir com o mesmo ritmo calmo.';

  @override
  String get appearancePreviewQuote =>
      'As configurações legíveis devem parecer visíveis antes de parecerem configuráveis.';

  @override
  String get appearancePreviewLink => 'Link de amostra';

  @override
  String get appearancePreviewCode => 'exemplo de código';

  @override
  String get readerFontFamily => 'Família de fontes';

  @override
  String get readerFontSystem => 'Sistema';

  @override
  String get readerFontSerif => 'Serif';

  @override
  String get readerFontSans => 'Sem';

  @override
  String get readerFontMono => 'Mono';

  @override
  String get readerFontStack => 'Lendo pilha de fontes';

  @override
  String get standardFont => 'Fonte padrão';

  @override
  String get serifFont => 'Fonte serifada';

  @override
  String get sansSerifFont => 'Fonte sem serifa';

  @override
  String get fixedWidthFont => 'Fonte de largura fixa';

  @override
  String get mathFont => 'Fonte matemática';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'Textura de leitura';

  @override
  String get readerThemeDefault => 'Padrão';

  @override
  String get readerThemePaper => 'Papel';

  @override
  String get readerThemeSepia => 'Sépia';

  @override
  String get readerThemeDim => 'Cinza suave';

  @override
  String get readingWidth => 'Largura de leitura';

  @override
  String get readingWidthNarrow => 'Estreito';

  @override
  String get readingWidthStandard => 'Padrão';

  @override
  String get readingWidthWide => 'Largo';

  @override
  String get codeFontFamily => 'Fonte do código';

  @override
  String get codeFontSystemMono => 'Sistema mono';

  @override
  String get codeFontStack => 'Pilha de fontes de código';

  @override
  String get codeFontSize => 'Tamanho da fonte do código';

  @override
  String get codeFontSizeFollowReader => 'Siga o corpo';

  @override
  String get codeFontSizeOneStepDown => 'Um passo para baixo';

  @override
  String get codeLineHeight => 'Altura da linha de código';

  @override
  String get codeSoftWrap => 'Quebrar linhas de código';

  @override
  String get storage => 'Armazenamento';

  @override
  String get clearImageCache => 'Limpar cache de imagens';

  @override
  String get clearImageCacheSubtitle =>
      'Remover imagens em cache usadas para leitura offline';

  @override
  String get cacheCleared => 'Cache limpo';

  @override
  String get subscriptions => 'Feeds';

  @override
  String get defaultsGroup => 'Globais';

  @override
  String get folders => 'Assinaturas';

  @override
  String get globalDefaults => 'Padrões globais';

  @override
  String get allSubscriptions => 'Todas as assinaturas';

  @override
  String get manage => 'Gerenciar';

  @override
  String get overview => 'Visão geral';

  @override
  String get categoriesLabel => 'Categorias';

  @override
  String get globalDefaultsDescription =>
      'Aplicado quando uma pasta ou assinatura não substitui uma configuração.';

  @override
  String get allSubscriptionsDescription =>
      'Revise a estrutura geral da assinatura e escolha uma assinatura para editar.';

  @override
  String get uncategorizedDescription =>
      'As assinaturas sem uma pasta herdam os padrões globais até serem substituídas.';

  @override
  String get tags => 'Etiquetas';

  @override
  String get all => 'Todos os artigos';

  @override
  String get uncategorized => 'Sem categoria';

  @override
  String get refreshAll => 'Atualizar fontes';

  @override
  String get refreshFeed => 'Atualizar feed';

  @override
  String get refreshCategory => 'Atualizar categoria';

  @override
  String get refreshFeedAndSync => 'Atualizar feed e sincronizar';

  @override
  String get refreshCategoryAndSync => 'Atualizar categoria e sincronizar';

  @override
  String get refreshSourcesAndSync => 'Atualizar fontes e sincronizar';

  @override
  String get accountSync => 'Sincronização de conta';

  @override
  String get accountSyncSubtitle =>
      'Sincronize esta conta remota em segundo plano.';

  @override
  String get syncAccount => 'Sincronizar conta';

  @override
  String get syncingAccount => 'Sincronizando conta...';

  @override
  String get syncedAccount => 'Conta sincronizada';

  @override
  String get refreshSelected => 'Atualizar selecionado';

  @override
  String get importOpml => 'Importar OPML';

  @override
  String get opmlParseFailed => 'Arquivo OPML inválido';

  @override
  String get exportOpml => 'Exportar OPML';

  @override
  String get addSubscription => 'Adicionar assinatura';

  @override
  String get selectCategory => 'Selecione uma categoria';

  @override
  String get loadingCategories => 'Carregando categorias...';

  @override
  String get creatingCategory => 'Criando categoria...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'As contas Fever não suportam a adição de assinaturas. Gerencie assinaturas no servidor.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'Esta ação requer conectividade com o serviço remoto.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'O serviço remoto rejeitou as credenciais da conta atual. Verifique as configurações da conta e tente novamente.';

  @override
  String get remoteCommandNeedsRefresh =>
      'O serviço remoto não correspondeu ao feed ou categoria atual. Sincronize e tente novamente.';

  @override
  String get remoteCommandRejected =>
      'O serviço remoto rejeitou esta ação. Revise a solicitação e tente novamente.';

  @override
  String get remoteCommandUnavailable =>
      'O serviço remoto não conseguiu concluir esta ação neste momento. Tente novamente mais tarde.';

  @override
  String get remoteCommandNotSupported =>
      'Esta conta remota não suporta esta ação.';

  @override
  String get remoteCommandRequiresCategory =>
      'Esta conta remota requer uma categoria do lado do servidor para a assinatura.';

  @override
  String get newCategory => 'Nova categoria';

  @override
  String get articles => 'Artigos';

  @override
  String get unread => 'Não lido';

  @override
  String get refreshConcurrency => 'Atualizar simultaneidade';

  @override
  String refreshingProgress(int current, int total) {
    return 'Atualizando $current/$total...';
  }

  @override
  String get markAllRead => 'Marcar tudo como lido';

  @override
  String get fullText => 'Texto completo';

  @override
  String get fullTextRetry =>
      'Falha ao buscar texto completo. Tentar novamente';

  @override
  String get readerSettings => 'Configurações do leitor';

  @override
  String get done => 'Concluído';

  @override
  String get more => 'Mais';

  @override
  String get showAll => 'Mostrar tudo';

  @override
  String get unreadOnly => 'Somente não lido';

  @override
  String get selectAnArticle => 'Selecione um artigo';

  @override
  String get readerEmptySubtitle => 'Abra um artigo da lista para lê-lo aqui.';

  @override
  String get searchReaderEmptyTitle => 'Selecione um resultado de pesquisa';

  @override
  String get searchReaderEmptySubtitle =>
      'Insira uma palavra-chave e abra um resultado da lista.';

  @override
  String errorMessage(String error) {
    return 'Erro: $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Falha ao obter contagem de não lidos: $error';
  }

  @override
  String get refreshed => 'Atualizado';

  @override
  String get refreshedAll => 'Atualizado tudo';

  @override
  String get refreshedAndSynced => 'Atualizado e sincronizado';

  @override
  String get add => 'Adicionar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Criar';

  @override
  String get delete => 'Excluir';

  @override
  String get deleted => 'Excluído';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'URL do feed ou site';

  @override
  String get feedOrWebsiteUrlHint => 'Cole um site ou URL RSS';

  @override
  String get findFeeds => 'Encontrar feeds';

  @override
  String get discoveringFeeds => 'Procurando feeds...';

  @override
  String get addingSubscription => 'Adicionando assinatura...';

  @override
  String get selectFeed => 'Selecionar feed';

  @override
  String get noFeedsFound => 'Nenhum feed encontrado';

  @override
  String get noFeedsFoundHint =>
      'Cole o RSS/Atom URL diretamente ou tente outra página do site.';

  @override
  String get subscriptionPreview => 'Visualização da fonte';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fontes de assinatura encontradas',
      one: '1 fonte de assinatura encontrada',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'Nenhum item de visualização recente disponível';

  @override
  String get feedSourceDirect => 'URL RSS/Atom';

  @override
  String get feedSourceAlternate => 'Descoberto na página';

  @override
  String get feedSourceCommonPath => 'Caminho comum de feed';

  @override
  String get name => 'Nome';

  @override
  String get addedAndSynced => 'Adicionado e sincronizado';

  @override
  String get subscriptionAddedTitle => 'Assinatura adicionada';

  @override
  String get subscriptionAddedMessage =>
      'A assinatura foi adicionada. Você pode abri-lo agora ou continuar adicionando mais.';

  @override
  String get subscriptionRefreshWarning =>
      'A assinatura foi adicionada, mas a primeira atualização falhou. Você pode tentar atualizar novamente mais tarde.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Já inscrito';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'Este feed já está em suas assinaturas. Nenhuma alteração de categoria foi feita.';

  @override
  String get viewSubscription => 'Ver assinatura';

  @override
  String get continueAddingSubscription => 'Continuar adicionando';

  @override
  String get moveToCurrentCategory => 'Mover para a categoria atual';

  @override
  String get deleteSubscription => 'Excluir assinatura';

  @override
  String get deleteSubscriptionConfirmTitle => 'Excluir assinatura?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'Isso também excluirá os artigos armazenados em cache.';

  @override
  String get makeAvailableOffline => 'Disponibilizar off-line';

  @override
  String get deleteCategory => 'Excluir categoria';

  @override
  String get deleteCategoryConfirmTitle => 'Excluir categoria?';

  @override
  String get deleteCategoryConfirmContent =>
      'Os feeds nesta categoria serão movidos para Sem categoria.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Exclua esta categoria no serviço remoto e reconcilie o espelho local.';

  @override
  String get remoteWritableTaxonomyTitle => 'Categorias remotas';

  @override
  String get remoteWritableTaxonomyDescription =>
      'As alterações de categoria são aplicadas no serviço remoto e depois espelhadas localmente.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Grupos remotos somente leitura';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'Essas categorias refletem grupos remotos somente leitura. Renomeie, exclua ou mova itens no serviço remoto.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle =>
      'Categoria gerenciada remotamente';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'A categoria deste feed vem de um espelho de grupo remoto somente leitura.';

  @override
  String get deleteTagConfirmTitle => 'Excluir etiqueta?';

  @override
  String get deleteTagConfirmContent => 'Isso o removerá de todos os artigos.';

  @override
  String get categoryDeleted => 'Categoria excluída';

  @override
  String get refresh => 'Atualizar';

  @override
  String get moveToCategory => 'Mover para categoria';

  @override
  String get noFeedsFoundInOpml => 'Nenhum feed encontrado em OPML';

  @override
  String importedFeeds(int count) {
    return '$count feeds importados';
  }

  @override
  String get exportedOpml => 'Exportado OPML';

  @override
  String fullTextFailed(String error) {
    return 'Falha ao buscar texto completo: $error';
  }

  @override
  String get scrollToLoadMore => 'Role para carregar mais';

  @override
  String get noArticles => 'Nenhum artigo';

  @override
  String get noUnreadArticles => 'Nenhum artigo não lido';

  @override
  String get articleListEmptySubtitle =>
      'Adicione uma assinatura ou atualize fontes e os artigos aparecerão aqui.';

  @override
  String get unreadEmptySubtitle => 'Tudo no escopo atual foi lido.';

  @override
  String get star => 'Marcar como favorito';

  @override
  String get unstar => 'Remover dos favoritos';

  @override
  String get starred => 'Favoritos';

  @override
  String get readLater => 'Lista de leitura';

  @override
  String get removeReadLater => 'Remover da lista de leitura';

  @override
  String get openArticle => 'Artigo aberto';

  @override
  String get markRead => 'Marcar como lido';

  @override
  String get markUnread => 'Marcar como não lido';

  @override
  String get collapse => 'Recolher';

  @override
  String get expand => 'Expandir';

  @override
  String get openInBrowser => 'Abrir no navegador';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get share => 'Compartilhar';

  @override
  String get autoMarkRead => 'Marcar automaticamente como lido quando aberto';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchInContent => 'Pesquisar no conteúdo';

  @override
  String get clearSearch => 'Limpar pesquisa';

  @override
  String get searchStartTitle => 'Comece a pesquisar';

  @override
  String get searchStartSubtitle =>
      'Insira palavras-chave para pesquisar títulos, resumos e conteúdo.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'Nenhum artigo corresponde a “$query”.';
  }

  @override
  String get articleNotFoundSubtitle =>
      'Este artigo pode ter sido excluído ou não está mais disponível localmente.';

  @override
  String get findInPage => 'Encontrar na página';

  @override
  String get previousMatch => 'Partida anterior';

  @override
  String get nextMatch => 'Próxima partida';

  @override
  String get caseSensitive => 'Diferencia maiúsculas de minúsculas';

  @override
  String get close => 'Fechar';

  @override
  String get groupingAndSorting => 'Agrupamento e classificação';

  @override
  String get groupBy => 'Agrupar por';

  @override
  String get groupNone => 'Nenhum';

  @override
  String get groupByDay => 'Dia';

  @override
  String get sortOrder => 'Ordem de classificação';

  @override
  String get sortNewestFirst => 'O mais novo primeiro';

  @override
  String get sortOldestFirst => 'Mais antigo primeiro';

  @override
  String get enabled => 'Habilitado';

  @override
  String get rename => 'Renomear';

  @override
  String get edit => 'Editar';

  @override
  String get nameAlreadyExists => 'O nome já existe';

  @override
  String get lastChecked => 'Última verificação';

  @override
  String get lastSynced => 'Última sincronização';

  @override
  String get never => 'Nunca';

  @override
  String get cleanupReadArticles => 'Artigos de leitura de limpeza';

  @override
  String get cleanupNow => 'Execute a limpeza';

  @override
  String cachingArticles(int count) {
    return 'Armazenando $count artigos em cache...';
  }

  @override
  String get manageTags => 'Gerenciar tags';

  @override
  String get newTag => 'Nova etiqueta';

  @override
  String get tagColor => 'Cor da etiqueta';

  @override
  String get autoColor => 'Automático';

  @override
  String get tagsLoadingError => 'Erro ao carregar tags';

  @override
  String cleanedArticles(int count) {
    return '$count artigos limpos';
  }

  @override
  String days(int days) {
    return '$days dias';
  }

  @override
  String get services => 'Serviços';

  @override
  String get account => 'Conta';

  @override
  String get connection => 'Ligação';

  @override
  String get addOrRegisterAccount => 'Adicionar ou registrar conta';

  @override
  String get local => 'locais';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Adicionar Local';

  @override
  String get addLocalAccount => 'Adicionar conta local';

  @override
  String get addMiniflux => 'Adicionar Miniflux';

  @override
  String get addGoogleReaderApi => 'Adicionar Google Reader API';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Adicionar Fever';

  @override
  String get minifluxStrategy => 'Miniflux estratégia';

  @override
  String get minifluxStrategySubtitle =>
      'Controla a quantidade de dados buscados/pré-buscados durante a sincronização.';

  @override
  String get remoteSyncStrategy => 'Estratégia de sincronização remota';

  @override
  String get remoteSyncStrategySubtitle =>
      'Controla a janela remota do artigo puxada durante a sincronização.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux pode percorrer entradas remotas até esta janela por sincronização.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Google Reader página de serviços compatíveis através de entradas de fluxo remoto até esta janela por sincronização.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever sincroniza itens não lidos e salvos, limitados por esta janela por sincronização.';

  @override
  String get remoteEntriesLimit => 'Entradas por sincronização';

  @override
  String get remoteFetchConcurrency => 'Simultaneidade de busca remota';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Controla solicitações simultâneas em lote de artigos remotos durante a sincronização da conta.';

  @override
  String get minifluxWebFetchMode => 'Busca de página da web';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'Quando \"Baixar páginas da Web durante a sincronização\" estiver ativado.';

  @override
  String get minifluxWebFetchModeClient => 'Cliente (Readability)';

  @override
  String get minifluxWebFetchModeServer =>
      'Servidor (Miniflux conteúdo de busca)';

  @override
  String get maxNetworkResponseBytes => 'Maximum network response size';

  @override
  String get maxNetworkResponseBytesSubtitle =>
      'Limits buffered responses for sync, feeds, web pages, and other network requests. A high limit is still enforced.';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String get fieldName => 'Nome';

  @override
  String get nameRequired => 'Digite um nome';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Insira a base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Insira o token API';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Insira a tecla API';

  @override
  String get authenticationMethod => 'Método de autenticação';

  @override
  String get usernamePassword => 'Nome de usuário e senha';

  @override
  String get minifluxAuthHint =>
      'Use um token API (recomendado) ou nome de usuário/senha.';

  @override
  String get feverAuthHint =>
      'Use uma chave API (recomendado) ou nome de usuário/senha.';

  @override
  String get username => 'Nome de usuário';

  @override
  String get usernameRequired => 'Digite o nome de usuário';

  @override
  String get password => 'Senha';

  @override
  String get passwordRequired => 'Digite a senha';

  @override
  String get defaultModel => 'Modelo padrão';

  @override
  String get savedApiKeyClearHint =>
      'Deixe em branco para limpar a chave API salva.';

  @override
  String get savedCredentialsClearHint =>
      'Deixe em branco para limpar as credenciais salvas.';

  @override
  String get aiServicesEmptyState => 'Nenhum serviço AI adicionado ainda.';

  @override
  String modelSummary(String model) {
    return 'Modelo: $model';
  }

  @override
  String get show => 'Mostrar';

  @override
  String get hide => 'Esconder';

  @override
  String get missingRequiredFields => 'Campos obrigatórios ausentes';

  @override
  String get invalidBaseUrl => 'Base inválida URL';

  @override
  String get onlySupportedInLocalAccount => 'Suportado apenas na conta local';

  @override
  String get autoRefresh => 'Atualização automática da fonte';

  @override
  String get autoRefreshSubtitle =>
      'Atualize as fontes de assinatura no intervalo selecionado. A atualização em segundo plano do celular é agendada pelo sistema, geralmente não mais do que a cada 15 minutos, e pode não ser executada exatamente na hora certa.';

  @override
  String get off => 'Desligado';

  @override
  String everyMinutes(int minutes) {
    return 'A cada $minutes min';
  }

  @override
  String get appPreferences => 'Preferências do app';

  @override
  String get about => 'Sobre';

  @override
  String get dataDirectory => 'Diretório de dados';

  @override
  String get copyPath => 'Copiar caminho';

  @override
  String get openFolder => 'Abrir pasta';

  @override
  String get logDirectory => 'Diretório de registros';

  @override
  String get openLog => 'Abrir registro';

  @override
  String get openLogFolder => 'Abra a pasta de registros';

  @override
  String get exportLogs => 'Exportar registros';

  @override
  String get exportedLogs => 'Registros exportados';

  @override
  String get noLogsFound => 'Nenhum arquivo de log encontrado';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get version => 'Versão';

  @override
  String get buildNumber => 'Número da versão';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return 'Versão $version · Compilação $buildNumber';
  }

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get checkingForUpdates => 'Verificando...';

  @override
  String get updateAvailable => 'Atualização';

  @override
  String get upToDate => 'Está na versão mais recente';

  @override
  String get updateCheckFailed => 'Não foi possível verificar atualizações.';

  @override
  String newVersionAvailable(Object version) {
    return 'Nova versão $version disponível';
  }

  @override
  String get releaseNotes => 'Notas da versão';

  @override
  String get goToOfficialUpdate => 'Abrir a página da versão';

  @override
  String get openSourceLicense => 'Licença de código aberto';

  @override
  String get viewLicense => 'Ver licença';

  @override
  String get thirdPartyLicenses => 'Licenças de terceiros';

  @override
  String get viewThirdPartyLicenses =>
      'Veja todas as licenças de código aberto';

  @override
  String get licenseLoadFailed => 'Falha ao carregar a licença.';

  @override
  String get mitLicenseName => 'Licença MIT';

  @override
  String get shortcutNextPreviousArticle => 'J/K: Artigo seguinte/anterior';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: histórico de retrocesso/avançamento';

  @override
  String get shortcutRefreshCurrentSelection => 'R: Atualizar (seleção atual)';

  @override
  String get shortcutToggleUnreadOnly => 'U: Alternar somente não lido';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: Alternar entre lido/não lido para o artigo selecionado';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S: Alternar estrela para artigo selecionado';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: Pesquisa artigos (lista); foco Encontrar na página (leitor)';

  @override
  String get filter => 'Filtro';

  @override
  String get filterKeywordsHint =>
      'Adicione palavras-chave reservadas (separe com \";\", conecte múltiplas com \"+\")';

  @override
  String get sync => 'Sincronização';

  @override
  String get enableSync => 'Ativar sincronização';

  @override
  String get enableFilter => 'Ativar filtro';

  @override
  String get syncAlwaysEnabled =>
      'Sempre ativado (Configurações - Sincronização - Modo de sincronização é \"Todos\")';

  @override
  String get syncImages => 'Baixar imagens durante a sincronização';

  @override
  String get syncWebPages => 'Baixe páginas da web durante a sincronização';

  @override
  String get syncStatusSyncing => 'Sincronizando';

  @override
  String get syncStatusSyncingFeeds => 'Sincronizando feeds';

  @override
  String get syncStatusSyncingSubscriptions => 'Sincronizando assinaturas';

  @override
  String get syncStatusSyncingUnreadArticles =>
      'Sincronizando artigos não lidos';

  @override
  String get syncStatusUploadingChanges => 'Fazendo upload de alterações';

  @override
  String get syncStatusCompleted => 'Sincronização concluída';

  @override
  String get syncStatusFailed => 'Falha na sincronização';

  @override
  String get showAiSummary => 'Mostrar resumo';

  @override
  String get summary => 'Resumo';

  @override
  String get showImageTitle => 'Mostrar título da imagem';

  @override
  String get showAttachedImage => 'Mostrar imagem anexada';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'Herdar';

  @override
  String get auto => 'Automático';

  @override
  String get autoOn => 'Automático (ligado)';

  @override
  String get autoOff => 'Desligado';

  @override
  String get defaultValue => 'Valor padrão';

  @override
  String get defaultOption => 'Padrão';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint => 'Usado ao buscar feeds RSS/Atom.';

  @override
  String get userAgentWebHint =>
      'Usado ao buscar páginas da web completas (Readability).';

  @override
  String get resetToDefault => 'Redefinir para o padrão';

  @override
  String get notificationNewArticleTitle => 'Novo artigo';

  @override
  String get notificationNewArticlesTitle => 'Novos artigos';

  @override
  String notificationNewArticlesBody(int count) {
    return '$count novos artigos encontrados';
  }

  @override
  String get notificationNewArticlesChannelName => 'Novos artigos';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Notificações para novos artigos encontrados durante a sincronização';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Fechar';

  @override
  String get translationAndAiServices => 'Tradução e IA';

  @override
  String get translation => 'Tradução';

  @override
  String get translationProvider => 'Provedor de tradução';

  @override
  String get aiServices => 'AI serviços';

  @override
  String get addAiService => 'Adicionar serviço AI';

  @override
  String get aiService => 'AI serviço';

  @override
  String get aiSummary => 'Resumo com IA';

  @override
  String get aiSummaryService => 'AI serviço resumido';

  @override
  String get targetLanguage => 'Idioma de destino';

  @override
  String get followAppLanguage => 'Seguir idioma do app';

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
  String get deepLEndpointFree => 'Grátis';

  @override
  String get deepLEndpointPro => 'Pró';

  @override
  String get setAsDefault => 'Definir como padrão';

  @override
  String get defaultAlreadySet => 'Padrão (já definido)';

  @override
  String get aiSummaryPrompt => 'AI prompt de resumo';

  @override
  String get aiTranslationPrompt => 'Prompt de tradução com IA';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Resuma este artigo em $language (título: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Traduza este trecho do artigo para $language (título: $title): $content';
  }

  @override
  String get promptVariables => 'Variáveis disponíveis';

  @override
  String get promptVariableContentDescription => 'Conteúdo do artigo';

  @override
  String get promptVariableLanguageDescription => 'Idioma alvo';

  @override
  String get promptVariableTitleDescription => 'Título do artigo';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 significa ilimitado; as solicitações serão enfileiradas quando excedidas.';

  @override
  String get aiSummaryAction => 'Resumo com IA';

  @override
  String get translateAction => 'Traduzir';

  @override
  String get translationMode => 'Modo de tradução';

  @override
  String get immersiveTranslation => 'Tradução imersiva';

  @override
  String get traditionalTranslation => 'Tradução tradicional';

  @override
  String get generating => 'Gerando…';

  @override
  String get queued => 'Na fila';

  @override
  String get regenerate => 'Regenerar';

  @override
  String get cachedPromptOutdated =>
      'Prompt atualizado; regenerar para atualizar.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Conteúdo possivelmente em $source; o idioma de destino é $target.';
  }

  @override
  String get dontRemindThisLanguage => 'Não lembre deste idioma';

  @override
  String get autoAiSummary => 'Resumo automático AI';

  @override
  String get autoTranslate => 'Tradução automática';

  @override
  String get aiNotConfigured => 'AI serviço não configurado.';

  @override
  String get translationNotAvailable =>
      'A tradução não está disponível para o provedor selecionado.';

  @override
  String get clearTranslation => 'Tradução clara';

  @override
  String get dbRecoveryTitle => 'Recuperação de banco de dados';

  @override
  String get dbRecoveryDescription =>
      'O aplicativo detectou um problema no banco de dados e executou a recuperação. Seus dados foram preservados em disco (backup/arquivo movido).';

  @override
  String get dbRecoveryTimeLabel => 'Hora';

  @override
  String get dbRecoveryDbNameLabel => 'Nome do banco de dados';

  @override
  String get dbRecoveryOpenedAsLabel => 'Aberto como';

  @override
  String get dbRecoveryBackupPathLabel => 'Cópia de segurança';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Original movido';

  @override
  String get dbRecoveryErrorLabel => 'Erro';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Dica: Use os botões de cópia para copiar caminhos para solução de problemas ou suporte.';

  @override
  String get provider => 'Provedor';

  @override
  String get googleReaderConnectionTitle => 'Conexão do Google Reader';

  @override
  String get keepExistingPasswordHint =>
      'Deixe em branco para manter a senha atual';

  @override
  String get testConnection => 'Testar conexão';

  @override
  String get googleReaderConnectionFailed =>
      'Falha na conexão com o Google Reader.';

  @override
  String googleReaderConnectedWith(String profile) {
    return 'Conectado: $profile';
  }

  @override
  String googleReaderConnectedAs(String profile, String user) {
    return 'Conectado: $profile - $user';
  }

  @override
  String get googleReaderConnectionSaveFailed =>
      'Falha ao salvar a conexão do Google Reader.';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'Não encontrado';

  @override
  String get openFailedGeneral =>
      'Não foi possível abrir este local. Verifique as permissões e tente novamente.';

  @override
  String get macosMenuLanguageRestartHint =>
      'O idioma da barra de menu pode exigir a reinicialização do aplicativo para ser totalmente aplicado.';

  @override
  String pathNotFound(Object path) {
    return 'O caminho não existe: $path';
  }

  @override
  String get settings => 'Configurações';

  @override
  String get settingsSearchHint => 'Configurações de pesquisa';

  @override
  String get settingsSearchNoResults =>
      'Nenhuma configuração corresponde a esta pesquisa.';

  @override
  String get settingsSearchPageLabel => 'Página';

  @override
  String get settingsSearchSectionLabel => 'Seção';

  @override
  String get settingsSearchSettingLabel => 'Configuração';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count resultados';
  }

  @override
  String get feeds => 'Feeds';

  @override
  String get saved => 'Salvos';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get appearance => 'Aparência';

  @override
  String get theme => 'Tema';

  @override
  String get themeMode => 'Modo tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Luz';

  @override
  String get dark => 'Escuro';

  @override
  String get dynamicColor => 'Cores dinâmicas';

  @override
  String get dynamicColorSubtitle =>
      'Siga as cores dinâmicas ou de destaque do sistema quando disponíveis';

  @override
  String get seedColorPreset => 'Cor de destaque';

  @override
  String get seedColorPresetSubtitle =>
      'Usado quando as cores dinâmicas estão desativadas/indisponíveis';

  @override
  String get seedColorBlue => 'Azul';

  @override
  String get seedColorGreen => 'Verde';

  @override
  String get seedColorPurple => 'Roxo';

  @override
  String get seedColorOrange => 'Laranja';

  @override
  String get seedColorPink => 'Rosa';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma do sistema';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Leitura';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get lineHeight => 'Altura da linha';

  @override
  String get horizontalPadding => 'Preenchimento horizontal';

  @override
  String get applicationAppearance => 'Aparência do aplicativo';

  @override
  String get readerAppearance => 'Aparência do leitor';

  @override
  String get codeAppearance => 'Aparência do código';

  @override
  String get custom => 'Personalizado';

  @override
  String get back => 'Voltar';

  @override
  String get forward => 'Avançar';

  @override
  String get fontSettings => 'Fontes';

  @override
  String get advancedFontSettings => 'Configurações avançadas de fonte';

  @override
  String get fontsAndCode => 'Fontes e código';

  @override
  String get customFontStack => 'Pilha de fontes personalizadas';

  @override
  String get codeTypography => 'Tipografia de código';

  @override
  String get fontSizeExtraSmall => 'Extra pequeno';

  @override
  String get fontSizeSmall => 'Pequeno';

  @override
  String get fontSizeMediumRecommended => 'Médio (recomendado)';

  @override
  String get fontSizeLarge => 'Grande';

  @override
  String get fontSizeExtraLarge => 'Extra grande';

  @override
  String get minimumFontSize => 'Tamanho mínimo da fonte';

  @override
  String get lineHeightCompact => 'Compacto';

  @override
  String get lineHeightStandard => 'Padrão';

  @override
  String get lineHeightRelaxed => 'Descontraído';

  @override
  String get appearancePreview => 'Visualização';

  @override
  String get appearancePreviewTitle =>
      'Uma superfície de leitura mais silenciosa';

  @override
  String get appearancePreviewMeta => 'Visualização · Hoje';

  @override
  String get appearancePreviewBody =>
      'Sintonize o leitor uma vez e deixe cada artigo abrir com o mesmo ritmo calmo.';

  @override
  String get appearancePreviewQuote =>
      'As configurações legíveis devem parecer visíveis antes de parecerem configuráveis.';

  @override
  String get appearancePreviewLink => 'Link de amostra';

  @override
  String get appearancePreviewCode => 'exemplo de código';

  @override
  String get readerFontFamily => 'Família de fontes';

  @override
  String get readerFontSystem => 'Sistema';

  @override
  String get readerFontSerif => 'Serif';

  @override
  String get readerFontSans => 'Sem';

  @override
  String get readerFontMono => 'Mono';

  @override
  String get readerFontStack => 'Lendo pilha de fontes';

  @override
  String get standardFont => 'Fonte padrão';

  @override
  String get serifFont => 'Fonte serifada';

  @override
  String get sansSerifFont => 'Fonte sem serifa';

  @override
  String get fixedWidthFont => 'Fonte de largura fixa';

  @override
  String get mathFont => 'Fonte matemática';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'Textura de leitura';

  @override
  String get readerThemeDefault => 'Padrão';

  @override
  String get readerThemePaper => 'Papel';

  @override
  String get readerThemeSepia => 'Sépia';

  @override
  String get readerThemeDim => 'Cinza suave';

  @override
  String get readingWidth => 'Largura de leitura';

  @override
  String get readingWidthNarrow => 'Estreito';

  @override
  String get readingWidthStandard => 'Padrão';

  @override
  String get readingWidthWide => 'Largo';

  @override
  String get codeFontFamily => 'Fonte do código';

  @override
  String get codeFontSystemMono => 'Sistema mono';

  @override
  String get codeFontStack => 'Pilha de fontes de código';

  @override
  String get codeFontSize => 'Tamanho da fonte do código';

  @override
  String get codeFontSizeFollowReader => 'Siga o corpo';

  @override
  String get codeFontSizeOneStepDown => 'Um passo para baixo';

  @override
  String get codeLineHeight => 'Altura da linha de código';

  @override
  String get codeSoftWrap => 'Quebrar linhas de código';

  @override
  String get storage => 'Armazenamento';

  @override
  String get clearImageCache => 'Limpar cache de imagens';

  @override
  String get clearImageCacheSubtitle =>
      'Remover imagens em cache usadas para leitura offline';

  @override
  String get cacheCleared => 'Cache limpo';

  @override
  String get subscriptions => 'Feeds';

  @override
  String get defaultsGroup => 'Globais';

  @override
  String get folders => 'Assinaturas';

  @override
  String get globalDefaults => 'Padrões globais';

  @override
  String get allSubscriptions => 'Todas as assinaturas';

  @override
  String get manage => 'Gerenciar';

  @override
  String get overview => 'Visão geral';

  @override
  String get categoriesLabel => 'Categorias';

  @override
  String get globalDefaultsDescription =>
      'Aplicado quando uma pasta ou assinatura não substitui uma configuração.';

  @override
  String get allSubscriptionsDescription =>
      'Revise a estrutura geral da assinatura e escolha uma assinatura para editar.';

  @override
  String get uncategorizedDescription =>
      'As assinaturas sem uma pasta herdam os padrões globais até serem substituídas.';

  @override
  String get tags => 'Etiquetas';

  @override
  String get all => 'Todos os artigos';

  @override
  String get uncategorized => 'Sem categoria';

  @override
  String get refreshAll => 'Atualizar fontes';

  @override
  String get refreshFeed => 'Atualizar feed';

  @override
  String get refreshCategory => 'Atualizar categoria';

  @override
  String get refreshFeedAndSync => 'Atualizar feed e sincronizar';

  @override
  String get refreshCategoryAndSync => 'Atualizar categoria e sincronizar';

  @override
  String get refreshSourcesAndSync => 'Atualizar fontes e sincronizar';

  @override
  String get accountSync => 'Sincronização de conta';

  @override
  String get accountSyncSubtitle =>
      'Sincronize esta conta remota em segundo plano.';

  @override
  String get syncAccount => 'Sincronizar conta';

  @override
  String get syncingAccount => 'Sincronizando conta...';

  @override
  String get syncedAccount => 'Conta sincronizada';

  @override
  String get refreshSelected => 'Atualizar selecionado';

  @override
  String get importOpml => 'Importar OPML';

  @override
  String get opmlParseFailed => 'Arquivo OPML inválido';

  @override
  String get exportOpml => 'Exportar OPML';

  @override
  String get addSubscription => 'Adicionar assinatura';

  @override
  String get selectCategory => 'Selecione uma categoria';

  @override
  String get loadingCategories => 'Carregando categorias...';

  @override
  String get creatingCategory => 'Criando categoria...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'As contas Fever não suportam a adição de assinaturas. Gerencie assinaturas no servidor.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'Esta ação requer conectividade com o serviço remoto.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'O serviço remoto rejeitou as credenciais da conta atual. Verifique as configurações da conta e tente novamente.';

  @override
  String get remoteCommandNeedsRefresh =>
      'O serviço remoto não correspondeu ao feed ou categoria atual. Sincronize e tente novamente.';

  @override
  String get remoteCommandRejected =>
      'O serviço remoto rejeitou esta ação. Revise a solicitação e tente novamente.';

  @override
  String get remoteCommandUnavailable =>
      'O serviço remoto não conseguiu concluir esta ação neste momento. Tente novamente mais tarde.';

  @override
  String get remoteCommandNotSupported =>
      'Esta conta remota não suporta esta ação.';

  @override
  String get remoteCommandRequiresCategory =>
      'Esta conta remota requer uma categoria do lado do servidor para a assinatura.';

  @override
  String get newCategory => 'Nova categoria';

  @override
  String get articles => 'Artigos';

  @override
  String get unread => 'Não lido';

  @override
  String get refreshConcurrency => 'Atualizar simultaneidade';

  @override
  String refreshingProgress(int current, int total) {
    return 'Atualizando $current/$total...';
  }

  @override
  String get markAllRead => 'Marcar tudo como lido';

  @override
  String get fullText => 'Texto completo';

  @override
  String get fullTextRetry =>
      'Falha ao buscar texto completo. Tentar novamente';

  @override
  String get readerSettings => 'Configurações do leitor';

  @override
  String get done => 'Concluído';

  @override
  String get more => 'Mais';

  @override
  String get showAll => 'Mostrar tudo';

  @override
  String get unreadOnly => 'Somente não lido';

  @override
  String get selectAnArticle => 'Selecione um artigo';

  @override
  String get readerEmptySubtitle => 'Abra um artigo da lista para lê-lo aqui.';

  @override
  String get searchReaderEmptyTitle => 'Selecione um resultado de pesquisa';

  @override
  String get searchReaderEmptySubtitle =>
      'Insira uma palavra-chave e abra um resultado da lista.';

  @override
  String errorMessage(String error) {
    return 'Erro: $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Falha ao obter contagem de não lidos: $error';
  }

  @override
  String get refreshed => 'Atualizado';

  @override
  String get refreshedAll => 'Atualizado tudo';

  @override
  String get refreshedAndSynced => 'Atualizado e sincronizado';

  @override
  String get add => 'Adicionar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Criar';

  @override
  String get delete => 'Excluir';

  @override
  String get deleted => 'Excluído';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'URL do feed ou site';

  @override
  String get feedOrWebsiteUrlHint => 'Cole um site ou URL RSS';

  @override
  String get findFeeds => 'Encontrar feeds';

  @override
  String get discoveringFeeds => 'Procurando feeds...';

  @override
  String get addingSubscription => 'Adicionando assinatura...';

  @override
  String get selectFeed => 'Selecionar feed';

  @override
  String get noFeedsFound => 'Nenhum feed encontrado';

  @override
  String get noFeedsFoundHint =>
      'Cole o RSS/Atom URL diretamente ou tente outra página do site.';

  @override
  String get subscriptionPreview => 'Visualização da fonte';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fontes de assinatura encontradas',
      one: '1 fonte de assinatura encontrada',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'Nenhum item de visualização recente disponível';

  @override
  String get feedSourceDirect => 'URL RSS/Atom';

  @override
  String get feedSourceAlternate => 'Descoberto na página';

  @override
  String get feedSourceCommonPath => 'Caminho comum de feed';

  @override
  String get name => 'Nome';

  @override
  String get addedAndSynced => 'Adicionado e sincronizado';

  @override
  String get subscriptionAddedTitle => 'Assinatura adicionada';

  @override
  String get subscriptionAddedMessage =>
      'A assinatura foi adicionada. Você pode abri-lo agora ou continuar adicionando mais.';

  @override
  String get subscriptionRefreshWarning =>
      'A assinatura foi adicionada, mas a primeira atualização falhou. Você pode tentar atualizar novamente mais tarde.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Já inscrito';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'Este feed já está em suas assinaturas. Nenhuma alteração de categoria foi feita.';

  @override
  String get viewSubscription => 'Ver assinatura';

  @override
  String get continueAddingSubscription => 'Continuar adicionando';

  @override
  String get moveToCurrentCategory => 'Mover para a categoria atual';

  @override
  String get deleteSubscription => 'Excluir assinatura';

  @override
  String get deleteSubscriptionConfirmTitle => 'Excluir assinatura?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'Isso também excluirá os artigos armazenados em cache.';

  @override
  String get makeAvailableOffline => 'Disponibilizar off-line';

  @override
  String get deleteCategory => 'Excluir categoria';

  @override
  String get deleteCategoryConfirmTitle => 'Excluir categoria?';

  @override
  String get deleteCategoryConfirmContent =>
      'Os feeds nesta categoria serão movidos para Sem categoria.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Exclua esta categoria no serviço remoto e reconcilie o espelho local.';

  @override
  String get remoteWritableTaxonomyTitle => 'Categorias remotas';

  @override
  String get remoteWritableTaxonomyDescription =>
      'As alterações de categoria são aplicadas no serviço remoto e depois espelhadas localmente.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Grupos remotos somente leitura';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'Essas categorias refletem grupos remotos somente leitura. Renomeie, exclua ou mova itens no serviço remoto.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle =>
      'Categoria gerenciada remotamente';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'A categoria deste feed vem de um espelho de grupo remoto somente leitura.';

  @override
  String get deleteTagConfirmTitle => 'Excluir etiqueta?';

  @override
  String get deleteTagConfirmContent => 'Isso o removerá de todos os artigos.';

  @override
  String get categoryDeleted => 'Categoria excluída';

  @override
  String get refresh => 'Atualizar';

  @override
  String get moveToCategory => 'Mover para categoria';

  @override
  String get noFeedsFoundInOpml => 'Nenhum feed encontrado em OPML';

  @override
  String importedFeeds(int count) {
    return '$count feeds importados';
  }

  @override
  String get exportedOpml => 'Exportado OPML';

  @override
  String fullTextFailed(String error) {
    return 'Falha ao buscar texto completo: $error';
  }

  @override
  String get scrollToLoadMore => 'Role para carregar mais';

  @override
  String get noArticles => 'Nenhum artigo';

  @override
  String get noUnreadArticles => 'Nenhum artigo não lido';

  @override
  String get articleListEmptySubtitle =>
      'Adicione uma assinatura ou atualize fontes e os artigos aparecerão aqui.';

  @override
  String get unreadEmptySubtitle => 'Tudo no escopo atual foi lido.';

  @override
  String get star => 'Marcar como favorito';

  @override
  String get unstar => 'Remover dos favoritos';

  @override
  String get starred => 'Favoritos';

  @override
  String get readLater => 'Lista de leitura';

  @override
  String get removeReadLater => 'Remover da lista de leitura';

  @override
  String get openArticle => 'Artigo aberto';

  @override
  String get markRead => 'Marcar como lido';

  @override
  String get markUnread => 'Marcar como não lido';

  @override
  String get collapse => 'Recolher';

  @override
  String get expand => 'Expandir';

  @override
  String get openInBrowser => 'Abrir no navegador';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get share => 'Compartilhar';

  @override
  String get autoMarkRead => 'Marcar automaticamente como lido quando aberto';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchInContent => 'Pesquisar no conteúdo';

  @override
  String get clearSearch => 'Limpar pesquisa';

  @override
  String get searchStartTitle => 'Comece a pesquisar';

  @override
  String get searchStartSubtitle =>
      'Insira palavras-chave para pesquisar títulos, resumos e conteúdo.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'Nenhum artigo corresponde a “$query”.';
  }

  @override
  String get articleNotFoundSubtitle =>
      'Este artigo pode ter sido excluído ou não está mais disponível localmente.';

  @override
  String get findInPage => 'Encontrar na página';

  @override
  String get previousMatch => 'Partida anterior';

  @override
  String get nextMatch => 'Próxima partida';

  @override
  String get caseSensitive => 'Diferencia maiúsculas de minúsculas';

  @override
  String get close => 'Fechar';

  @override
  String get groupingAndSorting => 'Agrupamento e classificação';

  @override
  String get groupBy => 'Agrupar por';

  @override
  String get groupNone => 'Nenhum';

  @override
  String get groupByDay => 'Dia';

  @override
  String get sortOrder => 'Ordem de classificação';

  @override
  String get sortNewestFirst => 'O mais novo primeiro';

  @override
  String get sortOldestFirst => 'Mais antigo primeiro';

  @override
  String get enabled => 'Habilitado';

  @override
  String get rename => 'Renomear';

  @override
  String get edit => 'Editar';

  @override
  String get nameAlreadyExists => 'O nome já existe';

  @override
  String get lastChecked => 'Última verificação';

  @override
  String get lastSynced => 'Última sincronização';

  @override
  String get never => 'Nunca';

  @override
  String get cleanupReadArticles => 'Artigos de leitura de limpeza';

  @override
  String get cleanupNow => 'Execute a limpeza';

  @override
  String cachingArticles(int count) {
    return 'Armazenando $count artigos em cache...';
  }

  @override
  String get manageTags => 'Gerenciar tags';

  @override
  String get newTag => 'Nova etiqueta';

  @override
  String get tagColor => 'Cor da etiqueta';

  @override
  String get autoColor => 'Automático';

  @override
  String get tagsLoadingError => 'Erro ao carregar tags';

  @override
  String cleanedArticles(int count) {
    return '$count artigos limpos';
  }

  @override
  String days(int days) {
    return '$days dias';
  }

  @override
  String get services => 'Serviços';

  @override
  String get account => 'Conta';

  @override
  String get connection => 'Conexão';

  @override
  String get addOrRegisterAccount => 'Adicionar ou registrar conta';

  @override
  String get local => 'locais';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Adicionar Local';

  @override
  String get addLocalAccount => 'Adicionar conta local';

  @override
  String get addMiniflux => 'Adicionar Miniflux';

  @override
  String get addGoogleReaderApi => 'Adicionar Google Reader API';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Adicionar Fever';

  @override
  String get minifluxStrategy => 'Miniflux estratégia';

  @override
  String get minifluxStrategySubtitle =>
      'Controla a quantidade de dados buscados/pré-buscados durante a sincronização.';

  @override
  String get remoteSyncStrategy => 'Estratégia de sincronização remota';

  @override
  String get remoteSyncStrategySubtitle =>
      'Controla a janela remota do artigo puxada durante a sincronização.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux pode percorrer entradas remotas até esta janela por sincronização.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Google Reader página de serviços compatíveis através de entradas de fluxo remoto até esta janela por sincronização.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever sincroniza itens não lidos e salvos, limitados por esta janela por sincronização.';

  @override
  String get remoteEntriesLimit => 'Entradas por sincronização';

  @override
  String get remoteFetchConcurrency => 'Simultaneidade de busca remota';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Controla solicitações simultâneas em lote de artigos remotos durante a sincronização da conta.';

  @override
  String get minifluxWebFetchMode => 'Busca de página da web';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'Quando \"Baixar páginas da Web durante a sincronização\" estiver ativado.';

  @override
  String get minifluxWebFetchModeClient => 'Cliente (Readability)';

  @override
  String get minifluxWebFetchModeServer =>
      'Servidor (Miniflux conteúdo de busca)';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String get fieldName => 'Nome';

  @override
  String get nameRequired => 'Digite um nome';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Insira a base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Insira o token API';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Insira a tecla API';

  @override
  String get authenticationMethod => 'Método de autenticação';

  @override
  String get usernamePassword => 'Nome de usuário e senha';

  @override
  String get minifluxAuthHint =>
      'Use um token API (recomendado) ou nome de usuário/senha.';

  @override
  String get feverAuthHint =>
      'Use uma chave API (recomendado) ou nome de usuário/senha.';

  @override
  String get username => 'Nome de usuário';

  @override
  String get usernameRequired => 'Digite o nome de usuário';

  @override
  String get password => 'Senha';

  @override
  String get passwordRequired => 'Digite a senha';

  @override
  String get defaultModel => 'Modelo padrão';

  @override
  String get savedApiKeyClearHint =>
      'Deixe em branco para limpar a chave API salva.';

  @override
  String get savedCredentialsClearHint =>
      'Deixe em branco para limpar as credenciais salvas.';

  @override
  String get aiServicesEmptyState => 'Nenhum serviço AI adicionado ainda.';

  @override
  String modelSummary(String model) {
    return 'Modelo: $model';
  }

  @override
  String get show => 'Mostrar';

  @override
  String get hide => 'Esconder';

  @override
  String get missingRequiredFields => 'Campos obrigatórios ausentes';

  @override
  String get invalidBaseUrl => 'Base inválida URL';

  @override
  String get onlySupportedInLocalAccount => 'Suportado apenas na conta local';

  @override
  String get autoRefresh => 'Atualização automática da fonte';

  @override
  String get autoRefreshSubtitle =>
      'Atualize as fontes de assinatura no intervalo selecionado. A atualização em segundo plano do celular é agendada pelo sistema, geralmente não mais do que a cada 15 minutos, e pode não ser executada exatamente na hora certa.';

  @override
  String get off => 'Desligado';

  @override
  String everyMinutes(int minutes) {
    return 'A cada $minutes min';
  }

  @override
  String get appPreferences => 'Preferências do app';

  @override
  String get about => 'Sobre';

  @override
  String get dataDirectory => 'Diretório de dados';

  @override
  String get copyPath => 'Copiar caminho';

  @override
  String get openFolder => 'Abrir pasta';

  @override
  String get logDirectory => 'Diretório de registros';

  @override
  String get openLog => 'Abrir registro';

  @override
  String get openLogFolder => 'Abra a pasta de registros';

  @override
  String get exportLogs => 'Exportar registros';

  @override
  String get exportedLogs => 'Registros exportados';

  @override
  String get noLogsFound => 'Nenhum arquivo de log encontrado';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get version => 'Versão';

  @override
  String get buildNumber => 'Número da versão';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return 'Versão $version · Compilação $buildNumber';
  }

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get checkingForUpdates => 'Verificando...';

  @override
  String get updateAvailable => 'Atualização';

  @override
  String get upToDate => 'Você está na versão mais recente';

  @override
  String get updateCheckFailed => 'Não foi possível verificar atualizações.';

  @override
  String newVersionAvailable(Object version) {
    return 'Nova versão $version disponível';
  }

  @override
  String get releaseNotes => 'Notas da versão';

  @override
  String get goToOfficialUpdate => 'Abrir a página da versão';

  @override
  String get openSourceLicense => 'Licença de código aberto';

  @override
  String get viewLicense => 'Ver licença';

  @override
  String get thirdPartyLicenses => 'Licenças de terceiros';

  @override
  String get viewThirdPartyLicenses =>
      'Veja todas as licenças de código aberto';

  @override
  String get licenseLoadFailed => 'Falha ao carregar a licença.';

  @override
  String get mitLicenseName => 'Licença MIT';

  @override
  String get shortcutNextPreviousArticle => 'J/K: Artigo seguinte/anterior';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: histórico de retrocesso/avançamento';

  @override
  String get shortcutRefreshCurrentSelection => 'R: Atualizar (seleção atual)';

  @override
  String get shortcutToggleUnreadOnly => 'U: Alternar somente não lido';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: Alternar entre lido/não lido para o artigo selecionado';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S: Alternar estrela para artigo selecionado';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: Pesquisa artigos (lista); foco Encontrar na página (leitor)';

  @override
  String get filter => 'Filtro';

  @override
  String get filterKeywordsHint =>
      'Adicione palavras-chave reservadas (separe com \";\", conecte múltiplas com \"+\")';

  @override
  String get sync => 'Sincronização';

  @override
  String get enableSync => 'Ativar sincronização';

  @override
  String get enableFilter => 'Ativar filtro';

  @override
  String get syncAlwaysEnabled =>
      'Sempre ativado (Configurações - Sincronização - Modo de sincronização é \"Todos\")';

  @override
  String get syncImages => 'Baixar imagens durante a sincronização';

  @override
  String get syncWebPages => 'Baixe páginas da web durante a sincronização';

  @override
  String get syncStatusSyncing => 'Sincronizando';

  @override
  String get syncStatusSyncingFeeds => 'Sincronizando feeds';

  @override
  String get syncStatusSyncingSubscriptions => 'Sincronizando assinaturas';

  @override
  String get syncStatusSyncingUnreadArticles =>
      'Sincronizando artigos não lidos';

  @override
  String get syncStatusUploadingChanges => 'Fazendo upload de alterações';

  @override
  String get syncStatusCompleted => 'Sincronização concluída';

  @override
  String get syncStatusFailed => 'Falha na sincronização';

  @override
  String get showAiSummary => 'Mostrar resumo';

  @override
  String get summary => 'Resumo';

  @override
  String get showImageTitle => 'Mostrar título da imagem';

  @override
  String get showAttachedImage => 'Mostrar imagem anexada';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'Herdar';

  @override
  String get auto => 'Automático';

  @override
  String get autoOn => 'Automático (ligado)';

  @override
  String get autoOff => 'Desligado';

  @override
  String get defaultValue => 'Valor padrão';

  @override
  String get defaultOption => 'Padrão';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint => 'Usado ao buscar feeds RSS/Atom.';

  @override
  String get userAgentWebHint =>
      'Usado ao buscar páginas da web completas (Readability).';

  @override
  String get resetToDefault => 'Redefinir para o padrão';

  @override
  String get notificationNewArticleTitle => 'Novo artigo';

  @override
  String get notificationNewArticlesTitle => 'Novos artigos';

  @override
  String notificationNewArticlesBody(int count) {
    return '$count novos artigos encontrados';
  }

  @override
  String get notificationNewArticlesChannelName => 'Novos artigos';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Notificações para novos artigos encontrados durante a sincronização';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Fechar';

  @override
  String get translationAndAiServices => 'Tradução e IA';

  @override
  String get translation => 'Tradução';

  @override
  String get translationProvider => 'Provedor de tradução';

  @override
  String get aiServices => 'AI serviços';

  @override
  String get addAiService => 'Adicionar serviço AI';

  @override
  String get aiService => 'AI serviço';

  @override
  String get aiSummary => 'Resumo com IA';

  @override
  String get aiSummaryService => 'AI serviço resumido';

  @override
  String get targetLanguage => 'Idioma de destino';

  @override
  String get followAppLanguage => 'Seguir idioma do app';

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
  String get deepLEndpointFree => 'Grátis';

  @override
  String get deepLEndpointPro => 'Pró';

  @override
  String get setAsDefault => 'Definir como padrão';

  @override
  String get defaultAlreadySet => 'Padrão (já definido)';

  @override
  String get aiSummaryPrompt => 'AI prompt de resumo';

  @override
  String get aiTranslationPrompt => 'Prompt de tradução com IA';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Resuma este artigo em $language (título: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Traduza este trecho do artigo para $language (título: $title): $content';
  }

  @override
  String get promptVariables => 'Variáveis disponíveis';

  @override
  String get promptVariableContentDescription => 'Conteúdo do artigo';

  @override
  String get promptVariableLanguageDescription => 'Idioma alvo';

  @override
  String get promptVariableTitleDescription => 'Título do artigo';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 significa ilimitado; as solicitações serão enfileiradas quando excedidas.';

  @override
  String get aiSummaryAction => 'Resumo com IA';

  @override
  String get translateAction => 'Traduzir';

  @override
  String get translationMode => 'Modo de tradução';

  @override
  String get immersiveTranslation => 'Tradução imersiva';

  @override
  String get traditionalTranslation => 'Tradução tradicional';

  @override
  String get generating => 'Gerando…';

  @override
  String get queued => 'Na fila';

  @override
  String get regenerate => 'Regenerar';

  @override
  String get cachedPromptOutdated =>
      'Prompt atualizado; regenerar para atualizar.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Conteúdo possivelmente em $source; o idioma de destino é $target.';
  }

  @override
  String get dontRemindThisLanguage => 'Não lembre deste idioma';

  @override
  String get autoAiSummary => 'Resumo automático AI';

  @override
  String get autoTranslate => 'Tradução automática';

  @override
  String get aiNotConfigured => 'AI serviço não configurado.';

  @override
  String get translationNotAvailable =>
      'A tradução não está disponível para o provedor selecionado.';

  @override
  String get clearTranslation => 'Tradução clara';

  @override
  String get dbRecoveryTitle => 'Recuperação de banco de dados';

  @override
  String get dbRecoveryDescription =>
      'O aplicativo detectou um problema no banco de dados e executou a recuperação. Seus dados foram preservados em disco (backup/arquivo movido).';

  @override
  String get dbRecoveryTimeLabel => 'Hora';

  @override
  String get dbRecoveryDbNameLabel => 'Nome do banco de dados';

  @override
  String get dbRecoveryOpenedAsLabel => 'Aberto como';

  @override
  String get dbRecoveryBackupPathLabel => 'Cópia de segurança';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Original movido';

  @override
  String get dbRecoveryErrorLabel => 'Erro';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Dica: Use os botões de cópia para copiar caminhos para solução de problemas ou suporte.';

  @override
  String get provider => 'Provedor';

  @override
  String get googleReaderConnectionTitle => 'Conexão do Google Reader';

  @override
  String get keepExistingPasswordHint =>
      'Deixe em branco para manter a senha atual';

  @override
  String get testConnection => 'Testar conexão';

  @override
  String get googleReaderConnectionFailed =>
      'Falha na conexão com o Google Reader.';

  @override
  String googleReaderConnectedWith(String profile) {
    return 'Conectado: $profile';
  }

  @override
  String googleReaderConnectedAs(String profile, String user) {
    return 'Conectado: $profile - $user';
  }

  @override
  String get googleReaderConnectionSaveFailed =>
      'Falha ao salvar a conexão do Google Reader.';
}
