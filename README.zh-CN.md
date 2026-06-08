# Fleur

简体中文 | [English](README.md)

[![Quality](https://github.com/YunFeng86/Fleur/actions/workflows/quality.yml/badge.svg)](https://github.com/YunFeng86/Fleur/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Fleur 是一个 macOS-first 的 RSS 阅读器，面向开放 Web，提供安静、本地优先的阅读工作流。

Fleur 1.0 计划作为优先面向 macOS 的正式版本发布。源码树中仍保留其他平台目标，但 1.0 的官方发行产物计划仅提供 macOS 版本。

## 下载

请从 [GitHub Releases](https://github.com/YunFeng86/Fleur/releases) 下载 Fleur。

> macOS 安全提示：Fleur 1.0 构建目前未签名、未公证。首次打开时，macOS Gatekeeper 可能会显示安全提醒。请只从官方 GitHub Releases 下载；如果你更谨慎，也可以审计源码后自行构建。

如果 macOS 阻止打开应用，请在 Finder 中找到 `Fleur.app`，按住 Control 点击，选择“打开”，然后再次确认“打开”。

如果 macOS 提示应用“已损坏”或“无法打开”，请查看下面的 Q&A。

## Fleur 可以做什么

- 在围绕文章列表和专注阅读器设计的桌面工作区中阅读 RSS 和 Atom 订阅。
- 从网站发现订阅源，添加直接 RSS/Atom URL，并用文件夹、标签、星标、未读筛选和稍后阅读整理内容。
- 导入和导出 OPML，让订阅列表保持可迁移。
- 提取文章全文，缓存图片和网页内容，支持离线阅读和后台刷新。
- 支持本地账户、Miniflux、Fever 和 Google Reader compatible 服务同步。
- 自定义阅读器字体栈、阅读宽度、行高、阅读纹理、代码排版、语法高亮、数学公式、阅读器内搜索和键盘快捷键。
- 可配置翻译和 AI 摘要服务，作为可选的阅读辅助能力。

## 平台策略

| 平台 | 1.0 发行状态 | 说明 |
| --- | --- | --- |
| macOS 10.15+ | 1.0 官方目标 | 以未签名、未公证的 DMG 分发。 |
| Windows | 不包含在 1.0 发行产物中 | 0.x 版本可能包含 Windows 构建；1.0 转为 macOS-first。 |
| Linux | 不包含在 1.0 发行产物中 | 源码路径可能存在，但暂不计划提供 1.0 官方包。 |
| Android / iOS | 实验性源码目标 | 除非另行说明，仅适合本地开发验证。 |
| Web | 暂不支持 | 不属于当前支持的发布路径。 |

## 本地化

Fleur 使用 Flutter 本地化文件覆盖应用 UI 和 macOS 菜单字符串。

| 状态 | 语言 |
| --- | --- |
| 主要支持 | 英文、简体中文、繁体中文 |
| Beta / 实验性支持 | 德语、西班牙语、法语、日语、韩语、葡萄牙语、葡萄牙语（巴西） |

Beta 本地化表示相关字符串已经存在，但仍需要母语用户检查翻译质量、界面截断、术语统一、通知文案和发行说明。欢迎通过 Issue 或 Pull Request 帮忙校对。

## 从源码构建

推荐工具链：

- Flutter 3.38.x stable，与当前 CI 保持一致
- Dart 3.10.x
- 用于 macOS 构建的 Xcode

安装依赖：

```bash
flutter pub get
```

生成 Isar 模型代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

在 macOS 上运行 Fleur：

```bash
flutter run -d macos
```

本地构建 macOS release：

```bash
flutter build macos --release
```

## 质量检查

```bash
./tool/quality/format_dart.sh
./tool/quality/check_generated_sources.sh
flutter analyze
flutter test
```

集成测试可能需要显式指定设备：

```bash
flutter test -d macos integration_test/category_query_benchmark_test.dart
```

## 项目结构

Fleur 使用接近 Clean Architecture 的 Flutter 结构，并通过 Riverpod 管理状态。

```text
lib/
├── app/          # 应用入口、路由、运行时宿主
├── models/       # Isar 数据模型
├── repositories/ # 数据访问层
├── providers/    # Riverpod providers 和 controllers
├── services/     # RSS、同步、提取、设置、AI、通知
├── screens/      # 顶层页面
├── widgets/      # 可复用 UI 组件
├── theme/        # 主题和设计 token
├── l10n/         # 本地化文件
├── utils/        # 工具函数
└── db/           # 数据库初始化
```

## 技术栈

| 类别 | 技术 |
| --- | --- |
| 应用框架 | [Flutter](https://flutter.dev/) |
| 状态管理 | [Riverpod](https://riverpod.dev/) |
| 本地数据库 | [Isar Community](https://pub.dev/packages/isar_community) |
| 路由 | [go_router](https://pub.dev/packages/go_router) |
| HTTP | [Dio](https://pub.dev/packages/dio) |
| RSS 解析 | [rss_dart](https://pub.dev/packages/rss_dart) |
| HTML 渲染 | [flutter_widget_from_html](https://pub.dev/packages/flutter_widget_from_html) |
| 桌面窗口 | [window_manager](https://pub.dev/packages/window_manager) |
| 本地通知 | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |

## Q&A

### 为什么 Fleur 1.0 只发布 macOS 版本？

Fleur 最近的工作主要集中在让桌面阅读体验更贴近 macOS：窗口控制、键盘导航、分栏工作区、阅读器布局和菜单行为。把 1.0 定义为 macOS-first，可以让支持承诺更诚实。

### 为什么 macOS 应用未签名、未公证？

Fleur 是一个独立维护的开源项目。1.0 的 macOS 构建目前不会进行 Apple 代码签名和公证，因为项目暂时没有付费的 Apple Developer Program 账号。Apple 目前标注该计划费用为 [每年 99 美元](https://developer.apple.com/programs/)。

因此，首次打开 Fleur 时，macOS 可能会显示安全提醒。这不代表 Fleur 有意不安全，但未签名构建也确实不提供 Apple 的开发者身份验证。请只从官方 GitHub Releases 下载；如果你更谨慎，也可以从源码自行构建。

### macOS 提示 Fleur 已损坏或无法打开怎么办？

这通常是 Gatekeeper 对从网络下载的未签名应用保留了 quarantine 隔离属性。只有在你确认 Fleur 来自官方 GitHub Releases，或由你自己从源码构建时，才建议继续下面的操作。

建议按顺序尝试：

1. 先把 `Fleur.app` 复制到 `/Applications`。
2. 在 Finder 中找到 `Fleur.app`，按住 Control 点击，选择“打开”，然后再次确认“打开”。
3. 打开“系统设置” -> “隐私与安全性”，向下滚动到安全性区域；如果看到 Fleur 的拦截提示，点击“仍要打开”。
4. 如果 macOS 仍提示应用已损坏，可以移除本地隔离属性：

```bash
xattr -dr com.apple.quarantine /Applications/Fleur.app
```

然后再次从 Finder 打开 `Fleur.app`。

这个命令不会给应用签名或公证，只是移除你本机这份应用上的隔离标记。不建议全局关闭 Gatekeeper。

### Windows 和 Linux 是被放弃了吗？

不一定。1.0 的平台策略主要说明官方发行产物和验证重心，并不等于永久删除源码路径。当后续有足够验证和发布维护时间时，Windows 和 Linux 支持可以重新评估。

### Fleur 支持哪些语言？

英文、简体中文、繁体中文是主要支持语言。德语、西班牙语、法语、日语、韩语、葡萄牙语和葡萄牙语（巴西）会作为 1.0 的 Beta / 实验性本地化提供。

### Beta 本地化是什么意思？

它表示该语言已经可以在应用中使用，但还没有完成与英文、中文同级别的语言支持。欢迎反馈不自然的翻译、被截断的标签、菜单问题、未翻译字符串或发行说明中的语言错误。

## 贡献

欢迎提交 Bug 报告、本地化校对和聚焦的 Pull Request。反馈本地化问题时，建议包含：

- 语言和应用版本
- 涉及布局或截断时附上截图
- 当前文案
- 建议文案和简短理由

## 许可证

Fleur 使用 [MIT License](LICENSE) 发布。
