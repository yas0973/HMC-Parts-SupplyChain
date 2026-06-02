<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>
<%
    // 로그인 및 세션 체크 [cite: 52, 53, 54]
    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    
    if (userId == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // 보고서용 샘플 데이터 (대시보드 evalList 기반) [cite: 60]
    String reportDate = "2026-03-26";
    String[][] performanceData = {
        {"품질 지수", "98.5%", "A", "정상"},
        {"납기 준수", "96.2%", "B", "주의"},
        {"가격 경쟁력", "92.0%", "B", "정상"},
        {"협력도", "100%", "A", "우수"}
    };
%>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>벤더 성과 보고서 | HMC SCM</title>
    <link rel="stylesheet" href="/project/style.css">
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
    <style>
        /* 대시보드 스타일 계승 [cite: 64, 65] */
        :root {
            --primary: #003DA5; --accent: #00AAD4; --panel: #0D1B2A;
            --surface: #112240; --border: rgba(0,170,212,.2);
            --text: #E8F0FE; --success: #00E5A0; --warning: #F59E0B;
        }
        body { background: var(--panel); color: var(--text); font-family: 'Noto Sans KR', sans-serif; margin: 0; }
        .wrapper { display: flex; flex-direction: column; min-height: 100vh; }
        .layout { flex: 1; display: grid; grid-template-columns: 220px 1fr; }
        .main { padding: 28px; }

        /* 보고서 특화 스타일 */
        .report-header { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 30px; border-bottom: 2px solid var(--accent); padding-bottom: 15px; }
        .report-title { font-size: 32px; font-weight: 700; }
        .report-info { text-align: right; color: var(--muted); }

        .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 24px; margin-bottom: 20px; }
        .card-title { font-size: 18px; color: var(--accent); margin-bottom: 20px; text-transform: uppercase; letter-spacing: 1px; }

        /* 테이블 스타일 [cite: 89, 90, 91] */
        .tbl { width: 100%; border-collapse: collapse; }
        .tbl th { color: var(--muted); padding: 12px; border-bottom: 1px solid var(--border); text-align: left; font-size: 14px; }
        .tbl td { padding: 15px 12px; border-bottom: 1px solid rgba(255,255,255,.05); font-size: 16px; }

        /* 이메일 폼 스타일 */
        .email-section { display: flex; gap: 10px; align-items: center; margin-top: 20px; }
        .input-field { background: rgba(255,255,255,0.05); border: 1px solid var(--border); color: white; padding: 10px 15px; border-radius: 5px; flex: 1; }
        .btn-send { background: var(--accent); color: white; border: none; padding: 10px 25px; border-radius: 5px; cursor: pointer; font-weight: 600; transition: 0.3s; }
        .btn-send:hover { background: #008eb3; box-shadow: 0 0 15px rgba(0,170,212,0.4); }

        .status-tag { font-family: 'Share Tech Mono', monospace; font-weight: bold; }
    </style>
    <script>
        function sendEmail() {
            const email = document.getElementById('targetEmail').value;
            if(!email) { alert('이메일 주소를 입력해주세요.'); return; }
            
            // 실제 환경에서는 AJAX를 통해 서버(Java Mail API)로 전송 로직 구현
            alert(email + ' 주소로 보고서 전송이 시작되었습니다.');
        }
    </script>
</head>
<body>
<div class="wrapper">
    <jsp:include page="/project/navbar.jsp" />
    <div class="layout">
        <jsp:include page="/project/sidebar.jsp" />
        
        <div class="main">
            <div class="report-header">
                <div class="report-title">PARTNER PERFORMANCE REPORT</div>
                <div class="report-info">
                    <div>대상 기업: <strong><%= company %></strong></div>
                    <div>기준 일자: <%= reportDate %></div>
                </div>
            </div>

            <div class="grid2">
                <div class="card">
                    <div class="card-title">종합 평가 지표</div>
                    <table class="tbl">
                        <thead>
                            <tr>
                                <th>평가 항목</th>
                                <th>수치</th>
                                <th>등급</th>
                                <th>상태</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% for(String[] row : performanceData) { %>
                            <tr>
                                <td><%= row[0] %></td>
                                <td class="status-tag" style="color:var(--success)"><%= row[1] %></td>
                                <td><span class="badge grade-a"><%= row[2] %></span></td>
                                <td><%= row[3] %></td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>

                <div class="card">
                    <div class="card-title">보고서 외부 전송 (E-MAIL)</div>
                    <p style="color: var(--muted); font-size: 14px; margin-bottom: 15px;">
                        본 성과 보고서를 파트너사 또는 담당자에게 PDF 형식으로 전송합니다.
                    </p>
                    <div class="email-section">
                        <input type="email" id="targetEmail" class="input-field" placeholder="recipient@hyundai.com">
                        <button onclick="sendEmail()" class="btn-send">보고서 발송</button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>