# HMC-SCM 요구사항 명세서 (Requirement Spec)

- **문서 ID:** HMC_SCM_Requirement_Spec_v1.0
- **작성일:** 2026-06-02 | **버전:** v1.0 (초안)
- **단계:** 2. 분석 (Analysis)

---

## 1. 현황 분석 (Internal Assessment)

- **기존 시스템:** JSP + MySQL 단일 웹앱, DB 접근은 `util.DBUtil` 단일 유틸로 통일(17개 JSP 사용)
- **프로세스:** 조달 업무 일부가 시스템화되어 있으나 로직이 JSP에 집중
- **문제점:**
  - 자격증명 하드코딩(`root`/`1234`)
  - View와 비즈니스 로직 혼재로 변경 영향 추적 어려움
  - 파일 경로 = URL 구조라 폴더 재배치 시 링크 영향 큼

## 2. 환경 분석 (External Analysis)

- **유사 사례:** 일반 e-Procurement(전자조달) 시스템(입찰·납품·평가 공통 패턴)
- **기술 환경:** Tomcat 9 / MySQL 8 / Bootstrap 5 / Naver Maps
- **외부 데이터:** 지도/좌표(Naver) — 납품 경로 최적화에 활용

## 3. 기능 요구사항 (Functional Requirements)

| ID | 기능 | 설명 | 화면(JSP) | 권한 |
| :--- | :--- | :--- | :--- | :--- |
| FR-AUTH-01 | 로그인 | 세션 기반 인증 | login | 전체 |
| FR-AUTH-02 | 회원가입 | 협력사/담당 가입 | signup | 비회원 |
| FR-AUTH-03 | 가입 승인 | 신규 회원 승인 처리 | adminApproval | admin |
| FR-AUTH-04 | 프로필 | 내 정보/회사정보 관리 | profile | 전체 |
| FR-DASH-01 | 대시보드 | 주요 지표 요약 | dashboard | admin, scm |
| FR-NOTI-01 | 공지 등록/목록 | 공지 작성·조회 | notice | admin/scm 작성 |
| FR-NOTI-02 | 공지 열람 | 열람 기록(notice_reads) | noticeRead | 전체 |
| FR-BID-01 | 입찰 등록 | 입찰 공고 생성(+이미지) | bidReg | scm |
| FR-BID-02 | 입찰 목록 | 공고 조회/검색 | bidList | 전체 |
| FR-BID-03 | 입찰 품목 등록 | 입찰 대상 품목 등록 | bidItemReg | scm |
| FR-BID-04 | 응찰 | 협력사 응찰(bid_applications) | bidList/bidReg | vendor |
| FR-ITEM-01 | 품목 등록 | 품목 마스터 등록 | itemReg | scm |
| FR-ITEM-02 | 품목 상세 등록 | 상세 스펙 등록 | itemDetailReg | scm |
| FR-PART-01 | 부품 검색 | 부품 검색 | partSearch | 전체 |
| FR-PART-02 | 부품 DB 조회 | parts_db 열람 | parts_db_view | admin, scm |
| FR-DLV-01 | 납품 등록 | 납품 처리 | delivery | vendor |
| FR-DLV-02 | 납품 현황 | 납품 목록/상태 | deliveryList | 전체 |
| FR-EVAL-01 | 협력사 평가 | 평가 입력(evaluations) | evaluation | scm |
| FR-EVAL-02 | 평가 목록 | 평가 결과 조회 | evaluationList | admin, scm |
| FR-VEN-01 | 협력사 상세 | 협력사 정보 조회 | vendorDetail | admin, scm |
| FR-VEN-02 | 협력사 리포트 | 성과 리포트 | vendorReport2 | admin, scm |
| FR-STL-01 | 정산 | 납품 기준 정산 | settlement | scm |
| FR-OPT-01 | 생산 최적화 | 유전알고리즘 기반 | supplymgt | scm |
| FR-OPT-02 | 납품 최적경로 | TSP + 지도 시각화 | bestroute2 | scm |

## 4. 비기능 요구사항 (Non-Functional Requirements)

| 분류 | 요구사항 |
| :--- | :--- |
| 보안 | 세션 인증, 역할 기반 접근제어, SQL은 PreparedStatement, 자격증명 외부화 |
| 성능 | 목록 페이지 페이징, 인덱스 적용 *(확인 필요)* |
| 호환성 | 최신 브라우저(Chrome/Edge), UTF-8 |
| 가용성 | DB 연결 실패 시 예외 처리, 자원 해제(DBUtil.close) |
| 유지보수성 | 공통 레이아웃(navbar/sidebar/footer) 재사용 |

## 5. 요구사항 추적 매트릭스 (RTM)

| 요구 ID | 설계 항목 | 구현(JSP/테이블) | 테스트 ID |
| :--- | :--- | :--- | :--- |
| FR-BID-01 | 입찰 프로세스 | bidReg / bids, bid_images | TC-BID-01 |
| FR-DLV-01 | 납품 프로세스 | delivery / deliveries | TC-DLV-01 |
| FR-EVAL-01 | 평가 프로세스 | evaluation / evaluations | TC-EVAL-01 |
| ... | (전 기능 매핑 — 확인 필요) | | |
