import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { Logger } from 'container'

const PRIVACY_STORE = 'privacy_store'
const PRIVACY_AGREED_KEY = 'privacy_agreed'

@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController
  context?: common.UIAbilityContext
  onAgreed: () => void = () => {}
  onExit: () => void = () => {}

  build() {
    Column() {
      Text('隐私政策')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.app_text_primary'))
        .margin({ top: 8, bottom: 16 })

      Text() {
        Span('感谢您使用浮叶 WebLeaf。在您开始使用前，请仔细阅读并同意')
        Span('《隐私政策》')
          .fontColor($r('app.color.app_primary'))
          .onClick(() => {
            this.controller.close()
            router.pushUrl({
              url: 'pages/PrivacyPolicyDetail',
              params: { 'needShowDialog': true }
            })
          })
        Span('。我们重视您的隐私，仅收集必要的信息以提供核心功能。')
      }
      .fontSize(14)
      .fontColor($r('app.color.app_text_secondary'))
      .lineHeight(22)
      .margin({ bottom: 24 })

      Row({ space: 12 }) {
        Button('不同意并退出')
          .height(44)
          .borderRadius(8)
          .fontSize(15)
          .fontColor($r('app.color.app_text_secondary'))
          .backgroundColor($r('app.color.app_card_bg'))
          .border({ width: 1, color: $r('app.color.app_border') })
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close()
            this.onExit()
          })

        Button('同意')
          .height(44)
          .borderRadius(8)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.app_primary'))
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close()
            this.onAgreed()
          })
      }
      .width('100%')
    }
    .padding(24)
    .width('100%')
  }
}

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
  private context: common.UIAbilityContext | null = null
  private prefStore: preferences.Preferences | null = null
  private dialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.checkPrivacyAgreement()
  }

  private async checkPrivacyAgreement(): Promise<void> {
    try {
      this.prefStore = await preferences.getPreferences(this.context!, PRIVACY_STORE)
      const agreed: boolean = await this.prefStore.get(PRIVACY_AGREED_KEY, false) as boolean
      if (agreed) {
        this.startAnimation()
      } else {
        this.showPrivacyDialog()
      }
    } catch (e) {
      Logger.warn('SplashPage', 'checkPrivacyAgreement failed')
      this.showPrivacyDialog()
    }
  }

  private showPrivacyDialog(): void {
    this.dialogController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgreed: () => {
          this.saveAgreement()
          this.startAnimation()
        },
        onExit: () => {
          this.exitApp()
        }
      })
    })
    this.dialogController.open()
  }

  private async saveAgreement(): Promise<void> {
    try {
      if (this.prefStore) {
        await this.prefStore.put(PRIVACY_AGREED_KEY, true)
        await this.prefStore.flush()
      }
    } catch (e) {
      Logger.warn('SplashPage', 'saveAgreement failed')
    }
  }

  private exitApp(): void {
    try {
      this.context?.terminateSelf()
    } catch (e) {
      Logger.error('SplashPage', 'exitApp failed: ' + JSON.stringify(e))
    }
  }

  private startAnimation(): void {
    this.getUIContext().animateTo({
      duration: 600, curve: Curve.EaseOut, delay: 200
    }, () => {
      this.sealOpacity = 1
      this.sealScale = 1
    })

    this.getUIContext().animateTo({
      duration: 500, curve: Curve.EaseOut, delay: 500
    }, () => {
      this.titleOpacity = 1
      this.titleTranslateY = 0
    })

    this.getUIContext().animateTo({
      duration: 400, curve: Curve.EaseIn, delay: 900
    }, () => {
      this.subtitleOpacity = 1
      this.progressOpacity = 1
    })

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

    this.timerId = setTimeout(() => {
      this.goHome()
    }, 2500)
  }

  aboutToDisappear(): void {
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
    if (this.jumped) return
    this.jumped = true
    if (this.timerId !== -1) { clearTimeout(this.timerId); this.timerId = -1 }
    if (this.progressTimerId !== -1) { clearInterval(this.progressTimerId); this.progressTimerId = -1 }
    try {
      router.replaceUrl({ url: 'pages/Index' })
    } catch (e) {
      console.error('SplashPage', 'navigate failed: ' + JSON.stringify(e))
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.app_primary'))

      Column({ space: 24 }) {
        Image($r('app.media.foreground'))
          .width(120).height(120).borderRadius(28)
          .opacity(this.sealOpacity)
          .scale({ x: this.sealScale, y: this.sealScale })
          .shadow({ radius: 12, color: $r('app.color.app_splash_shadow'), offsetX: 0, offsetY: 4 })

        Column({ space: 4 }) {
          Text('浮叶').fontSize(36).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Text('WebLeaf').fontSize(15).fontColor(Color.White).fontWeight(FontWeight.Lighter).opacity(0.7)
        }
        .opacity(this.titleOpacity)
        .translate({ y: this.titleTranslateY })
      }

      Column({ space: 12 }) {
        Row() {
          Stack() {
            Row().width(160).height(3).borderRadius(1.5).backgroundColor(Color.White).opacity(0.25)
            Row().width(160 * (this.progress / 100)).height(3).borderRadius(1.5).backgroundColor(Color.White)
          }.width(160).height(3)
        }.width('100%').justifyContent(FlexAlign.Center).opacity(this.progressOpacity)

        Text('跳过')
          .fontSize(13).fontColor(Color.White).opacity(0.6)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 }).borderRadius(14)
          .border({ width: 1, color: Color.White })
          .onClick(() => { this.goHome() })
      }
      .opacity(this.subtitleOpacity)
      .alignSelf(ItemAlign.Center)
      .position({ x: 0, y: 0 }).margin({ top: 660 }).width('100%')
    }
    .width('100%').height('100%').alignContent(Alignment.Center)
  }
}
