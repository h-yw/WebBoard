import { promptAction } from '@kit.ArkUI';
import { Logger } from '../common/Logger';

export interface DialogOption {
  title: string | Resource;
  message: string | Resource;
  confirmText?: string | Resource;
  cancelText?: string | Resource;
  onConfirm?: () => void;
  onCancel?: () => void;
}

let currentDialogId: number = -1;

interface DialogState {
  title: string;
  message: string;
  confirmText: string;
  cancelText: string;
  isAlert: boolean;
  onConfirm: (() => void) | null;
  onCancel: (() => void) | null;
}

let dialogState: DialogState = {
  title: '',
  message: '',
  confirmText: '确定',
  cancelText: '取消',
  isAlert: false,
  onConfirm: null,
  onCancel: null
};

@Builder
function DialogContentBuilder() {
  Column({ space: 16 }) {
    if (dialogState.title.length > 0) {
      Text(dialogState.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.app_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%');
    }
    Text(dialogState.message)
      .fontSize(15)
      .fontColor($r('app.color.app_text_secondary'))
      .textAlign(TextAlign.Center)
      .width('100%');

    Row({ space: 12 }) {
      if (!dialogState.isAlert) {
        Button(dialogState.cancelText)
          .height(40)
          .borderRadius(8)
          .width(100)
          .fontSize(15)
          .fontColor($r('app.color.app_text_secondary'))
          .backgroundColor($r('app.color.app_card_bg'))
          .border({ width: 1, color: $r('app.color.app_border') })
          .onClick(() => {
            if (dialogState.onCancel) {
              dialogState.onCancel();
            }
            closeDialog();
          });
      }
      Button(dialogState.confirmText)
        .height(40)
        .borderRadius(8)
        .width(100)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.app_primary'))
        .onClick(() => {
          if (dialogState.onConfirm) {
            dialogState.onConfirm();
          }
          closeDialog();
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }
  .padding({ left: 24, right: 24, top: 20, bottom: 20 })
  .width('100%')
  .alignItems(HorizontalAlign.Center);
}

function closeDialog(): void {
  if (currentDialogId >= 0) {
    try {
      promptAction.closeCustomDialog(currentDialogId);
    } catch (e) {
      Logger.error('DialogUtil', 'closeDialog failed: ' + JSON.stringify(e));
    }
    currentDialogId = -1;
  }
}

export class Dialog {
  static confirm(option: DialogOption): void {
    dialogState.title = typeof option.title === 'string' ? option.title : '';
    dialogState.message = typeof option.message === 'string' ? option.message : '';
    dialogState.confirmText = typeof option.confirmText === 'string' ? option.confirmText : '确定';
    dialogState.cancelText = typeof option.cancelText === 'string' ? option.cancelText : '取消';
    dialogState.isAlert = false;
    dialogState.onConfirm = option.onConfirm ?? null;
    dialogState.onCancel = option.onCancel ?? null;

    try {
      promptAction.openCustomDialog({
        builder: (): void => {
          DialogContentBuilder()
        },
        autoCancel: false
      }).then((id: number) => {
        currentDialogId = id;
      }).catch((e: Error) => {
        Logger.error('DialogUtil', 'confirm failed: ' + JSON.stringify(e));
      });
    } catch (e) {
      Logger.error('DialogUtil', 'confirm failed: ' + JSON.stringify(e));
    }
  }

  static alert(option: DialogOption): void {
    dialogState.title = typeof option.title === 'string' ? option.title : '';
    dialogState.message = typeof option.message === 'string' ? option.message : '';
    dialogState.confirmText = typeof option.confirmText === 'string' ? option.confirmText : '确定';
    dialogState.cancelText = '';
    dialogState.isAlert = true;
    dialogState.onConfirm = option.onConfirm ?? null;
    dialogState.onCancel = null;

    try {
      promptAction.openCustomDialog({
        builder: (): void => {
          DialogContentBuilder()
        },
        autoCancel: false
      }).then((id: number) => {
        currentDialogId = id;
      }).catch((e: Error) => {
        Logger.error('DialogUtil', 'alert failed: ' + JSON.stringify(e));
      });
    } catch (e) {
      Logger.error('DialogUtil', 'alert failed: ' + JSON.stringify(e));
    }
  }
}
