import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from '../model/AiphoneLogger';
import {
  PreferencesNavigationCardSnapshotStore,
  buildNavigationCardBindingData,
  navigationCardFormEventFromMessage
} from '../model/NavigationCardSnapshot';

function textParam(want: Want, key: string): string {
  if (want.parameters === undefined || want.parameters === null) {
    return '';
  }
  const value = want.parameters[key];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function errorCodeOf(error: BusinessError): string {
  return error.code === undefined || error.code === null ? 'unknown' : error.code.toString();
}

export default class NavigationCardFormExtensionAbility extends FormExtensionAbility {
  private store(): PreferencesNavigationCardSnapshotStore {
    return new PreferencesNavigationCardSnapshotStore(this.context);
  }

  private bindingData(): formBindingData.FormBindingData {
    const snapshot = this.store().getSnapshotSync();
    return formBindingData.createFormBindingData(buildNavigationCardBindingData(snapshot, Date.now()));
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = textParam(want, formInfo.FormParam.IDENTITY_KEY);
    if (formId.length > 0) {
      this.store().addFormIdSync(formId);
    }
    aiLogInfo('[AIPhone][NavigationCardFormAdd] formId=' + formId);
    return this.bindingData();
  }

  onCastToNormalForm(formId: string): void {
    this.store().addFormIdSync(formId);
    aiLogInfo('[AIPhone][NavigationCardFormCastNormal] formId=' + formId);
  }

  onUpdateForm(formId: string): void {
    const binding = this.bindingData();
    formProvider.updateForm(formId, binding).then(() => {
      aiLogInfo('[AIPhone][NavigationCardFormUpdate] formId=' + formId + ' ok=true');
    }).catch((error: BusinessError) => {
      aiLogError('[AIPhone][NavigationCardFormUpdate] formId=' + formId +
        ' ok=false code=' + errorCodeOf(error) + ' message=' + error.message);
    });
  }

  onFormEvent(formId: string, message: string): void {
    const event = navigationCardFormEventFromMessage(message);
    aiLogInfo('[AIPhone][NavigationCardFormEvent] formId=' + formId + ' event=' + event);
    if (event === 'refresh' || event === 'open_map' || event === 'open_agent') {
      this.onUpdateForm(formId);
    }
  }

  onRemoveForm(formId: string): void {
    this.store().removeFormIdSync(formId);
    aiLogInfo('[AIPhone][NavigationCardFormRemove] formId=' + formId);
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
