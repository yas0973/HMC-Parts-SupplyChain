<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    if ("logout".equals(request.getParameter("action"))) {
        session.invalidate(); response.sendRedirect("login.jsp"); return;
    }
    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    String roleLabel = (String) session.getAttribute("roleLabel");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isAdmin  = "admin".equals(role);
    boolean isScm    = "scm".equals(role);
    boolean isVendor = "vendor".equals(role);
    boolean canDelete        = isScm;
    boolean canSeeAllPrices  = !isVendor;
    String initials = (company != null && company.length() >= 2) ? company.substring(0,2) : company;

    // ── DB 조회 ──
    List<String[]> bidList      = new ArrayList<>();
    List<String[]> deliveryList = new ArrayList<>();
    List<String[]> evalList     = new ArrayList<>();
    int kpiBids=0, kpiVendors=0, kpiPending=0;
    double kpiDeliveryRate = 0;

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();

        // KPI: 진행중 발주 수
        ps = conn.prepareStatement("SELECT COUNT(*) FROM bids WHERE status='OPEN'");
        rs = ps.executeQuery(); if(rs.next()) kpiBids = rs.getInt(1); rs.close(); ps.close();

        // KPI: 연결 벤더 수 (vendor 역할 유저가 소속된 업체만)
        ps = conn.prepareStatement(
            "SELECT COUNT(DISTINCT v.vendor_id) FROM vendors v " +
            "JOIN users u ON v.vendor_id = u.company_id WHERE u.role = 'vendor'");
        rs = ps.executeQuery(); if(rs.next()) kpiVendors = rs.getInt(1); rs.close(); ps.close();

        // KPI: 검토대기 입찰 수
        ps = conn.prepareStatement("SELECT COUNT(*) FROM bid_applications WHERE status='PENDING'");
        rs = ps.executeQuery(); if(rs.next()) kpiPending = rs.getInt(1); rs.close(); ps.close();

        // KPI: 납기 준수율 (delivered 건수 / 전체)
        ps = conn.prepareStatement("SELECT COUNT(*) FROM deliveries");
        rs = ps.executeQuery(); rs.next(); int totalD = rs.getInt(1); rs.close(); ps.close();
        if (totalD > 0) {
            ps = conn.prepareStatement("SELECT COUNT(*) FROM deliveries WHERE status='DELIVERED'");
            rs = ps.executeQuery(); rs.next(); int doneD = rs.getInt(1); rs.close(); ps.close();
            kpiDeliveryRate = Math.round((double)doneD/totalD*1000)/10.0;
        }

        // 발주 현황 (최근 5건)
        String bidSql = "SELECT b.bid_id, b.title, v.vendor_name, b.status, DATE(b.reg_dt) as reg_dt " +
                        "FROM bids b LEFT JOIN users u ON b.creator_id=u.user_id " +
                        "LEFT JOIN vendors v ON u.company_id=v.vendor_id " +
                        "ORDER BY b.reg_dt DESC LIMIT 5";
        ps = conn.prepareStatement(bidSql); rs = ps.executeQuery();
        while(rs.next()) {
            String st = rs.getString("status");
            String stLabel = "OPEN".equals(st)?"진행중":"CLOSED".equals(st)?"완료":"검토중";
            bidList.add(new String[]{ String.valueOf(rs.getInt("bid_id")), rs.getString("title"),
                rs.getString("vendor_name")!=null?rs.getString("vendor_name"):"-", stLabel,
                rs.getString("reg_dt") });
        } rs.close(); ps.close();

        // 납품 현황 (최근 5건)
        String dlSql = "SELECT d.delivery_id, v.vendor_name, p.part_name, d.status, DATE(d.reg_dt) as reg_dt " +
                       "FROM deliveries d " +
                       "LEFT JOIN vendors v ON d.vendor_id=v.vendor_id " +
                       "LEFT JOIN parts p ON d.part_code=p.part_code " +
                       "ORDER BY d.reg_dt DESC LIMIT 5";
        ps = conn.prepareStatement(dlSql); rs = ps.executeQuery();
        while(rs.next()) {
            String st = rs.getString("status");
            String stLabel = "DELIVERED".equals(st)?"납품완료":"IN_TRANSIT".equals(st)?"운송중":"SCHEDULED".equals(st)?"준비중":"지연";
            deliveryList.add(new String[]{ String.valueOf(rs.getInt("delivery_id")),
                rs.getString("vendor_name")!=null?rs.getString("vendor_name"):"-",
                rs.getString("part_name")!=null?rs.getString("part_name"):"-",
                stLabel, rs.getString("reg_dt") });
        } rs.close(); ps.close();

        // 업체 평가 현황
        String evSql = "SELECT e.eval_id, v.vendor_name, v.tier, v.address, " +
                       "e.total_score, e.grade, e.delivery_rate, e.eval_year " +
                       "FROM evaluations e LEFT JOIN vendors v ON e.vendor_id=v.vendor_id " +
                       "ORDER BY e.total_score DESC LIMIT 5";
        ps = conn.prepareStatement(evSql); rs = ps.executeQuery();
        while(rs.next()) {
            evalList.add(new String[]{
                String.valueOf(rs.getInt("eval_id")),
                rs.getString("vendor_name")!=null?rs.getString("vendor_name"):"-",
                rs.getString("tier")!=null?rs.getString("tier"):"-",
                rs.getString("address")!=null?rs.getString("address"):"-",
                rs.getString("total_score"),
                rs.getString("grade"),
                rs.getString("delivery_rate")!=null ? rs.getString("delivery_rate")+"%" : "-",
                rs.getString("eval_year")
            });
        } rs.close(); ps.close();

    } catch (SQLException e) {
        e.printStackTrace();
    } finally {
        DBUtil.close(conn, ps, rs);
    }
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 대시보드</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240; --sidebar:#0a1520; --border:rgba(0,170,212,.2); --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0; --warning:#F59E0B; --danger:#EF4444; }
  html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); }
  .wrapper { display:flex; flex-direction:column; min-height:100vh; }
  .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
  .main { padding:28px; overflow-y:auto; }
  .topbar { display:flex; justify-content:space-between; align-items:center; margin-bottom:24px; }
  .page-title { font-size:40px; font-weight:700; letter-spacing:1px; }
  .page-title span { color:var(--accent); font-weight:400; }
  .scm-alert { background:rgba(239,68,68,.08); border:1px solid rgba(239,68,68,.25); border-radius:8px; padding:10px 16px; margin-bottom:16px; font-size:12px; color:#FCA5A5; display:flex; align-items:center; gap:8px; }
  .kpi-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin-bottom:20px; }
  .kpi-card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:16px; position:relative; overflow:hidden; }
  .kpi-card::before { content:''; position:absolute; top:0; left:0; right:0; height:2px; }
  .kpi-card.c-blue::before   { background:linear-gradient(90deg,#003DA5,#00AAD4); }
  .kpi-card.c-green::before  { background:linear-gradient(90deg,#00AAD4,#00E5A0); }
  .kpi-card.c-amber::before  { background:linear-gradient(90deg,#F59E0B,#EF4444); }
  .kpi-card.c-purple::before { background:linear-gradient(90deg,#7C3AED,#00AAD4); }
  .kpi-val { font-size:30px; font-weight:700; font-family:'Share Tech Mono',monospace; color:var(--muted); }
  .kpi-lbl { font-size:33px; color:#fff; margin-top:4px; }
  .kpi-sub { font-size:15px; margin-top:6px; color:var(--muted); }
  .kpi-sub.up { color:var(--success); } .kpi-sub.down { color:var(--danger); }
  .grid2 { display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-bottom:16px; }
  .card { background:#fff; border:1px solid #e2e8f0; border-radius:10px; padding:0; overflow:hidden; box-shadow:0 2px 12px rgba(0,0,0,.08); }
  .card-title { font-size:19px; font-weight:600; color:#94a3b8; letter-spacing:0.8px; background:#112240; padding:13px 20px; border-left:4px solid #00AAD4; }
  .card-body { padding:16px; background:#fff; }
  .tbl { width:100%; border-collapse:collapse; }
  .tbl th { font-size:18px; color:#64748b; font-weight:600; padding:10px 14px; border-bottom:2px solid #e2e8f0; text-align:left; background:#f8fafc; }
  .tbl td { padding:12px 14px; border-bottom:1px solid #f1f5f9; color:#334155; font-size:19px; }
  .tbl tbody tr { cursor:pointer; transition:background 0.15s; }
  .tbl tbody tr:hover { background:#bfdbfe; }
  .badge { display:inline-block; width:72px; text-align:center; padding:4px 0; border-radius:20px; font-size:16px; font-weight:700; }
  .badge.open    { background:rgba(0,229,160,.15); color:#00875A; border:1px solid rgba(0,229,160,.3); }
  .badge.review  { background:rgba(245,158,11,.15); color:#B45309; border:1px solid rgba(245,158,11,.3); }
  .badge.done    { background:rgba(0,170,212,.15); color:#0077A3; border:1px solid rgba(0,170,212,.3); }
  .badge.delay   { background:rgba(239,68,68,.15); color:#B91C1C; border:1px solid rgba(239,68,68,.3); }
  .badge.grade-a { background:rgba(0,229,160,.15); color:#00875A; border:1px solid rgba(0,229,160,.3); }
  .badge.grade-b { background:rgba(0,170,212,.15); color:#0077A3; border:1px solid rgba(0,170,212,.3); }
  .badge.grade-c { background:rgba(245,158,11,.15); color:#B45309; border:1px solid rgba(245,158,11,.3); }
  .btn-del { background:rgba(239,68,68,.1); border:1px solid rgba(239,68,68,.3); color:#B91C1C; border-radius:6px; padding:3px 10px; font-size:11px; cursor:pointer; }
  .price-cell { font-family:'Share Tech Mono',monospace; color:#0077A3; font-weight:600; }
  .unit { font-size:13px; color:#94a3b8; font-weight:400; margin-left:4px; }
  .empty-row td { text-align:center; color:var(--muted); font-size:14px; padding:20px; }
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="topbar">
        <div class="page-title">대시보드 <span>/ 현황 요약</span></div>
      </div>

      <% if (isScm) { %>
      <div class="scm-alert">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        SCM 관리자 권한으로 접속 중입니다.
      </div>
      <% } %>

      <!-- KPI -->
      <div class="kpi-grid">
        <div class="kpi-card c-blue">
          <div class="kpi-val">진행중 발주</div>
          <div class="kpi-lbl"><%= kpiBids %> 건</div>
        </div>
        <div class="kpi-card c-green">
          <div class="kpi-val">연결 벤더</div>
          <div class="kpi-lbl"><%= kpiVendors %> 개사</div>
        </div>
        <div class="kpi-card c-amber">
          <div class="kpi-val">납기 준수율</div>
          <div class="kpi-lbl"><%= kpiDeliveryRate %>%</div>
        </div>
        <div class="kpi-card c-purple">
          <div class="kpi-val">검토대기 입찰</div>
          <div class="kpi-lbl"><%= kpiPending %> 건</div>
        </div>
      </div>

      <!-- 발주 + 납품 -->
      <div class="grid2">
        <div class="card">
          <div class="card-title">최근 발주 현황</div>
          <div class="card-body"><table class="tbl">
            <tr><th>발주명</th><th>담당 업체</th><th style="text-align:center">상태</th><% if(canDelete){ %><th>관리</th><% } %></tr>
            <% if (bidList.isEmpty()) { %><tr class="empty-row"><td colspan="4">등록된 발주가 없습니다.</td></tr>
            <% } else { for (String[] bid : bidList) { %>
            <tr onclick="location.href='itemDetailReg.jsp?id=<%= bid[0] %>'">
              <td><%= bid[1] %></td>
              <td><%= bid[2] %></td>
              <td style="text-align:center">
                <% if ("진행중".equals(bid[3])) { %><span class="badge open">진행중</span>
                <% } else if ("검토중".equals(bid[3])) { %><span class="badge review">검토중</span>
                <% } else { %><span class="badge done">완료</span><% } %>
              </td>
              <% if (canDelete) { %><td><button class="btn-del" onclick="event.stopPropagation()">삭제</button></td><% } %>
            </tr>
            <% } } %>
          </table></div>
        </div>

        <div class="card">
          <div class="card-title">납품 현황</div>
          <div class="card-body"><table class="tbl">
            <tr><th>업체명</th><th>품목</th><th style="text-align:center">상태</th><% if(canDelete){ %><th>관리</th><% } %></tr>
            <% if (deliveryList.isEmpty()) { %><tr class="empty-row"><td colspan="4">등록된 납품 현황이 없습니다.</td></tr>
            <% } else { for (String[] d : deliveryList) { %>
            <tr onclick="location.href='delivery.jsp?id=<%= d[0] %>'">
              <td><%= d[1] %></td><td><%= d[2] %></td>
              <td style="text-align:center">
                <% if ("납품완료".equals(d[3])) { %><span class="badge done">납품완료</span>
                <% } else if ("운송중".equals(d[3])) { %><span class="badge open">운송중</span>
                <% } else if ("준비중".equals(d[3])) { %><span class="badge review">준비중</span>
                <% } else { %><span class="badge delay">지연</span><% } %>
              </td>
              <% if (canDelete) { %><td><button class="btn-del" onclick="event.stopPropagation()">삭제</button></td><% } %>
            </tr>
            <% } } %>
          </table></div>
        </div>
      </div>

      <!-- 업체 평가 -->
      <div class="card">
        <div class="card-title">업체 평가 현황</div>
        <div class="card-body"><table class="tbl">
          <tr>
            <th>업체명</th><th>구분</th><th>납기준수</th><th style="text-align:center">등급</th>
            <% if (canSeeAllPrices) { %><th>종합점수</th><% } %>
            <% if (canDelete) { %><th>관리</th><% } %>
          </tr>
          <% if (evalList.isEmpty()) { %><tr class="empty-row"><td colspan="6">등록된 평가 데이터가 없습니다.</td></tr>
          <% } else { for (String[] ev : evalList) { %>
          <tr onclick="location.href='evaluation.jsp?id=<%= ev[0] %>'">
            <td><%= ev[1] %></td>
            <td><%= ev[2] %></td>
            <td><%= ev[6] %></td>
            <td style="text-align:center">
              <% if ("A".equals(ev[5])) { %><span class="badge grade-a">A</span>
              <% } else if ("B".equals(ev[5])) { %><span class="badge grade-b">B</span>
              <% } else { %><span class="badge grade-c">C</span><% } %>
            </td>
            <% if (canSeeAllPrices) { %>
            <td class="price-cell"><%= ev[4] %>점</td>
            <% } %>
            <% if (canDelete) { %><td><button class="btn-del" onclick="event.stopPropagation()">삭제</button></td><% } %>
          </tr>
          <% } } %>
        </table></div>
      </div>

    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>
