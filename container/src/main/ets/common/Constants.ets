export enum SourceType {
  PRESET = 'preset',
  FILE = 'file',
  URL = 'url'
}

export enum LogoType {
  INITIAL = 'initial',
  CUSTOM = 'custom'
}

export enum ColorMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export enum LayoutMode {
  GRID = 'grid',
  LIST = 'list'
}

export interface WebBoardConstantsInterface {
  DIR_NAME: string
  MAX_PRELOAD: number
  MAX_RECENT: number
  MAX_DESCRIPTION_LENGTH: number
}

export const WebBoardConstants: WebBoardConstantsInterface = {
  DIR_NAME: 'webboard',
  MAX_PRELOAD: 5,
  MAX_RECENT: 5,
  MAX_DESCRIPTION_LENGTH: 100
}
