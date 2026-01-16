/**
 * 알림함 헬퍼 함수
 *
 * 알림 아이콘, 제목, 시간 포맷팅 등 유틸리티 함수 제공
 */

/**
 * 큐 이름에 따른 아이콘 반환
 * @param queueName 큐 이름 (birthday, gift, alert, event 등)
 * @returns 이모지 아이콘
 */
export const getIconByQueueName = (queueName: string): string => {
  switch (queueName) {
    case 'birthday':
      return '🎂';
    case 'gift':
      return '🎁';
    case 'alert':
      return '📢';
    case 'event':
      return '🎉';
    case 'leave':
    case 'leave_approval':
    case 'leave_alert':
    case 'leave_cc':
    case 'leave_draft':
      return '📝';
    case 'eapproval_alert':
    case 'eapproval_cc':
    case 'eapproval_approval':
      return '✅';
    case 'contest_detail':
      return '🏆';
    default:
      return '🔔';
  }
};

/**
 * 큐 이름에 따른 제목 반환
 * @param queueName 큐 이름
 * @returns 한글 제목
 */
export const getTitleByQueueName = (queueName: string): string => {
  switch (queueName) {
    case 'birthday':
      return '생일 알림';
    case 'gift':
      return '선물 도착';
    case 'alert':
      return '시스템 알림';
    case 'event':
      return '이벤트';
    case 'leave':
      return '휴가 알림';
    case 'leave_approval':
      return '휴가 승인 요청';
    case 'leave_alert':
      return '휴가 알림';
    case 'leave_cc':
      return '휴가 참조';
    case 'leave_draft':
      return '휴가 임시저장';
    case 'eapproval_alert':
      return '전자결재 알림';
    case 'eapproval_cc':
      return '전자결재 참조';
    case 'eapproval_approval':
      return '전자결재 승인';
    case 'contest_detail':
      return '공모전 알림';
    default:
      return '알림';
  }
};

/**
 * 날짜/시간 문자열을 상대 시간으로 포맷팅
 * @param dateTimeString 날짜 문자열 (YYYY-MM-DD HH:mm:ss)
 * @returns 상대 시간 문자열 (예: "방금 전", "3분 전", "2시간 전")
 */
export const formatDateTime = (dateTimeString: string): string => {
  try {
    const date = new Date(dateTimeString);
    const now = new Date();
    const diffInMs = now.getTime() - date.getTime();
    const diffInMinutes = Math.floor(diffInMs / (1000 * 60));

    if (diffInMinutes < 1) return '방금 전';
    if (diffInMinutes < 60) return `${diffInMinutes}분 전`;

    const diffInHours = Math.floor(diffInMinutes / 60);
    if (diffInHours < 24) return `${diffInHours}시간 전`;

    const diffInDays = Math.floor(diffInHours / 24);
    if (diffInDays < 7) return `${diffInDays}일 전`;

    // 7일 이상 지난 경우 날짜 포맷으로 표시
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');

    return `${month}월 ${day}일 ${hours}:${minutes}`;
  } catch (error) {
    console.error('날짜 포맷팅 오류:', error);
    return dateTimeString;
  }
};

/**
 * 날짜 문자열을 절대 시간으로 포맷팅
 * @param dateTimeString 날짜 문자열 (YYYY-MM-DD HH:mm:ss)
 * @returns 포맷된 날짜 문자열 (예: "2024년 1월 15일 09:00")
 */
export const formatAbsoluteDateTime = (dateTimeString: string): string => {
  try {
    const date = new Date(dateTimeString);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');

    return `${year}년 ${month}월 ${day}일 ${hours}:${minutes}`;
  } catch (error) {
    console.error('날짜 포맷팅 오류:', error);
    return dateTimeString;
  }
};

/**
 * 알림 메시지를 축약 (긴 메시지를 자르고 ... 추가)
 * @param message 원본 메시지
 * @param maxLength 최대 길이 (기본값: 100)
 * @returns 축약된 메시지
 */
export const truncateMessage = (message: string, maxLength = 100): string => {
  if (message.length <= maxLength) return message;
  return `${message.substring(0, maxLength)}...`;
};

/**
 * 알림 미리보기 메시지 정리 (마크다운 제거 + 축약)
 * @param message 원본 메시지
 * @param maxLength 최대 길이
 * @returns 정리된 미리보기
 */
export const sanitizeNotificationPreview = (
  message: string,
  maxLength = 100
): string => {
  if (!message) return '';

  let cleaned = message;

  cleaned = cleaned.replace(/\\n/g, '\n');
  cleaned = cleaned.replace(/```[\s\S]*?```/g, '');
  cleaned = cleaned.replace(/`([^`]*)`/g, '$1');
  cleaned = cleaned.replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1');
  cleaned = cleaned.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  cleaned = cleaned.replace(/^#{1,6}\s+/gm, '');
  cleaned = cleaned.replace(/^>\s?/gm, '');
  cleaned = cleaned.replace(/^\s*[-*+]\s+/gm, '');
  cleaned = cleaned.replace(/^\s*\d+\.\s+/gm, '');
  cleaned = cleaned.replace(/\*\*([^*]+)\*\*/g, '$1');
  cleaned = cleaned.replace(/\*([^*]+)\*/g, '$1');
  cleaned = cleaned.replace(/~~([^~]+)~~/g, '$1');
  cleaned = cleaned.replace(/\|/g, ' ');

  cleaned = cleaned.replace(/\s+/g, ' ').trim();

  return truncateMessage(cleaned, maxLength);
};
