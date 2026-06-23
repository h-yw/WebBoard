# 数据模型与存储

## WebAppItem 数据模型

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `string` | 唯一标识符，使用时间戳+随机数生成 |
| `name` | `string` | 应用名称 |
| `description` | `string` | 应用描述（可选） |
| `logoType` | `string` | Logo 类型：`'initial'`（首字母）或 `'custom'`（自定义图片） |
| `logoUri` | `string` | 自定义 Logo 图片路径（logoType 为 custom 时有效） |
| `entryHtml` | `string` | 入口 HTML 文件路径，支持 `rawfile://` 和文件路径两种格式 |
| `sourceType` | `string` | 来源类型：`'preset'`（预设）或 `'file'`（导入） |
| `createTime` | `number` | 创建时间戳 |

### 源码

```typescript
export class WebAppItem {
  id: string = ''
  name: string = ''
  description: string = ''
  logoType: string = 'initial'
  logoUri: string = ''
  entryHtml: string = ''
  sourceType: string = 'file'
  createTime: number = 0
}
```

## StorageManager 存储管理

### 功能

- 基于 `@ohos.data.preferences` 实现轻量级键值存储
- 将 WebAppItem 数组序列化为 JSON 字符串存储
- 支持增删查改操作

### API

| 方法 | 说明 |
|------|------|
| `init()` | 初始化 Preferences 实例 |
| `getAll()` | 获取所有 WebAppItem |
| `saveAll(items)` | 保存所有 WebAppItem |
| `add(item)` | 添加单个 WebAppItem |
| `remove(id)` | 根据 id 删除 WebAppItem |

### 存储键

- **Store Name**: `webboard_store`
- **Key**: `web_apps`
- **Value**: JSON 字符串（WebAppItem 数组）

### 源码

```typescript
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'webboard_store'
const KEY_WEB_APPS = 'web_apps'

export class StorageManager {
  private prefInstance: preferences.Preferences | null = null
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  async init(): Promise<void> {
    this.prefInstance = await preferences.getPreferences(this.context, STORE_NAME)
  }

  async getAll(): Promise<WebAppItem[]> {
    if (!this.prefInstance) {
      await this.init()
    }
    const json = await this.prefInstance!.get(KEY_WEB_APPS, '[]') as string
    const rawArr: object[] = JSON.parse(json) as object[]
    // 转换为 WebAppItem 数组...
    return result
  }

  async saveAll(items: WebAppItem[]): Promise<void> {
    if (!this.prefInstance) {
      await this.init()
    }
    const json = JSON.stringify(items)
    await this.prefInstance!.put(KEY_WEB_APPS, json)
    await this.prefInstance!.flush()
  }

  async add(item: WebAppItem): Promise<void> {
    const items = await this.getAll()
    items.push(item)
    await this.saveAll(items)
  }

  async remove(id: string): Promise<void> {
    const items = await this.getAll()
    const filtered = items.filter(item => item.id !== id)
    await this.saveAll(filtered)
  }
}
```

## WebPreloader 预加载管理

### 功能

- 维护最近使用记录（最多 5 个）
- 管理预加载实例（最多 3 个）
- 提供预加载状态查询

### 数据结构

```typescript
interface PreloadEntry {
  key: string           // 唯一标识（entryHtml）
  src: string           // Web 组件加载源
  controller: webview.WebviewController  // Web 控制器
  loaded: boolean       // 是否已加载
  timestamp: number     // 时间戳
}
```

### API

| 方法 | 说明 |
|------|------|
| `getInstance()` | 获取单例实例 |
| `recordAccess(key)` | 记录访问（更新最近使用列表） |
| `getRecentKeys()` | 获取最近使用列表 |
| `preload(key, src)` | 预加载指定资源 |
| `isPreloaded(key)` | 检查是否已预加载 |
| `markLoaded(key)` | 标记为已加载 |
| `getController(key)` | 获取预加载的控制器 |
| `remove(key)` | 移除预加载条目 |
| `clear()` | 清空所有预加载 |

## FileManager 文件管理

### 功能

- 文件选择器（HTML、图片、目录）
- 文件复制（从 URI 到沙箱）
- 目录操作

### API

| 方法 | 说明 |
|------|------|
| `selectHtmlFile()` | 选择 HTML 文件 |
| `selectDirectory()` | 选择目录 |
| `selectImageFile()` | 选择图片文件 |
| `generateId()` | 生成唯一 ID |

## 数据流

```
用户操作 → 页面处理 → StorageManager → Preferences
                ↓
         WebPreloader → 预加载管理
                ↓
         FileManager → 文件操作
```

## 注意事项

1. **数据迁移**：如果 WebAppItem 添加新字段，需要在 StorageManager.getAll() 中处理旧数据的兼容
2. **存储限制**：Preferences 适合小数据量，大量数据应考虑使用数据库
3. **并发安全**：Preferences 不支持多进程并发访问
4. **文件清理**：删除应用时需要清理对应的沙箱文件
