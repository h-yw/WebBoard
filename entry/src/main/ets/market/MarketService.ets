export interface MarketAppInfo {
  id: string
  name: string
  description: string
  icon: string           // Placeholder icon URL (can use emoji or svg)
  url: string            // Remote URL
  category: string       // 'game' | 'tool' | 'education' | 'entertainment'
  version: string
  size: string           // e.g. '2.5KB'
  downloads: number
  createdAt: string
  installCount?: number  // Mock data
}

export class MarketService {
  // Mock data - replace with real API call later
  private mockApps: MarketAppInfo[] = [
    {
      id: '2048',
      name: '2048',
      description: '经典数字拼图游戏，滑动合并方块直到 2048',
      icon: '🎮',
      url: 'https://example.com/2048',
      category: 'game',
      version: '2.0.0',
      size: '3.2KB',
      downloads: 15230,
      createdAt: '2026-01-15'
    },
    {
      id: 'stopwatch',
      name: '在线秒表',
      description: '精确到毫秒的计时器，支持计次和分段计时',
      icon: '⏱️',
      url: 'https://example.com/stopwatch',
      category: 'tool',
      version: '1.2.0',
      size: '1.8KB',
      downloads: 8930,
      createdAt: '2026-02-20'
    },
    {
      id: 'daily-poem',
      name: '每日诗词',
      description: '每天一句古诗词，感受中文之美',
      icon: '📜',
      url: 'https://example.com/poem',
      category: 'education',
      version: '1.1.0',
      size: '4.5KB',
      downloads: 21450,
      createdAt: '2026-03-01'
    },
    {
      id: 'snake',
      name: '贪吃蛇',
      description: '经典诺基亚风格贪吃蛇游戏',
      icon: '🐍',
      url: 'https://example.com/snake',
      category: 'game',
      version: '1.0.0',
      size: '5.1KB',
      downloads: 32100,
      createdAt: '2026-04-10'
    },
    {
      id: 'calculator',
      name: '科学计算器',
      description: '支持三角函数、对数、指数运算',
      icon: '🧮',
      url: 'https://example.com/calculator',
      category: 'tool',
      version: '1.3.0',
      size: '6.7KB',
      downloads: 18760,
      createdAt: '2026-05-05'
    },
    {
      id: 'typing',
      name: '打字练习',
      description: '英文打字速度测试和练习',
      icon: '⌨️',
      url: 'https://example.com/typing',
      category: 'education',
      version: '1.0.0',
      size: '2.3KB',
      downloads: 5600,
      createdAt: '2026-06-01'
    }
  ]

  getApps(): MarketAppInfo[] {
    return this.mockApps
  }

  getCategories(): string[] {
    const cats: Set<string> = new Set()
    for (let i = 0; i < this.mockApps.length; i++) {
      cats.add(this.mockApps[i].category)
    }
    return Array.from(cats)
  }

  // Future: fetch from real API
  // async fetchApps(): Promise<MarketAppInfo[]> {
  //   const resp = await fetch('https://api.example.com/apps')
  //   return resp.json()
  // }
}

export function getCategoryLabel(category: string): string {
  const map: Record<string, string> = {
    'game': '游戏',
    'tool': '工具',
    'education': '教育',
    'entertainment': '娱乐'
  }
  if (map[category] !== undefined) {
    return map[category]
  }
  return category
}

export function formatDownloads(count: number): string {
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1) + 'M'
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1) + 'K'
  }
  return count.toString()
}
