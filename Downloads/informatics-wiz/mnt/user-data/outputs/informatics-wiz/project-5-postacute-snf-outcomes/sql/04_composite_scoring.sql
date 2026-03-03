-- ============================================================
-- Project 5: Post-Acute Care & SNF Outcomes Analysis
-- Script 04: Composite Quality Scoring + Facility Tiers
-- ============================================================

USE snf_outcomes;

-- ------------------------------------------------------------
-- COMPOSITE QUALITY SCORE
-- Dimensions: readmission (30%), clinical (25%), staffing (25%), compliance (20%)
-- Higher score = BETTER facility quality (inverted from risk projects)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_quality_scores AS
WITH bounds AS (
    SELECT
        MIN(readmission_rate_30d)   AS min_read,  MAX(readmission_rate_30d)   AS max_read,
        MIN(hospital_transfer_rate) AS min_htx,   MAX(hospital_transfer_rate) AS max_htx,
        MIN(pressure_ulcer_rate)    AS min_pu,    MAX(pressure_ulcer_rate)    AS max_pu,
        MIN(fall_injury_rate)       AS min_fall,  MAX(fall_injury_rate)       AS max_fall,
        MIN(pain_management_rate)   AS min_pain,  MAX(pain_management_rate)   AS max_pain,
        MIN(rn_hours_per_resident)  AS min_rn,    MAX(rn_hours_per_resident)  AS max_rn,
        MIN(cna_hours_per_resident) AS min_cna,   MAX(cna_hours_per_resident) AS max_cna,
        MIN(health_deficiency_count) AS min_def,  MAX(health_deficiency_count) AS max_def
    FROM quality_measures qm
    JOIN facilities f ON qm.cms_certification_number = f.cms_certification_number
    WHERE qm.report_quarter = (SELECT MAX(report_quarter) FROM quality_measures)
),

normalized AS (
    SELECT
        f.cms_certification_number,
        f.facility_name,
        f.state,
        f.ownership_type,
        f.certified_beds,
        f.urban_rural,
        qm.report_quarter,

        -- Readmission domain (inverted — lower rate = better score)
        ROUND(((b.max_read - qm.readmission_rate_30d) / NULLIF(b.max_read - b.min_read, 0) * 10 +
               (b.max_htx - qm.hospital_transfer_rate) / NULLIF(b.max_htx - b.min_htx, 0) * 10) / 2, 2)
            AS score_readmission,

        -- Clinical quality domain (inverted — lower bad outcome rate = better)
        ROUND(((b.max_pu - qm.pressure_ulcer_rate) / NULLIF(b.max_pu - b.min_pu, 0) * 10 +
               (b.max_fall - qm.fall_injury_rate) / NULLIF(b.max_fall - b.min_fall, 0) * 10 +
               (qm.pain_management_rate - b.min_pain) / NULLIF(b.max_pain - b.min_pain, 0) * 10) / 3, 2)
            AS score_clinical,

        -- Staffing domain (higher hours = better score)
        ROUND(((qm.rn_hours_per_resident - b.min_rn) / NULLIF(b.max_rn - b.min_rn, 0) * 10 +
               (qm.cna_hours_per_resident - b.min_cna) / NULLIF(b.max_cna - b.min_cna, 0) * 10) / 2, 2)
            AS score_staffing,

        -- Compliance domain (inverted — fewer deficiencies = better)
        ROUND((b.max_def - qm.health_deficiency_count) / NULLIF(b.max_def - b.min_def, 0) * 10, 2)
            AS score_compliance,

        -- Raw metrics for tooltips
        qm.readmission_rate_30d, qm.rn_hours_per_resident,
        qm.cna_hours_per_resident, qm.health_deficiency_count,
        qm.pressure_ulcer_rate, qm.fall_injury_rate

    FROM quality_measures qm
    JOIN facilities f ON qm.cms_certification_number = f.cms_certification_number
    CROSS JOIN bounds b
    WHERE qm.report_quarter = (SELECT MAX(report_quarter) FROM quality_measures)
)
SELECT
    *,
    ROUND(
        score_readmission * 0.30 +
        score_clinical    * 0.25 +
        score_staffing    * 0.25 +
        score_compliance  * 0.20
    , 2) * 10 AS composite_quality_score,

    CASE
        WHEN ROUND(score_readmission*0.30+score_clinical*0.25+score_staffing*0.25+score_compliance*0.20,2)*10 >= 75
            THEN 'Excellent'
        WHEN ROUND(score_readmission*0.30+score_clinical*0.25+score_staffing*0.25+score_compliance*0.20,2)*10 >= 55
            THEN 'Good'
        WHEN ROUND(score_readmission*0.30+score_clinical*0.25+score_staffing*0.25+score_compliance*0.20,2)*10 >= 35
            THEN 'Fair'
        ELSE 'Poor'
    END AS quality_tier,

    RANK() OVER (ORDER BY ROUND(score_readmission*0.30+score_clinical*0.25+score_staffing*0.25+score_compliance*0.20,2)*10 DESC)
        AS national_rank,

    RANK() OVER (PARTITION BY state ORDER BY ROUND(score_readmission*0.30+score_clinical*0.25+score_staffing*0.25+score_compliance*0.20,2)*10 DESC)
        AS state_rank

FROM normalized;

-- ============================================================
-- Script 05: Staffing-Outcome Correlation Analysis
-- ============================================================

-- ------------------------------------------------------------
-- Does more RN staffing = lower readmission rates?
-- Bin facilities by staffing quartile and compare readmissions
-- ------------------------------------------------------------
WITH staffing_quartiles AS (
    SELECT
        cms_certification_number,
        facility_name,
        state,
        rn_hours_per_resident,
        readmission_rate_30d,
        composite_quality_score,
        NTILE(4) OVER (ORDER BY rn_hours_per_resident ASC) AS rn_staffing_quartile
    FROM vw_quality_scores
)
SELECT
    rn_staffing_quartile,
    CASE rn_staffing_quartile
        WHEN 1 THEN 'Q1 — Lowest Staffing'
        WHEN 2 THEN 'Q2 — Below Average'
        WHEN 3 THEN 'Q3 — Above Average'
        WHEN 4 THEN 'Q4 — Highest Staffing'
    END                                                     AS staffing_tier_label,
    COUNT(*)                                                AS facility_count,
    ROUND(AVG(rn_hours_per_resident), 2)                   AS avg_rn_hours,
    ROUND(AVG(readmission_rate_30d), 2)                    AS avg_readmission_rate,
    ROUND(AVG(composite_quality_score), 1)                 AS avg_quality_score,
    -- Readmission gap vs. Q4 (highest staffing)
    ROUND(AVG(readmission_rate_30d) - (
        SELECT AVG(readmission_rate_30d) FROM staffing_quartiles WHERE rn_staffing_quartile = 4
    ), 2)                                                   AS readmission_gap_vs_best_staffed
FROM staffing_quartiles
GROUP BY rn_staffing_quartile
ORDER BY rn_staffing_quartile;

-- ============================================================
-- Script 06: Trend Analysis — Improving vs. Declining Facilities
-- ============================================================

-- Classify facilities by their 8-quarter trajectory
WITH quarterly_scores AS (
    SELECT
        f.cms_certification_number,
        f.facility_name,
        f.state,
        qm.report_quarter,
        qm.readmission_rate_30d,
        ROW_NUMBER() OVER (PARTITION BY f.cms_certification_number ORDER BY qm.report_quarter) AS quarter_num
    FROM quality_measures qm
    JOIN facilities f ON qm.cms_certification_number = f.cms_certification_number
),
first_last AS (
    SELECT
        cms_certification_number,
        facility_name,
        state,
        MAX(CASE WHEN quarter_num = 1 THEN readmission_rate_30d END) AS first_quarter_rate,
        MAX(CASE WHEN quarter_num = 8 THEN readmission_rate_30d END) AS latest_quarter_rate
    FROM quarterly_scores
    WHERE quarter_num IN (1, 8)
    GROUP BY cms_certification_number, facility_name, state
)
SELECT
    cms_certification_number,
    facility_name,
    state,
    ROUND(first_quarter_rate, 2)                                    AS first_quarter_readmission,
    ROUND(latest_quarter_rate, 2)                                   AS latest_quarter_readmission,
    ROUND(latest_quarter_rate - first_quarter_rate, 2)             AS rate_change,
    ROUND((latest_quarter_rate - first_quarter_rate) / NULLIF(first_quarter_rate, 0) * 100, 1)
                                                                    AS pct_change,
    CASE
        WHEN (latest_quarter_rate - first_quarter_rate) <= -3 THEN 'Rising Star'
        WHEN (latest_quarter_rate - first_quarter_rate) <= -1 THEN 'Improving'
        WHEN (latest_quarter_rate - first_quarter_rate) <= 1  THEN 'Stable'
        WHEN (latest_quarter_rate - first_quarter_rate) <= 3  THEN 'Declining'
        ELSE 'At Risk'
    END                                                             AS trajectory_segment
FROM first_last
ORDER BY rate_change ASC;
