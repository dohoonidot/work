import axios from 'axios';

import { API_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';

const logger = createLogger('FileService');
const API_URL = API_BASE_URL;

export interface FileAttachment {
  file: File;
  id: string;
  name: string;
  size: number;
  type: string;
  extension: string;
}

export class FileService {
  /**
   * 파일 첨부가 있는 메시지 전송 (streamChat/timeout)
   * 사내업무 아카이브에서 사용 - PDF 파일 허용
   */
  static async sendMessageWithFiles(
    archiveId: string,
    userId: string,
    message: string,
    files: FileAttachment[],
    category: string = '',
    module: string = '',
    isWebSearchEnabled: boolean = false
  ): Promise<ReadableStream<Uint8Array>> {
    const formData = new FormData();
    
    // 텍스트 필드 추가 (Flutter와 동일한 필드명 사용)
    formData.append('archive_id', archiveId);
    formData.append('user_id', userId);
    formData.append('message', message);
    formData.append('category', category);
    formData.append('module', module);

    // 웹검색 토글 상태 (Flutter와 동일)
    const searchYn = isWebSearchEnabled ? 'y' : 'n';
    formData.append('search_yn', searchYn);
    
    // 파일 첨부
    files.forEach(fileAttachment => {
      formData.append('files', fileAttachment.file);
    });

    logger.dev('📤 파일 첨부 메시지 전송 (streamChat/timeout):', {
      archiveId,
      userId,
      message,
      filesCount: files.length,
      category,
      module
    });

    const response = await fetch(`${API_URL}/streamChat/timeout`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`파일 첨부 메시지 전송 실패: ${response.status}`);
    }

    return response.body!;
  }

  /**
   * AI 모델 선택이 있는 파일 첨부 메시지 전송 (streamChat/withModel)
   * 코딩/SAP/AI Chatbot 아카이브에서 사용 - 이미지 파일만 허용
   */
  static async sendMessageWithModelAndFiles(
    archiveId: string,
    userId: string,
    message: string,
    files: FileAttachment[],
    aiModel: string,
    category: string = '',
    module: string = '',
    isWebSearchEnabled: boolean = false
  ): Promise<ReadableStream<Uint8Array>> {
    const formData = new FormData();
    
    // 모델 파라미터 변환 (chatService와 동일한 로직)
    let apiModel = '';
    if (aiModel === 'gpt-5.2') {
      apiModel = 'Gpt-5.2';
    } else if (aiModel === 'gemini-pro-3') {
      apiModel = 'Gemini-Pro-3';
    } else if (aiModel === 'claude-sonnet-4.5') {
      apiModel = 'Claude-Sonnet-4.5';
    } else {
      apiModel = 'Gemini-Pro-3'; // 기본값
    }
    
    // 텍스트 필드 추가 (Flutter와 동일한 필드명 사용)
    formData.append('archive_id', archiveId);
    formData.append('user_id', userId);
    formData.append('message', message);
    formData.append('model', apiModel);
    formData.append('category', category);
    // module 파라미터: 소문자로 변환되어 전달됨 (ChatArea에서 처리), 없으면 빈 문자열
    const moduleValue = module && module.trim() ? module.toLowerCase() : '';
    formData.append('module', moduleValue);

    // 웹검색 토글 상태 (Flutter와 동일)
    const searchYn = isWebSearchEnabled ? 'y' : 'n';
    formData.append('search_yn', searchYn);
    
    // 파일 첨부
    files.forEach(fileAttachment => {
      formData.append('files', fileAttachment.file);
    });

    // 모듈 파라미터 로그 추가
    logger.dev('🔧 모듈 파라미터 (파일 첨부):', {
      moduleInput: module,
      moduleValue,
      category,
      apiModel,
    });

    logger.dev('📤 streamChat/withModel API 요청 바디 (파일 첨부):', {
      category,
      module: moduleValue,
      model: apiModel,
      archive_id: archiveId,
      user_id: userId,
      message: message.substring(0, 50) + '...',
      files: files.map(f => f.name),
      search_yn: searchYn
    });

    const response = await fetch(`${API_URL}/streamChat/withModel`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`AI 모델 선택 파일 첨부 메시지 전송 실패: ${response.status}`);
    }

    return response.body!;
  }

  /**
   * 파일 타입 검증
   * @param file 파일 객체
   * @param allowedTypes 허용된 파일 타입들
   * @returns 검증 결과
   */
  static validateFileType(file: File, allowedTypes: string[]): boolean {
    const extension = file.name.split('.').pop()?.toLowerCase() || '';
    return allowedTypes.includes(extension);
  }

  /**
   * 파일 크기 검증
   * @param file 파일 객체
   * @param maxSizeMB 최대 크기 (MB)
   * @returns 검증 결과
   */
  static validateFileSize(file: File, maxSizeMB: number = 20): boolean {
    const maxSizeBytes = maxSizeMB * 1024 * 1024;
    return file.size <= maxSizeBytes;
  }

  /**
   * 파일을 FileAttachment 객체로 변환
   */
  static createFileAttachment(file: File): FileAttachment {
    const extension = file.name.split('.').pop()?.toLowerCase() || '';
    
    return {
      file,
      id: Math.random().toString(36).substr(2, 9),
      name: file.name,
      size: file.size,
      type: file.type,
      extension
    };
  }

  /**
   * 사내업무 아카이브용 파일 검증 (PDF 허용)
   */
  static validateInternalFiles(files: FileAttachment[]): { valid: boolean; error?: string } {
    for (const fileAttachment of files) {
      // 파일 크기 검증
      if (!this.validateFileSize(fileAttachment.file)) {
        return {
          valid: false,
          error: `파일 크기가 너무 큽니다: ${fileAttachment.name} (${(fileAttachment.size / 1024 / 1024).toFixed(2)}MB)`
        };
      }
    }
    return { valid: true };
  }

  /**
   * AI 모델 선택 아카이브용 파일 검증 (이미지 파일만 허용)
   */
  static validateModelFiles(files: FileAttachment[]): { valid: boolean; error?: string } {
    const allowedExtensions = ['jpg', 'jpeg', 'png'];
    
    for (const fileAttachment of files) {
      // 파일 타입 검증
      if (!this.validateFileType(fileAttachment.file, allowedExtensions)) {
        return {
          valid: false,
          error: `이미지 파일(jpg, jpeg, png)만 첨부 가능합니다: ${fileAttachment.name}`
        };
      }
      
      // 파일 크기 검증
      if (!this.validateFileSize(fileAttachment.file)) {
        return {
          valid: false,
          error: `파일 크기가 너무 큽니다: ${fileAttachment.name} (${(fileAttachment.size / 1024 / 1024).toFixed(2)}MB)`
        };
      }
    }
    return { valid: true };
  }

  /**
   * 파일 크기를 읽기 쉬운 형태로 변환
   */
  static formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
}

export default FileService;
