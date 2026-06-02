# HMC-SCM 분석·설계 문서

> 본 문서는 `개발방법론__AIsw.md` 의 산출물 체계(분석/설계 단계)를 따른다.
> 최초 작성은 현재 코드 베이스(JSP 인벤토리 + DB 유틸)를 역분석하여 정리한 것이며,
> 빈 칸/`(확인 필요)` 표기는 담당자가 채워야 한다.

- **문서 버전:** v0.1 (초안)
- **대상 시스템:** HMC-SCM (공급망관리 / 조달·구매 시스템)

---

## 1. 개요 (Introduction)

| 항목 | 내용 |
| :--- | :--- |
| 목적 | 협력사 입찰·납품·평가·정산을 단일 웹 시스템으로 관리 |
| 범위 | 회원/인증, 입찰, 품목·부품, 납품, 평가, 협력사, 정산, 공급망 최적화 |
| 사용자 | 발주사 관리자(admin), 협력사(vendor) |

## 2. 현황 분석 (Analysis)

### 2.1 기존 시스템 구조
- JSP + MySQL(`HMC_SCM`) 기반의 서버 렌더링 웹앱
- DB 접근은 `util.DBUtil` 단일 유틸로 통일 (17개 JSP에서 사용)
- 프론트엔드는 Bootstrap 5 / Font Awesome, 지도는 Naver Maps API 사용

### 2.2 문제점 / 개선점
- 자격증명(`root`/`1234`)이 소스에 하드코딩됨 → 외부화 필요
- 비즈니스 로직이 JSP 스크립틀릿에 혼재 → 추후 서블릿/서비스 계층 분리 권장
- 파일 경로 기반 라우팅 → 폴더 재구성 시 링크 영향 큼

## 3. 기능 요구사항 (Functional Requirements)

| ID | 기능 | 관련 화면(JSP) |
| :--- | :--- | :--- |
| F-AUTH | 로그인/회원가입/관리자 승인/프로필 | `login`, `signup`, `adminApproval`, `profile` |
| F-DASH | 대시보드 | `dashboard` |
| F-NOTI | 공지 등록/조회 | `notice`, `noticeRead` |
| F-BID | 입찰 등록/목록/품목등록 | `bidReg`, `bidList`, `bidItemReg` |
| F-ITEM | 품목·부품 등록/검색/조회 | `itemReg`, `itemDetailReg`, `partSearch`, `parts_db_view` |
| F-DLV | 납품 등록/목록 | `delivery`, `deliveryList` |
| F-EVAL | 협력사 평가/목록 | `evaluation`, `evaluationList` |
| F-VENDOR | 협력사 상세/리포트 | `vendorDetail`, `vendorReport2` |
| F-STL | 정산 | `settlement` |
| F-OPT | 생산 최적화(유전알고리즘) | `supplymgt` |
| F-ROUTE | 납품 최적경로(TSP) | `bestroute2` |

## 4. 시스템 아키텍처 (Architecture Design)

```
[Browser]
   │ HTTP
[Tomcat 9.0]
   ├── JSP (View + Controller 혼재)
   │      └── util.DBUtil  ── JDBC ──► [MySQL: HMC_SCM]
   └── 외부 연동: Naver Maps API (경로 시각화)
```

- **3계층 목표(권장):** View(JSP) / Service(Java) / DAO(DBUtil 확장) 로 분리
- 현재는 View-DB 직접 호출 구조

## 5. 데이터 설계 (Data Design)

- **DBMS:** MySQL, 스키마 `HMC_SCM`
- **접속:** `jdbc:mysql://localhost:3306/HMC_SCM` (UTF-8, Asia/Seoul)
- **주요 엔터티 (코드 기준 추정 / 확인 필요):**
  - 회원/협력사, 공지, 입찰, 입찰품목, 품목/부품, 납품, 평가, 정산
- **상세 테이블 스키마:** (확인 필요 — `CREATE TABLE` 정의 추가)

## 6. 핵심 알고리즘 설계

### 6.1 생산 최적화 — 유전알고리즘 (`supplymgt.jsp`)
- 목적: 생산/공급 계획 최적해 탐색
- 구성요소: 적합도(fitness), 선택, 교차(crossover), 변이(mutation), 세대 반복
- (상세 파라미터: 개체 수/세대 수/교차·변이율 — 확인 필요)

### 6.2 납품 최적경로 — TSP (`bestroute2.jsp`)
- 목적: 다중 납품지 순회 최단 경로 산출
- 입력: 납품지 좌표, 거리 행렬
- 시각화: Naver Maps API
- (거리 계산 방식/휴리스틱 — 확인 필요)

## 7. 형상·배포 (Deployment)

- **버전관리:** Git / GitHub
- **빌드/배포:** Tomcat `webapps` 컨텍스트 배포
- **주의:** 본 GitHub 표준 구조는 *소스 정리용*이며, 실제 서비스 경로와 다름 (CLAUDE.md 4항 참고)

## 8. 보안 / 운영 체크리스트

- [ ] DB 자격증명 외부화 (환경변수/설정파일)
- [ ] 모든 SQL `PreparedStatement` 적용 확인
- [ ] 세션/권한(admin/vendor) 검증 일관성 확인
- [ ] 운영 DB 계정 분리 및 비밀번호 변경
