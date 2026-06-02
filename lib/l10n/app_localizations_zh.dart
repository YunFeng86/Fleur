// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => '未找到';

  @override
  String get openFailedGeneral => '无法打开该位置，请检查权限或稍后重试。';

  @override
  String get macosMenuLanguageRestartHint => '菜单栏语言可能需要重启应用才能完全生效。';

  @override
  String pathNotFound(Object path) {
    return '路径不存在：$path';
  }

  @override
  String get settings => '设置';

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsSearchNoResults => '没有匹配的设置。';

  @override
  String get settingsSearchPageLabel => '页面';

  @override
  String get settingsSearchSectionLabel => '分区';

  @override
  String get settingsSearchSettingLabel => '设置项';

  @override
  String get feeds => '订阅';

  @override
  String get saved => '收藏';

  @override
  String get comingSoon => '敬请期待';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeMode => '主题模式';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get dynamicColor => '动态取色';

  @override
  String get dynamicColorSubtitle => '使用 Material You 动态配色（仅 Android 12+）';

  @override
  String get seedColorPreset => '主题配色';

  @override
  String get seedColorPresetSubtitle => '动态取色关闭或不可用时生效';

  @override
  String get seedColorBlue => '蓝色';

  @override
  String get seedColorGreen => '绿色';

  @override
  String get seedColorPurple => '紫色';

  @override
  String get seedColorOrange => '橙色';

  @override
  String get seedColorPink => '粉色';

  @override
  String get language => '语言';

  @override
  String get systemLanguage => '系统语言';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => '阅读';

  @override
  String get fontSize => '字号';

  @override
  String get lineHeight => '行高';

  @override
  String get horizontalPadding => '左右边距';

  @override
  String get storage => '存储';

  @override
  String get clearImageCache => '清理图片缓存';

  @override
  String get clearImageCacheSubtitle => '移除离线阅读预取的图片缓存';

  @override
  String get cacheCleared => '缓存已清理';

  @override
  String get subscriptions => '订阅源';

  @override
  String get defaultsGroup => '全局';

  @override
  String get folders => '订阅源';

  @override
  String get globalDefaults => '全局默认';

  @override
  String get allSubscriptions => '全部项目';

  @override
  String get manage => '管理';

  @override
  String get overview => '概览';

  @override
  String get categoriesLabel => '分类数';

  @override
  String get globalDefaultsDescription => '当文件夹或订阅源未覆盖设置时，会继承这里的默认值。';

  @override
  String get allSubscriptionsDescription => '在这里查看整体订阅结构，并选择具体项目继续编辑。';

  @override
  String get uncategorizedDescription => '未分类的订阅源会继承全局默认，直到你为它们单独覆盖设置。';

  @override
  String get tags => '标签';

  @override
  String get all => '所有文章';

  @override
  String get uncategorized => '未分类';

  @override
  String get refreshAll => '刷新订阅源';

  @override
  String get refreshFeed => '刷新当前订阅源';

  @override
  String get refreshCategory => '刷新当前分类';

  @override
  String get refreshFeedAndSync => '刷新当前订阅源并同步';

  @override
  String get refreshCategoryAndSync => '刷新当前分类并同步';

  @override
  String get refreshSourcesAndSync => '刷新订阅源并同步';

  @override
  String get accountSync => '账号同步';

  @override
  String get accountSyncSubtitle => '在后台同步这个远程账号。';

  @override
  String get syncAccount => '同步账号';

  @override
  String get syncingAccount => '正在同步账号...';

  @override
  String get syncedAccount => '账号已同步';

  @override
  String get refreshSelected => '刷新当前';

  @override
  String get importOpml => '导入 OPML';

  @override
  String get opmlParseFailed => 'OPML 文件无效';

  @override
  String get exportOpml => '导出 OPML';

  @override
  String get addSubscription => '添加订阅';

  @override
  String get selectCategory => '选择分类';

  @override
  String get loadingCategories => '正在加载分类...';

  @override
  String get creatingCategory => '正在创建分类...';

  @override
  String get feverAddSubscriptionNotSupported => 'Fever 账号不支持添加订阅，请在服务端管理订阅。';

  @override
  String get remoteCommandRequiresConnectivity => '此操作需要连接远程服务后才能完成。';

  @override
  String get remoteCommandRequiresAuthentication => '远程服务拒绝了当前账号凭据，请检查账号设置后重试。';

  @override
  String get remoteCommandNeedsRefresh => '远程服务无法匹配当前订阅或分类，请先同步后重试。';

  @override
  String get remoteCommandRejected => '远程服务拒绝了这次操作，请检查请求内容后重试。';

  @override
  String get remoteCommandUnavailable => '远程服务暂时无法完成此操作，请稍后再试。';

  @override
  String get remoteCommandNotSupported => '当前远程账号不支持这个操作。';

  @override
  String get remoteCommandRequiresCategory => '当前远程账号要求订阅必须归属服务端分类。';

  @override
  String get newCategory => '新建分类';

  @override
  String get articles => '文章';

  @override
  String get unread => '未读';

  @override
  String get refreshConcurrency => '刷新并发数';

  @override
  String refreshingProgress(int current, int total) {
    return '正在刷新 $current/$total...';
  }

  @override
  String get markAllRead => '全部已读';

  @override
  String get fullText => '阅读全文';

  @override
  String get fullTextRetry => '获取全文失败，重试';

  @override
  String get readerSettings => '阅读设置';

  @override
  String get done => '完成';

  @override
  String get more => '更多';

  @override
  String get showAll => '显示全部';

  @override
  String get unreadOnly => '只看未读';

  @override
  String get selectAnArticle => '请选择一篇文章';

  @override
  String get readerEmptySubtitle => '从左侧列表打开文章后，会在这里阅读。';

  @override
  String get savedReaderEmptyTitle => '选择一篇收藏';

  @override
  String get savedReaderEmptySubtitle => '从已收藏或稍后读列表中打开文章。';

  @override
  String get searchReaderEmptyTitle => '选择一条搜索结果';

  @override
  String get searchReaderEmptySubtitle => '输入关键词后，从左侧结果中打开文章。';

  @override
  String errorMessage(String error) {
    return '错误：$error';
  }

  @override
  String unreadCountError(String error) {
    return '未读数获取失败：$error';
  }

  @override
  String get refreshed => '已刷新';

  @override
  String get refreshedAll => '全部已刷新';

  @override
  String get refreshedAndSynced => '已刷新并同步';

  @override
  String get add => '添加';

  @override
  String get cancel => '取消';

  @override
  String get create => '创建';

  @override
  String get delete => '删除';

  @override
  String get deleted => '已删除';

  @override
  String get rssAtomUrl => 'RSS/Atom 地址';

  @override
  String get feedOrWebsiteUrl => '订阅源或网站 URL';

  @override
  String get feedOrWebsiteUrlHint => '粘贴网站地址或 RSS URL';

  @override
  String get findFeeds => '查找订阅源';

  @override
  String get discoveringFeeds => '正在发现订阅源…';

  @override
  String get addingSubscription => '正在添加订阅…';

  @override
  String get selectFeed => '选择订阅源';

  @override
  String get noFeedsFound => '未找到可用的订阅源';

  @override
  String get noFeedsFoundHint => '可以直接粘贴 RSS/Atom 地址，或试试这个网站的其他页面。';

  @override
  String get subscriptionPreview => '来源预览';

  @override
  String subscriptionResultsFound(int count) {
    return '已找到 $count 个订阅源';
  }

  @override
  String get subscriptionPreviewUnavailable => '暂无可预览的最近文章';

  @override
  String get feedSourceDirect => 'RSS/Atom 地址';

  @override
  String get feedSourceAlternate => '页面声明';

  @override
  String get feedSourceCommonPath => '常见订阅路径';

  @override
  String get name => '名称';

  @override
  String get addedAndSynced => '已添加并同步';

  @override
  String get subscriptionAddedTitle => '订阅已添加';

  @override
  String get subscriptionAddedMessage => '订阅已添加。你可以现在查看，也可以继续添加更多订阅。';

  @override
  String get subscriptionRefreshWarning => '订阅已添加，但首次刷新失败。你可以稍后重新刷新。';

  @override
  String get subscriptionAlreadyExistsTitle => '已经订阅';

  @override
  String get subscriptionAlreadyExistsMessage => '这个订阅源已经在你的订阅列表中，没有改动它的分类。';

  @override
  String get viewSubscription => '查看订阅';

  @override
  String get continueAddingSubscription => '继续添加';

  @override
  String get moveToCurrentCategory => '移到当前分类';

  @override
  String get deleteSubscription => '删除订阅';

  @override
  String get deleteSubscriptionConfirmTitle => '删除订阅？';

  @override
  String get deleteSubscriptionConfirmContent => '确定要删除此订阅源吗？';

  @override
  String get makeAvailableOffline => '离线可用';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get deleteCategoryConfirmTitle => '删除分类？';

  @override
  String get deleteCategoryConfirmContent => '该分类下的订阅源将移动到未分类。';

  @override
  String get remoteDeleteCategoryConfirmContent => '将先在远程服务上删除该分类，然后回刷本地镜像。';

  @override
  String get remoteWritableTaxonomyTitle => '远程分类';

  @override
  String get remoteWritableTaxonomyDescription => '分类变更会应用到远程服务，并同步回本地镜像。';

  @override
  String get remoteReadOnlyTaxonomyTitle => '只读远程分组';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      '这些分类来自只读远程分组镜像。重命名、删除或移动请在远程服务中管理。';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => '分类由远程管理';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription => '这个订阅源的分类来自只读远程分组镜像。';

  @override
  String get deleteTagConfirmTitle => '删除标签？';

  @override
  String get deleteTagConfirmContent => '这会从所有文章中移除该标签。';

  @override
  String get categoryDeleted => '分类已删除';

  @override
  String get refresh => '刷新';

  @override
  String get moveToCategory => '移动到分类';

  @override
  String get noFeedsFoundInOpml => 'OPML 中未找到订阅';

  @override
  String importedFeeds(int count) {
    return '已导入 $count 个订阅';
  }

  @override
  String get exportedOpml => '已导出 OPML';

  @override
  String fullTextFailed(String error) {
    return '获取全文失败：$error';
  }

  @override
  String get scrollToLoadMore => '滚动以加载更多';

  @override
  String get noArticles => '暂无文章';

  @override
  String get noStarredArticles => '暂无收藏文章';

  @override
  String get noReadLaterArticles => '暂无稍后读文章';

  @override
  String get noUnreadArticles => '暂无未读文章';

  @override
  String get articleListEmptySubtitle => '添加订阅或同步后，文章会出现在这里。';

  @override
  String get unreadEmptySubtitle => '当前筛选范围内的文章都已读完。';

  @override
  String get savedSearchEmptySubtitle => '当前收藏中没有匹配结果。';

  @override
  String get star => '收藏';

  @override
  String get unstar => '取消收藏';

  @override
  String get starred => '已收藏';

  @override
  String get readLater => '稍后读';

  @override
  String get removeReadLater => '移出稍后读';

  @override
  String get openArticle => '打开文章';

  @override
  String get markRead => '标记为已读';

  @override
  String get markUnread => '标记为未读';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展开';

  @override
  String get openInBrowser => '在浏览器打开';

  @override
  String get copyLink => '复制链接';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get share => '分享';

  @override
  String get autoMarkRead => '打开时自动标记为已读';

  @override
  String get search => '搜索';

  @override
  String get searchInContent => '搜索正文';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get searchStartTitle => '开始搜索';

  @override
  String get searchStartSubtitle => '输入关键词查找标题、摘要和正文。';

  @override
  String searchNoResultsSubtitle(Object query) {
    return '没有匹配“$query”的文章。';
  }

  @override
  String get articleNotFoundSubtitle => '这篇文章可能已被删除，或本地暂时不可用。';

  @override
  String get findInPage => '页面内查找';

  @override
  String get previousMatch => '上一个匹配';

  @override
  String get nextMatch => '下一个匹配';

  @override
  String get caseSensitive => '区分大小写';

  @override
  String get close => '关闭';

  @override
  String get groupingAndSorting => '分组与排序';

  @override
  String get groupBy => '分组方式';

  @override
  String get groupNone => '不分组';

  @override
  String get groupByDay => '按日期';

  @override
  String get sortOrder => '排序';

  @override
  String get sortNewestFirst => '最新优先';

  @override
  String get sortOldestFirst => '最旧优先';

  @override
  String get enabled => '启用';

  @override
  String get rename => '重命名';

  @override
  String get edit => '编辑';

  @override
  String get nameAlreadyExists => '名称已存在';

  @override
  String get lastChecked => '上次检查';

  @override
  String get lastSynced => '上次同步';

  @override
  String get never => '从未';

  @override
  String get cleanupReadArticles => '清理已读文章';

  @override
  String get cleanupNow => '立即清理';

  @override
  String cachingArticles(int count) {
    return '正在缓存 $count 篇文章...';
  }

  @override
  String get manageTags => '管理标签';

  @override
  String get newTag => '新标签';

  @override
  String get tagColor => '标签颜色';

  @override
  String get autoColor => '自动';

  @override
  String get tagsLoadingError => '加载标签失败';

  @override
  String cleanedArticles(int count) {
    return '已清理 $count 篇文章';
  }

  @override
  String days(int days) {
    return '$days 天';
  }

  @override
  String get services => '服务';

  @override
  String get account => '账号';

  @override
  String get addOrRegisterAccount => '添加或注册账号';

  @override
  String get local => '本地';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => '添加本地';

  @override
  String get addLocalAccount => '添加本地账号';

  @override
  String get addMiniflux => '添加 Miniflux';

  @override
  String get addFever => '添加 Fever';

  @override
  String get minifluxStrategy => 'Miniflux 策略';

  @override
  String get minifluxStrategySubtitle => '控制同步时拉取量与预取行为。';

  @override
  String get remoteSyncStrategy => '远程同步策略';

  @override
  String get remoteSyncStrategySubtitle => '控制同步时拉取的远程文章窗口。';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux 会分页拉取远程文章，最多到这个每次同步窗口。';

  @override
  String get remoteSyncStrategyFeverSubtitle => 'Fever 同步未读和收藏条目，并受这个每次同步窗口限制。';

  @override
  String get remoteEntriesLimit => '每次同步拉取条数';

  @override
  String get remoteFetchConcurrency => '远端拉取并发数';

  @override
  String get remoteFetchConcurrencySubtitle => '控制账号同步文章批次时的并发请求数。';

  @override
  String get minifluxWebFetchMode => '网页抓取方式';

  @override
  String get minifluxWebFetchModeSubtitle => '当订阅开启“同步时下载 Web 页面”时生效。';

  @override
  String get minifluxWebFetchModeClient => '客户端（Readability）';

  @override
  String get minifluxWebFetchModeServer => '服务端（Miniflux fetch-content）';

  @override
  String get unlimited => '无限制';

  @override
  String get fieldName => '名称';

  @override
  String get nameRequired => '请输入名称';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => '请输入 Base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => '请输入 API Token';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => '请输入 API Key';

  @override
  String get authenticationMethod => '认证方式';

  @override
  String get usernamePassword => '用户名与密码';

  @override
  String get minifluxAuthHint => '可填写 API Token（推荐）或用户名/密码。';

  @override
  String get feverAuthHint => '可填写 API Key（推荐）或用户名/密码。';

  @override
  String get username => '用户名';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get password => '密码';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get defaultModel => '默认模型';

  @override
  String get savedApiKeyClearHint => '留空会清除已保存的 API Key。';

  @override
  String get savedCredentialsClearHint => '留空会清除已保存的凭据。';

  @override
  String get aiServicesEmptyState => '还没有添加任何 AI 服务。';

  @override
  String modelSummary(String model) {
    return '模型：$model';
  }

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get missingRequiredFields => '请填写必填项';

  @override
  String get invalidBaseUrl => 'Base URL 无效';

  @override
  String get onlySupportedInLocalAccount => '仅本地账号支持此操作';

  @override
  String get autoRefresh => '自动刷新订阅源';

  @override
  String get autoRefreshSubtitle =>
      '按所选周期刷新订阅源；移动端后台刷新由系统调度，通常不会短于 15 分钟，且不保证准点。';

  @override
  String get off => '关闭';

  @override
  String everyMinutes(int minutes) {
    return '每 $minutes 分钟';
  }

  @override
  String get appPreferences => '应用偏好';

  @override
  String get about => '关于';

  @override
  String get dataDirectory => '数据目录';

  @override
  String get copyPath => '复制路径';

  @override
  String get openFolder => '打开文件夹';

  @override
  String get logDirectory => '日志目录';

  @override
  String get openLog => '打开日志';

  @override
  String get openLogFolder => '打开日志文件夹';

  @override
  String get exportLogs => '导出日志';

  @override
  String get exportedLogs => '日志已导出';

  @override
  String get noLogsFound => '未找到日志文件';

  @override
  String get keyboardShortcuts => '快捷键';

  @override
  String get version => '版本号';

  @override
  String get buildNumber => '构建号';

  @override
  String get openSourceLicense => '开源许可证';

  @override
  String get viewLicense => '查看许可证';

  @override
  String get thirdPartyLicenses => '第三方许可证';

  @override
  String get viewThirdPartyLicenses => '查看所有开源许可证';

  @override
  String get licenseLoadFailed => '加载许可证失败。';

  @override
  String get mitLicenseName => 'MIT 许可证';

  @override
  String get shortcutNextPreviousArticle => 'J / K：下一篇 / 上一篇文章';

  @override
  String get shortcutRefreshCurrentSelection => 'R：刷新（当前选中项）';

  @override
  String get shortcutToggleUnreadOnly => 'U：切换仅未读';

  @override
  String get shortcutToggleReadUnreadSelectedArticle => 'M：切换所选文章的已读 / 未读';

  @override
  String get shortcutToggleStarSelectedArticle => 'S：切换所选文章的星标状态';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F：搜索文章（列表）；聚焦页内查找（阅读器）';

  @override
  String get filter => '过滤';

  @override
  String get filterKeywordsHint => '添加保留关键字（不同的关键字用“;”分隔，多重条件使用“+”连接）';

  @override
  String get sync => '同步';

  @override
  String get enableSync => '启用同步';

  @override
  String get enableFilter => '启用过滤';

  @override
  String get syncAlwaysEnabled => '总是启用，因为设置 - 同步 - 同步模式为\"全部\"';

  @override
  String get syncImages => '同步时下载图片';

  @override
  String get syncWebPages => '同步时下载 Web 页面';

  @override
  String get syncStatusSyncing => '同步中';

  @override
  String get syncStatusSyncingFeeds => '同步订阅源';

  @override
  String get syncStatusSyncingSubscriptions => '同步订阅';

  @override
  String get syncStatusSyncingUnreadArticles => '同步未读文章';

  @override
  String get syncStatusUploadingChanges => '上传更改';

  @override
  String get syncStatusCompleted => '同步完成';

  @override
  String get syncStatusFailed => '同步失败';

  @override
  String get showAiSummary => '显示摘要';

  @override
  String get summary => '摘要';

  @override
  String get showImageTitle => '显示图片标题';

  @override
  String get showAttachedImage => '显示附文图像';

  @override
  String get htmlDecoding => 'HTML 转码';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => '继承';

  @override
  String get auto => '自动';

  @override
  String get autoOn => '开';

  @override
  String get autoOff => '关';

  @override
  String get defaultValue => '默认值';

  @override
  String get defaultOption => '默认';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => '网页 User-Agent';

  @override
  String get userAgentRssHint => '用于抓取 RSS/Atom 订阅源。';

  @override
  String get userAgentWebHint => '用于抓取网页全文（阅读模式）。';

  @override
  String get resetToDefault => '恢复默认';

  @override
  String get notificationNewArticleTitle => '新文章';

  @override
  String get notificationNewArticlesTitle => '新文章';

  @override
  String notificationNewArticlesBody(int count) {
    return '发现 $count 篇新文章';
  }

  @override
  String get notificationNewArticlesChannelName => '新文章';

  @override
  String get notificationNewArticlesChannelDescription => '同步时发现新文章的通知';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowClose => '关闭';

  @override
  String get translationAndAiServices => '翻译与 AI 服务';

  @override
  String get translation => '翻译';

  @override
  String get translationProvider => '翻译提供方';

  @override
  String get aiServices => 'AI 服务';

  @override
  String get addAiService => '添加 AI 服务';

  @override
  String get aiService => 'AI 服务';

  @override
  String get aiSummary => 'AI 总结';

  @override
  String get aiSummaryService => 'AI 总结服务';

  @override
  String get targetLanguage => '目标语言';

  @override
  String get followAppLanguage => '跟随软件语言';

  @override
  String get translationProviderGoogleWeb => 'Google 翻译（网页）';

  @override
  String get translationProviderBingWeb => 'Bing 翻译（网页）';

  @override
  String get translationProviderBaiduApi => '百度翻译（API）';

  @override
  String get translationProviderDeepLApi => 'DeepL（API）';

  @override
  String get translationProviderDeepLX => 'DeepLX';

  @override
  String translationProviderAiService(Object name) {
    return 'AI：$name';
  }

  @override
  String get translationProviderBaiduApiSubtitle => '配置 App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => '免费版';

  @override
  String get deepLEndpointPro => '专业版';

  @override
  String get setAsDefault => '设为默认';

  @override
  String get defaultAlreadySet => '默认（已设置）';

  @override
  String get aiSummaryPrompt => 'AI 总结提示词';

  @override
  String get aiTranslationPrompt => 'AI 翻译提示词';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '请用 $language 总结这篇文章（标题：$title）：$content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '请将这段文章内容翻译成 $language（标题：$title）：$content';
  }

  @override
  String get promptVariables => '可用变量';

  @override
  String get promptVariableContentDescription => '文章正文';

  @override
  String get promptVariableLanguageDescription => '目标语言';

  @override
  String get promptVariableTitleDescription => '文章标题';

  @override
  String get tpmLimit => 'TPM 限制';

  @override
  String get tpmLimitSubtitle => '0 表示不限制；超出后将进入队列等待。';

  @override
  String get aiSummaryAction => 'AI 总结';

  @override
  String get translateAction => '翻译';

  @override
  String get translationMode => '翻译模式';

  @override
  String get immersiveTranslation => '沉浸式翻译';

  @override
  String get traditionalTranslation => '传统翻译';

  @override
  String get generating => '生成中…';

  @override
  String get queued => '排队中';

  @override
  String get regenerate => '重新生成';

  @override
  String get cachedPromptOutdated => 'Prompt 已更新，请重新生成。';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return '检测到内容可能是 $source，目标语言是 $target。';
  }

  @override
  String get dontRemindThisLanguage => '不再提醒此语言';

  @override
  String get autoAiSummary => '自动 AI 总结';

  @override
  String get autoTranslate => '自动翻译';

  @override
  String get aiNotConfigured => '尚未配置 AI 服务。';

  @override
  String get translationNotAvailable => '所选翻译提供方暂不支持。';

  @override
  String get clearTranslation => '关闭翻译';

  @override
  String get dbRecoveryTitle => '数据库恢复';

  @override
  String get dbRecoveryDescription =>
      '应用检测到数据库异常，已自动进行恢复。你的数据已在磁盘上保留（备份/已移动的原库文件）。';

  @override
  String get dbRecoveryTimeLabel => '时间';

  @override
  String get dbRecoveryDbNameLabel => '数据库名';

  @override
  String get dbRecoveryOpenedAsLabel => '实际打开为';

  @override
  String get dbRecoveryBackupPathLabel => '备份';

  @override
  String get dbRecoveryMovedOriginalPathLabel => '已移动原库';

  @override
  String get dbRecoveryErrorLabel => '错误';

  @override
  String get dbRecoveryDataPreservedHint => '提示：可使用右侧复制按钮复制路径，便于排查或反馈。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => '未找到';

  @override
  String get openFailedGeneral => '無法打開該位置，請檢查權限或稍後重試。';

  @override
  String get macosMenuLanguageRestartHint => '選單列語言可能需要重新啟動應用程式才能完全生效。';

  @override
  String pathNotFound(Object path) {
    return '路徑不存在：$path';
  }

  @override
  String get settings => '設定';

  @override
  String get settingsSearchHint => '搜尋設定';

  @override
  String get settingsSearchNoResults => '沒有符合的設定。';

  @override
  String get settingsSearchPageLabel => '頁面';

  @override
  String get settingsSearchSectionLabel => '區段';

  @override
  String get settingsSearchSettingLabel => '設定項';

  @override
  String get feeds => '訂閱';

  @override
  String get saved => '收藏';

  @override
  String get comingSoon => '敬請期待';

  @override
  String get appearance => '外觀';

  @override
  String get theme => '主題';

  @override
  String get themeMode => '主題模式';

  @override
  String get system => '跟隨系統';

  @override
  String get light => '淺色';

  @override
  String get dark => '深色';

  @override
  String get dynamicColor => '動態取色';

  @override
  String get dynamicColorSubtitle => '使用 Material You 動態配色（僅 Android 12+）';

  @override
  String get seedColorPreset => '主題配色';

  @override
  String get seedColorPresetSubtitle => '動態取色關閉或不可用時生效';

  @override
  String get seedColorBlue => '藍色';

  @override
  String get seedColorGreen => '綠色';

  @override
  String get seedColorPurple => '紫色';

  @override
  String get seedColorOrange => '橙色';

  @override
  String get seedColorPink => '粉色';

  @override
  String get language => '語言';

  @override
  String get systemLanguage => '系統語言';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => '閱讀';

  @override
  String get fontSize => '字號';

  @override
  String get lineHeight => '行高';

  @override
  String get horizontalPadding => '左右邊距';

  @override
  String get storage => '儲存';

  @override
  String get clearImageCache => '清理圖片快取';

  @override
  String get clearImageCacheSubtitle => '移除離線閱讀預取的圖片快取';

  @override
  String get cacheCleared => '快取已清理';

  @override
  String get subscriptions => '訂閱源';

  @override
  String get defaultsGroup => '全域';

  @override
  String get folders => '訂閱源';

  @override
  String get globalDefaults => '全域預設';

  @override
  String get allSubscriptions => '全部項目';

  @override
  String get manage => '管理';

  @override
  String get overview => '概覽';

  @override
  String get categoriesLabel => '分類數';

  @override
  String get globalDefaultsDescription => '當資料夾或訂閱源沒有覆寫設定時，會繼承這裡的預設值。';

  @override
  String get allSubscriptionsDescription => '在這裡查看整體訂閱結構，並選擇具體項目繼續編輯。';

  @override
  String get uncategorizedDescription => '未分類的訂閱源會繼承全域預設，直到你為它們單獨覆寫設定。';

  @override
  String get tags => '標籤';

  @override
  String get all => '所有文章';

  @override
  String get uncategorized => '未分類';

  @override
  String get refreshAll => '重新整理訂閱源';

  @override
  String get refreshFeed => '重新整理目前訂閱源';

  @override
  String get refreshCategory => '重新整理目前分類';

  @override
  String get refreshFeedAndSync => '重新整理目前訂閱源並同步';

  @override
  String get refreshCategoryAndSync => '重新整理目前分類並同步';

  @override
  String get refreshSourcesAndSync => '重新整理訂閱源並同步';

  @override
  String get accountSync => '帳號同步';

  @override
  String get accountSyncSubtitle => '在背景同步這個遠端帳號。';

  @override
  String get syncAccount => '同步帳號';

  @override
  String get syncingAccount => '正在同步帳號...';

  @override
  String get syncedAccount => '帳號已同步';

  @override
  String get refreshSelected => '重新整理當前';

  @override
  String get importOpml => '匯入 OPML';

  @override
  String get opmlParseFailed => 'OPML 檔案無效';

  @override
  String get exportOpml => '匯出 OPML';

  @override
  String get addSubscription => '新增訂閱';

  @override
  String get selectCategory => '選擇分類';

  @override
  String get loadingCategories => '正在載入分類...';

  @override
  String get creatingCategory => '正在建立分類...';

  @override
  String get feverAddSubscriptionNotSupported => 'Fever 帳號不支援新增訂閱，請在伺服器端管理訂閱。';

  @override
  String get remoteCommandRequiresConnectivity => '此操作需要連線到遠端服務後才能完成。';

  @override
  String get remoteCommandRequiresAuthentication => '遠端服務拒絕了目前帳號憑證，請檢查帳號設定後再試。';

  @override
  String get remoteCommandNeedsRefresh => '遠端服務無法匹配目前的訂閱或分類，請先同步後再試。';

  @override
  String get remoteCommandRejected => '遠端服務拒絕了這次操作，請檢查請求內容後再試。';

  @override
  String get remoteCommandUnavailable => '遠端服務暫時無法完成此操作，請稍後再試。';

  @override
  String get remoteCommandNotSupported => '目前的遠端帳號不支援這個操作。';

  @override
  String get remoteCommandRequiresCategory => '目前的遠端帳號要求訂閱必須歸屬伺服器分類。';

  @override
  String get newCategory => '新增分類';

  @override
  String get articles => '文章';

  @override
  String get unread => '未讀';

  @override
  String get refreshConcurrency => '重新整理並發數';

  @override
  String refreshingProgress(int current, int total) {
    return '正在重新整理 $current/$total...';
  }

  @override
  String get markAllRead => '全部已讀';

  @override
  String get fullText => '閱讀全文';

  @override
  String get fullTextRetry => '取得全文失敗，重試';

  @override
  String get readerSettings => '閱讀設定';

  @override
  String get done => '完成';

  @override
  String get more => '更多';

  @override
  String get showAll => '顯示全部';

  @override
  String get unreadOnly => '只看未讀';

  @override
  String get selectAnArticle => '請選擇一篇文章';

  @override
  String get readerEmptySubtitle => '從左側列表打開文章後，會在這裡閱讀。';

  @override
  String get savedReaderEmptyTitle => '選擇一篇收藏';

  @override
  String get savedReaderEmptySubtitle => '從已收藏或稍後讀列表中打開文章。';

  @override
  String get searchReaderEmptyTitle => '選擇一條搜尋結果';

  @override
  String get searchReaderEmptySubtitle => '輸入關鍵字後，從左側結果中打開文章。';

  @override
  String errorMessage(String error) {
    return '錯誤：$error';
  }

  @override
  String unreadCountError(String error) {
    return '未讀數取得失敗：$error';
  }

  @override
  String get refreshed => '已重新整理';

  @override
  String get refreshedAll => '全部已重新整理';

  @override
  String get refreshedAndSynced => '已重新整理並同步';

  @override
  String get add => '新增';

  @override
  String get cancel => '取消';

  @override
  String get create => '建立';

  @override
  String get delete => '刪除';

  @override
  String get deleted => '已刪除';

  @override
  String get rssAtomUrl => 'RSS/Atom 位址';

  @override
  String get feedOrWebsiteUrl => '訂閱源或網站 URL';

  @override
  String get feedOrWebsiteUrlHint => '貼上網站地址或 RSS URL';

  @override
  String get findFeeds => '尋找訂閱源';

  @override
  String get discoveringFeeds => '正在發現訂閱源…';

  @override
  String get addingSubscription => '正在新增訂閱…';

  @override
  String get selectFeed => '選擇訂閱源';

  @override
  String get noFeedsFound => '未找到可用的訂閱源';

  @override
  String get noFeedsFoundHint => '可以直接貼上 RSS/Atom 地址，或試試這個網站的其他頁面。';

  @override
  String get subscriptionPreview => '來源預覽';

  @override
  String subscriptionResultsFound(int count) {
    return '已找到 $count 個訂閱源';
  }

  @override
  String get subscriptionPreviewUnavailable => '暫無可預覽的最近文章';

  @override
  String get feedSourceDirect => 'RSS/Atom 地址';

  @override
  String get feedSourceAlternate => '頁面宣告';

  @override
  String get feedSourceCommonPath => '常見訂閱路徑';

  @override
  String get name => '名稱';

  @override
  String get addedAndSynced => '已新增並同步';

  @override
  String get subscriptionAddedTitle => '訂閱已新增';

  @override
  String get subscriptionAddedMessage => '訂閱已新增。你可以現在查看，也可以繼續新增更多訂閱。';

  @override
  String get subscriptionRefreshWarning => '訂閱已新增，但首次重新整理失敗。你可以稍後重新整理。';

  @override
  String get subscriptionAlreadyExistsTitle => '已經訂閱';

  @override
  String get subscriptionAlreadyExistsMessage => '這個訂閱源已經在你的訂閱列表中，沒有改動它的分類。';

  @override
  String get viewSubscription => '查看訂閱';

  @override
  String get continueAddingSubscription => '繼續新增';

  @override
  String get moveToCurrentCategory => '移到目前分類';

  @override
  String get deleteSubscription => '刪除訂閱';

  @override
  String get deleteSubscriptionConfirmTitle => '刪除訂閱？';

  @override
  String get deleteSubscriptionConfirmContent => '確定要刪除此訂閱源嗎？';

  @override
  String get makeAvailableOffline => '離線可用';

  @override
  String get deleteCategory => '刪除分類';

  @override
  String get deleteCategoryConfirmTitle => '刪除分類？';

  @override
  String get deleteCategoryConfirmContent => '此分類下的訂閱源將移至未分類。';

  @override
  String get remoteDeleteCategoryConfirmContent => '將先在遠端服務上刪除這個分類，然後回刷本機鏡像。';

  @override
  String get remoteWritableTaxonomyTitle => '遠端分類';

  @override
  String get remoteWritableTaxonomyDescription => '分類變更會套用到遠端服務，並同步回本機鏡像。';

  @override
  String get remoteReadOnlyTaxonomyTitle => '唯讀遠端分組';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      '這些分類來自唯讀遠端分組鏡像。重新命名、刪除或移動請在遠端服務中管理。';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => '分類由遠端管理';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription => '這個訂閱源的分類來自唯讀遠端分組鏡像。';

  @override
  String get deleteTagConfirmTitle => '刪除標籤？';

  @override
  String get deleteTagConfirmContent => '這會從所有文章中移除該標籤。';

  @override
  String get categoryDeleted => '分類已刪除';

  @override
  String get refresh => '重新整理';

  @override
  String get moveToCategory => '移動到分類';

  @override
  String get noFeedsFoundInOpml => 'OPML 中未找到訂閱';

  @override
  String importedFeeds(int count) {
    return '已匯入 $count 個訂閱';
  }

  @override
  String get exportedOpml => '已匯出 OPML';

  @override
  String fullTextFailed(String error) {
    return '取得全文失敗：$error';
  }

  @override
  String get scrollToLoadMore => '捲動以載入更多';

  @override
  String get noArticles => '暫無文章';

  @override
  String get noStarredArticles => '暫無收藏文章';

  @override
  String get noReadLaterArticles => '暫無稍後讀文章';

  @override
  String get noUnreadArticles => '暫無未讀文章';

  @override
  String get articleListEmptySubtitle => '新增訂閱或同步後，文章會出現在這裡。';

  @override
  String get unreadEmptySubtitle => '目前篩選範圍內的文章都已讀完。';

  @override
  String get savedSearchEmptySubtitle => '目前收藏中沒有符合的結果。';

  @override
  String get star => '收藏';

  @override
  String get unstar => '取消收藏';

  @override
  String get starred => '已收藏';

  @override
  String get readLater => '稍後讀';

  @override
  String get removeReadLater => '移出稍後讀';

  @override
  String get openArticle => '打開文章';

  @override
  String get markRead => '標記為已讀';

  @override
  String get markUnread => '標記為未讀';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展開';

  @override
  String get openInBrowser => '在瀏覽器打開';

  @override
  String get copyLink => '複製連結';

  @override
  String get copiedToClipboard => '已複製到剪貼簿';

  @override
  String get share => '分享';

  @override
  String get autoMarkRead => '打開時自動標記為已讀';

  @override
  String get search => '搜尋';

  @override
  String get searchInContent => '搜尋內容';

  @override
  String get clearSearch => '清除搜尋';

  @override
  String get searchStartTitle => '開始搜尋';

  @override
  String get searchStartSubtitle => '輸入關鍵字查找標題、摘要和正文。';

  @override
  String searchNoResultsSubtitle(Object query) {
    return '沒有符合「$query」的文章。';
  }

  @override
  String get articleNotFoundSubtitle => '這篇文章可能已被刪除，或本地暫時不可用。';

  @override
  String get findInPage => '頁面內尋找';

  @override
  String get previousMatch => '上一個符合';

  @override
  String get nextMatch => '下一個符合';

  @override
  String get caseSensitive => '區分大小寫';

  @override
  String get close => '關閉';

  @override
  String get groupingAndSorting => '分組與排序';

  @override
  String get groupBy => '分組依據';

  @override
  String get groupNone => '無';

  @override
  String get groupByDay => '按天';

  @override
  String get sortOrder => '排序方式';

  @override
  String get sortNewestFirst => '最新的在先';

  @override
  String get sortOldestFirst => '最舊的在先';

  @override
  String get enabled => '啟用';

  @override
  String get rename => '重新命名';

  @override
  String get edit => '編輯';

  @override
  String get nameAlreadyExists => '名稱已存在';

  @override
  String get lastChecked => '上次檢查';

  @override
  String get lastSynced => '上次同步';

  @override
  String get never => '從未';

  @override
  String get cleanupReadArticles => '清理已讀文章';

  @override
  String get cleanupNow => '立即清理';

  @override
  String cachingArticles(int count) {
    return '正在緩存 $count 篇文章...';
  }

  @override
  String get manageTags => '管理標籤';

  @override
  String get newTag => '新標籤';

  @override
  String get tagColor => '標籤顏色';

  @override
  String get autoColor => '自動';

  @override
  String get tagsLoadingError => '載入標籤失敗';

  @override
  String cleanedArticles(int count) {
    return '清理了 $count 篇文章';
  }

  @override
  String days(int days) {
    return '$days 天';
  }

  @override
  String get services => '服務';

  @override
  String get account => '帳號';

  @override
  String get addOrRegisterAccount => '新增或註冊帳號';

  @override
  String get local => '本地';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => '新增本地';

  @override
  String get addLocalAccount => '新增本地帳號';

  @override
  String get addMiniflux => '新增 Miniflux';

  @override
  String get addFever => '新增 Fever';

  @override
  String get minifluxStrategy => 'Miniflux 策略';

  @override
  String get minifluxStrategySubtitle => '控制同步時的拉取量與預取行為。';

  @override
  String get remoteSyncStrategy => '遠端同步策略';

  @override
  String get remoteSyncStrategySubtitle => '控制同步時拉取的遠端文章視窗。';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux 會分頁拉取遠端文章，最多到這個每次同步視窗。';

  @override
  String get remoteSyncStrategyFeverSubtitle => 'Fever 同步未讀和收藏項目，並受這個每次同步視窗限制。';

  @override
  String get remoteEntriesLimit => '每次同步拉取筆數';

  @override
  String get remoteFetchConcurrency => '遠端拉取並發數';

  @override
  String get remoteFetchConcurrencySubtitle => '控制帳號同步文章批次時的並發請求數。';

  @override
  String get minifluxWebFetchMode => '網頁抓取方式';

  @override
  String get minifluxWebFetchModeSubtitle => '當訂閱開啟「同步時下載 Web 頁面」時生效。';

  @override
  String get minifluxWebFetchModeClient => '用戶端（Readability）';

  @override
  String get minifluxWebFetchModeServer => '伺服端（Miniflux fetch-content）';

  @override
  String get unlimited => '無限制';

  @override
  String get fieldName => '名稱';

  @override
  String get nameRequired => '請輸入名稱';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => '請輸入 Base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => '請輸入 API Token';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => '請輸入 API Key';

  @override
  String get authenticationMethod => '驗證方式';

  @override
  String get usernamePassword => '使用者名稱與密碼';

  @override
  String get minifluxAuthHint => '可填寫 API Token（建議）或使用者名稱/密碼。';

  @override
  String get feverAuthHint => '可填寫 API Key（建議）或使用者名稱/密碼。';

  @override
  String get username => '使用者名稱';

  @override
  String get usernameRequired => '請輸入使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get passwordRequired => '請輸入密碼';

  @override
  String get defaultModel => '預設模型';

  @override
  String get savedApiKeyClearHint => '留空會清除已儲存的 API Key。';

  @override
  String get savedCredentialsClearHint => '留空會清除已儲存的憑證。';

  @override
  String get aiServicesEmptyState => '尚未新增任何 AI 服務。';

  @override
  String modelSummary(String model) {
    return '模型：$model';
  }

  @override
  String get show => '顯示';

  @override
  String get hide => '隱藏';

  @override
  String get missingRequiredFields => '請填寫必填欄位';

  @override
  String get invalidBaseUrl => 'Base URL 無效';

  @override
  String get onlySupportedInLocalAccount => '僅本地帳號支援此操作';

  @override
  String get autoRefresh => '自動重新整理訂閱源';

  @override
  String get autoRefreshSubtitle =>
      '按所選週期重新整理訂閱源；行動裝置背景重新整理由系統排程，通常不會短於 15 分鐘，且不保證準時。';

  @override
  String get off => '關閉';

  @override
  String everyMinutes(int minutes) {
    return '每 $minutes 分鐘';
  }

  @override
  String get appPreferences => '應用偏好';

  @override
  String get about => '關於';

  @override
  String get dataDirectory => '資料目錄';

  @override
  String get copyPath => '複製路徑';

  @override
  String get openFolder => '打開資料夾';

  @override
  String get logDirectory => '日誌目錄';

  @override
  String get openLog => '打開日誌';

  @override
  String get openLogFolder => '打開日誌資料夾';

  @override
  String get exportLogs => '匯出日誌';

  @override
  String get exportedLogs => '日誌已匯出';

  @override
  String get noLogsFound => '未找到日誌檔案';

  @override
  String get keyboardShortcuts => '快速鍵';

  @override
  String get version => '版本號';

  @override
  String get buildNumber => '構建號';

  @override
  String get openSourceLicense => '開放原始碼授權';

  @override
  String get viewLicense => '檢視授權';

  @override
  String get thirdPartyLicenses => '第三方授權';

  @override
  String get viewThirdPartyLicenses => '檢視所有開放原始碼授權';

  @override
  String get licenseLoadFailed => '載入授權失敗。';

  @override
  String get mitLicenseName => 'MIT 授權';

  @override
  String get shortcutNextPreviousArticle => 'J / K：下一篇 / 上一篇文章';

  @override
  String get shortcutRefreshCurrentSelection => 'R：重新整理（目前選取項）';

  @override
  String get shortcutToggleUnreadOnly => 'U：切換僅未讀';

  @override
  String get shortcutToggleReadUnreadSelectedArticle => 'M：切換所選文章的已讀 / 未讀';

  @override
  String get shortcutToggleStarSelectedArticle => 'S：切換所選文章的星號狀態';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F：搜尋文章（清單）；聚焦頁內尋找（閱讀器）';

  @override
  String get filter => '過濾';

  @override
  String get filterKeywordsHint => '新增保留關鍵字（不同的關鍵字用“;”分隔，多重條件使用“+”連接）';

  @override
  String get sync => '同步';

  @override
  String get enableSync => '啟用同步';

  @override
  String get enableFilter => '啟用過濾';

  @override
  String get syncAlwaysEnabled => '總是啟用，因為設定 - 同步 - 同步模式為\"全部\"';

  @override
  String get syncImages => '同步時下載圖片';

  @override
  String get syncWebPages => '同步時下載網頁';

  @override
  String get syncStatusSyncing => '同步中';

  @override
  String get syncStatusSyncingFeeds => '同步訂閱源';

  @override
  String get syncStatusSyncingSubscriptions => '同步訂閱';

  @override
  String get syncStatusSyncingUnreadArticles => '同步未讀文章';

  @override
  String get syncStatusUploadingChanges => '上傳變更';

  @override
  String get syncStatusCompleted => '同步完成';

  @override
  String get syncStatusFailed => '同步失敗';

  @override
  String get showAiSummary => '顯示摘要';

  @override
  String get summary => '摘要';

  @override
  String get showImageTitle => '顯示圖片標題';

  @override
  String get showAttachedImage => '顯示附文圖像';

  @override
  String get htmlDecoding => 'HTML 轉碼';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => '繼承';

  @override
  String get auto => '自動';

  @override
  String get autoOn => '開';

  @override
  String get autoOff => '關';

  @override
  String get defaultValue => '預設值';

  @override
  String get defaultOption => '預設';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => '網頁 User-Agent';

  @override
  String get userAgentRssHint => '用於抓取 RSS/Atom 訂閱源。';

  @override
  String get userAgentWebHint => '用於抓取網頁全文（閱讀模式）。';

  @override
  String get resetToDefault => '恢復預設';

  @override
  String get notificationNewArticleTitle => '新文章';

  @override
  String get notificationNewArticlesTitle => '新文章';

  @override
  String notificationNewArticlesBody(int count) {
    return '發現 $count 篇新文章';
  }

  @override
  String get notificationNewArticlesChannelName => '新文章';

  @override
  String get notificationNewArticlesChannelDescription => '同步時發現新文章的通知';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '還原';

  @override
  String get windowClose => '關閉';

  @override
  String get translationAndAiServices => '翻譯與 AI 服務';

  @override
  String get translation => '翻譯';

  @override
  String get translationProvider => '翻譯提供方';

  @override
  String get aiServices => 'AI 服務';

  @override
  String get addAiService => '新增 AI 服務';

  @override
  String get aiService => 'AI 服務';

  @override
  String get aiSummary => 'AI 總結';

  @override
  String get aiSummaryService => 'AI 總結服務';

  @override
  String get targetLanguage => '目標語言';

  @override
  String get followAppLanguage => '跟隨軟體語言';

  @override
  String get translationProviderGoogleWeb => 'Google 翻譯（網頁）';

  @override
  String get translationProviderBingWeb => 'Bing 翻譯（網頁）';

  @override
  String get translationProviderBaiduApi => '百度翻譯（API）';

  @override
  String get translationProviderDeepLApi => 'DeepL（API）';

  @override
  String get translationProviderDeepLX => 'DeepLX';

  @override
  String translationProviderAiService(Object name) {
    return 'AI：$name';
  }

  @override
  String get translationProviderBaiduApiSubtitle => '設定 App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => '免費版';

  @override
  String get deepLEndpointPro => '專業版';

  @override
  String get setAsDefault => '設為預設';

  @override
  String get defaultAlreadySet => '預設（已設定）';

  @override
  String get aiSummaryPrompt => 'AI 總結提示詞';

  @override
  String get aiTranslationPrompt => 'AI 翻譯提示詞';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '請用 $language 總結這篇文章（標題：$title）：$content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '請將這段文章內容翻譯成 $language（標題：$title）：$content';
  }

  @override
  String get promptVariables => '可用變數';

  @override
  String get promptVariableContentDescription => '文章內容';

  @override
  String get promptVariableLanguageDescription => '目標語言';

  @override
  String get promptVariableTitleDescription => '文章標題';

  @override
  String get tpmLimit => 'TPM 限制';

  @override
  String get tpmLimitSubtitle => '0 表示不限制；超出後將進入佇列等待。';

  @override
  String get aiSummaryAction => 'AI 總結';

  @override
  String get translateAction => '翻譯';

  @override
  String get translationMode => '翻譯模式';

  @override
  String get immersiveTranslation => '沉浸式翻譯';

  @override
  String get traditionalTranslation => '傳統翻譯';

  @override
  String get generating => '生成中…';

  @override
  String get queued => '排隊中';

  @override
  String get regenerate => '重新生成';

  @override
  String get cachedPromptOutdated => 'Prompt 已更新，請重新生成。';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return '偵測到內容可能是 $source，目標語言是 $target。';
  }

  @override
  String get dontRemindThisLanguage => '不再提醒此語言';

  @override
  String get autoAiSummary => '自動 AI 總結';

  @override
  String get autoTranslate => '自動翻譯';

  @override
  String get aiNotConfigured => '尚未設定 AI 服務。';

  @override
  String get translationNotAvailable => '所選翻譯提供方暫不支援。';

  @override
  String get clearTranslation => '關閉翻譯';

  @override
  String get dbRecoveryTitle => '資料庫恢復';

  @override
  String get dbRecoveryDescription =>
      '應用偵測到資料庫異常，已自動進行恢復。你的資料已在磁碟上保留（備份/已移動的原庫檔案）。';

  @override
  String get dbRecoveryTimeLabel => '時間';

  @override
  String get dbRecoveryDbNameLabel => '資料庫名稱';

  @override
  String get dbRecoveryOpenedAsLabel => '實際開啟為';

  @override
  String get dbRecoveryBackupPathLabel => '備份';

  @override
  String get dbRecoveryMovedOriginalPathLabel => '已移動原庫';

  @override
  String get dbRecoveryErrorLabel => '錯誤';

  @override
  String get dbRecoveryDataPreservedHint => '提示：可使用右側複製按鈕複製路徑，便於排查或回報。';
}
