import { LogoType, SourceType } from '../common/Constants'

export interface WebAppRecord {
  id: string
  name: string
  description: string
  logo_type: string
  logo_uri: string
  entry_html: string
  source_type: string
  create_time: number
  persist_uri: string
  persist_mode: string
}

export class WebAppItem {
  id: string = ''
  name: string = ''
  description: string = ''
  logoType: string = LogoType.INITIAL
  logoUri: string = ''
  entryHtml: string = ''
  sourceType: string = SourceType.FILE
  createTime: number = 0
  persistUri: string = ''
  persistMode: string = ''

  static fromRecord(obj: WebAppRecord): WebAppItem {
    const item = new WebAppItem()
    item.id = typeof obj.id === 'string' ? obj.id : ''
    item.name = typeof obj.name === 'string' ? obj.name : ''
    item.description = typeof obj.description === 'string' ? obj.description : ''
    item.logoType = typeof obj.logo_type === 'string' ? obj.logo_type : LogoType.INITIAL
    item.logoUri = typeof obj.logo_uri === 'string' ? obj.logo_uri : ''
    item.entryHtml = typeof obj.entry_html === 'string' ? obj.entry_html : ''
    item.sourceType = typeof obj.source_type === 'string' ? obj.source_type : SourceType.FILE
    item.createTime = typeof obj.create_time === 'number' ? obj.create_time : 0
    item.persistUri = typeof obj.persist_uri === 'string' ? obj.persist_uri : ''
    item.persistMode = typeof obj.persist_mode === 'string' ? obj.persist_mode : ''
    return item
  }
}
