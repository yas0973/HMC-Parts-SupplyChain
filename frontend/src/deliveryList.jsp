<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId  = (String) session.getAttribute("userId");
    String company = (String) session.getAttribute("company");
    String role    = (String) session.getAttribute("role");

    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendor = "vendor".equals(role);

    // [0]=vendor_name [1]=tier [2]=part_name [3]=part_code [4]=status_label [5]=address [6]=delivery_id
    List<String[]> deliveryList = new ArrayList<>();
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql = "SELECT d.delivery_id, v.vendor_name, v.tier, p.part_name, p.part_code, " +
                     "d.status, v.address " +
                     "FROM deliveries d " +
                     "LEFT JOIN vendors v ON d.vendor_id = v.vendor_id " +
                     "LEFT JOIN parts p ON d.part_code = p.part_code ";
        if (isVendor) sql += "JOIN users u ON u.company_id = v.vendor_id AND u.user_id = ? ";
        sql += "ORDER BY d.delivery_id DESC";

        ps = conn.prepareStatement(sql);
        if (isVendor) ps.setString(1, userId);
        rs = ps.executeQuery();
        while (rs.next()) {
            String st = rs.getString("status");
            String stLabel = "DELIVERED".equals(st)  ? "납품완료"
                           : "IN_TRANSIT".equals(st) ? "운송중"
                           : "SCHEDULED".equals(st)  ? "준비중"
                           : "지연";
            deliveryList.add(new String[]{
                rs.getString("vendor_name") != null ? rs.getString("vendor_name") : "-",  // [0]
                rs.getString("tier")        != null ? rs.getString("tier")        : "-",  // [1]
                rs.getString("part_name")   != null ? rs.getString("part_name")   : "-",  // [2]
                rs.getString("part_code")   != null ? rs.getString("part_code")   : "-",  // [3]
                stLabel,                                                                     // [4]
                rs.getString("address")     != null ? rs.getString("address")     : "-",  // [5]
                String.valueOf(rs.getInt("delivery_id"))                                    // [6]
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
<title>HMC SCM | 납품 현황 목록</title>
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
    .avatar { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 600; flex-shrink: 0; letter-spacing: 0.02em; }
    .avatar.av-done    { background: rgba(0,180,120,.12); border-color: rgba(0,180,120,.3);  color: #007a52; }
    .avatar.av-transit { background: rgba(0,170,212,.12); border-color: rgba(0,170,212,.3);  color: #007a9e; }
    .avatar.av-ready   { background: rgba(200,130,0,.10); border-color: rgba(200,130,0,.28); color: #8a5c00; }
    .avatar.av-delayed { background: rgba(220,50,50,.10); border-color: rgba(220,50,50,.28); color: #aa2020; }
    .vendor-name { color: #1e293b; font-weight: 500; text-decoration: none; font-size: 21px; }
    .vendor-name:hover { color: #005b82; text-decoration: underline; }
    .vendor-tier { display: inline-block; margin-left: 8px; font-size: 13px; color: #64748b; background: rgba(0,0,0,.05); border: 1px solid rgba(0,0,0,.1); border-radius: 4px; padding: 2px 7px; vertical-align: middle; }
    .pn-badge { display: inline-block; font-size: 19px; background: rgba(0,61,165,.07); border: 1px solid rgba(0,100,200,.18); color: #1e4a80; border-radius: 5px; padding: 4px 14px; letter-spacing: 0.3px; }
    .badge { display: inline-flex; align-items: center; justify-content: center; gap: 7px; width: 120px; padding: 6px 0; border-radius: 20px; font-size: 18px; font-weight: 600; white-space: nowrap; }
    .badge.done    { background: rgba(0,180,120,.12);  color: #007a52; border: 1px solid rgba(0,180,120,.3); }
    .badge.transit { background: rgba(0,170,212,.10);  color: #007a9e; border: 1px solid rgba(0,170,212,.28); }
    .badge.ready   { background: rgba(200,130,0,.10);  color: #8a5c00; border: 1px solid rgba(200,130,0,.28); }
    .badge.delayed { background: rgba(220,50,50,.10);  color: #aa2020; border: 1px solid rgba(220,50,50,.28); }
    .region-text { font-size: 21px; color: #475569; }
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
    <div class="page-title">납품 현황 <span>/ 공급 업체 목록</span></div>

    <div class="table-card">
        <div class="card-header">
            <span class="card-header-title">납품 현황 목록</span>
            <span class="card-header-count">총 <%= deliveryList.size() %>건</span>
        </div>
        <table class="tbl">
            <thead>
                <tr>
                    <th>공급 업체</th>
                    <th class="center">부품명</th>
                    <th class="center">부품번호 (P/N)</th>
                    <th class="center">현재 상태</th>
                    <th class="center">지역</th>
                </tr>
            </thead>
            <tbody>
            <% if (deliveryList.isEmpty()) { %>
            <tr class="empty-row"><td colspan="5">납품 이력이 없습니다.</td></tr>
            <% } else { for (String[] d : deliveryList) { %>
            <%
                String cs   = d[4];
                String ccls = "납품완료".equals(cs) ? "done"
                            : "운송중".equals(cs)   ? "transit"
                            : "준비중".equals(cs)   ? "ready"
                            : "delayed";
                String avatarCls = "납품완료".equals(cs) ? "av-done"
                                 : "운송중".equals(cs)   ? "av-transit"
                                 : "준비중".equals(cs)   ? "av-ready"
                                 : "av-delayed";
                String initials = d[0].length() >= 2 ? d[0].substring(0,2) : d[0];
            %>
            <tr onclick="location.href='delivery.jsp?deliveryId=<%= d[6] %>'">
                <td>
                    <div class="vendor-wrap">
                        <div class="avatar <%= avatarCls %>"><%= initials %></div>
                        <div>
                            <a href="delivery.jsp?deliveryId=<%= d[6] %>" class="vendor-name"><%= d[0] %></a>
                            <span class="vendor-tier"><%= d[1] %></span>
                        </div>
                    </div>
                </td>
                <td class="center"><%= d[2] %></td>
                <td class="center"><span class="pn-badge"><%= d[3] %></span></td>
                <td class="center"><span class="badge <%= ccls %>"><%= cs %></span></td>
                <td class="center"><span class="region-text"><%= d[5] %></span></td>
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
