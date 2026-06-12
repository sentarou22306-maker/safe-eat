import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safe Eat Japan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アプリの目的を伝えるウェルカムメッセージ
            const Icon(Icons.health_and_safety, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              '安心して食事を楽しもう',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '商品のバーコードを読み取って\nアレルギー情報を確認できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // 🌟 スキャン画面へ移動するための特大ボタン！
            ElevatedButton.icon(
              onPressed: () {
                // main.dart で設定した '/scan' の道を通って次の画面へジャンプ！
                context.push('/scan');
              },
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text('バーコードをスキャン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // ボタンを丸くして押しやすく
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
