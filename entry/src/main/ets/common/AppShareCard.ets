export class ShareCardParams {
  appName: string = ''
  appDescription: string = ''

  constructor(name: string, desc: string) {
    this.appName = name
    this.appDescription = desc
  }
}

@Builder
export function AppShareCardBuilder(params: ShareCardParams) {
  AppShareCard({ appName: params.appName, appDescription: params.appDescription })
}

@Component
export struct AppShareCard {
  @Prop appName: string = ''
  @Prop appDescription: string = ''

  build() {
    Column() {
      // 顶部品牌区
      Column({ space: 8 }) {
        // 叶片 Icon
        Shape() {
          Path()
            .commands('M 256 76 C 311 86 396 176 396 276 C 396 361 331 421 256 441 C 181 421 116 361 116 276 C 116 176 201 86 256 76 Z')
            .fill('#6366F1')
            .fillOpacity(0.95)
        }
        .width(48)
        .height(48)

        Text('浮叶')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')

        Text('WebLeaf')
          .fontSize(11)
          .fontColor('#94A3B8')
          .fontWeight(FontWeight.Lighter)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 32, bottom: 24 })

      // 分隔线
      Divider()
        .width('60%')
        .color('#E2E8F0')

      // 应用信息区
      Column({ space: 6 }) {
        Text(this.appName)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .textAlign(TextAlign.Center)
          .width('100%')

        if (this.appDescription.length > 0) {
          Text(this.appDescription)
            .fontSize(14)
            .fontColor('#64748B')
            .textAlign(TextAlign.Center)
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .padding({ top: 20, bottom: 20 })
      .alignItems(HorizontalAlign.Center)

      // 底部品牌
      Row({ space: 4 }) {
        Text('—')
          .fontSize(12)
          .fontColor('#CBD5E1')
        Text('来自 浮叶 WebLeaf')
          .fontSize(11)
          .fontColor('#CBD5E1')
        Text('—')
          .fontSize(12)
          .fontColor('#CBD5E1')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 24 })
    }
    .width(360)
    .padding({ left: 24, right: 24 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
    .shadow({
      radius: 8,
      color: '#1E000000',
      offsetX: 0,
      offsetY: 4
    })
  }
}
