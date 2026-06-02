<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    request.setCharacterEncoding("UTF-8");
    String userId  = (String) session.getAttribute("userId");
    String company = (String) session.getAttribute("company");
    String role    = (String) session.getAttribute("role");

    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendor = "vendor".equals(role);
    boolean isAdmin  = "admin".equals(role);
    boolean isScm    = "scm".equals(role);

    // ── 삭제 처리 ──────────────────────────────────────────────
    String delId  = request.getParameter("delete");
    String delMsg = "";
    if (delId != null && !delId.isEmpty()) {
        Connection connD = null; PreparedStatement psD = null;
        try {
            connD = DBUtil.getConnection();
            String delSql = isScm
                ? "DELETE FROM bids WHERE bid_id = ?"
                : "DELETE FROM bids WHERE bid_id = ? AND creator_id = ?";
            psD = connD.prepareStatement(delSql);
            psD.setInt(1, Integer.parseInt(delId));
            if (!isScm) psD.setString(2, userId);
            int affected = psD.executeUpdate();
            delMsg = affected > 0 ? "삭제되었습니다." : "삭제 권한이 없습니다.";
        } catch (Exception e) {
            delMsg = "삭제 오류: " + e.getMessage();
        } finally {
            DBUtil.close(connD, psD, null);
        }
    }

    // ── 발주 목록 조회 (bids + users) ─────────────────────────
    // [0]=bid_id [1]=part_name [2]=part_code [3]=part_category
    // [4]=material [5]=spec [6]=status_label [7]=status_raw
    // [8]=reg_dt [9]=creator_id [10]=creator_name [11]=vendor_name
    List<String[]> bidList = new ArrayList<>();
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql =
            "SELECT b.bid_id, b.part_name, b.part_code, b.part_category, " +
            "b.material, b.spec, b.status, " +
            "DATE_FORMAT(b.reg_dt,'%Y.%m.%d') as reg_dt, " +
            "b.creator_id, u.user_name, v.vendor_name " +
            "FROM bids b " +
            "LEFT JOIN users u ON b.creator_id = u.user_id " +
            "LEFT JOIN vendors v ON u.company_id = v.vendor_id ";
        if (isVendor) sql += "WHERE b.status = 'OPEN' ";
        sql += "ORDER BY b.reg_dt DESC";

        ps = conn.prepareStatement(sql);
        rs = ps.executeQuery();
        while (rs.next()) {
            String st = rs.getString("status");
            String stLabel = "OPEN".equals(st) ? "진행중" : "CLOSED".equals(st) ? "마감" : "검토중";
            bidList.add(new String[]{
                String.valueOf(rs.getInt("bid_id")),
                rs.getString("part_name")    != null ? rs.getString("part_name")    : "-",
                rs.getString("part_code")    != null ? rs.getString("part_code")    : "-",
                rs.getString("part_category")!= null ? rs.getString("part_category"): "-",
                rs.getString("material")     != null ? rs.getString("material")     : "-",
                rs.getString("spec")         != null ? rs.getString("spec")         : "-",
                stLabel,
                st != null ? st : "",
                rs.getString("reg_dt")       != null ? rs.getString("reg_dt")       : "-",
                rs.getString("creator_id")   != null ? rs.getString("creator_id")   : "",
                rs.getString("user_name")    != null ? rs.getString("user_name")    : "-",
                rs.getString("vendor_name")  != null ? rs.getString("vendor_name")  : "-"
            });
        }
    } catch (Exception e) {
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
    <title>HMC SCM | 발주 현황</title>
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
        .main {
            padding: 32px; overflow-y: auto;
            background:
                radial-gradient(ellipse at 20% 0%, rgba(0,61,165,0.18) 0%, transparent 60%),
                radial-gradient(ellipse at 80% 100%, rgba(0,170,212,0.10) 0%, transparent 55%),
                linear-gradient(160deg, #0a1828 0%, #0D1B2A 50%, #091522 100%);
        }
        .top-bar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }
        .page-title { font-size: 20px; font-weight: 700; letter-spacing: 0.5px; }
        .page-title span { color: var(--accent); font-weight: 400; font-size: 15px; }
        .btn-reg { display: inline-block; padding: 10px 20px; border-radius: 8px; background: rgba(0,170,212,.15); border: 1px solid rgba(0,170,212,.4); color: var(--accent); font-size: 13px; font-weight: 600; text-decoration: none; transition: all .2s; cursor: pointer; }
        .btn-reg:hover { background: rgba(0,170,212,.28); color: var(--accent); }

        .del-msg { display: flex; align-items: center; gap: 8px; padding: 11px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 13px; background: rgba(0,229,160,.08); border: 1px solid rgba(0,229,160,.2); color: var(--success); }

        .table-card { background: #0f2035; border: 1px solid rgba(0,170,212,.25); border-radius: 14px; overflow: hidden; }
        .card-header { display: flex; align-items: center; justify-content: space-between; padding: 14px 22px; background: #112240; border-bottom: 1px solid rgba(0,170,212,.25); }
        .card-header-title { font-size: 15px; font-weight: 600; color: #E8F0FE; letter-spacing: 0.4px; }
        .card-header-count { font-size: 13px; font-weight: 400; color: var(--muted); }

        .tbl { width: 100%; border-collapse: collapse; table-layout: fixed; }
        .tbl thead tr { background: #112240; border-bottom: 1px solid rgba(0,170,212,.18); }
        .tbl thead th { padding: 11px 16px; font-size: 11px; font-weight: 600; color: var(--muted); text-align: left; letter-spacing: 0.6px; text-transform: uppercase; white-space: nowrap; }
        .tbl thead th.center { text-align: center; }
        .tbl tbody tr { background: #ffffff; border-bottom: 1px solid #e8edf3; cursor: pointer; transition: background 0.15s; }
        .tbl tbody tr:last-child { border-bottom: none; }
        .tbl tbody tr:hover { background: #bfdbfe; }
        .tbl tbody td { padding: 13px 16px; font-size: 13px; color: #1e293b; vertical-align: middle; line-height: 1.5; }
        .tbl tbody td.center { text-align: center; }
        .empty-row td { text-align: center; color: var(--muted); padding: 40px; background: #0f2035 !important; font-size: 13px; cursor: default; }

        .vendor-wrap { display: flex; align-items: center; gap: 10px; }
        .avatar { width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 600; flex-shrink: 0; }
        .avatar.av-open   { background: rgba(0,180,120,.12); border: 1px solid rgba(0,180,120,.3);  color: #007a52; }
        .avatar.av-closed { background: rgba(100,116,139,.1); border: 1px solid rgba(100,116,139,.3); color: #64748b; }
        .avatar.av-review { background: rgba(200,130,0,.10);  border: 1px solid rgba(200,130,0,.28); color: #8a5c00; }

        .vendor-name { color: #1e293b; font-weight: 500; text-decoration: none; font-size: 13px; }
        .vendor-name:hover { color: #005b82; text-decoration: underline; }

        .part-name { color: #1e293b; text-decoration: none; font-size: 13px; font-weight: 500; }
        .part-name:hover { text-decoration: underline; color: #005b82; }
        .pn-badge { display: inline-block; font-size: 11px; background: rgba(0,61,165,.07); border: 1px solid rgba(0,100,200,.18); color: #1e4a80; border-radius: 5px; padding: 3px 10px; letter-spacing: 0.3px; font-family: 'Share Tech Mono', monospace; word-break: break-all; }

        .badge { display: inline-flex; align-items: center; justify-content: center; width: 72px; padding: 4px 0; border-radius: 20px; font-size: 12px; font-weight: 600; white-space: nowrap; }
        .badge.open   { background: rgba(0,180,120,.12);  color: #007a52; border: 1px solid rgba(0,180,120,.3); }
        .badge.closed { background: rgba(100,116,139,.1); color: #64748b; border: 1px solid rgba(100,116,139,.2); }
        .badge.review { background: rgba(200,130,0,.10);  color: #8a5c00; border: 1px solid rgba(200,130,0,.28); }

        .del-btn { background: rgba(239,68,68,.1); border: 1px solid rgba(239,68,68,.25); color: #EF4444; border-radius: 6px; padding: 4px 12px; font-size: 11px; font-weight: 600; cursor: pointer; transition: all .2s; font-family: 'Noto Sans KR', sans-serif; }
        .del-btn:hover { background: rgba(239,68,68,.22); }

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

    <div class="top-bar">
        <div class="page-title">발주 현황 <span>/ 발주 목록</span></div>
        <a href="bidReg.jsp" class="btn-reg">+ 발주 등록</a>
    </div>

    <% if (!delMsg.isEmpty()) { %>
    <div class="del-msg">✓ <%= delMsg %></div>
    <% } %>

    <div class="table-card">
        <div class="card-header">
            <span class="card-header-title">발주 목록</span>
            <span class="card-header-count">총 <%= bidList.size() %>건</span>
        </div>
        <table class="tbl">
            <thead>
                <tr>
                    <th>등록 업체</th>
                    <th class="center">부품명</th>
                    <th class="center">부품번호 (P/N)</th>
                    <th class="center">분류</th>
                    <th class="center">재질</th>
                    <th class="center">규격</th>
                    <th class="center">발주 상태</th>
                    <% if (!isVendor) { %><th class="center">관리</th><% } %>
                </tr>
            </thead>
            <tbody>
            <% if (bidList.isEmpty()) { %>
            <tr class="empty-row"><td colspan="<%= isVendor ? 7 : 8 %>"><%= isVendor ? "현재 진행 중인 발주가 없습니다." : "등록된 발주가 없습니다." %></td></tr>
            <% } else { for (String[] b : bidList) {
                boolean isMine  = userId.equals(b[9]);
                boolean canDel  = isScm || isMine;
                String statusCls = "진행중".equals(b[6]) ? "open"
                                 : "마감".equals(b[6])   ? "closed" : "review";
                String avatarCls = "진행중".equals(b[6]) ? "av-open"
                                 : "마감".equals(b[6])   ? "av-closed" : "av-review";
                String initials  = b[11].length() >= 2 ? b[11].substring(0,2) : b[11];
            %>
            <tr onclick="location.href='itemDetailReg.jsp?bidId=<%= b[0] %>'">
                <td>
                    <div class="vendor-wrap">
                        <div class="avatar <%= avatarCls %>"><%= initials %></div>
                        <div>
                            <a href="vendorDetail.jsp?vendorName=<%= java.net.URLEncoder.encode(b[11], "UTF-8") %>"
                               class="vendor-name" onclick="event.stopPropagation()"><%= b[11] %></a>
                            <div style="font-size:12px; color:#64748b; margin-top:2px;"><%= b[10] %></div>
                        </div>
                    </div>
                </td>
                <td class="center">
                    <a href="itemDetailReg.jsp?bidId=<%= b[0] %>" class="part-name"><%= b[1] %></a>
                </td>
                <td class="center"><span class="pn-badge"><%= b[2] %></span></td>
                <td class="center"><%= b[3] %></td>
                <td class="center"><%= b[4] %></td>
                <td class="center"><%= b[5] %></td>
                <td class="center"><span class="badge <%= statusCls %>"><%= b[6] %></span></td>
                <% if (!isVendor) { %>
                <td class="center" onclick="event.stopPropagation()">
                    <% if (canDel) { %>
                    <button class="del-btn"
                            onclick="deleteBid('<%= b[0] %>', '<%= b[1].replace("'","") %>')">삭제</button>
                    <% } else { %><span style="font-size:12px;color:#94a3b8;">-</span><% } %>
                </td>
                <% } %>
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
<script>
function deleteBid(id, title) {
    if (confirm('[' + title + ']\n이 발주를 삭제할까요?')) {
        location.href = 'bidList.jsp?delete=' + id;
    }
}
</script>
</body>
</html>
