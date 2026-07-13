/**
 * WebLeaf SDK — Promise-based H5 Native Bridge for HarmonyOS WebBoard (浮叶)
 *
 * Auto-injected by WebContainer or loaded directly via <script> tag.
 * Establishes window.webLeaf with Promise-based API over JSBridgeHandle.
 *
 * Backward compatible — existing window.JSBridge / window.JSBridgeHandle
 * code continues to work unchanged.
 *
 * v1.0.0 — getVersion, hasMethod, timeout, callback cap, iframe security
 *
 * Usage:
 *   window.webLeaf.getAppInfo().then(data => { ... })
 *   window.webLeaf.vibrate({ duration: 200, count: 1 }).then(() => { ... })
 *   window.webLeaf.getVersion().then(v => console.log(v))
 */

(function() {
  'use strict';
  if (window.webLeaf) return;

  // Initialize JSBridge callback layer if not already present
  if (!window.JSBridge) {
    window.JSBridge = {
      _callbacks: {},
      _callId: 0,
      MAX_CALLBACKS: 500,
      call: function(method, params, callback) {
        var id = String(++this._callId);
        if (typeof callback === 'function') {
          // Callback leak protection: cap at MAX_CALLBACKS, evict oldest 100
          var keys = Object.keys(this._callbacks);
          if (keys.length >= this.MAX_CALLBACKS) {
            var toRemove = keys.slice(0, 100);
            for (var i = 0; i < toRemove.length; i++) {
              delete this._callbacks[toRemove[i]];
            }
          }
          this._callbacks[id] = callback;
        }
        params = params || {};
        var paramsStr = typeof params === 'string' ? params : JSON.stringify(params);
        window.JSBridgeHandle.call(method, paramsStr, id);
        return id;
      }
    };
  }

  // Ensure __JSBridgeCallback__ exists for native callback delivery
  if (!window.__JSBridgeCallback__) {
    window.__JSBridgeCallback__ = function(id, data) {
      var cb = window.JSBridge._callbacks[id];
      if (cb) {
        cb(typeof data === 'string' ? JSON.parse(data) : data);
        delete window.JSBridge._callbacks[id];
      }
    };
  }

  // Promise-based webLeaf SDK
  window.webLeaf = {
    _call: function(method, params) {
      var TIMEOUT_MS = 30000;
      return new Promise(function(resolve, reject) {
        var timeoutId = setTimeout(function() {
          var err = new Error('调用超时');
          err.code = 'TIMEOUT';
          reject(err);
        }, TIMEOUT_MS);
        window.JSBridge.call(method, params || {}, function(response) {
          clearTimeout(timeoutId);
          if (response && response.status === 'ok') {
            resolve(response.data || null);
          } else {
            var errCode = (response && response.code) || 'UNKNOWN';
            var errMsg = (response && response.message) || (response && response.error) || '未知错误';
            var err = new Error(errMsg);
            err.code = errCode;
            reject(err);
          }
        });
      });
    },

    /** Get SDK/container version info */
    getVersion: function() {
      return window.webLeaf._call('getVersion');
    },

    /** Check if a method is available in current runtime */
    hasMethod: function(name) {
      return window.webLeaf._call('hasMethod', { name: name });
    },

    /** Get application and device information (response includes sdkVersion) */
    getAppInfo: function() {
      return window.webLeaf._call('getAppInfo');
    },

    /** Modify navigation bar style (0=hide, 1=stack) */
    modifyNavStyle: function(style, title) {
      return window.webLeaf._call('modifyNavStyle', { style: style, title: title });
    },

    /** Share content via system share sheet */
    systemShare: function(params) {
      return window.webLeaf._call('systemShare', params || {});
    },

    /** Pick images from system gallery */
    systemImagePick: function(params) {
      return window.webLeaf._call('systemImagePick', params || {});
    },

    /** Trigger device vibration */
    vibrate: function(params) {
      return window.webLeaf._call('vibrate', params || {});
    },

    /** Register back press handler */
    onBackPress: function() {
      return window.webLeaf._call('onBackPress', { callbackId: 'sdk_' + Date.now() });
    },

    /** Navigate back to previous page */
    navigateBack: function() {
      return window.webLeaf._call('navigateBack');
    },

    /** Generic method call */
    call: function(method, params) {
      return window.webLeaf._call(method, params || {});
    }
  };

  // Iframe security: block JSBridge access in iframe context
  try {
    if (window !== window.top) {
      delete window.JSBridgeHandle;
      delete window.JSBridge;
      delete window.webLeaf;
      delete window.__JSBridgeCallback__;
    }
  } catch(e) {
    // Cross-origin iframe: silently ignore (already blocked by same-origin policy)
  }

  // Dispatch ready event for H5 readiness detection
  try {
    window.dispatchEvent(new CustomEvent('WebLeafReady', { detail: { version: '1.0.0' } }));
  } catch(e) {
    // Silently ignore
  }

  // Log SDK initialization
  try {
    console.log('[WebLeaf] SDK initialized, window.webLeaf ready');
  } catch(e) {
    // Silently ignore
  }
})();
