-- ============================================================
-- Project 4: Multi-Source Operational Analytics
-- Script 03: KPI Calculations — Earned Value & Productivity
-- ============================================================

USE operational_analytics;

-- ------------------------------------------------------------
-- EARNED VALUE METRICS per workstream per week
-- EV methodology: industry-standard project performance measurement
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_earned_value AS
SELECT
    w.workstream_id,
    w.workstream_name,
    p.report_week,
    p.report_date,

    -- Core earned value metrics
    p.planned_value          AS pv,         -- Budgeted cost of scheduled work
    p.earned_value           AS ev,         -- Budgeted cost of work performed
    p.actual_cost            AS ac,         -- Actual cost incurred

    -- Variance indicators
    ROUND(p.earned_value - p.actual_cost, 2)    AS cost_variance,       -- CV: positive = under budget
    ROUND(p.earned_value - p.planned_value, 2)  AS schedule_variance,   -- SV: positive = ahead of schedule

    -- Performance indexes (1.0 = on plan, > 1.0 = better than plan)
    ROUND(p.earned_value / NULLIF(p.actual_cost, 0), 3)    AS cpi,      -- Cost Performance Index
    ROUND(p.earned_value / NULLIF(p.planned_value, 0), 3)  AS spi,      -- Schedule Performance Index

    -- % Complete (actual vs. planned)
    p.pct_complete_actual,
    p.pct_complete_planned,
    ROUND(p.pct_complete_actual - p.pct_complete_planned, 2) AS pct_complete_variance,

    -- Estimate at Completion (EAC): projected total cost at current CPI
    ROUND(p.budget_at_completion / NULLIF(p.earned_value / p.actual_cost, 0), 2) AS eac,
    p.budget_at_completion     AS bac,
    ROUND(p.budget_at_completion - (p.budget_at_completion / NULLIF(p.earned_value / p.actual_cost, 0)), 2)
                                AS variance_at_completion   -- Positive = projected to finish under budget

FROM weekly_performance p
JOIN workstreams w ON p.workstream_id = w.workstream_id;

-- ============================================================
-- Script 04: Variance Analysis & Risk Flagging
-- ============================================================

-- ------------------------------------------------------------
-- WEEK-OVER-WEEK VARIANCE TREND using LAG()
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_variance_trend AS
SELECT
    workstream_id,
    workstream_name,
    report_week,
    cpi,
    spi,
    cost_variance,
    schedule_variance,
    pct_complete_actual,
    pct_complete_planned,
    pct_complete_variance,

    -- WoW change in cost variance
    ROUND(cost_variance - LAG(cost_variance, 1)
        OVER (PARTITION BY workstream_id ORDER BY report_week), 2) AS cv_wow_change,

    -- 4-week moving average CPI (smooths weekly noise)
    ROUND(AVG(cpi) OVER (
        PARTITION BY workstream_id
        ORDER BY report_week
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 3) AS cpi_4wk_avg,

    -- Running cumulative actual cost
    SUM(ac) OVER (
        PARTITION BY workstream_id
        ORDER BY report_week
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_actual_cost

FROM vw_earned_value;

-- ------------------------------------------------------------
-- AUTOMATED RISK FLAG GENERATION
-- Rule-based flagging for executive dashboard and report
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_risk_flags AS
WITH latest_week AS (
    SELECT workstream_id, MAX(report_week) AS latest_week
    FROM weekly_performance
    GROUP BY workstream_id
),
current_performance AS (
    SELECT ev.*
    FROM vw_earned_value ev
    JOIN latest_week lw ON ev.workstream_id = lw.workstream_id
                       AND ev.report_week = lw.latest_week
)
SELECT
    workstream_id,
    workstream_name,
    report_week,
    cpi,
    spi,
    pct_complete_variance,
    eac,
    bac,

    -- Cost risk flag
    CASE
        WHEN cpi < 0.85 THEN '🔴 CRITICAL — CPI below 0.85, significant cost overrun'
        WHEN cpi < 0.95 THEN '🟠 HIGH — CPI below 0.95, cost tracking above plan'
        WHEN cpi > 1.10 THEN '🟡 WATCH — CPI unusually high, verify scope not reduced'
        ELSE '🟢 ON TRACK'
    END AS cost_risk_flag,

    -- Schedule risk flag
    CASE
        WHEN spi < 0.85 THEN '🔴 CRITICAL — SPI below 0.85, major schedule delay'
        WHEN spi < 0.95 THEN '🟠 HIGH — SPI below 0.95, schedule slipping'
        ELSE '🟢 ON TRACK'
    END AS schedule_risk_flag,

    -- Completion variance flag
    CASE
        WHEN pct_complete_variance < -10 THEN '🔴 CRITICAL — 10+ points behind planned completion'
        WHEN pct_complete_variance < -5  THEN '🟠 HIGH — 5-10 points behind plan'
        WHEN pct_complete_variance < -2  THEN '🟡 WATCH — Slightly behind plan'
        ELSE '🟢 ON TRACK'
    END AS completion_risk_flag,

    -- Budget exposure
    ROUND(eac - bac, 2)  AS projected_overrun,
    CASE
        WHEN (eac - bac) / NULLIF(bac, 0) > 0.10 THEN '🔴 >10% projected budget overrun'
        WHEN (eac - bac) / NULLIF(bac, 0) > 0.05 THEN '🟠 5-10% projected budget overrun'
        WHEN (eac - bac) / NULLIF(bac, 0) > 0     THEN '🟡 <5% projected budget overrun'
        ELSE '🟢 Projected to finish under budget'
    END AS budget_exposure_flag

FROM current_performance
ORDER BY cpi ASC;  -- Worst performers first

-- ------------------------------------------------------------
-- PROGRAM HEALTH SUMMARY — Single-row executive snapshot
-- ------------------------------------------------------------
SELECT
    SUM(ac)                                                             AS total_actual_cost_to_date,
    SUM(bac)                                                            AS total_program_budget,
    ROUND(SUM(ac) / SUM(bac) * 100, 1)                                 AS pct_budget_consumed,
    ROUND(AVG(pct_complete_actual), 1)                                  AS avg_pct_complete,
    ROUND(AVG(pct_complete_planned), 1)                                 AS avg_pct_complete_planned,
    ROUND(AVG(cpi), 3)                                                  AS program_cpi,
    ROUND(AVG(spi), 3)                                                  AS program_spi,
    COUNT(CASE WHEN cpi < 0.95 THEN 1 END)                             AS workstreams_over_budget,
    COUNT(CASE WHEN spi < 0.95 THEN 1 END)                             AS workstreams_behind_schedule,
    ROUND(SUM(eac) - SUM(bac), 2)                                      AS total_projected_overrun
FROM (
    SELECT ev.*, ev.eac, ev.bac, ev.ac
    FROM vw_earned_value ev
    JOIN (SELECT workstream_id, MAX(report_week) AS latest_week FROM weekly_performance GROUP BY workstream_id) lw
      ON ev.workstream_id = lw.workstream_id AND ev.report_week = lw.latest_week
) latest;
