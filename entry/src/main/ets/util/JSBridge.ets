import { webview } from '@kit.ArkWeb'
import { common, bundleManager } from '@kit.AbilityKit'
import { connection } from '@kit.NetworkKit'
import request from '@ohos.request'
import { deviceInfo } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { vibrator } from '@kit.SensorServiceKit'
import { util } from '@kit.ArkTS'
import { Logger } from '../common/Logger'

interface NavStyleParams {
  style: number
  title?: string
}

interface ShareParams {
  title?: string
  content?: string
  image?: string
  url?: string
  type?: string
}

interface ImagePickParams {
  type?: string
  count?: number
  limit?: number
}

interface VibrateParams {
  type?: string
  duration?: number
  interval?: number
  count?: number
}

interface BackPressCallbackParam {
  callbackId: string
}

export interface JsProxyObject {
  object: object
  name: string
  methodList: string[]
  controller: webview.WebviewController
  port?: object[]
}

interface ShareResult {
  platform: string
}

interface PhotoItem {
  path: string
  name: string
  size: number
  base64: string
}

interface GetAppInfoResult {
  appName: string
  appVersion: string
  appVersionName: string
  internet: string
  deviceBrand: string
  deviceModel: string
}

interface JSBridgeResponse {
  status: string
  data?: object | null
  error?: string
}

class JSBridgeProxyObject {
  private bridge: JSBridge

  constructor(bridge: JSBridge) {
    this.bridge = bridge
  }

  call(method: string, params: string, callId: string): void {
    this.bridge.handleCall(method, params, callId)
  }
}

export class JSBridge {
  private controller: webview.WebviewController
  private context: common.UIAbilityContext
  private navChangeCallback: ((style: number, title?: string) => void) | null = null
  private backPressCallback: (() => boolean) | null = null
  private backPressCallbackIds: string[] = []
  private navigateBackCallback: (() => void) | null = null

  constructor(controller: webview.WebviewController, context: common.UIAbilityContext) {
    this.controller = controller
    this.context = context
  }

  get javaScriptProxy(): JsProxyObject {
    return {
      object: new JSBridgeProxyObject(this),
      name: 'JSBridgeHandle',
      methodList: ['call'],
      controller: this.controller
    }
  }

  initJSBridge(): void {
    const script: string =
      '(function() {' +
      'if (window.JSBridge) return;' +
      'window.JSBridge = {' +
      '  _callbacks: {},' +
      '  _callId: 0,' +
      '  call: function(method, params, callback) {' +
      '    var id = String(++this._callId);' +
      '    if (typeof callback === "function") {' +
      '      this._callbacks[id] = callback;' +
      '    }' +
      '    params = params || {};' +
      '    window.JSBridgeHandle.call(method, JSON.stringify(params), id);' +
      '    return id;' +
      '  }' +
      '};' +
      'window.__JSBridgeCallback__ = function(id, data) {' +
      '  var cb = window.JSBridge._callbacks[id];' +
      '  if (cb) {' +
      '    cb(typeof data === "string" ? JSON.parse(data) : data);' +
      '    delete window.JSBridge._callbacks[id];' +
      '  }' +
      '};' +
      '})();'
    try {
      this.controller.runJavaScript(script)
    } catch (e) {
      Logger.error('JSBridge', 'initJSBridge failed')
    }
  }

  handleCall(method: string, params: string, callId: string): void {
    switch (method) {
      case 'getAppInfo':
        this.handleGetAppInfo(callId)
        break
      case 'modifyNavStyle':
        this.handleModifyNavStyle(params, callId)
        break
      case 'systemShare':
        this.handleSystemShare(params, callId)
        break
      case 'systemImagePick':
        this.handleSystemImagePick(params, callId)
        break
      case 'vibrate':
        this.handleVibrate(params, callId)
        break
      case 'onBackPress':
        this.handleOnBackPress(params, callId)
        break
      case 'navigateBack':
        this.handleNavigateBack(callId)
        break
      default:
        this.callback(callId, { status: 'error', error: 'unknown method: ' + method })
        break
    }
  }

  callback(callId: string, data: JSBridgeResponse): void {
    try {
      const jsonStr: string = JSON.stringify(data)
      const script: string = 'window.__JSBridgeCallback__("' + callId + '",' + jsonStr + ')'
      this.controller.runJavaScript(script)
    } catch (e) {
      Logger.error('JSBridge', 'callback failed')
    }
  }

  setNavChangeCallback(cb: ((style: number, title?: string) => void) | null): void {
    this.navChangeCallback = cb
  }

  setNavigateBackCallback(cb: (() => void) | null): void {
    this.navigateBackCallback = cb
  }

  setBackPressCallback(cb: (() => boolean) | null): void {
    this.backPressCallback = cb
  }

  getBackPressCallback(): (() => boolean) | null {
    return this.backPressCallback
  }

  hasBackPressCallback(): boolean {
    return this.backPressCallback !== null || this.backPressCallbackIds.length > 0
  }

  private handleGetAppInfo(callId: string): void {
    try {
      let appName: string = 'WebBoard'
      let appVersion: string = '1.0.0'
      let appVersionName: string = '1.0.0'

      try {
        const bundleInfo = bundleManager.getBundleInfoForSelfSync(
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
        )
        appVersion = bundleInfo.versionName
        appVersionName = bundleInfo.versionName
        if (bundleInfo.appInfo) {
          appName = bundleInfo.appInfo.label
        }
      } catch (e) {
        Logger.warn('JSBridge', 'getBundleInfo failed, using defaults')
      }

      let internet: string = 'none'
      try {
        const netHandle = connection.getDefaultNetSync()
        const caps = connection.getNetCapabilitiesSync(netHandle)
        if (caps.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0) {
          internet = 'wifi'
        } else if (caps.bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0) {
          internet = 'cellular'
        } else if (caps.bearerTypes.indexOf(connection.NetBearType.BEARER_ETHERNET) >= 0) {
          internet = 'wifi'
        }
      } catch (e) {
        Logger.warn('JSBridge', 'getNetworkInfo failed')
      }

      let deviceBrand: string = 'HUAWEI'
      let deviceModel: string = ''
      try {
        deviceBrand = deviceInfo.brand
        deviceModel = deviceInfo.productModel
      } catch (e) {
        Logger.warn('JSBridge', 'getDeviceInfo failed')
      }

      const data: GetAppInfoResult = {
        appName: appName,
        appVersion: appVersion,
        appVersionName: appVersionName,
        internet: internet,
        deviceBrand: deviceBrand,
        deviceModel: deviceModel
      }

      this.callback(callId, { status: 'ok', data: data as object })
    } catch (e) {
      this.callback(callId, { status: 'error', error: 'getAppInfo failed' })
    }
  }

  private handleModifyNavStyle(paramsStr: string, callId: string): void {
    try {
      const params: NavStyleParams = JSON.parse(paramsStr) as NavStyleParams
      if (this.navChangeCallback) {
        this.navChangeCallback(params.style, params.title)
      }
      this.callback(callId, { status: 'ok', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', error: 'modifyNavStyle failed' })
    }
  }

  private async handleSystemShare(paramsStr: string, callId: string): Promise<void> {
    try {
      const params: ShareParams = JSON.parse(paramsStr) as ShareParams
      const content: string = params.content || ''
      const title: string = params.title || ''
      const url: string = params.url || ''
      const image: string = params.image || ''

      let sharedData: systemShare.SharedData
      if (image.length > 0) {
        // 分享图片：本地路径 / file:// / 网络URL
        let imageUri: string = image
        if (image.startsWith('http://') || image.startsWith('https://')) {
          // 网络图片 → 下载到缓存
          const timestamp: number = Date.now()
          const ext: string = image.endsWith('.png') ? '.png' : '.jpg'
          const tmpPath: string = this.context.cacheDir + '/share_img_' + timestamp.toString() + ext
          try {
            const downloadTask: request.DownloadTask = await request.downloadFile(this.context, {
              url: image,
              filePath: tmpPath
            })
            await new Promise<void>((resolve: Function, reject: Function) => {
              downloadTask.on('complete', () => { resolve() })
              downloadTask.on('fail', (err: number) => { reject(new Error('download failed: ' + err.toString())) })
            })
            imageUri = fileUri.getUriFromPath(tmpPath)
          } catch (e) {
            Logger.error('JSBridge', 'download image failed, fallback to url')
            // 降级为分享链接
            sharedData = new systemShare.SharedData({
              utd: utd.UniformDataType.HYPERLINK,
              content: image,
              title: title
            })
            const controller = new systemShare.ShareController(sharedData)
            let fbShared: boolean = false
            controller.on('shareCompleted', (fbResult: systemShare.ShareOperationResult) => {
              fbShared = true
              const fbPlatform: string = fbResult.targetAbilityInfo.name
              const fbShareResult: ShareResult = { platform: fbPlatform }
              this.callback(callId, { status: 'ok', data: fbShareResult as object })
            })
            controller.on('dismiss', () => {
              if (!fbShared) {
                const fbShareResult: ShareResult = { platform: 'cancelled' }
                this.callback(callId, { status: 'ok', data: fbShareResult as object })
              }
            })
            controller.show(this.context, {})
            return
          }
        } else if (!image.startsWith('file://')) {
          imageUri = fileUri.getUriFromPath(image)
        }
        sharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.IMAGE,
          uri: imageUri,
          title: title
        })
      } else if (url.length > 0) {
        // 分享链接
        sharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: url,
          title: title
        })
      } else {
        // 分享文本
        sharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.PLAIN_TEXT,
          content: content,
          title: title
        })
      }

      const controller = new systemShare.ShareController(sharedData)
      let sharedToTarget: boolean = false

      controller.on('shareCompleted', (result: systemShare.ShareOperationResult) => {
        sharedToTarget = true
        const platform: string = result.targetAbilityInfo.name
        const shareResult: ShareResult = { platform: platform }
        this.callback(callId, { status: 'ok', data: shareResult as object })
      })

      controller.on('dismiss', () => {
        if (!sharedToTarget) {
          const shareResult: ShareResult = { platform: 'cancelled' }
          this.callback(callId, { status: 'ok', data: shareResult as object })
        }
      })

      controller.show(this.context, {})
    } catch (e) {
      Logger.error('JSBridge', 'systemShare failed')
      this.callback(callId, { status: 'error', error: 'systemShare failed' })
    }
  }

  private handleSystemImagePick(paramsStr: string, callId: string): void {
    try {
      const params: ImagePickParams = JSON.parse(paramsStr) as ImagePickParams
      const maxCount: number = params.count || 9

      const picker = new photoAccessHelper.PhotoViewPicker()
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = maxCount

      picker.select(options).then((result: photoAccessHelper.PhotoSelectResult) => {
        const uris: string[] = result.photoUris
        const photoItems: PhotoItem[] = []

        const processNext = (index: number): void => {
          if (index >= uris.length) {
            this.callback(callId, { status: 'ok', data: photoItems as object })
            return
          }

          try {
            const uri: string = uris[index]
            const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
            const stat = fileIo.statSync(uri)
            const name: string = uri.substring(uri.lastIndexOf('/') + 1)

            if (stat.size > 0) {
              const buf = new ArrayBuffer(stat.size)
              fileIo.readSync(file.fd, buf)
              fileIo.closeSync(file)

              const uint8Array = new Uint8Array(buf)
              const base64Helper = new util.Base64Helper()
              const base64Str: string = base64Helper.encodeToStringSync(uint8Array)

              photoItems.push({
                path: uri,
                name: name,
                size: stat.size,
                base64: base64Str
              })
            } else {
              fileIo.closeSync(file)
            }
          } catch (e) {
            Logger.warn('JSBridge', 'read photo failed at index: ' + index.toString())
          }

          processNext(index + 1)
        }

        processNext(0)
      }).catch(() => {
        Logger.error('JSBridge', 'photoPicker select failed')
        this.callback(callId, { status: 'error', error: 'imagePick cancelled or failed' })
      })
    } catch (e) {
      Logger.error('JSBridge', 'systemImagePick failed')
      this.callback(callId, { status: 'error', error: 'systemImagePick failed' })
    }
  }

  private handleVibrate(paramsStr: string, callId: string): void {
    try {
      const params: VibrateParams = JSON.parse(paramsStr) as VibrateParams
      const duration: number = params.duration || 300
      const count: number = params.count || 1
      const interval: number = params.interval || 200

      const actualDuration: number = Math.min(duration, 1000)
      let remaining: number = count

      const doVibrate = (): void => {
        if (remaining <= 0) {
          this.callback(callId, { status: 'ok', data: null })
          return
        }
        try {
          vibrator.startVibration({
            type: 'time',
            duration: actualDuration
          }, {
            usage: 'physicalFeedback'
          })
        } catch (e) {
          Logger.warn('JSBridge', 'vibrate failed')
        }
        remaining--
        if (remaining > 0) {
          setTimeout(doVibrate, actualDuration + interval)
        } else {
          this.callback(callId, { status: 'ok', data: null })
        }
      }

      doVibrate()
    } catch (e) {
      this.callback(callId, { status: 'error', error: 'vibrate failed' })
    }
  }

  private handleOnBackPress(paramsStr: string, callId: string): void {
    try {
      const params: BackPressCallbackParam = JSON.parse(paramsStr) as BackPressCallbackParam
      const callbackId: string = params.callbackId

      this.backPressCallback = (): boolean => {
        try {
          const script: string =
            'window.__JSBridgeCallback__("' + callbackId + '",{"allow":1})'
          this.controller.runJavaScript(script)
        } catch (e) {
          Logger.error('JSBridge', 'backPress callback failed')
        }
        return true
      }

      if (this.backPressCallbackIds.indexOf(callbackId) < 0) {
        this.backPressCallbackIds.push(callbackId)
      }

      this.callback(callId, { status: 'ok', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', error: 'onBackPress failed' })
    }
  }

  private handleNavigateBack(callId: string): void {
    try {
      if (this.navigateBackCallback) {
        this.navigateBackCallback()
      }
      this.callback(callId, { status: 'ok', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', error: 'navigateBack failed' })
    }
  }
}
