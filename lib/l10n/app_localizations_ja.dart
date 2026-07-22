// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => '見つかりません';

  @override
  String get openFailedGeneral => 'この場所を開けませんでした。権限を確認して、再試行してください。';

  @override
  String get macosMenuLanguageRestartHint =>
      'メニュー バーの言語を完全に適用するには、アプリの再起動が必要な場合があります。';

  @override
  String pathNotFound(Object path) {
    return 'パスが存在しません: $path';
  }

  @override
  String get settings => '設定';

  @override
  String get settingsSearchHint => '検索設定';

  @override
  String get settingsSearchNoResults => 'この検索に一致する設定はありません。';

  @override
  String get settingsSearchPageLabel => 'ページ';

  @override
  String get settingsSearchSectionLabel => 'セクション';

  @override
  String get settingsSearchSettingLabel => '設定';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count件の結果';
  }

  @override
  String get feeds => '購読';

  @override
  String get saved => '保存済み';

  @override
  String get comingSoon => '近日公開予定';

  @override
  String get appearance => '外観';

  @override
  String get theme => 'テーマ';

  @override
  String get themeMode => 'テーマモード';

  @override
  String get system => 'システム';

  @override
  String get light => 'ライト';

  @override
  String get dark => '暗い';

  @override
  String get dynamicColor => 'ダイナミックなカラー';

  @override
  String get dynamicColorSubtitle => '利用可能な場合はシステムの動的カラーまたはアクセントカラーに従います';

  @override
  String get seedColorPreset => 'アクセントカラー';

  @override
  String get seedColorPresetSubtitle => 'ダイナミックカラーがオフまたは使用できない場合に使用されます。';

  @override
  String get seedColorBlue => 'ブルー';

  @override
  String get seedColorGreen => '緑';

  @override
  String get seedColorPurple => '紫';

  @override
  String get seedColorOrange => 'オレンジ';

  @override
  String get seedColorPink => 'ピンク';

  @override
  String get language => '言語';

  @override
  String get systemLanguage => 'システムの言語';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => '読む';

  @override
  String get fontSize => 'フォントサイズ';

  @override
  String get lineHeight => '行の高さ';

  @override
  String get horizontalPadding => '水平方向のパディング';

  @override
  String get applicationAppearance => 'アプリの外観';

  @override
  String get readerAppearance => '読者登場';

  @override
  String get codeAppearance => 'コードの外観';

  @override
  String get custom => 'カスタム';

  @override
  String get back => '戻る';

  @override
  String get forward => '進む';

  @override
  String get fontSettings => 'フォント';

  @override
  String get advancedFontSettings => '高度なフォント設定';

  @override
  String get fontsAndCode => 'フォントとコード';

  @override
  String get customFontStack => 'カスタムフォントスタック';

  @override
  String get codeTypography => 'コードのタイポグラフィー';

  @override
  String get fontSizeExtraSmall => '極小';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeMediumRecommended => '中 (推奨)';

  @override
  String get fontSizeLarge => '大';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get minimumFontSize => '最小フォントサイズ';

  @override
  String get lineHeightCompact => 'コンパクト';

  @override
  String get lineHeightStandard => '標準';

  @override
  String get lineHeightRelaxed => 'リラックスした';

  @override
  String get appearancePreview => 'プレビュー';

  @override
  String get appearancePreviewTitle => 'より静かな読書面';

  @override
  String get appearancePreviewMeta => 'プレビュー · 今日';

  @override
  String get appearancePreviewBody => '読者を一度チューニングしてから、すべての記事を同じ穏やかなリズムで開きます。';

  @override
  String get appearancePreviewQuote =>
      '読み取り可能な設定は、構成可能であると感じる前に、目に見えるように感じられる必要があります。';

  @override
  String get appearancePreviewLink => 'サンプルリンク';

  @override
  String get appearancePreviewCode => 'コードサンプル';

  @override
  String get readerFontFamily => 'フォントファミリー';

  @override
  String get readerFontSystem => 'システム';

  @override
  String get readerFontSerif => 'セリフ';

  @override
  String get readerFontSans => 'サンズ';

  @override
  String get readerFontMono => 'モノラル';

  @override
  String get readerFontStack => 'フォントスタックの読み取り';

  @override
  String get standardFont => '標準フォント';

  @override
  String get serifFont => 'セリフフォント';

  @override
  String get sansSerifFont => 'サンセリフフォント';

  @override
  String get fixedWidthFont => '固定幅フォント';

  @override
  String get mathFont => '数学フォント';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => 'テクスチャの読み取り';

  @override
  String get readerThemeDefault => 'デフォルト';

  @override
  String get readerThemePaper => '紙';

  @override
  String get readerThemeSepia => 'セピア';

  @override
  String get readerThemeDim => 'ソフトグレー';

  @override
  String get readingWidth => '読み取り幅';

  @override
  String get readingWidthNarrow => '狭い';

  @override
  String get readingWidthStandard => '標準';

  @override
  String get readingWidthWide => 'ワイド';

  @override
  String get codeFontFamily => 'コードフォント';

  @override
  String get codeFontSystemMono => 'システムモノラル';

  @override
  String get codeFontStack => 'コードフォントスタック';

  @override
  String get codeFontSize => 'コードのフォントサイズ';

  @override
  String get codeFontSizeFollowReader => '本文に従う';

  @override
  String get codeFontSizeOneStepDown => '一歩下がって';

  @override
  String get codeLineHeight => 'コード行の高さ';

  @override
  String get codeSoftWrap => 'コード行を折り返す';

  @override
  String get storage => 'ストレージ';

  @override
  String get clearImageCache => '画像キャッシュをクリア';

  @override
  String get clearImageCacheSubtitle => 'オフライン読み取りに使用されるキャッシュされた画像を削除する';

  @override
  String get cacheCleared => 'キャッシュをクリアしました';

  @override
  String get subscriptions => '購読フィード';

  @override
  String get defaultsGroup => 'グローバル';

  @override
  String get folders => '定期購入';

  @override
  String get globalDefaults => 'グローバルデフォルト';

  @override
  String get allSubscriptions => 'すべてのサブスクリプション';

  @override
  String get manage => '管理する';

  @override
  String get overview => '概要';

  @override
  String get categoriesLabel => 'カテゴリー';

  @override
  String get globalDefaultsDescription =>
      'フォルダーまたはサブスクリプションが設定をオーバーライドしない場合に適用されます。';

  @override
  String get allSubscriptionsDescription =>
      '全体的なサブスクリプション構造を確認し、編集するサブスクリプションを選択します。';

  @override
  String get uncategorizedDescription =>
      'フォルダーのないサブスクリプションは、上書きされるまでグローバルなデフォルトを継承します。';

  @override
  String get tags => 'タグ';

  @override
  String get all => 'すべての記事';

  @override
  String get uncategorized => '未分類';

  @override
  String get refreshAll => 'ソースを更新する';

  @override
  String get refreshFeed => 'フィードを更新する';

  @override
  String get refreshCategory => 'カテゴリを更新';

  @override
  String get refreshFeedAndSync => 'フィードを更新して同期する';

  @override
  String get refreshCategoryAndSync => 'カテゴリを更新して同期する';

  @override
  String get refreshSourcesAndSync => 'ソースを更新して同期する';

  @override
  String get accountSync => 'アカウントの同期';

  @override
  String get accountSyncSubtitle => 'このリモート アカウントをバックグラウンドで同期します。';

  @override
  String get syncAccount => 'アカウントを同期';

  @override
  String get syncingAccount => 'アカウントを同期中...';

  @override
  String get syncedAccount => 'アカウントを同期しました';

  @override
  String get refreshSelected => '選択したものを更新';

  @override
  String get importOpml => 'OPML をインポートします';

  @override
  String get opmlParseFailed => '無効な OPML ファイル';

  @override
  String get exportOpml => 'OPML をエクスポート';

  @override
  String get addSubscription => 'サブスクリプションの追加';

  @override
  String get selectCategory => 'カテゴリを選択してください';

  @override
  String get loadingCategories => 'カテゴリを読み込んでいます...';

  @override
  String get creatingCategory => 'カテゴリを作成中...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Fever アカウントはサブスクリプションの追加をサポートしていません。サブスクリプションはサーバー上で管理してください。';

  @override
  String get remoteCommandRequiresConnectivity =>
      'このアクションには、リモート サービスへの接続が必要です。';

  @override
  String get remoteCommandRequiresAuthentication =>
      'リモート サービスは現在のアカウントの資格情報を拒否しました。アカウント設定を確認して、再試行してください。';

  @override
  String get remoteCommandNeedsRefresh =>
      'リモート サービスは現在のフィードまたはカテゴリと一致しませんでした。同期して再試行してください。';

  @override
  String get remoteCommandRejected =>
      'リモート サービスはこのアクションを拒否しました。リクエストを確認して、再試行してください。';

  @override
  String get remoteCommandUnavailable =>
      'リモート サービスは現在このアクションを完了できませんでした。後でもう一度試してください。';

  @override
  String get remoteCommandNotSupported => 'このリモート アカウントはこのアクションをサポートしていません。';

  @override
  String get remoteCommandRequiresCategory =>
      'このリモート アカウントには、サブスクリプションのサーバー側カテゴリが必要です。';

  @override
  String get newCategory => '新しいカテゴリー';

  @override
  String get articles => '記事';

  @override
  String get unread => '未読';

  @override
  String get refreshConcurrency => '同時リフレッシュ';

  @override
  String refreshingProgress(int current, int total) {
    return '$current/$totalを更新中...';
  }

  @override
  String get markAllRead => 'すべて既読としてマークする';

  @override
  String get fullText => '全文';

  @override
  String get fullTextRetry => '全文を取得できませんでした。再試行';

  @override
  String get readerSettings => 'リーダーの設定';

  @override
  String get done => '完了';

  @override
  String get more => 'もっと見る';

  @override
  String get showAll => 'すべて表示';

  @override
  String get unreadOnly => '未読のみ';

  @override
  String get selectAnArticle => '記事を選択してください';

  @override
  String get readerEmptySubtitle => 'リストから記事を開いて、ここで読んでください。';

  @override
  String get savedReaderEmptyTitle => '保存した記事を選択する';

  @override
  String get savedReaderEmptySubtitle => '[保存] または [後で読む] から記事を開きます。';

  @override
  String get searchReaderEmptyTitle => '検索結果を選択してください';

  @override
  String get searchReaderEmptySubtitle => 'キーワードを入力し、リストから結果を開きます。';

  @override
  String errorMessage(String error) {
    return 'エラー: $error';
  }

  @override
  String unreadCountError(String error) {
    return '未読数の取得に失敗しました: $error';
  }

  @override
  String get refreshed => 'リフレッシュされた';

  @override
  String get refreshedAll => 'すべて更新しました';

  @override
  String get refreshedAndSynced => '更新され同期されました';

  @override
  String get add => '追加';

  @override
  String get cancel => 'キャンセル';

  @override
  String get create => '作成';

  @override
  String get delete => '削除';

  @override
  String get deleted => '削除されました';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => 'フィードまたはWebサイトのURL';

  @override
  String get feedOrWebsiteUrlHint => 'WebサイトまたはRSS URLを貼り付け';

  @override
  String get findFeeds => 'フィードを検索';

  @override
  String get discoveringFeeds => 'フィードを検索中...';

  @override
  String get addingSubscription => 'サブスクリプションを追加しています...';

  @override
  String get selectFeed => 'フィードを選択';

  @override
  String get noFeedsFound => 'フィードが見つかりません';

  @override
  String get noFeedsFoundHint => 'RSS/Atom URL を直接貼り付けるか、サイトの別のページを試してください。';

  @override
  String get subscriptionPreview => 'ソースプレビュー';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の購読元が見つかりました',
      one: '1件の購読元が見つかりました',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable => '利用可能な最近のプレビュー アイテムはありません';

  @override
  String get feedSourceDirect => 'RSS/Atom URL';

  @override
  String get feedSourceAlternate => 'ページで検出';

  @override
  String get feedSourceCommonPath => '一般的なフィードパス';

  @override
  String get name => '名前';

  @override
  String get addedAndSynced => '追加して同期しました';

  @override
  String get subscriptionAddedTitle => 'サブスクリプションが追加されました';

  @override
  String get subscriptionAddedMessage =>
      'サブスクリプションが追加されました。今すぐ開くことも、さらに追加し続けることもできます。';

  @override
  String get subscriptionRefreshWarning =>
      'サブスクリプションが追加されましたが、最初の更新に失敗しました。後で更新を再試行できます。';

  @override
  String get subscriptionAlreadyExistsTitle => 'すでに購読しています';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'このフィードはすでにサブスクリプションに含まれています。カテゴリの変更は行われませんでした。';

  @override
  String get viewSubscription => 'サブスクリプションを表示する';

  @override
  String get continueAddingSubscription => '追加を続ける';

  @override
  String get moveToCurrentCategory => '現在のカテゴリに移動';

  @override
  String get deleteSubscription => 'サブスクリプションの削除';

  @override
  String get deleteSubscriptionConfirmTitle => 'サブスクリプションを削除しますか?';

  @override
  String get deleteSubscriptionConfirmContent => 'これにより、キャッシュされた記事も削除されます。';

  @override
  String get makeAvailableOffline => 'オフラインでも利用できるようにする';

  @override
  String get deleteCategory => 'カテゴリの削除';

  @override
  String get deleteCategoryConfirmTitle => 'カテゴリを削除しますか?';

  @override
  String get deleteCategoryConfirmContent => 'このカテゴリのフィードは未分類に移動されます。';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'リモート サービスでこのカテゴリを削除し、ローカル ミラーを調整します。';

  @override
  String get remoteWritableTaxonomyTitle => 'リモートカテゴリ';

  @override
  String get remoteWritableTaxonomyDescription =>
      'カテゴリの変更はリモート サービスに適用され、ローカルにミラーリングされます。';

  @override
  String get remoteReadOnlyTaxonomyTitle => '読み取り専用のリモート グループ';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'これらのカテゴリは、読み取り専用のリモート グループを反映しています。リモート サービス内のアイテムの名前変更、削除、または移動を行います。';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => 'リモートで管理されるカテゴリ';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'このフィードのカテゴリは、読み取り専用のリモート グループ ミラーから取得されます。';

  @override
  String get deleteTagConfirmTitle => 'タグを削除しますか?';

  @override
  String get deleteTagConfirmContent => 'これにより、すべての記事から削除されます。';

  @override
  String get categoryDeleted => 'カテゴリが削除されました';

  @override
  String get refresh => 'リフレッシュ';

  @override
  String get moveToCategory => 'カテゴリに移動';

  @override
  String get noFeedsFoundInOpml => 'OPML にフィードが見つかりません';

  @override
  String importedFeeds(int count) {
    return '$count件のフィードをインポートしました';
  }

  @override
  String get exportedOpml => 'エクスポート済み OPML';

  @override
  String fullTextFailed(String error) {
    return '全文の取得に失敗しました: $error';
  }

  @override
  String get scrollToLoadMore => 'スクロールしてさらに読み込む';

  @override
  String get noArticles => '記事がありません';

  @override
  String get noStarredArticles => 'スター付きの記事はまだありません';

  @override
  String get noReadLaterArticles => '後で読む記事はまだありません';

  @override
  String get noUnreadArticles => '未読の記事はありません';

  @override
  String get articleListEmptySubtitle =>
      'サブスクリプションを追加するか、ソースを更新すると、記事がここに表示されます。';

  @override
  String get unreadEmptySubtitle => '現在のスコープ内のすべてが読み取られています。';

  @override
  String get savedSearchEmptySubtitle => 'この検索に一致する保存済み記事はありません。';

  @override
  String get star => 'スターを付ける';

  @override
  String get unstar => 'スターを外す';

  @override
  String get starred => 'スター付き';

  @override
  String get readLater => 'あとで読む';

  @override
  String get removeReadLater => 'あとで読むから削除';

  @override
  String get openArticle => '記事を開く';

  @override
  String get markRead => '既読マークを付ける';

  @override
  String get markUnread => '未読としてマークする';

  @override
  String get collapse => '崩壊する';

  @override
  String get expand => '拡大する';

  @override
  String get openInBrowser => 'ブラウザで開く';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get share => 'シェアする';

  @override
  String get autoMarkRead => '開いたときに自動的に既読マークを付ける';

  @override
  String get search => '検索';

  @override
  String get searchInContent => 'コンテンツ内を検索する';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get searchStartTitle => '検索を開始する';

  @override
  String get searchStartSubtitle => 'キーワードを入力してタイトル、概要、内容を検索します。';

  @override
  String searchNoResultsSubtitle(Object query) {
    return '「$query」に一致する記事はありません。';
  }

  @override
  String get articleNotFoundSubtitle => 'この記事は削除されたか、ローカルで入手できなくなった可能性があります。';

  @override
  String get findInPage => 'ページ内で検索';

  @override
  String get previousMatch => '前回の試合';

  @override
  String get nextMatch => '次の試合';

  @override
  String get caseSensitive => '大文字と小文字を区別する';

  @override
  String get close => '閉じる';

  @override
  String get groupingAndSorting => 'グループ化と並べ替え';

  @override
  String get groupBy => 'グループ化';

  @override
  String get groupNone => 'なし';

  @override
  String get groupByDay => '日';

  @override
  String get sortOrder => '並べ替え順序';

  @override
  String get sortNewestFirst => '新しい順';

  @override
  String get sortOldestFirst => '古い順';

  @override
  String get enabled => '有効';

  @override
  String get rename => '名前の変更';

  @override
  String get edit => '編集';

  @override
  String get nameAlreadyExists => '名前はすでに存在します';

  @override
  String get lastChecked => '最後にチェックした';

  @override
  String get lastSynced => '最後に同期しました';

  @override
  String get never => '決してしない';

  @override
  String get cleanupReadArticles => '読んだ記事をクリーンアップする';

  @override
  String get cleanupNow => 'クリーンアップを実行する';

  @override
  String cachingArticles(int count) {
    return '$count件の記事をキャッシュしています...';
  }

  @override
  String get manageTags => 'タグの管理';

  @override
  String get newTag => '新しいタグ';

  @override
  String get tagColor => 'タグの色';

  @override
  String get autoColor => '自動';

  @override
  String get tagsLoadingError => 'タグの読み込みエラー';

  @override
  String cleanedArticles(int count) {
    return '$count件の記事をクリーンアップしました';
  }

  @override
  String days(int days) {
    return '$days日';
  }

  @override
  String get services => 'サービス';

  @override
  String get account => 'アカウント';

  @override
  String get connection => '接続';

  @override
  String get addOrRegisterAccount => 'アカウントの追加または登録';

  @override
  String get local => 'ローカル';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'ローカルの追加';

  @override
  String get addLocalAccount => 'ローカルアカウントの追加';

  @override
  String get addMiniflux => 'Miniflux を追加';

  @override
  String get addGoogleReaderApi => 'Google Reader API を追加';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Fever を追加';

  @override
  String get minifluxStrategy => 'Miniflux 戦略';

  @override
  String get minifluxStrategySubtitle => '同期中にフェッチ/プリフェッチされるデータの量を制御します。';

  @override
  String get remoteSyncStrategy => 'リモート同期戦略';

  @override
  String get remoteSyncStrategySubtitle => '同期中に取得されるリモート記事ウィンドウを制御します。';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux は、この同期ごとのウィンドウまでリモート エントリをページングできます。';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      'Google Reader 互換サービス ページは、この同期ごとのウィンドウまでのリモート ストリーム エントリを介して表示されます。';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever は、この同期ごとのウィンドウを上限として、未読アイテムと保存済みアイテムを同期します。';

  @override
  String get remoteEntriesLimit => '同期ごとのエントリ数';

  @override
  String get remoteFetchConcurrency => 'リモートフェッチの同時実行';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'アカウント同期中の同時リモート記事バッチリクエストを制御します。';

  @override
  String get minifluxWebFetchMode => 'Webページの取得';

  @override
  String get minifluxWebFetchModeSubtitle => '「同期中にWebページをダウンロード」が有効な場合。';

  @override
  String get minifluxWebFetchModeClient => 'クライアント (Readability)';

  @override
  String get minifluxWebFetchModeServer => 'サーバー (Miniflux コンテンツの取得)';

  @override
  String get unlimited => '無制限';

  @override
  String get fieldName => '名前';

  @override
  String get nameRequired => '名前を入力してください';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'ベース URL を入力してください';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'API トークンを入力してください';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'API キーを入力してください';

  @override
  String get authenticationMethod => '認証方式';

  @override
  String get usernamePassword => 'ユーザー名とパスワード';

  @override
  String get minifluxAuthHint => 'API トークン (推奨) またはユーザー名/パスワードを使用します。';

  @override
  String get feverAuthHint => 'API キー (推奨) またはユーザー名/パスワードを使用します。';

  @override
  String get username => 'ユーザー名';

  @override
  String get usernameRequired => 'ユーザー名を入力してください';

  @override
  String get password => 'パスワード';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get defaultModel => 'デフォルトモデル';

  @override
  String get savedApiKeyClearHint => '保存された API キーをクリアするには、空白のままにします。';

  @override
  String get savedCredentialsClearHint => '保存された資格情報をクリアするには、空白のままにします。';

  @override
  String get aiServicesEmptyState => 'AI サービスはまだ追加されていません。';

  @override
  String modelSummary(String model) {
    return 'モデル: $model';
  }

  @override
  String get show => '表示する';

  @override
  String get hide => '隠す';

  @override
  String get missingRequiredFields => '必須フィールドが欠落しています';

  @override
  String get invalidBaseUrl => '無効なベース URL';

  @override
  String get onlySupportedInLocalAccount => 'ローカルアカウントでのみサポートされています';

  @override
  String get autoRefresh => '自動ソースリフレッシュ';

  @override
  String get autoRefreshSubtitle =>
      '選択した間隔でサブスクリプション ソースを更新します。モバイルのバックグラウンド更新はシステムによってスケジュールされており、通常は 15 分ごとに行われるため、時間どおりに実行されない場合があります。';

  @override
  String get off => 'オフ';

  @override
  String everyMinutes(int minutes) {
    return '$minutes分ごと';
  }

  @override
  String get appPreferences => 'アプリ設定';

  @override
  String get about => 'について';

  @override
  String get dataDirectory => 'データディレクトリ';

  @override
  String get copyPath => 'パスをコピーする';

  @override
  String get openFolder => 'フォルダーを開く';

  @override
  String get logDirectory => 'ログディレクトリ';

  @override
  String get openLog => 'ログを開く';

  @override
  String get openLogFolder => 'ログフォルダを開く';

  @override
  String get exportLogs => 'ログのエクスポート';

  @override
  String get exportedLogs => 'エクスポートされたログ';

  @override
  String get noLogsFound => 'ログファイルが見つかりません';

  @override
  String get keyboardShortcuts => 'キーボードショートカット';

  @override
  String get version => 'バージョン';

  @override
  String get buildNumber => 'ビルド番号';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return 'バージョン $version · ビルド $buildNumber';
  }

  @override
  String get checkForUpdates => 'アップデートを確認';

  @override
  String get checkingForUpdates => '確認中...';

  @override
  String get updateAvailable => 'アップデート';

  @override
  String get upToDate => '最新バージョンです';

  @override
  String get updateCheckFailed => 'アップデートを確認できませんでした。';

  @override
  String newVersionAvailable(Object version) {
    return '新しいバージョン $version が利用可能です';
  }

  @override
  String get releaseNotes => 'リリースノート';

  @override
  String get goToOfficialUpdate => 'リリースページを開く';

  @override
  String get openSourceLicense => 'オープンソースライセンス';

  @override
  String get viewLicense => 'ライセンスを表示する';

  @override
  String get thirdPartyLicenses => 'サードパーティライセンス';

  @override
  String get viewThirdPartyLicenses => 'すべてのオープンソース ライセンスを表示する';

  @override
  String get licenseLoadFailed => 'ライセンスのロードに失敗しました。';

  @override
  String get mitLicenseName => 'MITライセンス';

  @override
  String get shortcutNextPreviousArticle => 'J / K: 次の記事 / 前の記事';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: 履歴を戻る/進む';

  @override
  String get shortcutRefreshCurrentSelection => 'R: リフレッシュ (現在の選択)';

  @override
  String get shortcutToggleUnreadOnly => 'U: 読み取り専用に切り替えます';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: 選択した記事の既読/未読を切り替えます';

  @override
  String get shortcutToggleStarSelectedArticle => 'S: 選択した記事のスターを切り替えます';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: 記事 (リスト) を検索します。フォーカス ページ内検索 (リーダー)';

  @override
  String get filter => 'フィルター';

  @override
  String get filterKeywordsHint => '予約キーワードを追加（「;」で区切って複数を「+」で連結）';

  @override
  String get sync => '同期';

  @override
  String get enableSync => '同期を有効にする';

  @override
  String get enableFilter => 'フィルターを有効にする';

  @override
  String get syncAlwaysEnabled => '常に有効 (設定 - 同期 - 同期モードが「すべて」)';

  @override
  String get syncImages => '同期中に画像をダウンロードする';

  @override
  String get syncWebPages => '同期中に Web ページをダウンロードする';

  @override
  String get syncStatusSyncing => '同期中';

  @override
  String get syncStatusSyncingFeeds => 'フィードを同期しています';

  @override
  String get syncStatusSyncingSubscriptions => 'サブスクリプションの同期';

  @override
  String get syncStatusSyncingUnreadArticles => '未読記事を同期する';

  @override
  String get syncStatusUploadingChanges => '変更のアップロード';

  @override
  String get syncStatusCompleted => '同期が完了しました';

  @override
  String get syncStatusFailed => '同期に失敗しました';

  @override
  String get showAiSummary => '概要を表示';

  @override
  String get summary => '概要';

  @override
  String get showImageTitle => '画像のタイトルを表示';

  @override
  String get showAttachedImage => '添付画像を表示';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => '継承する';

  @override
  String get auto => '自動';

  @override
  String get autoOn => '自動(オン)';

  @override
  String get autoOff => 'オフ';

  @override
  String get defaultValue => 'デフォルト値';

  @override
  String get defaultOption => 'デフォルト';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint => 'RSS/Atom フィードを取得するときに使用されます。';

  @override
  String get userAgentWebHint => '完全な Web ページ (Readability) を取得するときに使用されます。';

  @override
  String get resetToDefault => 'デフォルトにリセットする';

  @override
  String get notificationNewArticleTitle => '新しい記事';

  @override
  String get notificationNewArticlesTitle => '新しい記事';

  @override
  String notificationNewArticlesBody(int count) {
    return '$count件の新しい記事が見つかりました';
  }

  @override
  String get notificationNewArticlesChannelName => '新しい記事';

  @override
  String get notificationNewArticlesChannelDescription => '同期中に見つかった新しい記事の通知';

  @override
  String get windowMinimize => '最小化する';

  @override
  String get windowMaximize => '最大化する';

  @override
  String get windowRestore => '復元';

  @override
  String get windowClose => '閉じる';

  @override
  String get translationAndAiServices => '翻訳とAI';

  @override
  String get translation => '翻訳';

  @override
  String get translationProvider => '翻訳プロバイダー';

  @override
  String get aiServices => 'AI サービス';

  @override
  String get addAiService => 'AI サービスを追加';

  @override
  String get aiService => 'AI サービス';

  @override
  String get aiSummary => 'AI要約';

  @override
  String get aiSummaryService => 'AI おまとめサービス';

  @override
  String get targetLanguage => 'ターゲット言語';

  @override
  String get followAppLanguage => 'アプリの言語に従う';

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
    return 'AI: $name';
  }

  @override
  String get translationProviderBaiduApiSubtitle => 'App ID / App Key を設定します';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => '無料';

  @override
  String get deepLEndpointPro => 'プロ';

  @override
  String get setAsDefault => 'デフォルトとして設定';

  @override
  String get defaultAlreadySet => 'デフォルト（設定済み）';

  @override
  String get aiSummaryPrompt => 'AI 概要プロンプト';

  @override
  String get aiTranslationPrompt => 'AI翻訳プロンプト';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'この記事を$languageで要約してください（タイトル: $title）: $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'この記事の一部を$languageに翻訳してください（タイトル: $title）: $content';
  }

  @override
  String get promptVariables => '利用可能な変数';

  @override
  String get promptVariableContentDescription => '記事の内容';

  @override
  String get promptVariableLanguageDescription => '対象言語';

  @override
  String get promptVariableTitleDescription => '記事タイトル';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle => '0 は無制限を意味します。リクエストは超過するとキューに入れられます。';

  @override
  String get aiSummaryAction => 'AI要約';

  @override
  String get translateAction => '翻訳する';

  @override
  String get translationMode => '翻訳モード';

  @override
  String get immersiveTranslation => '没入型翻訳';

  @override
  String get traditionalTranslation => '従来の翻訳';

  @override
  String get generating => '生成中…';

  @override
  String get queued => 'キューに入れられました';

  @override
  String get regenerate => '再生する';

  @override
  String get cachedPromptOutdated => 'Prompt が更新されました。再生成してリフレッシュします。';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'コンテンツは$sourceの可能性があります。ターゲット言語は$targetです。';
  }

  @override
  String get dontRemindThisLanguage => 'この言語ではリマインダーを表示しない';

  @override
  String get autoAiSummary => '自動 AI サマリー';

  @override
  String get autoTranslate => '自動翻訳';

  @override
  String get aiNotConfigured => 'AI サービスが構成されていません。';

  @override
  String get translationNotAvailable => '選択したプロバイダーでは翻訳を利用できません。';

  @override
  String get clearTranslation => '明確な翻訳';

  @override
  String get dbRecoveryTitle => 'データベースの回復';

  @override
  String get dbRecoveryDescription =>
      'アプリはデータベースの問題を検出し、回復を実行しました。データはディスク上に保存されました (バックアップ/ファイルの移動)。';

  @override
  String get dbRecoveryTimeLabel => '時間';

  @override
  String get dbRecoveryDbNameLabel => 'DB名';

  @override
  String get dbRecoveryOpenedAsLabel => 'としてオープン';

  @override
  String get dbRecoveryBackupPathLabel => 'バックアップ';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'オリジナルを移動しました';

  @override
  String get dbRecoveryErrorLabel => 'エラー';

  @override
  String get dbRecoveryDataPreservedHint =>
      'ヒント: コピー ボタンを使用して、トラブルシューティングまたはサポート用のパスをコピーします。';
}
