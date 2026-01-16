export interface Gift {
  id: number;
  gift_type: string;
  gift_content: string;
  gift_title?: string;
  gift_description?: string;
  gift_url?: string; // 선물 확인 링크
  received_at?: string; // 받은 시간
  created_at: string;
  sender_name?: string;
  coupon_img_url?: string; // 쿠폰 이미지 URL (snake_case - 하위 호환성)
  couponImgUrl?: string; // 쿠폰 이미지 URL (camelCase - API 응답)
  coupon_end_date?: string; // 쿠폰 만료일
  gift_name?: string; // 선물 이름
  description?: string; // 선물 설명
  message?: string; // 메시지
  queue_name?: string; // 큐 이름
  is_new?: boolean; // 새 선물 여부
}

export interface CheckGiftsResponse {
  gifts: Gift[];
  status_code: number;
}
