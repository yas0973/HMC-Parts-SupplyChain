<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, util.DBUtil" %>
<%
    if (session.getAttribute("userId") != null) {
        response.sendRedirect("dashboard.jsp");
        return;
    }

    String errorMsg     = "";
    String paramId      = request.getParameter("userId")       != null ? request.getParameter("userId").trim()       : "";
    String paramPw      = request.getParameter("password")     != null ? request.getParameter("password").trim()     : "";
    String selectedRole = request.getParameter("selectedRole") != null ? request.getParameter("selectedRole").trim() : "";

    // ── DB에서 KPI 조회 (로그인 전에도 보여줌) ──
    int    kpiVendors     = 0;
    double kpiDelivery    = 0.0;

    Connection connKpi = null; PreparedStatement psKpi = null; ResultSet rsKpi = null;
    try {
        connKpi = DBUtil.getConnection();

        // 연결 벤더 수 (vendor 역할 유저가 소속된 업체만)
        psKpi = connKpi.prepareStatement(
            "SELECT COUNT(DISTINCT v.vendor_id) FROM vendors v " +
            "JOIN users u ON v.vendor_id = u.company_id WHERE u.role = 'vendor'");
        rsKpi = psKpi.executeQuery();
        if (rsKpi.next()) kpiVendors = rsKpi.getInt(1);
        rsKpi.close(); psKpi.close();

        // 납기 준수율 (DELIVERED / 전체)
        psKpi = connKpi.prepareStatement("SELECT COUNT(*) FROM deliveries");
        rsKpi = psKpi.executeQuery();
        rsKpi.next();
        int total = rsKpi.getInt(1);
        rsKpi.close(); psKpi.close();

        if (total > 0) {
            psKpi = connKpi.prepareStatement("SELECT COUNT(*) FROM deliveries WHERE status='DELIVERED'");
            rsKpi = psKpi.executeQuery();
            rsKpi.next();
            int done = rsKpi.getInt(1);
            kpiDelivery = Math.round((double) done / total * 1000.0) / 10.0;
        }
    } catch (Exception e) {
        // DB 연결 안 돼도 로그인 페이지는 표시
    } finally {
        DBUtil.close(connKpi, psKpi, rsKpi);
    }

    // ── 로그인 처리 ──
    if (!paramId.isEmpty() && !paramPw.isEmpty()) {
        if (selectedRole.isEmpty()) {
            errorMsg = "접속 유형을 선택해주세요.";
        } else {
            Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
            try {
                conn = DBUtil.getConnection();
                String sql = "SELECT u.user_id, u.user_name, u.role, u.status, u.approved_by_scm, u.approved_by_admin, v.vendor_name " +
                             "FROM users u LEFT JOIN vendors v ON u.company_id = v.vendor_id " +
                             "WHERE u.user_id = ? AND u.password = ?";
                ps = conn.prepareStatement(sql);
                ps.setString(1, paramId);
                ps.setString(2, paramPw);
                rs = ps.executeQuery();

                if (rs.next()) {
                    String dbRole  = rs.getString("role");
                    String dbStatus = rs.getString("status");

                    // status 체크 (PENDING / REJECTED)
                    if ("PENDING".equals(dbStatus)) {
                        String roleLabel2 = "vendor".equals(dbRole) ? "벤더사" : "원청기업";
                        if ("vendor".equals(dbRole)) {
                            boolean scmOk   = "1".equals(rs.getString("approved_by_scm"));
                            boolean adminOk = "1".equals(rs.getString("approved_by_admin"));
                            errorMsg = "승인 대기 중입니다. [관리자: " + (scmOk?"✓":"대기") + " / 원청기업: " + (adminOk?"✓":"대기") + "]";
                        } else {
                            errorMsg = "승인 대기 중입니다. 관리자(SCM)의 승인을 기다려주세요.";
                        }
                    } else if ("REJECTED".equals(dbStatus)) {
                        errorMsg = "가입이 거절되었습니다. 관리자에게 문의해주세요.";
                    } else if (!dbRole.equals(selectedRole)) {
                        // 선택한 역할과 DB 역할 비교
                        String selLabel = "admin".equals(selectedRole) ? "원청기업" : "scm".equals(selectedRole) ? "SCM 관리자" : "벤더사";
                        String dbLabel  = "admin".equals(dbRole)       ? "원청기업" : "scm".equals(dbRole)       ? "SCM 관리자" : "벤더사";
                        errorMsg = "선택한 접속 유형(" + selLabel + ")이 실제 계정 유형(" + dbLabel + ")과 다릅니다.";
                    } else {
                        String vendorNm  = rs.getString("vendor_name");
                        String company   = (vendorNm != null && !vendorNm.isEmpty()) ? vendorNm : rs.getString("user_name");
                        String roleLabel = "admin".equals(dbRole) ? "원청기업" : "scm".equals(dbRole) ? "SCM 관리자" : "벤더사";
                        session.invalidate();
                        HttpSession ns = request.getSession(true);
                        ns.setAttribute("userId",    rs.getString("user_id"));
                        ns.setAttribute("company",   company);
                        ns.setAttribute("role",      dbRole);
                        ns.setAttribute("roleLabel", roleLabel);
                        ns.setMaxInactiveInterval(1800);
                        response.sendRedirect("dashboard.jsp");
                        return;
                    }
                } else {
                    errorMsg = "아이디 또는 비밀번호가 올바르지 않습니다.";
                }
            } catch (SQLException e) {
                e.printStackTrace();
                errorMsg = "DB 연결 오류가 발생했습니다. 잠시 후 다시 시도해주세요.";
            } finally {
                DBUtil.close(conn, ps, rs);
            }
        }
    }

    // 납기 준수율 표시용 포맷
    String kpiDeliveryStr = (kpiDelivery == Math.floor(kpiDelivery))
        ? String.valueOf((int) kpiDelivery) + "%"
        : kpiDelivery + "%";
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 로그인</title>
<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240; --border:rgba(0,170,212,.25); --text:#E8F0FE; --muted:#7A8FA6; --error:#FF4D6D; --success:#00E5A0; }
  html, body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); overflow:hidden; }
  #bg-canvas { position:fixed; inset:0; z-index:0; opacity:.55; }
  .grid-overlay { position:fixed; inset:0; z-index:1; pointer-events:none; background-image:linear-gradient(rgba(0,170,212,.04) 1px,transparent 1px),linear-gradient(90deg,rgba(0,170,212,.04) 1px,transparent 1px); background-size:60px 60px; animation:gridShift 20s linear infinite; }
  @keyframes gridShift { to { background-position:60px 60px; } }
  .wrapper { position:relative; z-index:10; display:grid; grid-template-columns:1fr 520px; height:100vh; }

  /* 히어로 */
  .hero { display:flex; flex-direction:column; justify-content:center; padding:64px 72px; background:linear-gradient(135deg,rgba(0,61,165,.18) 0%,rgba(0,170,212,.06) 100%); border-right:1px solid var(--border); backdrop-filter:blur(8px); }
  .brand-mark { display:flex; align-items:center; gap:16px; margin-bottom:48px; }
  .h-logo { width:56px; height:56px; background:var(--primary); clip-path:polygon(50% 0%,100% 25%,100% 75%,50% 100%,0% 75%,0% 25%); display:flex; align-items:center; justify-content:center; font-family:'Bebas Neue',sans-serif; font-size:28px; color:#fff; animation:pulseLogo 3s ease-in-out infinite; }
  @keyframes pulseLogo { 0%,100%{box-shadow:0 0 24px rgba(0,61,165,.7)} 50%{box-shadow:0 0 40px rgba(0,170,212,.9)} }
  .brand-text .co  { font-size:12px; letter-spacing:3px; color:var(--accent); text-transform:uppercase; }
  .brand-text .sys { font-family:'Bebas Neue',sans-serif; font-size:24px; letter-spacing:2px; }
  .chain-vis { display:flex; align-items:center; margin-bottom:36px; opacity:.85; }
  .chain-node { display:flex; flex-direction:column; align-items:center; gap:8px; }
  .cn-dot { width:48px; height:48px; border-radius:50%; border:2px solid; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; }
  .cn-dot.hmc { border-color:var(--primary); background:rgba(0,61,165,.3); color:#7BA7FF; }
  .cn-dot.v1  { border-color:var(--accent); background:rgba(0,170,212,.2); color:var(--accent); }
  .cn-dot.v2  { border-color:#00E5A0; background:rgba(0,229,160,.15); color:#00E5A0; }
  .cn-label { font-size:11px; color:var(--muted); white-space:nowrap; }
  .chain-line { flex:1; height:2px; min-width:36px; background:linear-gradient(90deg,var(--primary),var(--accent)); opacity:.5; position:relative; }
  .chain-line::after { content:''; position:absolute; right:-1px; top:50%; transform:translateY(-50%); border:5px solid transparent; border-left-color:var(--accent); }
  .hero-title { font-family:'Bebas Neue',sans-serif; font-size:clamp(48px,5vw,72px); line-height:1.05; letter-spacing:2px; margin-bottom:24px; }
  .hero-title span { color:var(--accent); }
  .hero-desc { font-size:15px; color:var(--muted); line-height:1.9; max-width:460px; margin-bottom:44px; }
  .kpi-row { display:flex; gap:16px; flex-wrap:wrap; }
  .kpi { flex:1; min-width:120px; background:rgba(0,170,212,.08); border:1px solid var(--border); border-radius:10px; padding:18px 20px; position:relative; overflow:hidden; }
  .kpi::before { content:''; position:absolute; top:0; left:0; right:0; height:2px; background:linear-gradient(90deg,var(--primary),var(--accent)); }
  .kpi-val { font-family:'Share Tech Mono',monospace; font-size:30px; color:var(--accent); }
  .kpi-lbl { font-size:12px; color:var(--muted); margin-top:6px; letter-spacing:1px; }

  /* 로그인 패널 */
  .login-panel { display:flex; flex-direction:column; justify-content:center; padding:48px 52px; background:rgba(13,27,42,.9); backdrop-filter:blur(20px); border-left:1px solid var(--border); overflow-y:auto; }
  .login-header { margin-bottom:28px; }
  .login-header h2 { font-family:'Bebas Neue',sans-serif; font-size:36px; letter-spacing:2px; margin-bottom:6px; }
  .login-header p { font-size:14px; color:var(--muted); letter-spacing:1px; }
  .status-bar { display:flex; align-items:center; gap:10px; background:rgba(0,229,160,.08); border:1px solid rgba(0,229,160,.2); border-radius:8px; padding:10px 16px; margin-bottom:28px; }
  .status-dot { width:9px; height:9px; border-radius:50%; background:var(--success); box-shadow:0 0 8px var(--success); animation:blink 2s ease-in-out infinite; }
  @keyframes blink { 0%,100%{opacity:1} 50%{opacity:.3} }
  .status-bar span { font-size:13px; color:var(--success); letter-spacing:1px; }

  /* 역할 선택 */
  .form-label { display:block; font-size:12px; letter-spacing:2px; color:var(--muted); text-transform:uppercase; margin-bottom:8px; }
  .role-grid { display:grid; grid-template-columns:1fr 1fr 1fr; gap:8px; margin-bottom:6px; }
  .role-btn { background:rgba(255,255,255,.03); border:1px solid rgba(255,255,255,.08); border-radius:8px; padding:12px 10px; cursor:pointer; transition:all .25s; text-align:center; }
  .role-btn:hover { border-color:rgba(0,170,212,.4); background:rgba(0,170,212,.06); }
  .role-btn.active { border-color:var(--accent); background:rgba(0,170,212,.1); }
  .role-btn.active .rb-name { color:var(--accent); }
  .rb-tag  { font-size:10px; color:var(--muted); letter-spacing:1.5px; text-transform:uppercase; margin-bottom:4px; }
  .rb-name { font-size:13px; font-weight:500; color:var(--text); transition:color .25s; }
  .role-error-msg { font-size:11px; color:var(--error); margin-bottom:16px; display:none; }
  .role-error-msg.show { display:block; }

  /* 에러 박스 */
  .error-box { display:flex; align-items:center; gap:10px; background:rgba(255,77,109,.1); border:1px solid rgba(255,77,109,.35); border-radius:8px; padding:12px 16px; margin-bottom:20px; animation:shake .4s ease; }
  @keyframes shake { 0%,100%{transform:translateX(0)} 20%{transform:translateX(-6px)} 60%{transform:translateX(6px)} }
  .error-box span { font-size:14px; color:var(--error); }

  /* 폼 */
  .form-group { margin-bottom:18px; }
  .input-wrap { position:relative; display:flex; align-items:center; }
  .input-icon { position:absolute; left:14px; color:var(--muted); pointer-events:none; }
  .form-control { width:100%; background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1); border-radius:8px; padding:13px 14px 13px 44px; color:var(--text); font-family:'Share Tech Mono',monospace; font-size:15px; outline:none; transition:border-color .3s,background .3s; }
  .form-control:focus { border-color:var(--accent); background:rgba(0,170,212,.07); }
  .form-control::placeholder { color:rgba(122,143,166,.5); }
  .save-id-row { display:flex; align-items:center; gap:8px; margin-bottom:20px; }
  .save-id-row input[type="checkbox"] { width:16px; height:16px; accent-color:var(--accent); cursor:pointer; }
  .save-id-row label { font-size:14px; color:var(--muted); cursor:pointer; }
  .btn-login { width:100%; background:linear-gradient(135deg,var(--primary) 0%,#0055CC 50%,var(--accent) 100%); background-size:200% 200%; border:none; border-radius:8px; padding:15px; color:#fff; font-weight:700; font-size:16px; letter-spacing:2px; cursor:pointer; position:relative; overflow:hidden; transition:background-position .5s,box-shadow .3s,transform .15s; font-family:'Noto Sans KR',sans-serif; }
  .btn-login:hover { background-position:right center; box-shadow:0 6px 30px rgba(0,170,212,.45); transform:translateY(-1px); }
  .btn-shine { position:absolute; top:0; left:-75%; width:50%; height:100%; background:linear-gradient(90deg,transparent,rgba(255,255,255,.18),transparent); transform:skewX(-20deg); transition:left .6s; }
  .btn-login:hover .btn-shine { left:125%; }
  .signup-row { display:flex; align-items:center; justify-content:center; gap:8px; margin-top:20px; }
  .signup-row span { font-size:14px; color:var(--muted); }
  .signup-row a { font-size:14px; color:var(--accent); text-decoration:none; font-weight:500; }
  .signup-row a:hover { text-decoration:underline; }
  .login-footer { margin-top:24px; text-align:center; font-size:12px; color:rgba(122,143,166,.5); }
  @media(max-width:900px) { .wrapper { grid-template-columns:1fr; } .hero { display:none; } .login-panel { justify-content:center; min-height:100vh; } }
</style>
</head>
<body>
<canvas id="bg-canvas"></canvas>
<div class="grid-overlay"></div>
<div class="wrapper">

  <!-- 히어로 -->
  <div class="hero">
    <div class="brand-mark">
      <div class="h-logo">H</div>
      <div class="brand-text">
        <div class="co">Hyundai Motor Company</div>
        <div class="sys">SCM Optimization Platform</div>
      </div>
    </div>
    <div class="chain-vis">
      <div class="chain-node"><div class="cn-dot hmc">HMC</div><div class="cn-label">원청기업</div></div>
      <div class="chain-line"></div>
      <div class="chain-node"><div class="cn-dot v1">벤더</div><div class="cn-label">협력사</div></div>
      <div class="chain-line"></div>
      <div class="chain-node"><div class="cn-dot v2">SCM</div><div class="cn-label">공급망팀</div></div>
    </div>
    <h1 class="hero-title">SUPPLY CHAIN<br><span>GENETIC</span><br>OPTIMIZER</h1>
    <p class="hero-desc">유전 알고리즘(Genetic Algorithm) 기반의 다계층 공급망 생산 최적화 플랫폼입니다. 현대자동차 본사 및 협력사의 생산 계획, 재고, 납기를 실시간으로 통합 관리합니다.</p>

    <!-- ★ DB 연동 KPI -->
    <div class="kpi-row">
      <div class="kpi">
        <div class="kpi-val"><%= kpiVendors %></div>
        <div class="kpi-lbl">연결 벤더</div>
      </div>
      <div class="kpi">
        <div class="kpi-val"><%= kpiDeliveryStr %></div>
        <div class="kpi-lbl">납기 준수율</div>
      </div>
      <div class="kpi">
        <div class="kpi-val">GA·G7</div>
        <div class="kpi-lbl">알고리즘 세대</div>
      </div>
    </div>
  </div>

  <!-- 로그인 패널 -->
  <div class="login-panel">
    <div class="login-header">
      <h2>시스템 로그인</h2>
      <p>AUTHORIZED PERSONNEL ONLY · HMC SCM v3.7</p>
    </div>
    <div class="status-bar"><div class="status-dot"></div><span>SYSTEM ONLINE · GA ENGINE ACTIVE</span></div>

    <% if (!errorMsg.isEmpty()) { %>
    <div class="error-box">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FF4D6D" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <span><%= errorMsg %></span>
    </div>
    <% } %>

    <!-- 역할 선택 -->
    <div style="margin-bottom:4px;">
      <label class="form-label">접속 유형 선택</label>
      <div class="role-grid">
        <div class="role-btn <%= "admin".equals(selectedRole) || selectedRole.isEmpty() ? "active" : "" %>"
             onclick="setRole('admin', this)">
          <div class="rb-tag">ADMIN</div><div class="rb-name">원청기업</div>
        </div>
        <div class="role-btn <%= "vendor".equals(selectedRole) ? "active" : "" %>"
             onclick="setRole('vendor', this)">
          <div class="rb-tag">VENDOR</div><div class="rb-name">벤더사</div>
        </div>
        <div class="role-btn <%= "scm".equals(selectedRole) ? "active" : "" %>"
             onclick="setRole('scm', this)">
          <div class="rb-tag">SCM</div><div class="rb-name">SCM 관리자</div>
        </div>
      </div>
      <div class="role-error-msg" id="roleErrorMsg">접속 유형을 선택해주세요.</div>
    </div>

    <form method="post" action="login.jsp" autocomplete="off" onsubmit="return validateLogin()">
      <input type="hidden" name="selectedRole" id="selectedRole"
             value="<%= selectedRole.isEmpty() ? "admin" : selectedRole %>">

      <div class="form-group">
        <label class="form-label">사용자 ID</label>
        <div class="input-wrap">
          <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          <input type="text" id="userId" name="userId" class="form-control" placeholder="아이디 입력" value="<%= paramId %>" required>
        </div>
      </div>
      <div class="form-group">
        <label class="form-label">비밀번호</label>
        <div class="input-wrap">
          <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          <input type="password" id="password" name="password" class="form-control" placeholder="비밀번호 입력" required>
        </div>
      </div>
      <div class="save-id-row">
        <input type="checkbox" id="saveId" onchange="toggleSaveId(this)">
        <label for="saveId">아이디 저장</label>
      </div>
      <button type="submit" class="btn-login"><span class="btn-shine"></span>시스템 접속</button>
    </form>

    <div class="signup-row"><span>계정이 없으신가요?</span><a href="signup.jsp">회원가입</a></div>
    <div class="login-footer">© 2024 Hyundai Motor Company · Supply Chain Management Division</div>
  </div>
</div>

<script>
var currentRole = '<%= selectedRole.isEmpty() ? "admin" : selectedRole %>';

function setRole(role, btn) {
  document.querySelectorAll('.role-btn').forEach(function(b) { b.classList.remove('active'); });
  btn.classList.add('active');
  currentRole = role;
  document.getElementById('selectedRole').value = role;
  document.getElementById('roleErrorMsg').classList.remove('show');
}

function validateLogin() {
  if (!currentRole) {
    document.getElementById('roleErrorMsg').classList.add('show');
    return false;
  }
  return true;
}

window.onload = function() {
  var saved = localStorage.getItem('savedUserId');
  if (saved) {
    document.getElementById('userId').value = saved;
    document.getElementById('saveId').checked = true;
  }
};

function toggleSaveId(cb) {
  if (cb.checked) localStorage.setItem('savedUserId', document.getElementById('userId').value);
  else localStorage.removeItem('savedUserId');
}

document.querySelector('form').addEventListener('submit', function() {
  if (document.getElementById('saveId').checked)
    localStorage.setItem('savedUserId', document.getElementById('userId').value);
});

// 파티클 배경
var canvas = document.getElementById('bg-canvas');
var ctx = canvas.getContext('2d');
var W, H, particles = [];
function resize() { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; }
window.addEventListener('resize', resize); resize();

function Particle() { this.reset(true); }
Particle.prototype.reset = function(initial) {
  this.x = Math.random()*W; this.y = initial ? Math.random()*H : H+10;
  this.vx = (Math.random()-.5)*.4; this.vy = -(Math.random()*.8+.2);
  this.r = Math.random()*2+.5; this.life = 1; this.decay = Math.random()*.004+.002;
  this.col = Math.random()>.5 ? '0,170,212' : '0,61,165';
};
Particle.prototype.update = function() {
  this.x+=this.vx; this.y+=this.vy; this.life-=this.decay;
  if(this.life<=0||this.y<-10) this.reset(false);
};
Particle.prototype.draw = function() {
  ctx.beginPath(); ctx.arc(this.x,this.y,this.r,0,Math.PI*2);
  ctx.fillStyle='rgba('+this.col+','+this.life*.7+')'; ctx.fill();
};

function drawConn() {
  for(var i=0;i<particles.length;i++) {
    for(var j=i+1;j<particles.length;j++) {
      var dx=particles[i].x-particles[j].x, dy=particles[i].y-particles[j].y;
      var d=Math.sqrt(dx*dx+dy*dy);
      if(d<100){
        ctx.beginPath(); ctx.moveTo(particles[i].x,particles[i].y);
        ctx.lineTo(particles[j].x,particles[j].y);
        ctx.strokeStyle='rgba(0,170,212,'+(1-d/100)*.12+')';
        ctx.lineWidth=.5; ctx.stroke();
      }
    }
  }
}
for(var i=0;i<80;i++) particles.push(new Particle());
function animate() {
  ctx.clearRect(0,0,W,H); drawConn();
  particles.forEach(function(p){p.update();p.draw();});
  requestAnimationFrame(animate);
}
animate();
</script>
</body>
</html>
