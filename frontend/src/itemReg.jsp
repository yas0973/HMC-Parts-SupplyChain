<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>

<%!
    public static class PartItem {
        int id;

        String vendorName;
        String region;
        String contactName;
        String contactPhone;
        String contactEmail;
        String certification;

        String partName;
        String partCode;
        String partCategory;
        String partImage;   // 실제 업로드 대신 이미지 URL 또는 파일명
        String description;

        String maxCapacity;
        String availableStock;
        String minimumOrderQty;
        String productionLeadTime;

        String unitCost;
        String transportCost;
        String delayRisk;
        String defectRate;

        public PartItem(int id) {
            this.id = id;
        }
    }

    public PartItem findItemById(List<PartItem> list, int id) {
        for (PartItem item : list) {
            if (item.id == id) return item;
        }
        return null;
    }

    public String nvl(String s) {
        return s == null ? "" : s;
    }
%>

<%
    request.setCharacterEncoding("UTF-8");

    List<PartItem> partList = (List<PartItem>)session.getAttribute("partList");
    if (partList == null) {
        partList = new ArrayList<PartItem>();
        session.setAttribute("partList", partList);
    }

    Integer nextId = (Integer)session.getAttribute("nextId");
    if (nextId == null) {
        nextId = 1;
        session.setAttribute("nextId", nextId);
    }

    String action = request.getParameter("action");
    if (action == null) action = "";

    String message = "";
    String editMode = "N";
    int editId = -1;

    String vendorName = "";
    String region = "";
    String contactName = "";
    String contactPhone = "";
    String contactEmail = "";
    String certification = "";

    String partName = "";
    String partCode = "";
    String partCategory = "";
    String partImage = "";
    String description = "";

    String maxCapacity = "";
    String availableStock = "";
    String minimumOrderQty = "";
    String productionLeadTime = "";

    String unitCost = "";
    String transportCost = "";
    String delayRisk = "";
    String defectRate = "";

    // 수정 버튼 클릭 시 기존값 폼에 채우기
    if ("edit".equals(action)) {
        try {
            editId = Integer.parseInt(request.getParameter("id"));
            PartItem editItem = findItemById(partList, editId);

            if (editItem != null) {
                editMode = "Y";

                vendorName = nvl(editItem.vendorName);
                region = nvl(editItem.region);
                contactName = nvl(editItem.contactName);
                contactPhone = nvl(editItem.contactPhone);
                contactEmail = nvl(editItem.contactEmail);
                certification = nvl(editItem.certification);

                partName = nvl(editItem.partName);
                partCode = nvl(editItem.partCode);
                partCategory = nvl(editItem.partCategory);
                partImage = nvl(editItem.partImage);
                description = nvl(editItem.description);

                maxCapacity = nvl(editItem.maxCapacity);
                availableStock = nvl(editItem.availableStock);
                minimumOrderQty = nvl(editItem.minimumOrderQty);
                productionLeadTime = nvl(editItem.productionLeadTime);

                unitCost = nvl(editItem.unitCost);
                transportCost = nvl(editItem.transportCost);
                delayRisk = nvl(editItem.delayRisk);
                defectRate = nvl(editItem.defectRate);
            }
        } catch (Exception e) {
            message = "수정할 항목을 찾는 중 오류가 발생했습니다.";
        }
    }

    // 저장(신규 추가)
    if ("add".equals(action)) {
        vendorName = nvl(request.getParameter("vendorName"));
        region = nvl(request.getParameter("region"));
        contactName = nvl(request.getParameter("contactName"));
        contactPhone = nvl(request.getParameter("contactPhone"));
        contactEmail = nvl(request.getParameter("contactEmail"));
        certification = nvl(request.getParameter("certification"));

        partName = nvl(request.getParameter("partName"));
        partCode = nvl(request.getParameter("partCode"));
        partCategory = nvl(request.getParameter("partCategory"));
        partImage = nvl(request.getParameter("partImage"));
        description = nvl(request.getParameter("description"));

        maxCapacity = nvl(request.getParameter("maxCapacity"));
        availableStock = nvl(request.getParameter("availableStock"));
        minimumOrderQty = nvl(request.getParameter("minimumOrderQty"));
        productionLeadTime = nvl(request.getParameter("productionLeadTime"));

        unitCost = nvl(request.getParameter("unitCost"));
        transportCost = nvl(request.getParameter("transportCost"));
        delayRisk = nvl(request.getParameter("delayRisk"));
        defectRate = nvl(request.getParameter("defectRate"));

        if (!vendorName.trim().equals("") && !partName.trim().equals("")) {
            PartItem item = new PartItem(nextId);

            item.vendorName = vendorName;
            item.region = region;
            item.contactName = contactName;
            item.contactPhone = contactPhone;
            item.contactEmail = contactEmail;
            item.certification = certification;

            item.partName = partName;
            item.partCode = partCode;
            item.partCategory = partCategory;
            item.partImage = partImage;
            item.description = description;

            item.maxCapacity = maxCapacity;
            item.availableStock = availableStock;
            item.minimumOrderQty = minimumOrderQty;
            item.productionLeadTime = productionLeadTime;

            item.unitCost = unitCost;
            item.transportCost = transportCost;
            item.delayRisk = delayRisk;
            item.defectRate = defectRate;

            partList.add(item);

            nextId = nextId + 1;
            session.setAttribute("nextId", nextId);

            message = "부품 정보가 등록되었습니다.";

            vendorName = "";
            region = "";
            contactName = "";
            contactPhone = "";
            contactEmail = "";
            certification = "";

            partName = "";
            partCode = "";
            partCategory = "";
            partImage = "";
            description = "";

            maxCapacity = "";
            availableStock = "";
            minimumOrderQty = "";
            productionLeadTime = "";

            unitCost = "";
            transportCost = "";
            delayRisk = "";
            defectRate = "";
        } else {
            message = "업체명과 부품명은 필수 입력입니다.";
        }
    }

    // 수정 저장
    if ("update".equals(action)) {
        try {
            editId = Integer.parseInt(request.getParameter("id"));

            vendorName = nvl(request.getParameter("vendorName"));
            region = nvl(request.getParameter("region"));
            contactName = nvl(request.getParameter("contactName"));
            contactPhone = nvl(request.getParameter("contactPhone"));
            contactEmail = nvl(request.getParameter("contactEmail"));
            certification = nvl(request.getParameter("certification"));

            partName = nvl(request.getParameter("partName"));
            partCode = nvl(request.getParameter("partCode"));
            partCategory = nvl(request.getParameter("partCategory"));
            partImage = nvl(request.getParameter("partImage"));
            description = nvl(request.getParameter("description"));

            maxCapacity = nvl(request.getParameter("maxCapacity"));
            availableStock = nvl(request.getParameter("availableStock"));
            minimumOrderQty = nvl(request.getParameter("minimumOrderQty"));
            productionLeadTime = nvl(request.getParameter("productionLeadTime"));

            unitCost = nvl(request.getParameter("unitCost"));
            transportCost = nvl(request.getParameter("transportCost"));
            delayRisk = nvl(request.getParameter("delayRisk"));
            defectRate = nvl(request.getParameter("defectRate"));

            PartItem item = findItemById(partList, editId);

            if (item != null) {
                item.vendorName = vendorName;
                item.region = region;
                item.contactName = contactName;
                item.contactPhone = contactPhone;
                item.contactEmail = contactEmail;
                item.certification = certification;

                item.partName = partName;
                item.partCode = partCode;
                item.partCategory = partCategory;
                item.partImage = partImage;
                item.description = description;

                item.maxCapacity = maxCapacity;
                item.availableStock = availableStock;
                item.minimumOrderQty = minimumOrderQty;
                item.productionLeadTime = productionLeadTime;

                item.unitCost = unitCost;
                item.transportCost = transportCost;
                item.delayRisk = delayRisk;
                item.defectRate = defectRate;

                message = "부품 정보가 수정되었습니다.";
                editMode = "N";
                editId = -1;

                vendorName = "";
                region = "";
                contactName = "";
                contactPhone = "";
                contactEmail = "";
                certification = "";

                partName = "";
                partCode = "";
                partCategory = "";
                partImage = "";
                description = "";

                maxCapacity = "";
                availableStock = "";
                minimumOrderQty = "";
                productionLeadTime = "";

                unitCost = "";
                transportCost = "";
                delayRisk = "";
                defectRate = "";
            } else {
                message = "수정할 항목을 찾을 수 없습니다.";
                editMode = "N";
            }
        } catch (Exception e) {
            message = "수정 처리 중 오류가 발생했습니다.";
        }
    }

    // 삭제
    if ("delete".equals(action)) {
        try {
            int id = Integer.parseInt(request.getParameter("id"));
            PartItem item = findItemById(partList, id);
            if (item != null) {
                partList.remove(item);
                message = "부품 정보가 삭제되었습니다.";
            }
        } catch (Exception e) {
            message = "삭제 처리 중 오류가 발생했습니다.";
        }
    }

    // 전체 초기화
    if ("clear".equals(action)) {
        partList.clear();
        message = "전체 목록이 초기화되었습니다.";
    }
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>업체별 부품 등록 입력 양식</title>
<style>
    body{
        font-family: Arial, "맑은 고딕", sans-serif;
        background:#f4f7fb;
        margin:0;
        padding:30px;
        color:#222;
    }
    .container{
        max-width:1200px;
        margin:0 auto;
        background:#fff;
        border-radius:14px;
        box-shadow:0 4px 18px rgba(0,0,0,0.08);
        padding:30px;
    }
    h1{
        margin-top:0;
        color:#1f3c88;
    }
    h2{
        color:#1f3c88;
        margin-top:30px;
    }
    .desc{
        background:#f3f7ff;
        border:1px solid #dbe6ff;
        padding:14px;
        border-radius:10px;
        line-height:1.7;
        margin-bottom:24px;
    }
    .section-title{
        font-size:18px;
        font-weight:bold;
        margin:28px 0 12px 0;
        color:#234ea0;
        border-left:5px solid #2d6cdf;
        padding-left:10px;
    }
    .grid{
        display:grid;
        grid-template-columns:repeat(2, 1fr);
        gap:16px;
    }
    .field{
        display:flex;
        flex-direction:column;
    }
    .field.full{
        grid-column:1 / -1;
    }
    label{
        font-weight:bold;
        margin-bottom:6px;
        color:#333;
    }
    .required{
        color:#d32f2f;
        margin-left:4px;
    }
    input[type="text"],
    input[type="number"],
    input[type="email"],
    select,
    textarea{
        padding:10px 12px;
        border:1px solid #cfd8ea;
        border-radius:8px;
        font-size:14px;
        box-sizing:border-box;
        width:100%;
        background:#fff;
    }
    textarea{
        resize:vertical;
        min-height:110px;
    }
    .help{
        font-size:12px;
        color:#666;
        margin-top:5px;
        line-height:1.5;
    }
    .btn-area{
        margin-top:28px;
        display:flex;
        gap:10px;
        flex-wrap:wrap;
    }
    .btn{
        border:none;
        border-radius:8px;
        padding:10px 16px;
        cursor:pointer;
        font-size:14px;
        font-weight:bold;
        text-decoration:none;
        display:inline-block;
    }
    .btn-primary{
        background:#2d6cdf;
        color:#fff;
    }
    .btn-primary:hover{
        background:#1f57ba;
    }
    .btn-secondary{
        background:#e9eef8;
        color:#234;
    }
    .btn-secondary:hover{
        background:#dce5f6;
    }
    .btn-danger{
        background:#d64545;
        color:#fff;
    }
    .btn-danger:hover{
        background:#b83434;
    }
    .btn-warning{
        background:#ffb300;
        color:#222;
    }
    .btn-warning:hover{
        background:#e6a100;
    }
    .btn-info{
        background:#26a69a;
        color:#fff;
    }
    .btn-info:hover{
        background:#1e8e84;
    }
    table{
        width:100%;
        border-collapse:collapse;
        margin-top:16px;
    }
    th, td{
        border:1px solid #d8e0ef;
        padding:12px;
        text-align:left;
        vertical-align:top;
        font-size:14px;
    }
    th{
        background:#eef4ff;
    }
    .small{
        font-size:13px;
        color:#555;
        line-height:1.6;
    }
    .legend{
        margin-top:25px;
        background:#fff9e8;
        border:1px solid #ffe08a;
        border-radius:10px;
        padding:15px;
        line-height:1.8;
    }
    .msg{
        margin:14px 0 18px 0;
        background:#eef7ee;
        border:1px solid #cfe7cf;
        color:#256029;
        padding:12px 14px;
        border-radius:10px;
    }
    .list-table th, .list-table td{
        text-align:center;
        vertical-align:middle;
        font-size:13px;
    }
    .photo-thumb{
        max-width:80px;
        max-height:60px;
        border:1px solid #ddd;
        border-radius:6px;
        background:#fff;
        padding:4px;
    }
    .action-form{
        display:inline;
    }
    @media (max-width: 768px){
        .grid{
            grid-template-columns:1fr;
        }
    }
</style>
<script>
function confirmDelete() {
    return confirm("선택한 부품 정보를 삭제할까요?");
}
function confirmClear() {
    return confirm("전체 목록을 초기화할까요?");
}
</script>
</head>
<body>
<div class="container">
    <h1>업체별 부품 등록 입력 양식</h1>

    <div class="desc">
        이 화면은 1차/2차 벤더 Open Market 플랫폼에서 사용할 수 있는
        <b>업체별 부품 등록 폼</b>입니다.<br>
        공급업체가 자사의 부품 정보, 생산능력, 재고, 가격, 납기위험, 불량률, 사진 등을 입력하여
        원청 또는 구매 담당자가 검색할 수 있도록 하기 위한 입력 양식입니다.
    </div>

    <% if (!message.equals("")) { %>
        <div class="msg"><%= message %></div>
    <% } %>

    <form method="post">
        <input type="hidden" name="action" value="<%= "Y".equals(editMode) ? "update" : "add" %>">
        <input type="hidden" name="id" value="<%= editId %>">

        <div class="section-title">1. 업체 기본 정보</div>
        <div class="grid">
            <div class="field">
                <label>업체명<span class="required">*</span></label>
                <input type="text" name="vendorName" value="<%= vendorName %>" placeholder="예: ABC Precision">
            </div>

            <div class="field">
                <label>지역 / 소재지</label>
                <input type="text" name="region" value="<%= region %>" placeholder="예: 경기 화성 / 충남 아산">
            </div>

            <div class="field">
                <label>담당자명</label>
                <input type="text" name="contactName" value="<%= contactName %>" placeholder="예: 김영수">
            </div>

            <div class="field">
                <label>연락처</label>
                <input type="text" name="contactPhone" value="<%= contactPhone %>" placeholder="예: 010-1234-5678">
            </div>

            <div class="field">
                <label>이메일</label>
                <input type="email" name="contactEmail" value="<%= contactEmail %>" placeholder="예: vendor@company.com">
            </div>

            <div class="field">
                <label>기술인증</label>
                <input type="text" name="certification" value="<%= certification %>" placeholder="예: ISO9001, IATF16949, KC, CE">
            </div>
        </div>

        <div class="section-title">2. 부품 기본 정보</div>
        <div class="grid">
            <div class="field">
                <label>부품명<span class="required">*</span></label>
                <input type="text" name="partName" value="<%= partName %>" placeholder="예: 알루미늄 하우징">
            </div>

            <div class="field">
                <label>부품코드</label>
                <input type="text" name="partCode" value="<%= partCode %>" placeholder="예: AH-2026-001">
            </div>

            <div class="field">
                <label>부품분류</label>
                <select name="partCategory">
                    <option value="">선택하세요</option>
                    <option value="원자재" <%= "원자재".equals(partCategory) ? "selected" : "" %>>원자재</option>
                    <option value="부품" <%= "부품".equals(partCategory) ? "selected" : "" %>>부품</option>
                    <option value="반제품" <%= "반제품".equals(partCategory) ? "selected" : "" %>>반제품</option>
                    <option value="완제품" <%= "완제품".equals(partCategory) ? "selected" : "" %>>완제품</option>
                    <option value="전자부품" <%= "전자부품".equals(partCategory) ? "selected" : "" %>>전자부품</option>
                    <option value="기계부품" <%= "기계부품".equals(partCategory) ? "selected" : "" %>>기계부품</option>
                    <option value="소재" <%= "소재".equals(partCategory) ? "selected" : "" %>>소재</option>
                </select>
            </div>

            <div class="field">
                <label>부품 사진 URL 또는 파일명</label>
                <input type="file" name="partImage" value="<%= partImage %>" placeholder="예: ./img/part1.png 또는 https://...">
                <div class="help">JSP 단독 실행용 예제이므로 실제 업로드 대신 이미지 경로를 입력합니다.</div>
            </div>

            <div class="field full">
                <label>부품 상세설명</label>
                <textarea name="description" placeholder="부품의 재질, 규격, 용도, 특징 등을 입력하세요."><%= description %></textarea>
            </div>
        </div>

        <div class="section-title">3. 생산 및 재고 정보</div>
        <div class="grid">
            <div class="field">
                <label>최대생산량(1일 기준)<span class="required">*</span></label>
                <input type="number" name="maxCapacity" value="<%= maxCapacity %>" placeholder="예: 5000">
                <div class="help">하루 기준 최대 생산 가능한 수량을 입력합니다.</div>
            </div>

            <div class="field">
                <label>현재 투입가능 재고량<span class="required">*</span></label>
                <input type="number" name="availableStock" value="<%= availableStock %>" placeholder="예: 1200">
                <div class="help">즉시 공급 또는 생산에 투입 가능한 현재 재고 수량입니다.</div>
            </div>

            <div class="field">
                <label>최소 주문 가능 수량</label>
                <input type="number" name="minimumOrderQty" value="<%= minimumOrderQty %>" placeholder="예: 100">
            </div>

            <div class="field">
                <label>평균 생산 리드타임(일)</label>
                <input type="number" name="productionLeadTime" value="<%= productionLeadTime %>" placeholder="예: 3">
                <div class="help">주문 후 납품까지 평균적으로 걸리는 일수입니다.</div>
            </div>
        </div>

        <div class="section-title">4. 가격 및 위험 정보</div>
        <div class="grid">
            <div class="field">
                <label>단가(원)<span class="required">*</span></label>
                <input type="number" step="0.01" name="unitCost" value="<%= unitCost %>" placeholder="예: 9500">
            </div>

            <div class="field">
                <label>운송비(원)</label>
                <input type="number" step="0.01" name="transportCost" value="<%= transportCost %>" placeholder="예: 500">
            </div>

            <div class="field">
                <label>납기지연 위험요소(0~1)</label>
                <input type="number" step="0.01" min="0" max="1" name="delayRisk" value="<%= delayRisk %>" placeholder="예: 0.15">
                <div class="help">0에 가까울수록 안정적, 1에 가까울수록 지연 위험이 높음을 의미합니다.</div>
            </div>

            <div class="field">
                <label>불량률(0~1)</label>
                <input type="number" step="0.01" min="0" max="1" name="defectRate" value="<%= defectRate %>" placeholder="예: 0.03">
                <div class="help">예: 0.03은 3% 수준의 불량률을 의미합니다.</div>
            </div>
        </div>

        <div class="btn-area">
            <% if ("Y".equals(editMode)) { %>
                <button type="submit" class="btn btn-warning">수정 저장</button>
                <a href="vendor_part_manage.jsp" class="btn btn-secondary">수정 취소</a>
            <% } else { %>
                <button type="submit" class="btn btn-primary">부품 정보 등록</button>
                <button type="reset" class="btn btn-secondary">입력 초기화</button>
            <% } %>
        </div>
    </form>

    <div class="legend">
        <b>입력 항목 설명</b><br>
        - <b>최대생산량</b>: 하루 기준 최대 생산 가능 수량<br>
        - <b>현재 투입가능 재고량</b>: 바로 공급 또는 생산에 활용 가능한 현재 재고 수량<br>
        - <b>단가</b>: 부품 1개당 가격<br>
        - <b>운송비</b>: 납품 시 추가되는 물류/운송 비용<br>
        - <b>납기지연 위험요소</b>: 납기 지연 가능성을 0~1 값으로 표현<br>
        - <b>불량률</b>: 생산품의 품질 문제 발생 비율을 0~1 값으로 표현
    </div>

    <h2>등록된 부품 목록</h2>

    <form method="post" class="action-form" style="margin-bottom:10px;">
        <input type="hidden" name="action" value="clear">
        <button type="submit" class="btn btn-danger" onclick="return confirmClear();">전체 목록 초기화</button>
    </form>

    <table class="list-table">
        <tr>
            <th>번호</th>
            <th>업체명</th>
            <th>부품명</th>
            <th>부품코드</th>
            <th>분류</th>
            <th>최대생산량</th>
            <th>재고량</th>
            <th>단가</th>
            <th>운송비</th>
            <th>납기위험</th>
            <th>불량률</th>
            <th>사진</th>
            <th>수정</th>
            <th>삭제</th>
        </tr>

        <% if (partList.size() == 0) { %>
            <tr>
                <td colspan="14">등록된 부품 정보가 없습니다.</td>
            </tr>
        <% } else { %>
            <% for (int i = 0; i < partList.size(); i++) {
                PartItem item = partList.get(i);
            %>
                <tr>
                    <td><%= i + 1 %></td>
                    <td><%= item.vendorName %></td>
                    <td><%= item.partName %></td>
                    <td><%= item.partCode %></td>
                    <td><%= item.partCategory %></td>
                    <td><%= item.maxCapacity %></td>
                    <td><%= item.availableStock %></td>
                    <td><%= item.unitCost %></td>
                    <td><%= item.transportCost %></td>
                    <td><%= item.delayRisk %></td>
                    <td><%= item.defectRate %></td>
                    <td>
                        <% if (!nvl(item.partImage).trim().equals("")) { %>
                            <a href="<%= item.partImage %>" target="_blank">
                                <img src="<%= item.partImage %>" alt="부품사진" class="photo-thumb">
                            </a>
                        <% } else { %>
                            사진 없음
                        <% } %>
                    </td>
                    <td>
                        <form method="post" class="action-form">
                            <input type="hidden" name="action" value="edit">
                            <input type="hidden" name="id" value="<%= item.id %>">
                            <button type="submit" class="btn btn-warning">수정</button>
                        </form>
                    </td>
                    <td>
                        <form method="post" class="action-form">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="<%= item.id %>">
                            <button type="submit" class="btn btn-danger" onclick="return confirmDelete();">삭제</button>
                        </form>
                    </td>
                </tr>
                <tr>
                    <td colspan="14" style="text-align:left;background:#fafcff;">
                        <b>지역:</b> <%= item.region %> /
                        <b>담당자:</b> <%= item.contactName %> /
                        <b>연락처:</b> <%= item.contactPhone %> /
                        <b>이메일:</b> <%= item.contactEmail %> /
                        <b>기술인증:</b> <%= item.certification %> /
                        <b>최소주문수량:</b> <%= item.minimumOrderQty %> /
                        <b>생산리드타임:</b> <%= item.productionLeadTime %> 일
                        <br><br>
                        <b>상세설명:</b><br>
                        <%= nvl(item.description).replaceAll("\n", "<br>") %>
                    </td>
                </tr>
            <% } %>
        <% } %>
    </table>

    <div class="small" style="margin-top:15px;">
        현재 예제는 <b>Session 기반 JSP 예제</b>입니다.<br>
        실제 운영 환경에서는 DB(MySQL/Oracle) 연동 및 실제 파일 업로드 기능(Servlet, multipart 처리)을 추가하는 것이 좋습니다.
    </div>
</div>
</body>
</html>