export interface GetAppInfoResult {
  appName: string
  appVersion: string
  appVersionName: string
  internet: string
  deviceBrand: string
  deviceModel: string
  sdkVersion: string
}

export interface ShareParams {
  title?: string
  content?: string
  image?: string
  url?: string
  type?: string
}

export interface ShareResult {
  platform: string
}

export interface PhotoItem {
  path: string
  name: string
  size: number
  base64: string
}

export interface ImagePickParams {
  type?: string
  count?: number
  limit?: number
}

export interface VibrateParams {
  type?: string
  duration?: number
  interval?: number
  count?: number
}

export interface VersionInfo {
  sdk: string
  container: string
  api: number
}

export interface HasMethodResult {
  available: boolean
}

export interface WebLeafSDK {
  /** Get application and device information */
  getAppInfo(): Promise<GetAppInfoResult>

  /** Modify navigation bar style (0=hide, 1=stack) */
  modifyNavStyle(style: number, title?: string): Promise<void>

  /** Share content via system share sheet */
  systemShare(params: ShareParams): Promise<ShareResult | null>

  /** Pick images from system gallery */
  systemImagePick(params: ImagePickParams): Promise<PhotoItem[]>

  /** Trigger device vibration */
  vibrate(params: VibrateParams): Promise<void>

  /** Register back press handler */
  onBackPress(): Promise<void>

  /** Navigate back to previous page */
  navigateBack(): Promise<void>

  /** Get SDK and container version info */
  getVersion(): Promise<VersionInfo>

  /** Check if a specific method is available */
  hasMethod(name: string): Promise<HasMethodResult>

  /** Generic method call */
  call(method: string, params?: Record<string, any>): Promise<any>
}

/** JSBridge callback response (used internally) */
export interface JSBridgeResponse {
  status: 'ok' | 'error'
  code: string
  data?: any
  error?: string
  message?: string
}

/** Internal JSBridge object */
export interface JSBridgeObject {
  _callbacks: Record<string, Function>
  _callId: number
  MAX_CALLBACKS: number
  call(method: string, params: any, callback: (res: JSBridgeResponse) => void): string
}
