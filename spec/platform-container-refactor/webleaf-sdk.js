/**
 * WebLeaf SDK — WebBoard/浮叶 Platform Bridge
 * =============================================
 *
 * Promise-based wrapper over the native JSBridge injection layer.
 * Provides a developer-friendly API for H5 applications running
 * inside the WebLeaf (浮叶) WebBoard container on HarmonyOS.
 *
 * ## Quick Start
 *
 * ```js
 * // The SDK is auto-injected when loaded in WebLeaf. Just use it:
 * window.webLeaf.getAppInfo().then(info => {
 *   console.log('App:', info.appName, info.appVersion);
 * });
 *
 * // Or import this file for IDE type hints:
 * // <script src="webleaf-sdk.js"></script>
 * ```
 *
 * ## Backward Compatibility
 *
 * The existing `window.JSBridgeHandle.call(method, params, callId)` API
 * continues to work unchanged. This SDK adds a Promise wrapper on top.
 *
 * @version 1.0.0
 * @license MIT
 */

(function () {
  'use strict';

  // ──────────────────────────────────────────────
  // Guard: prevent double initialization
  // ──────────────────────────────────────────────
  if (typeof window.webLeaf !== 'undefined') {
    return;
  }

  // ──────────────────────────────────────────────
  // JSBridge callback layer (if not already present)
  // ──────────────────────────────────────────────
  if (!window.JSBridge) {
    /**
     * @typedef {Object} JSBridgeResponse
     * @property {string} status  - 'ok' or 'error'
     * @property {Object} [data]  - Response payload (present on success)
     * @property {string} [error] - Error message (present on failure)
     */

    /**
     * @namespace JSBridge
     * @description Internal callback-based bridge layer.
     * Communicates with the native layer via `window.JSBridgeHandle.call()`.
     */
    window.JSBridge = {
      /** @private */
      _callbacks: {},
      /** @private */
      _callId: 0,

      /**
       * Call a native method with a callback.
       * @param {string} method   - Method name (e.g., 'getAppInfo')
       * @param {Object} params   - Parameters object
       * @param {function(JSBridgeResponse): void} callback - Response callback
       * @returns {string} callId for tracking
       */
      call: function (method, params, callback) {
        var id = String(++this._callId);
        if (typeof callback === 'function') {
          this._callbacks[id] = callback;
        }
        params = params || {};
        var paramsStr = typeof params === 'string' ? params : JSON.stringify(params);
        window.JSBridgeHandle.call(method, paramsStr, id);
        return id;
      }
    };
  }

  // ──────────────────────────────────────────────
  // Callback dispatcher (if not already present)
  // ──────────────────────────────────────────────
  if (!window.__JSBridgeCallback__) {
    /**
     * Native callback receiver. Called by the native layer to deliver responses.
     * @param {string} id   - callId from the original request
     * @param {string} data - JSON-encoded response
     */
    window.__JSBridgeCallback__ = function (id, data) {
      var cb = window.JSBridge._callbacks[id];
      if (cb) {
        try {
          cb(typeof data === 'string' ? JSON.parse(data) : data);
        } catch (e) {
          cb({ status: 'error', error: 'parse error: ' + e.message });
        }
        delete window.JSBridge._callbacks[id];
      }
    };
  }

  // ──────────────────────────────────────────────
  // Public API — window.webLeaf
  // ──────────────────────────────────────────────

  /**
   * @namespace webLeaf
   * @description Promise-based SDK for WebBoard native capabilities.
   * Accessible via `window.webLeaf` after the 'WebLeafReady' event fires.
   */
  window.webLeaf = {
    /**
     * Internal method: calls a native method and returns a Promise.
     * @private
     * @param {string} method - Native method name
     * @param {Object} [params] - Method parameters
     * @returns {Promise<any>}
     */
    _call: function (method, params) {
      return new Promise(function (resolve, reject) {
        window.JSBridge.call(method, params || {}, function (response) {
          if (response && response.status === 'ok') {
            resolve(response.data || null);
          } else {
            reject(new Error((response && response.error) || 'Unknown error'));
          }
        });
      });
    },

    // ──── Methods ────

    /**
     * Get application and device information.
     *
     * @returns {Promise<GetAppInfoResult>}
     *
     * @example
     * window.webLeaf.getAppInfo().then(info => {
     *   console.log(info.appName, info.appVersion);
     * });
     */
    getAppInfo: function () {
      return window.webLeaf._call('getAppInfo');
    },

    /**
     * Modify the native navigation bar style.
     *
     * @param {number} style       - Bar style: 0=hide, 1=stack mode
     * @param {string} [title]     - Optional custom title
     * @returns {Promise<void>}
     *
     * @example
     * window.webLeaf.modifyNavStyle(0).then(() => {
     *   // Navigation bar is now hidden
     * });
     */
    modifyNavStyle: function (style, title) {
      return window.webLeaf._call('modifyNavStyle', { style: style, title: title });
    },

    /**
     * Share content via the system share sheet.
     *
     * @param {Object}   params            - Share parameters
     * @param {string}   [params.title]    - Share title
     * @param {string}   [params.content]  - Text content to share
     * @param {string}   [params.image]    - Image URL (http/https or local file)
     * @param {string}   [params.url]      - URL to share
     * @param {string}   [params.type]     - Content type hint
     * @returns {Promise<ShareResult>}
     *
     * @example
     * window.webLeaf.systemShare({
     *   title: '分享标题',
     *   content: '分享内容',
     *   url: 'https://example.com'
     * }).then(result => {
     *   console.log('Shared to:', result.platform);
     * });
     */
    systemShare: function (params) {
      return window.webLeaf._call('systemShare', params || {});
    },

    /**
     * Pick images from the system photo gallery.
     *
     * @param {Object}   params           - Image pick parameters
     * @param {string}   [params.type]    - MIME type filter
     * @param {number}   [params.count]   - Maximum number of images (default: 9)
     * @param {number}   [params.limit]   - Size limit in bytes
     * @returns {Promise<PhotoItem[]>}
     *
     * @example
     * window.webLeaf.systemImagePick({ count: 3 }).then(photos => {
     *   photos.forEach(p => console.log(p.name, p.path));
     * });
     */
    systemImagePick: function (params) {
      return window.webLeaf._call('systemImagePick', params || {});
    },

    /**
     * Trigger device vibration.
     *
     * @param {Object}   params             - Vibration parameters
     * @param {string}   [params.type]      - Vibration type
     * @param {number}   [params.duration]  - Duration per vibration (ms, max 1000)
     * @param {number}   [params.count]     - Number of repetitions (default: 1)
     * @param {number}   [params.interval]  - Interval between repetitions (ms)
     * @returns {Promise<void>}
     *
     * @example
     * window.webLeaf.vibrate({ duration: 200, count: 2 }).then(() => {
     *   console.log('Vibration complete');
     * });
     */
    vibrate: function (params) {
      return window.webLeaf._call('vibrate', params || {});
    },

    /**
     * Register a back press handler. When the user presses the system back
     * button, the native layer will ask the H5 page for confirmation.
     * Call this method during initialization and use the native back press
     * callback flow to intercept.
     *
     * @returns {Promise<void>}
     *
     * @example
     * window.webLeaf.onBackPress().then(() => {
     *   console.log('Back press handler registered');
     * });
     */
    onBackPress: function () {
      return window.webLeaf._call('onBackPress', { callbackId: 'sdk_' + Date.now() });
    },

    /**
     * Navigate back to the previous page in the app.
     * Equivalent to the user tapping the system back button.
     *
     * @returns {Promise<void>}
     *
     * @example
     * window.webLeaf.navigateBack().then(() => {
     *   console.log('Navigated back');
     * });
     */
    navigateBack: function () {
      return window.webLeaf._call('navigateBack');
    },

    /**
     * Generic method call. Use for any native method not covered by
     * the typed methods above.
     *
     * @param {string} method   - Native method name
     * @param {Object} [params] - Method parameters
     * @returns {Promise<any>}
     *
     * @example
     * window.webLeaf.call('customMethod', { foo: 'bar' }).then(result => {
     *   console.log(result);
     * });
     */
    call: function (method, params) {
      return window.webLeaf._call(method, params || {});
    }
  };

  // ──────────────────────────────────────────────
  // Ready Event
  // ──────────────────────────────────────────────

  /**
   * @event WebLeafReady
   * @description Fired on `window` when the webLeaf SDK is fully initialized.
   * H5 applications can use this to defer initialization until the SDK is ready.
   *
   * @example
   * window.addEventListener('WebLeafReady', () => {
   *   console.log('WebLeaf SDK ready');
   *   window.webLeaf.getAppInfo().then(console.log);
   * });
   */
  try {
    window.dispatchEvent(new CustomEvent('WebLeafReady', {
      detail: { version: '1.0.0' }
    }));
  } catch (e) {
    // Ignore if CustomEvent is not supported
  }

  // Log initialization
  try {
    console.log('[WebLeaf] SDK initialized, window.webLeaf ready');
  } catch (e) {
    // Silently fail in environments without console
  }

})();
