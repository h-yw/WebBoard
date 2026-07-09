import { webview } from '@kit.ArkWeb'
import { WebBoardConstants } from '../common/Constants'

const STALE_ENTRY_MS = 5 * 60 * 1000 // 5 minutes

interface PreloadEntry {
  key: string
  src: string
  controller: webview.WebviewController
  loaded: boolean
  timestamp: number
}

export class WebPreloader {
  private static instance: WebPreloader | null = null
  private entries: PreloadEntry[] = []
  private maxPreload: number = WebBoardConstants.MAX_PRELOAD
  private recentKeys: string[] = []
  private maxRecent: number = WebBoardConstants.MAX_RECENT

  static getInstance(): WebPreloader {
    if (!WebPreloader.instance) {
      WebPreloader.instance = new WebPreloader()
    }
    return WebPreloader.instance
  }

  private cleanStale(): void {
    const now = Date.now()
    this.entries = this.entries.filter(e => (now - e.timestamp) < STALE_ENTRY_MS)
  }

  private evictLRU(): void {
    if (this.entries.length === 0) {
      return
    }
    this.entries.sort((a, b) => a.timestamp - b.timestamp)
    this.entries.shift()
  }

  recordAccess(key: string): void {
    const index = this.recentKeys.indexOf(key)
    if (index > -1) {
      this.recentKeys.splice(index, 1)
    }
    this.recentKeys.unshift(key)
    if (this.recentKeys.length > this.maxRecent) {
      this.recentKeys.pop()
    }
  }

  getRecentKeys(): string[] {
    return this.recentKeys.slice(0, this.maxPreload)
  }

  preload(key: string, src: string): void {
    // Skip preloading for network URLs (loaded directly from the web)
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return
    }

    // Clean stale entries on each preload
    this.cleanStale()

    const existing = this.entries.find(e => e.key === key)
    if (existing) {
      existing.timestamp = Date.now()
      return
    }

    if (this.entries.length >= this.maxPreload) {
      this.evictLRU()
    }

    const controller = new webview.WebviewController()
    const entry: PreloadEntry = {
      key: key,
      src: src,
      controller: controller,
      loaded: false,
      timestamp: Date.now()
    }
    this.entries.push(entry)
  }

  isPreloaded(key: string): boolean {
    const entry = this.entries.find(e => e.key === key)
    return entry !== undefined && entry.loaded
  }

  markLoaded(key: string): void {
    const entry = this.entries.find(e => e.key === key)
    if (entry) {
      entry.loaded = true
    }
  }

  getController(key: string): webview.WebviewController | null {
    const entry = this.entries.find(e => e.key === key)
    return entry ? entry.controller : null
  }

  getSrc(key: string): string | null {
    const entry = this.entries.find(e => e.key === key)
    return entry ? entry.src : null
  }

  remove(key: string): void {
    const index = this.entries.findIndex(e => e.key === key)
    if (index > -1) {
      this.entries.splice(index, 1)
    }
  }

  clear(): void {
    this.entries = []
  }
}
