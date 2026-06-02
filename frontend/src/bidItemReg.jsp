<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.sql.*, java.util.*, util.DBUtil" %>
<%@ page import="java.util.Base64" %>
<%
    request.setCharacterEncoding("UTF-8");

    if (session.getAttribute("userId") == null) { response.sendRedirect("login.jsp"); return; }
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (!"vendor".equals(role)) { response.sendRedirect("bidList.jsp"); return; }

    String bidId = request.getParameter("bidId");
    if (bidId == null || bidId.trim().isEmpty()) { response.sendRedirect("bidList.jsp"); return; }

    String message = ""; String msgType = "success";

    // ── POST 처리 ─────────────────────────────────────────────
    if ("POST".equals(request.getMethod())) {
        String unitPrice   = request.getParameter("unit_price");
        String prodCap     = request.getParameter("production_capacity");
        String inventory   = request.getParameter("current_inventory");
        String leadTime    = request.getParameter("lead_time");
        String moq         = request.getParameter("moq");
        String riskGrade   = request.getParameter("risk_grade");
        String transCost   = request.getParameter("transport_cost");

        Connection connW = null; PreparedStatement psW = null; ResultSet rsW = null;
        try {
            connW = DBUtil.getConnection();
            // vendor_id 조회
            psW = connW.prepareStatement("SELECT company_id FROM users WHERE user_id = ?");
            psW.setString(1, userId);
            rsW = psW.executeQuery();
            int vendorId = rsW.next() ? rsW.getInt("company_id") : 0;
            rsW.close(); psW.close();

            if (vendorId == 0) {
                message = "벤더 정보를 찾을 수 없습니다."; msgType = "error";
            } else {
                // 기존 신청 여부 확인
                psW = connW.prepareStatement(
                    "SELECT app_id FROM bid_applications WHERE bid_id = ? AND vendor_id = ?");
                psW.setInt(1, Integer.parseInt(bidId));
                psW.setInt(2, vendorId);
                rsW = psW.executeQuery();
                boolean exists = rsW.next();
                rsW.close(); psW.close();

                int price       = 0; try { price       = Integer.parseInt(unitPrice != null ? unitPrice.trim() : "0"); } catch(Exception ex){}
                int prodCapInt  = 0; try { prodCapInt  = Integer.parseInt(prodCap   != null ? prodCap.trim()   : "0"); } catch(Exception ex){}
                int invInt      = 0; try { invInt      = Integer.parseInt(inventory != null ? inventory.trim() : "0"); } catch(Exception ex){}
                int moqInt      = 0; try { moqInt      = Integer.parseInt(moq       != null ? moq.trim()       : "0"); } catch(Exception ex){}
                int transCostInt= 0; try { transCostInt= Integer.parseInt(transCost != null ? transCost.trim() : "0"); } catch(Exception ex){}

                if (exists) {
                    // UPDATE
                    psW = connW.prepareStatement(
                        "UPDATE bid_applications SET quote_price=?, production_capacity=?, current_inventory=?, " +
                        "lead_time=?, moq=?, risk_grade=?, transport_cost=?, apply_dt=NOW() " +
                        "WHERE bid_id=? AND vendor_id=?");
                    psW.setInt(1, price);
                    psW.setInt(2, prodCapInt);
                    psW.setInt(3, invInt);
                    psW.setString(4, leadTime != null ? leadTime.trim() : "");
                    psW.setInt(5, moqInt);
                    psW.setString(6, riskGrade != null ? riskGrade.trim() : "Medium");
                    psW.setInt(7, transCostInt);
                    psW.setInt(8, Integer.parseInt(bidId));
                    psW.setInt(9, vendorId);
                } else {
                    // INSERT
                    psW = connW.prepareStatement(
                        "INSERT INTO bid_applications (bid_id, vendor_id, quote_price, production_capacity, " +
                        "current_inventory, lead_time, moq, risk_grade, transport_cost, status, apply_dt) " +
                        "VALUES (?,?,?,?,?,?,?,?,?,'PENDING',NOW())");
                    psW.setInt(1, Integer.parseInt(bidId));
                    psW.setInt(2, vendorId);
                    psW.setInt(3, price);
                    psW.setInt(4, prodCapInt);
                    psW.setInt(5, invInt);
                    psW.setString(6, leadTime != null ? leadTime.trim() : "");
                    psW.setInt(7, moqInt);
                    psW.setString(8, riskGrade != null ? riskGrade.trim() : "Medium");
                    psW.setInt(9, transCostInt);
                }
                psW.executeUpdate();

                response.sendRedirect("bidList.jsp");
                return;
            }
        } catch (Exception e) {
            message = "오류: " + e.getMessage(); msgType = "error";
        } finally {
            DBUtil.close(connW, psW, rsW);
        }
    }

    // ── GET: 벤더 정보 + 발주 정보 + 기존 신청값 조회 ────────────
    // 발주 업체(SCM) 정보
    String scmCompany="-", scmUserName="-", scmEmail="-", scmPhone="-", scmAddr="-";
    String scmRole="-", scmBizNo="-", scmTechCert="-";

    String vendorName="-",bizNo="-",corpNo="-",techCert="-",address="-",represent="-",creditGrade="-",tier="-";
    String vEmail="-", vPhone="-";
    String bidTitle="-",bidDeadline="-",bidContent="-";
    String partName="-",partCode="-",partCategory="-",material="-",spec="-";
    String usage="-", feature="-";
    String imgBase64="", imgType="image/jpeg";

    // 기존 신청값
    String prevPrice="",prevProdCap="",prevInventory="",prevLeadTime="",prevMoq="100",prevRisk="Medium";
    String prevTransCost="", prevDelayRisk="", prevDefectRate="";

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();

        // 발주 업체(SCM) 정보 조회 - bids.creator_id 기준
        ps = conn.prepareStatement(
            "SELECT u.user_name, u.email, u.phone, u.biz_no, u.tech_cert, u.role as urole, " +
            "v.vendor_name, v.address " +
            "FROM bids b " +
            "LEFT JOIN users u ON b.creator_id = u.user_id " +
            "LEFT JOIN vendors v ON u.company_id = v.vendor_id " +
            "WHERE b.bid_id = ?");
        ps.setInt(1, Integer.parseInt(bidId));
        rs = ps.executeQuery();
        if (rs.next()) {
            scmUserName = rs.getString("user_name")  != null ? rs.getString("user_name")  : "-";
            scmEmail    = rs.getString("email")       != null ? rs.getString("email")       : "-";
            scmPhone    = rs.getString("phone")       != null ? rs.getString("phone")       : "-";
            scmBizNo    = rs.getString("biz_no")      != null ? rs.getString("biz_no")      : "-";
            scmTechCert = rs.getString("tech_cert")   != null ? rs.getString("tech_cert")   : "-";
            scmCompany  = rs.getString("vendor_name") != null ? rs.getString("vendor_name") : "-";
            scmAddr     = rs.getString("address")     != null ? rs.getString("address")     : "-";
            String ur   = rs.getString("urole");
            scmRole     = "admin".equals(ur) ? "원청기업" : "scm".equals(ur) ? "관리자" : "벤더사";
        }
        rs.close(); ps.close();

        // 벤더 정보
        ps = conn.prepareStatement(
            "SELECT u.email, u.phone, u.biz_no, u.corp_no, u.tech_cert, " +
            "v.vendor_name, v.representative, v.address, v.credit_grade, v.tier, v.vendor_id " +
            "FROM users u LEFT JOIN vendors v ON u.company_id = v.vendor_id WHERE u.user_id = ?");
        ps.setString(1, userId);
        rs = ps.executeQuery();
        int vendorIdInt = 0;
        if (rs.next()) {
            vEmail      = rs.getString("email")         != null ? rs.getString("email")         : "-";
            vPhone      = rs.getString("phone")         != null ? rs.getString("phone")         : "-";
            bizNo       = rs.getString("biz_no")        != null ? rs.getString("biz_no")        : "-";
            corpNo      = rs.getString("corp_no")       != null ? rs.getString("corp_no")       : "-";
            techCert    = rs.getString("tech_cert")     != null ? rs.getString("tech_cert")     : "-";
            vendorName  = rs.getString("vendor_name")   != null ? rs.getString("vendor_name")   : "-";
            represent   = rs.getString("representative")!= null ? rs.getString("representative"): "-";
            address     = rs.getString("address")       != null ? rs.getString("address")       : "-";
            creditGrade = rs.getString("credit_grade")  != null ? rs.getString("credit_grade")  : "-";
            tier        = rs.getString("tier")          != null ? rs.getString("tier")          : "-";
            vendorIdInt = rs.getInt("vendor_id");
        }
        rs.close(); ps.close();

        // 발주 정보
        ps = conn.prepareStatement(
            "SELECT title, deadline, content, part_name, part_code, part_category, material, spec, part_image, part_image_type " +
            "FROM bids WHERE bid_id = ?");
        ps.setInt(1, Integer.parseInt(bidId));
        rs = ps.executeQuery();
        if (rs.next()) {
            bidTitle    = rs.getString("title")        != null ? rs.getString("title")        : "-";
            bidDeadline = rs.getString("deadline")     != null ? rs.getString("deadline")     : "-";
            bidContent  = rs.getString("content")      != null ? rs.getString("content")      : "-";
            partName    = rs.getString("part_name")    != null ? rs.getString("part_name")    : "-";
            partCode    = rs.getString("part_code")    != null ? rs.getString("part_code")    : "-";
            partCategory= rs.getString("part_category")!= null ? rs.getString("part_category"): "-";
            material    = rs.getString("material")     != null ? rs.getString("material")     : "-";
            spec        = rs.getString("spec")         != null ? rs.getString("spec")         : "-";
            byte[] imgBytes = rs.getBytes("part_image");
            imgType = rs.getString("part_image_type") != null ? rs.getString("part_image_type") : "image/jpeg";
            if (imgBytes != null && imgBytes.length > 0) imgBase64 = Base64.getEncoder().encodeToString(imgBytes);
        }
        rs.close(); ps.close();

        // 기존 신청값
        if (vendorIdInt > 0) {
            ps = conn.prepareStatement(
                "SELECT quote_price, production_capacity, current_inventory, lead_time, moq, risk_grade, transport_cost " +
                "FROM bid_applications WHERE bid_id = ? AND vendor_id = ?");
            ps.setInt(1, Integer.parseInt(bidId));
            ps.setInt(2, vendorIdInt);
            rs = ps.executeQuery();
            if (rs.next()) {
                prevPrice     = rs.getInt("quote_price") > 0 ? String.valueOf(rs.getInt("quote_price")) : "";
                prevProdCap   = rs.getString("production_capacity") != null ? rs.getString("production_capacity") : "";
                prevInventory = rs.getString("current_inventory")   != null ? rs.getString("current_inventory")   : "";
                prevLeadTime  = rs.getString("lead_time")           != null ? rs.getString("lead_time")           : "";
                prevMoq       = rs.getString("moq")                 != null ? rs.getString("moq")                 : "100";
                prevRisk      = rs.getString("risk_grade")          != null ? rs.getString("risk_grade")          : "Medium";
                prevTransCost = rs.getInt("transport_cost") > 0 ? String.valueOf(rs.getInt("transport_cost"))     : "";
            }
        }
    } catch (Exception e) {
        message = "조회 오류: " + e.getMessage(); msgType = "error";
    } finally {
        DBUtil.close(conn, ps, rs);
    }

    boolean isEdit = !prevPrice.isEmpty();
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 입찰 신청</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  :root{--accent:#00AAD4;--panel:#0D1B2A;--surface:#112240;--border:rgba(0,170,212,.2);--text:#E8F0FE;--muted:#7A8FA6;--success:#00E5A0;--warning:#F59E0B;--danger:#EF4444}
  html,body{font-family:'Noto Sans KR',sans-serif;background:var(--panel);color:var(--text);min-height:100%}
  .wrapper{display:flex;flex-direction:column;min-height:100vh}
  .layout{flex:1;display:grid;grid-template-columns:220px 1fr}
  .main{padding:28px;overflow-y:auto}
  .page-title{font-size:22px;font-weight:700;margin-bottom:6px}
  .page-title span{color:var(--accent);font-weight:400;font-size:16px}
  .page-sub{font-size:12px;color:var(--muted);margin-bottom:24px;display:flex;align-items:center;gap:8px}

  .msg{padding:12px 16px;border-radius:8px;margin-bottom:20px;font-size:13px;display:flex;align-items:center;gap:8px}
  .msg.error{background:rgba(239,68,68,.08);border:1px solid rgba(239,68,68,.25);color:var(--danger)}

  .section-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:22px;margin-bottom:18px}
  .section-title{font-size:11px;font-weight:600;color:var(--accent);letter-spacing:2px;text-transform:uppercase;border-left:3px solid var(--accent);padding-left:10px;margin-bottom:16px}

  .info-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .info-item{display:flex;flex-direction:column;gap:4px}
  .info-item.full{grid-column:1/-1}
  .info-label{font-size:10px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
  .info-value{font-size:13px;color:var(--text);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:7px;padding:9px 12px}
  .info-value.mono{font-family:'Share Tech Mono',monospace;color:var(--accent)}
  .part-img{max-width:200px;max-height:150px;object-fit:cover;border-radius:8px;border:1px solid var(--border);cursor:pointer;transition:all .2s}
  .part-img:hover{border-color:var(--accent)}

  .form-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}
  .field{display:flex;flex-direction:column;gap:6px}
  .field.full{grid-column:1/-1}
  label{font-size:11px;color:var(--muted);letter-spacing:.5px;text-transform:uppercase}
  .required{color:var(--danger);margin-left:2px}
  input[type="text"],input[type="number"],select{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:8px;padding:10px 13px;color:var(--text);font-family:'Noto Sans KR',sans-serif;font-size:13px;outline:none;transition:border-color .2s;width:100%}
  input:focus,select:focus{border-color:var(--accent);background:rgba(0,170,212,.05)}
  input.invalid{border-color:var(--danger)!important}
  input::placeholder{color:rgba(122,143,166,.4)}
  select option{background:#112240}
  .input-unit{display:flex;gap:8px;align-items:center}
  .unit-txt{font-size:13px;color:var(--muted);flex-shrink:0}
  .help{font-size:11px;color:var(--muted);margin-top:3px}

  .btn-area{display:flex;gap:10px;margin-top:4px}
  .btn{border:none;border-radius:8px;padding:11px 22px;cursor:pointer;font-size:13px;font-weight:600;font-family:'Noto Sans KR',sans-serif;transition:all .2s}
  .btn-success{background:linear-gradient(135deg,#003DA5,#00AAD4);color:#fff}
  .btn-success:hover{opacity:.9;transform:translateY(-1px)}
  .btn-ghost{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);color:var(--muted)}
  .btn-ghost:hover{background:rgba(255,255,255,.08);color:var(--text)}

  .edit-badge{display:inline-block;padding:4px 14px;border-radius:20px;font-size:12px;font-weight:700;background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.3);color:var(--warning);margin-left:10px}

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
      <div class="page-title">
        입찰 신청 <span>/ <%= bidTitle %></span>
        <% if (isEdit) { %><span class="edit-badge">수정 모드</span><% } %>
      </div>
      <div class="page-sub">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        마감일: <strong><%= bidDeadline %></strong>
        <% if (!"-".equals(bidContent)) { %>&nbsp;|&nbsp; <%= bidContent %><% } %>
      </div>

      <% if (!message.isEmpty()) { %>
      <div class="msg error"><%= message %></div>
      <% } %>

      <!-- 1. 발주 업체 정보 -->
      <div class="section-card">
        <div class="section-title">1. 발주 업체 정보</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">회사명</div><div class="info-value"><%= scmCompany %></div></div>
          <div class="info-item"><div class="info-label">역할</div><div class="info-value"><%= scmRole != null ? scmRole : "-" %></div></div>
          <div class="info-item"><div class="info-label">담당자명</div><div class="info-value"><%= scmUserName %></div></div>
          <div class="info-item"><div class="info-label">연락처</div><div class="info-value"><%= scmPhone %></div></div>
          <div class="info-item"><div class="info-label">이메일</div><div class="info-value"><%= scmEmail %></div></div>
          <div class="info-item"><div class="info-label">기술인증</div><div class="info-value"><%= scmTechCert != null ? scmTechCert : "-" %></div></div>
          <div class="info-item"><div class="info-label">사업자번호</div><div class="info-value mono"><%= scmBizNo != null ? scmBizNo : "-" %></div></div>
          <div class="info-item"><div class="info-label">소재지</div><div class="info-value"><%= scmAddr %></div></div>
        </div>
      </div>

      <!-- 1-1. 발주 품목 정보 -->
      <div class="section-card">
        <div class="section-title">1-1. 발주 품목 정보</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">부품명</div><div class="info-value"><%= partName %></div></div>
          <div class="info-item"><div class="info-label">부품코드</div><div class="info-value mono"><%= partCode %></div></div>
          <div class="info-item"><div class="info-label">부품분류</div><div class="info-value"><%= partCategory %></div></div>
          <div class="info-item"><div class="info-label">재질</div><div class="info-value"><%= material %></div></div>
          <div class="info-item"><div class="info-label">규격</div><div class="info-value"><%= spec %></div></div>
          <div class="info-item"><div class="info-label">용도</div><div class="info-value"><%= usage != null ? usage : "-" %></div></div>
          <div class="info-item full"><div class="info-label">특징</div><div class="info-value"><%= feature != null ? feature : "-" %></div></div>
          <% if (!imgBase64.isEmpty()) { %>
          <div class="info-item full">
            <div class="info-label">부품 사진</div>
            <div style="margin-top:6px;">
              <img class="part-img" src="data:<%= imgType %>;base64,<%= imgBase64 %>" alt="부품사진"
                   onclick="document.getElementById('modalImg').src=this.src; document.getElementById('imgModal').classList.add('show')">
            </div>
          </div>
          <% } %>
        </div>
      </div>

      <!-- 2. 벤더사 (참여업체 정보) -->
      <div class="section-card">
        <div class="section-title">2. 벤더사 (참여업체 정보)</div>
        <div class="info-grid">
          <div class="info-item"><div class="info-label">업체명</div><div class="info-value"><%= vendorName %></div></div>
          <div class="info-item"><div class="info-label">차수</div><div class="info-value"><%= tier %></div></div>
          <div class="info-item"><div class="info-label">대표자</div><div class="info-value"><%= represent %></div></div>
          <div class="info-item"><div class="info-label">신용등급</div><div class="info-value" style="color:#00E5A0;font-weight:700"><%= creditGrade %></div></div>
          <div class="info-item"><div class="info-label">이메일</div><div class="info-value"><%= vEmail %></div></div>
          <div class="info-item"><div class="info-label">연락처</div><div class="info-value"><%= vPhone %></div></div>
          <div class="info-item"><div class="info-label">사업자번호</div><div class="info-value mono"><%= bizNo %></div></div>
          <div class="info-item"><div class="info-label">법인번호</div><div class="info-value mono"><%= corpNo %></div></div>
          <div class="info-item full"><div class="info-label">기술인증</div><div class="info-value"><%= techCert %></div></div>
          <div class="info-item full"><div class="info-label">주소</div><div class="info-value"><%= address %></div></div>
        </div>
      </div>

      <form method="post" action="bidItemReg.jsp?bidId=<%= bidId %>" id="regForm" onsubmit="return validateForm()">

        <!-- 2-1. 벤더사 생산 및 재고 정보 -->
        <div class="section-card">
          <div class="section-title">2-1. 생산 및 재고 정보</div>
          <div class="form-grid">
            <div class="field">
              <label>최대 생산량 (1일 기준)<span class="required">*</span></label>
              <div class="input-unit">
                <input type="number" id="production_capacity" name="production_capacity" value="<%= prevProdCap %>" placeholder="예: 5000">
                <span class="unit-txt">개</span>
              </div>
              <div class="help">하루 기준 최대 생산 가능한 수량을 입력합니다.</div>
            </div>
            <div class="field">
              <label>현재 투입가능 재고량<span class="required">*</span></label>
              <div class="input-unit">
                <input type="number" id="current_inventory" name="current_inventory" value="<%= prevInventory %>" placeholder="예: 1200">
                <span class="unit-txt">개</span>
              </div>
              <div class="help">즉시 공급 또는 생산에 투입 가능한 현재 재고 수량입니다.</div>
            </div>
            <div class="field">
              <label>최소 주문 수량 (MOQ)<span class="required">*</span></label>
              <div class="input-unit">
                <input type="number" id="moq" name="moq" value="<%= prevMoq %>">
                <span class="unit-txt">개</span>
              </div>
            </div>
            <div class="field">
              <label>평균 생산 리드타임<span class="required">*</span></label>
              <div class="input-unit">
                <input type="number" id="lead_time_days" name="lead_time" value="<%= prevLeadTime %>">
                <span class="unit-txt">일</span>
              </div>
              <div class="help">주문 후 납품까지 평균적으로 걸리는 일수입니다.</div>
            </div>
          </div>
        </div>

        <!-- 2-2. 가격 및 위험 정보 -->
        <div class="section-card">
          <div class="section-title">2-2. 가격 및 위험 정보</div>
          <div class="form-grid">
            <div class="field">
              <label>입찰 단가<span class="required">*</span></label>
              <div class="input-unit">
                <input type="number" id="unit_price" name="unit_price" value="<%= prevPrice %>" placeholder="단가 입력">
                <span class="unit-txt">원</span>
              </div>
            </div>
            <div class="field">
              <label>운송비</label>
              <div class="input-unit">
                <input type="number" step="0.01" id="transport_cost" name="transport_cost" value="<%= prevTransCost %>" placeholder="예: 500">
                <span class="unit-txt">원</span>
              </div>
            </div>
            <div class="field">
              <label>납기지연 위험요소</label>
              <input type="number" step="0.01" min="0" max="1" id="delay_risk" name="delay_risk" value="<%= prevDelayRisk %>" placeholder="예: 0.15">
              <div class="help">0에 가까울수록 안정적, 1에 가까울수록 지연 위험이 높습니다.</div>
            </div>
            <div class="field">
              <label>불량률</label>
              <input type="number" step="0.01" min="0" max="1" id="defect_rate" name="defect_rate" value="<%= prevDefectRate %>" placeholder="예: 0.03">
              <div class="help">예: 0.03은 3% 수준의 불량률을 의미합니다.</div>
            </div>
            <div class="field full">
              <label>공급 위험 등급<span class="required">*</span></label>
              <select id="risk_grade" name="risk_grade">
                <option value="Low"    <%= "Low".equals(prevRisk)    ? "selected" : "" %>>낮음 (Low) - 안정적인 공급 가능</option>
                <option value="Medium" <%= "Medium".equals(prevRisk)||prevRisk.isEmpty() ? "selected" : "" %>>보통 (Medium) - 일반적인 수준</option>
                <option value="High"   <%= "High".equals(prevRisk)   ? "selected" : "" %>>높음 (High) - 수급 불안정 위험 존재</option>
              </select>
            </div>
          </div>
          <div class="btn-area">
            <button type="submit" class="btn btn-success">
              <%= isEdit ? "✎ 입찰 수정 완료" : "✓ 입찰 신청 완료" %>
            </button>
            <button type="button" class="btn btn-ghost" onclick="history.back()">취소</button>
          </div>
        </div>

      </form>
    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>

<div class="img-modal" id="imgModal" onclick="this.classList.remove('show')">
  <button class="img-close">✕</button>
  <img id="modalImg" src="" alt="확대">
</div>

<script>
function validateForm() {
  var fields = ['production_capacity','current_inventory','moq','lead_time_days','unit_price'];
  var ok = true;
  fields.forEach(function(id) {
    var el = document.getElementById(id);
    if (!el || !el.value.trim()) { if(el) el.classList.add('invalid'); ok = false; }
    else if(el) el.classList.remove('invalid');
  });
  if (!ok) alert('필수 항목을 모두 입력해주세요.');
  return ok;
}
document.querySelectorAll('input,select').forEach(function(el) {
  el.addEventListener('input', function() { this.classList.remove('invalid'); });
});
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') document.getElementById('imgModal').classList.remove('show');
});
</script>
</body>
</html>
