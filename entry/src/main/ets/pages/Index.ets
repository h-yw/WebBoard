import { WebAppItem } from '../model/WebAppItem'
import { AppDataSource } from '../model/AppDataSource'
import { StorageManager } from '../util/StorageManager'
import { WebPreloader } from '../util/WebPreloader'
import { WorkDirectory } from '../util/WorkDirectory'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ImportPage } from './ImportPage'
import { ViewerPage } from './ViewerPage'
import { EditPage } from './EditPage'
import { SettingsPage } from './SettingsPage'
import { LogoType, SourceType } from '../common/Constants'

interface ViewerParam {
  entryHtml: string
  appName: string
}

interface EditParam {
  appId: string
  appName: string
  appDescription: string
  logoType: string
  logoUri: string
  entryHtml: string
}

@Entry
@Component
struct Index {
  @State appList: WebAppItem[] = []
  @State searchKeyword: string = ''
  @State isRefreshing: boolean = false
  private dataSource: AppDataSource = new AppDataSource()
  private storageMgr: StorageManager | null = null
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack = new NavPathStack()
  private dataChanged: boolean = false

  getFilteredApps(): WebAppItem[] {
    if (!this.appList || this.appList.length === 0) {
      return []
    }
    if (this.searchKeyword.length === 0) {
      return this.appList
    }
    const keyword = this.searchKeyword.toLowerCase()
    const result: WebAppItem[] = []
    for (let i = 0; i < this.appList.length; i++) {
      const app = this.appList[i]
      if (app.name.toLowerCase().includes(keyword) ||
          app.description.toLowerCase().includes(keyword)) {
        result.push(app)
      }
    }
    return result
  }

  async aboutToAppear(): Promise<void> {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.storageMgr = new StorageManager(this.context)
    WorkDirectory.ensureDirectory(this.context)
    
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
      this.dataSource.setApps(this.getFilteredApps())
    }
  }

  async scanWorkDirectory(): Promise<void> {
    if (!this.context || !this.storageMgr) {
      this.isRefreshing = false
      return
    }

    const existingItems = await this.storageMgr.getAll()
    const scannedItems = WorkDirectory.scanDirectory(this.context)

    const existingPaths = new Set<string>()
    for (let i = 0; i < existingItems.length; i++) {
      existingPaths.add(existingItems[i].entryHtml)
    }

    let hasNew = false
    for (let i = 0; i < scannedItems.length; i++) {
      if (!existingPaths.has(scannedItems[i].entryHtml)) {
        await this.storageMgr.add(scannedItems[i])
        hasNew = true
      }
    }

    if (hasNew) {
      await this.loadApps()
    }

    this.isRefreshing = false
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

  getSourceColor(sourceType: string): Resource {
    if (sourceType === SourceType.PRESET) {
      return $r('app.color.app_success')
    }
    if (sourceType === SourceType.DIRECTORY) {
      return $r('app.color.app_warning')
    }
    return $r('app.color.app_primary')
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

  navigateToEdit(item: WebAppItem): void {
    const param: EditParam = {
      appId: item.id,
      appName: item.name,
      appDescription: item.description,
      logoType: item.logoType,
      logoUri: item.logoUri,
      entryHtml: item.entryHtml
    }
    this.navPathStack.pushPath({ name: 'EditPage', param: param })
  }

  showActionSheet(item: WebAppItem): void {
    this.getUIContext().showAlertDialog({
      title: '操作',
      message: '请选择要执行的操作',
      buttons: [
        {
          value: '编辑',
          action: () => {
            this.navigateToEdit(item)
          }
        },
        {
          value: '删除',
          action: () => {
            this.confirmDelete(item)
          }
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    })
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
  SearchBar() {
    Row() {
      Text('🔍')
        .fontSize(16)
        .fontColor($r('app.color.app_text_muted'))
      TextInput({ placeholder: '搜索应用...', text: this.searchKeyword })
        .fontSize(14)
        .height(36)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchKeyword = value
          this.dataSource.setApps(this.getFilteredApps())
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.app_search_bg'))
    .borderRadius(8)
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
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
          colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
        })
        .alignContent(Alignment.Center)
      }

      Column() {
        Row() {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.app_text_primary'))
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
            .fontColor($r('app.color.app_text_secondary'))
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
    .backgroundColor($r('app.color.app_card_bg'))
    .shadow({
      radius: 6,
      color: $r('app.color.app_shadow'),
      offsetX: 0,
      offsetY: 1
    })
    .onClick(() => {
      this.openViewer(item)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.showActionSheet(item)
        })
    )
  }

  @Builder
  Menus() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Text('⚙️')
          .fontSize(16)
      }
      .height(32)
      .borderRadius(6)
      .onClick(() => {
        this.navPathStack.pushPath({ name: 'SettingsPage' })
      })

      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Row({ space: 4 }) {
          Text('＋')
            .fontSize(16)
            .fontColor($r('app.color.app_primary'))
          Text('导入')
            .fontSize(13)
            .fontColor($r('app.color.app_primary'))
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
    } else if (name === 'EditPage') {
      EditPage()
    } else if (name === 'SettingsPage') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        this.SearchBar()

        if (this.getFilteredApps().length === 0) {
          Column() {
            Text(this.searchKeyword.length > 0 ? '未找到匹配的应用' : '暂无应用')
              .fontSize(16)
              .fontColor($r('app.color.app_text_muted'))
            Text(this.searchKeyword.length > 0 ? '请尝试其他关键词' : '点击右上角「导入」添加 HTML 应用')
              .fontSize(13)
              .fontColor($r('app.color.app_text_disabled'))
              .margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 12 }) {
              LazyForEach(this.dataSource, (item: WebAppItem) => {
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
          }
          .onRefreshing(() => {
            this.scanWorkDirectory()
          })
          .backgroundColor($r('app.color.app_background'))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
    .title('WebBoard')
    .menus(this.Menus)
    .navDestination(this.buildNavDestination)
  }
}
