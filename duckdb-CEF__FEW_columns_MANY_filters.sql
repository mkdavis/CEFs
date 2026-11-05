------------------------------------------------------------------------------------------------
-- "F E W"  C O L U M N S  &  "M A N Y"  F I L T E R S
------------------------------------------------------------------------------------------------
select Symbol, AssetClass, AssetSubClass, CLO, EffYield, YieldTTm
, "Today_G/L_Pct", "Total_G/L_Pct"
, AcctPct, "FidelityStmtValue$" as "Acct$$"
, "FidelityStmtTotCostBasis$" as "AcctCostBasis$$"
, Action, cefMastery_discPrem as "P/D", ZScore1Yr 
, cefMastery_color as color, cefMastery_score as score, cefMastery_finalScore as finalScore
, cefMastery_debtToEquity as debtToEq, cefMastery_mnthsDistrRem as distrRem	
, cefMastery_NIItoDistrb as NIItoDistrb, cefMastery_NIIRealGaintoDistrb as NIIRealGaintoDistrb
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, "*Avg Cost Basis*", "*Lowest Cost Basis*"
, 'Sold [x'||CAST(FidelitySOLDTotalCount AS VARCHAR)||']' as "[xSold]" 
, LastSoldDate, LastPurchasedDate, cefMastery_finalScore
, "best_of_best" as "B_of_B"
, TotSrvcs, SharedSrvcs, Own, FidelityAcctName
from cef_FINAL_report
where Symbol is NOT NULL 
and (SponsorName <>'abrdn Inc.' or SponsorName is NULL)
and (DistributionFrequency <> 'Annually' or DistributionFrequency is NULL)
and (Action<>'AVOID' or Action is NULL) 
and (trim(AssetSubClass) <> 'Municipal Municipal' or AssetSubClass is NULL)
and (trim(AssetClass) <> 'Muni' or AssetClass is NULL)
--and (action in ('BUY', 'Top5', 'Top10', 'Top25') or (action in ('HOLD', 'vetted') and TotSrvcs>=2))
--and (AcctPct <= 0.50 or AcctPct is NULL) 
--and ("Total_G/L_Pct"<=-0.01 or "Total_G/L_Pct" is NULL)
--and ("AvgCostBasis%_Diff"<=-0.01 or "AvgCostBasis%_Diff" is NULL)
--and EffYield > 5.00 
--and ("LowestCostBasis%_Diff"<=-0.01 or "LowestCostBasis%_Diff" is NULL)
--and (trim(AssetClass) <> 'Muni' or AssetClass is NULL)
--and (LastPurchasedDate  <= '2025-01-31' or LastPurchasedDate is NULL)
--and Own='Own'
--and (Risk<=7 or Risk is NULL )
--and FidelitySOLDTotalCount > 1
-- attn: negative 'cost basis' is good!
--and "AvgCostBasis%_Diff" <= 6.0
--and trim(SharedSrvcs) <>'IFRI' --avoid where IFRI is only recommendation
--and ((AssetClass in ('Income', 'Hybrid') and PrcChgPct < -0.20) or (AssetClass='Equity' and PrcChgPct < -0.50)) --and TotSrvcs>1))
--and AssetSubClass like '%CLO%'
--and trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--and trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--and trim(SharedSrvcs) like '%bdcMstry%'  --BDC Masters
--and best_of_best = 'x'
--and (trim(cefMastery_color) in ('GREEN!','green', 'YELLOW!', 'YELLOW!/distrb(-)', 'yellow/distrb(-)') or cefMastery_color is NULL)
and trim("cef/etf/bdc")='cef'
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
--and (EffYield > 7.25 or EffYield is NULL)
--and "P/D" <13
--and "cef/etf/bdc"='cef'
--and Wk52_RangePct <= 85
--and Yr5_RangePct <= 65
--and (ZScore6M > -1.5 and ZScore6M < 1.5)
--and (ZScore1Yr > -1.5 and ZScore1Yr < 1.5)
--and symbol in ('BXSY')
--order by AssetClass desc, PrcChgPct;
order by "Total_G/L_Pct";