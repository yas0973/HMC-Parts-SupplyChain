<%@ page contentType="text/html; charset=UTF-8" %>

<%
String company   = (String) session.getAttribute("company");
String role      = (String) session.getAttribute("role");
String roleLabel = (String) session.getAttribute("roleLabel");

boolean isAdmin  = "admin".equals(role);
boolean isVendor = "vendor".equals(role);
String currentPage = request.getRequestURI();
%>

 <div class="sidebar"> 
        <div class="sidebar-logo">
          <div class="title">HMC SCM</div>
          <div class="sub">Supply Chain Platform v3.7</div>
        </div>
        <div class="role-badge">
          <div class="rl">접속 권한</div>
          <div class="rn"><%= company %> (<%= roleLabel %>)</div>
        </div>

        <div class="nav-section">메인</div>
        <a href="dashboard.jsp" class="nav-item <%= currentPage.contains("dashboard.jsp") ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/>
            <rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>
          </svg>
          대시보드
        </a>

        <div class="nav-section">발주 / 입찰</div>
        <% if ((isAdmin) || (isVendor)) { %>
        <a href="bidReg.jsp" class="nav-item <%= currentPage.contains("bidReg.jsp") ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
            <polyline points="14,2 14,8 20,8"/>
            <line x1="12" y1="18" x2="12" y2="12"/><line x1="9" y1="15" x2="15" y2="15"/>
          </svg>
          발주 등록
        </a>
        <% } %>
        <a href="bidList.jsp" 
        class="nav-item <%= (currentPage.contains("bidList.jsp") 
                     || currentPage.contains("itemDetailReg.jsp")) 
                     ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 11l3 3L22 4"/>
            <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
          </svg>
          발주 현황
        </a>
        <div class="nav-section">관리</div>
        <a href="deliveryList.jsp" 
        class="nav-item <%= (currentPage.contains("deliveryList.jsp") 
                     || currentPage.contains("delivery.jsp")) 
                     ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="1" y="3" width="15" height="13"/>
            <polygon points="16,8 20,8 23,11 23,16 16,16 16,8"/>
            <circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/>
          </svg>
          납품 현황
        </a>
        <a href="evaluationList.jsp" 
        class="nav-item <%= (currentPage.contains("evaluationList.jsp") 
                     || currentPage.contains("evaluation.jsp")) 
                     ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
          업체 평가
        </a>
        <a href="settlement.jsp" class="nav-item <%= currentPage.contains("settlement.jsp") ? "active" : "" %>">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="1" x2="12" y2="23"/>
            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
          </svg>
          정산
        </a>

        <div class="nav-bottom">
          <div class="nav-section">계정</div>
          <a href="dashboard.jsp?action=logout" class="nav-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
              <polyline points="16,17 21,12 16,7"/><line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
            로그아웃
          </a>
        </div>
      </div>