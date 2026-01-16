
// lib/models/received_gift.dart

class ReceivedGift {
  final String id;
  final String message;
  final String couponImgUrl;
  final String couponEndDate;
  final String senderName;
  final DateTime receivedDate;
  bool isRead;

  ReceivedGift({
    required this.id,
    required this.message,
    required this.couponImgUrl,
    required this.couponEndDate,
    required this.senderName,
    required this.receivedDate,
    this.isRead = false,
  });

  factory ReceivedGift.fromServerData(Map<String, dynamic> data) {
    return ReceivedGift(
      id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: data['message'] ?? '선물이 도착했습니다.',
      couponImgUrl: data['couponImgUrl'] ?? '',
      couponEndDate: data['coupon_end_date'] ?? '',
      senderName: data['sender_name'] ?? 'ASPN AI',
      receivedDate: data['send_time'] != null ? DateTime.parse(data['send_time']) : DateTime.now(),
    );
  }
}
