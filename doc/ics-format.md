# Ailurus ICS Format

本文档描述 Ailurus 当前用于 CalDAV 同步的 ICS 结构与解析约定。

主要实现文件：`lib/features/settings/data/caldav_sync_service.dart`

## 1. 顶层结构

每个事件会生成一个独立 `.ics` 资源，文件名规则：

- `ailurus-<eventId>.ics`

ICS 基础结构：

```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Ailurus//Calendar Sync//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
...
END:VEVENT
END:VCALENDAR
```

## 2. VEVENT 标准字段

Ailurus 生成的 `VEVENT` 含以下标准字段：

- `UID`
- `DTSTAMP`
- `LAST-MODIFIED`
- `SEQUENCE`
- `DTSTART;VALUE=DATE`
- `TRANSP`（`TRANSPARENT`）
- `SUMMARY`
- `DESCRIPTION`
- `CATEGORIES`
- `RRULE`（仅公历按年重复时）

说明：

- `DTSTART` 为日期值（非时间）
- `DTSTAMP` 为 UTC 时间戳（`yyyyMMddTHHmmssZ`）
- `LAST-MODIFIED` 为事件最后修改时间（UTC）
- `SEQUENCE` 为事件版本计数（随修改递增）
- `TRANSP:TRANSPARENT` 用于表示该全天纪念日不占用忙闲状态

## 2.1 行折叠（Line Folding）

为提高跨客户端兼容性，Ailurus 在生成端按 RFC 约定对长行进行折叠：

- 每行最长 75 octets
- 超长部分续行时使用 `CRLF + 空格` 前缀
- 解析端会进行 unfold（将续行还原）

示例（概念化）：

```ics
DESCRIPTION:This is a long value ...
 <continued content>
```

## 3. Ailurus 扩展字段（X-）

为保证多端双向同步与可逆解析，写入以下自定义字段：

- `X-AILURUS-EVENT-TYPE`
- `X-AILURUS-SOURCE-CALENDAR` (`gregorian` / `chinese-lunar`)
- `X-AILURUS-SOURCE-YEAR`（公历）
- `X-AILURUS-SOURCE-MONTH`
- `X-AILURUS-SOURCE-DAY`
- `X-AILURUS-IS-LEAP-MONTH`
- `X-AILURUS-IS-PINNED`
- `X-AILURUS-IS-FAVORITE`
- `X-AILURUS-TITLE`
- `X-AILURUS-PERSON-NAME`
- `X-AILURUS-TIMEZONE`
- `X-AILURUS-CREATED-AT`（ISO-8601）
- `X-AILURUS-UPDATED-AT`（ISO-8601）

农历事件额外可能包含：

- `X-AILURUS-GROUP-ID`

## 4. 解析规则（远端 -> 本地）

仅处理文件名符合 `ailurus-*.ics` 的资源。

解析顺序：

1. 读取 ICS 行并做 unfold（处理换行折叠）。
2. 提取键值（键统一转大写，忽略参数后缀）。
3. 必要字段校验：`DTSTART` 等。
4. 构造 `EventRecord`。

时间字段处理：

- `updatedAt` 优先：
  1. `X-AILURUS-UPDATED-AT`
  2. `LAST-MODIFIED`
  3. `DTSTAMP`
  4. 最后退化到 `createdAt`
- `createdAt` 优先：
  1. `X-AILURUS-CREATED-AT`
  2. `DTSTAMP`
  3. Epoch (`1970-01-01T00:00:00Z`)

## 5. 与同步冲突策略的关系

同步冲突依赖 `updatedAt` 比较，因此以下字段非常关键：

- `X-AILURUS-UPDATED-AT`（最佳）
- `LAST-MODIFIED` / `DTSTAMP`（回退）

状态同步字段：

- `X-AILURUS-IS-PINNED`
- `X-AILURUS-IS-FAVORITE`

上述两个字段用于跨端同步置顶/收藏状态；远端拉取解析后会恢复到本地 `EventRecord.isPinned` 与 `EventRecord.isFavorite`。

若远端资源无法 GET 或无法解析，会进入保护模式：

- 不用本地版本覆盖该远端 ID
- 不将该远端 ID 作为删除目标

## 6. 示例（简化）

```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Ailurus//Calendar Sync//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:ailurus-abc123@ailurus.app
DTSTAMP:20260316T030000Z
LAST-MODIFIED:20260316T030500Z
SEQUENCE:1773630300
DTSTART;VALUE=DATE:19900501
TRANSP:TRANSPARENT
SUMMARY:Alice - Birthday
DESCRIPTION:From Ailurus
CATEGORIES:birthday
RRULE:FREQ=YEARLY
X-AILURUS-EVENT-TYPE:birthday
X-AILURUS-SOURCE-CALENDAR:gregorian
X-AILURUS-SOURCE-YEAR:1990
X-AILURUS-SOURCE-MONTH:5
X-AILURUS-SOURCE-DAY:1
X-AILURUS-IS-LEAP-MONTH:false
X-AILURUS-IS-PINNED:true
X-AILURUS-IS-FAVORITE:true
X-AILURUS-TITLE:Alice
X-AILURUS-PERSON-NAME:Alice
X-AILURUS-TIMEZONE:Asia/Shanghai
X-AILURUS-CREATED-AT:2026-03-16T11:00:00+08:00
X-AILURUS-UPDATED-AT:2026-03-16T11:05:00+08:00
END:VEVENT
END:VCALENDAR
```
