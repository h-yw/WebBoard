import { webview } from '@kit.ArkWeb'
import { common, bundleManager, abilityAccessCtrl, Permissions, PermissionRequestResult } from '@kit.AbilityKit'
import { connection } from '@kit.NetworkKit'
import request from '@ohos.request'
import { deviceInfo } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { vibrator } from '@kit.SensorServiceKit'
import { util } from '@kit.ArkTS'
import { pasteboard } from '@kit.BasicServicesKit'
import { geoLocationManager } from '@kit.LocationKit'
import { notificationManager } from '@kit.NotificationKit'
import { window as arkWindow } from '@kit.ArkUI'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import { Logger } from '../common/Logger'

export type SourceType = 'rawfile' | 'file' | 'url'

export const SDK_VERSION: string = '1.0.0'

export const ERROR_CODES: Record<string, string> = {
  'OK': 'OK',
  'PERMISSION_DENIED': 'PERMISSION_DENIED',
  'USER_CANCELLED': 'USER_CANCELLED',
  'METHOD_NOT_FOUND': 'METHOD_NOT_FOUND',
  'TIMEOUT': 'TIMEOUT',
  'INTERNAL_ERROR': 'INTERNAL_ERROR',
  'INVALID_PARAMS': 'INVALID_PARAMS'
}

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
  sdkVersion: string
}

interface VersionData {
  sdk: string
  container: string
  api: number
}

interface HasMethodData {
  available: boolean
}

interface JSBridgeResponse {
  status: string
  code: string
  data?: object | null
  error?: string
  message?: string
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
  private sourceType: SourceType
  private navChangeCallback: ((style: number, title?: string) => void) | null = null
  private backPressCallback: (() => boolean) | null = null
  private backPressCallbackIds: string[] = []
  private navigateBackCallback: (() => void) | null = null

  constructor(controller: webview.WebviewController, context: common.UIAbilityContext, sourceType: SourceType = 'file') {
    this.controller = controller
    this.context = context
    this.sourceType = sourceType
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
    if (!this.checkPermission(method)) {
      this.callback(callId, { status: 'error', code: 'PERMISSION_DENIED', message: '方法在当前来源下不可用', error: 'permission denied' })
      return
    }
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
      case 'getVersion':
        this.handleGetVersion(callId)
        break
      case 'hasMethod':
        this.handleHasMethod(params, callId)
        break
      case 'setClipboard':
        this.handleSetClipboard(params, callId)
        break
      case 'getLocation':
        this.handleGetLocation(callId)
        break
      case 'scanQRCode':
        this.handleScanQRCode(callId)
        break
      case 'downloadFile':
        this.handleDownloadFile(params, callId)
        break
      case 'showNotification':
        this.handleShowNotification(params, callId)
        break
      case 'setScreenKeepAwake':
        this.handleSetScreenKeepAwake(params, callId)
        break
      default:
        this.callback(callId, { status: 'error', code: 'METHOD_NOT_FOUND', message: '未知方法: ' + method, error: 'unknown method' })
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

  private getPermissionMap(): Record<string, string> {
    if (this.sourceType === 'rawfile') {
      return {
        'getAppInfo': 'allow',
        'modifyNavStyle': 'allow',
        'systemShare': 'allow',
        'systemImagePick': 'allow',
        'vibrate': 'allow',
        'onBackPress': 'allow',
        'navigateBack': 'allow',
        'setClipboard': 'allow',
        'getLocation': 'allow',
        'scanQRCode': 'allow',
        'downloadFile': 'allow',
        'showNotification': 'allow',
        'setScreenKeepAwake': 'allow'
      }
    }
    return {
      'getAppInfo': 'allow',
      'modifyNavStyle': 'allow',
      'systemShare': 'deny',
      'systemImagePick': 'deny',
      'vibrate': 'deny',
      'onBackPress': 'allow',
      'navigateBack': 'allow',
      'setClipboard': 'allow',
      'getLocation': 'allow',
      'scanQRCode': 'deny',
      'downloadFile': 'allow',
      'showNotification': 'deny',
      'setScreenKeepAwake': 'allow'
    }
  }

  private checkPermission(method: string): boolean {
    const map: Record<string, string> = this.getPermissionMap()
    return map[method] !== 'deny'
  }

  private handleGetVersion(callId: string): void {
    const versionData: VersionData = { sdk: SDK_VERSION, container: SDK_VERSION, api: 1 }
    this.callback(callId, { status: 'ok', code: 'OK', data: versionData as object })
  }

  private handleHasMethod(paramsStr: string, callId: string): void {
    try {
      const params: Record<string, string> = JSON.parse(paramsStr) as Record<string, string>
      const name: string = params['name'] || ''
      const knownMethods: string[] = ['getAppInfo', 'modifyNavStyle', 'systemShare', 'systemImagePick',
        'vibrate', 'onBackPress', 'navigateBack', 'getVersion', 'hasMethod',
        'setClipboard', 'getLocation', 'scanQRCode', 'downloadFile', 'showNotification', 'setScreenKeepAwake']
      const resultData: HasMethodData = { available: knownMethods.indexOf(name) >= 0 }
      this.callback(callId, { status: 'ok', code: 'OK', data: resultData as object })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INVALID_PARAMS', message: '参数解析失败', error: 'JSON parse failed' })
    }
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
        deviceModel: deviceModel,
        sdkVersion: '1.0.0'
      }

      this.callback(callId, { status: 'ok', code: 'OK', data: data as object })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '获取应用信息失败', error: 'getAppInfo failed' })
    }
  }

  private handleModifyNavStyle(paramsStr: string, callId: string): void {
    try {
      const params: NavStyleParams = JSON.parse(paramsStr) as NavStyleParams
      if (this.navChangeCallback) {
        this.navChangeCallback(params.style, params.title)
      }
      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '修改导航样式失败', error: 'modifyNavStyle failed' })
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
            this.doShare(new systemShare.SharedData({
              utd: utd.UniformDataType.HYPERLINK,
              content: image,
              title: title
            }), callId)
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
        sharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: url,
          title: title
        })
      } else {
        sharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.PLAIN_TEXT,
          content: content,
          title: title
        })
      }

      this.doShare(sharedData, callId)
    } catch (e) {
      Logger.error('JSBridge', 'systemShare failed')
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '系统分享失败', error: 'systemShare failed' })
    }
  }

  private doShare(data: systemShare.SharedData, callId: string): void {
    try {
      const controller = new systemShare.ShareController(data)
      let sharedToTarget: boolean = false

      controller.on('shareCompleted', (result: systemShare.ShareOperationResult) => {
        sharedToTarget = true
        const platform: string = result.targetAbilityInfo.name
        const shareResult: ShareResult = { platform: platform.length > 0 ? platform : 'unknown' }
        this.callback(callId, { status: 'ok', code: 'OK', data: shareResult as object })
      })

      controller.on('dismiss', () => {
        if (!sharedToTarget) {
          this.callback(callId, { status: 'error', code: 'USER_CANCELLED', message: '用户取消分享', error: 'share cancelled by user' })
        }
      })

      controller.show(this.context, {})
    } catch (e) {
      Logger.error('JSBridge', 'doShare failed')
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '系统分享失败', error: 'systemShare failed' })
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
            this.callback(callId, { status: 'ok', code: 'OK', data: photoItems as object })
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
        this.callback(callId, { status: 'error', code: 'USER_CANCELLED', message: '用户取消选择', error: 'imagePick cancelled or failed' })
      })
    } catch (e) {
      Logger.error('JSBridge', 'systemImagePick failed')
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '图片选择失败', error: 'systemImagePick failed' })
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
          this.callback(callId, { status: 'ok', code: 'OK', data: null })
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
          this.callback(callId, { status: 'ok', code: 'OK', data: null })
        }
      }

      doVibrate()
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '振动失败', error: 'vibrate failed' })
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

      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '返回拦截注册失败', error: 'onBackPress failed' })
    }
  }

  private handleNavigateBack(callId: string): void {
    try {
      if (this.navigateBackCallback) {
        this.navigateBackCallback()
      }
      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '返回操作失败', error: 'navigateBack failed' })
    }
  }

  private async handleSetClipboard(paramsStr: string, callId: string): Promise<void> {
    try {
      const params = JSON.parse(paramsStr) as Record<string, string>
      const text: string = params.text || ''
      if (!text) {
        this.callback(callId, { status: 'error', code: 'INVALID_PARAMS', message: 'text required' })
        return
      }
      const pbData = pasteboard.createData('text/plain', text)
      await pasteboard.getSystemPasteboard().setData(pbData)
      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: 'clipboard failed' })
    }
  }

  // --- Runtime permission request helper ---
  private async requestPermission(permName: Permissions): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )
      const tokenId = bundleInfo.appInfo.accessTokenId
      const result = atManager.checkAccessTokenSync(tokenId, permName)
      if (result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true
      }
      const permList: Permissions[] = [permName]
      const reqResult: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        this.context as common.UIAbilityContext, permList)
      return reqResult.authResults[0] === 0
    } catch (e) {
      Logger.error('JSBridge', 'requestPermission failed: ' + JSON.stringify(e))
      return false
    }
  }

  private async handleGetLocation(callId: string): Promise<void> {
    try {
      const granted = await this.requestPermission('ohos.permission.APPROXIMATELY_LOCATION' as Permissions)
      if (!granted) {
        this.callback(callId, { status: 'error', code: 'PERMISSION_DENIED', message: '位置权限未授予，请在系统设置中开启' })
        return
      }
      geoLocationManager.getCurrentLocation().then((location) => {
        const locData: Record<string, Object> = { 'lat': location.latitude, 'lng': location.longitude, 'accuracy': location.accuracy }
        this.callback(callId, { status: 'ok', code: 'OK', data: locData as object })
      }).catch((err: Error) => {
        Logger.error('JSBridge', 'getCurrentLocation failed: ' + JSON.stringify(err))
        this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '获取位置失败' })
      })
    } catch (e) {
      Logger.error('JSBridge', 'handleGetLocation error: ' + JSON.stringify(e))
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '定位功能不可用' })
    }
  }

  private async handleScanQRCode(callId: string): Promise<void> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      }
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(this.context, options)
      const rawVal: string = result.originalValue || ''
      if (rawVal.length > 0 && rawVal !== 'undefined') {
        const qrData: Record<string, string> = { 'result': rawVal }
        this.callback(callId, { status: 'ok', code: 'OK', data: qrData as object })
      } else {
        this.callback(callId, { status: 'error', code: 'USER_CANCELLED', message: '扫码已取消' })
      }
    } catch (e) {
      Logger.warn('JSBridge', 'scanQRCode cancelled: ' + JSON.stringify(e))
      this.callback(callId, { status: 'error', code: 'USER_CANCELLED', message: '扫码已取消' })
    }
  }

  private async handleDownloadFile(paramsStr: string, callId: string): Promise<void> {
    try {
      const params = JSON.parse(paramsStr) as Record<string, string>
      const url: string = params.url || ''
      if (!url) {
        this.callback(callId, { status: 'error', code: 'INVALID_PARAMS', message: 'url required' })
        return
      }
      const filePath: string = params.path || (this.context.cacheDir + '/download_' + Date.now())
      Logger.debug('JSBridge', 'downloadFile: ' + url + ' → ' + filePath)
      const downloadTask = await request.downloadFile(this.context, { url: url, filePath: filePath })
      downloadTask.on('complete', () => {
        const dlResult: Record<string, string> = { 'savedPath': filePath }
        this.callback(callId, { status: 'ok', code: 'OK', data: dlResult as object })
      })
      downloadTask.on('fail', (err: number) => {
        Logger.error('JSBridge', 'downloadFile failed with code: ' + err)
        this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '下载失败 (code:' + err + ')，请检查 URL 是否可达' })
      })
    } catch (e) {
      Logger.error('JSBridge', 'handleDownloadFile error: ' + JSON.stringify(e))
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '下载发起失败' })
    }
  }

  private async handleShowNotification(paramsStr: string, callId: string): Promise<void> {
    try {
      // Request notification permission if not enabled
      const isEnabled: boolean = notificationManager.isNotificationEnabledSync()
      if (!isEnabled) {
        try {
          await notificationManager.requestEnableNotification(this.context as common.UIAbilityContext)
        } catch (e) {
          this.callback(callId, { status: 'error', code: 'PERMISSION_DENIED', message: '通知权限未授予，请在系统设置中开启' })
          return
        }
      }
      const params = JSON.parse(paramsStr) as Record<string, string>
      const title: string = params.title || 'WebLeaf'
      const body: string = params.body || ''
      const notificationRequest: notificationManager.NotificationRequest = {
        id: Date.now(),
        content: {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title: title, text: body }
        }
      } as notificationManager.NotificationRequest
      await notificationManager.publish(notificationRequest)
      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      Logger.error('JSBridge', 'handleShowNotification error: ' + JSON.stringify(e))
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: '发送通知失败，请在系统设置中开启通知权限' })
    }
  }

  private async handleSetScreenKeepAwake(paramsStr: string, callId: string): Promise<void> {
    try {
      const params = JSON.parse(paramsStr) as Record<string, Object>
      const enabled: boolean = params['enabled'] === true
      const mainWindow = await arkWindow.getLastWindow(this.context)
      await mainWindow.setKeepScreenOn(enabled)
      this.callback(callId, { status: 'ok', code: 'OK', data: null })
    } catch (e) {
      this.callback(callId, { status: 'error', code: 'INTERNAL_ERROR', message: 'setKeepAwake failed' })
    }
  }
}
