import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

/// 구매신청서 전용 모달
class PurchaseRequestModal extends ConsumerStatefulWidget {
  const PurchaseRequestModal({super.key});

  @override
  ConsumerState<PurchaseRequestModal> createState() =>
      _PurchaseRequestModalState();
}

class _PurchaseRequestModalState extends ConsumerState<PurchaseRequestModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  // 구매신청서 데이터
  String? _purpose;
  String? _totalCost;
  String? _quotation;
  String? _remarks;

  // 구매 항목 테이블 데이터
  List<Map<String, dynamic>> _purchaseItems = [
    {
      'item': '',
      'unitPrice': '',
      'quantity': '',
      'amount': '',
      'remarks': '',
    },
    {
      'item': '',
      'unitPrice': '',
      'quantity': '',
      'amount': '',
      'remarks': '',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '구매신청서',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPurposeSection(),
            const SizedBox(height: 16),
            _buildPurchaseTable(),
            const SizedBox(height: 16),
            _buildTotalCostSection(),
            const SizedBox(height: 16),
            _buildQuotationSection(),
            const SizedBox(height: 16),
            _buildRemarksSection(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitDraft,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('상신'),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. 목적(사유) 섹션
  Widget _buildPurposeSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. 목적 (사유)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        FormBuilderTextField(
          name: 'purpose',
          decoration: _buildInputDecoration('구매 목적 및 사유를 입력하세요'),
          maxLines: 3,
          validator: FormBuilderValidators.required(errorText: '목적(사유)은 필수입니다'),
          onChanged: (value) {
            setState(() {
              _purpose = value;
            });
          },
        ),
      ],
    );
  }

  /// 2. 내용 및 비용 테이블 섹션
  Widget _buildPurchaseTable() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. 내용 및 비용',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
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
                    Expanded(flex: 2, child: _buildHeaderCell('구입 항목')),
                    Expanded(flex: 1, child: _buildHeaderCell('단가*')),
                    Expanded(flex: 1, child: _buildHeaderCell('수량')),
                    Expanded(flex: 1, child: _buildHeaderCell('금액*')),
                    Expanded(flex: 1, child: _buildHeaderCell('비고')),
                  ],
                ),
              ),
              // 테이블 바디
              ..._purchaseItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

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
                      // 구입 항목
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            initialValue: item['item'],
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
                                _purchaseItems[index]['item'] = value;
                              });
                            },
                          ),
                        ),
                      ),
                      // 단가
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            initialValue: item['unitPrice'],
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF1A1D1F),
                              fontSize: 12,
                            ),
                            keyboardType: TextInputType.number,
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
                                _purchaseItems[index]['unitPrice'] = value;
                                _calculateAmount(index);
                              });
                            },
                          ),
                        ),
                      ),
                      // 수량
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            initialValue: item['quantity'],
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF1A1D1F),
                              fontSize: 12,
                            ),
                            keyboardType: TextInputType.number,
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
                                _purchaseItems[index]['quantity'] = value;
                                _calculateAmount(index);
                              });
                            },
                          ),
                        ),
                      ),
                      // 금액
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            initialValue: item['amount'],
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF1A1D1F),
                              fontSize: 12,
                            ),
                            readOnly: true,
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
                          ),
                        ),
                      ),
                      // 비고
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            initialValue: item['remarks'],
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
                                _purchaseItems[index]['remarks'] = value;
                              });
                            },
                          ),
                        ),
                      ),
                      // 삭제 버튼 (2개 이상일 때만 표시)
                      if (_purchaseItems.length > 1)
                        Container(
                          width: 40,
                          padding: const EdgeInsets.all(8),
                          child: IconButton(
                            onPressed: () => _removePurchaseItem(index),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: isDarkTheme
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFEF4444),
                            ),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '* VAT 포함 여부 必',
          style: TextStyle(
            fontSize: 10,
            color:
                isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _addPurchaseItem,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('항목 추가'),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. 총 비용 섹션
  Widget _buildTotalCostSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. 총 비용',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
          ),
          child: Text(
            _calculateTotalCost(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            ),
          ),
        ),
      ],
    );
  }

  /// 4. 견적서 섹션
  Widget _buildQuotationSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '4. 견적서',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        FormBuilderTextField(
          name: 'quotation',
          decoration: _buildInputDecoration('견적서 정보를 입력하세요'),
          maxLines: 2,
          onChanged: (value) {
            setState(() {
              _quotation = value;
            });
          },
        ),
      ],
    );
  }

  /// 5. 비고 섹션
  Widget _buildRemarksSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '5. 비고',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '항목별 구매처 URL, 정보, 업체, 구매방법 등 정보 기입',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF4A6CF7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FormBuilderTextField(
          name: 'remarks',
          decoration: _buildInputDecoration('추가 비고사항을 입력하세요'),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              _remarks = value;
            });
          },
        ),
      ],
    );
  }

  /// 테이블 헤더 셀
  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 입력 필드 데코레이션
  InputDecoration _buildInputDecoration(String label) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDarkTheme ? const Color(0xFFA0AEC0) : const Color(0xFF6C757D),
        fontSize: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7)),
      ),
      filled: true,
      fillColor: isDarkTheme ? const Color(0xFF2D3748) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  /// 금액 계산
  void _calculateAmount(int index) {
    final unitPrice =
        double.tryParse(_purchaseItems[index]['unitPrice'] ?? '0') ?? 0;
    final quantity =
        double.tryParse(_purchaseItems[index]['quantity'] ?? '0') ?? 0;
    final amount = unitPrice * quantity;

    setState(() {
      _purchaseItems[index]['amount'] = amount.toStringAsFixed(0);
      // 총 비용도 함께 업데이트
      _calculateTotalCost();
    });
  }

  /// 총 비용 계산
  String _calculateTotalCost() {
    double total = 0;
    for (final item in _purchaseItems) {
      final amount = double.tryParse(item['amount'] ?? '0') ?? 0;
      total += amount;
    }
    final totalCostString = total > 0 ? '${total.toStringAsFixed(0)}원' : '0원';

    // _totalCost 변수에 저장
    setState(() {
      _totalCost = totalCostString;
    });

    return totalCostString;
  }

  /// 구매 항목 추가
  void _addPurchaseItem() {
    setState(() {
      _purchaseItems.add({
        'item': '',
        'unitPrice': '',
        'quantity': '',
        'amount': '',
        'remarks': '',
      });
    });
  }

  /// 구매 항목 삭제
  void _removePurchaseItem(int index) {
    if (_purchaseItems.length > 1) {
      setState(() {
        _purchaseItems.removeAt(index);
        // 총 비용 재계산
        _calculateTotalCost();
      });
    }
  }

  /// 상신 처리
  Future<void> _submitDraft() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입력 정보를 확인해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _formKey.currentState?.save();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상신 확인'),
        content: const Text('구매신청서를 상신하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('상신'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // 구매신청서 상신 데이터 로그
        print('📋 구매신청서 상신 데이터:');
        print('  - 목적(사유): $_purpose');
        print('  - 구매 항목: $_purchaseItems');
        print('  - 총 비용: $_totalCost');
        print('  - 견적서: $_quotation');
        print('  - 비고: $_remarks');

        // TODO: 실제 API 호출 로직 구현
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구매신청서가 성공적으로 상신되었습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('상신 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
}
