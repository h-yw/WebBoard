import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { image } from '@kit.ImageKit'
import { ComponentContent } from '@kit.ArkUI'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import { WebAppItem } from '../model/WebAppItem'
import { Toast } from '../ui/ToastUtil'
import { Logger } from '../common/Logger'
import { AppShareCardBuilder, ShareCardParams } from '../component/AppShareCard'

interface ScanNavParam {
  scanUrl: string
  scanName: string
  scanDesc: string
}

/**
 * Share an app as a card image via the system share sheet.
 */
export async function shareAppCard(
  item: WebAppItem,
  context: common.UIAbilityContext,
  uiContext: UIContext
): Promise<void> {
  try {
    const params: ShareCardParams = new ShareCardParams(
      item.name, item.description, item.logoType, item.logoUri, item.entryHtml
    )
    const contentNode: ComponentContent<ShareCardParams> = new ComponentContent(
      uiContext, wrapBuilder(AppShareCardBuilder), params
    )

    const pixelMap: PixelMap = await uiContext.getComponentSnapshot()
      .createFromComponent(contentNode, 360, true, { scale: 2, waitUntilRenderFinished: true })

    const tmpPath: string = context.filesDir + '/share_card_' + Date.now().toString() + '.png'
    const packer: image.ImagePacker = image.createImagePacker()
    try {
      const packedData: ArrayBuffer = await packer.packToData(pixelMap, {
        format: 'image/png',
        quality: 100
      })
      const file = fs.openSync(tmpPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, packedData)
      fs.closeSync(file)
    } finally {
      packer.release()
    }

    const imageUri: string = fileUri.getUriFromPath(tmpPath)
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.IMAGE,
      uri: imageUri,
      title: item.name
    })

    const controller: systemShare.ShareController = new systemShare.ShareController(sharedData)
    controller.on('shareCompleted', () => {})
    controller.on('dismiss', () => {
      setTimeout(() => {
        try {
          if (fs.accessSync(tmpPath)) {
            fs.unlinkSync(tmpPath)
          }
        } catch (e) {
          Logger.warn('IndexActions', 'cleanup share temp file failed')
        }
      }, 3000)
    })
    controller.show(context, {
      previewMode: systemShare.SharePreviewMode.DETAIL
    })
  } catch (e) {
    Logger.error('IndexActions', 'shareAppCard failed: ' + JSON.stringify(e))
    Toast.show('分享失败')
  }
}

/**
 * Recursively delete a directory and all its contents.
 */
export function deleteDirectory(dirPath: string): void {
  try {
    const stack: string[] = [dirPath]
    const filesToDelete: string[] = []

    while (stack.length > 0) {
      const currentDir: string = stack.pop()!
      const entries: string[] = fs.listFileSync(currentDir)

      for (let i = 0; i < entries.length; i++) {
        const entry: string = entries[i]
        const fullPath: string = currentDir + '/' + entry
        const stat = fs.statSync(fullPath)
        if (stat.isDirectory()) {
          stack.push(fullPath)
        } else {
          filesToDelete.push(fullPath)
        }
      }
    }

    for (let i = filesToDelete.length - 1; i >= 0; i--) {
      fs.unlinkSync(filesToDelete[i])
    }

    const dirsToDelete: string[] = [dirPath]
    const tempStack: string[] = [dirPath]
    while (tempStack.length > 0) {
      const currentDir: string = tempStack.pop()!
      const entries: string[] = fs.listFileSync(currentDir)
      for (let i = 0; i < entries.length; i++) {
        const entry: string = entries[i]
        const fullPath: string = currentDir + '/' + entry
        const stat = fs.statSync(fullPath)
        if (stat.isDirectory()) {
          dirsToDelete.push(fullPath)
          tempStack.push(fullPath)
        }
      }
    }

    for (let i = dirsToDelete.length - 1; i >= 0; i--) {
      fs.rmdirSync(dirsToDelete[i])
    }
  } catch (e) {
    Logger.error('IndexActions', 'deleteDirectory failed: ' + dirPath)
  }
}

/**
 * Start QR code scanning. If a valid QR content is found,
 * navigates to ImportPage with the scanned data.
 */
export async function startScan(
  context: common.UIAbilityContext,
  uiContext: UIContext,
  navPathStack: NavPathStack
): Promise<void> {
  try {
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: false,
      enableAlbum: true
    }
    const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options)
    const rawVal: string = result.originalValue
    if (rawVal.length === 0 || rawVal === 'undefined') {
      Toast.show('未识别到二维码内容')
      return
    }
    const cleaned: string = rawVal.trim()
    Logger.info('IndexActions', 'scan raw: [' + cleaned + '] len=' + cleaned.length.toString())
    let parsed: Record<string, string>
    try {
      parsed = JSON.parse(cleaned) as Record<string, string>
    } catch (e) {
      uiContext.showAlertDialog({
        title: '扫码结果',
        message: '原始内容:\n' + cleaned + '\n\n长度: ' + cleaned.length.toString(),
        buttons: [{ value: '确定', action: (): void => {} }]
      })
      return
    }
    const title: string = parsed['t'] || ''
    const desc: string = parsed['d'] || ''
    const url: string = parsed['u'] || ''
    if (url.length > 0) {
      const scanNav: ScanNavParam = { scanUrl: url, scanName: title, scanDesc: desc }
      navPathStack.pushPath({ name: 'ImportPage', param: scanNav })
    } else {
      Toast.show('二维码内容不包含有效网址')
    }
  } catch (e) {
    Toast.show('扫码已取消')
  }
}
