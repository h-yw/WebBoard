import { promptAction } from '@kit.ArkUI';
import { Logger } from '../common/Logger';

export class Toast {
  static show(message: string | Resource, duration?: number): void {
    try {
      promptAction.showToast({
        message: message,
        duration: duration ?? 1500
      });
    } catch (e) {
      Logger.error('Toast', 'show failed: ' + JSON.stringify(e));
    }
  }

  static success(message: string | Resource): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 1500
      });
    } catch (e) {
      Logger.error('Toast', 'success failed: ' + JSON.stringify(e));
    }
  }

  static error(message: string | Resource): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 2000
      });
    } catch (e) {
      Logger.error('Toast', 'error failed: ' + JSON.stringify(e));
    }
  }
}
