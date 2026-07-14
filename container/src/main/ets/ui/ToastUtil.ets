import { Logger } from '../common/Logger';

export class Toast {
  private static uiContext: UIContext | null = null

  static setUIContext(uiContext: UIContext): void {
    Toast.uiContext = uiContext
  }

  static show(message: string | Resource, duration?: number): void {
    try {
      if (Toast.uiContext) {
        Toast.uiContext.getPromptAction().showToast({
          message: message,
          duration: duration ?? 1500
        })
      } else {
        Logger.warn('Toast', 'UIContext not set')
      }
    } catch (e) {
      Logger.error('Toast', 'show failed: ' + JSON.stringify(e))
    }
  }

  static success(message: string | Resource): void {
    Toast.show(message, 1500)
  }

  static error(message: string | Resource): void {
    Toast.show(message, 2000)
  }
}
