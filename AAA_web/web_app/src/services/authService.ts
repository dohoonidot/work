import { API_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';

const logger = createLogger('AuthService');

export interface LoginRequest {
  user_id: string;
  password: string;
}

export interface LoginResponse {
  status_code: number;
  is_agreed: number;
  is_approver: number;
  permission: number | null;
  user_id?: string;
  name?: string;
  department?: string;
  job_position?: string;
}

export interface RefreshResponse {
  status_code: number;
  is_agreed: number;
  is_approver: number;
  permission: number | null;
  user_id?: string;
  name?: string;
  department?: string;
  job_position?: string;
}

export interface UserInfo {
  userId: string;
  name?: string;
  department?: string;
  jobPosition?: string;
  privacyAgreed: boolean;
  isApprover: boolean;
  permission: number | null;
}

class AuthService {
  // 메모리에 사용자 정보 저장 (로컬스토리지 사용 안 함)
  private userInfo: UserInfo | null = null;

  /**
   * 웹용 로그인 API
   * POST /api/web/login
   * 서버가 쿠키에 access_token과 refresh_token을 저장
   */
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/web/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include', // 쿠키 포함 필수
        body: JSON.stringify({
          user_id: credentials.user_id,
          password: credentials.password,
        }),
      });

      const data: LoginResponse = await response.json();

      // 디버깅: 로그인 응답값 전체 출력
      console.log('🔐 [AuthService] 로그인 응답 전체:', data);
      console.log('🔐 [AuthService] is_approver 원본값:', data.is_approver, '타입:', typeof data.is_approver);

      // 로그인 성공 시 메모리에 사용자 정보 저장
      if (data.status_code === 200) {
        this.userInfo = {
          userId: data.user_id || credentials.user_id,
          name: data.name,
          department: data.department,
          jobPosition: data.job_position,
          privacyAgreed: data.is_agreed === 1,
          isApprover: data.is_approver === 1,
          permission: data.permission,
        };
        console.log('🔐 [AuthService] 저장된 userInfo:', this.userInfo);
        console.log('🔐 [AuthService] isApprover 저장값:', this.userInfo.isApprover);
        logger.dev('로그인 성공 - 사용자 정보 메모리에 저장 완료');
      }

      return data;
    } catch (error: any) {
      logger.error('로그인 실패:', error);
      throw error;
    }
  }

  /**
   * 웹용 리프레시 API
   * GET /api/web/refresh
   * 쿠키의 refresh_token을 사용하여 새로운 access_token 발급
   * 앱 시작 시 호출하여 로그인 상태 확인
   */
  async refresh(): Promise<RefreshResponse | null> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/web/refresh`, {
        method: 'POST',
        credentials: 'include', // 쿠키의 refresh_token 자동 전송
      });

      if (response.status === 401 || response.status === 403) {
        // 인증 실패 - 로그인 필요
        logger.dev('리프레시 실패 - 로그인 필요');
        this.userInfo = null;
        return null;
      }

      const data: RefreshResponse = await response.json();

      // 리프레시 성공 시 메모리에 사용자 정보 저장/업데이트
      if (data.status_code === 200) {
        this.userInfo = {
          userId: data.user_id || this.userInfo?.userId || '',  // 서버 응답 없으면 기존 ID 유지
          name: data.name,
          department: data.department,
          jobPosition: data.job_position,
          privacyAgreed: data.is_agreed === 1,
          isApprover: data.is_approver === 1,
          permission: data.permission,
        };
        logger.dev('리프레시 성공 - 사용자 정보 메모리에 업데이트 완료');
        return data;
      }

      this.userInfo = null;
      return null;
    } catch (error: any) {
      logger.error('리프레시 실패:', error);
      this.userInfo = null;
      return null;
    }
  }

  /**
   * 웹용 로그아웃 API
   * POST /api/web/logout
   * 서버에서 쿠키 삭제
   */
  async logout(): Promise<void> {
    try {
      await fetch(`${API_BASE_URL}/api/web/logout`, {
        method: 'POST',
        credentials: 'include', // 쿠키 포함
      });

      logger.dev('로그아웃 API 호출 완료');
    } catch (error: any) {
      logger.error('로그아웃 API 호출 실패:', error);
    } finally {
      // 메모리에서 사용자 정보 제거
      this.userInfo = null;
      logger.dev('사용자 정보 메모리에서 제거 완료');
      window.location.href = '/login';
    }
  }

  /**
   * 현재 로그인 사용자 정보 가져오기 (메모리에서)
   */
  getCurrentUser(): UserInfo | null {
    return this.userInfo;
  }

  /**
   * 관리자 권한 확인 (Flutter의 _hasVacationGrantPermission 참조)
   * permission 값이 0 또는 1인 경우 관리자 권한
   */
  hasAdminPermission(): boolean {
    const user = this.getCurrentUser();
    if (!user || user.permission === null) return false;

    return user.permission === 0 || user.permission === 1;
  }

  /**
   * 결재자 권한 확인
   */
  isApprover(): boolean {
    const user = this.getCurrentUser();
    return user?.isApprover || false;
  }

  /**
   * 인증 상태 확인 (메모리의 사용자 정보 확인)
   */
  isAuthenticated(): boolean {
    return this.userInfo !== null;
  }

  /**
   * 개인정보 동의 상태 조회
   */
  async checkPrivacy(userId: string): Promise<{ is_agreed: number }> {
    try {
      const response = await fetch(`${API_BASE_URL}/checkPrivacy`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          user_id: userId,
        }),
      });

      const data = await response.json();
      return data;
    } catch (error: any) {
      logger.error('개인정보 동의 상태 조회 실패:', error);
      throw error;
    }
  }

  /**
   * 개인정보 동의 상태 업데이트
   */
  async updatePrivacy(userId: string, isAgreed: boolean): Promise<void> {
    try {
      await fetch(`${API_BASE_URL}/updatePrivacy`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          user_id: userId,
          is_agreed: isAgreed ? 1 : 0,
        }),
      });

      // 메모리의 사용자 정보 업데이트
      if (this.userInfo) {
        this.userInfo.privacyAgreed = isAgreed;
        logger.dev('개인정보 동의 상태 메모리에 업데이트 완료');
      }
    } catch (error: any) {
      logger.error('개인정보 동의 상태 업데이트 실패:', error);
      throw error;
    }
  }
}

export default new AuthService();