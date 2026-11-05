------------------------------------------------------------------------------------------------
-- "M A N Y"  C O L U M N S  &  "F E W"  F I L T E R S
------------------------------------------------------------------------------------------------
select Symbol, AssetClass, Risk, EffYield, YieldTTm
, CLO, PrcChgPct
, "Today_G/L_Pct", "Total_G/L_Pct"
, AcctPct, "FidelityStmtValue$" as "Acct$$"
, "FidelityStmtTotCostBasis$" as "AcctCostBasis$$"
, TotSrvcs, SharedSrvcs, Action, Own, CurrPrc
, 'Sold [x'||CAST(FidelitySOLDTotalCount AS VARCHAR)||']' as "[xSold]" 
, LastSoldDate --, FirstSoldDate
, LastPurchasedDate, LastPurchasedAmt, LastPurchasedPrice
, Symbol||' ['||"cef/etf/bdc"||']' as Symbol
, cefMastery_color as color, cefMastery_score as score, cefMastery_finalScore as finalScore
, cefMastery_debtToEquity as debtToEq, cefMastery_mnthsDistrRem as distrRem	
, cefMastery_NIItoDistrb as NIItoDistrb, cefMastery_NIIRealGaintoDistrb as NIIRealGaintoDistrb
, "best_of_best"		
, "*Avg Cost Basis*", "*Lowest Cost Basis*"
, "*5-Yr High*", "*52-Wk High*", "*5-Yr RR%", "*52-Wk RR%"
, DistributionFrequency as DistributionFreq
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, Leverage, "P/D", CurrPrc, NAV
, ZScore1Yr, ZScore6M, ZScore3M
, AvgVol, "FidelityStmtTotCostBasis$"
, Symbol || COALESCE(' [' || "cef/etf/bdc" || ']', '') as Symbol
, FidelityAcctName, AssetClass
, AssetSubClass, Strategy, SponsorName, Comment, Flag
from cef_FINAL_report
where Symbol is NOT NULL 
and (SponsorName <>'abrdn Inc.' or SponsorName is NULL)
and (DistributionFrequency <> 'Annually' or DistributionFrequency is NULL)
and (Action<>'AVOID' or Action is NULL) 
and (trim(AssetSubClass) <> 'Municipal Municipal' or AssetSubClass is NULL)
and (trim(AssetClass) <> 'Muni' or AssetClass is NULL)
--and Own='Own'
--and trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--and trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--and trim(SharedSrvcs) like '%bdcMstry%'  --BDC Masters
--and best_of_best = 'x'
--and (
--    trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--    or trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--    or trim(SharedSrvcs) like '%bdcMstry%'  --BDC Masters
--    or best_of_best = 'x'
--  )
--and trim(SharedSrvcs) like '%core%'  --core
--and trim(SharedSrvcs) like '%CO%'  --Contrarian Outlook portfolio
--and trim(SharedSrvcs) like '%meffen%'  --Elizabeth Meffen portfolio
order by AssetClass desc, PrcChgPct;