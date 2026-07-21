//+------------------------------------------------------------------+
//|                     PortfolioManager.mqh                         |
//|                    Portfolio Risk & Confidence Manager           |
//|                    v3.6 - FIXED MACD LOSS MANAGEMENT            |
//|                    MACD Opposition + Confidence ≥ 20% Check     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.6"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "../PackageManagers/ComponentManager.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE - SINGLE MAIN SWITCH                       |
//+------------------------------------------------------------------+
bool g_debugPortfolioManager = false;  // Set to true to enable PortfolioManager debug logs

//+------------------------------------------------------------------+
//| Portfolio Manager Class - DIRECT TREND MANAGER                 |
//+------------------------------------------------------------------+
class CPortfolioManager
{
private:
   // Core members
   string            m_symbol;
   int               m_magicNumber;
   CTrade           *m_trade;
   
   // ──────────────────────────────────────────────────────────────
   // TREND MANAGER - DIRECT ACCESS
   // ──────────────────────────────────────────────────────────────
   CTrendManager    *m_trendManager;        // Direct trend source
   string            m_trendDirection;       // Cached trend
   datetime          m_trendTimestamp;       // Trend cache time
   int               m_trendCacheTimeout;    // Trend cache timeout (seconds)
   
   // Portfolio state
   double            m_portfolioConfidenceBoost;
   double            m_portfolioConfidencePenalty;
   bool              m_emergencyExitTriggered;
   datetime          m_lastEmergencyExit;
   
   // ════════════════════════════════════════════════════════════
   // Boost state caching for Position Manager
   // ════════════════════════════════════════════════════════════
   bool              m_boostActive;          // Cached boost active state
   double            m_boostPercentage;      // Cached boost percentage
   datetime          m_boostCacheTime;       // When boost was last cached
   int               m_boostCacheTimeout;    // How long to cache boost (seconds)
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT MANAGER - For component data ONLY (NOT trend)
   // ──────────────────────────────────────────────────────────────
   CComponentManager  *m_componentManager;
   SMarketAnalysis    m_cachedAnalysis;
   datetime           m_lastAnalysisTime;
   int                m_analysisCacheTimeout;  // seconds
   
   // ════════════════════════════════════════════════════════════
   // LOSS MANAGEMENT INPUTS (from main file)
   // ════════════════════════════════════════════════════════════
   bool              m_lossManagementEnabled;
   double            m_lossCloseConfidence;   // Default 20.0%
   double            m_lossMACDThreshold;     // MACD value threshold
   
   // ============================================================
   // POSITION MONITORING STRUCTURE - ENHANCED
   // ============================================================
   struct PositionMonitor
   {
      ulong  ticket;
      double entryPrice;
      double stopLoss;
      double riskPips;
      double halfRiskPips;
      bool   halfLossReached;
      bool   warningLogged;
      
      double macdAtEntry;
      double macdAtHalfLoss;
      double macdConfidenceAtEntry;
      double macdConfidenceAtHalfLoss;
      bool   positionClosed;
      bool   isBuy;
      
      // ═══ NEW: Track MACD opposition state ═══
      bool   macdOpposesTrend;      // True if MACD opposes the trend
      double macdOppositionConfidence; // Confidence of opposition
      bool   lossCloseExecuted;     // Prevent duplicate closes
   };
   PositionMonitor m_monitors[];
   
   // ============================================================
   // PRIVATE METHODS
   // ============================================================
   bool              InitializeComponentManager();
   void              DeinitializeComponentManager();
   SMarketAnalysis   GetMarketAnalysis();  // Returns by value (no reference)
   
   // ──────────────────────────────────────────────────────────────
   // TREND METHODS - DIRECT
   // ──────────────────────────────────────────────────────────────
   string            GetTrendDirect();       // Gets trend DIRECTLY from TrendManager
   void              UpdateTrendCache();     // Updates cached trend
   bool              IsTrendCacheValid();    // Checks if cached trend is valid
   
   // Position Monitoring - ENHANCED
   int               FindMonitor(ulong ticket);
   void              AddMonitor(ulong ticket, double entryPrice, double stopLoss, bool isBuy);
   void              RemoveMonitor(ulong ticket);
   bool              ShouldClosePosition(ulong ticket, PositionMonitor &monitor);
   void              ClosePositionForLoss(ulong ticket);
   void              ExecuteEmergencyExit();
   int               CountOpenPositions();
   
   // ═══ NEW: MACD Opposition Check Methods ═══
   bool              CheckMACDOpposition(const SMarketAnalysis &analysis, bool isBuy, double &confidence);
   bool              CheckMACDSupportsTrend(const SMarketAnalysis &analysis, bool isBuy);
   
   // ============================================================
   // BOOST CALCULATION METHODS - ALL data from ComponentManager
   // ============================================================
   double            CalculateRSIBoost(const SMarketAnalysis &analysis);
   double            CalculateVolumeBoost(const SMarketAnalysis &analysis);
   double            CalculateADXBoost(const SMarketAnalysis &analysis);
   double            CalculateMACDBoost(const SMarketAnalysis &analysis);
   
   // Logging - CRITICAL EVENTS ONLY
   void              LogLossManagement(const PositionMonitor &monitor, const SMarketAnalysis &analysis,
                                       double lossPips, double macdConfidence, bool macdOpposes);
   
   // ════════════════════════════════════════════════════════════
   // Internal boost cache update
   // ════════════════════════════════════════════════════════════
   void              UpdateBoostCache();
   
public:
   CPortfolioManager(string symbol, int magicNumber, CTrade &trade);
   ~CPortfolioManager();
   
   // ──────────────────────────────────────────────────────────────
   // TREND MANAGER SETTER
   // ──────────────────────────────────────────────────────────────
   void              SetTrendManager(CTrendManager* trendManager) { m_trendManager = trendManager; }
   string            GetTrendDirection() const { return m_trendDirection; }
   void              SetTrendCacheTimeout(int seconds) { m_trendCacheTimeout = seconds; }
   
   // ═══ NEW: Loss Management Configuration ═══
   void              SetLossManagementEnabled(bool enable) { m_lossManagementEnabled = enable; }
   void              SetLossCloseConfidence(double confidence) { m_lossCloseConfidence = confidence; }
   bool              IsLossManagementEnabled() const { return m_lossManagementEnabled; }
   double            GetLossCloseConfidence() const { return m_lossCloseConfidence; }
   
   // Main methods
   bool              Initialize();
   void              Update();
   double            GetPortfolioConfidenceBoost(double baseConfidence);
   double            ApplyPortfolioAdjustment(double baseConfidence);
   void              CloseAllPositions();
   
   // Position Monitoring
   void              MonitorPositions();
   void              OnTradeOpened(ulong ticket, double entryPrice, double stopLoss);
   void              OnTradeClosed(ulong ticket);
   
   // Debug control
   static void       SetGlobalDebug(bool enable) { g_debugPortfolioManager = enable; }
   static bool       GetGlobalDebug() { return g_debugPortfolioManager; }
   
   // ════════════════════════════════════════════════════════════
   // Boost status getters for Position Manager
   // ════════════════════════════════════════════════════════════
   bool              GetBoostStatus();        // Returns true if boost is active
   double            GetBoostPercentage();    // Returns current boost percentage (0-20)
   void              SetBoostCacheTimeout(int seconds) { m_boostCacheTimeout = seconds; }
   
   // Getters - All from ComponentManager
   double            GetPortfolioConfidenceBoost() const { return m_portfolioConfidenceBoost; }
   double            GetPortfolioConfidencePenalty() const { return m_portfolioConfidencePenalty; }
   double            GetMACDHistogram() const { return m_cachedAnalysis.macdData.histogramValue; }
   double            GetADXValue() const { return m_cachedAnalysis.adxData.adxValue; }
   double            GetVolumeRatio() const { return m_cachedAnalysis.volumeData.volumeRatio; }
   double            GetRSIConfidence() const { return m_cachedAnalysis.rsiData.confidence; }
   double            getMACDConfidence() const { return m_cachedAnalysis.macdData.confidence; }
   double            getVolumeConfidence() const { return m_cachedAnalysis.volumeData.confidence; }
   string            GetRSIDirection() const { return m_cachedAnalysis.rsiData.direction; }
   string            getMACDDirection() const { return m_cachedAnalysis.macdData.direction; }
   string            GetVolumeDirection() const { return m_cachedAnalysis.volumeData.direction; }
   string            GetTrendDirectionFromCM() const { return m_cachedAnalysis.overallSentiment; }
   
   // Component Manager access
   CComponentManager* GetComponentManager() { return m_componentManager; }
   
   // Portfolio status
   string            GetPortfolioStatus();
   string            GetComponentReport();
   string            GetMonitorReport();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CPortfolioManager::CPortfolioManager(string symbol, int magicNumber, CTrade &trade)
{
   // Only log constructor once
   LOG_DEBUG("CPortfolioManager constructor called for " + symbol, g_debugPortfolioManager);
   
   m_symbol = symbol;
   m_magicNumber = magicNumber;
   m_trade = &trade;
   m_analysisCacheTimeout = 5;
   m_trendCacheTimeout = 5;
   m_boostCacheTimeout = 2;
   
   m_lossManagementEnabled = true;
   m_lossCloseConfidence = 20.0;     // ← THRESHOLD SET TO 20%
   m_lossMACDThreshold = 0.0;
   
   m_portfolioConfidenceBoost = 0;
   m_portfolioConfidencePenalty = 0;
   m_emergencyExitTriggered = false;
   m_lastEmergencyExit = 0;
   m_lastAnalysisTime = 0;
   
   m_trendManager = NULL;
   m_trendDirection = "NEUTRAL";
   m_trendTimestamp = 0;
   
   m_boostActive = false;
   m_boostPercentage = 0;
   m_boostCacheTime = 0;
   
   m_componentManager = NULL;
   ZeroMemory(m_cachedAnalysis);
   
   ArrayResize(m_monitors, 0);
   
   // Always show these
   LOG_INFO("PortfolioManager v3.6 (Fixed MACD Loss Management) initialized for " + m_symbol, true);
   LOG_INFO("Loss Management: " + (m_lossManagementEnabled ? "ENABLED" : "DISABLED"), true);
   LOG_INFO("Close Confidence Threshold: " + DoubleToString(m_lossCloseConfidence, 0) + "%", true);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CPortfolioManager::~CPortfolioManager()
{
   LOG_DEBUG("CPortfolioManager destructor called for " + m_symbol, g_debugPortfolioManager);
   DeinitializeComponentManager();
}

//+------------------------------------------------------------------+
//| Initialize Component Manager                                     |
//+------------------------------------------------------------------+
bool CPortfolioManager::InitializeComponentManager()
{
   if(m_componentManager != NULL) return true;
   
   LOG_INFO("=== INITIALIZING COMPONENT MANAGER ===", true);
   
   m_componentManager = new CComponentManager(m_symbol, InpEntryTF);
   
   if(!m_componentManager.Initialize())
   {
      LOG_ERROR("Failed to initialize Component Manager");
      delete m_componentManager;
      m_componentManager = NULL;
      return false;
   }
   
   if(m_trendManager != NULL && m_componentManager != NULL)
      m_componentManager.SetTrendManager(m_trendManager);
   
   LOG_INFO("Component Manager initialized successfully", true);
   LOG_INFO("=== END INITIALIZATION ===", true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Component Manager                                   |
//+------------------------------------------------------------------+
void CPortfolioManager::DeinitializeComponentManager()
{
   if(m_componentManager != NULL)
   {
      LOG_DEBUG("Deinitializing Component Manager", g_debugPortfolioManager);
      delete m_componentManager;
      m_componentManager = NULL;
   }
}

//+------------------------------------------------------------------+
//| Get Market Analysis - SILENT - Called frequently               |
//+------------------------------------------------------------------+
SMarketAnalysis CPortfolioManager::GetMarketAnalysis()
{
   datetime now = TimeCurrent();
   if((now - m_lastAnalysisTime) < m_analysisCacheTimeout && m_lastAnalysisTime > 0)
   {
      return m_cachedAnalysis;  // NO LOGGING - called every second
   }
   
   if(m_componentManager == NULL)
   {
      if(!InitializeComponentManager())
      {
         LOG_ERROR("Failed to get analysis - Component Manager not initialized");
         return m_cachedAnalysis;
      }
   }
   
   if(m_componentManager != NULL)
   {
      m_cachedAnalysis = m_componentManager.AnalyzeMarket();
   }
   
   m_lastAnalysisTime = now;
   return m_cachedAnalysis;
}

//+------------------------------------------------------------------+
//| Initialize - Public entry point                                 |
//+------------------------------------------------------------------+
bool CPortfolioManager::Initialize()
{
   LOG_DEBUG("CPortfolioManager::Initialize called", g_debugPortfolioManager);
   bool result = InitializeComponentManager();
   LOG_DEBUG("CPortfolioManager::Initialize result: " + (result ? "SUCCESS" : "FAILED"), g_debugPortfolioManager);
   return result;
}

//+------------------------------------------------------------------+
//| Update - SILENT - Called frequently                            |
//+------------------------------------------------------------------+
void CPortfolioManager::Update()
{
   // NO LOGGING - called every tick
   GetMarketAnalysis();
   UpdateBoostCache();
}

// ============================================================
// TREND METHODS - DIRECT FROM TRENDMANAGER
// ============================================================

//+------------------------------------------------------------------+
//| Check if Trend Cache is Valid                                   |
//+------------------------------------------------------------------+
bool CPortfolioManager::IsTrendCacheValid()
{
   if(m_trendTimestamp == 0) return false;
   if(m_trendDirection == "NEUTRAL") return false;
   if((TimeCurrent() - m_trendTimestamp) > m_trendCacheTimeout) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Get Trend Directly - SILENT - Called frequently               |
//+------------------------------------------------------------------+
string CPortfolioManager::GetTrendDirect()
{
   // NO LOGGING - called every check
   if(IsTrendCacheValid())
   {
      return m_trendDirection;
   }
   
   if(m_trendManager != NULL)
   {
      string trend = m_trendManager.GetDirection();
      m_trendDirection = trend;
      m_trendTimestamp = TimeCurrent();
      return trend;
   }
   
   if(m_componentManager != NULL)
   {
      SMarketAnalysis analysis = m_componentManager.AnalyzeMarket();
      if(analysis.overallSentiment != "NEUTRAL")
      {
         m_trendDirection = analysis.overallSentiment;
         m_trendTimestamp = TimeCurrent();
         return m_trendDirection;
      }
   }
   
   m_trendDirection = "NEUTRAL";
   m_trendTimestamp = TimeCurrent();
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Update Trend Cache - SILENT                                    |
//+------------------------------------------------------------------+
void CPortfolioManager::UpdateTrendCache()
{
   // NO LOGGING
   if(m_trendManager != NULL)
   {
      m_trendDirection = m_trendManager.GetDirection();
      m_trendTimestamp = TimeCurrent();
   }
}

// ============================================================
// ════════════════════════════════════════════════════════════
// BOOST CACHE METHODS - SILENT
// ════════════════════════════════════════════════════════════
// ============================================================

//+------------------------------------------------------------------+
//| Update Boost Cache - SILENT - Called frequently                |
//+------------------------------------------------------------------+
void CPortfolioManager::UpdateBoostCache()
{
   datetime now = TimeCurrent();
   if((now - m_boostCacheTime) < m_boostCacheTimeout && m_boostCacheTime > 0)
   {
      return;  // NO LOGGING
   }
   
   double baseConfidence = 50.0;
   double boost = GetPortfolioConfidenceBoost(baseConfidence);
   
   m_boostPercentage = boost;
   m_boostActive = (boost > 0);
   m_boostCacheTime = now;
}

//+------------------------------------------------------------------+
//| Get Boost Status - SILENT                                      |
//+------------------------------------------------------------------+
bool CPortfolioManager::GetBoostStatus()
{
   UpdateBoostCache();
   return m_boostActive;
}

//+------------------------------------------------------------------+
//| Get Boost Percentage - SILENT                                  |
//+------------------------------------------------------------------+
double CPortfolioManager::GetBoostPercentage()
{
   UpdateBoostCache();
   return m_boostPercentage;
}

// ============================================================
// ════════════════════════════════════════════════════════════
// MACD OPPOSITION CHECK - CRITICAL LOGGING
// ════════════════════════════════════════════════════════════
// ============================================================

//+------------------------------------------------------------------+
//| Check MACD Opposition - LOG WHEN OPPOSITION DETECTED           |
//| Uses CONFIDENCE from ComponentManager, not histogram directly  |
//+------------------------------------------------------------------+
bool CPortfolioManager::CheckMACDOpposition(const SMarketAnalysis &analysis, bool isBuy, double &confidence)
{
   // Get MACD data from ComponentManager
   double macdHistogram = analysis.macdData.histogramValue;
   string macdDirection = analysis.macdData.direction;
   double macdConfidence = analysis.macdData.confidence;  // ← CONFIDENCE FROM COMPONENT MANAGER
   string trendDir = analysis.overallSentiment;
   
   confidence = 0;
   
   if(trendDir == "NEUTRAL")
      return false;
   
   bool macdOpposesTrend = false;
   
   if(trendDir == "BULLISH")
   {
      // For BUY positions: MACD is bearish if histogram < 0 OR direction is BEARISH
      if(macdHistogram < 0 || macdDirection == "BEARISH")
      {
         macdOpposesTrend = true;
         confidence = macdConfidence;  // ← USE CONFIDENCE FROM COMPONENT MANAGER
         LOG_DEBUG("MACD opposes BULLISH trend: histogram=" + DoubleToString(macdHistogram, 5) + ", direction=" + macdDirection + ", confidence=" + DoubleToString(confidence, 1) + "%", g_debugPortfolioManager);
      }
   }
   else if(trendDir == "BEARISH")
   {
      // For SELL positions: MACD is bullish if histogram > 0 OR direction is BULLISH
      if(macdHistogram > 0 || macdDirection == "BULLISH")
      {
         macdOpposesTrend = true;
         confidence = macdConfidence;  // ← USE CONFIDENCE FROM COMPONENT MANAGER
         LOG_DEBUG("MACD opposes BEARISH trend: histogram=" + DoubleToString(macdHistogram, 5) + ", direction=" + macdDirection + ", confidence=" + DoubleToString(confidence, 1) + "%", g_debugPortfolioManager);
      }
   }
   
   // DECISION: Use CONFIDENCE, NOT histogram
   if(macdOpposesTrend && confidence >= m_lossCloseConfidence)
   {
      LOG_DEBUG("MACD opposition confirmed with confidence " + DoubleToString(confidence, 1) + "% >= " + DoubleToString(m_lossCloseConfidence, 0) + "%", g_debugPortfolioManager);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check MACD Supports Trend - SILENT                             |
//+------------------------------------------------------------------+
bool CPortfolioManager::CheckMACDSupportsTrend(const SMarketAnalysis &analysis, bool isBuy)
{
   string trendDir = analysis.overallSentiment;
   string macdDirection = analysis.macdData.direction;
   double macdHistogram = analysis.macdData.histogramValue;
   
   if(trendDir == "NEUTRAL")
      return true;
   
   if(trendDir == "BULLISH")
   {
      return (macdDirection == "BULLISH" || macdHistogram > 0);
   }
   else
   {
      return (macdDirection == "BEARISH" || macdHistogram < 0);
   }
}

// ============================================================
// BOOST CALCULATION METHODS - SILENT (only used for boost)
// ============================================================

double CPortfolioManager::CalculateRSIBoost(const SMarketAnalysis &analysis)
{
   // NO LOGGING - boost calculation
   double rsiValue = analysis.rsiData.rsiValue;
   double rsiConfidence = analysis.rsiData.confidence;
   string rsiDirection = analysis.rsiData.direction;
   string trendDir = analysis.overallSentiment;
   
   bool isHealthy = (rsiValue >= 30 && rsiValue <= 70);
   if(!isHealthy) return 0;
   
   bool aligned = (trendDir == "BULLISH" && rsiDirection == "BULLISH") ||
                  (trendDir == "BEARISH" && rsiDirection == "BEARISH");
   if(!aligned) return 0;
   
   double boost = 2.0;
   if(rsiConfidence >= 5.0) boost += 3.0;
   if(rsiConfidence >= 10.0) boost += 5.0;
   
   return boost;
}

double CPortfolioManager::CalculateVolumeBoost(const SMarketAnalysis &analysis)
{
   // NO LOGGING - boost calculation
   double volConfidence = analysis.volumeData.confidence;
   string volumeDirection = analysis.volumeData.direction;
   string trendDir = analysis.overallSentiment;
   
   if(volConfidence < 5.0) return 0;
   
   bool aligned = (trendDir == "BULLISH" && volumeDirection == "BULLISH") ||
                  (trendDir == "BEARISH" && volumeDirection == "BEARISH");
   if(!aligned) return 0;
   
   return 2.0;
}

double CPortfolioManager::CalculateADXBoost(const SMarketAnalysis &analysis)
{
   // NO LOGGING - boost calculation
   double adxValue = analysis.adxData.adxValue;
   double bullPct = analysis.adxData.bullPercentage;
   string trendDir = analysis.overallSentiment;
   
   if(adxValue <= 0 || bullPct <= 0) return 0;
   
   string adxDirection = (bullPct >= 50) ? "BULLISH" : "BEARISH";
   double adxConfidence = (bullPct >= 50) ? bullPct : (100 - bullPct);
   
   if(adxConfidence < 30.0) return 0;
   
   bool aligned = (trendDir == "BULLISH" && adxDirection == "BULLISH") ||
                  (trendDir == "BEARISH" && adxDirection == "BEARISH");
   if(!aligned) return 0;
   
   return 3.0;
}

double CPortfolioManager::CalculateMACDBoost(const SMarketAnalysis &analysis)
{
   // NO LOGGING - boost calculation
   double histogram = analysis.macdData.histogramValue;
   double confidence = analysis.macdData.confidence;
   string macdDirection = analysis.macdData.direction;
   string trendDir = analysis.overallSentiment;
   
   bool supportsTrend = (trendDir == "BULLISH" && macdDirection == "BULLISH") ||
                        (trendDir == "BEARISH" && macdDirection == "BEARISH");
   if(!supportsTrend) return 0;
   
   double boost = 2.0;
   if(confidence > 10.0) boost += 3.0;
   
   return boost;
}

//+------------------------------------------------------------------+
//| Get Portfolio Confidence Boost - SILENT                         |
//+------------------------------------------------------------------+
double CPortfolioManager::GetPortfolioConfidenceBoost(double baseConfidence)
{
   // NO LOGGING - called frequently
   string trendDir = GetTrendDirect();
   
   if(trendDir == "NEUTRAL")
   {
      m_portfolioConfidenceBoost = 0;
      m_portfolioConfidencePenalty = 0;
      return 0;
   }
   
   SMarketAnalysis analysis = GetMarketAnalysis();
   analysis.overallSentiment = trendDir;
   
   double rsiBoost = CalculateRSIBoost(analysis);
   double volBoost = CalculateVolumeBoost(analysis);
   double adxBoost = CalculateADXBoost(analysis);
   double macdBoost = CalculateMACDBoost(analysis);
   
   double totalBoost = rsiBoost + volBoost + adxBoost + macdBoost;
   totalBoost = MathMax(0, MathMin(20.0, totalBoost));
   
   m_portfolioConfidenceBoost = totalBoost;
   m_portfolioConfidencePenalty = 0;
   
   return totalBoost;
}

//+------------------------------------------------------------------+
//| Apply Portfolio Adjustment - SILENT                             |
//+------------------------------------------------------------------+
double CPortfolioManager::ApplyPortfolioAdjustment(double baseConfidence)
{
   // NO LOGGING
   double boost = GetPortfolioConfidenceBoost(baseConfidence);
   double adjustedConfidence = baseConfidence + boost;
   adjustedConfidence = MathMax(0, MathMin(100, adjustedConfidence));
   return adjustedConfidence;
}

//+------------------------------------------------------------------+
//| Execute Emergency Exit                                          |
//+------------------------------------------------------------------+
void CPortfolioManager::ExecuteEmergencyExit()
{
   int closedCount = 0;
   
   LOG_WARNING("🚨 Emergency exit triggered");
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         int magic = (int)PositionGetInteger(POSITION_MAGIC);
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         if(magic == m_magicNumber && symbol == m_symbol)
         {
            if(m_trade.PositionClose(ticket))
            {
               closedCount++;
               LOG_DEBUG("Closed position #" + IntegerToString(ticket), g_debugPortfolioManager);
               RemoveMonitor(ticket);
            }
            else
            {
               LOG_ERROR("Failed to close position #" + IntegerToString(ticket));
            }
         }
      }
   }
   
   if(closedCount > 0)
      LOG_INFO("Emergency exit complete: " + IntegerToString(closedCount) + " positions closed", true);
   else
      LOG_DEBUG("No positions to close during emergency exit", g_debugPortfolioManager);
}

//+------------------------------------------------------------------+
//| POSITION MONITORING - CRITICAL LOGGING                          |
//+------------------------------------------------------------------+

int CPortfolioManager::FindMonitor(ulong ticket)
{
   for(int i = 0; i < ArraySize(m_monitors); i++)
   {
      if(m_monitors[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Add Monitor - LOG ALWAYS (trade lifecycle event)               |
//+------------------------------------------------------------------+
void CPortfolioManager::AddMonitor(ulong ticket, double entryPrice, double stopLoss, bool isBuy)
{
   // LOG ALWAYS - important trade event
   if(FindMonitor(ticket) != -1)
   {
      LOG_DEBUG("Position #" + IntegerToString(ticket) + " already in monitor list", g_debugPortfolioManager);
      return;
   }
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double riskPips = MathAbs(entryPrice - stopLoss) / point;
   
   SMarketAnalysis analysis = GetMarketAnalysis();
   
   int idx = ArraySize(m_monitors);
   ArrayResize(m_monitors, idx + 1);
   
   m_monitors[idx].ticket = ticket;
   m_monitors[idx].entryPrice = entryPrice;
   m_monitors[idx].stopLoss = stopLoss;
   m_monitors[idx].riskPips = riskPips;
   m_monitors[idx].halfRiskPips = riskPips * 0.50;
   m_monitors[idx].halfLossReached = false;
   m_monitors[idx].warningLogged = false;
   m_monitors[idx].macdAtEntry = analysis.macdData.histogramValue;
   m_monitors[idx].macdAtHalfLoss = 0;
   m_monitors[idx].macdConfidenceAtEntry = analysis.macdData.confidence;
   m_monitors[idx].macdConfidenceAtHalfLoss = 0;
   m_monitors[idx].positionClosed = false;
   m_monitors[idx].isBuy = isBuy;
   
   m_monitors[idx].macdOpposesTrend = false;
   m_monitors[idx].macdOppositionConfidence = 0;
   m_monitors[idx].lossCloseExecuted = false;
   
   string logMsg = StringFormat("📊 Position #%I64u %s | Entry: %.5f | Risk: %.1f pips | 50%% Threshold: %.1f pips | MACD Entry: %.5f (Conf: %.1f%%)",
                      ticket, isBuy ? "BUY" : "SELL", entryPrice, riskPips, 
                      m_monitors[idx].halfRiskPips, analysis.macdData.histogramValue,
                      analysis.macdData.confidence);
   LOG_INFO(logMsg, true);  // Always show
}

void CPortfolioManager::RemoveMonitor(ulong ticket)
{
   LOG_DEBUG("RemoveMonitor called for ticket #" + IntegerToString(ticket), g_debugPortfolioManager);
   int idx = FindMonitor(ticket);
   if(idx == -1) return;
   
   for(int i = idx; i < ArraySize(m_monitors) - 1; i++)
      m_monitors[i] = m_monitors[i + 1];
   
   ArrayResize(m_monitors, ArraySize(m_monitors) - 1);
}

//+------------------------------------------------------------------+
//| OnTradeOpened - LOG ALWAYS (trade lifecycle event)             |
//+------------------------------------------------------------------+
void CPortfolioManager::OnTradeOpened(ulong ticket, double entryPrice, double stopLoss)
{
   LOG_DEBUG("OnTradeOpened called for ticket #" + IntegerToString(ticket), g_debugPortfolioManager);
   bool isBuy = false;
   if(PositionSelectByTicket(ticket))
   {
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      isBuy = (type == POSITION_TYPE_BUY);
   }
   AddMonitor(ticket, entryPrice, stopLoss, isBuy);
   LOG_INFO("Trade opened - added to monitor: #" + IntegerToString(ticket), true);
}

void CPortfolioManager::OnTradeClosed(ulong ticket)
{
   LOG_DEBUG("OnTradeClosed called for ticket #" + IntegerToString(ticket), g_debugPortfolioManager);
   RemoveMonitor(ticket);
   LOG_INFO("Trade closed - removed from monitor: #" + IntegerToString(ticket), true);
}

//+------------------------------------------------------------------+
//| Should Close Position - CRITICAL - LOGS DECISIONS              |
//+------------------------------------------------------------------+
bool CPortfolioManager::ShouldClosePosition(ulong ticket, PositionMonitor &monitor)
{
   // Skip if already closed
   if(monitor.positionClosed || monitor.lossCloseExecuted)
      return false;
   
   if(!m_lossManagementEnabled)
      return false;
   
   if(!PositionSelectByTicket(ticket))
      return false;
   
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   double lossPips = monitor.isBuy ? (monitor.entryPrice - currentPrice) / point 
                                    : (currentPrice - monitor.entryPrice) / point;
   double lossPercent = monitor.riskPips > 0 ? (lossPips / monitor.riskPips) * 100 : 0;
   
   // ============================================================
   // LOG ONLY when 50% loss is reached or when close decision
   // ============================================================
   if(lossPips < monitor.halfRiskPips)
   {
      if(monitor.halfLossReached)
      {
         monitor.halfLossReached = false;
         monitor.macdOpposesTrend = false;
         monitor.macdOppositionConfidence = 0;
         LOG_DEBUG("Position #" + IntegerToString(ticket) + ": 📈 Loss reduced below 50% threshold", g_debugPortfolioManager);
      }
      return false;
   }
   
   // Get fresh analysis
   SMarketAnalysis analysis = GetMarketAnalysis();
   analysis.overallSentiment = GetTrendDirect();
   
   double oppositionConfidence = 0;
   bool macdOpposes = CheckMACDOpposition(analysis, monitor.isBuy, oppositionConfidence);
   
   monitor.macdOpposesTrend = macdOpposes;
   monitor.macdOppositionConfidence = oppositionConfidence;
   
   // ============================================================
   // LOG AT 50% LOSS REACHED - IMPORTANT
   // ============================================================
   if(!monitor.halfLossReached)
   {
      monitor.halfLossReached = true;
      monitor.macdAtHalfLoss = analysis.macdData.histogramValue;
      monitor.macdConfidenceAtHalfLoss = analysis.macdData.confidence;
      
      LOG_WARNING(StringFormat("🔴🔴🔴 [50%% LOSS REACHED] Position #%I64u | Loss: %.1f pips (%.0f%% of risk) | MACD Confidence: %.1f%% | Opposes: %s",
                  ticket, lossPips, lossPercent, oppositionConfidence, macdOpposes ? "YES" : "NO"));
   }
   
   // ============================================================
   // DECISION: Uses CONFIDENCE from CheckMACDOpposition()
   // Threshold is 20% (m_lossCloseConfidence = 20.0)
   // ============================================================
   if(macdOpposes && oppositionConfidence >= m_lossCloseConfidence)
   {
      monitor.lossCloseExecuted = true;
      monitor.positionClosed = true;
      
      LogLossManagement(monitor, analysis, lossPips, oppositionConfidence, macdOpposes);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Log Loss Management - ALWAYS SHOW - Critical Event            |
//+------------------------------------------------------------------+
void CPortfolioManager::LogLossManagement(const PositionMonitor &monitor, const SMarketAnalysis &analysis,
                                           double lossPips, double macdConfidence, bool macdOpposes)
{
   string logMsg = StringFormat(
      "\n🔴🔴🔴 LOSS MANAGEMENT TRIGGERED! 🔴🔴🔴\n"
      "   Position #%I64u | %s\n"
      "   Loss: %.1f pips (%.0f%% of risk)\n"
      "   Entry: %.5f | Current: %.5f | SL: %.5f\n"
      "   MACD at Entry: %.5f | Current MACD: %.5f\n"
      "   MACD Confidence: %.1f%% | Opposes Trend: %s\n"
      "   Trend: %s | MACD Direction: %s\n"
      "   Threshold: %.0f%% | Close Confidence: %.1f%%\n"
      "   ═══ CLOSING POSITION ═══",
      monitor.ticket,
      monitor.isBuy ? "BUY" : "SELL",
      lossPips,
      (lossPips / monitor.riskPips) * 100,
      monitor.entryPrice,
      PositionGetDouble(POSITION_PRICE_CURRENT),
      monitor.stopLoss,
      monitor.macdAtEntry,
      analysis.macdData.histogramValue,
      macdConfidence,
      macdOpposes ? "YES ✅" : "NO ❌",
      analysis.overallSentiment,
      analysis.macdData.direction,
      m_lossCloseConfidence,
      macdConfidence
   );
   
   LOG_WARNING(logMsg);  // Always show
}

void CPortfolioManager::ClosePositionForLoss(ulong ticket)
{
   LOG_DEBUG("ClosePositionForLoss called for ticket #" + IntegerToString(ticket), g_debugPortfolioManager);
   if(m_trade.PositionClose(ticket))
   {
      LOG_INFO("Closed position #" + IntegerToString(ticket) + " (MACD Opposition at 50% Loss)", true);
      RemoveMonitor(ticket);
   }
   else
   {
      LOG_ERROR("Failed to close position #" + IntegerToString(ticket));
   }
}

//+------------------------------------------------------------------+
//| MonitorPositions - LOG ONLY when positions exist                |
//+------------------------------------------------------------------+
void CPortfolioManager::MonitorPositions()
{
   int monitorCount = ArraySize(m_monitors);
   
   // Log only if there are positions being monitored
   if(monitorCount > 0 && g_debugPortfolioManager)
   {
      LOG_DEBUG("MonitorPositions called - monitoring " + IntegerToString(monitorCount) + " positions", g_debugPortfolioManager);
   }
   
   GetMarketAnalysis();
   
   for(int i = monitorCount - 1; i >= 0; i--)
   {
      ulong ticket = m_monitors[i].ticket;
      
      if(!PositionSelectByTicket(ticket))
      {
         LOG_DEBUG("Position #" + IntegerToString(ticket) + " no longer exists, removing from monitor", g_debugPortfolioManager);
         RemoveMonitor(ticket);
         continue;
      }
      
      int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic != m_magicNumber)
      {
         LOG_DEBUG("Position #" + IntegerToString(ticket) + " has different magic number, removing from monitor", g_debugPortfolioManager);
         RemoveMonitor(ticket);
         continue;
      }
      
      if(ShouldClosePosition(ticket, m_monitors[i]))
      {
         ClosePositionForLoss(ticket);
      }
   }
}

void CPortfolioManager::CloseAllPositions()
{
   LOG_WARNING("CloseAllPositions called - closing all positions");
   ExecuteEmergencyExit();
}

int CPortfolioManager::CountOpenPositions()
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         int magic = (int)PositionGetInteger(POSITION_MAGIC);
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         if(magic == m_magicNumber && symbol == m_symbol)
         {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Portfolio Status                                             |
//+------------------------------------------------------------------+
string CPortfolioManager::GetPortfolioStatus()
{
   SMarketAnalysis analysis = GetMarketAnalysis();
   string status = "";
   
   if(analysis.overallSentiment == "BULLISH" && analysis.componentResult.agreeingComponents >= 4)
   {
      status = "✅ Portfolio Healthy - Strong bullish alignment";
   }
   else if(analysis.overallSentiment == "BEARISH" && analysis.componentResult.agreeingComponents >= 4)
   {
      status = "✅ Portfolio Healthy - Strong bearish alignment";
   }
   else if(analysis.overallSentiment != "NEUTRAL" && analysis.activeComponents >= 3)
   {
      status = "⚠️ " + analysis.overallSentiment + " trend with " + 
               IntegerToString(analysis.activeComponents) + "/6 components active";
   }
   else
   {
      status = "❌ Mixed signals - Monitoring positions for divergence";
   }
   
   return status;
}

//+------------------------------------------------------------------+
//| Get Component Report                                             |
//+------------------------------------------------------------------+
string CPortfolioManager::GetComponentReport()
{
   SMarketAnalysis analysis = GetMarketAnalysis();
   
   string boostStatus = m_boostActive ? "✅ ACTIVE" : "❌ INACTIVE";
   string lossMgmtStatus = m_lossManagementEnabled ? "✅ ENABLED" : "❌ DISABLED";
   
   string report = StringFormat(
      "📊 PORTFOLIO REPORT (v3.6 - Fixed MACD Loss Management):\n"
      "   Trend: %s | Action: %s\n"
      "   PB Score: %.1f%% | PB Conf: %.1f%%\n"
      "   MTF: %.1f%% | MACD: %.1f%% | RSI: %.1f%% | ADX: %.1f%% | VOL: %.1f%%\n"
      "   Agree: %d | Disagree: %d | Neutral: %d\n"
      "   Active: %d/6 | Best: %s (%.1f%%)\n"
      "   Portfolio Boost: +%.1f%% (MAX 20%%) | Status: %s\n"
      "   Loss Management: %s | Close Threshold: %.0f%%\n"
      "   Open Positions: %d | Monitored: %d",
      analysis.overallSentiment,
      analysis.tradeAction,
      analysis.pbScore,
      analysis.pbConfidence,
      analysis.componentResult.mtf.confidence,
      analysis.componentResult.macd.confidence,
      analysis.componentResult.rsi.confidence,
      analysis.componentResult.adx.confidence,
      analysis.componentResult.vol.confidence,
      analysis.componentResult.agreeingComponents,
      analysis.componentResult.disagreeingComponents,
      analysis.componentResult.neutralComponents,
      analysis.activeComponents,
      analysis.bestComponent,
      analysis.bestScore,
      m_portfolioConfidenceBoost,
      boostStatus,
      lossMgmtStatus,
      m_lossCloseConfidence,
      CountOpenPositions(),
      ArraySize(m_monitors)
   );
   
   return report;
}

//+------------------------------------------------------------------+
//| Get Monitor Report                                               |
//+------------------------------------------------------------------+
string CPortfolioManager::GetMonitorReport()
{
   string report = "📊 MONITORED POSITIONS:\n";
   report += "═══════════════════════════════════════════════\n";
   
   if(ArraySize(m_monitors) == 0)
   {
      report += "   No positions being monitored\n";
      return report;
   }
   
   for(int i = 0; i < ArraySize(m_monitors); i++)
   {
      PositionMonitor m = m_monitors[i];
      
      double currentPrice = 0;
      if(PositionSelectByTicket(m.ticket))
         currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double lossPips = m.isBuy ? (m.entryPrice - currentPrice) / point 
                                 : (currentPrice - m.entryPrice) / point;
      double lossPercent = m.riskPips > 0 ? (lossPips / m.riskPips) * 100 : 0;
      
      report += StringFormat(
         "   #%I64u | %s | Loss: %.1f pips (%.0f%%) | 50%%: %s | MACD Opposes: %s | Conf: %.1f%%\n",
         m.ticket,
         m.isBuy ? "BUY" : "SELL",
         lossPips,
         lossPercent,
         m.halfLossReached ? "✅" : "⬜",
         m.macdOpposesTrend ? "🔴 YES" : "⬜ NO",
         m.macdOppositionConfidence
      );
   }
   
   return report;
}