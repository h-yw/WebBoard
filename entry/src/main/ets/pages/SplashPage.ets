import { router } from '@kit.ArkUI'

@Entry
@Component
struct SplashPage {
  @State sealOpacity: number = 0
  @State sealScale: number = 0.3
  @State titleOpacity: number = 0
  @State titleTranslateY: number = 30
  @State subtitleOpacity: number = 0
  @State progress: number = 0
  @State progressOpacity: number = 0

  private timerId: number = -1
  private progressTimerId: number = -1
  private jumped: boolean = false

  aboutToAppear(): void {
    // ① 叶片弹入（200ms 延迟，600ms 弹性动画）
    this.getUIContext().animateTo({
      duration: 600,
      curve: Curve.EaseOut,
      delay: 200
    }, () => {
      this.sealOpacity = 1
      this.sealScale = 1
    })

    // ② 品牌名上浮淡入（500ms 延迟）
    this.getUIContext().animateTo({
      duration: 500,
      curve: Curve.EaseOut,
      delay: 500
    }, () => {
      this.titleOpacity = 1
      this.titleTranslateY = 0
    })

    // ③ 副标题 + 进度条淡入（900ms 延迟）
    this.getUIContext().animateTo({
      duration: 400,
      curve: Curve.EaseIn,
      delay: 900
    }, () => {
      this.subtitleOpacity = 1
      this.progressOpacity = 1
    })

    // ④ 进度条匀速推进（50ms 间隔）
    let p = 0
    this.progressTimerId = setInterval(() => {
      p += 2
      if (p >= 100) {
        p = 100
        clearInterval(this.progressTimerId)
        this.progressTimerId = -1
      }
      this.progress = p
    }, 50)

    // ⑤ 2.5s 后自动跳转
    this.timerId = setTimeout(() => {
      this.goHome()
    }, 2500)
  }

  aboutToDisappear(): void {
    // 清理定时器，防止内存泄漏
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }
    if (this.progressTimerId !== -1) {
      clearInterval(this.progressTimerId)
      this.progressTimerId = -1
    }
  }

  private goHome(): void {
    if (this.jumped) {
      return
    }
    this.jumped = true
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }
    if (this.progressTimerId !== -1) {
      clearInterval(this.progressTimerId)
      this.progressTimerId = -1
    }
    try {
      router.replaceUrl({ url: 'pages/Index' })
    } catch (e) {
      console.error('SplashPage', 'navigate failed: ' + JSON.stringify(e))
    }
  }

  build() {
    Stack() {
      // 品牌背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.app_primary'))

      // 中间内容区
      Column({ space: 24 }) {
        // 应用图标（白色叶片 foreground.png）
        Image($r('app.media.foreground'))
          .width(120)
          .height(120)
          .borderRadius(28)
          .opacity(this.sealOpacity)
          .scale({ x: this.sealScale, y: this.sealScale })
          .shadow({
            radius: 12,
            color: $r('app.color.app_splash_shadow'),
            offsetX: 0,
            offsetY: 4
          })

        // 品牌名
        Column({ space: 4 }) {
          Text('浮叶')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Text('WebLeaf')
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Lighter)
            .opacity(0.7)
        }
        .opacity(this.titleOpacity)
        .translate({ y: this.titleTranslateY })
      }

      // 底部：进度条 + 跳过
      Column({ space: 12 }) {
        // 进度条
        Row() {
          Stack() {
            // 背景条
            Row()
              .width(160)
              .height(3)
              .borderRadius(1.5)
              .backgroundColor(Color.White)
              .opacity(0.25)

            // 进度填充
            Row()
              .width(160 * (this.progress / 100))
              .height(3)
              .borderRadius(1.5)
              .backgroundColor(Color.White)
          }
          .width(160)
          .height(3)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .opacity(this.progressOpacity)

        // 跳过按钮
        Text('跳过')
          .fontSize(13)
          .fontColor(Color.White)
          .opacity(0.6)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .borderRadius(14)
          .border({ width: 1, color: Color.White })
          .onClick(() => {
            this.goHome()
          })
      }
      .opacity(this.subtitleOpacity)
      .alignSelf(ItemAlign.Center)
      .position({ x: 0, y: 0 })
      .margin({ top: 660 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
