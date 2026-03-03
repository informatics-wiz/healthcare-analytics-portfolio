# Illinois Maternal Health ZIP Code Scorecard
## Epidemiological Findings Report
**Author:** informatics-wiz | **Data Period:** 2019–2023 | **Published:** 2024

---

## Executive Summary

Analysis of maternal and infant health outcomes across six Illinois ZIP codes reveals stark geographic disparities driven by structural inequities in provider access and economic conditions. Urban Chicago ZIP codes 60621 (Englewood) and 60644 (Austin) carry the highest composite vulnerability scores (78 and 74 of 100, respectively), while Oak Park (60302) scores 22 — representing a 56-point disparity within the same metropolitan area.

Three key findings drive intervention priorities:

1. **Provider access deserts** in rural Illinois are as harmful as urban poverty — Mill Shoals (62863) has zero OB/GYN providers per 10,000 reproductive-age women
2. **Late/no prenatal care** is the most modifiable risk factor, showing consistent improvement opportunity across all high-risk ZIPs
3. **Preterm birth and low birthweight rates** in high-risk ZIPs exceed state averages by 40–60%, with disproportionate impact on Black maternal health in Englewood and Austin

---

## Methodology

### Data Sources
- **IDPH Vital Statistics**: Annual birth and maternal outcome counts at ZIP level (2019–2023)
- **CDC WONDER**: County-level maternal mortality rates (allocated to ZIP by birth proportion)
- **CMS Provider of Services**: OB/GYN provider count and reproductive-age women population by ZIP

### Scoring Approach
Six metrics were normalized using min-max scaling (0–10 per metric, higher = worse outcomes) and weighted into a composite vulnerability score (0–100). Provider density was inverted so lower access = higher risk score. Five-year aggregate rates (2019–2023) were used to stabilize small-number suppression in rural ZIPs.

---

## Findings by Metric

### 1. Maternal Mortality Rate
The highest maternal mortality rates occurred in Englewood and Austin, where limited provider access and high poverty rates compound clinical risk factors. Mill Shoals, despite small population, recorded the highest per-capita rate in the cohort due to a single death against a small birth denominator — illustrating the statistical instability that makes rural maternal mortality particularly difficult to measure.

### 2. Preterm Birth Rate
Preterm birth rates in Englewood (17.2%) and Austin (16.4%) significantly exceed the Illinois state average of approximately 10.5%. Oak Park (8.0%) sits below the state average. The rural-urban divide is less pronounced for preterm birth than for prenatal care access, suggesting preterm birth is more strongly associated with socioeconomic factors than geography alone.

### 3. Late or No Prenatal Care
This metric shows the starkest rural-urban split. Mill Shoals (37.2% late/no entry) and Carbondale (19.8%) significantly outpace urban high-risk ZIPs for this metric, suggesting transportation and provider availability — not patient hesitancy — as the primary barrier. This is a highly modifiable risk factor with clear intervention pathways.

### 4. Low Birthweight Rate
Low birthweight rates mirror preterm birth patterns, with Englewood and Austin showing rates of 18.4% and 16.7% respectively — nearly double the Oak Park rate of 5.8%. Low birthweight is a strong predictor of infant mortality and long-term developmental outcomes, making this metric central to any maternal health equity strategy.

### 5. Provider Density
The most dramatic finding. Mill Shoals has **zero OB/GYN providers** within ZIP boundaries, with the nearest provider in Carmi (15+ miles). Rock Island shows the best rural density at 0.9 providers per 10,000 women — still below the commonly cited threshold of 2.0 needed for basic access. Oak Park has 19.8 providers per 10,000, illustrating the extreme inequity in distribution.

---

## ZIP Code Scorecard Summary

| ZIP | Community | Type | Composite Score | Risk Tier | Primary Driver |
|-----|-----------|------|-----------------|-----------|----------------|
| 60621 | Englewood | Urban | 78 | 🔴 Critical | Maternal mortality + LBW |
| 60644 | Austin | Urban | 74 | 🔴 Critical | Preterm + LBW |
| 61201 | Rock Island | Rural | 52 | 🟠 High | Prenatal access |
| 62901 | Carbondale | Rural | 48 | 🟡 Moderate | Prenatal access |
| 62863 | Mill Shoals | Rural | 61 | 🟠 High | Provider density |
| 60302 | Oak Park | Suburban | 22 | 🟢 Low | — |

---

## Recommendations

**For Critical-tier ZIPs (Englewood, Austin):**
- Expand federally qualified health center (FQHC) OB/GYN capacity
- Implement community health worker programs targeting prenatal care entry
- Partner with IDPH on Perinatal Quality Collaborative initiatives

**For High-tier rural ZIPs (Mill Shoals, Rock Island):**
- Prioritize telehealth prenatal care expansion
- Address transportation barriers through Medicaid non-emergency medical transport
- Incentivize OB/GYN practice establishment via rural health loan repayment programs

**For the Portfolio:**
- Link this analysis to Project 2 (SDOH) to understand structural drivers
- Feed composite scores into a value-based care population health model

---

*Data is publicly available and does not contain individually identifiable health information. All rates are calculated from aggregate counts.*
