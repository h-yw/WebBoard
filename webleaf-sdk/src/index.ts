import type {
  GetAppInfoResult,
  ShareParams,
  ShareResult,
  PhotoItem,
  ImagePickParams,
  VibrateParams,
  VersionInfo,
  HasMethodResult,
  WebLeafSDK,
  JSBridgeObject,
  JSBridgeResponse
} from './types'

export type {
  GetAppInfoResult,
  ShareParams,
  ShareResult,
  PhotoItem,
  ImagePickParams,
  VibrateParams,
  VersionInfo,
  HasMethodResult,
  WebLeafSDK,
  JSBridgeObject,
  JSBridgeResponse
} from './types'

/**
 * Check if the WebLeaf SDK is available in the current environment.
 * Returns true if window.webLeaf is defined.
 */
export function isWebLeafAvailable(): boolean {
  return typeof window !== 'undefined' &&
    typeof (window as any).webLeaf !== 'undefined' &&
    typeof (window as any).webLeaf.getAppInfo === 'function'
}

/**
 * Wait for the WebLeaf SDK to become ready.
 * Resolves when window.webLeaf is available or rejects after timeout.
 */
export function waitForWebLeaf(timeoutMs: number = 10000): Promise<void> {
  return new Promise((resolve, reject) => {
    if (isWebLeafAvailable()) {
      resolve()
      return
    }

    const timeout = setTimeout(() => {
      window.removeEventListener('WebLeafReady', onReady)
      reject(new Error('WebLeaf SDK not available after ' + timeoutMs + 'ms'))
    }, timeoutMs)

    const onReady = () => {
      clearTimeout(timeout)
      resolve()
    }

    window.addEventListener('WebLeafReady', onReady)

    // Also poll as fallback
    let attempts = 0
    const poll = setInterval(() => {
      attempts++
      if (isWebLeafAvailable()) {
        clearInterval(poll)
        clearTimeout(timeout)
        window.removeEventListener('WebLeafReady', onReady)
        resolve()
      } else if (attempts * 200 > timeoutMs) {
        clearInterval(poll)
        // Timeout handled by setTimeout
      }
    }, 200)
  })
}

// Extend the global Window interface
declare global {
  interface Window {
    webLeaf: WebLeafSDK
    JSBridge: JSBridgeObject
    JSBridgeHandle: {
      call(method: string, params: string, callId: string): void
    }
    __JSBridgeCallback__: (id: string, data: string) => void
    __webLeafDebug?: boolean
  }
}
