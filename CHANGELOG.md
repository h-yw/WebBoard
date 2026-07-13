# 更新日志

所有版本的重要变更均记录于此。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [1.0.0] - 2025-07-13

### 首次发布

#### 新增

- 卡片式 HTML 应用管理首页，支持网格/列表双布局切换
- 多来源导入：本地 HTML 文件、URL 远程页面
- 内置预设应用：速算估算微练、JSBridge 测试
- HTML 查看器：WebView 渲染、加载进度条、错误重试
- 应用编辑：修改名称、描述、Logo、网址
- JSBridge 8 个原生方法：getAppInfo / modifyNavStyle / systemShare / systemImagePick / vibrate / onBackPress / navigateBack / call
- URL 参数控制导航：`wl_nav_style` / `wl_nav_title`
- 二维码扫描导入，支持 JSON 格式
- 分享卡片：生成应用分享图 + 系统分享面板
- 下拉刷新扫描工作目录
- 搜索筛选应用
- 长按操作菜单（编辑/分享/删除）
- 设置页：深浅模式切换（跟随系统/浅色/深色）
- 预加载访问追踪（LRU，最多 5 条记录）
- SQLite 数据持久化（web_apps + settings 双表）
- 启动页 SplashPage + 品牌动画

#### 技术架构

- ArkTS + ArkUI 声明式开发
- Navigation + NavDestination 路由模式
- DatabaseManager 单例封装 SQLite
- EventEmitter 跨页面事件总线
- AppDataSource 实现 IDataSource，支持 LazyForEach 懒加载
- ComponentContent + uiContext.getPromptAction 驱动 Dialog/Loading
- hilog 统一日志
- 资源文件规范：颜色值统一迁移至 color.json + `$r()` 引用

---

## [0.9.0] - 2025-07-12

### 内测版本

#### 新增

- 基础卡片列表展示
- HTML 文件导入与查看
- Preferences 键值存储
- 基础 JSBridge 框架

---

> 版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)
