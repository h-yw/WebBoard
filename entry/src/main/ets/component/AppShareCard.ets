import { LogoType } from '../common/Constants'
import { JSON } from '@kit.ArkTS'

interface QrData {
  t: string
  d: string
  u: string
}

export class ShareCardParams {
  appName: string = ''
  appDescription: string = ''
  logoType: string = LogoType.INITIAL
  logoUri: string = ''
  entryHtml: string = ''

  constructor(name: string, desc: string, logoType: string = LogoType.INITIAL, logoUri: string = '', entryHtml: string = '') {
    this.appName = name
    this.appDescription = desc
    this.logoType = logoType
    this.logoUri = logoUri
    this.entryHtml = entryHtml
  }
}

@Builder
export function AppShareCardBuilder(params: ShareCardParams) {
  AppShareCard({ appName: params.appName, appDescription: params.appDescription, logoType: params.logoType, logoUri: params.logoUri, entryHtml: params.entryHtml })
}

@Component
export struct AppShareCard {
  @Prop appName: string = ''
  @Prop appDescription: string = ''
  @Prop logoType: string = LogoType.INITIAL
  @Prop logoUri: string = ''
  @Prop entryHtml: string = ''

  qrContent(): string {
    const qrData: QrData = {
      t: this.appName,
      d: this.appDescription,
      u: this.entryHtml
    }
    return JSON.stringify(qrData)
  }

  getInitial(): string {
    if (this.appName.length > 0) {
      return this.appName.charAt(0).toUpperCase()
    }
    return 'W'
  }

  build() {
    Column() {
      // ── 顶部品牌 ──
      Row() {
        Stack() {
          Image($r('app.media.background'))
            .width(22)
            .height(22)
            .borderRadius(5)
          Image($r('app.media.foreground'))
            .width(18)
            .height(18)
        }
        .width(22)
        .height(22)
        Text('浮叶')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_share_card_brand'))
          .margin({ left: 6 })
        Blank()
        // ── 二维码 ──
        if (this.entryHtml.length > 0) {
          Column({ space: 4 }) {
            QRCode(this.qrContent())
              .width(25)
              .height(25)
              .color($r('app.color.app_qr_code'))
              .borderRadius(16)
              .contentOpacity(0.5)

            Text('扫码添加')
              .fontSize(9)
              .fontColor($r('app.color.app_qr_label'))
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 16, bottom: 12 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)

      // ── 应用图标 ──
      Column() {
        if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
          Image('file://' + this.logoUri)
            .width(56)
            .height(56)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
        } else {
          Stack() {
            Text(this.getInitial())
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(56)
          .height(56)
          .borderRadius(14)
                  .linearGradient({
                    angle: 135,
                    colors: [[$r('app.color.app_gradient_start'), 0.0], [$r('app.color.app_gradient_end'), 1.0]]
                  })
          .alignContent(Alignment.Center)
        }
      }
      .padding({ top: 28, bottom: 20 })

      // ── 应用名称 ──
      Text(this.appName)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.app_share_card_text'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // ── 应用描述 ──
      if (this.appDescription.length > 0) {
        Text(this.appDescription)
          .fontSize(13)
          .fontColor($r('app.color.app_share_card_desc'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8, bottom: 28 })
      } else {
        Column().margin({ bottom: 28 })
      }

      // ── 底部品牌 ──
      Row(){
        Divider()
          .layoutWeight(1)
          .strokeWidth(1)
          .backgroundColor($r('app.color.app_share_card_footer'))
        Text('来自 浮叶 WebLeaf')
          .fontSize(11)
          .fontColor($r('app.color.app_share_card_footer'))
          .margin({ top:  4 , bottom: 4 })
          .padding({left:4,right:4})
        Divider()
          .layoutWeight(1)
          .strokeWidth(1)
          .backgroundColor($r('app.color.app_share_card_footer'))
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .width(360)
    .padding({ left: 32, right: 32, top: 24, bottom: 20 })
    .backgroundColor($r('app.color.app_share_card_bg'))
    .alignItems(HorizontalAlign.Center)
  }
}
