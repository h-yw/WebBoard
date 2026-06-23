export enum SourceType {
  PRESET = 'preset',
  FILE = 'file',
  DIRECTORY = 'directory'
}

export enum LogoType {
  INITIAL = 'initial',
  CUSTOM = 'custom'
}

export interface AppColorsInterface {
  PRIMARY: string
  PRIMARY_DARK: string
  SUCCESS: string
  WARNING: string
  BACKGROUND: string
  CARD_BG: string
  TEXT_PRIMARY: string
  TEXT_SECONDARY: string
  TEXT_MUTED: string
  TEXT_DISABLED: string
  BORDER: string
  DIVIDER: string
}

export const AppColors: AppColorsInterface = {
  PRIMARY: '#6366F1',
  PRIMARY_DARK: '#8B5CF6',
  SUCCESS: '#10B981',
  WARNING: '#F59E0B',
  BACKGROUND: '#F1F5F9',
  CARD_BG: '#F8FAFC',
  TEXT_PRIMARY: '#0F172A',
  TEXT_SECONDARY: '#64748B',
  TEXT_MUTED: '#94A3B8',
  TEXT_DISABLED: '#CBD5E1',
  BORDER: '#E2E8F0',
  DIVIDER: '#E2E8F0'
}

export interface StorageConstantsInterface {
  STORE_NAME: string
  KEY_WEB_APPS: string
}

export const StorageConstants: StorageConstantsInterface = {
  STORE_NAME: 'webboard_store',
  KEY_WEB_APPS: 'web_apps'
}

export interface WebBoardConstantsInterface {
  DIR_NAME: string
  MAX_PRELOAD: number
  MAX_RECENT: number
  MAX_DESCRIPTION_LENGTH: number
}

export const WebBoardConstants: WebBoardConstantsInterface = {
  DIR_NAME: 'webboard',
  MAX_PRELOAD: 3,
  MAX_RECENT: 5,
  MAX_DESCRIPTION_LENGTH: 100
}
