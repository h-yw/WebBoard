import { webview } from '@kit.ArkWeb'
import { WebBoardConstants } from '../common/Constants'

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
    const existing = this.entries.find(e => e.key === key)
    if (existing) {
      existing.timestamp = Date.now()
      return
    }

    if (this.entries.length >= this.maxPreload) {
      this.entries.sort((a, b) => a.timestamp - b.timestamp)
      this.entries.shift()
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
