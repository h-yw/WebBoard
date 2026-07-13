import { webview } from '@kit.ArkWeb'
import { WebBoardConstants } from '../common/Constants'
import { Logger } from '../common/Logger'

/**
 * Represents a pre-created WebviewController entry in the preheating pool.
 */
export interface PreloadEntry {
  key: string
  controller: webview.WebviewController
  createdAt: number
}

/**
 * WebPreloader tracks recently accessed HTML apps and manages a preheating
 * pool of WebviewController instances. When the app is idle, the preloader
 * creates controllers for the most-used apps so they can be reused instantly
 * when the user navigates to those apps.
 *
 * Features:
 * - Preheating pool with configurable max size (default 2)
 * - TTL-based expiration (default 5 minutes)
 * - Periodic cleanup every 60 seconds
 * - Feature flag for graceful degradation to pure tracker mode
 */
export class WebPreloader {
  private static instance: WebPreloader | null = null
  private recentKeys: string[] = []
  private maxRecent: number = WebBoardConstants.MAX_RECENT
  private pool: PreloadEntry[] = []
  private readonly MAX_POOL: number = 2
  private readonly TTL: number = 5 * 60 * 1000
  private enabled: boolean = true
  private cleanupTimer: number = -1
  private timerStarted: boolean = false

  static getInstance(): WebPreloader {
    if (!WebPreloader.instance) {
      WebPreloader.instance = new WebPreloader()
      WebPreloader.instance.startCleanupTimer()
    }
    return WebPreloader.instance
  }

  private startCleanupTimer(): void {
    if (this.timerStarted) {
      return
    }
    this.timerStarted = true
    this.cleanupTimer = setInterval((): void => {
      this.cleanup()
    }, 60000)
    Logger.debug('WebPreloader', 'cleanup timer started (interval: 60s)')
  }

  /**
   * Pre-create a WebviewController for the given key and add it to the pool.
   * No-op if the pool is full, the key already exists, or preheating is disabled.
   */
  preload(key: string): void {
    if (!this.enabled) {
      return
    }
    if (this.pool.length >= this.MAX_POOL) {
      return
    }
    for (let i = 0; i < this.pool.length; i++) {
      if (this.pool[i].key === key) {
        return
      }
    }
    const entry: PreloadEntry = {
      key: key,
      controller: new webview.WebviewController(),
      createdAt: Date.now()
    }
    this.pool.push(entry)
    Logger.debug('WebPreloader', 'preloaded controller for: ' + key)
  }

  /**
   * Take a pre-created controller out of the pool for the given key.
   * Removes the entry from the pool. Returns null if not preheated or expired.
   */
  takeController(key: string): webview.WebviewController | null {
    for (let i = 0; i < this.pool.length; i++) {
      if (this.pool[i].key === key) {
        const entry: PreloadEntry = this.pool[i]
        this.pool.splice(i, 1)
        Logger.debug('WebPreloader', 'took preloaded controller for: ' + key)
        return entry.controller
      }
    }
    return null
  }

  /**
   * Remove expired entries from the pool (entries older than TTL).
   */
  cleanup(): void {
    const now: number = Date.now()
    const remaining: PreloadEntry[] = []
    for (let i = 0; i < this.pool.length; i++) {
      if (now - this.pool[i].createdAt < this.TTL) {
        remaining.push(this.pool[i])
      }
    }
    if (remaining.length !== this.pool.length) {
      Logger.debug('WebPreloader', 'cleaned up ' + (this.pool.length - remaining.length) + ' expired entries')
      this.pool = remaining
    }
  }

  /**
   * Enable or disable the preheating feature. When disabled, preload() becomes a no-op.
   */
  setEnabled(enabled: boolean): void {
    this.enabled = enabled
    Logger.debug('WebPreloader', 'preheating enabled: ' + enabled)
  }

  /**
   * Record access to an app. Pushes the key to the front of the recent list.
   * If the key already exists, it is moved to the front.
   * The list is capped at maxRecent entries.
   */
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

  /**
   * Get the most recently accessed keys, up to MAX_PRELOAD count.
   */
  getRecentKeys(): string[] {
    return this.recentKeys.slice(0, WebBoardConstants.MAX_PRELOAD)
  }

  /**
   * Remove a key from the recent list.
   */
  remove(key: string): void {
    const index = this.recentKeys.indexOf(key)
    if (index > -1) {
      this.recentKeys.splice(index, 1)
    }
  }

  /**
   * Clear all recent access tracking and the preheating pool.
   */
  clear(): void {
    this.recentKeys = []
    this.pool = []
  }

  /**
   * Stop the cleanup timer and clear all state. Call when the app is shutting down.
   */
  destroy(): void {
    if (this.cleanupTimer > -1) {
      clearInterval(this.cleanupTimer)
      this.cleanupTimer = -1
    }
    this.timerStarted = false
    this.pool = []
    this.recentKeys = []
  }
}
