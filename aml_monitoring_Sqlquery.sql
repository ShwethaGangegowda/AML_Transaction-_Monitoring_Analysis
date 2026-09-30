#Database creation and data imported from Python
create database transaction_analysis
use transaction_analysis
describe mergeddata
select * from mergeddata

# DATA QUALITY ANALYSIS
-- Q1.Does every transaction have a matching client?
SELECT COUNT(*) AS orphaned_transactions FROM mergeddata WHERE client_name IS NULL;

-- Q2.Are there duplicate transaction_ids that would double-count volume?
SELECT transaction_id, COUNT(*) AS dup_txn FROM mergeddata GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Q3.Any transactions with null/zero/negative amounts that shouldn't be in the "clean" dataset?
SELECT COUNT(*) AS bad_amount_rows FROM mergeddata WHERE amount IS NULL OR amount <= 0;

#PORTFOLIO ANALYSIS
-- Q4.What's the overall shape of the book — volume, value, and how much of it is flagged?
WITH kpi_base AS (
    SELECT
        COUNT(transaction_id) AS total_transactions,
        ROUND(SUM(amount),2) AS total_transaction_amount,
        ROUND(SUM(amount) / COUNT(amount),2) AS avg_transaction_amount,
        COUNT(DISTINCT client_id) AS unique_customers,
        SUM(suspicious_txn) AS suspicious_transactions,
        SUM(suspicious_txn) * 100.0 / COUNT(transaction_id) AS suspicious_rate_pct,
        SUM(CASE WHEN suspicious_txn = 1 THEN amount ELSE 0 END) AS suspicious_transaction_amount,
        SUM(pep_flag) AS pep_flagged_transactions,
        SUM(sanctions_flag) AS sanctioned_transactions,
        SUM(ofac_match_flag) AS ofac_match_count,
        SUM(fatf_country_flag_txn) AS fatf_country_flag_count,
        SUM(structuring_pattern_flag) AS structuring_pattern_count,
        SUM(rapid_movement_flag) AS rapid_movement_count,
        SUM(trade_mispricing_flag) AS trade_mispricing_count
    FROM mergeddata)
SELECT 'Total Transactions' AS kpi_name, total_transactions AS kpi_value FROM kpi_base
UNION ALL SELECT 'Total Transaction Amount', total_transaction_amount FROM kpi_base
UNION ALL SELECT 'Average Transaction Amount', avg_transaction_amount FROM kpi_base
UNION ALL SELECT 'Unique Customers', unique_customers FROM kpi_base
UNION ALL SELECT 'Suspicious Transactions', suspicious_transactions FROM kpi_base
UNION ALL SELECT 'Suspicious Transaction Rate (%)', suspicious_rate_pct FROM kpi_base
UNION ALL SELECT 'Suspicious Transaction Amount',  suspicious_transaction_amount FROM kpi_base
UNION ALL SELECT 'PEP-Flagged Client Transactions',pep_flagged_transactions FROM kpi_base
UNION ALL SELECT 'Sanctioned Client Transactions',  sanctioned_transactions FROM kpi_base
UNION ALL SELECT 'OFAC Match Count',ofac_match_count FROM kpi_base
UNION ALL SELECT 'FATF Country Flag Count (Txn)', fatf_country_flag_count FROM kpi_base
UNION ALL SELECT 'Structuring Pattern Count', structuring_pattern_count FROM kpi_base
UNION ALL SELECT 'Rapid Movement Count', rapid_movement_count FROM kpi_base
UNION ALL SELECT 'Trade Mispricing Count', trade_mispricing_count FROM kpi_base;

-- Q5 .Find the list of unique customers?
WITH client_agg AS (
    SELECT client_id,client_name,client_type,sector,sector_risk,country,
        COUNT(transaction_id) AS transaction_count,
        ROUND(SUM(amount),2) AS total_transaction_amount,
        SUM(client_flag_count) AS client_flag_count,
        SUM(txn_flag_count) AS transaction_flag_count,
        SUM(suspicious_txn) AS suspicious_transaction_count
    FROM mergeddata
    GROUP BY client_id, client_name, client_type, sector, sector_risk, country
),
client_scored AS (
    SELECT *,
        (CASE sector_risk WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Low' THEN 1 ELSE 1 END)
        + LEAST(client_flag_count, 3)
        + (CASE WHEN transaction_count >= 40 THEN 2 WHEN transaction_count >= 25 THEN 1 ELSE 0 END)
        + (CASE WHEN transaction_flag_count >= 5 THEN 3
                WHEN transaction_flag_count >= 2 THEN 2
                WHEN transaction_flag_count >= 1 THEN 1
                ELSE 0 END) AS composite_risk_score
    FROM client_agg
)
SELECT client_id,client_name,client_type,sector,country,
    transaction_count AS transaction_per_client,
    total_transaction_amount AS transaction_amount,
    suspicious_transaction_count AS Suspicious_txn_count,
    client_flag_count AS clnt_flag_risk_count,
    transaction_flag_count AS txn_flag_risk_count,
    ROUND(suspicious_transaction_count * 100.0 / transaction_count, 2) AS suspicious_transaction_rate_pct,
    CASE
        WHEN composite_risk_score >= 8 THEN 'High'
        WHEN composite_risk_score >= 4 THEN 'Medium'
        ELSE 'Low'
    END  AS overall_risk_rating
FROM client_scored
ORDER BY client_id;
 
-- Q6. Find the top 20 clients who has highest transaction value?
SELECT
    client_id, client_name,
    ROUND(SUM(amount),2) AS Total_transaction_value,
    ROUND(SUM(amount)*100/ (SELECT SUM(amount) FROM mergeddata), 2) AS pct_of_total
FROM mergeddata
GROUP BY client_id, client_name
ORDER BY Total_transaction_value DESC
LIMIT 20;

#CLIENT RISK SEGMENTATION
-- Q7. How many clients fall into each risk rating, and how much money moves through each tier?
WITH client_agg AS
(
    SELECT
        client_id,
        MAX(sector_risk) AS sector_risk,
        MAX(client_flag_count) AS client_flag_count,
        COUNT(transaction_id) AS transaction_count,
        SUM(txn_flag_count) AS transaction_flag_count,
        SUM(suspicious_txn) AS suspicious_transaction_count,
        SUM(amount) AS total_value
    FROM mergeddata
    GROUP BY client_id
),
client_scored AS
(
    SELECT *,
        CASE
            WHEN sector_risk = 'High' THEN 3
            WHEN sector_risk = 'Medium' THEN 2
            WHEN sector_risk = 'Low' THEN 1
            ELSE 1
        END
        +
        CASE
            WHEN client_flag_count >= 5 THEN 3
            WHEN client_flag_count >= 2 THEN 2
            WHEN client_flag_count >= 1 THEN 1
            ELSE 0
        END
        +
        CASE
            WHEN transaction_flag_count >= 5 THEN 3
            WHEN transaction_flag_count >= 2 THEN 2
            WHEN transaction_flag_count >= 1 THEN 1
            ELSE 0
        END
        +
        CASE
            WHEN transaction_count >= 40 THEN 2
            WHEN transaction_count >= 25 THEN 1
            ELSE 0
        END
        AS composite_risk_score
        FROM client_agg
)
SELECT
    CASE
        WHEN composite_risk_score >= 5 THEN 'High'
        WHEN composite_risk_score >= 3 THEN 'Medium'
        ELSE 'Low'
    END AS overall_risk_rating,
    COUNT(*) AS client_count,
    ROUND(SUM(total_value), 2) AS total_value,
    ROUND(SUM(suspicious_transaction_count) * 100.0
        / NULLIF(SUM(transaction_count), 0),2) AS suspicious_rate_pct
FROM client_scored
GROUP BY
    CASE
        WHEN composite_risk_score >= 5 THEN 'High'
        WHEN composite_risk_score >= 3 THEN 'Medium'
        ELSE 'Low'
    END
ORDER BY client_count DESC;

-- Q8.Find the top 20 clients who carry multiple static risk flags simultaneously?
SELECT DISTINCT
    client_id, client_name, sector, country,
    pep_flag, sanctions_flag, fatf_country_flag_client, ofac_country_flag, sectoral_sanctions_flag,ownership_opacity_score,
    client_flag_count
FROM mergeddata
WHERE client_flag_count >= 3
ORDER BY client_flag_count DESC;

-- Q9. Do PEP clients actually transact differently than non-PEP clients, or is the flag not predictive?
SELECT
    CASE WHEN pep_flag = 1 THEN 'PEP' ELSE 'Non-PEP' END AS pep_status,
    COUNT(DISTINCT client_id) AS clients,
    ROUND(AVG(amount), 2) AS avg_txn_amount,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY pep_flag;

-- Q10.Find Clients with very high suspicious-transaction rate?
SELECT
    client_id, client_name,
    COUNT(transaction_id) AS total_txns,
    SUM(suspicious_txn) AS suspicious_txns,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 1) AS suspicious_rate_pct
FROM mergeddata
GROUP BY client_id, client_name
HAVING COUNT(transaction_id) >= 5   
ORDER BY suspicious_rate_pct DESC, total_txns DESC
LIMIT 25;

#SECTOR ANALYSIS
-- Q11. Which sectors carry the highest suspicious-transaction rate?
-- where should enhanced due diligence be concentrated?
SELECT
    sector,
    COUNT(DISTINCT client_id) AS clients,
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(amount),2) AS total_value,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY sector
ORDER BY suspicious_rate_pct DESC;
 
-- Q12.Within each sector, which specific alert type fires most ? 
SELECT
    sector,
    SUM(ofac_match_flag) AS ofac_match,
    SUM(fatf_country_flag_txn) AS fatf_country,
    SUM(structuring_pattern_flag) AS structuring,
    SUM(rapid_movement_flag) AS rapid_movement,
    SUM(trade_mispricing_flag) AS trade_mispricing
FROM mergeddata
GROUP BY sector
ORDER BY sector;

-- Q13: Does sector_risk actually line up with the observed suspicious rate, 
--   or are some "Low" sectors quietly running hot?
SELECT
    sector, sector_risk,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS observed_suspicious_rate_pct
FROM mergeddata
GROUP BY sector, sector_risk
ORDER BY observed_suspicious_rate_pct DESC;

#COUNTRY ANALYSIS
-- Q14. Which client countries carry the highest suspicious rate and flag density?
SELECT
    country,
    COUNT(DISTINCT client_id) AS clients,
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct,
    COUNT(DISTINCT CASE WHEN fatf_country_flag_client = 1
                         THEN client_id END) AS fatf_flagged_clients,
    COUNT(DISTINCT CASE WHEN ofac_country_flag = 1
                         THEN client_id END) AS ofac_flagged_clients
FROM mergeddata
GROUP BY country
ORDER BY suspicious_rate_pct DESC;

-- Q15: Cross-border corridor analysis-which client_country, counterparty_country PAIRS carry
--  the most flagged activity?    
SELECT
    client_country, counterparty_country,
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(amount),2) AS total_value,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2)   AS suspicious_rate_pct
FROM mergeddata
GROUP BY client_country, counterparty_country
HAVING COUNT(transaction_id) >= 20    -- ignore thin/low-volume corridors, mostly noise
ORDER BY suspicious_transactions DESC;
 
 -- Q16: Cross-border vs domestic analysis - Do international transactions carry
--    materially more risk than same-country ones?
SELECT
    CASE WHEN client_country = counterparty_country THEN 'Domestic' ELSE 'Cross-Border' END AS txn_scope,
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(amount),2) AS total_value,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2)    AS suspicious_rate_pct
FROM mergeddata
GROUP BY txn_scope;
 
# TREND ANALYSIS
-- Q17: Is suspicious activity trending up or down month over month ? Is monitoring effectiveness improving,
-- or is risk growing faster than controls?
SELECT
    DATE_FORMAT(timestamp,'%Y-%m') AS txn_month,      
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(amount),2) AS total_value,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY txn_month
ORDER BY txn_month;

 -- Q18: Day-of-week pattern — Do suspicious transactions cluster on specific days ?
 SELECT
    CASE DAYOFWEEK(timestamp)
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END  AS day_of_week,
    COUNT(transaction_id) AS transactions,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY day_of_week
ORDER BY suspicious_rate_pct DESC;

-- Q19:Which Transaction_type(Wire, SWIFT, ACH,Check) has bigger share of flagged activity?
SELECT
    transaction_type,
    COUNT(transaction_id) AS transactions,
    ROUND(SUM(amount),2) AS total_value,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY transaction_type
ORDER BY suspicious_rate_pct DESC;

#ALERT DRIVER / RULE PERFORMANCE
-- Q20.Which individual alert rule fires most — where's the monitoring workload actually concentrated?
  with client_unique AS (
    SELECT
        client_id,
        MAX(pep_flag) AS pep_flag,
        MAX(sanctions_flag) AS sanctions_flag,
        MAX(fatf_country_flag_client) AS fatf_country_flag,
        MAX(ofac_country_flag) AS ofac_country_flag,
        MAX(sectoral_sanctions_flag) AS sectoral_sanctions_flag,
        MAX(ownership_opacity_score) AS ownership_opacity_score
    FROM mergeddata
    GROUP BY client_id
),
client_pop AS (SELECT COUNT(*) AS population_base FROM client_unique),
txn_pop AS (SELECT COUNT(*) AS population_base FROM mergeddata),
flag_totals AS (
    SELECT 'pep_flag' AS flag_name, 'Client' AS flag_level, SUM(pep_flag) AS records_triggered, (SELECT population_base FROM client_pop) AS population_base FROM client_unique
    UNION ALL SELECT 'sanctions_flag', 'Client', SUM(sanctions_flag), (SELECT population_base FROM client_pop) FROM client_unique
    UNION ALL SELECT 'fatf_country_flag', 'Client', SUM(fatf_country_flag), (SELECT population_base FROM client_pop) FROM client_unique
    UNION ALL SELECT 'ofac_country_flag', 'Client', SUM(ofac_country_flag), (SELECT population_base FROM client_pop) FROM client_unique
    UNION ALL SELECT 'sectoral_sanctions_flag', 'Client', SUM(sectoral_sanctions_flag), (SELECT population_base FROM client_pop) FROM client_unique
    UNION ALL SELECT 'ownership_opacity_score', 'Client', SUM(ownership_opacity_score), (SELECT population_base FROM client_pop) FROM client_unique
    UNION ALL SELECT 'ofac_match_flag', 'Transaction', SUM(ofac_match_flag), (SELECT population_base FROM txn_pop) FROM mergeddata
    UNION ALL SELECT 'fatf_country_flag', 'Transaction', SUM(fatf_country_flag_txn), (SELECT population_base FROM txn_pop) FROM mergeddata
    UNION ALL SELECT 'structuring_pattern_flag', 'Transaction', SUM(structuring_pattern_flag), (SELECT population_base FROM txn_pop) FROM mergeddata
    UNION ALL SELECT 'rapid_movement_flag', 'Transaction', SUM(rapid_movement_flag), (SELECT population_base FROM txn_pop) FROM mergeddata
    UNION ALL SELECT 'trade_mispricing_flag', 'Transaction', SUM(trade_mispricing_flag), (SELECT population_base FROM txn_pop) FROM mergeddata
)
SELECT
    flag_name,
    flag_level,
    records_triggered,
    population_base,
    ROUND(records_triggered * 100.0 / population_base, 2) AS triggered_rate_pct
FROM flag_totals
ORDER BY flag_level DESC, triggered_rate_pct DESC;

-- Q21: Rule co-occurrence — When structuring_pattern_flag fires, does rapid_movement_flag tend to fire alongside it? 
SELECT
    COUNT(*) AS total_structuring_alerts,
    SUM(CASE WHEN rapid_movement_flag = 1 THEN 1 ELSE 0 END) AS rapid_movement,
    ROUND(SUM(CASE WHEN rapid_movement_flag = 1 THEN 1 ELSE 0 END) * 100.0/ COUNT(*), 1)  AS co_occurrence_pct
FROM mergeddata
WHERE structuring_pattern_flag = 1;

#TRANSACTION PATTERN/STRUCTURING PATTERN
-- Q22. Find the Distribution of transaction sizes to see where volume concentrates?
SELECT
    CASE
        WHEN amount < 1000 THEN '< $1,000'
        WHEN amount < 5000 THEN '$1,000 - $4,999'
        WHEN amount < 10000 THEN '$5,000 - $9,999'
        WHEN amount < 25000 THEN '$10,000 - $24,999'
        ELSE '$25,000+'
    END AS amount_band,
    COUNT(*) AS transaction_count,
    SUM(suspicious_txn) AS suspicious_transactions,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*), 2) AS suspicious_rate_pct
FROM mergeddata
GROUP BY amount_band
ORDER BY MIN(amount);

-- Q23:Find Clients with an unusually high volume of transactions clustered just under a round-number threshold $10,000
-- reporting line ?
SELECT
    client_id, client_name,
    COUNT(*) AS txns_near_threshold
FROM mergeddata
WHERE amount BETWEEN 8000 AND 9999.99
GROUP BY client_id, client_name
HAVING COUNT(*) >= 3
ORDER BY txns_near_threshold DESC;

-- Q24: Outlier transactions- Which individual transactions sit furthest from their OWN client's
--  typical transaction size?
SELECT
    m.transaction_id, m.client_id, m.client_name, m.amount,
    c.avg_amount, c.stddev_amount,
    ROUND((m.amount - c.avg_amount) / NULLIF(c.stddev_amount, 0), 2) AS z_score
FROM mergeddata m
JOIN (
    SELECT client_id, ROUND(AVG(amount),2)AS avg_amount,
	ROUND(SQRT(AVG(amount*amount) - AVG(amount)*AVG(amount)),2) AS stddev_amount
    FROM mergeddata
    GROUP BY client_id
) c ON m.client_id = c.client_id
WHERE c.stddev_amount > 0
ORDER BY ABS((m.amount - c.avg_amount) / c.stddev_amount) DESC
LIMIT 25;

#CLIENT PRIORITIZATION / CASE QUEUE
-- Q25: Find priority list of customers for the compliance team's review queue which blends
--    suspicious volume, alert intensity, and dollar exposure?
SELECT
    client_id, client_name, sector, country, overall_risk_rating,
    COUNT(transaction_id) AS total_transactions,
    SUM(suspicious_txn) AS suspicious_transactions,
    SUM(txn_flag_count) AS total_alert_count,
    ROUND(SUM(amount),2) AS total_value,
    ROUND((3 * SUM(suspicious_txn))
        + SUM(txn_flag_count)
        + SUM(amount) / 1000000.0,2) AS priority_score
FROM mergeddata
GROUP BY client_id, client_name, sector, country, overall_risk_rating
ORDER BY priority_score DESC
LIMIT 25;

-- Q26: Find clients with comparatively few transactions, but a disproportionate share has already flagged ?
SELECT 
    client_id,
    client_name,
    COUNT(transaction_id) AS total_txns,
    SUM(suspicious_txn) AS suspicious_txns,
    ROUND(SUM(suspicious_txn) * 100.0 / COUNT(*),1) AS suspicious_rate_pct
FROM
    mergeddata
GROUP BY client_id , client_name
HAVING COUNT(transaction_id) BETWEEN 1 AND 12 AND SUM(suspicious_txn) >= 2
ORDER BY suspicious_rate_pct DESC;
 

