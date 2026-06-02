<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, util.DBUtil" %>
<%
    request.setCharacterEncoding("UTF-8");
    response.setContentType("application/json; charset=UTF-8");

    // 세션 체크
    if (session.getAttribute("userId") == null) {
        out.print("{\"error\":\"unauthorized\"}");
        return;
    }

    String keyword = request.getParameter("q");
    if (keyword == null || keyword.trim().length() < 1) {
        out.print("[]");
        return;
    }
    keyword = keyword.trim();

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    StringBuilder sb = new StringBuilder("[");

    try {
        conn = DBUtil.getConnection();
        ps = conn.prepareStatement(
            "SELECT part_code, part_name_ko, part_name_en, " +
            "       vehicle_domain, system_major, system_minor, " +
            "       material_group, primary_spec_name, primary_spec_unit, " +
            "       secondary_spec_name, secondary_spec_unit, ksic_name " +
            "FROM parts_db " +
            "WHERE part_name_ko LIKE ? OR part_code LIKE ? " +
            "ORDER BY part_name_ko " +
            "LIMIT 10"
        );
        String like = "%" + keyword + "%";
        ps.setString(1, like);
        ps.setString(2, like);
        rs = ps.executeQuery();

        boolean first = true;
        while (rs.next()) {
            if (!first) sb.append(",");
            first = false;

            // JSON 이스케이프 헬퍼 (간단 처리)
            String partCode       = escapeJson(rs.getString("part_code"));
            String partNameKo     = escapeJson(rs.getString("part_name_ko"));
            String partNameEn     = escapeJson(rs.getString("part_name_en"));
            String vehicleDomain  = escapeJson(rs.getString("vehicle_domain"));
            String systemMajor    = escapeJson(rs.getString("system_major"));
            String systemMinor    = escapeJson(rs.getString("system_minor"));
            String materialGroup  = escapeJson(rs.getString("material_group"));
            String primarySpec    = escapeJson(rs.getString("primary_spec_name"));
            String primaryUnit    = escapeJson(rs.getString("primary_spec_unit"));
            String secondarySpec  = escapeJson(rs.getString("secondary_spec_name"));
            String secondaryUnit  = escapeJson(rs.getString("secondary_spec_unit"));
            String ksicName       = escapeJson(rs.getString("ksic_name"));

            sb.append("{")
              .append("\"part_code\":\"").append(partCode).append("\",")
              .append("\"part_name_ko\":\"").append(partNameKo).append("\",")
              .append("\"part_name_en\":\"").append(partNameEn).append("\",")
              .append("\"vehicle_domain\":\"").append(vehicleDomain).append("\",")
              .append("\"system_major\":\"").append(systemMajor).append("\",")
              .append("\"system_minor\":\"").append(systemMinor).append("\",")
              .append("\"material_group\":\"").append(materialGroup).append("\",")
              .append("\"primary_spec\":\"").append(primarySpec).append("\",")
              .append("\"primary_unit\":\"").append(primaryUnit).append("\",")
              .append("\"secondary_spec\":\"").append(secondarySpec).append("\",")
              .append("\"secondary_unit\":\"").append(secondaryUnit).append("\",")
              .append("\"ksic_name\":\"").append(ksicName).append("\"")
              .append("}");
        }

    } catch (Exception e) {
        out.print("{\"error\":\"" + e.getMessage() + "\"}");
        return;
    } finally {
        DBUtil.close(conn, ps, rs);
    }

    sb.append("]");
    out.print(sb.toString());
%>
<%!
    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
%>
