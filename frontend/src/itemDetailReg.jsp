<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil, java.util.Base64" %>
<%
    request.setCharacterEncoding("UTF-8");
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendor = "vendor".equals(role);
    boolean isScm    = "scm".equals(role) || "admin".equals(role);

    String bidId = request.getParameter("bidId");
    if (bidId == null || bidId.trim().isEmpty()) { response.sendRedirect("bidList.jsp"); return; }

    // ── 입찰 신청 삭제 처리 ──────────────────────────────────────
    String delAppId = request.getParameter("delAppId");
    String delMsg = "";
    if (delAppId != null && !delAppId.trim().isEmpty()) {
        Connection connD = null; PreparedStatement psD = null;
        try {
            connD = DBUtil.getConnection();
            // 본인 신청 건만 삭제 가능 (vendor_id 일치 확인)
            psD = connD.prepareStatement(
                "DELETE ba FROM bid_applications ba " +
                "JOIN users u ON u.company_id = ba.vendor_id " +
                "WHERE ba.app_id = ? AND u.user_id = ?");
            psD.setInt(1, Integer.parseInt(delAppId));
            psD.setString(2, userId);
            int affected = psD.executeUpdate();
            delMsg = affected > 0 ? "입찰 신청이 삭제되었습니다." : "삭제 권한이 없습니다.";
        } catch (Exception e) {
            delMsg = "삭제 오류: " + e.getMessage();
        } finally {
            DBUtil.close(connD, psD, null);
        }
    }

    // ── 발주 부품 기본 정보 조회 ──────────────────────────────────
    String bidTitle="-", bidStatus="-", bidDeadline="-", bidContent="-", bidBudget="-";
    String partName="-", partCode="-", partCategory="-", material="-", spec="-";
    String imgBase64="", imgType="image/jpeg";
    String scmCompany="-", scmUserName="-", scmEmail="-", scmPhone="-", scmAddr="-";
    String scmBizNo="-", scmCorpNo="-", scmTechCert="-", scmRole="-";

    // ── 입찰 신청 목록 조회 ────────────────────────────────────────
    List<String[]> appList = new ArrayList<>();
    int myVendorId = 0;

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();

        // 내 vendor_id 조회
        ps = conn.prepareStatement("SELECT company_id FROM users WHERE user_id = ?");
        ps.setString(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) myVendorId = rs.getInt("company_id");
        rs.close(); ps.close();

        // 발주 정보 + 발주 업체 정보 조회
        ps = conn.prepareStatement(
            "SELECT b.title, b.status, b.deadline, b.content, b.budget, " +
            "b.part_name, b.part_code, b.part_category, " +
            "b.material, b.spec, b.part_image, b.part_image_type, " +
            "u.user_name, u.email, u.phone, u.biz_no, u.corp_no, u.tech_cert, u.role as urole, " +
            "v.vendor_name, v.address " +
            "FROM bids b " +
            "LEFT JOIN users u ON b.creator_id = u.user_id " +
            "LEFT JOIN vendors v ON u.company_id = v.vendor_id " +
            "WHERE b.bid_id = ?");
        ps.setInt(1, Integer.parseInt(bidId));
        rs = ps.executeQuery();
        if (rs.next()) {
            bidTitle    = rs.getString("title")         != null ? rs.getString("title")         : "-";
            bidStatus   = rs.getString("status")        != null ? rs.getString("status")        : "-";
            bidDeadline = rs.getString("deadline")      != null ? rs.getString("deadline")      : "-";
            bidContent  = rs.getString("content")       != null ? rs.getString("content")       : "-";
            bidBudget   = rs.getLong("budget") > 0 ? "₩ " + String.format("%,d", rs.getLong("budget")) : "-";
            partName    = rs.getString("part_name")     != null ? rs.getString("part_name")     : "-";
            partCode    = rs.getString("part_code")     != null ? rs.getString("part_code")     : "-";
            partCategory= rs.getString("part_category") != null ? rs.getString("part_category") : "-";
            material    = rs.getString("material")      != null ? rs.getString("material")      : "-";
            spec        = rs.getString("spec")          != null ? rs.getString("spec")          : "-";
            scmUserName = rs.getString("user_name")     != null ? rs.getString("user_name")     : "-";
            scmEmail    = rs.getString("email")         != null ? rs.getString("email")         : "-";
            scmPhone    = rs.getString("phone")         != null ? rs.getString("phone")         : "-";
            scmBizNo    = rs.getString("biz_no")        != null ? rs.getString("biz_no")        : "-";
            scmCorpNo   = rs.getString("corp_no")       != null ? rs.getString("corp_no")       : "-";
            scmTechCert = rs.getString("tech_cert")     != null ? rs.getString("tech_cert")     : "-";
            scmCompany  = rs.getString("vendor_name")   != null ? rs.getString("vendor_name")   : "-";
            scmAddr     = rs.getString("address")       != null ? rs.getString("address")       : "-";
            String ur   = rs.getString("urole");
            scmRole     = "admin".equals(ur) ? "원청기업" : "scm".equals(ur) ? "관리자" : "벤더사";
            byte[] imgBytes = rs.getBytes("part_image");
            imgType = rs.getString("part_image_type") != null ? rs.getString("part_image_type") : "image/jpeg";
            if (imgBytes != null && imgBytes.length > 0)
                imgBase64 = Base64.getEncoder().encodeToString(imgBytes);
        }
        rs.close(); ps.close();

        // 입찰 신청 목록 조회
        ps = conn.prepareStatement(
            "SELECT ba.app_id, ba.vendor_id, ba.quote_price, ba.apply_dt, ba.status, " +
            "ba.production_capacity, ba.current_inventory, ba.lead_time, ba.moq, ba.risk_grade, " +
            "ba.transport_cost, " +
            "v.vendor_name, v.tier, v.address, u.user_name, u.biz_no, u.corp_no, u.tech_cert " +
            "FROM bid_applications ba " +
            "LEFT JOIN vendors v ON ba.vendor_id = v.vendor_id " +
            "LEFT JOIN users u ON u.company_id = v.vendor_id AND u.role = 'vendor' " +
            "WHERE ba.bid_id = ? ORDER BY ba.apply_dt DESC");
        ps.setInt(1, Integer.parseInt(bidId));
        rs = ps.executeQuery();
        while (rs.next()) {
            appList.add(new String[]{
                String.valueOf(rs.getInt("app_id")),                                              // [0]
                rs.getString("vendor_name")      != null ? rs.getString("vendor_name")      : "-",// [1]
                rs.getInt("quote_price") > 0
                    ? String.format("%,d", rs.getInt("quote_price"))                              // [2]
                    : "-",
                rs.getString("apply_dt") != null
                    ? rs.getString("apply_dt").substring(0, 10)                                   // [3]
                    : "-",
                rs.getString("status")           != null ? rs.getString("status")           : "-",// [4]
                rs.getString("production_capacity")!=null?rs.getString("production_capacity"): "-",// [5]
                rs.getString("current_inventory") != null ? rs.getString("current_inventory"): "-",// [6]
                rs.getString("lead_time")         != null ? rs.getString("lead_time")        : "-",// [7]
                rs.getString("moq")               != null ? rs.getString("moq")              : "-",// [8]
                rs.getString("risk_grade")        != null ? rs.getString("risk_grade")       : "-",// [9]
                rs.getString("user_name")         != null ? rs.getString("user_name")        : "-",// [10]
                rs.getString("biz_no")            != null ? rs.getString("biz_no")           : "-",// [11]
                rs.getString("tier")              != null ? rs.getString("tier")             : "-",// [12]
                rs.getString("address")           != null ? rs.getString("address")          : "-",// [13]
                String.valueOf(rs.getInt("vendor_id")),                                           // [14]
                rs.getString("corp_no")           != null ? rs.getString("corp_no")          : "-",// [15]
                rs.getString("tech_cert")         != null ? rs.getString("tech_cert")        : "-",// [16]
                rs.getInt("transport_cost") > 0
                    ? String.format("%,d", rs.getInt("transport_cost"))                           // [17]
                    : "-"
            });
        }
    } catch (Exception e) { e.printStackTrace(); }
    finally { DBUtil.close(conn, ps, rs); }

    boolean alreadyApplied = false;
    for (String[] a : appList) {
        if (String.valueOf(myVendorId).equals(a[14])) { alreadyApplied = true; break; }
    }
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 입찰 신청 현황</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--accent:#00AAD4;--panel:#0D1B2A;--surface:#112240;--border:rgba(0,170,212,.2);--text:#E8F0FE;--muted:#7A8FA6;--success:#00E5A0;--warning:#F59E0B;--danger:#EF4444}
html,body{height:100%;font-family:'Noto Sans KR',sans-serif;background:var(--panel);color:var(--text)}
.wrapper{display:flex;flex-direction:column;min-height:100vh}
.layout{flex:1;display:grid;grid-template-columns:220px 1fr}
.main{padding:28px;overflow-y:auto}

.page-header{display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:24px;gap:16px}
.page-title{font-size:20px;font-weight:700}
.page-title span{color:var(--accent);font-weight:400;font-size:15px}
.status-pill{display:inline-flex;align-items:center;gap:6px;padding:5px 14px;border-radius:20px;font-size:12px;font-weight:700}
.st-open{background:rgba(0,180,120,.12);color:#00a86b;border:1px solid rgba(0,180,120,.3)}
.st-closed{background:rgba(100,116,139,.1);color:#64748b;border:1px solid rgba(100,116,139,.2)}

.section-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px}
.section-title{font-size:11px;font-weight:600;color:var(--accent);letter-spacing:2px;text-transform:uppercase;border-left:3px solid var(--accent);padding-left:10px;margin-bottom:14px}

/* 등록자/부품 정보 그리드 */
.info-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.info-item{display:flex;flex-direction:column;gap:4px}
.info-item.full{grid-column:1/-1}
.info-label{font-size:10px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
.info-value{font-size:13px;color:var(--text);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:7px;padding:9px 12px}
.info-value.mono{font-family:'Share Tech Mono',monospace;color:var(--accent)}

/* 부품 요약 */
.part-summary{display:flex;gap:20px;align-items:flex-start}
.part-img{width:120px;height:90px;object-fit:cover;border-radius:8px;border:1px solid var(--border);cursor:pointer;flex-shrink:0;transition:all .2s}
.part-img:hover{border-color:var(--accent)}
.part-meta{flex:1;display:grid;grid-template-columns:1fr 1fr;gap:8px}
.meta-item{display:flex;flex-direction:column;gap:3px}
.meta-label{font-size:10px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
.meta-value{font-size:13px;color:var(--text);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:6px;padding:7px 10px}
.meta-value.mono{font-family:'Share Tech Mono',monospace;color:var(--accent);font-size:12px}
.meta-item.full{grid-column:1/-1}

/* 입찰 테이블 */
.app-table{width:100%;border-collapse:collapse;table-layout:fixed}
.app-table th{color:var(--muted);font-size:11px;font-weight:600;padding:10px 14px;border-bottom:1px solid rgba(255,255,255,.07);text-align:left;letter-spacing:.5px;text-transform:uppercase;white-space:nowrap}
.app-table td{padding:12px 14px;border-bottom:1px solid rgba(255,255,255,.04);font-size:13px;color:#B0C4D8;vertical-align:middle;line-height:1.5}
.app-table tr:last-child td{border-bottom:none}
.app-table tbody tr{transition:background .15s;cursor:pointer}
.app-table tbody tr:hover td{background:rgba(0,170,212,.06)}
.app-table tbody tr.my-row td{background:rgba(0,229,160,.04)}
.app-table tbody tr.my-row:hover td{background:rgba(0,229,160,.08)}

.price-cell{font-family:'Share Tech Mono',monospace;color:#00E5A0;font-weight:700;font-size:13px}
.masked-cell{color:var(--muted);font-size:12px;letter-spacing:1px}
.my-badge{display:inline-block;padding:1px 7px;border-radius:4px;font-size:10px;font-weight:700;background:rgba(0,229,160,.15);color:var(--success);border:1px solid rgba(0,229,160,.3);margin-left:6px;vertical-align:middle}

.app-status{display:inline-block;padding:2px 10px;border-radius:10px;font-size:11px;font-weight:700}
.st-pending{background:rgba(245,158,11,.12);color:var(--warning);border:1px solid rgba(245,158,11,.25)}
.st-approved{background:rgba(0,229,160,.12);color:var(--success);border:1px solid rgba(0,229,160,.25)}
.st-rejected{background:rgba(239,68,68,.12);color:var(--danger);border:1px solid rgba(239,68,68,.25)}

.risk-low{color:#00E5A0;font-weight:600;font-size:13px}
.risk-med{color:var(--warning);font-weight:600;font-size:13px}
.risk-high{color:var(--danger);font-weight:600;font-size:13px}

.empty-box{text-align:center;padding:40px;font-size:13px;color:var(--muted)}
.del-btn{background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.25);color:#EF4444;border-radius:6px;padding:4px 10px;font-size:11px;font-weight:600;cursor:pointer;transition:all .2s;font-family:'Noto Sans KR',sans-serif}
.del-btn:hover{background:rgba(239,68,68,.22)}

.btn-area{display:flex;gap:10px;margin-top:4px;flex-wrap:wrap}
.btn-link{display:inline-block;padding:10px 22px;border-radius:8px;font-size:13px;font-weight:600;text-decoration:none;transition:all .2s;cursor:pointer;border:none;font-family:'Noto Sans KR',sans-serif}
.btn-success{background:rgba(0,229,160,.15);border:1px solid rgba(0,229,160,.3);color:var(--success)}
.btn-success:hover{background:rgba(0,229,160,.28);color:var(--success);text-decoration:none}
.btn-warning{background:rgba(245,158,11,.15);border:1px solid rgba(245,158,11,.3);color:var(--warning)}
.btn-warning:hover{background:rgba(245,158,11,.28);color:var(--warning);text-decoration:none}
.btn-ghost{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);color:var(--muted)}
.btn-ghost:hover{background:rgba(255,255,255,.08);color:var(--text);text-decoration:none}
.btn-detail{background:rgba(0,170,212,.1);border:1px solid rgba(0,170,212,.3);color:var(--accent)}
.btn-detail:hover{background:rgba(0,170,212,.2);color:var(--accent);text-decoration:none}

/* 팝업 */
.popup-overlay{display:none;position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,.65);backdrop-filter:blur(4px);align-items:center;justify-content:center}
.popup-overlay.show{display:flex}
.popup-box{background:#0D1B2A;border:1px solid rgba(0,170,212,.3);border-radius:14px;width:700px;max-width:95vw;max-height:88vh;overflow-y:auto;box-shadow:0 24px 60px rgba(0,0,0,.75)}
.popup-box::-webkit-scrollbar{width:5px}
.popup-box::-webkit-scrollbar-thumb{background:rgba(0,170,212,.25);border-radius:3px}
.popup-header{display:flex;align-items:center;justify-content:space-between;padding:16px 22px;border-bottom:1px solid rgba(0,170,212,.2);background:#112240;border-radius:14px 14px 0 0;position:sticky;top:0;z-index:1}
.popup-header-title{font-size:15px;font-weight:700;color:var(--text)}
.popup-close{width:28px;height:28px;border-radius:50%;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);color:var(--muted);font-size:14px;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:all .2s}
.popup-close:hover{background:rgba(239,68,68,.2);color:var(--danger)}
.popup-body{padding:18px 22px;display:flex;flex-direction:column;gap:14px}
.pop-section{background:#112240;border:1px solid rgba(0,170,212,.15);border-radius:10px;padding:16px 18px}
.pop-section-title{font-size:11px;font-weight:600;color:var(--accent);letter-spacing:2px;text-transform:uppercase;border-left:3px solid var(--accent);padding-left:8px;margin-bottom:14px}
.pop-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.pop-item{display:flex;flex-direction:column;gap:4px}
.pop-item.full{grid-column:1/-1}
.pop-label{font-size:10px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
.pop-value{font-size:13px;color:var(--text);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:7px;padding:9px 12px}
.pop-value.mono{font-family:'Share Tech Mono',monospace;color:var(--accent)}
.pop-value.price{font-family:'Share Tech Mono',monospace;color:#00E5A0;font-weight:700}
.pop-masked{color:var(--muted);font-size:12px;letter-spacing:1px}

.img-modal{display:none;position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,.88);align-items:center;justify-content:center}
.img-modal.show{display:flex}
.img-modal img{max-width:82vw;max-height:82vh;border-radius:12px;border:2px solid var(--accent)}
.img-close{position:absolute;top:20px;right:28px;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2);color:#fff;border-radius:50%;width:36px;height:36px;font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center}
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">

      <% if (!delMsg.isEmpty()) { %>
      <div style="padding:11px 16px;border-radius:8px;margin-bottom:16px;font-size:13px;
                  background:rgba(0,229,160,.08);border:1px solid rgba(0,229,160,.2);color:var(--success);">
        ✓ <%= delMsg %>
      </div>
      <% } %>

      <div class="page-header">
        <div>
          <div class="page-title"><%= partName %> <span>/ 입찰 신청 현황</span></div>
          <div style="font-size:12px;color:var(--muted);margin-top:5px;">마감일 <%= bidDeadline %></div>
        </div>
        <span class="status-pill <%= "OPEN".equals(bidStatus)?"st-open":"st-closed" %>">
          <%= "OPEN".equals(bidStatus) ? "● 진행중" : "● 마감" %>
        </span>
      </div>

      <!-- 1. 등록자 정보 -->
      <div class="section-card">
        <div class="section-title">1. 등록자 정보</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">회사명</div><div class="info-value"><%= scmCompany %></div></div>
          <div class="info-item"><div class="info-label">역할</div><div class="info-value"><%= scmRole %></div></div>
          <div class="info-item"><div class="info-label">담당자</div><div class="info-value"><%= scmUserName %></div></div>
          <div class="info-item"><div class="info-label">이메일</div><div class="info-value"><%= scmEmail %></div></div>
          <div class="info-item"><div class="info-label">연락처</div><div class="info-value"><%= scmPhone %></div></div>
          <div class="info-item"><div class="info-label">사업자번호</div><div class="info-value mono"><%= scmBizNo %></div></div>
          <div class="info-item"><div class="info-label">법인번호</div><div class="info-value mono"><%= scmCorpNo %></div></div>
          <div class="info-item"><div class="info-label">기술인증</div><div class="info-value"><%= scmTechCert %></div></div>
          <% if (!"-".equals(bidContent)) { %><div class="info-item full"><div class="info-label">발주 내용</div><div class="info-value"><%= bidContent %></div></div><% } %>
          <% if (!"-".equals(bidBudget)) { %><div class="info-item"><div class="info-label">예산</div><div class="info-value" style="font-family:'Share Tech Mono',monospace;color:#00E5A0;font-weight:700"><%= bidBudget %></div></div><% } %>
        </div>
      </div>

      <!-- 2. 발주 부품 정보 -->
      <div class="section-card">
        <div class="section-title">2. 부품 정보</div>
        <div class="part-summary">
          <% if (!imgBase64.isEmpty()) { %>
          <img class="part-img" src="data:<%= imgType %>;base64,<%= imgBase64 %>"
               alt="부품사진" onclick="openImg(this.src)">
          <% } %>
          <div class="part-meta">
            <div class="meta-item"><div class="meta-label">부품명</div><div class="meta-value"><%= partName %></div></div>
            <div class="meta-item"><div class="meta-label">부품코드</div><div class="meta-value mono"><%= partCode %></div></div>
            <div class="meta-item"><div class="meta-label">분류</div><div class="meta-value"><%= partCategory %></div></div>
            <div class="meta-item"><div class="meta-label">재질</div><div class="meta-value"><%= material %></div></div>
            <div class="meta-item full"><div class="meta-label">규격</div><div class="meta-value"><%= spec %></div></div>
          </div>
        </div>
      </div>

      <!-- 입찰 신청 목록 -->
      <div class="section-card">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;">
          <div class="section-title" style="margin-bottom:0;">입찰 신청 목록 (<%= appList.size() %>건)</div>
        </div>

        <% if (appList.isEmpty()) { %>
        <div class="empty-box">아직 입찰 신청이 없습니다.</div>
        <% } else { %>
        <div style="overflow-x:auto;">
          <table class="app-table">
            <colgroup>
              <col style="width:33%"/>
              <% if (isScm) { %><col style="width:11%"/><% } %>
              <col style="width:11%"/>
              <% if (isScm) { %><col style="width:8%"/><col style="width:8%"/><col style="width:9%"/><% } %>
              <col style="width:9%"/>
              <col style="width:9%"/>
              <col style="width:10%"/>
              <% if (isVendor) { %><col style="width:8%"/><% } %>
            </colgroup>
            <thead>
              <tr>
                <th>업체명</th>
                <% if (isScm) { %><th>입찰 단가 (원)</th><% } %>
                <th>신청일</th>
                <% if (isScm) { %>
                <th>최대생산량</th>
                <th>재고량</th>
                <th>리드타임 (일)</th>
                <% } %>
                <th>MOQ</th>
                <th>위험등급</th>
                <th>상태</th>
                <% if (isVendor) { %><th></th><% } %>
              </tr>
            </thead>
            <tbody>
            <% for (int i = 0; i < appList.size(); i++) {
                 String[] a = appList.get(i);
                 boolean isMyRow = String.valueOf(myVendorId).equals(a[14]);
                 String stCls   = "PENDING".equals(a[4])  ? "st-pending"
                                : "APPROVED".equals(a[4]) ? "st-approved" : "st-rejected";
                 String stLabel = "PENDING".equals(a[4])  ? "검토중"
                                : "APPROVED".equals(a[4]) ? "승인" : "거절";
                 String riskCls = "Low".equals(a[9])  ? "risk-low"
                                : "High".equals(a[9]) ? "risk-high" : "risk-med";
            %>
            <tr class="<%= isMyRow ? "my-row" : "" %>"
                onclick="openDetail(<%= i %>, <%= isMyRow %>, <%= isScm %>)">
              <td>
                <strong><%= a[1] %></strong>
                <% if (isMyRow) { %><span class="my-badge">내 신청</span><% } %>
              </td>
              <% if (isScm) { %>
              <td class="price-cell"><%= "-".equals(a[2]) ? "-" : "₩ " + a[2] %></td>
              <% } %>
              <td><%= a[3] %></td>
              <% if (isScm) { %>
              <td><%= a[5] %> 개</td>
              <td><%= a[6] %> 개</td>
              <td><%= a[7] %> 일</td>
              <% } %>
              <td><%= a[8] %> 개</td>
              <td><span class="<%= riskCls %>"><%= a[9] %></span></td>
              <td><span class="app-status <%= stCls %>"><%= stLabel %></span></td>
              <% if (isVendor) { %>
              <td onclick="event.stopPropagation()">
                <% if (isMyRow) { %>
                <form method="get" action="itemDetailReg.jsp" style="margin:0;">
                  <input type="hidden" name="bidId" value="<%= bidId %>">
                  <input type="hidden" name="delAppId" value="<%= a[0] %>">
                  <button type="submit" class="del-btn"
                          onclick="return confirm('입찰 신청을 삭제할까요?')">삭제</button>
                </form>
                <% } else { %><span style="font-size:11px;color:var(--muted);">—</span><% } %>
              </td>
              <% } %>
            </tr>
            <% } %>
            </tbody>
          </table>
        </div>
        <div style="font-size:11px;color:var(--muted);margin-top:10px;">
          ※ 행을 클릭하면 상세 정보를 확인할 수 있습니다.
          <% if (isVendor) { %>&nbsp; 다른 업체의 상세 정보는 운송비만 공개됩니다.<% } %>
        </div>
        <% } %>
      </div>

      <!-- 하단 버튼 -->
      <div class="btn-area">
        <% if (isVendor && "OPEN".equals(bidStatus)) { %>
        <a href="bidItemReg.jsp?bidId=<%= bidId %>"
           class="btn-link <%= alreadyApplied ? "btn-warning" : "btn-success" %>">
          <%= alreadyApplied ? "✎ 입찰 수정하기" : "✓ 입찰 신청하기" %>
        </a>
        <% } %>
        <a href="bidList.jsp" class="btn-link btn-ghost">← 목록으로</a>
      </div>

    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>
<!-- wrapper 끝 -->

<!-- 상세 팝업 -->
<div class="popup-overlay" id="popupOverlay" onclick="overlayClick(event)">
  <div class="popup-box">
    <div class="popup-header">
      <div class="popup-header-title" id="popupTitle">입찰 신청 상세</div>
      <button class="popup-close" onclick="closePopup()">✕</button>
    </div>
    <div class="popup-body" id="popupBody"></div>
  </div>
</div>

<div class="img-modal" id="imgModal" onclick="this.classList.remove('show')">
  <button class="img-close">✕</button>
  <img id="modalImg" src="" alt="확대">
</div>

<script>
var APPS = [
<%
for (int i = 0; i < appList.size(); i++) {
    String[] a = appList.get(i);
    if (i > 0) out.print(",");
    out.print("{");
    String[] keys = {"appId","vendorName","quotePrice","applyDt","status",
                     "prodCap","inventory","leadTime","moq","riskGrade",
                     "userName","bizNo","tier","address","vendorId",
                     "corpNo","techCert","transCost"};
    for (int k = 0; k < keys.length; k++) {
        if (k > 0) out.print(",");
        String v = a[k].replace("\\","\\\\").replace("\"","\\\"").replace("\n"," ").replace("\r","");
        out.print("\"" + keys[k] + "\":\"" + v + "\"");
    }
    out.print("}");
}
%>
];
var MY_VENDOR_ID = "<%= myVendorId %>";
var BID_INFO = {
  partName:    "<%= partName.replace("\"","\\\"") %>",
  partCode:    "<%= partCode.replace("\"","\\\"") %>",
  partCategory:"<%= partCategory.replace("\"","\\\"") %>",
  material:    "<%= material.replace("\"","\\\"") %>",
  spec:        "<%= spec.replace("\"","\\\"") %>",
  scmCompany:  "<%= scmCompany.replace("\"","\\\"") %>",
  scmRole:     "<%= scmRole.replace("\"","\\\"") %>",
  scmUserName: "<%= scmUserName.replace("\"","\\\"") %>",
  scmEmail:    "<%= scmEmail.replace("\"","\\\"") %>",
  scmPhone:    "<%= scmPhone.replace("\"","\\\"") %>",
  scmAddr:     "<%= scmAddr.replace("\"","\\\"") %>",
  scmBizNo:    "<%= scmBizNo.replace("\"","\\\"") %>",
  scmCorpNo:   "<%= scmCorpNo.replace("\"","\\\"") %>",
  scmTechCert: "<%= scmTechCert.replace("\"","\\\"") %>",
  bidContent:  "<%= bidContent.replace("\"","\\\"") %>",
  bidBudget:   "<%= bidBudget.replace("\"","\\\"") %>"
};

function openDetail(idx, isMyRow, isScm) {
  var a = APPS[idx];
  var b = BID_INFO;
  var stLabel = a.status==='PENDING'?'검토중':a.status==='APPROVED'?'승인':'거절';
  var canSeeAll = isScm || isMyRow;

  document.getElementById('popupTitle').textContent = a.vendorName + ' 입찰 상세';

  var html =
    sec('1. 등록자 정보', [
      pi('회사명', b.scmCompany),
      pi('역할', b.scmRole),
      pi('담당자', b.scmUserName),
      pi('이메일', b.scmEmail),
      pi('연락처', b.scmPhone),
      piF('기술인증', b.scmTechCert),
      piM('사업자번호', b.scmBizNo),
      piM('법인번호', b.scmCorpNo),
      piF('주소', b.scmAddr),
      b.bidContent !== '-' ? piF('발주 내용', b.bidContent) : '',
      b.bidBudget  !== '-' ? pi('예산', b.bidBudget)        : ''
    ]) +
    sec('2. 부품 정보', [
      pi('부품명', b.partName),
      piM('부품코드', b.partCode),
      pi('분류', b.partCategory),
      pi('재질', b.material),
      piF('규격', b.spec)
    ]) +
    sec('3. 벤더사 (참여업체 정보)', [
      pi('업체명', a.vendorName),
      pi('차수', a.tier),
      pi('담당자', a.userName),
      pi('연락처', a.address),
      piF('기술인증', a.techCert),
      piM('사업자번호', a.bizNo),
      piM('법인번호', a.corpNo),
      piF('주소', a.address)
    ]);

  if (canSeeAll) {
    html +=
      sec('3-1. 생산 및 재고 정보', [
        pi('최대 생산량 (1일)', a.prodCap + ' 개'),
        pi('현재 투입가능 재고량', a.inventory + ' 개'),
        pi('리드타임', a.leadTime + ' 일'),
        pi('최소 주문 수량 (MOQ)', a.moq + ' 개')
      ]) +
      sec('3-2. 가격 및 위험 정보', [
        piP('입찰 단가', a.quotePrice !== '-' ? '₩ ' + a.quotePrice : '-'),
        pi('운송비', a.transCost !== '-' ? a.transCost + ' 원' : '-'),
        pi('공급 위험 등급', a.riskGrade),
        pi('신청일', a.applyDt),
        pi('상태', stLabel)
      ]);
  } else {
    html +=
      sec('3-1. 공개 정보', [
        pi('최소 주문 수량 (MOQ)', a.moq + ' 개'),
        pi('공급 위험 등급', a.riskGrade),
        pi('신청일', a.applyDt),
        pi('상태', stLabel)
      ]) +
      '<div style="text-align:center;padding:14px;font-size:12px;color:var(--muted);">※ 단가·생산·재고 상세는 비공개입니다.</div>';
  }

  document.getElementById('popupBody').innerHTML = html;
  document.getElementById('popupOverlay').classList.add('show');
}

function sec(title, items) {
  return '<div class="pop-section"><div class="pop-section-title">'+title+'</div><div class="pop-grid">'+items.join('')+'</div></div>';
}
function pi(l,v)  { return '<div class="pop-item"><div class="pop-label">'+l+'</div><div class="pop-value">'+esc(v)+'</div></div>'; }
function piM(l,v) { return '<div class="pop-item"><div class="pop-label">'+l+'</div><div class="pop-value mono">'+esc(v)+'</div></div>'; }
function piP(l,v) { return '<div class="pop-item"><div class="pop-label">'+l+'</div><div class="pop-value price">'+esc(v)+'</div></div>'; }
function piF(l,v) { return '<div class="pop-item full"><div class="pop-label">'+l+'</div><div class="pop-value">'+esc(v)+'</div></div>'; }
function esc(s)   { return String(s||'-').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function closePopup()    { document.getElementById('popupOverlay').classList.remove('show'); }
function overlayClick(e) { if(e.target===document.getElementById('popupOverlay')) closePopup(); }
function openImg(src)    { document.getElementById('modalImg').src=src; document.getElementById('imgModal').classList.add('show'); }
document.addEventListener('keydown', function(e) {
  if (e.key==='Escape') { closePopup(); document.getElementById('imgModal').classList.remove('show'); }
});
</script>
</body>
</html>
