-- Healthcare analysis queries
-- Tables loaded from data/Healthcare_Analytics_Clean_30000.xlsx: visits, billing, patients, providers, facilities, services
-- Written for SQLite. python/load_to_sqlite.py builds healthcare.db and runs these queries.

-- 1. Headline KPIs
SELECT COUNT(*)                                              AS visits,
       COUNT(DISTINCT v.Patient_ID)                          AS patients,
       ROUND(SUM(b.Charge_SAR), 0)                           AS total_billed_sar,
       ROUND(SUM(b.Collected_SAR), 0)                        AS collected_sar,
       ROUND(100.0 * SUM(b.Collected_SAR) / SUM(b.Charge_SAR), 1) AS collection_rate_pct,
       ROUND(SUM(b.Charge_SAR - b.Collected_SAR), 0)         AS uncollected_sar,
       ROUND(AVG(v.Wait_Minutes), 1)                         AS avg_wait_min
FROM visits v
JOIN billing b ON b.Visit_ID = v.Visit_ID;

-- 2. Revenue and collection by service
SELECT s.Service_Name,
       COUNT(*)                                              AS visits,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM visits), 1) AS visit_share_pct,
       ROUND(SUM(b.Charge_SAR), 0)                           AS billed_sar,
       ROUND(100.0 * SUM(b.Charge_SAR) / (SELECT SUM(Charge_SAR) FROM billing), 1) AS revenue_share_pct,
       ROUND(SUM(b.Charge_SAR - b.Collected_SAR), 0)         AS uncollected_sar
FROM visits v
JOIN billing b  ON b.Visit_ID = v.Visit_ID
JOIN services s ON s.Service_ID = v.Service_ID
GROUP BY s.Service_Name
ORDER BY billed_sar DESC;

-- 3. Insured vs self-pay
SELECT p.Payment_Type,
       COUNT(*)                                              AS visits,
       ROUND(100.0 * SUM(b.Collected_SAR) / SUM(b.Charge_SAR), 1) AS collection_rate_pct
FROM visits v
JOIN billing b  ON b.Visit_ID = v.Visit_ID
JOIN patients p ON p.Patient_ID = v.Patient_ID
GROUP BY p.Payment_Type;

-- 4. Waiting time bands
SELECT CASE
           WHEN Wait_Minutes <= 30  THEN '0-30 min'
           WHEN Wait_Minutes <= 60  THEN '31-60 min'
           WHEN Wait_Minutes <= 90  THEN '61-90 min'
           WHEN Wait_Minutes <= 120 THEN '91-120 min'
           ELSE '121-150 min'
       END                                                   AS wait_band,
       COUNT(*)                                              AS visits,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM visits), 1) AS share_pct
FROM visits
GROUP BY wait_band
ORDER BY MIN(Wait_Minutes);

-- 5. Emergency visits seen within the 30-minute target
SELECT COUNT(*)                                              AS er_visits,
       ROUND(100.0 * SUM(CASE WHEN Wait_Minutes <= 30 THEN 1 ELSE 0 END) / COUNT(*), 1) AS seen_in_30_min_pct,
       ROUND(AVG(Wait_Minutes), 1)                           AS avg_wait_min
FROM visits
WHERE Department = 'Emergency';

-- 6. Admissions per bed by hospital
SELECT f.Facility_Name, f.City, f.Beds,
       SUM(CASE WHEN v.Outcome = 'Admitted' THEN 1 ELSE 0 END) AS admissions,
       ROUND(1.0 * SUM(CASE WHEN v.Outcome = 'Admitted' THEN 1 ELSE 0 END) / f.Beds, 1) AS admissions_per_bed
FROM visits v
JOIN facilities f ON f.Facility_ID = v.Facility_ID
GROUP BY f.Facility_Name, f.City, f.Beds
ORDER BY admissions_per_bed DESC;

-- 7. Outcome rates
SELECT Outcome,
       COUNT(*)                                              AS visits,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM visits), 1) AS rate_pct
FROM visits
GROUP BY Outcome
ORDER BY visits DESC;

-- 8. 2025 vs 2024
SELECT strftime('%Y', v.Visit_Date)                          AS year,
       COUNT(*)                                              AS visits,
       ROUND(SUM(b.Charge_SAR), 0)                           AS billed_sar,
       ROUND(SUM(b.Collected_SAR), 0)                        AS collected_sar,
       ROUND(AVG(b.Charge_SAR), 0)                           AS avg_bill_sar,
       ROUND(AVG(v.Wait_Minutes), 1)                         AS avg_wait_min
FROM visits v
JOIN billing b ON b.Visit_ID = v.Visit_ID
WHERE strftime('%Y', v.Visit_Date) IN ('2024', '2025')
GROUP BY year
ORDER BY year;
