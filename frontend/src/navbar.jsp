<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String company   = (String) session.getAttribute("company");
    String roleLabel = (String) session.getAttribute("roleLabel");
    String userId    = (String) session.getAttribute("userId");
    String role      = (String) session.getAttribute("role");
    if (company == null) company = "";
    if (userId  == null) userId  = "";
    if (role    == null) role    = "";
    String initials = company.length() >= 2 ? company.substring(0,2) : company;

    // ── DB에서 개인별 안읽은 알림 조회 ──
    // notice_reads에 내 기록이 없는 것 = 아직 안읽은 것
    StringBuilder notifJson = new StringBuilder("[");
    int unreadCount = 0;
    boolean first = true;

    // 1) 세션 partList 기반 알림 (부품 등록 대기)
    List<?> rawList = (List<?>) session.getAttribute("partList");
    int partCount = (rawList != null) ? rawList.size() : 0;
    if (partCount > 0) {
        notifJson.append("{\"id\":0,\"type\":\"success\",\"unread\":true,")
            .append("\"msg\":\"[부품 등록] 현재 ").append(partCount)
            .append("개 부품이 등록 대기 중입니다. 최종 등록을 완료해주세요.\",")
            .append("\"time\":\"세션 기준\"}");
        unreadCount++;
        first = false;
    }

    // 2) DB notices - 내가 안읽은 것만 (notice_reads에 내 기록 없는 것)
    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        String sql =
            "SELECT n.notice_id, n.type, n.title, " +
            "DATE_FORMAT(n.created_dt, '%Y.%m.%d') as fmt_dt " +
            "FROM notices n " +
            "WHERE (n.target_role = 'all' OR n.target_role = ?) " +
            "AND n.notice_id NOT IN (" +
            "  SELECT nr.notice_id FROM notice_reads nr WHERE nr.user_id = ?" +
            ") " +
            "ORDER BY n.created_dt DESC LIMIT 10";
        ps = conn.prepareStatement(sql);
        ps.setString(1, role);
        ps.setString(2, userId);
        rs = ps.executeQuery();

        while (rs.next()) {
            int    nId    = rs.getInt("notice_id");
            String nType  = rs.getString("type");
            String nTitle = rs.getString("title").replace("\"", "\\\"").replace("\n", " ");
            String nTime  = rs.getString("fmt_dt");

            if (!first) notifJson.append(",");
            notifJson.append("{")
                .append("\"id\":").append(nId).append(",")
                .append("\"type\":\"").append(nType).append("\",")
                .append("\"unread\":true,")
                .append("\"msg\":\"").append(nTitle).append("\",")
                .append("\"time\":\"").append(nTime).append("\"")
                .append("}");
            unreadCount++;
            first = false;
        }
    } catch (Exception e) {
        // DB 오류 시 알림 없이 표시
    } finally {
        DBUtil.close(conn, ps, rs);
    }

    notifJson.append("]");
%>
<style>
.topnav {
  display: flex; align-items: center;
  padding: 0 24px; height: 56px;
  background: #0a1520;
  border-bottom: 1px solid rgba(0,170,212,.15);
  gap: 16px; position: relative; z-index: 300;
}
.nav-logo { display: flex; align-items: center; gap: 10px; flex-shrink: 0; text-decoration: none; border-radius: 8px; padding: 4px 8px; margin: -4px -8px; transition: background .2s; }
.nav-logo:hover { background: rgba(0,170,212,.08); text-decoration: none; }
.nav-logo:hover .logo-hex { box-shadow: 0 0 14px rgba(0,170,212,.55); }
.logo-hex { width: 34px; height: 34px; background: linear-gradient(135deg,#003DA5,#00AAD4); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 16px; font-weight: 700; color: #fff; transition: box-shadow .2s; }
.logo-text .lt { font-size: 13px; font-weight: 700; color: #E8F0FE; letter-spacing: 1px; }
.logo-text .ls { font-size: 10px; color: #7A8FA6; letter-spacing: .5px; }
.nav-search { display: flex; align-items: center; gap: 8px; width: 400px; position: absolute; left: 50%; transform: translateX(-50%); background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.08); border-radius: 8px; padding: 0 14px; height: 36px; }
.nav-search input { background: none; border: none; outline: none; color: #E8F0FE; font-size: 13px; font-family: inherit; width: 100%; }
.nav-search input::placeholder { color: rgba(122,143,166,.5); font-size: 12px; }
.nav-right { display: flex; align-items: center; gap: 12px; margin-left: auto; flex-shrink: 0; }
.nav-status { display: flex; align-items: center; gap: 6px; font-size: 10px; color: #7A8FA6; letter-spacing: 1px; }
.status-dot { width: 6px; height: 6px; border-radius: 50%; background: #00E5A0; box-shadow: 0 0 6px #00E5A0; animation: npulse 2s infinite; }
@keyframes npulse { 0%,100%{opacity:1} 50%{opacity:.4} }
.nav-divider { width: 1px; height: 20px; background: rgba(255,255,255,.08); }
.bell-wrap { position: relative; }
.bell-btn { width: 36px; height: 36px; border-radius: 8px; background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.08); display: flex; align-items: center; justify-content: center; cursor: pointer; transition: background .2s, border-color .2s; position: relative; }
.bell-btn:hover    { background: rgba(0,170,212,.1); border-color: rgba(0,170,212,.3); }
.bell-btn.open     { background: rgba(0,170,212,.12); border-color: rgba(0,170,212,.4); }
.bell-btn svg      { color: #7A8FA6; transition: color .2s; }
.bell-btn:hover svg, .bell-btn.open svg { color: #00AAD4; }
.bell-badge { position: absolute; top: -5px; right: -5px; min-width: 16px; height: 16px; border-radius: 8px; background: #EF4444; border: 2px solid #0a1520; font-size: 9px; font-weight: 700; color: #fff; display: flex; align-items: center; justify-content: center; padding: 0 3px; pointer-events: none; }
.notif-panel { display: none; position: absolute; top: calc(100% + 8px); right: 0; width: 330px; background: #112240; border: 1px solid rgba(0,170,212,.2); border-radius: 10px; overflow: hidden; box-shadow: 0 12px 40px rgba(0,0,0,.55); z-index: 999; }
.notif-panel.show { display: block; }
.np-header { display: flex; align-items: center; justify-content: space-between; padding: 13px 16px; border-bottom: 1px solid rgba(255,255,255,.06); background: rgba(0,170,212,.04); }
.np-title { font-size: 12px; font-weight: 600; color: #E8F0FE; display: flex; align-items: center; gap: 6px; }
.np-title-badge { font-size: 10px; font-weight: 700; padding: 1px 6px; border-radius: 10px; background: #EF4444; color: #fff; }
.np-clear { font-size: 11px; color: #7A8FA6; cursor: pointer; background: none; border: none; font-family: inherit; transition: color .15s; padding: 0; }
.np-clear:hover { color: #00AAD4; }
.np-list { max-height: 320px; overflow-y: auto; }
.np-list::-webkit-scrollbar { width: 4px; }
.np-list::-webkit-scrollbar-thumb { background: rgba(0,170,212,.2); border-radius: 2px; }
.np-group-label { font-size: 10px; color: #7A8FA6; letter-spacing: 1px; text-transform: uppercase; padding: 8px 16px 4px; background: rgba(255,255,255,.02); border-bottom: 1px solid rgba(255,255,255,.04); }
.np-item { display: flex; gap: 10px; padding: 11px 16px; border-bottom: 1px solid rgba(255,255,255,.04); transition: background .15s; cursor: pointer; }
.np-item:last-child { border-bottom: none; }
.np-item:hover { background: rgba(0,170,212,.08); }
.np-item.unread { background: rgba(0,170,212,.03); }
.np-icon { width: 30px; height: 30px; border-radius: 7px; flex-shrink: 0; display: flex; align-items: center; justify-content: center; margin-top: 1px; }
.np-icon.type-notice  { background: rgba(0,170,212,.15); }
.np-icon.type-warn    { background: rgba(245,158,11,.15); }
.np-icon.type-success { background: rgba(0,229,160,.15); }
.np-icon.type-notice  svg { color: #00AAD4; }
.np-icon.type-warn    svg { color: #F59E0B; }
.np-icon.type-success svg { color: #00E5A0; }
.np-body { flex: 1; min-width: 0; }
.np-msg  { font-size: 12px; color: #C8D8E8; line-height: 1.55; word-break: keep-all; }
.np-time { font-size: 10px; color: #7A8FA6; margin-top: 4px; }
.np-dot  { width: 6px; height: 6px; border-radius: 50%; background: #00AAD4; flex-shrink: 0; margin-top: 6px; }
.np-item:not(.unread) .np-dot { visibility: hidden; }
.np-empty { padding: 28px 16px; text-align: center; font-size: 12px; color: #7A8FA6; }
.np-footer { padding: 9px 16px; border-top: 1px solid rgba(255,255,255,.06); text-align: center; }
.np-footer a { font-size: 11px; color: rgba(0,170,212,.7); text-decoration: none; transition: color .15s; }
.np-footer a:hover { color: #00AAD4; }
.nav-user-wrap { position: relative; }
.nav-user { display: flex; align-items: center; gap: 8px; cursor: pointer; padding: 4px 8px; border-radius: 8px; transition: background .2s; user-select: none; }
.nav-user:hover { background: rgba(255,255,255,.06); }
.nav-user.open  { background: rgba(0,170,212,.1); }
.user-avatar { width: 30px; height: 30px; border-radius: 8px; background: linear-gradient(135deg,#003DA5,#00AAD4); display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; color: #fff; }
.user-info-text .un { font-size: 12px; font-weight: 500; color: #E8F0FE; }
.user-info-text .ur { font-size: 10px; color: #7A8FA6; }
.nav-arrow { width: 14px; height: 14px; color: #7A8FA6; transition: transform .2s; }
.nav-user.open .nav-arrow { transform: rotate(180deg); }
.user-dropdown { display: none; position: absolute; top: calc(100% + 8px); right: 0; width: 220px; background: #112240; border: 1px solid rgba(0,170,212,.2); border-radius: 10px; overflow: hidden; box-shadow: 0 12px 40px rgba(0,0,0,.5); z-index: 999; }
.user-dropdown.show { display: block; }
.ud-header { padding: 14px 16px; border-bottom: 1px solid rgba(255,255,255,.06); background: rgba(0,170,212,.04); }
.ud-name { font-size: 13px; font-weight: 600; color: #E8F0FE; }
.ud-meta { font-size: 11px; color: #7A8FA6; margin-top: 3px; }
.ud-role { display: inline-block; margin-top: 6px; font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 20px; background: rgba(0,170,212,.15); color: #00AAD4; }
.ud-menu { padding: 6px 0; }
.ud-item { display: flex; align-items: center; gap: 10px; padding: 10px 16px; text-decoration: none; color: #B0C4D8; font-size: 13px; transition: background .15s, color .15s; }
.ud-item:hover { background: rgba(0,170,212,.08); color: #E8F0FE; text-decoration: none; }
.ud-item svg { color: #7A8FA6; flex-shrink: 0; transition: color .15s; }
.ud-item:hover svg { color: #00AAD4; }
.ud-divider { height: 1px; background: rgba(255,255,255,.06); margin: 4px 0; }
.ud-item.logout { color: #EF4444; }
.ud-item.logout svg { color: #EF4444; }
.ud-item.logout:hover { background: rgba(239,68,68,.08); }
</style>

<nav class="topnav">
  <a class="nav-logo" href="/project/dashboard.jsp" title="대시보드로 이동">
    <div class="logo-hex">H</div>
    <div class="logo-text">
      <div class="lt">HMC SCM</div>
      <div class="ls">Supply Chain Platform</div>
    </div>
  </a>

  <div class="nav-search">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px;color:#7A8FA6;flex-shrink:0">
      <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
    </svg>
    <input type="text" placeholder="발주명, 업체명 검색...">
  </div>

  <div class="nav-right">
    <div class="nav-status"><div class="status-dot"></div>SYSTEM ONLINE</div>
    <div class="nav-divider"></div>

    <div class="bell-wrap">
      <div class="bell-btn" id="bellBtn" onclick="toggleBell()" title="알림 / 공지">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
        </svg>
        <span class="bell-badge" id="bellBadge"><%= unreadCount %></span>
      </div>

      <div class="notif-panel" id="notifPanel">
        <div class="np-header">
          <span class="np-title">
            알림 / 공지
            <span class="np-title-badge" id="npTitleBadge"><%= unreadCount %></span>
          </span>
          <button class="np-clear" onclick="clearAllNotifs()">모두 읽음</button>
        </div>
        <div class="np-list" id="npList"></div>
        <div class="np-footer">
          <a href="/project/notice.jsp">전체 공지 보기 →</a>
        </div>
      </div>
    </div>

    <div class="nav-divider"></div>

    <div class="nav-user-wrap">
      <div class="nav-user" id="navUser" onclick="toggleUserMenu()">
        <div class="user-avatar"><%= initials %></div>
        <div class="user-info-text">
          <div class="un"><%= company %></div>
          <div class="ur"><%= roleLabel %></div>
        </div>
        <svg class="nav-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="6,9 12,15 18,9"/>
        </svg>
      </div>

      <div class="user-dropdown" id="userDropdown">
        <div class="ud-header">
          <div class="ud-name"><%= company %></div>
          <div class="ud-meta">ID : <%= userId %></div>
          <span class="ud-role"><%= roleLabel %></span>
        </div>
        <div class="ud-menu">
          <a class="ud-item" href="/project/profile.jsp">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            내 프로필 보기
          </a>
          <% if ("scm".equals(role) || "admin".equals(role)) { %>
          <a class="ud-item" href="/project/adminApproval.jsp">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22,4 12,14.01 9,11.01"/></svg>
            가입 승인 관리
          </a>
          <% } %>
          <div class="ud-divider"></div>
          <a class="ud-item logout" href="/project/dashboard.jsp?action=logout">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16,17 21,12 16,7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
            로그아웃
          </a>
        </div>
      </div>
    </div>
  </div>
</nav>

<script>
(function () {
  var NOTIFS = <%= notifJson.toString() %>;

  var ICONS = {
    notice: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
    warn:   '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
    success:'<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22,4 12,14.01 9,11.01"/></svg>'
  };

  function updateBadge() {
    var unread = NOTIFS.filter(function(n){ return n.unread; }).length;
    document.getElementById('bellBadge').textContent = unread;
    document.getElementById('npTitleBadge').textContent = unread;
    document.getElementById('bellBadge').style.display    = unread > 0 ? 'flex' : 'none';
    document.getElementById('npTitleBadge').style.display = unread > 0 ? 'inline-flex' : 'none';
  }

  function renderNotifs() {
    var list = document.getElementById('npList');
    updateBadge();

    if (NOTIFS.length === 0) {
      list.innerHTML = '<div class="np-empty">새 알림이 없습니다 ✓</div>';
      return;
    }

    var typeOrder = { warn: 0, success: 1, notice: 2 };
    var sorted = NOTIFS.slice().sort(function(a, b){
      var ao = typeOrder[a.type] !== undefined ? typeOrder[a.type] : 9;
      var bo = typeOrder[b.type] !== undefined ? typeOrder[b.type] : 9;
      if (ao !== bo) return ao - bo;
      return (b.unread ? 1 : 0) - (a.unread ? 1 : 0);
    });

    var labels  = { warn:'발주 / 납품 알림', success:'부품 등록 현황', notice:'공지 / 시스템' };
    var lastType = null;
    var html    = '';
    sorted.forEach(function(n) {
      if (n.type !== lastType) {
        html += '<div class="np-group-label">' + (labels[n.type] || '알림') + '</div>';
        lastType = n.type;
      }
      html +=
        '<div class="np-item' + (n.unread ? ' unread' : '') + '" onclick="clickNotif(' + n.id + ', this)">' +
          '<div class="np-icon type-' + n.type + '">' + ICONS[n.type] + '</div>' +
          '<div class="np-body">' +
            '<div class="np-msg">' + n.msg + '</div>' +
            '<div class="np-time">' + n.time + '</div>' +
          '</div>' +
          '<div class="np-dot"></div>' +
        '</div>';
    });
    list.innerHTML = html;
  }

  // 알림 클릭 → notice_reads에 기록 → 목록에서 제거 → notice.jsp 이동
  window.clickNotif = function(noticeId, el) {
    // 목록에서 즉시 제거
    NOTIFS = NOTIFS.filter(function(n){ return n.id !== noticeId; });
    el.remove();
    updateBadge();

    // 남은 항목 없으면 빈 메시지
    var list = document.getElementById('npList');
    var items = list.querySelectorAll('.np-item');
    if (items.length === 0) {
      list.innerHTML = '<div class="np-empty">새 알림이 없습니다 ✓</div>';
    }

    if (noticeId > 0) {
      // DB에 읽음 기록 INSERT (AJAX)
      fetch('/project/noticeRead.jsp?id=' + noticeId, { method: 'POST' })
        .then(function() {
          // notice.jsp로 이동 (해당 공지 하이라이트)
          window.location.href = '/project/notice.jsp?highlight=' + noticeId;
        });
    }
  };

  // 모두 읽음 → notice_reads에 전체 기록
  window.clearAllNotifs = function () {
    NOTIFS = NOTIFS.filter(function(n){ return n.id === 0; }); // 세션 알림만 유지
    NOTIFS.forEach(function(n){ n.unread = false; });
    renderNotifs();
    fetch('/project/noticeRead.jsp?all=1', { method: 'POST' });
  };

  window.toggleBell = function () {
    var isOpen = document.getElementById('notifPanel').classList.contains('show');
    closeAll();
    if (!isOpen) {
      document.getElementById('notifPanel').classList.add('show');
      document.getElementById('bellBtn').classList.add('open');
    }
  };

  window.toggleUserMenu = function () {
    var isOpen = document.getElementById('userDropdown').classList.contains('show');
    closeAll();
    if (!isOpen) {
      document.getElementById('userDropdown').classList.add('show');
      document.getElementById('navUser').classList.add('open');
    }
  };

  function closeAll() {
    document.getElementById('notifPanel').classList.remove('show');
    document.getElementById('bellBtn').classList.remove('open');
    document.getElementById('userDropdown').classList.remove('show');
    document.getElementById('navUser').classList.remove('open');
  }

  document.addEventListener('click', function (e) {
    var bellWrap = document.querySelector('.bell-wrap');
    var userWrap = document.querySelector('.nav-user-wrap');
    if ((!bellWrap || !bellWrap.contains(e.target)) &&
        (!userWrap || !userWrap.contains(e.target))) {
      closeAll();
    }
  });

  renderNotifs();
})();
</script>
