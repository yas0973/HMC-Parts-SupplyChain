<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, util.DBUtil, java.util.Base64" %>
<%
    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    String roleLabel = (String) session.getAttribute("roleLabel");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendorOrAdmin = "vendor".equals(role) || "admin".equals(role);
    String initials = company != null && company.length() >= 2 ? company.substring(0,2) : company;

    String message = ""; String msgType = "success";

    // ── POST 처리 ──────────────────────────────────────────────
    String action = request.getParameter("action");
    if ("saveInfo".equals(action)) {
        String newEmail = request.getParameter("email") != null ? request.getParameter("email").trim() : "";
        String newPhone = request.getParameter("phone") != null ? request.getParameter("phone").trim() : "";
        Connection connW = null; PreparedStatement psW = null;
        try {
            connW = DBUtil.getConnection();
            psW = connW.prepareStatement("UPDATE users SET email=?, phone=? WHERE user_id=?");
            psW.setString(1, newEmail);
            psW.setString(2, newPhone);
            psW.setString(3, userId);
            psW.executeUpdate();
            message = "기본 정보가 저장되었습니다!"; msgType = "success";
        } catch (Exception e) {
            message = "저장 오류: " + e.getMessage(); msgType = "error";
        } finally { DBUtil.close(connW, psW, null); }
    }

    if ("changePw".equals(action)) {
        String curPw  = request.getParameter("curPw")  != null ? request.getParameter("curPw").trim()  : "";
        String newPw  = request.getParameter("newPw")  != null ? request.getParameter("newPw").trim()  : "";
        String confPw = request.getParameter("confPw") != null ? request.getParameter("confPw").trim() : "";
        if (!newPw.equals(confPw)) {
            message = "새 비밀번호가 일치하지 않습니다."; msgType = "error";
        } else if (newPw.length() < 6) {
            message = "새 비밀번호는 6자 이상이어야 합니다."; msgType = "error";
        } else {
            Connection connW = null; PreparedStatement psW = null; ResultSet rsW = null;
            try {
                connW = DBUtil.getConnection();
                psW = connW.prepareStatement("SELECT user_id FROM users WHERE user_id=? AND password=?");
                psW.setString(1, userId); psW.setString(2, curPw);
                rsW = psW.executeQuery();
                if (!rsW.next()) {
                    message = "현재 비밀번호가 올바르지 않습니다."; msgType = "error";
                } else {
                    rsW.close(); psW.close();
                    psW = connW.prepareStatement("UPDATE users SET password=? WHERE user_id=?");
                    psW.setString(1, newPw); psW.setString(2, userId);
                    psW.executeUpdate();
                    message = "비밀번호가 변경되었습니다!"; msgType = "success";
                }
            } catch (Exception e) {
                message = "오류: " + e.getMessage(); msgType = "error";
            } finally { DBUtil.close(connW, psW, rsW); }
        }
    }

    // ── 서류 삭제 처리 ──────────────────────────────────────────
    if ("deleteDocs".equals(action) && isVendorOrAdmin) {
        Connection connW = null; PreparedStatement psW = null; ResultSet rsW = null;
        try {
            connW = DBUtil.getConnection();
            psW = connW.prepareStatement("SELECT company_id FROM users WHERE user_id=?");
            psW.setString(1, userId);
            rsW = psW.executeQuery();
            int companyId = rsW.next() ? rsW.getInt("company_id") : 0;
            rsW.close(); psW.close();
            if (companyId > 0) {
                psW = connW.prepareStatement(
                    "UPDATE vendors SET biz_doc=NULL, biz_doc_type=NULL, corp_doc=NULL, corp_doc_type=NULL WHERE vendor_id=?");
                psW.setInt(1, companyId);
                psW.executeUpdate();
                message = "서류가 삭제되었습니다. 재등록해주세요."; msgType = "success";
            }
        } catch (Exception e) {
            message = "삭제 오류: " + e.getMessage(); msgType = "error";
        } finally { DBUtil.close(connW, psW, rsW); }
    }

    // ── 서류 저장 처리 ──────────────────────────────────────────
    if ("saveDocs".equals(action) && isVendorOrAdmin) {
        String bizBase64  = request.getParameter("bizBase64");
        String bizType    = request.getParameter("bizType");
        String corpBase64 = request.getParameter("corpBase64");
        String corpType   = request.getParameter("corpType");

        Connection connW = null; PreparedStatement psW = null; ResultSet rsW = null;
        try {
            connW = DBUtil.getConnection();
            // company_id 조회
            psW = connW.prepareStatement("SELECT company_id FROM users WHERE user_id=?");
            psW.setString(1, userId);
            rsW = psW.executeQuery();
            int companyId = rsW.next() ? rsW.getInt("company_id") : 0;
            rsW.close(); psW.close();

            if (companyId > 0) {
                // biz_doc 저장
                if (bizBase64 != null && !bizBase64.isEmpty()) {
                    String base64Data = bizBase64.contains(",") ? bizBase64.split(",")[1] : bizBase64;
                    byte[] bizBytes = Base64.getDecoder().decode(base64Data);
                    psW = connW.prepareStatement(
                        "UPDATE vendors SET biz_doc=?, biz_doc_type=? WHERE vendor_id=?");
                    psW.setBytes(1, bizBytes);
                    psW.setString(2, bizType != null ? bizType : "image/jpeg");
                    psW.setInt(3, companyId);
                    psW.executeUpdate(); psW.close();
                }
                // corp_doc 저장
                if (corpBase64 != null && !corpBase64.isEmpty()) {
                    String base64Data = corpBase64.contains(",") ? corpBase64.split(",")[1] : corpBase64;
                    byte[] corpBytes = Base64.getDecoder().decode(base64Data);
                    psW = connW.prepareStatement(
                        "UPDATE vendors SET corp_doc=?, corp_doc_type=? WHERE vendor_id=?");
                    psW.setBytes(1, corpBytes);
                    psW.setString(2, corpType != null ? corpType : "image/jpeg");
                    psW.setInt(3, companyId);
                    psW.executeUpdate(); psW.close();
                }
                message = "서류가 저장되었습니다!"; msgType = "success";
            } else {
                message = "업체 정보를 찾을 수 없습니다."; msgType = "error";
            }
        } catch (Exception e) {
            message = "서류 저장 오류: " + e.getMessage(); msgType = "error";
        } finally { DBUtil.close(connW, psW, rsW); }
    }

    // ── DB 조회 ────────────────────────────────────────────────
    String email="", phone="", joinDate="-", bizNo="-", corpNo="-", techCert="-";
    String vendorAddr="-", represent="-", creditGrade="-", tier="-";
    int totalBids=0, totalApps=0, totalDeliveries=0;
    boolean hasBizDoc=false, hasCorpDoc=false;
    String bizDocBase64="", bizDocType="", corpDocBase64="", corpDocType="";

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        // 유저 + 벤더 정보
        ps = conn.prepareStatement(
            "SELECT u.email, u.phone, u.join_date, u.biz_no, u.corp_no, u.tech_cert, " +
            "v.address, v.representative, v.credit_grade, v.tier, " +
            "v.biz_doc, v.biz_doc_type, v.corp_doc, v.corp_doc_type " +
            "FROM users u LEFT JOIN vendors v ON u.company_id=v.vendor_id WHERE u.user_id=?");
        ps.setString(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            email      = rs.getString("email")         != null ? rs.getString("email")         : "";
            phone      = rs.getString("phone")         != null ? rs.getString("phone")         : "";
            joinDate   = rs.getString("join_date")     != null ? rs.getString("join_date").substring(0,10) : "-";
            bizNo      = rs.getString("biz_no")        != null ? rs.getString("biz_no")        : "-";
            corpNo     = rs.getString("corp_no")       != null ? rs.getString("corp_no")       : "-";
            techCert   = rs.getString("tech_cert")     != null ? rs.getString("tech_cert")     : "-";
            vendorAddr = rs.getString("address")       != null ? rs.getString("address")       : "-";
            represent  = rs.getString("representative")!= null ? rs.getString("representative"): "-";
            creditGrade= rs.getString("credit_grade")  != null ? rs.getString("credit_grade")  : "-";
            tier       = rs.getString("tier")          != null ? rs.getString("tier")          : "-";
            // 서류 조회
            byte[] bizBytes = rs.getBytes("biz_doc");
            if (bizBytes != null && bizBytes.length > 0) {
                hasBizDoc   = true;
                bizDocBase64 = Base64.getEncoder().encodeToString(bizBytes);
                bizDocType   = rs.getString("biz_doc_type") != null ? rs.getString("biz_doc_type") : "image/jpeg";
            }
            byte[] corpBytes = rs.getBytes("corp_doc");
            if (corpBytes != null && corpBytes.length > 0) {
                hasCorpDoc    = true;
                corpDocBase64 = Base64.getEncoder().encodeToString(corpBytes);
                corpDocType   = rs.getString("corp_doc_type") != null ? rs.getString("corp_doc_type") : "image/jpeg";
            }
        }
        rs.close(); ps.close();

        // 활동 통계
        ps = conn.prepareStatement("SELECT COUNT(*) FROM bids WHERE creator_id=?");
        ps.setString(1, userId); rs = ps.executeQuery();
        if (rs.next()) totalBids = rs.getInt(1); rs.close(); ps.close();

        if ("vendor".equals(role)) {
            ps = conn.prepareStatement(
                "SELECT COUNT(*) FROM bid_applications ba JOIN users u ON u.company_id=ba.vendor_id WHERE u.user_id=?");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) totalApps = rs.getInt(1); rs.close(); ps.close();
        }

        ps = conn.prepareStatement(
            "SELECT COUNT(*) FROM deliveries d JOIN users u ON u.company_id=d.vendor_id WHERE u.user_id=?");
        ps.setString(1, userId); rs = ps.executeQuery();
        if (rs.next()) totalDeliveries = rs.getInt(1); rs.close(); ps.close();

    } catch (Exception e) {
        e.printStackTrace();
    } finally { DBUtil.close(conn, ps, rs); }
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 내 프로필</title>
<link rel="stylesheet" href="/project/style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--primary:#003DA5;--accent:#00AAD4;--panel:#0D1B2A;--surface:#112240;--sidebar:#0a1520;--border:rgba(0,170,212,.2);--text:#E8F0FE;--muted:#7A8FA6;--success:#00E5A0;--warning:#F59E0B;--danger:#EF4444}
html,body{font-family:'Noto Sans KR',sans-serif;background:var(--panel);color:var(--text);height:100%}
.wrapper{display:flex;flex-direction:column;min-height:100vh}
.layout{flex:1;display:grid;grid-template-columns:220px 1fr}
.main{padding:28px;overflow-y:auto}
/* 푸터 강제 수평 보정 */
.footer,.footer *{writing-mode:horizontal-tb !important;text-orientation:mixed !important}
.footer-line{display:flex !important;flex-direction:row !important;align-items:center !important;flex-wrap:wrap;gap:16px}
.footer-links{display:flex !important;flex-direction:row !important;gap:12px !important}
.footer-link{white-space:nowrap !important;display:inline !important}
.page-title{font-size:22px;font-weight:700;letter-spacing:1px;margin-bottom:24px}
.page-title span{color:var(--accent);font-weight:400;font-size:16px}

/* 탭 */
.tabs{display:flex;gap:4px;margin-bottom:24px;border-bottom:1px solid var(--border);padding-bottom:0}
.tab-btn{padding:10px 20px;font-size:13px;font-weight:500;cursor:pointer;color:var(--muted);background:none;border:none;border-bottom:2px solid transparent;font-family:'Noto Sans KR',sans-serif;transition:all .2s;margin-bottom:-1px}
.tab-btn:hover{color:var(--text)}
.tab-btn.active{color:var(--accent);border-bottom-color:var(--accent)}
.tab-content{display:none}
.tab-content.active{display:block}

/* 카드 */
.profile-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:24px;margin-bottom:20px}
.card-header{font-size:12px;font-weight:600;color:var(--accent);letter-spacing:1.5px;text-transform:uppercase;border-left:3px solid var(--accent);padding-left:10px;margin-bottom:20px}

/* 헤더 */
.profile-hero{display:flex;align-items:center;gap:24px;padding:28px;background:var(--surface);border:1px solid var(--border);border-radius:12px;margin-bottom:20px;background:linear-gradient(135deg,#112240 60%,rgba(0,170,212,.06) 100%)}
.avatar-lg{width:80px;height:80px;border-radius:50%;background:linear-gradient(135deg,#003DA5,#00AAD4);display:flex;align-items:center;justify-content:center;font-size:28px;font-weight:700;color:#fff;border:3px solid rgba(0,170,212,.4);box-shadow:0 0 24px rgba(0,170,212,.25);flex-shrink:0;overflow:hidden}
.avatar-lg img{width:100%;height:100%;object-fit:cover;border-radius:50%}
.avatar-wrap{position:relative;flex-shrink:0;cursor:pointer}
.avatar-wrap:hover .avatar-overlay{opacity:1}
.avatar-overlay{position:absolute;inset:0;border-radius:50%;background:rgba(0,0,0,.55);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;opacity:0;transition:opacity .2s;cursor:pointer}
.avatar-overlay i{font-size:16px;color:#fff}
.avatar-overlay span{font-size:10px;color:rgba(255,255,255,.8);letter-spacing:.5px}
.profile-info .name{font-size:20px;font-weight:700;margin-bottom:4px}
.profile-info .meta{font-size:13px;color:var(--muted);margin-bottom:10px}
.role-pill{display:inline-block;padding:3px 12px;border-radius:20px;font-size:11px;font-weight:600;letter-spacing:1px;background:rgba(0,170,212,.15);border:1px solid rgba(0,170,212,.35);color:var(--accent)}

/* 폼 */
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.form-group{display:flex;flex-direction:column;gap:6px}
.form-group.full{grid-column:1/-1}
.form-label{font-size:12px;color:var(--muted);letter-spacing:.5px}
.form-input{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:8px;padding:10px 14px;color:var(--text);font-family:'Noto Sans KR',sans-serif;font-size:13px;outline:none;transition:border-color .2s,background .2s;width:100%}
.form-input:focus{border-color:var(--accent);background:rgba(0,170,212,.06)}
.form-input:disabled{opacity:.5;cursor:not-allowed;background:rgba(255,255,255,.02)}
.form-input::placeholder{color:rgba(122,143,166,.4)}
.form-input.mono{font-family:'Share Tech Mono',monospace;color:var(--accent)}

/* 구분선 */
.section-divider{border:none;border-top:1px solid rgba(255,255,255,.07);margin:20px 0}

/* 버튼 */
.btn{border:none;border-radius:8px;padding:9px 18px;cursor:pointer;font-size:13px;font-weight:500;font-family:'Noto Sans KR',sans-serif;transition:all .2s}
.btn-accent{background:rgba(0,170,212,.15);border:1px solid rgba(0,170,212,.4);color:var(--accent)}
.btn-accent:hover{background:rgba(0,170,212,.25)}
.btn-ghost{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);color:var(--muted)}
.btn-ghost:hover{background:rgba(255,255,255,.08)}
.btn-danger{background:rgba(239,68,68,.15);border:1px solid rgba(239,68,68,.3);color:var(--danger)}
.btn-area{display:flex;gap:10px;margin-top:20px}

/* 통계 */
.stat-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
.stat-card{background:rgba(0,170,212,.05);border:1px solid var(--border);border-radius:10px;padding:18px;text-align:center;position:relative;overflow:hidden}
.stat-card::before{content:'';position:absolute;top:0;left:0;right:0;height:2px}
.stat-card.c1::before{background:linear-gradient(90deg,#003DA5,#00AAD4)}
.stat-card.c2::before{background:linear-gradient(90deg,#00AAD4,#00E5A0)}
.stat-card.c3::before{background:linear-gradient(90deg,#F59E0B,#EF4444)}
.stat-num{font-size:32px;font-weight:700;font-family:'Share Tech Mono',monospace;color:var(--accent)}
.stat-lbl{font-size:12px;color:var(--muted);margin-top:4px}

/* 보안 */
.security-info{display:flex;align-items:center;gap:10px;background:rgba(0,229,160,.06);border:1px solid rgba(0,229,160,.15);border-radius:8px;padding:12px 16px;margin-bottom:20px;font-size:13px;color:var(--success)}
.pw-bars{display:flex;gap:4px;margin:6px 0 4px}
.pw-bar{height:3px;flex:1;border-radius:2px;background:rgba(255,255,255,.08);transition:background .3s}
.pw-bar.active.weak{background:var(--danger)}
.pw-bar.active.medium{background:var(--warning)}
.pw-bar.active.strong{background:var(--success)}
.pw-label{font-size:11px;color:var(--muted)}

/* 서류 업로드 */
  .doc-dropzone { border:2px dashed rgba(0,170,212,.25); border-radius:10px; padding:28px 20px; text-align:center; cursor:pointer; transition:all .2s; background:rgba(255,255,255,.02); }
  .doc-dropzone:hover, .doc-dropzone.drag-over { border-color:var(--accent); background:rgba(0,170,212,.06); }
  .drop-icon { font-size:28px; color:var(--accent); opacity:.5; margin-bottom:10px; transition:opacity .2s; }
  .doc-dropzone:hover .drop-icon { opacity:1; }
  .drop-text { font-size:13px; color:var(--muted); margin-bottom:4px; }
  .drop-sub  { font-size:11px; color:rgba(122,143,166,.5); }
  .file-result { margin-top:10px; background:rgba(0,229,160,.05); border:1px solid rgba(0,229,160,.2); border-radius:8px; overflow:hidden; }
  .file-result-inner { display:flex; align-items:center; gap:10px; padding:12px 14px; }
  .file-result-info { flex:1; min-width:0; }
  .file-result-name { font-size:13px; color:var(--text); font-weight:500; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .file-result-size { font-size:11px; color:var(--muted); margin-top:2px; }
  .file-progress { height:3px; background:rgba(255,255,255,.06); }
  .file-progress-bar { height:100%; background:linear-gradient(90deg,var(--accent),var(--success)); width:0%; transition:width .6s ease; border-radius:2px; }
  .doc-btn-view { display:inline-flex; align-items:center; gap:5px; padding:4px 10px; border-radius:5px; font-size:11px; cursor:pointer; background:rgba(0,170,212,.1); border:1px solid rgba(0,170,212,.3); color:var(--accent); font-family:'Noto Sans KR',sans-serif; transition:all .2s; white-space:nowrap; }
  .doc-btn-view:hover { background:rgba(0,170,212,.2); }
  .doc-btn-del { width:26px; height:26px; border-radius:5px; cursor:pointer; background:rgba(239,68,68,.1); border:1px solid rgba(239,68,68,.3); color:var(--danger); display:flex; align-items:center; justify-content:center; font-size:11px; transition:all .2s; }
  .doc-btn-del:hover { background:rgba(239,68,68,.25); }
  .badge-submitted { display:inline-block; padding:2px 8px; border-radius:4px; font-size:10px; font-weight:700; background:rgba(0,229,160,.15); border:1px solid rgba(0,229,160,.3); color:var(--success); margin-left:8px; vertical-align:middle; letter-spacing:.5px; }
  .blind-card { border:1px solid var(--border); border-radius:10px; overflow:hidden; cursor:pointer; transition:all .2s; background:rgba(255,255,255,.02); }
  .blind-card:hover { border-color:var(--accent); box-shadow:0 0 16px rgba(0,170,212,.15); }
  .blind-img-wrap { position:relative; height:140px; overflow:hidden; background:#0a1015; }
  .blind-img { width:100%; height:100%; object-fit:cover; filter:blur(12px) brightness(.6); }
  .blind-overlay { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; color:rgba(255,255,255,.85); background:rgba(0,0,0,.3); }
  .blind-footer { display:flex; align-items:center; gap:8px; padding:10px 14px; border-top:1px solid var(--border); background:rgba(255,255,255,.02); }
  .blind-pdf { display:flex; flex-direction:column; align-items:center; justify-content:center; height:180px; cursor:pointer; }
  .blind-empty { display:flex; flex-direction:column; align-items:center; justify-content:center; height:180px; cursor:default; border-style:dashed; }
  .blind-empty:hover { border-color:var(--border) !important; box-shadow:none !important; }


.toggle-row{display:flex;align-items:center;justify-content:space-between;padding:14px 0;border-bottom:1px solid rgba(255,255,255,.04)}
.toggle-row:last-child{border-bottom:none}
.toggle-info .tl{font-size:13px;color:var(--text);font-weight:500}
.toggle-info .td{font-size:12px;color:var(--muted);margin-top:3px}
.toggle{position:relative;width:44px;height:24px;flex-shrink:0}
.toggle input{opacity:0;width:0;height:0}
.toggle-slider{position:absolute;cursor:pointer;inset:0;background:rgba(255,255,255,.1);border-radius:24px;transition:.3s;border:1px solid rgba(255,255,255,.15)}
.toggle-slider::before{content:'';position:absolute;width:18px;height:18px;border-radius:50%;background:#fff;left:2px;top:2px;transition:.3s}
.toggle input:checked+.toggle-slider{background:rgba(0,170,212,.4);border-color:var(--accent)}
.toggle input:checked+.toggle-slider::before{transform:translateX(20px);background:var(--accent)}

/* 메시지 */
.flash-msg{padding:12px 16px;border-radius:8px;margin-bottom:16px;font-size:13px;display:flex;align-items:center;gap:8px}
.flash-msg.success{background:rgba(0,229,160,.08);border:1px solid rgba(0,229,160,.2);color:var(--success)}
.flash-msg.error{background:rgba(239,68,68,.08);border:1px solid rgba(239,68,68,.25);color:var(--danger)}
.js-msg{display:none}
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="page-title">내 프로필 <span>/ 계정 관리</span></div>

      <!-- 서버 메시지 -->
      <% if (!message.isEmpty()) { %>
      <div class="flash-msg <%= msgType %>">
        <i class="fas <%= "success".equals(msgType) ? "fa-check-circle" : "fa-exclamation-circle" %>"></i>
        <%= message %>
      </div>
      <% } %>

      <!-- 프로필 헤더 -->
      <div class="profile-hero">
        <div class="avatar-wrap" onclick="document.getElementById('avatarInput').click()">
          <div class="avatar-lg" id="avatarBox">
            <span id="avatarInitials"><%= initials %></span>
          </div>
          <div class="avatar-overlay">
            <i class="fas fa-camera"></i><span>변경</span>
          </div>
        </div>
        <input type="file" id="avatarInput" accept="image/*" style="display:none" onchange="previewAvatar(this)">
        <div class="profile-info">
          <div class="name"><%= company %></div>
          <div class="meta"><%= email %> · <%= joinDate %> 가입</div>
          <span class="role-pill"><%= roleLabel %></span>
          <div style="margin-top:10px;display:flex;gap:8px;">
            <button class="btn btn-ghost" style="font-size:11px;padding:5px 12px" onclick="document.getElementById('avatarInput').click()">
              <i class="fas fa-camera" style="margin-right:5px"></i>사진 변경
            </button>
          </div>
        </div>
      </div>

      <!-- 탭 -->
      <div class="tabs">
        <button class="tab-btn active" onclick="switchTab('info',this)"><i class="fas fa-user" style="margin-right:6px"></i>기본 정보</button>
        <button class="tab-btn" onclick="switchTab('stat',this)"><i class="fas fa-chart-bar" style="margin-right:6px"></i>활동 현황</button>
        <button class="tab-btn" onclick="switchTab('security',this)"><i class="fas fa-lock" style="margin-right:6px"></i>보안</button>
        <button class="tab-btn" onclick="switchTab('notify',this)"><i class="fas fa-bell" style="margin-right:6px"></i>알림 설정</button>
      </div>

      <!-- ── 탭1: 기본 정보 ── -->
      <div id="tab-info" class="tab-content active">
        <div id="js-msg-info" class="flash-msg js-msg"></div>
        <div class="profile-card">
          <div class="card-header">기본 정보</div>
          <form method="post" action="profile.jsp">
            <input type="hidden" name="action" value="saveInfo">
            <div class="form-grid">
              <div class="form-group">
                <label class="form-label">회사명 / 이름</label>
                <input class="form-input" type="text" value="<%= company %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">아이디</label>
                <input class="form-input" type="text" value="<%= userId %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">이메일</label>
                <input class="form-input" type="email" name="email" id="emailInput" value="<%= email %>" placeholder="이메일 입력">
              </div>
              <div class="form-group">
                <label class="form-label">연락처</label>
                <input class="form-input" type="text" name="phone" id="phoneInput" value="<%= phone %>" placeholder="010-0000-0000">
              </div>
              <div class="form-group">
                <label class="form-label">역할</label>
                <input class="form-input" type="text" value="<%= roleLabel %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">가입일</label>
                <input class="form-input" type="text" value="<%= joinDate %>" disabled>
              </div>
            </div>

            <!-- 원청/벤더만: 사업 정보 -->
            <% if (isVendorOrAdmin) { %>
            <hr class="section-divider">
            <div class="card-header" style="margin-bottom:16px;">업체 정보</div>
            <div class="form-grid">
              <div class="form-group">
                <label class="form-label">사업자등록번호</label>
                <input class="form-input mono" type="text" value="<%= bizNo %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">법인등록번호</label>
                <input class="form-input mono" type="text" value="<%= corpNo %>" disabled>
              </div>
              <div class="form-group full">
                <label class="form-label">기술인증</label>
                <input class="form-input" type="text" value="<%= techCert %>" disabled>
              </div>
              <% if ("vendor".equals(role)) { %>
              <div class="form-group">
                <label class="form-label">대표자</label>
                <input class="form-input" type="text" value="<%= represent %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">신용등급</label>
                <input class="form-input" type="text" value="<%= creditGrade %>" disabled style="color:#00E5A0;font-weight:700">
              </div>
              <div class="form-group">
                <label class="form-label">차수</label>
                <input class="form-input" type="text" value="<%= tier %>" disabled>
              </div>
              <div class="form-group">
                <label class="form-label">주소</label>
                <input class="form-input" type="text" value="<%= vendorAddr %>" disabled>
              </div>
              <% } %>
            </div>
            <% } %>

            <div class="btn-area">
              <button type="submit" class="btn btn-accent"><i class="fas fa-save" style="margin-right:6px"></i>변경사항 저장</button>
            </div>
          </form>
        </div>

        <!-- 서류 업로드 (vendors DB 저장) -->
        <% if (isVendorOrAdmin) { %>
        <div class="profile-card">
          <div class="card-header">사업 서류 등록</div>

          <% if (!hasBizDoc) { %>
          <!-- 업로드 영역 -->
          <div id="docUploadArea">
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
              <div>
                <div class="form-label" style="margin-bottom:10px;">사업자 등록증 <span style="color:var(--danger)">*</span></div>
                <input type="file" id="bizFile" accept=".pdf,.jpg,.jpeg,.png" style="display:none" onchange="handleFile(this,'biz')">
                <div class="doc-dropzone" id="bizDrop" onclick="document.getElementById('bizFile').click()"
                     ondragover="dragOver(event)" ondragleave="dragLeave(event,'bizDrop')" ondrop="dropFile(event,'biz')">
                  <div class="drop-icon"><i class="fas fa-file-alt"></i></div>
                  <div class="drop-text">클릭하거나 파일을 드래그하세요</div>
                  <div class="drop-sub">PDF, JPG, PNG · 최대 10MB</div>
                </div>
                <div class="file-result" id="bizResult" style="display:none">
                  <div class="file-result-inner">
                    <i class="fas fa-file-check" style="color:var(--success)"></i>
                    <div class="file-result-info">
                      <div class="file-result-name" id="bizName"></div>
                      <div class="file-result-size" id="bizSize"></div>
                    </div>
                    <div style="display:flex; gap:6px; margin-left:auto">
                      <button class="doc-btn-view" onclick="previewDocLocal('biz')"><i class="fas fa-eye"></i> 미리보기</button>
                      <button class="doc-btn-del" onclick="removeFile('biz')"><i class="fas fa-times"></i></button>
                    </div>
                  </div>
                  <div class="file-progress"><div class="file-progress-bar" id="bizBar"></div></div>
                </div>
              </div>
              <div>
                <div class="form-label" style="margin-bottom:10px;">법인 등록증</div>
                <input type="file" id="corpFile" accept=".pdf,.jpg,.jpeg,.png" style="display:none" onchange="handleFile(this,'corp')">
                <div class="doc-dropzone" id="corpDrop" onclick="document.getElementById('corpFile').click()"
                     ondragover="dragOver(event)" ondragleave="dragLeave(event,'corpDrop')" ondrop="dropFile(event,'corp')">
                  <div class="drop-icon"><i class="fas fa-building"></i></div>
                  <div class="drop-text">클릭하거나 파일을 드래그하세요</div>
                  <div class="drop-sub">PDF, JPG, PNG · 최대 10MB</div>
                </div>
                <div class="file-result" id="corpResult" style="display:none">
                  <div class="file-result-inner">
                    <i class="fas fa-file-check" style="color:var(--success)"></i>
                    <div class="file-result-info">
                      <div class="file-result-name" id="corpName"></div>
                      <div class="file-result-size" id="corpSize"></div>
                    </div>
                    <div style="display:flex; gap:6px; margin-left:auto">
                      <button class="doc-btn-view" onclick="previewDocLocal('corp')"><i class="fas fa-eye"></i> 미리보기</button>
                      <button class="doc-btn-del" onclick="removeFile('corp')"><i class="fas fa-times"></i></button>
                    </div>
                  </div>
                  <div class="file-progress"><div class="file-progress-bar" id="corpBar"></div></div>
                </div>
              </div>
            </div>
            <!-- hidden form으로 Base64 DB 전송 -->
            <form method="post" action="profile.jsp" id="docForm">
              <input type="hidden" name="action" value="saveDocs">
              <input type="hidden" name="bizBase64"  id="bizBase64Input">
              <input type="hidden" name="bizType"    id="bizTypeInput">
              <input type="hidden" name="corpBase64" id="corpBase64Input">
              <input type="hidden" name="corpType"   id="corpTypeInput">
            </form>
            <div class="btn-area" style="margin-top:20px">
              <button class="btn btn-accent" onclick="saveDocs()"><i class="fas fa-upload" style="margin-right:6px"></i>서류 제출 (DB 저장)</button>
            </div>
          </div>
          <% } else { %>
          <!-- 이미 서류 등록됨 → DB에서 불러와 표시 -->
          <div>
            <div style="display:flex; align-items:center; gap:8px; margin-bottom:16px; background:rgba(0,229,160,.07); border:1px solid rgba(0,229,160,.2); border-radius:8px; padding:10px 14px; font-size:13px; color:var(--success);">
              <i class="fas fa-shield-alt"></i> 서류가 등록되어 있습니다. 클릭하면 확인할 수 있습니다.
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
              <div>
                <div class="form-label" style="margin-bottom:10px;">사업자 등록증 <span class="badge-submitted">등록완료</span></div>
                <% if (bizDocType.startsWith("image")) { %>
                <div class="blind-card" onclick="openDocImg('data:<%= bizDocType %>;base64,<%= bizDocBase64 %>')">
                  <div class="blind-img-wrap">
                    <img src="data:<%= bizDocType %>;base64,<%= bizDocBase64 %>" alt="" class="blind-img">
                    <div class="blind-overlay"><i class="fas fa-lock" style="font-size:22px; margin-bottom:8px;"></i><div style="font-size:12px; font-weight:600">클릭하여 확인</div></div>
                  </div>
                  <div class="blind-footer"><i class="fas fa-file-alt" style="color:var(--accent)"></i><span style="font-size:12px; color:var(--muted)">사업자 등록증</span></div>
                </div>
                <% } else { %>
                <div class="blind-card blind-pdf" onclick="alert('PDF 미리보기는 준비 중입니다.')">
                  <i class="fas fa-file-pdf" style="font-size:32px; color:#EF4444; margin-bottom:10px"></i>
                  <div style="font-size:13px; color:var(--muted)">사업자 등록증 (PDF)</div>
                </div>
                <% } %>
              </div>
              <div>
                <div class="form-label" style="margin-bottom:10px;">법인 등록증
                  <% if (hasCorpDoc) { %><span class="badge-submitted">등록완료</span><% } else { %><span style="font-size:11px; color:var(--muted)">미등록</span><% } %>
                </div>
                <% if (hasCorpDoc && corpDocType.startsWith("image")) { %>
                <div class="blind-card" onclick="openDocImg('data:<%= corpDocType %>;base64,<%= corpDocBase64 %>')">
                  <div class="blind-img-wrap">
                    <img src="data:<%= corpDocType %>;base64,<%= corpDocBase64 %>" alt="" class="blind-img">
                    <div class="blind-overlay"><i class="fas fa-lock" style="font-size:22px; margin-bottom:8px;"></i><div style="font-size:12px; font-weight:600">클릭하여 확인</div></div>
                  </div>
                  <div class="blind-footer"><i class="fas fa-building" style="color:var(--accent)"></i><span style="font-size:12px; color:var(--muted)">법인 등록증</span></div>
                </div>
                <% } else if (!hasCorpDoc) { %>
                <div class="blind-card blind-empty">
                  <i class="fas fa-folder-open" style="font-size:28px; color:rgba(122,143,166,.3); margin-bottom:8px"></i>
                  <div style="font-size:12px; color:rgba(122,143,166,.4)">미등록</div>
                </div>
                <% } %>
              </div>
            </div>
            <div class="btn-area" style="margin-top:20px">
              <form method="post" action="profile.jsp" style="margin:0">
                <input type="hidden" name="action" value="deleteDocs">
                <button type="submit" class="btn btn-ghost" onclick="return confirm('서류를 삭제하고 재등록하시겠습니까?')">
                  <i class="fas fa-edit" style="margin-right:6px"></i>서류 재등록
                </button>
              </form>
            </div>
          </div>
          <% } %>
        </div>

        <!-- 이미지 확대 모달 -->
        <div id="docImgModal" style="display:none; position:fixed; inset:0; z-index:9999; background:rgba(0,0,0,.85); align-items:center; justify-content:center;" onclick="this.style.display='none'">
          <img id="docImgModalSrc" src="" style="max-width:85vw; max-height:85vh; border-radius:12px; border:2px solid var(--accent)">
        </div>

        <!-- 로컬 미리보기 모달 -->
        <div id="docModal" style="display:none; position:fixed; inset:0; z-index:9999; background:rgba(0,0,0,.8); align-items:center; justify-content:center;" onclick="closeDocModal()">
          <div style="background:var(--surface); border:1px solid var(--border); border-radius:12px; overflow:hidden; width:700px; max-width:95vw;" onclick="event.stopPropagation()">
            <div style="display:flex; align-items:center; justify-content:space-between; padding:14px 20px; border-bottom:1px solid var(--border); background:rgba(0,170,212,.05);">
              <span style="font-size:13px; font-weight:600; color:var(--accent)" id="modalTitle">서류 미리보기</span>
              <div onclick="closeDocModal()" style="width:28px; height:28px; border-radius:50%; background:rgba(255,255,255,.07); border:1px solid rgba(255,255,255,.15); color:var(--text); display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:13px;">✕</div>
            </div>
            <div style="max-height:75vh; overflow:auto; text-align:center; background:#0a1015;">
              <img id="modalImg" src="" style="max-width:100%; display:none;">
              <iframe id="modalPdf" src="" style="width:100%; height:70vh; border:none; display:none;"></iframe>
              <div id="modalNoPreview" style="display:none; padding:40px; color:var(--muted); font-size:13px;"><i class="fas fa-file-alt" style="font-size:32px; display:block; margin-bottom:12px; color:var(--accent)"></i>미리보기를 지원하지 않습니다.</div>
            </div>
          </div>
        </div>



      <% } %><!-- /isVendorOrAdmin -->

      </div><!-- /tab-info -->

      <!-- ── 탭2: 활동 현황 ── -->
      <div id="tab-stat" class="tab-content">
        <div class="profile-card">
          <div class="card-header">활동 통계</div>
          <div class="stat-grid">
            <div class="stat-card c1">
              <div class="stat-num"><%= totalBids %></div>
              <div class="stat-lbl">등록 발주</div>
            </div>
            <% if ("vendor".equals(role)) { %>
            <div class="stat-card c2">
              <div class="stat-num"><%= totalApps %></div>
              <div class="stat-lbl">입찰 신청</div>
            </div>
            <% } else { %>
            <div class="stat-card c2">
              <div class="stat-num">-</div>
              <div class="stat-lbl">입찰 신청</div>
            </div>
            <% } %>
            <div class="stat-card c3">
              <div class="stat-num"><%= totalDeliveries %></div>
              <div class="stat-lbl">납품 건수</div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── 탭3: 보안 ── -->
      <div id="tab-security" class="tab-content">
        <div id="js-msg-pw" class="flash-msg js-msg"></div>
        <div class="profile-card">
          <div class="card-header">비밀번호 변경</div>
          <form method="post" action="profile.jsp">
            <input type="hidden" name="action" value="changePw">
            <div class="form-grid">
              <div class="form-group full">
                <label class="form-label">현재 비밀번호</label>
                <input class="form-input" type="password" name="curPw" placeholder="현재 비밀번호 입력">
              </div>
              <div class="form-group">
                <label class="form-label">새 비밀번호</label>
                <input class="form-input" type="password" name="newPw" id="newPwInput" placeholder="6자 이상" oninput="checkPwStrength(this.value)">
                <div class="pw-bars">
                  <div class="pw-bar" id="bar1"></div><div class="pw-bar" id="bar2"></div>
                  <div class="pw-bar" id="bar3"></div><div class="pw-bar" id="bar4"></div>
                </div>
                <div class="pw-label" id="pwLabel">비밀번호를 입력하세요</div>
              </div>
              <div class="form-group">
                <label class="form-label">새 비밀번호 확인</label>
                <input class="form-input" type="password" name="confPw" placeholder="비밀번호 재입력">
              </div>
            </div>
            <div class="btn-area">
              <button type="submit" class="btn btn-accent"><i class="fas fa-key" style="margin-right:6px"></i>비밀번호 변경</button>
            </div>
          </form>
        </div>

        <div class="profile-card">
          <div class="card-header">계정 관리</div>
          <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0">
            <div>
              <div style="font-size:13px;font-weight:500;color:var(--text)">로그아웃</div>
              <div style="font-size:12px;color:var(--muted);margin-top:3px">현재 세션을 종료하고 로그인 화면으로 이동합니다</div>
            </div>
            <a href="/project/dashboard.jsp?action=logout" class="btn btn-ghost">
              <i class="fas fa-sign-out-alt" style="margin-right:6px"></i>로그아웃
            </a>
          </div>
        </div>
      </div>

      <!-- ── 탭4: 알림 설정 ── -->
      <div id="tab-notify" class="tab-content">
        <div class="profile-card">
          <div class="card-header">이메일 알림</div>
          <div class="toggle-row">
            <div class="toggle-info"><div class="tl">발주 상태 변경 알림</div><div class="td">발주 상태가 변경될 때 이메일로 알림을 받습니다</div></div>
            <label class="toggle"><input type="checkbox" checked><span class="toggle-slider"></span></label>
          </div>
          <div class="toggle-row">
            <div class="toggle-info"><div class="tl">납품 일정 알림</div><div class="td">납품 마감 3일 전 이메일 알림을 받습니다</div></div>
            <label class="toggle"><input type="checkbox" checked><span class="toggle-slider"></span></label>
          </div>
          <div class="toggle-row">
            <div class="toggle-info"><div class="tl">시스템 공지 알림</div><div class="td">시스템 점검 및 공지사항 알림을 받습니다</div></div>
            <label class="toggle"><input type="checkbox" checked><span class="toggle-slider"></span></label>
          </div>
        </div>
        <div class="btn-area">
          <button class="btn btn-accent" onclick="alert('저장되었습니다.')"><i class="fas fa-save" style="margin-right:6px"></i>알림 설정 저장</button>
        </div>
      </div>

    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>

<script>
// 아바타 미리보기
function previewAvatar(input) {
  if (!input.files || !input.files[0]) return;
  var reader = new FileReader();
  reader.onload = function(e) {
    document.getElementById('avatarBox').innerHTML = '<img src="' + e.target.result + '" alt="프로필사진">';
    try { localStorage.setItem('profileImg_<%= userId %>', e.target.result); } catch(err) {}
  };
  reader.readAsDataURL(input.files[0]);
}
window.addEventListener('load', function() {
  try {
    var saved = localStorage.getItem('profileImg_<%= userId %>');
    if (saved) document.getElementById('avatarBox').innerHTML = '<img src="' + saved + '" alt="프로필사진">';
  } catch(err) {}
});

// ── 서류 업로드 ──────────────────────────────────────────
var docFiles = { biz: null, corp: null };

function handleFile(input, key) {
  if (!input.files || !input.files[0]) return;
  var file = input.files[0];
  if (file.size > 10 * 1024 * 1024) { alert('파일 크기는 10MB 이하여야 합니다.'); return; }
  docFiles[key] = file;
  document.getElementById(key+'Name').textContent = file.name;
  document.getElementById(key+'Size').textContent = formatFileSize(file.size);
  document.getElementById(key+'Drop').style.display = 'none';
  document.getElementById(key+'Result').style.display = 'block';
  setTimeout(function() { document.getElementById(key+'Bar').style.width = '100%'; }, 50);
}
function removeFile(key) {
  docFiles[key] = null;
  document.getElementById(key+'File').value = '';
  document.getElementById(key+'Drop').style.display = 'block';
  document.getElementById(key+'Result').style.display = 'none';
  document.getElementById(key+'Bar').style.width = '0%';
}
function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB';
  return (bytes/(1024*1024)).toFixed(1) + ' MB';
}
function dragOver(e) { e.preventDefault(); e.currentTarget.classList.add('drag-over'); }
function dragLeave(e, id) { document.getElementById(id).classList.remove('drag-over'); }
function dropFile(e, key) {
  e.preventDefault();
  e.currentTarget.classList.remove('drag-over');
  var file = e.dataTransfer.files[0];
  if (file) { docFiles[key] = file; handleFile({files:[file]}, key); }
}
function saveDocs() {
  if (!docFiles.biz) { alert('사업자 등록증은 필수 서류입니다.'); return; }
  var reader1 = new FileReader();
  reader1.onload = function(e) {
    document.getElementById('bizBase64Input').value = e.target.result;
    document.getElementById('bizTypeInput').value   = docFiles.biz.type;
    if (docFiles.corp) {
      var reader2 = new FileReader();
      reader2.onload = function(e2) {
        document.getElementById('corpBase64Input').value = e2.target.result;
        document.getElementById('corpTypeInput').value   = docFiles.corp.type;
        document.getElementById('docForm').submit();
      };
      reader2.readAsDataURL(docFiles.corp);
    } else {
      document.getElementById('docForm').submit();
    }
  };
  reader1.readAsDataURL(docFiles.biz);
}
function openDocImg(src) {
  document.getElementById('docImgModalSrc').src = src;
  document.getElementById('docImgModal').style.display = 'flex';
}

function setupBlind(key) {
  var file = docFiles[key];
  if (!file) return;
  if (file.type === 'application/pdf') {
    document.getElementById(key+'Blind').style.display = 'none';
    document.getElementById(key+'BlindPdf').style.display = 'flex';
    document.getElementById(key+'BlindPdfName').textContent = file.name;
  } else {
    var reader = new FileReader();
    reader.onload = function(e) { document.getElementById(key+'BlindImg').src = e.target.result; };
    reader.readAsDataURL(file);
    document.getElementById(key+'Blind').style.display = 'block';
    document.getElementById(key+'BlindPdf').style.display = 'none';
    document.getElementById(key+'BlindName').textContent = file.name;
  }
}
function editDocs() {
  document.getElementById('docUploadArea').style.display = 'block';
  document.getElementById('docSubmittedArea').style.display = 'none';
}
function previewDocLocal(key) {
  var file = docFiles[key]; if (!file) return;
  var modal = document.getElementById('docModal');
  var img = document.getElementById('modalImg');
  var pdf = document.getElementById('modalPdf');
  var noPreview = document.getElementById('modalNoPreview');
  document.getElementById('modalTitle').textContent = (key==='biz'?'사업자 등록증':'법인 등록증') + ' — ' + file.name;
  img.style.display = pdf.style.display = noPreview.style.display = 'none';
  var url = URL.createObjectURL(file);
  if (file.type === 'application/pdf') { pdf.src = url; pdf.style.display = 'block'; }
  else if (file.type.startsWith('image/')) { img.src = url; img.style.display = 'block'; }
  else { noPreview.style.display = 'block'; }
  modal.style.display = 'flex';
}
function closeDocModal() {
  document.getElementById('docModal').style.display = 'none';
  document.getElementById('modalPdf').src = '';
}

// 탭 전환
function switchTab(name, btn) {
  document.querySelectorAll('.tab-content').forEach(function(t){ t.classList.remove('active'); });
  document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('active'); });
  document.getElementById('tab-' + name).classList.add('active');
  btn.classList.add('active');
}

// 비밀번호 강도
function checkPwStrength(pw) {
  var bars  = [document.getElementById('bar1'),document.getElementById('bar2'),document.getElementById('bar3'),document.getElementById('bar4')];
  var label = document.getElementById('pwLabel');
  bars.forEach(function(b){ b.className='pw-bar'; });
  if (!pw) { label.textContent='비밀번호를 입력하세요'; label.style.color='var(--muted)'; return; }
  var score=0;
  if (pw.length>=6)  score++;
  if (pw.length>=10) score++;
  if (/[A-Z]/.test(pw)||/[0-9]/.test(pw)) score++;
  if (/[^A-Za-z0-9]/.test(pw)) score++;
  var cls=score<=1?'weak':score<=2?'medium':'strong';
  var lbls={weak:'약함',medium:'보통',strong:'강함'};
  var clrs={weak:'var(--danger)',medium:'var(--warning)',strong:'var(--success)'};
  for(var i=0;i<score;i++) bars[i].classList.add('active',cls);
  label.textContent='비밀번호 강도: '+lbls[cls];
  label.style.color=clrs[cls];
}

// URL 파라미터로 탭 자동 이동 (보안 탭 등)
var hash = window.location.hash;
if (hash === '#security') {
  document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('active'); });
  document.querySelectorAll('.tab-content').forEach(function(t){ t.classList.remove('active'); });
  document.querySelector('[onclick="switchTab(\'security\',this)"]').classList.add('active');
  document.getElementById('tab-security').classList.add('active');
}
</script>
</body>
</html>
