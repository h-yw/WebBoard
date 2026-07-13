/**
 * WebLeaf SDK — Auto-injected JavaScript for `window.webLeaf` Promise API.
 *
 * This script is injected via `WebContainer.ets`'s `onPageBegin` callback
 * using `this.controller.runJavaScript(WEBLEAF_SDK_SCRIPT)`.
 *
 * It establishes:
 * 1. `window.JSBridge` — internal callback-based bridge (backward compatible)
 * 2. `window.webLeaf` — Promise-based developer-facing API (dual-track)
 * 3. Dispatch of `WebLeafReady` event on window for H5 readiness detection
 *
 * Backward compatible — existing `window.JSBridgeHandle.call()` usage
 * continues to work unchanged.
 */
export const WEBLEAF_SDK_SCRIPT: string =
  '(function() {' +
  'if (window.webLeaf) return;' +
  '' +
  '// Initialize JSBridge callback layer if not already present' +
  'if (!window.JSBridge) {' +
  '  window.JSBridge = {' +
  '    _callbacks: {},' +
  '    _callId: 0,' +
  '    call: function(method, params, callback) {' +
  '      var id = String(++this._callId);' +
  '      if (typeof callback === "function") {' +
  '        this._callbacks[id] = callback;' +
  '      }' +
  '      params = params || {};' +
  '      var paramsStr = typeof params === "string" ? params : JSON.stringify(params);' +
  '      window.JSBridgeHandle.call(method, paramsStr, id);' +
  '      return id;' +
  '    }' +
  '  };' +
  '}' +
  '' +
  '// Ensure __JSBridgeCallback__ exists for native callback delivery' +
  'if (!window.__JSBridgeCallback__) {' +
  '  window.__JSBridgeCallback__ = function(id, data) {' +
  '    var cb = window.JSBridge._callbacks[id];' +
  '    if (cb) {' +
  '      cb(typeof data === "string" ? JSON.parse(data) : data);' +
  '      delete window.JSBridge._callbacks[id];' +
  '    }' +
  '  };' +
  '}' +
  '' +
  '// Promise-based webLeaf SDK' +
  'window.webLeaf = {' +
  '  _call: function(method, params) {' +
  '    var self = this;' +
  '    return new Promise(function(resolve, reject) {' +
  '      window.JSBridge.call(method, params || {}, function(response) {' +
  '        if (response && response.status === "ok") {' +
  '          resolve(response.data || null);' +
  '        } else {' +
  '          reject(new Error((response && response.error) || "Unknown error"));' +
  '        }' +
  '      });' +
  '    });' +
  '  },' +
  '' +
  '  /** Get application and device information */' +
  '  getAppInfo: function() {' +
  '    return window.webLeaf._call("getAppInfo");' +
  '  },' +
  '' +
  '  /** Modify navigation bar style (0=hide, 1=stack) */' +
  '  modifyNavStyle: function(style, title) {' +
  '    return window.webLeaf._call("modifyNavStyle", { style: style, title: title });' +
  '  },' +
  '' +
  '  /** Share content via system share sheet */' +
  '  systemShare: function(params) {' +
  '    return window.webLeaf._call("systemShare", params || {});' +
  '  },' +
  '' +
  '  /** Pick images from system gallery */' +
  '  systemImagePick: function(params) {' +
  '    return window.webLeaf._call("systemImagePick", params || {});' +
  '  },' +
  '' +
  '  /** Trigger device vibration */' +
  '  vibrate: function(params) {' +
  '    return window.webLeaf._call("vibrate", params || {});' +
  '  },' +
  '' +
  '  /** Register back press handler */' +
  '  onBackPress: function() {' +
  '    return window.webLeaf._call("onBackPress", { callbackId: "sdk_" + Date.now() });' +
  '  },' +
  '' +
  '  /** Navigate back to previous page */' +
  '  navigateBack: function() {' +
  '    return window.webLeaf._call("navigateBack");' +
  '  },' +
  '' +
  '  /** Generic method call */' +
  '  call: function(method, params) {' +
  '    return window.webLeaf._call(method, params || {});' +
  '  }' +
  '};' +
  '' +
  '// Dispatch ready event for H5 readiness detection' +
  'try {' +
  '  window.dispatchEvent(new CustomEvent("WebLeafReady", { detail: { version: "1.0.0" } }));' +
  '} catch(e) {}' +
  '' +
  '// Log SDK initialization' +
  'try { console.log("[WebLeaf] SDK initialized, window.webLeaf ready"); } catch(e) {}' +
  '})();'
