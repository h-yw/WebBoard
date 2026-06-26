import { common } from '@kit.AbilityKit'
import { WebAppItem } from '../model/WebAppItem'
import { StorageManager } from '../util/StorageManager'
import { FileManager } from '../util/FileManager'
import { WorkDirectory } from '../util/WorkDirectory'
import { LogoType, SourceType } from '../common/Constants'
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'

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
    if (!this.context || this.urlInput.length === 0) {
      return
    }

    this.isDownloading = true
    this.statusMessage = '正在下载...'

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(this.urlInput, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING
      })

      if (response.responseCode === 200) {
        const htmlContent = response.result as string

        const urlParts = this.urlInput.split('/')
        let fileName = urlParts[urlParts.length - 1] || 'downloaded.html'
        if (!fileName.endsWith('.html') && !fileName.endsWith('.htm')) {
          fileName = fileName + '.html'
        }

        const workDir = WorkDirectory.getPath(this.context)
        WorkDirectory.ensureDirectory(this.context)
        const filePath = workDir + '/' + fileName

        const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.writeSync(file.fd, htmlContent)
        fileIo.closeSync(file)

        this.selectedFileUri = filePath
        this.selectedFileName = fileName
        this.importMode = 'url'
        if (this.appName.length === 0) {
          this.appName = fileName.replace(/\.html?$/i, '')
        }
        this.statusMessage = '下载完成: ' + fileName
      } else {
        this.statusMessage = '下载失败: HTTP ' + response.responseCode
      }

      httpRequest.destroy()
    } catch (e) {
      const err = e as Error
      this.statusMessage = '下载失败: ' + err.message
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

      if (this.importMode === 'url') {
        destPath = this.selectedFileUri
        this.statusMessage = '正在保存...'
      } else {
        this.statusMessage = '正在复制: ' + fileName + '...'
        destPath = fileMgr.copyFileToWorkspace(this.selectedFileUri, fileName, workDir)
      }

      const item = new WebAppItem()
      item.id = fileMgr.generateId()
      item.name = this.appName.trim().length > 0 ? this.appName.trim() : fileName.replace(/\.html?$/i, '')
      item.description = this.appDescription.trim()
      item.logoType = this.logoType
      item.logoUri = ''
      item.entryHtml = destPath
      item.sourceType = SourceType.FILE
      item.createTime = Date.now()

      if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
        try {
          const logoFileName = item.id + '_logo.png'
          const logoDest = fileMgr.copyFileToWorkspace(this.logoUri, logoFileName, workDir)
          item.logoUri = logoDest
        } catch (e) {
          item.logoType = LogoType.INITIAL
        }
      }

      const storageMgr = StorageManager.getInstance(this.context)
      await storageMgr.add(item)

      AppStorage.setOrCreate('dataChanged', true)
      this.getUIContext().getPromptAction().showToast({ message: '导入成功' })
      this.navPathStack?.pop()
    } catch (e) {
      const err = e as Error
      this.statusMessage = '导入失败: ' + err.message
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
                    Text('从文件导入')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.app_text_primary'))
                    Text('选择本地 HTML 文件')
                      .fontSize(12)
                      .fontColor($r('app.color.app_text_muted'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')

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
                Text('或')
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
                    Text('从网址导入')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.app_text_primary'))
                    Text('输入 HTML 网址下载')
                      .fontSize(12)
                      .fontColor($r('app.color.app_text_muted'))
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                Row({ space: 8 }) {
                  TextInput({ placeholder: 'https://example.com/page.html', text: this.urlInput })
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
              .backgroundColor('#FEF2F2')
            }

            if (this.importMode !== 'none') {
              Column({ space: 16 }) {
                Column({ space: 6 }) {
                  Text('应用名称')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.app_text_muted'))
                    .width('100%')
                  TextInput({ placeholder: '输入应用名称', text: this.appName })
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
                  Text('应用描述（可选）')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.app_text_muted'))
                    .width('100%')
                  TextInput({ placeholder: '输入应用描述', text: this.appDescription })
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
                  Text('应用图标')
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
                        colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
                      })
                      .alignContent(Alignment.Center)
                    }

                    Column({ space: 6 }) {
                      Text(this.logoType === LogoType.CUSTOM ? '更换图标' : '自定义图标')
                        .fontSize(14)
                        .fontColor($r('app.color.app_primary'))
                        .onClick(() => {
                          this.pickLogoImage()
                        })

                      if (this.logoType === LogoType.CUSTOM) {
                        Text('使用首字母')
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
                Text('保存并导入')
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
    }
    .title('导入 HTML 应用')
  }
}
