import { relationalStore } from '@kit.ArkData';
import { WebAppItem, WebAppRecord } from '../model/WebAppItem';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

const DB_NAME = 'webboard.db';
const DB_VERSION = 1;

const CREATE_TABLE_WEB_APPS: string =
  'CREATE TABLE IF NOT EXISTS web_apps (' +
  'id TEXT PRIMARY KEY, ' +
  'name TEXT NOT NULL, ' +
  'description TEXT DEFAULT \'\', ' +
  'logo_type TEXT DEFAULT \'initial\', ' +
  'logo_uri TEXT DEFAULT \'\', ' +
  'entry_html TEXT NOT NULL, ' +
  'source_type TEXT DEFAULT \'file\', ' +
  'create_time INTEGER NOT NULL, ' +
  'persist_uri TEXT DEFAULT \'\', ' +
  'persist_mode TEXT DEFAULT \'\')';

const CREATE_TABLE_SETTINGS: string =
  'CREATE TABLE IF NOT EXISTS settings (' +
  'key TEXT PRIMARY KEY, ' +
  'value TEXT NOT NULL)';

export class DatabaseManager {
  private static instance: DatabaseManager | null = null;
  private rdbStore: relationalStore.RdbStore | null = null;
  private initPromise: Promise<void> | null = null;
  private context: Context;

  private constructor(context: Context) {
    this.context = context;
  }

  static getInstance(context: Context): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager(context);
    }
    return DatabaseManager.instance;
  }

  async init(): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.createDatabase();
    }
    await this.initPromise;
  }

  private async createDatabase(): Promise<void> {
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      this.rdbStore = await relationalStore.getRdbStore(this.context, config);
      await this.rdbStore.executeSql(CREATE_TABLE_WEB_APPS);
      await this.rdbStore.executeSql(CREATE_TABLE_SETTINGS);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'init failed: ' + err.code + ' ' + err.message);
      this.initPromise = null;
      throw new Error('DatabaseManager init failed: ' + err.code + ' ' + err.message);
    }
  }

  private async ensureReady(): Promise<void> {
    await this.init();
    if (!this.rdbStore) {
      throw new Error('DatabaseManager not initialized');
    }
  }

  // --- web_apps CRUD ---

  async getAllApps(): Promise<WebAppItem[]> {
    await this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates('web_apps');
      predicates.orderByDesc('create_time');
      const resultSet = await this.rdbStore!.query(predicates, [
        'id', 'name', 'description', 'logo_type', 'logo_uri',
        'entry_html', 'source_type', 'create_time', 'persist_uri', 'persist_mode'
      ]);
      const items: WebAppItem[] = [];
      while (resultSet.goToNextRow()) {
        const item = WebAppItem.fromRecord({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          logo_type: resultSet.getString(resultSet.getColumnIndex('logo_type')),
          logo_uri: resultSet.getString(resultSet.getColumnIndex('logo_uri')),
          entry_html: resultSet.getString(resultSet.getColumnIndex('entry_html')),
          source_type: resultSet.getString(resultSet.getColumnIndex('source_type')),
          create_time: resultSet.getLong(resultSet.getColumnIndex('create_time')),
          persist_uri: resultSet.getString(resultSet.getColumnIndex('persist_uri')),
          persist_mode: resultSet.getString(resultSet.getColumnIndex('persist_mode'))
        });
        items.push(item);
      }
      resultSet.close();
      return items;
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'getAllApps failed: ' + err.code + ' ' + err.message);
      return [];
    }
  }

  async getAppById(id: string): Promise<WebAppItem | null> {
    await this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates('web_apps');
      predicates.equalTo('id', id);
      const resultSet = await this.rdbStore!.query(predicates, [
        'id', 'name', 'description', 'logo_type', 'logo_uri',
        'entry_html', 'source_type', 'create_time', 'persist_uri', 'persist_mode'
      ]);
      let item: WebAppItem | null = null;
      if (resultSet.goToFirstRow()) {
        item = WebAppItem.fromRecord({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          logo_type: resultSet.getString(resultSet.getColumnIndex('logo_type')),
          logo_uri: resultSet.getString(resultSet.getColumnIndex('logo_uri')),
          entry_html: resultSet.getString(resultSet.getColumnIndex('entry_html')),
          source_type: resultSet.getString(resultSet.getColumnIndex('source_type')),
          create_time: resultSet.getLong(resultSet.getColumnIndex('create_time')),
          persist_uri: resultSet.getString(resultSet.getColumnIndex('persist_uri')),
          persist_mode: resultSet.getString(resultSet.getColumnIndex('persist_mode'))
        });
      }
      resultSet.close();
      return item;
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'getAppById failed: ' + err.code + ' ' + err.message);
      return null;
    }
  }

  async addApp(item: WebAppItem): Promise<void> {
    await this.ensureReady();
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': item.id,
        'name': item.name,
        'description': item.description,
        'logo_type': item.logoType,
        'logo_uri': item.logoUri,
        'entry_html': item.entryHtml,
        'source_type': item.sourceType,
        'create_time': item.createTime,
        'persist_uri': item.persistUri,
        'persist_mode': item.persistMode
      };
      await this.rdbStore!.insert('web_apps', valueBucket);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'addApp failed: ' + err.code + ' ' + err.message);
      throw new Error('DatabaseManager addApp failed: ' + err.code + ' ' + err.message);
    }
  }

  async updateApp(item: WebAppItem): Promise<void> {
    await this.ensureReady();
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'name': item.name,
        'description': item.description,
        'logo_type': item.logoType,
        'logo_uri': item.logoUri,
        'entry_html': item.entryHtml,
        'source_type': item.sourceType,
        'create_time': item.createTime,
        'persist_uri': item.persistUri,
        'persist_mode': item.persistMode
      };
      const predicates = new relationalStore.RdbPredicates('web_apps');
      predicates.equalTo('id', item.id);
      await this.rdbStore!.update(valueBucket, predicates);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'updateApp failed: ' + err.code + ' ' + err.message);
      throw new Error('DatabaseManager updateApp failed: ' + err.code + ' ' + err.message);
    }
  }

  async deleteApp(id: string): Promise<void> {
    await this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates('web_apps');
      predicates.equalTo('id', id);
      await this.rdbStore!.delete(predicates);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'deleteApp failed: ' + err.code + ' ' + err.message);
      throw new Error('DatabaseManager deleteApp failed: ' + err.code + ' ' + err.message);
    }
  }

  // --- settings CRUD ---

  async getSetting(key: string, defaultVal: string): Promise<string> {
    await this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates('settings');
      predicates.equalTo('key', key);
      const resultSet = await this.rdbStore!.query(predicates, ['key', 'value']);
      let value = defaultVal;
      if (resultSet.goToFirstRow()) {
        value = resultSet.getString(resultSet.getColumnIndex('value'));
      }
      resultSet.close();
      return value;
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'getSetting failed: ' + err.code + ' ' + err.message);
      return defaultVal;
    }
  }

  async setSetting(key: string, value: string): Promise<void> {
    await this.ensureReady();
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'key': key,
        'value': value
      };
      const predicates = new relationalStore.RdbPredicates('settings');
      predicates.equalTo('key', key);
      const rows = await this.rdbStore!.update(valueBucket, predicates);
      if (rows === 0) {
        await this.rdbStore!.insert('settings', valueBucket);
      }
    } catch (e) {
      const err = e as BusinessError;
      Logger.error('DatabaseManager', 'setSetting failed: ' + err.code + ' ' + err.message);
    }
  }
}
