import { WebAppItem } from '../model/WebAppItem'
import { StorageManager } from '../util/StorageManager'
import { WebPreloader } from '../util/WebPreloader'
import { WorkDirectory } from '../util/WorkDirectory'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ImportPage } from './ImportPage'
import { ViewerPage } from './ViewerPage'
import { AppColors, LogoType, SourceType } from '../common/Constants'

interface ViewerParam {
  entryHtml: string
  appName: string
}

@Entry
@Component
struct Index {
  @State appList: WebAppItem[] = []
  private storageMgr: StorageManager | null = null
  private navPathStack: NavPathStack = new NavPathStack()
  private dataChanged: boolean = false

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.storageMgr = new StorageManager(context)
    WorkDirectory.ensureDirectory(context)
    await this.loadApps()
    if (this.appList.length === 0) {
      await this.addPresetApp()
      await this.loadApps()
    }
    this.preloadRecentApps()
  }

  onPageShow(): void {
    if (this.dataChanged) {
      this.loadApps()
      this.dataChanged = false
    }
  }

  async addPresetApp(): Promise<void> {
    const id = WorkDirectory.generateId()
    const item = new WebAppItem()
    item.id = id
    item.name = '速算估算微练'
    item.description = '掌握 1/2 到 1/20 的快速转换，提升心算敏感度'
    item.logoType = LogoType.INITIAL
    item.logoUri = ''
    item.entryHtml = 'rawfile://code_artifact.html'
    item.sourceType = SourceType.PRESET
    item.createTime = Date.now()
    if (this.storageMgr) {
      await this.storageMgr.add(item)
      this.dataChanged = true
    }
  }

  async loadApps(): Promise<void> {
    if (this.storageMgr) {
      this.appList = await this.storageMgr.getAll()
    }
  }

  preloadRecentApps(): void {
    const preloader = WebPreloader.getInstance()
    const recentKeys = preloader.getRecentKeys()
    for (let i = 0; i < recentKeys.length; i++) {
      const key = recentKeys[i]
      const item = this.appList.find(app => app.entryHtml === key)
      if (item && !preloader.isPreloaded(key)) {
        let src = ''
        if (key.startsWith('rawfile://')) {
          src = key.substring(10)
        } else {
          src = 'file://' + key
        }
        preloader.preload(key, src)
      }
    }
  }

  getInitial(name: string): string {
    if (name.length > 0) {
      return name.charAt(0).toUpperCase()
    }
    return 'W'
  }

  getSourceColor(sourceType: string): string {
    if (sourceType === SourceType.PRESET) {
      return AppColors.SUCCESS
    }
    if (sourceType === SourceType.DIRECTORY) {
      return AppColors.WARNING
    }
    return AppColors.PRIMARY
  }

  getSourceLabel(sourceType: string): string {
    if (sourceType === SourceType.PRESET) {
      return '预设'
    }
    if (sourceType === SourceType.DIRECTORY) {
      return '目录'
    }
    return '文件'
  }

  navigateToImport(): void {
    this.navPathStack.pushPath({ name: 'ImportPage' })
  }

  openViewer(item: WebAppItem): void {
    const param: ViewerParam = { entryHtml: item.entryHtml, appName: item.name }
    this.navPathStack.pushPath({ name: 'ViewerPage', param: param })
  }

  confirmDelete(item: WebAppItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除确认',
      message: '确定要删除「' + item.name + '」吗？',
      primaryButton: {
        value: '删除',
        action: () => {
          this.deleteApp(item)
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  async deleteApp(item: WebAppItem): Promise<void> {
    if (!this.storageMgr) {
      return
    }
    await this.storageMgr.remove(item.id)
    if (item.entryHtml.startsWith('rawfile://')) {
    } else {
      if (item.sourceType === SourceType.DIRECTORY) {
        const dirPath = item.entryHtml.substring(0, item.entryHtml.lastIndexOf('/'))
        try {
          fs.accessSync(dirPath)
          this.deleteDirectory(dirPath)
        } catch (e) {
          console.error('deleteApp directory not found: ' + dirPath)
        }
      } else {
        try {
          fs.accessSync(item.entryHtml)
          fs.unlinkSync(item.entryHtml)
        } catch (e) {
          console.error('deleteApp file delete failed: ' + item.entryHtml)
        }
      }
    }
    this.dataChanged = true
    await this.loadApps()
    try {
      this.getUIContext().getPromptAction().showToast({ message: '已删除' })
    } catch (e) {
      console.error('showToast failed')
    }
  }

  private deleteDirectory(dirPath: string): void {
    try {
      const stack: string[] = [dirPath]
      const filesToDelete: string[] = []

      while (stack.length > 0) {
        const currentDir = stack.pop()!
        const entries = fs.listFileSync(currentDir)

        for (let i = 0; i < entries.length; i++) {
          const entry = entries[i]
          const fullPath = currentDir + '/' + entry
          const stat = fs.statSync(fullPath)
          if (stat.isDirectory()) {
            stack.push(fullPath)
          } else {
            filesToDelete.push(fullPath)
          }
        }
      }

      for (let i = filesToDelete.length - 1; i >= 0; i--) {
        fs.unlinkSync(filesToDelete[i])
      }

      const dirsToDelete: string[] = [dirPath]
      const tempStack: string[] = [dirPath]
      while (tempStack.length > 0) {
        const currentDir = tempStack.pop()!
        const entries = fs.listFileSync(currentDir)
        for (let i = 0; i < entries.length; i++) {
          const entry = entries[i]
          const fullPath = currentDir + '/' + entry
          const stat = fs.statSync(fullPath)
          if (stat.isDirectory()) {
            dirsToDelete.push(fullPath)
            tempStack.push(fullPath)
          }
        }
      }

      for (let i = dirsToDelete.length - 1; i >= 0; i--) {
        fs.rmdirSync(dirsToDelete[i])
      }
    } catch (e) {
      console.error('deleteDirectory failed: ' + dirPath)
    }
  }

  @Builder
  CardItem(item: WebAppItem) {
    Row() {
      if (item.logoType === LogoType.CUSTOM && item.logoUri.length > 0) {
        Image(item.logoUri)
          .width(56)
          .height(56)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
      } else {
        Stack() {
          Text(this.getInitial(item.name))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(56)
        .height(56)
        .borderRadius(12)
        .linearGradient({
          angle: 135,
          colors: [[AppColors.PRIMARY, 0.0], [AppColors.PRIMARY_DARK, 1.0]]
        })
        .alignContent(Alignment.Center)
      }

      Column() {
        Row() {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)

          Text(this.getSourceLabel(item.sourceType))
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor(this.getSourceColor(item.sourceType))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        if (item.description.length > 0) {
          Text(item.description)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(Color.White)
    .shadow({
      radius: 6,
      color: '#08000000',
      offsetX: 0,
      offsetY: 1
    })
    .onClick(() => {
      this.openViewer(item)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.confirmDelete(item)
        })
    )
  }

  @Builder
  Menus() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Row({ space: 4 }) {
          Text('＋')
            .fontSize(16)
            .fontColor(AppColors.PRIMARY)
          Text('导入')
            .fontSize(13)
            .fontColor(AppColors.PRIMARY)
        }
      }
      .height(32)
      .borderRadius(6)
      .onClick(() => {
        this.navigateToImport()
      })
    }
    .height('100%')
    .padding({ right: 8 })
  }

  @Builder
  buildNavDestination(name: string) {
    if (name === 'ImportPage') {
      ImportPage()
    } else if (name === 'ViewerPage') {
      ViewerPage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        if (this.appList.length === 0) {
          Column() {
            Text('暂无应用')
              .fontSize(16)
              .fontColor(AppColors.TEXT_MUTED)
            Text('点击右上角「导入」添加 HTML 应用')
              .fontSize(13)
              .fontColor(AppColors.TEXT_DISABLED)
              .margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 12 }) {
            ForEach(this.appList, (item: WebAppItem) => {
              ListItem() {
                this.CardItem(item)
              }
            }, (item: WebAppItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12, bottom: 16 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .backgroundColor(AppColors.BACKGROUND)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BACKGROUND)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
    .title('WebBoard')
    .menus(this.Menus)
    .navDestination(this.buildNavDestination)
  }
}
