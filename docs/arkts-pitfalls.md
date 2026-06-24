# ArkUI 踩坑记录

## 1. Radio 的 onChange 在程序化变更时触发导致状态回弹

### 问题现象

设置页面中，用户选择外观模式（浅色/深色/跟随系统）后返回，再次打开设置页面时：

1. 先看到正确的选项被选中（如"深色模式"）
2. 闪烁一下，恢复为默认的"跟随系统"

而同一页面的预加载 Toggle 开关没有此问题，设置后能正确保持。

### 根本原因

Radio 组件的 `.onChange()` 回调在 `checked` 属性**程序化变更**时也会触发（不仅仅是用户点击时）。

原代码中每个 Radio 同时有两种事件处理：

```typescript
// 错误写法
Row() {
  Radio({ value: ColorMode.SYSTEM, group: 'colorMode' })
    .checked(this.selectedMode === ColorMode.SYSTEM)
    .onChange(() => {
      this.applyColorMode(ColorMode.SYSTEM)  // 不管参数，写死值
    })
}
.onClick(() => {
  this.applyColorMode(ColorMode.SYSTEM)
})
```

当 `aboutToAppear` 从 preferences 读取到保存的值（如 "dark"）并更新 `@State selectedMode` 时：

1. `selectedMode` 从 `SYSTEM` 变为 `DARK`
2. Radio "DARK" 的 `.checked` 从 `false` 变为 `true` → 正确显示
3. Radio "SYSTEM" 的 `.checked` 从 `true` 变为 `false`
4. **Radio "SYSTEM" 的 `.onChange()` 被触发**（因为 `checked` 发生了变更）
5. `.onChange()` 忽略了回调参数，直接调用 `applyColorMode(SYSTEM)`
6. `selectedMode` 被重置回 `SYSTEM` → 恢复为默认

### Toggle 为什么没有这个问题

```typescript
// Toggle 正常工作
Toggle({ type: ToggleType.Switch, isOn: this.preloadEnabled })
  .onChange((isOn: boolean) => {
    this.setPreloadEnabled(isOn)  // 使用回调参数值
  })
```

Toggle 的 `.onChange()` 不会在 `isOn` 程序化变更时触发（与 Radio 行为不同）。

### 正确做法

使用 `.onClick()` 替代 `.onChange()` 处理用户交互。`.onClick()` 只在用户实际点击时触发，不会在属性程序化变更时触发：

```typescript
// 正确写法
Row() {
  Radio({ value: ColorMode.SYSTEM, group: 'colorMode' })
    .checked(this.selectedMode === ColorMode.SYSTEM)
    .onClick(() => {
      this.applyColorMode(ColorMode.SYSTEM)
    })
}
.onClick(() => {
  this.applyColorMode(ColorMode.SYSTEM)
})
```

### 对比

| 组件 | 事件 | 程序化变更时触发 | 用户交互时触发 | 适用场景 |
|------|------|:---:|:---:|------|
| Radio | `.onChange()` | **是** | 是 | 需要响应所有状态变更时 |
| Radio | `.onClick()` | 否 | 是 | 只需响应用户交互时 |
| Toggle | `.onChange()` | 否 | 是 | 通用 |

### 排查过程

1. **最初怀疑 preferences 存储问题** — 但排查后发现 `put()` + `flush()` 正确持久化
2. **怀疑 async 生命周期问题** — 将 `async aboutToAppear` 改为 `.then()` 模式，问题未解决
3. **发现关键线索**：预加载 Toggle 正常但 Radio 不正常 → 问题出在 Radio 组件本身
4. **对比 Toggle 和 Radio 的区别** → 发现 Radio 的 `.onChange()` 在 `checked` 程序化变更时触发
5. **修复**：移除 `.onChange()`，改用 `.onClick()`

### 经验教训

- **不要假设组件行为一致**：Radio 和 Toggle 的 `onChange` 触发时机不同
- **优先使用 `.onClick()`**：对于只需响应用户交互的场景，`.onClick()` 比 `.onChange()` 更安全
- **关注"闪烁后恢复"现象**：这通常意味着状态被正确设置后又被某个回调重置
- **对比正常工作的相似组件**：通过对比 Toggle 和 Radio 的行为差异快速定位问题
