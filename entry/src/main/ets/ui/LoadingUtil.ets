import { promptAction } from '@kit.ArkUI';
import { Logger } from '../common/Logger';

let currentLoadingId: number = -1;
let isShowing: boolean = false;
let loadingMessage: string = '';

@Builder
function LoadingContentBuilder() {
  Column({ space: 16 }) {
    LoadingProgress()
      .width(40)
      .height(40)
      .color($r('app.color.app_primary'));
    if (loadingMessage.length > 0) {
      Text(loadingMessage)
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.Center);
    }
  }
  .padding({ left: 32, right: 32, top: 24, bottom: 24 })
  .alignItems(HorizontalAlign.Center);
}

export class Loading {
  static show(message?: string): void {
    if (isShowing) {
      return;
    }
    loadingMessage = message ?? '';
    try {
      promptAction.openCustomDialog({
        builder: (): void => {
          LoadingContentBuilder()
        },
        customStyle: false,
        autoCancel: false
      }).then((id: number) => {
        currentLoadingId = id;
        isShowing = true;
      }).catch((e: Error) => {
        Logger.error('LoadingUtil', 'show failed: ' + JSON.stringify(e));
      });
    } catch (e) {
      Logger.error('LoadingUtil', 'show failed: ' + JSON.stringify(e));
    }
  }

  static hide(): void {
    if (!isShowing || currentLoadingId < 0) {
      return;
    }
    try {
      promptAction.closeCustomDialog(currentLoadingId);
    } catch (e) {
      Logger.error('LoadingUtil', 'hide failed: ' + JSON.stringify(e));
    }
    currentLoadingId = -1;
    isShowing = false;
    loadingMessage = '';
  }
}
