import 'package:flutter/material.dart';
import 'electronic_approval_management_screen.dart';

/// 결재 내역 상세 모달
class ApprovalDetailModal extends StatelessWidget {
  final ApprovalDocument document;

  const ApprovalDetailModal({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 모달 헤더
            _buildModalHeader(context),

            // 모달 콘텐츠
            Expanded(
              child: _buildModalContent(),
            ),

            // 모달 하단 버튼
            _buildModalFooter(context),
          ],
        ),
      ),
    );
  }

  /// 모달 헤더
  Widget _buildModalHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE9ECEF)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Color(0xFF4A6CF7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '문서번호: ${document.documentNo}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(document.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              document.status,
              style: TextStyle(
                color: _getStatusColor(document.status),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  /// 모달 콘텐츠
  Widget _buildModalContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 정보 섹션
          _buildInfoSection('기본 정보', [
            _buildInfoRow('기안자', document.drafter),
            _buildInfoRow('문서유형', document.type),
            _buildInfoRow('기안일', _formatDate(document.draftDate)),
            _buildInfoRow(
                '완료일',
                document.completionDate != null
                    ? _formatDate(document.completionDate!)
                    : '미완료'),
            _buildInfoRow('상태', document.status),
          ]),

          const SizedBox(height: 32),

          // 결재라인 섹션
          _buildInfoSection('결재라인', [
            _buildApprovalLine(),
          ]),

          const SizedBox(height: 32),

          // 내용 섹션
          _buildInfoSection('문서 내용', [
            _buildDocumentContent(),
          ]),

          const SizedBox(height: 32),

          // 첨부파일 섹션
          _buildInfoSection('첨부파일', [
            _buildAttachmentSection(),
          ]),
        ],
      ),
    );
  }

  /// 모달 하단 버튼
  Widget _buildModalFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFE9ECEF)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              // 인쇄 기능 추후 구현
              print('인쇄: ${document.documentNo}');
            },
            icon: const Icon(Icons.print),
            label: const Text('인쇄'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              // 수정 기능 추후 구현
              print('수정: ${document.documentNo}');
            },
            icon: const Icon(Icons.edit),
            label: const Text('수정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A745),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 섹션 빌드
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  /// 정보 행 빌드
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D1F),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6C757D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 결재라인 빌드
  Widget _buildApprovalLine() {
    // 더미 결재라인 데이터
    final approvers = ['김과장', '이차장', '박부장'];
    final approvalStatus = ['승인', '대기', '미처리'];

    return Row(
      children: approvers.asMap().entries.map((entry) {
        final index = entry.key;
        final approver = entry.value;
        final status = approvalStatus[index];
        final isLast = index == approvers.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _getApprovalStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getApprovalStatusColor(status)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        approver,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: _getApprovalStatusColor(status),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Color(0xFF6C757D),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 문서 내용 빌드
  Widget _buildDocumentContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D1F),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '여기에 실제 문서 내용이 표시됩니다. 추후 구체적인 문서 내용을 로드하여 표시할 예정입니다.',
            style: TextStyle(
              color: Color(0xFF6C757D),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Color(0xFF8B95A1),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '문서 내용 영역',
                    style: TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '(추후 구현 예정)',
                    style: TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 첨부파일 섹션 빌드
  Widget _buildAttachmentSection() {
    // 더미 첨부파일 데이터
    final attachments = ['신청서.pdf', '참고자료.xlsx'];

    if (attachments.isEmpty) {
      return const Text(
        '첨부파일이 없습니다.',
        style: TextStyle(
          color: Color(0xFF8B95A1),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: attachments
          .map(
            (filename) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    color: Color(0xFF4A6CF7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // 다운로드 기능 추후 구현
                      print('다운로드: $filename');
                    },
                    icon: const Icon(Icons.download),
                    tooltip: '다운로드',
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  /// 상태에 따른 색상 반환
  Color _getStatusColor(String status) {
    switch (status) {
      case '완료':
        return const Color(0xFF28A745);
      case '진행중':
        return const Color(0xFF007BFF);
      case '대기중':
        return const Color(0xFFFFC107);
      case '검토중':
        return const Color(0xFF17A2B8);
      default:
        return const Color(0xFF6C757D);
    }
  }

  /// 결재 상태에 따른 색상 반환
  Color _getApprovalStatusColor(String status) {
    switch (status) {
      case '승인':
        return const Color(0xFF28A745);
      case '대기':
        return const Color(0xFFFFC107);
      case '미처리':
        return const Color(0xFF6C757D);
      case '반려':
        return const Color(0xFFDC3545);
      default:
        return const Color(0xFF6C757D);
    }
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}
