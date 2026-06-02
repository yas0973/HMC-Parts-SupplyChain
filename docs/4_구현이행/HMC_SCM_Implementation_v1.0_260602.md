# HMC-SCM 구현·이행 정의서 (Implementation & Deployment)

- **문서 ID:** HMC_SCM_Implementation_v1.0
- **작성일:** 2026-06-02 | **버전:** v1.0 (초안)
- **단계:** 4. 구현 및 이행 (Implementation)

---

## 1. 구현 계획 (Implementation Plan)

| 모듈 | 우선순위 | 의존성 | 상태 |
| :--- | :--- | :--- | :--- |
| 인증/회원 | 1 | - | 구현됨 |
| 공통 레이아웃 | 1 | - | 구현됨 |
| 입찰 | 2 | 인증, 품목 | 구현됨 |
| 품목/부품 | 2 | 인증 | 구현됨 |
| 납품 | 3 | 입찰 | 구현됨 |
| 평가/정산 | 3 | 납품 | 구현됨 |
| 최적화(GA/TSP) | 4 | 데이터 누적 | 구현됨 |

## 2. 코딩 규약 (Coding Convention)

- DB 사용 JSP 표준 import: `<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>`
- 쿼리는 `PreparedStatement` 사용 (SQL Injection 방지)
- 자원 해제: `DBUtil.close(conn, ps, rs)` 필수
- 인코딩: 요청/응답 UTF-8 통일
- 권한 체크: 페이지 진입 시 `session.getAttribute("role")` 검증

## 3. 형상·배포 관리 (Deployment Spec)

### 3.1 버전 관리
- Git / GitHub: `https://github.com/yas0973/HMC-Parts-SupplyChain`
- 브랜치 전략: `main`(배포), 기능 단위 브랜치 권장 *(확인 필요)*

### 3.2 빌드/배포
- 런타임: Tomcat 9.0 `webapps` 컨텍스트 배포
- DB 드라이버: `com.mysql.cj.jdbc.Driver` (MySQL Connector/J 필요)
- ⚠️ **현재 GitHub 구조는 소스 정리용**이며 실제 서비스 경로(`webapps/ROOT/...`)와 다름.
  재배포 시 JSP 경로/링크와 `DBUtil` 패키지 위치를 컨텍스트에 맞게 정렬해야 함.

### 3.3 배포 전 체크리스트
- [ ] DB 자격증명 외부화(환경변수/`db.properties`)
- [ ] MySQL Connector/J `WEB-INF/lib` 배치
- [ ] `HMC_SCM` 스키마/테이블 생성 스크립트 적용
- [ ] Naver Maps 키 설정

## 4. 테스트 정의 (Test Specification)

| TC ID | 시나리오(BDD) | 기대결과 |
| :--- | :--- | :--- |
| TC-AUTH-01 | 미승인 회원 로그인 시도 | 로그인 거부/대기 안내 |
| TC-AUTH-02 | admin이 회원 승인 | 상태 '승인'으로 변경 |
| TC-BID-01 | scm이 입찰 등록 | bids/bid_images 저장, 목록 노출 |
| TC-BID-02 | vendor 응찰 | bid_applications 저장 |
| TC-DLV-01 | vendor 납품 등록 | deliveries 저장, 현황 반영 |
| TC-EVAL-01 | scm 평가 입력 | evaluations 저장, grade 반영 |
| TC-OPT-01 | 생산 최적화 실행 | 유전알고리즘 결과 산출 |
| TC-OPT-02 | 최적경로 조회 | TSP 경로 + 지도 표시 |
| TC-SEC-01 | 권한 없는 페이지 접근 | 접근 차단/리다이렉트 |

> 단위/통합/인터페이스 테스트 결과는 실행 후 기록 **(확인 필요)**.

## 5. 운영 매뉴얼 (Operations Manual)

- **기동:** Tomcat 시작 → `http://<host>:8080/<context>/login.jsp`
- **DB:** MySQL 기동, `HMC_SCM` 접속 확인
- **모니터링:** Tomcat 로그(`logs/catalina.out`), DB 슬로우쿼리
- **장애 1차 점검:** ① DB 연결(DBUtil) ② 드라이버 로딩 ③ 세션/권한 ④ 외부 API 키
