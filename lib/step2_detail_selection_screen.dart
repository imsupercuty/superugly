// lib/step2_detail_selection_screen.dart

import 'package:flutter/material.dart';

class Step2Screen extends StatefulWidget {
  final String categoryTitle;
  final List<String> words;

  const Step2Screen({
    super.key,
    required this.categoryTitle,
    required this.words,
  });

  @override
  State<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<Step2Screen> {
  // 사용자가 선택한 단어들을 저장하는 집합(Set)
  Set<String> _selectedWords = {};

  // 단어 선택/해제 토글
  void _toggleWordSelection(String word) {
    setState(() {
      if (_selectedWords.contains(word)) {
        _selectedWords.remove(word);
      } else {
        _selectedWords.add(word);
      }
    });
  }

  // 🚨 최종 선택 완료 후 메인 달력 화면으로 결과 전달
  void _completeSelection() {
    if (_selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 하나 이상 선택해주세요.'), duration: Duration(seconds: 1)),
      );
      return;
    }

    // 선택된 단어들을 하나의 문자열로 조합하여 반환 ("감정: 기쁨, 행복, 사랑")
    final resultString = '${widget.categoryTitle}: ${_selectedWords.join(', ')}';

    // Navigator.pop을 사용하여 결과를 Step 1 화면으로 전달
    Navigator.pop(context, resultString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        centerTitle: true,
        actions: [
          // 완료 버튼
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _completeSelection,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STEP 2\n다음으로 원하시는 단어를\n선택해주세요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // 🚨 선택 가능한 단어 그리드 UI (Wrap 사용)
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: widget.words.map((word) {
                    final isSelected = _selectedWords.contains(word);
                    return ActionChip(
                      label: Text(word),
                      // 선택 상태에 따라 색상 변경
                      backgroundColor: isSelected ? Colors.teal[300] : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onPressed: () => _toggleWordSelection(word),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}