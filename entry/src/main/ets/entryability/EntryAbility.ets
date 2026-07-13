/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../database/DatabaseManager';
import { FileManager } from '../util/FileManager';
import { ColorMode } from '../common/Constants';
import { Logger } from '../common/Logger';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    try {
      const dbMgr = DatabaseManager.getInstance(this.context)
      dbMgr.init().then(async () => {
        // Restore color mode from settings
        const mode = await dbMgr.getSetting('color_mode', ColorMode.SYSTEM)
        let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        if (mode === ColorMode.LIGHT) {
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        } else if (mode === ColorMode.DARK) {
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        }
        this.context.getApplicationContext().setColorMode(colorMode)

        // Activate persisted permissions for file access
        const apps = await dbMgr.getAllApps()
        const persistUris: string[] = []
        for (let i = 0; i < apps.length; i++) {
          if (apps[i].persistUri.length > 0) {
            persistUris.push(apps[i].persistUri)
          }
        }
        if (persistUris.length > 0) {
          try {
            FileManager.activatePermissions(persistUris)
          } catch (e) {
            Logger.error('EntryAbility', 'activatePermissions failed: ' + JSON.stringify(e))
          }
        }
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to init DB. Cause: %{public}s', JSON.stringify(err));
      })
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init DB. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // SplashPage is loaded as the entry point. It has its own NavPathStack
    // and handles navigation to Index internally via Navigation + replacePath.
    // This eliminates the deprecated router.replaceUrl() API and keeps
    // the navigation architecture consistent across the app.
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}