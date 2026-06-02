# HMC-SCM 개발 가이드 (CLAUDE.md)

> AI 에이전트(Claude)와 개발자가 함께 보는 작업 기준 문서입니다.
> 코드를 제안·수정하기 전에 이 문서를 먼저 확인하세요.

---

## 1. 프로젝트 개요

- **이름:** HMC-SCM (Supply Chain Management / 공급망관리 시스템)
- **성격:** 입찰·품목·납품·평가·정산을 다루는 조달/구매 웹 애플리케이션
- **특징 기능:** 유전알고리즘 기반 생산 최적화, TSP 기반 납품 최적경로 탐색

## 2. 기술 스택

| 구분 | 사용 기술 |
| :--- | :--- |
| 언어/런타임 | Java (JSP, 서블릿 컨테이너 구동) |
| 서버 | Apache Tomcat 9.0 |
| DB | MySQL — 스키마 `HMC_SCM` |
| DB 드라이버 | `com.mysql.cj.jdbc.Driver` |
| 프론트 | Bootstrap 5.3.3, Font Awesome 5.15.3 (CDN) |
| 외부 API | Naver Maps (`bestroute2.jsp` 경로 시각화) |

## 3. 폴더 구조

```
HMC-SCM/
├── CLAUDE.md                  ← 이 문서 (개발 가이드)
├── frontend/
│   ├── src/                   ← JSP 페이지 전체
│   ├── com/util/DBUtil.java   ← DB 연결 유틸 (※ 4번 주의사항 참고)
│   ├── ai-agent/              ← 알고리즘 핵심 JSP (분석용 사본)
│   │   ├── supplymgt.jsp      ← 유전알고리즘 생산최적화
│   │   └── bestroute2.jsp     ← TSP 최적경로
│   └── style.css              ← 공통 스타일시트
└── docs/
    ├── HMC_SCM_분석설계문서.md   ← 분석·설계 산출물
    └── 개발방법론__AIsw.md       ← 개발방법론(참고)
```

### 기능 모듈 (frontend/src)
- **인증/회원:** `login.jsp`, `signup.jsp`, `adminApproval.jsp`, `profile.jsp`
- **공통 레이아웃:** `navbar.jsp`, `sidebar.jsp`, `footer.jsp`
- **대시보드:** `dashboard.jsp`
- **공지:** `notice.jsp`, `noticeRead.jsp`
- **입찰:** `bidReg.jsp`, `bidList.jsp`, `bidItemReg.jsp`
- **품목/부품:** `itemReg.jsp`, `itemDetailReg.jsp`, `partSearch.jsp`, `parts_db_view.jsp`
- **납품:** `delivery.jsp`, `deliveryList.jsp`
- **평가:** `evaluation.jsp`, `evaluationList.jsp`
- **협력사:** `vendorDetail.jsp`, `vendorReport2.jsp`
- **정산:** `settlement.jsp`
- **공급망 최적화:** `supplymgt.jsp`(유전알고리즘), `bestroute2.jsp`(TSP)

## 4. ⚠️ 중요 주의사항 (GitHub 정리 후 현재 상태)

1. **사이트가 현재는 동작하지 않습니다.**
   GitHub 표준 구조로 폴더를 옮기면서 JSP의 URL 경로/상대 링크가 깨진 상태입니다.
   실제 재배포 시에는 Tomcat 컨텍스트 기준으로 경로를 다시 맞춰야 합니다.

2. **DBUtil 패키지 경로 불일치.**
   - JSP들은 `<%@ page import="...util.DBUtil" %>` 즉 **`package util`** 로 참조합니다.
   - 이 레포에서는 다이어그램에 맞춰 `frontend/com/util/DBUtil.java` 에 두었습니다.
   - 실제 구동 시: 패키지를 `util` 그대로 두려면 `WEB-INF/classes/util/DBUtil.java` 위치가 맞고,
     `com.util` 로 바꾸려면 17개 JSP의 import도 함께 수정해야 합니다.

3. **`supplymgt.jsp` / `bestroute2.jsp` 는 `src/` 와 `ai-agent/` 양쪽에 중복 존재**합니다.
   장기적으로는 한쪽만 원본으로 두는 것을 권장합니다.

## 5. DB 접속 정보 (DBUtil.java)

- URL: `jdbc:mysql://localhost:3306/HMC_SCM`
- 옵션: `useSSL=false&serverTimezone=Asia/Seoul&characterEncoding=UTF-8`
- 계정: `root` / `1234`  ← **운영 전 반드시 변경 및 외부화(환경변수/설정파일) 필요**

## 6. 코딩 규약

- DB 접근 JSP 표준 import: `<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>`
- 연결 해제는 반드시 `DBUtil.close(conn, ps, rs)` 사용 (자원 누수 방지)
- SQL은 `PreparedStatement` 사용 (SQL Injection 방지)

## 7. AI 에이전트 작업 지침

1. 코드 변경 전 `docs/HMC_SCM_분석설계문서.md` 의 관련 기능 명세를 먼저 확인한다.
2. DB 스키마 변경이 필요하면 문서를 먼저 갱신하고 코드를 수정한다.
3. 자격증명(비밀번호 등)은 코드에 하드코딩하지 말고 외부화한다.
