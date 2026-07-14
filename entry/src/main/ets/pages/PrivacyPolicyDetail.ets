import { router } from '@kit.ArkUI'

@Entry
@Component
struct PrivacyPolicyDetail {
  @State needShowDialog: boolean = false

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined
    if (params && params['needShowDialog'] === true) {
      this.needShowDialog = true
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Button() {
          Text('返回').fontSize(15).fontColor($r('app.color.app_primary'))
        }
        .height(40)
        .borderRadius(8)
        .backgroundColor($r('app.color.app_card_bg'))
        .onClick(() => {
          if (this.needShowDialog) {
            router.replaceUrl({ url: 'pages/SplashPage' })
          } else {
            router.back()
          }
        })

        Text('隐私政策').fontSize(18).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)

        Row().width(60) // spacer
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.app_card_bg'))

      // Content
      Scroll() {
        Column({ space: 16 }) {
          Text('隐私政策').fontSize(22).fontWeight(FontWeight.Bold).width('100%')
          Text('最后更新：2026年7月').fontSize(13).fontColor($r('app.color.app_text_muted')).width('100%')

          Text('1. 信息收集').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('本应用仅在您明确授权的情况下收集以下信息：位置信息（用于 JSBridge getLocation 接口）、通知权限（用于 JSBridge showNotification 接口）。我们不会在未获授权的情况下收集任何个人信息。')

          Text('2. 信息使用').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('收集的信息仅用于实现对应的原生功能，不会上传至任何服务器。所有数据处理均在本地设备端完成。')

          Text('3. 权限说明').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('本应用使用以下系统权限：INTERNET（WebView 网络访问）、VIBRATE（震动反馈）、FILE_ACCESS_PERSIST（文件持久化）、APPROXIMATELY_LOCATION（模糊定位）。所有权限仅在您主动触发相关功能时使用。')

          Text('4. 第三方服务').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('本应用不集成任何第三方统计分析或广告 SDK。所有 HTML 内容由您自行导入或选择，应用本身不追踪用户行为。')

          Text('5. 联系我们').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('如您对本隐私政策有任何疑问，请联系开发者。')
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .layoutWeight(1)

      // Bottom button
      if (this.needShowDialog) {
        Button('返回并同意')
          .height(48).borderRadius(8).fontSize(16).fontColor(Color.White)
          .backgroundColor($r('app.color.app_primary'))
          .width('90%').margin({ bottom: 20 })
          .onClick(() => {
            router.replaceUrl({ url: 'pages/SplashPage' })
          })
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}
