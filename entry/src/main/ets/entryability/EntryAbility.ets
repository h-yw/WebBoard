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
import { window } from '@kit.ArkUI';
import { DatabaseManager, FileManager, ColorMode, Logger } from 'container';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('EntryAbility', 'onCreate')
    try {
      const dbMgr = DatabaseManager.getInstance(this.context)
      dbMgr.init().then(async () => {
        const mode = await dbMgr.getSetting('color_mode', ColorMode.SYSTEM)
        let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        if (mode === ColorMode.LIGHT) {
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        } else if (mode === ColorMode.DARK) {
          colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        }
        this.context.getApplicationContext().setColorMode(colorMode)

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
        Logger.error('EntryAbility', 'DB init failed: ' + JSON.stringify(err))
      })
    } catch (err) {
      Logger.error('EntryAbility', 'onCreate error: ' + JSON.stringify(err))
    }
  }

  onDestroy(): void {
    Logger.info('EntryAbility', 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Logger.info('EntryAbility', 'onWindowStageCreate')
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        Logger.error('EntryAbility', 'loadContent failed: ' + JSON.stringify(err))
        return
      }
      Logger.info('EntryAbility', 'loadContent success')
    })
  }

  onWindowStageDestroy(): void {
    Logger.info('EntryAbility', 'onWindowStageDestroy')
  }

  onForeground(): void {
    Logger.info('EntryAbility', 'onForeground')
  }

  onBackground(): void {
    Logger.info('EntryAbility', 'onBackground')
  }
}
