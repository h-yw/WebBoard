# 浮叶 WebLeaf

<p align="center">
  <strong>轻量 HTML 应用管理器 · HarmonyOS NEXT</strong>
</p>

---

## 简介

浮叶（WebLeaf）是一款 HarmonyOS NEXT 原生应用，用于管理和运行 HTML 应用。支持从本地文件、网址或预设内容导入 HTML，以卡片形式展示，点击即用。内置 JSBridge，让 H5 页面可以调用系统原生能力。

| | |
|---|---|
| **应用名称** | 浮叶 / WebLeaf |
| **包名** | `life.hlovez.webboard` |
| **目标 SDK** | HarmonyOS NEXT SDK 6.0.2 (API 12+) |
| **最低设备** | 手机 |
| **当前版本** | 1.0.0 |

## 功能

- **卡片管理** — 网格/列表双布局，搜索筛选，长按操作菜单
- **多来源导入** — 本地 HTML 文件、URL 远程页面、内置预设
- **内置查看器** — WebView 渲染，加载进度条，错误重试
- **应用编辑** — 修改名称、描述、图标、网址
- **JSBridge** — H5 可调用 8 个原生方法（应用信息、导航控制、系统分享、图片选取、震动等）
- **分享卡片** — 生成应用分享图，系统分享面板
- **二维码导入** — 扫码导入应用，支持 JSON 格式 `{"t":"title","d":"desc","u":"url"}`
- **下拉刷新** — 扫描工作目录，自动发现新文件
- **深浅模式** — 跟随系统 / 手动切换
- **预加载追踪** — LRU 访问记录，为后续 WebView 预热预留接口

## 技术栈

| 类别 | 技术 |
|---|---|
| 语言 | ArkTS |
| UI 框架 | ArkUI (声明式) |
| 路由 | Navigation + NavDestination |
| 数据库 | SQLite (`@ohos.data.relationalStore`) |
| 跨端通信 | javaScriptProxy + runJavaScript |
| 日志 | hilog |
| 构建 | Hvigor |

## 项目结构

```
entry/src/main/ets/
├── common/
│   ├── Constants.ets            # 枚举常量 (SourceType, LogoType, LayoutMode)
│   ├── EventEmitter.ets         # 跨页面事件总线 (subscribe/unsubscribe)
│   └── Logger.ets               # hilog 封装
├── component/
│   └── AppShareCard.ets         # 分享卡片组件
├── database/
│   └── DatabaseManager.ets      # SQLite 单例 (web_apps + settings 双表)
├── entryability/
│   └── EntryAbility.ets         # 入口 Ability
├── model/
│   ├── WebAppItem.ets           # 数据模型
│   └── AppDataSource.ets        # LazyForEach IDataSource 实现
├── pages/
│   ├── Index.ets                # 首页 (卡片列表 + 搜索 + 导航)
│   ├── SplashPage.ets           # 启动页
│   ├── ImportPage.ets           # 导入页 (文件/URL)
│   ├── ViewerPage.ets           # HTML 查看器 (WebView + JSBridge)
│   ├── EditPage.ets             # 编辑页
│   └── SettingsPage.ets         # 设置页
├── ui/
│   ├── ToastUtil.ets            # Toast 封装
│   ├── LoadingUtil.ets          # Loading 封装
│   └── DialogUtil.ets           # Dialog 封装 (ComponentContent)
└── util/
    ├── FileManager.ets          # 文件选择/复制
    ├── JSBridge.ets             # JSBridge 方法注册
    ├── WebPreloader.ets         # 访问追踪 (LRU)
    ├── WorkDirectory.ets        # 工作目录管理
    └── IndexActions.ets         # 首页操作 (分享/删除/扫码)
```

## 页面路由

采用 `Navigation + NavDestination` 模式（HarmonyOS API 12+ 推荐）：

- `main_pages.json` 仅注册 `pages/Index` 和 `pages/SplashPage`
- `SplashPage` → `router.replaceUrl()` 跳转 `Index`
- `Index` 内通过 `NavPathStack.pushPath()` 导航到 ImportPage / ViewerPage / EditPage / SettingsPage
- 子页面通过 `@Builder buildNavDestination()` 注册，参数通过 `pushPath({ name, param })` 传递

## 数据库

SQLite 双表设计：

| 表 | 字段 | 说明 |
|---|---|---|
| `web_apps` | id, name, description, logo_type, logo_uri, entry_html, source_type, create_time, persist_uri, persist_mode | 应用数据 |
| `settings` | key, value | 键值设置 (layout_mode, color_mode 等) |

`DatabaseManager` 为单例模式，`init()` 在 `EntryAbility.onCreate()` 中调用，所有页面操作前已初始化完成。

## JSBridge

ViewerPage 通过 `javaScriptProxy` 注入 `JSBridgeHandle` 对象，H5 可调用：

| 方法 | 说明 |
|---|---|
| `getAppInfo()` | 获取应用信息（版本、网络状态、设备信息） |
| `modifyNavStyle(style, title)` | 修改导航栏样式（隐藏/透明） |
| `systemShare(title, content, image, url)` | 调用系统分享 |
| `systemImagePick(type, count, limit)` | 图片选择 |
| `vibrate(type, duration, interval, count)` | 震动反馈 |
| `onBackPress()` | H5 返回回调 |
| `navigateBack()` | 退出查看器 |
| `call(method, params)` | 通用方法入口 |

URL 参数支持：`?wl_nav_style=0`（隐藏导航）、`?wl_nav_title=标题`

## 权限

| 权限 | 用途 |
|---|---|
| `ohos.permission.INTERNET` | WebView 网络访问 |
| `ohos.permission.FILE_ACCESS_PERSIST` | 持久文件 URI 访问 |
| `ohos.permission.VIBRATE` | JSBridge 震动方法 |
| `ohos.permission.GET_NETWORK_INFO` | JSBridge 网络状态查询 |

## 构建

```bash
# 增量构建
hvigorw assembleHap

# 全量构建
hvigorw clean && hvigorw assembleHap
```

或使用 DevEco Studio 打开项目直接构建运行。

## 开发文档

| 文档 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 架构、路由、Web 组件说明 |
| [docs/feature.md](docs/feature.md) | URL 参数 + JSBridge 功能规格 |
| [docs/feature2.md](docs/feature2.md) | 编辑页、卡片列表、分享卡片规格 |
| [docs/data-model.md](docs/data-model.md) | 数据模型与存储设计 |
| [docs/ui-design.md](docs/ui-design.md) | UI 设计规范（色彩、间距、字体） |
| [docs/refactor.md](docs/refactor.md) | 重构记录与优化 TODO |
| [docs/arkts-pitfalls.md](docs/arkts-pitfalls.md) | ArkTS/ArkUI 已知坑位 |

## 已知限制

- `router.replaceUrl()` 在当前 SDK 有废弃警告，但仍为唯一可用的页面替换 API
- WebView 离屏预加载不可行（ArkUI Web 组件必须在组件树中渲染）
- `AppStorage.Set()` 有废弃警告，建议迁移至 `AppStorage.setOrCreate()`
- `onPageShow` 在 Navigation 模式下不保证在返回时触发

## License

MIT
