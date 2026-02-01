// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flutter Reader';

  @override
  String get notFound => '未找到';

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

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
  String get tags => '标签';

  @override
  String get all => '所有文章';

  @override
  String get uncategorized => '未分类';

  @override
  String get refreshAll => '刷新全部';

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
  String get name => '名称';

  @override
  String get addedAndSynced => '已添加并同步';

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
  String get noUnreadArticles => '暂无未读文章';

  @override
  String get star => '收藏';

  @override
  String get unstar => '取消收藏';

  @override
  String get starred => '已收藏';

  @override
  String get readLater => '稍后读';

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
  String get autoMarkRead => '打开时自动标记为已读';

  @override
  String get search => '搜索';

  @override
  String get searchInContent => '搜索正文';

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
  String get rules => '规则';

  @override
  String get addRule => '新增规则';

  @override
  String get editRule => '编辑规则';

  @override
  String get ruleName => '规则名称';

  @override
  String get keyword => '关键字';

  @override
  String get matchIn => '匹配范围';

  @override
  String get matchTitle => '标题';

  @override
  String get matchAuthor => '作者';

  @override
  String get matchLink => '链接';

  @override
  String get matchContent => '内容';

  @override
  String get actions => '动作';

  @override
  String get autoStar => '自动收藏';

  @override
  String get autoMarkReadAction => '自动标记为已读';

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
  String get showNotification => '显示通知';

  @override
  String get manageTags => '管理标签';

  @override
  String get newTag => '新标签';

  @override
  String get tagColor => '标签颜色';

  @override
  String get autoColor => '自动';

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
  String get autoRefresh => '自动刷新';

  @override
  String get autoRefreshSubtitle => '在后台自动刷新订阅源';

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
  String get keyboardShortcuts => '快捷键';

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
  String get showAiSummary => 'Show AI Summary';

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
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Flutter Reader';

  @override
  String get notFound => '未找到';

  @override
  String get settings => '設定';

  @override
  String get appearance => '外觀';

  @override
  String get theme => '主題';

  @override
  String get system => '跟隨系統';

  @override
  String get light => '淺色';

  @override
  String get dark => '深色';

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
  String get tags => '標籤';

  @override
  String get all => '所有文章';

  @override
  String get uncategorized => '未分類';

  @override
  String get refreshAll => '重新整理全部';

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
  String get name => '名稱';

  @override
  String get addedAndSynced => '已新增並同步';

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
  String get noUnreadArticles => '暫無未讀文章';

  @override
  String get star => '收藏';

  @override
  String get unstar => '取消收藏';

  @override
  String get starred => '已收藏';

  @override
  String get readLater => '稍後讀';

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
  String get autoMarkRead => '打開時自動標記為已讀';

  @override
  String get search => '搜尋';

  @override
  String get searchInContent => '搜尋內容';

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
  String get rules => '規則';

  @override
  String get addRule => '新增規則';

  @override
  String get editRule => '編輯規則';

  @override
  String get ruleName => '規則名稱';

  @override
  String get keyword => '關鍵字';

  @override
  String get matchIn => '匹配範圍';

  @override
  String get matchTitle => '標題';

  @override
  String get matchAuthor => '作者';

  @override
  String get matchLink => '連結';

  @override
  String get matchContent => '內容';

  @override
  String get actions => '動作';

  @override
  String get autoStar => '自動收藏';

  @override
  String get autoMarkReadAction => '自動標記為已讀';

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
  String get showNotification => '顯示通知';

  @override
  String get manageTags => '管理標籤';

  @override
  String get newTag => '新標籤';

  @override
  String get tagColor => '標籤顏色';

  @override
  String get autoColor => '自動';

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
  String get autoRefresh => '自動重新整理';

  @override
  String get autoRefreshSubtitle => '在背景自動重新整理訂閱來源';

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
  String get keyboardShortcuts => '快速鍵';

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
  String get showAiSummary => '顯示 AI 摘要';

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
}
