import { FormExtensionAbility, formBindingData } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { Logger } from 'container'

export default class AppFormCardAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    try {
      const formData: Record<string, string> = {
        'appName': '浮叶',
        'appCount': '0'
      }
      return formBindingData.createFormBindingData(formData)
    } catch (e) {
      Logger.error('FormAbility', 'onAddForm error: ' + JSON.stringify(e))
      return formBindingData.createFormBindingData({})
    }
  }

  onRemoveForm(formId: string): void {
    Logger.debug('FormAbility', 'onRemoveForm: ' + formId)
  }

  onUpdateForm(formId: string): void {
    Logger.debug('FormAbility', 'onUpdateForm: ' + formId)
  }

  onCastTempToNormalForm(formId: string): void {
    Logger.debug('FormAbility', 'onCastTempToNormal: ' + formId)
  }

  onEvent(formId: string, message: string): void {
    Logger.debug('FormAbility', 'onEvent: ' + formId + ' msg: ' + message)
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    Logger.debug('FormAbility', 'onChangeVisibility: ' + JSON.stringify(newStatus))
  }
}
