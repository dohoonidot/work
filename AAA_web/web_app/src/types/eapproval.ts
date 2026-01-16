export interface EApprovalAttachment {
  file_name: string;
  size?: number;
  url?: string;
  prefix?: string;
}

export interface EApprovalApprover {
  approver_id: string;
  approver_name: string;
  approval_seq?: number;
  department?: string;
  job_position?: string;
  user_id?: string;
  next_approver_id?: string;
}

export interface EApprovalCcPerson {
  user_id?: string;
  name: string;
  department?: string;
}

export interface EApprovalDraftData {
  department?: string;
  name?: string;
  job_position?: string;
  approval_type?: string;
  approval_line?: EApprovalApprover[];
  cc_list?: EApprovalCcPerson[];
  title?: string;
  leave_type?: string;
  grant_days?: number;
  reason?: string;
  start_date?: string;
  end_date?: string;
  half_day_slot?: string;
  attachments_list?: EApprovalAttachment[];
  html_content?: string;
  content?: string;
  [key: string]: any;
}
