<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>
<%
    // 1. 세션 및 권한 체크
    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    String roleLabel = (String) session.getAttribute("roleLabel");

    if (userId == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // 2. 아바타용 이니셜 추출 (필요 시 유지, 현재 UI에서는 제거됨)
    String initials = (company != null && company.length() >= 2) ?
        company.substring(0,2) : company;
%>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HMC SCM | 정산 현황 상세</title>
    
    <link rel="stylesheet" href="/project/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
    
    <style>
        /* 대시보드 디자인 시스템 계승 */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --primary: #003DA5;
            --accent: #00AAD4; --panel: #0D1B2A;
            --surface: #112240; --sidebar: #0a1520; --border: rgba(0,170,212,.2);
            --text: #E8F0FE; --muted: #7A8FA6; --success: #00E5A0;
            --warning: #F59E0B; --danger: #EF4444;
        }
        html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: var(--panel); color: var(--text); overflow: hidden; }
        
        .wrapper { display: flex; flex-direction: column; height: 100vh; }
        
        /* 레이아웃 구조 (사이드바 220px 그리드 고정) */
        .layout { flex: 1; display: grid; grid-template-columns: 220px 1fr; overflow: hidden; }

        /* [가운데 콘텐츠] 내용만 약 20% 축소 적용 */
        .main { padding: 28px; overflow-y: auto; background: var(--panel); }
        .content-wrapper { max-width: 80%; margin: 0 auto; } 
        
        .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
        .page-title { font-size: 32px; font-weight: 700; letter-spacing: 1px; }
        .page-title span { color: var(--accent); font-weight: 400; font-size: 14px; }

        /* KPI 카드 스타일 */
        .kpi-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 20px; }
        .kpi-card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 16px; position: relative; overflow: hidden; }
        .kpi-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 2px; background: linear-gradient(90deg,#00AAD4,#00E5A0); }
        .kpi-val { font-size: 24px; font-weight: 700; font-family: 'Share Tech Mono', monospace; }
        .kpi-lbl { font-size: 18px; color: var(--muted); margin-top: 4px; }

        /* 카드 및 테이블 스타일 */
        .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 16px; margin-bottom: 16px; }
        .card-title { font-size: 32px; color: var(--muted); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px; }
        
        .tbl { width: 100%; border-collapse: collapse; }
        .tbl th { font-size: 24px; color: var(--muted); font-weight: 500; padding: 6px 8px; border-bottom: 1px solid rgba(255,255,255,.07); text-align: left; }
        .tbl td { padding: 9px 8px; border-bottom: 1px solid rgba(255,255,255,0.04); color: #B0C4D8; font-size: 13px; }

        /* 뱃지 및 가격 셀 */
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 18px; font-weight: 600; }
        .badge.done { background: rgba(0,229,160,.15); color: #00E5A0; }
        .badge.open { background: rgba(0,170,212,0.15); color: #00AAD4; }
        .price-cell { font-family: 'Share Tech Mono', monospace; color: #00E5A0; font-weight: 600; }

        .btn-action { background: rgba(0,170,212,0.1); color: var(--accent); border: 1px solid var(--accent); padding: 8px 20px; border-radius: 5px; text-decoration: none; font-size: 14px; transition: 0.2s; }
        .btn-action:hover { background: var(--accent); color: white; text-decoration: none; }
    </style>
</head>
<body>
<div class="wrapper">
    <jsp:include page="/project/navbar.jsp" />
    
    <div class="layout">
      <jsp:include page="/project/sidebar.jsp" />  

        <main class="main">
            <div class="content-wrapper">
                <div class="topbar">
                    <div class="page-title">매입 정산 리포트 <span>/ Monthly Settlement Summary</span></div>
                    </div>

                <div class="kpi-grid">
                    <div class="kpi-card"><div class="kpi-val">₩ 42,850,000</div><div class="kpi-lbl">당월 총 매입액</div></div>
                    <div class="kpi-card"><div class="kpi-val">₩ 38,200,000</div><div class="kpi-lbl">정산 완료액</div></div>
                    <div class="kpi-card"><div class="kpi-val">₩ 4,650,000</div><div class="kpi-lbl">미결제 잔액</div></div>
                    <div class="kpi-card"><div class="kpi-val">2026-04-10</div><div class="kpi-lbl">차기 지급 예정일</div></div>
                </div>

                <div class="card">
                    <div class="card-title">세부 거래 내역</div>
                    <table class="tbl">
                        <thead>
                            <tr>
                                <th>거래 일자</th><th>전표 번호</th><th>품목</th><th>금액</th><th>상태</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td>2026-03-25</td><td>INV-2603-01</td><td>엔진모듈 A-1</td><td class="price-cell">₩ 24,000,000</td><td><span class="badge done">지급 완료</span></td></tr>
                            <tr><td>2026-03-20</td><td>INV-2603-02</td><td>배기시스템 B-7</td><td class="price-cell">₩ 8,500,000</td><td><span class="badge done">지급 완료</span></td></tr>
                            <tr><td>2026-03-15</td><td>INV-2603-03</td><td>고정용 플랜지</td><td class="price-cell">₩ 3,200,000</td><td><span class="badge open">승인 대기</span></td></tr>
                        </tbody>
                    </table>
                    <div style="text-align:right; margin-top:30px;">
                        <a href="dashboard.jsp" class="btn-action">대시보드로 돌아가기</a>
                    </div>
                </div>

            </div>
        </main>
    </div>
    
    <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>