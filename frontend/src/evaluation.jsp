<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId  = (String) session.getAttribute("userId");
    String company = (String) session.getAttribute("company");
    String role    = (String) session.getAttribute("role");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    String evalId = request.getParameter("id") != null ? request.getParameter("id") : "";

    // 평가 데이터
    String vendorName   = "-";
    String totalScore   = "-";
    String evalGrade    = "-";
    String deliveryRate = "-";
    String qualityRate  = "-";
    String evalYear     = "-";
    String tier         = "-";

    // 연도별 이력
    List<String[]> historyList = new ArrayList<>();

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();

        if (!evalId.isEmpty()) {
            // 현재 평가 상세
            ps = conn.prepareStatement(
                "SELECT e.*, v.vendor_name, v.tier FROM evaluations e " +
                "LEFT JOIN vendors v ON e.vendor_id = v.vendor_id WHERE e.eval_id = ?");
            ps.setInt(1, Integer.parseInt(evalId));
            rs = ps.executeQuery();
            if (rs.next()) {
                vendorName   = rs.getString("vendor_name")!=null?rs.getString("vendor_name"):"-";
                totalScore   = rs.getString("total_score")!=null?rs.getString("total_score"):"-";
                evalGrade    = rs.getString("grade")!=null?rs.getString("grade"):"-";
                deliveryRate = rs.getString("delivery_rate")!=null?rs.getString("delivery_rate")+"%":"-";
                qualityRate  = rs.getString("quality_rate")!=null?rs.getString("quality_rate")+"%":"-";
                evalYear     = rs.getString("eval_year")!=null?rs.getString("eval_year"):"-";
                tier         = rs.getString("tier")!=null?rs.getString("tier"):"-";

                int vendorId = rs.getInt("vendor_id");
                rs.close(); ps.close();

                // 연도별 이력
                ps = conn.prepareStatement(
                    "SELECT eval_year, total_score, grade FROM evaluations " +
                    "WHERE vendor_id = ? ORDER BY eval_year DESC LIMIT 5");
                ps.setInt(1, vendorId);
                rs = ps.executeQuery();
                while (rs.next()) {
                    historyList.add(new String[]{
                        rs.getString("eval_year")!=null?rs.getString("eval_year"):"-",
                        rs.getString("total_score")!=null?rs.getString("total_score"):"-",
                        rs.getString("grade")!=null?rs.getString("grade"):"-"
                    });
                }
            }
        }
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
<title>HMC SCM | 업체 평가 상세</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing:border-box; margin:0; padding:0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#050A15; --surface:#0B1628; --sidebar:#030812; --border:rgba(0,170,212,.3); --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0; --warning:#F59E0B; --danger:#EF4444; }
  html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); }
  .wrapper { display:flex; flex-direction:column; min-height:100vh; }
  .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
  .main { padding:28px; overflow-y:auto; }
  .page-title { font-size:40px; font-weight:700; letter-spacing:1px; margin-bottom:24px; }
  .page-title span { color:var(--accent); font-weight:400; }
  .kpi-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin-bottom:30px; }
  .kpi-card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:20px; position:relative; overflow:hidden; text-align:center; box-shadow:0 4px 20px rgba(0,0,0,.4); }
  .kpi-card::before { content:''; position:absolute; top:0; left:0; right:0; height:3px; background:linear-gradient(90deg,#00AAD4,#00E5A0); }
  .kpi-val { font-size:32px; font-weight:700; margin-bottom:8px; }
  .kpi-lbl { font-size:40px; color:var(--success); font-family:'Share Tech Mono',monospace; }
  .section-title-bar { background:#0D1B2A; border:1px solid var(--border); border-radius:8px; padding:20px 28px; margin-bottom:12px; display:flex; align-items:center; box-shadow:0 2px 10px rgba(0,0,0,.3); }
  .section-title-text { font-size:32px; font-weight:700; color:var(--text); letter-spacing:1px; }
  .card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:24px; margin-bottom:40px; box-shadow:0 8px 30px rgba(0,0,0,.5); }
  .tbl { width:100%; border-collapse:collapse; }
  .tbl th { font-size:22px; color:var(--muted); font-weight:500; padding:15px 8px; border-bottom:2px solid rgba(255,255,255,.1); text-align:center; }
  .tbl td { padding:18px 8px; border-bottom:1px solid rgba(255,255,255,.05); color:#B0C4D8; text-align:center; font-size:18px; }
  .badge { display:inline-block; padding:4px 12px; border-radius:4px; font-size:18px; font-weight:600; }
  .badge.grade-a, .badge.st-best { background:rgba(0,229,160,.15); color:#00E5A0; }
  .badge.grade-b, .badge.st-good { background:rgba(0,170,212,.15); color:#00AAD4; }
  .badge.grade-c, .badge.st-fair { background:rgba(245,158,11,.15); color:#F59E0B; }
  .badge.grade-d { background:rgba(239,68,68,.15); color:#EF4444; }
  .price-cell { font-family:'Share Tech Mono',monospace; color:#00E5A0; font-weight:bold; }
  .btn-action { background:rgba(0,170,212,.1); color:var(--accent); border:1px solid var(--accent); padding:10px 25px; border-radius:5px; text-decoration:none; font-size:16px; transition:.2s; display:inline-block; }
  .btn-action:hover { background:var(--accent); color:#fff; }
  .empty-row td { color:var(--muted); font-size:14px; }
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="page-title">업체 평가 상세 <span>/ <%= vendorName %></span></div>

      <div class="kpi-grid">
        <div class="kpi-card"><div class="kpi-val">종합 평가 점수</div><div class="kpi-lbl"><%= totalScore %> 점</div></div>
        <div class="kpi-card"><div class="kpi-val">최종 등급</div>
          <div class="kpi-lbl">
            <span class="badge <%= "A".equals(evalGrade)?"grade-a":"B".equals(evalGrade)?"grade-b":"C".equals(evalGrade)?"grade-c":"grade-d" %>"><%= evalGrade %></span>
          </div>
        </div>
        <div class="kpi-card"><div class="kpi-val">납기 준수율</div><div class="kpi-lbl"><%= deliveryRate %></div></div>
        <div class="kpi-card"><div class="kpi-val">품질 합격률</div><div class="kpi-lbl"><%= qualityRate %></div></div>
      </div>

      <div class="section-title-bar"><span class="section-title-text">연도별 평가 이력</span></div>
      <div class="card" style="background:rgba(0,170,212,.15)!important;">
        <table class="tbl">
          <thead><tr><th>평가 연도</th><th>구분</th><th>최종 점수</th><th>최종 등급</th></tr></thead>
          <tbody>
            <% if (historyList.isEmpty()) { %>
            <tr class="empty-row"><td colspan="4">평가 이력이 없습니다.</td></tr>
            <% } else { for (String[] h : historyList) { %>
            <tr>
              <td><%= h[0] %>년</td>
              <td>정기 평가</td>
              <td class="price-cell"><%= h[1] %> / 100</td>
              <td>
                <span class="badge <%= "A".equals(h[2])?"grade-a":"B".equals(h[2])?"grade-b":"C".equals(h[2])?"grade-c":"grade-d" %>"><%= h[2] %></span>
              </td>
            </tr>
            <% } } %>
          </tbody>
        </table>
        <div style="text-align:right; margin-top:30px;">
          <a href="evaluationList.jsp" class="btn-action">← 평가 목록으로</a>
        </div>
      </div>
    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>
