import 'package:flutter/material.dart';

class IconPreviewPage extends StatelessWidget {
  const IconPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('선물 관련 아이콘 미리보기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '선물 관련 Material Icons',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 아이콘 그리드
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildIconCard('Icons.redeem', Icons.redeem, '선물 받기'),
                  _buildIconCard(
                      'Icons.local_offer', Icons.local_offer, '할인/쿠폰 태그'),
                  _buildIconCard('Icons.confirmation_number',
                      Icons.confirmation_number, '쿠폰/티켓'),
                  _buildIconCard(
                      'Icons.card_giftcard', Icons.card_giftcard, '선물 카드'),
                  _buildIconCard('Icons.inbox', Icons.inbox, '받은 편지함'),
                  _buildIconCard(
                      'Icons.folder_special', Icons.folder_special, '특별한 폴더'),
                  _buildIconCard('Icons.inventory', Icons.inventory, '인벤토리'),
                  _buildIconCard('Icons.favorite', Icons.favorite, '좋아요/하트'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCard(String iconName, IconData icon, String description) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            Text(
              iconName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
