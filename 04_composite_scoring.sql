-- ============================================================
-- Project 1: Illinois Maternal Health ZIP Code Scorecard
-- Script 04: Composite Scoring Model
-- Min-max normalization + weighted index
-- ============================================================

USE il_maternal_health;

-- ------------------------------------------------------------
-- STEP 1: Capture min/max values across all ZIPs for normalization
-- Higher raw value = worse outcome for all metrics EXCEPT provider density
-- For provider density: lower density = worse outcome (invert score)
-- ------------------------------------------------------------
WITH raw_metrics AS (
    SELECT
        zip_code,
        community_name,
        region_type,
        maternal_mortality_rate,
        preterm_birth_rate,
        late_no_prenatal_pct,
        low_birthweight_rate,
        csection_rate,
        obgyn_per_10k_women
    FROM vw_5yr_aggregate
),

-- STEP 2: Calculate min and max across the cohort for each metric
metric_bounds AS (
    SELECT
        MIN(maternal_mortality_rate)  AS min_mmr,  MAX(maternal_mortality_rate)  AS max_mmr,
        MIN(preterm_birth_rate)       AS min_ptr,  MAX(preterm_birth_rate)       AS max_ptr,
        MIN(late_no_prenatal_pct)     AS min_pnc,  MAX(late_no_prenatal_pct)     AS max_pnc,
        MIN(low_birthweight_rate)     AS min_lbw,  MAX(low_birthweight_rate)     AS max_lbw,
        MIN(csection_rate)            AS min_csc,  MAX(csection_rate)            AS max_csc,
        MIN(obgyn_per_10k_women)      AS min_den,  MAX(obgyn_per_10k_women)      AS max_den
    FROM raw_metrics
),

-- STEP 3: Normalize each metric to 0–10 scale
-- Higher score always = worse outcome
normalized AS (
    SELECT
        r.zip_code,
        r.community_name,
        r.region_type,
        r.maternal_mortality_rate,
        r.preterm_birth_rate,
        r.late_no_prenatal_pct,
        r.low_birthweight_rate,
        r.csection_rate,
        r.obgyn_per_10k_women,

        -- Standard normalization (higher raw = higher risk score)
        ROUND(CASE WHEN b.max_mmr = b.min_mmr THEN 0
              ELSE (r.maternal_mortality_rate - b.min_mmr) / (b.max_mmr - b.min_mmr) * 10 END, 2)
            AS score_mortality,

        ROUND(CASE WHEN b.max_ptr = b.min_ptr THEN 0
              ELSE (r.preterm_birth_rate - b.min_ptr) / (b.max_ptr - b.min_ptr) * 10 END, 2)
            AS score_preterm,

        ROUND(CASE WHEN b.max_pnc = b.min_pnc THEN 0
              ELSE (r.late_no_prenatal_pct - b.min_pnc) / (b.max_pnc - b.min_pnc) * 10 END, 2)
            AS score_prenatal_care,

        ROUND(CASE WHEN b.max_lbw = b.min_lbw THEN 0
              ELSE (r.low_birthweight_rate - b.min_lbw) / (b.max_lbw - b.min_lbw) * 10 END, 2)
            AS score_low_birthweight,

        ROUND(CASE WHEN b.max_csc = b.min_csc THEN 0
              ELSE (r.csection_rate - b.min_csc) / (b.max_csc - b.min_csc) * 10 END, 2)
            AS score_csection,

        -- INVERTED normalization: lower density = higher risk
        ROUND(CASE WHEN b.max_den = b.min_den THEN 0
              ELSE (b.max_den - r.obgyn_per_10k_women) / (b.max_den - b.min_den) * 10 END, 2)
            AS score_provider_density

    FROM raw_metrics r
    CROSS JOIN metric_bounds b
),

-- STEP 4: Apply weights and calculate composite score
-- Weights: mortality 25%, preterm 20%, prenatal 20%, LBW 15%, c-section 10%, density 10%
scored AS (
    SELECT
        zip_code,
        community_name,
        region_type,
        maternal_mortality_rate,
        preterm_birth_rate,
        late_no_prenatal_pct,
        low_birthweight_rate,
        csection_rate,
        obgyn_per_10k_women,
        score_mortality,
        score_preterm,
        score_prenatal_care,
        score_low_birthweight,
        score_csection,
        score_provider_density,
        ROUND(
            (score_mortality        * 0.25) +
            (score_preterm          * 0.20) +
            (score_prenatal_care    * 0.20) +
            (score_low_birthweight  * 0.15) +
            (score_csection         * 0.10) +
            (score_provider_density * 0.10)
        , 2) * 10 AS composite_score
    FROM normalized
)

-- STEP 5: Final ranked scorecard
SELECT
    RANK() OVER (ORDER BY composite_score DESC)  AS vulnerability_rank,
    zip_code,
    community_name,
    region_type,
    composite_score,
    CASE
        WHEN composite_score >= 70 THEN 'Critical'
        WHEN composite_score >= 50 THEN 'High'
        WHEN composite_score >= 30 THEN 'Moderate'
        ELSE 'Low'
    END                                          AS risk_tier,
    score_mortality,
    score_preterm,
    score_prenatal_care,
    score_low_birthweight,
    score_csection,
    score_provider_density
FROM scored
ORDER BY composite_score DESC;
