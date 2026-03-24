# Ailurus Sync Mechanism

本文档说明当前 Ailurus 的 CalDAV 同步实现（以代码为准）。

## 1. 同步入口

- UI 入口：设置页 `立即同步` 按钮。
- 调用链：
  1. `SettingsPage` 触发 `syncNow()`
  2. `SyncSettingsNotifier.syncNow()`
  3. `CaldavSyncService.sync()`

主要文件：

- `lib/features/settings/presentation/settings_page.dart`
- `lib/features/settings/application/sync_settings_controller.dart`
- `lib/features/settings/data/caldav_sync_service.dart`

## 2. 总体流程

每次同步按以下顺序执行：

1. 校验配置（URL、用户名、密码、日历路径）。
2. 认证预检（`PROPFIND Depth:0`）。
3. 远端发现与拉取（`PROPFIND Depth:1` + 对每个资源 `GET`）。
4. 本地/远端同 ID 合并（基于 `updatedAt` 的时间戳规则）。
5. 上传需要由本地胜出的事件（`PUT text/calendar`）。
6. 删除远端过期事件（`DELETE`，仅对确认远端不存在且本地也不存在的 ID）。
7. 将下载/更新的远端事件写入本地仓库。
8. 更新同步状态（`syncedEventIds`、`lastSyncAtIso`、`lastSyncError`）。

## 3. 冲突处理规则（时间戳）

以事件 `id` 为主键，冲突规则如下：

- **仅本地存在**：加入上传候选，后续 `PUT` 到远端。
- **仅远端存在**：下载并写入本地。
- **本地与远端都存在**：
  - `local.updatedAt > remote.updatedAt`：本地胜出，上传本地版本。
  - `remote.updatedAt > local.updatedAt`：远端胜出，下载并覆盖本地。
  - 时间相同：不做改写。

这是一个简化的 Last-Writer-Wins（LWW）策略。

## 4. 失败保护策略

为避免“看不全远端导致误覆盖/误删”，有两层保护：

1. **集合发现失败保护**（collection-level）：
   - 如果 `PROPFIND Depth:1` 失败，本轮直接中止写操作（不上传、不删除）。

2. **单条远端不可访问保护**（item-level）：
   - 如果某个远端 ID 被发现，但 `GET`/解析失败，标记为不可访问。
   - 对该 ID：
     - 不用本地版本覆盖上传。
     - 不参与远端删除候选。

## 5. 删除策略

删除候选来自 `settings.syncedEventIds`，但需要同时满足：

- 不在当前本地合并结果中；
- 不在本轮远端发现 ID 集合中。

这样可以避免把“远端存在但暂时无法读取”的事件误删。

## 6. 状态字段语义

`SyncSettings` 中和同步相关的字段：

- `syncedEventIds`: 当前已知同步事件 ID 集合。
- `lastSyncAtIso`: 最近一次同步尝试时间。
- `lastSyncError`: 本轮错误信息（若存在）。

`syncNow()` 完成后会更新这些字段并持久化。

## 7. 已知边界

- 依赖设备时间与 `updatedAt` 维护质量；设备时钟偏差会影响 LWW 精度。
- 对非 Ailurus 生成的 ICS，解析能力有限（详见 `doc/ics-format.md`）。
