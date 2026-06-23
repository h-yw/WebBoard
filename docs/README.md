# WebBoard 项目文档

## 项目概述

WebBoard 是一个 HarmonyOS 应用，用于管理和渲染 HTML 内容。支持从 assets 读取预设 HTML、导入 HTML 文件或目录，并以卡片形式展示，点击即可使用。

- **Bundle Name**: `life.hlovez.webboard`
- **API Level**: 22
- **目标设备**: 手机

## 功能列表

### 1. 首页卡片展示

- 单列列表布局，全宽显示卡片内容
- 每张卡片包含：图标（渐变紫色首字母或自定义图片）、名称、来源标签、描述
- 支持点击打开查看器，长按删除
- 支持"导入"按钮添加 HTML 应用

### 2. 预设内容

- 内置 `code_artifact.html`（速算估算微练）作为预设内容
- 使用 `$rawfile()` 语法直接加载，无需复制到沙箱
- 首次启动自动添加预设卡片

### 3. HTML 文件导入

- 使用 `DocumentViewPicker` 选择 HTML 文件
- 支持自定义应用名称和描述
- 支持选择自定义 Logo 图片（默认使用首字母图标）
- 文件复制到应用沙箱的 `webboard/` 工作目录
- 导入页面使用系统导航，无自定义返回按钮

### 4. HTML 查看器

- 使用 `Web` 组件渲染 HTML 内容
- 支持 `rawfile://` 和 `file://` 两种路径
- 启用 JavaScript、文件访问、混合内容、DOM 存储
- 启用缓存模式（`CacheMode.Default`）提升二次加载速度
- 加载进度条、错误重试功能
- 使用系统导航返回手势

### 5. 智能预加载

- 记录最近使用的 HTML 文件（最多 5 个）
- 首页空闲时预加载最近使用的 2-3 个文件
- 打开预加载的文件时秒开

### 6. 数据持久化

- 使用 `@ohos.data.preferences` 存储应用列表
- JSON 序列化 WebAppItem 数组
- 支持增删查改操作

## 项目结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # 入口能力
├── model/
│   └── WebAppItem.ets            # 数据模型
├── util/
│   ├── FileManager.ets           # 文件选择器工具
│   ├── StorageManager.ets        # Preferences 持久化
│   ├── WebPreloader.ets          # 智能预加载管理器
│   └── WorkDirectory.ets         # 工作目录管理
├── pages/
│   ├── Index.ets                 # 首页（卡片列表）
│   ├── ImportPage.ets            # 导入页面
│   └── ViewerPage.ets            # HTML 查看器
└── resources/
    └── rawfile/
        └── code_artifact.html    # 预设 HTML 内容
```

## 技术要点

### Navigation 路由

使用 `Navigation` + `NavDestination` 模式实现页面路由：

- **Index.ets**：`@Entry` 组件，包含 `Navigation(navPathStack)` 容器
- **ImportPage.ets**：`@Component` 组件，使用 `NavDestination()` 作为根容器
- **ViewerPage.ets**：`@Component` 组件，使用 `NavDestination()` 作为根容器

系统自动提供返回按钮和返回手势支持。

### 页面注册

`main_pages.json` 只需注册入口页面：

```json5
{
  "src": [
    "pages/Index"
  ]
}
```

子页面通过 `navDestination` builder 注册：

```typescript
@Builder
buildNavDestination(name: string) {
  if (name === 'ImportPage') {
    ImportPage()
  } else if (name === 'ViewerPage') {
    ViewerPage()
  }
}

Navigation(this.navPathStack) {
  // ...
}
.title('WebBoard')
.menus(this.Menus)
.navDestination(this.buildNavDestination)
```

### 标题栏菜单

使用 Navigation 的 `.menus()` 功能添加标题栏右侧按钮：

```typescript
@Builder
Menus() {
  Row({ space: 8 }) {
    Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
      Row({ space: 4 }) {
        Text('🔄').fontSize(16)
        Text('刷新').fontSize(13).fontColor('#6366F1')
      }
    }
    .height(32)
    .borderRadius(6)
    .onClick(() => { this.scanWorkDirectory() })

    Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
      Row({ space: 4 }) {
        Text('＋').fontSize(16).fontColor('#6366F1')
        Text('导入').fontSize(13).fontColor('#6366F1')
      }
    }
    .height(32)
    .borderRadius(6)
    .onClick(() => { this.navigateToImport() })
  }
  .height('100%')
  .padding({ right: 8 })
}
```

### 参数传递

使用 `NavPathStack.pushPath` 传递参数：

```typescript
interface ViewerParam {
  entryHtml: string
  appName: string
}

// 传递参数
const param: ViewerParam = { entryHtml: item.entryHtml, appName: item.name }
this.navPathStack.pushPath({ name: 'ViewerPage', param: param })

// 接收参数
const paramObj = this.navPathStack.getParamByName('ViewerPage') as ViewerParam[]
if (paramObj && paramObj.length > 0) {
  this.entryHtml = paramObj[0].entryHtml
}
```

### Web 组件配置

```typescript
Web({ src: $rawfile('code_artifact.html'), controller: this.controller })
  .javaScriptAccess(true)          // 启用 JavaScript
  .mixedMode(MixedMode.All)        // 允许混合内容
  .domStorageAccess(true)          // 启用 DOM 存储
  .cacheMode(CacheMode.Default)    // 启用缓存
  .onProgressChange((event) => {   // 加载进度
    this.loadProgress = event.newProgress
  })
  .onPageEnd(() => {               // 加载完成
    this.isLoading = false
  })
  .onErrorReceive((event) => {     // 错误处理
    this.hasError = true
  })
```

### rawfile 直接加载

使用 `$rawfile()` 语法直接加载 rawfile 资源，无需复制到沙箱：

```typescript
// 存储标识
item.entryHtml = 'rawfile://code_artifact.html'

// 加载时判断
if (this.entryHtml.startsWith('rawfile://')) {
  Web({ src: $rawfile(this.entryHtml.substring(10)), controller: this.controller })
} else {
  Web({ src: 'file://' + this.entryHtml, controller: this.controller })
}
```

## 配置说明

### 权限配置（module.json5）

```json5
{
  "requestPermissions": [
    {
      "name": "ohos.permission.INTERNET"
    }
  ]
}
```

### 页面注册（main_pages.json）

```json5
{
  "src": [
    "pages/Index"
  ]
}
```

子页面通过 `navDestination` builder 注册（无需在 main_pages.json 中声明）。

## 已知限制

无

## 后续优化方向

1. **应用编辑**：支持修改已导入应用的名称、描述、Logo
2. **应用排序**：支持按名称、时间、使用频率排序
3. **分类管理**：支持对应用进行分类
4. **分享功能**：支持将应用分享给其他用户
