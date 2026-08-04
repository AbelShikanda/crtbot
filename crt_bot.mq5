//+------------------------------------------------------------------+
//|                           crtbot.mq5                             |
//|                    Enhanced Trading EA with                      |
//|                    PROGRESSIVE SCENARIO SYSTEM                   |
//|                    + TREND MANAGER INTEGRATION                   |
//|                    + SIMPLE WEIGHTED SYSTEM                     |
//|                    + DYNAMIC CONFIDENCE THRESHOLDS              |
//|                    + PORTFOLIO MANAGER INTEGRATION              |
//|                    + BOOST-AWARE TP TRAILING                    |
//|                    + v3.48: CANDLE MODULE INTEGRATED           |
//|                    + v4.0: POSITIONMANAGER SELF-CONTAINED     |
//|                    + REMOVED: Pullback, RR Check, TP Calc     |
//|                    + CHECKS: 11 → 8 (27% reduction)           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "4.0"
#property strict

// ============================================================
// INCLUDES
// ============================================================
#include <Trade\Trade.mqh>

#include "include/Headers/Enums.mqh"
#include "include/Headers/Structures.mqh"
#include "include/Headers/Inputs.mqh"

// Logger Module
#include "include/Utils/Logger.mqh"

// Data Modules
#include "include/Data/AdxModule.mqh"
#include "include/Data/MacdModule.mqh"
#include "include/Data/RsiModule.mqh"
#include "include/Data/VolumeModule.mqh"
#include "include/Data/MtfModule.mqh"
#include "include/Data/PullbackModule.mqh"
#include "include/Data/CandleModule.mqh"

// Managers
#include "include/PackageManagers/TrendManager.mqh"
#include "include/PackageManagers/PositionManager.mqh"
#include "include/PackageManagers/Riskmanager.mqh"
#include "include/PackageManagers/PortfolioManager.mqh"
#include "include/PackageManagers/ComponentManager.mqh"
#include "include/PackageManagers/SessionManager.mqh"

// Core Modules
#include "include/Core/Dashboard.mqh"
#include "include/Core/ChartModule.mqh"
#include "include/Data/OrderblockModule.mqh"
#include "include/Core/ScenarioNarrative.mqh"

// ============================================================
// GLOBAL DEBUG TOGGLES
// ============================================================
bool g_debugMode = false;
bool g_debugMain = false;
bool g_debugTrend = false;
bool g_debugPortfolio = false;
bool g_debugPosition = false;
bool g_debugRisk = false;
bool g_debugComponent = false;
bool g_debugPullback = false;
bool g_debugSession = false;
bool g_debugOrderBlock = false;
bool g_debugCandle = false;

// ============================================================
// GLOBAL VARIABLES
// ============================================================
CPullbackModule   *g_pullback = NULL;
CPositionManager  *g_positionManager = NULL;
CRiskManager      *g_riskManager = NULL;
CPortfolioManager *g_portfolioManager = NULL;
CComponentManager *g_componentManager = NULL;
CTrendManager     *g_trendManager = NULL;
CSessionManager   *g_sessionManager = NULL;
COrderBlockDisplay *g_orderBlockDisplay = NULL;
CCandleModule     *g_candleModule = NULL;
CTrade             g_trade;
int                g_magicNumber;
datetime           g_lastBarTime = 0;

CChartModule*          g_chartModule = NULL;
CDashboard*           g_dashboard = NULL;
ScenarioNarrative*    g_scenarioNarrative = NULL;

// Trend logging control
datetime           g_lastTrendLog = 0;
int                g_weakCounter = 0;
int                g_rangeCounter = 0;
int                g_lowStrengthCounter = 0;
int                g_notStrongCounter = 0;
int                g_neutralCounter = 0;

// Portfolio logging control
datetime           g_lastPortfolioLog = 0;

// ============================================================
// ═══ RISK MANAGER STATUS FOR DASHBOARD ═══
// ============================================================
string g_riskStatusMessage = "Ready";
bool   g_riskCanTrade = true;

// ============================================================
// INITIALIZATION STATUS TRACKING
// ============================================================
enum EInitStatus
{
   INIT_STATUS_NOT_STARTED,
   INIT_STATUS_TREND_MANAGER,
   INIT_STATUS_COMPONENT_MANAGER,
   INIT_STATUS_PULLBACK,
   INIT_STATUS_SESSION_MANAGER,
   INIT_STATUS_ORDER_BLOCK_DISPLAY,
   INIT_STATUS_CANDLE_MODULE,
   INIT_STATUS_COMPLETE
};

EInitStatus g_initStatus = INIT_STATUS_NOT_STARTED;
int         g_initAttempts = 0;
datetime    g_lastInitAttempt = 0;
bool        g_initializationFailed = false;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Logger::Initialize();
   
   LOG_INFO("=== PULLBACK EA v4.0 (POSITIONMANAGER SELF-CONTAINED) ===", g_debugMain);
   LOG_INFO("   Boost TP Distance: 100 points (when boost active)", g_debugMain);
   LOG_INFO("   TP never moves backward", g_debugMain);
   LOG_INFO("   SL/TP: MANAGED BY POSITIONMANAGER (Hybrid Structure)", g_debugMain);
   LOG_INFO("   Order Blocks: " + (InpShowOrderBlocks ? "ENABLED" : "DISABLED"), g_debugMain);
   LOG_INFO("   Max OBs: " + IntegerToString(InpMaxOrderBlocks) + " above/below", g_debugMain);
   LOG_INFO("   DEBUG: " + (g_debugMode ? "ON" : "OFF (minimal)"), g_debugMain);
   LOG_INFO("   RISK MANAGER v2.10:", g_debugMain);
   LOG_INFO("     - Cooldown: 2 hours on loss", g_debugMain);
   LOG_INFO("     - Max Daily Trades: 3", g_debugMain);
   LOG_INFO("     - Profit Threshold: $20 (stops day)", g_debugMain);
   LOG_INFO("     - Daily Reset: 3:00 AM", g_debugMain);
   LOG_INFO("   CANDLE MODULE v1.05 (Dual Mode):", g_debugMain);
   LOG_INFO("     - Cooldown Mode: Wait 1-3 candles, 60% threshold", g_debugMain);
   LOG_INFO("     - Trading Mode: Check immediately, 50% threshold", g_debugMain);
   LOG_INFO("   POSITIONMANAGER v4.0:", g_debugMain);
   LOG_INFO("     - Hybrid SL/TP (Structure + Fallback)", g_debugMain);
   LOG_INFO("     - Buffer protection (avoid whipsaws)", g_debugMain);
   LOG_INFO("     - Min RR: 1.5:1 enforced", g_debugMain);
   LOG_INFO("   CHECKS REDUCED: 11 → 8 (27% fewer)", g_debugMain);
   LOG_INFO("   REMOVED: PullbackModule, RR Check, TP Calculation", g_debugMain);
   
   g_magicNumber = InpMagicNumber;
   g_trade.SetExpertMagicNumber(g_magicNumber);
   g_trade.SetDeviationInPoints(10);
   
   // ============================================================
   // 1. CREATE TREND MANAGER
   // ============================================================
   g_trendManager = new CTrendManager(_Symbol, InpTrendTF);
   if(g_trendManager == NULL)
   {
      LOG_ERROR("❌ Failed to create TrendManager");
      return INIT_FAILED;
   }
   
   // ============================================================
   // 2. CREATE RISK MANAGER
   // ============================================================
   g_riskManager = new CRiskManager(_Symbol);
   if(g_riskManager == NULL)
   {
      LOG_ERROR("❌ Failed to create RiskManager");
      return INIT_FAILED;
   }
   g_riskManager.EnableDebug(g_debugRisk);
   
   // ============================================================
   // 3. CREATE POSITION MANAGER (v4.0 - Self-Contained)
   // ============================================================
   g_positionManager = new CPositionManager(_Symbol, g_magicNumber, g_trade);
   if(g_positionManager == NULL)
   {
      LOG_ERROR("❌ Failed to create PositionManager");
      return INIT_FAILED;
   }
   LOG_DEBUG("✅ PositionManager v4.0 created (Self-Contained SL/TP)", g_debugPosition);
   
   // ─── LOAD CONFIG FROM INPUTS ───
   g_positionManager.   LoadConfigFromInputs();
   if(g_debugPosition)
      g_positionManager.PrintConfig();
   
   // ============================================================
   // ★★★ CONNECT RISK MANAGER TO POSITION MANAGER ★★★
   // ============================================================
   if(g_positionManager != NULL && g_riskManager != NULL)
   {
      g_positionManager.SetRiskManager(g_riskManager);
      LOG_INFO("✅ PositionManager → RiskManager connected", g_debugMain);
      LOG_INFO("   Trade results will be reported to RiskManager", g_debugMain);
   }
   else
   {
      LOG_WARNING("⚠️ Could not connect PositionManager to RiskManager");
   }
   
   // ============================================================
   // 4. CREATE PORTFOLIO MANAGER
   // ============================================================
   g_portfolioManager = new CPortfolioManager(_Symbol, g_magicNumber, g_trade);
   if(g_portfolioManager == NULL)
   {
      LOG_ERROR("❌ Failed to create PortfolioManager");
      return INIT_FAILED;
   }
   
   // ============================================================
   // ★★★ CONNECT TRENDMANAGER → PORTFOLIOMANAGER ★★★
   // ============================================================
   if(g_trendManager != NULL && g_portfolioManager != NULL)
   {
      g_portfolioManager.SetTrendManager(g_trendManager);
      LOG_DEBUG("✅ PortfolioManager → TrendManager connected", g_debugMain);
   }
   
   // ============================================================
   // ★★★ CONNECT PORTFOLIOMANAGER → POSITIONMANAGER ★★★
   // ============================================================
   if(g_portfolioManager != NULL && g_positionManager != NULL)
   {
      g_positionManager.SetPortfolioManager(g_portfolioManager);
      LOG_INFO("✅ PositionManager → PortfolioManager connected", g_debugMain);
      LOG_INFO("   TP will trail at 100 points when boost active", g_debugMain);
      LOG_INFO("   TP will NEVER move backward", g_debugMain);
   }
   else
   {
      LOG_WARNING("⚠️ Could not connect PositionManager to PortfolioManager");
   }
   
   // ============================================================
   // 5. CREATE COMPONENT MANAGER
   // ============================================================
   g_componentManager = new CComponentManager(_Symbol, InpEntryTF);
   if(g_componentManager == NULL)
   {
      LOG_ERROR("❌ Failed to create ComponentManager");
      return INIT_FAILED;
   }
   
   if(g_componentManager != NULL && g_trendManager != NULL)
   {
      g_componentManager.SetTrendManager(g_trendManager);
   }
   
   // ============================================================
   // 6. CREATE PULLBACK MODULE (Kept for chart display only)
   // ============================================================
   g_pullback = new CPullbackModule(_Symbol, InpEntryTF, InpRangeBars);
   if(g_pullback == NULL)
   {
      LOG_ERROR("❌ Failed to create PullbackModule");
      return INIT_FAILED;
   }
   g_pullback.EnableDebug(g_debugPullback);
   
   if(g_pullback != NULL && g_trendManager != NULL)
   {
      g_pullback.SetTrendManager(g_trendManager);
   }
   LOG_DEBUG("✅ PullbackModule created (Chart display only)", g_debugPullback);
   
   // ============================================================
   // 7. CREATE SESSION MANAGER
   // ============================================================
   g_sessionManager = new CSessionManager(_Symbol, InpEntryTF);
   if(g_sessionManager == NULL)
   {
      LOG_ERROR("❌ Failed to create SessionManager");
      return INIT_FAILED;
   }
   g_sessionManager.EnableDebug(g_debugSession);
   LOG_DEBUG("✅ SessionManager created", g_debugSession);
   
   // ============================================================
   // 8. CREATE ORDER BLOCK DISPLAY
   // ============================================================
   if(InpShowOrderBlocks)
   {
      g_orderBlockDisplay = new COrderBlockDisplay(_Symbol, InpOrderBlockTF);
      if(g_orderBlockDisplay == NULL)
      {
         LOG_ERROR("❌ Failed to create OrderBlockDisplay");
         return INIT_FAILED;
      }
      g_orderBlockDisplay.SetMaxBlocks(InpMaxOrderBlocks);
      g_orderBlockDisplay.EnableDebug(g_debugOrderBlock);
      LOG_DEBUG("✅ OrderBlockDisplay created", g_debugOrderBlock);
   }
   
   // ============================================================
   // 9. CREATE SCENARIO NARRATIVE
   // ============================================================
   g_scenarioNarrative = new ScenarioNarrative();
   if(g_scenarioNarrative == NULL)
   {
      LOG_ERROR("❌ Failed to create ScenarioNarrative");
      return INIT_FAILED;
   }
   
   // ============================================================
   // 10. CREATE CHART MODULE
   // ============================================================
   if(InpShowChart)
   {
      g_chartModule = new CChartModule(_Symbol, InpEntryTF, InpRangeBars);
      if(g_chartModule != NULL)
      {
         g_chartModule.SetPullbackModule(g_pullback);
         g_chartModule.SetSessionManager(g_sessionManager);
         LOG_DEBUG("✅ ChartModule created", g_debugMain);
         
         if(InpShowOrderBlocks && g_orderBlockDisplay != NULL)
         {
            g_chartModule.SetOrderBlockDisplay(g_orderBlockDisplay);
            LOG_DEBUG("✅ ChartModule → OrderBlockDisplay connected", g_debugMain);
         }
      }
   }
   
   // ============================================================
   // 11. CREATE DASHBOARD
   // ============================================================
   if(InpShowDashboard)
   {
      g_dashboard = new CDashboard(_Symbol);
      if(g_dashboard != NULL)
      {
         g_dashboard.Initialize();
         g_dashboard.SetLotSize(InpLotSize);
         g_dashboard.SetTrendManager(g_trendManager);
         g_dashboard.SetComponentManager(g_componentManager);
         g_dashboard.SetMinConfidenceThreshold(InpNeutralThreshold);
         
         // ─── CONNECT RISK MANAGER TO DASHBOARD ───
         if(g_riskManager != NULL)
         {
            g_dashboard.SetRiskManager(g_riskManager);
            LOG_INFO("✅ Dashboard → RiskManager connected", g_debugMain);
         }
         else
         {
            LOG_WARNING("⚠️ RiskManager is NULL - Dashboard will show 'Not Initialized'");
         }
      }
   }
   
   // ============================================================
   // 12. CREATE CANDLE MODULE (v1.05 - Dual Mode)
   // ============================================================
   g_candleModule = new CCandleModule(_Symbol, PERIOD_M15, InpEntryTF);
   if(g_candleModule == NULL)
   {
      LOG_ERROR("❌ Failed to create CandleModule");
      return INIT_FAILED;
   }
   g_candleModule.SetDebug(g_debugCandle);
   g_candleModule.SetConfidenceThresholds(60.0, 50.0);
   LOG_DEBUG("✅ CandleModule v1.05 created (Dual Mode)", g_debugMain);
   
   // Connect RiskManager to CandleModule (for cooldown reset)
   if(g_riskManager != NULL && g_candleModule != NULL)
   {
      LOG_INFO("✅ CandleModule → RiskManager connected (cooldown reset)", g_debugMain);
   }
   
   EventSetTimer(1);
   
   g_initStatus = INIT_STATUS_NOT_STARTED;
   g_initAttempts = 0;
   g_lastInitAttempt = 0;
   g_initializationFailed = false;
   
   LOG_INFO("✅ EA INITIALIZED - v4.0", g_debugMain);
   LOG_INFO("   TrendManager → PortfolioManager: ✓", g_debugMain);
   LOG_INFO("   PortfolioManager → PositionManager: ✓ (Boost TP 100 pts)", g_debugMain);
   LOG_INFO("   PositionManager → RiskManager: ✓ (Trade result tracking)", g_debugMain);
   LOG_INFO("   CandleModule: ✓ (Dual Mode: Cooldown + Trading)", g_debugMain);
   LOG_INFO("   PositionManager: ✓ (Self-Contained SL/TP)", g_debugMain);
   LOG_INFO("   Checks: 11 → 8 (27% reduction)", g_debugMain);
   LOG_INFO("=========================================================", g_debugMain);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK HANDLER                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InitializeIndicatorsAsync())
      return;
   
   if(g_portfolioManager != NULL)
      g_portfolioManager.Update();
   
   // ═══ UPDATE RISK MANAGER STATUS ═══
   if(g_riskManager != NULL)
   {
      g_riskStatusMessage = g_riskManager.GetStatusMessage();
      g_riskCanTrade = g_riskManager.CanTrade();
      
      if(g_debugRisk && g_riskManager.IsInCooldown())
      {
         static datetime lastCooldownLog = 0;
         if(TimeCurrent() - lastCooldownLog >= 60)
         {
            lastCooldownLog = TimeCurrent();
            LOG_DEBUG("⏳ Cooldown: " + g_riskManager.GetCooldownRemaining(), g_debugRisk);
         }
      }
   }
   
   // ═══ COOLDOWN MONITORING - CANDLE MODULE ═══
   if(g_riskManager != NULL && g_riskManager.IsInCooldown() && g_candleModule != NULL)
   {
      static bool cooldownStartLogged = false;
      
      if(!cooldownStartLogged)
      {
         g_candleModule.ResetCooldownCandleTracking();
         cooldownStartLogged = true;
         
         int waitCandles = g_candleModule.GetWaitCandles();
         LOG_DEBUG("🕯️ CandleModule: Waiting for " + IntegerToString(waitCandles) + 
                   " M15 candle(s) before exhaustion check", g_debugCandle);
      }
      
      static datetime lastCandleCheck = 0;
      datetime currentTime = TimeCurrent();
      
      if(currentTime - lastCandleCheck >= 30)
      {
         lastCandleCheck = currentTime;
         
         int trendDirection = 0;
         if(g_trendManager != NULL)
         {
            if(g_trendManager.IsBullish()) trendDirection = 1;
            else if(g_trendManager.IsBearish()) trendDirection = -1;
         }
         
         if(trendDirection == 0 && g_componentManager != NULL)
         {
            SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
            if(analysis.overallSentiment == "BULLISH") trendDirection = 1;
            else if(analysis.overallSentiment == "BEARISH") trendDirection = -1;
         }
         
         if(trendDirection != 0)
         {
            double cooldownRemaining = g_riskManager.GetCooldownRemainingSeconds();
            
            if(g_candleModule.ShouldResetCooldown(trendDirection, cooldownRemaining))
            {
               LOG_INFO("🔄 CANDLE MODULE: Cooldown reset triggered", g_debugCandle);
               
               SExhaustionResult result = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
               
               g_riskManager.ResetCooldown();
               
               string resetReason = g_candleModule.GetResetReason(trendDirection);
               LOG_INFO("   Reason: " + resetReason, g_debugMain);
               LOG_INFO("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", g_debugCandle);
               LOG_INFO("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", g_debugCandle);
               LOG_INFO("   Candles Waited: " + IntegerToString(result.candlesWaited) + "/" + IntegerToString(result.candlesRequired), g_debugCandle);
               
               g_riskStatusMessage = "Cooldown Reset: " + resetReason;
               cooldownStartLogged = false;
            }
            else
            {
               static datetime lastStatusLog = 0;
               if(currentTime - lastStatusLog >= 300)
               {
                  lastStatusLog = currentTime;
                  SExhaustionResult result = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
                  
                  if(!result.isValid && result.candlesWaited < g_candleModule.GetWaitCandles())
                  {
                     LOG_DEBUG("🕯️ Candle Monitor: " + result.waitStatus, g_debugCandle);
                  }
                  else if(result.isValid)
                  {
                     LOG_DEBUG("🕯️ Candle Monitor: " + result.description + " (Conf: " + 
                              DoubleToString(result.confidence, 0) + "%)", g_debugCandle);
                  }
                  else
                  {
                     LOG_DEBUG("🕯️ Candle Monitor: " + result.description, g_debugCandle);
                  }
               }
            }
         }
      }
   }
   else
   {
      static bool wasInCooldown = false;
      if(wasInCooldown && g_riskManager != NULL && !g_riskManager.IsInCooldown())
      {
         wasInCooldown = false;
      }
      if(g_riskManager != NULL && g_riskManager.IsInCooldown())
      {
         wasInCooldown = true;
      }
   }
   
   // ═══ RUN EVERY 10 SECONDS ═══
   static datetime lastCheckTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastCheckTime >= 10)
   {
      lastCheckTime = currentTime;
      
      datetime currentBarTime = iTime(_Symbol, InpEntryTF, 0);
      if(currentBarTime != g_lastBarTime)
      {
         g_lastBarTime = currentBarTime;
      }
      
      CheckSignal();
      UpdateChart();
      UpdateDashboard();
      UpdateOrderBlocks();
   }
}

//+------------------------------------------------------------------+
//| UPDATE ORDER BLOCKS                                              |
//+------------------------------------------------------------------+
void UpdateOrderBlocks()
{
   if(!InpShowOrderBlocks || g_orderBlockDisplay == NULL)
      return;
   
   static datetime lastUpdateTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastUpdateTime >= 5)
   {
      lastUpdateTime = currentTime;
      g_orderBlockDisplay.Update();
      
      if(g_debugOrderBlock)
      {
         LOG_DEBUG("📊 Order Blocks Updated: " + 
                   IntegerToString(g_orderBlockDisplay.GetTotalBlocksAbove()) + " above, " +
                   IntegerToString(g_orderBlockDisplay.GetTotalBlocksBelow()) + " below",
                   g_debugOrderBlock);
      }
   }
}

//+------------------------------------------------------------------+
//| ASYNCHRONOUS INDICATOR INITIALIZATION                           |
//+------------------------------------------------------------------+
bool InitializeIndicatorsAsync()
{
   if(g_initStatus == INIT_STATUS_COMPLETE)
      return true;
      
   if(g_initializationFailed)
   {
      static datetime lastRecoveryAttempt = 0;
      datetime currentTime = TimeCurrent();
      
      if(currentTime - lastRecoveryAttempt >= 60)
      {
         lastRecoveryAttempt = currentTime;
         LOG_WARNING("⚠️ Attempting recovery from failed initialization...");
         g_initStatus = INIT_STATUS_NOT_STARTED;
         g_initializationFailed = false;
         g_initAttempts = 0;
      }
      else
      {
         return false;
      }
   }
   
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastInitAttempt < 1)
      return false;
   
   g_lastInitAttempt = currentTime;
   g_initAttempts++;
   
   if(g_initStatus < INIT_STATUS_TREND_MANAGER)
   {
      if(!WaitForData(InpTrendTF, 100))
         return false;
      
      if(!g_trendManager.Initialize())
      {
         if(g_initAttempts >= 10)
            g_initializationFailed = true;
         return false;
      }
      
      LOG_DEBUG("✅ TrendManager initialized", g_debugTrend);
      g_initStatus = INIT_STATUS_TREND_MANAGER;
   }
   
   if(g_initStatus < INIT_STATUS_COMPONENT_MANAGER)
   {
      if(!WaitForData(InpEntryTF, 200))
         return false;
      
      if(!g_componentManager.Initialize())
      {
         if(g_initAttempts >= 10)
            g_initializationFailed = true;
         return false;
      }
      
      LOG_DEBUG("✅ ComponentManager initialized", g_debugComponent);
      g_initStatus = INIT_STATUS_COMPONENT_MANAGER;
   }
   
   if(g_initStatus < INIT_STATUS_PULLBACK)
   {
      if(!WaitForData(InpEntryTF, 200))
         return false;
      
      if(!g_pullback.Initialize())
      {
         if(g_initAttempts >= 10)
            g_initializationFailed = true;
         return false;
      }
      
      if(g_trendManager != NULL)
         g_pullback.SetTrendManager(g_trendManager);
      
      LOG_DEBUG("✅ PullbackModule initialized (Chart display)", g_debugPullback);
      g_initStatus = INIT_STATUS_PULLBACK;
   }
   
   if(g_initStatus < INIT_STATUS_SESSION_MANAGER)
   {
      if(!WaitForData(InpEntryTF, 50))
         return false;
      
      if(!g_sessionManager.Initialize())
      {
         if(g_initAttempts >= 10)
            g_initializationFailed = true;
         return false;
      }
      
      LOG_DEBUG("✅ SessionManager initialized", g_debugSession);
      g_initStatus = INIT_STATUS_SESSION_MANAGER;
   }
   
   if(g_initStatus < INIT_STATUS_ORDER_BLOCK_DISPLAY)
   {
      if(InpShowOrderBlocks && g_orderBlockDisplay != NULL)
      {
         g_orderBlockDisplay.Update();
         LOG_DEBUG("✅ OrderBlockDisplay initialized", g_debugOrderBlock);
      }
      g_initStatus = INIT_STATUS_ORDER_BLOCK_DISPLAY;
   }
   
   if(g_initStatus < INIT_STATUS_CANDLE_MODULE)
   {
      if(g_candleModule != NULL)
      {
         if(!WaitForData(PERIOD_M15, 100))
            return false;
         if(!WaitForData(PERIOD_M1, 100))
            return false;
         
         LOG_DEBUG("✅ CandleModule initialized", g_debugCandle);
      }
      g_initStatus = INIT_STATUS_CANDLE_MODULE;
   }
   
   if(g_initStatus == INIT_STATUS_CANDLE_MODULE)
   {
      if(g_pullback != NULL && g_trendManager != NULL)
      {
         SPullbackAnalysisResult testResult = g_pullback.GetPullbackAnalysis();
         if(testResult.rangeHigh > 0 && testResult.rangeLow > 0 && testResult.rangeHigh > testResult.rangeLow)
         {
            g_initStatus = INIT_STATUS_COMPLETE;
            LOG_INFO("✅ ALL MODULES INITIALIZED - READY", g_debugMain);
            
            if(g_sessionManager != NULL && g_debugSession)
            {
               LOG_DEBUG("📊 Current Session: " + g_sessionManager.GetSessionName(), g_debugSession);
            }
            
            if(g_riskManager != NULL && g_debugRisk)
            {
               LOG_DEBUG("📊 Risk Manager: " + g_riskManager.GetStatusMessage(), g_debugRisk);
            }
            
            if(g_candleModule != NULL && g_debugCandle)
            {
               LOG_DEBUG("🕯️ Candle Module: Ready (Dual Mode)", g_debugCandle);
            }
            
            if(g_positionManager != NULL && g_debugPosition)
            {
               LOG_DEBUG("📊 PositionManager: Self-Contained SL/TP", g_debugPosition);
            }
            
            return true;
         }
         else
         {
            return false;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| WAIT FOR DATA                                                    |
//+------------------------------------------------------------------+
bool WaitForData(ENUM_TIMEFRAMES tf, int requiredBars)
{
   int bars = Bars(_Symbol, tf);
   
   if(bars < requiredBars)
   {
      static datetime lastLog = 0;
      datetime currentTime = TimeCurrent();
      
      if(currentTime - lastLog >= 10)
      {
         lastLog = currentTime;
         LOG_DEBUG("⏳ Waiting for data on " + EnumToString(tf) + " (" + 
                   IntegerToString(bars) + "/" + IntegerToString(requiredBars) + " bars)", g_debugMain);
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| TIMER                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_initStatus != INIT_STATUS_COMPLETE)
      return;
   
   if(g_positionManager != NULL)
      g_positionManager.ManagePositions();
   
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.Update();
   }
   
   if(g_riskManager != NULL)
   {
      g_riskStatusMessage = g_riskManager.GetStatusMessage();
      g_riskCanTrade = g_riskManager.CanTrade();
   }
   
   if(g_sessionManager != NULL && g_debugSession)
   {
      static datetime lastSessionLog = 0;
      if(TimeCurrent() - lastSessionLog >= 300)
      {
         lastSessionLog = TimeCurrent();
         LOG_DEBUG("📊 Session: " + g_sessionManager.GetSessionName(), g_debugSession);
      }
   }
   
   if(g_riskManager != NULL && g_debugRisk)
   {
      static datetime lastRiskLog = 0;
      if(TimeCurrent() - lastRiskLog >= 300)
      {
         lastRiskLog = TimeCurrent();
         LOG_DEBUG("📊 Risk Status: " + g_riskManager.GetStatusMessage(), g_debugRisk);
      }
   }
   
   if(g_candleModule != NULL && g_riskManager != NULL && g_riskManager.IsInCooldown())
   {
      static datetime lastCandleLog = 0;
      if(TimeCurrent() - lastCandleLog >= 300)
      {
         lastCandleLog = TimeCurrent();
         if(g_debugCandle)
         {
            string status = g_candleModule.GetStatusReport();
            LOG_DEBUG("🕯️ " + status, g_debugCandle);
         }
      }
   }
   
   static datetime lastReconnectCheck = 0;
   datetime currentTime = TimeCurrent();

   if(currentTime - lastReconnectCheck >= 60)
   {
      lastReconnectCheck = currentTime;
      
      if(g_trendManager != NULL && g_pullback != NULL)
      {
         int testTrend = g_pullback.GetTrendPublic();
         if(testTrend == 0 && g_trendManager != NULL)
         {
            g_pullback.SetTrendManager(g_trendManager);
         }
      }
   }
   
   static datetime lastPosLog = 0;
   if(TimeCurrent() - lastPosLog >= 60)
   {
      int posCount = PositionsTotal();
      if(posCount > 0)
         LOG_DEBUG("📊 Open positions: " + IntegerToString(posCount), g_debugPosition);
      lastPosLog = TimeCurrent();
   }
   
   UpdateChart();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| CLEANUP                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LOG_INFO("=== SHUTTING DOWN ===", g_debugMain);
   
   if(InpEnableTrading && g_positionManager != NULL)
   {
      LOG_INFO("Closing all positions...", g_debugMain);
      g_positionManager.CloseAllPositions();
   }
   
   if(g_candleModule != NULL) { delete g_candleModule; g_candleModule = NULL; }
   if(g_orderBlockDisplay != NULL) { delete g_orderBlockDisplay; g_orderBlockDisplay = NULL; }
   if(g_sessionManager != NULL) { delete g_sessionManager; g_sessionManager = NULL; }
   if(g_portfolioManager != NULL) { delete g_portfolioManager; g_portfolioManager = NULL; }
   if(g_pullback != NULL) { delete g_pullback; g_pullback = NULL; }
   if(g_positionManager != NULL) { delete g_positionManager; g_positionManager = NULL; }
   if(g_riskManager != NULL) { delete g_riskManager; g_riskManager = NULL; }
   if(g_componentManager != NULL) { delete g_componentManager; g_componentManager = NULL; }
   if(g_trendManager != NULL) { delete g_trendManager; g_trendManager = NULL; }
   if(g_chartModule != NULL) { delete g_chartModule; g_chartModule = NULL; }
   if(g_dashboard != NULL) { delete g_dashboard; g_dashboard = NULL; }
   if(g_scenarioNarrative != NULL) { delete g_scenarioNarrative; g_scenarioNarrative = NULL; }
   
   string chartPrefix = "PBR_" + _Symbol + "_";
   ObjectsDeleteAll(0, chartPrefix);
   
   string dashPrefix = "DASH_" + _Symbol + "_";
   ObjectsDeleteAll(0, dashPrefix);
   
   string obPrefix = "OB_" + _Symbol + "_";
   ObjectsDeleteAll(0, obPrefix);
   
   EventKillTimer();
   Logger::Shutdown();
   LOG_INFO("✅ CLEANUP COMPLETE", g_debugMain);
}

// ============================================================
// CORE FUNCTIONS
// ============================================================

//+------------------------------------------------------------------+
//| GetThresholdForDirection                                         |
//+------------------------------------------------------------------+
double GetThresholdForDirection(string direction)
{
   if(direction == "BULLISH")
      return InpBuyThreshold;
   else if(direction == "BEARISH")
      return InpSellThreshold;
   else
      return InpNeutralThreshold;
}

//+------------------------------------------------------------------+
//| Get State Name - Helper for Crossover States                    |
//+------------------------------------------------------------------+
string GetStateName(ENUM_CROSS_STATE state)
{
   switch(state)
   {
      case CROSS_UP:   return "↗ CROSS UP";
      case CROSS_ZONE: return "≈ ZONE";
      case CROSS_DOWN: return "↘ CROSS DOWN";
      case CLEAR_UP:   return "▲ CLEAR UP";
      case CLEAR_DOWN: return "▼ CLEAR DOWN";
      default:         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| CheckSignal - v4.1 WITH MA89 PULLBACK CHECK                     |
//| Uses TrendManager for pullback validation before CandleModule   |
//| CHECKS: 8 → 9 (Added Pullback near MA89)                      |
//+------------------------------------------------------------------+
void CheckSignal()
{
   if(g_componentManager == NULL || g_trendManager == NULL || g_candleModule == NULL) 
   {
      LOG_DEBUG("❌ CheckSignal: Required modules are NULL", g_debugMain);
      return;
   }
   
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   LOG_DEBUG("🔍 CHECK SIGNAL v4.1 - 9 CHECKS (with MA89 Pullback)", g_debugMain);
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECK 1: RISK MANAGER ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 1/9: Risk Manager", g_debugMain);
   
   if(g_riskManager != NULL && !g_riskManager.CanTrade())
   {
      LOG_DEBUG("❌ Risk Manager blocks trading: " + g_riskManager.GetStatusMessage(), g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Risk blocks trading");
      return;
   }
   LOG_DEBUG("✅ Risk Manager passed", g_debugMain);
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECKS 2-4: TREND MANAGER ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 2-4/9: Trend Manager", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(1, "Analyzing trend...");
   UpdateDashboard();
   
   // ─── ANALYZE TREND ───
   LOG_DEBUG("📊 Calling g_trendManager.AnalyzeTrend()...", g_debugMain);
   STrendResult trendResult = g_trendManager.AnalyzeTrend();
   LOG_DEBUG("✅ AnalyzeTrend() complete", g_debugMain);
   
   // ─── GET CROSSOVER DATA ───
   int priority = g_trendManager.GetCrossoverPriority();
   string scenario = g_trendManager.GetCrossoverScenarioName();
   string direction = g_trendManager.GetDirection();
   double strength = g_trendManager.GetStrength();
   bool isGolden = g_trendManager.IsGoldenCross();
   bool isDeath = g_trendManager.IsDeathCross();
   
   // ─── CHECK 2: PRIORITY 1-3 ───
   bool isEntrySignal = (priority <= 3);
   bool isStrongEntry = (priority == 1);
   bool isDipEntry = (priority == 2);
   bool isPullbackEntry = (priority == 3);
   
   if(!isEntrySignal)
   {
      LOG_DEBUG("❌ Priority " + IntegerToString(priority) + " - NOT entry (requires 1-3)", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Priority " + IntegerToString(priority) + " - No entry");
      return;
   }
   LOG_DEBUG("✅ Priority " + IntegerToString(priority) + " - Entry signal", g_debugMain);
   
   // ─── CHECK 3: DIRECTION ───
   if(direction == "NEUTRAL")
   {
      LOG_DEBUG("❌ Direction is NEUTRAL - No trade", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Direction: NEUTRAL");
      return;
   }
   LOG_DEBUG("✅ Direction: " + direction, g_debugMain);
   
   // ─── CHECK 4: STRENGTH ───
   if(strength < InpMinTrendStrength)
   {
      LOG_DEBUG("❌ Strength too weak: " + DoubleToString(strength, 1) + "% < " + 
                DoubleToString(InpMinTrendStrength, 1) + "%", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Strength too weak");
      return;
   }
   LOG_DEBUG("✅ Strength: " + DoubleToString(strength, 1) + "%", g_debugMain);
   
   // ✅ CHECKS 2-4 PASSED
   string passMsg = scenario + " P" + IntegerToString(priority) + " | " + direction + 
                     " (" + DoubleToString(strength, 1) + "%)";
   if(isGolden) passMsg += " | 🟡 GOLDEN CROSS!";
   LOG_DEBUG("✅ TREND MANAGER PASSED: " + passMsg, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(1, passMsg);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECK 4.5: PULLBACK NEAR MA89 (NEW - Using TrendManager) ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 4.5/9: Pullback near M5 MA89", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(2, "Checking pullback near MA89...");
   UpdateDashboard();
   
   double pullbackPercent = 0;
   bool hasValidPullback = g_trendManager.CheckPullbackNearMA89(pullbackPercent, 30.0, 300);
   
   if(!hasValidPullback)
   {
      LOG_DEBUG("❌ No valid pullback near M5 MA89", g_debugMain);
      LOG_DEBUG("   Pullback: " + DoubleToString(pullbackPercent, 1) + "% (min 30%)", g_debugMain);
      
      // Log MA89 details for debugging
      double ma89_M5 = g_trendManager.GetMA89_Entry();
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distancePips = 0;
      if(ma89_M5 > 0)
         distancePips = MathAbs(currentPrice - ma89_M5) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      LOG_DEBUG("   M5 MA89: " + DoubleToString(ma89_M5, _Digits), g_debugMain);
      LOG_DEBUG("   Current: " + DoubleToString(currentPrice, _Digits), g_debugMain);
      LOG_DEBUG("   Distance: " + DoubleToString(distancePips, 0) + " pips (max 300)", g_debugMain);
      
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(2, "No pullback near MA89");
      return;
   }
   
   LOG_DEBUG("✅ Pullback near M5 MA89: " + DoubleToString(pullbackPercent, 1) + "%", g_debugMain);
   
   // ─── LOG MA89 DETAILS ───
   double ma89_M5 = g_trendManager.GetMA89_Entry();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distancePips = 0;
   if(ma89_M5 > 0)
      distancePips = MathAbs(currentPrice - ma89_M5) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   LOG_DEBUG("   M5 MA89: " + DoubleToString(ma89_M5, _Digits), g_debugMain);
   LOG_DEBUG("   Current: " + DoubleToString(currentPrice, _Digits), g_debugMain);
   LOG_DEBUG("   Distance: " + DoubleToString(distancePips, 0) + " pips", g_debugMain);
   LOG_DEBUG("   Pullback: " + DoubleToString(pullbackPercent, 1) + "%", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(2, "Pullback: " + DoubleToString(pullbackPercent, 0) + "% near MA89");
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECK 5: CANDLE MODULE - EXHAUSTION ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 5/9: Candle Module - Exhaustion", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(3, "Checking exhaustion...");
   UpdateDashboard();
   
   int trendDirection = 0;
   if(direction == "BULLISH") trendDirection = 1;
   else if(direction == "BEARISH") trendDirection = -1;
   
   double cooldownRemaining = 0;
   if(g_riskManager != NULL)
      cooldownRemaining = g_riskManager.GetCooldownRemainingSeconds();
   
   SExhaustionResult exhaustion = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
   
   LOG_DEBUG("   Mode: " + exhaustion.modeName, g_debugMain);
   LOG_DEBUG("   Valid: " + (exhaustion.isValid ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   Confidence: " + DoubleToString(exhaustion.confidence, 1) + "%", g_debugMain);
   LOG_DEBUG("   HTF Pattern: " + exhaustion.htfPattern + " (" + 
             DoubleToString(exhaustion.htfPatternStrength, 0) + "%)", g_debugMain);
   LOG_DEBUG("   LTF Pattern: " + exhaustion.ltfPattern + " (" + 
             DoubleToString(exhaustion.ltfPatternStrength, 0) + "%)", g_debugMain);
   
   if(!exhaustion.isValid)
   {
      LOG_DEBUG("❌ No exhaustion: " + exhaustion.description, g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(3, "No exhaustion");
      return;
   }
   LOG_DEBUG("✅ Exhaustion detected", g_debugMain);
   
   if(exhaustion.confidence < 50.0)
   {
      LOG_DEBUG("❌ Confidence too low: " + DoubleToString(exhaustion.confidence, 1) + "% < 50%", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(3, "Confidence too low");
      return;
   }
   LOG_DEBUG("✅ Exhaustion confidence: " + DoubleToString(exhaustion.confidence, 1) + "%", g_debugMain);
   
   // ✅ CHECK 5 PASSED
   string candleMsg = "Exhaustion: " + exhaustion.type + " (" + 
                      DoubleToString(exhaustion.confidence, 0) + "%)";
   LOG_DEBUG("✅ CANDLE MODULE PASSED: " + candleMsg, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(3, candleMsg);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECKS 6-7: CONFIDENCE + ALIGNMENT ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 6-7/9: Confidence + Alignment", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(4, "Checking confidence...");
   UpdateDashboard();
   
   SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
   
   double baseConfidence = analysis.overallConfidence;
   double portfolioBoost = 0;
   
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.Update();
      portfolioBoost = g_portfolioManager.GetPortfolioConfidenceBoost(baseConfidence);
      double adjustedConfidence = baseConfidence + portfolioBoost;
      adjustedConfidence = MathMax(0, MathMin(100, adjustedConfidence));
      analysis.overallConfidence = adjustedConfidence;
   }
   
   string finalSentiment = direction;
   if(finalSentiment == "NEUTRAL")
      finalSentiment = analysis.overallSentiment;
   
   double thresholdToUse = GetThresholdForDirection(finalSentiment);
   
   LOG_DEBUG("   Final Sentiment: " + finalSentiment, g_debugMain);
   LOG_DEBUG("   Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugMain);
   LOG_DEBUG("   Threshold: " + DoubleToString(thresholdToUse, 1) + "%", g_debugMain);
   
   // ─── CHECK 6: CONFIDENCE ───
   if(finalSentiment == "NEUTRAL")
   {
      LOG_DEBUG("❌ NEUTRAL sentiment - no clear direction", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "NEUTRAL sentiment");
      return;
   }
   
   if(analysis.overallConfidence < thresholdToUse)
   {
      LOG_DEBUG("❌ Confidence too low: " + DoubleToString(analysis.overallConfidence, 1) + "% < " + 
                DoubleToString(thresholdToUse, 1) + "%", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "Confidence too low");
      return;
   }
   LOG_DEBUG("✅ Confidence passed", g_debugMain);
   
   // ─── CHECK 7: ALIGNMENT ───
   bool signalAlignsWithTrend = false;
   
   if(finalSentiment == "BULLISH" && 
      (direction == "BULLISH" || (direction == "NEUTRAL" && InpAllowNeutralTrend)))
      signalAlignsWithTrend = true;
   else if(finalSentiment == "BEARISH" && 
           (direction == "BEARISH" || (direction == "NEUTRAL" && InpAllowNeutralTrend)))
      signalAlignsWithTrend = true;
   
   LOG_DEBUG("   Aligns with trend: " + (signalAlignsWithTrend ? "YES" : "NO"), g_debugMain);
   
   if(!signalAlignsWithTrend)
   {
      LOG_DEBUG("❌ Signal does not align with trend", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "Signal doesn't align");
      return;
   }
   
   // ✅ CHECKS 6-7 PASSED
   string confMessage = "Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "% ≥ " + 
                        DoubleToString(thresholdToUse, 1) + "%";
   LOG_DEBUG("✅ CONFIDENCE PASSED: " + confMessage, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(4, confMessage);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CHECK 8: RISK LIMITS ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 CHECK 8/9: Risk Limits", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(5, "Checking risk limits...");
   UpdateDashboard();
   
   if(g_riskManager != NULL && !g_riskManager.CheckRiskLimits())
   {
      LOG_DEBUG("❌ Risk: " + g_riskManager.GetStatusMessage(), g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(5, "Risk: " + g_riskManager.GetStatusMessage());
      return;
   }
   
   // ✅ CHECK 8 PASSED
   if(g_riskManager != NULL)
   {
      LOG_DEBUG("✅ Risk: " + g_riskManager.GetStatusMessage(), g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckPassed(5, "Risk: " + g_riskManager.GetStatusMessage());
   }
   else
   {
      LOG_DEBUG("✅ Risk: Ready", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckPassed(5, "Risk: Ready");
   }
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ EXECUTION ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 EXECUTION - All 9 checks passed", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(6, "Executing trade...");
   UpdateDashboard();
   
   // ─── DETERMINE TRADE DIRECTION ───
   int tradeSignal = 0;
   if(direction == "BULLISH")
      tradeSignal = 1;
   else if(direction == "BEARISH")
      tradeSignal = -1;
   else
      tradeSignal = 0;
   
   if(tradeSignal == 0)
   {
      LOG_DEBUG("❌ No trade direction", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "No trade direction");
      return;
   }
   
   // ─── CALCULATE LOT SIZE ───
   double lotSize = InpLotSize;
   
   // ─── ADJUST BASED ON PRIORITY ───
   if(isStrongEntry)      // Priority 1
      lotSize = lotSize * 1.0;
   else if(isDipEntry)    // Priority 2
      lotSize = lotSize * 0.85;
   else if(isPullbackEntry) // Priority 3
      lotSize = lotSize * 0.65;
   
   // ─── RISK MANAGER LOT SIZING ───
   if(g_riskManager != NULL && tradeSignal != 0)
   {
      PrescribedTrade tempTrade;
      ZeroMemory(tempTrade);
      tempTrade.signal = tradeSignal;
      tempTrade.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double riskLotSize = g_riskManager.CalculateLotSize(tempTrade);
      if(riskLotSize > 0 && riskLotSize < lotSize)
         lotSize = riskLotSize;
   }
   
   // ─── ENFORCE MIN/MAX ───
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   if(stepLot > 0)
      lotSize = MathRound(lotSize / stepLot) * stepLot;
   
   LOG_DEBUG("   Lot Size: " + DoubleToString(lotSize, 2) + " (Priority " + 
             IntegerToString(priority) + ")", g_debugMain);
   
   // ─── LOG TRADE SIGNAL ───
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   LOG_TRADE("✅✅✅ TRADE SIGNAL v4.1 ✅✅✅");
   LOG_TRADE("   Priority: " + IntegerToString(priority) + " (" + scenario + ")");
   LOG_TRADE("   Direction: " + direction + " | Strength: " + DoubleToString(strength, 1) + "%");
   if(isGolden) LOG_TRADE("   🟡 GOLDEN CROSS!");
   if(isDeath) LOG_TRADE("   ⚫ DEATH CROSS!");
   LOG_TRADE("   Pullback: " + DoubleToString(pullbackPercent, 1) + "% near M5 MA89");
   LOG_TRADE("   Exhaustion: " + exhaustion.type + " (" + 
             DoubleToString(exhaustion.confidence, 0) + "%)");
   LOG_TRADE("   HTF Pattern: " + exhaustion.htfPattern);
   LOG_TRADE("   LTF Pattern: " + exhaustion.ltfPattern);
   LOG_TRADE("   Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%");
   LOG_TRADE("   Lot Size: " + DoubleToString(lotSize, 2));
   LOG_TRADE("   SL/TP: Managed by PositionManager (Hybrid Structure)");
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   
   // ─── EXECUTE TRADE ───
   if(InpEnableTrading && g_positionManager != NULL)
   {
      LOG_DEBUG("📊 Executing trade via PositionManager...", g_debugMain);
      
      bool execResult = g_positionManager.ExecuteTrade(tradeSignal, lotSize);
      
      if(execResult)
      {
         LOG_TRADE("✅✅✅ TRADE EXECUTED SUCCESSFULLY ✅✅✅");
         LOG_DEBUG("✅ Trade executed successfully (SL/TP self-contained)", g_debugMain);
         
         if(g_riskManager != NULL)
            g_riskManager.OnTradeExecuted();
         
         if(g_dashboard != NULL)
         {
            string dirText = tradeSignal == 1 ? "BUY" : "SELL";
            g_dashboard.SetCheckPassed(6, "SUCCESSFUL - " + dirText);
            g_dashboard.SetTradeExecuted();
         }
      }
      else
      {
         LOG_ERROR("❌❌❌ TRADE EXECUTION FAILED ❌❌❌");
         if(g_dashboard != NULL)
            g_dashboard.SetCheckFailed(6, "Execution FAILED");
      }
   }
   else
   {
      LOG_DEBUG("⚠️ Trading disabled - Signal detected but not executed", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "Trading disabled");
   }
   
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   LOG_DEBUG("🔍 CHECK SIGNAL COMPLETE - 9/9 PASSED", g_debugMain);
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Update Chart                                                    |
//+------------------------------------------------------------------+
void UpdateChart()
{
   if(InpShowChart && g_chartModule != NULL)
   {
      if(g_pullback != NULL && g_trendManager != NULL)
      {
         int testTrend = g_pullback.GetTrendPublic();
         if(testTrend == 0 && g_trendManager != NULL)
         {
            g_pullback.SetTrendManager(g_trendManager);
         }
      }
      
      g_chartModule.Update();
   }
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(InpShowDashboard && g_dashboard != NULL && g_componentManager != NULL)
   {
      RangeData range = g_pullback.DetectRange();
      int trend = g_pullback.GetTrendPublic();
      
      if(range.isValid)
      {
         SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
         SPullbackAnalysisResult pbResult = g_pullback.GetPullbackAnalysis();
         
         SComponentData componentData;
         ZeroMemory(componentData);
         
         componentData.pbConfidence = pbResult.confidence;
         componentData.pbPercent = range.pullbackPercent;
         componentData.pbAdjustedPercent = range.pullbackPercent;
         if(trend == -1) componentData.pbAdjustedPercent = 100 - range.pullbackPercent;
         componentData.pbZone = range.pullbackZone;
         
         componentData.mtfConfidence = analysis.mtfData.confidence;
         componentData.mtfTotalScore = analysis.mtfData.totalScore;
         
         componentData.macdConfidence = analysis.macdData.confidence;
         componentData.macdHistogram = analysis.macdData.histogramValue;
         componentData.macdScore = analysis.macdData.macdScore;
         
         componentData.adxConfidence = analysis.adxData.bullPercentage;
         componentData.adxValue = analysis.adxData.adxValue;
         
         componentData.rsiConfidence = analysis.rsiData.confidence;
         componentData.rsiValue = analysis.rsiData.rsiValue;
         
         componentData.volConfidence = analysis.volumeData.confidence;
         componentData.volRatio = analysis.volumeData.volumeRatio;
         componentData.priceChange = analysis.volumeData.priceChange;
         
         double baseConfidence = analysis.overallConfidence;
         double portfolioBoost = 0;
         
         if(g_portfolioManager != NULL)
         {
            g_portfolioManager.Update();
            portfolioBoost = g_portfolioManager.GetPortfolioConfidenceBoost(baseConfidence);
         }
         
         double finalConfidence = MathMax(0, MathMin(100, baseConfidence + portfolioBoost));
         
         componentData.finalConfidence = finalConfidence;
         componentData.baseConfidence = baseConfidence;
         componentData.portfolioBoost = portfolioBoost;
         componentData.finalDirection = analysis.overallSentiment;
         componentData.activeComponents = analysis.activeComponents;
         componentData.overallScore = analysis.overallScore;
         
         ScenarioResult scenario;
         ZeroMemory(scenario);
         
         if(g_scenarioNarrative != NULL)
         {
            scenario = g_scenarioNarrative.DetectScenario(componentData);
         }
         else
         {
            scenario.confidence = finalConfidence;
            scenario.description = "Pullback Scenario";
            scenario.conditions = "Pullback in " + range.pullbackZone;
            scenario.action = "Monitor";
            scenario.riskLevel = "Medium";
            scenario.narrative = "Market in pullback phase";
            
            double thresholdToUse = GetThresholdForDirection(analysis.overallSentiment);
            
            if(pbResult.zoneCategory == "PERFECT" && finalConfidence >= thresholdToUse)
            {
               scenario.scenario = 1;
               scenario.description = "Optimal Pullback Scenario";
               scenario.action = "ENTER with full position";
               scenario.riskLevel = "Low";
            }
            else if((pbResult.zoneCategory == "SWEET" || pbResult.zoneCategory == "EDGE") && finalConfidence >= thresholdToUse * 0.85)
            {
               scenario.scenario = 2;
               scenario.description = "Good Pullback Scenario";
               scenario.action = "ENTER with standard position";
               scenario.riskLevel = "Low-Medium";
            }
            else if(finalConfidence >= thresholdToUse * 0.7)
            {
               scenario.scenario = 3;
               scenario.description = "Moderate Pullback Scenario";
               scenario.action = "Consider reduced position";
               scenario.riskLevel = "Medium";
            }
            else
            {
               scenario.scenario = 4;
               scenario.description = "Weak Pullback Scenario";
               scenario.action = "Monitor - Wait for better entry";
               scenario.riskLevel = "Medium-High";
            }
         }
         
         PrescribedTrade trade;
         ZeroMemory(trade);
         
         double thresholdToUse = GetThresholdForDirection(analysis.overallSentiment);
         
         if(g_positionManager != NULL && g_positionManager.HasOpenPositions())
         {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket <= 0) continue;
               
               if(PositionSelectByTicket(ticket))
               {
                  int magic = (int)PositionGetInteger(POSITION_MAGIC);
                  string symbol = PositionGetString(POSITION_SYMBOL);
                  
                  if(magic == InpMagicNumber && symbol == _Symbol)
                  {
                     ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                     trade.signal = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                     trade.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                     trade.stopLoss = PositionGetDouble(POSITION_SL);
                     trade.takeProfit = PositionGetDouble(POSITION_TP);
                     
                     PositionState state;
                     if(g_positionManager.GetState(ticket, state))
                     {
                        trade.takeProfit2 = state.takeProfit2;
                        trade.partialLevel75 = state.partialLevel75;
                        trade.riskRewardRatio = state.isBreakevenSet ? 0 : MathAbs(trade.takeProfit - trade.entryPrice) / MathAbs(trade.stopLoss - trade.entryPrice);
                     }
                     else
                     {
                        trade.takeProfit2 = 0;
                        trade.partialLevel75 = 0;
                        double risk = MathAbs(trade.stopLoss - trade.entryPrice);
                        double reward = MathAbs(trade.takeProfit - trade.entryPrice);
                        trade.riskRewardRatio = (risk > 0) ? reward / risk : 0;
                     }
                     
                     trade.pullbackPercent = range.pullbackPercent;
                     trade.pullbackScore = (int)pbResult.pullbackScore;
                     trade.entryReason = "OPEN POSITION #" + IntegerToString(ticket);
                     
                     double actualLot = PositionGetDouble(POSITION_VOLUME);
                     g_dashboard.SetLotSize(actualLot);
                     
                     break;
                  }
               }
            }
         }
         else
         {
            if(analysis.overallSentiment == "BULLISH" && finalConfidence >= thresholdToUse)
               trade.signal = 1;
            else if(analysis.overallSentiment == "BEARISH" && finalConfidence >= thresholdToUse)
               trade.signal = -1;
            else
               trade.signal = 0;
            
            trade.pullbackPercent = range.pullbackPercent;
            trade.pullbackScore = (int)pbResult.pullbackScore;
            trade.entryReason = analysis.summary;
            trade.riskRewardRatio = 0;
            trade.entryPrice = 0;
            trade.stopLoss = 0;
            trade.takeProfit = 0;
            trade.takeProfit2 = 0;
            trade.partialLevel75 = 0;
         }
         
         SComponentResult compResult = analysis.componentResult;
         
         g_dashboard.Update(range, componentData, scenario, trade, compResult, analysis);
      }
   }
}

// ============================================================
// MANUAL FUNCTIONS (All remain unchanged)
// ============================================================

void ShowPullbackInfo()
{
   if(g_pullback == NULL || g_componentManager == NULL)
   {
      LOG_ERROR("❌ Module not initialized");
      return;
   }
   
   if(g_pullback != NULL && g_trendManager != NULL)
      g_pullback.SetTrendManager(g_trendManager);
   
   RangeData range = g_pullback.DetectRange();
   if(!range.isValid)
   {
      LOG_ERROR("❌ No valid range");
      return;
   }
   
   SPullbackAnalysisResult pbResult = g_pullback.GetPullbackAnalysis();
   int trend = g_pullback.GetTrendPublic();
   SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
   
   LOG_INFO("=== PULLBACK INFO ===", g_debugMain);
   LOG_INFO("Range: " + DoubleToString(range.rangeLow, _Digits) + " - " + 
       DoubleToString(range.rangeHigh, _Digits), g_debugMain);
   LOG_INFO("Pullback: " + DoubleToString(range.pullbackPercent, 1) + "%", g_debugMain);
   LOG_INFO("Zone: " + pbResult.zoneCategory, g_debugMain);
   LOG_INFO("Confidence: " + DoubleToString(pbResult.confidence, 1) + "%", g_debugMain);
   LOG_INFO("Trend: " + (trend == 1 ? "BULLISH" : trend == -1 ? "BEARISH" : "NEUTRAL"), g_debugMain);
   
   if(g_sessionManager != NULL)
   {
      LOG_INFO("Session: " + g_sessionManager.GetSessionName() + 
               " (" + g_sessionManager.GetSessionHours() + ")", g_debugMain);
   }
   
   if(g_riskManager != NULL)
   {
      LOG_INFO("Risk Status: " + g_riskManager.GetStatusMessage(), g_debugMain);
      LOG_INFO("Daily Trades: " + IntegerToString(g_riskManager.GetDailyTradeCount()) + 
               "/" + IntegerToString(g_riskManager.GetMaxDailyTrades()), g_debugMain);
      if(g_riskManager.IsInCooldown())
      {
         LOG_INFO("Cooldown: " + g_riskManager.GetCooldownRemaining(), g_debugMain);
      }
   }
   
   LOG_INFO("", g_debugMain);
   LOG_INFO("=== COMPONENT MANAGER ===", g_debugMain);
   LOG_INFO("Sentiment: " + analysis.overallSentiment, g_debugMain);
   LOG_INFO("Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugMain);
   LOG_INFO("Active: " + IntegerToString(analysis.activeComponents) + "/6", g_debugMain);
   LOG_INFO("=====================", g_debugMain);
}

void ShowScenario()
{
   if(g_pullback == NULL || g_componentManager == NULL || g_scenarioNarrative == NULL)
   {
      LOG_ERROR("❌ Module not initialized");
      return;
   }
   
   if(g_pullback != NULL && g_trendManager != NULL)
      g_pullback.SetTrendManager(g_trendManager);
   
   RangeData range = g_pullback.DetectRange();
   if(!range.isValid)
   {
      LOG_ERROR("❌ No valid range");
      return;
   }
   
   SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
   int trend = g_pullback.GetTrendPublic();
   SPullbackAnalysisResult pbResult = g_pullback.GetPullbackAnalysis();
   
   SComponentData componentData;
   ZeroMemory(componentData);
   
   componentData.pbConfidence = pbResult.confidence;
   componentData.pbPercent = range.pullbackPercent;
   componentData.pbAdjustedPercent = range.pullbackPercent;
   if(trend == -1) componentData.pbAdjustedPercent = 100 - range.pullbackPercent;
   componentData.pbZone = range.pullbackZone;
   
   componentData.mtfConfidence = analysis.mtfData.confidence;
   componentData.mtfTotalScore = analysis.mtfData.totalScore;
   
   componentData.macdConfidence = analysis.macdData.confidence;
   componentData.macdHistogram = analysis.macdData.histogramValue;
   componentData.macdScore = analysis.macdData.macdScore;
   
   componentData.adxConfidence = analysis.adxData.bullPercentage;
   componentData.adxValue = analysis.adxData.adxValue;
   
   componentData.rsiConfidence = analysis.rsiData.confidence;
   componentData.rsiValue = analysis.rsiData.rsiValue;
   
   componentData.volConfidence = analysis.volumeData.confidence;
   componentData.volRatio = analysis.volumeData.volumeRatio;
   componentData.priceChange = analysis.volumeData.priceChange;
   
   componentData.finalConfidence = analysis.overallConfidence;
   componentData.finalDirection = analysis.overallSentiment;
   componentData.activeComponents = analysis.activeComponents;
   componentData.overallScore = analysis.overallScore;
   
   ScenarioResult scenario = g_scenarioNarrative.DetectScenario(componentData);
   SSynthesizedScenario synthesized = g_scenarioNarrative.SynthesizeScenario(componentData);
   
   LOG_INFO("=== MARKET SCENARIO ===", g_debugMain);
   LOG_INFO("📊 " + synthesized.scenarioEmoji + " " + synthesized.scenarioName, g_debugMain);
   LOG_INFO("   Direction: " + synthesized.direction + " | Confidence: " + 
       DoubleToString(synthesized.confidence, 1) + "%", g_debugMain);
   LOG_INFO("   Action: " + synthesized.action + " | Risk: " + synthesized.riskLevel, g_debugMain);
   
   if(g_sessionManager != NULL)
   {
      LOG_INFO("   Session: " + g_sessionManager.GetSessionName() + 
               " (" + g_sessionManager.GetSessionHours() + ")", g_debugMain);
   }
   
   if(g_riskManager != NULL)
   {
      LOG_INFO("   Risk: " + g_riskManager.GetStatusMessage(), g_debugMain);
      LOG_INFO("   Daily: " + IntegerToString(g_riskManager.GetDailyTradeCount()) + 
               "/" + IntegerToString(g_riskManager.GetMaxDailyTrades()), g_debugMain);
   }
   
   LOG_INFO("", g_debugMain);
   LOG_INFO("📋 " + synthesized.narrative, g_debugMain);
   LOG_INFO("=========================", g_debugMain);
}

// ═══ CANDLE MODULE HELPER FUNCTIONS ═══

void ShowCandleStatus()
{
   if(g_candleModule == NULL)
   {
      LOG_ERROR("❌ CandleModule not initialized");
      return;
   }
   
   int trendDirection = 0;
   if(g_trendManager != NULL)
   {
      if(g_trendManager.IsBullish()) trendDirection = 1;
      else if(g_trendManager.IsBearish()) trendDirection = -1;
   }
   
   double cooldownRemaining = 0;
   if(g_riskManager != NULL)
   {
      cooldownRemaining = g_riskManager.GetCooldownRemainingSeconds();
   }
   
   SExhaustionResult result = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
   
   LOG_INFO(g_candleModule.GetExhaustionReport(result), g_debugMain);
   LOG_INFO(g_candleModule.GetStatusReport(), g_debugMain);
   
   if(g_candleModule.IsWaitingForCandle())
   {
      LOG_INFO("⏳ " + g_candleModule.GetCandleWaitStatus(), g_debugMain);
   }
}

void ForceResetCooldown()
{
   if(g_riskManager == NULL)
   {
      LOG_ERROR("❌ RiskManager not initialized");
      return;
   }
   
   if(g_riskManager.IsInCooldown())
   {
      g_riskManager.ResetCooldown();
      LOG_INFO("✅ Cooldown manually reset", g_debugMain);
   }
   else
   {
      LOG_INFO("ℹ️ Not in cooldown", g_debugMain);
   }
}

// ═══ RISK MANAGER HELPER FUNCTIONS ═══

string GetRiskStatus()
{
   if(g_riskManager == NULL) return "RiskManager not initialized";
   return g_riskManager.GetStatusMessage();
}

string GetCooldownRemaining()
{
   if(g_riskManager == NULL) return "N/A";
   return g_riskManager.GetCooldownRemaining();
}

int GetDailyTradeCount()
{
   if(g_riskManager == NULL) return 0;
   return g_riskManager.GetDailyTradeCount();
}

int GetMaxDailyTrades()
{
   if(g_riskManager == NULL) return 0;
   return g_riskManager.GetMaxDailyTrades();
}

bool IsInCooldown()
{
   if(g_riskManager == NULL) return false;
   return g_riskManager.IsInCooldown();
}

bool IsDayStopped()
{
   if(g_riskManager == NULL) return false;
   return g_riskManager.IsDayStoppedFlag();
}

bool CanTrade()
{
   if(g_riskManager == NULL) return true;
   return g_riskManager.CanTrade();
}

void ShowRiskStatus()
{
   if(g_riskManager == NULL)
   {
      LOG_ERROR("❌ RiskManager not initialized");
      return;
   }
   
   LOG_INFO("=== RISK MANAGER STATUS ===", g_debugMain);
   LOG_INFO("  Status: " + g_riskManager.GetStatusMessage(), g_debugMain);
   LOG_INFO("  Daily Trades: " + IntegerToString(g_riskManager.GetDailyTradeCount()) + 
            "/" + IntegerToString(g_riskManager.GetMaxDailyTrades()), g_debugMain);
   if(g_riskManager.IsInCooldown())
   {
      LOG_INFO("  Cooldown: " + g_riskManager.GetCooldownRemaining(), g_debugMain);
   }
   LOG_INFO("  In Cooldown: " + (g_riskManager.IsInCooldown() ? "YES" : "NO"), g_debugMain);
   LOG_INFO("  Day Stopped: " + (g_riskManager.IsDayStoppedFlag() ? "YES" : "NO"), g_debugMain);
   LOG_INFO("  Can Trade: " + (g_riskManager.CanTrade() ? "YES" : "NO"), g_debugMain);
   LOG_INFO("===========================", g_debugMain);
}

void RefreshDisplays()
{
   string chartPrefix = "PBR_" + _Symbol + "_";
   ObjectsDeleteAll(0, chartPrefix);
   
   string dashPrefix = "DASH_" + _Symbol + "_";
   ObjectsDeleteAll(0, dashPrefix);
   
   if(g_chartModule != NULL)
      g_chartModule.Update();
   
   if(g_dashboard != NULL)
      UpdateDashboard();
      
   LOG_INFO("✅ Displays refreshed", g_debugMain);
}

void ClearAllDrawings()
{
   string chartPrefix = "PBR_" + _Symbol + "_";
   ObjectsDeleteAll(0, chartPrefix);
   
   string dashPrefix = "DASH_" + _Symbol + "_";
   ObjectsDeleteAll(0, dashPrefix);
   
   LOG_INFO("✅ All drawings cleared", g_debugMain);
}

// ============================================================
// SESSION MANAGER HELPER FUNCTIONS
// ============================================================

string GetSessionInfo()
{
   if(g_sessionManager == NULL) return "SessionManager not initialized";
   return g_sessionManager.GetSessionName() + " (" + g_sessionManager.GetSessionHours() + ")";
}

int GetCurrentSessionId()
{
   if(g_sessionManager == NULL) return -1;
   return g_sessionManager.GetCurrentSessionId();
}

string GetSessionName()
{
   if(g_sessionManager == NULL) return "Unknown";
   return g_sessionManager.GetSessionName();
}

double GetSessionHigh()
{
   if(g_sessionManager == NULL) return 0;
   return g_sessionManager.GetSessionHigh();
}

double GetSessionLow()
{
   if(g_sessionManager == NULL) return 0;
   return g_sessionManager.GetSessionLow();
}

void ShowSessionInfo()
{
   if(g_sessionManager == NULL)
   {
      LOG_ERROR("❌ SessionManager not initialized");
      return;
   }
   
   SessionInfo info = g_sessionManager.GetSessionInfo();
   LOG_INFO("=== SESSION INFO ===", g_debugMain);
   LOG_INFO("  Session: " + info.name + " (" + info.shortName + ")", g_debugMain);
   LOG_INFO("  Hours: " + info.hours, g_debugMain);
   LOG_INFO("  Start: " + TimeToString(info.startTime), g_debugMain);
   LOG_INFO("  End: " + TimeToString(info.endTime), g_debugMain);
   LOG_INFO("  High: " + DoubleToString(info.high, _Digits), g_debugMain);
   LOG_INFO("  Low: " + DoubleToString(info.low, _Digits), g_debugMain);
   LOG_INFO("  Valid: " + (info.isValid ? "YES" : "NO"), g_debugMain);
   LOG_INFO("=====================", g_debugMain);
}

// ============================================================
// ORDER BLOCK DISPLAY HELPER FUNCTIONS
// ============================================================

string GetOrderBlockSummary()
{
   if(g_orderBlockDisplay == NULL) return "OrderBlockDisplay not initialized";
   return StringFormat("OBs: %d above, %d below",
                       g_orderBlockDisplay.GetTotalBlocksAbove(),
                       g_orderBlockDisplay.GetTotalBlocksBelow());
}

void ShowOrderBlocks()
{
   if(g_orderBlockDisplay == NULL)
   {
      LOG_ERROR("❌ OrderBlockDisplay not initialized");
      return;
   }
   g_orderBlockDisplay.PrintOrderBlocks();
}

OrderBlock GetClosestOrderBlockAbove()
{
   if(g_orderBlockDisplay == NULL)
   {
      OrderBlock empty;
      ZeroMemory(empty);
      empty.isValid = false;
      return empty;
   }
   return g_orderBlockDisplay.GetBlockAbove(0);
}

OrderBlock GetClosestOrderBlockBelow()
{
   if(g_orderBlockDisplay == NULL)
   {
      OrderBlock empty;
      ZeroMemory(empty);
      empty.isValid = false;
      return empty;
   }
   return g_orderBlockDisplay.GetBlockBelow(0);
}

// ============================================================
// PORTFOLIO MANAGER HELPER FUNCTIONS
// ============================================================

string GetPortfolioStatus()
{
   if(g_portfolioManager == NULL) return "PortfolioManager not initialized";
   return g_portfolioManager.GetPortfolioStatus();
}

string GetPortfolioReport()
{
   if(g_portfolioManager == NULL) return "PortfolioManager not initialized";
   return g_portfolioManager.GetComponentReport();
}

void ShowPortfolioStatus()
{
   if(g_portfolioManager == NULL)
   {
      LOG_ERROR("❌ PortfolioManager not initialized");
      return;
   }
   LOG_INFO(g_portfolioManager.GetComponentReport(), g_debugMain);
}

// ============================================================
// TREND HELPER FUNCTIONS
// ============================================================

string GetTrendSummary()
{
   if(g_trendManager == NULL) return "TrendManager not initialized";
   return g_trendManager.GetSummaryString();
}

double GetTrendStrength()
{
   if(g_trendManager == NULL) return 0;
   return g_trendManager.GetStrength();
}

string GetTrendDirection()
{
   if(g_trendManager == NULL) return "NEUTRAL";
   return g_trendManager.GetDirection();
}

bool IsBullishTrend()
{
   if(g_trendManager == NULL) return false;
   return g_trendManager.IsBullish();
}

bool IsBearishTrend()
{
   if(g_trendManager == NULL) return false;
   return g_trendManager.IsBearish();
}

void ShowTrendInfo()
{
   if(g_trendManager == NULL)
   {
      LOG_ERROR("❌ TrendManager not initialized");
      return;
   }
   LOG_INFO(g_trendManager.GetDetailedReport(), g_debugMain);
}

void ShowTrendSummary()
{
   if(g_trendManager == NULL)
   {
      LOG_ERROR("❌ TrendManager not initialized");
      return;
   }
   LOG_INFO("📊 " + g_trendManager.GetSummaryString(), g_debugMain);
}