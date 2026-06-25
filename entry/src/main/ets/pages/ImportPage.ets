import { common } from '@kit.AbilityKit'
import { WebAppItem } from '../model/WebAppItem'
import { StorageManager } from '../util/StorageManager'
import { FileManager } from '../util/FileManager'
import { WorkDirectory } from '../util/WorkDirectory'
import { LogoType, SourceType } from '../common/Constants'

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
      this.statusMessage = '正在复制: ' + fileName + '...'
      const destPath = fileMgr.copyFileToWorkspace(this.selectedFileUri, fileName, workDir)

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
          Column() {
            this.SectionTitle('选择文件')

            Button() {
              Row({ space: 8 }) {
                Text('📄')
                  .fontSize(16)
                Text('选择 HTML 文件')
                  .fontSize(15)
                  .fontColor(Color.White)
              }
            }
            .height(48)
            .borderRadius(10)
            .backgroundColor($r('app.color.app_primary'))
            .width('90%')
            .onClick(() => {
              this.pickHtmlFile()
            })

            if (this.statusMessage.length > 0) {
              Row() {
                Text(this.importMode === 'none' ? '⚠️' : '✅')
                  .fontSize(14)
                Text(this.statusMessage)
                  .fontSize(13)
                  .fontColor(this.importMode === 'none' ? $r('app.color.app_error') : $r('app.color.app_info'))
              }
              .margin({ left: 20, right: 20, top: 12 })
            }

            if (this.importMode === 'file') {
              Column() {
                this.SectionTitle('应用名称')

                TextInput({ placeholder: '输入应用名称', text: this.appName })
                  .fontSize(15)
                  .height(48)
                  .margin({ left: 16, right: 16 })
                  .borderRadius(10)
                  .backgroundColor($r('app.color.app_card_bg'))
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => {
                    this.appName = value
                  })

                this.SectionTitle('应用描述')

                TextInput({ placeholder: '输入应用描述（可选）', text: this.appDescription })
                  .fontSize(15)
                  .height(80)
                  .margin({ left: 16, right: 16 })
                  .borderRadius(10)
                  .backgroundColor($r('app.color.app_card_bg'))
                  .padding({ left: 12, right: 12 })
                  .maxLength(100)
                  .onChange((value: string) => {
                    this.appDescription = value
                  })

                this.SectionTitle('应用图标')

                Row() {
                  if (this.logoType === LogoType.CUSTOM && this.logoUri.length > 0) {
                    Image(this.logoUri)
                      .width(64)
                      .height(64)
                      .borderRadius(14)
                      .objectFit(ImageFit.Cover)
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

                  Column({ space: 8 }) {
                    Button() {
                      Row({ space: 4 }) {
                        Text('🖼️')
                          .fontSize(14)
                        Text('选择图片')
                          .fontSize(13)
                          .fontColor(Color.White)
                      }
                    }
                    .height(32)
                    .borderRadius(8)
                    .backgroundColor($r('app.color.app_primary'))
                    .onClick(() => {
                      this.pickLogoImage()
                    })

                    if (this.logoType === LogoType.CUSTOM) {
                      Button() {
                        Row({ space: 4 }) {
                          Text('Aa')
                            .fontSize(14)
                            .fontColor($r('app.color.app_text_secondary'))
                          Text('使用首字母')
                            .fontSize(13)
                            .fontColor($r('app.color.app_text_secondary'))
                        }
                      }
                      .height(32)
                      .borderRadius(8)
                      .backgroundColor($r('app.color.app_card_bg'))
                      .border({ width: 1, color: $r('app.color.app_border') })
                      .onClick(() => {
                        this.resetLogo()
                      })
                    }
                  }
                  .margin({ left: 16 })
                }
                .width('100%')
                .padding({ left: 20, right: 20 })
                .margin({ top: 4 })
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .margin({ top: 4 })
            }

            Button() {
              Row({ space: 6 }) {
                Text('📥')
                  .fontSize(16)
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
            .margin({ top: 28, bottom: 32 })
            .enabled(this.importMode !== 'none')
            .onClick(() => {
              this.handleSave()
            })
          }
          .width('100%')
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
