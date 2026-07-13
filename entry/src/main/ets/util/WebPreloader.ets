import { WebBoardConstants } from '../common/Constants'

/**
 * WebPreloader tracks recently accessed HTML apps so the system can
 * prepare for quick loading. Currently provides access tracking and
 * LRU-based recent list management for future preloading enhancements.
 *
 * In the current architecture, WebView instances cannot be truly preloaded
 * outside of a Web component tree. This tracker serves as the foundation
 * for future platform-level preloading when the API supports it.
 */
export class WebPreloader {
  private static instance: WebPreloader | null = null
  private recentKeys: string[] = []
  private maxRecent: number = WebBoardConstants.MAX_RECENT

  static getInstance(): WebPreloader {
    if (!WebPreloader.instance) {
      WebPreloader.instance = new WebPreloader()
    }
    return WebPreloader.instance
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
   * Clear all recent access tracking.
   */
  clear(): void {
    this.recentKeys = []
  }
}
