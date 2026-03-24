# Ailurus Agent Guide

本文件用于规范在本项目内工作的代码智能体（Agent）行为。

## 1. 项目概览

- 项目类型：Flutter 跨平台应用（生日/纪念日管理，支持公历与农历）
- 主要目录：
  - `lib/app/`：应用启动、路由、主题
  - `lib/core/`：通用类型与工具
  - `lib/features/events/`：事件领域逻辑与页面
  - `lib/features/settings/`：设置、同步、CalDAV
  - `lib/l10n/`：本地化资源

## 2. 必须遵守的约束

- 不要手动编辑以下生成文件：
  - `lib/generated/l10n/app_localizations.dart`
  - `lib/generated/l10n/app_localizations_*.dart`
- 本地化文本只修改：`lib/l10n/app_*.arb`
- 代码应保持与现有风格一致（命名、缩进、错误处理、组件结构）
- 修改尽量小而聚焦，不做与任务无关的重构
- 不提交敏感信息（账号、密码、token、私钥等）
- 增加或删除任何可见文案时，必须同步更新多语言翻译（`lib/l10n/app_*.arb`）
- 修改 ICS 生成/解析/同步规则时，必须同步更新文档（`doc/ics-format.md` 与必要的 `doc/sync-mechanism.md`）

## 3. 常用开发命令

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run -d linux
```

如需构建验证，可使用：

```bash
flutter build linux --debug
```

## 4. 工作流程（Agent）

1. 先定位相关模块与现有实现，复用已有模式。
2. 实施最小改动，优先保证行为正确与 UI 一致性。
3. 改动后至少执行：
   - `flutter analyze`
   - `flutter test`
4. 涉及本地化时，补齐 `app_zh.arb / app_en.arb / app_ja.arb / app_ko.arb` 等对应文案，并执行 `flutter gen-l10n`。
5. 输出结果时说明：修改了哪些文件、为什么改、如何验证。

## 5. UI/表单相关约定

- 下拉框/输入框优先复用现有样式体系（主题或已有封装组件）。
- 保持组件尺寸一致，避免控件宽度超出父容器。
- 对列表/弹出菜单设置合理的最大高度，避免遮挡与溢出。

## 6. 完成标准（Definition of Done）

- 需求对应功能已实现且范围准确。
- `flutter analyze` 无错误。
- `flutter test` 通过（若有历史失败需明确说明）。
- 未改动不应修改的生成文件与无关文件。

## 7. 非目标

- 未经明确要求，不进行大规模架构调整。
- 未经明确要求，不新增重型依赖。
- 未经明确要求，不修改 CI/CD 或发布配置。
