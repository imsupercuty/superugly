// lib/scent_gemini_screen.dart

import 'package:flutter/material.dart';
import 'scent_models.dart';
import 'gemini_service.dart';

// ====================================================
// [1] ScentGeminiScreen - 향 정보 화면 (Gemini API 활용)
// ====================================================
class ScentGeminiScreen extends StatefulWidget {
  const ScentGeminiScreen({super.key});

  @override
  State<ScentGeminiScreen> createState() => _ScentGeminiScreenState();
}

class _ScentGeminiScreenState extends State<ScentGeminiScreen> {
  // 1. 상태 변수 및 컨트롤러 정의
  late Future<List<ScentInfo>> _scentInfoFuture;
  final TextEditingController _searchController = TextEditingController(); // 검색창

  @override
  void initState() {
    super.initState();
    _scentInfoFuture = fetchScentInfo(); // 15가지 향 정보 로드
  }

  // 검색 아이콘 클릭 시 Gemini API를 호출하여 상세 정보를 가져오는 함수
  Future<void> _fetchDetailedScentInfo(String query) async {
    if (query.isEmpty) {
      _showResultDialog(context, '검색 오류', '검색어를 입력해 주세요.');
      return;
    }

    _showLoadingDialog(context);

    try {
      final prompt =
          '**"${query}"** 향에 대해 향의 정보(특징), 향의 역사, 기능/효능, 상징적 의미를 나누어 상세하게 한국어로 설명해줘.';

      final result = await getGeminiRecommendation(prompt);

      if (mounted) Navigator.of(context).pop();

      _showResultDialog(context, '\'$query\' 상세 분석 (AI)', result);

    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showResultDialog(context, 'API 오류', '정보를 가져오는 데 실패했습니다: ${e.toString()}');
    }
  }

  // 로딩 다이얼로그 (검색용)
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('정보 분석 중...'),
          ],
        ),
      ),
    );
  }

  // 검색 결과를 보여주는 다이얼로그 함수
  void _showResultDialog(BuildContext context, String title, String result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(result, style: const TextStyle(height: 1.5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 2. 향 검색창 영역
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '궁금한 향(예: 라벤더, 샌달우드)을 검색하세요.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
                  ),
                  onSubmitted: _fetchDetailedScentInfo,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _fetchDetailedScentInfo(_searchController.text);
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. 향 정보 리스트 (스크롤 가능)
        Expanded(
          child: FutureBuilder<List<ScentInfo>>(
            future: _scentInfoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text(
                  '정보 로드 오류: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ));
              } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final scentList = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  itemCount: scentList.length,
                  itemBuilder: (context, index) {
                    final scent = scentList[index];
                    return ScentCategoryCard(
                      icon: scent.icon,
                      title: scent.title,
                      description: scent.description,
                    );
                  },
                );
              }
              return const Center(child: Text('표시할 향 정보가 없습니다.'));
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ====================================================
// [2] ScentCategoryCard 위젯
// ====================================================
class ScentCategoryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const ScentCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}