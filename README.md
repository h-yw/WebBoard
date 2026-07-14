# 浮叶 WebLeaf

<p align="center">
  <strong>HarmonyOS HTML 轻应用容器 · 让任何 HTML 页面变成一个"应用"</strong>
</p>

---

## 简介

浮叶（WebLeaf）是一个 **HTML 轻应用容器**——它不是一个浏览器，而是一个让 HTML 页面获得原生能力（分享、定位、剪贴板、通知等）的运行环境。

- **对用户**：导入 HTML 文件或网址 → 以卡片形式管理 → 一键打开
- **对开发者**：编写标准 H5 页面 → 通过 `window.webLeaf` 调用原生 API → 无需学习 ArkTS

| | |
|---|---|
| **包名** | `life.hlovez.webboard` |
| **目标 SDK** | HarmonyOS NEXT SDK 6.0.2 (API 12+) |
| **架构** | 单模块 + HSP 容器分离 |
| **当前版本** | 1.0.0 |

## 核心功能

### 用户功能
- **卡片管理** — 网格/列表双布局，搜索（名称+描述+文件名校验），长按操作菜单
- **一键导入** — 选择 HTML 文件 → 自动提取 `<title>` 作为名称 → 直接保存（无需填表）
- **多来源导入** — 本地 HTML 文件、URL 远程页面、内置预设
- **内置查看器** — WebView 渲染 + JSBridge 注入 + 加载进度 + 错误重试
- **应用编辑** — 修改名称、描述、图标、网址
- **二维码导入** — 扫码导入，JSON 格式 `{"t":"title","d":"desc","u":"url"}`
- **深浅模式** — 跟随系统 / 手动切换
- **搜索历史** — 最近 5 条搜索记录自动保存

### 原生能力 (JSBridge)
H5 页面通过 `window.webLeaf.xxx()` 调用以下原生能力：

| 方法 | 说明 | 权限 |
|---|---|---|
| `getAppInfo()` | 应用信息 + SDK 版本 | — |
| `modifyNavStyle(style, title)` | 导航栏控制（隐藏/透明） | — |
| `systemShare(params)` | 系统分享面板 | — |
| `systemImagePick(params)` | 系统相册图片选择 | — |
| `vibrate(params)` | 设备震动 | `ohos.permission.VIBRATE` |
| `getVersion()` | SDK/容器/API 版本 | — |
| `setClipboard(text)` | 写入系统剪贴板 | — |
| `getLocation()` | GPS 定位 | 运行时弹窗授权 |
| `downloadFile(url)` | 文件下载（缓存目录） | — |
| `showNotification(title, body)` | 系统通知 | 运行时弹窗授权 |
| `setScreenKeepAwake(enabled)` | 屏幕常亮 | — |
| `onBackPress()` | 返回拦截注册 | — |
| `navigateBack()` | 返回上一页 | — |
| `call(method, params)` | 通用方法入口 | — |

### 安全特性
- **三级权限管控**：rawfile(完全信任) / file(限制敏感方法) / url(限制敏感方法)
- **iframe 安全屏蔽**：iframe 中自动删除 JSBridge 对象
- **标准化错误码**：`PERMISSION_DENIED` / `USER_CANCELLED` / `TIMEOUT` 等
- **30s 超时保护**：JSBridge 调用 30 秒自动超时
- **回调防泄漏**：Callback 上限 500，超出自动清理

### 开发者 SDK

```bash
# webleaf-sdk — TypeScript 类型定义
npm install webleaf-sdk
```

SDK 自动注入到 WebView 中（通过 `onPageBegin` + `runJavaScript`），H5 页面零配置即可使用。

```typescript
import { waitForWebLeaf } from 'webleaf-sdk'

await waitForWebLeaf()
const info = await window.webLeaf.getAppInfo()
console.log(info.appName, info.sdkVersion)
```

详见 [`webleaf-sdk/`](./webleaf-sdk/) 目录。

## 技术栈

| 类别 | 技术 |
|---|---|
| 语言 | ArkTS |
| UI 框架 | ArkUI (声明式) |
| 路由 | Navigation + NavDestination |
| 数据库 | SQLite (`@ohos.data.relationalStore`) |
| 跨端通信 | javaScriptProxy + runJavaScript (双轨制) |
| 日志 | Logger (`hilog` 封装) |
| 事件总线 | EventEmitter (订阅/取消订阅) |
| 构建 | Hvigor (daemon + incremental 加速) |

## 项目结构

```
WebBoard/
├── container/ (HSP)                # 容器核心（动态共享包）
│   └── src/main/ets/
│       ├── webview/
│       │   ├── WebContainer.ets     # 可复用 WebView 组件
│       │   ├── JSBridge.ets         # JSBridge 框架 + 权限管控
│       │   └── webleaf-sdk.ets      # SDK 注入脚本
│       ├── database/
│       │   └── DatabaseManager.ets  # SQLite 单例
│       ├── model/                   # 数据模型
│       ├── ui/                      # Toast / Loading / Dialog
│       ├── util/                    # 文件管理 / 预热 / 工作目录
│       └── common/                  # 常量 / 事件总线 / 日志
│
├── entry/ (HAP)                     # 应用管理壳
│   └── src/main/ets/
│       ├── pages/                   # Index / ImportPage / ViewerPage ...
│       ├── entryability/
│       └── resources/
│
└── webleaf-sdk/                     # H5 开发者 SDK（npm 包）
    ├── src/types.ts                 # TypeScript 类型定义
    └── package.json
```

## 权限

| 权限 | 类型 | 用途 |
|---|---|---|
| `INTERNET` | system_grant | WebView 网络访问 |
| `VIBRATE` | system_grant | JSBridge 震动 |
| `FILE_ACCESS_PERSIST` | system_grant | 文件 URI 持久化 |
| `GET_NETWORK_INFO` | system_grant | 网络状态查询 |
| `APPROXIMATELY_LOCATION` | user_grant | JSBridge 定位（运行时弹窗） |
| `LOCATION` | user_grant | 精确定位（运行时弹窗） |

## 构建

```bash
# 增量构建（推荐日常开发）
hvigorw assembleHap

# 全量构建
hvigorw clean && hvigorw assembleHap
```

或使用 DevEco Studio 打开项目直接运行。

## 开发文档

| 文档 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 架构、路由、Web 组件说明 |
| [docs/feature.md](docs/feature.md) | URL 参数 + JSBridge 功能规格 |
| [docs/data-model.md](docs/data-model.md) | 数据模型与存储设计 |
| [docs/ui-design.md](docs/ui-design.md) | UI 设计规范（色彩、间距、字体） |
| [docs/arkts-pitfalls.md](docs/arkts-pitfalls.md) | ArkTS/ArkUI 已知坑位 |

## 已知限制

- SplashPage 使用 `router.replaceUrl()`（有废弃警告），待后续版本迁移到纯 Navigation
- WebView 离屏预加载不可行（ArkUI Web 组件必须在组件树中渲染）
- `onPageShow` 在 Navigation + NavDestination 模式下不保证在返回时触发

## License

MIT
