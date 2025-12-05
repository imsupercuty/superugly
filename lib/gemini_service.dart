// lib/gemini_service.dart

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'scent_models.dart';

// ⚠️ 실제 사용 시, 이 부분을 환경 변수 등으로 안전하게 관리해야 합니다.
const String apiKey = 'AIzaSyAqy8tirp1ucbC89dOL4aF_g9nduCmI3BQ'; // ⬅️ 여기에 실제 API 키를 넣어주세요!

// ⬇️ GeminiService 클래스를 정의합니다.
class GeminiService {

  final _model = gemini.GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

  // 1. 화면에 필요한 향 정보를 Gemini API를 통해 가져오는 메서드
  Future<List<ScentInfo>> fetchScentInfo() async {
    final systemInstruction =
        '당신은 향기 전문가입니다. 대표적인 향수 계열과 노트(Note)를 포함하여 **총 15가지**의 다양한 향을 선정하고, 각각의 **특징과 심리적 효능을 2~3줄 이내**로 간결하게 한국어로 설명해주세요. 답변은 반드시 다음 JSON 배열 형식으로만 출력해야 합니다: [{"title": "향이름(계열)", "description": "특징 및 효능 설명"}, ...]';

    try {
      final response = await _model.generateContent([
        gemini.Content('user', [gemini.TextPart('시스템 지침: ${systemInstruction}')]),
        gemini.Content('user', [gemini.TextPart('15가지 다양한 향 정보를 JSON으로 출력해줘.')]),
      ]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Gemini API가 유효한 응답을 반환하지 않았습니다.');
      }

      // ⬇️ JSON 파싱 및 정리 코드 강화
      String jsonString = response.text!
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .replaceAll('\n', '')
          .replaceAll('\\', '')
          .trim();

      if (!jsonString.startsWith('[')) {
        jsonString = '[$jsonString]';
      }
      if (jsonString.endsWith(',]')) {
        jsonString = jsonString.substring(0, jsonString.length - 2) + ']';
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);

      // ⬇️ 아이콘 맵 정의 (새로운 키워드 추가)
      final iconMap = {
        '꽃': '🌸', '플로럴': '🌸', '장미': '🌹', '자스민': '🌼',
        '시트러스': '🍊', '레몬': '🍋', '오렌지': '🍊', '자몽': '🍊',
        '우디': '🌳', '나무': '🌲', '샌달우드': '🪵', '시더': '🌲',
        '프레시': '💧', '청량': '💧', '아쿠아': '🌊', '바다': '🌊',
        '그린': '🌿', '풀잎': '🍃', '허브': '🌱', '아로마틱': '🌿',
        '스파이스': '🌶️', '향신료': '🌶️',
        '구르망': '🍮', '달콤': '🍭', '바닐라': '🍦',
        '오리엔탈': '🕌', '앰버': '🍯',
        '머스크': '🐘', '사향': '🐘',
        '가죽': '🧥', '레더': '🧥',
        '푸제르': '☘️', '이끼': '🍂',
        '시프레': '🍂', '과일': '🍎', '프루티': '🍎',
        '파우더리': '🌫️', '비누': '✨', '알데히딕': '✨',
        '흙': '🥔', '스모키': '💨', '애니말릭': '🐾',
        '라벤더': '💜', '베리': '🍓', '민트': '🍃',
        '따뜻': '🔥', '시원': '❄️', '새콤': '🍋',
        'Floral': '🌸', 'Citrus': '🍊', 'Woody': '🌳', 'Fresh': '💧', 'Spice': '🌶️',
        'Gourmand': '🍮', 'Aquatic': '🌊', 'Oriental': '🕌', 'Musk': '🐘', 'Leather': '🧥',
      };

      return jsonList.map((json) {
        String title = json['title'] as String;
        String description = json['description'] as String;
        String combinedText = '$title $description'.toLowerCase();

        String matchedIcon = '❓';
        for (var entry in iconMap.entries) {
          if (combinedText.contains(entry.key.toLowerCase())) {
            matchedIcon = entry.value;
            break;
          }
        }
        return ScentInfo.fromJson(json, matchedIcon);
      }).toList();

    } catch (e) {
      print('Gemini API 호출 오류 (더미 데이터 사용): $e');
      return [];
    }
  }

  // 2. 맞춤형 추천을 받는 메서드 (단계별 진단 및 검색 상세 정보에 사용됨)
  Future<String> getGeminiRecommendation(String prompt) async {
    try {
      final response = await _model.generateContent([
        gemini.Content.text(prompt)
      ]);
      return response.text ?? '추천 정보를 가져올 수 없습니다.';
    } catch (e) {
      return '추천을 받는 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}

// ⬇️ main.dart와 scent_gemini_screen.dart에서 바로 함수를 호출할 수 있도록 래핑
final GeminiService _singletonService = GeminiService();

Future<String> getGeminiRecommendation(String prompt) {
  return _singletonService.getGeminiRecommendation(prompt);
}

Future<List<ScentInfo>> fetchScentInfo() {
  return _singletonService.fetchScentInfo();
}