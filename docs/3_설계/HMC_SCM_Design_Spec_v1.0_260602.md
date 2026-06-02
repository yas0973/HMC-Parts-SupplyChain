# HMC-SCM 설계서 (Design Specification)

- **문서 ID:** HMC_SCM_Design_Spec_v1.0
- **작성일:** 2026-06-02 | **버전:** v1.0 (초안)
- **단계:** 3. 설계 (Design)

---

## 1. 시스템 아키텍처 (Architecture Design)

```
            [ Browser (admin / scm / vendor) ]
                        │ HTTP
        ┌───────────────────────────────────┐
        │           Tomcat 9.0               │
        │   JSP (View + Controller 혼재)     │
        │        │                           │
        │   util.DBUtil (JDBC)               │
        └───────────────────────────────────┘
                 │                  │
        [ MySQL: HMC_SCM ]   [ Naver Maps API ]
```

- **현재 구조:** 2계층(JSP ↔ DB 직접 호출)
- **목표 구조:** 3계층 — View(JSP) / Service(Java) / DAO(DBUtil 확장)
- **공통 컴포넌트:** `navbar.jsp`, `sidebar.jsp`, `footer.jsp` (레이아웃 include)

## 2. 기능 분해도 (Function Map)

```
HMC-SCM
├── 인증/회원       : login, signup, adminApproval, profile
├── 대시보드        : dashboard
├── 공지            : notice, noticeRead
├── 입찰            : bidReg, bidList, bidItemReg
├── 품목/부품       : itemReg, itemDetailReg, partSearch, parts_db_view
├── 납품            : delivery, deliveryList
├── 평가            : evaluation, evaluationList
├── 협력사          : vendorDetail, vendorReport2
├── 정산            : settlement
└── 최적화          : supplymgt(GA), bestroute2(TSP)
```

## 3. 데이터 설계 (Data Design)

- **DBMS:** MySQL / 스키마 `HMC_SCM` / 문자셋 UTF-8 / TZ Asia/Seoul

### 3.1 주요 테이블 (코드 역분석 기준)

| 테이블 | 용도 | 비고 |
| :--- | :--- | :--- |
| `users` | 사용자(역할 admin/scm/vendor) | 가장 많이 참조 |
| `vendors` | 협력사 정보 | users와 조인 |
| `bids` | 입찰 공고 | |
| `bid_applications` | 응찰 내역 | bids-vendors 연결 |
| `bid_images` | 입찰 첨부 이미지 | |
| `deliveries` | 납품 내역 | |
| `evaluations` | 협력사 평가 | grade/status 포함 |
| `notices` | 공지 | |
| `notice_reads` | 공지 열람 기록 | |
| `parts_db` | 부품 마스터 | |
| `parts` | 부품(입찰/품목 연계) | |

> ⚠️ 컬럼 상세·PK/FK·인덱스 정의는 실제 `CREATE TABLE` 추출 필요 **(확인 필요)**.

### 3.2 관계 개요 (ERD 텍스트)
```
users 1 ── N vendors? (또는 users.role=vendor)
bids 1 ── N bid_applications ── N vendors
bids 1 ── N bid_images
vendors 1 ── N deliveries
vendors 1 ── N evaluations
notices 1 ── N notice_reads
```
*(정확한 카디널리티 확인 필요)*

## 4. UI/UX 설계 (Interface Layout)

- 공통 레이아웃: 상단 `navbar` + 좌측 `sidebar` + 하단 `footer`
- 프레임워크: Bootstrap 5 그리드/컴포넌트, Font Awesome 아이콘
- 역할별 메뉴 노출 분기(session `role` 기준)
- 목록형 화면(bidList, deliveryList, evaluationList) + 등록/상세 폼

## 5. 프로세스 설계 (Process Logic)

### 5.1 입찰 프로세스
```
scm: bidReg(공고+bidItemReg) → bidList 노출
vendor: bidList에서 응찰 → bid_applications insert
scm: 응찰 검토 → 낙찰 결정(status update)
```

### 5.2 납품·평가·정산
```
vendor: delivery 등록 → deliveries insert
scm: deliveryList 확인 → evaluation 입력(evaluations)
scm: settlement 정산 처리
```

### 5.3 최적화 알고리즘
- **supplymgt (유전알고리즘):** 개체(생산계획) → 적합도 평가 → 선택/교차/변이 → 세대 반복 → 최적 계획 산출
- **bestroute2 (TSP):** 납품지 좌표 입력 → 거리행렬 → 최단 순회경로 탐색 → Naver Maps 시각화

## 6. 인터페이스 정의 (Integration Spec)

| 연동 | 방식 | 비고 |
| :--- | :--- | :--- |
| DB | JDBC (`util.DBUtil.getConnection`) | MySQL |
| Naver Maps | JS SDK (`ncpKeyId`) | 클라이언트 로딩 |
| 첨부 이미지 | Base64 인코딩 저장/표시 | bid_images |

## 7. 아키텍처 결정 기록 (ADR)

| ID | 결정 | 배경 | 대안 |
| :--- | :--- | :--- | :--- |
| ADR-001 | DB 접근을 `util.DBUtil` 단일화 | 연결/해제 일관성 | 페이지별 직접 연결(기각) |
| ADR-002 | JSP 서버 렌더링 채택 | 학습/구축 속도 | SPA+REST(향후 고려) |
| ADR-003 | 지도 연동은 Naver Maps | 국내 좌표 정확도 | Google Maps |
| ADR-004 | 이미지 Base64 저장 | 파일서버 불필요 | 파일시스템/스토리지(용량 시 재검토) |
