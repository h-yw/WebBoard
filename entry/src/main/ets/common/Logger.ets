export class Logger {
  private static readonly TAG: string = 'WebLeaf'

  static debug(tag: string, msg: string): void {
    console.debug(Logger.TAG + ' [' + tag + '] ' + msg)
  }

  static info(tag: string, msg: string): void {
    console.info(Logger.TAG + ' [' + tag + '] ' + msg)
  }

  static warn(tag: string, msg: string): void {
    console.warn(Logger.TAG + ' [' + tag + '] ' + msg)
  }

  static error(tag: string, msg: string): void {
    console.error(Logger.TAG + ' [' + tag + '] ' + msg)
  }
}
