/**
 * IndexedDB 서비스
 * Flutter 앱의 DatabaseHelper와 동일한 기능을 제공
 */

import { createLogger } from '../utils/logger';

const logger = createLogger('IndexedDBService');

const DB_NAME = 'aspn_agent_db';
const DB_VERSION = 1;

// 스토어 이름들
const STORES = {
  ARCHIVES: 'archives',
  MESSAGES: 'messages',
  SETTINGS: 'settings',
} as const;

interface ArchiveRecord {
  archive_id: string;
  archive_name: string;
  archive_type: string;
  archive_time: string;
  user_id: string;
  data: string; // JSON stringified archive data
}

interface MessageRecord {
  chat_id: number;
  archive_id: string;
  message: string;
  role: number;
  timestamp: string;
  data: string; // JSON stringified message data
}

interface SettingsRecord {
  key: string;
  value: string;
}

class IndexedDBService {
  private db: IDBDatabase | null = null;

  /**
   * 데이터베이스 초기화
   */
  async init(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        logger.error('IndexedDB 초기화 실패:', request.error);
        reject(request.error);
      };

      request.onsuccess = () => {
        this.db = request.result;
        console.log('IndexedDB 초기화 성공');
        resolve();
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        // 아카이브 스토어 생성
        if (!db.objectStoreNames.contains(STORES.ARCHIVES)) {
          const archiveStore = db.createObjectStore(STORES.ARCHIVES, {
            keyPath: 'archive_id',
          });
          archiveStore.createIndex('user_id', 'user_id', { unique: false });
          archiveStore.createIndex('archive_time', 'archive_time', { unique: false });
        }

        // 메시지 스토어 생성
        if (!db.objectStoreNames.contains(STORES.MESSAGES)) {
          const messageStore = db.createObjectStore(STORES.MESSAGES, {
            keyPath: 'chat_id',
          });
          messageStore.createIndex('archive_id', 'archive_id', { unique: false });
          messageStore.createIndex('timestamp', 'timestamp', { unique: false });
        }

        // 설정 스토어 생성
        if (!db.objectStoreNames.contains(STORES.SETTINGS)) {
          const settingsStore = db.createObjectStore(STORES.SETTINGS, {
            keyPath: 'key',
          });
        }
      };
    });
  }

  /**
   * 데이터베이스 연결 확인
   */
  private ensureDB(): IDBDatabase {
    if (!this.db) {
      throw new Error('IndexedDB가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return this.db;
  }

  // ========== 아카이브 관련 메서드 ==========

  /**
   * 아카이브 저장
   */
  async saveArchive(archive: ArchiveRecord): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.ARCHIVES], 'readwrite');
      const store = transaction.objectStore(STORES.ARCHIVES);
      const request = store.put(archive);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 아카이브 목록 가져오기
   */
  async getArchives(userId: string): Promise<ArchiveRecord[]> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.ARCHIVES], 'readonly');
      const store = transaction.objectStore(STORES.ARCHIVES);
      const index = store.index('user_id');
      const request = index.getAll(userId);

      request.onsuccess = () => {
        const archives = request.result as ArchiveRecord[];
        // 시간순 정렬 (최신순)
        archives.sort((a, b) => 
          new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime()
        );
        resolve(archives);
      };
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 아카이브 삭제
   */
  async deleteArchive(archiveId: string): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.ARCHIVES, STORES.MESSAGES], 'readwrite');
      
      // 아카이브 삭제
      const archiveStore = transaction.objectStore(STORES.ARCHIVES);
      const archiveRequest = archiveStore.delete(archiveId);

      // 관련 메시지 삭제
      const messageStore = transaction.objectStore(STORES.MESSAGES);
      const messageIndex = messageStore.index('archive_id');
      const messageRequest = messageIndex.openCursor(IDBKeyRange.only(archiveId));

      messageRequest.onsuccess = (event) => {
        const cursor = (event.target as IDBRequest<IDBCursorWithValue>).result;
        if (cursor) {
          cursor.delete();
          cursor.continue();
        }
      };

      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
    });
  }

  // ========== 메시지 관련 메서드 ==========

  /**
   * 메시지 저장
   */
  async saveMessage(message: MessageRecord): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.MESSAGES], 'readwrite');
      const store = transaction.objectStore(STORES.MESSAGES);
      const request = store.put(message);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 메시지 목록 가져오기
   */
  async getMessages(archiveId: string, limit?: number): Promise<MessageRecord[]> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.MESSAGES], 'readonly');
      const store = transaction.objectStore(STORES.MESSAGES);
      const index = store.index('archive_id');
      const request = index.getAll(archiveId);

      request.onsuccess = () => {
        let messages = request.result as MessageRecord[];
        // 시간순 정렬
        messages.sort((a, b) => 
          new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
        );
        // 제한이 있으면 적용
        if (limit) {
          messages = messages.slice(-limit);
        }
        resolve(messages);
      };
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 아카이브의 모든 메시지 삭제
   */
  async deleteMessages(archiveId: string): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.MESSAGES], 'readwrite');
      const store = transaction.objectStore(STORES.MESSAGES);
      const index = store.index('archive_id');
      const request = index.openCursor(IDBKeyRange.only(archiveId));

      request.onsuccess = (event) => {
        const cursor = (event.target as IDBRequest<IDBCursorWithValue>).result;
        if (cursor) {
          cursor.delete();
          cursor.continue();
        } else {
          resolve();
        }
      };
      request.onerror = () => reject(request.error);
    });
  }

  // ========== 설정 관련 메서드 ==========

  /**
   * 설정 저장
   */
  async saveSetting(key: string, value: string): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.SETTINGS], 'readwrite');
      const store = transaction.objectStore(STORES.SETTINGS);
      const request = store.put({ key, value });

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 설정 가져오기
   */
  async getSetting(key: string): Promise<string | null> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.SETTINGS], 'readonly');
      const store = transaction.objectStore(STORES.SETTINGS);
      const request = store.get(key);

      request.onsuccess = () => {
        const result = request.result as SettingsRecord | undefined;
        resolve(result?.value || null);
      };
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 설정 삭제
   */
  async deleteSetting(key: string): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([STORES.SETTINGS], 'readwrite');
      const store = transaction.objectStore(STORES.SETTINGS);
      const request = store.delete(key);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * 데이터베이스 초기화 (모든 데이터 삭제)
   */
  async clear(): Promise<void> {
    const db = this.ensureDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(
        [STORES.ARCHIVES, STORES.MESSAGES, STORES.SETTINGS],
        'readwrite'
      );

      transaction.objectStore(STORES.ARCHIVES).clear();
      transaction.objectStore(STORES.MESSAGES).clear();
      transaction.objectStore(STORES.SETTINGS).clear();

      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
    });
  }
}

// 싱글톤 인스턴스
const indexedDBService = new IndexedDBService();

// 앱 시작 시 초기화
if (typeof window !== 'undefined') {
  indexedDBService.init().catch((error) => {
    logger.error('IndexedDB 초기화 실패:', error);
  });
}

export default indexedDBService;

