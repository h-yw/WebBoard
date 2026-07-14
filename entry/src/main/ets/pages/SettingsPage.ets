import { common, ConfigurationConstant, bundleManager } from '@kit.AbilityKit'
import { DatabaseManager, ColorMode, Logger } from 'container'

@Component
export struct SettingsPage {
  @State selectedMode: string = ColorMode.SYSTEM
  @State preloadEnabled: boolean = true
  @State versionName: string = ''
  @State cardTargetAppName: string = ''
  private cardTargetAppEntry: string = ''
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack | undefined = undefined
  private dbMgr: DatabaseManager | null = null

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack

    if (this.context) {
      this.dbMgr = DatabaseManager.getInstance(this.context)
      this.dbMgr.init().then(async () => {
        const mode = await this.dbMgr!.getSetting('color_mode', ColorMode.SYSTEM)
        this.selectedMode = mode
        const enabled = await this.dbMgr!.getSetting('preload_enabled', 'true')
        this.preloadEnabled = enabled === 'true'
        const cardApp = await this.dbMgr!.getSetting('card_target_app', '')
        if (cardApp.length > 0) {
          this.cardTargetAppEntry = cardApp
          const apps = await this.dbMgr!.getAllApps()
          const found = apps.find(a => a.entryHtml === cardApp)
          if (found) {
            this.cardTargetAppName = found.name
          }
        }
      })
    }

    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).then((bundleInfo) => {
      this.versionName = bundleInfo.versionName
    }).catch(() => {
      Logger.error('SettingsPage', 'Failed to get bundle info')
      this.versionName = '1.0.0'
    })
  }

  async applyColorMode(mode: string): Promise<void> {
    if (!this.context || !this.dbMgr) {
      return
    }

    this.selectedMode = mode

    await this.dbMgr.setSetting('color_mode', mode)

    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === ColorMode.LIGHT) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (mode === ColorMode.DARK) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }

    try {
      this.context.getApplicationContext().setColorMode(colorMode)
    } catch (e) {
      Logger.error('SettingsPage', 'Failed to set color mode')
    }
  }

  async setPreloadEnabled(enabled: boolean): Promise<void> {
    if (!this.context || !this.dbMgr) {
      return
    }

    this.preloadEnabled = enabled

    await this.dbMgr.setSetting('preload_enabled', enabled ? 'true' : 'false')
  }

  private showAppPicker(): void {
    if (!this.context || !this.dbMgr) {
      return
    }
    this.dbMgr.getAllApps().then((apps) => {
      if (apps.length === 0) {
        return
      }
      const sheets: SheetInfo[] = [
        { title: '（无 — 打开首页）', action: (): void => {
          this.cardTargetAppName = ''
          this.cardTargetAppEntry = ''
          this.dbMgr!.setSetting('card_target_app', '')
        }}
      ]
      for (let i = 0; i < apps.length; i++) {
        const app = apps[i]
        sheets.push({ title: app.name, action: (): void => {
          this.cardTargetAppName = app.name
          this.cardTargetAppEntry = app.entryHtml
          this.dbMgr!.setSetting('card_target_app', app.entryHtml)
        }})
      }
      this.getUIContext().showActionSheet({
        title: '选择卡片快捷方式',
        message: '点击卡片时直接打开选中的应用',
        sheets: sheets,
        cancel: (): void => { Logger.warn('SettingsPage', 'app picker cancelled') }
      })
    }).catch((err: Error) => {
      Logger.warn('SettingsPage', 'getAllApps failed')
    })
  }

  build() {
    NavDestination() {
      Column() {
        Text($r('app.string.label_appearance'))
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
              Text($r('app.string.color_mode_system'))
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text($r('app.string.color_mode_system_desc'))
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
              Text($r('app.string.color_mode_light'))
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text($r('app.string.color_mode_light_desc'))
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
              Text($r('app.string.color_mode_dark'))
                .fontSize(15)
                .fontColor($r('app.color.app_text_primary'))

              Text($r('app.string.color_mode_dark_desc'))
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

        Text($r('app.string.label_performance'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Text($r('app.string.preload_label'))
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

        Text($r('app.string.preload_desc'))
          .fontSize(12)
          .fontColor($r('app.color.app_text_muted'))
          .margin({ left: 4, top: 4 })

        // --- 桌面卡片配置 ---
        Text('桌面卡片')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Text('快捷方式')
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .layoutWeight(1)

            Text(this.cardTargetAppName.length > 0 ? this.cardTargetAppName : '未设置')
              .fontSize(14)
              .fontColor(this.cardTargetAppName.length > 0 ? $r('app.color.app_primary') : $r('app.color.app_text_muted'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.showAppPicker()
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.app_card_bg'))
        .borderRadius(12)
        .margin({ top: 8 })

        Text('点击卡片时直接打开指定的应用，留空则打开首页')
          .fontSize(12)
          .fontColor($r('app.color.app_text_muted'))
          .margin({ left: 4, top: 4 })

        Text($r('app.string.label_about'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
          .letterSpacing(0.5)
          .margin({ left: 4, top: 20, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Start)

        Column() {
          Row() {
            Text($r('app.string.label_version'))
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .layoutWeight(1)

            Text(this.versionName)
              .fontSize(15)
              .fontColor($r('app.color.app_text_muted'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Divider()
            .color($r('app.color.app_divider'))
            .margin({ left: 16, right: 16 })

          Column() {
            Text($r('app.string.app_full_name'))
              .fontSize(15)
              .fontColor($r('app.color.app_text_primary'))
              .fontWeight(FontWeight.Medium)

            Text($r('app.string.app_description'))
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
    .title($r('app.string.nav_title_settings'))
  }
}
