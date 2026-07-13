/**
 * Container HSP Facade — re-exports all public APIs for consumption via `import { ... } from 'container'`.
 *
 * This file is referenced by module.json5 `srcEntry: "./ets/Index.ets"`.
 * All exports use paths relative to this file's location (container/src/main/ets/).
 */

// --- ArkUI Components ---
export { WebContainer } from './webview/WebContainer'
export { WebContainerController } from './webview/WebContainerController'

// --- Database ---
export { DatabaseManager } from './database/DatabaseManager'

// --- Data Models ---
export { WebAppItem, WebAppRecord } from './model/WebAppItem'
export { AppDataSource } from './model/AppDataSource'

// --- UI Utilities ---
export { Toast } from './ui/ToastUtil'
export { Loading } from './ui/LoadingUtil'
export { Dialog } from './ui/DialogUtil'

// --- Common Utilities ---
export { Logger } from './common/Logger'
export { eventEmitter, EventArg } from './common/EventEmitter'
export { WebBoardConstants, ColorMode, LayoutMode, LogoType, SourceType } from './common/Constants'

// --- Services ---
export { WebPreloader } from './util/WebPreloader'
export { FileManager } from './util/FileManager'
export { WorkDirectory } from './util/WorkDirectory'

// --- JSBridge ---
export { JSBridge, JsProxyObject } from './webview/JSBridge'

// --- JSBridge SDK ---
export { WEBLEAF_SDK_SCRIPT } from './webview/webleaf-sdk'
