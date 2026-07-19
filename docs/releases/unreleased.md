# Fleur Unreleased

<!-- update-notes:en -->
- Reworked the Windows and Linux desktop frame with a persistent custom title bar, native caption controls, and connected left navigation chrome.
- Made workspace navigation adapt between expanded, rail, and off-canvas presentations while preserving article route history across window resizing.
- Moved Settings into the shared window frame and added independent expanded, rail, and off-canvas settings navigation.
<!-- /update-notes:en -->

<!-- update-notes:zh -->
- 重整 Windows 与 Linux 桌面窗口框架：使用持久自绘标题栏、原生窗口控制按钮，以及与标题栏连成一体的左侧导航 chrome。
- 工作区导航可根据可用宽度在展开、窄栏和临时侧栏之间自适应切换，并在窗口缩放时保持文章路由历史稳定。
- 设置页迁移到共享窗口框架，并使用独立的展开、窄栏和临时侧栏导航状态。
<!-- /update-notes:zh -->

## Internal

- Implemented the core shell and adaptive workspace decisions from ADR-0001.
- Split shell, settings scene/search, and sidebar chrome responsibilities so the main source files remain below 1000 lines.
