import axios from 'axios';
import { API_BASE_URL } from '../utils/apiConfig';
import api from './api';
import { createLogger } from '../utils/logger';

const logger = createLogger('DepartmentService');

class DepartmentService {
  /**
   * 부서 목록 조회
   */
  async getDepartmentList(): Promise<string[]> {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/getDepartmentList`);
      
      // 응답 형식에 따라 처리
      if (Array.isArray(response.data)) {
        return response.data;
      } else if (response.data && response.data.departments) {
        return response.data.departments;
      }
      
      return [];
    } catch (error: any) {
      logger.error('부서 목록 조회 실패:', error);
      throw new Error('부서 목록을 불러오는데 실패했습니다.');
    }
  }

  /**
   * 부서별 멤버 조회
   */
  async getDepartmentMembers(department: string): Promise<Array<{ name: string; department?: string; [key: string]: any }>> {
    try {
      const encodedDepartment = encodeURIComponent(department);
      const response = await axios.get(
        `${API_BASE_URL}/api/getDepartmentMembers?department=${encodedDepartment}`
      );

      const data = response.data;

      // 응답 형식에 따라 처리
      if (Array.isArray(data)) {
        return data.map((member) => 
          typeof member === 'object' 
            ? { name: member.name || member.user_name || '', department: member.department || department, ...member }
            : { name: member.toString(), department }
        );
      } else if (data && typeof data === 'object') {
        // {'members': [...]} 형태
        if (data.members && Array.isArray(data.members)) {
          return data.members.map((member: any) => ({
            name: member.name || member.user_name || '',
            department: member.department || department,
            ...member
          }));
        }
        
        // {부서명: [...]} 형태
        const firstKey = Object.keys(data)[0];
        if (firstKey && Array.isArray(data[firstKey])) {
          return data[firstKey].map((member: any) => ({
            name: member.name || member.user_name || '',
            department: member.department || department,
            ...member
          }));
        }
      }

      return [];
    } catch (error: any) {
      logger.error(`부서 멤버 조회 실패 (${department}):`, error);
      return [];
    }
  }
}

export default new DepartmentService();

