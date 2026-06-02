<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, util.DBUtil" %>
<%
    // 이미 로그인된 경우 대시보드로
    if (session.getAttribute("userId") != null) {
        response.sendRedirect("dashboard.jsp"); return;
    }

    String message  = "";
    String msgType  = "";

    // 폼 값 유지용
    String companyNm  = "";
    String role       = "";
    String userId_val = "";
    String userName   = "";
    String email      = "";
    String phone      = "";
    String address    = "";
    String represent  = "";
    String bizNo      = "";
    String corpNo     = "";
    String techCert   = "";

    if ("POST".equals(request.getMethod())) {
        companyNm  = request.getParameter("companyNm")  != null ? request.getParameter("companyNm").trim()  : "";
        role       = request.getParameter("role")       != null ? request.getParameter("role").trim()       : "";
        userId_val = request.getParameter("userId")     != null ? request.getParameter("userId").trim()     : "";
        String pw  = request.getParameter("pw")         != null ? request.getParameter("pw").trim()         : "";
        String pw2 = request.getParameter("pw2")        != null ? request.getParameter("pw2").trim()        : "";
        userName   = request.getParameter("userName")   != null ? request.getParameter("userName").trim()   : "";
        email      = request.getParameter("email")      != null ? request.getParameter("email").trim()      : "";
        phone      = request.getParameter("phone")      != null ? request.getParameter("phone").trim()      : "";
        address    = request.getParameter("address")    != null ? request.getParameter("address").trim()    : "";
        represent  = request.getParameter("represent")  != null ? request.getParameter("represent").trim()  : "";
        bizNo      = request.getParameter("bizNo")      != null ? request.getParameter("bizNo").trim()      : "";
        corpNo     = request.getParameter("corpNo")     != null ? request.getParameter("corpNo").trim()     : "";
        techCert   = request.getParameter("techCert")   != null ? request.getParameter("techCert").trim()   : "";

        // 유효성 검사
        boolean isVendorOrAdmin = "vendor".equals(role) || "admin".equals(role);

        if (companyNm.isEmpty() || role.isEmpty() || userId_val.isEmpty() || pw.isEmpty() || userName.isEmpty() || email.isEmpty()) {
            message = "필수 항목을 모두 입력해주세요."; msgType = "error";
        } else if (!pw.equals(pw2)) {
            message = "비밀번호가 일치하지 않습니다."; msgType = "error";
        } else if (pw.length() < 6) {
            message = "비밀번호는 6자 이상이어야 합니다."; msgType = "error";
        } else if (isVendorOrAdmin && (bizNo.isEmpty() || corpNo.isEmpty() || techCert.isEmpty())) {
            message = "원청기업/벤더사는 사업자번호, 법인번호, 기술인증을 입력해주세요."; msgType = "error";
        } else {
            Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
            try {
                conn = DBUtil.getConnection();

                // 아이디 중복 체크
                ps = conn.prepareStatement("SELECT user_id FROM users WHERE user_id = ?");
                ps.setString(1, userId_val);
                rs = ps.executeQuery();
                if (rs.next()) {
                    message = "이미 사용 중인 아이디입니다."; msgType = "error";
                    rs.close(); ps.close();
                } else {
                    rs.close(); ps.close();

                    // 역할별 status, company_id 결정
                    String status = "scm".equals(role) ? "APPROVED" : "PENDING";
                    Integer companyId = null;

                    // scm은 바로 저장, admin/vendor는 company_id 없이 저장 (승인 후 연결)
                    ps = conn.prepareStatement(
                        "INSERT INTO users (user_id, password, user_name, role, company_id, email, phone, join_date, biz_no, corp_no, tech_cert, status) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?)");
                    ps.setString(1, userId_val);
                    ps.setString(2, pw);
                    ps.setString(3, userName);
                    ps.setString(4, role);
                    if (companyId != null) ps.setInt(5, companyId); else ps.setNull(5, java.sql.Types.INTEGER);
                    ps.setString(6, email);
                    ps.setString(7, phone.isEmpty() ? null : phone);
                    ps.setString(8, bizNo.isEmpty()  ? null : bizNo);
                    ps.setString(9, corpNo.isEmpty() ? null : corpNo);
                    ps.setString(10, techCert.isEmpty() ? null : techCert);
                    ps.setString(11, status);
                    ps.executeUpdate();
                    ps.close();

                    // 벤더/원청기업 → vendors 테이블에 임시 저장 (승인 후 company_id 연결)
                    if ("vendor".equals(role)) {
                        ps = conn.prepareStatement(
                            "INSERT INTO vendors (vendor_name, biz_no, representative, address, tier) VALUES (?, ?, ?, ?, '미정')",
                            PreparedStatement.RETURN_GENERATED_KEYS);
                        ps.setString(1, companyNm);
                        ps.setString(2, bizNo.isEmpty() ? null : bizNo);
                        ps.setString(3, represent.isEmpty() ? null : represent);
                        ps.setString(4, address.isEmpty() ? null : address);
                        ps.executeUpdate();
                        rs = ps.getGeneratedKeys();
                        if (rs.next()) {
                            int newVendorId = rs.getInt(1);
                            rs.close(); ps.close();
                            // company_id 바로 연결
                            ps = conn.prepareStatement("UPDATE users SET company_id = ? WHERE user_id = ?");
                            ps.setInt(1, newVendorId);
                            ps.setString(2, userId_val);
                            ps.executeUpdate();
                        }
                    }

                    if ("scm".equals(role)) {
                        message = "회원가입이 완료되었습니다! 바로 로그인하세요.";
                        msgType = "success";
                    } else {
                        message = "가입 신청이 완료되었습니다. 승인 후 로그인 가능합니다.";
                        msgType = "pending";
                    }
                    // 성공 시 폼 초기화
                    companyNm = role = userId_val = userName = email = phone = address = represent = bizNo = corpNo = techCert = "";
                }
            } catch (Exception e) {
                message = "오류 발생: " + e.getMessage(); msgType = "error";
            } finally {
                DBUtil.close(conn, ps, rs);
            }
        }
    }
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 회원가입</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --primary: #003DA5; --accent: #00AAD4; --panel: #0D1B2A;
  --surface: #112240; --border: rgba(0,170,212,.2);
  --text: #E8F0FE; --muted: #7A8FA6;
  --success: #00E5A0; --danger: #EF4444; --warning: #F59E0B;
}
html, body { min-height: 100vh; font-family: 'Noto Sans KR', sans-serif; background: var(--panel); color: var(--text); }
body {
  background:
    radial-gradient(ellipse at 15% 10%, rgba(0,61,165,.25) 0%, transparent 55%),
    radial-gradient(ellipse at 85% 90%, rgba(0,170,212,.15) 0%, transparent 50%),
    #0D1B2A;
  display: flex; align-items: flex-start; justify-content: center; padding: 40px 20px;
}

.signup-wrap { width: 100%; max-width: 560px; }

/* 로고 */
.logo-area { text-align: center; margin-bottom: 28px; }
.logo-hex { width: 52px; height: 52px; background: linear-gradient(135deg,#003DA5,#00AAD4); border-radius: 14px; display: inline-flex; align-items: center; justify-content: center; font-size: 22px; font-weight: 700; color: #fff; margin-bottom: 10px; }
.logo-title { font-size: 22px; font-weight: 700; color: var(--text); letter-spacing: 1px; }
.logo-sub   { font-size: 12px; color: var(--muted); margin-top: 4px; }

/* 카드 */
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 32px; }
.card-title { font-size: 16px; font-weight: 700; color: var(--text); margin-bottom: 24px; padding-bottom: 14px; border-bottom: 1px solid rgba(255,255,255,.07); }

/* 역할 선택 탭 */
.role-tabs { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin-bottom: 24px; }
.role-tab {
  padding: 12px 8px; border-radius: 10px; text-align: center; cursor: pointer;
  border: 1px solid rgba(255,255,255,.1); background: rgba(255,255,255,.03);
  transition: all .2s; user-select: none;
}
.role-tab:hover { border-color: rgba(0,170,212,.4); background: rgba(0,170,212,.06); }
.role-tab.active { border-color: var(--accent); background: rgba(0,170,212,.12); }
.role-tab .role-icon { font-size: 22px; margin-bottom: 6px; }
.role-tab .role-name { font-size: 12px; font-weight: 600; color: var(--text); }
.role-tab .role-desc { font-size: 10px; color: var(--muted); margin-top: 2px; }
.role-tab.active .role-name { color: var(--accent); }

/* 폼 */
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.field { display: flex; flex-direction: column; gap: 6px; }
.field.full { grid-column: 1 / -1; }
label { font-size: 11px; color: var(--muted); letter-spacing: .5px; text-transform: uppercase; }
.required { color: var(--danger); margin-left: 2px; }
input[type="text"], input[type="password"], input[type="email"] {
  background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.1);
  border-radius: 8px; padding: 11px 14px; color: var(--text);
  font-family: 'Noto Sans KR', sans-serif; font-size: 13px;
  outline: none; transition: border-color .2s, background .2s; width: 100%;
}
input:focus { border-color: var(--accent); background: rgba(0,170,212,.05); }
input.invalid { border-color: var(--danger) !important; }
input::placeholder { color: rgba(122,143,166,.4); }

/* 구분선 */
.divider { border: none; border-top: 1px solid rgba(255,255,255,.07); margin: 20px 0; }
.section-label {
  font-size: 11px; font-weight: 600; color: var(--accent);
  letter-spacing: 2px; text-transform: uppercase;
  border-left: 3px solid var(--accent); padding-left: 8px; margin-bottom: 14px;
}

/* 메시지 */
.msg { display: flex; align-items: center; gap: 8px; padding: 12px 16px; border-radius: 8px; font-size: 13px; margin-bottom: 18px; }
.msg.error   { background: rgba(239,68,68,.08); border: 1px solid rgba(239,68,68,.25); color: var(--danger); }
.msg.success { background: rgba(0,229,160,.08); border: 1px solid rgba(0,229,160,.2); color: var(--success); }
.msg.pending { background: rgba(245,158,11,.08); border: 1px solid rgba(245,158,11,.25); color: var(--warning); }

/* 버튼 */
.btn-submit {
  width: 100%; padding: 13px; border: none; border-radius: 10px;
  background: linear-gradient(135deg, #003DA5, #00AAD4);
  color: #fff; font-size: 15px; font-weight: 600;
  font-family: 'Noto Sans KR', sans-serif;
  cursor: pointer; transition: opacity .2s, transform .2s; margin-top: 20px;
}
.btn-submit:hover { opacity: .9; transform: translateY(-1px); }

.login-link { text-align: center; margin-top: 18px; font-size: 13px; color: var(--muted); }
.login-link a { color: var(--accent); text-decoration: none; font-weight: 500; }
.login-link a:hover { text-decoration: underline; }

/* 숨김 섹션 */
.biz-section { display: none; }
.biz-section.show { display: block; }
</style>
</head>
<body>
<div class="signup-wrap">
  <div class="logo-area">
    <div class="logo-hex">H</div>
    <div class="logo-title">HMC SCM</div>
    <div class="logo-sub">Supply Chain Management Platform</div>
  </div>

  <div class="card">
    <div class="card-title">회원가입</div>

    <% if (!message.isEmpty()) { %>
    <div class="msg <%= msgType %>">
      <% if ("error".equals(msgType)) { %>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <% } else if ("pending".equals(msgType)) { %>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12,6 12,12 16,14"/></svg>
      <% } else { %>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22,4 12,14.01 9,11.01"/></svg>
      <% } %>
      <%= message %>
    </div>
    <% } %>

    <form method="post" action="signup.jsp" id="signupForm" onsubmit="return validateForm()">
      <input type="hidden" name="role" id="roleInput" value="<%= role %>">

      <!-- 역할 선택 -->
      <div class="role-tabs">
        <div class="role-tab <%= "admin".equals(role) ? "active" : "" %>" onclick="selectRole('admin', this)">
          <div class="role-icon">🏢</div>
          <div class="role-name">원청기업</div>
          <div class="role-desc">발주 담당자</div>
        </div>
        <div class="role-tab <%= "vendor".equals(role) ? "active" : "" %>" onclick="selectRole('vendor', this)">
          <div class="role-icon">🔧</div>
          <div class="role-name">벤더사</div>
          <div class="role-desc">공급 업체</div>
        </div>
        <div class="role-tab <%= "scm".equals(role) ? "active" : "" %>" onclick="selectRole('scm', this)">
          <div class="role-icon">⚙️</div>
          <div class="role-name">관리자</div>
          <div class="role-desc">SCM 운영</div>
        </div>
      </div>

      <!-- 기본 계정 정보 -->
      <div class="section-label">기본 정보</div>
      <div class="form-grid">
        <div class="field">
          <label>아이디<span class="required">*</span></label>
          <input type="text" name="userId" id="userId" value="<%= userId_val %>" placeholder="영문, 숫자 조합">
        </div>
        <div class="field">
          <label>담당자명<span class="required">*</span></label>
          <input type="text" name="userName" id="userName" value="<%= userName %>" placeholder="실명 입력">
        </div>
        <div class="field">
          <label>비밀번호<span class="required">*</span></label>
          <input type="password" name="pw" id="pw" placeholder="6자 이상">
        </div>
        <div class="field">
          <label>비밀번호 확인<span class="required">*</span></label>
          <input type="password" name="pw2" id="pw2" placeholder="비밀번호 재입력">
        </div>
        <div class="field">
          <label>이메일<span class="required">*</span></label>
          <input type="email" name="email" id="email" value="<%= email %>" placeholder="example@email.com">
        </div>
        <div class="field">
          <label>연락처</label>
          <input type="text" name="phone" id="phone" value="<%= phone %>" placeholder="010-0000-0000">
        </div>
      </div>

      <!-- 원청기업/벤더 추가 정보 -->
      <div class="biz-section <%= ("admin".equals(role)||"vendor".equals(role)) ? "show" : "" %>" id="bizSection">
        <hr class="divider">
        <div class="section-label">업체 정보</div>
        <div class="form-grid">
          <div class="field full">
            <label>회사명<span class="required">*</span></label>
            <input type="text" name="companyNm" id="companyNm" value="<%= companyNm %>" placeholder="법인명 입력">
          </div>
          <div class="field" id="representField">
            <label>대표자명</label>
            <input type="text" name="represent" id="represent" value="<%= represent %>" placeholder="대표자 성명">
          </div>
          <div class="field" id="addressField">
            <label>회사 주소</label>
            <input type="text" name="address" id="address" value="<%= address %>" placeholder="소재지 주소">
          </div>
          <div class="field">
            <label>사업자등록번호<span class="required">*</span></label>
            <input type="text" name="bizNo" id="bizNo" value="<%= bizNo %>" placeholder="000-00-00000">
          </div>
          <div class="field">
            <label>법인등록번호<span class="required">*</span></label>
            <input type="text" name="corpNo" id="corpNo" value="<%= corpNo %>" placeholder="000000-0000000">
          </div>
          <div class="field full">
            <label>기술인증<span class="required">*</span></label>
            <input type="text" name="techCert" id="techCert" value="<%= techCert %>" placeholder="예: ISO9001, IATF16949">
          </div>
        </div>
      </div>

      <!-- scm은 회사명 따로 -->
      <div class="biz-section" id="scmSection">
        <hr class="divider">
        <div class="form-grid">
          <div class="field full">
            <label>소속 / 부서명</label>
            <input type="text" name="companyNm" placeholder="예: HMC SCM 운영팀" id="companyNmScm">
          </div>
        </div>
      </div>

      <button type="submit" class="btn-submit">가입 신청하기</button>
    </form>

    <div class="login-link">이미 계정이 있으신가요? <a href="login.jsp">로그인</a></div>
  </div>
</div>

<script>
var currentRole = '<%= role.isEmpty() ? "" : role %>';

function selectRole(role, el) {
  currentRole = role;
  document.getElementById('roleInput').value = role;
  document.querySelectorAll('.role-tab').forEach(function(t){ t.classList.remove('active'); });
  el.classList.add('active');

  var bizSection = document.getElementById('bizSection');
  var scmSection = document.getElementById('scmSection');

  if (role === 'admin' || role === 'vendor') {
    bizSection.classList.add('show');
    scmSection.classList.remove('show');
  } else if (role === 'scm') {
    bizSection.classList.remove('show');
    scmSection.classList.add('show');
  } else {
    bizSection.classList.remove('show');
    scmSection.classList.remove('show');
  }
}

function validateForm() {
  var role = document.getElementById('roleInput').value;
  if (!role) { alert('역할을 선택해주세요.'); return false; }

  var required = ['userId','userName','pw','pw2','email'];
  var missing = [];

  required.forEach(function(id) {
    var el = document.getElementById(id);
    if (!el || !el.value.trim()) {
      if (el) el.classList.add('invalid');
      missing.push(id);
    } else {
      if (el) el.classList.remove('invalid');
    }
  });

  if (document.getElementById('pw').value !== document.getElementById('pw2').value) {
    alert('비밀번호가 일치하지 않습니다.');
    return false;
  }

  if (role === 'admin' || role === 'vendor') {
    ['companyNm','bizNo','corpNo','techCert'].forEach(function(id) {
      var el = document.getElementById(id);
      if (!el || !el.value.trim()) {
        if (el) el.classList.add('invalid');
        missing.push(id);
      } else {
        if (el) el.classList.remove('invalid');
      }
    });
  }

  if (missing.length > 0) {
    alert('필수 항목을 모두 입력해주세요.');
    return false;
  }
  return true;
}

document.querySelectorAll('input').forEach(function(el) {
  el.addEventListener('input', function() { this.classList.remove('invalid'); });
});
</script>
</body>
</html>
