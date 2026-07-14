/**
 * Preset apps bundled in rawfile/.
 * Add a new entry here + the .html file to rawfile/ to ship a new built-in app.
 */
export interface PresetAppEntry {
  file: string       // filename in rawfile/, e.g. 'flip_clock.html'
  name: string
  description: string
}

export const PRESET_APPS: PresetAppEntry[] = [
  {
    file: 'code_artifact.html',
    name: '速算估算微练',
    description: '掌握 1/2 到 1/20 的快速转换，提升心算敏感度'
  },
  {
    file: 'jsbridge_test.html',
    name: 'JSBridge 测试',
    description: '测试 JSBridge 所有原生方法调用'
  },
  {
    file: 'flip_clock.html',
    name: '翻转时钟',
    description: '优雅的 Flip 时钟，支持屏幕常亮'
  }
]
