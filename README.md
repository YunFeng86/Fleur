# Fleur

一款使用 Flutter 构建的跨平台 RSS 阅读器应用，采用 Clean Architecture 架构和 Riverpod 状态管理。

## ✨ 功能特性

- 📰 **RSS/Atom 订阅** - 支持 RSS 和 Atom 格式的订阅源
- 📂 **分类管理** - 自定义分类整理你的订阅
- 📖 **全文提取** - 智能提取文章完整内容（支持 WordPress、Hexo、Hugo、Halo 等）
- 🌓 **Material You** - 支持 Dynamic Color 动态主题
- 🌍 **多语言支持** - 支持简体中文、繁体中文、英文
- 📱 **响应式布局** - 适配手机、平板和桌面端
- 🔔 **本地通知** - 新文章推送提醒
- 💾 **离线阅读** - 本地缓存文章内容

## 📱 支持平台

平台状态按以下边界声明维护：

- **正式支持** - 当前持续验证，并具备基本发布准备度
- **预览支持** - 代码路径存在，但尚未完成常规验证或发布链路产品化
- **暂不支持** - 当前构建或运行不属于支持路径

| 平台 | 状态 | 当前依据 |
|------|------|----------|
| Windows 10/11 (x64) | ✅ 正式支持 | 当前主要验证与发布目标，已稳定使用 |
| Android | 🔄 预览支持 | 可用于开发验证，但 release 仍使用 debug 签名，未完成正式发布链路 |
| iOS | 🔄 预览支持 | 代码路径存在，尚未建立常规验证与发布流程 |
| macOS 11+ | 🔄 预览支持 | 可尝试运行，但窗口行为与打包未常规验证 |
| Linux (x64) | 🔄 预览支持 | 可尝试运行，但 GTK、通知与打包未常规验证 |
| Web | ❌ 暂不支持 | 当前 `flutter build web` 在本仓库上失败，未纳入支持路径 |

**如果你在预览平台上成功运行，请在 [Issues](https://github.com/YunFeng86/Fleur/issues) 报告你的系统信息和遇到的问题。**

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.10.0
- Dart SDK >= 3.10.0

### 安装依赖

```bash
flutter pub get
```

### 生成代码

项目使用 Isar 数据库，需要生成模型代码：

```bash
dart run build_runner build
```

如果遇到冲突，可以使用：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 运行应用

```bash
# 正式支持路径
flutter run -d windows
```

```bash
# 预览平台自行验证（先使用 `flutter devices` 确认设备 ID）
flutter run -d macos
flutter run -d linux
flutter run -d <android-device-id>
flutter run -d <ios-device-id>
```

- Android 预览构建目前仅适合本地验证；release 产物仍使用 debug 签名，**不应视为正式发布包**。
- Web 当前不提供受支持的运行命令；本仓库上的 `flutter build web` 仍会因现有 Web 目标阻塞项失败。

### 构建发布版本

```bash
# 正式支持发布构建
flutter build windows
```

```bash
# 预览平台验证构建（不代表正式发布就绪）
flutter build apk
flutter build ios
flutter build macos
flutter build linux
```

## 🏗️ 项目架构

项目采用 **Clean Architecture** 分层架构：

```
lib/
├── app/          # 应用入口、路由配置 (go_router)
├── models/       # Isar 数据模型
├── repositories/ # 数据访问层
├── providers/    # Riverpod 状态管理
├── services/     # 业务逻辑层
├── screens/      # 页面
├── widgets/      # 可复用组件
├── theme/        # 主题配置
├── l10n/         # 国际化
├── utils/        # 工具函数
└── db/           # 数据库初始化
```

## 🛠️ 技术栈

| 类别 | 技术 |
|------|------|
| 状态管理 | [Riverpod](https://riverpod.dev/) |
| 本地数据库 | [Isar](https://isar.dev/) |
| 路由 | [go_router](https://pub.dev/packages/go_router) |
| 网络请求 | [Dio](https://pub.dev/packages/dio) |
| RSS 解析 | [rss_dart](https://pub.dev/packages/rss_dart) |
| HTML 渲染 | [flutter_widget_from_html](https://pub.dev/packages/flutter_widget_from_html) |
| 窗口管理 | [window_manager](https://pub.dev/packages/window_manager) |
| 本地通知 | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |

## 🧪 测试

```bash
# 运行单元测试
flutter test

# 运行集成测试（需显式指定设备）
flutter test -d macos integration_test/category_query_benchmark_test.dart # macos可替换为所需集成测试的平台

# 或使用其他设备 ID
flutter test -d <device-id> integration_test/category_query_benchmark_test.dart
```

## ✅ 质量检查

```bash
# 格式化检查（排除 build_runner 生成文件）
./tool/quality/format_dart.sh

# 生成代码同步检查
./tool/quality/check_generated_sources.sh

# 静态分析
flutter analyze

# 单元 / Widget 测试
flutter test
```

### Git Hooks

仓库提供了 `lefthook.yml`，安装 Lefthook 后执行以下命令即可启用本地 hooks：

```bash
lefthook install
```

当前 `pre-commit` 会自动格式化暂存区中的 Dart 源文件，并重新加入暂存区：

- 仅处理 `*.dart`
- 自动跳过 `*.g.dart` 和 `*.freezed.dart`
- 不运行 `analyze`、`test` 或代码生成，保证提交动作足够轻

当前 `pre-push` 会按以下顺序执行：

- 改动 `lib/l10n/*.arb`、`l10n.yaml` 或 `pubspec.yaml` 时运行 `flutter gen-l10n`
- 改动 `lib/models/*.dart`、`build.yaml` 或 `pubspec.yaml` 时运行 `dart run build_runner build --delete-conflicting-outputs`
- 始终运行 `flutter analyze`
- 始终运行 `flutter test`

如果生成命令改写了已跟踪文件，hook 会直接失败，避免漏提交流水线所需的生成物。

### 当前已知边界

- `Article.categoryId` 去规范化目前仍保留，但 benchmark 使用统一的“慢路径时间节省百分比”口径评估；低于 30% 保留线时应进入复盘，而不是继续默认其复杂度已被证明合理。
- Android、iOS、macOS、Linux 当前都属于预览支持；如果需要把其中任一平台提升为正式支持，应先补齐常规验证与发布准备度。
- Web 在当前仓库中仍不纳入支持路径，相关兼容性问题需要单独处理。

## 📄 License

本项目采用 MIT 许可证。
