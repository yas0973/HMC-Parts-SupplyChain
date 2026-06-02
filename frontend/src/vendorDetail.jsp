<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (userId == null) { response.sendRedirect("login.jsp"); return; }

    boolean isVendor        = "vendor".equals(role);
    boolean canSeeAllPrices = !isVendor;

    // vendorId 또는 appId로 접근
    String vendorIdParam = request.getParameter("vendorId");
    String appIdParam    = request.getParameter("appId");
    String fromBid       = request.getParameter("bidId"); // 돌아갈 때 사용

    String vendorId="", vendorName="-", bizNo="-", representative="-";
    String address="-", creditGrade="-", tier="-";
    String lastEvalScore="-", lastEvalGrade="-";

    // 입찰 신청 정보 (appId로 들어온 경우)
    String quotePrice="-", applyDt="-", appStatus="-";
    String prodCap="-", inventory="-", leadTime="-", moq="-", riskGrade="-";
    boolean hasAppInfo = false;

    // 부품 목록
    List<String[]> partList = new ArrayList<>();

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();

        // appId로 들어온 경우 vendorId 추출 + 입찰 정보 조회
        if (appIdParam != null && !appIdParam.isEmpty()) {
            ps = conn.prepareStatement(
                "SELECT ba.vendor_id, ba.quote_price, ba.apply_dt, ba.status, " +
                "ba.production_capacity, ba.current_inventory, ba.lead_time, ba.moq, ba.risk_grade " +
                "FROM bid_applications ba WHERE ba.app_id=?");
            ps.setInt(1, Integer.parseInt(appIdParam));
            rs = ps.executeQuery();
            if (rs.next()) {
                vendorIdParam   = String.valueOf(rs.getInt("vendor_id"));
                quotePrice      = rs.getInt("quote_price") > 0 ? "₩ " + String.format("%,d", rs.getInt("quote_price")) : "-";
                applyDt         = rs.getString("apply_dt") != null ? rs.getString("apply_dt").substring(0,10) : "-";
                appStatus       = rs.getString("status")   != null ? rs.getString("status") : "-";
                prodCap         = rs.getString("production_capacity") != null ? rs.getString("production_capacity") : "-";
                inventory       = rs.getString("current_inventory")   != null ? rs.getString("current_inventory")   : "-";
                leadTime        = rs.getString("lead_time")            != null ? rs.getString("lead_time")            : "-";
                moq             = rs.getString("moq")                  != null ? rs.getString("moq")                  : "-";
                riskGrade       = rs.getString("risk_grade")           != null ? rs.getString("risk_grade")           : "-";
                hasAppInfo      = true;
            }
            rs.close(); ps.close();
        }

        if (vendorIdParam != null && !vendorIdParam.isEmpty()) {
            vendorId = vendorIdParam;

            // 벤더 기본 정보
            ps = conn.prepareStatement("SELECT * FROM vendors WHERE vendor_id=?");
            ps.setInt(1, Integer.parseInt(vendorId));
            rs = ps.executeQuery();
            if (rs.next()) {
                vendorName   = rs.getString("vendor_name")   != null ? rs.getString("vendor_name")   : "-";
                bizNo        = rs.getString("biz_no")        != null ? rs.getString("biz_no")        : "-";
                representative=rs.getString("representative")!= null ? rs.getString("representative"): "-";
                address      = rs.getString("address")       != null ? rs.getString("address")       : "-";
                creditGrade  = rs.getString("credit_grade")  != null ? rs.getString("credit_grade")  : "-";
                tier         = rs.getString("tier")          != null ? rs.getString("tier")          : "-";
            }
            rs.close(); ps.close();

            // 최근 평가
            ps = conn.prepareStatement(
                "SELECT total_score, grade FROM evaluations WHERE vendor_id=? ORDER BY eval_year DESC LIMIT 1");
            ps.setInt(1, Integer.parseInt(vendorId));
            rs = ps.executeQuery();
            if (rs.next()) {
                lastEvalScore = rs.getString("total_score") != null ? rs.getString("total_score") + "점" : "-";
                lastEvalGrade = rs.getString("grade")       != null ? rs.getString("grade")       : "-";
            }
            rs.close(); ps.close();
        }
    } catch (Exception e) {
        e.printStackTrace();
    } finally {
        DBUtil.close(conn, ps, rs);
    }

    String stLabel = "PENDING".equals(appStatus) ? "검토중" : "APPROVED".equals(appStatus) ? "승인" : "REJECTED".equals(appStatus) ? "거절" : appStatus;
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 업체 상세</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--accent:#00AAD4;--panel:#0D1B2A;--surface:#112240;--border:rgba(0,170,212,.2);--text:#E8F0FE;--muted:#7A8FA6;--success:#00E5A0;--warning:#F59E0B;--danger:#EF4444}
html,body{height:100%;font-family:'Noto Sans KR',sans-serif;background:var(--panel);color:var(--text)}
.wrapper{display:flex;flex-direction:column;min-height:100vh}
.layout{flex:1;display:grid;grid-template-columns:220px 1fr}
.main{padding:28px;overflow-y:auto}

/* 헤더 */
.vendor-hero{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:24px;margin-bottom:20px;display:flex;align-items:center;gap:20px;background:linear-gradient(135deg,#112240 60%,rgba(0,170,212,.05) 100%)}
.vendor-avatar{width:64px;height:64px;border-radius:14px;background:linear-gradient(135deg,#003DA5,#00AAD4);display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:700;color:#fff;flex-shrink:0}
.vendor-hero-info .vname{font-size:20px;font-weight:700;margin-bottom:6px}
.vendor-hero-info .vmeta{font-size:13px;color:var(--muted);display:flex;gap:12px;flex-wrap:wrap}
.chip{display:inline-block;padding:2px 10px;border-radius:8px;font-size:11px;font-weight:700}
.chip-accent{background:rgba(0,170,212,.15);color:var(--accent);border:1px solid rgba(0,170,212,.2)}
.chip-success{background:rgba(0,229,160,.15);color:var(--success);border:1px solid rgba(0,229,160,.25)}
.chip-warning{background:rgba(245,158,11,.15);color:var(--warning);border:1px solid rgba(245,158,11,.25)}

/* 섹션 */
.section-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:22px;margin-bottom:18px}
.section-title{font-size:11px;font-weight:600;color:var(--accent);letter-spacing:2px;text-transform:uppercase;border-left:3px solid var(--accent);padding-left:10px;margin-bottom:16px}
.info-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.info-item{display:flex;flex-direction:column;gap:4px}
.info-item.full{grid-column:1/-1}
.info-label{font-size:10px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
.info-value{font-size:13px;color:var(--text);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:7px;padding:9px 12px}
.info-value.mono{font-family:'Share Tech Mono',monospace;color:var(--accent)}
.info-value.price{font-family:'Share Tech Mono',monospace;color:#00E5A0;font-weight:700}
.info-value.grade{color:#00E5A0;font-weight:700}

/* 입찰 상태 배지 */
.app-status{display:inline-block;padding:3px 12px;border-radius:10px;font-size:12px;font-weight:700}
.st-pending{background:rgba(245,158,11,.12);color:var(--warning);border:1px solid rgba(245,158,11,.25)}
.st-approved{background:rgba(0,229,160,.12);color:var(--success);border:1px solid rgba(0,229,160,.25)}
.st-rejected{background:rgba(239,68,68,.12);color:var(--danger);border:1px solid rgba(239,68,68,.25)}

/* 버튼 */
.btn-back{display:inline-block;padding:10px 22px;border-radius:8px;font-size:13px;font-weight:600;text-decoration:none;transition:all .2s;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);color:var(--muted)}
.btn-back:hover{background:rgba(255,255,255,.08);color:var(--text);text-decoration:none}
.btn-area{display:flex;gap:10px;margin-top:4px}
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">

      <!-- 업체 헤더 -->
      <div class="vendor-hero">
        <div class="vendor-avatar"><%= vendorName.length()>=2?vendorName.substring(0,2):vendorName %></div>
        <div class="vendor-hero-info">
          <div class="vname"><%= vendorName %></div>
          <div class="vmeta">
            <span class="chip chip-accent"><%= tier %></span>
            <span class="chip chip-success">신용등급: <%= creditGrade %></span>
            <% if (!"-".equals(lastEvalGrade)) { %>
            <span class="chip chip-warning">최근 평가: <%= lastEvalScore %> (<%= lastEvalGrade %>)</span>
            <% } %>
          </div>
        </div>
      </div>

      <!-- 1. 업체 기본 정보 -->
      <div class="section-card">
        <div class="section-title">1. 업체 기본 정보</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">업체명</div><div class="info-value"><%= vendorName %></div></div>
          <div class="info-item"><div class="info-label">차수</div><div class="info-value"><%= tier %></div></div>
          <div class="info-item"><div class="info-label">대표자</div><div class="info-value"><%= representative %></div></div>
          <div class="info-item"><div class="info-label">신용등급</div><div class="info-value grade"><%= creditGrade %></div></div>
          <div class="info-item"><div class="info-label">사업자번호</div><div class="info-value mono"><%= bizNo %></div></div>
          <div class="info-item"><div class="info-label">주소</div><div class="info-value"><%= address %></div></div>
        </div>
      </div>

      <!-- 2. 입찰 신청 정보 (appId로 들어온 경우) -->
      <% if (hasAppInfo) { %>
      <div class="section-card">
        <div class="section-title">2. 입찰 신청 정보</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">입찰 단가</div><div class="info-value price"><%= quotePrice %></div></div>
          <div class="info-item"><div class="info-label">신청 상태</div>
            <div class="info-value">
              <span class="app-status <%= "PENDING".equals(appStatus)?"st-pending":"APPROVED".equals(appStatus)?"st-approved":"st-rejected" %>">
                <%= stLabel %>
              </span>
            </div>
          </div>
          <div class="info-item"><div class="info-label">신청일</div><div class="info-value"><%= applyDt %></div></div>
          <div class="info-item"><div class="info-label">공급 위험 등급</div><div class="info-value"><%= riskGrade %></div></div>
        </div>
        <hr style="border:none;border-top:1px solid rgba(255,255,255,.06);margin:14px 0">
        <div class="info-grid">
          <div class="info-item"><div class="info-label">월 생산능력</div><div class="info-value"><%= prodCap %> 개</div></div>
          <div class="info-item"><div class="info-label">현재 재고량</div><div class="info-value"><%= inventory %> 개</div></div>
          <div class="info-item"><div class="info-label">최소 주문 수량</div><div class="info-value"><%= moq %> 개</div></div>
          <div class="info-item full"><div class="info-label">리드 타임</div><div class="info-value"><%= leadTime %></div></div>
        </div>
      </div>
      <% } %>

      <div class="btn-area">
        <% if (fromBid != null && !fromBid.isEmpty()) { %>
        <a href="itemDetailReg.jsp?bidId=<%= fromBid %>" class="btn-back">← 발주 상세로</a>
        <% } else { %>
        <a href="javascript:history.back()" class="btn-back">← 돌아가기</a>
        <% } %>
      </div>

    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>
</body>
</html>
