
INSTALL httpfs;
LOAD httpfs;

---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- S E T U P   V A R I A B L E S
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
CREATE OR REPLACE MACRO fidelity_file() AS
    getvariable('fidelity_positions_CSV_file');

CREATE OR REPLACE MACRO universe_DAILY_CSV_file() AS
 '/Users/markdavis/Sync/CEFs/portfolios/daily_stuff/cmplt_universe_of_srvcs_DAILY.csv';
SELECT universe_DAILY_CSV_file();

---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-00__fidelity_accounts.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
DROP TABLE IF EXISTS fidelity_accounts;
CREATE TABLE fidelity_accounts 
	("selectedFidelityAcct#" VARCHAR,
	 "FidelityAcct#" VARCHAR PRIMARY KEY,
	 "FidelityAcctNme" VARCHAR);
INSERT INTO fidelity_accounts
    VALUES ('x', '257054233', 'Rollover IRA [Mark]'),
    			 ('', '230668380', 'Roth IRA [Mark]'),
					 ('', '236264601', 'Inherited IRA [Eleanor]'),		 
					 ('', '241891742', 'Inherited Roth IRA [Alice]'),
					 ('', '249363366', 'Inherited IRA [Alice]'),
					 ('', 'Z03120502', 'Brokerage'),					 
					 ('', '30204', 'Kyndryl 401(K)'),
					 ('', '230739689', 'Roth IRA [Suzanne]'),
					 ('', '258012719', 'Rollover IRA [Suzanne]');
SELECT * FROM fidelity_accounts;
SELECT * FROM fidelity_accounts
where trim(lower("selectedFidelityAcct#"))='x';

-- IMPORTANT!!  IMPORTANT!!  IMPORTANT!!  IMPORTANT!!
-- for the SOLD positions  [except Rollover IRA], we need
-- to execute this script!!!  The downloaded files provided
-- by Fidelity for 'Inherited IRA [Eleanor]', etc. just 
-- don't seem to behave as expected...
-- ++++ - ++++ - ++++ - ++++ - ++++ - ++++ - ++++ - ++++ -
-- 1). open terminal
-- 2). run "bash ~/Downloads/duckDB_script.sh"
-- 3). run "bash ~/Downloads/duckDB_script_clean_Fidelity_DAILY.sh"
-- ++++ - ++++ - ++++ - ++++ - ++++ - ++++ - ++++ - ++++ -



---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-01__cmplt_universe_of_services.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: Take master portfolio list ALL service(s) from "Google sheets" 
-- IMPORTANT #2: dbl-chk "CURR_DTE" as these will change over time!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- 1) Raw ingest (keep file order for deterministic dedupe)
DROP TABLE IF EXISTS cmplt_universe_google_sheet_raw;
CREATE TABLE cmplt_universe_google_sheet_raw AS
SELECT
    ROW_NUMBER() OVER () AS _load_seq,
    Symbol, Name, Volume, Price, "prc-chg-pct", "52-wk low", "52-wk high",
    "5-yr low", "5-yr high", "Asset Class", "Asset Sub-Class", Action,
    "CEF/ETF/BDC", CLO, "Order", Portfolio, Comment
FROM read_csv_auto(
	universe_DAILY_CSV_file(),
    delim = ',',
    header = true,
    all_varchar = true
);

-- 2) Final table with unique (Symbol, "Order")
DROP TABLE IF EXISTS cmplt_universe_google_sheet;
CREATE TABLE cmplt_universe_google_sheet AS
SELECT
    Symbol, Name, Volume, Price, "prc-chg-pct", "52-wk low", "52-wk high",
    "5-yr low", "5-yr high", "Asset Class", "Asset Sub-Class", Action,
    "CEF/ETF/BDC", CLO, "Order", Portfolio, Comment
FROM cmplt_universe_google_sheet_raw
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY TRIM(Symbol), TRIM("Order")
    ORDER BY _load_seq
) = 1;


select * from cmplt_universe_google_sheet;

------------------------------------------------------------------------------------------------
-- L i s t  of  P o r t f o l i o  S e r v i c e (s)  reconstruction 
------------------------------------------------------------------------------------------------
-- Let's reconstruct so some fields to decimal, rather than varchar...
DROP TABLE IF EXISTS portfolio_services_every_symbol;
CREATE TABLE portfolio_services_every_symbol (
	Symbol VARCHAR
	, AssetClass VARCHAR		
	, AssetSubClass VARCHAR
	, Action VARCHAR
	, "cef/etf/bdc" VARCHAR
	, CLO VARCHAR
	, "Order" VARCHAR
	, Portfolio VARCHAR	
	, Name VARCHAR
	, Comment VARCHAR
	, CurrDate DATE
	, CurrVol DECIMAL	
	, CurrPrc DECIMAL
	, PrcChgPct DECIMAL
	, Wk52_Low DECIMAL
	, Wk52_High DECIMAL
	, Yr5_Low DECIMAL
	, Yr5_High DECIMAL
);
DESCRIBE portfolio_services_every_symbol;


-- Portfolio Service(s)  "Complete List"
INSERT INTO portfolio_services_every_symbol BY NAME 
(
  SELECT 
    cef.Symbol as Symbol
    , cef."Asset Class" as AssetClass 
    , cef."Asset Sub-Class" as AssetSubClass 
    , cef.Action as Action
    , cef."CEF/ETF/BDC" as "cef/etf/bdc" 
    , cef.CLO as CLO
    , cef."Order" as "Order"         
    , cef.Portfolio as Portfolio  
		, cef.Name as Name
		, cef.Comment
 		, current_date as CurrDate	
		, CASE 
			 WHEN trim(cef.Volume)='#N/A' then NULL
			 WHEN trim(cef.Volume)='Loading...' then NULL
			 ELSE cast(regexp_replace(regexp_replace(trim(cef.Volume), '[,]', ''), '[,]', '') as decimal)
			END as CurrVol
		, CASE 
			 WHEN trim(cef.Price)='#N/A' then NULL
			 WHEN trim(cef.Price)='Loading...' then NULL
			 ELSE cast(regexp_replace(trim(cef.Price), '[,]', '') as decimal)
			END as CurrPrc
		, CASE 
			 WHEN trim(cef."prc-chg-pct")='#N/A' then NULL
			 WHEN trim(cef."prc-chg-pct")='Loading...' then NULL
			 ELSE cast(regexp_replace(trim(cef."prc-chg-pct"), '[,]', '') as decimal)
			END as PrcChgPct
		, CASE 
			 WHEN trim(cef."52-wk low")='#N/A' then NULL
			 WHEN trim(cef."52-wk low")='Loading...' then NULL
			 ELSE cast(regexp_replace(trim(cef."52-wk low"), '[,]', '') as decimal)
			END as Wk52_Low
		, CASE 
			 WHEN trim(cef."52-wk high")='#N/A' then NULL
			 WHEN trim(cef."52-wk high")='Loading...' then NULL
		 ELSE cast(regexp_replace(trim(cef."52-wk high"), '[,]', '') as decimal)
			END as Wk52_High
		, CASE 
			 WHEN trim(cef."5-yr low")='#N/A' then NULL
			 WHEN trim(cef."5-yr low")='Loading...' then NULL
			 ELSE cast(regexp_replace(trim(cef."5-yr low"), '[,]', '') as decimal)
			END as Yr5_Low
		, CASE 
			 WHEN trim(cef."5-yr high")='#N/A' then NULL
			 WHEN trim(cef."5-yr high")='Loading...' then NULL
			 ELSE cast(regexp_replace(trim(cef."5-yr high"), '[,]', '') as decimal)
			END as Yr5_High	 	
  FROM cmplt_universe_google_sheet cef
  WHERE symbol is not null
);
select * from portfolio_services_every_symbol
order by Symbol;




------------------------------------------------------------------------------------------------
--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
-- P O R T F O L I O  of  S E R V I C E s
--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS portfolio_services_unique_symbols;
CREATE TABLE portfolio_services_unique_symbols (
	Symbol VARCHAR
	, AssetClass VARCHAR		
	, AssetSubClass VARCHAR
	, Action VARCHAR
	, "cef/etf/bdc" VARCHAR
	, CLO VARCHAR
	, "Order" VARCHAR
	, Portfolio VARCHAR	
	, Name VARCHAR
	, Comment VARCHAR
	, CurrDate DATE
	, CurrVol DECIMAL	
	, CurrPrc DECIMAL
	, PrcChgPct DECIMAL
	, Wk52_Low DECIMAL
	, Wk52_High DECIMAL
	, Yr5_Low DECIMAL
	, Yr5_High DECIMAL
	, TotSrvcs SMALLINT
);
DESCRIBE portfolio_services_unique_symbols;

--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
-- MASTER LIST of [Portfolio] Services -- we want a UNIQUE LIST!!
--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
INSERT INTO portfolio_services_unique_symbols BY NAME 
(
	with portfolio_unique_tmp as (
		select *
		, RANK() OVER(PARTITION BY Symbol ORDER BY Action, "Order" desc) rnk
		from portfolio_services_every_symbol
		-- let's exclude some of the services from this analysis
		where TRY_CAST(TRIM("Order") AS INTEGER) <= 30
	),
	portfolio_tot_srvcs_tmp as (
	select Symbol
	, count(Symbol) as TotSrvcs
	from portfolio_unique_tmp
	group by Symbol
	)
	select 
		unq.Symbol, unq.AssetClass, unq.AssetSubClass, unq.Action, unq."cef/etf/bdc", unq.CLO
	, unq."Order", unq.Portfolio, unq.Name, unq.Comment, unq.CurrDate, unq.CurrVol
	, unq.CurrPrc, unq.PrcChgPct, unq.Wk52_Low, unq.Wk52_High
	, unq.Yr5_Low, unq.Yr5_High, srvcs.TotSrvcs 
	from portfolio_unique_tmp unq 
	left outer join portfolio_tot_srvcs_tmp srvcs
	on unq.Symbol=srvcs.Symbol
	where unq.Rnk=1
	order by unq.Symbol
);
select * from portfolio_services_unique_symbols
order by Symbol;


------------------------------------------------------------------------------------------------
--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
-- W H I C H  S E R V I C E S  S H A R E   S Y M B O L (s) ?
--***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***-***
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS shared_portfolio_services_sandbox;
CREATE TABLE shared_portfolio_services_sandbox (
	symbol VARCHAR
	, CEFMastery VARCHAR
	, ETFMastery VARCHAR	
	, BDCMastery VARCHAR	
	, armchair VARCHAR
	, IL_taxable VARCHAR
	, IL_tactical100 VARCHAR
	, IL_generator VARCHAR
	, IL_etfAlpha VARCHAR
	, IL_EQwatch VARCHAR
	, IL_INCwatch VARCHAR	
	, IL_wklyemail VARCHAR	
	, cntrn_outlk VARCHAR	
	, will_allender VARCHAR
  , eliz_meffen VARCHAR	
	, fb_challenge VARCHAR	    	
	, shared_srvcs VARCHAR
);
DESCRIBE shared_portfolio_services_sandbox;


--***-***-***-***-***-***-***-***-***-***-***-***-***-***
-- MASTER LIST of [Portfolio] -- INSERT 
--***-***-***-***-***-***-***-***-***-***-***-***-***-***
INSERT INTO shared_portfolio_services_sandbox BY NAME 
(
	with shared_services_tmp as (
	  select unq.symbol
	  , CEFMastery.symbol as CEFMastery
	  , ETFMastery.symbol as ETFMastery
	  , BDCMastery.symbol as BDCMastery
    , armchair.symbol as armchair
	  , inc_lab1.symbol as IL_taxable
	  , inc_lab2.symbol as IL_tactical100
	  , inc_lab3.symbol as IL_generator
	  , inc_lab4.symbol as IL_etfAlpha
	  , inc_lab5.symbol as IL_EQwatch
	  , inc_lab6.symbol as IL_INCwatch
	  , inc_lab7.symbol as IL_wklyemail
	  , contrarian_outlook.symbol as cntrn_outlk
	  , will_allender.symbol as will_allender
	  , eliz_meffen.symbol as eliz_meffen
	  , fb_challenge.symbol as fb_challenge
	  from portfolio_services_unique_symbols unq

	  left outer join (
	    select distinct symbol
	      -- CEFMastery
	    from portfolio_services_every_symbol
	    where "order"=1
	  ) CEFMastery
	  on unq.symbol=CEFMastery.symbol		  

	  left outer join (
	    select distinct symbol
	      -- ETFMastery
	    from portfolio_services_every_symbol
	    where "order"=2
	  ) ETFMastery
	  on unq.symbol=ETFMastery.symbol

	  left outer join (
	    select distinct symbol
	      -- BDCMastery
	    from portfolio_services_every_symbol
	    where "order"=3
	  ) BDCMastery
	  on unq.symbol=BDCMastery.symbol	  

	  left outer join (
	    select distinct symbol
	      -- ArmchairIncome
	    from portfolio_services_every_symbol
	    where "order"=4
	  ) armchair
	  on unq.symbol=armchair.symbol	  

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [taxable income]
	    from portfolio_services_every_symbol
	    where "order"=5
	  ) inc_lab1
	  on unq.symbol=inc_lab1.symbol

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [tactical income 100]
	    from portfolio_services_every_symbol
	    where "order"=6
	  ) inc_lab2
	  on unq.symbol=inc_lab2.symbol

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [income generator]
	    from portfolio_services_every_symbol
	    where "order"=7
	  ) inc_lab3
	  on unq.symbol=inc_lab3.symbol

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [ETF Alpha]
	    from portfolio_services_every_symbol
	    where "order"=8
	  ) inc_lab4
	  on unq.symbol=inc_lab4.symbol

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [Equity Watchlist]
	    from portfolio_services_every_symbol
	    where "order"=9
	  ) inc_lab5
	  on unq.symbol=inc_lab5.symbol

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [Fixed Income Watchlist]
	    from portfolio_services_every_symbol
	    where "order"=10
	  ) inc_lab6
	  on unq.symbol=inc_lab6.symbol	

	  left outer join (
	    select distinct symbol
	      -- IncomeLab [wkly email]
	    from portfolio_services_every_symbol
	    where "order"=11
	  ) inc_lab7
	  on unq.symbol=inc_lab7.symbol	    

	  left outer join (
	    select distinct symbol
	      -- Contrrian Outlook
	    from portfolio_services_every_symbol
	    where "order"=12
	  ) contrarian_outlook
	  on unq.symbol=contrarian_outlook.symbol

	  left outer join (
	    select distinct symbol
	      -- Will Allender
	    from portfolio_services_every_symbol
	    where "order"=13
	  ) will_allender
	  on unq.symbol=will_allender.symbol

	  left outer join (
	    select distinct symbol
	      -- Elizabeth Meffen
	    from portfolio_services_every_symbol
	    where "order"=14
	  ) eliz_meffen
	  on unq.symbol=eliz_meffen.symbol

	  left outer join (
	    select distinct symbol
	      -- FB Challenge
	    from portfolio_services_every_symbol
	    where "order"=20
	  ) fb_challenge
	  on unq.symbol=fb_challenge.symbol   	  	 	  	  	  	  	  
	)
	select symbol, CEFMastery, ETFMastery, BDCMastery
  	, armchair, IL_taxable, IL_tactical100, IL_generator 
	, IL_etfAlpha, IL_EQwatch, IL_INCwatch
	, IL_wklyemail, cntrn_outlk, will_allender 
  , eliz_meffen, fb_challenge 	    	
	, concat_ws(' & ',regexp_replace(CEFMastery, '\b[A-Z.]+\b', 'cefMstry')
					 ,regexp_replace(ETFMastery, '\b[A-Z.]+\b', 'etfMstry')
					 ,regexp_replace(BDCMastery, '\b[A-Z.]+\b', 'bdcMstry')
	         ,regexp_replace(armchair, '\b[A-Z.]+\b', 'armchair')
	         ,regexp_replace(IL_taxable, '\b[A-Z.]+\b', '_taxable')
	         ,regexp_replace(IL_tactical100, '\b[A-Z.]+\b', '_tactical100')
	         ,regexp_replace(IL_generator, '\b[A-Z.]+\b', '_generator')
	         ,regexp_replace(IL_etfAlpha, '\b[A-Z.]+\b', '_etfAlpha')
	         ,regexp_replace(IL_EQwatch, '\b[A-Z.]+\b', '_EQwatch')
	         ,regexp_replace(IL_INCwatch, '\b[A-Z.]+\b', '_INCwatch')
	         ,regexp_replace(IL_wklyemail, '\b[A-Z.]+\b', '_wklyemail')
	         ,regexp_replace(cntrn_outlk, '\b[A-Z.]+\b', 'CO')
	         ,regexp_replace(will_allender, '\b[A-Z.]+\b', 'allender')
	         ,regexp_replace(eliz_meffen, '\b[A-Z.]+\b', 'meffen')
	         ,regexp_replace(fb_challenge, '\b[A-Z.]+\b', 'FB')
	         ) as shared_srvcs
	from shared_services_tmp
);
select * from shared_portfolio_services_sandbox
order by symbol;



---------------------------------------------------------------------------------------------
-- F I N A L !!!  F I N A L !!!
---------------------------------------------------------------------------------------------
--Which funds are recommended in more than one service?
---------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS cmplt_universe_of_srvcs;
CREATE TABLE cmplt_universe_of_srvcs (
	Symbol VARCHAR
	, AssetClass VARCHAR		
	, AssetSubClass VARCHAR
	, Action VARCHAR
	, "cef/etf/bdc" VARCHAR
	, CLO VARCHAR
	, "Order" VARCHAR
	, Portfolio VARCHAR	
	, Name VARCHAR
	, Comment VARCHAR
	, CurrDate DATE
	, CurrVol DECIMAL	
	, CurrPrc DECIMAL
	, PrcChgPct DECIMAL
	, Wk52_Low DECIMAL
	, Wk52_High DECIMAL
	, Yr5_Low DECIMAL
	, Yr5_High DECIMAL
	, TotSrvcs SMALLINT
	, SharedSrvcs VARCHAR	
);
DESCRIBE cmplt_universe_of_srvcs;


--***-***-***-***-***-***-***-***-***-***-***-***-***-***
-- COMPLETE UNIVERSE of SERVICES -- INSERT 
--***-***-***-***-***-***-***-***-***-***-***-***-***-***
INSERT INTO cmplt_universe_of_srvcs BY NAME 
(
	select unq.*, shrd.shared_srvcs as SharedSrvcs
	from portfolio_services_unique_symbols unq
	left outer join shared_portfolio_services_sandbox shrd
	on unq.symbol=shrd.Symbol
	order by unq.symbol
)
;
select * from cmplt_universe_of_srvcs
order by Symbol;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-02__fidelity_positions.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: dbl-chk "input file" to get latest Fidelity statement!!
-- IMPORTANT #2: MUST 'clean' the last few rubbish lines b/c Fidelity's statement includes
-- IMPORTANT #3: dbl-chk "FidelityStmtDte" as this will change over time!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

--Fidelity Positions 
DROP TABLE IF EXISTS fidelity_positions_csv;
CREATE TABLE fidelity_positions_csv AS 
	SELECT 
	"Account Number" as fidelity_acct, "Account Name" as fidelity_acct_name, Symbol as symbol, Description as name
	, Quantity as qty, "Last Price" as last_prc, "Last Price Change" as last_prc_chg
	, "Current Value" as curr_value, "Total Gain/Loss Dollar" as "tot_g/l_amt", "Total Gain/Loss Percent" as "tot_g/l_pct"
	, "Percent Of Account" as acct_pct, "Cost Basis Total" as tot_cost_basis, "Average Cost Basis" as avg_cost_basis
	, "Today's Gain/Loss Percent" as "today_g/l_pct"
	FROM read_csv_auto(fidelity_file(), delim=',', header=true, all_varchar=true, null_padding=true)
  where Symbol is NOT NULL
;
DESCRIBE fidelity_positions_csv;
select * from fidelity_positions_csv;


------------------------------------------------------------------------------------------------
-- F I D E L I T Y _ P O S I T I O N S  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_positions;
CREATE TABLE fidelity_positions(
	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR
	, Symbol VARCHAR
	, Name VARCHAR
	, FidelityStmtQty DECIMAL
	, FidelityStmtDte DATE
	, FidelityStmtPrc DECIMAL
	, FidelityStmtPrcChg DECIMAL	
	, FidelityStmtValue DECIMAL
	, "Total_G/L_Amt" DECIMAL
	, "Total_G/L_Pct" DECIMAL
	, AcctPct DECIMAL
	, TotCostBasis DECIMAL
	, AvgCostBasis DECIMAL
	, "Today_G/L_Pct" DECIMAL
);
DESCRIBE fidelity_positions;

-- sometimes, the field has wierd characters (i.e. $,%,+,-) that need to be filtered
INSERT INTO fidelity_positions BY NAME 
(
  SELECT 
	fp.fidelity_acct as FidelityAcct
	, fp.fidelity_acct_name as FidelityAcctName
	, fp.symbol as Symbol
	, fp.name as Name
	, CASE 
			WHEN fp.qty=trim('') then NULL
			WHEN fp.qty=trim('--') then NULL
			ELSE fp.qty
		END as FidelityStmtQty	
	, current_date as FidelityStmtDte
	, CASE 
			WHEN fp.last_prc=trim('') then NULL
			WHEN fp.last_prc=trim('--') then NULL
			WHEN fp.last_prc=trim('n/a') then NULL
			ELSE cast(regexp_replace(trim(trim(fp.last_prc),'$'), '[,]', '') as decimal)
		END as FidelityStmtPrc
	, CASE 
			WHEN trim(fp.last_prc_chg)=trim('') then NULL
			WHEN trim(fp.last_prc_chg)=trim('--') then NULL
			WHEN trim(fp.last_prc_chg)=trim('n/a') then NULL
			WHEN trim(fp.last_prc_chg) ^@ '(' then cast(regexp_replace(trim(trim(fp.last_prc_chg),'$()'), '[,]', '') as decimal)*-1
			WHEN trim(fp.last_prc_chg) ^@ '-' then cast(regexp_replace(trim(trim(fp.last_prc_chg),'$-'), '[,]', '') as decimal)*-1
			ELSE cast(regexp_replace(trim(trim(fp.last_prc_chg),'$+'), '[,]', '') as decimal)
	  END as FidelityStmtPrcChg
	, CASE 
			WHEN fp.curr_value=trim('') then NULL
			WHEN fp.curr_value=trim('--') then NULL
			WHEN fp.curr_value=trim('n/a') then NULL
			WHEN fp.curr_value ^@ '(' then cast(regexp_replace(trim(trim(fp.curr_value),'$()'), '[,]', '') as decimal)*-1
			WHEN fp.curr_value ^@ '-' then cast(regexp_replace(trim(trim(fp.curr_value),'$-'), '[,]', '') as decimal)*-1
			ELSE cast(regexp_replace(trim(trim(fp.curr_value),'$+'), '[,]', '') as decimal)
	  END as FidelityStmtValue	
	, CASE 
			WHEN fp."tot_g/l_amt"=trim('') then NULL
			WHEN fp."tot_g/l_amt"=trim('--') then NULL
			WHEN fp."tot_g/l_amt"=trim('n/a') then NULL
			WHEN fp."tot_g/l_amt" ^@ '(' then cast(regexp_replace(trim(trim(fp."tot_g/l_amt"),'$()'), '[,]', '') as decimal)*-1
			WHEN fp."tot_g/l_amt" ^@ '-' then cast(regexp_replace(trim(trim(fp."tot_g/l_amt"),'$-'), '[,]', '') as decimal)*-1
			ELSE cast(regexp_replace(trim(trim(fp."tot_g/l_amt"),'$+'), '[,]', '') as decimal)
	  END as "Total_G/L_Amt" 
	, CASE 
			WHEN fp."tot_g/l_pct"=trim('') then NULL
			WHEN fp."tot_g/l_pct"=trim('--') then NULL
			WHEN fp."tot_g/l_pct"=trim('n/a') then NULL
			WHEN fp."tot_g/l_pct" ^@ '-' then cast(regexp_replace(trim(trim(fp."tot_g/l_pct"),'%-'), '[,]', '') as decimal)*-1
			ELSE cast(regexp_replace(trim(trim(fp."tot_g/l_pct"),'%'), '[,]', '') as decimal)
	  END as "Total_G/L_Pct"
  , CASE 
		 WHEN fp.acct_pct=trim('') then NULL
		 WHEN fp.acct_pct=trim('--') then NULL
		 ELSE cast(trim(fp.acct_pct,'%') as decimal)
    END as AcctPct 
  , CASE 
		 WHEN fp.tot_cost_basis=trim('') then NULL
		 WHEN fp.tot_cost_basis=trim('--') then NULL
		 WHEN fp.tot_cost_basis=trim('n/a') then NULL
		 ELSE cast(regexp_replace(trim(trim(fp.tot_cost_basis),'$'), '[,]', '') as decimal)
    END as TotCostBasis  	
 ,  CASE 
		 WHEN fp.avg_cost_basis=trim('') then NULL
		 WHEN fp.avg_cost_basis=trim('--') then NULL
		 WHEN fp.avg_cost_basis=trim('n/a') then NULL
		 ELSE cast(regexp_replace(trim(trim(fp.avg_cost_basis),'$'), '[,]', '') as decimal)
		END as AvgCostBasis
 ,  CASE 
 		 WHEN fp."today_g/l_pct"=trim('') then NULL
 		 WHEN fp."today_g/l_pct"=trim('--') then NULL
 		 WHEN fp."today_g/l_pct"=trim('n/a') then NULL
 	   WHEN fp."today_g/l_pct" ^@ '-' then cast(regexp_replace(trim(trim(fp."today_g/l_pct"),'%-'), '[,]', '') as decimal)*-1
 	 	 ELSE cast(regexp_replace(trim(trim(fp."today_g/l_pct"),'%'), '[,]', '') as decimal)
    END as "Today_G/L_Pct"	  	  
  FROM fidelity_positions_csv fp
);

-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
select f.* from fidelity_positions f
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-03__fidelity_yields.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: dbl-chk "input file" to get latest Fidelity statement!!
-- IMPORTANT #2: MUST 'clean' the last few rubbish lines b/c Fidelity's statement includes
-- IMPORTANT #3: dbl-chk "FidelityStmtDte" as this will change over time!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


--Fidelity YIELDS 
DROP TABLE IF EXISTS fidelity_yields_csv;
CREATE TABLE fidelity_yields_csv AS 
	SELECT 
	Symbol as symbol, Description as name
	, "Account Number" as fidelity_acct
	, "Account Name" as fidelity_acct_name
	, "Current Value" as curr_value
	, "Cost basis total" as cost_basis
	, "Amount per share" as distrb_amt
	, Quantity as qty
	, "Payment frequency" as freq
		, CASE 
			WHEN freq='Semi-annually' then 2
			WHEN freq='Quarterly' then 4
			WHEN freq='Monthly' then 12
			ELSE 0
		END as annualize
  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/daily_stuff/fidelity_YIELD_all_accts.csv', delim=',', header=true, all_varchar=true)
  where Symbol is NOT NULL
;
DESCRIBE fidelity_yields_csv;
select * from fidelity_yields_csv;


------------------------------------------------------------------------------------------------
-- F I D E L I T Y _ Y I E L D S  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_yields;
CREATE TABLE fidelity_yields(
	Symbol VARCHAR
	, Name VARCHAR
	, FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR
	, CurrentValue DECIMAL
	, CostBasis DECIMAL	
	, DistrbAmt DECIMAL
	, Qty DECIMAL
	, Frequency VARCHAR
	, Annualize DECIMAL
	, Yield_on_Cost	DECIMAL	
	, Effective_Yield DECIMAL			
);
DESCRIBE fidelity_yields;

-- sometimes, the field has wierd characters (i.e. $,%,+,-) that need to be filtered
INSERT INTO fidelity_yields BY NAME 
(
  SELECT 
	fp.fidelity_acct as FidelityAcct
	, fp.fidelity_acct_name as FidelityAcctName
	, fp.symbol as Symbol
	, fp.name as Name
	, CASE 
			WHEN fp.curr_value=trim('') then NULL
			WHEN fp.curr_value=trim('--') then NULL
			WHEN fp.curr_value=trim('n/a') then NULL
			ELSE try_cast(regexp_replace(trim(trim(fp.curr_value),'$'), '[,]', '', 'g') as decimal)
		END as CurrentValue
	, CASE 
			WHEN fp.cost_basis=trim('') then NULL
			WHEN fp.cost_basis=trim('--') then NULL
			WHEN fp.cost_basis=trim('n/a') then NULL
			ELSE try_cast(regexp_replace(trim(trim(fp.cost_basis),'$'), '[,]', '', 'g') as decimal)
		END as CostBasis
	, CASE 
			WHEN fp.distrb_amt=trim('') then NULL
			WHEN fp.distrb_amt=trim('--') then NULL
			WHEN fp.distrb_amt=trim('n/a') then NULL
			ELSE try_cast(regexp_replace(trim(trim(fp.distrb_amt),'$'), '[,]', '', 'g') as decimal)
		END as DistrbAmt		
	, try_cast(regexp_replace(trim(fp.qty), '[,]', '', 'g') as decimal) as Qty	
	, fp.freq as Frequency    
  , cast(fp.annualize as decimal) as Annualize
	, (((DistrbAmt * Annualize) * cast (Qty as decimal)) / nullif(cast(CostBasis as decimal), 0)) * 100 as Yield_on_Cost 
	, (((DistrbAmt * Annualize) * cast (Qty as decimal)) / nullif(cast(CurrentValue as decimal), 0)) * 100 as Effective_Yield   
  FROM fidelity_yields_csv fp
);
select * from fidelity_yields;


-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
select f.* from fidelity_yields f
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-04__CEF_Connect.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: get latest via CEFConnect.com API!!
-- IMPORTANT #2: Need to convert the .json to .csv
-- 		https://www.cefconnect.com/api/v3/DailyPricing
-- 		https://codebeautify.org/json-to-csv
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

--CEFConnect Positions 
DROP TABLE IF EXISTS cef_connect_csv;
CREATE TABLE cef_connect_csv AS 
	SELECT 
	Ticker as Symbol, Discount
	, DistributionRateNAV, DistributionRatePrice, DistributionAmtUSD
	, ReturnOnNAV, CategoryId, CategoryName, SponsorName, IsManagedDistribution
	, Price, NAV, Name, LastUpdated, Strategy, LeverageRatioPercentage
	, MarketCapUSDm, DistributionFrequency, ExpenseRatio,TotalAssetsUSDm
	, IsLeveraged, IsPriceBelow52WkAvg, IsDiscountBelow52WkAvg, IsAMTPct
	, IsManaged, Term, AvgDailyVolume, Price52WkAvg, Discount52WkAvg
	, ZScore1Yr, ZScore3M, ZScore6M, ZScoreDate
	, InceptionDate, DistributionDate
  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/daily_stuff/cefconnect_DAILY.csv', delim=',', all_varchar=true)
;
DESCRIBE cef_connect_csv;
select * from cef_connect_csv;



DROP TABLE IF EXISTS cef_connect_positions;
CREATE TABLE cef_connect_positions(
	Symbol VARCHAR
	, Discount DECIMAL
	, DistributionRateNAV DECIMAL
	, DistributionRatePrice DECIMAL
	, DistributionAmtUSD DECIMAL
	, ReturnOnNAV DECIMAL
	, CategoryId SMALLINT
	, CategoryName VARCHAR
	, Risk SMALLINT
	, SponsorName VARCHAR
	, IsManagedDistribution VARCHAR
	, Price DECIMAL
	, NAV DECIMAL
	, Name VARCHAR
	, LastUpdated VARCHAR
	, Strategy VARCHAR
	, AssetClass VARCHAR
	, AssetSubClass VARCHAR
	, LeverageRatioPercentage DECIMAL
	, MarketCapUSDm DECIMAL
	, DistributionFrequency VARCHAR
	, ExpenseRatio DECIMAL
	, TotalAssetsUSDm DECIMAL
	, IsLeveraged VARCHAR
	, IsPriceBelow52WkAvg VARCHAR
	, IsDiscountBelow52WkAvg VARCHAR
	, IsAMTPct VARCHAR
	, IsManaged VARCHAR
	, Term VARCHAR
	, AvgDailyVolume DECIMAL
	, Price52WkAvg DECIMAL
	, Discount52WkAvg DECIMAL
	, ZScore1Yr DECIMAL
	, ZScore3M DECIMAL
	, ZScore6M DECIMAL
	, ZScoreDate DATE
	, InceptionDate DATE
	, DistributionDate DATE
	, PRIMARY KEY(Symbol));
DESCRIBE cef_connect_positions;


--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: this table originally came from CEFConnect.com!!
-- IMPORTANT #2: Only really need this once!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

--CEFConnect Positions 
DROP TABLE IF EXISTS cef_connect_RISK;
CREATE TABLE cef_connect_RISK (CategoryId SMALLINT, Name VARCHAR, Risk SMALLINT);
DESCRIBE cef_connect_RISK;
COPY cef_connect_RISK FROM '/Users/markdavis/Sync/CEFs/portfolios/cefconnect/cefconnect__risk.csv' (DELIMITER ',', HEADER);
--COPY cef_connect_RISK FROM '/Users/markdavis/Downloads/cefconnect__risk.csv' (DELIMITER ',', HEADER);
--select * from cef_connect_RISK;

INSERT OR IGNORE INTO cef_connect_positions BY NAME 
(
  SELECT 
	cef.Symbol
	, cef.Discount 
	, cef.DistributionRateNAV 
	, cef.DistributionRatePrice 
	, cef.DistributionAmtUSD 
	, cef.ReturnOnNAV
	, cef.CategoryId
	, cef.CategoryName 
	, risk.Risk
	, cef.SponsorName 
	, cef.IsManagedDistribution 
	, cef.Price 
	, cef.NAV 
	, cef.Name
	, cef.LastUpdated 
	, cef.Strategy
	, split_part(cef.Strategy, '-', 1) as AssetClass
	, ltrim(concat(split_part(cef.Strategy, '-', 2), ' ', split_part(cef.Strategy, '-', 3), ' ', split_part(cef.Strategy, '-', 4))) as AssetSubClass
	, cef.LeverageRatioPercentage 
	, cef.MarketCapUSDm 
	, cef.DistributionFrequency
	, cef.ExpenseRatio 
	, cef.TotalAssetsUSDm 
	, cef.IsLeveraged 
	, cef.IsPriceBelow52WkAvg 
	, cef.IsDiscountBelow52WkAvg 
	, cef.IsAMTPct 
	, cef.IsManaged 
	, cef.Term 
	, cef.AvgDailyVolume 
	, cef.Price52WkAvg 
	, cef.Discount52WkAvg 
	, cef.ZScore1Yr 
	, cef.ZScore3M 
	, cef.ZScore6M 
	, cef.ZScoreDate[0:10] as ZScoreDate 
	, cef.InceptionDate[0:10] as InceptionDate
	, cef.DistributionDate[0:10] as DistributionDate	
  FROM cef_connect_csv cef
  LEFT OUTER JOIN cef_connect_RISK risk
  ON cef.CategoryId=risk.CategoryId
);
select *
from cef_connect_positions;



---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-05__Seeking_Alpha_CEF_portfolio.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: this table comes from Seeking Alpha portfolio
-- IMPORTANT #2: dbl-chk "SeekingAlphaDte" as this will change over time!!
-- NOTE: Ingest MULTIPLE 'portfolio' file(s) b/c Seeking Alpha only
-- 			 allows 500 max symbols.  Also, ensures only UNIQUE symbols!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

-- Complete list of tickers in Seeking Alpha
DROP TABLE IF EXISTS Seeking_Alpha_CEF_portfolio_csv;

CREATE TABLE Seeking_Alpha_CEF_portfolio_csv AS
SELECT
    Symbol,
    Price,
    Change,
    "Change %" AS chgPct,
    "Yield TTM" AS yieldTTM,
    "Yield FWD" AS yieldFWD,
    Volume,
    "Avg. Vol" AS avgVol,
    "Ex-Div Date" AS exDivDte,
    "Payout Date" AS payoutDte,
    Frequency
FROM read_csv_auto(
    [
        '/Users/markdavis/Sync/CEFs/portfolios/daily_stuff/seeking_alpha_DAILY_CEFs.csv',
        '/Users/markdavis/Sync/CEFs/portfolios/daily_stuff/seeking_alpha_DAILY_Stocks.csv'
    ],
    header=true,
    all_varchar=true
)
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY Symbol
    ORDER BY Symbol
) = 1;

DESCRIBE Seeking_Alpha_CEF_portfolio_csv;
select * from Seeking_Alpha_CEF_portfolio_csv
order by Symbol;

------------------------------------------------------------------------------------------------
-- S E E K I N G _ A L P H A  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS Seeking_Alpha_CEF_portfolio;
CREATE TABLE Seeking_Alpha_CEF_portfolio (
	Symbol VARCHAR
	, SeekingAlphaDate VARCHAR
	, Price DECIMAL
	, Change DECIMAL
	, ChangePct DECIMAL
	, YieldTTM DECIMAL
	, YieldFWD DECIMAL
	, Volume INTEGER
	, AvgVol INTEGER
	, ExDivDate VARCHAR
	, PayoutDate VARCHAR
	, Frequency VARCHAR
	, PRIMARY KEY(symbol));
DESCRIBE Seeking_Alpha_CEF_portfolio;


-- sometimes, the field has wierd characters (i.e. $,%,+,-) that need to be filtered
INSERT OR IGNORE INTO Seeking_Alpha_CEF_portfolio BY NAME 
(
  SELECT 
	sa.Symbol as Symbol
	, current_date as SeekingAlphaDate
  , CASE 
  		WHEN trim(sa.Price)='-' then NULL
  		ELSE sa.Price
  	END as Price  
  , CASE 
  		WHEN trim(sa.Change)='-' then NULL
  		ELSE sa.Change
  	END as Change
  , CASE 
  		WHEN trim(sa.chgPct)='-' then NULL
  		ELSE cast(trim(sa.chgPct,'%') as decimal)
  	END as ChangePct  		
  , CASE 
  		WHEN trim(yieldTTM)='-' then NULL
  		ELSE cast(trim(sa.yieldTTM,'%') as decimal)
  	END as YieldTTM 
  , CASE 
  		WHEN trim(sa.yieldFWD)='-' then NULL
  		ELSE cast(trim(sa.yieldFWD,'%') as decimal)
  	END as YieldFWD   	
	, CASE 
			WHEN trim(sa.Volume)='-' then NULL
			ELSE cast(sa.Volume as decimal)
	  END as Volume	
	, CASE 
			WHEN trim(sa.avgVol)='-' then NULL
			ELSE cast(sa.avgVol as decimal)
	  END as AvgVol
	, sa.exDivDte as ExDivDate
	, sa.payoutDte as PayoutDate
	, sa.Frequency as Frequency
  FROM Seeking_Alpha_CEF_portfolio_csv sa
);
select * from Seeking_Alpha_CEF_portfolio
order by ChangePct asc;



---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-06__fidelity_SOLD_positions.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

-- #1 '257054233', 'Rollover IRA [Mark]'
DROP TABLE IF EXISTS fidelity__SOLD_RolloverIRA_Mark_csv;
CREATE TABLE fidelity__SOLD_RolloverIRA_Mark_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '257054233' as FidelityAcct, Profit, 'Rollover IRA [Mark]' as FidelityAcctName
	    FROM read_csv_auto (['/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/RolloverIRA_Mark_SOLD__*.csv'], delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
    WHERE AcquiredDate is NOT NULL;    
DESCRIBE fidelity__SOLD_RolloverIRA_Mark_csv;
select * from fidelity__SOLD_RolloverIRA_Mark_csv
order by SoldDate DESC;



-- #2 '236264601', 'Inherited IRA [Eleanor]'
DROP TABLE IF EXISTS fidelity__SOLD_InheritedIRA_Eleanor_csv;
CREATE TABLE fidelity__SOLD_InheritedIRA_Eleanor_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '236264601' as FidelityAcct, Profit, 'Inherited IRA [Eleanor]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_InheritedIRA_Eleanor_csv;
select * from fidelity__SOLD_InheritedIRA_Eleanor_csv;

COPY fidelity__SOLD_InheritedIRA_Eleanor_csv from '/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/InheritedIRA_Eleanor_SOLD__everything_combined.csv' (FORMAT CSV, HEADER false);
select * from fidelity__SOLD_InheritedIRA_Eleanor_csv;

UPDATE fidelity__SOLD_InheritedIRA_Eleanor_csv
SET FidelityAcct='236264601', FidelityAcctName='Inherited IRA [Eleanor]';
select * from fidelity__SOLD_InheritedIRA_Eleanor_csv;



-- #3 'Z03120502', 'Brokerage'
DROP TABLE IF EXISTS fidelity__SOLD_Brokerage_csv;
CREATE TABLE fidelity__SOLD_Brokerage_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, 'Z03120502' as FidelityAcct, Profit, 'Brokerage' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_Brokerage_csv;
select * from fidelity__SOLD_Brokerage_csv;



-- #4 '230668380', 'Roth IRA [Mark]'
DROP TABLE IF EXISTS fidelity__SOLD_RothIRA_Mark_csv;
CREATE TABLE fidelity__SOLD_RothIRA_Mark_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '230668380' as FidelityAcct, Profit, 'Roth IRA [Mark]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_RothIRA_Mark_csv;
select * from fidelity__SOLD_RothIRA_Mark_csv;

COPY fidelity__SOLD_RothIRA_Mark_csv from '/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/RothIRA_Mark_SOLD__everything_combined.csv' (FORMAT CSV, HEADER false);
select * from fidelity__SOLD_RothIRA_Mark_csv;

UPDATE fidelity__SOLD_RothIRA_Mark_csv
SET FidelityAcct='230668380', FidelityAcctName='Roth IRA [Mark]';
select * from fidelity__SOLD_RothIRA_Mark_csv;



-- #5 '241891742', 'Inherited Roth IRA [Alice]'
DROP TABLE IF EXISTS fidelity__SOLD_InheritedRothIRA_Alice_csv;
CREATE TABLE fidelity__SOLD_InheritedRothIRA_Alice_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '241891742' as FidelityAcct, Profit, 'Inherited Roth IRA [Alice]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_InheritedRothIRA_Alice_csv;
select * from fidelity__SOLD_InheritedRothIRA_Alice_csv;

COPY fidelity__SOLD_InheritedRothIRA_Alice_csv from '/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/InheritedRothIRA_Alice_SOLD__everything_combined.csv' (FORMAT CSV, HEADER false);
select * from fidelity__SOLD_InheritedRothIRA_Alice_csv;

UPDATE fidelity__SOLD_InheritedRothIRA_Alice_csv
SET FidelityAcct='241891742', FidelityAcctName='Inherited Roth IRA [Alice]';
select * from fidelity__SOLD_InheritedRothIRA_Alice_csv;



-- #6 '249363366', 'Inherited IRA [Alice]'
DROP TABLE IF EXISTS fidelity__SOLD_InheritedIRA_Alice_csv;
CREATE TABLE fidelity__SOLD_InheritedIRA_Alice_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '249363366' as FidelityAcct, Profit, 'Inherited IRA [Alice]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_InheritedIRA_Alice_csv;
select * from fidelity__SOLD_InheritedIRA_Alice_csv;

COPY fidelity__SOLD_InheritedIRA_Alice_csv from '/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/InheritedIRA_Alice_SOLD__everything_combined.csv' (FORMAT CSV, HEADER false);
select * from fidelity__SOLD_InheritedIRA_Alice_csv;

UPDATE fidelity__SOLD_InheritedIRA_Alice_csv
SET FidelityAcct='249363366', FidelityAcctName='Inherited IRA [Alice]';
select * from fidelity__SOLD_InheritedIRA_Alice_csv;


-- delete bad rows
DELETE FROM fidelity__SOLD_InheritedIRA_Alice_csv
WHERE AcquiredDate IS NULL OR TRIM(CAST(AcquiredDate AS VARCHAR)) = '';


-- #7 '230739689', 'Roth IRA [Suzanne]'
DROP TABLE IF EXISTS fidelity__SOLD_RothIRA_Suzanne_csv;
CREATE TABLE fidelity__SOLD_RothIRA_Suzanne_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '230739689' as FidelityAcct, Profit, 'Roth IRA [Suzanne]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_RothIRA_Suzanne_csv;
select * from fidelity__SOLD_RothIRA_Suzanne_csv;



-- #8 '258012719', 'Rollover IRA [Suzanne]'
DROP TABLE IF EXISTS fidelity__SOLD_RolloverIRA_Suzanne_csv;
CREATE TABLE fidelity__SOLD_RolloverIRA_Suzanne_csv AS 
		SELECT Symbol, Descr, AcquiredDate, SoldDate, Quantity, CostBasis, Proceeds
		, '258012719' as FidelityAcct, Profit, 'Rollover IRA [Suzanne]' as FidelityAcctName
	    FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/sold/seed__MONTHLY_Portfolio_Closed_Lots.csv', delim=',', header=true,
	    		columns={Symbol:VARCHAR, Descr:VARCHAR, AcquiredDate:DATE, SoldDate:DATE, Quantity:VARCHAR, CostBasis:VARCHAR, Proceeds:VARCHAR, ShortTermGainLoss:VARCHAR, Profit:VARCHAR},
	    		auto_type_candidates = ['VARCHAR', 'DATE'], null_padding=true)
	    WHERE AcquiredDate IS NOT NULL AND Symbol <> 'FAKE(000000000)';
DESCRIBE fidelity__SOLD_RolloverIRA_Suzanne_csv;
select * from fidelity__SOLD_RolloverIRA_Suzanne_csv;



DROP TABLE IF EXISTS fidelity_SOLD_setup;
CREATE TABLE fidelity_SOLD_setup(
	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR
	, Symbol VARCHAR
	, Qty DECIMAL
	, CostBasis DECIMAL
	, Proceeds DECIMAL
	, Profit DECIMAL
	, AcquiredDate DATE
	, SoldDate DATE	
	, SoldMonth_num INTEGER
	, SoldMonth VARCHAR
);
DESCRIBE fidelity_SOLD_setup;

INSERT INTO fidelity_SOLD_setup BY NAME 
(
  SELECT
  	sold.FidelityAcct as FidelityAcct
  , sold.FidelityAcctName as FidelityAcctName	
  , case 
			when trim(sold.Symbol[:9])='undefined' then sold.Symbol
			else trim(sold.Symbol[:length(sold.Symbol)-11])
	  end as Symbol
	, case 
			when trim(sold.Quantity)='n/a' then NULL
			when trim(sold.Quantity) ^@ '-' then cast(regexp_replace(trim(trim(sold.Quantity),'-'), '[,]', '') as decimal)*-1
			else cast(regexp_replace(trim(trim(sold.Quantity),'+'), '[,]', '') as decimal)
	  end as Qty	
	, case 
			when trim(sold.CostBasis)='n/a' then NULL
			when trim(sold.CostBasis) ^@ '-' then cast(regexp_replace(trim(trim(sold.CostBasis),'$-'), '[,]', '') as decimal)*-1
			else cast(regexp_replace(trim(trim(sold.CostBasis),'$+'), '[,]', '') as decimal)
	  end as CostBasis
	, case 
			when trim(sold.Proceeds)='n/a' then NULL
			when trim(sold.Proceeds) ^@ '-' then cast(regexp_replace(trim(trim(sold.Proceeds),'$-'), '[,]', '') as decimal)*-1
			else cast(regexp_replace(trim(trim(sold.Proceeds),'$+'), '[,]', '') as decimal)
	  end as Proceeds
	, case 
			when trim(sold.Profit)='n/a' then NULL
			when trim(sold.Profit) ^@ '-' then cast(regexp_replace(trim(trim(sold.Profit),'$-'), '[,]', '') as decimal)*-1
			else cast(regexp_replace(trim(trim(sold.Profit),'$+'), '[,]', '') as decimal)
	  end as Profit	  		  	
	, sold.AcquiredDate as AcquiredDate
	, sold.SoldDate as SoldDate
	, date_part('month', sold.SoldDate) as SoldMonth_num
	, case
			when date_part('month', sold.SoldDate)=1 then cast(date_part('year', sold.SoldDate) as varchar)||'Jan'
			when date_part('month', sold.SoldDate)=2 then cast(date_part('year', sold.SoldDate) as varchar)||'Feb'
			when date_part('month', sold.SoldDate)=3 then cast(date_part('year', sold.SoldDate) as varchar)||'Mar'
			when date_part('month', sold.SoldDate)=4 then cast(date_part('year', sold.SoldDate) as varchar)||'Apr'
			when date_part('month', sold.SoldDate)=5 then cast(date_part('year', sold.SoldDate) as varchar)||'May'
			when date_part('month', sold.SoldDate)=6 then cast(date_part('year', sold.SoldDate) as varchar)||'Jun'
			when date_part('month', sold.SoldDate)=7 then cast(date_part('year', sold.SoldDate) as varchar)||'Jly'
			when date_part('month', sold.SoldDate)=8 then cast(date_part('year', sold.SoldDate) as varchar)||'Aug'
			when date_part('month', sold.SoldDate)=9 then cast(date_part('year', sold.SoldDate) as varchar)||'Sep'
			when date_part('month', sold.SoldDate)=10 then cast(date_part('year', sold.SoldDate) as varchar)||'Oct'
			when date_part('month', sold.SoldDate)=11 then cast(date_part('year', sold.SoldDate) as varchar)||'Nov'
			when date_part('month', sold.SoldDate)=12 then cast(date_part('year', sold.SoldDate) as varchar)||'Dec'
			else NULL
		end as SoldMonth	
  FROM (
  	select * from fidelity__SOLD_RolloverIRA_Mark_csv
  	union by name
  	select * from fidelity__SOLD_InheritedIRA_Eleanor_csv
  	union by name
  	select * from fidelity__SOLD_Brokerage_csv
  	union by name
  	select * from fidelity__SOLD_RothIRA_Mark_csv
  	union by name
  	select * from fidelity__SOLD_InheritedRothIRA_Alice_csv
  	union by name
  	select * from fidelity__SOLD_InheritedIRA_Alice_csv
  	union by name
  	select * from fidelity__SOLD_RothIRA_Suzanne_csv
  	union by name
  	select * from fidelity__SOLD_RolloverIRA_Suzanne_csv   	
  ) sold
);
select *
from fidelity_SOLD_setup
order by FidelityAcct, Symbol, SoldDate;

select FidelityAcct, Symbol, SoldDate, SoldMonth, sum(Qty) as Qty
	,sum(CostBasis) as CostBasis, sum(Proceeds) as Proceeds
	, round(sum(CostBasis)/sum(Qty),2) as CostBasisPerShare
	, sum(Profit) as Profit
	, ROW_NUMBER() OVER (PARTITION BY FidelityAcct, Symbol ORDER BY SoldDate DESC) As RN	
from fidelity_SOLD_setup
group by FidelityAcct, Symbol, SoldDate, SoldMonth
order by FidelityAcct, Symbol,SoldDate;


------------------------------------------------------------------------------------------------
-- F I D E L I T Y _ S O L D   
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_SOLD;
CREATE TABLE fidelity_SOLD (
	Symbol VARCHAR
	, FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR
	, AvgCostBasisPerShare DECIMAL	
	, LowestCostBasisPerShare DECIMAL
	, HighestCostBasisPerShare DECIMAL
  , FirstSoldDate DATE
  , LastSoldDate DATE
	, FidelitySOLDTotalCount SMALLINT	
	, "SoldDate__(n)" DATE
	, "CostBasis__(n)" DECIMAL
	, "SoldDate__(n-1)" DATE
	, "CostBasis__(n-1)" DECIMAL
	, "SoldDate__(n-2)" DATE
	, "CostBasis__(n-2)" DECIMAL
	, "SoldDate__(n-3)" DATE
	, "CostBasis__(n-3)" DECIMAL		
	, "SoldDate__(n-4)" DATE
	, "CostBasis__(n-4)" DECIMAL	
	, "SoldDate__(n-5)" DATE
	, "CostBasis__(n-5)" DECIMAL
	, "SoldDate__(n-6)" DATE
	, "CostBasis__(n-6)" DECIMAL	
	, "SoldDate__(n-7)" DATE
	, "CostBasis__(n-7)" DECIMAL
	, "SoldDate__(n-8)" DATE
	, "CostBasis__(n-8)" DECIMAL
	, "SoldDate__(n-9)" DATE
	, "CostBasis__(n-9)" DECIMAL		
	);
DESCRIBE fidelity_SOLD;

DROP VIEW IF EXISTS v1;
CREATE VIEW v1 as   
SELECT Symbol
	, FidelityAcct
	, FidelityAcctName
	, SoldDate, SoldMonth, sum(Qty) as Qty
	, sum(CostBasis) as CostBasis, sum(Proceeds) as Proceeds
	, sum(Profit) as Profit
	, round(sum(CostBasis)/sum(Qty),2) as CostBasisPerShare
	, ROW_NUMBER() OVER (PARTITION BY FidelityAcct, Symbol ORDER BY SoldDate ASC) As RN
FROM
	fidelity_SOLD_setup 
group by Symbol, FidelityAcct, FidelityAcctName, SoldDate, SoldMonth;
select * from v1
order by FidelityAcct, FidelityAcctName, Symbol;


DROP VIEW IF EXISTS v2;
CREATE VIEW v2 as   
SELECT Symbol, FidelityAcct, FidelityAcctName, count(*) as FidelitySOLDTotalCount
from v1
group by Symbol, FidelityAcct, FidelityAcctName
order by Symbol, FidelityAcct, FidelityAcctName;
select * from v2
order by FidelityAcct, FidelityAcctName, Symbol;


INSERT INTO fidelity_SOLD BY NAME 
(
	SELECT v1.Symbol
    , v1.FidelityAcct
    , v1.FidelityAcctName
    , round(sum(CostBasis/Qty)/count(v1.Symbol),2) as AvgCostBasisPerShare
    , MIN(CostBasisPerShare) as LowestCostBasisPerShare
    , MAX(CostBasisPerShare) as HighestCostBasisPerShare
    , MIN(SoldDate) as FirstSoldDate
    , MAX(SoldDate) as LastSoldDate 
    , any_value(v2.FidelitySOLDTotalCount) as FidelitySOLDTotalCount
    , MAX(CASE RN WHEN FidelitySOLDTotalCount THEN SoldDate END) As "SoldDate__(n)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount THEN round(CostBasis/Qty,2) END) As "CostBasis__(n)"  
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-1 THEN SoldDate END) As "SoldDate__(n-1)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-1 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-1)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-2 THEN SoldDate END) As "SoldDate__(n-2)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-2 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-2)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-3 THEN SoldDate END) As "SoldDate__(n-3)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-3 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-3)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-4 THEN SoldDate END) As "SoldDate__(n-4)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-4 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-4)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-5 THEN SoldDate END) As "SoldDate__(n-5)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-5 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-5)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-6 THEN SoldDate END) As "SoldDate__(n-6)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-6 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-6)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-7 THEN SoldDate END) As "SoldDate__(n-7)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-7 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-7)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-8 THEN SoldDate END) As "SoldDate__(n-8)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-8 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-8)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-9 THEN SoldDate END) As "SoldDate__(n-9)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-9 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-9)"	    
	FROM v1 v1
	left outer join v2 v2
	on v1.FidelityAcct=v2.FidelityAcct
	and v1.Symbol=v2.Symbol
	--WHERE RN <= 5
	GROUP BY v1.FidelityAcct, v1.FidelityAcctName, v1.Symbol
	order by v1.FidelityAcct, v1.FidelityAcctName, v1.Symbol
);
select * from fidelity_SOLD 
order by FidelityAcct, Symbol;


-------------------------------------------------------------------------------------------------
-- F I D E L I T Y _ S O L D _ C O M B I N E _ A L L _ A C C O U N T s   
-------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_combine_ALL_accts_SOLD;
CREATE TABLE fidelity_combine_ALL_accts_SOLD (
	Symbol VARCHAR
	, AvgCostBasisPerShare DECIMAL	
	, LowestCostBasisPerShare DECIMAL
	, HighestCostBasisPerShare DECIMAL
  , FirstSoldDate DATE
  , LastSoldDate DATE
	, FidelitySOLDTotalCount SMALLINT	
	, "SoldDate__(n)" DATE
	, "CostBasis__(n)" DECIMAL
	, "SoldDate__(n-1)" DATE
	, "CostBasis__(n-1)" DECIMAL
	, "SoldDate__(n-2)" DATE
	, "CostBasis__(n-2)" DECIMAL
	, "SoldDate__(n-3)" DATE
	, "CostBasis__(n-3)" DECIMAL		
	, "SoldDate__(n-4)" DATE
	, "CostBasis__(n-4)" DECIMAL	
	, "SoldDate__(n-5)" DATE
	, "CostBasis__(n-5)" DECIMAL
	, "SoldDate__(n-6)" DATE
	, "CostBasis__(n-6)" DECIMAL	
	, "SoldDate__(n-7)" DATE
	, "CostBasis__(n-7)" DECIMAL
	, "SoldDate__(n-8)" DATE
	, "CostBasis__(n-8)" DECIMAL
	, "SoldDate__(n-9)" DATE
	, "CostBasis__(n-9)" DECIMAL		
	);
DESCRIBE fidelity_combine_ALL_accts_SOLD;

DROP VIEW IF EXISTS v1_combine_ALL_accts;
CREATE VIEW v1_combine_ALL_accts as   
SELECT Symbol
	, SoldDate, SoldMonth, sum(Qty) as Qty
	, sum(CostBasis) as CostBasis, sum(Proceeds) as Proceeds
	, sum(Profit) as Profit
	, round(sum(CostBasis)/sum(Qty),2) as CostBasisPerShare
	, ROW_NUMBER() OVER (PARTITION BY Symbol ORDER BY SoldDate ASC) As RN
FROM
	fidelity_SOLD_setup 
group by Symbol, SoldDate, SoldMonth;
select * from v1_combine_ALL_accts
order by Symbol;


DROP VIEW IF EXISTS v2_combine_ALL_accts;
CREATE VIEW v2_combine_ALL_accts as   
SELECT Symbol, count(*) as FidelitySOLDTotalCount
from v1_combine_ALL_accts
group by Symbol
order by Symbol;
select * from v2_combine_ALL_accts
order by Symbol;


INSERT INTO fidelity_combine_ALL_accts_SOLD BY NAME 
(
	SELECT v1.Symbol
    , round(sum(CostBasis/Qty)/count(v1.Symbol),2) as AvgCostBasisPerShare
    , MIN(CostBasisPerShare) as LowestCostBasisPerShare
    , MAX(CostBasisPerShare) as HighestCostBasisPerShare
    , MIN(SoldDate) as FirstSoldDate
    , MAX(SoldDate) as LastSoldDate 
    , any_value(v2.FidelitySOLDTotalCount) as FidelitySOLDTotalCount
    , MAX(CASE RN WHEN FidelitySOLDTotalCount THEN SoldDate END) As "SoldDate__(n)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount THEN round(CostBasis/Qty,2) END) As "CostBasis__(n)"  
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-1 THEN SoldDate END) As "SoldDate__(n-1)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-1 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-1)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-2 THEN SoldDate END) As "SoldDate__(n-2)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-2 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-2)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-3 THEN SoldDate END) As "SoldDate__(n-3)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-3 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-3)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-4 THEN SoldDate END) As "SoldDate__(n-4)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-4 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-4)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-5 THEN SoldDate END) As "SoldDate__(n-5)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-5 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-5)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-6 THEN SoldDate END) As "SoldDate__(n-6)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-6 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-6)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-7 THEN SoldDate END) As "SoldDate__(n-7)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-7 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-7)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-8 THEN SoldDate END) As "SoldDate__(n-8)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-8 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-8)"	    
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-9 THEN SoldDate END) As "SoldDate__(n-9)"
    , MAX(CASE RN WHEN FidelitySOLDTotalCount-9 THEN round(CostBasis/Qty,2) END) As "CostBasis__(n-9)"	    
	FROM v1_combine_ALL_accts v1
	left outer join v2_combine_ALL_accts v2
	on v1.Symbol=v2.Symbol
	--WHERE RN <= 5
	GROUP BY v1.Symbol
	order by v1.Symbol
);
select * from fidelity_combine_ALL_accts_SOLD 
order by Symbol;



------------------------------------------------------------------------------------------------
--Q U I C K   C H E C K  --- How many Fidelity Positions Sold of specific stock?
------------------------------------------------------------------------------------------------
with x as (
	select FidelityAcct, Symbol, SoldDate, sum(Profit) as Profit
	from fidelity_SOLD_setup
	group by FidelityAcct, Symbol, SoldDate
)
select FidelityAcct, Symbol, sum(Profit) as Profit, count(*) as cnt
from x
group by FidelityAcct, Symbol
having count(*)>2
order by Symbol;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-07__cef_activist.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--CEFs Activist Information + more...
DROP TABLE IF EXISTS cef_universe__activist_csv;
CREATE TABLE cef_universe__activist_csv AS 
	SELECT 
	Fund, Holder1_name, Holder1_Pct, Activist1, Holder2_name
	, Holder2_Pct, Activist2, Institutions_Pct, MutualFund_Holders
	, Institutional_shares
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/activist/CEF__activist_info.csv', delim=',', all_varchar=true);
DESCRIBE cef_universe__activist_csv;
select * from cef_universe__activist_csv; 


------------------------------------------------------------------------------------------------
-- C E F _ U N I V E R S E _ A C T I V I S T  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS cef_universe__activist;
CREATE TABLE cef_universe__activist (
	SYMBOL VARCHAR
	, HLDR1_NME VARCHAR
	, HLDR1_PCT DECIMAL
	, HLDR1_ACTVST_FLG VARCHAR
	, HLDR2_NME VARCHAR
	, HLDR2_PCT DECIMAL
	, HLDR2_ACTVST_FLG VARCHAR
	, INSTN_PCT DECIMAL
	, MUTUAL_FND_HLDRS DECIMAL
	, INSTN_SHARES DECIMAL
);
DESCRIBE cef_universe__activist;


-- we need to load the "all character" table into a table w/ varying datatypes.
INSERT INTO cef_universe__activist BY NAME 
(
  SELECT
	cef.Fund as SYMBOL
	, cef.Holder1_name as HLDR1_NME
	, cef.Holder1_Pct as HLDR1_PCT
	, cef.Activist1 as HLDR1_ACTVST_FLG
	, cef.Holder2_name as HLDR2_NME
	, cef.Holder2_Pct as HLDR2_PCT
	, cef.Activist2 as HLDR2_ACTVST_FLG
	, cef.Institutions_Pct as INSTN_PCT
	, cef.MutualFund_Holders as MUTUAL_FND_HLDRS
	, cef.Institutional_shares as INSTN_SHARES	
  FROM cef_universe__activist_csv cef
);
--select * from cef_universe__activist;


---------------------------------------------------------------------------------------------
-- Sort by Symbol  [show everything]
---------------------------------------------------------------------------------------------
select a.SYMBOL, a.HLDR1_NME, a.HLDR1_PCT, a.HLDR1_ACTVST_FLG
  , a.HLDR2_NME, a.HLDR2_PCT, a.HLDR2_ACTVST_FLG 
from cef_universe__activist a
order by a.SYMBOL; 


---------------------------------------------------------------------------------------------
-- If Any Duplicates?  C O R R E C T!!!
---------------------------------------------------------------------------------------------
--select SYMBOL, count(*) cnt
--from cef_universe__activist
--group by SYMBOL
--having count(*)>1
--order by SYMBOL;


-- REMOVE Duplicates? 
--DELETE FROM cef_universe__activist 
--WHERE SYMBOL = 'NIE';




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-08__cef_best_of_best.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- B E S T _ o f _ t h e _ B E S T !!!
-- Setup for Inherited Account(s)!!
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

-- high-high-low CEF/ETF Income
-- Chemist's "Triple-Factor" Closed-End Fund Report 
--	 (note: used to be named: "High-High-Low" CEF Report)
-- Symbols exist in at least 4 services!!
-- Steven Bavaria's 'CORE'  Income Factory
-- CEF/ETF Income Portfolio
-- Steven Bavaria's Personal Portfolio
DROP TABLE IF EXISTS tbl1;
CREATE TABLE tbl1 AS 
  WITH x AS (
	SELECT Symbol, 'CEF__high-high-low' as portfolioName, '1st' as importance
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/best_of_best/CEF__high-high-low.csv', delim=',', header=true, all_varchar=true)
	  UNION by name
    SELECT Symbol, 'CEF__placeholder' as portfolioName, '2nd' as importance
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/best_of_best/CEF__placeholder.csv', delim=',', header=true, all_varchar=true)
  )
  select *, RANK() OVER(PARTITION BY Symbol ORDER BY Importance) Rank
  from x;

DESCRIBE tbl1;
select * from tbl1
order by Symbol, Rank;



------------------------------------------------------------------------------------------------
-- Let's combine all 5 portfolio() together.  Only keep unique!!
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS best_of_the_best_CEFs;

CREATE TABLE best_of_the_best_CEFs (
	Symbol VARCHAR
	, portfolioName VARCHAR
	, PRIMARY KEY(Symbol)
);
DESCRIBE best_of_the_best_CEFs;


INSERT INTO best_of_the_best_CEFs BY NAME 
(
  SELECT
	cef.Symbol
	, cef.portfolioName	
  FROM tbl1 cef
  where cef.Symbol is not NULL 
  and cef.Rank=1
);
select * from best_of_the_best_CEFs
order by Symbol;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-09__cef_mastery_statistics.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- C E F _ M A S T E R Y
-- CEF Mastery provides immense amount of useful info!
-- The "score" & "final score" is most important.
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS cef_mastery_pivot_csv;
CREATE TABLE cef_mastery_pivot_csv AS 
	SELECT "_Fund" as Symbol, "Dist Type              & Freq" as distType, "Current Yield" as yield, "Asset Class" as assetClass
	, "Current Disc Prem" as discountPremium, "Hist Avg Discount Premium" as historicalDiscPrem
	, "Est Mo. Distr Rem" as mnthsDistrRem, "Debt to Equity" as debtToEquity
	, "Net Inv Inc to Distr" as NIItoDistrb, "NII/Real Gain to Distr" as NIIRealGaintoDistrb
	, Score as score, "Final Score" as finalScore
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/weekly_stuff/CEF_Mastery_071126__weekly.csv', delim=',', header=true, all_varchar=true);

DESCRIBE cef_mastery_pivot_csv;
select * from cef_mastery_pivot_csv
order by Symbol;



------------------------------------------------------------------------------------------------
-- C E F _ M A S T E R Y  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS cef_mastery_pivot_setup;
CREATE TABLE cef_mastery_pivot_setup (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, assetClass VARCHAR
	, discountPremium VARCHAR
	, historicalDiscPrem VARCHAR	
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR
	, NIItoDistrb VARCHAR
	, NIIRealGaintoDistrb VARCHAR
	, score INTEGER
	, finalScore INTEGER
	, PRIMARY KEY(symbol));
DESCRIBE cef_mastery_pivot_setup;

-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO cef_mastery_pivot_setup BY NAME 
(
  SELECT 
	cefmstry.Symbol as Symbol
  , cefmstry.distType as distType
  , cefmstry.yield as yield
  , cefmstry.assetClass as assetClass 
  , cefmstry.discountPremium as discountPremium
  , cefmstry.historicalDiscPrem	as historicalDiscPrem
  , CASE 
  		WHEN trim(cefmstry.mnthsDistrRem)='#N/A' then NULL
  		ELSE cefmstry.mnthsDistrRem
  	END as mnthsDistrRem
  , cefmstry.debtToEquity as debtToEquity	
  , cefmstry.NIItoDistrb	as NIItoDistrb
  , cefmstry.NIIRealGaintoDistrb	as NIIRealGaintoDistrb    
  , CASE 
  		WHEN trim(cefmstry.score)='#N/A' then NULL
  		ELSE cefmstry.score
  	END as score 
  , CASE 
  		WHEN trim(cefmstry.finalScore)='#N/A' then NULL
  		ELSE cefmstry.finalScore
  	END as finalScore  	 	 
  FROM cef_mastery_pivot_csv cefmstry
);
select * from cef_mastery_pivot_setup
order by Symbol asc;


------------------------------------------------------------------------------------------------
-- C E F _ M A S T E R Y  let's add 'color' logic 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS cef_mastery_pivot_tbl;
CREATE TABLE cef_mastery_pivot_tbl (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, assetClass VARCHAR
	, discountPremium VARCHAR
	, historicalDiscPrem VARCHAR
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR
	, NIItoDistrb VARCHAR
	, NIIRealGaintoDistrb VARCHAR		
	, score INTEGER
	, finalScore INTEGER
	, color VARCHAR
	, PRIMARY KEY(symbol));
DESCRIBE cef_mastery_pivot_tbl;


-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO cef_mastery_pivot_tbl BY NAME 
(
  SELECT 
	cefmstry.Symbol as Symbol
  , cefmstry.distType as distType
  , cefmstry.yield as yield
  , cefmstry.assetClass as assetClass
  , cefmstry.discountPremium as discountPremium	
  , cefmstry.historicalDiscPrem as historicalDiscPrem	
  , cefmstry.mnthsDistrRem as mnthsDistrRem
  , cefmstry.debtToEquity as debtToEquity	
  , cefmstry.NIItoDistrb as NIItoDistrb	
  , cefmstry.NIIRealGaintoDistrb as NIIRealGaintoDistrb 
  , cefmstry.score as score
  , cefmstry.finalScore as finalScore        
	, CASE 
			when cefmstry.finalScore is NULL then NULL
			when cefmstry.mnthsDistrRem<=-50 then 'RED!'
			when cefmstry.mnthsDistrRem<=-25 then 'red'
			when cefmstry.finalScore<0 then 'red'
			when cefmstry.finalScore<=19 and cefmstry.mnthsDistrRem<=-1 then 'yellow/distrb(-)'
			when cefmstry.finalScore<=19 then 'yellow'
			when cefmstry.finalScore<=25 and cefmstry.mnthsDistrRem<=-1 then 'YELLOW!/distrb(-)'
			when cefmstry.finalScore<=25 then 'YELLOW!'
			when cefmstry.finalScore<=99 and cefmstry.score<=25 and cefmstry.mnthsDistrRem<=-1 then 'green/distrb(-)'
			when cefmstry.finalScore<=99 and cefmstry.score<=25 then 'green'
			when cefmstry.finalScore<=99 and cefmstry.score>=26 and cefmstry.mnthsDistrRem<=-1 then 'GREEN!/distrb(-)'
			when cefmstry.finalScore<=99 and cefmstry.score>=26 then 'GREEN!'
			else '???'
		END as color   	 	 
  FROM cef_mastery_pivot_setup cefmstry
);
select * from cef_mastery_pivot_tbl
order by Symbol asc;
select * from cef_mastery_pivot_tbl
where color in ('GREEN!', 'green')
and Symbol not in ('IAF', 'MXF')   -- skip these 'country specific' CEFS
order by Symbol asc;



---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-10__etf_mastery_statistics.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- E T F _ M A S T E R Y
-- CEF Mastery provides immense amount of useful info!
-- The "score" & "final score" is most important.
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS etf_mastery_pivot_csv;
CREATE TABLE etf_mastery_pivot_csv AS 
	SELECT "_Fund" as Symbol, "Dist Type              & Freq" as distType, "Current Yield" as yield
	, "Current Disc Prem" as discountPremium, "Est Mo. Distr Rem" as mnthsDistrRem
	, "Debt to Equity" as debtToEquity
	, "Net Inv Inc to Distr" as NIItoDistrb, "NII/Real Gain to Distr" as NIIRealGaintoDistrb
	, Score as score, "Final Score" as finalScore	
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/weekly_stuff/ETF_Mastery_071126__weekly.csv', delim=',', header=true, all_varchar=true);

DESCRIBE etf_mastery_pivot_csv;
select * from etf_mastery_pivot_csv
order by Symbol;



------------------------------------------------------------------------------------------------
-- E T F _ M A S T E R Y  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS etf_mastery_pivot_setup;
CREATE TABLE etf_mastery_pivot_setup (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, discountPremium VARCHAR
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR
	, NIItoDistrb VARCHAR
	, NIIRealGaintoDistrb VARCHAR		
	, score INTEGER
	, finalScore INTEGER
	, PRIMARY KEY(symbol));
DESCRIBE etf_mastery_pivot_setup;

-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO etf_mastery_pivot_setup BY NAME 
(
  SELECT 
	etfmstry.Symbol as Symbol
  , etfmstry.distType as distType
  , etfmstry.yield as yield  
  , etfmstry.discountPremium as discountPremium	
  , CASE 
  		WHEN trim(etfmstry.mnthsDistrRem)='#N/A' then NULL
  		ELSE etfmstry.mnthsDistrRem
  	END as mnthsDistrRem
  , etfmstry.debtToEquity as debtToEquity	  	
  , etfmstry.NIItoDistrb as NIItoDistrb	  	
  , etfmstry.NIIRealGaintoDistrb as NIIRealGaintoDistrb	  	
  , CASE 
  		WHEN trim(etfmstry.score)='#N/A' then NULL
  		ELSE etfmstry.score
  	END as score 
  , CASE 
  		WHEN trim(etfmstry.finalScore)='#N/A' then NULL
  		ELSE etfmstry.finalScore
  	END as finalScore  	 	 
  FROM etf_mastery_pivot_csv etfmstry
);
select * from etf_mastery_pivot_setup
order by Symbol asc;


------------------------------------------------------------------------------------------------
-- E T F _ M A S T E R Y  let's add 'color' logic 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS etf_mastery_pivot_tbl;
CREATE TABLE etf_mastery_pivot_tbl (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, discountPremium VARCHAR
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR	
	, NIItoDistrb VARCHAR	
	, NIIRealGaintoDistrb VARCHAR	
	, score INTEGER
	, finalScore INTEGER
	, color VARCHAR
	, PRIMARY KEY(symbol));
DESCRIBE etf_mastery_pivot_tbl;


-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO etf_mastery_pivot_tbl BY NAME 
(
  SELECT 
	etfmstry.Symbol as Symbol
  , etfmstry.distType as distType
  , etfmstry.yield as yield
  , etfmstry.discountPremium as discountPremium	
  , etfmstry.mnthsDistrRem as mnthsDistrRem
  , etfmstry.debtToEquity as debtToEquity	  	  
  , etfmstry.NIItoDistrb as NIItoDistrb	  	  
  , etfmstry.NIIRealGaintoDistrb as NIIRealGaintoDistrb	  	  
  , etfmstry.score as score
  , etfmstry.finalScore as finalScore        
	, CASE 
			when etfmstry.finalScore is NULL then NULL
			when etfmstry.mnthsDistrRem<=-50 then 'RED!'
			when etfmstry.mnthsDistrRem<=-25 then 'red'
			when etfmstry.finalScore<0 then 'red'
			when etfmstry.finalScore<=19 and etfmstry.mnthsDistrRem<=-1 then 'yellow/distrb(-)'
			when etfmstry.finalScore<=19 then 'yellow'
			when etfmstry.finalScore<=25 and etfmstry.mnthsDistrRem<=-1 then 'YELLOW!/distrb(-)'
			when etfmstry.finalScore<=25 then 'YELLOW!'
			when etfmstry.finalScore<=99 and etfmstry.score<=25 and etfmstry.mnthsDistrRem<=-1 then 'green/distrb(-)'
			when etfmstry.finalScore<=99 and etfmstry.score<=25 then 'green'
			when etfmstry.finalScore<=99 and etfmstry.score>=26 and etfmstry.mnthsDistrRem<=-1 then 'GREEN!/distrb(-)'
			when etfmstry.finalScore<=99 and etfmstry.score>=26 then 'GREEN!'
			else '???'
		END as color   	 	 
  FROM etf_mastery_pivot_setup etfmstry
);
select * from etf_mastery_pivot_tbl
order by Symbol asc;
select * from etf_mastery_pivot_tbl
where color in ('GREEN!', 'green')
order by Symbol asc;


---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-11__bdc_mastery_statistics.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- C E F _ M A S T E R Y
-- CEF Mastery provides immense amount of useful info!
-- The "score" & "final score" is most important.
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS bdc_mastery_pivot_csv;
CREATE TABLE bdc_mastery_pivot_csv AS 
	SELECT column00 as Symbol, column01 as distType, column22 as yield
	, column09 as discountPremium, column21 as mnthsDistrRem
	, column12 as NIItoDistrb, column13 as NIIRealGaintoDistrb	
	, column11 as debtToEquity, column06 as score, column06 as finalScore		
	FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/weekly_stuff/BDC_Mastery_071126__weekly.csv', delim=',', header=false, skip=1, all_varchar=true);

DESCRIBE bdc_mastery_pivot_csv;
select * from bdc_mastery_pivot_csv;
--order by Symbol;



------------------------------------------------------------------------------------------------
-- B D C _ M A S T E R Y  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS bdc_mastery_pivot_setup;
CREATE TABLE bdc_mastery_pivot_setup (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, discountPremium VARCHAR
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR	
	, NIItoDistrb VARCHAR	
	, NIIRealGaintoDistrb VARCHAR	
	, score INTEGER
	, finalScore INTEGER
	, PRIMARY KEY(symbol));
DESCRIBE bdc_mastery_pivot_setup;

-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO bdc_mastery_pivot_setup BY NAME 
(
  SELECT 
	bdcmstry.Symbol as Symbol
  , bdcmstry.distType as distType
  , bdcmstry.yield as yield  
  , bdcmstry.discountPremium as discountPremium	
  , CASE 
  		WHEN trim(bdcmstry.mnthsDistrRem)='#N/A' then NULL
  		ELSE bdcmstry.mnthsDistrRem
  	END as mnthsDistrRem
  , bdcmstry.debtToEquity as debtToEquity
  , bdcmstry.NIItoDistrb as NIItoDistrb
  , bdcmstry.NIIRealGaintoDistrb as NIIRealGaintoDistrb  	
  , CASE 
  		WHEN trim(bdcmstry.score)='#N/A' then NULL
  		ELSE bdcmstry.score
  	END as score 
  , CASE 
  		WHEN trim(bdcmstry.finalScore)='#N/A' then NULL
  		ELSE bdcmstry.finalScore
  	END as finalScore  	 	 
  FROM bdc_mastery_pivot_csv bdcmstry
);
select * from bdc_mastery_pivot_setup
order by Symbol asc;


------------------------------------------------------------------------------------------------
-- B D C _ M A S T E R Y  let's add 'color' logic 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS bdc_mastery_pivot_tbl;
CREATE TABLE bdc_mastery_pivot_tbl (
	Symbol VARCHAR
	, distType VARCHAR
	, yield VARCHAR
	, discountPremium VARCHAR
	, mnthsDistrRem INTEGER
	, debtToEquity VARCHAR	
	, NIItoDistrb VARCHAR
	, NIIRealGaintoDistrb VARCHAR	
	, score INTEGER
	, finalScore INTEGER
	, color VARCHAR
	, PRIMARY KEY(symbol));
DESCRIBE bdc_mastery_pivot_tbl;


-- sometimes, the field has wierd characters (i.e. #N/A) that need to be filtered
INSERT OR IGNORE INTO bdc_mastery_pivot_tbl BY NAME 
(
  SELECT 
	bdcmstry.Symbol as Symbol
  , bdcmstry.distType as distType
  , bdcmstry.yield as yield
  , bdcmstry.discountPremium as discountPremium	
  , bdcmstry.mnthsDistrRem as mnthsDistrRem
  , bdcmstry.debtToEquity as debtToEquity	
  , bdcmstry.NIItoDistrb as NIItoDistrb	
  , bdcmstry.NIIRealGaintoDistrb as NIIRealGaintoDistrb	 	  
  , bdcmstry.score as score
  , bdcmstry.finalScore as finalScore        
	, CASE 
			when bdcmstry.finalScore is NULL then NULL
			when bdcmstry.mnthsDistrRem<=-50 then 'RED!'
			when bdcmstry.mnthsDistrRem<=-25 then 'red'
			when bdcmstry.finalScore<0 then 'red'
			when bdcmstry.finalScore<=19 and bdcmstry.mnthsDistrRem<=-1 then 'yellow/distrb(-)'
			when bdcmstry.finalScore<=19 then 'yellow'
			when bdcmstry.finalScore<=25 and bdcmstry.mnthsDistrRem<=-1 then 'YELLOW!/distrb(-)'
			when bdcmstry.finalScore<=25 then 'YELLOW!'
			when bdcmstry.finalScore<=99 and bdcmstry.score<=25 and bdcmstry.mnthsDistrRem<=-1 then 'green/distrb(-)'
			when bdcmstry.finalScore<=99 and bdcmstry.score<=25 then 'green'
			when bdcmstry.finalScore<=99 and bdcmstry.score>=26 and bdcmstry.mnthsDistrRem<=-1 then 'GREEN!/distrb(-)'
			when bdcmstry.finalScore<=99 and bdcmstry.score>=26 then 'GREEN!'
			else '???'
		END as color   	 	 
  FROM bdc_mastery_pivot_setup bdcmstry
);
select * from bdc_mastery_pivot_tbl
order by Symbol asc;
select * from bdc_mastery_pivot_tbl
where color in ('GREEN!', 'green')
or Symbol in ('PBDC', 'OBDC', 'ARCC', 'MAIN', 'CSWC')
or mnthsDistrRem>=0
order by Symbol asc;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-12__fidelity_BOUGHT_positions.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--Fidelity 'bought' Positions 
-- ATTN: 'old format'. For some reason, Fidelity changed the DATE 
-- format of this 'bought/sold' download file.  
DROP TABLE IF EXISTS fidelity_BOUGHT_SOLD_old_format_csv;
CREATE TABLE fidelity_BOUGHT_SOLD_old_format_csv AS 
	SELECT 
		"Run Date" as purchase_date
		, Account as fidelity_acct_name, "Account Number" as fidelity_acct
		, Action as action, Symbol as symbol, Description as name
		, Quantity as qty, "Price" as price, Fees as fees
		, Amount as amount, "Settlement Date" as settlement_date
  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/bought__sold/OLD_FORMAT/fidelity_BOUGHT_SOLD_all_accts__Y*Q*.csv', delim=',', header=true)
--  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/bought__sold/tstQ*.csv', delim=',', header=true)
  where Symbol is NOT NULL
;
DESCRIBE fidelity_BOUGHT_SOLD_old_format_csv;
select * from fidelity_BOUGHT_SOLD_old_format_csv;


--Fidelity 'bought' Positions 
-- ATTN: 'new format' as of 03/01/2025  (i.e. all_accts__Y2025Q2) 
DROP TABLE IF EXISTS fidelity_BOUGHT_SOLD_new_format_csv;
CREATE TABLE fidelity_BOUGHT_SOLD_new_format_csv AS 
	SELECT 
		"Run Date" as purchase_date
		, Account as fidelity_acct_name, "Account Number" as fidelity_acct
		, Action as action, Symbol as symbol, Description as name
		, Quantity as qty, "Price" as price, Fees as fees
		, Amount as amount, "Settlement Date" as settlement_date
  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/bought__sold/fidelity_BOUGHT_SOLD_all_accts__Y*Q*.csv', delim=',', header=true)
--  FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/bought__sold/tstQ*.csv', delim=',', header=true)
  where Symbol is NOT NULL
;
DESCRIBE fidelity_BOUGHT_SOLD_new_format_csv;
select * from fidelity_BOUGHT_SOLD_new_format_csv;


DROP TABLE IF EXISTS fidelity_BOUGHT_SOLD_csv;
CREATE TABLE fidelity_BOUGHT_SOLD_csv AS
SELECT * FROM fidelity_BOUGHT_SOLD_new_format_csv WHERE 1=0;

INSERT INTO fidelity_BOUGHT_SOLD_csv BY NAME 
(
select *
  FROM (
  	select * from fidelity_BOUGHT_SOLD_old_format_csv
  	union by name
  	select * from fidelity_BOUGHT_SOLD_new_format_csv
)
);
select * from fidelity_BOUGHT_SOLD_csv;


DROP TABLE IF EXISTS fidelity_BOUGHT;
CREATE TABLE fidelity_BOUGHT (
	purchase_date DATE
	, symbol VARCHAR
	, FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR		
	, price DECIMAL
	, qty DECIMAL
	, amount DECIMAL
);
DESCRIBE fidelity_BOUGHT;


-- What purchase were made?  "Complete List"
INSERT INTO fidelity_BOUGHT 
(
	select purchase_date, trim(symbol) as symbol, fidelity_acct, fidelity_acct_name
	, avg(CAST(price as decimal)) as price
	, sum(CAST(qty as decimal)) as qty
	, sum(CAST(amount as decimal)) as amount
	from fidelity_BOUGHT_SOLD_csv
	where trim(action) like 'YOU BOUGHT%'
	--and trim(symbol) in ('BUI', 'ARDC', 'UTG', 'ECC', 'PDI', 'PDO', 'TEI')
	group by fidelity_acct, fidelity_acct_name, symbol, purchase_date
	order by fidelity_acct, symbol, purchase_date desc
);

select * 
from fidelity_BOUGHT bought;


------------------------------------------------------------------------------------------------
-- Really ONLY care about the 'last time' Symbol was bought
-- Just another point of reference before purchasing again
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_last_time_BOUGHT;
CREATE TABLE fidelity_last_time_BOUGHT AS
	with x as (
	select * 
	, ROW_NUMBER() OVER (PARTITION BY Symbol, FidelityAcct ORDER BY purchase_date DESC) As RN
	from fidelity_BOUGHT bought
	order by FidelityAcct, symbol, purchase_date desc
	)
	select * from x
	-- if we don't filter by specific account here...
	-- we will get duplicate symbol(s) when joining to 
	-- the 'final report' in the next step
	left outer join fidelity_accounts
	on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
	-- we don't need to see "tiny" purchases, just "noise"
	and amount < -10.0
	and RN=1;
describe fidelity_last_time_BOUGHT;

select * from fidelity_last_time_BOUGHT
order by symbol;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-13__cef_FINAL_report.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: It's possible to change to different Fidelity accounts!
--               replace FidelityAcct around line#(s) 146 & 156
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
--'257054233'  -- Rollover IRA [Mark]
--'236264601'  -- Inherited IRA [Eleanor]

------------------------------------------------------------------------------------------------
-- C E F _ U N I V E R S E  [E X T E N D  B E H A V I O R] 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS combine_multiple_CEF_portfolios;
CREATE TABLE combine_multiple_CEF_portfolios (
  Symbol VARCHAR
	, AssetClass VARCHAR
	, AssetSubClass VARCHAR
	, Strategy VARCHAR
	, SponsorName VARCHAR
	, CategoryName VARCHAR
	, Risk SMALLINT
	, Leverage SMALLINT
	, "cef/etf/bdc" VARCHAR
	, CLO VARCHAR
	, Action VARCHAR	
	, TotSrvcs SMALLINT
	, SharedSrvcs VARCHAR			
	, Portfolio VARCHAR
	, CostYield DECIMAL
	, EffYield DECIMAL
	, YieldTTM DECIMAL
	, DistributionFrequency VARCHAR
	, AvgVol DECIMAL
	, Name VARCHAR	
	, Own VARCHAR	
	, Sold VARCHAR
	,	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR
  , FidelitySOLDTotalCount SMALLINT	
	, FirstSoldDate DATE 
	, LastSoldDate DATE 
	, "CostBasis__(n)" DECIMAL
	, "CostBasis__(n-1)" DECIMAL
	, "CostBasis__(n-2)" DECIMAL	
	, "CostBasis__(n-3)" DECIMAL
	, LastPurchasedDate DATE
	, LastPurchasedPrice DECIMAL
	, LastPurchasedAmt DECIMAL
	, "P/D" DECIMAL
	, ZScore3M DECIMAL	
	, ZScore6M DECIMAL
	, ZScore1Yr DECIMAL			
	, Comment VARCHAR
	, Flag VARCHAR
  , CurrPrc DECIMAL	
  , PrcChgPct DECIMAL
  , NAV DECIMAL  
	, AvgCostBasisPerShare DECIMAL
	, LowestCostBasisPerShare DECIMAL
	, FidelityStmtQty DECIMAL
  , "FidelityStmtValue$" DECIMAL	
  , "FidelityStmtTotCostBasis$" DECIMAL	
	, AcctPct DECIMAL	
	, "Today_G/L_Pct" DECIMAL
	, "Total_G/L_Amt" DECIMAL
	, "Total_G/L_Pct" DECIMAL		
	, Yr5_High DECIMAL  
	, Yr5_Low DECIMAL
	, Wk52_High DECIMAL
	, Wk52_Low DECIMAL
	, Wk52_Avg DECIMAL
	, ExDivDate VARCHAR
	, PayoutDate VARCHAR
	, cefMastery_score VARCHAR
	, cefMastery_finalScore VARCHAR
	, cefMastery_color VARCHAR
	, cefMastery_mnthsDistrRem VARCHAR
	, cefMastery_debtToEquity VARCHAR	
	, cefMastery_discPrem VARCHAR
	, cefMastery_NIItoDistrb VARCHAR
	, cefMastery_NIIRealGaintoDistrb VARCHAR
	, "best_of_best" VARCHAR
	, PRIMARY KEY(Symbol));
DESCRIBE combine_multiple_CEF_portfolios;



INSERT OR IGNORE INTO combine_multiple_CEF_portfolios BY NAME 
(
  SELECT 
		unvrs.Symbol as Symbol
		, case
				when unvrs."cef/etf/bdc" = 'cef' then cef_connect.AssetClass
				else unvrs.AssetClass
			end as AssetClass
		, case
				when unvrs."cef/etf/bdc" = 'cef' then cef_connect.AssetSubClass
				else unvrs.AssetSubClass
			end as AssetSubClass			
		, cef_connect.Strategy as Strategy
		, cef_connect.SponsorName as SponsorName
		, cef_connect.CategoryName as CategoryName	
		, cef_connect.Risk as Risk
		, cef_connect.LeverageRatioPercentage as Leverage	
		, unvrs."cef/etf/bdc" as "cef/etf/bdc"
		, unvrs.CLO as CLO
		, unvrs.Action as Action
		, unvrs.TotSrvcs as TotSrvcs
		, unvrs.SharedSrvcs as SharedSrvcs			
		, unvrs.Portfolio as Portfolio
		, FdltyYields.Yield_on_Cost as CostYield
		, FdltyYields.Effective_Yield as EffYield			
		, case 
				when cef_connect.DistributionRatePrice is NULL then alpha.YieldTTM
				else cef_connect.DistributionRatePrice
			end as YieldTTM
		, case 
				when cef_connect.DistributionFrequency is NULL then alpha.Frequency
				else cef_connect.DistributionFrequency
			end as DistributionFrequency
		, case
				when cef_connect.AvgDailyVolume is NULL then alpha.AvgVol
				else cef_connect.AvgDailyVolume
			end as AvgVol
		, case
				when unvrs."cef/etf/bdc" = 'cef' then cef_connect.Name
				else unvrs.Name
			end as Name			
		, case
				when fidelity.Symbol is not NULL then 'Own'
				else NULL
		  end as Own
		, case
				when sold.Symbol is not NULL then 'Sold'
				else NULL
		  end as Sold  
		, fidelity.FidelityAcct as FidelityAcct
		, fidelity.FidelityAcctName as FidelityAcctName
		, sold.FidelitySOLDTotalCount as FidelitySOLDTotalCount 
		, sold.FirstSoldDate as FirstSoldDate 
		, sold.LastSoldDate as LastSoldDate 	
		, sold."CostBasis__(n)" 
		, sold."CostBasis__(n-1)" 
		, sold."CostBasis__(n-2)"
		, sold."CostBasis__(n-3)"
		, bought.purchase_date as LastPurchasedDate
		, bought.price as LastPurchasedPrice 
		, bought.amount as LastPurchasedAmt
		, cef_connect.Discount as "P/D"
		, cef_connect.ZScore3M as ZScore3M
		, cef_connect.ZScore6M as ZScore6M
		, cef_connect.ZScore1Yr as ZScore1Yr	
		, unvrs.Comment as Comment
		, case
				when activist.HLDR1_ACTVST_FLG='Y' and activist.HLDR2_ACTVST_FLG='Y' then 'YY'
				when activist.HLDR1_ACTVST_FLG='Y' and activist.HLDR2_ACTVST_FLG is NULL then 'Y-'
				when activist.HLDR1_ACTVST_FLG is NULL and activist.HLDR2_ACTVST_FLG='Y' then '-Y'
				else '--'
		  end as Flag
		, case
				when fidelity.Symbol is NULL and alpha.Price is NULL then unvrs.CurrPrc			
				when fidelity.Symbol is NULL then alpha.Price
				else fidelity.FidelityStmtPrc
		  end as CurrPrc			  	
		, case
				when fidelity.Symbol is NULL and alpha.ChangePct is NULL then unvrs.PrcChgPct
				when fidelity.Symbol is NULL then alpha.ChangePct
				else fidelity.FidelityStmtPrcChg
		  end as PrcChgPct
		, cef_connect.NAV as NAV
		, case
				when fidelity.Symbol is NULL and sold.Symbol is NOT NULL then sold.AvgCostBasisPerShare
				when fidelity.Symbol is NOT NULL and sold.Symbol is NULL then fidelity.AvgCostBasis
				when fidelity.Symbol is NOT NULL and sold.Symbol is NOT NULL then (fidelity.AvgCostBasis + sold.LowestCostBasisPerShare) / 2
				else NULL
		  end as AvgCostBasisPerShare
		, case
				when fidelity.Symbol is NULL and sold.Symbol is NOT NULL then sold.LowestCostBasisPerShare
				when fidelity.Symbol is NOT NULL and sold.Symbol is NULL then fidelity.AvgCostBasis
				when fidelity.Symbol is NOT NULL and sold.Symbol is NOT NULL and sold.LowestCostBasisPerShare < fidelity.AvgCostBasis then sold.LowestCostBasisPerShare
				when fidelity.Symbol is NOT NULL and sold.Symbol is NOT NULL and fidelity.AvgCostBasis < sold.LowestCostBasisPerShare then fidelity.AvgCostBasis
				else NULL
		  end as LowestCostBasisPerShare		  
		, fidelity.FidelityStmtQty as FidelityStmtQty
		, fidelity.FidelityStmtValue as "FidelityStmtValue$" 
		, fidelity.TotCostBasis as "FidelityStmtTotCostBasis$" 
		, fidelity.AcctPct as	AcctPct
		, fidelity."Today_G/L_Pct" as "Today_G/L_Pct"
		, fidelity."Total_G/L_Amt" as "Total_G/L_Amt"
		, fidelity."Total_G/L_Pct" as "Total_G/L_Pct"
		, unvrs.Yr5_High as Yr5_High
		, unvrs.Wk52_High as Wk52_High
		, unvrs.Yr5_Low as Yr5_Low
		, unvrs.Wk52_Low as Wk52_Low
		, cef_connect.Price52WkAvg as Wk52_Avg
		, alpha.ExDivDate as ExDivDate
		, alpha.PayoutDate as PayoutDate 	
		, case 
				when cefMastery.score is not NULL then cefMastery.score
				when etfMastery.score is not NULL then etfMastery.score
				when bdcMastery.score is not NULL then bdcMastery.score
				else NULL
			end as cefMastery_score
		, case 
				when cefMastery.finalScore is not NULL then cefMastery.finalScore
				when etfMastery.finalScore is not NULL then etfMastery.finalScore
				when bdcMastery.finalScore is not NULL then bdcMastery.finalScore
				else NULL
			end as cefMastery_finalScore
		, case 
				when cefMastery.color is not NULL then cefMastery.color
				when etfMastery.color is not NULL then etfMastery.color
				when bdcMastery.color is not NULL then bdcMastery.color
				else NULL
			end as cefMastery_color
		, case 
				when cefMastery.mnthsDistrRem is not NULL then cefMastery.mnthsDistrRem
				when etfMastery.mnthsDistrRem is not NULL then etfMastery.mnthsDistrRem
				when bdcMastery.mnthsDistrRem is not NULL then bdcMastery.mnthsDistrRem
				else NULL
			end as cefMastery_mnthsDistrRem					
		, case 
				when cefMastery.debtToEquity is not NULL then cefMastery.debtToEquity
				when etfMastery.debtToEquity is not NULL then etfMastery.debtToEquity
				when bdcMastery.debtToEquity is not NULL then bdcMastery.debtToEquity
				else NULL
			end as cefMastery_debtToEquity
		, case 
				when cefMastery.discountPremium is not NULL then cefMastery.discountPremium
				when etfMastery.discountPremium is not NULL then etfMastery.discountPremium
				when bdcMastery.discountPremium is not NULL then bdcMastery.discountPremium
				else NULL
			end as cefMastery_discPrem
		, case 
				when cefMastery.NIItoDistrb is not NULL then cefMastery.NIItoDistrb
				when etfMastery.NIItoDistrb is not NULL then etfMastery.NIItoDistrb
				else NULL
			end as cefMastery_NIItoDistrb
		, case 
				when cefMastery.NIIRealGaintoDistrb is not NULL then cefMastery.NIIRealGaintoDistrb
				when etfMastery.NIIRealGaintoDistrb is not NULL then etfMastery.NIIRealGaintoDistrb
				else NULL
			end as cefMastery_NIIRealGaintoDistrb					 								
		, case
				when best_of_best.Symbol is not NULL then 'x'
				else NULL
			end as "best_of_best"	
  from cmplt_universe_of_srvcs unvrs
	left outer join (
			select f.* from fidelity_positions f
			left outer join fidelity_accounts
			on trim(FidelityAcct)=trim("FidelityAcct#")
			where trim(lower("selectedFidelityAcct#"))='x') fidelity 
	on unvrs.Symbol=fidelity.Symbol
	left outer join (
			select y.* from fidelity_yields y
			left outer join fidelity_accounts
			on trim(FidelityAcct)=trim("FidelityAcct#")
			where trim(lower("selectedFidelityAcct#"))='x') FdltyYields 
	on unvrs.Symbol=FdltyYields.Symbol	
	left outer join cef_connect_positions cef_connect
	on unvrs.Symbol=cef_connect.Symbol
	left outer join Seeking_Alpha_CEF_portfolio alpha
	on unvrs.Symbol=alpha.Symbol	
	left outer join cef_universe__activist activist
	on unvrs.Symbol=activist.Symbol
	left outer join cef_mastery_pivot_tbl cefMastery
	on unvrs.Symbol=cefMastery.Symbol
	left outer join etf_mastery_pivot_tbl etfMastery
	on unvrs.Symbol=etfMastery.Symbol	
	left outer join bdc_mastery_pivot_tbl bdcMastery
	on unvrs.Symbol=bdcMastery.Symbol	
	left outer join best_of_the_best_CEFs best_of_best 
	on unvrs.Symbol=best_of_best.Symbol
	left outer join fidelity_last_time_BOUGHT bought
	on unvrs.Symbol=bought.Symbol	
	left outer join fidelity_combine_ALL_accts_SOLD sold
	-- inspect 'specific' fidelity account for SOLD info
	--left outer join (
	--		select f.* from fidelity_SOLD f
	--		left outer join fidelity_accounts
	--		on trim(FidelityAcct)=trim("FidelityAcct#")
	--		where trim(lower("selectedFidelityAcct#"))='x') sold
	on unvrs.Symbol =sold.Symbol
	order by unvrs.Symbol, unvrs.AssetClass
);

select *
from combine_multiple_CEF_portfolios
order by Symbol;


DROP VIEW IF EXISTS calculate_DIFFERENCE;
CREATE VIEW calculate_DIFFERENCE as   
SELECT Symbol, CurrPrc
, AvgCostBasisPerShare, LowestCostBasisPerShare, Yr5_High, Wk52_High 
, Yr5_Low, Wk52_Low
, (Yr5_High + Yr5_Low) / 2 as Yr5_Avg
, case
		when Wk52_Avg > 0 then Wk52_Avg
		else (Wk52_High + Wk52_Low) / 2
	end as Wk52_Avg
, round(-(subtract(CurrPrc,AvgCostBasisPerShare) / nullif(abs(AvgCostBasisPerShare), 0)) * 100,2) as "AvgCostBasis%_Diff"
, round(-(subtract(CurrPrc,LowestCostBasisPerShare) / nullif(abs(LowestCostBasisPerShare), 0)) * 100,2) as "LowestCostBasis%_Diff"
, round(-(subtract(CurrPrc,Yr5_High) / nullif(abs(Yr5_High), 0)) * 100,2) as "Yr5_High%_Diff"
, round(-(subtract(CurrPrc,Wk52_High) / nullif(abs(Wk52_High), 0)) * 100,2) as "Wk52_High%_Diff"
, round(-(subtract(CurrPrc,Yr5_Low) / nullif(abs(Yr5_Low), 0)) * 100,2) as "Yr5_Low%_Diff"
, round(-(subtract(CurrPrc,Wk52_Low) / nullif(abs(Wk52_Low), 0)) * 100,2) as "Wk52_Low%_Diff"
, round(-(subtract(CurrPrc,Wk52_Avg) / nullif(abs(Wk52_Avg), 0)) * 100,2) as "Wk52_Avg%_Diff"
, round(((Yr5_High - Yr5_Low) / nullif((Yr5_High + Yr5_Low) / 2, 0)) * 100, 2) as "Yr5_RangeRatio%"
, case
		when Wk52_Avg > 0 then round(((Wk52_High - Wk52_Low) / Wk52_Avg) * 100, 2)
		else round(((Wk52_High - Wk52_Low) / nullif((Wk52_High + Wk52_Low) / 2, 0)) * 100, 2)
	end as "Wk52_RangeRatio%"
from combine_multiple_CEF_portfolios;
select * from calculate_DIFFERENCE
where Symbol in ('AWF', 'AWP')
order by Symbol;


------------------------------------------------------------------------------------------------
-- C E F _ U N I V E R S E  [B E T T E R  F O R M A T] 
------------------------------------------------------------------------------------------------
-- 
-- RR = "Range Ratio".  Measures price volatility. 
-- A range for a specific trading period is the highest and lowest prices traded within that time. 
-- 
DROP TABLE IF EXISTS cef_FINAL_report;
CREATE TABLE cef_FINAL_report (

  Symbol VARCHAR
	, AssetClass VARCHAR
	, AssetSubClass VARCHAR
	, Strategy VARCHAR
	, SponsorName VARCHAR
	, CategoryName VARCHAR
	, Risk SMALLINT	
	, Leverage SMALLINT
	, "cef/etf/bdc" VARCHAR
	, CLO VARCHAR
	, Action VARCHAR	
	, TotSrvcs SMALLINT
	, SharedSrvcs VARCHAR			
	, Portfolio VARCHAR
	, CostYield DECIMAL(18,2)
	, EffYield DECIMAL(18,2)
	, YieldTTM DECIMAL(18,2)	
	, DistributionFrequency VARCHAR
	, AvgVol BIGINT
	, Name VARCHAR	
	, Own VARCHAR	
	, Sold VARCHAR
	,	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR	
	, FidelitySOLDTotalCount SMALLINT	
	, FirstSoldDate DATE 
	, LastSoldDate DATE 
	, "CostBasis__(n)" DECIMAL
	, "CostBasis__(n-1)" DECIMAL
	, "CostBasis__(n-2)" DECIMAL
	, "CostBasis__(n-3)" DECIMAL	
	, LastPurchasedDate DATE
	, LastPurchasedPrice DECIMAL(18,2)
	, LastPurchasedAmt DECIMAL(18,0)		
	, "P/D" DECIMAL(18,2)
	, ZScore3M DECIMAL(18,2)	
	, ZScore6M DECIMAL(18,2)
	, ZScore1Yr DECIMAL(18,2)			
	, Comment VARCHAR
	, Flag VARCHAR
  , CurrPrc DECIMAL(18,2)
  , PrcChgPct DECIMAL(18,2)	
  , NAV DECIMAL(18,2)	
	, AvgCostBasisPerShare DECIMAL
	, LowestCostBasisPerShare DECIMAL	
	, FidelityStmtQty DECIMAL
  , "FidelityStmtValue$" DECIMAL(18,0)	
  , "FidelityStmtTotCostBasis$" DECIMAL(18,0)	
	, AcctPct DECIMAL(18,2)	
	, "Today_G/L_Pct" DECIMAL(18,2)
	, "Total_G/L_Amt" DECIMAL
	, "Total_G/L_Pct" DECIMAL(18,2)		
	, "trimProfit/Shr" DECIMAL(18,2)
	, "trimProfit/$" DECIMAL(18,0)
	, Yr5_High DECIMAL  
	, Yr5_Low DECIMAL
	, Wk52_High DECIMAL
	, Wk52_Low DECIMAL
	, Yr5_Avg DECIMAL	
	, Wk52_Avg DECIMAL				
  , "AvgCostBasis%_Diff" DECIMAL
  , "LowestCostBasis%_Diff" DECIMAL  
	, "Yr5_High%_Diff" DECIMAL 
	, "Wk52_High%_Diff" DECIMAL	 
	, "Yr5_Low%_Diff" DECIMAL
	, "Wk52_Low%_Diff" DECIMAL
	, "Yr5_Avg%_Diff" DECIMAL
	, "Wk52_Avg%_Diff" DECIMAL
	, "Yr5_RangeRatio%" DECIMAL
	, "Wk52_RangeRatio%" DECIMAL	
	, "*Avg Cost Basis*" VARCHAR
	, "*Lowest Cost Basis*" VARCHAR		
	, "*5-Yr High*" VARCHAR	
	, "*52-Wk High*" VARCHAR	
	, "*5-Yr Low*" VARCHAR	
	, "*52-Wk Low*" VARCHAR
	, "*5-Yr Avg*" VARCHAR
	, "*52-Wk Avg*" VARCHAR
	, "*5-Yr RR%" VARCHAR	
	, "*52-Wk RR%" VARCHAR			
	, ExDivDate VARCHAR
	, PayoutDate VARCHAR
	, cefMastery_score VARCHAR
	, cefMastery_finalScore VARCHAR
	, cefMastery_color VARCHAR
	, cefMastery_mnthsDistrRem VARCHAR
	, cefMastery_discPrem DECIMAL(18,2)	
	, cefMastery_debtToEquity VARCHAR	
	, cefMastery_NIItoDistrb VARCHAR
	, cefMastery_NIIRealGaintoDistrb VARCHAR
	, "best_of_best" VARCHAR
	, PRIMARY KEY(SYMBOL));
DESCRIBE cef_FINAL_report;

INSERT OR IGNORE INTO cef_FINAL_report BY NAME 
(
  SELECT 
		ext.Symbol
		, ext.AssetClass
		, ext.AssetSubClass
		, ext.Strategy
		, ext.SponsorName
		, ext.CategoryName
		, ext.Risk
		, ext.Leverage
		, ext."cef/etf/bdc"
		, ext.CLO
		, ext.Action
		, ext.TotSrvcs 
		, ext.SharedSrvcs		
		, ext.Portfolio
		, trunc(ext.CostYield, 2) as CostYield
		, trunc(ext.EffYield, 2) as EffYield
		, trunc(ext.YieldTTM, 2) as YieldTTM
		, ext.DistributionFrequency
		, cast(trunc(ext.AvgVol) as BIGINT) as AvgVol
		, ext.Name
		, ext.Own
		, ext.Sold
		, ext.FidelityAcct
		, ext.FidelityAcctName
		, ext.FidelitySOLDTotalCount
		, ext.FirstSoldDate
		, ext.LastSoldDate
		, ext."CostBasis__(n)" 
		, ext."CostBasis__(n-1)" 
		, ext."CostBasis__(n-2)"
		, ext."CostBasis__(n-3)"
		, ext.LastPurchasedDate 
		, trunc(ext.LastPurchasedPrice, 2) as LastPurchasedPrice
		, round(ext.LastPurchasedAmt, 0) as LastPurchasedAmt
		, trunc(ext."P/D", 2) as "P/D"
		, trunc(ext.ZScore3M, 2) as ZScore3M
		, trunc(ext.ZScore6M, 2) as ZScore6M
		, trunc(ext.ZScore1Yr, 2) as ZScore1Yr
		, ext.Comment
		, ext.Flag	 
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.AvgCostBasisPerShare AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."AvgCostBasis%_Diff" AS VARCHAR),'0')||'%)' as "*Avg Cost Basis*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.LowestCostBasisPerShare AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."LowestCostBasis%_Diff" AS VARCHAR),'0')||'%)' as "*Lowest Cost Basis*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.Yr5_High AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."Yr5_High%_Diff" AS VARCHAR),'0')||'%)' as "*5-Yr High*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.Wk52_High AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."Wk52_High%_Diff" AS VARCHAR),'0')||'%)' as "*52-Wk High*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.Yr5_Low AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."Yr5_Low%_Diff" AS VARCHAR),'0')||'%)' as "*5-Yr Low*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(ext.Wk52_Low AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."Wk52_Low%_Diff" AS VARCHAR),'0')||'%)' as "*52-Wk Low*"
		, rtrim(CAST(ext.CurrPrc AS VARCHAR),'0')||' --> '||rtrim(CAST(diff.Wk52_Avg AS VARCHAR),'0')||'   ('||rtrim(CAST(diff."Wk52_Avg%_Diff" AS VARCHAR),'0')||'%)' as "*52-Wk Avg*"
		, rtrim(CAST(diff."Yr5_RangeRatio%" AS VARCHAR),'0')||'%' as "*5-Yr RR%"
		, rtrim(CAST(diff."Wk52_RangeRatio%" AS VARCHAR),'0')||'%' as "*52-Wk RR%"
		, trunc(ext.CurrPrc, 2) as CurrPrc
		, trunc(ext.PrcChgPct, 2) as PrcChgPct
		, trunc(ext.NAV, 2) as NAV
		, ext.AvgCostBasisPerShare
		, ext.LowestCostBasisPerShare			
		, ext.FidelityStmtQty
		, round(ext."FidelityStmtValue$", 0) as "FidelityStmtValue$"
		, round(ext."FidelityStmtTotCostBasis$", 0) as "FidelityStmtTotCostBasis$"
		, trunc(ext.AcctPct, 2) as AcctPct
		, trunc(ext."Today_G/L_Pct", 2) as "Today_G/L_Pct"
		, ext."Total_G/L_Amt"
		, trunc(ext."Total_G/L_Pct", 2) as "Total_G/L_Pct"
		, case
				when ext.Own='Own' and ext."Total_G/L_Amt" > 0 then trunc(ext."Total_G/L_Amt" / nullif(ext.CurrPrc, 0), 2)
				else NULL
			end as "trimProfit/Shr"
		, ext.Yr5_High
		, ext.Wk52_High
		, ext.Yr5_Low
		, ext.Wk52_Low
		, diff.Yr5_Avg
		, diff.Wk52_Avg		
		, diff."AvgCostBasis%_Diff"
		, diff."LowestCostBasis%_Diff"							
		, diff."Yr5_High%_Diff"
		, diff."Wk52_High%_Diff"	
		, diff."Yr5_Low%_Diff"	
		, diff."Wk52_Low%_Diff"
		, diff."Wk52_Avg%_Diff"
		, diff."Yr5_RangeRatio%"
		, diff."Wk52_RangeRatio%"			
		, ext.ExDivDate
		, ext.PayoutDate
		, ext.cefMastery_score 
		, ext.cefMastery_finalScore 
		, ext.cefMastery_color 
		, ext.cefMastery_mnthsDistrRem 
		, ext.cefMastery_debtToEquity
		, trunc(try_cast(replace(replace(trim(ext.cefMastery_discPrem), '%', ''), ',', '') as DECIMAL(18,6)), 2) as cefMastery_discPrem
		, ext.cefMastery_NIItoDistrb
		, ext.cefMastery_NIIRealGaintoDistrb
		, ext."best_of_best"			
  from combine_multiple_CEF_portfolios ext
	left outer join (
		select Symbol, Yr5_Avg, Wk52_Avg
		, CASE WHEN isfinite("AvgCostBasis%_Diff") THEN "AvgCostBasis%_Diff" END as "AvgCostBasis%_Diff"
		, CASE WHEN isfinite("LowestCostBasis%_Diff") THEN "LowestCostBasis%_Diff" END as "LowestCostBasis%_Diff"
		, CASE WHEN isfinite("Yr5_High%_Diff") THEN "Yr5_High%_Diff" END as "Yr5_High%_Diff"
		, CASE WHEN isfinite("Wk52_High%_Diff") THEN "Wk52_High%_Diff" END as "Wk52_High%_Diff"
		, CASE WHEN isfinite("Yr5_Low%_Diff") THEN "Yr5_Low%_Diff" END as "Yr5_Low%_Diff"
		, CASE WHEN isfinite("Wk52_Low%_Diff") THEN "Wk52_Low%_Diff" END as "Wk52_Low%_Diff"
		, CASE WHEN isfinite("Wk52_Avg%_Diff") THEN "Wk52_Avg%_Diff" END as "Wk52_Avg%_Diff"
		, CASE WHEN isfinite("Yr5_RangeRatio%") THEN "Yr5_RangeRatio%" END as "Yr5_RangeRatio%"
		, CASE WHEN isfinite("Wk52_RangeRatio%") THEN "Wk52_RangeRatio%" END as "Wk52_RangeRatio%"
		from calculate_DIFFERENCE
	) diff
  on ext.Symbol=diff.Symbol
	order by ext.Symbol, ext.AssetClass
);
select *
from cef_FINAL_report
where Symbol in ('AWF', 'AWP')
order by Symbol;




------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- P L A Y G R O U N D
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
select Symbol, AssetClass, Risk, CostYield, EffYield, YieldTTm, PrcChgPct
, "Today_G/L_Pct", "Total_G/L_Pct", "trimProfit/Shr", "trimProfit/$"
, AcctPct, "FidelityStmtValue$" as "Acct$$"
, "FidelityStmtTotCostBasis$" as "AcctCostBasis$$"
, TotSrvcs, SharedSrvcs, Action, Own, CurrPrc
, 'Sold [x'||CAST(FidelitySOLDTotalCount AS VARCHAR)||']' as "[xSold]" 
, LastSoldDate --, FirstSoldDate
, LastPurchasedDate, LastPurchasedAmt, LastPurchasedPrice
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol, CLO
, cefMastery_score, cefMastery_finalScore
, cefMastery_color
, cefMastery_debtToEquity as debtToEq, cefMastery_mnthsDistrRem as distrRem	
, cefMastery_NIItoDistrb as NIItoDistrb, cefMastery_NIIRealGaintoDistrb as NIIRealGaintoDistrb
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, "best_of_best"		
, "*Avg Cost Basis*", "*Lowest Cost Basis*"
, "*5-Yr High*", "*52-Wk High*", "*5-Yr RR%", "*52-Wk RR%"
, DistributionFrequency as distrbFreq
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, Leverage
, "P/D", cefMastery_discPrem, CurrPrc, NAV
, ZScore1Yr, ZScore6M, ZScore3M
, AvgVol
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, FidelityAcctName, AssetClass
, AssetSubClass, Strategy, SponsorName, Comment, Flag
from cef_FINAL_report
where Symbol is NOT NULL 
and (
	action in ('BUY*', 'BUY', 'buy', 'Top5', 'Top10') 
	or (action in ('HOLD', 'vetted') and TotSrvcs>=2 and trim(SharedSrvcs) not like '%IFRI%')
	or (action in ('HOLD', 'vetted') and TotSrvcs>=3)
	)
--and LastSoldDate>='2024-10-01'	
--and (action in ('BUY', 'Top5', 'Top10', 'Top25') or (action in ('HOLD', 'vetted') and TotSrvcs>=2))
and (SponsorName <>'abrdn Inc.' or SponsorName is NULL)
and (AcctPct <= 0.75 or AcctPct is NULL) 
and ("Total_G/L_Pct"<=-0.01 or "Total_G/L_Pct" is NULL)
and ("AvgCostBasis%_Diff"<=-0.01 or "AvgCostBasis%_Diff" is NULL)
--and ("LowestCostBasis%_Diff"<=-0.01 or "LowestCostBasis%_Diff" is NULL)
and (trim(AssetSubClass) <> 'Municipal Municipal' or AssetSubClass is NULL)
and (trim(AssetClass) <> 'Muni' or AssetClass is NULL)
--and (LastPurchasedDate  <= '2025-01-26' or LastPurchasedDate is NULL)
--and (Risk<=7 or Risk is NULL )
--and FidelitySOLDTotalCount > 1
-- attn: negative 'cost basis' is good!
--and "AvgCostBasis%_Diff" <= 6.0
--and trim(SharedSrvcs) <>'IFRI' --avoid where IFRI is only recommendation
--and ((AssetClass in ('Income', 'Hybrid') and PrcChgPct < -0.20) or (AssetClass='Equity' and PrcChgPct < -0.50)) --and TotSrvcs>1))
--and AssetSubClass like '%CLO%'
--and trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--and trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--and best_of_best = 'x'
and (trim(SharedSrvcs) like '%cefMstry%' or trim(SharedSrvcs) like '%etfMstry%' or trim(SharedSrvcs) like '%bdcMstry%' or best_of_best = 'x')
and (trim(cefMastery_color) in ('GREEN!','green', 'YELLOW!', 'YELLOW!/distrb(-)', 'yellow/distrb(-)') or cefMastery_color is NULL)
--and trim(SharedSrvcs) like '%_wklyemail%'  --periodic IncomeLab email
--and trim(SharedSrvcs) like '%_generator%'  --IncomeLab [generator]
--and trim(SharedSrvcs) like '%_taxable%'  --IncomeLab [taxable]
--and trim(SharedSrvcs) like '%_tactical100%'  --IncomeLab [tactical income 100]
--and trim(SharedSrvcs) like '%_etfAlpha%'  --IncomeLab - ETF Alpha
--and trim(SharedSrvcs) like '%_INCwatch%'  --IncomeLab - Income Watchlist
--and trim(SharedSrvcs) like '%_EQwatch%'  --IncomeLab - Equity Watchlist
--and trim(SharedSrvcs) like '%CO%'  --Contrarian Outlook
--and trim(SharedSrvcs) like '%meffen%'  --Elizabeth Meffen portfolio
--and trim(SharedSrvcs) like '%allender%'  --Will Allender portfolio
--and trim(SharedSrvcs) like '%armchair%'  --Armchair
--and trim(SharedSrvcs) like '%FB%'  --Facebook
--and (lower(AssetSubClass) like 'utili%' or lower(AssetSubClass) like 'ener%')
--and Own='Own'
and (YieldTTm > 7.25 or YieldTTm is NULL)
--and (CostYield > 7.25 or CostYield is NULL)
--and "P/D" <13
--and "cef/etf/bdc"='cef'
--and "Wk52_RangeRatio%" >= 30
--and "Yr5_RangeRatio%" >= 30
--and (ZScore6M > -1.5 and ZScore6M < 1.5)
--and (ZScore1Yr > -1.5 and ZScore1Yr < 1.5)
and (DistributionFrequency <> 'Annually' or DistributionFrequency is NULL)
and (Action<>'AVOID' or Action is NULL) 
order by AssetClass desc, PrcChgPct;