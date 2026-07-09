import { LogoType } from './Constants'

export class ShareCardParams {
  appName: string = ''
  appDescription: string = ''
  logoType: string = LogoType.INITIAL
  logoUri: string = ''

  constructor(name: string, desc: string, logoType: string = LogoType.INITIAL, logoUri: string = '') {
    this.appName = name
    this.appDescription = desc
    this.logoType = logoType
    this.logoUri = logoUri
  }
}

@Builder
export function AppShareCardBuilder(params: ShareCardParams) {
  AppShareCard({ appName: params.appName, appDescription: params.appDescription, logoType: params.logoType, logoUri: params.logoUri })
}

@Component
export struct AppShareCard {
  @Prop appName: string = ''
  @Prop appDescription: string = ''
  @Prop logoType: string = LogoType.INITIAL
  @Prop logoUri: string = ''

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
          .fontColor('#6366F1')
          .margin({ left: 6 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

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
            colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
          })
          .alignContent(Alignment.Center)
        }
      }
      .padding({ top: 28, bottom: 20 })

      // ── 应用名称 ──
      Text(this.appName)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .textAlign(TextAlign.Center)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // ── 应用描述 ──
      if (this.appDescription.length > 0) {
        Text(this.appDescription)
          .fontSize(13)
          .fontColor('#64748B')
          .textAlign(TextAlign.Center)
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8, bottom: 28 })
      } else {
        Column().margin({ bottom: 28 })
      }

      // ── 分隔装饰 ──
      Row() {
        Divider()
          .width('30%')
          .color('#E2E8F0')
        Text('✦')
          .fontSize(8)
          .fontColor('#CBD5E1')
          .margin({ left: 10, right: 10 })
        Divider()
          .width('30%')
          .color('#E2E8F0')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)

      // ── 底部品牌 ──
      Text('来自 浮叶 WebLeaf')
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ top: 16, bottom: 4 })
    }
    .width(360)
    .padding({ left: 32, right: 32, top: 24, bottom: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
  }
}
