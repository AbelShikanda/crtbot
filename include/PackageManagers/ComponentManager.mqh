//+------------------------------------------------------------------+
//|                    ComponentManager.mqh                          |
//|                    Main Component Manager                        |
//|                    v3.3 - AUTO TREND DETECTION                  |
//|                    ULTRA SIMPLE SYSTEM                          |
//|                    SEPARATE: Score (display) vs Confidence (calc)|
//|                    AGREEMENT-WEIGHTED CONFIDENCE               |
//|                    AGREE = ADD, DISAGREE = SUBTRACT            |
//|                    NEUTRAL = IGNORED (no contribution)         |
//|                    MATHEMATICAL: Weighted voting system        |
//|                    NEW: Auto-detect trade direction from trend |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.3"

#include "../Data/AdxModule.mqh"
#include "../Data/MacdModule.mqh"
#include "../Data/MtfModule.mqh"
#include "../Data/PullbackModule.mqh"
#include "../Data/RsiModule.mqh"
#include "../Data/VolumeModule.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// COMPONENT MANAGER INDEPENDENT TOGGLE - SINGLE MAIN SWITCH
// ============================================================
bool g_debugComponentManager = false;  // Set to true to enable all ComponentManager debug logs

//+------------------------------------------------------------------+
//| Market Analysis Result Structure                                 |
//+------------------------------------------------------------------+
struct SMarketAnalysis
{
   SADXSummary adxData;
   SMACDSummary macdData;
   SMTFSummary mtfData;
   SPullbackSummary pullbackData;
   SRSISummary rsiData;
   SVolumeSummary volumeData;
   SComponentResult componentResult;
   
   string overallSentiment;
   double overallConfidence;      // For calculations (weighted avg of CONFIDENCE)
   double overallScore;           // For display only (weighted avg of SCORE)
   double pbConfidence;           // PB confidence for calculations
   double pbScore;                // PB score for display only
   string summary;
   datetime timestamp;
   int activeComponents;
   string bestComponent;
   double bestScore;
   string tradeAction;
   double usedThreshold;
};

//+------------------------------------------------------------------+
//| Component Manager Class                                         |
//+------------------------------------------------------------------+
class CComponentManager
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_tradeDirection;
   double   m_currentPrice;
   bool     m_isInitialized;
   string   m_lastError;
   int      m_cacheTimeout;      // Cache timeout in seconds (default: 5)
   
   // ──────────────────────────────────────────────────────────────
   // CACHE
   // ──────────────────────────────────────────────────────────────
   bool     m_cacheValid;
   datetime m_cacheTime;
   SMarketAnalysis m_cachedAnalysis;
   int      m_cachedTradeDirection;
   double   m_cachedPrice;
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT MODULES
   // ──────────────────────────────────────────────────────────────
   CAdxModule m_adxModule;
   CMacdModule m_macdModule;
   CMtfModule m_mtfModule;
   CPullbackModule m_pullbackModule;
   CRsiModule m_rsiModule;
   CVolumeModule m_volumeModule;
   
   // ──────────────────────────────────────────────────────────────
   // TREND MANAGER
   // ──────────────────────────────────────────────────────────────
   CTrendManager* m_trendManager;
   
   // ──────────────────────────────────────────────────────────────
   // THRESHOLDS
   // ──────────────────────────────────────────────────────────────
   double   m_minConfidenceThreshold;
   double   m_buyConfidenceThreshold;
   double   m_sellConfidenceThreshold;
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT WEIGHTS
   // ──────────────────────────────────────────────────────────────
   double   m_mtfWeight;
   double   m_macdWeight;
   double   m_rsiWeight;
   double   m_adxWeight;
   double   m_volWeight;
   double   m_pullbackWeight;
   
   // ──────────────────────────────────────────────────────────────
   // TREND CACHE
   // ──────────────────────────────────────────────────────────────
   string   m_cachedTrendDirection;
   datetime m_cachedTrendTime;
   bool     m_hasCachedTrend;
   string   m_lastValidTrendDirection;
   datetime m_lastValidTrendTime;
   int      m_cacheWarnings;
   bool     m_useCachedTrend;
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   void     InvalidateCache();
   bool     IsCacheValid(int tradeDirection, double currentPrice);
   void     UpdateCache(int tradeDirection, double currentPrice, SMarketAnalysis &analysis);
   
   SComponentResult AggregateComponents(
      SADXSummary &adx,
      SMACDSummary &macd,
      SMTFSummary &mtf,
      SPullbackSummary &pullback,
      SRSISummary &rsi,
      SVolumeSummary &volume
   );
   
   string   DetermineSentiment(SMarketAnalysis &analysis);
   double   CalculateOverallConfidence(SMarketAnalysis &analysis);
   double   CalculateOverallScore(SMarketAnalysis &analysis);
   string   GenerateSummary(SMarketAnalysis &analysis);
   void     CalculateActiveComponents(SMarketAnalysis &analysis);
   void     FindBestComponent(SMarketAnalysis &analysis);
   string   GetTradeAction(SMarketAnalysis &analysis);
   string   GetDirectionArrow(string direction);
   string   GetShortDirection(string direction);
   string   GetDirectionFromTrendManager();
   string   GetAlignment(string componentDir, string trendDir);
   bool     IsValidZone(string zoneCategory);
   double   GetThresholdForDirection(string direction);
   double   GetComponentConfidenceForDirection(SComponentDisplay &comp, string trendDir);
   string   GetComponentAlignmentString(string alignment);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CComponentManager(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   ~CComponentManager();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize();
   bool IsInitialized() const { return m_isInitialized; }
   string GetLastError() const { return m_lastError; }
   
   // ──────────────────────────────────────────────────────────────
   // CONFIGURATION
   // ──────────────────────────────────────────────────────────────
   void SetConfidenceThreshold(double threshold) { m_minConfidenceThreshold = threshold; InvalidateCache(); }
   void SetBuyThreshold(double threshold) { m_buyConfidenceThreshold = threshold; InvalidateCache(); }
   void SetSellThreshold(double threshold) { m_sellConfidenceThreshold = threshold; InvalidateCache(); }
   void SetCacheTimeout(int seconds);
   void SetWeights(double adxWeight, double macdWeight, double mtfWeight, 
                   double pullbackWeight, double rsiWeight, double volumeWeight);
   void SetTradeDirection(int direction) { m_tradeDirection = direction; InvalidateCache(); }
   void SetCurrentPrice(double price) { m_currentPrice = price; }
   void SetTrendManager(CTrendManager* trendManager);
   
   // ──────────────────────────────────────────────────────────────
   // AUTO TREND DETECTION (NEW v3.3)
   // ──────────────────────────────────────────────────────────────
   void AutoSetTradeDirectionFromTrend();
   int  GetAutoTradeDirection();  // Returns 1, -1, or 0 based on trend
   
   // ──────────────────────────────────────────────────────────────
   // GETTERS
   // ──────────────────────────────────────────────────────────────
   double GetBuyThreshold() const { return m_buyConfidenceThreshold; }
   double GetSellThreshold() const { return m_sellConfidenceThreshold; }
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   int GetTradeDirection() const { return m_tradeDirection; }
   
   // ──────────────────────────────────────────────────────────────
   // MODULE ACCESS
   // ──────────────────────────────────────────────────────────────
   CAdxModule* GetAdxModule() { return &m_adxModule; }
   CMacdModule* GetMacdModule() { return &m_macdModule; }
   CMtfModule* GetMtfModule() { return &m_mtfModule; }
   CPullbackModule* GetPullbackModule() { return &m_pullbackModule; }
   CRsiModule* GetRsiModule() { return &m_rsiModule; }
   CVolumeModule* GetVolumeModule() { return &m_volumeModule; }
   
   // ──────────────────────────────────────────────────────────────
   // CACHE MANAGEMENT
   // ──────────────────────────────────────────────────────────────
   string GetCachedTrend() const { return m_cachedTrendDirection; }
   bool HasCachedTrend() const { return m_hasCachedTrend; }
   void ResetCacheWarnings() { m_cacheWarnings = 0; }
   void ForceUseCachedTrend(bool use) { m_useCachedTrend = use; }
   void Refresh() { InvalidateCache(); }
   
   // ──────────────────────────────────────────────────────────────
   // DEBUG CONTROL
   // ──────────────────────────────────────────────────────────────
   static void SetGlobalDebug(bool enable) { g_debugComponentManager = enable; }
   static bool GetGlobalDebug() { return g_debugComponentManager; }
   
   // ──────────────────────────────────────────────────────────────
   // MAIN ANALYSIS METHODS (UPDATED v3.3)
   // ──────────────────────────────────────────────────────────────
   SMarketAnalysis AnalyzeMarket();
   SMarketAnalysis AnalyzeMarketWithPrice(int tradeDirection, double currentPrice);
   
   // ──────────────────────────────────────────────────────────────
   // OUTPUT METHODS
   // ──────────────────────────────────────────────────────────────
   void PrintAnalysis(SMarketAnalysis &analysis);
   string GetSummaryString(SMarketAnalysis &analysis);
   string GetQuickStatus(SMarketAnalysis &analysis);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CComponentManager::CComponentManager(string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_INFO("CComponentManager constructor called", g_debugComponentManager);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_isInitialized = false;
   m_lastError = "";
   m_cacheTimeout = 5;
   
   m_buyConfidenceThreshold = InpBuyThreshold;
   m_sellConfidenceThreshold = InpSellThreshold;
   m_minConfidenceThreshold = InpNeutralThreshold;
   
   m_tradeDirection = 0;
   m_currentPrice = 0;
   m_trendManager = NULL;
   
   m_mtfWeight = InpWeight_MTF;
   m_macdWeight = InpWeight_MACD;
   m_rsiWeight = InpWeight_RSI;
   m_adxWeight = InpWeight_ADX;
   m_volWeight = InpWeight_Volume;
   m_pullbackWeight = InpWeight_PB;
   
   InvalidateCache();
   
   m_cachedTrendDirection = "NEUTRAL";
   m_cachedTrendTime = 0;
   m_hasCachedTrend = false;
   m_lastValidTrendDirection = "NEUTRAL";
   m_lastValidTrendTime = 0;
   m_cacheWarnings = 0;
   m_useCachedTrend = false;
   
   LOG_INFO("Component Manager created - Symbol: " + m_symbol + 
       ", Timeframe: " + EnumToString(m_timeframe) + 
       ", Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s", g_debugComponentManager);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CComponentManager::~CComponentManager()
{
   LOG_INFO("CComponentManager destructor called", g_debugComponentManager);
}

//+------------------------------------------------------------------+
//| Invalidate Cache                                                |
//+------------------------------------------------------------------+
void CComponentManager::InvalidateCache()
{
   LOG_DEBUG("Invalidating cache...", g_debugComponentManager);
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cachedTradeDirection = 0;
   m_cachedPrice = 0;
   ZeroMemory(m_cachedAnalysis);
}

//+------------------------------------------------------------------+
//| Is Cache Valid                                                  |
//+------------------------------------------------------------------+
bool CComponentManager::IsCacheValid(int tradeDirection, double currentPrice)
{
   if(!m_cacheValid) return false;
   if((TimeCurrent() - m_cacheTime) > m_cacheTimeout) return false;
   if(m_cachedTradeDirection != tradeDirection) return false;
   if(MathAbs(m_cachedPrice - currentPrice) > 0.01) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Update Cache                                                    |
//+------------------------------------------------------------------+
void CComponentManager::UpdateCache(int tradeDirection, double currentPrice, SMarketAnalysis &analysis)
{
   m_cachedAnalysis = analysis;
   m_cachedTradeDirection = tradeDirection;
   m_cachedPrice = currentPrice;
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
   LOG_DEBUG("Cache updated (age: 0s)", g_debugComponentManager);
}

//+------------------------------------------------------------------+
//| Set Cache Timeout                                               |
//+------------------------------------------------------------------+
void CComponentManager::SetCacheTimeout(int seconds)
{
   if(seconds > 0)
   {
      m_cacheTimeout = seconds;
      LOG_INFO("Cache timeout set to " + IntegerToString(seconds) + " seconds", g_debugComponentManager);
      InvalidateCache();
   }
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CComponentManager::Initialize()
{
   LOG_INFO("========================================", g_debugComponentManager);
   LOG_INFO("Component Manager Initialization v3.3", g_debugComponentManager);
   LOG_INFO("========================================", g_debugComponentManager);
   LOG_INFO("Symbol: " + m_symbol, g_debugComponentManager);
   LOG_INFO("Timeframe: " + EnumToString(m_timeframe), g_debugComponentManager);
   LOG_INFO("----------------------------------------", g_debugComponentManager);
   LOG_INFO("COMPONENT WEIGHTS (for calculations):", g_debugComponentManager);
   LOG_INFO("  PB: " + DoubleToString(m_pullbackWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("  MTF: " + DoubleToString(m_mtfWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("  MACD: " + DoubleToString(m_macdWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("  RSI: " + DoubleToString(m_rsiWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("  VOL: " + DoubleToString(m_volWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("  ADX: " + DoubleToString(m_adxWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("----------------------------------------", g_debugComponentManager);
   LOG_INFO("CONFIDENCE THRESHOLDS (for entries):", g_debugComponentManager);
   LOG_INFO("  BUY: " + DoubleToString(m_buyConfidenceThreshold, 0) + "%", g_debugComponentManager);
   LOG_INFO("  SELL: " + DoubleToString(m_sellConfidenceThreshold, 0) + "%", g_debugComponentManager);
   LOG_INFO("  NEUTRAL: " + DoubleToString(m_minConfidenceThreshold, 0) + "%", g_debugComponentManager);
   LOG_INFO("----------------------------------------", g_debugComponentManager);
   LOG_INFO("CACHE TIMEOUT: " + IntegerToString(m_cacheTimeout) + "s", g_debugComponentManager);
   LOG_INFO("========================================", g_debugComponentManager);
   
   bool allInitialized = true;
   
   LOG_DEBUG("Initializing ADX Module...", g_debugComponentManager);
   if(!m_adxModule.Initialize())
   {
      LOG_INFO("Failed to initialize ADX Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   LOG_DEBUG("Initializing MACD Module...", g_debugComponentManager);
   if(!m_macdModule.Initialize())
   {
      LOG_INFO("Failed to initialize MACD Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   LOG_DEBUG("Initializing MTF Module...", g_debugComponentManager);
   if(!m_mtfModule.Initialize())
   {
      LOG_INFO("Failed to initialize MTF Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   LOG_DEBUG("Initializing Pullback Module...", g_debugComponentManager);
   if(!m_pullbackModule.Initialize())
   {
      LOG_INFO("Failed to initialize Pullback Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   LOG_DEBUG("Initializing RSI Module...", g_debugComponentManager);
   if(!m_rsiModule.Initialize())
   {
      LOG_INFO("Failed to initialize RSI Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   LOG_DEBUG("Initializing Volume Module...", g_debugComponentManager);
   if(!m_volumeModule.Initialize())
   {
      LOG_INFO("Failed to initialize Volume Module", g_debugComponentManager);
      allInitialized = false;
   }
   
   m_isInitialized = allInitialized;
   
   if(m_isInitialized) 
   {
      LOG_INFO("✅ Component Manager initialization complete", g_debugComponentManager);
      InvalidateCache();
   }
   else 
   {
      LOG_INFO("❌ Component Manager initialization failed", g_debugComponentManager);
      m_lastError = "Failed to initialize one or more modules";
   }
   
   return m_isInitialized;
}

//+------------------------------------------------------------------+
//| Set Weights                                                      |
//+------------------------------------------------------------------+
void CComponentManager::SetWeights(double adxWeight, double macdWeight, double mtfWeight, 
                                   double pullbackWeight, double rsiWeight, double volumeWeight)
{
   LOG_DEBUG("Setting weights...", g_debugComponentManager);
   
   double total = adxWeight + macdWeight + mtfWeight + pullbackWeight + rsiWeight + volumeWeight;
   if(total > 0)
   {
      m_adxWeight = adxWeight / total;
      m_macdWeight = macdWeight / total;
      m_mtfWeight = mtfWeight / total;
      m_pullbackWeight = pullbackWeight / total;
      m_rsiWeight = rsiWeight / total;
      m_volWeight = volumeWeight / total;
      
      LOG_INFO("Weights normalized: PB=" + DoubleToString(m_pullbackWeight * 100, 0) +
               "%, MTF=" + DoubleToString(m_mtfWeight * 100, 0) +
               "%, MACD=" + DoubleToString(m_macdWeight * 100, 0) +
               "%, RSI=" + DoubleToString(m_rsiWeight * 100, 0) +
               "%, VOL=" + DoubleToString(m_volWeight * 100, 0) +
               "%, ADX=" + DoubleToString(m_adxWeight * 100, 0) + "%", g_debugComponentManager);
      InvalidateCache();
   }
   else
   {
      LOG_INFO("Total weight must be > 0", g_debugComponentManager);
   }
}

//+------------------------------------------------------------------+
//| Set TrendManager                                                |
//+------------------------------------------------------------------+
void CComponentManager::SetTrendManager(CTrendManager* trendManager)
{
   LOG_DEBUG("Setting TrendManager...", g_debugComponentManager);
   m_trendManager = trendManager;
   
   if(m_trendManager != NULL)
   {
      m_pullbackModule.SetTrendManager(trendManager);
      
      m_cachedTrendDirection = m_trendManager.GetDirection();
      m_cachedTrendTime = TimeCurrent();
      m_hasCachedTrend = true;
      m_cacheWarnings = 0;
      
      LOG_INFO("✅ TrendManager set and cached: " + m_cachedTrendDirection, g_debugComponentManager);
   }
   else
   {
      LOG_DEBUG("⚠️ TrendManager set to NULL - using cached value if available", g_debugComponentManager);
   }
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Auto-Set Trade Direction From Trend (NEW v3.3)                  |
//+------------------------------------------------------------------+
void CComponentManager::AutoSetTradeDirectionFromTrend()
{
   LOG_INFO("Auto-setting trade direction from trend...", g_debugComponentManager);
   
   if(m_trendManager == NULL) {
      LOG_INFO("Cannot auto-set direction: TrendManager is NULL", g_debugComponentManager);
      return;
   }
   
   string trendDir = m_trendManager.GetDirection();
   LOG_DEBUG("  TrendManager returned: " + trendDir, g_debugComponentManager);
   
   if(trendDir == "BULLISH") {
      m_tradeDirection = 1;
      LOG_INFO("✅ Auto-set trade direction to BUY (1) from BULLISH trend", g_debugComponentManager);
   }
   else if(trendDir == "BEARISH") {
      m_tradeDirection = -1;
      LOG_INFO("✅ Auto-set trade direction to SELL (-1) from BEARISH trend", g_debugComponentManager);
   }
   else {
      m_tradeDirection = 0;
      LOG_INFO("⚠️ Trend is NEUTRAL - trade direction set to 0 (no trade)", g_debugComponentManager);
   }
   
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Get Auto Trade Direction (NEW v3.3)                             |
//+------------------------------------------------------------------+
int CComponentManager::GetAutoTradeDirection()
{
   if(m_trendManager == NULL) {
      LOG_INFO("Cannot get auto direction: TrendManager is NULL", g_debugComponentManager);
      return 0;
   }
   
   string trendDir = m_trendManager.GetDirection();
   
   if(trendDir == "BULLISH") return 1;
   else if(trendDir == "BEARISH") return -1;
   else return 0;
}

//+------------------------------------------------------------------+
//| Get Direction From TrendManager                                 |
//+------------------------------------------------------------------+
string CComponentManager::GetDirectionFromTrendManager()
{
   LOG_DEBUG("Getting trend direction...", g_debugComponentManager);
   string result = "NEUTRAL";
   bool usingCached = false;
   bool usingLastValid = false;
   int cacheAgeSeconds = 0;
   
   if(m_hasCachedTrend && m_cachedTrendDirection != "NEUTRAL")
   {
      cacheAgeSeconds = (int)(TimeCurrent() - m_cachedTrendTime);
      if(cacheAgeSeconds < 3600)
      {
         usingCached = true;
         result = m_cachedTrendDirection;
         LOG_DEBUG("  Using cached trend: " + result + " (age: " + IntegerToString(cacheAgeSeconds) + "s)", g_debugComponentManager);
         return result;
      }
   }
   
   if(m_trendManager != NULL)
   {
      string trend = m_trendManager.GetDirection();
      LOG_DEBUG("  TrendManager returned: " + trend, g_debugComponentManager);
      
      m_cachedTrendDirection = trend;
      m_cachedTrendTime = TimeCurrent();
      m_hasCachedTrend = true;
      
      if(trend != "NEUTRAL")
      {
         m_lastValidTrendDirection = trend;
         m_lastValidTrendTime = TimeCurrent();
         result = trend;
         LOG_DEBUG("  Using TrendManager: " + result, g_debugComponentManager);
         return result;
      }
      else
      {
         if(m_lastValidTrendDirection != "NEUTRAL")
         {
            int lastValidAge = (int)(TimeCurrent() - m_lastValidTrendTime);
            if(lastValidAge < 3600)
            {
               result = m_lastValidTrendDirection;
               usingLastValid = true;
               LOG_DEBUG("  ⚠️ TrendManager returned NEUTRAL, using last valid: " + 
                          result + " (age: " + IntegerToString(lastValidAge/60) + " min)", g_debugComponentManager);
               return result;
            }
         }
      }
   }
   
   if(m_lastValidTrendDirection != "NEUTRAL")
   {
      int lastValidAge = (int)(TimeCurrent() - m_lastValidTrendTime);
      if(lastValidAge < 3600)
      {
         result = m_lastValidTrendDirection;
         usingLastValid = true;
         LOG_DEBUG("  🔄 Using last valid trend: " + result + 
                    " (age: " + IntegerToString(lastValidAge/60) + " min)", g_debugComponentManager);
         return result;
      }
   }
   
   if(m_cacheWarnings < 10 || m_cacheWarnings % 50 == 0)
   {
      LOG_DEBUG("  ⚠️ No valid trend available - returning NEUTRAL", g_debugComponentManager);
   }
   m_cacheWarnings++;
   
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Component Alignment String                                   |
//+------------------------------------------------------------------+
string CComponentManager::GetComponentAlignmentString(string alignment)
{
   if(alignment == "AGREE") return "✅ AGREE";
   else if(alignment == "DISAGREE") return "❌ DISAGREE";
   else return "⚪ NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Direction Arrow                                             |
//+------------------------------------------------------------------+
string CComponentManager::GetDirectionArrow(string direction)
{
   if(direction == "BULLISH") return "▲";
   else if(direction == "BEARISH") return "▼";
   else return "●";
}

//+------------------------------------------------------------------+
//| Get Short Direction                                             |
//+------------------------------------------------------------------+
string CComponentManager::GetShortDirection(string direction)
{
   if(direction == "BULLISH") return "BULL";
   else if(direction == "BEARISH") return "BEAR";
   else return "NEUT";
}

//+------------------------------------------------------------------+
//| Get Alignment                                                   |
//+------------------------------------------------------------------+
string CComponentManager::GetAlignment(string componentDir, string trendDir)
{
   if(componentDir == "NEUTRAL") return "NEUTRAL";
   if(componentDir == trendDir) return "AGREE";
   return "DISAGREE";
}

//+------------------------------------------------------------------+
//| Is Valid Zone                                                    |
//+------------------------------------------------------------------+
bool CComponentManager::IsValidZone(string zoneCategory)
{
   if(zoneCategory == "EXTREME") return false;
   return true;
}

//+------------------------------------------------------------------+
//| Get Threshold For Direction                                      |
//+------------------------------------------------------------------+
double CComponentManager::GetThresholdForDirection(string direction)
{
   if(direction == "BULLISH")
      return m_buyConfidenceThreshold;
   else if(direction == "BEARISH")
      return m_sellConfidenceThreshold;
   else
      return m_minConfidenceThreshold;
}

//+------------------------------------------------------------------+
//| Aggregate Components                                             |
//+------------------------------------------------------------------+
SComponentResult CComponentManager::AggregateComponents(
   SADXSummary &adx,
   SMACDSummary &macd,
   SMTFSummary &mtf,
   SPullbackSummary &pullback,
   SRSISummary &rsi,
   SVolumeSummary &volume
)
{
   LOG_DEBUG("=== AGGREGATING COMPONENTS ===", g_debugComponentManager);
   
   SComponentResult result;
   ZeroMemory(result);
   result.timestamp = TimeCurrent();
   
   string trendDir = GetDirectionFromTrendManager();
   result.direction = trendDir;
   
   LOG_DEBUG("  Trend Direction: " + trendDir, g_debugComponentManager);
   
   double pbScore = pullback.pullbackScore;
   double pbConfidence = pullback.pullbackScore;
   string pbZone = pullback.zoneCategory;
   double pbPercent = pullback.adjustedPercent;
   
   result.pb.name = "PB";
   result.pb.directionText = trendDir;
   result.pb.direction = GetDirectionArrow(trendDir);
   result.pb.confidence = pbConfidence;
   result.pb.score = pbScore;
   result.pb.rawScore = pbPercent;
   result.pb.weight = m_pullbackWeight;
   result.pb.isActive = IsValidZone(pbZone);
   result.pb.alignment = "AGREE";
   
   LOG_DEBUG("  PB: " + DoubleToString(pbScore, 0) + "% score, " + 
              DoubleToString(pbConfidence, 0) + "% conf, " + 
              result.pb.alignment + ", zone=" + pbZone, g_debugComponentManager);
   
   result.mtf.name = "MTF";
   result.mtf.directionText = mtf.direction;
   result.mtf.direction = GetDirectionArrow(mtf.direction);
   result.mtf.confidence = mtf.confidence;
   result.mtf.score = mtf.confidence;
   result.mtf.rawScore = (double)mtf.totalScore;
   result.mtf.weight = m_mtfWeight;
   result.mtf.isActive = (mtf.totalScore >= 20 && mtf.confidence >= 10);
   result.mtf.alignment = GetAlignment(mtf.direction, trendDir);
   
   LOG_DEBUG("  MTF: " + DoubleToString(mtf.confidence, 0) + "% score, " + 
              result.mtf.alignment + ", active=" + (result.mtf.isActive ? "YES" : "NO"), g_debugComponentManager);
   
   result.macd.name = "MACD";
   result.macd.directionText = macd.direction;
   result.macd.direction = GetDirectionArrow(macd.direction);
   result.macd.confidence = macd.confidence;
   result.macd.score = macd.confidence;
   result.macd.rawScore = macd.histogramValue;
   result.macd.weight = m_macdWeight;
   result.macd.isActive = (macd.direction != "NEUTRAL" && macd.confidence >= 10);
   result.macd.alignment = GetAlignment(macd.direction, trendDir);
   
   LOG_DEBUG("  MACD: " + DoubleToString(macd.confidence, 0) + "% conf, " + 
              result.macd.alignment + ", active=" + (result.macd.isActive ? "YES" : "NO"), g_debugComponentManager);
   
   result.rsi.name = "RSI";
   result.rsi.directionText = rsi.direction;
   result.rsi.direction = GetDirectionArrow(rsi.direction);
   result.rsi.confidence = rsi.confidence;
   result.rsi.score = rsi.confidence;
   result.rsi.rawScore = rsi.rsiValue;
   result.rsi.weight = m_rsiWeight;
   result.rsi.isActive = (rsi.direction != "NEUTRAL" && rsi.confidence >= 10);
   result.rsi.alignment = GetAlignment(rsi.direction, trendDir);
   
   LOG_DEBUG("  RSI: " + DoubleToString(rsi.confidence, 0) + "% conf, " + 
              result.rsi.alignment + ", active=" + (result.rsi.isActive ? "YES" : "NO"), g_debugComponentManager);
   
   SADXDirectionResult adxResult = m_adxModule.GetDirectionResult();
   string adxDirection = adxResult.direction;
   double adxConfidence = adxResult.confidence;
   double adxScore = adxResult.confidence;
   
   result.adx.name = "ADX";
   result.adx.directionText = adxDirection;
   result.adx.direction = GetDirectionArrow(adxDirection);
   result.adx.confidence = adxConfidence;
   result.adx.score = adxScore;
   result.adx.rawScore = adx.adxValue;
   result.adx.weight = m_adxWeight;
   result.adx.isActive = (adx.adxValue >= 20 && adxConfidence >= 10);
   result.adx.alignment = GetAlignment(adxDirection, trendDir);
   
   LOG_DEBUG("  ADX: " + DoubleToString(adxConfidence, 0) + "% conf (ENHANCED), " + 
              result.adx.alignment + ", active=" + (result.adx.isActive ? "YES" : "NO"), g_debugComponentManager);
   
   result.vol.name = "VOL";
   result.vol.directionText = volume.direction;
   result.vol.direction = GetDirectionArrow(volume.direction);
   result.vol.confidence = volume.confidence;
   result.vol.score = volume.confidence;
   result.vol.rawScore = volume.volumeRatio;
   result.vol.weight = m_volWeight;
   result.vol.isActive = (volume.direction != "NEUTRAL" && volume.confidence >= 10);
   result.vol.alignment = GetAlignment(volume.direction, trendDir);
   
   LOG_DEBUG("  VOL: " + DoubleToString(volume.confidence, 0) + "% conf, " + 
              result.vol.alignment + ", active=" + (result.vol.isActive ? "YES" : "NO"), g_debugComponentManager);
   
   result.agreeingComponents = 0;
   result.disagreeingComponents = 0;
   result.neutralComponents = 0;
   
   result.agreeingComponents++;
   
   if(result.mtf.alignment == "AGREE") result.agreeingComponents++;
   else if(result.mtf.alignment == "DISAGREE") result.disagreeingComponents++;
   else if(result.mtf.alignment == "NEUTRAL") result.neutralComponents++;
   
   if(result.macd.alignment == "AGREE") result.agreeingComponents++;
   else if(result.macd.alignment == "DISAGREE") result.disagreeingComponents++;
   else if(result.macd.alignment == "NEUTRAL") result.neutralComponents++;
   
   if(result.adx.alignment == "AGREE") result.agreeingComponents++;
   else if(result.adx.alignment == "DISAGREE") result.disagreeingComponents++;
   else if(result.adx.alignment == "NEUTRAL") result.neutralComponents++;
   
   if(result.rsi.alignment == "AGREE") result.agreeingComponents++;
   else if(result.rsi.alignment == "DISAGREE") result.disagreeingComponents++;
   else if(result.rsi.alignment == "NEUTRAL") result.neutralComponents++;
   
   if(result.vol.alignment == "AGREE") result.agreeingComponents++;
   else if(result.vol.alignment == "DISAGREE") result.disagreeingComponents++;
   else if(result.vol.alignment == "NEUTRAL") result.neutralComponents++;
   
   LOG_DEBUG("  Alignment: Agree=" + IntegerToString(result.agreeingComponents) +
              ", Disagree=" + IntegerToString(result.disagreeingComponents) +
              ", Neutral=" + IntegerToString(result.neutralComponents), g_debugComponentManager);
   
   result.activeComponents = 0;
   if(result.pb.isActive) result.activeComponents++;
   if(result.mtf.isActive) result.activeComponents++;
   if(result.macd.isActive) result.activeComponents++;
   if(result.adx.isActive) result.activeComponents++;
   if(result.rsi.isActive) result.activeComponents++;
   if(result.vol.isActive) result.activeComponents++;
   
   LOG_DEBUG("  Active Components: " + IntegerToString(result.activeComponents) + "/6", g_debugComponentManager);
   
   double agreeTotal = 0;
   double disagreeTotal = 0;
   double totalWeight = 0;
   
   double pbContrib = result.pb.confidence * result.pb.weight;
   agreeTotal += pbContrib;
   totalWeight += result.pb.weight;
   
   LOG_DEBUG("  PB: " + DoubleToString(result.pb.confidence, 2) + " × " + 
              DoubleToString(result.pb.weight, 2) + " = " + 
              DoubleToString(pbContrib, 2) + " (AGREE)", g_debugComponentManager);
   
   if(result.mtf.alignment == "AGREE")
   {
      double contrib = result.mtf.confidence * result.mtf.weight;
      agreeTotal += contrib;
      totalWeight += result.mtf.weight;
      LOG_DEBUG("  MTF: " + DoubleToString(result.mtf.confidence, 2) + " × " + 
                 DoubleToString(result.mtf.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (AGREE)", g_debugComponentManager);
   }
   else if(result.mtf.alignment == "DISAGREE")
   {
      double contrib = result.mtf.confidence * result.mtf.weight;
      disagreeTotal += contrib;
      totalWeight += result.mtf.weight;
      LOG_DEBUG("  MTF: " + DoubleToString(result.mtf.confidence, 2) + " × " + 
                 DoubleToString(result.mtf.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (DISAGREE)", g_debugComponentManager);
   }
   
   if(result.macd.alignment == "AGREE")
   {
      double contrib = result.macd.confidence * result.macd.weight;
      agreeTotal += contrib;
      totalWeight += result.macd.weight;
      LOG_DEBUG("  MACD: " + DoubleToString(result.macd.confidence, 2) + " × " + 
                 DoubleToString(result.macd.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (AGREE)", g_debugComponentManager);
   }
   else if(result.macd.alignment == "DISAGREE")
   {
      double contrib = result.macd.confidence * result.macd.weight;
      disagreeTotal += contrib;
      totalWeight += result.macd.weight;
      LOG_DEBUG("  MACD: " + DoubleToString(result.macd.confidence, 2) + " × " + 
                 DoubleToString(result.macd.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (DISAGREE)", g_debugComponentManager);
   }
   
   if(result.adx.alignment == "AGREE")
   {
      double contrib = result.adx.confidence * result.adx.weight;
      agreeTotal += contrib;
      totalWeight += result.adx.weight;
      LOG_DEBUG("  ADX: " + DoubleToString(result.adx.confidence, 2) + " × " + 
                 DoubleToString(result.adx.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (AGREE) ← ENHANCED CONFIDENCE", g_debugComponentManager);
   }
   else if(result.adx.alignment == "DISAGREE")
   {
      double contrib = result.adx.confidence * result.adx.weight;
      disagreeTotal += contrib;
      totalWeight += result.adx.weight;
      LOG_DEBUG("  ADX: " + DoubleToString(result.adx.confidence, 2) + " × " + 
                 DoubleToString(result.adx.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (DISAGREE)", g_debugComponentManager);
   }
   
   if(result.rsi.alignment == "AGREE")
   {
      double contrib = result.rsi.confidence * result.rsi.weight;
      agreeTotal += contrib;
      totalWeight += result.rsi.weight;
      LOG_DEBUG("  RSI: " + DoubleToString(result.rsi.confidence, 2) + " × " + 
                 DoubleToString(result.rsi.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (AGREE)", g_debugComponentManager);
   }
   else if(result.rsi.alignment == "DISAGREE")
   {
      double contrib = result.rsi.confidence * result.rsi.weight;
      disagreeTotal += contrib;
      totalWeight += result.rsi.weight;
      LOG_DEBUG("  RSI: " + DoubleToString(result.rsi.confidence, 2) + " × " + 
                 DoubleToString(result.rsi.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (DISAGREE)", g_debugComponentManager);
   }
   
   if(result.vol.alignment == "AGREE")
   {
      double contrib = result.vol.confidence * result.vol.weight;
      agreeTotal += contrib;
      totalWeight += result.vol.weight;
      LOG_DEBUG("  VOL: " + DoubleToString(result.vol.confidence, 2) + " × " + 
                 DoubleToString(result.vol.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (AGREE)", g_debugComponentManager);
   }
   else if(result.vol.alignment == "DISAGREE")
   {
      double contrib = result.vol.confidence * result.vol.weight;
      disagreeTotal += contrib;
      totalWeight += result.vol.weight;
      LOG_DEBUG("  VOL: " + DoubleToString(result.vol.confidence, 2) + " × " + 
                 DoubleToString(result.vol.weight, 2) + " = " + 
                 DoubleToString(contrib, 2) + " (DISAGREE)", g_debugComponentManager);
   }
   
   result.rawAgreeTotal = agreeTotal;
   result.rawDisagreeTotal = disagreeTotal;
   result.rawConfidenceTotal = agreeTotal - disagreeTotal;
   result.activeWeight = totalWeight;
   
   LOG_DEBUG("  Totals: Agree=" + DoubleToString(agreeTotal, 2) +
              ", Disagree=" + DoubleToString(disagreeTotal, 2) +
              ", Net=" + DoubleToString(result.rawConfidenceTotal, 2) +
              ", Weight=" + DoubleToString(totalWeight, 2), g_debugComponentManager);
   
   if(totalWeight > 0)
      result.confidence = result.rawConfidenceTotal / totalWeight;
   else
      result.confidence = 0;
   
   if(result.confidence < 0) 
   {
      result.confidence = 0;
      LOG_DEBUG("  Confidence clamped to 0 (was negative)", g_debugComponentManager);
   }
   if(result.confidence > 100) result.confidence = 100;
   
   LOG_DEBUG("  Final Confidence: " + DoubleToString(result.confidence, 1) + "%", g_debugComponentManager);
   
   double agreeScoreTotal = 0;
   double disagreeScoreTotal = 0;
   double totalScoreWeight = 0;
   
   agreeScoreTotal += result.pb.score * result.pb.weight;
   totalScoreWeight += result.pb.weight;
   
   if(result.mtf.alignment == "AGREE")
   {
      agreeScoreTotal += result.mtf.score * result.mtf.weight;
      totalScoreWeight += result.mtf.weight;
   }
   else if(result.mtf.alignment == "DISAGREE")
   {
      disagreeScoreTotal += result.mtf.score * result.mtf.weight;
      totalScoreWeight += result.mtf.weight;
   }
   
   if(result.macd.alignment == "AGREE")
   {
      agreeScoreTotal += result.macd.score * result.macd.weight;
      totalScoreWeight += result.macd.weight;
   }
   else if(result.macd.alignment == "DISAGREE")
   {
      disagreeScoreTotal += result.macd.score * result.macd.weight;
      totalScoreWeight += result.macd.weight;
   }
   
   if(result.adx.alignment == "AGREE")
   {
      agreeScoreTotal += result.adx.score * result.adx.weight;
      totalScoreWeight += result.adx.weight;
   }
   else if(result.adx.alignment == "DISAGREE")
   {
      disagreeScoreTotal += result.adx.score * result.adx.weight;
      totalScoreWeight += result.adx.weight;
   }
   
   if(result.rsi.alignment == "AGREE")
   {
      agreeScoreTotal += result.rsi.score * result.rsi.weight;
      totalScoreWeight += result.rsi.weight;
   }
   else if(result.rsi.alignment == "DISAGREE")
   {
      disagreeScoreTotal += result.rsi.score * result.rsi.weight;
      totalScoreWeight += result.rsi.weight;
   }
   
   if(result.vol.alignment == "AGREE")
   {
      agreeScoreTotal += result.vol.score * result.vol.weight;
      totalScoreWeight += result.vol.weight;
   }
   else if(result.vol.alignment == "DISAGREE")
   {
      disagreeScoreTotal += result.vol.score * result.vol.weight;
      totalScoreWeight += result.vol.weight;
   }
   
   result.rawScoreTotal = agreeScoreTotal - disagreeScoreTotal;
   
   if(totalScoreWeight > 0)
      result.overallScore = result.rawScoreTotal / totalScoreWeight;
   else
      result.overallScore = 0;
   
   if(result.overallScore < 0) result.overallScore = 0;
   if(result.overallScore > 100) result.overallScore = 100;
   
   LOG_DEBUG("  Final Score (display): " + DoubleToString(result.overallScore, 1) + "%", g_debugComponentManager);
   
   result.description = StringFormat(
      "TREND: %s | PB Score(DISPLAY):%.0f%% PB Conf(CALC):%.0f%% | MTF:%.0f%% MACD:%.0f%% RSI:%.0f%% ADX:%.0f%% VOL:%.0f%% | Conf(CALC):%.0f%% Score(DISPLAY):%.0f%% | Agree:%d Disagree:%d Neutral:%d | Formula:(%.2f-%.2f)/%.2f=%.1f%%",
      result.direction,
      result.pb.score,
      result.pb.confidence,
      result.mtf.confidence,
      result.macd.confidence,
      result.rsi.confidence,
      result.adx.confidence,
      result.vol.confidence,
      result.confidence,
      result.overallScore,
      result.agreeingComponents,
      result.disagreeingComponents,
      result.neutralComponents,
      result.rawAgreeTotal,
      result.rawDisagreeTotal,
      result.activeWeight,
      result.confidence
   );
   
   LOG_DEBUG("=== AGGREGATION COMPLETE ===", g_debugComponentManager);
   return result;
}

//+------------------------------------------------------------------+
//| Analyze Market (UPDATED v3.3)                                   |
//+------------------------------------------------------------------+
SMarketAnalysis CComponentManager::AnalyzeMarket()
{
   LOG_DEBUG("AnalyzeMarket() called", g_debugComponentManager);
   
   // 🆕 AUTO-SET TRADE DIRECTION FROM TREND IF NOT SET
   if(m_tradeDirection == 0 && m_trendManager != NULL) {
      LOG_INFO("⚠️ Trade direction not set - auto-detecting from trend...", g_debugComponentManager);
      AutoSetTradeDirectionFromTrend();
   }
   
   if(m_currentPrice <= 0)
      m_currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   return AnalyzeMarketWithPrice(m_tradeDirection, m_currentPrice);
}

//+------------------------------------------------------------------+
//| Analyze Market With Price (UPDATED v3.3)                        |
//+------------------------------------------------------------------+
SMarketAnalysis CComponentManager::AnalyzeMarketWithPrice(int tradeDirection, double currentPrice)
{
   LOG_DEBUG("=== ANALYZE MARKET WITH PRICE ===", g_debugComponentManager);
   
   // 🆕 If tradeDirection is 0, auto-set from trend
   if(tradeDirection == 0 && m_trendManager != NULL) {
      LOG_INFO("⚠️ Trade direction 0 passed - auto-detecting from trend...", g_debugComponentManager);
      string trendDir = m_trendManager.GetDirection();
      if(trendDir == "BULLISH") {
         tradeDirection = 1;
         LOG_INFO("✅ Auto-set to BUY (1) from BULLISH trend", g_debugComponentManager);
      } else if(trendDir == "BEARISH") {
         tradeDirection = -1;
         LOG_INFO("✅ Auto-set to SELL (-1) from BEARISH trend", g_debugComponentManager);
      } else {
         LOG_INFO("⚠️ Trend is NEUTRAL - keeping trade direction 0", g_debugComponentManager);
      }
      m_tradeDirection = tradeDirection; // Save it
      InvalidateCache(); // Invalidate cache since direction changed
   }
   
   LOG_DEBUG("  Trade Direction: " + IntegerToString(tradeDirection), g_debugComponentManager);
   LOG_DEBUG("  Current Price: " + DoubleToString(currentPrice, 2), g_debugComponentManager);
   
   SMarketAnalysis analysis;
   ZeroMemory(analysis);
   analysis.timestamp = TimeCurrent();
   analysis.overallScore = 0;
   analysis.usedThreshold = 0;
   
   if(IsCacheValid(tradeDirection, currentPrice))
   {
      LOG_DEBUG("✅ Using CACHED analysis (age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)", g_debugComponentManager);
      return m_cachedAnalysis;
   }
   
   LOG_DEBUG("  Cache invalid or expired - recalculating...", g_debugComponentManager);
   
   if(!m_isInitialized)
   {
      analysis.summary = "Component Manager not initialized";
      analysis.overallSentiment = "NEUTRAL";
      analysis.overallConfidence = 0;
      analysis.overallScore = 0;
      analysis.activeComponents = 0;
      analysis.tradeAction = "NO TRADE";
      LOG_INFO("Component Manager not initialized", g_debugComponentManager);
      return analysis;
   }
   
   m_tradeDirection = tradeDirection;
   m_currentPrice = currentPrice;
   
   LOG_DEBUG("  Fetching component data...", g_debugComponentManager);
   analysis.adxData = m_adxModule.GetADXSummary();
   analysis.macdData = m_macdModule.GetMACDSummary();
   analysis.mtfData = m_mtfModule.GetMTFSummary(tradeDirection, currentPrice);
   analysis.pullbackData = m_pullbackModule.GetPullbackSummary();
   analysis.rsiData = m_rsiModule.GetRSISummary(tradeDirection);
   analysis.volumeData = m_volumeModule.GetVolumeSummary();
   LOG_DEBUG("  Component data fetched", g_debugComponentManager);
   
   string trendDir = GetDirectionFromTrendManager();
   LOG_DEBUG("  Trend Direction: " + trendDir, g_debugComponentManager);
   
   if(trendDir == "NEUTRAL" && m_lastValidTrendDirection != "NEUTRAL")
   {
      int lastValidAge = (int)(TimeCurrent() - m_lastValidTrendTime);
      if(lastValidAge < 3600)
      {
         LOG_DEBUG("  ⚠️ TrendManager returned NEUTRAL, using last valid: " + 
                    m_lastValidTrendDirection + " (age: " + IntegerToString(lastValidAge/60) + " min)", g_debugComponentManager);
         trendDir = m_lastValidTrendDirection;
      }
   }
   
   if(trendDir == "NEUTRAL")
   {
      LOG_INFO("⚠️ No trend direction available - returning NEUTRAL", g_debugComponentManager);
      SMarketAnalysis neutralAnalysis;
      ZeroMemory(neutralAnalysis);
      neutralAnalysis.timestamp = TimeCurrent();
      neutralAnalysis.overallSentiment = "NEUTRAL";
      neutralAnalysis.overallConfidence = 0;
      neutralAnalysis.overallScore = 0;
      neutralAnalysis.activeComponents = 0;
      neutralAnalysis.tradeAction = "NO TRADE (Neutral Trend)";
      neutralAnalysis.summary = "NO TRADE - Trend is neutral. Waiting for directional bias.";
      neutralAnalysis.bestComponent = "None";
      neutralAnalysis.bestScore = 0;
      neutralAnalysis.usedThreshold = m_minConfidenceThreshold;
      
      // DON'T CACHE NEUTRAL RESULTS
      return neutralAnalysis;
   }
   
   LOG_DEBUG("  Aggregating components...", g_debugComponentManager);
   analysis.componentResult = AggregateComponents(
      analysis.adxData,
      analysis.macdData,
      analysis.mtfData,
      analysis.pullbackData,
      analysis.rsiData,
      analysis.volumeData
   );
   
   analysis.componentResult.direction = trendDir;
   analysis.overallSentiment = trendDir;
   
   analysis.overallConfidence = analysis.componentResult.confidence;
   analysis.overallScore = analysis.componentResult.overallScore;
   analysis.pbConfidence = analysis.componentResult.pb.confidence;
   analysis.pbScore = analysis.componentResult.pb.score;
   
   analysis.activeComponents = analysis.componentResult.activeComponents;
   analysis.usedThreshold = GetThresholdForDirection(trendDir);
   analysis.tradeAction = GetTradeAction(analysis);
   
   CalculateActiveComponents(analysis);
   FindBestComponent(analysis);
   analysis.summary = GenerateSummary(analysis);
   
   LOG_INFO("✅ Analysis complete - Direction: " + analysis.overallSentiment +
             ", Confidence: " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugComponentManager);
   
   UpdateCache(tradeDirection, currentPrice, analysis);
   
   return analysis;
}

//+------------------------------------------------------------------+
//| Get Trade Action                                                |
//+------------------------------------------------------------------+
string CComponentManager::GetTradeAction(SMarketAnalysis &analysis)
{
   LOG_DEBUG("  Determining trade action...", g_debugComponentManager);
   
   if(analysis.overallSentiment == "NEUTRAL")
   {
      LOG_DEBUG("    → NO TRADE (Neutral Trend)", g_debugComponentManager);
      return "NO TRADE (Neutral Trend)";
   }
   
   string pbZone = analysis.pullbackData.zoneCategory;
   if(pbZone == "EXTREME")
   {
      LOG_DEBUG("    → NO TRADE (Extreme Zone: " + pbZone + ")", g_debugComponentManager);
      return "NO TRADE (Extreme Zone)";
   }
   
   double threshold = GetThresholdForDirection(analysis.overallSentiment);
   double confidence = analysis.overallConfidence;
   
   LOG_DEBUG("    Confidence: " + DoubleToString(confidence, 1) + 
              "%, Threshold: " + DoubleToString(threshold, 1) + "%", g_debugComponentManager);
   
   if(confidence < threshold)
   {
      string confStr = DoubleToString(threshold, 0);
      LOG_DEBUG("    → NO TRADE (Below " + confStr + "% threshold)", g_debugComponentManager);
      return "NO TRADE (Below " + confStr + "% threshold)";
   }
   
   if(pbZone == "TRANSITION" || pbZone == "TRANSITION EDGE")
   {
      LOG_DEBUG("    → REDUCED (Transition zone)", g_debugComponentManager);
      return "REDUCED (Transition zone)";
   }
   
   LOG_DEBUG("    → ENTRY ✓", g_debugComponentManager);
   return "ENTRY";
}

//+------------------------------------------------------------------+
//| Determine Sentiment                                              |
//+------------------------------------------------------------------+
string CComponentManager::DetermineSentiment(SMarketAnalysis &analysis)
{
   return GetDirectionFromTrendManager();
}

//+------------------------------------------------------------------+
//| Calculate Active Components                                     |
//+------------------------------------------------------------------+
void CComponentManager::CalculateActiveComponents(SMarketAnalysis &analysis)
{
   analysis.activeComponents = analysis.componentResult.activeComponents;
}

//+------------------------------------------------------------------+
//| Find Best Component                                              |
//+------------------------------------------------------------------+
void CComponentManager::FindBestComponent(SMarketAnalysis &analysis)
{
   double bestScore = 0;
   string bestName = "None";
   
   if(analysis.componentResult.pb.isActive && analysis.componentResult.pb.score > bestScore)
   {
      bestScore = analysis.componentResult.pb.score;
      bestName = "PB";
   }
   if(analysis.componentResult.mtf.isActive && analysis.componentResult.mtf.score > bestScore)
   {
      bestScore = analysis.componentResult.mtf.score;
      bestName = "MTF";
   }
   if(analysis.componentResult.macd.isActive && analysis.componentResult.macd.score > bestScore)
   {
      bestScore = analysis.componentResult.macd.score;
      bestName = "MACD";
   }
   if(analysis.componentResult.adx.isActive && analysis.componentResult.adx.score > bestScore)
   {
      bestScore = analysis.componentResult.adx.score;
      bestName = "ADX";
   }
   if(analysis.componentResult.rsi.isActive && analysis.componentResult.rsi.score > bestScore)
   {
      bestScore = analysis.componentResult.rsi.score;
      bestName = "RSI";
   }
   if(analysis.componentResult.vol.isActive && analysis.componentResult.vol.score > bestScore)
   {
      bestScore = analysis.componentResult.vol.score;
      bestName = "VOL";
   }
   
   analysis.bestComponent = bestName;
   analysis.bestScore = bestScore;
   
   LOG_DEBUG("  Best Component: " + bestName + " (" + DoubleToString(bestScore, 1) + "%)", g_debugComponentManager);
}

//+------------------------------------------------------------------+
//| Generate Summary                                                 |
//+------------------------------------------------------------------+
string CComponentManager::GenerateSummary(SMarketAnalysis &analysis)
{
   string summary = "";
   double threshold = analysis.usedThreshold;
   string thresholdStr = (threshold > 0) ? DoubleToString(threshold, 0) : "?";
   string direction = analysis.overallSentiment;
   string dirDisplay = (direction == "BULLISH") ? "BUY" : (direction == "BEARISH") ? "SELL" : "HOLD";
   
   summary += StringFormat("TREND: %s (%s) | Action: %s | Conf(CALC): %.1f%% | Score(DISPLAY): %.1f%% | Threshold: %s%%",
                          analysis.overallSentiment, dirDisplay,
                          analysis.tradeAction, 
                          analysis.overallConfidence, 
                          analysis.overallScore,
                          thresholdStr);
   
   summary += " | ";
   summary += StringFormat("PB Score(DISPLAY):%.0f%% PB Conf(CALC):%.0f%% MTF:%.0f%% MACD:%.0f%% RSI:%.0f%% ADX:%.0f%% VOL:%.0f%%",
                          analysis.componentResult.pb.score,
                          analysis.componentResult.pb.confidence,
                          analysis.componentResult.mtf.confidence,
                          analysis.componentResult.macd.confidence,
                          analysis.componentResult.rsi.confidence,
                          analysis.componentResult.adx.confidence,
                          analysis.componentResult.vol.confidence);
   
   summary += " | ";
   summary += StringFormat("Active: %d/6 | Agree:%d Disagree:%d Neutral:%d",
                          analysis.activeComponents,
                          analysis.componentResult.agreeingComponents,
                          analysis.componentResult.disagreeingComponents,
                          analysis.componentResult.neutralComponents);
   
   summary += StringFormat(" | Formula: (%.2f-%.2f)/%.2f=%.1f%%",
                          analysis.componentResult.rawAgreeTotal,
                          analysis.componentResult.rawDisagreeTotal,
                          analysis.componentResult.activeWeight,
                          analysis.componentResult.confidence);
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Quick Status                                                 |
//+------------------------------------------------------------------+
string CComponentManager::GetQuickStatus(SMarketAnalysis &analysis)
{
   double threshold = analysis.usedThreshold;
   string thresholdStr = (threshold > 0) ? DoubleToString(threshold, 0) : "?";
   string dir = analysis.overallSentiment;
   if(dir == "BULLISH") dir = "BUY";
   else if(dir == "BEARISH") dir = "SELL";
   else dir = "HOLD";
   
   return StringFormat("[%s] %s | Conf(CALC):%.0f%% | Score(DISPLAY):%.0f%% | Threshold:%s%% | Active:%d/6 | Agree:%d Disagree:%d | Net:%.2f",
                       analysis.overallSentiment, analysis.tradeAction,
                       analysis.overallConfidence, 
                       analysis.overallScore,
                       thresholdStr,
                       analysis.activeComponents,
                       analysis.componentResult.agreeingComponents,
                       analysis.componentResult.disagreeingComponents,
                       analysis.componentResult.rawConfidenceTotal);
}

//+------------------------------------------------------------------+
//| Get Summary String                                               |
//+------------------------------------------------------------------+
string CComponentManager::GetSummaryString(SMarketAnalysis &analysis)
{
   double threshold = analysis.usedThreshold;
   string thresholdStr = (threshold > 0) ? DoubleToString(threshold, 0) : "?";
   
   return StringFormat(
      "[%s] %s | Conf(CALC): %.1f%% | Score(DISPLAY): %.1f%% | Threshold: %s%% | PB Score:%.0f%% PB Conf:%.0f%% | MTF:%.0f%% MACD:%.0f%% RSI:%.0f%% ADX:%.0f%% VOL:%.0f%% | Agree:%d Disagree:%d | (%.2f-%.2f)/%.2f=%.1f%%",
      analysis.overallSentiment, analysis.tradeAction,
      analysis.overallConfidence, 
      analysis.overallScore,
      thresholdStr,
      analysis.componentResult.pb.score,
      analysis.componentResult.pb.confidence,
      analysis.componentResult.mtf.confidence,
      analysis.componentResult.macd.confidence,
      analysis.componentResult.rsi.confidence,
      analysis.componentResult.adx.confidence,
      analysis.componentResult.vol.confidence,
      analysis.componentResult.agreeingComponents,
      analysis.componentResult.disagreeingComponents,
      analysis.componentResult.rawAgreeTotal,
      analysis.componentResult.rawDisagreeTotal,
      analysis.componentResult.activeWeight,
      analysis.componentResult.confidence
   );
}

//+------------------------------------------------------------------+
//| Print Analysis                                                   |
//+------------------------------------------------------------------+
void CComponentManager::PrintAnalysis(SMarketAnalysis &analysis)
{
   LOG_INFO("========== MARKET ANALYSIS ==========", g_debugComponentManager);
   LOG_INFO("Time: " + TimeToString(analysis.timestamp), g_debugComponentManager);
   LOG_INFO("Symbol: " + m_symbol, g_debugComponentManager);
   LOG_INFO("Timeframe: " + EnumToString(m_timeframe), g_debugComponentManager);
   LOG_INFO("Cache Status: " + (m_cacheValid ? "VALID (age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)" : "INVALID"), g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("TREND DIRECTION: " + analysis.overallSentiment, g_debugComponentManager);
   LOG_INFO("TRADE ACTION: " + analysis.tradeAction, g_debugComponentManager);
   
   double threshold = analysis.usedThreshold;
   string thresholdStr = (threshold > 0) ? DoubleToString(threshold, 0) : "?";
   LOG_INFO("USED THRESHOLD: " + thresholdStr + "%", g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("📊 CONFIDENCE (for CALCULATIONS): " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("📊 SCORE (for DISPLAY ONLY): " + DoubleToString(analysis.overallScore, 1) + "%", g_debugComponentManager);
   LOG_INFO("📊 PB CONFIDENCE (for CALCULATIONS): " + DoubleToString(analysis.pbConfidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("📊 PB SCORE (for DISPLAY ONLY): " + DoubleToString(analysis.pbScore, 1) + "%", g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("📊 MATHEMATICAL BREAKDOWN:", g_debugComponentManager);
   LOG_INFO("   Agree Total: " + DoubleToString(analysis.componentResult.rawAgreeTotal, 2), g_debugComponentManager);
   LOG_INFO("   Disagree Total: " + DoubleToString(analysis.componentResult.rawDisagreeTotal, 2), g_debugComponentManager);
   LOG_INFO("   Net Total: " + DoubleToString(analysis.componentResult.rawConfidenceTotal, 2), g_debugComponentManager);
   LOG_INFO("   Active Weight: " + DoubleToString(analysis.componentResult.activeWeight, 2), g_debugComponentManager);
   LOG_INFO("   Formula: (" + DoubleToString(analysis.componentResult.rawAgreeTotal, 2) +
             " - " + DoubleToString(analysis.componentResult.rawDisagreeTotal, 2) +
             ") / " + DoubleToString(analysis.componentResult.activeWeight, 2) +
             " = " + DoubleToString(analysis.componentResult.confidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("📊 COMPONENT ALIGNMENT:", g_debugComponentManager);
   LOG_INFO("   AGREE: " + IntegerToString(analysis.componentResult.agreeingComponents), g_debugComponentManager);
   LOG_INFO("   DISAGREE: " + IntegerToString(analysis.componentResult.disagreeingComponents), g_debugComponentManager);
   LOG_INFO("   NEUTRAL: " + IntegerToString(analysis.componentResult.neutralComponents), g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("WEIGHTS: PB=" + DoubleToString(m_pullbackWeight * 100, 0) +
             "%, MTF=" + DoubleToString(m_mtfWeight * 100, 0) +
             "%, MACD=" + DoubleToString(m_macdWeight * 100, 0) +
             "%, RSI=" + DoubleToString(m_rsiWeight * 100, 0) +
             "%, VOL=" + DoubleToString(m_volWeight * 100, 0) +
             "%, ADX=" + DoubleToString(m_adxWeight * 100, 0) + "%", g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("COMPONENT STATUS:", g_debugComponentManager);
   LOG_INFO("  ▲▼ Name    Score(DISPLAY)%  Conf(CALC)%   Raw   Wgt%  Alignment", g_debugComponentManager);
   LOG_INFO("  ────────────────────────────────────────────────────────────────", g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.pb.direction,
         analysis.componentResult.pb.name,
         analysis.componentResult.pb.score,
         analysis.componentResult.pb.confidence,
         analysis.componentResult.pb.rawScore,
         analysis.componentResult.pb.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.pb.alignment)), g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.mtf.direction,
         analysis.componentResult.mtf.name,
         analysis.componentResult.mtf.score,
         analysis.componentResult.mtf.confidence,
         analysis.componentResult.mtf.rawScore,
         analysis.componentResult.mtf.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.mtf.alignment)), g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.macd.direction,
         analysis.componentResult.macd.name,
         analysis.componentResult.macd.score,
         analysis.componentResult.macd.confidence,
         analysis.componentResult.macd.rawScore,
         analysis.componentResult.macd.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.macd.alignment)), g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.adx.direction,
         analysis.componentResult.adx.name,
         analysis.componentResult.adx.score,
         analysis.componentResult.adx.confidence,
         analysis.componentResult.adx.rawScore,
         analysis.componentResult.adx.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.adx.alignment)), g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.rsi.direction,
         analysis.componentResult.rsi.name,
         analysis.componentResult.rsi.score,
         analysis.componentResult.rsi.confidence,
         analysis.componentResult.rsi.rawScore,
         analysis.componentResult.rsi.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.rsi.alignment)), g_debugComponentManager);
   
   LOG(StringFormat("  %s %-6s %13.0f%% %11.0f%% %6.1f %4.0f%%  %s",
         analysis.componentResult.vol.direction,
         analysis.componentResult.vol.name,
         analysis.componentResult.vol.score,
         analysis.componentResult.vol.confidence,
         analysis.componentResult.vol.rawScore,
         analysis.componentResult.vol.weight * 100,
         GetComponentAlignmentString(analysis.componentResult.vol.alignment)), g_debugComponentManager);
   
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("AGREEMENT-WEIGHTED AVERAGE:", g_debugComponentManager);
   LOG_INFO("  Confidence (for CALCULATIONS): " + DoubleToString(analysis.componentResult.confidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("  Score (for DISPLAY ONLY): " + DoubleToString(analysis.componentResult.overallScore, 1) + "%", g_debugComponentManager);
   LOG_INFO("  Active Components: " + IntegerToString(analysis.componentResult.activeComponents) + "/6", g_debugComponentManager);
   LOG_INFO("  Agreeing Components: " + IntegerToString(analysis.componentResult.agreeingComponents), g_debugComponentManager);
   LOG_INFO("  Disagreeing Components: " + IntegerToString(analysis.componentResult.disagreeingComponents), g_debugComponentManager);
   LOG_INFO("  Neutral Components: " + IntegerToString(analysis.componentResult.neutralComponents), g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("FINAL RESULT:", g_debugComponentManager);
   LOG_INFO("  Direction: " + analysis.overallSentiment, g_debugComponentManager);
   LOG_INFO("  Action: " + analysis.tradeAction, g_debugComponentManager);
   LOG_INFO("  Confidence (CALC): " + DoubleToString(analysis.overallConfidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("  Score (DISPLAY): " + DoubleToString(analysis.overallScore, 1) + "%", g_debugComponentManager);
   LOG_INFO("  PB Confidence (CALC): " + DoubleToString(analysis.pbConfidence, 1) + "%", g_debugComponentManager);
   LOG_INFO("  PB Score (DISPLAY): " + DoubleToString(analysis.pbScore, 1) + "%", g_debugComponentManager);
   LOG_INFO("  Threshold Used: " + thresholdStr + "%", g_debugComponentManager);
   LOG_INFO("  Active Components: " + IntegerToString(analysis.activeComponents) + "/6", g_debugComponentManager);
   LOG_INFO("  Best Component: " + analysis.bestComponent + " (" + DoubleToString(analysis.bestScore, 1) + "%)", g_debugComponentManager);
   LOG_INFO("--------------------------------------", g_debugComponentManager);
   LOG_INFO("  " + analysis.summary, g_debugComponentManager);
   LOG_INFO("======================================", g_debugComponentManager);
}