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
//|                    + v3.43: REMOVED MACD OPPOSITION CHECKS     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.43"
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
#include "include/Core/ScenarioNarrative.mqh"

// Trend Module
#include "include/PackageManagers/TrendManager.mqh"

#include "include/PackageManagers/PositionManager.mqh"
#include "include/PackageManagers/Riskmanager.mqh"
#include "include/PackageManagers/PortfolioManager.mqh"

// Core Modules
#include "include/Core/Dashboard.mqh"
#include "include/Core/ChartModule.mqh"
#include "include/PackageManagers/ComponentManager.mqh"

// ============================================================
// GLOBAL DEBUG TOGGLES - SET TO FALSE BY DEFAULT
// ============================================================
bool g_debugMode = false;
bool g_debugMain = true;
bool g_debugTrend = false;
bool g_debugPortfolio = false;
bool g_debugPosition = false;
bool g_debugRisk = false;
bool g_debugComponent = false;
bool g_debugPullback = false;

// ============================================================
// INPUT PARAMETERS - LOSS MANAGEMENT
// ============================================================
input bool InpEnableLossManagement = true;        // Enable Loss Management
input double InpLossCloseConfidence = 10.0;        // MACD Confidence % to close
input bool InpCloseOnMACDDivergence = true;        // Close on MACD divergence

// ============================================================
// GLOBAL VARIABLES
// ============================================================
CPullbackModule   *g_pullback = NULL;
CPositionManager  *g_positionManager = NULL;
CRiskManager      *g_riskManager = NULL;
CPortfolioManager *g_portfolioManager = NULL;
CComponentManager *g_componentManager = NULL;
CTrendManager     *g_trendManager = NULL;
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
// INITIALIZATION STATUS TRACKING
// ============================================================
enum EInitStatus
{
   INIT_STATUS_NOT_STARTED,
   INIT_STATUS_TREND_MANAGER,
   INIT_STATUS_COMPONENT_MANAGER,
   INIT_STATUS_PULLBACK,
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
   
   LOG_INFO("=== PULLBACK EA v3.43 (REMOVED MACD OPPOSITION CHECKS) ===", g_debugMain);
   LOG_INFO("   Boost TP Distance: 100 points (when boost active)", g_debugMain);
   LOG_INFO("   TP never moves backward", g_debugMain);
   LOG_INFO("   Loss Management: " + (InpEnableLossManagement ? "ENABLED" : "DISABLED"), g_debugMain);
   LOG_INFO("   MACD Close Confidence: " + DoubleToString(InpLossCloseConfidence, 0) + "%", g_debugMain);
   LOG_INFO("   DEBUG: " + (g_debugMode ? "ON" : "OFF (minimal)"), g_debugMain);
   
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
   // g_trendManager.EnableDebug(g_debugTrend);
   
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
   // 4. CREATE PORTFOLIO MANAGER (v3.6 - Fixed MACD Loss Management)
   // ============================================================
   g_portfolioManager = new CPortfolioManager(_Symbol, g_magicNumber, g_trade);
   if(g_portfolioManager == NULL)
   {
      LOG_ERROR("❌ Failed to create PortfolioManager");
      return INIT_FAILED;
   }
   // g_portfolioManager.EnableDebug(g_debugPortfolio);
   
   // ============================================================
   // ★★★ CRITICAL: CONNECT TRENDMANAGER → PORTFOLIOMANAGER ★★★
   // ============================================================
   if(g_trendManager != NULL && g_portfolioManager != NULL)
   {
      g_portfolioManager.SetTrendManager(g_trendManager);
      LOG_DEBUG("✅ PortfolioManager → TrendManager connected", g_debugMain);
   }
   
   // ============================================================
   // ★★★ CRITICAL: CONNECT PORTFOLIOMANAGER → POSITIONMANAGER ★★★
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
   // ★★★ CONFIGURE LOSS MANAGEMENT ★★★
   // ============================================================
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.SetLossManagementEnabled(InpEnableLossManagement);
      g_portfolioManager.SetLossCloseConfidence(InpLossCloseConfidence);
      LOG_INFO("✅ PortfolioManager Loss Management configured:", g_debugMain);
      LOG_INFO("   Enabled: " + (InpEnableLossManagement ? "YES" : "NO"), g_debugMain);
      LOG_INFO("   Close Confidence: " + DoubleToString(InpLossCloseConfidence, 0) + "%", g_debugMain);
   }
   
   if(g_positionManager != NULL)
   {
      g_positionManager.SetLossManagementEnabled(InpEnableLossManagement);
      g_positionManager.SetLossCloseConfidence(InpLossCloseConfidence);
      LOG_INFO("✅ PositionManager Loss Management configured:", g_debugMain);
      LOG_INFO("   Enabled: " + (InpEnableLossManagement ? "YES" : "NO"), g_debugMain);
      LOG_INFO("   Close Confidence: " + DoubleToString(InpLossCloseConfidence, 0) + "%", g_debugMain);
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
   // g_componentManager.EnableDebug(g_debugComponent);
   
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
   // 7. CREATE SCENARIO NARRATIVE
   // ============================================================
   g_scenarioNarrative = new ScenarioNarrative();
   if(g_scenarioNarrative == NULL)
   {
      LOG_ERROR("❌ Failed to create ScenarioNarrative");
      return INIT_FAILED;
   }
   
   // ============================================================
   // 8. CREATE CHART MODULE
   // ============================================================
   if(InpShowChart)
   {
      g_chartModule = new CChartModule(_Symbol, InpEntryTF, InpRangeBars);
      if(g_chartModule != NULL)
      {
         g_chartModule.SetPullbackModule(g_pullback);
      }
   }
   
   // ============================================================
   // 9. CREATE DASHBOARD
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
   
   EventSetTimer(1);
   
   g_initStatus = INIT_STATUS_NOT_STARTED;
   g_initAttempts = 0;
   g_lastInitAttempt = 0;
   g_initializationFailed = false;
   
   LOG_INFO("✅ EA INITIALIZED - v3.43 (Removed MACD Opposition Checks)", g_debugMain);
   LOG_INFO("   TrendManager → PortfolioManager: ✓", g_debugMain);
   LOG_INFO("   PortfolioManager → PositionManager: ✓ (Boost TP 100 pts)", g_debugMain);
   LOG_INFO("   PullbackModule → TrendManager: ✓", g_debugMain);
   LOG_INFO("   Loss Management: " + (InpEnableLossManagement ? "ACTIVE" : "OFF"), g_debugMain);
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
   
   datetime currentBarTime = iTime(_Symbol, InpEntryTF, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;
   
   CheckSignal();
   UpdateChart();
   UpdateDashboard();
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
   
   if(g_initStatus == INIT_STATUS_PULLBACK)
   {
      if(g_pullback != NULL && g_trendManager != NULL)
      {
         SPullbackAnalysisResult testResult = g_pullback.GetPullbackAnalysis();
         if(testResult.rangeHigh > 0 && testResult.rangeLow > 0 && testResult.rangeHigh > testResult.rangeLow)
         {
            g_initStatus = INIT_STATUS_COMPLETE;
            LOG_INFO("✅ ALL MODULES INITIALIZED - READY", g_debugMain);
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
   
   // PositionManager manages positions including loss management
   if(g_positionManager != NULL)
      g_positionManager.ManagePositions();
   
   // PortfolioManager monitors positions (MACD loss management only - no entry checks)
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.Update();
      g_portfolioManager.MonitorPositions();
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
//| CheckSignal - NO MACD OPPOSITION CHECKS                         |
//| REJECT entry if Risk-Reward < 1.5:1                            |
//+------------------------------------------------------------------+
void CheckSignal()
{
   if(g_componentManager == NULL || g_trendManager == NULL) 
      return;
   
   STrendResult trendResult = g_trendManager.AnalyzeTrend();
   
   int tradeDirection = 0;
   if(trendResult.direction == "BULLISH")
      tradeDirection = 1;
   else if(trendResult.direction == "BEARISH")
      tradeDirection = -1;
   else
      tradeDirection = 0;
   
   g_componentManager.SetTradeDirection(tradeDirection);
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_componentManager.SetCurrentPrice(currentPrice);
   
   if(g_pullback != NULL && g_trendManager != NULL)
   {
      g_pullback.SetTrendManager(g_trendManager);
   }
   
   SPullbackAnalysisResult pbResult = g_pullback.GetPullbackAnalysis();
   int trend = g_pullback.GetTrendPublic();
   
   if(!pbResult.showOnChart || pbResult.rangeHigh == 0 || pbResult.rangeLow == 0)
      return;
   
   if(pbResult.rangeHigh <= pbResult.rangeLow)
      return;
   
   if(!g_trendManager.ShouldAllowEntries())
   {
      g_neutralCounter++;
      return;
   }
   
   if(trendResult.strength < InpMinTrendStrength)
   {
      g_lowStrengthCounter++;
      return;
   }
   
   if(InpRequireStrongTrend && !g_trendManager.IsStrongTrend())
   {
      g_notStrongCounter++;
      return;
   }
   
   if(!InpAllowNeutralTrend && trendResult.direction == "NEUTRAL")
   {
      g_neutralCounter++;
      return;
   }
   
   SMarketAnalysis analysis = g_componentManager.AnalyzeMarket();
   
   double baseConfidence = analysis.overallConfidence;
   double portfolioBoost = 0;
   
   // ============================================================
   // GET ENHANCED BOOST FROM PORTFOLIO MANAGER
   // ============================================================
   if(g_portfolioManager != NULL)
   {
      g_portfolioManager.Update();
      portfolioBoost = g_portfolioManager.GetPortfolioConfidenceBoost(baseConfidence);
      
      double adjustedConfidence = baseConfidence + portfolioBoost;
      adjustedConfidence = MathMax(0, MathMin(100, adjustedConfidence));
      analysis.overallConfidence = adjustedConfidence;
   }
   
   // ============================================================
   // ═══ MACD OPPOSITION CHECKS COMPLETELY REMOVED ═══
   // No rejection based on MACD opposing trend
   // ============================================================
   
   double finalConfidence = analysis.overallConfidence;
   double thresholdToUse = GetThresholdForDirection(analysis.overallSentiment);
   
   if(analysis.overallSentiment == "NEUTRAL" || finalConfidence < thresholdToUse)
      return;
   
   bool signalAlignsWithTrend = false;
   
   if(analysis.overallSentiment == "BULLISH" && 
      (trendResult.direction == "BULLISH" || 
       (trendResult.direction == "NEUTRAL" && InpAllowNeutralTrend)))
   {
      signalAlignsWithTrend = true;
   }
   else if(analysis.overallSentiment == "BEARISH" && 
           (trendResult.direction == "BEARISH" || 
            (trendResult.direction == "NEUTRAL" && InpAllowNeutralTrend)))
   {
      signalAlignsWithTrend = true;
   }
   
   if(!signalAlignsWithTrend)
      return;
   
   if(g_riskManager != NULL && !g_riskManager.CheckRiskLimits())
      return;
   
   double rangeHigh = pbResult.rangeHigh;
   double rangeLow = pbResult.rangeLow;
   double rangeSize = rangeHigh - rangeLow;
   double pullbackPercent = pbResult.pullbackPercent;
   string zoneCategory = pbResult.zoneCategory;
   
   if(rangeHigh == 0 || rangeLow == 0 || rangeHigh <= rangeLow)
      return;
   
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   PrescribedTrade trade;
   ZeroMemory(trade);
   
   if(analysis.overallSentiment == "BULLISH")
      trade.signal = 1;
   else if(analysis.overallSentiment == "BEARISH")
      trade.signal = -1;
   else
      trade.signal = 0;
   
   if(trade.signal == 0) return;
   
   trade.entryPrice = currentPrice;
   
   // ============================================================
   // STEP 1: SET STOP LOSS
   // ============================================================
   if(trade.signal == 1)
      trade.stopLoss = rangeLow;
   else
      trade.stopLoss = rangeHigh;
   
   double riskAmount = MathAbs(trade.stopLoss - trade.entryPrice);
   double riskPips = riskAmount / pointValue;
   
   if(riskAmount <= 0)
      return;
   
   // ============================================================
   // STEP 2: CALCULATE TAKE PROFIT WITH MINIMUM RR 1:1.5
   // ============================================================
   double primaryTP = 0, rr = 0;
   
   bool rrPassed = CalculateTakeProfits(trade.signal, currentPrice, rangeHigh, rangeLow, 
                                         pullbackPercent, riskAmount, primaryTP, rr,
                                         portfolioBoost);
   
   if(!rrPassed)
   {
      LOG_DEBUG("❌ Trade REJECTED: Insufficient Risk-Reward (RR: " + 
                DoubleToString(rr, 2) + ":1 < Minimum " + DoubleToString(InpMinRR, 1) + ":1)", 
                g_debugMain);
      return;
   }
   
   if(primaryTP <= 0)
   {
      LOG_DEBUG("❌ Trade REJECTED: Invalid Take Profit level", g_debugMain);
      return;
   }
   
   trade.takeProfit = primaryTP;
   trade.takeProfit2 = 0;
   
   double rewardAmount = MathAbs(trade.takeProfit - trade.entryPrice);
   double rewardPips = rewardAmount / pointValue;
   
   trade.riskRewardRatio = rewardAmount / riskAmount;
   trade.riskRewardRatio2 = 0;
   
   // ============================================================
   // STEP 3: LOG TRADE DETAILS
   // ============================================================
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   LOG_TRADE("✅✅✅ TRADE SIGNAL ACCEPTED ✅✅✅");
   LOG_TRADE("   Direction: " + (trade.signal == 1 ? "LONG (BUY)" : "SHORT (SELL)"));
   LOG_TRADE("   Entry: " + DoubleToString(trade.entryPrice, _Digits));
   LOG_TRADE("   Stop Loss: " + DoubleToString(trade.stopLoss, _Digits) + 
             " (" + DoubleToString(riskPips, 1) + " pips risk)");
   LOG_TRADE("   Take Profit: " + DoubleToString(trade.takeProfit, _Digits) + 
             " (" + DoubleToString(rewardPips, 1) + " pips reward)");
   LOG_TRADE("   Risk-Reward: " + DoubleToString(trade.riskRewardRatio, 2) + ":1" +
             " (Minimum: " + DoubleToString(InpMinRR, 1) + ":1)");
   LOG_TRADE("   Pullback Zone: " + zoneCategory + " (" + 
             DoubleToString(pullbackPercent, 1) + "%)");
   LOG_TRADE("   Boost: " + StringFormat("%+.1f%%", portfolioBoost));
   LOG_TRADE("   Confidence: " + DoubleToString(finalConfidence, 1) + "%");
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   
   if(trade.signal == 1)
      trade.partialLevel75 = currentPrice + (trade.takeProfit - currentPrice) * 0.75;
   else
      trade.partialLevel75 = currentPrice - (currentPrice - trade.takeProfit) * 0.75;
   
   trade.pullbackPercent = pbResult.pullbackPercent;
   trade.pullbackScore = (int)pbResult.pullbackScore;
   trade.entryReason = zoneCategory + " pullback - Boost " + StringFormat("%+.1f%%", portfolioBoost);
   
   // ============================================================
   // STEP 4: CALCULATE LOT SIZE
   // ============================================================
   double lotSize = InpLotSize;
   
   if(g_riskManager != NULL)
      lotSize = g_riskManager.CalculateLotSize(trade);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   if(stepLot > 0)
      lotSize = MathRound(lotSize / stepLot) * stepLot;
   
   LOG_DEBUG("   Lot Size: " + DoubleToString(lotSize, 2), g_debugMain);
   
   // ============================================================
   // STEP 5: EXECUTE TRADE
   // ============================================================
   if(InpEnableTrading && g_positionManager != NULL)
   {
      bool executed = g_positionManager.ExecuteTrade(trade, lotSize);
      if(executed)
      {
         LOG_TRADE("✅✅✅ TRADE EXECUTED SUCCESSFULLY ✅✅✅");
      }
      else
      {
         LOG_ERROR("❌❌❌ TRADE EXECUTION FAILED ❌❌❌");
      }
   }
   else
   {
      LOG_DEBUG("⚠️ Trading disabled - Signal detected but not executed", g_debugMain);
   }
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
   LOG_INFO("", g_debugMain);
   LOG_INFO("📋 " + synthesized.narrative, g_debugMain);
   LOG_INFO("=========================", g_debugMain);
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