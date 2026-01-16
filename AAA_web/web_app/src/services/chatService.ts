import api from './api';
import { API_BASE_URL } from '../utils/apiConfig';
import type { Archive, ChatMessage } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('ChatService');

export interface CreateArchiveResponse {
  archive: Archive;
}

class ChatService {
  private extractJsonPrefix(text: string): { jsonText: string; rest: string } | null {
    const start = text.indexOf('{');
    if (start === -1) return null;

    let depth = 0;
    let inString = false;
    let escapeNext = false;

    for (let i = start; i < text.length; i += 1) {
      const ch = text[i];

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (ch === '\\') {
        escapeNext = true;
        continue;
      }

      if (ch === '"') {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (ch === '{') depth += 1;
      if (ch === '}') depth -= 1;

      if (depth === 0) {
        const jsonText = text.slice(start, i + 1);
        const rest = text.slice(i + 1);
        return { jsonText, rest };
      }
    }

    return null;
  }

  async processStream(params: {
    stream: ReadableStream<Uint8Array>;
    onChunk?: (chunk: string) => void;
    onLeaveTrigger?: (data: any) => void;
    onApprovalTrigger?: (data: any) => void;
  }): Promise<string> {
    const { stream, onChunk, onLeaveTrigger, onApprovalTrigger } = params;
    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let fullResponse = '';
    let buffer = '';
    const allowedApprovalTypes = new Set(['hr_leave_grant']);

    while (true) {
      const { done, value } = await reader.read();

      if (done) break;

      const chunk = decoder.decode(value, { stream: true });
      buffer += chunk;

      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('event: ')) {
          continue;
        }

        let textContent = line;
        if (line.startsWith('data: ')) {
          textContent = line.substring(6);
        }

        if (!textContent.trim() || textContent === ':') {
          continue;
        }

        const trimmedText = textContent.trim();
        const jsonPrefix = this.extractJsonPrefix(trimmedText);

        if (jsonPrefix) {
          try {
            const jsonData = JSON.parse(jsonPrefix.jsonText);

            const requiredFields = ['user_id', 'start_date', 'end_date', 'leave_type'];
            const hasAllRequiredFields = requiredFields.every(field => field in jsonData);

            if (hasAllRequiredFields && onLeaveTrigger) {
              const triggerData = {
                type: 'trigger_leave_modal',
                data: jsonData
              };

              logger.dev('[Chat Service] 휴가 신청 트리거 감지:', triggerData);
              onLeaveTrigger(triggerData.data);
            }

            const approvalPayload =
              jsonData?.approval_type ? jsonData
              : jsonData?.data?.approval_type ? jsonData.data
              : null;

            if (approvalPayload && onApprovalTrigger) {
              const approvalType = String(approvalPayload.approval_type || '');
              if (allowedApprovalTypes.has(approvalType)) {
                onApprovalTrigger(approvalPayload);
              }
            }

            if (!jsonPrefix.rest.trim()) {
              continue;
            }

            textContent = jsonPrefix.rest;
          } catch {
            // JSON 파싱 실패하면 일반 텍스트로 처리
          }
        }

        const formattedText = textContent
          .replace(/\\n\\n/g, '\n\n')
          .replace(/\\n/g, '\n');

        fullResponse += formattedText;

        if (onChunk && formattedText) {
          onChunk(formattedText);
        }
      }
    }

    if (buffer.trim()) {
      let textContent = buffer;
      if (buffer.startsWith('data: ')) {
        textContent = buffer.substring(6);
      }

      if (textContent.trim() && textContent !== ':') {
        const trimmedText = textContent.trim();
        const jsonPrefix = this.extractJsonPrefix(trimmedText);

        if (jsonPrefix) {
          try {
            const jsonData = JSON.parse(jsonPrefix.jsonText);

            const requiredFields = ['user_id', 'start_date', 'end_date', 'leave_type'];
            const hasAllRequiredFields = requiredFields.every(field => field in jsonData);

            if (hasAllRequiredFields && onLeaveTrigger) {
              const triggerData = {
                type: 'trigger_leave_modal',
                data: jsonData
              };

              logger.dev('[Chat Service] 휴가 신청 트리거 감지:', triggerData);
              onLeaveTrigger(triggerData.data);
            }

            const approvalPayload =
              jsonData?.approval_type ? jsonData
              : jsonData?.data?.approval_type ? jsonData.data
              : null;

            if (approvalPayload && onApprovalTrigger) {
              const approvalType = String(approvalPayload.approval_type || '');
              if (allowedApprovalTypes.has(approvalType)) {
                onApprovalTrigger(approvalPayload);
              }
            }

            if (!jsonPrefix.rest.trim()) {
              return fullResponse;
            }

            textContent = jsonPrefix.rest;
          } catch {
            // JSON 파싱 실패하면 일반 텍스트로 처리
          }
        }

        const formattedText = textContent
          .replace(/\\n\\n/g, '\n\n')
          .replace(/\\n/g, '\n');

        fullResponse += formattedText;

        if (onChunk && formattedText) {
          onChunk(formattedText);
        }
      }
    }

    return fullResponse;
  }
  /**
   * 아카이브 목록 가져오기 (Flutter의 getArchiveListFromServer 참조)
   */
  async getArchiveList(userId: string): Promise<Archive[]> {
    try {
      logger.dev('getArchiveList 호출:', userId);
      const response = await api.post<{ archive_list: Archive[] }>(
        '/getArchiveList',
        { user_id: userId }
      );

      logger.dev('getArchiveList 응답:', response);

      if (response.status === 204) {
        return [];
      }

      return response.data.archive_list || [];
    } catch (error: any) {
      logger.error('getArchiveList 에러:', error);
      logger.error('에러 상세:', error.response?.data);
      
      // 500 에러 시 빈 배열 반환
      if (error.response?.status === 500) {
        logger.warn('서버 에러로 인해 빈 아카이브 목록을 반환합니다.');
        return [];
      }
      
      throw error;
    }
  }

  /**
   * 아카이브 상세 정보 가져오기 (Flutter의 getArchiveDetailFromServer 참조)
   */
  async getArchiveDetail(
    archiveId: string,
    maxChatId: number = 0
  ): Promise<ChatMessage[]> {
    const response = await api.post<{
      status_code: number;
      chats?: ChatMessage[];
    }>('/getSingleArchive', {
      archive_id: archiveId,
      max_chat_id: maxChatId,
    });

    if (response.data.status_code === 204) {
      return [];
    }

    if (response.data.status_code === 200 && response.data.chats) {
      return response.data.chats;
    }

    return [];
  }

  /**
   * AI에게 메시지 전송 (스트리밍)
   * Flutter의 StreamService 참조
   */
  async sendMessage(params: {
    userId: string;
    archiveId: string;
    message: string;
    aiModel: string;
    archiveName?: string;
    isWebSearchEnabled?: boolean;
    module?: string; // SAP 모듈 선택
    onChunk?: (chunk: string) => void;
    onLeaveTrigger?: (data: any) => void; // 휴가 신청 트리거 콜백 추가
    onApprovalTrigger?: (data: any) => void; // 전자결재 상신 트리거 콜백 추가
  }): Promise<string> {
    const { userId, archiveId, message, aiModel, archiveName, isWebSearchEnabled = false, module = '', onChunk, onLeaveTrigger, onApprovalTrigger } = params;

    // 아카이브 타입 확인 (Flutter와 동일한 로직)
    const isCodeArchive = archiveName === '코딩어시스턴트';
    // SAP 어시스턴트는 공백 유무에 따라 다를 수 있으므로 둘 다 체크
    const isSapArchive = archiveName === 'SAP어시스턴트' || archiveName === 'SAP 어시스턴트';
    const isAiChatbot = archiveName === 'AI Chatbot';

    // AI 모델 선택 기능이 있는 아카이브인지 확인
    const useModelSelector = isCodeArchive || isSapArchive || isAiChatbot;

    logger.dev('sendMessage 호출:', {
      archiveName,
      isCodeArchive,
      isSapArchive,
      isAiChatbot,
      useModelSelector,
      aiModel
    });

    let response: Response;

    if (useModelSelector) {
      // streamChat/withModel API 사용 (코딩/SAP/AI Chatbot)
      const formData = new FormData();
      
      // 카테고리 설정
      let category = '';
      if (isCodeArchive) {
        category = 'code';
      } else if (isSapArchive) {
        category = 'sap';
      } else if (isAiChatbot) {
        category = ''; // AI Chatbot은 빈 카테고리
      }

      // 모델 파라미터 변환 (Flutter와 동일)
      let apiModel = '';
      if (aiModel === 'gpt-5.2') {
        apiModel = 'Gpt-5.2';
      } else if (aiModel === 'gemini-pro-3') {
        apiModel = 'Gemini-Pro-3';
      } else if (aiModel === 'claude-sonnet-4.5') {
        apiModel = 'Claude-Sonnet-4.5';
      } else {
        apiModel = 'Gemini-Pro-3'; // 기본값 (업그레이드된 모델로)
      }

      formData.append('category', category);
      // module 파라미터: SAP 아카이브일 때 선택된 모듈을 소문자로 변환하여 전달, 없으면 빈 문자열
      const moduleValue = module && module.trim() ? module.toLowerCase() : '';
      formData.append('module', moduleValue);
      formData.append('model', apiModel);
      formData.append('archive_id', archiveId);
      formData.append('user_id', userId);
      formData.append('message', message);

      // 웹검색 토글 상태 (Flutter와 동일)
      const searchYn = isWebSearchEnabled ? 'y' : 'n';
      formData.append('search_yn', searchYn);
      logger.dev('🌐 웹검색 상태:', searchYn);

      // 모듈 파라미터 로그 추가
      logger.dev('🔧 모듈 파라미터:', {
        isSapArchive,
        moduleInput: module,
        moduleValue,
        category,
      });

      logger.dev('📤 streamChat/withModel API 요청 바디:', { 
        category, 
        module: moduleValue,
        model: apiModel,
        archive_id: archiveId,
        user_id: userId,
        message: message.substring(0, 50) + '...',
        search_yn: searchYn
      });

      response = await fetch(`${API_BASE_URL}/streamChat/withModel`, {
        method: 'POST',
        headers: {
          // Authorization 헤더 제거 - 쿠키 기반 인증 사용 (Flutter와 동일)
          // Authorization: `Bearer ${localStorage.getItem('auth_token')}`,
        },
        credentials: 'include', // 쿠키 포함하여 전송
        body: formData,
      });
    } else {
      // streamChat/timeout API 사용 (사내업무)
      const formData = new FormData();
      formData.append('category', ''); // 사내업무는 빈 문자열
      formData.append('module', ''); // 기본값
      formData.append('archive_id', archiveId);
      formData.append('user_id', userId);
      formData.append('message', message);

      logger.dev('streamChat/timeout API 사용');

      response = await fetch(`${API_BASE_URL}/streamChat/timeout`, {
        method: 'POST',
        headers: {
          // Authorization 헤더 제거 - 쿠키 기반 인증 사용 (Flutter와 동일)
          // Authorization: `Bearer ${localStorage.getItem('auth_token')}`,
        },
        credentials: 'include', // 쿠키 포함하여 전송
        body: formData,
      });
    }

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    if (!response.body) {
      throw new Error('Response body is null');
    }

    return this.processStream({
      stream: response.body,
      onChunk,
      onLeaveTrigger,
      onApprovalTrigger,
    });
  }

  /**
   * 아카이브 생성 (Flutter의 createArchive 참조)
   */
  async createArchive(
    userId: string,
    title: string,
    archiveType: string = ''
  ): Promise<CreateArchiveResponse> {
    const response = await api.post<CreateArchiveResponse>('/createArchive', {
      user_id: userId,
      archive_type: archiveType,
    });

    return response.data;
  }

  /**
   * 아카이브 수정 (Flutter의 updateArchive 참조)
   */
  async updateArchive(
    userId: string,
    archiveId: string,
    newTitle: string
  ): Promise<void> {
    await api.post('/updateArchive', {
      user_id: userId,
      archive_id: archiveId,
      archive_name: newTitle,
    });
  }

  /**
   * 아카이브 제목 자동 생성 스트림 (Flutter의 getAutoTitleStream 참조)
   * 사용자의 첫 메시지를 기반으로 AI가 생성한 제목을 SSE 스트림으로 받음
   */
  async getAutoTitleStream(
    userId: string,
    archiveId: string,
    message: string,
    onTitleChunk: (chunk: string) => void,
    onComplete: (fullTitle: string) => void,
    onError: (error: Error) => void
  ): Promise<void> {
    // 다른 API 호출들과 동일하게 API_BASE_URL 사용
    const url = `${API_BASE_URL}/updateArchive/Auto/Stream`;

    try {
      logger.dev('🎯 자동 타이틀 업데이트 요청 시작:', { url, userId, archiveId, message });

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          user_id: userId,
          archive_id: archiveId,
          message: message,
        }),
      });

      if (!response.ok) {
        throw new Error(`자동 타이틀 업데이트 요청 실패: ${response.status}`);
      }

      if (!response.body) {
        throw new Error('응답 스트림이 없습니다');
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let accumulatedTitle = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        const lines = text.split('\n');

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.substring(6).trim();
            if (data) {
              accumulatedTitle += data;
              onTitleChunk(data);
            }
          }
        }
      }

      logger.dev('✅ 자동 타이틀 생성 완료:', accumulatedTitle);
      onComplete(accumulatedTitle.trim());
    } catch (error) {
      logger.error('❌ 자동 타이틀 업데이트 예외 발생:', error);
      onError(error as Error);
    }
  }

  /**
   * 아카이브 삭제 (Flutter의 deleteArchive 참조)
   */
  async deleteArchive(archiveId: string): Promise<void> {
    logger.dev('🗑️ deleteArchive API 호출:', { archive_id: archiveId });

    try {
      // Flutter와 동일하게 쿠키 기반 인증 사용 (Authorization 헤더 제거)
      const response = await api.post('/deleteArchive', {
        archive_id: archiveId,
      });

      logger.dev('🗑️ deleteArchive API 성공:', response.status, response.data);

      // Flutter에서는 204를 성공으로 처리하므로 여기서도 확인
      if (response.status === 204) {
        logger.dev('🗑️ 아카이브 삭제 성공 (204 No Content)');
        return;
      }

      // 다른 성공 상태도 처리
      if (response.status >= 200 && response.status < 300) {
        logger.dev('🗑️ 아카이브 삭제 성공:', response.status);
        return;
      }

    } catch (error: any) {
      logger.error('🗑️ deleteArchive API 실패:', {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
        config: error.config
      });

      // Flutter처럼 204도 성공으로 처리
      if (error.response?.status === 204) {
        logger.dev('🗑️ 아카이브 삭제 성공 (204 No Content - 에러로 처리됨)');
        return;
      }

      throw error;
    }
  }

  /**
   * 기본 아카이브 초기화 (Flutter의 resetArchive 기능)
   * Flutter 참조: lib/shared/providers/chat_notifier.dart 라인 731-796
   */
  async resetArchive(
    userId: string,
    archiveId: string,
    archiveType: string,
    archiveName: string
  ): Promise<string> {
    try {
      logger.dev('🔄 아카이브 초기화 시작:', {
        userId,
        archiveId,
        archiveType,
        archiveName,
      });

      // 1. 기존 아카이브 삭제
      logger.dev('1️⃣ 기존 아카이브 삭제 중...');
      await this.deleteArchive(archiveId);
      logger.dev('✅ 아카이브 삭제 완료');

      // 2. 동일한 타입의 새 아카이브 생성
      // Flutter 로직: archiveType에 따라 적절한 타이틀 설정
      let newTitle = '';
      if (archiveType === 'code') {
        newTitle = '코딩어시스턴트'; // Flutter와 동일
      } else if (archiveType === 'sap') {
        newTitle = 'SAP어시스턴트'; // Flutter와 동일
      } else {
        // archiveType === '' (사내업무, AI Chatbot)
        newTitle = ''; // 빈 문자열로 생성 후 이름 변경
      }

      logger.dev('2️⃣ 새 아카이브 생성 중...', { archiveType, newTitle });
      const response = await this.createArchive(userId, newTitle, archiveType);
      const newArchiveId = response.archive.archive_id;
      logger.dev('✅ 새 아카이브 생성 완료:', newArchiveId);

      // 3. 기본 아카이브인 경우 제목 변경
      // archiveType === '' 이면서 사내업무 또는 AI Chatbot인 경우
      if (archiveType === '' && archiveName === '사내업무') {
        logger.dev('3️⃣ 아카이브 이름을 "사내업무"로 변경 중...');
        await this.updateArchive(userId, newArchiveId, '사내업무');
        logger.dev('✅ 이름 변경 완료');
      } else if (archiveType === '' && archiveName === 'AI Chatbot') {
        logger.dev('3️⃣ 아카이브 이름을 "AI Chatbot"으로 변경 중...');
        await this.updateArchive(userId, newArchiveId, 'AI Chatbot');
        logger.dev('✅ 이름 변경 완료');
      }

      logger.dev('🎉 아카이브 초기화 완료:', archiveId, '->', newArchiveId);
      return newArchiveId;
    } catch (error) {
      logger.error('❌ 아카이브 초기화 실패:', error);
      throw error;
    }
  }

  /**
   * 알림 목록 조회 (Flutter의 getNotifications 참조)
   */
  async getNotifications(userId: string): Promise<any[]> {
    const response = await api.post<{ notifications: any[] }>('/getNotifications', {
      user_id: userId,
    });

    return response.data.notifications || [];
  }

  /**
   * 받은 선물함 조회 (Flutter의 checkGifts 참조)
   */
  async checkGifts(userId: string): Promise<any> {
    const response = await api.post('/queue/checkGifts', {
      user_id: userId,
    });

    return response.data;
  }

  /**
   * 알림 목록 조회 (Flutter의 checkAlerts 참조)
   */
  async checkAlerts(userId: string): Promise<any> {
    const response = await api.post('/queue/checkAlerts', {
      user_id: userId,
    });

    return response.data;
  }

  /**
   * 알림 수신확인 (Flutter의 updateAlerts 참조)
   */
  async updateAlerts(userId: string, alertId: number): Promise<any> {
    const response = await api.post('/queue/updateAlerts', {
      user_id: userId,
      id: alertId,
    });

    return response.data;
  }

  /**
   * 알림 삭제 (Flutter의 deleteAlerts 참조)
   */
  async deleteAlerts(userId: string, alertId: number): Promise<any> {
    const response = await api.post('/queue/deleteAlerts', {
      user_id: userId,
      id: alertId,
    });

    return response.data;
  }

  /**
   * 개인정보 동의 상태 조회 (Flutter의 checkPrivacyAgreement 참조)
   */
  async checkPrivacyAgreement(userId: string): Promise<any> {
    const response = await api.post('/checkPrivacy', {
      user_id: userId,
    });

    return response.data;
  }

  /**
   * 개인정보 동의 상태 업데이트 (Flutter의 updatePrivacyAgreement 참조)
   */
  async updatePrivacyAgreement(userId: string, isAgreed: boolean): Promise<any> {
    const response = await api.post('/updatePrivacy', {
      user_id: userId,
      is_agreed: isAgreed ? 1 : 0,
    });

    return response.data;
  }

  /**
   * 서버 DB 아카이브 끝번호 조회 (Flutter의 getMaxSerial 참조)
   */
  async getMaxSerial(userId: string): Promise<number> {
    const response = await api.post<{ max_serial: number }>('/getMaxSerial', {
      user_id: userId,
    });

    return response.data.max_serial;
  }

  /**
   * 서버 DB 마지막 chat_id 조회 (Flutter의 getlastChatId 참조)
   */
  async getlastChatId(archiveId: string, userId: string): Promise<number> {
    const response = await api.post<{ last_chat_id: number }>('/getlastChatId', {
      archive_id: archiveId,
      user_id: userId,
    });

    return response.data.last_chat_id;
  }

  /**
   * 메시지 검색 (메모리 기반 - Flutter의 searchArchiveContent 로직 참조)
   *
   * React 웹앱에서는 로컬 DB가 없으므로, 이미 로드된 아카이브 데이터를 메모리에서 검색합니다.
   * Flutter의 database_helper.dart:1222-1314 searchArchiveContent 로직을 참조했습니다.
   */
  async searchArchiveContent(
    searchText: string,
    archives: Archive[],
    userId: string
  ): Promise<Array<{
    archive_id: string;
    archive_name: string;
    archive_type?: string;
    archive_time?: string;
    chat_id?: number;
    role?: number;
    message?: string;
    match_type: 'title' | 'content';
    match_text: string;
    snippet?: string;
    match_index?: number;
  }>> {
    try {
      if (!searchText || searchText.trim() === '') {
        return [];
      }

      const results: any[] = [];

      logger.dev(`검색 시작: "${searchText}", 아카이브 수: ${archives.length}`);

      // 사용자의 아카이브만 필터링
      const userArchives = archives.filter(
        (archive) => archive.user_id === userId || !archive.user_id
      );

      // 각 아카이브에서 검색
      for (const archive of userArchives) {
        const archiveId = archive.archive_id;
        const archiveName = archive.archive_name;
        const archiveType = archive.archive_type || '';
        const archiveTime = archive.archive_time;

        // 1. 아카이브 제목 검색
        if (
          archiveName &&
          archiveName.toLowerCase().includes(searchText.toLowerCase())
        ) {
          results.push({
            archive_id: archiveId,
            archive_name: archiveName,
            archive_type: archiveType,
            archive_time: archiveTime,
            match_type: 'title',
            match_text: archiveName,
            snippet: null,
          });
        }

        // 2. 아카이브의 채팅 내용 검색
        // 서버에서 해당 아카이브의 메시지 가져오기
        const messages = await this.getArchiveDetail(archiveId);

        for (const message of messages) {
          const messageText = message.message || '';
          const role = message.role;
          const chatId = message.chat_id;

          // COT 내용 필터링 (Flutter 로직 참조)
          const filteredMessage = this._filterCOTContent(
            messageText,
            archiveType,
            archiveName,
            role
          );

          // 검색어가 포함되어 있는지 확인
          if (
            filteredMessage.toLowerCase().includes(searchText.toLowerCase())
          ) {
            // 검색어의 모든 발생 위치 찾기
            const lowerMessage = filteredMessage.toLowerCase();
            const lowerSearchText = searchText.toLowerCase();

            let startIndex = 0;
            while (true) {
              const matchIndex = lowerMessage.indexOf(
                lowerSearchText,
                startIndex
              );
              if (matchIndex === -1) break;

              // 각 발생 위치마다 별도의 스니펫 생성
              const snippet = this._createSnippet(
                filteredMessage,
                searchText,
                matchIndex
              );

              results.push({
                archive_id: archiveId,
                archive_name: archiveName,
                archive_type: archiveType,
                archive_time: archiveTime,
                chat_id: chatId,
                role: role,
                message: filteredMessage,
                match_type: 'content',
                match_text: searchText,
                snippet: snippet,
                match_index: matchIndex,
              });

              startIndex = matchIndex + lowerSearchText.length;
            }
          }
        }
      }

      logger.dev(`검색 완료: ${results.length}개 결과`);
      return results;
    } catch (error: any) {
      logger.error('아카이브 검색 중 오류 발생:', error);
      return [];
    }
  }

  /**
   * COT 내용 필터링 (Flutter의 _filterCOTContent 참조)
   */
  private _filterCOTContent(
    fullText: string,
    archiveType: string,
    archiveName: string,
    role?: number
  ): string {
    // 사용자 메시지(role=0)는 COT 필터링 없이 원본 반환
    if (role === 0) {
      return fullText;
    }

    // streamChat/withModel API를 사용하는 아카이브들은 COT 부분 완전 제거
    const shouldRemoveCOT =
      archiveName === '코딩 어시스턴트' ||
      archiveName === '코딩어시스턴트' ||
      archiveName === 'SAP 어시스턴트' ||
      archiveName === 'SAP어시스턴트' ||
      archiveName === 'AI Chatbot' ||
      archiveType === 'coding' ||
      archiveType === 'sap' ||
      archiveType === 'code';

    if (shouldRemoveCOT) {
      // 1. </think> 태그가 있는지 확인
      const thinkEndIndex = fullText.indexOf('</think>');

      if (thinkEndIndex !== -1) {
        // </think> 태그가 있으면 그 이후 부분만 반환
        if (thinkEndIndex + 9 < fullText.length) {
          return fullText.substring(thinkEndIndex + 9); // 태그 길이(9)만큼 건너뛰기
        } else {
          return ''; // </think> 뒤에 내용이 없으면 빈 문자열 반환
        }
      }

      // 2. <think>와 </think> 사이 내용 제거
      const thinkRegex = /<think>[\s\S]*?<\/think>/g;
      return fullText.replace(thinkRegex, '');
    }

    // 사내업무 아카이브 조건 확인
    const isBusinessArchive =
      archiveName === '사내업무' || archiveType === '';

    // 1. </think> 태그가 있는지 확인
    const thinkEndIndex = fullText.indexOf('</think>');

    if (thinkEndIndex !== -1) {
      // </think> 태그가 있으면 그 이후 부분만 반환
      if (thinkEndIndex + 9 < fullText.length) {
        return fullText.substring(thinkEndIndex + 9);
      } else {
        return '';
      }
    }

    // 사내업무에서는 처음부터 cot 시작으로 간주하고 응답 부분만 찾아야 함
    if (isBusinessArchive) {
      // </think> 태그가 없으면 전체 내용을 COT로 간주하므로 빈 문자열 반환
      return '';
    }

    const thinkRegex = /<think>[\s\S]*?<\/think>/g;
    return fullText.replace(thinkRegex, '');
  }

  /**
   * 스니펫 생성 (Flutter의 _createSnippet 참조)
   */
  private _createSnippet(
    fullText: string,
    searchText: string,
    customIndex?: number
  ): string {
    try {
      const lowerFullText = fullText.toLowerCase();
      const lowerSearchText = searchText.toLowerCase();

      // customIndex가 제공된 경우 해당 인덱스 사용, 아니면 첫 번째 등장 위치 찾기
      const index =
        customIndex !== undefined
          ? customIndex
          : lowerFullText.indexOf(lowerSearchText);

      if (index === -1) return fullText;

      // 검색어 위치의 앞뒤 컨텍스트 포함 (10자)
      const start = index - 10 < 0 ? 0 : index - 10;
      const end =
        index + searchText.length + 10 > fullText.length
          ? fullText.length
          : index + searchText.length + 10;

      let snippet = fullText.substring(start, end);

      // 시작과 끝을 표시
      if (start > 0) snippet = '...' + snippet;
      if (end < fullText.length) snippet = snippet + '...';

      return snippet;
    } catch (error) {
      logger.error('스니펫 생성 중 오류:', error);
      return fullText;
    }
  }
}

export default new ChatService();
