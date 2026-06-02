<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.net.HttpURLConnection" %>
<%@ page import="java.net.URL" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.io.BufferedReader" %>
<%@ page import="java.io.InputStreamReader" %>
<%@ page import="java.nio.charset.StandardCharsets" %>

<%
    // =========================
    // Naver API 인증 정보
    // =========================
     final String NAVER_CLIENT_ID = "qbne7axnj9";
     final String NAVER_CLIENT_SECRET = "Af9UBYC9fXfzs9Kb6Eu4A4hFY4vMYB2aaQQ2qx7s";


    // =========================
    // Directions 프록시 처리
    // =========================
    String apiAction = request.getParameter("apiAction");

    if ("directions".equals(apiAction)) {
        response.setContentType("application/json; charset=UTF-8");

        String start = request.getParameter("start");   // lon,lat
        String goal = request.getParameter("goal");     // lon,lat
        String option = request.getParameter("option"); // trafast 등

        if (start == null || goal == null || start.trim().isEmpty() || goal.trim().isEmpty()) {
            response.setStatus(400);
            out.print("{\"error\":true,\"message\":\"start/goal 파라미터가 필요합니다.\"}");
            return;
        }

        if (option == null || option.trim().isEmpty()) {
            option = "trafast";
        }

        HttpURLConnection conn = null;
        BufferedReader reader = null;

        try {
            String endpoint = "https://maps.apigw.ntruss.com/map-direction-15/v1/driving";
            String query = "start=" + URLEncoder.encode(start, "UTF-8")
                         + "&goal=" + URLEncoder.encode(goal, "UTF-8")
                         + "&option=" + URLEncoder.encode(option, "UTF-8");

            URL url = new URL(endpoint + "?" + query);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("x-ncp-apigw-api-key-id", NAVER_CLIENT_ID);
            conn.setRequestProperty("x-ncp-apigw-api-key", NAVER_CLIENT_SECRET);
            conn.setRequestProperty("Accept", "application/json");

            int status = conn.getResponseCode();
            response.setStatus(status);

            if (status >= 200 && status < 300) {
                reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8));
            } else {
                reader = new BufferedReader(new InputStreamReader(conn.getErrorStream(), StandardCharsets.UTF_8));
            }

            StringBuilder body = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                body.append(line);
            }

            out.print(body.toString());
            return;

        } catch (Exception e) {
            response.setStatus(500);
            out.print("{\"error\":true,\"message\":\"" + e.getMessage().replace("\"", "\\\"") + "\"}");
            return;
        } finally {
            try { if (reader != null) reader.close(); } catch (Exception ignore) {}
            try { if (conn != null) conn.disconnect(); } catch (Exception ignore) {}
        }
    }
%>

<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<title>TSP 주소 기반 최적 경로 시스템</title>
<meta name="viewport" content="width=device-width, initial-scale=1">

<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

<script type="text/javascript"
src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=<%= NAVER_CLIENT_ID %>"></script>

<style>
    body {
        background: #f6f8fb;
        font-family: "맑은 고딕", sans-serif;
    }

    .wrap {
        max-width: 1280px;
        margin: 30px auto;
    }

    .card-box {
        background: #fff;
        border-radius: 18px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.08);
        padding: 24px;
        margin-bottom: 20px;
    }

    .title {
        font-size: 1.7rem;
        font-weight: 700;
        color: #1f2d3d;
        margin-bottom: 8px;
    }

    .sub-title {
        font-size: 1.1rem;
        font-weight: 700;
        margin-bottom: 15px;
        color: #2f4858;
    }

    .stop-item {
        border: 1px solid #dee2e6;
        border-radius: 14px;
        padding: 16px;
        margin-bottom: 14px;
        background: #fcfcfd;
    }

    .result-box {
        background: #f8f9fa;
        border: 1px dashed #adb5bd;
        border-radius: 12px;
        padding: 15px;
    }

    .search-results {
        border: 1px solid #dee2e6;
        border-radius: 10px;
        margin-top: 10px;
        max-height: 220px;
        overflow-y: auto;
        background: #fff;
    }

    .search-item {
        padding: 10px 12px;
        border-bottom: 1px solid #f1f3f5;
        cursor: pointer;
    }

    .search-item:last-child {
        border-bottom: none;
    }

    .search-item:hover {
        background: #f8f9fa;
    }

    .route-step {
        background: white;
        border: 1px solid #e9ecef;
        border-radius: 10px;
        padding: 10px 12px;
        margin-bottom: 8px;
    }

    .small-note {
        color: #6c757d;
        font-size: 0.9rem;
    }

    .calc-highlight {
        background: #eef6ff;
        border: 1px solid #cfe2ff;
        border-radius: 12px;
        padding: 14px;
    }

    #map {
        width: 100%;
        height: 520px;
        border-radius: 14px;
        border: 1px solid #dee2e6;
        display: none;
    }

    #mapGuide {
        display: none;
        margin-bottom: 8px;
        white-space: pre-line;
    }

    #detailMap {
        width: 100%;
        height: 75vh;
        border: 1px solid #dee2e6;
        border-radius: 14px;
    }
</style>
</head>
<body>

<div class="container wrap">
    <div class="card-box">
        <div class="title">주소 기반 Traveling Salesman Problem 최적 경로 시스템</div>
        <div class="small-note">
            주소 검색 후 위도/경도를 자동 추출하고, 여러 목적지의 최적 방문 순서를 계산합니다.
        </div>
    </div>

    <div class="row g-4">
        <div class="col-lg-8">
            <div class="card-box">
                <div class="sub-title">1. 출발지 설정</div>

                <div class="row g-3">
                    <div class="col-md-8">
                        <label class="form-label">출발지 주소</label>
                        <input type="text" id="startAddress" class="form-control" placeholder="예: 서울특별시 중구 세종대로 110">
                    </div>
                    <div class="col-md-4 d-flex align-items-end">
                        <button type="button" class="btn btn-primary w-100" onclick="searchStartAddress()">출발지 검색</button>
                    </div>

                    <div class="col-md-4">
                        <label class="form-label">출발지 위도</label>
                        <input type="text" id="startLat" class="form-control" readonly>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">출발지 경도</label>
                        <input type="text" id="startLon" class="form-control" readonly>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">출발일시</label>
                        <input type="datetime-local" id="startDateTime" class="form-control">
                    </div>

                    <div class="col-12">
                        <div id="startSearchResults" class="search-results" style="display:none;"></div>
                    </div>
                </div>
            </div>

            <div class="card-box">
                <div class="sub-title">2. 주행 조건 설정</div>

                <div class="row g-3">
                    <div class="col-md-4">
                        <label class="form-label">평균 속도 (km/h)</label>
                        <input type="number" id="avgSpeed" class="form-control" value="100" min="1" step="1">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">연비 (km/L)</label>
                        <input type="number" id="fuelEfficiency" class="form-control" value="12" min="0.1" step="0.1">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">유가 (원/L)</label>
                        <input type="number" id="fuelPrice" class="form-control" value="1800" min="1" step="1">
                    </div>
                </div>
            </div>

            <div class="card-box">
                <div class="d-flex justify-content-between align-items-center mb-3">
                    <div class="sub-title mb-0">3. 방문지(목적지) 설정</div>
                    <button type="button" class="btn btn-success" onclick="addStop()">+ 방문지 추가</button>
                </div>

                <div id="stopList"></div>

                <div class="mt-3 d-flex gap-2">
                    <button type="button" class="btn btn-dark" onclick="calculateTSP()">최적 경로 계산</button>
                    <button type="button" class="btn btn-secondary" onclick="resetAll()">초기화</button>
                </div>

                <div class="small-note mt-3">
                    목적지가 8개 이하이면 정확탐색, 9개 이상이면 최근접 이웃 방식으로 계산합니다.
                </div>
            </div>
        </div>

        <div class="col-lg-4">
            <div class="card-box">
                <div class="d-flex justify-content-between align-items-center mb-3">
                    <div class="sub-title mb-0">4. 계산 결과</div>
                    <button type="button" class="btn btn-outline-primary btn-sm" onclick="showOptimalRouteMap()">
                        최적경로 지도보기
                    </button>
                </div>

                <div class="result-box mb-3">
                    <div><strong>계산 방식:</strong> <span id="algoType">-</span></div>
                    <div><strong>총 이동거리:</strong> <span id="totalDistance">-</span></div>
                </div>

                <div class="calc-highlight mb-3">
                    <div><strong>첫 구간 거리:</strong> <span id="firstLegDistance">-</span></div>
                    <div><strong>예상 도착시간:</strong> <span id="firstArrivalTime">-</span></div>
                    <div><strong>첫 구간 필요 연료:</strong> <span id="firstFuelNeeded">-</span></div>
                    <div><strong>첫 구간 예상 유류비:</strong> <span id="firstFuelCost">-</span></div>
                </div>

                <div id="routeResult">
                    아직 계산된 경로가 없습니다.
                </div>
            </div>

            <div class="card-box">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <div class="sub-title mb-0">5. 최적경로 지도</div>
                    <button type="button" class="btn btn-outline-secondary btn-sm" onclick="openMapDetailModal()">자세히</button>
                </div>

                <div id="mapGuide" class="small-note">
                    계산 후 버튼을 누르면 최적 경로가 지도에 표시됩니다.
                </div>
                <div id="map"></div>
            </div>
        </div>
    </div>
</div>

<!-- 상세 지도 모달 -->
<div class="modal fade" id="mapDetailModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content" style="border-radius:18px;">
            <div class="modal-header">
                <h5 class="modal-title">최적경로 상세 지도</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="닫기"></button>
            </div>
            <div class="modal-body">
                <div class="small-note mb-2" id="detailMapGuide">
                    확대된 지도에서 최적 경로를 확인할 수 있습니다.
                </div>
                <div id="detailMap"></div>
            </div>
        </div>
    </div>
</div>

<script>
let stopIndex = 0;

let map = null;
let markers = [];
let polylines = [];

let detailMap = null;
let detailMarkers = [];
let detailPolylines = [];

let latestCalculatedStart = null;
let latestCalculatedRoute = [];

window.onload = function() {
    addStop();

    document.getElementById("startAddress").addEventListener("keypress", function(e) {
        if (e.key === "Enter") {
            e.preventDefault();
            searchStartAddress();
        }
    });

    const now = new Date();
    const local = new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    document.getElementById("startDateTime").value = local;
};

async function searchAddressByText(address) {
    const url = "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=" + encodeURIComponent(address);

    const response = await fetch(url, {
        headers: {
            "Accept": "application/json"
        }
    });

    if (!response.ok) {
        throw new Error("주소 검색 오류: " + response.status);
    }

    return await response.json();
}

async function searchStartAddress() {
    const address = document.getElementById("startAddress").value.trim();
    const box = document.getElementById("startSearchResults");

    if (!address) {
        alert("출발지 주소를 입력하세요.");
        return;
    }

    box.style.display = "block";
    box.innerHTML = '<div class="search-item">검색 중...</div>';

    try {
        const results = await searchAddressByText(address);

        if (!results || results.length === 0) {
            box.innerHTML = '<div class="search-item">검색 결과가 없습니다.</div>';
            return;
        }

        let html = "";
        results.forEach(function(item, idx) {
            html += '<div class="search-item" onclick="selectStart('
                 + '\'' + escapeJs(item.display_name) + '\','
                 + '\'' + item.lat + '\','
                 + '\'' + item.lon + '\''
                 + ')">';
            html += '<strong>' + (idx + 1) + '. ' + item.display_name + '</strong><br>';
            html += '위도: ' + item.lat + ' / 경도: ' + item.lon;
            html += '</div>';
        });

        box.innerHTML = html;
    } catch (e) {
        box.innerHTML = '<div class="search-item">오류: ' + e.message + '</div>';
    }
}

function selectStart(address, lat, lon) {
    document.getElementById("startAddress").value = address;
    document.getElementById("startLat").value = parseFloat(lat).toFixed(6);
    document.getElementById("startLon").value = parseFloat(lon).toFixed(6);
    document.getElementById("startSearchResults").style.display = "none";
}

function addStop() {
    const idx = stopIndex++;
    const list = document.getElementById("stopList");

    let html = '';
    html += '<div class="stop-item" id="stopItem_' + idx + '">';
    html += '  <div class="d-flex justify-content-between align-items-center mb-2">';
    html += '      <strong>방문지 ' + (idx + 1) + '</strong>';
    html += '      <button type="button" class="btn btn-sm btn-outline-danger" onclick="removeStop(' + idx + ')">삭제</button>';
    html += '  </div>';

    html += '  <div class="row g-3">';
    html += '      <div class="col-md-8">';
    html += '          <label class="form-label">주소</label>';
    html += '          <input type="text" id="stopAddress_' + idx + '" class="form-control" placeholder="방문지 주소 입력">';
    html += '      </div>';
    html += '      <div class="col-md-4 d-flex align-items-end">';
    html += '          <button type="button" class="btn btn-outline-primary w-100" onclick="searchStopAddress(' + idx + ')">주소 검색</button>';
    html += '      </div>';

    html += '      <div class="col-md-6">';
    html += '          <label class="form-label">위도</label>';
    html += '          <input type="text" id="stopLat_' + idx + '" class="form-control" readonly>';
    html += '      </div>';
    html += '      <div class="col-md-6">';
    html += '          <label class="form-label">경도</label>';
    html += '          <input type="text" id="stopLon_' + idx + '" class="form-control" readonly>';
    html += '      </div>';

    html += '      <div class="col-12">';
    html += '          <div id="stopSearchResults_' + idx + '" class="search-results" style="display:none;"></div>';
    html += '      </div>';
    html += '  </div>';
    html += '</div>';

    list.insertAdjacentHTML("beforeend", html);

    document.getElementById("stopAddress_" + idx).addEventListener("keypress", function(e) {
        if (e.key === "Enter") {
            e.preventDefault();
            searchStopAddress(idx);
        }
    });
}

function removeStop(idx) {
    const item = document.getElementById("stopItem_" + idx);
    if (item) item.remove();
}

async function searchStopAddress(idx) {
    const address = document.getElementById("stopAddress_" + idx).value.trim();
    const box = document.getElementById("stopSearchResults_" + idx);

    if (!address) {
        alert("방문지 주소를 입력하세요.");
        return;
    }

    box.style.display = "block";
    box.innerHTML = '<div class="search-item">검색 중...</div>';

    try {
        const results = await searchAddressByText(address);

        if (!results || results.length === 0) {
            box.innerHTML = '<div class="search-item">검색 결과가 없습니다.</div>';
            return;
        }

        let html = "";
        results.forEach(function(item, i) {
            html += '<div class="search-item" onclick="selectStop('
                 + idx + ','
                 + '\'' + escapeJs(item.display_name) + '\','
                 + '\'' + item.lat + '\','
                 + '\'' + item.lon + '\''
                 + ')">';
            html += '<strong>' + (i + 1) + '. ' + item.display_name + '</strong><br>';
            html += '위도: ' + item.lat + ' / 경도: ' + item.lon;
            html += '</div>';
        });

        box.innerHTML = html;
    } catch (e) {
        box.innerHTML = '<div class="search-item">오류: ' + e.message + '</div>';
    }
}

function selectStop(idx, address, lat, lon) {
    document.getElementById("stopAddress_" + idx).value = address;
    document.getElementById("stopLat_" + idx).value = parseFloat(lat).toFixed(6);
    document.getElementById("stopLon_" + idx).value = parseFloat(lon).toFixed(6);
    document.getElementById("stopSearchResults_" + idx).style.display = "none";
}

function getInputData() {
    const startAddress = document.getElementById("startAddress").value.trim();
    const startLat = parseFloat(document.getElementById("startLat").value);
    const startLon = parseFloat(document.getElementById("startLon").value);
    const startDateTime = document.getElementById("startDateTime").value;
    const avgSpeed = parseFloat(document.getElementById("avgSpeed").value);
    const fuelEfficiency = parseFloat(document.getElementById("fuelEfficiency").value);
    const fuelPrice = parseFloat(document.getElementById("fuelPrice").value);

    if (!startAddress || isNaN(startLat) || isNaN(startLon)) {
        alert("출발지를 먼저 설정하세요.");
        return null;
    }

    if (!startDateTime) {
        alert("출발일시를 입력하세요.");
        return null;
    }

    if (isNaN(avgSpeed) || avgSpeed <= 0) {
        alert("평균 속도를 올바르게 입력하세요.");
        return null;
    }

    if (isNaN(fuelEfficiency) || fuelEfficiency <= 0) {
        alert("연비를 올바르게 입력하세요.");
        return null;
    }

    if (isNaN(fuelPrice) || fuelPrice <= 0) {
        alert("유가를 올바르게 입력하세요.");
        return null;
    }

    const stopItems = document.querySelectorAll("[id^='stopItem_']");
    const stops = [];

    stopItems.forEach(function(item, idx) {
        const addressInput = item.querySelector("input[id^='stopAddress_']");
        const latInput = item.querySelector("input[id^='stopLat_']");
        const lonInput = item.querySelector("input[id^='stopLon_']");

        const address = addressInput ? addressInput.value.trim() : "";
        const lat = latInput ? parseFloat(latInput.value) : NaN;
        const lon = lonInput ? parseFloat(lonInput.value) : NaN;

        if (address && !isNaN(lat) && !isNaN(lon)) {
            stops.push({
                name: "방문지 " + (idx + 1),
                address: address,
                lat: lat,
                lon: lon
            });
        }
    });

    if (stops.length === 0) {
        alert("방문지를 1개 이상 입력하세요.");
        return null;
    }

    return {
        start: {
            name: "출발지",
            address: startAddress,
            lat: startLat,
            lon: startLon,
            dateTime: startDateTime
        },
        drive: {
            avgSpeed: avgSpeed,
            fuelEfficiency: fuelEfficiency,
            fuelPrice: fuelPrice
        },
        stops: stops
    };
}

function toRad(value) {
    return value * Math.PI / 180;
}

function haversine(lat1, lon1, lat2, lon2) {
    const R = 6371.0;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);

    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function calculateRouteDistance(start, orderedStops) {
    let total = 0;
    let current = start;

    orderedStops.forEach(function(stop) {
        total += haversine(current.lat, current.lon, stop.lat, stop.lon);
        current = stop;
    });

    return total;
}

function permute(arr) {
    if (arr.length <= 1) return [arr];

    const result = [];

    for (let i = 0; i < arr.length; i++) {
        const current = arr[i];
        const remaining = arr.slice(0, i).concat(arr.slice(i + 1));
        const perms = permute(remaining);

        perms.forEach(function(p) {
            result.push([current].concat(p));
        });
    }

    return result;
}

function nearestNeighborRoute(start, stops) {
    const unvisited = stops.slice();
    const route = [];
    let current = start;

    while (unvisited.length > 0) {
        let bestIndex = 0;
        let bestDist = haversine(current.lat, current.lon, unvisited[0].lat, unvisited[0].lon);

        for (let i = 1; i < unvisited.length; i++) {
            const d = haversine(current.lat, current.lon, unvisited[i].lat, unvisited[i].lon);
            if (d < bestDist) {
                bestDist = d;
                bestIndex = i;
            }
        }

        const next = unvisited.splice(bestIndex, 1)[0];
        route.push(next);
        current = next;
    }

    return route;
}

function formatNumber(num) {
    return new Intl.NumberFormat("ko-KR").format(Math.round(num));
}

function formatDateTime(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    const hh = String(date.getHours()).padStart(2, "0");
    const mm = String(date.getMinutes()).padStart(2, "0");
    return y + "-" + m + "-" + d + " " + hh + ":" + mm;
}

function calculateFirstLegInfo(start, firstStop, drive) {
    if (!firstStop) {
        document.getElementById("firstLegDistance").innerText = "-";
        document.getElementById("firstArrivalTime").innerText = "-";
        document.getElementById("firstFuelNeeded").innerText = "-";
        document.getElementById("firstFuelCost").innerText = "-";
        return;
    }

    const distance = haversine(start.lat, start.lon, firstStop.lat, firstStop.lon);
    const travelHours = distance / drive.avgSpeed;
    const fuelNeeded = distance / drive.fuelEfficiency;
    const fuelCost = fuelNeeded * drive.fuelPrice;

    const startDate = new Date(start.dateTime);
    const arrivalDate = new Date(startDate.getTime() + travelHours * 60 * 60 * 1000);

    document.getElementById("firstLegDistance").innerText = distance.toFixed(2) + " km";
    document.getElementById("firstArrivalTime").innerText = formatDateTime(arrivalDate);
    document.getElementById("firstFuelNeeded").innerText = fuelNeeded.toFixed(2) + " L";
    document.getElementById("firstFuelCost").innerText = formatNumber(fuelCost) + " 원";
}

function calculateTSP() {
    const data = getInputData();
    if (!data) return;

    const start = data.start;
    const drive = data.drive;
    const stops = data.stops;

    let bestRoute = [];
    let bestDistance = Infinity;
    let algorithm = "";

    if (stops.length <= 8) {
        const allRoutes = permute(stops);

        allRoutes.forEach(function(route) {
            const dist = calculateRouteDistance(start, route);
            if (dist < bestDistance) {
                bestDistance = dist;
                bestRoute = route;
            }
        });

        algorithm = "정확 탐색 (Brute Force)";
    } else {
        bestRoute = nearestNeighborRoute(start, stops);
        bestDistance = calculateRouteDistance(start, bestRoute);
        algorithm = "휴리스틱 (Nearest Neighbor)";
    }

    document.getElementById("algoType").innerText = algorithm;
    document.getElementById("totalDistance").innerText = bestDistance.toFixed(2) + " km";

    calculateFirstLegInfo(start, bestRoute[0], drive);
    renderRouteResult(start, bestRoute, drive);

    latestCalculatedStart = start;
    latestCalculatedRoute = bestRoute;

    document.getElementById("mapGuide").style.display = "block";
    document.getElementById("mapGuide").innerText = "계산이 완료되었습니다.\n'최적경로 지도보기' 버튼을 누르면 실제 도로 기준으로 표시됩니다.";
}

function renderRouteResult(start, route, drive) {
    const box = document.getElementById("routeResult");
    let html = "";

    html += '<div class="route-step">';
    html += '<strong>0. 출발지</strong><br>';
    html += start.address + '<br>';
    html += '(' + start.lat.toFixed(6) + ', ' + start.lon.toFixed(6) + ')<br>';
    html += '출발일시: ' + start.dateTime.replace("T", " ");
    html += '</div>';

    let current = start;
    let cumulative = 0;
    let currentDate = new Date(start.dateTime);

    route.forEach(function(stop, idx) {
        const d = haversine(current.lat, current.lon, stop.lat, stop.lon);
        const travelHours = d / drive.avgSpeed;
        const fuelNeeded = d / drive.fuelEfficiency;
        const fuelCost = fuelNeeded * drive.fuelPrice;

        cumulative += d;
        currentDate = new Date(currentDate.getTime() + travelHours * 60 * 60 * 1000);

        html += '<div class="route-step">';
        html += '<strong>' + (idx + 1) + '. ' + stop.name + '</strong><br>';
        html += stop.address + '<br>';
        html += '(' + stop.lat.toFixed(6) + ', ' + stop.lon.toFixed(6) + ')<br>';
        html += '구간거리: ' + d.toFixed(2) + ' km<br>';
        html += '누적거리: ' + cumulative.toFixed(2) + ' km<br>';
        html += '예상도착: ' + formatDateTime(currentDate) + '<br>';
        html += '연료소요: ' + fuelNeeded.toFixed(2) + ' L<br>';
        html += '예상유류비: ' + formatNumber(fuelCost) + ' 원';
        html += '</div>';

        current = stop;
    });

    box.innerHTML = html;
}

function initMapIfNeeded() {
    if (map) return;

    map = new naver.maps.Map('map', {
        center: new naver.maps.LatLng(36.5, 127.8),
        zoom: 7
    });
}

function initDetailMapIfNeeded() {
    if (detailMap) return;

    detailMap = new naver.maps.Map('detailMap', {
        center: new naver.maps.LatLng(36.5, 127.8),
        zoom: 7
    });
}

function clearMapObjects() {
    markers.forEach(function(m) { m.setMap(null); });
    polylines.forEach(function(p) { p.setMap(null); });
    markers = [];
    polylines = [];
}

function clearDetailMapObjects() {
    detailMarkers.forEach(function(m) { m.setMap(null); });
    detailPolylines.forEach(function(p) { p.setMap(null); });
    detailMarkers = [];
    detailPolylines = [];
}

function setMapGuide(message) {
    const guide = document.getElementById("mapGuide");
    guide.style.display = "block";
    guide.innerText = message;
}

function setDetailMapGuide(message) {
    document.getElementById("detailMapGuide").innerText = message;
}

function getBestRoute(data) {
    if (!data || !data.route) return null;

    if (data.route.trafast && data.route.trafast.length > 0) return data.route.trafast[0];
    if (data.route.traoptimal && data.route.traoptimal.length > 0) return data.route.traoptimal[0];
    if (data.route.tracomfort && data.route.tracomfort.length > 0) return data.route.tracomfort[0];
    if (data.route.traavoidtoll && data.route.traavoidtoll.length > 0) return data.route.traavoidtoll[0];
    if (data.route.traavoidcaronly && data.route.traavoidcaronly.length > 0) return data.route.traavoidcaronly[0];

    return null;
}

async function requestDirectionsSegment(startPoint, goalPoint) {
    const params = new URLSearchParams();
    params.append("apiAction", "directions");
    params.append("start", startPoint.lon + "," + startPoint.lat);
    params.append("goal", goalPoint.lon + "," + goalPoint.lat);
    params.append("option", "trafast");

    const response = await fetch("<%= request.getRequestURI() %>", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
        },
        body: params.toString()
    });

    const data = await response.json();

    if (!response.ok || data.error) {
        throw new Error("경로 조회 실패");
    }

    const route = getBestRoute(data);
    if (!route || !route.path || route.path.length === 0) {
        throw new Error("경로 데이터 없음");
    }

    return route;
}

function addMarkerToTarget(targetMap, targetMarkers, point, labelText) {
    const marker = new naver.maps.Marker({
        position: new naver.maps.LatLng(point.lat, point.lon),
        map: targetMap,
        title: labelText
    });

    const html = '<div style="padding:8px 10px;font-size:13px;min-width:140px;">'
               + '<strong>' + labelText + '</strong><br>'
               + point.address
               + '</div>';

    const info = new naver.maps.InfoWindow({
        content: html
    });

    naver.maps.Event.addListener(marker, 'click', function() {
        if (info.getMap()) info.close();
        else info.open(targetMap, marker);
    });

    targetMarkers.push(marker);
}

async function drawRouteOnTarget(targetMap, targetMarkers, targetPolylines, guideSetter) {
    if (!latestCalculatedStart || !latestCalculatedRoute || latestCalculatedRoute.length === 0) {
        throw new Error("먼저 최적 경로 계산을 실행하세요.");
    }

    const fullPoints = [latestCalculatedStart].concat(latestCalculatedRoute);

    addMarkerToTarget(targetMap, targetMarkers, latestCalculatedStart, "출발지");
    latestCalculatedRoute.forEach(function(stop, idx) {
        addMarkerToTarget(targetMap, targetMarkers, stop, (idx + 1) + "번 방문지");
    });

    guideSetter("실제 도로 기준 최적 경로를 불러오는 중입니다...");

    const bounds = new naver.maps.LatLngBounds();
    let totalRoadDistance = 0;
    let totalRoadDuration = 0;
    let totalTollFare = 0;
    let totalTaxiFare = 0;

    for (let i = 0; i < fullPoints.length - 1; i++) {
        const from = fullPoints[i];
        const to = fullPoints[i + 1];

        const route = await requestDirectionsSegment(from, to);

        const path = route.path.map(function(p) {
            const latlng = new naver.maps.LatLng(p[1], p[0]);
            bounds.extend(latlng);
            return latlng;
        });

        const polyline = new naver.maps.Polyline({
            map: targetMap,
            path: path,
            strokeColor: '#007bff',
            strokeWeight: 6,
            strokeOpacity: 0.85
        });

        targetPolylines.push(polyline);

        if (route.summary) {
            totalRoadDistance += route.summary.distance || 0;
            totalRoadDuration += route.summary.duration || 0;
            totalTollFare += route.summary.tollFare || 0;
            totalTaxiFare += route.summary.taxiFare || 0;
        }
    }

    fullPoints.forEach(function(p) {
        bounds.extend(new naver.maps.LatLng(p.lat, p.lon));
    });

    targetMap.fitBounds(bounds);

    const distanceKm = (totalRoadDistance / 1000).toFixed(2);
    const durationMin = Math.round(totalRoadDuration / 60000);

    guideSetter(
        "실제 도로 기준 최적 경로가 표시되었습니다.\n"
        + "총 실제 도로 거리: " + distanceKm + " km\n"
        + "총 예상 시간: " + durationMin + " 분\n"
        + "총 통행료: " + formatNumber(totalTollFare) + " 원\n"
        + "총 예상 택시비: " + formatNumber(totalTaxiFare) + " 원"
    );
}

async function showOptimalRouteMap() {
    if (!latestCalculatedStart || !latestCalculatedRoute || latestCalculatedRoute.length === 0) {
        alert("먼저 최적 경로 계산을 실행하세요.");
        return;
    }

    const mapDiv = document.getElementById("map");
    mapDiv.style.display = "block";

    initMapIfNeeded();
    clearMapObjects();

    try {
        await drawRouteOnTarget(map, markers, polylines, setMapGuide);
    } catch (e) {
        console.error(e);
        setMapGuide("실제 도로 경로 표시 중 오류가 발생했습니다: " + e.message);
        alert("지도 경로 표시 실패: " + e.message);
    }
}

async function openMapDetailModal() {
    if (!latestCalculatedStart || !latestCalculatedRoute || latestCalculatedRoute.length === 0) {
        alert("먼저 최적 경로 계산을 실행하세요.");
        return;
    }

    const modalElement = document.getElementById("mapDetailModal");
    const modal = new bootstrap.Modal(modalElement);
    modal.show();

    setTimeout(async function() {
        initDetailMapIfNeeded();
        clearDetailMapObjects();

        try {
            await drawRouteOnTarget(detailMap, detailMarkers, detailPolylines, setDetailMapGuide);
            naver.maps.Event.trigger(detailMap, "resize");
        } catch (e) {
            console.error(e);
            setDetailMapGuide("상세 지도 표시 중 오류가 발생했습니다: " + e.message);
            alert("상세 지도 표시 실패: " + e.message);
        }
    }, 300);
}

function resetAll() {
    document.getElementById("startAddress").value = "";
    document.getElementById("startLat").value = "";
    document.getElementById("startLon").value = "";
    document.getElementById("startSearchResults").style.display = "none";
    document.getElementById("startSearchResults").innerHTML = "";

    const now = new Date();
    const local = new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    document.getElementById("startDateTime").value = local;

    document.getElementById("avgSpeed").value = 100;
    document.getElementById("fuelEfficiency").value = 12;
    document.getElementById("fuelPrice").value = 1800;

    document.getElementById("stopList").innerHTML = "";
    stopIndex = 0;
    addStop();

    document.getElementById("algoType").innerText = "-";
    document.getElementById("totalDistance").innerText = "-";
    document.getElementById("firstLegDistance").innerText = "-";
    document.getElementById("firstArrivalTime").innerText = "-";
    document.getElementById("firstFuelNeeded").innerText = "-";
    document.getElementById("firstFuelCost").innerText = "-";
    document.getElementById("routeResult").innerHTML = "아직 계산된 경로가 없습니다.";

    latestCalculatedStart = null;
    latestCalculatedRoute = [];

    document.getElementById("map").style.display = "none";
    document.getElementById("mapGuide").style.display = "none";
    document.getElementById("mapGuide").innerText = "";

    document.getElementById("detailMapGuide").innerText = "확대된 지도에서 최적 경로를 확인할 수 있습니다.";

    clearMapObjects();
    clearDetailMapObjects();
}

function escapeJs(str) {
    if (!str) return "";
    return str
        .replace(/\\/g, "\\\\")
        .replace(/'/g, "\\'")
        .replace(/"/g, '\\"')
        .replace(/\r/g, "")
        .replace(/\n/g, "");
}
</script>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

</body>
</html>