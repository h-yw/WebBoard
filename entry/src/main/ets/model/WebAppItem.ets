import { LogoType, SourceType } from '../common/Constants'

export class WebAppItem {
  id: string = ''
  name: string = ''
  description: string = ''
  logoType: string = LogoType.INITIAL
  logoUri: string = ''
  entryHtml: string = ''
  sourceType: string = SourceType.FILE
  createTime: number = 0

  static fromRecord(obj: Record<string, Object>): WebAppItem {
    const item = new WebAppItem()
    item.id = typeof obj['id'] === 'string' ? obj['id'] : ''
    item.name = typeof obj['name'] === 'string' ? obj['name'] : ''
    item.description = typeof obj['description'] === 'string' ? obj['description'] : ''
    item.logoType = typeof obj['logoType'] === 'string' ? obj['logoType'] : LogoType.INITIAL
    item.logoUri = typeof obj['logoUri'] === 'string' ? obj['logoUri'] : ''
    item.entryHtml = typeof obj['entryHtml'] === 'string' ? obj['entryHtml'] : ''
    item.sourceType = typeof obj['sourceType'] === 'string' ? obj['sourceType'] : SourceType.FILE
    item.createTime = typeof obj['createTime'] === 'number' ? obj['createTime'] : 0
    return item
  }
}
