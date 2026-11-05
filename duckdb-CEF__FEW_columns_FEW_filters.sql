------------------------------------------------------------------------------------------------
-- F E W  C O L U M N S  &  F E W  F I L T E R S
------------------------------------------------------------------------------------------------
select Symbol, AssetClass, AssetSubClass, CLO, EffYield, YieldTTm
, "Today_G/L_Pct", "Total_G/L_Pct"
, AcctPct, "FidelityStmtValue$" as "Acct$$"
, "FidelityStmtTotCostBasis$" as "AcctCostBasis$$"
, Action, cefMastery_discPrem as "P/D", ZScore1Yr 
, cefMastery_color as color
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
--and Own='Own'
--and (trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--or trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--or trim(SharedSrvcs) like '%bdcMstry%')  --BDC Masters
--and (
--    trim(SharedSrvcs) like '%cefMstry%'  --CEF Masters
--    or trim(SharedSrvcs) like '%etfMstry%'  --ETF Masters
--    or trim(SharedSrvcs) like '%bdcMstry%'  --BDC Masters
--    or best_of_best = 'x'
--  )
--and best_of_best = 'x'
--and trim(SharedSrvcs) like '%core%'  --core
--and trim(SharedSrvcs) like '%CO%'  --Contrarian Outlook portfolio
--and trim(SharedSrvcs) like '%meffen%'  --Elizabeth Meffen portfolio
and Symbol in ('HIO', 'FSCO', 'RMT', 'MCI', 'IDP', 'USA', 'DNP', 'PTY', 'PDI', 'HY', 'MCN', 'VVR')
order by AssetClass desc, PrcChgPct;