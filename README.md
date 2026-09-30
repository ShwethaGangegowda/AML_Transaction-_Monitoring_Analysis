# AML_Transaction_Monitoring_Analysis
An end to end AML/KYC transaction monitoring and risk analysis project using SQL, Python, Excel, and Power BI focused on client and transaction data to identify suspicious activity, sanctions/FATF exposure, high-risk sectors and countries, transaction patterns, alert-rule concentration and behavioural analysis. 

# Project Overview
This project analyses 2000 clients and 50,000 transactions for FATF/OFAC exposure and transaction-monitoring alerts. Here the client master is joined with the transaction ledger to quantify alert activity, identify concentration by sector and country, measure monthly stability, and rank clients for review. A transaction is labelled suspicious when at least one of five transaction-level flags is active - OFAC match, FATF-country exposure, structuring, rapid movement, or trade mispricing.

# Business Objective

The objective of this project is to support a risk-based AML/KYC monitoring approach by combining static client risk indicators with transaction-level behavior.

The analysis helps identify:

* Which clients require closer review?
* Where suspicious activity is concentrated?
* Which AML rules generate the most alerts?
* Which countries and sectors have elevated risk indicators?
* Which transactions deviate significantly from normal client behavior?

# Key Performance Indicators:
•	50,000 transactions across 2,000 clients.

•	Total transaction value of approximately $209.8 million.

•	4,489 suspicious transactions, representing 8.98% of all transactions.

•	Suspicious transactions represented approximately $22.2 million, or 10.6% of total transaction value.

•	Average transaction value is determined to be $ 4,194.14.

•	Median Transaction Value is $1582.19.

•	Average transaction value is approximately 2.65 times the median transaction value, i.e., Mean-to-Median Ratio, which supports the conclusion that transaction values are right-skewed.

•	High Risk clients are estimated to be 1,218 and High Risk client Transactions are estimated to be 36,370.

# Key Findings
•	Rapid movement is the dominant alert- It appears in 2,460 transactions (4.92%), followed by OFAC transaction matches in 1,790 transactions (3.58%). These two rules account for the majority of flagged events which is approximately 81.6% of transaction-level rule triggers and should be the first focus for alert-quality review.

•	Energy/Oil with 10.67% had the highest suspicious transaction rate among sectors. Defence/Arms and Import/Export are also among the higher-rate segments, while Real Estate and Casino/Gambling show lower rates in this sample. Tech is labelled Low risk but runs at 9.20%. Rates should be interpreted with volume alongside them.

•	Venezuela, represented by country code VE, has the highest suspicious rate at 12.71% across 2,722 transactions among all client countries and with all 108 clients OFAC-flagged. North Korea (KP) and Iran (IR) show 100% FATF and OFAC flag rates in the observed population. This is a prioritization signal, not proof that all activity from that country is illicit.

•	The transaction amount distribution is strongly right-skewed. The mean amount is $4,196.14, while the median is $1,582.18, indicating that a relatively small number of large transactions materially influence total value. This supports using both count-based and value-based monitoring thresholds.

•	Suspicious rates by transaction type are: Check 9.34%, Wire 9.13%, SWIFT 8.84%, ACH 8.60%. The differences are useful for segment-specific rule tuning, but they should be tested for statistical significance and operational cost before changing thresholds.

•	1,218 high-risk clients are 60.9% of the base; their suspicious rate is 11.60%, versus 4.99% for Medium and 1.53% for Low. PEP clients average $6,365 per transaction versus $4,063 for non-PEPs; suspicious rates are 10.81% versus 8.87%.

•	Repeated 100%-suspicious corridors involve Venezuela, Syria, Russia, and Iran. Domestic activity is smaller but slightly more alert-dense than cross-border activity: 10.00% versus 8.93%.

•	The $5,000–$9,999 band has the highest suspicious rate, 15.43%; near-$10,000 clustering warrants review.

•	A transparent client-prioritization score was created using suspicious transaction counts, alert counts, and transaction value. Jones-Atkinson has highest $154.9 K outlier transaction versus a $ 7.1 K client average, z-score 6.18.

# Recommendations:
* Operational controls:
Review rapid-movement alerts for false-positive patterns, especially where transfers are routine treasury activity. Introduce a second-stage rule that considers velocity,amount, counterparty novelty, and time between outgoing and incoming movements.
 
* Risk-based segmentation:
Apply enhanced due diligence and tighter monitoring to clients in Energy/Oil, Defence/Arms, and Import/Export, while preserving volume-based controls so that lower-rate but high-value segments are not overlooked.

* Alert quality and model governance:
Capture investigator outcomes for every alert, then measure precision, false-positive rate, time to-disposition, and value-at-risk. These labels can support a calibrated scoring model and threshold optimization

# Repository Contents

├── aml_analysis.sql --------# SQL queries for AML analysis

├── AML_Transaction_Data.xlsx---------# Transaction and client dataset

├── AML_Analysis_Python.ipynb ----------# Python data cleaning and analysis

├── AML_Dashboard.pbix --------# Power BI interactive dashboard

|── Project_Structure.pdf-------# Project overview and key findings

|── README.md --------# Project documentation


# Tools Used
^ MySQL Workbench — data analysis, aggregation, CTEs, risk calculations and business queries

^ Python / Pandas — data cleaning, transformation, risk scoring and statistical analysis

^ Excel — dataset

^ Power BI — Interactive dashboards, KPIs and risk visualizations

# How to Run
Clone this repository.
1. Python Analysis
* Open Jupiter Notebook.Install the required Python libraries:
  pip install pandas numpy
* run the schema-creation section of aml monitoring_Python.ipynb 
* Run the notebook cells sequentially
* Create MySQL connection and connect the analysis to MYSQL for further analysis.

2. SQL Analysis
* Open MySQL Workbench.
* Create the required database and tables.  
* Import the AML transaction dataset.
* Open aml_monitoring_Sqlquery.sql.
* Run the queries section by section to reproduce the analysis.

3. Power BI Dashboard
* Open:AML_Dashboard.pbix
* Refresh the dataset if required.
* The Power BI dashboard includes:
  |Total Transactions|
  |Total Transaction Value|
  |Suspicious Transactions|
  |Suspicious Transaction Rate|
  |High-Risk Clients|
  |OFAC-Flagged Clients|
  |FATF-Flagged Clients|
  |PEP Clients|
  |Sanctions-Flagged Clients|
  |Total AML Alerts|
  |Outlier Transactions|
  |High-Value Clients|

# Author
Shwetha Gangegowda

Data Analytics | SQL | Python | Power BI | AML/KYC Analytics



