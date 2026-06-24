import { common } from '@kit.AbilityKit'
import { WebAppItem } from '../model/WebAppItem'
import { StorageManager } from '../util/StorageManager'
import { FileManager } from '../util/FileManager'
import { WorkDirectory } from '../util/WorkDirectory'
import { LogoType } from '../common/Constants'

interface EditParam {
  appId: string
  appName: string
  appDescription: string
  logoType: string
  logoUri: string
  entryHtml: string
}

@Component
export struct EditPage {
  @State appName: string = ''
  @State appDescription: string = ''
  @State logoUri: string = ''
  @State logoType: string = LogoType.INITIAL
  @State statusMessage: string = ''
  private appId: string = ''
  private entryHtml: string = ''
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
      }
    }
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
    if (this.appName.trim().length === 0) {
      this.statusMessage = '请输入应用名称'
      return
    }

    const workDir = WorkDirectory.getPath(this.context)
    WorkDirectory.ensureDirectory(this.context)
    const fileMgr = new FileManager(this.context)

    try {
      this.statusMessage = '正在保存...'

      const item = new WebAppItem()
      item.id = this.appId
      item.name = this.appName.trim()
      item.description = this.appDescription.trim()
      item.logoType = this.logoType
      item.logoUri = this.logoUri
      item.entryHtml = this.entryHtml
      item.sourceType = 'file'
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

      const storageMgr = StorageManager.getInstance(this.context)
      const items = await storageMgr.getAll()
      const index = items.findIndex(i => i.id === this.appId)
      if (index >= 0) {
        items[index] = item
        await storageMgr.saveAll(items)
      }

      this.getUIContext().getPromptAction().showToast({ message: '保存成功' })
      this.navPathStack?.pop()
    } catch (e) {
      this.statusMessage = '保存失败'
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
                    SymbolGlyph($r('sys.symbol.picture'))
                      .fontSize(14)
                      .fontColor([Color.White])
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

            if (this.statusMessage.length > 0) {
              Text(this.statusMessage)
                .fontSize(13)
                .fontColor($r('app.color.app_text_secondary'))
                .margin({ left: 20, right: 20, top: 12 })
            }

            Button() {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.save'))
                  .fontSize(16)
                  .fontColor([Color.White])
                Text('保存修改')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
              }
            }
            .height(50)
            .borderRadius(12)
            .backgroundColor(this.appName.trim().length > 0 ? $r('app.color.app_primary') : $r('app.color.app_text_disabled'))
            .width('90%')
            .margin({ top: 28, bottom: 32 })
            .enabled(this.appName.trim().length > 0)
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
    .title('编辑应用')
  }
}
