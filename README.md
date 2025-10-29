# 회의록 받아쓰기 앱 (Whisper.cpp 버전)

**Whisper.cpp** 기반 온디바이스 AI 음성인식 회의록 받아쓰기 앱입니다.

> ⚠️ **중요**: 이 버전은 OpenAI Whisper 모델을 사용합니다.
> 자세한 사용법은 [README_WHISPER.md](README_WHISPER.md)를 참고하세요.

## 주요 기능

### 음성 인식
- **온디바이스 음성인식**: 네트워크 연결 없이도 실시간으로 음성을 텍스트로 변환
- **한국어 지원**: 기본적으로 한국어 음성 인식을 지원
- **실시간 받아쓰기**: 말하는 즉시 텍스트로 변환

### 화자 구분
- **다중 화자 지원**: 최대 3명의 화자를 기본으로 설정 (추가 가능)
- **수동 화자 전환**: 화자 전환 버튼으로 현재 발화자를 쉽게 변경
- **자동 화자 전환 감지**: 일정 시간 침묵 후 자동으로 화자가 전환될 수 있음
- **화자별 색상 구분**: 각 화자에게 고유한 색상을 부여하여 시각적으로 구분

### 대본 정리
- **다양한 포맷 지원**:
  - 기본 텍스트 형식
  - 타임스탬프 포함 형식
  - 간단한 형식
  - Markdown 형식
  - JSON 형식
- **회의 통계**: 참석자별 발화 수, 회의 소요 시간 등 통계 정보 제공
- **세그먼트 그룹화**: 같은 화자의 연속된 발화를 하나로 합침

### 구글 드라이브 연동
- **클라우드 백업**: 회의록을 구글 드라이브에 텍스트 파일로 저장
- **자동 동기화**: 기존 파일을 자동으로 업데이트
- **구글 계정 연동**: 안전한 OAuth 2.0 인증

### 기타 기능
- **로컬 저장소**: SQLite를 사용한 안정적인 로컬 데이터 저장
- **공유 기능**: 회의록을 다른 앱으로 공유
- **클립보드 복사**: 회의록을 클립보드에 복사
- **제목 편집**: 회의록 제목을 자유롭게 수정
- **다크 모드**: 시스템 설정에 따라 자동으로 다크 모드 전환

## 기술 스택

### Flutter & Dart
- **Flutter**: 크로스 플랫폼 UI 프레임워크
- **Material Design 3**: 최신 디자인 시스템 적용

### 온디바이스 AI
- **Whisper.cpp**: OpenAI Whisper 모델의 C++ 포팅 버전
- **완전한 오프라인 처리**: 네트워크 없이 100% 로컬에서 실행
- **높은 정확도**: 기존 음성 인식 대비 월등한 성능
- **99개 언어 지원**: 한국어 포함 다국어 지원

### 데이터 관리
- **sqflite**: SQLite 데이터베이스
- **path_provider**: 로컬 파일 시스템 접근

### 구글 API
- **google_sign_in**: 구글 계정 인증
- **googleapis**: 구글 드라이브 API

### 기타 패키지
- **provider**: 상태 관리
- **intl**: 날짜/시간 포맷팅
- **uuid**: 고유 ID 생성
- **share_plus**: 파일 공유
- **permission_handler**: 권한 관리

## 시작하기

### 사전 요구사항

1. **Flutter SDK**: Flutter 3.0 이상
2. **개발 환경**:
   - Android Studio 또는 VS Code
   - Xcode (iOS 개발 시)

### 설치

1. 저장소 클론:
```bash
git clone <repository-url>
cd talk2mybar
```

2. 의존성 설치:
```bash
flutter pub get
```

3. 구글 드라이브 API 설정 (선택사항):
   - [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트 생성
   - Drive API 활성화
   - OAuth 2.0 클라이언트 ID 생성
   - Android/iOS 앱에 클라이언트 ID 추가

### 실행

```bash
# Android
flutter run

# iOS
flutter run
```

### 빌드

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS
flutter build ios
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/                   # 데이터 모델
│   ├── meeting.dart         # 회의 모델
│   ├── speaker.dart         # 화자 모델
│   └── transcript_segment.dart  # 대화 세그먼트 모델
├── screens/                  # 화면
│   ├── home_screen.dart     # 홈 화면 (회의록 목록)
│   ├── recording_screen.dart    # 녹음 화면
│   └── meeting_detail_screen.dart  # 회의록 상세
├── services/                 # 비즈니스 로직
│   ├── database_service.dart    # 데이터베이스 서비스
│   ├── speech_service.dart      # 음성 인식 서비스
│   ├── speaker_detection_service.dart  # 화자 구분 서비스
│   └── google_drive_service.dart   # 구글 드라이브 서비스
└── utils/                    # 유틸리티
    └── transcript_formatter.dart   # 대본 포맷팅
```

## 사용 방법

### 1. 새 회의록 시작

1. 홈 화면에서 "새 회의록" 버튼을 탭합니다.
2. 회의록 제목을 입력합니다.
3. 필요시 화자 이름을 수정합니다.

### 2. 녹음하기

1. 마이크 버튼을 눌러 녹음을 시작합니다.
2. 말을 하면 실시간으로 텍스트로 변환됩니다.
3. 화자가 바뀔 때 화자 전환 버튼을 누릅니다.
4. 중지 버튼을 눌러 녹음을 일시정지합니다.

### 3. 저장 및 공유

1. 저장 버튼을 눌러 회의록을 저장합니다.
2. 회의록 목록에서 저장된 회의록을 확인합니다.
3. 회의록을 탭하여 상세 내용을 봅니다.
4. 공유 또는 구글 드라이브에 업로드합니다.

## 권한

### Android
- `RECORD_AUDIO`: 마이크 접근 (음성 녹음)
- `INTERNET`: 구글 드라이브 연동

### iOS
- `NSMicrophoneUsageDescription`: 마이크 접근
- `NSSpeechRecognitionUsageDescription`: 음성 인식

## 제약사항

### 화자 구분의 한계
- 현재 온디바이스 화자 구분은 완전히 자동화되지 않았습니다.
- 사용자가 수동으로 화자를 전환해야 가장 정확합니다.
- 침묵 구간 기반 자동 전환은 참고용으로만 사용하세요.

### 음성 인식 정확도
- 온디바이스 음성 인식은 네트워크 기반보다 정확도가 낮을 수 있습니다.
- 조용한 환경에서 사용하는 것이 좋습니다.
- 명확한 발음과 적절한 속도로 말하세요.

## 향후 개선 사항

- [ ] 더 정확한 화자 구분 (음성 임베딩 기반)
- [ ] 오프라인 음성 인식 모델 개선
- [ ] 회의록 검색 기능
- [ ] 회의록 카테고리/태그 기능
- [ ] 여러 언어 지원
- [ ] 회의록 편집 기능
- [ ] 음성 파일 저장 및 재생
- [ ] AI 기반 회의록 요약

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 기여

버그 리포트, 기능 제안, Pull Request를 환영합니다!

## 문의

문제가 있거나 질문이 있으시면 이슈를 등록해주세요.
