import { preferences } from '@kit.ArkData';
import { WebAppItem } from '../model/WebAppItem';
import { BusinessError } from '@kit.BasicServicesKit';
import { StorageConstants, ColorMode } from '../common/Constants';

export class StorageManager {
  private prefInstance: preferences.Preferences | null = null
  private initPromise: Promise<void> | null = null
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  private async ensureInit(): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.init()
    }
    await this.initPromise
  }

  private async init(): Promise<void> {
    try {
      this.prefInstance = await preferences.getPreferences(this.context, StorageConstants.STORE_NAME)
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager init failed: ' + err.code + ' ' + err.message)
      this.initPromise = null
      throw new Error('StorageManager init failed: ' + err.code + ' ' + err.message)
    }
  }

  async getAll(): Promise<WebAppItem[]> {
    await this.ensureInit()
    try {
      const json = await this.prefInstance!.get(StorageConstants.KEY_WEB_APPS, '[]') as string
      const rawArr: object[] = JSON.parse(json) as object[]
      const result: WebAppItem[] = []
      for (let i = 0; i < rawArr.length; i++) {
        const obj = rawArr[i] as Record<string, Object>
        result.push(WebAppItem.fromRecord(obj))
      }
      return result
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager getAll failed: ' + err.code + ' ' + err.message)
      return []
    }
  }

  async saveAll(items: WebAppItem[]): Promise<void> {
    await this.ensureInit()
    try {
      const json = JSON.stringify(items)
      await this.prefInstance!.put(StorageConstants.KEY_WEB_APPS, json)
      await this.prefInstance!.flush()
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager saveAll failed: ' + err.code + ' ' + err.message)
    }
  }

  async add(item: WebAppItem): Promise<void> {
    const items = await this.getAll()
    items.push(item)
    await this.saveAll(items)
  }

  async remove(id: string): Promise<void> {
    const items = await this.getAll()
    const filtered: WebAppItem[] = []
    for (let i = 0; i < items.length; i++) {
      if (items[i].id !== id) {
        filtered.push(items[i])
      }
    }
    await this.saveAll(filtered)
  }

  async getColorMode(): Promise<string> {
    await this.ensureInit()
    try {
      return await this.prefInstance!.get(StorageConstants.KEY_COLOR_MODE, ColorMode.SYSTEM) as string
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager getColorMode failed: ' + err.code + ' ' + err.message)
      return ColorMode.SYSTEM
    }
  }

  async setColorMode(mode: string): Promise<void> {
    await this.ensureInit()
    try {
      await this.prefInstance!.put(StorageConstants.KEY_COLOR_MODE, mode)
      await this.prefInstance!.flush()
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager setColorMode failed: ' + err.code + ' ' + err.message)
    }
  }

  async isPreloadEnabled(): Promise<boolean> {
    await this.ensureInit()
    try {
      return await this.prefInstance!.get(StorageConstants.KEY_PRELOAD_ENABLED, true) as boolean
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager isPreloadEnabled failed: ' + err.code + ' ' + err.message)
      return true
    }
  }

  async setPreloadEnabled(enabled: boolean): Promise<void> {
    await this.ensureInit()
    try {
      await this.prefInstance!.put(StorageConstants.KEY_PRELOAD_ENABLED, enabled)
      await this.prefInstance!.flush()
    } catch (e) {
      const err = e as BusinessError
      console.error('StorageManager setPreloadEnabled failed: ' + err.code + ' ' + err.message)
    }
  }
}
