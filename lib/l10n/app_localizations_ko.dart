// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => '찾을 수 없음';

  @override
  String get openFailedGeneral => '이 위치를 열 수 없습니다. 권한을 확인하고 다시 시도하세요.';

  @override
  String get macosMenuLanguageRestartHint =>
      '메뉴 표시줄 언어를 완전히 적용하려면 앱을 다시 시작해야 할 수도 있습니다.';

  @override
  String pathNotFound(Object path) {
    return '경로가 없습니다: $path';
  }

  @override
  String get settings => '설정';

  @override
  String get settingsSearchHint => '검색 설정';

  @override
  String get settingsSearchNoResults => '이 검색과 일치하는 설정이 없습니다.';

  @override
  String get settingsSearchPageLabel => '페이지';

  @override
  String get settingsSearchSectionLabel => '섹션';

  @override
  String get settingsSearchSettingLabel => '설정';

  @override
  String settingsSearchResultCount(Object count) {
    return '결과 $count개';
  }

  @override
  String get feeds => '구독';

  @override
  String get saved => '저장됨';

  @override
  String get comingSoon => '곧 출시 예정';

  @override
  String get appearance => '외관';

  @override
  String get theme => '테마';

  @override
  String get themeMode => '테마 모드';

  @override
  String get system => '시스템';

  @override
  String get light => '빛';

  @override
  String get dark => '어둠';

  @override
  String get dynamicColor => '동적 색상';

  @override
  String get dynamicColorSubtitle => '가능한 경우 시스템 동적 또는 강조 색상을 따르십시오.';

  @override
  String get seedColorPreset => '악센트 색상';

  @override
  String get seedColorPresetSubtitle => '동적 색상이 꺼져 있거나 사용할 수 없을 때 사용됩니다.';

  @override
  String get seedColorBlue => '블루';

  @override
  String get seedColorGreen => '녹색';

  @override
  String get seedColorPurple => '보라색';

  @override
  String get seedColorOrange => '오렌지';

  @override
  String get seedColorPink => '핑크';

  @override
  String get language => '언어';

  @override
  String get systemLanguage => '시스템 언어';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => '읽기';

  @override
  String get fontSize => '글꼴 크기';

  @override
  String get lineHeight => '줄 높이';

  @override
  String get horizontalPadding => '수평 패딩';

  @override
  String get applicationAppearance => '앱 외관';

  @override
  String get readerAppearance => '리더의 모습';

  @override
  String get codeAppearance => '코드 모양';

  @override
  String get custom => '맞춤';

  @override
  String get back => '뒤로';

  @override
  String get forward => '앞으로';

  @override
  String get fontSettings => '글꼴';

  @override
  String get advancedFontSettings => '고급 글꼴 설정';

  @override
  String get fontsAndCode => '글꼴 및 코드';

  @override
  String get customFontStack => '맞춤 글꼴 스택';

  @override
  String get codeTypography => '코드 타이포그래피';

  @override
  String get fontSizeExtraSmall => '아주 작은';

  @override
  String get fontSizeSmall => '작은';

  @override
  String get fontSizeMediumRecommended => '중간(권장)';

  @override
  String get fontSizeLarge => '대형';

  @override
  String get fontSizeExtraLarge => '특대형';

  @override
  String get minimumFontSize => '최소 글꼴 크기';

  @override
  String get lineHeightCompact => '콤팩트';

  @override
  String get lineHeightStandard => '표준';

  @override
  String get lineHeightRelaxed => '편안한';

  @override
  String get appearancePreview => '미리보기';

  @override
  String get appearancePreviewTitle => '더 조용한 독서 표면';

  @override
  String get appearancePreviewMeta => '미리보기 · 오늘';

  @override
  String get appearancePreviewBody =>
      '독자를 한 번 조정한 다음 모든 기사를 동일한 차분한 리듬으로 시작하십시오.';

  @override
  String get appearancePreviewQuote =>
      '읽을 수 있는 설정은 구성 가능하다고 느끼기 전에 눈에 보이는 것처럼 느껴져야 합니다.';

  @override
  String get appearancePreviewLink => '샘플 링크';

  @override
  String get appearancePreviewCode => '코드 샘플';

  @override
  String get readerFontFamily => '글꼴 계열';

  @override
  String get readerFontSystem => '시스템';

  @override
  String get readerFontSerif => '세리프';

  @override
  String get readerFontSans => '샌즈';

  @override
  String get readerFontMono => '모노';

  @override
  String get readerFontStack => '글꼴 스택 읽기';

  @override
  String get standardFont => '표준 글꼴';

  @override
  String get serifFont => '세리프 글꼴';

  @override
  String get sansSerifFont => '산세리프 글꼴';

  @override
  String get fixedWidthFont => '고정폭 글꼴';

  @override
  String get mathFont => '수학 글꼴';

  @override
  String get fontStackExample =>
      '\"PingFang SC\", \"Noto Sans CJK SC\", system-ui, sans-serif';

  @override
  String get monoFontStackExample => '\"SF Mono\", Menlo, Consolas, monospace';

  @override
  String get mathFontStackExample =>
      '\"STIX Two Math\", \"Cambria Math\", serif';

  @override
  String get readerTheme => '질감 읽기';

  @override
  String get readerThemeDefault => '기본값';

  @override
  String get readerThemePaper => '종이';

  @override
  String get readerThemeSepia => '세피아';

  @override
  String get readerThemeDim => '소프트 그레이';

  @override
  String get readingWidth => '독서 폭';

  @override
  String get readingWidthNarrow => '좁다';

  @override
  String get readingWidthStandard => '표준';

  @override
  String get readingWidthWide => '와이드';

  @override
  String get codeFontFamily => '코드 글꼴';

  @override
  String get codeFontSystemMono => '시스템 모노';

  @override
  String get codeFontStack => '코드 글꼴 스택';

  @override
  String get codeFontSize => '코드 글꼴 크기';

  @override
  String get codeFontSizeFollowReader => '신체 따르기';

  @override
  String get codeFontSizeOneStepDown => '한 단계 아래로';

  @override
  String get codeLineHeight => '코드 줄 높이';

  @override
  String get codeSoftWrap => '코드 줄 바꿈';

  @override
  String get storage => '저장';

  @override
  String get clearImageCache => '이미지 캐시 지우기';

  @override
  String get clearImageCacheSubtitle => '오프라인 읽기에 사용되는 캐시된 이미지 제거';

  @override
  String get cacheCleared => '캐시를 지웠습니다';

  @override
  String get subscriptions => '구독 피드';

  @override
  String get defaultsGroup => '글로벌';

  @override
  String get folders => '구독';

  @override
  String get globalDefaults => '전역 기본값';

  @override
  String get allSubscriptions => '모든 구독';

  @override
  String get manage => '관리하다';

  @override
  String get overview => '개요';

  @override
  String get categoriesLabel => '카테고리';

  @override
  String get globalDefaultsDescription => '폴더 또는 구독이 설정을 재정의하지 않을 때 적용됩니다.';

  @override
  String get allSubscriptionsDescription => '전체 구독 구조를 검토하고 편집할 구독을 선택하세요.';

  @override
  String get uncategorizedDescription => '폴더가 없는 구독은 재정의될 때까지 전역 기본값을 상속합니다.';

  @override
  String get tags => '태그';

  @override
  String get all => '모든 기사';

  @override
  String get uncategorized => '분류되지 않음';

  @override
  String get refreshAll => '소스 새로 고침';

  @override
  String get refreshFeed => '피드 새로 고침';

  @override
  String get refreshCategory => '카테고리 새로고침';

  @override
  String get refreshFeedAndSync => '피드 새로 고침 및 동기화';

  @override
  String get refreshCategoryAndSync => '카테고리 새로고침 및 동기화';

  @override
  String get refreshSourcesAndSync => '소스 새로고침 및 동기화';

  @override
  String get accountSync => '계정 동기화';

  @override
  String get accountSyncSubtitle => '이 원격 계정을 백그라운드에서 동기화하세요.';

  @override
  String get syncAccount => '계정 동기화';

  @override
  String get syncingAccount => '계정 동기화 중...';

  @override
  String get syncedAccount => '계정 동기화됨';

  @override
  String get refreshSelected => '새로고침 선택됨';

  @override
  String get importOpml => 'OPML 가져오기';

  @override
  String get opmlParseFailed => '잘못된 OPML 파일';

  @override
  String get exportOpml => 'OPML 내보내기';

  @override
  String get addSubscription => '구독 추가';

  @override
  String get selectCategory => '카테고리를 선택하세요';

  @override
  String get loadingCategories => '카테고리 로드 중...';

  @override
  String get creatingCategory => '카테고리 생성 중...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Fever 계정은 구독 추가를 지원하지 않습니다. 서버에서 구독을 관리하세요.';

  @override
  String get remoteCommandRequiresConnectivity =>
      '이 작업을 수행하려면 원격 서비스에 연결해야 합니다.';

  @override
  String get remoteCommandRequiresAuthentication =>
      '원격 서비스가 현재 계정 자격 증명을 거부했습니다. 계정 설정을 확인하고 다시 시도하세요.';

  @override
  String get remoteCommandNeedsRefresh =>
      '원격 서비스가 현재 피드 또는 카테고리와 일치하지 않습니다. 동기화하고 다시 시도하세요.';

  @override
  String get remoteCommandRejected =>
      '원격 서비스가 이 작업을 거부했습니다. 요청을 검토한 후 다시 시도하세요.';

  @override
  String get remoteCommandUnavailable =>
      '원격 서비스가 지금은 이 작업을 완료할 수 없습니다. 나중에 다시 시도하세요.';

  @override
  String get remoteCommandNotSupported => '이 원격 계정은 이 작업을 지원하지 않습니다.';

  @override
  String get remoteCommandRequiresCategory =>
      '이 원격 계정에는 구독을 위한 서버 측 범주가 필요합니다.';

  @override
  String get newCategory => '새로운 카테고리';

  @override
  String get articles => '기사';

  @override
  String get unread => '읽지 않음';

  @override
  String get refreshConcurrency => '동시성 새로 고침';

  @override
  String refreshingProgress(int current, int total) {
    return '$current/$total 새로 고치는 중...';
  }

  @override
  String get markAllRead => '모두 읽은 것으로 표시';

  @override
  String get fullText => '본문';

  @override
  String get fullTextRetry => '본문을 가져오지 못했습니다. 다시 시도';

  @override
  String get readerSettings => '리더 설정';

  @override
  String get done => '완료';

  @override
  String get more => '더보기';

  @override
  String get showAll => '모두 표시';

  @override
  String get unreadOnly => '읽지 않은 것만';

  @override
  String get selectAnArticle => '기사를 선택하세요';

  @override
  String get readerEmptySubtitle => '여기에서 읽으려면 목록에서 기사를 엽니다.';

  @override
  String get savedReaderEmptyTitle => '저장된 기사 선택';

  @override
  String get savedReaderEmptySubtitle => '저장됨 또는 나중에 읽기에서 기사를 엽니다.';

  @override
  String get searchReaderEmptyTitle => '검색결과를 선택하세요';

  @override
  String get searchReaderEmptySubtitle => '키워드를 입력한 다음 목록에서 결과를 엽니다.';

  @override
  String errorMessage(String error) {
    return '오류: $error';
  }

  @override
  String unreadCountError(String error) {
    return '읽지 않은 수를 가져오지 못했습니다: $error';
  }

  @override
  String get refreshed => '새로 고침';

  @override
  String get refreshedAll => '모두 새로고침';

  @override
  String get refreshedAndSynced => '새로고침 및 동기화됨';

  @override
  String get add => '추가';

  @override
  String get cancel => '취소';

  @override
  String get create => '만들기';

  @override
  String get delete => '삭제';

  @override
  String get deleted => '삭제됨';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get feedOrWebsiteUrl => '피드 또는 웹사이트 URL';

  @override
  String get feedOrWebsiteUrlHint => '웹사이트 또는 RSS URL 붙여넣기';

  @override
  String get findFeeds => '피드 찾기';

  @override
  String get discoveringFeeds => '피드 찾는 중...';

  @override
  String get addingSubscription => '구독 추가 중...';

  @override
  String get selectFeed => '피드 선택';

  @override
  String get noFeedsFound => '피드를 찾을 수 없음';

  @override
  String get noFeedsFoundHint => 'RSS/Atom URL을 직접 붙여넣거나 사이트의 다른 페이지를 시도해 보세요.';

  @override
  String get subscriptionPreview => '소스 미리보기';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '구독 소스 $count개 발견',
      one: '구독 소스 1개 발견',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable => '사용 가능한 최근 미리보기 항목이 없습니다.';

  @override
  String get feedSourceDirect => 'RSS/Atom URL';

  @override
  String get feedSourceAlternate => '페이지에서 발견됨';

  @override
  String get feedSourceCommonPath => '일반 피드 경로';

  @override
  String get name => '이름';

  @override
  String get addedAndSynced => '추가 및 동기화됨';

  @override
  String get subscriptionAddedTitle => '구독이 추가되었습니다';

  @override
  String get subscriptionAddedMessage => '구독이 추가되었습니다. 지금 열거나 계속 추가할 수 있습니다.';

  @override
  String get subscriptionRefreshWarning =>
      '구독이 추가되었지만 첫 번째 새로 고침이 실패했습니다. 나중에 새로고침을 다시 시도할 수 있습니다.';

  @override
  String get subscriptionAlreadyExistsTitle => '이미 구독 중입니다';

  @override
  String get subscriptionAlreadyExistsMessage =>
      '이 피드는 이미 구독정보에 있습니다. 카테고리가 변경되지 않았습니다.';

  @override
  String get viewSubscription => '구독 보기';

  @override
  String get continueAddingSubscription => '계속 추가';

  @override
  String get moveToCurrentCategory => '현재 카테고리로 이동';

  @override
  String get deleteSubscription => '구독 삭제';

  @override
  String get deleteSubscriptionConfirmTitle => '구독을 삭제하시겠습니까?';

  @override
  String get deleteSubscriptionConfirmContent => '캐시된 기사도 삭제됩니다.';

  @override
  String get makeAvailableOffline => '오프라인에서 사용 가능';

  @override
  String get deleteCategory => '카테고리 삭제';

  @override
  String get deleteCategoryConfirmTitle => '카테고리를 삭제하시겠습니까?';

  @override
  String get deleteCategoryConfirmContent => '이 카테고리의 피드는 분류되지 않음으로 이동됩니다.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      '원격 서비스에서 이 범주를 삭제한 다음 로컬 미러를 조정하십시오.';

  @override
  String get remoteWritableTaxonomyTitle => '원격 카테고리';

  @override
  String get remoteWritableTaxonomyDescription =>
      '범주 변경 사항은 원격 서비스에 적용된 다음 로컬로 미러링됩니다.';

  @override
  String get remoteReadOnlyTaxonomyTitle => '읽기 전용 원격 그룹';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      '이러한 범주는 읽기 전용 원격 그룹을 미러링합니다. 원격 서비스의 항목 이름을 바꾸거나 삭제하거나 이동합니다.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => '원격으로 관리되는 카테고리';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      '이 피드의 카테고리는 읽기 전용 원격 그룹 미러에서 제공됩니다.';

  @override
  String get deleteTagConfirmTitle => '태그를 삭제하시겠습니까?';

  @override
  String get deleteTagConfirmContent => '그러면 모든 기사에서 해당 내용이 제거됩니다.';

  @override
  String get categoryDeleted => '카테고리가 삭제되었습니다.';

  @override
  String get refresh => '새로고침';

  @override
  String get moveToCategory => '카테고리로 이동';

  @override
  String get noFeedsFoundInOpml => 'OPML에 피드가 없습니다.';

  @override
  String importedFeeds(int count) {
    return '피드 $count개를 가져왔습니다';
  }

  @override
  String get exportedOpml => 'OPML을(를) 내보냈습니다.';

  @override
  String fullTextFailed(String error) {
    return '본문을 가져오지 못했습니다: $error';
  }

  @override
  String get scrollToLoadMore => '더 로드하려면 스크롤하세요.';

  @override
  String get noArticles => '기사 없음';

  @override
  String get noStarredArticles => '아직 별표표시된 기사가 없습니다.';

  @override
  String get noReadLaterArticles => '아직 나중에 읽을 기사가 없습니다.';

  @override
  String get noUnreadArticles => '읽지 않은 기사 없음';

  @override
  String get articleListEmptySubtitle => '구독을 추가하거나 소스를 새로 고치면 여기에 기사가 표시됩니다.';

  @override
  String get unreadEmptySubtitle => '현재 범위의 모든 내용을 읽었습니다.';

  @override
  String get savedSearchEmptySubtitle => '이 검색과 일치하는 저장된 기사가 없습니다.';

  @override
  String get star => '별표 표시';

  @override
  String get unstar => '별표 해제';

  @override
  String get starred => '별표';

  @override
  String get readLater => '나중에 읽기';

  @override
  String get removeReadLater => '나중에 읽기에서 제거';

  @override
  String get openArticle => '기사 열기';

  @override
  String get markRead => '읽은 것으로 표시';

  @override
  String get markUnread => '읽지 않은 것으로 표시';

  @override
  String get collapse => '접기';

  @override
  String get expand => '펼치기';

  @override
  String get openInBrowser => '브라우저에서 열기';

  @override
  String get copyLink => '링크 복사';

  @override
  String get copiedToClipboard => '클립보드에 복사됨';

  @override
  String get share => '공유';

  @override
  String get autoMarkRead => '열면 읽음으로 자동 표시';

  @override
  String get search => '검색';

  @override
  String get searchInContent => '콘텐츠에서 검색';

  @override
  String get clearSearch => '검색 지우기';

  @override
  String get searchStartTitle => '검색 시작';

  @override
  String get searchStartSubtitle => '제목, 요약, 내용을 검색하려면 키워드를 입력하세요.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return '“$query”과(와) 일치하는 기사가 없습니다.';
  }

  @override
  String get articleNotFoundSubtitle => '이 기사는 삭제되었거나 더 이상 로컬에서 사용할 수 없습니다.';

  @override
  String get findInPage => '페이지에서 찾기';

  @override
  String get previousMatch => '이전 경기';

  @override
  String get nextMatch => '다음 경기';

  @override
  String get caseSensitive => '대소문자 구분';

  @override
  String get close => '닫기';

  @override
  String get groupingAndSorting => '그룹화 및 정렬';

  @override
  String get groupBy => '그룹화 기준';

  @override
  String get groupNone => '없음';

  @override
  String get groupByDay => '일';

  @override
  String get sortOrder => '정렬 순서';

  @override
  String get sortNewestFirst => '최신순';

  @override
  String get sortOldestFirst => '오래된 것부터';

  @override
  String get enabled => '활성화됨';

  @override
  String get rename => '이름 바꾸기';

  @override
  String get edit => '편집';

  @override
  String get nameAlreadyExists => '이름이 이미 존재합니다.';

  @override
  String get lastChecked => '마지막 확인';

  @override
  String get lastSynced => '마지막 동기화';

  @override
  String get never => '절대로';

  @override
  String get cleanupReadArticles => '읽기 기사 정리';

  @override
  String get cleanupNow => '정리 실행';

  @override
  String cachingArticles(int count) {
    return '기사 $count개를 캐시하는 중...';
  }

  @override
  String get manageTags => '태그 관리';

  @override
  String get newTag => '새 태그';

  @override
  String get tagColor => '태그 색상';

  @override
  String get autoColor => '자동';

  @override
  String get tagsLoadingError => '태그를 로드하는 중에 오류가 발생했습니다.';

  @override
  String cleanedArticles(int count) {
    return '기사 $count개를 정리했습니다';
  }

  @override
  String days(int days) {
    return '$days일';
  }

  @override
  String get services => '서비스';

  @override
  String get account => '계정';

  @override
  String get addOrRegisterAccount => '계정 추가 또는 등록';

  @override
  String get local => '지역';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => '로컬 추가';

  @override
  String get addLocalAccount => '로컬 계정 추가';

  @override
  String get addMiniflux => 'Miniflux 추가';

  @override
  String get addGoogleReaderApi => 'Google Reader API 추가';

  @override
  String get googleReaderApi => 'Google Reader API';

  @override
  String get googleReaderCompatible => 'Google Reader compatible service';

  @override
  String get addFever => 'Fever 추가';

  @override
  String get minifluxStrategy => 'Miniflux 전략';

  @override
  String get minifluxStrategySubtitle => '동기화 중에 가져오거나 미리 가져오는 데이터의 양을 제어합니다.';

  @override
  String get remoteSyncStrategy => '원격 동기화 전략';

  @override
  String get remoteSyncStrategySubtitle => '동기화 중에 끌어온 원격 기사 창을 제어합니다.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux은 이 동기화별 창까지 원격 항목을 통해 페이징할 수 있습니다.';

  @override
  String get remoteSyncStrategyGoogleReaderSubtitle =>
      '이 동기화 창까지 원격 스트림 항목을 통해 Google Reader 호환 서비스 페이지를 표시합니다.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever은 읽지 않은 항목과 저장된 항목을 동기화하며 이 동기화별 창으로 제한됩니다.';

  @override
  String get remoteEntriesLimit => '동기화당 항목';

  @override
  String get remoteFetchConcurrency => '원격 가져오기 동시성';

  @override
  String get remoteFetchConcurrencySubtitle =>
      '계정 동기화 중 동시 원격 기사 일괄 요청을 제어합니다.';

  @override
  String get minifluxWebFetchMode => '웹페이지 가져오기';

  @override
  String get minifluxWebFetchModeSubtitle => '\"동기화 중 웹 페이지 다운로드\"가 활성화된 경우.';

  @override
  String get minifluxWebFetchModeClient => '클라이언트(Readability)';

  @override
  String get minifluxWebFetchModeServer => '서버(Miniflux 가져오기 콘텐츠)';

  @override
  String get unlimited => '무제한';

  @override
  String get fieldName => '이름';

  @override
  String get nameRequired => '이름을 입력하세요';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => '베이스 URL 입력';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'API 토큰을 입력하세요.';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'API 키를 입력하세요.';

  @override
  String get authenticationMethod => '인증방법';

  @override
  String get usernamePassword => '사용자 이름 및 비밀번호';

  @override
  String get minifluxAuthHint => 'API 토큰(권장) 또는 사용자 이름/비밀번호를 사용하세요.';

  @override
  String get feverAuthHint => 'API 키(권장) 또는 사용자 이름/비밀번호를 사용하세요.';

  @override
  String get username => '사용자 이름';

  @override
  String get usernameRequired => '사용자 이름을 입력하세요';

  @override
  String get password => '비밀번호';

  @override
  String get passwordRequired => '비밀번호를 입력하세요';

  @override
  String get defaultModel => '기본 모델';

  @override
  String get savedApiKeyClearHint => '저장된 API 키를 지우려면 공백으로 남겨두세요.';

  @override
  String get savedCredentialsClearHint => '저장된 자격 증명을 지우려면 비워 두세요.';

  @override
  String get aiServicesEmptyState => '아직 AI 서비스가 추가되지 않았습니다.';

  @override
  String modelSummary(String model) {
    return '모델: $model';
  }

  @override
  String get show => '쇼';

  @override
  String get hide => '숨기기';

  @override
  String get missingRequiredFields => '필수 입력란이 누락되었습니다.';

  @override
  String get invalidBaseUrl => '잘못된 베이스 URL';

  @override
  String get onlySupportedInLocalAccount => '로컬 계정에서만 지원됩니다.';

  @override
  String get autoRefresh => '자동 소스 새로 고침';

  @override
  String get autoRefreshSubtitle =>
      '선택한 간격으로 구독 소스를 새로 고칩니다. 모바일 백그라운드 새로 고침은 시스템에 예약되어 있으며 일반적으로 15분 간격으로 이루어지며 정확한 시간에 실행되지 않을 수도 있습니다.';

  @override
  String get off => '끄기';

  @override
  String everyMinutes(int minutes) {
    return '$minutes분마다';
  }

  @override
  String get appPreferences => '앱 설정';

  @override
  String get about => '소개';

  @override
  String get dataDirectory => '데이터 디렉토리';

  @override
  String get copyPath => '경로 복사';

  @override
  String get openFolder => '폴더 열기';

  @override
  String get logDirectory => '로그 디렉터리';

  @override
  String get openLog => '로그 열기';

  @override
  String get openLogFolder => '로그 폴더 열기';

  @override
  String get exportLogs => '로그 내보내기';

  @override
  String get exportedLogs => '내보낸 로그';

  @override
  String get noLogsFound => '로그 파일을 찾을 수 없습니다.';

  @override
  String get keyboardShortcuts => '키보드 단축키';

  @override
  String get version => '버전';

  @override
  String get buildNumber => '빌드 번호';

  @override
  String versionAndBuild(Object version, Object buildNumber) {
    return '버전 $version · 빌드 $buildNumber';
  }

  @override
  String get checkForUpdates => '업데이트 확인';

  @override
  String get checkingForUpdates => '확인 중...';

  @override
  String get updateAvailable => '업데이트';

  @override
  String get upToDate => '최신 버전입니다';

  @override
  String get updateCheckFailed => '업데이트를 확인할 수 없습니다.';

  @override
  String newVersionAvailable(Object version) {
    return '새 버전 $version을 사용할 수 있습니다';
  }

  @override
  String get releaseNotes => '릴리스 노트';

  @override
  String get goToOfficialUpdate => '릴리스 페이지 열기';

  @override
  String get openSourceLicense => '오픈소스 라이선스';

  @override
  String get viewLicense => '라이선스 보기';

  @override
  String get thirdPartyLicenses => '타사 라이센스';

  @override
  String get viewThirdPartyLicenses => '모든 오픈소스 라이선스 보기';

  @override
  String get licenseLoadFailed => '라이센스를 로드하지 못했습니다.';

  @override
  String get mitLicenseName => 'MIT 라이센스';

  @override
  String get shortcutNextPreviousArticle => 'J/K: 다음/이전 기사';

  @override
  String get shortcutBackForwardHistory =>
      'Alt + ← / Alt + →; macOS Cmd + [ / ]: 뒤로/앞으로 기록';

  @override
  String get shortcutRefreshCurrentSelection => 'R: 새로 고침(현재 선택)';

  @override
  String get shortcutToggleUnreadOnly => 'U: 읽지 않은 상태로 전환';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: 선택한 기사에 대해 읽음/읽지 않음을 전환합니다.';

  @override
  String get shortcutToggleStarSelectedArticle => 'S: 선택한 기사의 별표를 전환합니다.';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: 기사 검색(목록); focus 페이지에서 찾기(리더)';

  @override
  String get filter => '필터';

  @override
  String get filterKeywordsHint => '예약된 키워드 추가(\";\"로 구분, 여러 개는 \"+\"로 연결)';

  @override
  String get sync => '동기화';

  @override
  String get enableSync => '동기화 활성화';

  @override
  String get enableFilter => '필터 활성화';

  @override
  String get syncAlwaysEnabled => '항상 활성화됨(설정 - 동기화 - 동기화 모드는 \"모두\"임)';

  @override
  String get syncImages => '동기화 중 이미지 다운로드';

  @override
  String get syncWebPages => '동기화 중 웹 페이지 다운로드';

  @override
  String get syncStatusSyncing => '동기화 중';

  @override
  String get syncStatusSyncingFeeds => '피드 동기화 중';

  @override
  String get syncStatusSyncingSubscriptions => '구독 동기화 중';

  @override
  String get syncStatusSyncingUnreadArticles => '읽지 않은 기사 동기화 중';

  @override
  String get syncStatusUploadingChanges => '변경사항 업로드 중';

  @override
  String get syncStatusCompleted => '동기화 완료';

  @override
  String get syncStatusFailed => '동기화 실패';

  @override
  String get showAiSummary => '요약 표시';

  @override
  String get summary => '요약';

  @override
  String get showImageTitle => '이미지 제목 표시';

  @override
  String get showAttachedImage => '첨부된 이미지 표시';

  @override
  String get htmlDecoding => 'HTML decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => '상속';

  @override
  String get auto => '자동';

  @override
  String get autoOn => '자동(켜짐)';

  @override
  String get autoOff => '끄기';

  @override
  String get defaultValue => '기본값';

  @override
  String get defaultOption => '기본값';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web User-Agent';

  @override
  String get userAgentRssHint => 'RSS/Atom 피드를 가져올 때 사용됩니다.';

  @override
  String get userAgentWebHint => '전체 웹페이지(Readability)를 가져올 때 사용됩니다.';

  @override
  String get resetToDefault => '기본값으로 재설정';

  @override
  String get notificationNewArticleTitle => '새 기사';

  @override
  String get notificationNewArticlesTitle => '새로운 기사';

  @override
  String notificationNewArticlesBody(int count) {
    return '새 기사 $count개를 찾았습니다';
  }

  @override
  String get notificationNewArticlesChannelName => '새로운 기사';

  @override
  String get notificationNewArticlesChannelDescription =>
      '동기화 중에 발견된 새 기사에 대한 알림';

  @override
  String get windowMinimize => '최소화';

  @override
  String get windowMaximize => '최대화';

  @override
  String get windowRestore => '복원';

  @override
  String get windowClose => '닫기';

  @override
  String get translationAndAiServices => '번역 및 AI';

  @override
  String get translation => '번역';

  @override
  String get translationProvider => '번역 제공업체';

  @override
  String get aiServices => 'AI 서비스';

  @override
  String get addAiService => 'AI 서비스 추가';

  @override
  String get aiService => 'AI 서비스';

  @override
  String get aiSummary => 'AI 요약';

  @override
  String get aiSummaryService => 'AI 요약 서비스';

  @override
  String get targetLanguage => '대상 언어';

  @override
  String get followAppLanguage => '앱 언어 따르기';

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
  String get translationProviderBaiduApiSubtitle => 'App ID / App Key 구성';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => '무료';

  @override
  String get deepLEndpointPro => '프로';

  @override
  String get setAsDefault => '기본값으로 설정';

  @override
  String get defaultAlreadySet => '기본값(이미 설정됨)';

  @override
  String get aiSummaryPrompt => 'AI 요약 프롬프트';

  @override
  String get aiTranslationPrompt => 'AI 번역 프롬프트';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '이 기사를 $language로 요약해 주세요(제목: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return '이 기사 일부를 $language로 번역해 주세요(제목: $title): $content';
  }

  @override
  String get promptVariables => '사용 가능한 변수';

  @override
  String get promptVariableContentDescription => '기사 내용';

  @override
  String get promptVariableLanguageDescription => '대상 언어';

  @override
  String get promptVariableTitleDescription => '기사 제목';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle => '0은 무제한을 의미합니다. 요청이 초과되면 대기열에 추가됩니다.';

  @override
  String get aiSummaryAction => 'AI 요약';

  @override
  String get translateAction => '번역하다';

  @override
  String get translationMode => '번역 모드';

  @override
  String get immersiveTranslation => '몰입형 번역';

  @override
  String get traditionalTranslation => '전통적인 번역';

  @override
  String get generating => '생성 중…';

  @override
  String get queued => '대기 중';

  @override
  String get regenerate => '재생성';

  @override
  String get cachedPromptOutdated => 'Prompt 업데이트됨; 새로 고치려면 재생성하세요.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return '콘텐츠가 $source일 수 있습니다. 대상 언어는 $target입니다.';
  }

  @override
  String get dontRemindThisLanguage => '이 언어에 대해 알림 안 함';

  @override
  String get autoAiSummary => '자동 AI 요약';

  @override
  String get autoTranslate => '자동 번역';

  @override
  String get aiNotConfigured => 'AI 서비스가 구성되지 않았습니다.';

  @override
  String get translationNotAvailable => '선택한 제공업체에 대해서는 번역이 제공되지 않습니다.';

  @override
  String get clearTranslation => '명확한 번역';

  @override
  String get dbRecoveryTitle => '데이터베이스 복구';

  @override
  String get dbRecoveryDescription =>
      '앱이 데이터베이스 문제를 감지하고 복구를 수행했습니다. 귀하의 데이터는 디스크에 보존되었습니다(백업/이동된 파일).';

  @override
  String get dbRecoveryTimeLabel => '시간';

  @override
  String get dbRecoveryDbNameLabel => 'DB 이름';

  @override
  String get dbRecoveryOpenedAsLabel => '다음으로 열림';

  @override
  String get dbRecoveryBackupPathLabel => '백업';

  @override
  String get dbRecoveryMovedOriginalPathLabel => '원본을 옮겼습니다.';

  @override
  String get dbRecoveryErrorLabel => '오류';

  @override
  String get dbRecoveryDataPreservedHint =>
      '팁: 문제 해결이나 지원을 위해 경로를 복사하려면 복사 버튼을 사용하세요.';
}
