# webleaf-sdk

WebBoard (浮叶) HarmonyOS JSBridge SDK — TypeScript type definitions for H5 app developers.

## Installation

```bash
npm install webleaf-sdk
# or
yarn add webleaf-sdk
```

## Usage

The SDK is auto-injected into WebView when your H5 page runs inside WebBoard.
This package provides TypeScript type definitions only — no runtime code needed.

### TypeScript project

```typescript
import { WebLeafSDK, waitForWebLeaf } from 'webleaf-sdk'

// Wait for SDK to be ready (auto-injected by container)
await waitForWebLeaf()

// Call native methods with full type safety
const appInfo = await window.webLeaf.getAppInfo()
console.log(appInfo.appName, appInfo.sdkVersion)

const version = await window.webLeaf.getVersion()
console.log('SDK:', version.sdk, 'API:', version.api)
```

### Vanilla JS project

```html
<script>
// SDK is auto-injected as window.webLeaf
// No import needed — just use the global object

window.WebLeafReady = function() {
  window.webLeaf.getAppInfo().then(info => {
    console.log('App:', info.appName)
  })
}
</script>
```

## API Reference

See [src/types.ts](./src/types.ts) for complete type definitions.

## Development

```bash
git clone ...
cd webleaf-sdk
npm install
npm run build
```

## License

MIT
