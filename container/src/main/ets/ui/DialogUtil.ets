import { ComponentContent } from '@kit.ArkUI';
import { Logger } from '../common/Logger';

export interface DialogOption {
  title: string | Resource;
  message: string | Resource;
  confirmText?: string | Resource;
  cancelText?: string | Resource;
  onConfirm?: () => void;
  onCancel?: () => void;
}

interface DialogContentProps {
  title: string
  message: string
  confirmText: string
  cancelText: string
  isAlert: boolean
  onConfirm: (() => void) | null
  onCancel: (() => void) | null
  onClose: (() => void) | null
}

/**
 * DialogContent is the @Component struct used to render dialog content.
 * It receives props via @Prop and handles button click events internally.
 */
@Component
struct DialogContent {
  @Prop dialogTitle: string = ''
  @Prop dialogMessage: string = ''
  @Prop confirmText: string = '确定'
  @Prop cancelText: string = '取消'
  @Prop isAlert: boolean = false
  onConfirmAction: (() => void) | null = null
  onCancelAction: (() => void) | null = null
  closeDialogAction: (() => void) | null = null

  build() {
    Column({ space: 16 }) {
      if (this.dialogTitle.length > 0) {
        Text(this.dialogTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_primary'))
          .textAlign(TextAlign.Center)
          .width('100%');
      }
      Text(this.dialogMessage)
        .fontSize(15)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.Center)
        .width('100%');

      Row({ space: 12 }) {
        if (!this.isAlert) {
          Button(this.cancelText)
            .height(40)
            .borderRadius(8)
            .width(100)
            .fontSize(15)
            .fontColor($r('app.color.app_text_secondary'))
            .backgroundColor($r('app.color.app_card_bg'))
            .border({ width: 1, color: $r('app.color.app_border') })
            .onClick(() => {
              if (this.onCancelAction) {
                this.onCancelAction();
              }
              if (this.closeDialogAction) {
                this.closeDialogAction();
              }
            });
        }
        Button(this.confirmText)
          .height(40)
          .borderRadius(8)
          .width(100)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.app_primary'))
          .onClick(() => {
            if (this.onConfirmAction) {
              this.onConfirmAction();
            }
            if (this.closeDialogAction) {
              this.closeDialogAction();
            }
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);
    }
    .padding({ left: 24, right: 24, top: 20, bottom: 20 })
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }
}

@Builder
function DialogContentBuilder(params: DialogContentProps) {
  DialogContent({
    dialogTitle: params.title,
    dialogMessage: params.message,
    confirmText: params.confirmText,
    cancelText: params.cancelText,
    isAlert: params.isAlert,
    onConfirmAction: params.onConfirm,
    onCancelAction: params.onCancel,
    closeDialogAction: params.onClose
  })
}

export class Dialog {
  private static uiContext: UIContext | null = null

  /**
   * Initialize Dialog with a UIContext. Must be called before confirm()/alert().
   * Typically called from Index.ets aboutToAppear().
   */
  static setUIContext(uiContext: UIContext): void {
    Dialog.uiContext = uiContext
  }

  static confirm(option: DialogOption): void {
    if (!Dialog.uiContext) {
      Logger.error('DialogUtil', 'Dialog not initialized - call Dialog.setUIContext() first')
      return
    }

    const title: string = typeof option.title === 'string' ? option.title : ''
    const message: string = typeof option.message === 'string' ? option.message : ''
    const confirmText: string = typeof option.confirmText === 'string' ? option.confirmText : '确定'
    const cancelText: string = typeof option.cancelText === 'string' ? option.cancelText : '取消'

    const props: DialogContentProps = {
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isAlert: false,
      onConfirm: option.onConfirm ?? null,
      onCancel: option.onCancel ?? null,
      onClose: null
    }

    try {
      const promptActionInstance = Dialog.uiContext!.getPromptAction()
      const content: ComponentContent<DialogContentProps> = new ComponentContent(
        Dialog.uiContext!,
        wrapBuilder(DialogContentBuilder),
        props
      )
      props.onClose = (): void => {
        try {
          promptActionInstance.closeCustomDialog(content)
        } catch (e) {
          Logger.error('DialogUtil', 'closeDialog failed: ' + JSON.stringify(e))
        }
      }
      content.update(props)
      promptActionInstance.openCustomDialog(content).catch((e: Error) => {
        Logger.error('DialogUtil', 'confirm failed: ' + JSON.stringify(e));
      })
    } catch (e) {
      Logger.error('DialogUtil', 'confirm failed: ' + JSON.stringify(e));
    }
  }

  static alert(option: DialogOption): void {
    if (!Dialog.uiContext) {
      Logger.error('DialogUtil', 'Dialog not initialized - call Dialog.setUIContext() first')
      return
    }

    const title: string = typeof option.title === 'string' ? option.title : ''
    const message: string = typeof option.message === 'string' ? option.message : ''
    const confirmText: string = typeof option.confirmText === 'string' ? option.confirmText : '确定'

    const props: DialogContentProps = {
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: '',
      isAlert: true,
      onConfirm: option.onConfirm ?? null,
      onCancel: null,
      onClose: null
    }

    try {
      const promptActionInstance = Dialog.uiContext!.getPromptAction()
      const content: ComponentContent<DialogContentProps> = new ComponentContent(
        Dialog.uiContext!,
        wrapBuilder(DialogContentBuilder),
        props
      )
      props.onClose = (): void => {
        try {
          promptActionInstance.closeCustomDialog(content)
        } catch (e) {
          Logger.error('DialogUtil', 'closeDialog failed: ' + JSON.stringify(e))
        }
      }
      content.update(props)
      promptActionInstance.openCustomDialog(content).catch((e: Error) => {
        Logger.error('DialogUtil', 'alert failed: ' + JSON.stringify(e));
      })
    } catch (e) {
      Logger.error('DialogUtil', 'alert failed: ' + JSON.stringify(e));
    }
  }
}
