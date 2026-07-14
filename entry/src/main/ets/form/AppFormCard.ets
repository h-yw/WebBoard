@Entry
@Component
struct AppFormCard {
  @State appName: string = '浮叶'
  @State appCount: string = '0'

  build() {
    Stack() {
      // Main content — tap to open target app
      Column({ space: 8 }) {
        Row() {
          Text('浮叶')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('WebLeaf')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .opacity(0.7)
            .margin({ left: 6 })
        }
        .width('100%')

        Divider()
          .color('#FFFFFF')
          .opacity(0.2)
          .height(1)
          .margin({ top: 4, bottom: 4 })

        Row() {
          Text(this.appCount)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('个应用')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .opacity(0.7)
            .margin({ left: 6 })
        }
        .width('100%')

        Text('点击打开')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .opacity(0.5)
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .linearGradient({
        angle: 135,
        colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
      })
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: {
            'fromCard': 'true',
            'cardAction': 'openApp'
          }
        })
      })

      // Settings gear icon in top-right corner
      Text('⚙')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .opacity(0.7)
        .position({ x: '82%', y: 4 })
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: {
              'fromCard': 'true',
              'cardAction': 'config'
            }
          })
        })
    }
    .width('100%')
    .height('100%')
  }
}
