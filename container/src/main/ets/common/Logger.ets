import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0000
const TAG: string = 'WebLeaf'

export class Logger {
  static debug(tag: string, msg: string): void {
    hilog.debug(DOMAIN, TAG, '[%{public}s] %{public}s', tag, msg)
  }

  static info(tag: string, msg: string): void {
    hilog.info(DOMAIN, TAG, '[%{public}s] %{public}s', tag, msg)
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(DOMAIN, TAG, '[%{public}s] %{public}s', tag, msg)
  }

  static error(tag: string, msg: string): void {
    hilog.error(DOMAIN, TAG, '[%{public}s] %{public}s', tag, msg)
  }
}
