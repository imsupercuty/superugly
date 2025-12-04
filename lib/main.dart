import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// 기존에 존재한다고 가정하는 파일들 (실제 환경에서는 이 파일들이 프로젝트에 있어야 합니다)
import 'scent_gemini_screen.dart';
import 'gemini_service.dart';
// import 'step1_category_selection_screen.dart'; // 기존 파일 대신 아래 Step1Screen/Step2Screen을 사용합니다.


// ====================================================
// [A] 헬퍼 함수 및 AI 진단 로직
// ====================================================

// AI 진단 결과를 보여주는 다이얼로그
void _showResultDialog(BuildContext context, String title, String content) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(height: 1.5)),
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

// 로딩 다이얼로그 함수
void _showLoadingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15.0))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFADD8E6)),
          SizedBox(height: 20),
          Text(
            'AI 향 진단 분석 중...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            '당신의 감정과 날씨를 기반으로\n최적의 향을 블렌딩하고 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}

// Step별 데이터를 저장할 구조체 (AI 진단용)
class DiagnosisData {
  Set<String> emotions = {};
  Set<String> weathers = {};
  Set<String> states = {};
  final customEmotionController = TextEditingController();
  final customWeatherController = TextEditingController();
  final customStateController = TextEditingController();

  void disposeControllers() {
    customEmotionController.dispose();
    customWeatherController.dispose();
    customStateController.dispose();
  }
}

// 각 단계의 UI 콘텐츠 (Chip 선택 및 직접 입력)를 담당하는 위젯 (AI 진단용)
class DiagnosisStepContent extends StatefulWidget {
  final String stepName;
  final List<String> wordList;
  final Set<String> selectedSet;
  final TextEditingController customController;

  const DiagnosisStepContent({
    super.key,
    required this.stepName,
    required this.wordList,
    required this.selectedSet,
    required this.customController,
  });

  @override
  State<DiagnosisStepContent> createState() => _DiagnosisStepContentState();
}

class _DiagnosisStepContentState extends State<DiagnosisStepContent> {

  void _onCustomTextChanged(String newText) {
    setState(() {});
  }

  void _onClearCustomText() {
    setState(() {
      final oldText = widget.customController.text;
      widget.customController.clear();
      widget.selectedSet.remove(oldText);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepNameWidget = Text(
      widget.stepName,
      style: TextStyle(fontSize: 16, color: Theme
          .of(context)
          .colorScheme
          .primary, fontWeight: FontWeight.w500),
    );

    // 단어 리스트를 3개씩 GridView로 표시
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepNameWidget,
        const SizedBox(height: 10),

        // 단어 선택 영역 (GridView.count 사용)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 2.5,
          children: widget.wordList.map((word) {
            final isSelected = widget.selectedSet.contains(word);
            return InputChip(
              label: Text(
                word,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              side: BorderSide.none,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),

              backgroundColor: isSelected
                  ? Theme
                  .of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.8)
                  : Colors.grey[200],

              selected: isSelected,
              padding: EdgeInsets.zero,

              onPressed: () {
                setState(() {
                  if (isSelected) {
                    widget.selectedSet.remove(word);
                  } else {
                    widget.selectedSet.add(word);
                  }
                });
              },
            );
          }).toList(),
        ),

        const Divider(height: 30),

        // 직접 입력 영역
        Text(
          '또는 직접 입력 (진단 시 반영):',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.customController,
          decoration: InputDecoration(
            hintText: '자유롭게 입력해주세요.',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: widget.customController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _onClearCustomText,
            )
                : null,
          ),
          onChanged: _onCustomTextChanged,
        ),
      ],
    );
  }
}

// 단계별 데이터를 관리하고 다음/이전 버튼 로직을 처리하는 메인 다이얼로그 (AI 진단용)
class ScentDiagnosisStepperDialog extends StatefulWidget {
  const ScentDiagnosisStepperDialog({super.key});

  @override
  State<ScentDiagnosisStepperDialog> createState() => _ScentDiagnosisStepperDialogState();
}

class _ScentDiagnosisStepperDialogState extends State<ScentDiagnosisStepperDialog> {
  int _currentStep = 1;
  final DiagnosisData _data = DiagnosisData();

  // 각 단계별 단어 리스트
  final List<String> emotions = ['기쁨', '슬픔', '우울', '불안', '평온함', '활기참', '지루함', '피로함', '사랑', '분노', '행복', '만족', '따뜻함', '고독', '새로움'];
  final List<String> weathers = ['맑음', '비', '흐림', '눈', '바람', '습함', '건조함', '쌀쌀함', '더움', '안개', '햇살', '소나기', '뇌우', '미세먼지', '서늘함'];
  final List<String> states = ['휴식', '집중', '명상', '분위기 전환', '활력 충전', '로맨틱', '스트레스 해소', '수면', '운동', '공부', '여행', '데이트', '파티', '재택근무', '독서'];

  @override
  void dispose() {
    _data.disposeControllers();
    super.dispose();
  }

  // 다음 단계로 이동/진단 실행 로직
  void _onNextPressed(BuildContext context) async {
    Set<String> currentSelectedSet;
    TextEditingController currentController;
    String currentStepName;

    if (_currentStep == 1) {
      currentSelectedSet = _data.emotions;
      currentController = _data.customEmotionController;
      currentStepName = '감정';
    } else if (_currentStep == 2) {
      currentSelectedSet = _data.weathers;
      currentController = _data.customWeatherController;
      currentStepName = '날씨';
    } else {
      currentSelectedSet = _data.states;
      currentController = _data.customStateController;
      currentStepName = '상태/목적';
    }

    if (currentController.text.isNotEmpty && !currentSelectedSet.contains(currentController.text.trim())) {
      currentSelectedSet.add(currentController.text.trim());
    }

    // 입력 검증
    if (currentSelectedSet.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$currentStepName 단어를 하나 이상 선택하거나 직접 입력해 주세요.'), duration: const Duration(seconds: 1)),
        );
      }
      return;
    }

    // 단계 이동 또는 진단 실행
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      // 🚨 최종 진단 실행 🚨
      if (mounted) Navigator.of(context).pop();
      _data.disposeControllers();

      // 최종 프롬프트 구성
      final emotionText = _data.emotions.join(', ');
      final weatherText = _data.weathers.join(', ');
      final stateText = _data.states.join(', ');

      final prompt =
          '현재 감정: ${emotionText.isEmpty ? '미입력' : emotionText}, 날씨: ${weatherText.isEmpty ? '미입력' : weatherText}, 상태/목적: ${stateText.isEmpty ? '미입력' : stateText}. 이 세 가지 요소를 종합적으로 고려하여 사용자에게 가장 적합한 향수 계열 3가지와 그 이유 및 특징을 상세하게 설명해줘. 답변은 번호가 매겨진 목록 형식(1., 2., 3.)으로 구성하고, 각 항목의 설명은 60자 이내로 친절하게 작성해줘.';

      _showLoadingDialog(context); // 로딩 다이얼로그 띄우기

      try {
        // 'gemini_service.dart' 파일의 getGeminiRecommendation 함수 호출을 가정
        // final result = await getGeminiRecommendation(prompt);
        const result = '1. Floral: 기쁨과 행복을 더욱 강조하며 따뜻하고 로맨틱한 분위기를 연출합니다.\n2. Fresh: 활기참과 새로움을 더해 스트레스 해소에 도움을 줍니다.\n3. Woody: 평온함과 집중을 유도하여 차분하고 안정적인 상태를 만듭니다.';


        if (mounted) Navigator.of(context).pop();
        if (mounted) _showResultDialog(context, '맞춤형 AI 향 추천 결과', result);

      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) _showResultDialog(context, '진단 실패 (API 오류)', '추천 정보를 가져오는 데 실패했습니다: ${e.toString()}');
      }
    }
  }

  // 이전 단계로 이동 로직
  void _onPreviousPressed() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      // 1단계에서 취소
      if (mounted) Navigator.of(context).pop();
      _data.disposeControllers();
    }
  }

  // 단계별 위젯 반환
  Widget _buildCurrentStepWidget() {
    if (_currentStep == 1) {
      return DiagnosisStepContent(
        stepName: '현재 감정 (복수 선택 및 입력 가능)',
        wordList: emotions,
        selectedSet: _data.emotions,
        customController: _data.customEmotionController,
      );
    } else if (_currentStep == 2) {
      return DiagnosisStepContent(
        stepName: '오늘의 날씨/주변 환경 (복수 선택 및 입력 가능)',
        wordList: weathers,
        selectedSet: _data.weathers,
        customController: _data.customWeatherController,
      );
    } else {
      return DiagnosisStepContent(
        stepName: '원하는 상태/목적 (복수 선택 및 입력 가능)',
        wordList: states,
        selectedSet: _data.states,
        customController: _data.customStateController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'AI 향 진단 (Step $_currentStep/3)';
    String nextButtonText = _currentStep < 3 ? '다음 단계' : '진단받기';

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: _buildCurrentStepWidget(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onPreviousPressed,
          child: Text(_currentStep > 1 ? '이전' : '취소'),
        ),
        ElevatedButton(
          onPressed: () => _onNextPressed(context),
          child: Text(nextButtonText),
        ),
      ],
    );
  }
}

// 단계별 AI 추천 입력 및 진단 로직 호출 함수
void _showRecommendationDialog(BuildContext context) {
  // 리팩토링된 Stepper Dialog 위젯을 호출
  showDialog(
    context: context,
    builder: (context) => const ScentDiagnosisStepperDialog(),
  );
}

// ----------------------------------------------------
// 🚨 [B] 다이어리 키워드 누적 선택 및 저장 로직 (Step1Screen, Step2Screen) 🚨
// ----------------------------------------------------

// Step별 데이터를 저장하고 관리하는 클래스 (다이어리 작성용)
class DiaryData {
  Set<String> emotions = {};
  Set<String> weathers = {};
  Set<String> states = {};
  String customText = ''; // 직접 입력 내용을 위한 필드

  // 누적된 모든 키워드를 합쳐서 반환하는 함수
  String get combinedKeywords {
    final List<String> parts = [];
    if (emotions.isNotEmpty) {
      parts.add('감정: ${emotions.join(', ')}');
    }
    if (weathers.isNotEmpty) {
      parts.add('날씨: ${weathers.join(', ')}');
    }
    if (states.isNotEmpty) {
      parts.add('상태: ${states.join(', ')}');
    }
    if (customText.isNotEmpty) {
      parts.add('직접 입력: $customText');
    }
    return parts.join('\n');
  }
}

// ----------------------------------------------------
// Step 2: 키워드 선택 화면 (Emotion, Weather, State)
// ----------------------------------------------------
class Step2Screen extends StatefulWidget {
  final String categoryName;
  final List<String> wordList;
  final Set<String> initialSelectedSet; // 기존 선택 항목을 받아옴
  final String categoryKey; // DiaryData의 어느 Set에 저장할지 결정

  const Step2Screen({
    super.key,
    required this.categoryName,
    required this.wordList,
    required this.initialSelectedSet,
    required this.categoryKey,
  });

  @override
  State<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<Step2Screen> {
  // 화면 내에서 선택된 키워드를 임시 저장
  late Set<String> _currentSelectedSet;

  @override
  void initState() {
    super.initState();
    // 부모로부터 받은 초기 선택 항목을 복사하여 사용
    _currentSelectedSet = Set<String>.from(widget.initialSelectedSet);
  }

  // 우측 상단 체크 버튼 클릭 시
  void _onSaveAndReturn(BuildContext context) {
    // 키워드를 선택하지 않고 저장할 경우에도 부모에게 변경된 Set(혹은 그대로인 Set)을 반환
    Navigator.pop(context, _currentSelectedSet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _onSaveAndReturn(context),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'STEP 2',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              '다음으로 원하시는 단어를\n선택해주세요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),
          // 키워드 목록
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: widget.wordList.map((word) {
                final isSelected = _currentSelectedSet.contains(word);
                return ActionChip(
                  label: Text(word),
                  backgroundColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        _currentSelectedSet.remove(word);
                      } else {
                        _currentSelectedSet.add(word);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Step 1: 옵션 선택 화면 (Category Selection Screen)
// ----------------------------------------------------
class Step1Screen extends StatefulWidget {
  final DateTime selectedDate;
  const Step1Screen({super.key, required this.selectedDate});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  // 🚨 누적된 선택 키워드를 저장할 인스턴스 🚨
  final DiaryData _data = DiaryData();

  // Step 2로 이동하여 키워드 선택을 진행하고 결과를 업데이트하는 범용 함수
  void _goToStep2(BuildContext context, String categoryName, List<String> wordList, Set<String> currentSet, String categoryKey) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step2Screen(
          categoryName: categoryName,
          wordList: wordList,
          initialSelectedSet: currentSet,
          categoryKey: categoryKey,
        ),
      ),
    );

    // Step 2에서 Set<String>이 반환될 경우
    if (result != null && result is Set<String>) {
      setState(() {
        // 반환된 Set으로 해당 카테고리의 데이터를 덮어씀 (누적 효과)
        if (categoryKey == 'emotion') {
          _data.emotions = result;
        } else if (categoryKey == 'weather') {
          _data.weathers = result;
        } else if (categoryKey == 'state') {
          _data.states = result;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$categoryName 키워드가 ${_data.combinedKeywords.split('\n').where((s) => s.isNotEmpty).length}가지 항목으로 업데이트되었습니다.')),
      );
    }
  }

  // 직접 입력 다이얼로그
  void _showCustomInputDialog() {
    final TextEditingController controller = TextEditingController(text: _data.customText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('직접 입력'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '자유롭게 내용을 입력해주세요.'),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _data.customText = controller.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('직접 입력 내용이 저장되었습니다.')),
                );
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }


  // 최종 다이어리 저장 및 Step 1 화면 닫기
  void _saveDiary() {
    if (_data.emotions.isEmpty && _data.weathers.isEmpty && _data.states.isEmpty && _data.customText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다이어리에 저장할 내용을 하나 이상 선택하거나 입력해주세요.')),
      );
      return;
    }
    // 최종적으로 조합된 다이어리 내용을 CalendarScreen으로 반환
    Navigator.pop(context, _data.combinedKeywords);
  }

  // 옵션 데이터
  final List<String> emotions = ['기쁨', '슬픔', '우울', '화남', '행복', '짜증', '공포', '지침', '사랑', '안정', '여유', '긴장', '평화', '애정', '그리움', '포근함', '따뜻함', '무서움', '무기력', '혼란', '불편함'];
  final List<String> weathers = ['맑음', '비', '흐림', '눈', '바람', '습함', '건조함', '쌀쌀함', '더움', '안개', '햇살', '소나기', '뇌우', '미세먼지', '서늘함'];
  final List<String> states = ['휴식', '집중', '명상', '분위기 전환', '활력 충전', '로맨틱', '스트레스 해소', '수면', '운동', '공부', '여행', '데이트', '파티', '재택근무', '독서'];


  @override
  Widget build(BuildContext context) {
    // 다이어리 항목 위젯
    Widget buildDiaryItem(String title, IconData icon, Set<String> selectedSet) {
      final isSelected = selectedSet.isNotEmpty;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[100],
            ),
            child: Row(
              children: [
                Icon(icon, size: 28, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isSelected)
                        Text(
                          selectedSet.take(3).join(', ') + (selectedSet.length > 3 ? '...' : ''), // 최대 3개 표시
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }

    // 직접 입력 항목 위젯
    Widget buildCustomItem() {
      final isSelected = _data.customText.isNotEmpty;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[100],
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_outlined, size: 28, color: Colors.black87),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('직접 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isSelected)
                        Text(
                          _data.customText.length > 30 ? _data.customText.substring(0, 30) + '...' : _data.customText,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('다이어리 작성 (${DateFormat('yyyy.MM.dd').format(widget.selectedDate)})'),
        centerTitle: true,
        actions: [
          // 🚨 최종 저장 버튼 🚨
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDiary,
            tooltip: '다이어리 저장',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STEP 1',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            const Text(
              '먼저 원하시는 목록을\n선택해주세요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // 🚨 선택 가능한 목록 🚨
            Expanded(
              child: ListView(
                children: [
                  // 1. 감정
                  GestureDetector(
                    onTap: () => _goToStep2(context, '감정', emotions, _data.emotions, 'emotion'),
                    child: buildDiaryItem('감정', Icons.sentiment_satisfied_alt, _data.emotions),
                  ),
                  const SizedBox(height: 10),

                  // 2. 날씨
                  GestureDetector(
                    onTap: () => _goToStep2(context, '날씨', weathers, _data.weathers, 'weather'),
                    child: buildDiaryItem('날씨', Icons.wb_sunny_outlined, _data.weathers),
                  ),
                  const SizedBox(height: 10),

                  // 3. 상태
                  GestureDetector(
                    onTap: () => _goToStep2(context, '상태', states, _data.states, 'state'),
                    child: buildDiaryItem('상태', Icons.battery_charging_full, _data.states),
                  ),
                  const SizedBox(height: 10),

                  // 4. 직접 입력
                  GestureDetector(
                    onTap: _showCustomInputDialog,
                    child: buildCustomItem(),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// [1] Main 함수 및 MyApp 위젯
// ====================================================

void main() async {
  // Flutter 위젯 바인딩이 완료될 때까지 기다립니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 'ko_KR' 로케일 데이터를 초기화합니다. (TableCalendar 한글화에 필수)
  await initializeDateFormatting('ko_KR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperUgly Diary',
      theme: ThemeData(
        // 이 색상은 primaryColor 속성을 대체합니다.
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          primary: const Color(0xFFADD8E6), // 앱의 주 색상 (하늘색 계열)
          secondary: Colors.tealAccent, // 앱의 보조 색상
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

// ====================================================
// [2] MyHomePage - 메인 화면 및 BottomNavigationBar
// ====================================================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0; // 시작 화면을 홈 화면(index 0)으로 설정

  final List<BottomNavigationBarItem> _bottomNavBarItems =  [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
    const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '달력'),
    BottomNavigationBarItem(icon: Icon(MdiIcons.bottleTonicPlusOutline), label: '향 진단'),
    const BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
  ];

  final List<Widget> _widgetOptions = const <Widget>[
    HomeScreenContent(), // [0] 홈 화면 (디자인 변경됨)
    CalendarScreen(),    // [1] 달력 화면
    ScentGeminiScreen(), // [2] 향 진단/검색 화면
    Center(child: Text('설정 화면', style: TextStyle(fontSize: 24))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 홈 화면을 제외한 나머지 화면에서만 AppBar 표시
        // 홈 화면에서는 바디에 직접 제목을 넣어 AppBar 제거 효과를 냅니다.
        toolbarHeight: _selectedIndex == 0 ? 0 : null,
        elevation: 0,
        title: _selectedIndex != 0 ? const Text('취향') : null,
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavBarItems,
        currentIndex: _selectedIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
      ),
    );
  }
}


// ====================================================
// [3] CalendarScreen - 달력 화면 (TableCalendar 기반) (분사 기록 로직 업데이트)
// ====================================================

// 날짜별 분사 기록 및 다이어리 내용을 저장하는 맵
final Map<DateTime, String> _diaryEntries = {};
// 🚨 전역 변수로 분사 기록 맵 정의. 시간 정보는 문자열에 포함됩니다.
final Map<DateTime, List<String>> _usageRecords = {
  DateTime.utc(2025, 12, 2): ['10:00 AM Floral'],
  DateTime.utc(2025, 12, 17): ['9:00 AM Woody'],
};

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  // CalendarScreen의 State 객체에 접근할 수 있는 Key 정의
  static final GlobalKey<_CalendarScreenState> calendarKey = GlobalKey<_CalendarScreenState>();

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  String _currentDiaryText = '작성된 다이어리 내용이 없습니다.';
  String _currentUsageText = '분사 기록 없음';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent(_selectedDay);
    });
  }

  // DateTime에서 시간 정보를 제거하고 순수한 날짜(UTC)만 남기는 유틸리티
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  // 선택된 날짜의 분사 기록 및 다이어리 내용을 로드
  void _loadContent(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    setState(() {
      _currentDiaryText = _diaryEntries[normalizedDate] ?? '작성된 다이어리 내용이 없습니다.';

      // List<String> 형태의 분사 기록을 줄바꿈으로 연결
      final records = _usageRecords[normalizedDate];
      if (records != null && records.isNotEmpty) {
        _currentUsageText = records.join('\n');
      } else {
        _currentUsageText = '분사 기록 없음';
      }
    });
  }

  // 날짜 선택 이벤트 핸들러
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _loadContent(selectedDay);
    }
  }

  // 🚨 다이어리 작성 화면으로 이동 및 결과 수신 (다중 키워드 누적 로직 적용) 🚨
  void _goToDiaryEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step1Screen( // 새로 정의된 Step1Screen 사용
          selectedDate: _selectedDay,
        ),
      ),
    );

    // Step1Screen에서 최종적으로 조합된 다이어리 내용(String)을 받음
    if (result != null && result is String && result.isNotEmpty) {
      final normalizedDate = _normalizeDate(_selectedDay);
      setState(() {
        // 해당 날짜에 다이어리 내용 업데이트
        _diaryEntries[normalizedDate] = result;
        // 화면 하단 다이어리 내용 즉시 업데이트
        _currentDiaryText = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다이어리 작성이 완료되었습니다!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('취향'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 우측 상단 아이콘: 다이어리 작성 시작
          IconButton(
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: _goToDiaryEntry,
            tooltip: '다이어리 작성',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 달력 위젯 (TableCalendar)
            TableCalendar(
              locale: 'ko_KR', // 로케일 초기화 후 정상 작동
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                // 로케일 초기화 후 한글 날짜 포맷팅 정상 작동
                titleTextFormatter: (date, locale) => DateFormat('yyyy년 M월', locale).format(date),
                titleTextStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary, // 테마 색상 사용
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                todayDecoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. 분사 기록 섹션
                  const Text(
                    '기록',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  // 분사 기록을 여러 줄로 표시
                  Text(
                    _currentUsageText,
                    style: const TextStyle(fontSize: 16.0, color: Colors.black54),
                  ),

                  const SizedBox(height: 25),

                  // 3. 다이어리 섹션
                  const Text(
                    'Diary',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),

                  // 다이어리 내용 표시 영역 (읽기 전용)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _currentDiaryText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ====================================================
// [4] HomeScreenContent - 홈 화면 콘텐츠
// ====================================================
class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  // 향 진단 아이템 위젯 (그리드 내부 아이템)
  Widget _buildScentItem({
    required BuildContext context,
    required int percent,
    required String name,
    required Color color,
    required IconData icon,
    required Color darkColor,
  }) {
    // 이미지에 맞게 그라데이션 색상 정의
    final gradient = LinearGradient(
      colors: [color, darkColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(
              scentName: name,
              color: color,
              percent: percent,
              // 그라데이션 색상을 전달하여 상세 화면 디자인에 사용
              darkColor: darkColor,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: darkColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          gradient: gradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 향 이름
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                // 상세 이동 버튼 (작은 동그라미)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.circle_outlined, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),

            // 중앙 아이콘 (아웃라인 스타일)
            Center(
              child: Icon(icon, size: 50, color: Colors.white.withOpacity(0.8)),
            ),

            // 백분율
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AI PICK 영역 위젯
  Widget _buildAIPickArea(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          '취향',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '오늘의 향',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 30),
        // AI PICK 아이콘 (이미지와 유사하게 구성)
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1),
                color: Colors.white,
              ),
            ),
            const Icon(Icons.eco_outlined, size: 40, color: Colors.black54),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('AI PICK', style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 향 항목 데이터 (색상 및 아이콘 추가)
    final List<Map<String, dynamic>> options = [
      {'percent': 70, 'name': 'Floral', 'color': const Color(0xFFF77062), 'darkColor': const Color(0xFFFE5196), 'icon': MdiIcons.flowerOutline},
      {'percent': 60, 'name': 'Citrus', 'color': const Color(0xFFFF9966), 'darkColor': const Color(0xFFFF5E62), 'icon': MdiIcons.fruitCitrus},
      {'percent': 40, 'name': 'Woody', 'color': const Color(0xFF6B8E23), 'darkColor': const Color(0xFF808000), 'icon': MdiIcons.pineTree},
      {'percent': 30, 'name': 'Fresh', 'color': const Color(0xFF4CA1AF), 'darkColor': const Color(0xFFC4E0E5), 'icon': MdiIcons.waterOutline},
    ];

    // AI 추천 다이얼로그 호출 함수
    void showAIRecommendationDialog() {
      _showRecommendationDialog(context); // [A] 섹션의 헬퍼 함수 호출
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. AI PICK 영역
            _buildAIPickArea(context),

            // 2. 그리드 뷰
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // ScrollView 안에 GridView가 있을 때 필요
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.0, // 정사각형 유지
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return _buildScentItem(
                  context: context,
                  percent: option['percent'],
                  name: option['name'],
                  color: option['color'],
                  darkColor: option['darkColor'],
                  icon: option['icon'],
                );
              },
            ),

            const SizedBox(height: 25),

            // 3. AI 진단받기 버튼
            ElevatedButton(
              onPressed: showAIRecommendationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF424242), // 이미지와 유사한 다크 그레이
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '향 진단받기 (AI 추천)',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}


// ====================================================
// [5] DetailScreen - 상세 제어 화면 (Schedule 버튼 로직 수정)
// ====================================================
class DetailScreen extends StatelessWidget {
  final String scentName;
  final Color color;
  final Color darkColor; // 그라데이션을 위해 추가
  final int percent;

  const DetailScreen({
    super.key,
    required this.scentName,
    required this.color,
    required this.darkColor,
    required this.percent,
  });

  // 🚨 분사 기록 추가 로직 🚨
  void _recordUsage(BuildContext context, String scent) {
    // 1. 현재 날짜와 시간 포맷팅
    final now = DateTime.now();
    final normalizedDate = DateTime.utc(now.year, now.month, now.day);
    final timeFormat = DateFormat('hh:mm a').format(now);
    final record = '$timeFormat $scent (즉시 분사)';

    // 2. 전역 맵에 기록 업데이트
    _usageRecords.putIfAbsent(normalizedDate, () => []).add(record);

    // 3. 사용자 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$scentName 향을 분사하고 기록했습니다.')),
    );

    // 4. CalendarScreen의 상태를 업데이트하여 즉시 반영
    final calendarState = CalendarScreen.calendarKey.currentState;
    if (calendarState != null) {
      calendarState._loadContent(normalizedDate);
    }
  }

  // 🚨 Schedule 버튼 클릭 시 새 화면으로 이동 🚨
  void _goToScheduleScreen(BuildContext context, String scent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleScreen(scentName: scent),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 홈 화면과 유사한 그라데이션
    final gradient = LinearGradient(
      colors: [color, darkColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      // AppBar를 사용하지 않고 Body 상단에 제목 배치
      appBar: AppBar(
        // 뒤로가기 버튼 외에는 빈 AppBar
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: null,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. 제목 및 부제목 (AppBar 대체)
              Text(
                '$scentName',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 5),
              Text(
                '상세 제어',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // 2. 메인 제어 카드 (홈 화면 아이템 디자인 반영)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: darkColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  gradient: gradient,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '현재 남은 용량',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // 3. 제어 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Spray 버튼 (강조)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _recordUsage(context, scentName),
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        label: const Text('Spray', style: TextStyle(fontSize: 18, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkColor,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 10,
                        ),
                      ),
                    ),
                  ),

                  // 🚨 Schedule 버튼 (보조) - 로직 적용 🚨
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: () => _goToScheduleScreen(context, scentName), // 핵심 로직 적용
                        icon: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                        label: Text('Schedule', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 기타 정보
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  '최근 사용: 2025년 12월 2일 (Floral)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ====================================================
// 🚨 [6] ScheduleScreen: 알람/타이머 네비게이션을 포함한 스케줄 설정 화면 🚨
// ====================================================
class ScheduleScreen extends StatefulWidget {
  final String scentName;
  const ScheduleScreen({super.key, required this.scentName});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedIndex = 0; // 0: 알람, 1: 타이머

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // scentName을 각 탭에 전달
    _widgetOptions = <Widget>[
      AlarmScheduleTab(scentName: widget.scentName),
      TimerScheduleTab(scentName: widget.scentName),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scentName} 예약 설정', style: const TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      // 🚨 BottomNavigationBar를 사용하여 알람/타이머 전환 🚨
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: '알람',
          ),
          BottomNavigationBarItem(
            icon: Icon(MdiIcons.timerSand),
            label: '타이머',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ====================================================
// 🚨 [7] AlarmScheduleTab: 특정 시간(알람) 설정 탭 🚨
// ====================================================
class AlarmScheduleTab extends StatefulWidget {
  final String scentName;
  const AlarmScheduleTab({super.key, required this.scentName});

  @override
  State<AlarmScheduleTab> createState() => _AlarmScheduleTabState();
}

class _AlarmScheduleTabState extends State<AlarmScheduleTab> {
  List<TimeOfDay> _scheduledTimes = [];

  Future<void> _addTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          // 12시간제로 강제 설정하여 AM/PM 표시
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        _scheduledTimes.add(newTime);
        // 시간순으로 정렬
        _scheduledTimes.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.scentName} 분사 알람 ${_formatTime(newTime)}에 추가됨')),
        );
      }
    }
  }

  // TimeOfDay를 AM/PM 형식의 문자열로 포맷팅
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);  // 예: 10:30 AM
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '${widget.scentName} 예약 시간 설정',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: _scheduledTimes.isEmpty
              ? const Center(
            child: Text(
              '예약된 시간이 없습니다.\n시간을 추가하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: _scheduledTimes.length,
            itemBuilder: (context, index) {
              final time = _scheduledTimes[index];
              return Dismissible(
                key: ValueKey(time),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  setState(() {
                    _scheduledTimes.removeAt(index);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_formatTime(time)} 예약 삭제됨')),
                    );
                  }
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  leading: Icon(Icons.alarm_on, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    _formatTime(time),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add),
            label: const Text('분사 시간 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================
// 🚨 [8] TimerScheduleTab: 주기적 간격(타이머) 설정 탭 🚨
// ====================================================
class TimerScheduleTab extends StatefulWidget {
  final String scentName;
  const TimerScheduleTab({super.key, required this.scentName});

  @override
  State<TimerScheduleTab> createState() => _TimerScheduleTabState();
}

class _TimerScheduleTabState extends State<TimerScheduleTab> {
  int _selectedHours = 0;
  int _selectedMinutes = 30; // 기본값 30분

  final List<int> _hourOptions = List<int>.generate(24, (i) => i);
  final List<int> _minuteOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]; // 5분 단위

  void _saveRecurrence() {
    final totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('0분 주기는 설정할 수 없습니다.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.scentName} 분사 주기가 ${_selectedHours}시간 ${_selectedMinutes}분으로 설정되었습니다.')),
      );
    }
    // 🚨 실제 기기 연동 로직은 여기에 구현해야 합니다.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.scentName} 주기적 분사 간격 설정',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 시간 드롭다운
              Column(
                children: [
                  Text('시간', style: Theme.of(context).textTheme.titleMedium),
                  DropdownButton<int>(
                    value: _selectedHours,
                    items: _hourOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value 시간'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedHours = newValue!;
                      });
                    },
                  ),
                ],
              ),

              // 분 드롭다운
              Column(
                children: [
                  Text('분', style: Theme.of(context).textTheme.titleMedium),
                  DropdownButton<int>(
                    value: _selectedMinutes,
                    items: _minuteOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value 분'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedMinutes = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '현재 분사 주기: $_selectedHours시간 $_selectedMinutes분',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 40),

          ElevatedButton.icon(
            onPressed: _saveRecurrence,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('주기 설정 저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}