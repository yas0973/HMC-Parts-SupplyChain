<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }
    if (!"scm".equals(role) && !"admin".equals(role)) { response.sendRedirect("dashboard.jsp"); return; }

    boolean isScm   = "scm".equals(role);
    boolean isAdmin = "admin".equals(role);

    String message = "";
    String msgType = "success";

    // ── 승인 / 거절 처리 ──────────────────────────────────────────
    String action     = request.getParameter("action");
    String targetUser = request.getParameter("targetUser");
    String targetRole = request.getParameter("targetRole");

    if (action != null && targetUser != null) {
        Connection connW = null; PreparedStatement psW = null;
        try {
            connW = DBUtil.getConnection();

            if ("approve".equals(action)) {
                if (isScm) {
                    // scm은 모든 역할 승인 가능 (approved_by_scm = 1)
                    psW = connW.prepareStatement(
                        "UPDATE users SET approved_by_scm = 1 WHERE user_id = ?");
                    psW.setString(1, targetUser);
                    psW.executeUpdate(); psW.close();
                } else if (isAdmin && "vendor".equals(targetRole)) {
                    // admin은 벤더만 승인 가능 (approved_by_admin = 1)
                    psW = connW.prepareStatement(
                        "UPDATE users SET approved_by_admin = 1 WHERE user_id = ? AND role = 'vendor'");
                    psW.setString(1, targetUser);
                    psW.executeUpdate(); psW.close();
                }

                // 벤더: scm + admin 둘 다 1이면 APPROVED
                // 원청: scm만 1이면 APPROVED
                psW = connW.prepareStatement(
                    "UPDATE users SET status = 'APPROVED' WHERE user_id = ? AND (" +
                    "  (role = 'vendor' AND approved_by_scm = 1 AND approved_by_admin = 1) OR" +
                    "  (role = 'admin'  AND approved_by_scm = 1)" +
                    ")");
                psW.setString(1, targetUser);
                psW.executeUpdate(); psW.close();

                message = "승인 처리되었습니다.";

            } else if ("reject".equals(action)) {
                // 거절: scm만 가능
                if (isScm) {
                    psW = connW.prepareStatement(
                        "UPDATE users SET status = 'REJECTED' WHERE user_id = ?");
                    psW.setString(1, targetUser);
                    psW.executeUpdate(); psW.close();
                    message = "거절 처리되었습니다.";
                } else {
                    message = "거절 권한이 없습니다."; msgType = "error";
                }
            }
        } catch (Exception e) {
            message = "처리 오류: " + e.getMessage(); msgType = "error";
        } finally {
            DBUtil.close(connW, psW, null);
        }
    }

    // ── 승인 대기 목록 조회 ────────────────────────────────────────
    // admin은 벤더만 / scm은 원청+벤더 모두
    List<String[]> pendingList = new ArrayList<>();
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql = "SELECT u.user_id, u.user_name, u.role, u.email, u.phone, u.join_date, " +
                     "u.biz_no, u.corp_no, u.tech_cert, u.status, " +
                     "u.approved_by_scm, u.approved_by_admin, " +
                     "v.vendor_name, v.address " +
                     "FROM users u LEFT JOIN vendors v ON u.company_id = v.vendor_id " +
                     "WHERE u.status IN ('PENDING','REJECTED') ";
        if (isAdmin) sql += "AND u.role = 'vendor' ";
        sql += "ORDER BY u.join_date DESC";

        ps = conn.prepareStatement(sql);
        rs = ps.executeQuery();
        while (rs.next()) {
            pendingList.add(new String[]{
                rs.getString("user_id"),
                rs.getString("user_name")      != null ? rs.getString("user_name")   : "-",
                rs.getString("role"),
                rs.getString("email")          != null ? rs.getString("email")       : "-",
                rs.getString("phone")          != null ? rs.getString("phone")       : "-",
                rs.getString("join_date")      != null ? rs.getString("join_date").substring(0,10) : "-",
                rs.getString("biz_no")         != null ? rs.getString("biz_no")      : "-",
                rs.getString("corp_no")        != null ? rs.getString("corp_no")     : "-",
                rs.getString("tech_cert")      != null ? rs.getString("tech_cert")   : "-",
                rs.getString("status"),
                rs.getString("approved_by_scm"),
                rs.getString("approved_by_admin"),
                rs.getString("vendor_name")    != null ? rs.getString("vendor_name") : "-"
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
<title>HMC SCM | 가입 승인 관리</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing:border-box; margin:0; padding:0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240; --border:rgba(0,170,212,.2); --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0; --warning:#F59E0B; --danger:#EF4444; }
  html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); }
  .wrapper { display:flex; flex-direction:column; min-height:100vh; }
  .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
  .main    { padding:32px; overflow-y:auto; }
  .page-title { font-size:24px; font-weight:700; margin-bottom:8px; }
  .page-title span { color:var(--accent); font-weight:400; font-size:18px; }
  .page-sub { font-size:13px; color:var(--muted); margin-bottom:28px; }

  .msg { display:flex; align-items:center; gap:8px; padding:12px 16px; border-radius:8px; margin-bottom:20px; font-size:13px; }
  .msg.success { background:rgba(0,229,160,.08); border:1px solid rgba(0,229,160,.2); color:var(--success); }
  .msg.error   { background:rgba(239,68,68,.08); border:1px solid rgba(239,68,68,.25); color:var(--danger); }

  /* 카드 */
  .user-card {
    background:var(--surface); border:1px solid var(--border);
    border-radius:12px; padding:20px 24px; margin-bottom:16px;
    display:flex; align-items:flex-start; justify-content:space-between; gap:20px;
  }
  .user-card.vendor-card { border-left:4px solid var(--accent); }
  .user-card.admin-card  { border-left:4px solid var(--warning); }
  .user-card.rejected    { opacity:.6; border-left-color:#64748b; }

  .user-info { flex:1; min-width:0; }
  .user-top  { display:flex; align-items:center; gap:12px; margin-bottom:10px; flex-wrap:wrap; }
  .user-name { font-size:15px; font-weight:700; color:var(--text); }
  .user-id   { font-family:'Share Tech Mono',monospace; font-size:12px; color:var(--accent); background:rgba(0,170,212,.1); padding:2px 8px; border-radius:5px; }
  .role-badge { display:inline-block; padding:2px 10px; border-radius:10px; font-size:11px; font-weight:700; }
  .rb-vendor { background:rgba(0,170,212,.15); color:var(--accent); }
  .rb-admin  { background:rgba(245,158,11,.15); color:var(--warning); }
  .rb-scm    { background:rgba(0,229,160,.15); color:var(--success); }

  .user-meta { display:grid; grid-template-columns:repeat(3,1fr); gap:8px; font-size:12px; }
  .meta-item { display:flex; flex-direction:column; gap:2px; }
  .meta-label { color:var(--muted); font-size:10px; letter-spacing:.5px; text-transform:uppercase; }
  .meta-value { color:#C8D8E8; }
  .meta-value.mono { font-family:'Share Tech Mono',monospace; color:var(--accent); font-size:11px; }

  /* 승인 진행 상태 */
  .approval-status { display:flex; gap:8px; margin-top:12px; flex-wrap:wrap; }
  .apv-chip {
    display:inline-flex; align-items:center; gap:5px;
    padding:3px 10px; border-radius:10px; font-size:11px; font-weight:600;
  }
  .apv-done { background:rgba(0,229,160,.12); color:var(--success); border:1px solid rgba(0,229,160,.25); }
  .apv-wait { background:rgba(100,116,139,.1); color:#64748b; border:1px solid rgba(100,116,139,.2); }

  /* 버튼 */
  .btn-group { display:flex; flex-direction:column; gap:8px; flex-shrink:0; }
  .btn { padding:8px 18px; border-radius:8px; font-size:12px; font-weight:600; cursor:pointer; font-family:'Noto Sans KR',sans-serif; transition:all .2s; border:none; text-align:center; min-width:90px; }
  .btn-approve { background:rgba(0,229,160,.15); border:1px solid rgba(0,229,160,.3); color:var(--success); }
  .btn-approve:hover { background:rgba(0,229,160,.28); }
  .btn-reject  { background:rgba(239,68,68,.1); border:1px solid rgba(239,68,68,.25); color:var(--danger); }
  .btn-reject:hover  { background:rgba(239,68,68,.2); }
  .btn-disabled { background:rgba(255,255,255,.03); border:1px solid rgba(255,255,255,.08); color:var(--muted); cursor:not-allowed; }

  .empty-box { text-align:center; padding:60px; color:var(--muted); font-size:14px; }
  .empty-box .icon { font-size:40px; margin-bottom:12px; }

  .section-head { font-size:12px; font-weight:600; color:var(--muted); letter-spacing:2px; text-transform:uppercase; margin-bottom:12px; padding-left:4px; }
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="page-title">가입 승인 관리 <span>/ APPROVAL</span></div>
      <div class="page-sub">
        <% if (isScm) { %>원청기업(승인: 관리자) · 벤더사(승인: 관리자 + 원청기업) 가입 요청 목록입니다.
        <% } else { %>벤더사 가입 요청 목록입니다. (원청기업 승인 권한)<% } %>
      </div>

      <% if (!message.isEmpty()) { %>
      <div class="msg <%= msgType %>">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <% if ("error".equals(msgType)) { %><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          <% } else { %><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22,4 12,14.01 9,11.01"/><% } %>
        </svg>
        <%= message %>
      </div>
      <% } %>

      <% if (pendingList.isEmpty()) { %>
      <div class="empty-box">
        <div class="icon">✓</div>
        <div>대기 중인 가입 요청이 없습니다.</div>
      </div>
      <% } else { %>

        <!-- 벤더사 목록 -->
        <% boolean hasVendor = false;
           for (String[] u : pendingList) { if ("vendor".equals(u[2])) { hasVendor = true; break; } }
           if (hasVendor) { %>
        <div class="section-head">벤더사 (scm + 원청기업 모두 승인 필요)</div>
        <% for (String[] u : pendingList) {
             if (!"vendor".equals(u[2])) continue;
             boolean scmApproved   = "1".equals(u[10]);
             boolean adminApproved = "1".equals(u[11]);
             boolean rejected      = "REJECTED".equals(u[9]);
             // 현재 로그인한 사람이 이미 승인했는지
             boolean alreadyApproved = (isScm && scmApproved) || (isAdmin && adminApproved);
             boolean canApprove = !alreadyApproved && !rejected && (isScm || isAdmin);
        %>
        <div class="user-card vendor-card <%= rejected ? "rejected" : "" %>">
          <div class="user-info">
            <div class="user-top">
              <span class="user-name"><%= u[12] %></span>
              <span class="user-id"><%= u[0] %></span>
              <span class="role-badge rb-vendor">벤더사</span>
              <% if (rejected) { %><span class="role-badge" style="background:rgba(239,68,68,.12);color:var(--danger);">거절됨</span><% } %>
            </div>
            <div class="user-meta">
              <div class="meta-item"><div class="meta-label">담당자</div><div class="meta-value"><%= u[1] %></div></div>
              <div class="meta-item"><div class="meta-label">이메일</div><div class="meta-value"><%= u[3] %></div></div>
              <div class="meta-item"><div class="meta-label">연락처</div><div class="meta-value"><%= u[4] %></div></div>
              <div class="meta-item"><div class="meta-label">사업자번호</div><div class="meta-value mono"><%= u[6] %></div></div>
              <div class="meta-item"><div class="meta-label">법인번호</div><div class="meta-value mono"><%= u[7] %></div></div>
              <div class="meta-item"><div class="meta-label">가입일</div><div class="meta-value"><%= u[5] %></div></div>
              <div class="meta-item" style="grid-column:1/-1;"><div class="meta-label">기술인증</div><div class="meta-value"><%= u[8] %></div></div>
            </div>
            <div class="approval-status">
              <span class="apv-chip <%= scmApproved ? "apv-done" : "apv-wait" %>">
                <%= scmApproved ? "✓" : "○" %> 관리자 승인
              </span>
              <span class="apv-chip <%= adminApproved ? "apv-done" : "apv-wait" %>">
                <%= adminApproved ? "✓" : "○" %> 원청기업 승인
              </span>
            </div>
          </div>
          <div class="btn-group">
            <% if (canApprove) { %>
            <form method="post" style="margin:0;">
              <input type="hidden" name="action" value="approve">
              <input type="hidden" name="targetUser" value="<%= u[0] %>">
              <input type="hidden" name="targetRole" value="vendor">
              <button type="submit" class="btn btn-approve">✓ 승인</button>
            </form>
            <% } else { %>
            <button class="btn btn-disabled"><%= alreadyApproved ? "승인완료" : "승인불가" %></button>
            <% } %>
            <% if (isScm && !rejected) { %>
            <form method="post" style="margin:0;">
              <input type="hidden" name="action" value="reject">
              <input type="hidden" name="targetUser" value="<%= u[0] %>">
              <button type="submit" class="btn btn-reject" onclick="return confirm('거절하시겠습니까?')">✕ 거절</button>
            </form>
            <% } %>
          </div>
        </div>
        <% } } %>

        <!-- 원청기업 목록 (scm만 봄) -->
        <% if (isScm) {
           boolean hasAdminUser = false;
           for (String[] u : pendingList) { if ("admin".equals(u[2])) { hasAdminUser = true; break; } }
           if (hasAdminUser) { %>
        <div class="section-head" style="margin-top:24px;">원청기업 (관리자만 승인 가능)</div>
        <% for (String[] u : pendingList) {
             if (!"admin".equals(u[2])) continue;
             boolean scmApproved = "1".equals(u[10]);
             boolean rejected    = "REJECTED".equals(u[9]);
        %>
        <div class="user-card admin-card <%= rejected ? "rejected" : "" %>">
          <div class="user-info">
            <div class="user-top">
              <span class="user-name"><%= u[1] %></span>
              <span class="user-id"><%= u[0] %></span>
              <span class="role-badge rb-admin">원청기업</span>
              <% if (rejected) { %><span class="role-badge" style="background:rgba(239,68,68,.12);color:var(--danger);">거절됨</span><% } %>
            </div>
            <div class="user-meta">
              <div class="meta-item"><div class="meta-label">이메일</div><div class="meta-value"><%= u[3] %></div></div>
              <div class="meta-item"><div class="meta-label">연락처</div><div class="meta-value"><%= u[4] %></div></div>
              <div class="meta-item"><div class="meta-label">가입일</div><div class="meta-value"><%= u[5] %></div></div>
              <div class="meta-item"><div class="meta-label">사업자번호</div><div class="meta-value mono"><%= u[6] %></div></div>
              <div class="meta-item"><div class="meta-label">법인번호</div><div class="meta-value mono"><%= u[7] %></div></div>
              <div class="meta-item" style="grid-column:1/-1;"><div class="meta-label">기술인증</div><div class="meta-value"><%= u[8] %></div></div>
            </div>
            <div class="approval-status">
              <span class="apv-chip <%= scmApproved ? "apv-done" : "apv-wait" %>">
                <%= scmApproved ? "✓" : "○" %> 관리자 승인
              </span>
            </div>
          </div>
          <div class="btn-group">
            <% if (!scmApproved && !rejected) { %>
            <form method="post" style="margin:0;">
              <input type="hidden" name="action" value="approve">
              <input type="hidden" name="targetUser" value="<%= u[0] %>">
              <input type="hidden" name="targetRole" value="admin">
              <button type="submit" class="btn btn-approve">✓ 승인</button>
            </form>
            <% } else { %>
            <button class="btn btn-disabled"><%= scmApproved ? "승인완료" : "승인불가" %></button>
            <% } %>
            <% if (!rejected) { %>
            <form method="post" style="margin:0;">
              <input type="hidden" name="action" value="reject">
              <input type="hidden" name="targetUser" value="<%= u[0] %>">
              <button type="submit" class="btn btn-reject" onclick="return confirm('거절하시겠습니까?')">✕ 거절</button>
            </form>
            <% } %>
          </div>
        </div>
        <% } } } %>
      <% } %>
    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>
