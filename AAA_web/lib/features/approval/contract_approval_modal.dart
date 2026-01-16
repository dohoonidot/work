import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 매출/매입계약 기안서 전용 모달
class ContractApprovalModal extends ConsumerStatefulWidget {
  const ContractApprovalModal({super.key});

  @override
  ConsumerState<ContractApprovalModal> createState() =>
      _ContractApprovalModalState();
}

class _ContractApprovalModalState extends ConsumerState<ContractApprovalModal>
    with TickerProviderStateMixin {
  // 테이블 헤더 데이터
  List<String> _headerData = [
    '항목',
    '금액',
    '거래처',
    '세금계산서 발행예정일',
    '결제조건',
    '특이사항',
  ];

  // 매출/매입계약 기안서 테이블 데이터
  // ignore: prefer_final_fields
  List<Map<String, dynamic>> _contractTableData = [
    {
      'item': 'H/W 매출',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
    },
    {
      'item': 'S/W 매출',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
    },
    {
      'item': '컨설팅 또는 개발매출',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
    },
    {
      'item': '기타 매출',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
    },
    {
      'item': '매출액',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isTotal': true,
    },
    {
      'item': '3rd Party 컨설팅 또는 개발용역비 원가',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isAddable': true, // 추가 가능한 항목 표시
    },
    {
      'item': '매입액',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isTotal': true,
    },
    {
      'item': '원가총액',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isTotal': true,
    },
    {
      'item': '매출총이익',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isTotal': true,
    },
    {
      'item': '이익율',
      'amount': '',
      'client': '',
      'taxInvoiceDate': '',
      'paymentTerms': '',
      'remarks': '',
      'isTotal': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '결재 상세',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildContractTable(),
        const SizedBox(height: 24),
        _buildSalesContractTable(),
      ],
    );
  }

  /// 매출/매입계약 기안서 테이블
  Widget _buildContractTable() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 테이블 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildEditableHeaderCell(0)),
                _buildVerticalDivider(),
                Expanded(flex: 1, child: _buildEditableHeaderCell(1)),
                _buildVerticalDivider(),
                Expanded(flex: 1, child: _buildEditableHeaderCell(2)),
                _buildVerticalDivider(),
                Expanded(flex: 1, child: _buildEditableHeaderCell(3)),
                _buildVerticalDivider(),
                Expanded(flex: 1, child: _buildEditableHeaderCell(4)),
                _buildVerticalDivider(),
                Expanded(flex: 1, child: _buildEditableHeaderCell(5)),
              ],
            ),
          ),
          // 테이블 바디
          ..._contractTableData.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;

            return Container(
                decoration: BoxDecoration(
                  color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF4A5568)
                          : const Color(0xFFE9ECEF),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? null
                              : const Color(0xFFF8F9FA), // 라이트 테마에서만 옅은 회색
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: row['isAddable'] == true
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['item'],
                                      style: TextStyle(
                                        color: isDarkTheme
                                            ? Colors.white
                                            : const Color(0xFF1A1D1F),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _addContractItem(index),
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      size: 18,
                                      color: const Color(0xFF4A6CF7),
                                    ),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              )
                            : row['isCustom'] == true
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row['item'],
                                          style: TextStyle(
                                            color: isDarkTheme
                                                ? Colors.white
                                                : const Color(0xFF1A1D1F),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _removeContractItem(index),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: const Color(0xFFEF4444),
                                        ),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    onDoubleTap: () => _editItemName(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              row['item'],
                                              style: TextStyle(
                                                color: isDarkTheme
                                                    ? Colors.white
                                                    : const Color(0xFF1A1D1F),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.edit,
                                            color: isDarkTheme
                                                ? Colors.white54
                                                : Colors.grey,
                                            size: 12,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: TextFormField(
                          initialValue: row['amount'],
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: isDarkTheme
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _contractTableData[index]['amount'] = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: TextFormField(
                          initialValue: row['client'],
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: isDarkTheme
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _contractTableData[index]['client'] = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: TextFormField(
                          initialValue: row['taxInvoiceDate'],
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: isDarkTheme
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _contractTableData[index]['taxInvoiceDate'] =
                                  value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: TextFormField(
                          initialValue: row['paymentTerms'],
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: isDarkTheme
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _contractTableData[index]['paymentTerms'] = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          initialValue: row['remarks'],
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: isDarkTheme
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _contractTableData[index]['remarks'] = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ));
          }).toList(),
        ],
      ),
    );
  }

  /// 헤더 구분선
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white30,
    );
  }

  /// 편집 가능한 테이블 헤더 셀
  Widget _buildEditableHeaderCell(int index) {
    return GestureDetector(
      onDoubleTap: () => _editHeaderCell(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _headerData[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.edit,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  /// 계약 항목 추가
  void _addContractItem(int afterIndex) {
    setState(() {
      _contractTableData.insert(afterIndex + 1, {
        'item': '3rd Party 컨설팅 또는 개발용역비 원가',
        'amount': '',
        'client': '',
        'taxInvoiceDate': '',
        'paymentTerms': '',
        'remarks': '',
        'isCustom': true, // 사용자가 추가한 항목 표시
      });
    });
  }

  /// 계약 항목 삭제
  void _removeContractItem(int index) {
    setState(() {
      _contractTableData.removeAt(index);
    });
  }

  /// 헤더 셀 편집
  void _editHeaderCell(int index) {
    showDialog(
      context: context,
      builder: (context) {
        String newText = _headerData[index];
        return AlertDialog(
          title: const Text('헤더 편집'),
          content: TextField(
            autofocus: true,
            controller: TextEditingController(text: newText),
            onChanged: (value) => newText = value,
            decoration: const InputDecoration(
              labelText: '헤더 텍스트',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _headerData[index] = newText;
                });
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 항목명 편집
  void _editItemName(int index) {
    showDialog(
      context: context,
      builder: (context) {
        String newText = _contractTableData[index]['item'];
        return AlertDialog(
          title: const Text('항목명 편집'),
          content: TextField(
            autofocus: true,
            controller: TextEditingController(text: newText),
            onChanged: (value) => newText = value,
            decoration: const InputDecoration(
              labelText: '항목명',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _contractTableData[index]['item'] = newText;
                });
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 매출 계약 내역서 테이블
  Widget _buildSalesContractTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE9ECEF),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 제목
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              '매출 계약 내역서',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 계약 정보 테이블
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                _buildContractInfoRow('계약명', 'contractName'),
                _buildContractInfoRow('계약업체', 'contractCompany'),
                _buildContractInfoRow('계약기간', 'contractPeriod'),
                _buildContractInfoRow('계약금액 (부가세별도)', 'contractAmount'),
                _buildContractInfoRow('청구시점', 'billingPoint'),
                _buildContractInfoRow('결제조건', 'paymentTerms'),
                _buildContractInfoRow('계약일자', 'contractDate'),
                _buildContractInfoRow('당사', 'ourCompany'),
                _buildContractInfoRow('계약사', 'contractingParty'),
                _buildContractInfoRow('첨부', 'attachments', isAttachment: true),
                _buildContractInfoRow('특이사항', 'specialNotes',
                    isMultiline: true),
              ],
            ),
          ),
          // 하단 안내사항
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• 특이사항란에는 계약 진행시 유의할점 및 위약사항에 따른 불이익등을 기입해 주시기 바랍니다.',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 계약내용란에는 유지보수내역을 상세히 기입해 주시기 바랍니다. 예) 인력투입 시 투입인원, 업무내용 등',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 계약No. 란은 관리팀에서 작성할 부분이니 기입하지 마시기 바랍니다.',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 매출& 매입계약 PA 요약 및 계약서(원본 or 사본) 첨부.',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 계약 정보 행
  Widget _buildContractInfoRow(String label, String fieldKey,
      {bool isAttachment = false, bool isMultiline = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // 라벨
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: const Border(
                right: BorderSide(
                  color: Color(0xFFE9ECEF),
                ),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 입력 필드
          Expanded(
            child: isAttachment
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        right: BorderSide(
                          color: Color(0xFFE9ECEF),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. 계약서 (Contract)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '2. PL Sheet [ 반드시 첨부해 주세요] (PL Sheet [Please attach without fail])',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextFormField(
                    maxLines: isMultiline ? 3 : 1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(
                          color: Color(0xFFE9ECEF),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        // TODO: 계약 정보 저장 로직 구현
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
