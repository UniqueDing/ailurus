# Ailurus

Ailurus 是一款跨平台 Flutter 应用，用于记录生日和纪念日，支持公历日期和中国农历日期。它以本地优先为核心设计，同时提供可选的 CalDAV 同步能力，方便在多设备之间同步事件数据。

## 应用功能

Ailurus 聚焦于一组简洁明确的个人日历工作流：

- 创建和管理生日、纪念日
- 支持公历和中国农历作为原始日期来源
- 计算下一次发生日期、年龄和周年数
- 置顶和收藏重要事项
- 在首页搜索和浏览事项
- 配置语言、主题模式和配色方案
- 使用 Ailurus 生成的 ICS 资源与 CalDAV 日历同步

主要用户流程对应四个路由：

- `/` — 首页
- `/event/new` — 创建事项
- `/event/:id` — 编辑事项
- `/settings` — 应用设置和同步配置

## 支持平台

本仓库是一个跨平台 Flutter 应用，目前包含以下平台目录：

- Android
- iOS
- macOS
- Windows
- Linux

## 存储结构

Ailurus 是本地优先应用。即使没有配置 CalDAV，也可以在本地存储和管理事项。

### 1. 本地事项存储

事项数据会以 JSON 形式持久化到应用支持目录。

- 文件：`events.json`
- 仓库实现：`lib/features/events/data/event_repository.dart`
- 领域模型：`lib/features/events/domain/event_models.dart`

数据结构保持简单：

```json
{
  "schemaVersion": 1,
  "data": [
    { "...event record json...": true }
  ]
}
```

`EventRepository` 会在内存中维护 `EventRecord` 映射，并通过临时文件重命名的方式原子化保存变更，同时向 UI 暴露查询和监听式 API。

### 2. 同步设置存储

同步和外观设置同样以 JSON 形式持久化到应用支持目录。

- 文件：`sync_settings.json`
- 仓库实现：`lib/features/settings/data/sync_settings_repository.dart`
- 状态模型：`lib/features/settings/application/sync_settings_controller.dart`

该文件保存的信息包括：

- CalDAV 服务器地址
- 用户名和密码
- 日历路径
- 是否允许不安全 TLS
- 语言代码
- 主题模式
- 当前配色方案
- 最近同步元数据
- 已知同步事项 ID

### 3. 远端同步存储模型

启用 CalDAV 后，Ailurus 不会任意写入第三方日历内容，而是使用稳定命名规则管理自己的 ICS 资源：

- `ailurus-<eventId>.ics`

ICS 结构和同步行为见：

- `doc/ics-format.md`
- `doc/sync-mechanism.md`

## 同步模型

Ailurus 使用本地优先、可选双向的 CalDAV 同步模型。

一次同步大致包括以下步骤：

1. 校验 CalDAV 配置
2. 执行认证预检
3. 使用 `PROPFIND` 发现远端资源
4. 使用 `GET` 拉取远端 ICS 资源
5. 通过事项 ID 和 `updatedAt` 比较本地与远端记录
6. 使用 `PUT` 上传本地较新的记录
7. 使用 `DELETE` 删除过期的远端资源
8. 将更新后的同步状态持久化到本地

冲突处理采用简化的基于时间戳的最后写入胜出策略。实现中也包含对远端部分读取失败的保护，避免一次远端拉取失败立刻导致覆盖或删除判断。

同步入口路径为：

- `SettingsPage`
- `SyncSettingsNotifier.syncNow()`
- `CaldavSyncService.sync()`

## 架构概览

代码库由一个轻量应用壳和若干功能模块组成。

```text
lib/
  app/                  # 应用启动、路由、主题
  core/                 # 共享底层类型和工具
  features/
    events/             # 事项领域、持久化、计算、界面
    settings/           # 同步设置、CalDAV 服务、设置界面
  generated/            # 生成的本地化输出
  l10n/                 # ARB 资源和本地化辅助封装
  main.dart             # 入口
```

### 应用层

- `lib/main.dart` 启动 Flutter，并用 `ProviderScope` 包裹应用
- `lib/app/app.dart` 构建根 `MaterialApp.router`
- `lib/app/router.dart` 定义顶层导航
- `lib/app/theme/` 包含主题和配色方案逻辑

### 事项功能

事项功能按领域、数据和展示拆分：

- `domain/`
  - 事项模型
  - 日历语义
  - 发生日期计算
- `data/`
  - 基于本地 JSON 的仓库
- `presentation/`
  - 首页
  - 事项编辑器
  - 可复用编辑组件

这是应用的核心功能：管理事项记录，并把原始日期转换为下一次发生日期。

### 设置功能

设置功能负责用户偏好和同步行为：

- `application/`
  - `SyncSettings`
  - notifier 和状态流转
- `data/`
  - 设置持久化
  - CalDAV 同步服务
- `presentation/`
  - 设置页和同步控制

该模块汇集了配置、远端同步和同步状态。

### 本地化

本地化资源位于 `lib/l10n/` 下的 ARB 文件中，`lib/l10n/app_texts.dart` 提供了一层轻量封装。

不要手动编辑 `lib/generated/l10n/` 下的生成文件。

## 领域模型摘要

应用中心模型是 `EventRecord`，它代表一个已存储事项，包含：

- 事项类型（`birthday` 或 `anniversary`）
- 原始日历类型（`gregorian` 或 `chinese lunar`）
- 日期字段
- 可选备注
- 置顶 / 收藏状态
- 创建和更新时间

发生日期计算独立实现，确保存储的原始日期和展示用的下一次发生日期解耦。

## CalDAV 与 ICS 约定

为了互操作性，Ailurus 会把事项序列化为日历资源，包含：

- 标准 ICS / VEVENT 字段
- 用于可逆解析和同步元数据的 Ailurus 自定义 `X-AILURUS-*` 字段

这些字段允许应用保留以下信息：

- 原始日历类型
- 闰月状态
- 置顶 / 收藏状态
- 创建和更新时间

如果修改 ICS 生成或解析规则，请同步更新：

- `doc/ics-format.md`
- `doc/sync-mechanism.md`

## 开发说明

### 常用命令

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run -d linux
```

### 应该编辑什么

- 可见文案请编辑 `lib/l10n/app_*.arb`
- 不要手动编辑生成的本地化文件：
  - `lib/generated/l10n/app_localizations.dart`
  - `lib/generated/l10n/app_localizations_*.dart`

### 实用约定

- 保持改动小而聚焦
- 复用当前模块中的既有模式
- 新增或删除可见文案时，同步更新所有支持的本地化文件
- 修改同步或 ICS 行为时，同步更新 `doc/` 中的文档

## 当前范围

Ailurus 有意保持轻量。它不是通用日历客户端。当前架构主要面向：

- 个人事项记录
- 基于简单 JSON 的本地持久化
- 可选 CalDAV 互操作
- 直接清晰的 Flutter 功能模块

如果想扩展应用，通常可以从这些位置开始：

- `lib/features/events/`：事项行为
- `lib/features/settings/`：同步和偏好设置
- `doc/`：协议和同步语义
