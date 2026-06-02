<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*, util.DBUtil" %>
<%
    String userId = (String) session.getAttribute("userId");
    String role   = (String) session.getAttribute("role");
    if (userId == null) { out.print("{\"ok\":false}"); return; }

    String idParam  = request.getParameter("id");
    String allParam = request.getParameter("all");

    Connection conn = null; PreparedStatement ps = null;
    try {
        conn = DBUtil.getConnection();

        if ("1".equals(allParam)) {
            // 전체 읽음 → 내가 아직 안읽은 공지 전체를 notice_reads에 INSERT
            ps = conn.prepareStatement(
                "INSERT IGNORE INTO notice_reads (notice_id, user_id) " +
                "SELECT n.notice_id, ? FROM notices n " +
                "WHERE (n.target_role = 'all' OR n.target_role = ?) " +
                "AND n.notice_id NOT IN (" +
                "  SELECT nr.notice_id FROM notice_reads nr WHERE nr.user_id = ?" +
                ")");
            ps.setString(1, userId);
            ps.setString(2, role != null ? role : "");
            ps.setString(3, userId);
            ps.executeUpdate();

        } else if (idParam != null && !idParam.isEmpty()) {
            // 개별 읽음 → notice_reads에 INSERT (이미 있으면 무시)
            ps = conn.prepareStatement(
                "INSERT IGNORE INTO notice_reads (notice_id, user_id) VALUES (?, ?)");
            ps.setInt(1, Integer.parseInt(idParam));
            ps.setString(2, userId);
            ps.executeUpdate();
        }

        out.print("{\"ok\":true}");
    } catch (Exception e) {
        out.print("{\"ok\":false,\"msg\":\"" + e.getMessage() + "\"}");
    } finally {
        DBUtil.close(conn, ps, null);
    }
%>
