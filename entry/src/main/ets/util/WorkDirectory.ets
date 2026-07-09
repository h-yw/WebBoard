import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { WebAppItem } from '../model/WebAppItem';
import { SourceType, WebBoardConstants } from '../common/Constants';
import { Logger } from '../common/Logger';

export class WorkDirectory {
  static getPath(context: common.UIAbilityContext): string {
    return context.filesDir + '/' + WebBoardConstants.DIR_NAME
  }

  static ensureDirectory(context: common.UIAbilityContext): void {
    const path = WorkDirectory.getPath(context)
    try {
      const stat = fs.statSync(path)
      if (!stat.isDirectory()) {
        fs.mkdirSync(path)
      }
    } catch (e) {
      try {
        fs.mkdirSync(path)
      } catch (mkdirErr) {
        Logger.error('WorkDirectory', 'ensureDirectory failed: ' + path)
      }
    }
  }

  static scanDirectory(context: common.UIAbilityContext): WebAppItem[] {
    const workDir = WorkDirectory.getPath(context)
    const items: WebAppItem[] = []

    try {
      const stat = fs.statSync(workDir)
      if (!stat.isDirectory()) {
        return items
      }
    } catch (e) {
      return items
    }

    let entries: string[] = []
    try {
      entries = fs.listFileSync(workDir)
    } catch (e) {
      return items
    }

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i]
      const fullPath = workDir + '/' + entry

      try {
        const stat = fs.statSync(fullPath)
        if (!stat.isDirectory() && (entry.endsWith('.html') || entry.endsWith('.htm'))) {
          const item = WorkDirectory.createFileItem(entry, fullPath)
          items.push(item)
        }
      } catch (e) {
        continue
      }
    }
    return items
  }

  static createFileItem(fileName: string, filePath: string): WebAppItem {
    const item = new WebAppItem()
    item.id = WorkDirectory.generateId()
    item.name = fileName.replace(/\.html?$/i, '')
    item.description = ''
    item.logoType = 'initial'
    item.logoUri = ''
    item.entryHtml = filePath
    item.sourceType = SourceType.FILE
    item.createTime = Date.now()
    return item
  }

  static generateId(): string {
    const timestamp = Date.now().toString(36)
    const random1 = Math.random().toString(36).substring(2, 8)
    const random2 = Math.random().toString(36).substring(2, 8)
    return timestamp + '-' + random1 + '-' + random2
  }
}
