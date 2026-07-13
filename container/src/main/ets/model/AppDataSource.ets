import { WebAppItem } from './WebAppItem'

export class AppDataSource implements IDataSource {
  private apps: WebAppItem[] = []
  private listener: DataChangeListener | null = null

  totalCount(): number {
    return this.apps.length
  }

  getData(index: number): WebAppItem {
    if (index >= 0 && index < this.apps.length) {
      return this.apps[index]
    }
    return new WebAppItem()
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listener = listener
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listener = null
  }

  setApps(apps: WebAppItem[]): void {
    this.apps = apps
    if (this.listener) {
      this.listener.onDataReloaded()
    }
  }

  addApp(item: WebAppItem): void {
    this.apps.push(item)
    if (this.listener) {
      this.listener.onDataAdd(this.apps.length - 1)
    }
  }

  removeApp(index: number): void {
    if (index >= 0 && index < this.apps.length) {
      this.apps.splice(index, 1)
      if (this.listener) {
        this.listener.onDataDelete(index)
      }
    }
  }

  updateApp(index: number, item: WebAppItem): void {
    if (index >= 0 && index < this.apps.length) {
      this.apps[index] = item
      if (this.listener) {
        this.listener.onDataChange(index)
      }
    }
  }

  clear(): void {
    this.apps = []
    if (this.listener) {
      this.listener.onDataReloaded()
    }
  }
}
