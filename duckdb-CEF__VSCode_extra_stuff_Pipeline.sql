
INSTALL httpfs;
LOAD httpfs;

CREATE OR REPLACE MACRO fidelity_file() AS
    getvariable('fidelity_positions_CSV_file');


---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-20__fidelity_marketvalue_workingcapital.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- WORKNG CAPITAL Breakdown  --  costBasis + moneyMkt + pending activity
-- don't forget MARKET VALUE!!
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS fidelity_marketvalue_workingcapital;
CREATE TABLE fidelity_marketvalue_workingcapital (
	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR		
	, totCostBasis DECIMAL
	, moneyMkt DECIMAL
	, pending DECIMAL
	, workingCapital DECIMAL
	, mktValue DECIMAL
);
DESCRIBE fidelity_marketvalue_workingcapital;


-- Portfolio Service(s)  "Complete List"
INSERT INTO fidelity_marketvalue_workingcapital 
(
	with x as (
		select FidelityAcct, FidelityAcctName, sum(TotCostBasis) as totCostBasis
		from fidelity_positions
		group by FidelityAcct, FidelityAcctName
	),
	y as (
		select FidelityAcct, FidelityAcctName, Symbol, FidelityStmtValue as moneyMkt
		from fidelity_positions
		where trim(Symbol) like 'SPAXX%'
	),
	z as (
		select FidelityAcct, FidelityAcctName, Symbol, FidelityStmtValue as pending
		from fidelity_positions
		where trim(Symbol)='Pending Activity'
	),
	zz as (
		select FidelityAcct, FidelityAcctName, sum(FidelityStmtValue) as mktValue
		from fidelity_positions
		group by FidelityAcct, FidelityAcctName
	)
	select x.FidelityAcct, x.FidelityAcctName, x.totCostBasis, y.moneyMkt, coalesce(z.pending, 0) as pending, (x.totCostBasis + y.moneyMkt + coalesce(z.pending,0)) as workingCapital
			, zz.mktValue
	from x
	left outer join y
	on x.FidelityAcct=y.FidelityAcct
	left outer join z
	on x.FidelityAcct=z.FidelityAcct
	left outer join zz
	on x.FidelityAcct=zz.FidelityAcct
);

select wrkcptl.* 
from fidelity_marketvalue_workingcapital wrkcptl
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-21__fidelity_equity_vs_income_pct.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

------------------------------------------------------------------------------------------------
-- what pct of portfolio is equity .vs income?
------------------------------------------------------------------------------------------------
with x as (
	select f.FidelityAcct, f.FidelityAcctName, f.Symbol
	, case 
		when s.AssetClass is not NULL then s.AssetClass
		else cc.AssetClass
	end as AssetClass
	, f.AcctPct, f.TotCostBasis 
	, case 
		when f.TotCostBasis is NULL then f.FidelityStmtValue
		else f.TotCostBasis
	end as CostBasis
	from fidelity_positions f
	left outer join cmplt_universe_of_srvcs s
	on f.Symbol=s.Symbol
	left outer join cef_connect_positions cc
	on f.Symbol=cc.Symbol 
	--where trim(f.FidelityAcct)='257054233'  -- Rollover IRA [Mark]
	--where trim(f.FidelityAcct)='236264601'  -- 	Inherited IRA [Eleanor]
)
select FidelityAcct, FidelityAcctName, AssetClass, count(*) as totalPositions, sum(AcctPct) as TotAcctPct, sum(CostBasis) as TotCostBasis
from x
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
group by FidelityAcct, FidelityAcctName, AssetClass
order by FidelityAcct, FidelityAcctName, AssetClass;


------------------------------------------------------------------------------------------------
-- what are the positions I own other than equity & income?
------------------------------------------------------------------------------------------------
with x as (
	select f.FidelityAcct, f.FidelityAcctName, f.Symbol
	, case 
		when s.AssetClass is not NULL then s.AssetClass
		else cc.AssetClass
	end as AssetClass
	, f.AcctPct, f.TotCostBasis 
	, case 
		when f.TotCostBasis is NULL then f.FidelityStmtValue
		else f.TotCostBasis
	end as CostBasis
	from fidelity_positions f
	left outer join cmplt_universe_of_srvcs s
	on f.Symbol=s.Symbol
	left outer join cef_connect_positions cc
	on f.Symbol=cc.Symbol 
)
select FidelityAcct, FidelityAcctName, Symbol, AssetClass, AcctPct, CostBasis
from x
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
and AssetClass is NULL;


---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-22__fidelity_positions_MNTHLY_SNAPshot.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT #1: dbl-chk "input file" to get proper MONTHLY Fidelity statement!!
-- Every month, I take a snapshot. This can be used to 
-- determine working capital & market value for any given month!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

--Fidelity Positions 
DROP TABLE IF EXISTS fidelity_positions_MNTHLY_SNAPshot_csv;
CREATE TABLE fidelity_positions_MNTHLY_SNAPshot_csv AS 
	SELECT 
	"Account Number" as fidelity_acct, "Account Name" as fidelity_acct_name, Symbol as symbol, Description as name
	, Quantity as qty, "Last Price" as last_prc, "Last Price Change" as last_prc_chg
	, "Current Value" as curr_value, "Total Gain/Loss Dollar" as "tot_g/l_amt", "Total Gain/Loss Percent" as "tot_g/l_pct"
	, "Percent Of Account" as acct_pct, "Cost Basis Total" as tot_cost_basis, "Average Cost Basis" as avg_cost_basis
	, "Today's Gain/Loss Percent" as "today_g/l_pct"
  FROM read_csv_auto(fidelity_file(), delim=',', header=true, all_varchar=true)
  WHERE Symbol>'' or Symbol is not NULL 
;
DESCRIBE fidelity_positions_MNTHLY_SNAPshot_csv;
select * from fidelity_positions_MNTHLY_SNAPshot_csv;


------------------------------------------------------------------------------------------------
-- F I D E L I T Y _ P O S I T I O N S _ M N T H L Y  reconstruction 
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_positions_MNTHLY_SNAPshot;
CREATE TABLE fidelity_positions_MNTHLY_SNAPshot (
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
	, PRIMARY KEY(FidelityAcct, Symbol));
DESCRIBE fidelity_positions_MNTHLY_SNAPshot;


-- sometimes, the field has wierd characters (i.e. $,%,+,-) that need to be filtered
INSERT OR IGNORE INTO fidelity_positions_MNTHLY_SNAPshot BY NAME 
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
  FROM fidelity_positions_MNTHLY_SNAPshot_csv fp
);

select * from fidelity_positions_MNTHLY_SNAPshot
where FidelityAcctName='Rollover IRA [Mark]';

select mnthly.* 
from fidelity_positions_MNTHLY_SNAPshot mnthly
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- WORKNG CAPITAL Breakdown  --  costBasis + moneyMkt + pending activity
-- don't forget MARKET VALUE!!
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot;
CREATE TABLE fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot (
	FidelityAcct VARCHAR
	, FidelityAcctName VARCHAR		
	, totCostBasis DECIMAL
	, moneyMkt DECIMAL
	, pending DECIMAL
	, workingCapital DECIMAL
	, mktValue DECIMAL
);
DESCRIBE fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot;


-- Portfolio Service(s)  "Complete List"
INSERT INTO fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot 
(
	with x as (
		select FidelityAcct, FidelityAcctName, sum(TotCostBasis) as totCostBasis
		from fidelity_positions_MNTHLY_SNAPshot
		group by FidelityAcct, FidelityAcctName
	),
	y as (
		select FidelityAcct, FidelityAcctName, Symbol, FidelityStmtValue as moneyMkt
		from fidelity_positions_MNTHLY_SNAPshot
		where trim(Symbol) like 'SPAXX%'
	),
	z as (
		select FidelityAcct, FidelityAcctName, Symbol, FidelityStmtValue as pending
		from fidelity_positions_MNTHLY_SNAPshot
		where trim(Symbol)='Pending Activity'
	),
	zz as (
		select FidelityAcct, FidelityAcctName, sum(FidelityStmtValue) as mktValue
		from fidelity_positions_MNTHLY_SNAPshot
		group by FidelityAcct, FidelityAcctName
	)
	select x.FidelityAcct, x.FidelityAcctName, x.totCostBasis, y.moneyMkt, coalesce(z.pending, 0) as pending, (x.totCostBasis + y.moneyMkt + coalesce(z.pending,0)) as workingCapital
			, zz.mktValue
	from x
	left outer join y
	on x.FidelityAcct=y.FidelityAcct
	left outer join z
	on x.FidelityAcct=z.FidelityAcct
	left outer join zz
	on x.FidelityAcct=zz.FidelityAcct
);

select mnthly.* 
from fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot mnthly
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-23__fidelity_dividends.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

--Fidelity 'dividends' 
-- ATTN: 'old format'. For some reason, Fidelity changed the DATE 
-- format of this 'dividend' download file.  
DROP TABLE IF EXISTS fidelity_dividends_NEW_FORMAT_csv;
CREATE TABLE fidelity_dividends_NEW_FORMAT_csv AS 
SELECT 
"Run Date" as RunDate, Account, "Account Number" as AccountNum, Action
, Symbol, Description, Type, "Exchange Quantity" as exchgQty
,	"Exchange Currency" as exchgCurr, Quantity
, Currency as currency, Price, "Exchange Rate" as exchgRate
, Commission, Fees, "Accrued Interest" as interest
, Amount, "Settlement Date" as date
FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/dividends/dividends_Y*Q*.csv', delim=',', header=true)
;
DESCRIBE fidelity_dividends_NEW_FORMAT_csv;
select * from fidelity_dividends_NEW_FORMAT_csv;


--Fidelity 'dividends' 
-- ATTN: 'new format' as of 03/01/2025  (i.e. Y2025Q2) 
DROP TABLE IF EXISTS fidelity_dividends_1st_OLD_FORMAT_csv;
CREATE TABLE fidelity_dividends_1st_OLD_FORMAT_csv AS 
SELECT 
"Run Date" as RunDate, Account, "Account Number" as AccountNum, Action
, Symbol, Description, Type, "Exchange Quantity" as exchgQty
,	"Exchange Currency" as exchgCurr, Quantity
, Currency as currency, Price, "Exchange Rate" as exchgRate
, Commission, Fees, "Accrued Interest" as interest
, Amount, "Settlement Date" as date
FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/dividends/1st_OLD_FORMAT/dividends_Y*Q*.csv', delim=',', header=true)
;
DESCRIBE fidelity_dividends_1st_OLD_FORMAT_csv;
select * from fidelity_dividends_1st_OLD_FORMAT_csv;



--Fidelity 'dividends' 
-- ATTN: 'new format' as of Oct'25-Dec'25  (i.e. Y2025Q4) 
DROP TABLE IF EXISTS fidelity_dividends_2nd_OLD_FORMAT_csv;
CREATE TABLE fidelity_dividends_2nd_OLD_FORMAT_csv AS 
SELECT 
"Run Date" as RunDate, Account, "Account Number" as AccountNum, Action
, Symbol, Description, Type, "Exchange Quantity" as exchgQty
,	"Exchange Currency" as exchgCurr, Quantity
, Currency as currency, Price, "Exchange Rate" as exchgRate
, Commission, Fees, "Accrued Interest" as interest
, Amount, "Settlement Date" as date
FROM read_csv_auto ('/Users/markdavis/Sync/CEFs/portfolios/fidelity/MONTHLY/dividends/2nd_OLD_FORMAT/dividends_Y*Q*.csv', delim=',', header=true)
;
DESCRIBE fidelity_dividends_2nd_OLD_FORMAT_csv;
select * from fidelity_dividends_2nd_OLD_FORMAT_csv;



DROP TABLE IF EXISTS fidelity_dividends_csv;
CREATE TABLE fidelity_dividends_csv AS
SELECT * FROM fidelity_dividends_NEW_FORMAT_csv WHERE 1=0;

INSERT INTO fidelity_dividends_csv BY NAME 
(
select *
  FROM (
  	select * from fidelity_dividends_1st_OLD_FORMAT_csv
  	union by name
  	select * from fidelity_dividends_2nd_OLD_FORMAT_csv
  	union by name
  	select * from fidelity_dividends_NEW_FORMAT_csv
)
);
select * from fidelity_dividends_csv;


DROP TABLE IF EXISTS fidelity_dividends;
CREATE TABLE fidelity_dividends(
	Account VARCHAR
	, AccountNum VARCHAR
	, Action VARCHAR
	, Quantity DECIMAL
	, Amount DECIMAL(18,2)
	, RunDate DATE
	, YrMnth VARCHAR
	, DivMonth VARCHAR
);
DESCRIBE fidelity_dividends;
select * from fidelity_dividends;


INSERT INTO fidelity_dividends BY NAME 
(
  SELECT 
	div.Account as Account
	-- in 2025, the dividend .csv provided by Fidelity changed!
	-- they now provide the 'account' & 'account num' fields seperately.
	, case 
			when trim(cast(div.RunDate as string)[:4])=='2024' then right(div.Account,9)
			else div.AccountNum
		end as AccountNum
	, div.Action as Action
	, cast(trim(cast(div.Quantity as VARCHAR)) as DECIMAL(18,2)) as Quantity
	, cast(trim(cast(div.Amount as VARCHAR)) as DECIMAL(18,2)) as Amount
	, RunDate
	, trim(cast(div.RunDate as string)[:4])||trim(cast(div.RunDate as string)[6:7]) as YrMnth	
	, case
			when trim(cast(div.RunDate as string)[6:7])='01' then trim(cast(div.RunDate as string)[:4])||'Jan'
			when trim(cast(div.RunDate as string)[6:7])='02' then trim(cast(div.RunDate as string)[:4])||'Feb'
			when trim(cast(div.RunDate as string)[6:7])='03' then trim(cast(div.RunDate as string)[:4])||'Mar'
			when trim(cast(div.RunDate as string)[6:7])='04' then trim(cast(div.RunDate as string)[:4])||'Apr'
			when trim(cast(div.RunDate as string)[6:7])='05' then trim(cast(div.RunDate as string)[:4])||'May'
			when trim(cast(div.RunDate as string)[6:7])='06' then trim(cast(div.RunDate as string)[:4])||'Jun'
			when trim(cast(div.RunDate as string)[6:7])='07' then trim(cast(div.RunDate as string)[:4])||'Jly'
			when trim(cast(div.RunDate as string)[6:7])='08' then trim(cast(div.RunDate as string)[:4])||'Aug'
			when trim(cast(div.RunDate as string)[6:7])='09' then trim(cast(div.RunDate as string)[:4])||'Sep'
			when trim(cast(div.RunDate as string)[6:7])='10' then trim(cast(div.RunDate as string)[:4])||'Oct'
			when trim(cast(div.RunDate as string)[6:7])='11' then trim(cast(div.RunDate as string)[:4])||'Nov'
			when trim(cast(div.RunDate as string)[6:7])='12' then trim(cast(div.RunDate as string)[:4])||'Dec'
		end as DivMonth
  FROM fidelity_dividends_csv div
  WHERE Account is not NULL
);
select *
from fidelity_dividends;


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- DIVIDENDs by MONTH
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
DROP TABLE IF EXISTS fidelity_dividends_by_MONTH;
CREATE TABLE fidelity_dividends_by_MONTH (
	Account VARCHAR
	, AccountNum VARCHAR
	, YrMnth VARCHAR
	, DivMonth VARCHAR		
	, RunDate DATE
	, TotDividends DECIMAL(18,2)
);
DESCRIBE fidelity_dividends_by_MONTH;


-- Portfolio Service(s)  "Complete List"
INSERT INTO fidelity_dividends_by_MONTH 
(
with dividends as (
select Account, AccountNum, YrMnth
	, any_value(DivMonth) as DivMonth
	, any_value(RunDate) as RunDate
	, sum(Amount) as TotDividends
from fidelity_dividends
-- filter out SPAXX b/c Fidelity shows 'REINVESTMENT'
where (Quantity=0 or trim(Action) not like '%(SPAXX)%')
--and Account='Rollover IRA [Mark] 257054233'
group by Account, AccountNum, YrMnth
order by Account, AccountNum
)
select Account, AccountNum, YrMnth, DivMonth, RunDate, TotDividends
from dividends
);

select div.Account, div.AccountNum
	, div.YrMnth, div.DivMonth, div.TotDividends
from fidelity_dividends_by_MONTH div
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(AccountNum)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
order by YrMnth desc;	




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-24__fidelity_profit.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::


--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-- IMPORTANT: dbl-chk "FidelityAcct" as this might need to be changed!!
-- IMPORTANT: dbl-chk "FidelityAcctName" as this might need to be changed!!
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
DROP TABLE IF EXISTS fidelity_profit;
CREATE TABLE fidelity_profit AS
	select Symbol
		, FidelityAcct
		, FidelityAcctName				     
		, SoldDate, SoldMonth, SoldMonth_num, cast(sum(Qty) as DECIMAL(18,2)) as Qty
		,cast(sum(CostBasis) as DECIMAL(18,2)) as CostBasis, cast(sum(Proceeds) as DECIMAL(18,2)) as Proceeds
	    , cast(round((1-(sum(CostBasis)/nullif(sum(Proceeds), 0)))*100,2) as DECIMAL(18,2)) as "Profit%"
	    --, round((1-(sum(CostBasis/Proceeds)/count(Symbol)))*100,3) as "Profit%"
		, round(sum(CostBasis)/sum(Qty),2) as CostBasisPerShare
		, round(sum(Proceeds)/sum(Qty),2) as "Sold@PerShare"		
		, cast(sum(Profit) as DECIMAL(18,2)) as Profit
		, ROW_NUMBER() OVER (PARTITION BY Symbol ORDER BY SoldDate ASC) As RN
	FROM fidelity_SOLD_setup 
	group by Symbol, FidelityAcct, FidelityAcctName, SoldDate, SoldMonth, SoldMonth_num
;
describe fidelity_profit;

select * from fidelity_profit 
where SoldMonth='2026Jly'
order by Symbol, RN;




------------------------------------------------------------------------------------------------
--T O T A L  P R O F I T broken down by each specific CEF
------------------------------------------------------------------------------------------------
with total_profit_setup as (
	select p.Symbol, FidelityAcct, FidelityAcctName
		, sum(profit) as TotalProfit
		, count(*) as "[xSold]"
		, cast(sa.Price as DECIMAL(18,2)) as CurrentPrice		
		, round(sum(CostBasis/Qty)/count(p.Symbol),2) as AvgCostBasisPerShare
		--, round(sum(CostBasis)/sum(Qty),2) as AvgCostBasisPerShare2	
		, case 
			when min(CostBasisPerShare)=max(CostBasisPerShare) then NULL
			else min(CostBasisPerShare)
		end as minCostBaisPerShare
		, case 
			when min(CostBasisPerShare)=max(CostBasisPerShare) then NULL
			else max(CostBasisPerShare)
		end as maxCostBaisPerShare	
from fidelity_profit p
left outer join Seeking_Alpha_CEF_portfolio sa
on p.Symbol=sa.Symbol
group by p.Symbol, FidelityAcct, FidelityAcctName, sa.Price	
)	
select * 
, case 
	when CurrentPrice < AvgCostBasisPerShare then 'CurrPrc<AvgCost'
	when CurrentPrice >= AvgCostBasisPerShare then '--'
  end as "AvgvsPrc"	
from total_profit_setup 
order by Symbol;	


------------------------------------------------------------------------------------------------
--T O T A L  P R O F I T broken by MONTH
------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS fidelity_profit_by_MONTH;
CREATE TABLE fidelity_profit_by_MONTH AS
	select FidelityAcct
		, FidelityAcctName				     
		, SoldMonth
		, strftime(SoldDate, '%Y%m') as YrMnth	
		, sum(Profit) as TotalProfit
	FROM fidelity_profit 
	group by FidelityAcct, FidelityAcctName, SoldMonth, YrMnth
;	
describe fidelity_profit_by_MONTH;

select FidelityAcct, FidelityAcctName, SoldMonth, TotalProfit 
from fidelity_profit_by_MONTH
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
order by YrMnth desc;


------------------------------------------------------------------------------------------------
--T O T A L  P R O F I T   [ALL MONTHs]
------------------------------------------------------------------------------------------------
select FidelityAcct, FidelityAcctName, sum(TotalProfit) as TotalProfit
from fidelity_profit_by_MONTH
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
group by FidelityAcct, FidelityAcctName;




---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::
-- duckdbTBL-25__quick_reference.sql
---:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::-:::

------------------------------------------------------------------------------------------------
-- HOW HEALTHY? Which of the fund(s) I own are considered
-- healthy based on CEF Mastery criteria?
------------------------------------------------------------------------------------------------
select f.Symbol, m.score, m.finalScore, m.color, m.yield, m.discountPremium as "P/D"
, cast(f."Total_G/L_Pct" as DECIMAL(18,2)) as "Total_G/L_Pct"
, cast(f.TotCostBasis as DECIMAL(18,2)) as TotCostBasis
, cast(f.AcctPct as DECIMAL(18,2)) as AcctPct
, final.Leverage, final."cef/etf/bdc", m.assetClass, f.Name, f.FidelityAcctName
from fidelity_positions f
left outer join cef_mastery_pivot_tbl m 
on f.Symbol=m.Symbol
left outer join cef_FINAL_report final
on f.Symbol=final.Symbol
where trim(f.FidelityAcctName)='Rollover IRA [Mark]'
--and trim(m.color)<>'GREEN!'
and f.AcctPct>=0.50
order by f.FidelityAcctName, f.AcctPct desc, f.Symbol;

------------------------------------------------------------------------------------------------
-- Why did Dec'24 "totCostBasis" not increase from Nov'24?
-- So, let's compare Dec'24 to Jan'25. Jan'25 look correct!
------------------------------------------------------------------------------------------------
select * from fidelity_positions_MNTHLY_SNAPshot;
select f.Symbol
, cast(f.TotCostBasis as DECIMAL(18,2)) as TotCostBasis
, cast(f.FidelityStmtValue as DECIMAL(18,2)) as FidelityStmtValue
, cast(f.AcctPct as DECIMAL(18,2)) as AcctPct
, s.Symbol
, cast(s.TotCostBasis as DECIMAL(18,2)) as TotCostBasis
, cast(s.FidelityStmtValue as DECIMAL(18,2)) as FidelityStmtValue
, cast(s.AcctPct as DECIMAL(18,2)) as AcctPct
, f.Name, f.FidelityAcctName
, case 
	when f.TotCostBasis=s.TotCostBasis then NULL
	else 'ATTN!!'
end as Flag
from fidelity_positions f
left outer join fidelity_positions_MNTHLY_SNAPshot s
on f.Symbol=s.Symbol
where trim(f.FidelityAcctName)='Rollover IRA [Mark]'
and trim(s.FidelityAcctName)='Rollover IRA [Mark]'
order by f.Symbol;



------------------------------------------------------------------------------------------------
--
-- P O I N T - IN - T I M E
--
-- WORKNG CAPITAL & MRKT VALUE Breakdown  
--  costBasis + moneyMkt + pending activity
-- for example, what does my working capital look like right now?
------------------------------------------------------------------------------------------------
select wrkcptl.* REPLACE (
	cast(wrkcptl.totCostBasis as DECIMAL(18,2)) as totCostBasis
	, cast(wrkcptl.moneyMkt as DECIMAL(18,2)) as moneyMkt
	, cast(wrkcptl.pending as DECIMAL(18,2)) as pending
	, cast(wrkcptl.workingCapital as DECIMAL(18,2)) as workingCapital
	, cast(wrkcptl.mktValue as DECIMAL(18,2)) as mktValue
)
from fidelity_marketvalue_workingcapital wrkcptl
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';



------------------------------------------------------------------------------------------------
--
-- M O N T H L Y   S N A P S H O T
--
-- WORKNG CAPITAL & MRKT VALUE Breakdown
-- for example, what did things look like on Mar 31, 2025?  
------------------------------------------------------------------------------------------------
select mnthly.* REPLACE (
	cast(mnthly.totCostBasis as DECIMAL(18,2)) as totCostBasis
	, cast(mnthly.moneyMkt as DECIMAL(18,2)) as moneyMkt
	, cast(mnthly.pending as DECIMAL(18,2)) as pending
	, cast(mnthly.workingCapital as DECIMAL(18,2)) as workingCapital
	, cast(mnthly.mktValue as DECIMAL(18,2)) as mktValue
)
from fidelity_marketvalue_workingcapital_MNTHLY_SNAPshot mnthly
-- '257054233'  -- Rollover IRA [Mark]
-- '236264601'  -- 	Inherited IRA [Eleanor]
left outer join fidelity_accounts
on trim(FidelityAcct)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x';



------------------------------------------------------------------------------------------------
-- AWESOME!!  DIVIDENDs & PROFITS [total!!]
------------------------------------------------------------------------------------------------
select div.AccountNum, f.FidelityAcctNme,  sum(div.TotDividends) as TotDividends, sum(pft.TotalProfit) as TotalProfit, sum(coalesce(div.TotDividends, 0)+coalesce(pft.TotalProfit, 0)) as Total 
from fidelity_dividends_by_MONTH div
left outer join fidelity_profit_by_MONTH pft
on trim(div.AccountNum)=trim(pft.FidelityAcct) 
and trim(div.YrMnth)=trim(pft.YrMnth) 
left outer join fidelity_accounts f
on trim(div.AccountNum)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
group by div.AccountNum, f.FidelityAcctNme;

------------------------------------------------------------------------------------------------
-- AWESOME!!  DIVIDENDs & PROFITS  [together] by YEAR
------------------------------------------------------------------------------------------------
select div.AccountNum, f.FidelityAcctNme, substring(div.YrMnth,1,4) as Year, sum(div.TotDividends) as TotDividends, sum(pft.TotalProfit) as TotalProfit, sum(coalesce(div.TotDividends, 0)+coalesce(pft.TotalProfit, 0)) as Total 
from fidelity_dividends_by_MONTH div
left outer join fidelity_profit_by_MONTH pft
on trim(div.AccountNum)=trim(pft.FidelityAcct) 
and trim(div.YrMnth)=trim(pft.YrMnth) 
left outer join fidelity_accounts f
on trim(div.AccountNum)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
group by div.AccountNum, f.FidelityAcctNme, substring(div.YrMnth,1,4)
order by substring(div.YrMnth,1,4) desc;

------------------------------------------------------------------------------------------------
-- AWESOME!!  DIVIDENDs & PROFITS [together] by MONTH
------------------------------------------------------------------------------------------------
select div.AccountNum, f.FidelityAcctNme, div.DivMonth, div.TotDividends, pft.TotalProfit, coalesce(div.TotDividends, 0)+coalesce(pft.TotalProfit, 0) as Total 
from fidelity_dividends_by_MONTH div
left outer join fidelity_profit_by_MONTH pft
on trim(div.AccountNum)=trim(pft.FidelityAcct) 
and trim(div.YrMnth)=trim(pft.YrMnth) 
left outer join fidelity_accounts f
on trim(div.AccountNum)=trim("FidelityAcct#")
where trim(lower("selectedFidelityAcct#"))='x'
order by div.YrMnth desc;
