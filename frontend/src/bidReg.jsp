<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page isELIgnored="true" %>
<%@ page import="java.util.*, java.sql.*, util.DBUtil" %>
<%!
    public static class BidItem {
        int id;
        String partName, partCode, partCategory, material, spec, usage, feature;
        List<String> imageBase64List = new ArrayList<String>();
        List<String> imageTypeList   = new ArrayList<String>();
        String registeredBy;
        public BidItem(int id) { this.id = id; }
    }
    public BidItem findItemById(List<BidItem> list, int id) {
        for (BidItem item : list) { if (item.id == id) return item; }
        return null;
    }
    public String nvl(String s) { return s == null ? "" : s.trim(); }
%>
<%
    request.setCharacterEncoding("UTF-8");

    if (session.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp"); return;
    }

    String userId    = (String) session.getAttribute("userId");
    String company   = (String) session.getAttribute("company");
    String role      = (String) session.getAttribute("role");
    String roleLabel = (String) session.getAttribute("roleLabel");
    boolean isScm    = "scm".equals(role);

    String message = "";
    String msgType = "success";

    // ── 로그인 사용자 정보 DB 조회 (읽기전용) ──────────────────────
    String userName = "-", email = "-", phone = "-";
    String bizNo = "-", corpNo = "-", techCert = "-";
    String vendorAddr = "-";

    Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
    try {
        conn = DBUtil.getConnection();
        ps = conn.prepareStatement(
            "SELECT u.user_name, u.email, u.phone, u.biz_no, u.corp_no, u.tech_cert, " +
            "v.address FROM users u LEFT JOIN vendors v ON u.company_id = v.vendor_id " +
            "WHERE u.user_id = ?");
        ps.setString(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            userName   = rs.getString("user_name") != null ? rs.getString("user_name") : "-";
            email      = rs.getString("email")     != null ? rs.getString("email")     : "-";
            phone      = rs.getString("phone")     != null ? rs.getString("phone")     : "-";
            bizNo      = rs.getString("biz_no")    != null ? rs.getString("biz_no")    : "-";
            corpNo     = rs.getString("corp_no")   != null ? rs.getString("corp_no")   : "-";
            techCert   = rs.getString("tech_cert") != null ? rs.getString("tech_cert") : "-";
            vendorAddr = rs.getString("address")   != null ? rs.getString("address")   : "-";
        }
    } catch (Exception e) {
        message = "사용자 정보 조회 오류: " + e.getMessage(); msgType = "error";
    } finally {
        DBUtil.close(conn, ps, rs);
    }

    // ── Session 목록 ──────────────────────────────────────────────
    List<BidItem> bidList = (List<BidItem>) session.getAttribute("bidList");
    if (bidList == null) { bidList = new ArrayList<BidItem>(); session.setAttribute("bidList", bidList); }

    Integer nextId = (Integer) session.getAttribute("nextId");
    if (nextId == null) { nextId = 1; session.setAttribute("nextId", nextId); }

    String action = nvl(request.getParameter("action"));

    // ── 다른 페이지에서 진입 시 자동 초기화 ─────────────────────
    // POST(action 있음)는 제외하고, 외부 페이지에서 GET으로 넘어온 경우만 초기화
    if (action.isEmpty()) {
        String referer = request.getHeader("Referer");
        boolean comingFromSamePage = (referer != null && referer.contains("bidReg.jsp"));
        if (!comingFromSamePage) {
            bidList.clear();
            session.setAttribute("bidList", bidList);
            nextId = 1;
            session.setAttribute("nextId", nextId);
        }
    }

    // ── POST: 부품 목록에 추가 ────────────────────────────────────
    if ("addPart".equals(action)) {
        String partName     = nvl(request.getParameter("partName"));
        String partCode     = nvl(request.getParameter("partCode"));
        String partCategory = nvl(request.getParameter("partCategory"));
        String material     = nvl(request.getParameter("material"));
        String spec         = nvl(request.getParameter("spec"));
        String usage        = nvl(request.getParameter("usage"));
        String feature      = nvl(request.getParameter("feature"));

        // 여러 장 이미지 수집 (imageBase64_0, imageBase64_1, ...)
        List<String> imgBase64s = new ArrayList<String>();
        List<String> imgTypes   = new ArrayList<String>();
        for (int fi = 0; fi < 20; fi++) {
            String b64  = nvl(request.getParameter("imageBase64_" + fi));
            String type = nvl(request.getParameter("imageType_" + fi));
            if (!b64.isEmpty()) { imgBase64s.add(b64); imgTypes.add(type.isEmpty() ? "image/jpeg" : type); }
        }

        List<String> missing = new ArrayList<String>();
        if (partName.isEmpty())     missing.add("부품명");
        if (partCode.isEmpty())     missing.add("부품코드");
        if (partCategory.isEmpty()) missing.add("부품분류");
        if (material.isEmpty())     missing.add("재질");
        if (spec.isEmpty())         missing.add("규격");
        if (usage.isEmpty())        missing.add("용도");
        if (feature.isEmpty())      missing.add("특징");
        if (imgBase64s.isEmpty())   missing.add("부품 사진");

        if (!missing.isEmpty()) {
            message = "필수 항목을 입력해주세요: " + String.join(", ", missing);
            msgType = "error";
        } else {
            BidItem item      = new BidItem(nextId);
            item.partName     = partName;
            item.partCode     = partCode;
            item.partCategory = partCategory;
            item.material     = material;
            item.spec         = spec;
            item.usage        = usage;
            item.feature      = feature;
            item.imageBase64List = imgBase64s;
            item.imageTypeList   = imgTypes;
            item.registeredBy = userId;
            bidList.add(item);
            nextId++;
            session.setAttribute("nextId", nextId);
            session.setAttribute("bidList", bidList);
            message = "부품이 목록에 추가되었습니다! (사진 " + imgBase64s.size() + "장)";
        }
    }

    // ── POST: DB 최종 등록 (bids + bid_images) ───────────────────
    if ("finalReg".equals(action)) {
        if (bidList.isEmpty()) {
            message = "등록할 부품이 없습니다."; msgType = "error";
        } else {
            Connection connW = null; PreparedStatement psW = null; ResultSet rsW = null;
            try {
                connW = DBUtil.getConnection();
                connW.setAutoCommit(false);
                int successCnt = 0;
                for (BidItem item : bidList) {
                    // 1) bids 테이블에 INSERT (대표 이미지는 첫 번째)
                    byte[] firstImg = null;
                    String firstType = "image/jpeg";
                    if (!item.imageBase64List.isEmpty()) {
                        String b64 = item.imageBase64List.get(0);
                        firstImg  = java.util.Base64.getDecoder().decode(
                            b64.contains(",") ? b64.split(",")[1] : b64);
                        firstType = item.imageTypeList.get(0);
                    }
                    psW = connW.prepareStatement(
                        "INSERT INTO bids (title, creator_id, status, reg_dt, " +
                        "part_name, part_code, part_category, material, spec, part_image, part_image_type) " +
                        "VALUES (?, ?, 'OPEN', NOW(), ?, ?, ?, ?, ?, ?, ?)",
                        PreparedStatement.RETURN_GENERATED_KEYS);
                    psW.setString(1, item.partName); // title = 부품명으로 자동 설정
                    psW.setString(2, userId);
                    psW.setString(3, item.partName);
                    psW.setString(4, item.partCode);
                    psW.setString(5, item.partCategory);
                    psW.setString(6, item.material);
                    psW.setString(7, item.spec);
                    psW.setBytes(8, firstImg);
                    psW.setString(9, firstType);
                    psW.executeUpdate();
                    rsW = psW.getGeneratedKeys();
                    int bidId = rsW.next() ? rsW.getInt(1) : 0;
                    rsW.close(); psW.close();

                    // 2) bid_images 테이블에 전체 이미지 INSERT
                    for (int i = 0; i < item.imageBase64List.size(); i++) {
                        String b64 = item.imageBase64List.get(i);
                        byte[] imgBytes = java.util.Base64.getDecoder().decode(
                            b64.contains(",") ? b64.split(",")[1] : b64);
                        psW = connW.prepareStatement(
                            "INSERT INTO bid_images (bid_id, image_data, image_type, sort_order) VALUES (?, ?, ?, ?)");
                        psW.setInt(1, bidId);
                        psW.setBytes(2, imgBytes);
                        psW.setString(3, item.imageTypeList.get(i));
                        psW.setInt(4, i);
                        psW.executeUpdate();
                        psW.close(); psW = null;
                    }
                    successCnt++;
                }
                connW.commit();
                bidList.clear();
                session.setAttribute("bidList", bidList);
                message = successCnt + "개 부품이 DB에 최종 등록되었습니다!";
            } catch (SQLException e) {
                if (connW != null) try { connW.rollback(); } catch (Exception ex) {}
                e.printStackTrace();
                message = "DB 등록 오류: " + e.getMessage(); msgType = "error";
            } finally {
                if (connW != null) try { connW.setAutoCommit(true); } catch (Exception ex) {}
                DBUtil.close(connW, psW, rsW);
            }
        }
    }

    // ── 삭제 ─────────────────────────────────────────────────────
    if ("delete".equals(action)) {
        try {
            int delId    = Integer.parseInt(request.getParameter("id"));
            BidItem item = findItemById(bidList, delId);
            if (item != null && (isScm || item.registeredBy.equals(userId))) {
                bidList.remove(item);
                session.setAttribute("bidList", bidList);
                message = "삭제되었습니다.";
            } else { message = "삭제 권한이 없습니다."; msgType = "error"; }
        } catch (Exception e) { message = "삭제 오류 발생"; msgType = "error"; }
    }

    // ── 전체 초기화 ───────────────────────────────────────────────
    if ("clear".equals(action)) {
        bidList.clear();
        session.setAttribute("bidList", bidList);
        message = "전체 목록이 초기화되었습니다.";
    }
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HMC SCM | 발주 등록</title>
<link rel="stylesheet" href="/project/style.css">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing:border-box; margin:0; padding:0; }
  :root { --primary:#003DA5; --accent:#00AAD4; --panel:#0D1B2A; --surface:#112240; --sidebar:#0a1520; --border:rgba(0,170,212,.2); --text:#E8F0FE; --muted:#7A8FA6; --success:#00E5A0; --warning:#F59E0B; --danger:#EF4444; }
  html, body { font-family:'Noto Sans KR',sans-serif; background:var(--panel); color:var(--text); min-height:100%; }
  .wrapper { display:flex; flex-direction:column; min-height:100vh; }
  .layout  { flex:1; display:grid; grid-template-columns:220px 1fr; }
  .main { padding:28px; overflow-y:auto; }
  .page-title { font-size:20px; font-weight:700; letter-spacing:1px; margin-bottom:24px; }
  .page-title span { color:var(--accent); font-weight:400; }
  .msg { padding:12px 16px; border-radius:8px; margin-bottom:20px; font-size:13px; display:flex; align-items:center; gap:8px; }
  .msg.success { background:rgba(0,229,160,.08); border:1px solid rgba(0,229,160,.2); color:var(--success); }
  .msg.error   { background:rgba(239,68,68,.08); border:1px solid rgba(239,68,68,.25); color:var(--danger); }
  .section-card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:20px; margin-bottom:20px; }
  .section-title { font-size:13px; font-weight:500; color:var(--accent); letter-spacing:1.5px; text-transform:uppercase; border-left:3px solid var(--accent); padding-left:10px; margin-bottom:16px; }
  .grid2 { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  /* 읽기전용 업체정보 */
  .info-item { display:flex; flex-direction:column; gap:5px; }
  .info-label { font-size:11px; color:var(--muted); letter-spacing:.5px; }
  .info-value { font-size:13px; color:var(--text); background:rgba(255,255,255,.03); border:1px solid rgba(255,255,255,.06); border-radius:8px; padding:10px 13px; min-height:38px; }
  .info-value.mono { font-family:'Share Tech Mono',monospace; color:var(--accent); }
  .field { display:flex; flex-direction:column; gap:6px; }
  .field.full { grid-column:1/-1; }
  label { font-size:12px; color:var(--muted); letter-spacing:.5px; }
  .required { color:var(--danger); margin-left:3px; }
  input[type="text"], input[type="number"], input[type="email"], select {
    background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1);
    border-radius:8px; padding:10px 14px; color:var(--text);
    font-family:'Noto Sans KR',sans-serif; font-size:13px; outline:none;
    transition:border-color .2s,background .2s; width:100%;
  }
  input:focus, select:focus { border-color:var(--accent); background:rgba(0,170,212,.06); }
  input.invalid, select.invalid { border-color:var(--danger)!important; background:rgba(239,68,68,.05)!important; }
  input::placeholder { color:rgba(122,143,166,.4); }
  select option { background:#112240; color:var(--text); }
  .help { font-size:11px; color:var(--muted); margin-top:3px; }
  input[type="file"] { display:none; }
  .file-label { display:flex; align-items:center; gap:10px; cursor:pointer; background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1); border-radius:8px; padding:10px 14px; transition:all .2s; width:100%; }
  .file-label:hover { border-color:var(--accent); background:rgba(0,170,212,.06); }
  .file-label.invalid { border-color:var(--danger)!important; background:rgba(239,68,68,.05)!important; }
  .file-label svg { color:var(--accent); flex-shrink:0; }
  .file-label .file-text { font-size:13px; color:var(--muted); }
  .preview-box { margin-top:8px; display:none; flex-wrap:wrap; gap:8px; }
  .btn { border:none; border-radius:8px; padding:10px 18px; cursor:pointer; font-size:13px; font-weight:500; font-family:'Noto Sans KR',sans-serif; transition:all .2s; }
  .btn-accent  { background:rgba(0,170,212,.15); border:1px solid rgba(0,170,212,.4); color:var(--accent); }
  .btn-accent:hover  { background:rgba(0,170,212,.25); }
  .btn-success { background:rgba(0,229,160,.15); border:1px solid rgba(0,229,160,.3); color:var(--success); }
  .btn-success:hover { background:rgba(0,229,160,.25); }
  .btn-danger  { background:rgba(239,68,68,.15); border:1px solid rgba(239,68,68,.3); color:var(--danger); }
  .btn-danger:hover  { background:rgba(239,68,68,.25); }
  .btn-ghost   { background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1); color:var(--muted); }
  .btn-ghost:hover   { background:rgba(255,255,255,.08); }
  .btn-area { display:flex; gap:10px; flex-wrap:wrap; margin-top:16px; }
  .tbl { width:100%; border-collapse:collapse; font-size:12px; }
  .tbl th { color:var(--muted); font-weight:500; padding:8px 10px; border-bottom:1px solid rgba(255,255,255,.07); text-align:left; white-space:nowrap; }
  .tbl td { padding:10px; border-bottom:1px solid rgba(255,255,255,.04); color:#B0C4D8; vertical-align:middle; }
  .tbl tr:hover td { background:rgba(0,170,212,.03); }
  .badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:10px; font-weight:600; }
  .badge-blue { background:rgba(0,170,212,.15); color:#00AAD4; }
  .img-thumb { width:52px; height:40px; object-fit:cover; border-radius:6px; border:1px solid var(--border); cursor:pointer; transition:transform .2s; }
  .img-thumb:hover { transform:scale(1.1); border-color:var(--accent); }
  .no-img { font-size:10px; color:var(--muted); }
  .img-modal { display:none; position:fixed; inset:0; z-index:9999; background:rgba(0,0,0,.85); align-items:center; justify-content:center; }
  .img-modal.show { display:flex; }
  .img-modal img { max-width:80vw; max-height:80vh; border-radius:12px; border:2px solid var(--accent); }
  .modal-close { position:absolute; top:20px; right:28px; background:rgba(255,255,255,.1); border:1px solid rgba(255,255,255,.2); color:#fff; border-radius:50%; width:36px; height:36px; font-size:18px; cursor:pointer; display:flex; align-items:center; justify-content:center; }
  .modal-close:hover { background:rgba(239,68,68,.3); }
</style>
</head>
<body>
<div class="wrapper">
  <jsp:include page="/project/navbar.jsp" />
  <div class="layout">
    <jsp:include page="/project/sidebar.jsp" />
    <div class="main">
      <div class="page-title">발주 등록 <span>/ 부품 정보 입력</span></div>

      <% if (!message.isEmpty()) { %>
      <div class="msg <%= msgType %>">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <% if ("error".equals(msgType)) { %><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          <% } else { %><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22,4 12,14.01 9,11.01"/><% } %>
        </svg>
        <%= message %>
      </div>
      <% } %>

      <!-- 1. 업체 기본 정보 (DB 자동조회, 읽기전용) -->
      <div class="section-card">
        <div class="section-title">1. 업체 기본 정보</div>
        <div class="grid2">
          <div class="info-item"><div class="info-label">회사명</div><div class="info-value"><%= company %></div></div>
          <div class="info-item"><div class="info-label">역할</div><div class="info-value"><%= roleLabel != null ? roleLabel : role %></div></div>
          <div class="info-item"><div class="info-label">담당자명</div><div class="info-value"><%= userName %></div></div>
          <div class="info-item"><div class="info-label">연락처</div><div class="info-value"><%= phone %></div></div>
          <div class="info-item"><div class="info-label">이메일</div><div class="info-value"><%= email %></div></div>
          <div class="info-item"><div class="info-label">기술인증</div><div class="info-value"><%= techCert %></div></div>
          <div class="info-item"><div class="info-label">사업자번호</div><div class="info-value mono"><%= bizNo %></div></div>
          <div class="info-item"><div class="info-label">소재지</div><div class="info-value"><%= vendorAddr %></div></div>
        </div>
      </div>

      <!-- 2. 부품 정보 입력 폼 -->
      <form method="post" action="bidReg.jsp" id="regForm" onsubmit="return validateForm()">
        <input type="hidden" name="action" value="addPart">
        <div id="hiddenImgContainer"></div>

        <div class="section-card">
          <div class="section-title">2. 부품 기본 정보</div>
          <div class="grid2">
            <div class="field" style="position:relative;">
              <label>부품명<span class="required">*</span></label>
              <div style="position:relative;">
                <input type="text" id="partName" name="partName" placeholder="부품명 또는 코드 입력 후 검색" autocomplete="off">
                <span id="searchSpinner" style="display:none;position:absolute;right:12px;top:50%;transform:translateY(-50%);color:var(--accent);font-size:12px;">검색중...</span>
              </div>
              <div class="help" style="color:var(--accent);opacity:.7;">💡 2글자 이상 입력하면 부품 DB에서 자동검색됩니다</div>
              <!-- 자동완성 드롭다운 -->
              <div id="autocompleteList" style="
                display:none; position:absolute; top:100%; left:0; right:0; z-index:999;
                background:#0D1B2A; border:1px solid rgba(0,170,212,.4);
                border-radius:0 0 10px 10px; max-height:260px; overflow-y:auto;
                box-shadow:0 8px 24px rgba(0,0,0,.5);
              "></div>
            </div>
            <div class="field"><label>부품코드<span class="required">*</span></label><input type="text" id="partCode" name="partCode" placeholder="부품명 검색 시 자동입력"></div>
            <div class="field">
              <label>부품분류<span class="required">*</span></label>
              <select id="partCategory" name="partCategory">
                <option value="">선택하세요</option>
                <option value="원자재">원자재</option>
                <option value="부품">부품</option>
                <option value="반제품">반제품</option>
                <option value="완제품">완제품</option>
              </select>
            </div>
            <div class="field"><label>재질<span class="required">*</span></label><input type="text" id="material" name="material" placeholder="부품 선택 시 자동입력 (직접 수정 가능)"></div>
            <div class="field"><label>규격<span class="required">*</span></label><input type="text" id="spec" name="spec" placeholder="부품 선택 시 자동입력 (직접 수정 가능)"></div>
            <div class="field"><label>용도<span class="required">*</span></label><input type="text" id="usage" name="usage" placeholder="부품 선택 시 자동입력 (직접 수정 가능)"></div>
            <div class="field"><label>특징<span class="required">*</span></label><input type="text" id="feature" name="feature" placeholder="부품 선택 시 자동입력 (직접 수정 가능)"></div>
            <div class="field">
              <label>부품 사진<span class="required">*</span></label>
              <label class="file-label" id="fileLabel" for="partImageFile">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17,8 12,3 7,8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                <span id="fileText" class="file-text">파일을 선택하세요 (여러 장 가능)</span>
              </label>
              <input type="file" id="partImageFile" accept="image/*" multiple onchange="previewImages(this)">
              <div class="preview-box" id="previewBox"></div>
              <div class="help">최대 5MB / jpg, png, gif / 여러 장 모두 bid_images 테이블에 저장</div>
            </div>
          </div>
          <div class="btn-area">
            <button type="submit" class="btn btn-accent">+ 부품 목록에 추가</button>
            <button type="reset" class="btn btn-ghost" onclick="resetPreview()">초기화</button>
          </div>
        </div>
      </form>

      <!-- 등록된 부품 목록 -->
      <div class="section-card">
        <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:14px;">
          <div class="section-title" style="margin-bottom:0;">등록된 부품 목록</div>
          <div style="display:flex; gap:8px; align-items:center;">
            <% if (!bidList.isEmpty()) { %>
            <form method="post" style="margin:0;">
              <input type="hidden" name="action" value="finalReg">
              <button type="submit" class="btn btn-success"
                      onclick="return confirm('<%= bidList.size() %>개 부품을 DB에 최종 등록할까요?')">
                ✓ DB 등록 (<%= bidList.size() %>개)
              </button>
            </form>
            <% } %>
            <form method="post" action="bidReg.jsp" style="margin:0;">
              <input type="hidden" name="action" value="clear">
              <button type="submit" class="btn btn-danger" style="padding:6px 12px; font-size:11px;"
                      onclick="return confirm('전체 목록을 초기화할까요?')">전체 초기화</button>
            </form>
          </div>
        </div>

        <% if (bidList.isEmpty()) { %>
        <div style="text-align:center; padding:30px; color:var(--muted); font-size:13px;">
          아직 추가된 부품이 없습니다. 위에서 부품 정보를 입력하고 추가해주세요.
        </div>
        <% } else { %>
        <style>
          .part-tbl { width:100%; border-collapse:collapse; font-size:13px; table-layout:fixed; }
          .part-tbl colgroup col:nth-child(1)  { width:44px; }
          .part-tbl colgroup col:nth-child(2)  { width:160px; }
          .part-tbl colgroup col:nth-child(3)  { width:130px; }
          .part-tbl colgroup col:nth-child(4)  { width:70px; }
          .part-tbl colgroup col:nth-child(5)  { width:90px; }
          .part-tbl colgroup col:nth-child(6)  { width:160px; }
          .part-tbl colgroup col:nth-child(7)  { width:120px; }
          .part-tbl colgroup col:nth-child(8)  { width:180px; }
          .part-tbl colgroup col:nth-child(9)  { width:80px; }
          .part-tbl colgroup col:nth-child(10) { width:64px; }
          .part-tbl th {
            font-size:11px; font-weight:600; letter-spacing:.6px; text-transform:uppercase;
            color:var(--muted); padding:10px 12px;
            border-bottom:1px solid rgba(0,170,212,.2);
            background:rgba(0,0,0,.15); text-align:left; white-space:nowrap;
          }
          .part-tbl td {
            padding:12px; vertical-align:middle;
            border-bottom:1px solid rgba(255,255,255,.04);
            color:var(--text); font-size:13px; word-break:keep-all; line-height:1.5;
          }
          .part-tbl tr:hover td { background:rgba(0,170,212,.04); }
          .part-tbl .cell-num  { text-align:center; color:var(--muted); font-size:12px; font-weight:600; }
          .part-tbl .cell-name { font-weight:500; color:var(--text); }
          .part-tbl .cell-code { font-family:'Share Tech Mono',monospace; font-size:11px; color:var(--accent); letter-spacing:.3px; word-break:break-all; }
          .part-tbl .cell-mat  { color:#B0C4D8; font-size:12px; }
          .part-tbl .cell-spec { color:#B0C4D8; font-size:12px; line-height:1.6; }
          .part-tbl .cell-use  { color:#B0C4D8; font-size:12px; }
          .part-tbl .cell-feat { color:#B0C4D8; font-size:12px; line-height:1.6; }
          .part-tbl .badge-cat {
            display:inline-block; padding:3px 9px; border-radius:5px; font-size:11px;
            font-weight:600; letter-spacing:.3px; white-space:nowrap;
            background:rgba(0,170,212,.12); color:var(--accent);
            border:1px solid rgba(0,170,212,.25);
          }
        </style>
        <div style="overflow-x:auto;">
          <table class="part-tbl">
            <colgroup>
              <col/><col/><col/><col/><col/><col/><col/><col/><col/><col/>
            </colgroup>
            <thead>
              <tr>
                <th style="text-align:center;">#</th>
                <th>부품명</th>
                <th>코드</th>
                <th>분류</th>
                <th>재질</th>
                <th>규격</th>
                <th>용도</th>
                <th>특징</th>
                <th style="text-align:center;">사진</th>
                <th style="text-align:center;">관리</th>
              </tr>
            </thead>
            <tbody>
            <% for (int i = 0; i < bidList.size(); i++) {
               BidItem item = bidList.get(i);
               boolean canDel = isScm || item.registeredBy.equals(userId);
            %>
            <tr>
              <td class="cell-num"><%= i+1 %></td>
              <td class="cell-name"><%= item.partName %></td>
              <td class="cell-code"><%= item.partCode %></td>
              <td><span class="badge-cat"><%= item.partCategory %></span></td>
              <td class="cell-mat"><%= item.material %></td>
              <td class="cell-spec"><%= item.spec %></td>
              <td class="cell-use"><%= item.usage %></td>
              <td class="cell-feat"><%= item.feature %></td>
              <td style="text-align:center;">
                <div style="display:flex; gap:4px; flex-wrap:wrap; justify-content:center;">
                <% for (int j = 0; j < item.imageBase64List.size(); j++) {
                     String b64 = item.imageBase64List.get(j);
                     String imgType = item.imageTypeList.get(j);
                     String imgSrc = "data:" + imgType + ";base64," + (b64.contains(",") ? b64.split(",")[1] : b64);
                %>
                  <img src="<%= imgSrc %>" class="img-thumb" onclick="openImg(this.src)" alt="부품사진">
                <% } %>
                <% if (item.imageBase64List.isEmpty()) { %><span class="no-img">없음</span><% } %>
                </div>
              </td>
              <td style="text-align:center;">
                <% if (canDel) { %>
                <form method="post" style="margin:0;">
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="id" value="<%= item.id %>">
                  <button type="submit" class="btn btn-danger" style="padding:5px 12px;font-size:12px;" onclick="return confirm('삭제할까요?')">삭제</button>
                </form>
                <% } else { %><span style="font-size:12px;color:var(--muted)">—</span><% } %>
              </td>
            </tr>
            <% } %>
            </tbody>
          </table>
        </div>
        <% } %>
      </div>

    </div>
  </div>
  <jsp:include page="/project/footer.jsp" />
</div>

<div class="img-modal" id="imgModal" onclick="closeImg()">
  <div class="modal-close" onclick="closeImg()">✕</div>
  <img id="modalImg" src="" alt="부품 사진 확대">
</div>

<script>
var selectedFiles = [];

// ── 부품명 자동완성 ──────────────────────────────────────
(function() {
  var input     = document.getElementById('partName');
  var dropdown  = document.getElementById('autocompleteList');
  var spinner   = document.getElementById('searchSpinner');
  var timer     = null;
  var currentKw = '';

  input.addEventListener('input', function() {
    var kw = this.value.trim();
    clearTimeout(timer);
    if (kw.length < 2) { hideDropdown(); return; }
    currentKw = kw;
    spinner.style.display = 'inline';
    timer = setTimeout(function() { fetchParts(kw); }, 300);
  });

  input.addEventListener('keydown', function(e) {
    var items = dropdown.querySelectorAll('.ac-item');
    var active = dropdown.querySelector('.ac-item.active');
    if (!items.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      var next = active ? active.nextElementSibling : items[0];
      if (!next) next = items[0];
      if (active) active.classList.remove('active');
      next.classList.add('active');
      next.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      var prev = active ? active.previousElementSibling : items[items.length - 1];
      if (!prev) prev = items[items.length - 1];
      if (active) active.classList.remove('active');
      prev.classList.add('active');
      prev.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'Enter') {
      if (active) { e.preventDefault(); active.click(); }
    } else if (e.key === 'Escape') {
      hideDropdown();
    }
  });

  document.addEventListener('click', function(e) {
    if (!e.target.closest('#partName') && !e.target.closest('#autocompleteList')) {
      hideDropdown();
    }
  });

  function fetchParts(kw) {
    fetch('partSearch.jsp?q=' + encodeURIComponent(kw))
      .then(function(r) { return r.json(); })
      .then(function(data) {
        spinner.style.display = 'none';
        if (kw !== currentKw) return;
        renderDropdown(data, kw);
      })
      .catch(function() { spinner.style.display = 'none'; });
  }

  function renderDropdown(items, kw) {
    if (!items || items.length === 0) {
      dropdown.innerHTML = '<div style="padding:12px 16px;color:var(--muted);font-size:12px;">검색 결과가 없습니다.</div>';
      dropdown.style.display = 'block';
      return;
    }
    var html = '';
    items.forEach(function(p) {
      var highlighted = p.part_name_ko.replace(
        new RegExp('(' + escapeRegex(kw) + ')', 'gi'),
        '<mark style="background:rgba(0,170,212,.3);color:var(--accent);border-radius:2px;padding:0 2px;">$1</mark>'
      );
      var tags = [];
      if (p.vehicle_domain) tags.push('<span style="background:rgba(0,229,160,.12);color:#00E5A0;border-radius:3px;padding:1px 6px;font-size:10px;">' + p.vehicle_domain + '</span>');
      if (p.system_major)   tags.push('<span style="background:rgba(0,170,212,.12);color:var(--accent);border-radius:3px;padding:1px 6px;font-size:10px;">' + p.system_major + '</span>');
      if (p.system_minor)   tags.push('<span style="background:rgba(255,255,255,.06);color:var(--muted);border-radius:3px;padding:1px 6px;font-size:10px;">' + p.system_minor + '</span>');

      html += '<div class="ac-item" style="' +
        'padding:10px 14px;cursor:pointer;border-bottom:1px solid rgba(255,255,255,.04);' +
        'transition:background .15s;"' +
        ' data-part=\'' + JSON.stringify(p).replace(/'/g,"&#39;") + '\'' +
        ' onmouseenter="this.classList.add(\'active\')"' +
        ' onmouseleave="this.classList.remove(\'active\')">' +
        '<div style="font-size:13px;color:var(--text);margin-bottom:4px;">' + highlighted + '</div>' +
        '<div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;">' +
          '<span style="font-family:monospace;font-size:11px;color:var(--accent);">' + p.part_code + '</span>' +
          tags.join('') +
        '</div>' +
        (p.part_name_en ? '<div style="font-size:11px;color:var(--muted);margin-top:2px;">' + p.part_name_en + '</div>' : '') +
        '</div>';
    });
    dropdown.innerHTML = html;
    dropdown.style.display = 'block';

    // 클릭 이벤트
    dropdown.querySelectorAll('.ac-item').forEach(function(el) {
      el.addEventListener('click', function() {
        var p = JSON.parse(this.getAttribute('data-part'));
        fillFields(p);
        hideDropdown();
      });
    });
  }

  function fillFields(p) {
    // 부품명, 코드 자동입력
    document.getElementById('partName').value = p.part_name_ko || '';
    document.getElementById('partCode').value  = p.part_code    || '';

    // 재질: material_group 매핑
    var mat = document.getElementById('material');
    if (p.material_group) mat.value = p.material_group;

    // 규격: primary + secondary spec 조합
    var specParts = [];
    if (p.primary_spec && p.primary_unit)    specParts.push(p.primary_spec + ' (' + p.primary_unit + ')');
    else if (p.primary_spec)                  specParts.push(p.primary_spec);
    if (p.secondary_spec && p.secondary_unit) specParts.push(p.secondary_spec + ' (' + p.secondary_unit + ')');
    else if (p.secondary_spec)                specParts.push(p.secondary_spec);
    var spec = document.getElementById('spec');
    if (specParts.length > 0) spec.value = specParts.join(', ');

    // 용도: system_major > system_minor 조합
    var usageParts = [];
    if (p.system_major) usageParts.push(p.system_major);
    if (p.system_minor) usageParts.push(p.system_minor);
    var usage = document.getElementById('usage');
    if (usageParts.length > 0) usage.value = usageParts.join(' > ');

    // 특징: vehicle_domain + ksic_name
    var featureParts = [];
    if (p.vehicle_domain) featureParts.push('차종: ' + p.vehicle_domain);
    if (p.ksic_name)      featureParts.push(p.ksic_name);
    var feature = document.getElementById('feature');
    if (featureParts.length > 0) feature.value = featureParts.join(' | ');

    // invalid 스타일 제거
    ['partName','partCode','material','spec','usage','feature'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el && el.value.trim()) el.classList.remove('invalid');
    });

    // 자동입력 완료 토스트
    showToast('✓ 부품 정보가 자동으로 입력되었습니다. 필요하면 직접 수정하세요.');
  }

  function hideDropdown() {
    dropdown.style.display = 'none';
    spinner.style.display = 'none';
  }

  function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
})();

// 자동입력 완료 토스트
function showToast(msg) {
  var t = document.createElement('div');
  t.textContent = msg;
  t.style.cssText = 'position:fixed;bottom:28px;left:50%;transform:translateX(-50%);' +
    'background:#00E5A0;color:#0D1B2A;padding:10px 20px;border-radius:8px;font-size:13px;font-weight:600;' +
    'z-index:9999;box-shadow:0 4px 16px rgba(0,229,160,.3);transition:opacity .4s;';
  document.body.appendChild(t);
  setTimeout(function() { t.style.opacity='0'; setTimeout(function(){t.remove();},400); }, 2500);
}

// ac-item active 스타일
var acStyle = document.createElement('style');
acStyle.textContent = '.ac-item.active { background: rgba(0,170,212,.1) !important; }';
document.head.appendChild(acStyle);



function previewImages(input) {
  if (input.files && input.files.length > 0) {
    Array.from(input.files).forEach(function(file) {
      if (file.size > 5 * 1024 * 1024) { alert(file.name + ' 파일이 5MB를 초과합니다.'); return; }
      selectedFiles.push(file);
    });
    renderPreviews();
    input.value = '';
  }
}

function renderPreviews() {
  var fileText   = document.getElementById('fileText');
  var previewBox = document.getElementById('previewBox');
  var fileLabel  = document.getElementById('fileLabel');
  previewBox.innerHTML = '';
  if (selectedFiles.length === 0) {
    fileText.textContent = '파일을 선택하세요 (여러 장 가능)';
    previewBox.style.display = 'none'; return;
  }
  fileText.textContent = selectedFiles.length + '개 파일 선택됨';
  fileLabel.classList.remove('invalid');
  previewBox.style.display = 'flex';
  selectedFiles.forEach(function(file, index) {
    var reader = new FileReader();
    reader.onload = function(e) {
      var wrapper = document.createElement('div');
      wrapper.style.cssText = 'position:relative; display:inline-block;';
      var img = document.createElement('img');
      img.src = e.target.result;
      img.style.cssText = 'width:80px;height:60px;object-fit:cover;border-radius:6px;border:1px solid rgba(0,170,212,.2);cursor:pointer;display:block;';
      img.onclick = function() { openImg(e.target.result); };
      var btn = document.createElement('button');
      btn.type = 'button'; btn.textContent = '✕';
      btn.style.cssText = 'position:absolute;top:-6px;right:-6px;width:18px;height:18px;background:#EF4444;border:none;border-radius:50%;color:#fff;font-size:10px;font-weight:700;cursor:pointer;';
      btn.onclick = function() { removeFile(index); };
      wrapper.appendChild(img); wrapper.appendChild(btn); previewBox.appendChild(wrapper);
    };
    reader.readAsDataURL(file);
  });
}

function removeFile(index) { selectedFiles.splice(index, 1); renderPreviews(); }

function resetPreview() {
  selectedFiles = [];
  document.getElementById('fileText').textContent = '파일을 선택하세요 (여러 장 가능)';
  var previewBox = document.getElementById('previewBox');
  previewBox.innerHTML = ''; previewBox.style.display = 'none';
  document.getElementById('hiddenImgContainer').innerHTML = '';
}

function validateForm() {
  var fields = [
    {id:'partName',label:'부품명'},{id:'partCode',label:'부품코드'},
    {id:'material',label:'재질'},{id:'spec',label:'규격'},
    {id:'usage',label:'용도'},{id:'feature',label:'특징'}
  ];
  var missing = [];
  fields.forEach(function(f) {
    var el = document.getElementById(f.id);
    if (!el.value.trim()) { el.classList.add('invalid'); missing.push(f.label); }
    else el.classList.remove('invalid');
  });
  var cat = document.getElementById('partCategory');
  if (!cat.value) { cat.classList.add('invalid'); missing.push('부품분류'); }
  else cat.classList.remove('invalid');
  if (selectedFiles.length === 0) {
    document.getElementById('fileLabel').classList.add('invalid');
    missing.push('부품 사진');
  }
  if (missing.length > 0) { alert('필수 항목을 입력해주세요:\n' + missing.join(', ')); return false; }

  // 모든 이미지를 Base64로 변환 후 hidden input으로 추가
  var container = document.getElementById('hiddenImgContainer');
  container.innerHTML = '';
  var done = 0;
  selectedFiles.forEach(function(file, i) {
    var reader = new FileReader();
    reader.onload = function(e) {
      var inputB64 = document.createElement('input');
      inputB64.type = 'hidden';
      inputB64.name = 'imageBase64_' + i;
      inputB64.value = e.target.result;
      var inputType = document.createElement('input');
      inputType.type = 'hidden';
      inputType.name = 'imageType_' + i;
      inputType.value = file.type;
      container.appendChild(inputB64);
      container.appendChild(inputType);
      done++;
      if (done === selectedFiles.length) {
        document.getElementById('regForm').submit();
      }
    };
    reader.readAsDataURL(file);
  });
  return false; // FileReader 비동기 → JS에서 직접 submit
}

document.querySelectorAll('input, select').forEach(function(el) {
  el.addEventListener('input',  function() { this.classList.remove('invalid'); });
  el.addEventListener('change', function() { this.classList.remove('invalid'); });
});
function openImg(url) { document.getElementById('modalImg').src = url; document.getElementById('imgModal').classList.add('show'); }
function closeImg()   { document.getElementById('imgModal').classList.remove('show'); }
document.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeImg(); });
</script>
</body>
</html>
