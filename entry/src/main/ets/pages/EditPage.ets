import { common } from '@kit.AbilityKit'
import { WebAppItem } from '../model/WebAppItem'
import { DatabaseManager } from '../database/DatabaseManager'
import { FileManager } from '../util/FileManager'
import { WorkDirectory } from '../util/WorkDirectory'
import { LogoType, SourceType } from '../common/Constants'
import { Dialog } from '../ui/DialogUtil'
import { Toast } from '../ui/ToastUtil'

interface EditParam {
  appId: string
  appName: string
  appDescription: string
  logoType: string
  logoUri: string
  entryHtml: string
  sourceType: string
}

@Component
export struct EditPage {
  @State appName: string = ''
  @State appDescription: string = ''
  @State appUrl: string = ''
  @State logoUri: string = ''
  @State logoType: string = LogoType.INITIAL
  @State statusMessage: string = ''
  @State hasUnsavedChanges: boolean = false
  @State isSaving: boolean = false
  @State nameCharCount: number = 0
  @State descCharCount: number = 0
  private appId: string = ''
  private entryHtml: string = ''
  private sourceType: string = SourceType.FILE
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack | undefined = undefined

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack
    if (this.navPathStack) {
      const paramObj = this.navPathStack.getParamByName('EditPage') as EditParam[]
      if (paramObj && paramObj.length > 0) {
        this.appId = paramObj[0].appId || ''
        this.appName = paramObj[0].appName || ''
        this.appDescription = paramObj[0].appDescription || ''
        this.logoType = paramObj[0].logoType || LogoType.INITIAL
        this.logoUri = paramObj[0].logoUri || ''
        this.entryHtml = paramObj[0].entryHtml || ''
        this.sourceType = paramObj[0].sourceType || SourceType.FILE
        if (this.sourceType === SourceType.URL) {
          this.appUrl = this.entryHtml
        }
        this.nameCharCount = this.appName.length
        this.descCharCount = this.appDescription.length
      }
    }
  }

  onBackPress(): boolean {
    if (this.hasUnsavedChanges) {
      Dialog.confirm({
        title: $r('app.string.unsaved_title'),
        message: $r('app.string.unsaved_message'),
        confirmText: $r('app.string.btn_leave'),
        cancelText: $r('app.string.btn_cancel'),
        onConfirm: () => {
          this.navPathStack?.pop()
        }
      })
      return true
    }
    return false
  }

  getInitial(): string {
    if (this.appName.length > 0) {
      return this.appName.charAt(0).toUpperCase()
    }
    return '?'
  }

  async pickLogoImage(): Promise<void> {
    if (!this.context) {
      return
    }
    const fileMgr = new FileManager(this.context)
    try {
      const uris = await fileMgr.selectImageFile()
      if (uris.length > 0) {
        this.logoUri = uris[0]
        this.logoType = LogoType.CUSTOM
        this.hasUnsavedChanges = true
      }
    } catch (e) {
      this.statusMessage = '选择图片失败'
    }
  }

  resetLogo(): void {
    this.logoUri = ''
    this.logoType = LogoType.INITIAL
    this.hasUnsavedChanges = true
  }

  async handleSave(): Promise<void> {
    if (!this.context) {
      return
    }
    if (this.appName.trim().length === 0) {
      this.statusMessage = '请输入应用名称'
      return
    }

    this.isSaving = true

    const workDir = WorkDirectory.getPath(this.context)
    WorkDirectory.ensureDirectory(this.context)
    const fileMgr = new FileManager(this.context)

    try {
      const item = new WebAppItem()
      item.id = this.appId
      item.name = this.appName.trim()
      item.description = this.appDescription.trim()
      item.logoType = this.logoType
      item.logoUri = this.logoUri
      item.entryHtml = this.sourceType === SourceType.URL ? this.appUrl : this.entryHtml
      item.sourceType = this.sourceType
      item.createTime = Date.now()

      if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
        try {
          const logoFileName = item.id + '_logo.png'
          const logoDest = fileMgr.copyFileToWorkspace(this.logoUri, logoFileName, workDir)
          item.logoUri = logoDest
        } catch (e) {
          item.logoType = LogoType.INITIAL
          item.logoUri = ''
        }
      }

      const dbMgr = DatabaseManager.getInstance(this.context)
      await dbMgr.updateApp(item)

      AppStorage.setOrCreate('dataChanged', true)
      this.hasUnsavedChanges = false
      Toast.show('保存成功')
      setTimeout(() => {
        this.navPathStack?.pop()
      }, 500)
    } catch (e) {
      this.statusMessage = '保存失败'
    } finally {
      this.isSaving = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            // ── 应用名称 ──
            Column({ space: 8 }) {
              Row() {
                Text($r('app.string.label_app_name'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_primary'))
                  .layoutWeight(1)
                Text(this.nameCharCount.toString() + '/50')
                  .fontSize(12)
                  .fontColor($r('app.color.app_text_disabled'))
              }
              .width('100%')

              TextInput({ placeholder: $r('app.string.label_name_placeholder'), text: this.appName })
                .fontSize(15)
                .height(48)
                .width('100%')
                .borderRadius(10)
                .backgroundColor($r('app.color.app_background'))
                .padding({ left: 14, right: 14 })
                .maxLength(50)
                .onChange((value: string) => {
                  this.appName = value
                  this.nameCharCount = value.length
                  this.hasUnsavedChanges = true
                })
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor($r('app.color.app_card_bg'))

            // ── 应用描述 ──
            Column({ space: 8 }) {
              Row() {
                Text($r('app.string.label_app_desc'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_primary'))
                  .layoutWeight(1)
                Text(this.descCharCount.toString() + '/100')
                  .fontSize(12)
                  .fontColor($r('app.color.app_text_disabled'))
              }
              .width('100%')

              TextArea({ placeholder: $r('app.string.label_desc_placeholder_optional'), text: this.appDescription })
                .fontSize(15)
                .height(88)
                .width('100%')
                .borderRadius(10)
                .backgroundColor($r('app.color.app_background'))
                .padding({ left: 14, right: 14 })
                .maxLength(100)
                .onChange((value: string) => {
                  this.appDescription = value
                  this.descCharCount = value.length
                  this.hasUnsavedChanges = true
                })
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor($r('app.color.app_card_bg'))

            // ── 导入网址（仅 URL 类型展示） ──
            if (this.sourceType === SourceType.URL) {
              Column({ space: 8 }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.link'))
                    .fontSize(14)
                    .fontColor([$r('app.color.app_primary')])
                    .margin({ right: 6 })
                  Text($r('app.string.label_import_url'))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.app_text_primary'))
                }

                TextInput({ placeholder: 'https://', text: this.appUrl })
                  .fontSize(14)
                  .height(48)
                  .width('100%')
                  .borderRadius(10)
                  .backgroundColor($r('app.color.app_background'))
                  .padding({ left: 14, right: 14 })
                  .onChange((value: string) => {
                    this.appUrl = value
                    this.hasUnsavedChanges = true
                  })
              }
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor($r('app.color.app_card_bg'))
            }

            // ── 应用图标 ──
            Column({ space: 12 }) {
              Text($r('app.string.label_app_logo'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.app_text_primary'))
                .width('100%')

              Row({ space: 20 }) {
                if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
                  Image('file://' + this.logoUri)
                    .width(64)
                    .height(64)
                    .borderRadius(14)
                    .objectFit(ImageFit.Cover)
                    .border({ width: 2, color: $r('app.color.app_primary') })
                } else {
                  Stack() {
                    Text(this.getInitial())
                      .fontSize(28)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(64)
                  .height(64)
                  .borderRadius(14)
                  .linearGradient({
                    angle: 135,
                    colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
                  })
                  .alignContent(Alignment.Center)
                }

                Column({ space: 10 }) {
                  Button() {
                    Row({ space: 4 }) {
                      SymbolGlyph($r('sys.symbol.picture'))
                        .fontSize(14)
                        .fontColor([Color.White])
                      Text($r('app.string.btn_select_image'))
                        .fontSize(13)
                        .fontColor(Color.White)
                    }
                  }
                  .height(36)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.app_primary'))
                  .width(120)
                  .onClick(() => {
                    this.pickLogoImage()
                  })

                  if (this.logoType === LogoType.CUSTOM) {
                    Button() {
                      Row({ space: 4 }) {
                        Text('Aa')
                          .fontSize(14)
                          .fontColor($r('app.color.app_text_secondary'))
                        Text($r('app.string.btn_use_initial'))
                          .fontSize(13)
                          .fontColor($r('app.color.app_text_secondary'))
                      }
                    }
                    .height(36)
                    .borderRadius(8)
                    .backgroundColor($r('app.color.app_card_bg'))
                    .border({ width: 1, color: $r('app.color.app_border') })
                    .width(120)
                    .onClick(() => {
                      this.resetLogo()
                    })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor($r('app.color.app_card_bg'))

            // 状态消息
            if (this.statusMessage.length > 0) {
              Row({ space: 8 }) {
                if (this.statusMessage.includes('失败')) {
                  SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                    .fontSize(16)
                    .fontColor([$r('app.color.app_error')])
                } else if (this.statusMessage.includes('成功')) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                    .fontSize(16)
                    .fontColor([$r('app.color.app_success')])
                }
                Text(this.statusMessage)
                  .fontSize(13)
                  .fontColor(this.statusMessage.includes('失败') ? $r('app.color.app_error') :
                    this.statusMessage.includes('成功') ? $r('app.color.app_success') : $r('app.color.app_text_secondary'))
              }
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor(this.statusMessage.includes('失败') ? '#FEF2F2' :
                this.statusMessage.includes('成功') ? '#F0FDF4' : $r('app.color.app_card_bg'))
            }

            // 保存按钮
            Button() {
              Row({ space: 6 }) {
                if (this.isSaving) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color(Color.White)
                  Text($r('app.string.btn_saving'))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                } else {
                  SymbolGlyph($r('sys.symbol.save'))
                    .fontSize(16)
                    .fontColor([Color.White])
                  Text($r('app.string.btn_save_changes'))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                }
              }
            }
            .height(50)
            .borderRadius(12)
            .backgroundColor(this.appName.trim().length > 0 && !this.isSaving ? $r('app.color.app_primary') : $r('app.color.app_text_disabled'))
            .width('100%')
            .enabled(this.appName.trim().length > 0 && !this.isSaving)
            .onClick(() => {
              this.handleSave()
            })
          }
          .width('90%')
          .margin({ top: 20, bottom: 32 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
    }
    .title($r('app.string.nav_title_edit'))
  }
}
