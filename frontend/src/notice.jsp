<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isAdmin   = "admin".equals(role) || "scm".equals(role);
    boolean isScm     = "scm".equals(role);
    String  highlight = request.getParameter("highlight") != null ? request.getParameter("highlight") : "";

    // ── 공지 등록 처리 (admin/scm만) ──
    String msg = "", msgType = "";
    if ("POST".equals(request.getMethod()) && isAdmin) {
        String nType    = request.getParameter("nType")    != null ? request.getParameter("nType")    : "notice";
        String nTitle   = request.getParameter("nTitle")   != null ? request.getParameter("nTitle").trim()   : "";
        String nContent = request.getParameter("nContent") != null ? request.getParameter("nContent").trim() : "";
        String nTarget  = request.getParameter("nTarget")  != null ? request.getParameter("nTarget")  : "all";

        if (!nTitle.isEmpty()) {
            Connection connW = null; PreparedStatement psW = null;
            try {
                connW = DBUtil.getConnection();
                psW = connW.prepareStatement(
                    "INSERT INTO notices (type, title, content, target_role, created_by) VALUES (?,?,?,?,?)");
                psW.setString(1, nType);
                psW.setString(2, nTitle);
                psW.setString(3, nContent);
                psW.setString(4, nTarget);
                psW.setString(5, userId);
                psW.executeUpdate();
                msg = "공지가 등록되었습니다!"; msgType = "success";
            } catch (Exception e) {
                msg = "등록 오류: " + e.getMessage(); msgType = "error";
            } finally {
                DBUtil.close(connW, psW, null);
            }
        }
    }

    // ── 공지 삭제 (scm=전체, admin=본인만) ──
    String delId = request.getParameter("delete");
    if (delId != null && isAdmin) {
        Connection connD = null; PreparedStatement psD = null;
        try {
            connD = DBUtil.getConnection();
            if (isScm) {
                psD = connD.prepareStatement("DELETE FROM notices WHERE notice_id=?");
                psD.setInt(1, Integer.parseInt(delId));
            } else {
                psD = connD.prepareStatement("DELETE FROM notices WHERE notice_id=? AND created_by=?");
                psD.setInt(1, Integer.parseInt(delId));
                psD.setString(2, userId);
            }
            int affected = psD.executeUpdate();
            msg     = affected > 0 ? "삭제되었습니다." : "본인이 등록한 공지만 삭제할 수 있습니다.";
            msgType = affected > 0 ? "success" : "error";
        } catch (Exception e) {
            msg = "삭제 오류"; msgType = "error";
        } finally {
            DBUtil.close(connD, psD, null);
        }
    }

    // ── 공지 목록 조회 (공용 - 개인 읽음 상태 없이 모두 표시) ──
    List<String[]> noticeList = new ArrayList<>();
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql =
            "SELECT n.notice_id, n.type, n.title, n.content, n.target_role, " +
            "DATE_FORMAT(n.created_dt,'%Y.%m.%d %H:%i') as fmt_dt, " +
            "u.user_name as creator, n.created_by " +
            "FROM notices n " +
            "LEFT JOIN users u ON n.created_by = u.user_id " +
            "WHERE n.target_role = 'all' OR n.target_role = ? " +
            "ORDER BY n.created_dt DESC";
        ps = conn.prepareStatement(sql);
        ps.setString(1, role);
        rs = ps.executeQuery();
        while (rs.next()) {
            noticeList.add(new String[]{
                String.valueOf(rs.getInt("notice_id")),  // [0]
                rs.getString("type"),                     // [1]
                rs.getString("title"),                    // [2]
                rs.getString("content") != null ? rs.getString("content") : "", // [3]
                rs.getString("target_role"),              // [4]
                rs.getString("fmt_dt"),                   // [5]
                rs.getString("creator") != null ? rs.getString("creator") : "-", // [6]
                rs.getString("created_by") != null ? rs.getString("created_by") : "" // [7]
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
<title>HMC SCM | 공지 / 알림</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing:border-box; margin:0; padding:0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240; --sidebar:#0a1520; --border:rgba(0,170,212,.2); --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0; --warning:#F59E0B; --danger:#EF4444; }
  html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); }
  .wrapper { display:flex; flex-direction:column; min-height:100vh; }
  .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
  .main    { padding:32px; overflow-y:auto; }
  .page-title { font-size:24px; font-weight:700; margin-bottom:24px; }
  .page-title span { color:var(--accent); font-weight:400; font-size:18px; }
  .msg { display:flex; align-items:center; gap:8px; padding:12px 16px; border-radius:8px; margin-bottom:20px; font-size:14px; }
  .msg.success { background:rgba(0,229,160,.08); border:1px solid rgba(0,229,160,.2); color:var(--success); }
  .msg.error   { background:rgba(239,68,68,.08); border:1px solid rgba(239,68,68,.25); color:var(--danger); }

  /* 등록 폼 */
  .write-card { background:var(--surface); border:1px solid var(--border); border-radius:12px; padding:22px; margin-bottom:24px; }
  .write-title { font-size:13px; font-weight:600; color:var(--accent); letter-spacing:1.5px; text-transform:uppercase; border-left:3px solid var(--accent); padding-left:10px; margin-bottom:16px; }
  .write-grid { display:grid; grid-template-columns:120px 120px 1fr; gap:10px; margin-bottom:10px; }
  select, input[type="text"], textarea { background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1); border-radius:8px; padding:9px 12px; color:var(--text); font-family:'Noto Sans KR',sans-serif; font-size:13px; outline:none; transition:border-color .2s; width:100%; }
  select:focus, input:focus, textarea:focus { border-color:var(--accent); background:rgba(0,170,212,.05); }
  select option { background:#112240; }
  textarea { resize:vertical; min-height:70px; }
  .btn-write { background:rgba(0,170,212,.15); border:1px solid rgba(0,170,212,.4); color:var(--accent); border-radius:8px; padding:9px 20px; font-size:13px; font-weight:500; cursor:pointer; font-family:'Noto Sans KR',sans-serif; transition:all .2s; }
  .btn-write:hover { background:rgba(0,170,212,.25); }

  /* 필터 탭 */
  .filter-tabs { display:flex; gap:6px; margin-bottom:16px; }
  .ftab { padding:6px 16px; border-radius:20px; font-size:12px; font-weight:500; cursor:pointer; border:1px solid rgba(255,255,255,.1); color:var(--muted); background:rgba(255,255,255,.03); transition:all .2s; }
  .ftab:hover, .ftab.active { border-color:var(--accent); background:rgba(0,170,212,.1); color:var(--accent); }

  /* 공지 목록 */
  .notice-list { display:flex; flex-direction:column; gap:10px; }
  .notice-item { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:16px 20px; display:flex; gap:14px; align-items:flex-start; transition:border-color .2s, background .2s; }
  .notice-item:hover { border-color:rgba(0,170,212,.4); background:rgba(0,170,212,.03); }
  .notice-item.highlight { border-color:var(--accent) !important; background:rgba(0,170,212,.08) !important; animation:highlightPulse 1.5s ease; }
  @keyframes highlightPulse { 0%{box-shadow:0 0 0 0 rgba(0,170,212,.5)} 50%{box-shadow:0 0 0 8px rgba(0,170,212,0)} 100%{box-shadow:0 0 0 0 rgba(0,170,212,0)} }
  .notice-icon { width:36px; height:36px; border-radius:9px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
  .icon-notice  { background:rgba(0,170,212,.15); color:var(--accent); }
  .icon-warn    { background:rgba(245,158,11,.15); color:var(--warning); }
  .icon-success { background:rgba(0,229,160,.15); color:var(--success); }
  .notice-body { flex:1; min-width:0; }
  .notice-header { display:flex; align-items:center; gap:10px; margin-bottom:5px; flex-wrap:wrap; }
  .notice-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:10px; font-weight:700; }
  .badge-notice  { background:rgba(0,170,212,.15); color:var(--accent); }
  .badge-warn    { background:rgba(245,158,11,.15); color:var(--warning); }
  .badge-success { background:rgba(0,229,160,.15); color:var(--success); }
  .notice-title   { font-size:14px; font-weight:600; color:var(--text); }
  .notice-content { font-size:13px; color:var(--muted); margin-top:4px; line-height:1.6; }
  .notice-meta    { font-size:11px; color:var(--muted); margin-top:6px; display:flex; gap:12px; }
  .notice-actions { display:flex; align-items:center; gap:8px; flex-shrink:0; }
  .btn-del { background:rgba(239,68,68,.1); border:1px solid rgba(239,68,68,.3); color:var(--danger); border-radius:6px; padding:4px 10px; font-size:11px; cursor:pointer; text-decoration:none; transition:all .2s; }
  .btn-del:hover { background:rgba(239,68,68,.2); }
  .target-badge { display:inline-block; padding:1px 7px; border-radius:10px; font-size:10px; background:rgba(255,255,255,.06); color:var(--muted); }
  .empty-box { text-align:center; padding:60px; color:var(--muted); font-size:14px; }
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="page-title">공지 / 알림 <span>/ NOTICE</span></div>

      <% if (!msg.isEmpty()) { %>
      <div class="msg <%= msgType %>"><%= msg %></div>
      <% } %>

      <!-- 공지 등록 폼 (admin/scm만) -->
      <% if (isAdmin) { %>
      <div class="write-card">
        <div class="write-title">공지 등록</div>
        <form method="post" action="notice.jsp">
          <div class="write-grid">
            <select name="nType">
              <option value="notice">📢 공지</option>
              <option value="warn">⚠️ 경고</option>
              <option value="success">✅ 안내</option>
            </select>
            <select name="nTarget">
              <option value="all">전체 대상</option>
              <option value="admin">원청기업</option>
              <option value="vendor">벤더사</option>
              <option value="scm">SCM</option>
            </select>
            <input type="text" name="nTitle" placeholder="공지 제목을 입력하세요" required>
          </div>
          <textarea name="nContent" placeholder="공지 내용 (선택)"></textarea>
          <div style="text-align:right; margin-top:10px;">
            <button type="submit" class="btn-write">+ 공지 등록</button>
          </div>
        </form>
      </div>
      <% } %>

      <!-- 필터 탭 -->
      <div class="filter-tabs">
        <span class="ftab active" onclick="filterNotice('all', this)">전체</span>
        <span class="ftab" onclick="filterNotice('notice', this)">공지</span>
        <span class="ftab" onclick="filterNotice('warn', this)">경고</span>
        <span class="ftab" onclick="filterNotice('success', this)">안내</span>
      </div>

      <!-- 공지 목록 -->
      <div class="notice-list" id="noticeList">
        <% if (noticeList.isEmpty()) { %>
        <div class="empty-box">등록된 공지가 없습니다.</div>
        <% } else {
            for (String[] n : noticeList) {
                String  nId      = n[0];
                String  nType    = n[1];
                String  nTitle   = n[2];
                String  nContent = n[3];
                String  nTarget  = n[4];
                String  nDate    = n[5];
                String  creator  = n[6];
                String  createdBy= n[7];
                boolean isMine   = userId.equals(createdBy);
                String  iconCls  = "warn".equals(nType) ? "icon-warn" : "success".equals(nType) ? "icon-success" : "icon-notice";
                String  badgeCls = "warn".equals(nType) ? "badge-warn" : "success".equals(nType) ? "badge-success" : "badge-notice";
                String  badgeTxt = "warn".equals(nType) ? "경고"       : "success".equals(nType) ? "안내"          : "공지";
                String  iconSvg  = "warn".equals(nType)
                    ? "<svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'/><line x1='12' y1='9' x2='12' y2='13'/><line x1='12' y1='17' x2='12.01' y2='17'/></svg>"
                    : "success".equals(nType)
                    ? "<svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M22 11.08V12a10 10 0 1 1-5.93-9.14'/><polyline points='22,4 12,14.01 9,11.01'/></svg>"
                    : "<svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><line x1='12' y1='8' x2='12' y2='12'/><line x1='12' y1='16' x2='12.01' y2='16'/></svg>";
        %>
        <div class="notice-item"
             id="notice-<%= nId %>"
             data-type="<%= nType %>">
          <div class="notice-icon <%= iconCls %>"><%=iconSvg%></div>
          <div class="notice-body">
            <div class="notice-header">
              <span class="notice-badge <%= badgeCls %>"><%= badgeTxt %></span>
              <% if (!"all".equals(nTarget)) { %>
              <span class="target-badge">
                <%= "admin".equals(nTarget) ? "원청기업" : "vendor".equals(nTarget) ? "벤더사" : "SCM" %> 전용
              </span>
              <% } %>
            </div>
            <div class="notice-title"><%= nTitle %></div>
            <% if (!nContent.isEmpty()) { %>
            <div class="notice-content"><%= nContent %></div>
            <% } %>
            <div class="notice-meta">
              <span><%= nDate %></span>
              <span>작성자: <%= creator %></span>
            </div>
          </div>
          <% if (isAdmin && (isMine || isScm)) { %>
          <div class="notice-actions">
            <a href="notice.jsp?delete=<%= nId %>" class="btn-del"
               onclick="return confirm('삭제할까요?')">삭제</a>
          </div>
          <% } %>
        </div>
        <% } } %>
      </div>
    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>

<script>
function filterNotice(type, el) {
  document.querySelectorAll('.ftab').forEach(function(t){ t.classList.remove('active'); });
  el.classList.add('active');
  document.querySelectorAll('.notice-item').forEach(function(item){
    item.style.display = (type === 'all' || item.dataset.type === type) ? 'flex' : 'none';
  });
}

// 네비바에서 클릭해서 온 경우 → 해당 공지 하이라이트 + 스크롤
window.onload = function() {
  var highlightId = '<%= highlight %>';
  if (highlightId) {
    var target = document.getElementById('notice-' + highlightId);
    if (target) {
      target.classList.add('highlight');
      setTimeout(function() {
        target.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 300);
    }
  }
};
</script>
</body>
</html>
