<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>

<%!
    // -----------------------------
    // Vendor 클래스
    // -----------------------------
    public static class Vendor {
        String name;
        int maxCapacity;          // 최대 생산 가능량
        int currentStock;         // 현재 재고
        double unitCost;          // 단가
        double transportCost;     // 운송비(개당)
        double delayRisk;         // 납기 지연 위험(0~1)
        double defectRisk;        // 품질 불량 위험(0~1)

        // 점수 기반 모델용 (0~20)
        int costScore;
        int deliveryScore;
        int inventoryScore;
        int qualityScore;
        int stabilityScore;

        public Vendor(String name, int maxCapacity, int currentStock,
                      double unitCost, double transportCost,
                      double delayRisk, double defectRisk,
                      int costScore, int deliveryScore, int inventoryScore,
                      int qualityScore, int stabilityScore) {
            this.name = name;
            this.maxCapacity = maxCapacity;
            this.currentStock = currentStock;
            this.unitCost = unitCost;
            this.transportCost = transportCost;
            this.delayRisk = delayRisk;
            this.defectRisk = defectRisk;
            this.costScore = costScore;
            this.deliveryScore = deliveryScore;
            this.inventoryScore = inventoryScore;
            this.qualityScore = qualityScore;
            this.stabilityScore = stabilityScore;
        }

        public int totalVendorScore() {
            return costScore + deliveryScore + inventoryScore + qualityScore + stabilityScore;
        }
    }

    // -----------------------------
    // Plan 클래스
    // -----------------------------
    public static class Plan {
        int[] qty; // A, B, C 업체 배분량
        double fitness;
        double objectiveCost;

        int diversificationScore;
        int planCostScore;
        int deliveryScore;
        int inventoryScore;
        double vendorWeightedScore;

        public Plan(int vendorCount) {
            qty = new int[vendorCount];
        }

        public Plan copy() {
            Plan p = new Plan(qty.length);
            for (int i = 0; i < qty.length; i++) {
                p.qty[i] = this.qty[i];
            }
            p.fitness = this.fitness;
            p.objectiveCost = this.objectiveCost;
            p.diversificationScore = this.diversificationScore;
            p.planCostScore = this.planCostScore;
            p.deliveryScore = this.deliveryScore;
            p.inventoryScore = this.inventoryScore;
            p.vendorWeightedScore = this.vendorWeightedScore;
            return p;
        }

        public int sum() {
            int s = 0;
            for (int q : qty) s += q;
            return s;
        }
    }

    // -----------------------------
    // 랜덤 객체
    // -----------------------------
    Random rnd = new Random();

    // -----------------------------
    // 랜덤 생산계획 생성
    // -----------------------------
    public Plan createRandomPlan(Vendor[] vendors, int totalDemand) {
        Plan p = new Plan(vendors.length);

        int remaining = totalDemand;
        int[] max = new int[vendors.length];

        for (int i = 0; i < vendors.length; i++) {
            max[i] = vendors[i].maxCapacity + vendors[i].currentStock;
        }

        for (int i = 0; i < vendors.length - 1; i++) {
            int allocMax = Math.min(max[i], remaining);
            int val = (allocMax > 0) ? rnd.nextInt(allocMax + 1) : 0;
            p.qty[i] = val;
            remaining -= val;
        }

        p.qty[vendors.length - 1] = remaining;

        repairPlan(p, vendors, totalDemand);
        return p;
    }

    // -----------------------------
    // 생산계획 보정
    // -----------------------------
    public void repairPlan(Plan p, Vendor[] vendors, int totalDemand) {
        int n = vendors.length;

        // 음수 제거
        for (int i = 0; i < n; i++) {
            if (p.qty[i] < 0) p.qty[i] = 0;
        }

        // capacity 초과 제거
        for (int i = 0; i < n; i++) {
            int cap = vendors[i].maxCapacity + vendors[i].currentStock;
            if (p.qty[i] > cap) p.qty[i] = cap;
        }

        int current = p.sum();

        // 부족하면 남는 capacity에 배분
        while (current < totalDemand) {
            boolean changed = false;
            for (int i = 0; i < n && current < totalDemand; i++) {
                int cap = vendors[i].maxCapacity + vendors[i].currentStock;
                if (p.qty[i] < cap) {
                    p.qty[i]++;
                    current++;
                    changed = true;
                }
            }
            if (!changed) break;
        }

        // 초과하면 줄이기
        while (current > totalDemand) {
            for (int i = 0; i < n && current > totalDemand; i++) {
                if (p.qty[i] > 0) {
                    p.qty[i]--;
                    current--;
                }
            }
        }
    }

    // -----------------------------
    // 분산점수 계산 (0~20)
    // 균형 배분일수록 높음
    // -----------------------------
    public int calcDiversificationScore(Plan p, int totalDemand) {
        double ideal = totalDemand / (double)p.qty.length;
        double diff = 0.0;
        for (int q : p.qty) {
            diff += Math.abs(q - ideal);
        }

        double maxDiff = totalDemand * 1.333; // 대략적 상한
        double normalized = Math.max(0.0, 1.0 - (diff / maxDiff));
        int score = (int)Math.round(normalized * 20.0);

        if (score < 0) score = 0;
        if (score > 20) score = 20;
        return score;
    }

    // -----------------------------
    // 계획 수준 비용점수 (0~20)
    // 비용이 낮을수록 높음
    // -----------------------------
    public int calcPlanCostScore(Plan p, Vendor[] vendors) {
        double totalCost = 0.0;
        for (int i = 0; i < vendors.length; i++) {
            totalCost += p.qty[i] * (vendors[i].unitCost + vendors[i].transportCost);
        }

        // 예시용 단순 정규화
        double best = 90.0 * p.sum();
        double worst = 140.0 * p.sum();

        double normalized = 1.0 - ((totalCost - best) / (worst - best));
        if (normalized < 0) normalized = 0;
        if (normalized > 1) normalized = 1;

        return (int)Math.round(normalized * 20.0);
    }

    // -----------------------------
    // 계획 수준 납기점수 (0~20)
    // 납기 위험이 낮을수록 높음
    // -----------------------------
    public int calcDeliveryScore(Plan p, Vendor[] vendors) {
        double risk = 0.0;
        int total = p.sum();
        if (total == 0) return 0;

        for (int i = 0; i < vendors.length; i++) {
            double ratio = p.qty[i] / (double)total;
            risk += ratio * vendors[i].delayRisk;
        }

        double normalized = 1.0 - risk;
        if (normalized < 0) normalized = 0;
        if (normalized > 1) normalized = 1;

        return (int)Math.round(normalized * 20.0);
    }

    // -----------------------------
    // 계획 수준 재고점수 (0~20)
    // 재고 부족 위험이 낮을수록 높음
    // -----------------------------
    public int calcInventoryScore(Plan p, Vendor[] vendors) {
        double shortageRisk = 0.0;
        int total = p.sum();
        if (total == 0) return 0;

        for (int i = 0; i < vendors.length; i++) {
            if (p.qty[i] == 0) continue;
            int availableStock = vendors[i].currentStock;
            double stockCoverage = availableStock / (double)Math.max(1, p.qty[i]);
            double risk = 1.0 - Math.min(stockCoverage, 1.0);
            shortageRisk += (p.qty[i] / (double)total) * risk;
        }

        double normalized = 1.0 - shortageRisk;
        if (normalized < 0) normalized = 0;
        if (normalized > 1) normalized = 1;

        return (int)Math.round(normalized * 20.0);
    }

    // -----------------------------
    // 업체 가중평균 점수
    // -----------------------------
    public double calcVendorWeightedScore(Plan p, Vendor[] vendors) {
        int total = p.sum();
        if (total == 0) return 0.0;

        double score = 0.0;
        for (int i = 0; i < vendors.length; i++) {
            double ratio = p.qty[i] / (double)total;
            score += ratio * vendors[i].totalVendorScore();
        }
        return score;
    }

    // -----------------------------
    // 점수 기반 적합도 평가
    // FinalFitness = 업체가중점수 + 분산 + 비용 + 납기 + 재고
    // -----------------------------
    public void evaluateScoreModel(Plan p, Vendor[] vendors) {
        p.vendorWeightedScore = calcVendorWeightedScore(p, vendors);
        p.diversificationScore = calcDiversificationScore(p, p.sum());
        p.planCostScore = calcPlanCostScore(p, vendors);
        p.deliveryScore = calcDeliveryScore(p, vendors);
        p.inventoryScore = calcInventoryScore(p, vendors);

        p.fitness = p.vendorWeightedScore
                  + p.diversificationScore
                  + p.planCostScore
                  + p.deliveryScore
                  + p.inventoryScore;

        p.objectiveCost = 0.0;
    }

    // -----------------------------
    // 비용 최소화 모델
    // 목적함수 = 총생산비용 + 운송비 + 재고비용 + 납기지연패널티 + 품질리스크패널티 + 집중도패널티
    // fitness는 1 / (1 + 목적함수)
    // -----------------------------
    public void evaluateCostModel(Plan p, Vendor[] vendors) {
        double productionCost = 0.0;
        double transportCost = 0.0;
        double inventoryCost = 0.0;
        double delayPenalty = 0.0;
        double qualityPenalty = 0.0;

        int total = p.sum();

        for (int i = 0; i < vendors.length; i++) {
            int q = p.qty[i];
            productionCost += q * vendors[i].unitCost;
            transportCost += q * vendors[i].transportCost;

            int shortage = Math.max(0, q - vendors[i].currentStock);
            inventoryCost += shortage * 2.0; // 예시용

            delayPenalty += q * vendors[i].delayRisk * 8.0;
            qualityPenalty += q * vendors[i].defectRisk * 10.0;
        }

        double concentrationPenalty = 0.0;
        for (int i = 0; i < vendors.length; i++) {
            double ratio = (total == 0) ? 0.0 : p.qty[i] / (double)total;
            concentrationPenalty += ratio * ratio;
        }
        concentrationPenalty = concentrationPenalty * 100.0;

        p.objectiveCost = productionCost + transportCost + inventoryCost
                        + delayPenalty + qualityPenalty + concentrationPenalty;

        p.fitness = 1.0 / (1.0 + p.objectiveCost);

        // 화면 표시용 보조값
        p.vendorWeightedScore = calcVendorWeightedScore(p, vendors);
        p.diversificationScore = calcDiversificationScore(p, p.sum());
        p.planCostScore = calcPlanCostScore(p, vendors);
        p.deliveryScore = calcDeliveryScore(p, vendors);
        p.inventoryScore = calcInventoryScore(p, vendors);
    }

    // -----------------------------
    // 평가 실행
    // -----------------------------
    public void evaluatePlan(Plan p, Vendor[] vendors, String model) {
        if ("cost".equals(model)) {
            evaluateCostModel(p, vendors);
        } else {
            evaluateScoreModel(p, vendors);
        }
    }

    // -----------------------------
    // 토너먼트 선택
    // -----------------------------
    public Plan tournamentSelect(List<Plan> population, String model) {
        Plan a = population.get(rnd.nextInt(population.size()));
        Plan b = population.get(rnd.nextInt(population.size()));

        if ("cost".equals(model)) {
            return (a.objectiveCost < b.objectiveCost) ? a : b;
        } else {
            return (a.fitness > b.fitness) ? a : b;
        }
    }

    // -----------------------------
    // 교차 연산
    // -----------------------------
    public Plan crossover(Plan p1, Plan p2, Vendor[] vendors, int totalDemand) {
        Plan child = new Plan(vendors.length);
        int split = rnd.nextInt(vendors.length);

        for (int i = 0; i < vendors.length; i++) {
            child.qty[i] = (i <= split) ? p1.qty[i] : p2.qty[i];
        }

        repairPlan(child, vendors, totalDemand);
        return child;
    }

    // -----------------------------
    // 돌연변이
    // -----------------------------
    public void mutate(Plan p, Vendor[] vendors, int totalDemand, double mutationRate) {
        if (rnd.nextDouble() < mutationRate) {
            int from = rnd.nextInt(vendors.length);
            int to = rnd.nextInt(vendors.length);

            if (from != to && p.qty[from] > 0) {
                int move = rnd.nextInt(Math.max(1, p.qty[from] / 5 + 1));
                p.qty[from] -= move;
                p.qty[to] += move;
            }
        }
        repairPlan(p, vendors, totalDemand);
    }

    // -----------------------------
    // 정렬
    // -----------------------------
    public void sortPopulation(List<Plan> population, final String model) {
        Collections.sort(population, new Comparator<Plan>() {
            public int compare(Plan a, Plan b) {
                if ("cost".equals(model)) {
                    return Double.compare(a.objectiveCost, b.objectiveCost);
                } else {
                    return Double.compare(b.fitness, a.fitness);
                }
            }
        });
    }
%>

<%
    request.setCharacterEncoding("UTF-8");

    String run = request.getParameter("run");
    String model = request.getParameter("model");
    if (model == null || model.trim().equals("")) model = "score";

    int totalDemand = 10000;
    int generations = 100;
    int populationSize = 30;
    double mutationRate = 0.15;

    try {
        if (request.getParameter("totalDemand") != null) totalDemand = Integer.parseInt(request.getParameter("totalDemand"));
        if (request.getParameter("generations") != null) generations = Integer.parseInt(request.getParameter("generations"));
        if (request.getParameter("populationSize") != null) populationSize = Integer.parseInt(request.getParameter("populationSize"));
        if (request.getParameter("mutationRate") != null) mutationRate = Double.parseDouble(request.getParameter("mutationRate"));
    } catch (Exception e) {
        // 기본값 유지
    }

    Vendor[] vendors = new Vendor[] {
        new Vendor("A업체", 5000, 1000, 95, 5, 0.10, 0.05, 18, 15, 16, 17, 18),
        new Vendor("B업체", 4000,  800, 90, 7, 0.15, 0.06, 16, 18, 14, 16, 15),
        new Vendor("C업체", 4500, 1200,100, 4, 0.12, 0.04, 14, 17, 18, 18, 17)
    };

    int totalAvailable = 0;
    for (Vendor v : vendors) {
        totalAvailable += (v.maxCapacity + v.currentStock);
    }

    Plan bestPlan = null;
    List<Plan> finalPopulation = null;
    String errorMsg = null;

    if ("Y".equals(run)) {
        if (totalDemand > totalAvailable) {
            errorMsg = "총 주문량이 전체 공급 가능량보다 큽니다. 주문량을 줄여 주세요.";
        } else {
            List<Plan> population = new ArrayList<Plan>();

            for (int i = 0; i < populationSize; i++) {
                Plan p = createRandomPlan(vendors, totalDemand);
                evaluatePlan(p, vendors, model);
                population.add(p);
            }

            sortPopulation(population, model);

            for (int gen = 0; gen < generations; gen++) {
                List<Plan> newPopulation = new ArrayList<Plan>();

                newPopulation.add(population.get(0).copy());
                if (population.size() > 1) newPopulation.add(population.get(1).copy());

                while (newPopulation.size() < populationSize) {
                    Plan parent1 = tournamentSelect(population, model);
                    Plan parent2 = tournamentSelect(population, model);

                    Plan child = crossover(parent1, parent2, vendors, totalDemand);
                    mutate(child, vendors, totalDemand, mutationRate);
                    evaluatePlan(child, vendors, model);
                    newPopulation.add(child);
                }

                sortPopulation(newPopulation, model);
                population = newPopulation;
            }

            sortPopulation(population, model);
            bestPlan = population.get(0);
            finalPopulation = population;
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>유전알고리즘 기반 생산최적화 JSP</title>
<style>
    body {
        font-family: Arial, "맑은 고딕", sans-serif;
        margin: 30px;
        background: #f7f9fc;
        color: #222;
    }
    .container {
        max-width: 1150px;
        margin: auto;
        background: white;
        padding: 24px;
        border-radius: 12px;
        box-shadow: 0 3px 10px rgba(0,0,0,0.08);
    }
    h1, h2, h3 {
        color: #1f3c88;
        margin-top: 28px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin-top: 12px;
    }
    th, td {
        border: 1px solid #d9e2f0;
        padding: 10px;
        text-align: center;
        vertical-align: middle;
    }
    th {
        background: #eaf1ff;
    }
    .form-box {
        background: #f3f7ff;
        padding: 18px;
        border-radius: 10px;
        margin-bottom: 20px;
    }
    .row {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
    }
    .field {
        flex: 1;
        min-width: 180px;
    }
    input, select {
        width: 100%;
        padding: 8px;
        margin-top: 4px;
        border: 1px solid #c8d3e6;
        border-radius: 6px;
        box-sizing: border-box;
    }
    .btn {
        background: #2d6cdf;
        color: white;
        border: none;
        padding: 10px 18px;
        border-radius: 8px;
        cursor: pointer;
        margin-top: 12px;
        font-size: 15px;
    }
    .btn:hover {
        background: #1f57ba;
    }
    .error {
        color: #c62828;
        font-weight: bold;
        margin-top: 10px;
    }
    .good {
        color: #1565c0;
        font-weight: bold;
    }
    .note {
        background: #fff9e8;
        border: 1px solid #ffe08a;
        padding: 12px;
        border-radius: 8px;
        margin-top: 15px;
        line-height: 1.7;
    }
    .guide-box {
        background: #f6fbff;
        border: 1px solid #cfe3ff;
        padding: 16px;
        border-radius: 10px;
        margin-top: 18px;
        line-height: 1.8;
    }
    .legend-table td {
        text-align: left;
        padding-left: 14px;
    }
    .small {
        font-size: 14px;
        color: #555;
    }
</style>
</head>
<body>
<div class="container">
    <h1>유전알고리즘 기반 생산최적화 JSP 예제</h1>
    <p>
        총 주문량을 A/B/C 업체에 어떻게 배분할지 유전알고리즘으로 탐색하는 예제입니다.
        점수 기반 모델 또는 비용 최소화 모델을 선택할 수 있습니다.
    </p>

    <div class="form-box">
        <form method="post">
            <input type="hidden" name="run" value="Y">

            <div class="row">
                <div class="field">
                    <label>총 주문량</label>
                    <input type="number" name="totalDemand" value="<%= totalDemand %>">
                </div>
                <div class="field">
                    <label>세대 수</label>
                    <input type="number" name="generations" value="<%= generations %>">
                </div>
                <div class="field">
                    <label>개체군 크기</label>
                    <input type="number" name="populationSize" value="<%= populationSize %>">
                </div>
                <div class="field">
                    <label>돌연변이율</label>
                    <input type="text" name="mutationRate" value="<%= mutationRate %>">
                </div>
                <div class="field">
                    <label>평가 모델</label>
                    <select name="model">
                        <option value="score" <%= "score".equals(model) ? "selected" : "" %>>점수 기반 모델</option>
                        <option value="cost" <%= "cost".equals(model) ? "selected" : "" %>>비용 최소화 모델</option>
                    </select>
                </div>
            </div>

            <button type="submit" class="btn">최적 생산계획 찾기</button>
        </form>

        <% if (errorMsg != null) { %>
            <div class="error"><%= errorMsg %></div>
        <% } %>
    </div>

    <h2>업체 정보</h2>
    <table>
        <tr>
            <th>업체</th>
            <th>최대생산량</th>
            <th>현재재고</th>
            <th>단가</th>
            <th>운송비</th>
            <th>납기위험</th>
            <th>불량위험</th>
            <th>업체총점</th>
        </tr>
        <% for (Vendor v : vendors) { %>
        <tr>
            <td><%= v.name %></td>
            <td><%= v.maxCapacity %></td>
            <td><%= v.currentStock %></td>
            <td><%= v.unitCost %></td>
            <td><%= v.transportCost %></td>
            <td><%= v.delayRisk %></td>
            <td><%= v.defectRisk %></td>
            <td><%= v.totalVendorScore() %></td>
        </tr>
        <% } %>
    </table>

    <% if (bestPlan != null) { %>
        <h2>최적 생산계획 결과</h2>
        <table>
            <tr>
                <th>업체</th>
                <th>배분량</th>
                <th>배분비율</th>
            </tr>
            <% for (int i = 0; i < vendors.length; i++) { %>
            <tr>
                <td><%= vendors[i].name %></td>
                <td><%= bestPlan.qty[i] %></td>
                <td><%= String.format("%.2f", bestPlan.qty[i] * 100.0 / bestPlan.sum()) %>%</td>
            </tr>
            <% } %>
            <tr>
                <th>합계</th>
                <th colspan="2"><%= bestPlan.sum() %></th>
            </tr>
        </table>

        <h3>평가 결과</h3>
        <table>
            <tr>
                <th>업체가중평균점수</th>
                <th>분산점수</th>
                <th>비용점수</th>
                <th>납기점수</th>
                <th>재고점수</th>
                <th>Fitness</th>
                <th>목적함수(총비용형)</th>
            </tr>
            <tr>
                <td><%= String.format("%.2f", bestPlan.vendorWeightedScore) %></td>
                <td><%= bestPlan.diversificationScore %></td>
                <td><%= bestPlan.planCostScore %></td>
                <td><%= bestPlan.deliveryScore %></td>
                <td><%= bestPlan.inventoryScore %></td>
                <td class="good"><%= String.format("%.6f", bestPlan.fitness) %></td>
                <td><%= String.format("%.2f", bestPlan.objectiveCost) %></td>
            </tr>
        </table>

        <div class="note">
            <b>해석 방법</b><br>
            - 점수 기반 모델: Fitness가 <b>클수록</b> 좋은 생산계획입니다.<br>
            - 비용 최소화 모델: 목적함수 값이 <b>작을수록</b> 좋은 생산계획입니다.<br>
            - 점수 기반 모델에서는 업체가중평균점수, 분산점수, 비용점수, 납기점수, 재고점수를 더해 적합도를 계산합니다.
        </div>

        <h3>최종 세대 상위 5개 계획</h3>
        <table>
            <tr>
                <th>순위</th>
                <th>A업체</th>
                <th>B업체</th>
                <th>C업체</th>
                <th>Fitness</th>
                <th>목적함수</th>
            </tr>
            <%
                int topN = Math.min(5, finalPopulation.size());
                for (int i = 0; i < topN; i++) {
                    Plan p = finalPopulation.get(i);
            %>
            <tr>
                <td><%= (i + 1) %></td>
                <td><%= p.qty[0] %></td>
                <td><%= p.qty[1] %></td>
                <td><%= p.qty[2] %></td>
                <td><%= String.format("%.6f", p.fitness) %></td>
                <td><%= String.format("%.2f", p.objectiveCost) %></td>
            </tr>
            <% } %>
        </table>
    <% } %>

    <h2>유전알고리즘 설정값 설명 (범례)</h2>
    <table class="legend-table">
        <tr>
            <th style="width:18%;">설정 항목</th>
            <th style="width:28%;">의미</th>
            <th style="width:34%;">쉽게 설명</th>
            <th style="width:20%;">예시</th>
        </tr>
        <tr>
            <td><b>총 주문량</b></td>
            <td>원청기업이 생산해야 하는 총 제품 수</td>
            <td>AI가 이 수량을 여러 업체에 나누어 생산하도록 계획을 만듭니다.</td>
            <td>10000 → A/B/C 업체에 분배</td>
        </tr>
        <tr>
            <td><b>세대 수</b></td>
            <td>유전알고리즘이 반복되는 횟수</td>
            <td>AI가 생산계획을 몇 번 진화시키며 더 좋은 해를 찾을지 결정합니다.</td>
            <td>102 → 102번 반복 개선</td>
        </tr>
        <tr>
            <td><b>개체군 크기</b></td>
            <td>한 세대에서 동시에 비교되는 생산계획 수</td>
            <td>AI가 한 번에 몇 개의 생산계획을 만들어 경쟁시킬지 결정합니다.</td>
            <td>32 → 32개의 계획 평가</td>
        </tr>
        <tr>
            <td><b>돌연변이율</b></td>
            <td>생산계획을 랜덤하게 변경할 확률</td>
            <td>너무 비슷한 해만 반복되지 않도록 일부 계획을 무작위로 바꾸는 비율입니다.</td>
            <td>0.15 → 15% 확률 변경</td>
        </tr>
        <tr>
            <td><b>평가 모델</b></td>
            <td>생산계획을 평가하는 기준</td>
            <td>점수 기반 또는 비용 최소화 방식 중 어떤 방식으로 최적해를 찾을지 결정합니다.</td>
            <td>점수 기반 모델</td>
        </tr>
    </table>

    <h2>평가 결과 항목 설명 (범례)</h2>
    <table class="legend-table">
        <tr>
            <th style="width:20%;">항목</th>
            <th style="width:30%;">의미</th>
            <th style="width:50%;">직관적 설명</th>
        </tr>
        <tr>
            <td><b>업체가중평균점수</b></td>
            <td>업체별 점수에 물량 비율을 반영한 평균 점수</td>
            <td>좋은 업체에 더 많은 물량을 배정하면 높아집니다.</td>
        </tr>
        <tr>
            <td><b>분산점수</b></td>
            <td>생산 물량이 여러 업체에 균형 있게 배분되었는지 평가</td>
            <td>한 업체에 몰리지 않고 적절히 나누어 생산하면 높아집니다.</td>
        </tr>
        <tr>
            <td><b>비용점수</b></td>
            <td>전체 생산계획의 비용 효율성 평가</td>
            <td>생산비와 운송비가 상대적으로 낮으면 높은 점수를 받습니다.</td>
        </tr>
        <tr>
            <td><b>납기점수</b></td>
            <td>정해진 일정 안에 납품할 가능성 평가</td>
            <td>납기 지연 위험이 낮고 생산 속도가 충분하면 높아집니다.</td>
        </tr>
        <tr>
            <td><b>재고점수</b></td>
            <td>재고 부족이나 공급 중단 위험을 평가</td>
            <td>현재 재고와 생산능력이 안정적이면 높은 점수를 받습니다.</td>
        </tr>
        <tr>
            <td><b>Fitness</b></td>
            <td>유전알고리즘이 해의 우수성을 판단하는 핵심 값</td>
            <td>점수 기반 모델에서는 클수록 좋고, 비용 최소화 모델에서는 보조지표로 사용됩니다.</td>
        </tr>
        <tr>
            <td><b>목적함수</b></td>
            <td>총생산비용, 운송비, 재고비용, 패널티 등을 합한 값</td>
            <td>비용 최소화 모델에서 가장 중요한 값이며, 작을수록 좋은 계획입니다.</td>
        </tr>
    </table>

    <div class="guide-box">
        <b>유전알고리즘 동작 원리</b><br><br>
        1. 여러 개의 생산계획을 랜덤으로 생성합니다.<br>
        2. 각 생산계획의 점수(Fitness) 또는 총비용을 계산합니다.<br>
        3. 좋은 계획을 선택합니다.<br>
        4. 선택된 계획을 서로 섞어 새로운 계획을 만듭니다.<br>
        5. 일부 계획은 랜덤하게 조금 바꿉니다. 이것이 돌연변이입니다.<br>
        6. 이 과정을 여러 세대 반복하여 더 좋은 생산계획을 찾습니다.
    </div>

    <div class="guide-box">
        <b>쉽게 이해하는 방법</b><br><br>
        유전알고리즘은 한 번에 정답을 맞히는 방식이 아니라,<br>
        여러 생산계획을 만들어 놓고 그중 좋은 계획만 남기면서 점점 더 나은 계획으로 발전시키는 방법입니다.<br>
        즉, <b>“여러 계획을 경쟁시키며 가장 좋은 생산 배분안을 찾는 과정”</b>이라고 이해하면 됩니다.
    </div>

    <h2>알고리즘 흐름</h2>
    <ol class="small">
        <li>랜덤하게 여러 생산계획을 생성합니다.</li>
        <li>각 생산계획의 적합도(Fitness) 또는 총비용을 계산합니다.</li>
        <li>좋은 계획을 선택합니다.</li>
        <li>교차(Crossover)와 돌연변이(Mutation)로 새 계획을 생성합니다.</li>
        <li>세대를 반복하면서 더 좋은 생산계획을 찾습니다.</li>
    </ol>

    <h2>참고</h2>
    <p class="small">
        이 예제는 수업 및 실습용으로 JSP 한 파일에 작성했습니다.<br>
        실제 서비스에서는 유전알고리즘 로직을 Servlet, Service, DAO로 분리하는 것이 좋습니다.
    </p>
</div>
</body>
</html>