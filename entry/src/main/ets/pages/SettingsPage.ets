import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { StorageManager } from '../util/StorageManager'
import { ColorMode } from '../common/Constants'

@Component
export struct SettingsPage {
  @State selectedMode: string = ColorMode.SYSTEM
  @State preloadEnabled: boolean = true
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack | undefined = undefined
  private storageMgr: StorageManager | null = null

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack

    if (this.context) {
      this.storageMgr = StorageManager.getInstance(this.context)
      this.storageMgr.getColorMode().then((mode: string) => {
        this.selectedMode = mode
      })
      this.storageMgr.isPreloadEnabled().then((enabled: boolean) => {
        this.preloadEnabled = enabled
      })
    }
  }

  async applyColorMode(mode: string): Promise<void> {
    if (!this.context || !this.storageMgr) {
      return
    }

    this.selectedMode = mode

    await this.storageMgr.setColorMode(mode)

    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === ColorMode.LIGHT) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (mode === ColorMode.DARK) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }

    try {
      this.context.getApplicationContext().setColorMode(colorMode)
    } catch (e) {
      console.error('Failed to set color mode')
    }
  }

  async setPreloadEnabled(enabled: boolean): Promise<void> {
    if (!this.context || !this.storageMgr) {
      return
    }

    this.preloadEnabled = enabled

    await this.storageMgr.setPreloadEnabled(enabled)
  }

  build() {
    NavDestination() {
      Column() {
        Text('外观')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Radio({ value: ColorMode.SYSTEM, group: 'colorMode' })
              .checked(this.selectedMode === ColorMode.SYSTEM)
              .onClick(() => {
                this.applyColorMode(ColorMode.SYSTEM)
              })
              .width(20)
              .height(20)

            Column() {
              Text('跟随系统')
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text('自动跟随系统深浅模式设置')
                .fontSize(12)
                .fontColor($r('app.color.app_text_muted'))
                .margin({ top: 2 })
            }
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.applyColorMode(ColorMode.SYSTEM)
          })

          Divider()
            .color($r('app.color.app_divider'))
            .margin({ left: 48, right: 16 })

          Row() {
            Radio({ value: ColorMode.LIGHT, group: 'colorMode' })
              .checked(this.selectedMode === ColorMode.LIGHT)
              .onClick(() => {
                this.applyColorMode(ColorMode.LIGHT)
              })
              .width(20)
              .height(20)

            Column() {
              Text('浅色模式')
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text('始终使用浅色模式')
                .fontSize(12)
                .fontColor($r('app.color.app_text_muted'))
                .margin({ top: 2 })
            }
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.applyColorMode(ColorMode.LIGHT)
          })

          Divider()
            .color($r('app.color.app_divider'))
            .margin({ left: 48, right: 16 })

          Row() {
            Radio({ value: ColorMode.DARK, group: 'colorMode' })
              .checked(this.selectedMode === ColorMode.DARK)
              .onClick(() => {
                this.applyColorMode(ColorMode.DARK)
              })
              .width(20)
              .height(20)

            Column() {
              Text('深色模式')
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text('始终使用深色模式')
                .fontSize(12)
                .fontColor($r('app.color.app_text_muted'))
                .margin({ top: 2 })
            }
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.applyColorMode(ColorMode.DARK)
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.app_card_bg'))
        .borderRadius(12)
        .margin({ top: 8 })

        Text('性能')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Text('预加载')
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.preloadEnabled })
              .onChange((isOn: boolean) => {
                this.setPreloadEnabled(isOn)
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
        .width('100%')
        .backgroundColor($r('app.color.app_card_bg'))
        .borderRadius(12)
        .margin({ top: 8 })

        Text('开启后会预加载最近使用的应用，提升打开速度')
          .fontSize(12)
          .fontColor($r('app.color.app_text_muted'))
          .margin({ left: 4, top: 4 })

        Text('关于')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Text('版本')
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .layoutWeight(1)

            Text('1.0.0')
              .fontSize(15)
              .fontColor($r('app.color.app_text_muted'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Divider()
            .color($r('app.color.app_divider'))
            .margin({ left: 16, right: 16 })

          Column() {
            Text('WebBoard')
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .fontWeight(FontWeight.Medium)

            Text('管理和渲染 HTML 内容的 HarmonyOS 应用')
              .fontSize(13)
              .fontColor($r('app.color.app_text_secondary'))
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
        .width('100%')
        .backgroundColor($r('app.color.app_card_bg'))
        .borderRadius(12)
        .margin({ top: 8 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.app_background'))
    }
    .title('设置')
  }
}
