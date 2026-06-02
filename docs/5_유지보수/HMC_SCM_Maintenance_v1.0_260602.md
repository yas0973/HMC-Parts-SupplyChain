# HMC-SCM 유지보수 가이드 (Maintenance Guide)

- **문서 ID:** HMC_SCM_Maintenance_v1.0
- **작성일:** 2026-06-02 | **버전:** v1.0 (초안)
- **단계:** 5. 유지보수 (Maintenance)

---

## 1. 운영 환경 정보

| 항목 | 값 |
| :--- | :--- |
| WAS | Apache Tomcat 9.0 |
| DB | MySQL — `HMC_SCM` |
| 접속 URL | `jdbc:mysql://localhost:3306/HMC_SCM` |
| 소스 | GitHub `yas0973/HMC-Parts-SupplyChain` |

## 2. 변경 관리 (Change Management)

1. 이슈 등록(GitHub Issues) → 브랜치 생성 → 수정 → PR → 리뷰 → `main` 병합
2. DB 스키마 변경 시 **설계 문서(Data Design) 먼저 갱신** 후 코드 반영
3. 변경 시 관련 요구사항 ID(FR-xxx)와 연결해 추적성 유지

## 3. 정기 점검 항목

| 주기 | 점검 내용 |
| :--- | :--- |
| 일 | Tomcat/DB 기동, 에러 로그 확인 |
| 주 | 디스크/로그 용량, 슬로우 쿼리 |
| 월 | 백업 복구 테스트, 보안 패치, 의존 라이브러리 점검 |

## 4. 장애 대응 절차 (Troubleshooting)

| 증상 | 점검 순서 | 조치 |
| :--- | :--- | :--- |
| 페이지 500 오류 | catalina.out 로그 확인 | 스택트레이스 기반 수정 |
| DB 연결 실패 | DBUtil URL/계정, MySQL 기동 | 자격증명/네트워크 점검 |
| 드라이버 오류 | `ClassNotFound: mysql` | Connector/J `WEB-INF/lib` 확인 |
| 지도 미표시 | Naver 키/네트워크 | 키 갱신, 콘솔 에러 확인 |
| 권한 우회 접근 | 세션 `role` 체크 누락 | 페이지 권한 검증 추가 |

## 5. 백업 / 복구

- **DB 백업:** `mysqldump HMC_SCM > backup_YYMMDD.sql` (일 1회 권장)
- **복구:** `mysql HMC_SCM < backup_YYMMDD.sql`
- **소스 백업:** Git 원격(GitHub)이 1차 백업 역할
- *백업 보관 주기/위치 정책 (확인 필요)*

## 6. 기술 부채 / 개선 백로그

| 우선순위 | 항목 | 내용 |
| :--- | :--- | :--- |
| 높음 | 자격증명 외부화 | DBUtil 하드코딩(`root`/`1234`) 제거 |
| 높음 | 사이트 경로 복구 | 폴더 재구성으로 깨진 JSP 링크/경로 정렬 |
| 중간 | 계층 분리 | JSP 스크립틀릿 → Service/DAO 분리 |
| 중간 | 입력 검증 강화 | 서버측 유효성·권한 일괄 점검 |
| 낮음 | 코드 중복 제거 | supplymgt/bestroute2 src·ai-agent 중복 정리 |

## 7. 보안 유지보수 체크리스트

- [ ] DB 비밀번호 정기 변경 및 운영 계정 분리
- [ ] 전 SQL `PreparedStatement` 적용 점검
- [ ] 세션 타임아웃/로그아웃 처리 확인
- [ ] 첨부(Base64) 크기 제한 및 검증
- [ ] 의존 라이브러리 취약점(CVE) 모니터링
