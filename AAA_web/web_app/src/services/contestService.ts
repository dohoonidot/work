import api from './api';
import { createLogger } from '../utils/logger';

const logger = createLogger('ContestService');

interface ContestListParams {
    viewType: 'random' | 'view_count' | 'votes';
    category?: string;
}

interface VoteContestParams {
    documentId: number;
    action: 'like' | 'unlike';
}

interface SubmitContestParams {
    message: string;
    files: File[];
    fileNames: string[];
}

interface UserInfo {
    name: string;
    department: string;
    job_position: string;
}

class ContestService {
    /**
     * 남은 투표 수 조회
     */
    async getRemainingVotes(): Promise<number> {
        try {
            const response = await api.get('/api/contest/remaining-votes');
            return response.data?.remaining_votes || 0;
        } catch (error: any) {
            logger.error('남은 투표 수 조회 실패:', error);
            throw new Error(error.response?.data?.message || '남은 투표 수를 불러오는데 실패했습니다.');
        }
    }

    /**
     * 사용자 정보 조회
     */
    async getUserInfo(): Promise<UserInfo> {
        try {
            const response = await api.get('/api/contest/user-info');
            return response.data;
        } catch (error: any) {
            logger.error('사용자 정보 조회 실패:', error);
            throw new Error(error.response?.data?.message || '사용자 정보를 불러오는데 실패했습니다.');
        }
    }

    /**
     * 공모전 목록 조회
     */
    async getContestList(params: ContestListParams): Promise<any> {
        try {
            const response = await api.get('/api/contest/list', {
                params: {
                    view_type: params.viewType,
                    category: params.category || '',
                },
            });
            return response.data;
        } catch (error: any) {
            logger.error('공모전 목록 조회 실패:', error);
            throw new Error(error.response?.data?.message || '공모전 목록을 불러오는데 실패했습니다.');
        }
    }

    /**
     * 공모전 투표
     */
    async voteContest(params: VoteContestParams): Promise<void> {
        try {
            await api.post('/api/contest/vote', {
                document_id: params.documentId,
                action: params.action,
            });
            logger.dev(`공모전 투표 성공: ${params.action} - ${params.documentId}`);
        } catch (error: any) {
            logger.error('공모전 투표 실패:', error);
            throw new Error(error.response?.data?.message || '투표에 실패했습니다.');
        }
    }

    /**
     * 공모전 신청서 제출
     */
    async submitContest(params: SubmitContestParams): Promise<void> {
        try {
            const formData = new FormData();
            formData.append('message', params.message);

            // 파일 추가
            params.files.forEach((file, index) => {
                formData.append('files', file);
                formData.append('file_names', params.fileNames[index]);
            });

            await api.post('/api/contest/submit', formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
            });

            logger.dev('공모전 신청서 제출 성공');
        } catch (error: any) {
            logger.error('공모전 신청서 제출 실패:', error);
            throw new Error(error.response?.data?.message || '신청서 제출에 실패했습니다.');
        }
    }
}

export default new ContestService();
