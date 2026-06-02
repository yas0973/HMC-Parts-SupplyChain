<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%
    String dbUrl  = "jdbc:mysql://localhost:3306/hmc_scm?useSSL=false&serverTimezone=Asia/Seoul&characterEncoding=UTF-8";
    String dbUser = "root";
    String dbPass = "1234"; // 본인 MySQL 비밀번호 입력

    String keyword = request.getParameter("keyword") != null ? request.getParameter("keyword").trim() : "";
    String domain  = request.getParameter("domain")  != null ? request.getParameter("domain")  : "";
    String pageStr  = request.getParameter("page") != null ? request.getParameter("page") : "1";
    int currentPage = Integer.parseInt(pageStr);
    int pageSize    = 20;
    int offset      = (currentPage - 1) * pageSize;

    StringBuilder where = new StringBuilder("WHERE 1=1");
    if (!keyword.isEmpty()) where.append(" AND (part_name_ko LIKE ? OR part_name_en LIKE ? OR part_code LIKE ?)");
    if (!domain.isEmpty())  where.append(" AND vehicle_domain = ?");

    int totalCount = 0;
    java.util.List<String[]> rows = new java.util.ArrayList<>();

    Class.forName("com.mysql.cj.jdbc.Driver");
    try (Connection conn = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {

        // count
        String countSql = "SELECT COUNT(*) FROM parts_db " + where;
        try (PreparedStatement ps = conn.prepareStatement(countSql)) {
            int idx = 1;
            if (!keyword.isEmpty()) { String kw = "%" + keyword + "%"; ps.setString(idx++, kw); ps.setString(idx++, kw); ps.setString(idx++, kw); }
            if (!domain.isEmpty())  ps.setString(idx++, domain);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) totalCount = rs.getInt(1);
        }

        // data
        String dataSql = "SELECT part_code, part_name_ko, part_name_en, vehicle_domain, system_major, system_minor, material_group, ksic_code, ksic_name FROM parts_db " + where + " ORDER BY catalog_id LIMIT ? OFFSET ?";
        try (PreparedStatement ps = conn.prepareStatement(dataSql)) {
            int idx = 1;
            if (!keyword.isEmpty()) { String kw = "%" + keyword + "%"; ps.setString(idx++, kw); ps.setString(idx++, kw); ps.setString(idx++, kw); }
            if (!domain.isEmpty())  ps.setString(idx++, domain);
            ps.setInt(idx++, pageSize);
            ps.setInt(idx++, offset);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                rows.add(new String[]{
                    rs.getString("part_code"),
                    rs.getString("part_name_ko"),
                    rs.getString("part_name_en"),
                    rs.getString("vehicle_domain"),
                    rs.getString("system_major"),
                    rs.getString("system_minor"),
                    rs.getString("material_group"),
                    rs.getString("ksic_code"),
                    rs.getString("ksic_name")
                });
            }
        }
    }
    int totalPage = (int) Math.ceil((double) totalCount / pageSize);
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<title>자동차 부품 DB</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;600;700&family=JetBrains+Mono:wght@400;600&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg: #0b0f1a;
    --surface: #131929;
    --surface2: #1a2236;
    --border: #1f2e47;
    --accent: #3b82f6;
    --accent2: #06b6d4;
    --text: #e2e8f0;
    --muted: #64748b;
    --tag-ice: #1d4ed8;
    --tag-ev: #065f46;
    --tag-hev: #7c3aed;
    --tag-common: #92400e;
  }

  body {
    font-family: 'Noto Sans KR', sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }

  /* Header */
  header {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 100%);
    border-bottom: 1px solid var(--border);
    padding: 24px 40px;
    display: flex;
    align-items: center;
    gap: 20px;
  }
  header .logo {
    width: 44px; height: 44px;
    background: linear-gradient(135deg, var(--accent), var(--accent2));
    border-radius: 10px;
    display: flex; align-items: center; justify-content: center;
    font-size: 20px;
  }
  header h1 { font-size: 1.4rem; font-weight: 700; letter-spacing: -0.5px; }
  header span { font-size: 0.8rem; color: var(--muted); margin-left: 4px; }

  /* Search bar */
  .search-bar {
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 20px 40px;
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    align-items: center;
  }
  .search-bar input[type=text] {
    flex: 1; min-width: 240px;
    background: var(--bg);
    border: 1px solid var(--border);
    color: var(--text);
    padding: 10px 16px;
    border-radius: 8px;
    font-family: inherit;
    font-size: 0.9rem;
    outline: none;
    transition: border-color .2s;
  }
  .search-bar input[type=text]:focus { border-color: var(--accent); }
  .search-bar select {
    background: var(--bg);
    border: 1px solid var(--border);
    color: var(--text);
    padding: 10px 14px;
    border-radius: 8px;
    font-family: inherit;
    font-size: 0.9rem;
    outline: none;
    cursor: pointer;
  }
  .search-bar button {
    background: linear-gradient(135deg, var(--accent), var(--accent2));
    color: #fff;
    border: none;
    padding: 10px 24px;
    border-radius: 8px;
    font-family: inherit;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: opacity .2s;
  }
  .search-bar button:hover { opacity: .85; }

  /* Stats */
  .stats {
    padding: 14px 40px;
    font-size: 0.82rem;
    color: var(--muted);
    border-bottom: 1px solid var(--border);
  }
  .stats strong { color: var(--accent2); }

  /* Table */
  .table-wrap {
    padding: 24px 40px;
    overflow-x: auto;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }
  thead th {
    background: var(--surface2);
    color: var(--muted);
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: .05em;
    text-transform: uppercase;
    padding: 12px 14px;
    text-align: left;
    border-bottom: 2px solid var(--border);
    white-space: nowrap;
  }
  tbody tr {
    border-bottom: 1px solid var(--border);
    transition: background .15s;
  }
  tbody tr:hover { background: var(--surface2); }
  tbody td {
    padding: 12px 14px;
    vertical-align: middle;
  }
  .code {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.78rem;
    color: var(--accent2);
  }
  .name-ko { font-weight: 600; }
  .name-en { font-size: 0.78rem; color: var(--muted); margin-top: 2px; }

  .tag {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 20px;
    font-size: 0.72rem;
    font-weight: 600;
    white-space: nowrap;
  }
  .tag-ICE  { background: rgba(29,78,216,.3); color: #93c5fd; border: 1px solid #1d4ed8; }
  .tag-EV   { background: rgba(6,95,70,.3);  color: #6ee7b7; border: 1px solid #065f46; }
  .tag-HEV  { background: rgba(124,58,237,.3); color: #c4b5fd; border: 1px solid #7c3aed; }
  .tag-ICE-HEV { background: rgba(29,78,216,.2); color: #93c5fd; border: 1px solid #3b82f6; }
  .tag-Common { background: rgba(146,64,14,.3); color: #fcd34d; border: 1px solid #92400e; }

  /* Pagination */
  .pagination {
    display: flex;
    justify-content: center;
    gap: 6px;
    padding: 24px 40px;
    flex-wrap: wrap;
  }
  .pagination a, .pagination span {
    display: inline-flex; align-items: center; justify-content: center;
    width: 36px; height: 36px;
    border-radius: 8px;
    font-size: 0.85rem;
    text-decoration: none;
    border: 1px solid var(--border);
    color: var(--muted);
    transition: all .2s;
  }
  .pagination a:hover { border-color: var(--accent); color: var(--accent); }
  .pagination .active { background: var(--accent); border-color: var(--accent); color: #fff; font-weight: 700; }

  .empty { text-align: center; padding: 60px; color: var(--muted); font-size: 0.9rem; }
</style>
</head>
<body>

<header>
  <div class="logo">⚙️</div>
  <div>
    <h1>자동차 부품 DB <span>hmc_scm · parts_db</span></h1>
  </div>
</header>

<form method="get" action="">
<div class="search-bar">
  <input type="text" name="keyword" placeholder="부품명(한/영) 또는 부품코드 검색..." value="<%=keyword%>">
  <select name="domain">
    <option value="">전체 도메인</option>
    <option value="ICE/HEV" <%="ICE/HEV".equals(domain)?"selected":""%>>ICE/HEV</option>
    <option value="EV"      <%="EV".equals(domain)?"selected":""%>>EV</option>
    <option value="HEV"     <%="HEV".equals(domain)?"selected":""%>>HEV</option>
    <option value="ICE"     <%="ICE".equals(domain)?"selected":""%>>ICE</option>
    <option value="Common"  <%="Common".equals(domain)?"selected":""%>>Common</option>
  </select>
  <button type="submit">🔍 검색</button>
</div>
</form>

<div class="stats">
  총 <strong><%=totalCount%></strong>건 &nbsp;·&nbsp; 페이지 <strong><%=currentPage%></strong> / <strong><%=Math.max(totalPage,1)%></strong>
  <% if(!keyword.isEmpty()) { %> &nbsp;·&nbsp; 검색어: <strong style="color:var(--text)"><%=keyword%></strong> <% } %>
</div>

<div class="table-wrap">
<% if (rows.isEmpty()) { %>
  <div class="empty">검색 결과가 없습니다.</div>
<% } else { %>
<table>
  <thead>
    <tr>
      <th>부품코드</th>
      <th>부품명</th>
      <th>도메인</th>
      <th>대분류</th>
      <th>중분류</th>
      <th>재질</th>
      <th>KSIC</th>
    </tr>
  </thead>
  <tbody>
  <% for (String[] r : rows) {
       String domainVal = r[3] != null ? r[3] : "";
       String tagClass  = "tag tag-" + domainVal.replace("/","-");
  %>
    <tr>
      <td><span class="code"><%=r[0]!=null?r[0]:""%></span></td>
      <td>
        <div class="name-ko"><%=r[1]!=null?r[1]:""%></div>
        <div class="name-en"><%=r[2]!=null?r[2]:""%></div>
      </td>
      <td><span class="<%=tagClass%>"><%=domainVal%></span></td>
      <td><%=r[4]!=null?r[4]:""%></td>
      <td><%=r[5]!=null?r[5]:""%></td>
      <td><%=r[6]!=null?r[6]:""%></td>
      <td><span class="code"><%=r[7]!=null?r[7]:""%></span> <span style="color:var(--muted);font-size:.78rem"><%=r[8]!=null?r[8]:""%></span></td>
    </tr>
  <% } %>
  </tbody>
</table>
<% } %>
</div>

<!-- Pagination -->
<div class="pagination">
<%
  int startPage = Math.max(1, currentPage - 4);
  int endPage   = Math.min(totalPage, currentPage + 5);
  String baseUrl = "parts_db_view.jsp?keyword=" + java.net.URLEncoder.encode(keyword,"UTF-8") + "&domain=" + java.net.URLEncoder.encode(domain,"UTF-8") + "&page=";

  if (currentPage > 1) { %><a href="<%=baseUrl+(currentPage-1)%>">‹</a><% }
  for (int i = startPage; i <= endPage; i++) {
    if (i == currentPage) { %><span class="active"><%=i%></span><%
    } else { %><a href="<%=baseUrl+i%>"><%=i%></a><% }
  }
  if (currentPage < totalPage) { %><a href="<%=baseUrl+(currentPage+1)%>">›</a><% }
%>
</div>

</body>
</html>
