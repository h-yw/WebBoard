# webleaf-sdk

**HarmonyOS JSBridge SDK — TypeScript type definitions for WebBoard (浮叶)**

当你的 H5 页面运行在 WebBoard (浮叶) 的 WebView 中时，`window.webLeaf` 对象会被自动注入，让前端代码直接调用 HarmonyOS 原生能力。

这个 npm 包提供 TypeScript 类型定义和辅助函数。**不需要安装也能用**（SDK 自动注入），安装只是为了获得 IDE 类型提示。

## 安装

```bash
npm install webleaf-sdk
# 或
yarn add webleaf-sdk
```

## 快速开始

### TypeScript 项目

```typescript
import { waitForWebLeaf, WebLeafSDK } from 'webleaf-sdk'

async function main() {
  // 等待 SDK 注入完成（自动注入通常在页面加载前完成）
  await waitForWebLeaf()

  // 获取应用信息
  const info = await window.webLeaf.getAppInfo()
  console.log('应用:', info.appName)
  console.log('SDK 版本:', info.sdkVersion)
  console.log('设备:', info.deviceBrand, info.deviceModel)

  // 检查特定方法是否可用
  const result = await window.webLeaf.hasMethod('vibrate')
  if (result.available) {
    await window.webLeaf.vibrate({ duration: 200, count: 1 })
  }
}

main()
```

### Vanilla JS 项目

```html
<script>
// SDK 自动注入，无需任何 import

// 方式一: 监听事件
window.addEventListener('WebLeafReady', function() {
  window.webLeaf.getAppInfo().then(info => {
    console.log('应用:', info.appName)
  })
})

// 方式二: 轮询检测
function waitForSDK() {
  if (window.webLeaf && window.webLeaf.getAppInfo) {
    window.webLeaf.getVersion().then(v => {
      console.log('SDK:', v.sdk, '容器:', v.container)
    })
    return
  }
  setTimeout(waitForSDK, 200)
}
waitForSDK()
</script>
```

## API 参考

### 基础方法

| 方法 | 描述 |
|------|------|
| `getAppInfo()` | 获取应用信息、SDK 版本、网络状态、设备信息 |
| `getVersion()` | 获取 SDK 版本(`sdk`)、容器版本(`container`)、API 级别(`api`) |
| `hasMethod(name)` | 检测指定方法在当前容器中是否可用，返回 `{ available: boolean }` |
| `call(method, params)` | 通用方法入口，传入方法名和参数对象 |

### UI 控制

| 方法 | 描述 |
|------|------|
| `modifyNavStyle(style, title?)` | 修改查看器导航栏。`style=0` 隐藏，`style=1` 透明，`style=-1` 设标题 |

### 系统能力

| 方法 | 描述 | 权限需求 |
|------|------|---------|
| `systemShare(params)` | 调起系统分享面板 | 无 |
| `systemImagePick(params)` | 打开系统相册选择图片 | 无 |
| `vibrate(params)` | 设备震动 | `ohos.permission.VIBRATE` |
| `setClipboard(text)` | 写入系统剪贴板 | 无 |
| `getLocation()` | 获取 GPS 定位 | 运行时授权（自动弹窗） |
| `downloadFile(url, path?)` | 下载文件到缓存目录 | 无 |
| `showNotification(title, body)` | 发送系统通知 | 运行时授权（自动弹窗） |
| `setScreenKeepAwake(enabled)` | 屏幕常亮/关闭 | 无 |

### 导航

| 方法 | 描述 |
|------|------|
| `navigateBack()` | 返回上一页（等同于系统返回） |
| `onBackPress()` | 注册返回拦截（H5 可阻止默认返回行为） |

### 辅助函数

| 函数 | 描述 |
|------|------|
| `isWebLeafAvailable()` | 同步检测 `window.webLeaf` 是否可用 |
| `waitForWebLeaf(timeout?)` | 等待 SDK 就绪，超时则 reject（默认 10s） |

## 错误处理

所有方法返回 Promise，成功 resolve `data`，失败 reject 带有 `code` 属性的 Error：

```typescript
try {
  const data = await window.webLeaf.getAppInfo()
} catch (err) {
  console.error(err.code)    // 'PERMISSION_DENIED' | 'USER_CANCELLED' | 'TIMEOUT' | ...
  console.error(err.message) // 人类可读的错误描述
}
```

常见错误码：

| 错误码 | 含义 |
|--------|------|
| `PERMISSION_DENIED` | 权限不足 |
| `USER_CANCELLED` | 用户取消操作 |
| `TIMEOUT` | 调用超时（30 秒） |
| `METHOD_NOT_FOUND` | 方法不存在 |
| `INTERNAL_ERROR` | 系统内部错误 |
| `INVALID_PARAMS` | 参数不合法 |

## 安全

- 所有 JSBridge 调用有 **30 秒超时保护**
- Callback 上限 **500 个**，超出自动清理最旧的 100 个
- **iframe 安全屏蔽**：iframe 中的页面无法访问 `window.webLeaf`
- 权限按来源管控：内置 rawfile 全部信任，本地/在线文件限制敏感方法

## 开发

```bash
git clone ...
cd webleaf-sdk
npm install
npm run build    # 构建 dist/
npm run prepublishOnly  # 发布前构建
```

## 示例

参考 [`examples/basic-usage.html`](./examples/basic-usage.html) 查看完整的使用示例。

## License

MIT
