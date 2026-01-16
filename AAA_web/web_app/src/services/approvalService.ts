import api from './api';

export interface ApprovalDocument {
  id: string;
  title: string;
  content: string;
  status: 'DRAFT' | 'PENDING' | 'APPROVED' | 'REJECTED';
  created_at: string;
  updated_at: string;
  creator_id: string;
  creator_name: string;
  approvers: Approver[];
  attachments?: Attachment[];
}

export interface Approver {
  user_id: string;
  name: string;
  department: string;
  position: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  approved_at?: string;
  comment?: string;
}

export interface Attachment {
  id: string;
  filename: string;
  url: string;
  size: number;
}

class ApprovalService {
  /**
   * 결재 문서 목록 조회 (Flutter: getApprovalList)
   */
  async getApprovalList(userId: string, status?: string, page = 1, limit = 20) {
    const response = await api.get('/approval/list', {
      params: { user_id: userId, status, page, limit }
    });
    return response.data;
  }

  /**
   * 결재 문서 상세 조회 (Flutter: getApprovalDetail)
   */
  async getApprovalDetail(documentId: string): Promise<ApprovalDocument> {
    const response = await api.get(`/approval/detail/${documentId}`);
    return response.data.document;
  }

  /**
   * 결재 승인 (Flutter: approveDocument)
   */
  async approveDocument(documentId: string, approverId: string, comment?: string) {
    const response = await api.post('/approval/approve', {
      document_id: documentId,
      approver_id: approverId,
      comment: comment || ''
    });
    return response.data;
  }

  /**
   * 결재 반려 (Flutter: rejectDocument)
   */
  async rejectDocument(documentId: string, approverId: string, reason: string) {
    const response = await api.post('/approval/reject', {
      document_id: documentId,
      approver_id: approverId,
      reason
    });
    return response.data;
  }

  /**
   * 결재 문서 생성 (상신) (Flutter: submitApproval)
   */
  async submitApproval(data: {
    user_id: string;
    title: string;
    content: string;
    approvers: string[];
    attachments?: File[];
  }) {
    const formData = new FormData();

    formData.append('user_id', data.user_id);
    formData.append('title', data.title);
    formData.append('content', data.content);
    formData.append('approvers', JSON.stringify(data.approvers));

    if (data.attachments) {
      data.attachments.forEach(file => {
        formData.append('files', file);
      });
    }

    const response = await api.post('/approval/submit', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
  }

  /**
   * 결재 문서 수정 (임시저장 상태일 때만)
   */
  async updateApproval(documentId: string, data: {
    title?: string;
    content?: string;
    approvers?: string[];
    attachments?: File[];
  }) {
    const formData = new FormData();

    if (data.title) formData.append('title', data.title);
    if (data.content) formData.append('content', data.content);
    if (data.approvers) formData.append('approvers', JSON.stringify(data.approvers));

    if (data.attachments) {
      data.attachments.forEach(file => {
        formData.append('files', file);
      });
    }

    const response = await api.post(`/approval/update/${documentId}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
  }

  /**
   * 결재 문서 삭제 (임시저장 상태일 때만)
   */
  async deleteApproval(documentId: string) {
    const response = await api.delete(`/approval/delete/${documentId}`);
    return response.data;
  }

  /**
   * 결재 대기 문서 조회 (관리자용)
   */
  async getPendingApprovals(approverId: string) {
    const response = await api.get('/approval/pending', {
      params: { approver_id: approverId }
    });
    return response.data;
  }

  /**
   * 결재 진행 상태 조회
   */
  async getApprovalProgress(documentId: string) {
    const response = await api.get(`/approval/progress/${documentId}`);
    return response.data;
  }

  /**
   * 결재 템플릿 목록 조회
   */
  async getApprovalTemplates() {
    const response = await api.get('/approval/templates');
    return response.data;
  }

  /**
   * 결재 템플릿으로 문서 생성
   */
  async createFromTemplate(templateId: string, userId: string) {
    const response = await api.post('/approval/create-from-template', {
      template_id: templateId,
      user_id: userId
    });
    return response.data;
  }
}

export default new ApprovalService();
