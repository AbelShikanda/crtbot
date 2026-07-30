//+------------------------------------------------------------------+
//|                           crtbot.mq5                             |
//|                    Enhanced Trading EA with                      |
//|                    PROGRESSIVE SCENARIO SYSTEM                   |
//|                    + TREND MANAGER INTEGRATION                   |
//|                    + SIMPLE WEIGHTED SYSTEM                     |
//|                    + DYNAMIC CONFIDENCE THRESHOLDS              |
//|                    + PORTFOLIO MANAGER INTEGRATION              |
//|                    + BOOST-AWARE TP TRAILING                    |
//|                    + FIXED SL (NO BUFFER) + DEBUG               |
//|                    + TREND MANAGER VERIFICATION                 |
//|                    + BRACKET-BASED LOT SIZING                   |
//|                    + v3.47: RISK MANAGER INTEGRATED            |
//|                    + COOLDOWN ON LOSS                          |
//|                    + DAILY TRADE LIMIT (3)                    |
//|                    + PROFIT THRESHOLDS ($20)                 |
//|                    + v3.48: CANDLE MODULE INTEGRATED          |
//|                    + COOLDOWN RESET ON EXHAUSTION             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.48"
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
// GLOBAL DEBUG TOGGLES - SET TO FALSE BY DEFAULT
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
   
   LOG_INFO("=== PULLBACK EA v3.48 (CANDLE MODULE INTEGRATED) ===", g_debugMain);
   LOG_INFO("   Boost TP Distance: 100 points (when boost active)", g_debugMain);
   LOG_INFO("   TP never moves backward", g_debugMain);
   LOG_INFO("   Order Blocks: " + (InpShowOrderBlocks ? "ENABLED" : "DISABLED"), g_debugMain);
   LOG_INFO("   Max OBs: " + IntegerToString(InpMaxOrderBlocks) + " above/below", g_debugMain);
   LOG_INFO("   DEBUG: " + (g_debugMode ? "ON" : "OFF (minimal)"), g_debugMain);
   LOG_INFO("   RISK MANAGER v2.10:", g_debugMain);
   LOG_INFO("     - Cooldown: 2 hours on loss", g_debugMain);
   LOG_INFO("     - Max Daily Trades: 3", g_debugMain);
   LOG_INFO("     - Profit Threshold: $20 (stops day)", g_debugMain);
   LOG_INFO("     - Daily Reset: 3:00 AM", g_debugMain);
   LOG_INFO("   CANDLE MODULE v1.01:", g_debugMain);
   LOG_INFO("     - Monitors M15 for exhaustion during cooldown", g_debugMain);
   LOG_INFO("     - Auto-resets cooldown on valid exhaustion", g_debugMain);
   LOG_INFO("     - Requires M15 + M1 confirmation", g_debugMain);
   LOG_INFO("     - Waits for next M15 candle after cooldown starts", g_debugMain);
   
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
   // 3. CREATE POSITION MANAGER
   // ============================================================
   g_positionManager = new CPositionManager(_Symbol, g_magicNumber, g_trade);
   if(g_positionManager == NULL)
   {
      LOG_ERROR("❌ Failed to create PositionManager");
      return INIT_FAILED;
   }
   LOG_DEBUG("✅ PositionManager created", g_debugPosition);
   
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
   // 6. CREATE PULLBACK MODULE
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
      LOG_DEBUG("   TF: " + EnumToString(InpOrderBlockTF), g_debugOrderBlock);
      LOG_DEBUG("   Max Blocks: " + IntegerToString(InpMaxOrderBlocks), g_debugOrderBlock);
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
         
         // ═══ WIRE SESSION MANAGER TO CHART MODULE ═══
         g_chartModule.SetSessionManager(g_sessionManager);
         LOG_DEBUG("✅ ChartModule → SessionManager connected", g_debugMain);
         
         // ═══ WIRE ORDER BLOCK DISPLAY TO CHART MODULE ═══
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
      }
   }
   
   // ============================================================
   // 12. CREATE CANDLE MODULE (for cooldown monitoring)
   // ============================================================
   g_candleModule = new CCandleModule(_Symbol, PERIOD_M15, InpEntryTF);
   if(g_candleModule == NULL)
   {
      LOG_ERROR("❌ Failed to create CandleModule");
      return INIT_FAILED;
   }
   g_candleModule.SetDebug(g_debugCandle);
   LOG_DEBUG("✅ CandleModule created (M15 exhaustion monitoring)", g_debugMain);
   
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
   
   LOG_INFO("✅ EA INITIALIZED - v3.48 (Candle Module Integrated)", g_debugMain);
   LOG_INFO("   TrendManager → PortfolioManager: ✓", g_debugMain);
   LOG_INFO("   PortfolioManager → PositionManager: ✓ (Boost TP 100 pts)", g_debugMain);
   LOG_INFO("   PositionManager → RiskManager: ✓ (Trade result tracking)", g_debugMain);
   LOG_INFO("   PullbackModule → TrendManager: ✓", g_debugMain);
   LOG_INFO("   SessionManager: ✓ (Active Session Tracking)", g_debugMain);
   LOG_INFO("   ChartModule → SessionManager: ✓ (Session Overlays)", g_debugMain);
   LOG_INFO("   ChartModule → OrderBlockDisplay: ✓ (H4 Order Blocks)", g_debugMain);
   LOG_INFO("   CandleModule: ✓ (Cooldown exhaustion monitoring)", g_debugMain);
   LOG_INFO("   CandleModule: ✓ (Waits for next M15 candle)", g_debugMain);
   LOG_INFO("   Position management every 1 second", g_debugMain);
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
      // Track cooldown start to reset candle tracking
      static bool cooldownStartLogged = false;
      
      if(!cooldownStartLogged)
      {
         // Reset candle tracking when cooldown starts
         g_candleModule.ResetCooldownCandleTracking();
         cooldownStartLogged = true;
         
         int waitCandles = g_candleModule.GetWaitCandles();
         LOG_DEBUG("🕯️ CandleModule: Waiting for " + IntegerToString(waitCandles) + 
                   " M15 candle(s) before exhaustion check", g_debugCandle);
      }
      
      // Only check periodically (every 30 seconds during cooldown for better responsiveness)
      static datetime lastCandleCheck = 0;
      datetime currentTime = TimeCurrent();
      
      if(currentTime - lastCandleCheck >= 30)
      {
         lastCandleCheck = currentTime;
         
         // Get trend direction from TrendManager
         int trendDirection = 0;
         if(g_trendManager != NULL)
         {
            if(g_trendManager.IsBullish()) trendDirection = 1;
            else if(g_trendManager.IsBearish()) trendDirection = -1;
         }
         
         // If trend is neutral, use component manager sentiment
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
               LOG_INFO("🔄 CANDLE MODULE: Cooldown reset triggered - Exhaustion detected on M15", g_debugCandle);
               
               // Get the result details for logging
               SExhaustionResult result = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
               
               g_riskManager.ResetCooldown();
               
               string resetReason = g_candleModule.GetResetReason(trendDirection);
               LOG_INFO("   Reason: " + resetReason, g_debugMain);
               LOG_INFO("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", g_debugCandle);
               LOG_INFO("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", g_debugCandle);
               LOG_INFO("   Candles Waited: " + IntegerToString(result.candlesWaited) + "/" + IntegerToString(result.candlesRequired), g_debugCandle);
               
               g_riskStatusMessage = "Cooldown Reset: " + resetReason;
               
               // Reset the cooldown tracking flag
               cooldownStartLogged = false;
               
               if(g_dashboard != NULL)
               {
                  // Update dashboard if needed
               }
            }
            else
            {
               // Log status periodically during cooldown
               static datetime lastStatusLog = 0;
               if(currentTime - lastStatusLog >= 300) // Every 5 minutes
               {
                  lastStatusLog = currentTime;
                  SExhaustionResult result = g_candleModule.AnalyzeExhaustion(trendDirection, cooldownRemaining);
                  
                  if(!result.isValid && result.candlesWaited < g_candleModule.GetWaitCandles())
                  {
                     // Still waiting for candles
                     LOG_DEBUG("🕯️ Candle Monitor: " + result.waitStatus, g_debugCandle);
                  }
                  else if(result.isValid)
                  {
                     LOG_DEBUG("🕯️ Candle Monitor: " + result.description + " (Conf: " + 
                              DoubleToString(result.confidence, 0) + "%)", g_debugCandle);
                     LOG_DEBUG("   HTF: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", g_debugCandle);
                     LOG_DEBUG("   LTF: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", g_debugCandle);
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
      // Reset cooldown tracking flag when not in cooldown
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
      
      // Update bar time tracking for other functions
      datetime currentBarTime = iTime(_Symbol, InpEntryTF, 0);
      if(currentBarTime != g_lastBarTime)
      {
         g_lastBarTime = currentBarTime;
         // New bar detected - can trigger additional logic if needed
      }
      
      CheckSignal();
      UpdateChart();
      UpdateDashboard();
      UpdateOrderBlocks();
   }
}

//+------------------------------------------------------------------+
//| UPDATE ORDER BLOCKS - Updates every 5 seconds                   |
//+------------------------------------------------------------------+
void UpdateOrderBlocks()
{
   if(!InpShowOrderBlocks || g_orderBlockDisplay == NULL)
      return;
   
   // Update every 5 seconds
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
      
      LOG_DEBUG("✅ PullbackModule initialized", g_debugPullback);
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
         // OrderBlockDisplay doesn't need async initialization - just update
         g_orderBlockDisplay.Update();
         LOG_DEBUG("✅ OrderBlockDisplay initialized", g_debugOrderBlock);
      }
      g_initStatus = INIT_STATUS_ORDER_BLOCK_DISPLAY;
   }
   
   if(g_initStatus < INIT_STATUS_CANDLE_MODULE)
   {
      if(g_candleModule != NULL)
      {
         // CandleModule needs M15 and M1 data
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
            
            // Log current session info
            if(g_sessionManager != NULL && g_debugSession)
            {
               LOG_DEBUG("📊 Current Session: " + g_sessionManager.GetSessionName() + 
                         " (" + g_sessionManager.GetSessionHours() + ")", g_debugSession);
            }
            
            // Log Order Block info
            if(g_orderBlockDisplay != NULL && g_debugOrderBlock)
            {
               LOG_DEBUG("📊 Order Blocks: " + 
                         IntegerToString(g_orderBlockDisplay.GetTotalBlocksAbove()) + " above, " +
                         IntegerToString(g_orderBlockDisplay.GetTotalBlocksBelow()) + " below",
                         g_debugOrderBlock);
            }
            
            // Log Risk Manager status
            if(g_riskManager != NULL && g_debugRisk)
            {
               LOG_DEBUG("📊 Risk Manager: " + g_riskManager.GetStatusMessage(), g_debugRisk);
               LOG_DEBUG("   Daily Trades: " + IntegerToString(g_riskManager.GetDailyTradeCount()) + 
                         "/" + IntegerToString(g_riskManager.GetMaxDailyTrades()), g_debugRisk);
            }
            
            // Log Candle Module status
            if(g_candleModule != NULL && g_debugCandle)
            {
               LOG_DEBUG("🕯️ Candle Module: Ready (M15 exhaustion monitoring)", g_debugCandle);
               LOG_DEBUG("   Will wait for next M15 candle after cooldown starts", g_debugCandle);
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
//| TIMER - POSITION MANAGEMENT                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_initStatus != INIT_STATUS_COMPLETE)
      return;
   
   // PositionManager manages positions
   if(g_positionManager != NULL)
      g_positionManager.ManagePositions();
   
   // PortfolioManager monitors positions (boost only - no loss management)
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.Update();
      // g_portfolioManager.MonitorPositions(); // REMOVED - no loss management
   }
   
   // ═══ RISK MANAGER PERIODIC CHECK ═══
   if(g_riskManager != NULL)
   {
      // Update status message
      g_riskStatusMessage = g_riskManager.GetStatusMessage();
      g_riskCanTrade = g_riskManager.CanTrade();
   }
   
   // Update SessionManager periodically
   if(g_sessionManager != NULL)
   {
      // SessionManager auto-updates internally
      if(g_debugSession)
      {
         static datetime lastSessionLog = 0;
         if(TimeCurrent() - lastSessionLog >= 300)  // Log every 5 minutes
         {
            lastSessionLog = TimeCurrent();
            LOG_DEBUG("📊 Session: " + g_sessionManager.GetSessionName() + 
                      " | High: " + DoubleToString(g_sessionManager.GetSessionHigh(), _Digits) +
                      " | Low: " + DoubleToString(g_sessionManager.GetSessionLow(), _Digits),
                      g_debugSession);
         }
      }
   }
   
   // ═══ LOG RISK STATUS PERIODICALLY ═══
   if(g_riskManager != NULL && g_debugRisk)
   {
      static datetime lastRiskLog = 0;
      if(TimeCurrent() - lastRiskLog >= 300)  // Log every 5 minutes
      {
         lastRiskLog = TimeCurrent();
         LOG_DEBUG("📊 Risk Status: " + g_riskManager.GetStatusMessage(), g_debugRisk);
         LOG_DEBUG("   Daily Trades: " + IntegerToString(g_riskManager.GetDailyTradeCount()) + 
                   "/" + IntegerToString(g_riskManager.GetMaxDailyTrades()), g_debugRisk);
         if(g_riskManager.IsInCooldown())
         {
            LOG_DEBUG("   Cooldown: " + g_riskManager.GetCooldownRemaining(), g_debugRisk);
         }
      }
   }
   
   // ═══ CANDLE MODULE PERIODIC LOG ═══
   if(g_candleModule != NULL && g_riskManager != NULL && g_riskManager.IsInCooldown())
   {
      static datetime lastCandleLog = 0;
      if(TimeCurrent() - lastCandleLog >= 300) // Log every 5 minutes during cooldown
      {
         lastCandleLog = TimeCurrent();
         if(g_debugCandle)
         {
            string status = g_candleModule.GetStatusReport();
            string waitStatus = g_candleModule.GetCandleWaitStatus();
            LOG_DEBUG("🕯️ " + status, g_debugCandle);
            LOG_DEBUG("   ⏳ " + waitStatus, g_debugCandle);
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
   
   // OrderBlockDisplay objects are deleted by its destructor
   // but we also clean up any remaining OB objects
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
//| CalculateTakeProfits - ENFORCE MINIMUM RR 1.5:1                 |
//| SL = rangeLow (BUY) or rangeHigh (SELL) - Risk is fixed        |
//| TP must be at least 1.5x the Risk                              |
//+------------------------------------------------------------------+
bool CalculateTakeProfits(int signal, double currentPrice, double rangeHigh, double rangeLow, 
                          double pullbackPercent, double riskAmount, 
                          double &primaryTP, double &rr,
                          double portfolioBoost = 0)
{
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double rangeSize = rangeHigh - rangeLow;
   
   // ──────────────────────────────────────────────────────────────
   // VALIDATION
   // ──────────────────────────────────────────────────────────────
   if(rangeHigh == 0 || rangeLow == 0 || rangeHigh <= rangeLow)
   {
      LOG_ERROR("❌ Invalid range data");
      return false;
   }
   
   if(riskAmount <= 0)
   {
      LOG_ERROR("❌ Invalid risk amount");
      return false;
   }
   
   // ──────────────────────────────────────────────────────────────
   // RISK IS FIXED = riskAmount (distance from entry to SL)
   // ──────────────────────────────────────────────────────────────
   double risk = riskAmount;  // This is always 1 unit of risk
   
   // ──────────────────────────────────────────────────────────────
   // CALCULATE REWARD (distance from entry to range extreme)
   // ──────────────────────────────────────────────────────────────
   double reward = 0;
   
   if(signal == 1)  // BUY - TP at rangeHigh
   {
      reward = rangeHigh - currentPrice;
   }
   else  // SELL - TP at rangeLow
   {
      reward = currentPrice - rangeLow;
   }
   
   if(reward < 0) reward = 0;
   
   // ──────────────────────────────────────────────────────────────
   // CALCULATE RISK-REWARD RATIO
   // RR = Reward / Risk
   // ──────────────────────────────────────────────────────────────
   rr = (risk > 0) ? reward / risk : 0;
   
   double requiredRR = InpMinRR;  // 1.5
   
   // ──────────────────────────────────────────────────────────────
   // CHECK IF RR MEETS MINIMUM 1.5:1
   // ──────────────────────────────────────────────────────────────
   if(rr >= requiredRR)
   {
      // ✅ PASS - Use range-based TP
      if(signal == 1)
         primaryTP = rangeHigh;
      else
         primaryTP = rangeLow;
      
      LOG_DEBUG("✅ RR: " + DoubleToString(rr, 2) + ":1 >= Minimum " + 
                DoubleToString(requiredRR, 1) + ":1 - Trade accepted", g_debugMain);
      return true;
   }
   else
   {
      // ❌ FAIL - RR too low
      LOG_DEBUG("❌❌❌ TRADE REJECTED: RR too low", g_debugMain);
      LOG_DEBUG("   Risk: " + DoubleToString(risk / pointValue, 1) + " pips", g_debugMain);
      LOG_DEBUG("   Reward: " + DoubleToString(reward / pointValue, 1) + " pips", g_debugMain);
      LOG_DEBUG("   RR: " + DoubleToString(rr, 2) + ":1", g_debugMain);
      LOG_DEBUG("   Required: " + DoubleToString(requiredRR, 1) + ":1 (Minimum)", g_debugMain);
      return false;
   }
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
//| CheckSignal - TREND MANAGER RECOMMENDATIONS FIRST               |
//| REJECT entry if TrendManager says no                           |
//| REJECT entry if Risk-Reward < 1.5:1                            |
//| REJECT entry if in NO GO ZONE (0-20% or 90-100%)              |
//| REJECT entry if RiskManager says no                           |
//| SL Buffer protection included                                   |
//| WITH FULL DEBUG LOGGING                                        |
//+------------------------------------------------------------------+
void CheckSignal()
{
   if(g_componentManager == NULL || g_trendManager == NULL) 
   {
      LOG_DEBUG("❌ CheckSignal: ComponentManager or TrendManager is NULL", g_debugMain);
      return;
   }
   
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   LOG_DEBUG("🔍 CHECK SIGNAL STARTED", g_debugMain);
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 1: TREND MANAGER RECOMMENDATION CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 1: Trend Manager Recommendation Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(1, "Analyzing recommendations...");
   UpdateDashboard();
   
   // Check Risk Manager first (quick exit)
   if(g_riskManager != NULL && !g_riskManager.CanTrade())
   {
      LOG_DEBUG("❌ Risk Manager blocks trading: " + g_riskManager.GetStatusMessage(), g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Risk blocks trading: " + g_riskManager.GetStatusMessage());
      return;
   }
   LOG_DEBUG("✅ Risk Manager passed", g_debugMain);
   
   // ─── ANALYZE TREND (this updates all TrendManager data) ───
   LOG_DEBUG("📊 Calling g_trendManager.AnalyzeTrend()...", g_debugMain);
   STrendResult trendResult = g_trendManager.AnalyzeTrend();
   LOG_DEBUG("✅ AnalyzeTrend() complete", g_debugMain);
   
   // ─── GET CROSSOVER RECOMMENDATION ───
   LOG_DEBUG("📊 Getting crossover data...", g_debugMain);
   int crossoverPriority = g_trendManager.GetCrossoverPriority();
   string crossoverScenario = g_trendManager.GetCrossoverScenarioName();
   bool isGoldenCross = g_trendManager.IsGoldenCross();
   bool isDeathCross = g_trendManager.IsDeathCross();
   string trendDirection = g_trendManager.GetDirection();
   double trendStrength = g_trendManager.GetStrength();
   double trendConfidence = g_trendManager.GetTrendConfidence();
   bool isM1Compatible = g_trendManager.IsM1Compatible();
   bool isStrongTrend = g_trendManager.IsStrongTrend();
   ENUM_CROSS_STATE m15State = g_trendManager.GetM15CrossState();
   ENUM_CROSS_STATE m5State = g_trendManager.GetM5CrossState();
   string m1Position = g_trendManager.GetM1Position();
   
   // ─── DEBUG: LOG ALL TREND MANAGER DATA ───
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   LOG_DEBUG("📊 TREND MANAGER DATA:", g_debugMain);
   LOG_DEBUG("   Trend Direction: " + trendDirection, g_debugMain);
   LOG_DEBUG("   Trend Strength: " + DoubleToString(trendStrength, 1) + "%", g_debugMain);
   LOG_DEBUG("   Trend Confidence: " + DoubleToString(trendConfidence, 1) + "%", g_debugMain);
   LOG_DEBUG("   Is Strong Trend: " + (isStrongTrend ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   Is M1 Compatible: " + (isM1Compatible ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   Crossover Priority: " + IntegerToString(crossoverPriority), g_debugMain);
   LOG_DEBUG("   Crossover Scenario: " + crossoverScenario, g_debugMain);
   LOG_DEBUG("   Golden Cross: " + (isGoldenCross ? "✅ YES" : "❌ NO"), g_debugMain);
   LOG_DEBUG("   Death Cross: " + (isDeathCross ? "✅ YES" : "❌ NO"), g_debugMain);
   LOG_DEBUG("   M15 21 vs 89 State: " + GetStateName(m15State), g_debugMain);
   LOG_DEBUG("   M5 21 vs 89 State: " + GetStateName(m5State), g_debugMain);
   LOG_DEBUG("   M1 Position: " + m1Position, g_debugMain);
   LOG_DEBUG("   M1 Distance: " + DoubleToString(g_trendManager.GetLastCrossover().m1_distance, 1) + " pts", g_debugMain);
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   
   // ─── DEBUG: LOG MA VALUES ───
   LOG_DEBUG("📊 MA VALUES:", g_debugMain);
   LOG_DEBUG("   M15 MA21: " + DoubleToString(g_trendManager.GetMA21_M15(), _Digits), g_debugMain);
   LOG_DEBUG("   M15 MA89: " + DoubleToString(g_trendManager.GetMA89_M15(), _Digits), g_debugMain);
   LOG_DEBUG("   M15 MA200: " + DoubleToString(g_trendManager.GetMA200_M15(), _Digits), g_debugMain);
   LOG_DEBUG("   M15 21-89 Diff: " + DoubleToString(g_trendManager.GetMA21_M15() - g_trendManager.GetMA89_M15(), _Digits), g_debugMain);
   LOG_DEBUG("   M5 MA21: " + DoubleToString(g_trendManager.GetMA21_M5(), _Digits), g_debugMain);
   LOG_DEBUG("   M5 MA89: " + DoubleToString(g_trendManager.GetMA89_M5(), _Digits), g_debugMain);
   LOG_DEBUG("   M5 21-89 Diff: " + DoubleToString(g_trendManager.GetMA21_M5() - g_trendManager.GetMA89_M5(), _Digits), g_debugMain);
   LOG_DEBUG("   M1 MA21: " + DoubleToString(g_trendManager.GetMA21_M1(), _Digits), g_debugMain);
   LOG_DEBUG("   Current Price: " + DoubleToString(g_trendManager.GetCurrentPrice(), _Digits), g_debugMain);
   LOG_DEBUG("   Price vs M1 MA21: " + DoubleToString(g_trendManager.GetCurrentPrice() - g_trendManager.GetMA21_M1(), _Digits), g_debugMain);
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   
   // ─── DETERMINE ENTRY STATUS BASED ON RECOMMENDATION ───
   bool isEntrySignal = (crossoverPriority <= 3);
   bool isStrongEntry = (crossoverPriority == 1);
   bool isDipEntry = (crossoverPriority == 2);
   bool isPullbackEntry = (crossoverPriority == 3);
   bool isWatchSignal = (crossoverPriority == 4);
   
   LOG_DEBUG("📊 Entry Status:", g_debugMain);
   LOG_DEBUG("   isEntrySignal: " + (isEntrySignal ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   isStrongEntry: " + (isStrongEntry ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   isDipEntry: " + (isDipEntry ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   isPullbackEntry: " + (isPullbackEntry ? "YES" : "NO"), g_debugMain);
   LOG_DEBUG("   isWatchSignal: " + (isWatchSignal ? "YES" : "NO"), g_debugMain);
   
   // ─── BUILD RECOMMENDATION STATUS ───
   string recStatus = "";
   
   if(isEntrySignal)
   {
      if(isStrongEntry)
         recStatus = "STRONG ENTRY (" + crossoverScenario + ")";
      else if(isDipEntry)
         recStatus = "DIP ENTRY (" + crossoverScenario + ")";
      else if(isPullbackEntry)
         recStatus = "PULLBACK ENTRY (" + crossoverScenario + ")";
   }
   else if(isWatchSignal)
   {
      recStatus = "WATCH (" + crossoverScenario + ")";
   }
   else
   {
      recStatus = "WAIT - No clear signal";
   }
   
   LOG_DEBUG("📊 Recommendation Status: " + recStatus, g_debugMain);
   
   // ─── CHECK IF TREND MANAGER RECOMMENDATION IS VALID ───
   if(!isEntrySignal)
   {
      LOG_DEBUG("❌ Recommendation is NOT an entry signal", g_debugMain);
      if(g_dashboard != NULL)
      {
         if(isWatchSignal)
            g_dashboard.SetCheckFailed(1, "Recommendation: " + recStatus + " - Monitor for entry");
         else
            g_dashboard.SetCheckFailed(1, "Recommendation: " + recStatus + " - No clear direction");
      }
      LOG_DEBUG("⛔ CheckSignal EXITING - No entry signal", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Recommendation is an entry signal", g_debugMain);
   
   // ─── CHECK TREND STRENGTH ───
   LOG_DEBUG("📊 Checking trend strength against InpMinTrendStrength (" + DoubleToString(InpMinTrendStrength, 1) + "%)", g_debugMain);
   if(trendStrength < InpMinTrendStrength)
   {
      LOG_DEBUG("❌ Trend too weak: " + DoubleToString(trendStrength, 1) + "% < " + DoubleToString(InpMinTrendStrength, 1) + "%", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Trend too weak: " + DoubleToString(trendStrength, 1) + "% < " + DoubleToString(InpMinTrendStrength, 1) + "%");
      LOG_DEBUG("⛔ CheckSignal EXITING - Trend too weak", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Trend strength passed", g_debugMain);
   
   // ─── CHECK STRONG TREND REQUIREMENT ───
   if(InpRequireStrongTrend && !isStrongTrend)
   {
      LOG_DEBUG("❌ Trend not strong enough: " + DoubleToString(trendStrength, 1) + "% (requires 60%+)", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Trend not strong enough: " + DoubleToString(trendStrength, 1) + "%");
      LOG_DEBUG("⛔ CheckSignal EXITING - Not strong enough", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Strong trend check passed", g_debugMain);
   
   // ─── CHECK NEUTRAL TREND ALLOWANCE ───
   if(!InpAllowNeutralTrend && trendDirection == "NEUTRAL")
   {
      LOG_DEBUG("❌ Trend: NEUTRAL not allowed", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "Trend: NEUTRAL not allowed");
      LOG_DEBUG("⛔ CheckSignal EXITING - Neutral not allowed", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Neutral trend check passed", g_debugMain);
   
   // ─── CHECK M1 COMPATIBILITY ───
   if(!isM1Compatible)
   {
      LOG_DEBUG("❌ M1 not compatible: Strength " + DoubleToString(trendStrength, 1) + "% < Moderate threshold", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(1, "M1 not compatible: Strength " + DoubleToString(trendStrength, 1) + "% < threshold");
      LOG_DEBUG("⛔ CheckSignal EXITING - M1 not compatible", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ M1 compatibility passed", g_debugMain);
   
   // ✅ TREND MANAGER RECOMMENDATION PASSED
   string passMessage = "Recommendation: " + recStatus + " | " + trendDirection + " (" + DoubleToString(trendStrength, 1) + "%)";
   if(isGoldenCross) passMessage += " | GOLDEN CROSS!";
   if(isDeathCross) passMessage += " | DEATH CROSS!";
   LOG_DEBUG("✅ RECOMMENDATION PASSED: " + passMessage, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(1, passMessage);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 2: CROSSOVER DETAIL CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 2: Crossover Detail Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(2, "Crossover: " + crossoverScenario + " (P" + IntegerToString(crossoverPriority) + ")");
   UpdateDashboard();
   
   // Crossover already passed in step 1, but we log the details
   string crossoverDetail = "Crossover: " + crossoverScenario + " (P" + IntegerToString(crossoverPriority) + ")";
   if(isGoldenCross) crossoverDetail += " | GOLDEN CROSS!";
   else if(isDeathCross) crossoverDetail += " | DEATH CROSS!";
   LOG_DEBUG("✅ Crossover passed: " + crossoverDetail, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(2, crossoverDetail);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 3: PULLBACK CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 3: Pullback Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(3, "Checking range and zone...");
   UpdateDashboard();
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_componentManager.SetCurrentPrice(currentPrice);
   LOG_DEBUG("   Current Price: " + DoubleToString(currentPrice, _Digits), g_debugMain);
   
   if(g_pullback != NULL && g_trendManager != NULL)
      g_pullback.SetTrendManager(g_trendManager);
   
   SPullbackAnalysisResult pbResult = g_pullback.GetPullbackAnalysis();
   int trend = g_pullback.GetTrendPublic();
   
   LOG_DEBUG("   Pullback Range High: " + DoubleToString(pbResult.rangeHigh, _Digits), g_debugMain);
   LOG_DEBUG("   Pullback Range Low: " + DoubleToString(pbResult.rangeLow, _Digits), g_debugMain);
   LOG_DEBUG("   Pullback Percent: " + DoubleToString(pbResult.pullbackPercent, 1) + "%", g_debugMain);
   LOG_DEBUG("   Pullback Zone: " + pbResult.zoneCategory, g_debugMain);
   
   if(!pbResult.showOnChart || pbResult.rangeHigh == 0 || pbResult.rangeLow == 0)
   {
      LOG_DEBUG("❌ Pullback: No valid range", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(3, "Pullback: No valid range");
      LOG_DEBUG("⛔ CheckSignal EXITING - No valid range", g_debugMain);
      return;
   }
   
   if(pbResult.rangeHigh <= pbResult.rangeLow)
   {
      LOG_DEBUG("❌ Pullback: Invalid range (High <= Low)", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(3, "Pullback: Invalid range");
      LOG_DEBUG("⛔ CheckSignal EXITING - Invalid range", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Pullback range valid", g_debugMain);
   
   // Check No Go Zone
   if(g_pullback != NULL && g_pullback.IsNoGoZone(pbResult.pullbackPercent))
   {
      string noGoReason = "";
      if(pbResult.pullbackPercent <= 20.0)
         noGoReason = "TOO EARLY (0-20%)";
      else if(pbResult.pullbackPercent >= 90.0)
         noGoReason = "OVEREXTENDED (90-100%)";
      else
         noGoReason = "NO GO ZONE";
      
      LOG_DEBUG("❌ Pullback: NO GO ZONE - " + noGoReason + " (" + DoubleToString(pbResult.pullbackPercent, 1) + "%)", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(3, "Pullback: NO GO ZONE - " + noGoReason + " (" + DoubleToString(pbResult.pullbackPercent, 1) + "%)");
      LOG_DEBUG("⛔ CheckSignal EXITING - No Go Zone", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Pullback not in No Go Zone", g_debugMain);
   
   // ✅ PULLBACK PASSED
   string pbPassMsg = "Pullback: " + pbResult.zoneCategory + " (" + DoubleToString(pbResult.pullbackPercent, 1) + "%)";
   LOG_DEBUG("✅ " + pbPassMsg, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(3, pbPassMsg);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 4: CONFIDENCE CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 4: Confidence Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(4, "Checking confidence thresholds...");
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
   
   // Use TrendManager direction for final sentiment
   string finalSentiment = trendDirection;
   if(finalSentiment == "NEUTRAL")
   {
      finalSentiment = analysis.overallSentiment;
   }
   
   double thresholdToUse = GetThresholdForDirection(finalSentiment);
   
   LOG_DEBUG("   Final Sentiment: " + finalSentiment, g_debugMain);
   LOG_DEBUG("   Overall Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugMain);
   LOG_DEBUG("   Threshold: " + DoubleToString(thresholdToUse, 1) + "%", g_debugMain);
   LOG_DEBUG("   Portfolio Boost: " + StringFormat("%+.1f%%", portfolioBoost), g_debugMain);
   
   if(finalSentiment == "NEUTRAL")
   {
      LOG_DEBUG("❌ Confidence: NEUTRAL sentiment - no clear direction", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "Confidence: NEUTRAL sentiment - no clear direction");
      LOG_DEBUG("⛔ CheckSignal EXITING - Neutral sentiment", g_debugMain);
      return;
   }
   
   if(analysis.overallConfidence < thresholdToUse)
   {
      LOG_DEBUG("❌ Confidence too low: " + DoubleToString(analysis.overallConfidence, 1) + "% < " + DoubleToString(thresholdToUse, 1) + "%", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "Confidence too low: " + DoubleToString(analysis.overallConfidence, 1) + "% < " + DoubleToString(thresholdToUse, 1) + "%");
      LOG_DEBUG("⛔ CheckSignal EXITING - Confidence too low", g_debugMain);
      return;
   }
   LOG_DEBUG("✅ Confidence passed", g_debugMain);
   
   // Check trend alignment
   bool signalAlignsWithTrend = false;
   
   if(finalSentiment == "BULLISH" && 
      (trendDirection == "BULLISH" || 
       (trendDirection == "NEUTRAL" && InpAllowNeutralTrend)))
   {
      signalAlignsWithTrend = true;
   }
   else if(finalSentiment == "BEARISH" && 
           (trendDirection == "BEARISH" || 
            (trendDirection == "NEUTRAL" && InpAllowNeutralTrend)))
   {
      signalAlignsWithTrend = true;
   }
   
   LOG_DEBUG("   Signal aligns with trend: " + (signalAlignsWithTrend ? "YES" : "NO"), g_debugMain);
   
   if(!signalAlignsWithTrend)
   {
      LOG_DEBUG("❌ Confidence: Signal does not align with trend", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(4, "Confidence: Signal does not align with trend");
      LOG_DEBUG("⛔ CheckSignal EXITING - Signal doesn't align", g_debugMain);
      return;
   }
   
   // ✅ CONFIDENCE PASSED
   string confMessage = "Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "% ≥ " + DoubleToString(thresholdToUse, 1) + "%";
   if(portfolioBoost != 0)
      confMessage += " | Boost: " + StringFormat("%+.1f%%", portfolioBoost);
   LOG_DEBUG("✅ " + confMessage, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(4, confMessage);
   UpdateDashboard();
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 5: RISK CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 5: Risk Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(5, "Checking risk limits...");
   UpdateDashboard();
   
   if(g_riskManager != NULL && !g_riskManager.CheckRiskLimits())
   {
      LOG_DEBUG("❌ Risk: " + g_riskManager.GetStatusMessage(), g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(5, "Risk: " + g_riskManager.GetStatusMessage());
      LOG_DEBUG("⛔ CheckSignal EXITING - Risk check failed", g_debugMain);
      return;
   }
   
   // ✅ RISK PASSED
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
   // ═══ STEP 6: RR CHECK ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 6: RR Check", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(6, "Calculating risk-reward ratio...");
   UpdateDashboard();
   
   double rangeHigh = pbResult.rangeHigh;
   double rangeLow = pbResult.rangeLow;
   double rangeSize = rangeHigh - rangeLow;
   double pullbackPercent = pbResult.pullbackPercent;
   string zoneCategory = pbResult.zoneCategory;
   
   LOG_DEBUG("   Range High: " + DoubleToString(rangeHigh, _Digits), g_debugMain);
   LOG_DEBUG("   Range Low: " + DoubleToString(rangeLow, _Digits), g_debugMain);
   LOG_DEBUG("   Range Size: " + DoubleToString(rangeSize, _Digits), g_debugMain);
   
   if(rangeHigh == 0 || rangeLow == 0 || rangeHigh <= rangeLow)
   {
      LOG_DEBUG("❌ RR Check: Invalid range", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: Invalid range");
      LOG_DEBUG("⛔ CheckSignal EXITING - Invalid range", g_debugMain);
      return;
   }
   
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   PrescribedTrade trade;
   ZeroMemory(trade);
   
   // ─── DETERMINE TRADE DIRECTION ───
   // Use TrendManager direction first, fallback to ComponentManager
   if(trendDirection == "BULLISH")
      trade.signal = 1;
   else if(trendDirection == "BEARISH")
      trade.signal = -1;
   else if(analysis.overallSentiment == "BULLISH")
      trade.signal = 1;
   else if(analysis.overallSentiment == "BEARISH")
      trade.signal = -1;
   else
      trade.signal = 0;
   
   LOG_DEBUG("   Trade Signal: " + (trade.signal == 1 ? "BUY" : trade.signal == -1 ? "SELL" : "NONE"), g_debugMain);
   
   if(trade.signal == 0)
   {
      LOG_DEBUG("❌ RR Check: No signal direction", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: No signal direction");
      LOG_DEBUG("⛔ CheckSignal EXITING - No signal direction", g_debugMain);
      return;
   }
   
   trade.entryPrice = currentPrice;
   
   // ─── SET STOP LOSS ───
   double slBuffer = InpSLBufferPoints * pointValue;
   
   if(trade.signal == 1)
      trade.stopLoss = rangeLow - slBuffer;
   else
      trade.stopLoss = rangeHigh + slBuffer;
   
   LOG_DEBUG("   SL Buffer: " + DoubleToString(slBuffer, _Digits) + " (" + IntegerToString(InpSLBufferPoints) + " points)", g_debugMain);
   LOG_DEBUG("   Stop Loss: " + DoubleToString(trade.stopLoss, _Digits), g_debugMain);
   
   if(trade.stopLoss <= 0)
   {
      LOG_DEBUG("❌ RR Check: Invalid SL level", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: Invalid SL level");
      LOG_DEBUG("⛔ CheckSignal EXITING - Invalid SL", g_debugMain);
      return;
   }
   
   double riskAmount = MathAbs(trade.stopLoss - trade.entryPrice);
   double riskPips = riskAmount / pointValue;
   
   LOG_DEBUG("   Risk Amount: " + DoubleToString(riskAmount, _Digits) + " (" + DoubleToString(riskPips, 1) + " pips)", g_debugMain);
   
   if(riskAmount <= 0)
   {
      LOG_DEBUG("❌ RR Check: Invalid risk amount", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: Invalid risk amount");
      LOG_DEBUG("⛔ CheckSignal EXITING - Invalid risk", g_debugMain);
      return;
   }
   
   double primaryTP = 0, rr = 0;
   bool rrPassed = CalculateTakeProfits(trade.signal, trade.entryPrice, rangeHigh, rangeLow, 
                                       pullbackPercent, riskAmount, primaryTP, rr,
                                       portfolioBoost);
   
   LOG_DEBUG("   RR Calculated: " + DoubleToString(rr, 2) + ":1", g_debugMain);
   LOG_DEBUG("   RR Passed: " + (rrPassed ? "YES" : "NO"), g_debugMain);
   
   if(!rrPassed)
   {
      LOG_DEBUG("❌ RR Check: " + DoubleToString(rr, 2) + ":1 < " + DoubleToString(InpMinRR, 1) + ":1 minimum", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: " + DoubleToString(rr, 2) + ":1 < " + DoubleToString(InpMinRR, 1) + ":1 minimum");
      LOG_DEBUG("⛔ CheckSignal EXITING - RR too low", g_debugMain);
      return;
   }
   
   if(primaryTP <= 0)
   {
      LOG_DEBUG("❌ RR Check: Invalid TP level", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(6, "RR Check: Invalid TP level");
      LOG_DEBUG("⛔ CheckSignal EXITING - Invalid TP", g_debugMain);
      return;
   }
   
   // ✅ RR CHECK PASSED
   string rrPassMsg = "RR Check: " + DoubleToString(rr, 2) + ":1 ≥ " + DoubleToString(InpMinRR, 1) + ":1";
   LOG_DEBUG("✅ " + rrPassMsg, g_debugMain);
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPassed(6, rrPassMsg);
   UpdateDashboard();
   
   trade.takeProfit = primaryTP;
   trade.takeProfit2 = 0;
   
   double rewardAmount = MathAbs(trade.takeProfit - trade.entryPrice);
   double rewardPips = rewardAmount / pointValue;
   trade.riskRewardRatio = rewardAmount / riskAmount;
   trade.riskRewardRatio2 = 0;
   
   LOG_DEBUG("   Take Profit: " + DoubleToString(trade.takeProfit, _Digits) + " (" + DoubleToString(rewardPips, 1) + " pips)", g_debugMain);
   LOG_DEBUG("   Reward Amount: " + DoubleToString(rewardAmount, _Digits), g_debugMain);
   
   // Calculate partial level
   if(trade.signal == 1)
      trade.partialLevel75 = trade.entryPrice + (trade.takeProfit - trade.entryPrice) * 0.75;
   else
      trade.partialLevel75 = trade.entryPrice - (trade.entryPrice - trade.takeProfit) * 0.75;
   
   trade.pullbackPercent = pbResult.pullbackPercent;
   trade.pullbackScore = (int)pbResult.pullbackScore;
   trade.entryReason = zoneCategory + " pullback - " + crossoverScenario + " (P" + IntegerToString(crossoverPriority) + ") - Boost " + StringFormat("%+.1f%%", portfolioBoost);
   
   // ─── LOG TRADE DETAILS ───
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   LOG_TRADE("✅✅✅ TRADE SIGNAL ACCEPTED ✅✅✅");
   LOG_TRADE("   Direction: " + (trade.signal == 1 ? "LONG (BUY)" : "SHORT (SELL)"));
   LOG_TRADE("   Recommendation: " + crossoverScenario + " (Priority " + IntegerToString(crossoverPriority) + ")");
   if(isGoldenCross) LOG_TRADE("   GOLDEN CROSS DETECTED!");
   if(isDeathCross) LOG_TRADE("   DEATH CROSS DETECTED!");
   LOG_TRADE("   Trend: " + trendDirection + " | Strength: " + DoubleToString(trendStrength, 1) + "%");
   LOG_TRADE("   M1 Compatible: " + (isM1Compatible ? "YES" : "NO"));
   LOG_TRADE("   Entry: " + DoubleToString(trade.entryPrice, _Digits));
   LOG_TRADE("   Stop Loss: " + DoubleToString(trade.stopLoss, _Digits) + 
            " (" + DoubleToString(riskPips, 1) + " pips risk)");
   LOG_TRADE("   Take Profit: " + DoubleToString(trade.takeProfit, _Digits) + 
            " (" + DoubleToString(rewardPips, 1) + " pips reward)");
   LOG_TRADE("   Risk-Reward: " + DoubleToString(trade.riskRewardRatio, 2) + ":1");
   LOG_TRADE("   Pullback Zone: " + zoneCategory + " (" + 
            DoubleToString(pullbackPercent, 1) + "%)");
   LOG_TRADE("   Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%");
   if(portfolioBoost != 0)
      LOG_TRADE("   Portfolio Boost: " + StringFormat("%+.1f%%", portfolioBoost));
   
   if(g_riskManager != NULL)
   {
      LOG_TRADE("   Risk Status: " + g_riskManager.GetStatusMessage());
   }
   
   if(g_sessionManager != NULL)
   {
      LOG_TRADE("   Session: " + g_sessionManager.GetSessionName());
   }
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ STEP 7: EXECUTION ═══
   // ═══════════════════════════════════════════════════════════════
   LOG_DEBUG("📌 STEP 7: Execution", g_debugMain);
   
   if(g_dashboard != NULL)
      g_dashboard.SetCheckPending(7, "Executing trade...");
   UpdateDashboard();
   
   // ─── CALCULATE LOT SIZE ───
   double lotSize = InpLotSize;
   if(g_riskManager != NULL)
      lotSize = g_riskManager.CalculateLotSize(trade);
   
   // ─── ADJUST LOT SIZE BASED ON RECOMMENDATION PRIORITY ───
   if(isStrongEntry)
      lotSize = lotSize * 1.0;      // 100% - Full position
   else if(isDipEntry)
      lotSize = lotSize * 0.85;     // 85% - Slightly reduced
   else if(isPullbackEntry)
      lotSize = lotSize * 0.65;     // 65% - Reduced position
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   if(stepLot > 0)
      lotSize = MathRound(lotSize / stepLot) * stepLot;
   
   LOG_DEBUG("   Lot Size: " + DoubleToString(lotSize, 2) + " (Priority " + IntegerToString(crossoverPriority) + ")", g_debugMain);
   
   // ─── EXECUTE TRADE ───
   if(InpEnableTrading && g_positionManager != NULL)
   {
      LOG_DEBUG("   Executing trade...", g_debugMain);
      bool execResult = g_positionManager.ExecuteTrade(trade, lotSize);
      if(execResult)
      {
         LOG_TRADE("✅✅✅ TRADE EXECUTED SUCCESSFULLY ✅✅✅");
         LOG_DEBUG("✅ Trade executed successfully", g_debugMain);
         
         if(g_riskManager != NULL)
            g_riskManager.OnTradeExecuted();
         
         string dirText = trade.signal == 1 ? "BUY" : "SELL";
         if(g_dashboard != NULL)
         {
            g_dashboard.SetCheckPassed(7, "SUCCESSFUL - " + dirText + " @ " + DoubleToString(trade.entryPrice, _Digits));
            g_dashboard.SetTradeExecuted();
         }
      }
      else
      {
         LOG_ERROR("❌❌❌ TRADE EXECUTION FAILED ❌❌❌");
         LOG_DEBUG("❌ Trade execution failed", g_debugMain);
         if(g_dashboard != NULL)
            g_dashboard.SetCheckFailed(7, "Execution FAILED");
      }
   }
   else
   {
      LOG_DEBUG("⚠️ Trading disabled - Signal detected but not executed", g_debugMain);
      if(g_dashboard != NULL)
         g_dashboard.SetCheckFailed(7, "Trading disabled");
   }
   
   LOG_DEBUG("═══════════════════════════════════════════════════════════", g_debugMain);
   LOG_DEBUG("🔍 CHECK SIGNAL COMPLETE", g_debugMain);
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
// MANUAL FUNCTIONS
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
   
   // ═══ SHOW RISK MANAGER STATUS ═══
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
   
   // ═══ SHOW RISK MANAGER STATUS ═══
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
   
   // Show the detailed report
   LOG_INFO(g_candleModule.GetExhaustionReport(result), g_debugMain);
   
   // Show the status report with pattern percentages
   LOG_INFO(g_candleModule.GetStatusReport(), g_debugMain);
   
   // Show wait status if waiting for next candle
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