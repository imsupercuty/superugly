// lib/step1_category_selection_screen.dart

import 'package:flutter/material.dart';
import 'step2_detail_selection_screen.dart';

// 카테고리별 단어 목록 정의 (사용자 요청에 따라 캡처된 단어 포함)
const Map<String, List<String>> _categoryData = {
  '감정': ['기쁨', '슬픔', '우울', '화남', '행복', '짜증', '공포', '지침', '사랑', '안정', '여유', '긴장', '평화', '애정', '그리움', '포근함', '따뜻함', '무서움', '무기력', '혼란', '불편함'],
  '날씨': ['맑음', '흐림', '비', '눈', '바람', '습함', '건조함', '쌀쌀함', '더움', '안개', '햇살'],
  '상태': ['휴식', '집중', '명상', '활력 충전', '스트레스 해소', '수면', '운동', '공부', '여행', '데이트', '파티', '독서'],
  '직접입력': ['직접입력'],
};

class Step1Screen extends StatelessWidget {
  final DateTime selectedDate;

  const Step1Screen({super.key, required this.selectedDate});

  // 카테고리 버튼 UI 정의
  Widget _buildCategoryCard(BuildContext context, String title, IconData icon) {
    return InkWell(
      onTap: () async {
        if (title == '직접입력') {
          // 직접 입력은 간단히 다이얼로그로 처리하고 결과를 반환합니다.
          final result = await _showDirectInputDialog(context);
          if (result != null && result.isNotEmpty) {
            Navigator.pop(context, '직접입력: $result');
          }
        } else {
          // Step 2 화면으로 이동하며 선택된 카테고리의 단어 목록을 전달
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Step2Screen(
                categoryTitle: title,
                words: _categoryData[title]!,
              ),
            ),
          );
          // Step 2에서 최종 선택된 결과가 돌아오면, 메인 달력 화면으로 다시 전달
          if (result != null) {
            Navigator.pop(context, result);
          }
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.black),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // 직접 입력 다이얼로그 (간단 구현)
  Future<String?> _showDirectInputDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('직접 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "내용을 입력해주세요."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 뒤로가기 버튼 유지
        title: const Text('STEP 1'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '먼저 원하시는 목록을\n선택해주세요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // 🚨 카테고리 선택 Grid UI
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildCategoryCard(context, '감정', Icons.sentiment_satisfied_alt),
                  _buildCategoryCard(context, '날씨', Icons.wb_sunny_outlined),
                  _buildCategoryCard(context, '상태', Icons.battery_charging_full),
                  _buildCategoryCard(context, '직접입력', Icons.edit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}