import { common } from '@kit.AbilityKit'
import { WebAppItem } from '../model/WebAppItem'
import { DatabaseManager } from '../database/DatabaseManager'
import { FileManager } from '../util/FileManager'
import { WorkDirectory } from '../util/WorkDirectory'
import { LogoType, SourceType } from '../common/Constants'
import { Toast } from '../ui/ToastUtil'
import { EventArg, eventEmitter } from '../common/EventEmitter'

@Component
export struct ImportPage {
  @State selectedFileName: string = ''
  @State selectedFileUri: string = ''
  @State appName: string = ''
  @State appDescription: string = ''
  @State logoUri: string = ''
  @State logoType: string = LogoType.INITIAL
  @State importMode: string = 'none'
  @State statusMessage: string = ''
  @State urlInput: string = ''
  @State isDownloading: boolean = false
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack | undefined = undefined

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack
  }

  getInitial(): string {
    if (this.appName.length > 0) {
      return this.appName.charAt(0).toUpperCase()
    }
    return '?'
  }

  async pickHtmlFile(): Promise<void> {
    if (!this.context) {
      return
    }
    const fileMgr = new FileManager(this.context)
    try {
      const uris = await fileMgr.selectHtmlFile()
      if (uris.length > 0) {
        this.selectedFileUri = uris[0]
        const fileName = fileMgr.getFileNameFromUri(uris[0])
        this.selectedFileName = fileName
        this.importMode = 'file'
        if (this.appName.length === 0) {
          this.appName = fileName.replace(/\.html?$/i, '')
        }
        this.statusMessage = '已选择: ' + fileName
      }
    } catch (e) {
      this.statusMessage = '选择文件失败'
    }
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
        this.statusMessage = '已选择 Logo'
      }
    } catch (e) {
      this.statusMessage = '选择图片失败'
    }
  }

  resetLogo(): void {
    this.logoUri = ''
    this.logoType = LogoType.INITIAL
  }

  async downloadFromUrl(): Promise<void> {
    if (this.urlInput.length === 0) {
      return
    }

    this.isDownloading = true
    this.statusMessage = '正在处理...'

    try {
      const url = this.urlInput.trim()
      const urlParts = url.split('/')
      let fileName = urlParts[urlParts.length - 1] || 'webpage'
      if (!fileName.includes('.')) {
        fileName = fileName + '.html'
      }

      this.selectedFileUri = url
      this.selectedFileName = fileName
      this.importMode = 'url'
      if (this.appName.length === 0) {
        this.appName = fileName.replace(/\.html?$/i, '')
      }
      this.statusMessage = '已选择: ' + url
    } catch (e) {
      const err = e as Error
      this.statusMessage = '处理失败: ' + err.message
    } finally {
      this.isDownloading = false
    }
  }

  async handleSave(): Promise<void> {
    if (!this.context) {
      return
    }
    if (this.importMode === 'none') {
      this.statusMessage = '请先选择文件'
      return
    }

    const workDir = WorkDirectory.getPath(this.context)
    WorkDirectory.ensureDirectory(this.context)
    const fileMgr = new FileManager(this.context)

    const fileName = this.selectedFileName
    try {
      let destPath: string
      let sourceType: string
      let persistUri: string = ''
      let persistMode: string = ''
      if (this.importMode === 'url') {
        destPath = this.selectedFileUri
        sourceType = SourceType.URL
        this.statusMessage = '正在保存...'
      } else {
        // Try persist permission first for file imports
        this.statusMessage = '正在处理: ' + fileName + '...'
        const persisted = await fileMgr.tryPersistPermission(this.selectedFileUri)
        if (persisted) {
          destPath = this.selectedFileUri
          if (destPath.startsWith('file://')) {
            destPath = destPath.substring(7)
          }
          sourceType = SourceType.FILE
          persistUri = this.selectedFileUri
          persistMode = 'read'
        } else {
          this.statusMessage = '正在复制: ' + fileName + '...'
          destPath = fileMgr.copyFileToWorkspace(this.selectedFileUri, fileName, workDir)
          sourceType = SourceType.FILE
        }
      }

      const item = new WebAppItem()
      item.id = fileMgr.generateId()
      item.name = this.appName.trim().length > 0 ? this.appName.trim() : fileName.replace(/\.html?$/i, '')
      item.description = this.appDescription.trim()
      item.logoType = this.logoType
      item.logoUri = ''
      item.entryHtml = destPath
      item.sourceType = sourceType
      item.createTime = Date.now()
      item.persistUri = persistUri
      item.persistMode = persistMode

      if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
        try {
          const logoFileName = item.id + '_logo.png'
          const logoDest = fileMgr.copyFileToWorkspace(this.logoUri, logoFileName, workDir)
          item.logoUri = logoDest
        } catch (e) {
          item.logoType = LogoType.INITIAL
        }
      }

      const dbMgr = DatabaseManager.getInstance(this.context)
      await dbMgr.addApp(item)

      Toast.show('导入成功')
      eventEmitter.emit("item:add", Object({item: item.id}) as EventArg)
      AppStorage.Set<number>('dataRefreshTick', Date.now())
      this.navPathStack?.pop()
    } catch (e) {
      const err = e as Error
      this.statusMessage = '导入失败: ' + err.message
    }
  }

  scanResult(paramRecord:object){
    if (paramRecord) {
      const scanUrl: string = paramRecord['scanUrl'] || ''
      const scanName: string = paramRecord['scanName'] || ''
      const scanDesc: string = paramRecord['scanDesc'] || ''
      if (scanUrl.length > 0) {
        this.urlInput = scanUrl
        this.selectedFileUri = scanUrl
        this.selectedFileName = scanName.length > 0 ? scanName : 'scan_import'
        this.importMode = 'url'
        if (scanName.length > 0) {
          this.appName = scanName
        }
        if (scanDesc.length > 0) {
          this.appDescription = scanDesc
        }
      }
    }
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.app_text_muted'))
      .letterSpacing(0.5)
      .margin({ left: 20, top: 20, bottom: 8 })
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Column({ space: 4 }) {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.doc'))
                    .fontSize(24)
                    .fontColor([this.importMode === 'file' ? $r('app.color.app_primary') : $r('app.color.app_text_muted')])
                  Column({ space: 4 }) {
                    Text($r('app.string.import_file_title'))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.app_text_primary'))
                    Text($r('app.string.import_file_desc'))
                      .fontSize(12)
                      .fontColor($r('app.color.app_text_muted'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .onClick(()=>{
                  this.pickHtmlFile()
                })

                if (this.importMode === 'file' && this.selectedFileName.length > 0) {
                  Divider()
                    .color($r('app.color.app_divider'))
                    .margin({ top: 8 })
                  Row({ space: 8 }) {
                    SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                      .fontSize(16)
                      .fontColor([$r('app.color.app_success')])
                    Text(this.selectedFileName)
                      .fontSize(13)
                      .fontColor($r('app.color.app_text_secondary'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .margin({ top: 8 })
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor($r('app.color.app_card_bg'))
              .border({ width: 1, color: this.importMode === 'file' ? $r('app.color.app_primary') : $r('app.color.app_border') })
              .onClick(() => {
                this.pickHtmlFile()
              })

              Row({ space: 12 }) {
                Divider()
                  .layoutWeight(1)
                  .color($r('app.color.app_divider'))
                Text($r('app.string.import_or'))
                  .fontSize(12)
                  .fontColor($r('app.color.app_text_muted'))
                Divider()
                  .layoutWeight(1)
                  .color($r('app.color.app_divider'))
              }
              .width('100%')

              Column({ space: 4 }) {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.link'))
                    .fontSize(24)
                    .fontColor([this.importMode === 'url' ? $r('app.color.app_primary') : $r('app.color.app_text_muted')])
                  Column({ space: 4 }) {
                    Text($r('app.string.import_url_title'))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.app_text_primary'))
                    Text($r('app.string.import_url_desc'))
                      .fontSize(12)
                      .fontColor($r('app.color.app_text_muted'))
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                Row({ space: 8 }) {
                  TextInput({ placeholder: $r('app.string.import_url_hint'), text: this.urlInput })
                    .fontSize(14)
                    .height(44)
                    .layoutWeight(1)
                    .borderRadius(8)
                    .backgroundColor($r('app.color.app_background'))
                    .padding({ left: 12, right: 12 })
                    .onChange((value: string) => {
                      this.urlInput = value
                    })

                  Button() {
                    if (this.isDownloading) {
                      LoadingProgress()
                        .width(20)
                        .height(20)
                        .color(Color.White)
                    } else {
                      SymbolGlyph($r('sys.symbol.arrow_down_circle'))
                        .fontSize(20)
                        .fontColor([Color.White])
                    }
                  }
                  .height(44)
                  .width(44)
                  .borderRadius(8)
                  .backgroundColor(this.urlInput.length > 0 ? $r('app.color.app_primary') : $r('app.color.app_text_disabled'))
                  .enabled(this.urlInput.length > 0 && !this.isDownloading)
                  .onClick(() => {
                    this.downloadFromUrl()
                  })
                }
                .width('100%')
                .margin({ top: 8 })

                if (this.importMode === 'url' && this.selectedFileName.length > 0) {
                  Divider()
                    .color($r('app.color.app_divider'))
                    .margin({ top: 8 })
                  Row({ space: 8 }) {
                    SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                      .fontSize(16)
                      .fontColor([$r('app.color.app_success')])
                    Text(this.selectedFileName)
                      .fontSize(13)
                      .fontColor($r('app.color.app_text_secondary'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .margin({ top: 8 })
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor($r('app.color.app_card_bg'))
              .border({ width: 1, color: this.importMode === 'url' ? $r('app.color.app_primary') : $r('app.color.app_border') })
            }
            .width('90%')
            .margin({ top: 16 })

            if (this.importMode === 'none' && this.statusMessage.length > 0) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                  .fontSize(16)
                  .fontColor([$r('app.color.app_error')])
                Text(this.statusMessage)
                  .fontSize(13)
                  .fontColor($r('app.color.app_error'))
              }
              .width('90%')
              .padding(10)
              .borderRadius(8)
              .backgroundColor($r('app.color.app_error_bg'))
            }

            if (this.importMode !== 'none') {
              Column({ space: 16 }) {
                Column({ space: 6 }) {
                Text($r('app.string.label_app_name'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_muted'))
                  .width('100%')
                TextInput({ placeholder: $r('app.string.label_name_placeholder'), text: this.appName })
                    .fontSize(15)
                    .height(44)
                    .width('100%')
                    .borderRadius(8)
                    .backgroundColor($r('app.color.app_background'))
                    .padding({ left: 12, right: 12 })
                    .onChange((value: string) => {
                      this.appName = value
                    })
                }

                Column({ space: 6 }) {
                Text($r('app.string.label_app_desc_optional'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_muted'))
                  .width('100%')
                TextInput({ placeholder: $r('app.string.label_desc_placeholder'), text: this.appDescription })
                    .fontSize(15)
                    .height(72)
                    .width('100%')
                    .borderRadius(8)
                    .backgroundColor($r('app.color.app_background'))
                    .padding({ left: 12, right: 12 })
                    .maxLength(100)
                    .onChange((value: string) => {
                      this.appDescription = value
                    })
                }

                Column({ space: 12 }) {
                Text($r('app.string.label_app_logo'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_muted'))
                  .width('100%')

                  Row({ space: 16 }) {
                    if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
                      Image(this.logoUri)
                        .width(56)
                        .height(56)
                        .borderRadius(12)
                        .objectFit(ImageFit.Cover)
                    } else {
                      Stack() {
                        Text(this.getInitial())
                          .fontSize(24)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)
                      }
                      .width(56)
                      .height(56)
                      .borderRadius(12)
                      .linearGradient({
                        angle: 135,
                        colors: [[$r('app.color.app_gradient_start'), 0.0], [$r('app.color.app_gradient_end'), 1.0]]
                      })
                      .alignContent(Alignment.Center)
                    }

                    Column({ space: 6 }) {
                      Text(this.logoType === LogoType.CUSTOM ? $r('app.string.btn_change_logo') : $r('app.string.btn_custom_logo'))
                        .fontSize(14)
                        .fontColor($r('app.color.app_primary'))
                        .onClick(() => {
                          this.pickLogoImage()
                        })

                      if (this.logoType === LogoType.CUSTOM) {
                      Text($r('app.string.btn_use_initial'))
                        .fontSize(13)
                        .fontColor($r('app.color.app_text_muted'))
                          .onClick(() => {
                            this.resetLogo()
                          })
                      }
                    }
                    .justifyContent(FlexAlign.Center)
                  }
                  .width('100%')
                }
              }
              .width('90%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor($r('app.color.app_card_bg'))
            }

            Button() {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
                  .fontSize(18)
                  .fontColor([Color.White])
                Text($r('app.string.btn_save_import'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
              }
            }
            .height(50)
            .borderRadius(12)
            .backgroundColor(this.importMode !== 'none' ? $r('app.color.app_primary') : $r('app.color.app_text_disabled'))
            .width('90%')
            .margin({ bottom: 32 })
            .enabled(this.importMode !== 'none')
            .onClick(() => {
              this.handleSave()
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
      .transition(TransitionEffect.opacity(0.5).animation({ duration: 300, curve: Curve.EaseInOut }))
    }
    .title('导入')
    .onReady((ctx)=>{
      const param = ctx.pathInfo.param as object
      this.navPathStack = ctx.pathStack
      this.scanResult(param)
    })

  }
}
