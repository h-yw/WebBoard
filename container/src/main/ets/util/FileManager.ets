import { fileIo as fs } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { fileShare } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WorkDirectory } from './WorkDirectory';
import { Logger } from '../common/Logger';

export class FileManager {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async selectHtmlFile(): Promise<string[]> {
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.html', '.htm']
    return await documentPicker.select(options)
  }

  async selectImageFile(): Promise<string[]> {
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.png', '.jpg', '.jpeg', '.webp', '.gif']
    return await documentPicker.select(options)
  }

  copyFileToWorkspace(sourceUri: string, fileName: string, workDir: string): string {
    const destPath = workDir + '/' + fileName

    try {
      const stat = fs.statSync(workDir)
      if (!stat.isDirectory()) {
        fs.mkdirSync(workDir)
      }
    } catch (e) {
      try {
        fs.mkdirSync(workDir)
      } catch (mkdirErr) {
        Logger.error('FileManager', 'copyFileToWorkspace mkdirSync failed: ' + workDir)
        throw new Error('Failed to create work directory: ' + workDir)
      }
    }

    let src: fs.File | undefined = undefined
    let dst: fs.File | undefined = undefined
    try {
      src = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY)
      dst = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      const buf = new ArrayBuffer(4096)
      let readLen = 0
      do {
        readLen = fs.readSync(src.fd, buf)
        if (readLen > 0) {
          fs.writeSync(dst.fd, buf.slice(0, readLen))
        }
      } while (readLen > 0)
    } catch (e) {
      Logger.error('FileManager', 'copyFileToWorkspace copy failed: ' + sourceUri)
    } finally {
      if (src !== undefined) {
        try {
          fs.closeSync(src)
        } catch (e) {
          Logger.error('FileManager', 'closeSync src failed')
        }
      }
      if (dst !== undefined) {
        try {
          fs.closeSync(dst)
        } catch (e) {
          Logger.error('FileManager', 'closeSync dst failed')
        }
      }
    }

    return destPath
  }

  getFileNameFromUri(uri: string): string {
    const decoded = decodeURIComponent(uri)
    const parts = decoded.split('/')
    const lastPart = parts[parts.length - 1] || 'unknown.html'
    const cleanPart = lastPart.split('?')[0]
    if (!cleanPart.includes('.')) {
      return cleanPart + '.html'
    }
    return cleanPart
  }

  generateId(): string {
    return WorkDirectory.generateId()
  }

  static isPersistPermissionSupported(): boolean {
    try {
      return canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')
    } catch (e) {
      return false
    }
  }

  async tryPersistPermission(uri: string): Promise<boolean> {
    if (!FileManager.isPersistPermissionSupported()) {
      return false
    }
    try {
      let policyInfo: fileShare.PolicyInfo = {
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE
      }
      await fileShare.persistPermission([policyInfo])
      return true
    } catch (e) {
      let err = e as BusinessError
      Logger.error('FileManager', 'tryPersistPermission failed for uri: ' + uri + ', error: ' + JSON.stringify(err))
      return false
    }
  }

  static async activatePermissions(uris: string[]): Promise<void> {
    if (!FileManager.isPersistPermissionSupported()) {
      return
    }
    for (let i = 0; i < uris.length; i++) {
      const uri = uris[i]
      if (uri.length === 0) {
        continue
      }
      try {
        let policyInfo: fileShare.PolicyInfo = {
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE
        }
        await fileShare.activatePermission([policyInfo])
      } catch (e) {
        let err = e as BusinessError
        Logger.error('FileManager', 'activatePermissions failed for uri: ' + uri + ', error: ' + JSON.stringify(err))
      }
    }
  }
}
