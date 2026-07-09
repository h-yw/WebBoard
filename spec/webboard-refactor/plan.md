# Implementation Plan: WebBoard Refactor — 浮叶 / WebLeaf

**Input**: Feature specification from `spec/webboard-refactor/spec.md`

## Summary

对现有 HarmonyOS 应用 WebBoard 进行全面迭代优化，更名为「浮叶 / WebLeaf」。核心变更包括：(1) 数据存储从 Preferences 迁移至 SQLite（`@ohos.data.relationalStore`）；(2) 网络导入改为纯 URL 引用（Web 组件直接加载）；(3) 文件导入增加持久化授权方案（`ohos.fileshare.persistPermission`）；(4) 封装全局 Toast/Loading/Dialog 工具函数；(5) 全面 UI/UX 升级与品牌焕新；(6) 国际化支持与代码性能优化。

## Technical Context

**Language/Version**: ArkTS (API 12+, HarmonyOS 6.0.2)  
**Primary Dependencies**: `@kit.ArkWeb` (Web组件), `@kit.ArkData` (relationalStore), `@kit.CoreFileKit` (fileIo, fileShare, picker), `@kit.AbilityKit` (UIAbility, promptAction), `@kit.NetworkKit` (http)  
**Storage**: `@ohos.data.relationalStore` (SQLite) — 表: `web_apps`, `settings`  
**UI Framework**: ArkUI 声明式 UI, Navigation 导航, @CustomDialog / openCustomDialog  
**Target Platform**: HarmonyOS NEXT (API 12+), Phone  
**Project Type**: HarmonyOS 移动应用  
**Performance Goals**: 列表 20+ 项滚动 > 55fps, SQLite 读写 < 50ms, 页面切换动画流畅  
**Constraints**: 离线场景需本地数据可用, 持久化授权依赖设备能力, 目标 SDK 22  
**Scale/Scope**: 单应用, 单模块(entry), ~30 个 .ets 源文件

## Project Structure

### Source Code (repository root)

```text
entry/src/main/ets/
├── common/
│   ├── Constants.ets          # 更新: 扩展 SourceType, 移除旧接口
│   └── Logger.ets              # [新增] 统一日志工具
│
├── database/
│   └── DatabaseManager.ets     # [新增] SQLite 管理器 (单例, 建表, CRUD)
│
├── model/
│   ├── WebAppItem.ets          # 更新: 新增 persistUri, persistMode 字段
│   └── AppDataSource.ets       # 保留 (适配新 WebAppItem)
│
├── ui/
│   ├── ToastUtil.ets           # [新增] 全局 Toast 工具函数
│   ├── LoadingUtil.ets         # [新增] 全局 Loading 弹窗
│   └── DialogUtil.ets          # [新增] 全局确认/提示弹窗
│
├── util/
│   ├── FileManager.ets         # 更新: 新增持久化授权逻辑
│   ├── StorageManager.ets      # [删除] 由 DatabaseManager 替代
│   ├── WebPreloader.ets        # 优化: 性能改进
│   └── WorkDirectory.ets       # 保留 (沙箱目录管理)
│
├── pages/
│   ├── Index.ets               # 重构: 适配 SQLite + UI 升级
│   ├── ImportPage.ets           # 重构: URL 纯引用 + 持久化授权
│   ├── ViewerPage.ets           # 重构: 支持 URL 直接加载
│   ├── EditPage.ets            # 重构: 适配 SQLite + UI 升级
│   └── SettingsPage.ets        # 重构: 国际化适配 + UI 升级
│
└── entryability/
    └── EntryAbility.ets        # 更新: 初始化 SQLite, 激活持久化授权

resources/
├── base/
│   ├── element/
│   │   ├── string.json         # [更新] 中文资源 (浮叶/WebLeaf)
│   │   └── color.json          # [更新] 品牌色
│   ├── media/
│   │   └── app_icon.png        # [更新] 新应用图标
│   └── profile/
│       └── main_pages.json     # 保留
│
├── en_US/
│   ├── element/
│   │   └── string.json         # [新增] 英文资源 (WebLeaf)
│   └── media/
│       └── app_icon.png        # [新增] 英文环境图标(可选)
│
├── dark/                        # [新增] 深色模式资源覆盖
│   └── element/
│       └── color.json
│
└── rawfile/
    └── code_artifact.html       # 保留

AppScope/
├── app.json5                    # [更新] label: 浮叶, icon
└── resources/
    └── media/
        └── app_icon.png         # [更新]

entry/src/main/
├── module.json5                 # [更新] 权限声明, 应用名
└── resources/                   # (同上 resources/ 结构)
```

## Research & Decisions

### R-001: SQLite 数据库方案

- **Decision**: 使用 `@ohos.data.relationalStore` 模块，单例模式管理 RdbStore 实例
- **Rationale**: HarmonyOS 官方推荐的关系型数据库方案，基于 SQLite 内核，支持事务、索引、加密、多线程安全
- **Alternatives considered**:
  - Preferences (当前方案): 只适合简单键值对，不适合结构化数据查询
  - 分布式数据对象: 过于复杂，当前无分布式需求
  - 纯文件存储 (JSON): 无法支持高效查询和事务

### R-002: Web 组件直接加载网络 URL

- **Decision**: Web 组件原生支持加载 https/http URL，无需下载到本地
- **Rationale**: Web 组件的 `src` 属性直接接受 URL 字符串，也可通过 `controller.loadUrl()` 动态加载。需要 `INTERNET` 权限和 `mixedMode(MixedMode.All)`
- **Alternatives considered**:
  - 下载到沙箱再加载 (当前): 浪费存储空间和下载时间
  - 使用 loadData 加载 HTML 字符串: 需要先 fetch 内容，对复杂页面支持差

### R-003: 文件持久化授权方案

- **Decision**: 采用 `ohos.fileshare.persistPermission` 实现持久化授权，同时保留沙箱复制作为 fallback
- **Rationale**: Picker 选择的 URI 只有临时授权，应用重启后失效。持久化授权需：
  1. `canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')` 检查设备支持
  2. 申请 `ohos.permission.FILE_ACCESS_PERSIST` 权限
  3. 选择文件后调用 `fileShare.persistPermission()` 持久化授权
  4. 应用启动时调用 `fileShare.activatePermission()` 激活授权
- **Alternatives considered**:
  - 纯沙箱复制 (当前 fallback): 最可靠但占用额外空间
  - 仅持久化授权: 部分设备不支持，需 fallback

### R-004: 全局 UI 工具函数实现方式

- **Decision**: 使用 `promptAction.openCustomDialog` + `ComponentContent` 实现全局 Loading 和 Dialog；`promptAction.showToast` 封装 Toast
- **Rationale**: `openCustomDialog` 不依赖页面内 `CustomDialogController` 声明，可通过全局 context 在任意位置调用，支持动态更新
- **Alternatives considered**:
  - @CustomDialog + CustomDialogController: 需在每个页面声明 controller，耦合度高
  - 系统 AlertDialog: 样式不可定制，功能有限

### R-005: 国际化方案

- **Decision**: 使用 HarmonyOS resource 目录的多语言文件 (`base/element/string.json` 中文, `en_US/element/string.json` 英文)
- **Rationale**: 系统原生支持通过 `$r('app.string.xxx')` 引用资源，自动跟随系统语言切换，无需额外框架
- **Alternatives considered**:
  - 运行时 JS 映射表: 需手动触发切换，无法与系统语言联动
  - i18n 第三方库: 开源生态不成熟，增加依赖风险

### R-006: UI/UX 全面升级策略

- **Decision**: 分两层推进 — (1) 基础层：品牌色系统、深色/浅色主题适配、统一间距圆角规范；(2) 交互层：页面转场动画、按钮反馈、列表加载动效
- **Rationale**: 先建立设计基础（颜色、字体、间距），在此基础上叠加动效，避免两者耦合难以调试
- **Alternatives considered**:
  - 一次性全部改动: 风险高、难以验证每个变更的正确性
  - 仅改颜色: 不够彻底，用户体验提升有限

## Data Model

### Table: web_apps

存储所有导入的 HTML 应用条目。

```sql
CREATE TABLE IF NOT EXISTS web_apps (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT DEFAULT '',
  logo_type   TEXT DEFAULT 'initial',   -- 'initial' | 'custom'
  logo_uri    TEXT DEFAULT '',
  entry_html  TEXT NOT NULL,             -- 本地路径 / 网络 URL
  source_type TEXT DEFAULT 'file',       -- 'preset' | 'file' | 'url'
  create_time INTEGER NOT NULL,
  persist_uri TEXT DEFAULT '',           -- [新增] 持久化授权 URI
  persist_mode TEXT DEFAULT ''           -- [新增] 'read' | 'read_write' | ''
);
```

**字段说明**:
- `entry_html`: 当 `source_type='url'` 时为 URL 字符串；当 `source_type='file'` 时为本地沙箱路径；当 `source_type='preset'` 时为 `rawfile://` 前缀
- `persist_uri` / `persist_mode`: 仅当成功进行持久化授权时填充，用于重启后激活授权

### Table: settings

存储应用设置项（替代 Preferences 存储），键值对结构。

```sql
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

**预定义键值**:
| key | 默认值 | 说明 |
|-----|--------|------|
| `color_mode` | `'system'` | 颜色模式: system / light / dark |
| `preload_enabled` | `'true'` | 预加载开关 |
| `layout_mode` | `'grid'` | 主页布局: grid / list |

### Data Access Patterns

| 操作 | API | 说明 |
|------|-----|------|
| 获取所有应用 | `SELECT * FROM web_apps ORDER BY create_time DESC` | 首页列表 |
| 按 ID 查询 | `SELECT * FROM web_apps WHERE id = ?` | 编辑/查看 |
| 新增应用 | `INSERT INTO web_apps VALUES (?,?,?,?,?,?,?,?,?,?)` | 导入 |
| 更新应用 | `UPDATE web_apps SET name=?, ... WHERE id=?` | 编辑保存 |
| 删除应用 | `DELETE FROM web_apps WHERE id=?` | 删除 |
| 获取设置 | `SELECT value FROM settings WHERE key=?` | 读取设置 |
| 保存设置 | `INSERT OR REPLACE INTO settings VALUES (?,?)` | 更新设置 |

## Contracts & Interfaces

### DatabaseManager (database/DatabaseManager.ets)

```typescript
// 单例类
export class DatabaseManager {
  static getInstance(context: Context): DatabaseManager;
  
  // 初始化数据库 (创建表结构)
  init(): Promise<void>;
  
  // web_apps CRUD
  getAllApps(): Promise<WebAppItem[]>;
  getAppById(id: string): Promise<WebAppItem | null>;
  addApp(item: WebAppItem): Promise<void>;
  updateApp(item: WebAppItem): Promise<void>;
  deleteApp(id: string): Promise<void>;
  
  // settings CRUD
  getSetting(key: string, defaultVal: string): Promise<string>;
  setSetting(key: string, value: string): Promise<void>;
}
```

### ToastUtil (ui/ToastUtil.ets)

```typescript
export class Toast {
  static show(message: string | Resource, duration?: number): void;
  static success(message: string | Resource): void;    // 绿色成功提示
  static error(message: string | Resource): void;      // 红色错误提示
}
```

### LoadingUtil (ui/LoadingUtil.ets)

```typescript
export class Loading {
  static show(message?: string): void;    // 显示加载弹窗
  static hide(): void;                    // 关闭加载弹窗
  static setContext(context: UIContext): void;  // 设置上下文 (EntryAbility 初始化)
}
```

### DialogUtil (ui/DialogUtil.ets)

```typescript
export interface DialogOption {
  title: string | Resource;
  message: string | Resource;
  confirmText?: string | Resource;    // 默认 "确定"
  cancelText?: string | Resource;     // 默认 "取消"
  onConfirm?: () => void;
  onCancel?: () => void;
}

export class Dialog {
  static setContext(context: UIContext): void;         // 初始化
  static confirm(option: DialogOption): void;          // 确认弹窗
  static alert(option: DialogOption): void;            // 提示弹窗 (仅确认按钮)
  static showCustom(builder: WrappedBuilder<[]>): void; // 自定义内容弹窗
}
```

### FileManager Enhancement (util/FileManager.ets)

```typescript
// 新增方法
export class FileManager {
  // 尝试持久化授权 (返回是否成功)
  tryPersistPermission(uri: string): Promise<boolean>;
  
  // 激活已持久化权限 (应用启动时调用)
  static activatePermissions(uris: string[]): Promise<void>;
  
  // 检查设备是否支持持久化授权
  static isPersistPermissionSupported(): boolean;
}
```

### WebAppItem Enhancement (model/WebAppItem.ets)

```typescript
export class WebAppItem {
  id: string = '';
  name: string = '';
  description: string = '';
  logoType: string = LogoType.INITIAL;
  logoUri: string = '';
  entryHtml: string = '';
  sourceType: string = SourceType.FILE;
  createTime: number = 0;
  persistUri: string = '';     // [新增]
  persistMode: string = '';    // [新增]
}
```

### SourceType Extended (common/Constants.ets)

```typescript
export enum SourceType {
  PRESET = 'preset',
  FILE = 'file',
  URL = 'url',           // [新增] 网络 URL 引用
  // 移除 DIRECTORY — 目录扫描功能保持但标记来源为 FILE
}
```

### Module Permissions (module.json5)

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" },
      { "name": "ohos.permission.FILE_ACCESS_PERSIST" }  // [新增] 持久化授权
    ]
  }
}
```

## Implementation Phases Summary

| 阶段 | 内容 | 依赖 |
|------|------|------|
| **Setup** | 品牌更名(浮叶/WebLeaf)、资源文件、权限配置 | — |
| **Data Layer** | SQLite DatabaseManager、数据模型更新 | Setup |
| **Common Utilities** | ToastUtil, LoadingUtil, DialogUtil | — |
| **Import Refactor** | URL 纯引用、持久化授权、FileManager 更新 | Data Layer |
| **Viewer Update** | 支持 URL 直接加载 Web 内容 | Import Refactor |
| **UI/UX & i18n** | 主题升级、国际化、交互优化 | 以上全部 |
| **Performance** | 预加载优化、列表渲染、代码结构优化 | UI/UX |
