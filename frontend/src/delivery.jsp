<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.util.*" %>
<%@ page import="java.net.HttpURLConnection" %>
<%@ page import="java.net.URL" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.io.BufferedReader" %>
<%@ page import="java.io.InputStreamReader" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%
    // ── Naver API 인증 정보 ──
    final String NAVER_CLIENT_ID     = "qbne7axnj9";
    final String NAVER_CLIENT_SECRET = "Af9UBYC9fXfzs9Kb6Eu4A4hFY4vMYB2aaQQ2qx7s";

    // ── Directions 프록시 처리 ──
    String apiAction = request.getParameter("apiAction");
    if ("directions".equals(apiAction)) {
        response.setContentType("application/json; charset=UTF-8");
        String start  = request.getParameter("start");
        String goal   = request.getParameter("goal");
        String option = request.getParameter("option");
        if (start == null || goal == null || start.trim().isEmpty() || goal.trim().isEmpty()) {
            response.setStatus(400);
            out.print("{\"error\":true,\"message\":\"start/goal 파라미터가 필요합니다.\"}");
            return;
        }
        if (option == null || option.trim().isEmpty()) option = "trafast";
        HttpURLConnection conn = null;
        BufferedReader reader  = null;
        try {
            String endpoint = "https://maps.apigw.ntruss.com/map-direction-15/v1/driving";
            String query    = "start=" + URLEncoder.encode(start, "UTF-8")
                            + "&goal="  + URLEncoder.encode(goal,  "UTF-8")
                            + "&option="+ URLEncoder.encode(option, "UTF-8");
            URL url = new URL(endpoint + "?" + query);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("x-ncp-apigw-api-key-id", NAVER_CLIENT_ID);
            conn.setRequestProperty("x-ncp-apigw-api-key",    NAVER_CLIENT_SECRET);
            conn.setRequestProperty("Accept", "application/json");
            int status = conn.getResponseCode();
            response.setStatus(status);
            reader = new BufferedReader(new InputStreamReader(
                status >= 200 && status < 300 ? conn.getInputStream() : conn.getErrorStream(),
                StandardCharsets.UTF_8));
            StringBuilder body = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) body.append(line);
            out.print(body.toString());
            return;
        } catch (Exception e) {
            response.setStatus(500);
            out.print("{\"error\":true,\"message\":\"" + e.getMessage().replace("\"","\\\"") + "\"}");
            return;
        } finally {
            try { if (reader != null) reader.close(); } catch (Exception ignore) {}
            try { if (conn   != null) conn.disconnect();} catch (Exception ignore) {}
        }
    }

    // ── 세션 체크 ──
    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    String roleLabel = (String) session.getAttribute("roleLabel");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    String deliveryId = request.getParameter("id") != null ? request.getParameter("id") : "DLV-2024-001";

    // 하드코딩 데이터
    String partName          = "엔진모듈 A-1";
    String vendor            = "현대모비스";
    String quantity          = "500 EA";
    String status            = "운송중";
    String driver            = "현대글로비스 경기 88사 1234";
    String driverName        = "김철수 기사님";
    String driverPhone       = "010-9876-5432";
    String departureLocation = "경기도 화성시 팔탄면 현대모비스 물류센터";
    String departureTime     = "2024-12-04 08:30";
    String arrivalLocation   = "울산광역시 북구 현대자동차 울산공장";
    String arrivalTime       = "2024-12-05 14:30";
    String routeSummary      = "화성 → 천안 → 대전 → 대구 → 울산 (경부고속도로)";
    String currentLocation   = "대전 IC";
    boolean isTransit = "운송중".equals(status);

    // 출발지/도착지 좌표 (하드코딩)
    // 현대모비스 화성 물류센터: 126.9988, 37.1815
    // 현대자동차 울산공장: 129.3571, 35.5384
    String startCoord = "126.9988,37.1815";
    String goalCoord  = "129.3571,35.5384";
%>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HMC SCM | 납품 상세 현황</title>
    <link rel="stylesheet" href="/project/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">

    <!-- 네이버 지도 SDK -->
    <script type="text/javascript"
        src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=<%= NAVER_CLIENT_ID %>"></script>

    <style>
        :root {
            --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240;
            --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0;
            --warning:#F59E0B; --border:rgba(0,170,212,.2); --danger:#EF4444;
        }
        html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); }
        .wrapper { display:flex; flex-direction:column; min-height:100vh; }
        .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
        .main-scroll { padding:30px; overflow-y:auto; background:var(--panel); }
        .page-title { font-size:28px; margin-bottom:24px; font-weight:700; }
        .page-title span { font-size:18px; opacity:0.7; }
        .info-card { border-radius:12px; padding:30px; border:1px solid var(--border); box-shadow:0 10px 30px rgba(0,0,0,0.3); background:var(--surface); }
        .info-card.transit { background:linear-gradient(135deg,#112240 55%,rgba(0,170,212,0.07) 100%); border-color:rgba(0,170,212,0.35); }

        /* 트래커 */
        .tracker { display:flex; justify-content:space-between; margin-bottom:36px; position:relative; padding:20px 0; }
        .tracker::before { content:''; position:absolute; top:38px; left:5%; right:5%; height:2px; background:rgba(255,255,255,0.08); z-index:1; }
        .step { position:relative; z-index:2; text-align:center; width:20%; }
        .step-icon { width:40px; height:40px; border-radius:50%; background:#1a2a44; border:2px solid #2d3d5a; color:#4a5a74; display:flex; align-items:center; justify-content:center; margin:0 auto 10px; transition:0.3s; font-size:14px; position:relative; }
        .step.completed .step-icon { background:var(--success); border-color:var(--success); color:#0D1B2A; }
        .step.active    .step-icon { background:var(--accent);  border-color:var(--accent);  color:#fff; box-shadow:0 0 15px rgba(0,170,212,.5); }
        @keyframes trackerPulse { 0%{transform:translate(-50%,-50%) scale(1);opacity:.6} 70%{transform:translate(-50%,-50%) scale(1.4);opacity:0} 100%{transform:translate(-50%,-50%) scale(1);opacity:0} }
        .step.active .step-icon::before { content:''; position:absolute; width:66px; height:66px; border-radius:50%; background:rgba(0,170,212,.45); border:2px solid rgba(0,170,212,.7); top:50%; left:50%; transform:translate(-50%,-50%); z-index:-1; animation:trackerPulse 1.8s ease-out infinite; }
        .step-label { font-size:12px; color:var(--muted); font-weight:500; }
        .step.active    .step-label { color:var(--accent); font-weight:700; }
        .step.completed .step-label { color:var(--success); }

        /* 테이블 */
        .detail-table { width:100%; border-collapse:collapse; margin-top:10px; }
        .detail-table th { width:160px; color:var(--muted); padding:16px 15px; font-size:13px; border-bottom:1px solid rgba(255,255,255,0.05); text-align:left; font-weight:500; white-space:nowrap; }
        .detail-table td { padding:16px 15px; font-size:15px; border-bottom:1px solid rgba(255,255,255,0.05); color:var(--text); }
        .mono { font-family:'Share Tech Mono',monospace; color:var(--accent); }
        .badge-status { display:inline-block; padding:4px 14px; border-radius:6px; font-size:13px; font-weight:600; }
        .badge-transit { background:rgba(0,170,212,.15); color:var(--accent); border:1px solid rgba(0,170,212,.4); }
        .badge-done    { background:rgba(0,229,160,.15); color:var(--success); border:1px solid rgba(0,229,160,.4); }
        .route-cell { display:flex; align-items:center; gap:12px; flex-wrap:wrap; }
        .btn-map { display:inline-flex; align-items:center; gap:6px; padding:6px 14px; border-radius:6px; font-size:13px; font-weight:500; background:rgba(0,170,212,.1); border:1px solid rgba(0,170,212,.4); color:var(--accent); cursor:pointer; transition:all .2s; white-space:nowrap; font-family:'Noto Sans KR',sans-serif; }
        .btn-map:hover { background:rgba(0,170,212,.25); }
        .btn-action { display:inline-block; padding:10px 22px; border-radius:8px; font-size:14px; font-weight:500; text-decoration:none; border:1px solid var(--accent); color:var(--accent); background:transparent; transition:all .2s; }
        .btn-action:hover { background:rgba(0,170,212,.12); text-decoration:none; color:var(--accent); }

        /* 지도 모달 */
        .map-modal { display:none; position:fixed; inset:0; z-index:9999; background:rgba(0,0,0,.78); align-items:center; justify-content:center; }
        .map-modal.show { display:flex; }
        .map-box { background:var(--surface); border:1px solid var(--border); border-radius:14px; overflow:hidden; width:900px; max-width:95vw; max-height:90vh; box-shadow:0 24px 60px rgba(0,0,0,.65); display:flex; flex-direction:column; }
        .map-header { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid var(--border); background:rgba(0,170,212,.05); flex-shrink:0; }
        .map-title { font-size:13px; font-weight:600; color:var(--accent); letter-spacing:.5px; }
        .map-close { width:30px; height:30px; border-radius:50%; background:rgba(255,255,255,.07); border:1px solid rgba(255,255,255,.15); color:var(--text); font-size:14px; cursor:pointer; display:flex; align-items:center; justify-content:center; transition:background .2s; }
        .map-close:hover { background:rgba(239,68,68,.35); }

        /* 지도 탭 */
        .map-tabs { display:flex; gap:0; border-bottom:1px solid var(--border); flex-shrink:0; }
        .map-tab { flex:1; padding:11px; font-size:13px; font-weight:500; color:var(--muted); background:none; border:none; cursor:pointer; font-family:'Noto Sans KR',sans-serif; border-bottom:2px solid transparent; transition:all .2s; }
        .map-tab:hover { color:var(--text); background:rgba(255,255,255,.03); }
        .map-tab.active { color:var(--accent); border-bottom-color:var(--accent); background:rgba(0,170,212,.04); }

        /* 탭 콘텐츠 */
        .map-tab-content { display:none; flex:1; overflow:hidden; flex-direction:column; }
        .map-tab-content.active { display:flex; }

        /* 네이버 지도 */
        #deliveryNaverMap { width:100%; flex:1; min-height:420px; }
        .map-status-bar { padding:10px 16px; background:rgba(0,170,212,.05); border-top:1px solid var(--border); font-size:12px; color:var(--muted); flex-shrink:0; display:flex; align-items:center; gap:8px; }
        .map-loading { display:flex; align-items:center; justify-content:center; height:420px; flex-direction:column; gap:12px; color:var(--muted); font-size:14px; }
        .spinner { width:32px; height:32px; border:3px solid rgba(0,170,212,.2); border-top-color:var(--accent); border-radius:50%; animation:spin .8s linear infinite; }
        @keyframes spin { to { transform:rotate(360deg); } }

        /* 경로 타임라인 탭 */
        .route-tab-body { padding:24px 28px; overflow-y:auto; flex:1; }
        .route-summary-row { display:flex; gap:12px; margin-bottom:24px; flex-wrap:wrap; }
        .route-kpi { background:rgba(0,170,212,.08); border:1px solid rgba(0,170,212,.2); border-radius:8px; padding:10px 16px; display:flex; flex-direction:column; gap:3px; }
        .route-kpi-label { font-size:11px; color:var(--muted); letter-spacing:1px; }
        .route-kpi-val   { font-size:18px; font-weight:700; font-family:'Share Tech Mono',monospace; color:var(--accent); }
    </style>
</head>
<body>
<div class="wrapper">
    <jsp:include page="/project/navbar.jsp" />
    <div class="layout">
        <jsp:include page="/project/sidebar.jsp" />
        <div class="main-scroll">
            <div class="page-title">납품 상세 정보 <span>/ Tracking ID: <%= deliveryId %></span></div>

            <div class="info-card <%= isTransit ? "transit" : "" %>">
                <!-- 트래커 -->
                <div class="tracker">
                    <div class="step completed"><div class="step-icon"><i class="fas fa-check"></i></div><div class="step-label">주문접수</div></div>
                    <div class="step completed"><div class="step-icon"><i class="fas fa-industry"></i></div><div class="step-label">생산완료</div></div>
                    <div class="step <%= isTransit ? "active" : "completed" %>"><div class="step-icon"><i class="fas fa-truck-moving"></i></div><div class="step-label">운송중</div></div>
                    <div class="step"><div class="step-icon"><i class="fas fa-warehouse"></i></div><div class="step-label">검수중</div></div>
                    <div class="step"><div class="step-icon"><i class="fas fa-flag-checkered"></i></div><div class="step-label">납품완료</div></div>
                </div>

                <!-- 상세 테이블 -->
                <table class="detail-table">
                    <tr><th>납품 품목</th><td><%= partName %></td></tr>
                    <tr><th>공급 업체</th><td><%= vendor %></td></tr>
                    <tr><th>납품 수량</th><td class="mono"><%= quantity %></td></tr>
                    <tr>
                        <th>현재 상태</th>
                        <td><span class="badge-status <%= isTransit ? "badge-transit" : "badge-done" %>"><%= status %></span></td>
                    </tr>
                    <tr><th>출발지</th><td><%= departureLocation %></td></tr>
                    <tr><th>출발 시각</th><td class="mono"><%= departureTime %></td></tr>
                    <tr><th>도착지</th><td><%= arrivalLocation %></td></tr>
                    <tr><th>도착 예정 시각</th><td class="mono"><%= arrivalTime %></td></tr>
                    <tr>
                        <th>운송 경로</th>
                        <td>
                            <div class="route-cell">
                                <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
                                    <span class="badge badge-pill" style="background:rgba(0,229,160,.12);border:1px solid rgba(0,229,160,.3);color:var(--success);font-size:12px;padding:5px 12px;font-weight:600;"><i class="fas fa-check" style="font-size:10px;margin-right:3px;"></i>화성</span>
                                    <i class="fas fa-chevron-right" style="font-size:10px;color:var(--muted);"></i>
                                    <span class="badge badge-pill" style="background:rgba(0,229,160,.12);border:1px solid rgba(0,229,160,.3);color:var(--success);font-size:12px;padding:5px 12px;font-weight:600;"><i class="fas fa-check" style="font-size:10px;margin-right:3px;"></i>천안</span>
                                    <i class="fas fa-chevron-right" style="font-size:10px;color:var(--muted);"></i>
                                    <span class="badge badge-pill" style="background:rgba(0,170,212,.2);border:2px solid rgba(0,170,212,.6);color:var(--accent);font-size:12px;padding:5px 12px;font-weight:700;box-shadow:0 0 10px rgba(0,170,212,.3);"><i class="fas fa-map-marker-alt" style="font-size:10px;margin-right:3px;"></i>대전</span>
                                    <i class="fas fa-chevron-right" style="font-size:10px;color:var(--muted);"></i>
                                    <span class="badge badge-pill" style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.12);color:var(--muted);font-size:12px;padding:5px 12px;">대구</span>
                                    <i class="fas fa-chevron-right" style="font-size:10px;color:var(--muted);"></i>
                                    <span class="badge badge-pill" style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.12);color:var(--muted);font-size:12px;padding:5px 12px;">울산</span>
                                    <span style="font-size:11px;color:var(--muted);margin-left:4px;">(경부고속도로)</span>
                                </div>
                                <button class="btn-map" onclick="openMap()">
                                    <i class="fas fa-map-marker-alt"></i> 지도 보기
                                </button>
                            </div>
                        </td>
                    </tr>
                    <tr><th>운송 차량</th><td><%= driver %></td></tr>
                    <tr>
                        <th>담당 기사</th>
                        <td>
                            <div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;">
                                <span><%= driverName %></span>
                                <a href="tel:<%= driverPhone %>" style="display:inline-flex;align-items:center;gap:6px;padding:5px 14px;border-radius:6px;font-size:13px;background:rgba(0,229,160,.1);border:1px solid rgba(0,229,160,.3);color:var(--success);text-decoration:none;">
                                    <i class="fas fa-phone" style="font-size:11px;"></i> <%= driverPhone %>
                                </a>
                            </div>
                        </td>
                    </tr>
                </table>
                <div style="text-align:right;margin-top:28px;">
                    <a href="deliveryList.jsp" class="btn-action">← 납품 현황 목록으로 돌아가기</a>
                </div>
            </div>
        </div>
    </div>
    <jsp:include page="/project/footer.jsp" />
</div>

<!-- ══ 지도 모달 ══ -->
<div class="map-modal" id="mapModal" onclick="closeMapOutside(event)">
    <div class="map-box" onclick="event.stopPropagation()">

        <div class="map-header">
            <span class="map-title"><i class="fas fa-route" style="margin-right:6px;"></i>운송 경로 — 경부고속도로</span>
            <div class="map-close" onclick="closeMap()">✕</div>
        </div>

        <!-- 탭 -->
        <div class="map-tabs">
            <button class="map-tab active" onclick="switchTab('naver')">
                <i class="fas fa-map" style="margin-right:6px;"></i>실시간 지도
            </button>
            <button class="map-tab" onclick="switchTab('timeline')">
                <i class="fas fa-list-ul" style="margin-right:6px;"></i>경로 타임라인
            </button>
        </div>

        <!-- 탭 1: 네이버 지도 -->
        <div class="map-tab-content active" id="tab-naver">
            <div id="mapLoadingArea" class="map-loading">
                <div class="spinner"></div>
                <span>실제 도로 기준 경로를 불러오는 중...</span>
            </div>
            <div id="deliveryNaverMap" style="display:none;"></div>
            <div class="map-status-bar" id="mapStatusBar">
                <i class="fas fa-info-circle" style="color:var(--accent);"></i>
                <span id="mapStatusText">경로를 불러오는 중입니다...</span>
            </div>
        </div>

        <!-- 탭 2: 경로 타임라인 -->
        <div class="map-tab-content" id="tab-timeline">
            <div class="route-tab-body">
                <div class="route-summary-row">
                    <div class="route-kpi"><span class="route-kpi-label">총 거리</span><span class="route-kpi-val">415 km</span></div>
                    <div class="route-kpi" style="background:rgba(0,229,160,.08);border-color:rgba(0,229,160,.2);"><span class="route-kpi-label">예상 소요시간</span><span class="route-kpi-val" style="color:var(--success);">약 4시간 30분</span></div>
                    <div class="route-kpi" style="background:rgba(245,158,11,.08);border-color:rgba(245,158,11,.2);"><span class="route-kpi-label">이용 고속도로</span><span class="route-kpi-val" style="color:var(--warning);font-size:14px;">경부고속도로 (1호선)</span></div>
                    <div class="route-kpi" style="background:rgba(0,170,212,.12);border:2px solid rgba(0,170,212,.5);"><span class="route-kpi-label" style="color:var(--accent);">현재 위치</span><span class="route-kpi-val" style="font-size:14px;">대전 IC 부근</span></div>
                </div>
                <div style="position:relative;padding-left:20px;">
                    <div style="position:absolute;left:27px;top:20px;bottom:20px;width:2px;background:linear-gradient(180deg,var(--accent),rgba(0,170,212,.15));"></div>
                    <!-- 출발 -->
                    <div style="display:flex;align-items:flex-start;gap:16px;margin-bottom:20px;">
                        <div style="width:16px;height:16px;border-radius:50%;background:var(--accent);border:3px solid var(--panel);flex-shrink:0;margin-top:3px;box-shadow:0 0 10px rgba(0,170,212,.6);"></div>
                        <div><div style="font-size:11px;color:var(--accent);letter-spacing:1px;margin-bottom:3px;">출발</div><div style="font-size:14px;font-weight:700;">현대모비스 화성물류센터</div><div style="font-size:12px;color:var(--muted);margin-top:2px;">경기도 화성시 팔탄면 · 출발 08:30</div></div>
                    </div>
                    <%
                    String[][] ics = {
                        {"화성 IC",    "경부고속도로 진입",   "08:45","0 km",  "done"},
                        {"기흥 IC",    "통과",               "09:10","32 km", "done"},
                        {"오산 IC",    "통과",               "09:25","48 km", "done"},
                        {"천안 IC",    "휴게소 경유 (선택)", "10:05","96 km", "done"},
                        {"청주 IC",    "통과",               "10:50","145 km","done"},
                        {"옥천 IC",    "통과",               "11:15","175 km","done"},
                        {"금강 휴게소","휴식 예정 (15분)",   "11:30","190 km","done"},
                        {"대전 IC",    "통과",               "11:55","210 km","current"},
                        {"회덕 JC",    "경부고속도로 유지",  "12:05","220 km","upcoming"},
                        {"추풍령 IC",  "통과",               "12:45","270 km","upcoming"},
                        {"김천 IC",    "통과",               "13:10","300 km","upcoming"},
                        {"대구 IC",    "통과",               "13:50","340 km","upcoming"},
                        {"경산 IC",    "통과",               "14:05","358 km","upcoming"},
                        {"언양 IC",    "경부고속도로 출구",  "14:45","405 km","upcoming"},
                    };
                    for (String[] ic : ics) {
                        boolean isRest    = ic[1].contains("휴게소")||ic[1].contains("휴식");
                        boolean isEnter   = ic[1].contains("진입")||ic[1].contains("출구")||ic[1].contains("JC");
                        boolean isCurrent = "current".equals(ic[4]);
                        boolean isDone    = "done".equals(ic[4]);
                    %>
                    <div style="display:flex;align-items:flex-start;gap:16px;margin-bottom:16px;position:relative;<%= isCurrent ? "background:rgba(0,170,212,.07);border:1px solid rgba(0,170,212,.2);border-radius:8px;padding:10px 10px 10px 0;margin-left:-10px;" : "" %>">
                        <div style="width:10px;height:10px;border-radius:50%;flex-shrink:0;margin-top:5px;margin-left:3px;
                            background:<%= isCurrent?"var(--accent)":isDone?"var(--success)":isRest?"var(--warning)":isEnter?"var(--success)":"rgba(255,255,255,.15)" %>;
                            border:2px solid var(--panel);
                            <%= isCurrent?"box-shadow:0 0 10px rgba(0,170,212,.8);width:13px;height:13px;":isDone?"opacity:0.7;":"opacity:0.4;" %>
                        "></div>
                        <div style="flex:1;display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:4px;">
                            <div>
                                <div style="display:flex;align-items:center;gap:8px;">
                                    <span style="font-size:13px;font-weight:600;color:<%= isCurrent?"var(--accent)":isDone?"var(--success)":isRest?"var(--warning)":isEnter?"var(--success)":"var(--muted)" %>;"><%= ic[0] %></span>
                                    <% if (isCurrent) { %><span style="background:rgba(0,170,212,.2);border:1px solid rgba(0,170,212,.5);color:var(--accent);font-size:10px;padding:2px 8px;border-radius:10px;font-weight:700;"><i class="fas fa-map-marker-alt" style="font-size:9px;"></i> 현재 위치</span><% } %>
                                </div>
                                <div style="font-size:11px;color:var(--muted);margin-top:2px;"><%= ic[1] %></div>
                            </div>
                            <div style="text-align:right;flex-shrink:0;">
                                <div style="font-size:12px;font-family:'Share Tech Mono',monospace;color:<%= isCurrent?"var(--accent)":isDone?"var(--success)":"var(--muted)" %>;"><%= ic[2] %></div>
                                <div style="font-size:11px;color:var(--muted);"><%= ic[3] %></div>
                            </div>
                        </div>
                    </div>
                    <% } %>
                    <!-- 도착 -->
                    <div style="display:flex;align-items:flex-start;gap:16px;">
                        <div style="width:16px;height:16px;border-radius:50%;background:var(--success);border:3px solid var(--panel);flex-shrink:0;margin-top:3px;box-shadow:0 0 10px rgba(0,229,160,.6);"></div>
                        <div><div style="font-size:11px;color:var(--success);letter-spacing:1px;margin-bottom:3px;">도착</div><div style="font-size:14px;font-weight:700;">현대자동차 울산공장</div><div style="font-size:12px;color:var(--muted);margin-top:2px;">울산광역시 북구 · 도착 예정 14:30</div></div>
                    </div>
                </div>
                <!-- 범례 -->
                <div style="display:flex;gap:16px;margin-top:20px;padding-top:16px;border-top:1px solid rgba(255,255,255,.06);flex-wrap:wrap;">
                    <div style="display:flex;align-items:center;gap:6px;font-size:11px;color:var(--muted);"><div style="width:8px;height:8px;border-radius:50%;background:var(--success);"></div>진입 / 출구 / 분기점</div>
                    <div style="display:flex;align-items:center;gap:6px;font-size:11px;color:var(--muted);"><div style="width:8px;height:8px;border-radius:50%;background:var(--warning);"></div>휴게소</div>
                    <div style="display:flex;align-items:center;gap:6px;font-size:11px;color:var(--muted);"><div style="width:8px;height:8px;border-radius:50%;background:rgba(0,170,212,.4);"></div>통과 IC</div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
// ── 탭 전환 ──
function switchTab(tab) {
    document.querySelectorAll('.map-tab').forEach(function(b, i) {
        b.classList.toggle('active', (i === 0 && tab === 'naver') || (i === 1 && tab === 'timeline'));
    });
    document.getElementById('tab-naver').classList.toggle('active',    tab === 'naver');
    document.getElementById('tab-timeline').classList.toggle('active', tab === 'timeline');
}

// ── 지도 모달 열기/닫기 ──
var mapInitialized = false;
var deliveryMap    = null;
var mapMarkers     = [];
var mapPolylines   = [];

function openMap() {
    document.getElementById('mapModal').classList.add('show');
    if (!mapInitialized) {
        mapInitialized = true;
        initDeliveryMap();
    }
}
function closeMap() {
    document.getElementById('mapModal').classList.remove('show');
}
function closeMapOutside(e) {
    if (e.target === document.getElementById('mapModal')) closeMap();
}
document.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeMap(); });

// ── 네이버 지도 초기화 및 경로 그리기 ──
function initDeliveryMap() {
    // 지도 생성 (화성~울산 중간 지점)
    deliveryMap = new naver.maps.Map('deliveryNaverMap', {
        center: new naver.maps.LatLng(36.35, 128.18),
        zoom: 8
    });

    document.getElementById('deliveryNaverMap').style.display = 'block';
    document.getElementById('mapLoadingArea').style.display  = 'none';

    // 출발지 마커
    var startPos = new naver.maps.LatLng(37.1815, 126.9988);
    var goalPos  = new naver.maps.LatLng(35.5384, 129.3571);

    // 현재 위치 (대전 IC 근방)
    var currentPos = new naver.maps.LatLng(36.3504, 127.3845);

    // 출발지 마커
    var startMarker = new naver.maps.Marker({
        position: startPos, map: deliveryMap, title: '출발지',
        icon: {
            content: '<div style="background:#00AAD4;color:#fff;padding:6px 10px;border-radius:8px;font-size:12px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(0,0,0,.3);">📦 출발 | 화성물류센터</div>',
            anchor: new naver.maps.Point(80, 30)
        }
    });

    // 도착지 마커
    var goalMarker = new naver.maps.Marker({
        position: goalPos, map: deliveryMap, title: '도착지',
        icon: {
            content: '<div style="background:#00E5A0;color:#0D1B2A;padding:6px 10px;border-radius:8px;font-size:12px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(0,0,0,.3);">🏭 도착 | 현대차 울산공장</div>',
            anchor: new naver.maps.Point(95, 30)
        }
    });

    // 현재 위치 마커 (깜빡이는 스타일)
    var currentMarker = new naver.maps.Marker({
        position: currentPos, map: deliveryMap, title: '현재 위치',
        icon: {
            content: '<div style="background:rgba(0,170,212,.9);color:#fff;padding:6px 10px;border-radius:8px;font-size:12px;font-weight:700;white-space:nowrap;box-shadow:0 0 12px rgba(0,170,212,.6);animation:pulse 1.5s infinite;">🚛 현재 | 대전 IC</div>',
            anchor: new naver.maps.Point(70, 30)
        }
    });

    mapMarkers.push(startMarker, goalMarker, currentMarker);

    // 실제 도로 경로 요청
    fetchRouteAndDraw();
}

async function fetchRouteAndDraw() {
    var statusText = document.getElementById('mapStatusText');
    statusText.textContent = '실제 도로 기준 경로를 불러오는 중...';

    try {
        var params = new URLSearchParams();
        params.append('apiAction', 'directions');
        params.append('start', '<%= startCoord %>');
        params.append('goal',  '<%= goalCoord %>');
        params.append('option', 'trafast');

        var res  = await fetch('<%= request.getRequestURI() %>', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
            body: params.toString()
        });
        var data = await res.json();

        if (!res.ok || data.error) throw new Error(data.message || '경로 조회 실패');

        var route = null;
        if      (data.route.trafast)        route = data.route.trafast[0];
        else if (data.route.traoptimal)     route = data.route.traoptimal[0];
        else if (data.route.tracomfort)     route = data.route.tracomfort[0];

        if (!route || !route.path) throw new Error('경로 데이터 없음');

        var path = route.path.map(function(p) {
            return new naver.maps.LatLng(p[1], p[0]);
        });

        // 경로 완료 구간 (파란색, 굵게)
        var donePoly = new naver.maps.Polyline({
            map: deliveryMap, path: path.slice(0, Math.floor(path.length * 0.5)),
            strokeColor: '#00AAD4', strokeWeight: 7, strokeOpacity: 0.9
        });

        // 경로 미완료 구간 (회색)
        var upcomingPoly = new naver.maps.Polyline({
            map: deliveryMap, path: path.slice(Math.floor(path.length * 0.5)),
            strokeColor: '#4A5A74', strokeWeight: 5, strokeOpacity: 0.7,
            strokeStyle: 'dash'
        });

        mapPolylines.push(donePoly, upcomingPoly);

        // 지도 범위 맞추기
        var bounds = new naver.maps.LatLngBounds();
        path.forEach(function(p) { bounds.extend(p); });
        deliveryMap.fitBounds(bounds, { top: 60, right: 60, bottom: 60, left: 60 });

        var distKm  = route.summary ? (route.summary.distance / 1000).toFixed(1) : '415';
        var durMin  = route.summary ? Math.round(route.summary.duration / 60000) : '270';
        var toll    = route.summary ? route.summary.tollFare || 0 : 0;

        statusText.innerHTML =
            '✅ 실제 도로 경로 표시 완료 &nbsp;|&nbsp; ' +
            '총 거리: <strong style="color:var(--accent)">' + distKm + ' km</strong> &nbsp;|&nbsp; ' +
            '예상 시간: <strong style="color:var(--success)">' + Math.floor(durMin/60) + '시간 ' + (durMin%60) + '분</strong>' +
            (toll > 0 ? ' &nbsp;|&nbsp; 통행료: <strong>' + toll.toLocaleString() + '원</strong>' : '');

    } catch (e) {
        console.error(e);
        // API 실패 시 직선 경로 대체 표시
        var fallbackPath = [
            new naver.maps.LatLng(37.1815, 126.9988),
            new naver.maps.LatLng(36.8000, 127.1500),
            new naver.maps.LatLng(36.3504, 127.3845),
            new naver.maps.LatLng(35.8700, 128.5500),
            new naver.maps.LatLng(35.5384, 129.3571)
        ];
        var fallbackPoly = new naver.maps.Polyline({
            map: deliveryMap, path: fallbackPath,
            strokeColor: '#00AAD4', strokeWeight: 5, strokeOpacity: 0.7, strokeStyle: 'dash'
        });
        mapPolylines.push(fallbackPoly);

        var bounds = new naver.maps.LatLngBounds();
        fallbackPath.forEach(function(p) { bounds.extend(p); });
        deliveryMap.fitBounds(bounds);

        statusText.innerHTML = '⚠️ 실제 도로 경로 조회 실패 — 참고용 경로가 표시되었습니다. (' + e.message + ')';
    }
}
</script>
</body>
</html>
