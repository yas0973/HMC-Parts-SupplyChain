<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId  = (String) session.getAttribute("userId");
    String company = (String) session.getAttribute("company");
    String role    = (String) session.getAttribute("role");

    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendor = "vendor".equals(role);

    // [0]=vendor_name [1]=tier [2]=address [3]=total_score [4]=grade [5]=delivery_rate [6]=quality_rate [7]=eval_year [8]=eval_id
    List<String[]> evalList = new ArrayList<>();
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql = "SELECT e.eval_id, v.vendor_name, v.tier, v.address, " +
                     "e.total_score, e.grade, e.delivery_rate, e.quality_rate, e.eval_year " +
                     "FROM evaluations e LEFT JOIN vendors v ON e.vendor_id = v.vendor_id ";
        if (isVendor) sql += "JOIN users u ON u.company_id = v.vendor_id AND u.user_id = ? ";
        sql += "ORDER BY e.total_score DESC";

        ps = conn.prepareStatement(sql);
        if (isVendor) ps.setString(1, userId);
        rs = ps.executeQuery();
        while (rs.next()) {
            evalList.add(new String[]{
                rs.getString("vendor_name")   != null ? rs.getString("vendor_name")   : "-",  // [0]
                rs.getString("tier")          != null ? rs.getString("tier")          : "-",  // [1]
                rs.getString("address")       != null ? rs.getString("address")       : "-",  // [2]
                rs.getString("total_score")   != null ? rs.getString("total_score")   : "0",  // [3]
                rs.getString("grade")         != null ? rs.getString("grade")         : "-",  // [4]
                rs.getString("delivery_rate") != null ? rs.getString("delivery_rate") + "%" : "-", // [5]
                rs.getString("quality_rate")  != null ? rs.getString("quality_rate")  + "%" : "-", // [6]
                rs.getString("eval_year")     != null ? rs.getString("eval_year")     : "-",  // [7]
                String.valueOf(rs.getInt("eval_id"))                                           // [8]
            });
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
<title>HMC SCM | 업체 평가 목록</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
        --primary: #003DA5; --accent: #00AAD4; --panel: #0D1B2A;
        --surface: #112240; --sidebar: #0a1520; --border: rgba(0,170,212,.2);
        --text: #E8F0FE; --muted: #7A8FA6; --success: #00E5A0;
        --warning: #F59E0B; --danger: #EF4444;
    }
    html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: var(--panel); color: var(--text); }
    .wrapper { display: flex; flex-direction: column; min-height: 100vh; }
    .layout  { flex: 1; display: grid; grid-template-columns: 220px 1fr; }
    .main    { padding: 32px; overflow-y: auto; }
    .page-title { font-size: 28px; font-weight: 700; margin-bottom: 24px; letter-spacing: 0.5px; }
    .page-title span { color: var(--accent); font-weight: 400; font-size: 21px; }
    .table-card { background: #0f2035; border: 1px solid rgba(0,170,212,.25); border-radius: 14px; overflow: hidden; }
    .card-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 24px; background: #112240; border-bottom: 1px solid rgba(0,170,212,.25); }
    .card-header-title { font-size: 21px; font-weight: 600; color: #E8F0FE; letter-spacing: 0.4px; }
    .card-header-count { font-size: 18px; font-weight: 400; color: var(--muted); }
    .tbl { width: 100%; border-collapse: collapse; }
    .tbl thead tr { background: #112240; border-bottom: 1px solid rgba(0,170,212,.18); }
    .tbl thead th { padding: 14px 24px; font-size: 20px; font-weight: 600; color: #D1D9E0; text-align: left; letter-spacing: 0.3px; }
    .tbl thead th.center { text-align: center; }
    .tbl tbody tr { background: #ffffff; border-bottom: 1px solid #e8edf3; cursor: pointer; transition: background 0.15s; }
    .tbl tbody tr:last-child { border-bottom: none; }
    .tbl tbody tr:hover { background: #bfdbfe; }
    .tbl tbody td { padding: 18px 24px; font-size: 21px; color: #1e293b; vertical-align: middle; }
    .tbl tbody td.center { text-align: center; }
    .empty-row td { text-align: center; color: var(--muted); padding: 40px; background: #0f2035 !important; font-size: 15px; }
    .vendor-wrap { display: flex; align-items: center; gap: 12px; }
    .avatar { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 600; flex-shrink: 0; }
    .avatar.av-a { background: rgba(0,180,120,.12); border: 1px solid rgba(0,180,120,.3);  color: #007a52; }
    .avatar.av-b { background: rgba(0,170,212,.12); border: 1px solid rgba(0,170,212,.3);  color: #007a9e; }
    .avatar.av-c { background: rgba(200,130,0,.10); border: 1px solid rgba(200,130,0,.28); color: #8a5c00; }
    .avatar.av-d { background: rgba(220,50,50,.10); border: 1px solid rgba(220,50,50,.28); color: #aa2020; }
    .vendor-name { color: #1e293b; font-weight: 500; text-decoration: none; font-size: 21px; }
    .vendor-name:hover { color: #005b82; text-decoration: underline; }
    .vendor-tier { display: inline-block; margin-left: 8px; font-size: 13px; color: #64748b; background: rgba(0,0,0,.05); border: 1px solid rgba(0,0,0,.1); border-radius: 4px; padding: 2px 7px; vertical-align: middle; }
    .score-cell { font-family: 'Share Tech Mono', monospace; font-size: 20px; font-weight: 700; color: #1e293b; }
    .badge { display: inline-flex; align-items: center; justify-content: center; gap: 7px; width: 80px; padding: 6px 0; border-radius: 20px; font-size: 18px; font-weight: 600; }
    .badge.grade-a { background: rgba(0,180,120,.12); color: #007a52; border: 1px solid rgba(0,180,120,.3); }
    .badge.grade-b { background: rgba(0,170,212,.10); color: #007a9e; border: 1px solid rgba(0,170,212,.28); }
    .badge.grade-c { background: rgba(200,130,0,.10); color: #8a5c00; border: 1px solid rgba(200,130,0,.28); }
    .badge.grade-d { background: rgba(220,50,50,.10); color: #aa2020; border: 1px solid rgba(220,50,50,.28); }
    .pct-cell { font-size: 18px; color: #334155; }
    .footer-bar { display: flex; justify-content: flex-end; margin-top: 20px; }
    .btn-back { display: inline-block; padding: 10px 22px; border-radius: 8px; font-size: 14px; font-weight: 500; border: 1px solid var(--accent); color: var(--accent); background: transparent; transition: background .2s; cursor: pointer; }
    .btn-back:hover { background: rgba(0,170,212,.12); }
</style>
</head>
<body>
<div class="wrapper">
<jsp:include page="/project/navbar.jsp" />
<div class="layout">
<jsp:include page="/project/sidebar.jsp" />

<div class="main">
    <div class="page-title">업체 평가 <span>/ 공급 업체 목록</span></div>

    <div class="table-card">
        <div class="card-header">
            <span class="card-header-title">업체 평가 현황 목록</span>
            <span class="card-header-count">총 <%= evalList.size() %>건</span>
        </div>
        <table class="tbl">
            <thead>
                <tr>
                    <th>공급 업체</th>
                    <th class="center">지역</th>
                    <th class="center">종합 점수</th>
                    <th class="center">최종 등급</th>
                    <th class="center">납기 준수율</th>
                    <th class="center">품질 합격률</th>
                </tr>
            </thead>
            <tbody>
            <% if (evalList.isEmpty()) { %>
            <tr class="empty-row"><td colspan="6">등록된 평가 데이터가 없습니다.</td></tr>
            <% } else { for (String[] e : evalList) { %>
            <%
                double scoreVal = 0;
                try { scoreVal = Double.parseDouble(e[3]); } catch (Exception ex) {}
                String gradeCls   = scoreVal >= 90 ? "grade-a" : scoreVal >= 80 ? "grade-b" : scoreVal >= 70 ? "grade-c" : "grade-d";
                String avatarCls  = scoreVal >= 90 ? "av-a"    : scoreVal >= 80 ? "av-b"    : scoreVal >= 70 ? "av-c"    : "av-d";
                String gradeLabel = e[4]; // DB에서 직접 가져온 등급 사용
                String initials   = e[0].length() >= 2 ? e[0].substring(0,2) : e[0];
                String scoreDisp  = scoreVal == (long)scoreVal
                                    ? String.valueOf((long)scoreVal)
                                    : String.format("%.1f", scoreVal);
            %>
            <tr onclick="location.href='evaluation.jsp?evalId=<%= e[8] %>'">
                <td>
                    <div class="vendor-wrap">
                        <div class="avatar <%= avatarCls %>"><%= initials %></div>
                        <div>
                            <a href="evaluation.jsp?evalId=<%= e[8] %>" class="vendor-name"><%= e[0] %></a>
                            <span class="vendor-tier"><%= e[1] %></span>
                        </div>
                    </div>
                </td>
                <td class="center"><%= e[2] %></td>
                <td class="center"><span class="score-cell"><%= scoreDisp %>점</span></td>
                <td class="center">
                    <span class="badge <%= gradeCls %>"><%= gradeLabel %></span>
                </td>
                <td class="center"><span class="pct-cell"><%= e[5] %></span></td>
                <td class="center"><span class="pct-cell"><%= e[6] %></span></td>
            </tr>
            <% } } %>
            </tbody>
        </table>
    </div>

    <div class="footer-bar">
        <button class="btn-back" onclick="history.back()">대시보드로 돌아가기</button>
    </div>
</div>
</div>
<jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>
