//+------------------------------------------------------------------+
//|                        MtfModule.mqh                             |
//|                    MTF Calculation Module                        |
//|                    v2.1 - WITH CACHING                          |
//|                    Returns: Direction, Confidence, Desc,         |
//|                    Narrative, and Full MTF Details              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.1"

#include "../Utils/Logger.mqh"

// ============================================================
// MTF MODULE INDEPENDENT TOGGLE - SINGLE MAIN SWITCH
// ============================================================
bool g_debugMtfModule = false;  // Set to true to enable all MTF module debug logs

//+------------------------------------------------------------------+
//| MTF Direction Result Structure                                   |
//+------------------------------------------------------------------+
struct SMTFDirectionResult
{
   // --- CORE COMPONENT MANAGER FIELDS ---
   string   direction;        // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;       // 0-100 (ENHANCED - accounts for consistency)
   string   description;      // Brief description of market condition
   string   narrative;        // Detailed narrative explaining the situation
   
   // --- PERCENTAGES FOR WEIGHTING ---
   double   bullPercentage;   // 0-100
   double   bearPercentage;   // 0-100
   
   // --- SCORES ---
   int      totalScore;       // Total MTF score (0-45)
   double   alignmentScore;   // Alignment score (0-100)
   int      m5Score;          // M5 timeframe score (0-20)
   int      m15Score;         // M15 timeframe score (0-11)
   int      h1Score;          // H1 timeframe score (0-8)
   double   consistency;      // How consistent across timeframes (0-100)
   
   // --- DESCRIPTIONS ---
   string   m5Description;    // M5 timeframe description
   string   m15Description;   // M15 timeframe description
   string   h1Description;    // H1 timeframe description
   
   // --- VALIDATION ---
   bool     isValid;
   string   errorMessage;
};

//+------------------------------------------------------------------+
//| MTF Summary Structure                                            |
//+------------------------------------------------------------------+
struct SMTFSummary
{
   // --- CORE ---
   string   direction;          // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;         // 0-100
   string   shortDescription;   // Brief description (max 50 chars)
   string   fullDescription;    // Full description
   
   // --- PERCENTAGES ---
   double   bullPercentage;     // 0-100
   double   bearPercentage;     // 0-100
   
   // --- SCORES ---
   int      totalScore;         // 0-45
   string   scoreDisplay;       // "35/45"
   string   timeframeDetails;   // "M5: 18/20 | M15: 9/11 | H1: 8/8"
   
   // --- VALIDATION ---
   bool     isValid;
};

//+------------------------------------------------------------------+
//| MTF Module Class                                                |
//+------------------------------------------------------------------+
class CMtfModule
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool     m_initialized;
   string   m_lastError;
   int      m_cacheTimeout;      // Cache timeout in seconds (default: 10)
   
   // ──────────────────────────────────────────────────────────────
   // CACHE
   // ──────────────────────────────────────────────────────────────
   bool     m_cacheValid;
   datetime m_cacheTime;
   int      m_cachedTradeDirection;
   double   m_cachedPrice;
   int      m_cachedM5Score;
   int      m_cachedM15Score;
   int      m_cachedH1Score;
   string   m_cachedM5Desc;
   string   m_cachedM15Desc;
   string   m_cachedH1Desc;
   
   // ──────────────────────────────────────────────────────────────
   // M5 EMA Handles
   // ──────────────────────────────────────────────────────────────
   int      m_maM5_21;
   int      m_maM5_50;
   int      m_maM5_60;
   int      m_maM5_120;
   
   // M15 EMA Handles
   int      m_maM15_21;
   int      m_maM15_50;
   int      m_maM15_60;
   int      m_maM15_120;
   
   // H1 EMA Handles
   int      m_maH1_21;
   int      m_maH1_50;
   int      m_maH1_60;
   int      m_maH1_120;
   
   // ──────────────────────────────────────────────────────────────
   // CURRENT SCORES
   // ──────────────────────────────────────────────────────────────
   int      m_m5Score;
   int      m_m15Score;
   int      m_h1Score;
   string   m_m5Desc;
   string   m_m15Desc;
   string   m_h1Desc;
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   double   GetMAValue(int handle);
   void     InvalidateCache();
   bool     IsCacheValid(int tradeDirection, double currentPrice);
   void     UpdateCache(int tradeDirection, double currentPrice);
   
   // Enhanced confidence calculation
   double   CalculateConfidenceInternal(int totalScore, int m5Score, int m15Score, int h1Score);
   double   CalculateBullPercentageInternal(int tradeDirection, int totalScore);
   
public:
   // Constructor / Destructor
   CMtfModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   ~CMtfModule();
   
   // Initialization
   bool Initialize();
   void Deinitialize();
   bool IsInitialized() const;
   string GetLastError() const { return m_lastError; }
   
   // Configuration
   void SetCacheTimeout(int seconds);
   
   // Core MTF Calculation
   int CalculateMTFScore(int tradeDirection, double currentPrice);
   void GetMTFScores(int &m5Score, int &m15Score, int &h1Score, 
                     string &m5Desc, string &m15Desc, string &h1Desc);
   int GetTotalScore();
   
   // COMPONENT MANAGER METHODS - Returns ALL needed info
   SMTFDirectionResult GetDirectionResult(int tradeDirection, double currentPrice);
   
   // Individual getters
   string GetDirection(int tradeDirection, int totalScore);
   double GetBullPercentage(int tradeDirection, int totalScore);
   double GetBearPercentage(int tradeDirection, int totalScore);
   double GetConfidence(int tradeDirection, double currentPrice);
   string GetDescription(int totalScore, string direction, double bullPct, double bearPct);
   string GetNarrative(string direction, int totalScore, double bullPct, double bearPct, double confidence);
   
   // Summary methods
   SMTFSummary GetMTFSummary(int tradeDirection, double currentPrice);
   string GetMTFSummaryString(int tradeDirection, double currentPrice);
   
   // Utility
   static void SetGlobalDebug(bool enable) { g_debugMtfModule = enable; }
   static bool GetGlobalDebug() { return g_debugMtfModule; }
   void Refresh();
   void PrintStatus(int tradeDirection, double currentPrice);
   void DebugMTF(int tradeDirection, double currentPrice);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CMtfModule::CMtfModule(string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("Constructor called", g_debugMtfModule);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_lastError = "";
   m_initialized = false;
   m_cacheTimeout = 10;
   
   // Initialize cache
   InvalidateCache();
   
   // Initialize handles to INVALID
   m_maM5_21 = INVALID_HANDLE;
   m_maM5_50 = INVALID_HANDLE;
   m_maM5_60 = INVALID_HANDLE;
   m_maM5_120 = INVALID_HANDLE;
   m_maM15_21 = INVALID_HANDLE;
   m_maM15_50 = INVALID_HANDLE;
   m_maM15_60 = INVALID_HANDLE;
   m_maM15_120 = INVALID_HANDLE;
   m_maH1_21 = INVALID_HANDLE;
   m_maH1_50 = INVALID_HANDLE;
   m_maH1_60 = INVALID_HANDLE;
   m_maH1_120 = INVALID_HANDLE;
   
   m_m5Score = 0;
   m_m15Score = 0;
   m_h1Score = 0;
   m_m5Desc = "";
   m_m15Desc = "";
   m_h1Desc = "";
   
   LOG_INFO("MTF Module created - Symbol: " + m_symbol + ", Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s", g_debugMtfModule);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CMtfModule::~CMtfModule()
{
   LOG_DEBUG("Destructor called", g_debugMtfModule);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Invalidate Cache                                                |
//+------------------------------------------------------------------+
void CMtfModule::InvalidateCache()
{
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cachedTradeDirection = 0;
   m_cachedPrice = 0;
   m_cachedM5Score = 0;
   m_cachedM15Score = 0;
   m_cachedH1Score = 0;
   m_cachedM5Desc = "";
   m_cachedM15Desc = "";
   m_cachedH1Desc = "";
}

//+------------------------------------------------------------------+
//| Is Cache Valid                                                  |
//+------------------------------------------------------------------+
bool CMtfModule::IsCacheValid(int tradeDirection, double currentPrice)
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
void CMtfModule::UpdateCache(int tradeDirection, double currentPrice)
{
   m_cachedTradeDirection = tradeDirection;
   m_cachedPrice = currentPrice;
   m_cachedM5Score = m_m5Score;
   m_cachedM15Score = m_m15Score;
   m_cachedH1Score = m_h1Score;
   m_cachedM5Desc = m_m5Desc;
   m_cachedM15Desc = m_m15Desc;
   m_cachedH1Desc = m_h1Desc;
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
}

//+------------------------------------------------------------------+
//| Set Cache Timeout                                               |
//+------------------------------------------------------------------+
void CMtfModule::SetCacheTimeout(int seconds)
{
   if(seconds > 0)
   {
      m_cacheTimeout = seconds;
      LOG_INFO("Cache timeout set to " + IntegerToString(seconds) + " seconds", g_debugMtfModule);
   }
}

//+------------------------------------------------------------------+
//| Refresh - Force cache invalidation                              |
//+------------------------------------------------------------------+
void CMtfModule::Refresh()
{
   LOG_DEBUG("Refreshing MTF data (cache invalidated)", g_debugMtfModule);
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CMtfModule::Initialize()
{
   LOG_INFO("=== INITIALIZATION START ===", g_debugMtfModule);
   
   InvalidateCache();
   
   // M5 EMAs
   LOG_DEBUG("Creating M5 EMAs...", g_debugMtfModule);
   m_maM5_21 = iMA(m_symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_maM5_50 = iMA(m_symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_maM5_60 = iMA(m_symbol, PERIOD_M5, 60, 0, MODE_EMA, PRICE_CLOSE);
   m_maM5_120 = iMA(m_symbol, PERIOD_M5, 120, 0, MODE_EMA, PRICE_CLOSE);
   
   // M15 EMAs
   LOG_DEBUG("Creating M15 EMAs...", g_debugMtfModule);
   m_maM15_21 = iMA(m_symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_maM15_50 = iMA(m_symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_maM15_60 = iMA(m_symbol, PERIOD_M15, 60, 0, MODE_EMA, PRICE_CLOSE);
   m_maM15_120 = iMA(m_symbol, PERIOD_M15, 120, 0, MODE_EMA, PRICE_CLOSE);
   
   // H1 EMAs
   LOG_DEBUG("Creating H1 EMAs...", g_debugMtfModule);
   m_maH1_21 = iMA(m_symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_maH1_50 = iMA(m_symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_maH1_60 = iMA(m_symbol, PERIOD_H1, 60, 0, MODE_EMA, PRICE_CLOSE);
   m_maH1_120 = iMA(m_symbol, PERIOD_H1, 120, 0, MODE_EMA, PRICE_CLOSE);
   
   // Verify handles
   if(m_maM5_21 == INVALID_HANDLE || m_maM5_50 == INVALID_HANDLE ||
      m_maM5_60 == INVALID_HANDLE || m_maM5_120 == INVALID_HANDLE ||
      m_maM15_21 == INVALID_HANDLE || m_maM15_50 == INVALID_HANDLE ||
      m_maM15_60 == INVALID_HANDLE || m_maM15_120 == INVALID_HANDLE ||
      m_maH1_21 == INVALID_HANDLE || m_maH1_50 == INVALID_HANDLE ||
      m_maH1_60 == INVALID_HANDLE || m_maH1_120 == INVALID_HANDLE)
   {
      m_lastError = "Failed to create one or more EMA handles";
      LOG(m_lastError, true);
      m_initialized = false;
      return false;
   }
   
   m_initialized = true;
   LOG_INFO("MTF Module initialized successfully", g_debugMtfModule);
   LOG_INFO("=== END INITIALIZATION ===", g_debugMtfModule);
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CMtfModule::Deinitialize()
{
   LOG_DEBUG("Deinitializing...", g_debugMtfModule);
   
   InvalidateCache();
   
   // Release M5 handles
   if(m_maM5_21 != INVALID_HANDLE) { IndicatorRelease(m_maM5_21); m_maM5_21 = INVALID_HANDLE; }
   if(m_maM5_50 != INVALID_HANDLE) { IndicatorRelease(m_maM5_50); m_maM5_50 = INVALID_HANDLE; }
   if(m_maM5_60 != INVALID_HANDLE) { IndicatorRelease(m_maM5_60); m_maM5_60 = INVALID_HANDLE; }
   if(m_maM5_120 != INVALID_HANDLE) { IndicatorRelease(m_maM5_120); m_maM5_120 = INVALID_HANDLE; }
   
   // Release M15 handles
   if(m_maM15_21 != INVALID_HANDLE) { IndicatorRelease(m_maM15_21); m_maM15_21 = INVALID_HANDLE; }
   if(m_maM15_50 != INVALID_HANDLE) { IndicatorRelease(m_maM15_50); m_maM15_50 = INVALID_HANDLE; }
   if(m_maM15_60 != INVALID_HANDLE) { IndicatorRelease(m_maM15_60); m_maM15_60 = INVALID_HANDLE; }
   if(m_maM15_120 != INVALID_HANDLE) { IndicatorRelease(m_maM15_120); m_maM15_120 = INVALID_HANDLE; }
   
   // Release H1 handles
   if(m_maH1_21 != INVALID_HANDLE) { IndicatorRelease(m_maH1_21); m_maH1_21 = INVALID_HANDLE; }
   if(m_maH1_50 != INVALID_HANDLE) { IndicatorRelease(m_maH1_50); m_maH1_50 = INVALID_HANDLE; }
   if(m_maH1_60 != INVALID_HANDLE) { IndicatorRelease(m_maH1_60); m_maH1_60 = INVALID_HANDLE; }
   if(m_maH1_120 != INVALID_HANDLE) { IndicatorRelease(m_maH1_120); m_maH1_120 = INVALID_HANDLE; }
   
   m_initialized = false;
   LOG_DEBUG("Deinitialization complete", g_debugMtfModule);
}

//+------------------------------------------------------------------+
//| Is Initialized                                                  |
//+------------------------------------------------------------------+
bool CMtfModule::IsInitialized() const
{
   return (m_maM5_21 != INVALID_HANDLE && m_maM5_50 != INVALID_HANDLE &&
           m_maM5_60 != INVALID_HANDLE && m_maM5_120 != INVALID_HANDLE &&
           m_maM15_21 != INVALID_HANDLE && m_maM15_50 != INVALID_HANDLE &&
           m_maM15_60 != INVALID_HANDLE && m_maM15_120 != INVALID_HANDLE &&
           m_maH1_21 != INVALID_HANDLE && m_maH1_50 != INVALID_HANDLE &&
           m_maH1_60 != INVALID_HANDLE && m_maH1_120 != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Get MA Value                                                    |
//+------------------------------------------------------------------+
double CMtfModule::GetMAValue(int handle)
{
   if(handle == INVALID_HANDLE) return 0;
   double buffer[1];
   if(CopyBuffer(handle, 0, 0, 1, buffer) < 1) return 0;
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Calculate MTF Score - WITH CACHING                              |
//+------------------------------------------------------------------+
int CMtfModule::CalculateMTFScore(int tradeDirection, double currentPrice)
{
   LOG_DEBUG("Calculating MTF Score...", g_debugMtfModule);
   
   // Check cache first
   if(IsCacheValid(tradeDirection, currentPrice))
   {
      LOG_DEBUG("  Using cached scores", g_debugMtfModule);
      m_m5Score = m_cachedM5Score;
      m_m15Score = m_cachedM15Score;
      m_h1Score = m_cachedH1Score;
      m_m5Desc = m_cachedM5Desc;
      m_m15Desc = m_cachedM15Desc;
      m_h1Desc = m_cachedH1Desc;
      return m_m5Score + m_m15Score + m_h1Score;
   }
   
   LOG_DEBUG("  Cache invalid, recalculating...", g_debugMtfModule);
   
   // Get MA values
   double m5_ma21 = GetMAValue(m_maM5_21);
   double m5_ma50 = GetMAValue(m_maM5_50);
   double m5_ma60 = GetMAValue(m_maM5_60);
   double m5_ma120 = GetMAValue(m_maM5_120);
   
   double m15_ma21 = GetMAValue(m_maM15_21);
   double m15_ma50 = GetMAValue(m_maM15_50);
   double m15_ma60 = GetMAValue(m_maM15_60);
   double m15_ma120 = GetMAValue(m_maM15_120);
   
   double h1_ma21 = GetMAValue(m_maH1_21);
   double h1_ma50 = GetMAValue(m_maH1_50);
   double h1_ma60 = GetMAValue(m_maH1_60);
   double h1_ma120 = GetMAValue(m_maH1_120);
   
   string dir = (tradeDirection == 1) ? "LONG" : (tradeDirection == -1) ? "SHORT" : "NEUTRAL";
   LOG_DEBUG("  Trade Direction: " + dir + ", Price: " + DoubleToString(currentPrice, 2), g_debugMtfModule);
   
   // ============================================================
   // M5 Calculation (20 points max)
   // ============================================================
   int m5Score = 0;
   m_m5Desc = "M5: ";
   
   // Check 1: MA21 vs MA50 (8 points)
   bool m5MA21AboveMA50 = (m5_ma21 > m5_ma50);
   bool m5MA21BelowMA50 = (m5_ma21 < m5_ma50);
   
   if((tradeDirection == 1 && m5MA21AboveMA50) ||
      (tradeDirection == -1 && m5MA21BelowMA50))
   {
      m5Score += 8;
      m_m5Desc += "MA21>MA50 ✓";
   }
   else
   {
      m_m5Desc += "MA21>MA50 ✗";
   }
   
   // Check 2: MA60 vs MA120 (6 points)
   bool m5MA60AboveMA120 = (m5_ma60 > m5_ma120);
   bool m5MA60BelowMA120 = (m5_ma60 < m5_ma120);
   
   if((tradeDirection == 1 && m5MA60AboveMA120) ||
      (tradeDirection == -1 && m5MA60BelowMA120))
   {
      m5Score += 6;
      m_m5Desc += " | MA60>MA120 ✓";
   }
   else
   {
      m_m5Desc += " | MA60>MA120 ✗";
   }
   
   // Check 3: Price vs MA120 (6 points)
   if((tradeDirection == 1 && currentPrice > m5_ma120) ||
      (tradeDirection == -1 && currentPrice < m5_ma120))
   {
      m5Score += 6;
      m_m5Desc += " | Price>MA120 ✓";
   }
   else
   {
      m_m5Desc += " | Price>MA120 ✗";
   }
   
   m5Score = MathMin(20, m5Score);
   m_m5Desc = "M5: " + IntegerToString(m5Score) + "/20 - " + m_m5Desc;
   
   // ============================================================
   // M15 Calculation (11 points max)
   // ============================================================
   int m15Score = 0;
   m_m15Desc = "M15: ";
   
   // Check 1: MA21 vs MA50 (6 points)
   bool m15MA21AboveMA50 = (m15_ma21 > m15_ma50);
   bool m15MA21BelowMA50 = (m15_ma21 < m15_ma50);
   
   if((tradeDirection == 1 && m15MA21AboveMA50) ||
      (tradeDirection == -1 && m15MA21BelowMA50))
   {
      m15Score += 6;
      m_m15Desc += "MA21>MA50 ✓";
   }
   else
   {
      m_m15Desc += "MA21>MA50 ✗";
   }
   
   // Check 2: MA60 vs MA120 (5 points)
   bool m15MA60AboveMA120 = (m15_ma60 > m15_ma120);
   bool m15MA60BelowMA120 = (m15_ma60 < m15_ma120);
   
   if((tradeDirection == 1 && m15MA60AboveMA120) ||
      (tradeDirection == -1 && m15MA60BelowMA120))
   {
      m15Score += 5;
      m_m15Desc += " | MA60>MA120 ✓";
   }
   else
   {
      m_m15Desc += " | MA60>MA120 ✗";
   }
   
   m15Score = MathMin(11, m15Score);
   m_m15Desc = "M15: " + IntegerToString(m15Score) + "/11 - " + m_m15Desc;
   
   // ============================================================
   // H1 Calculation (8 points max)
   // ============================================================
   int h1Score = 0;
   m_h1Desc = "H1: ";
   
   // Check 1: MA21 vs MA50 (4 points)
   bool h1MA21AboveMA50 = (h1_ma21 > h1_ma50);
   bool h1MA21BelowMA50 = (h1_ma21 < h1_ma50);
   
   if((tradeDirection == 1 && h1MA21AboveMA50) ||
      (tradeDirection == -1 && h1MA21BelowMA50))
   {
      h1Score += 4;
      m_h1Desc += "MA21>MA50 ✓";
   }
   else
   {
      m_h1Desc += "MA21>MA50 ✗";
   }
   
   // Check 2: MA60 vs MA120 (4 points)
   bool h1MA60AboveMA120 = (h1_ma60 > h1_ma120);
   bool h1MA60BelowMA120 = (h1_ma60 < h1_ma120);
   
   if((tradeDirection == 1 && h1MA60AboveMA120) ||
      (tradeDirection == -1 && h1MA60BelowMA120))
   {
      h1Score += 4;
      m_h1Desc += " | MA60>MA120 ✓";
   }
   else
   {
      m_h1Desc += " | MA60>MA120 ✗";
   }
   
   h1Score = MathMin(8, h1Score);
   m_h1Desc = "H1: " + IntegerToString(h1Score) + "/8 - " + m_h1Desc;
   
   // Store scores
   m_m5Score = m5Score;
   m_m15Score = m15Score;
   m_h1Score = h1Score;
   
   int totalScore = m5Score + m15Score + h1Score;
   
   // Update cache
   UpdateCache(tradeDirection, currentPrice);
   
   LOG_DEBUG("  Scores: M5=" + IntegerToString(m5Score) + "/20, M15=" + IntegerToString(m15Score) + "/11, H1=" + IntegerToString(h1Score) + "/8 → Total=" + IntegerToString(totalScore) + "/45", g_debugMtfModule);
   
   return MathMax(0, MathMin(45, totalScore));
}

//+------------------------------------------------------------------+
//| Get MTF Scores                                                  |
//+------------------------------------------------------------------+
void CMtfModule::GetMTFScores(int &m5Score, int &m15Score, int &h1Score, 
                              string &m5Desc, string &m15Desc, string &h1Desc)
{
   m5Score = m_m5Score;
   m15Score = m_m15Score;
   h1Score = m_h1Score;
   m5Desc = m_m5Desc;
   m15Desc = m_m15Desc;
   h1Desc = m_h1Desc;
}

//+------------------------------------------------------------------+
//| Get Total Score                                                 |
//+------------------------------------------------------------------+
int CMtfModule::GetTotalScore()
{
   return m_m5Score + m_m15Score + m_h1Score;
}

//+------------------------------------------------------------------+
//| Calculate Bull Percentage                                       |
//+------------------------------------------------------------------+
double CMtfModule::CalculateBullPercentageInternal(int tradeDirection, int totalScore)
{
   double normalized = (double)totalScore / 45.0;
   
   if(tradeDirection == 1)
   {
      return MathMin(100.0, normalized * 100.0);
   }
   else if(tradeDirection == -1)
   {
      return MathMax(0.0, 100.0 - (normalized * 100.0));
   }
   else
   {
      return 50.0;
   }
}

//+------------------------------------------------------------------+
//| Calculate Confidence - ENHANCED                                 |
//+------------------------------------------------------------------+
double CMtfModule::CalculateConfidenceInternal(int totalScore, int m5Score, int m15Score, int h1Score)
{
   LOG_DEBUG("Calculating enhanced confidence...", g_debugMtfModule);
   
   // 1. Overall alignment (0-100)
   double overallScore = (double)totalScore / 45.0 * 100.0;
   LOG_DEBUG("  Overall Score: " + DoubleToString(overallScore, 1) + "%", g_debugMtfModule);
   
   // 2. Consistency across timeframes (0-100)
   double consistency = 0;
   int maxScore = MathMax(m5Score, MathMax(m15Score, h1Score));
   if(maxScore > 0)
   {
      double avgScore = (m5Score + m15Score + h1Score) / 3.0;
      consistency = (avgScore / maxScore) * 100.0;
      LOG_DEBUG("  Consistency: " + DoubleToString(consistency, 1) + "%", g_debugMtfModule);
   }
   else
   {
      LOG_DEBUG("  Consistency: 0% (no scores)", g_debugMtfModule);
   }
   
   // 3. Weighted confidence
   double confidence = (overallScore * 0.6) + (consistency * 0.4);
   LOG_DEBUG("  Base Confidence: " + DoubleToString(confidence, 1) + "%", g_debugMtfModule);
   
   // 4. Bonus if H1 aligns strongly (h1Score >= 6 out of 8)
   if(h1Score >= 6)
   {
      confidence += 10;
      LOG_DEBUG("  H1 Alignment Bonus: +10%", g_debugMtfModule);
   }
   
   // 5. Cap if overall score is too low
   if(totalScore < 10)
   {
      confidence = MathMin(confidence, 25);
      LOG_DEBUG("  Low Score Cap: max 25%", g_debugMtfModule);
   }
   
   // 6. Minimum confidence
   if(totalScore > 0 && confidence < 5)
      confidence = 5;
   
   double result = MathMin(100.0, confidence);
   LOG_DEBUG("  Final Confidence: " + DoubleToString(result, 1) + "%", g_debugMtfModule);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Bull Percentage - Public                                    |
//+------------------------------------------------------------------+
double CMtfModule::GetBullPercentage(int tradeDirection, int totalScore)
{
   return CalculateBullPercentageInternal(tradeDirection, totalScore);
}

//+------------------------------------------------------------------+
//| Get Bear Percentage - Public                                    |
//+------------------------------------------------------------------+
double CMtfModule::GetBearPercentage(int tradeDirection, int totalScore)
{
   double bullPct = CalculateBullPercentageInternal(tradeDirection, totalScore);
   return MathMax(0.0, MathMin(100.0, 100.0 - bullPct));
}

//+------------------------------------------------------------------+
//| Get Confidence - Public                                         |
//+------------------------------------------------------------------+
double CMtfModule::GetConfidence(int tradeDirection, double currentPrice)
{
   int totalScore = CalculateMTFScore(tradeDirection, currentPrice);
   return CalculateConfidenceInternal(totalScore, m_m5Score, m_m15Score, m_h1Score);
}

//+------------------------------------------------------------------+
//| Get Direction                                                   |
//+------------------------------------------------------------------+
string CMtfModule::GetDirection(int tradeDirection, int totalScore)
{
   if(tradeDirection == 1)
   {
      if(totalScore >= 15) return "BULLISH";
      else return "NEUTRAL";
   }
   else if(tradeDirection == -1)
   {
      if(totalScore >= 15) return "BEARISH";
      else return "NEUTRAL";
   }
   else
   {
      return "NEUTRAL";
   }
}

//+------------------------------------------------------------------+
//| Get Description                                                 |
//+------------------------------------------------------------------+
string CMtfModule::GetDescription(int totalScore, string direction, double bullPct, double bearPct)
{
   string strengthDesc;
   if(totalScore >= 35) strengthDesc = "Strong Alignment";
   else if(totalScore >= 25) strengthDesc = "Good Alignment";
   else if(totalScore >= 18) strengthDesc = "Moderate Alignment";
   else if(totalScore >= 10) strengthDesc = "Weak Alignment";
   else strengthDesc = "No Alignment";
   
   string dirDesc = "";
   if(direction == "BULLISH")
   {
      if(bullPct >= 70) dirDesc = "Strong Bullish";
      else if(bullPct >= 55) dirDesc = "Moderate Bullish";
      else dirDesc = "Mild Bullish";
   }
   else if(direction == "BEARISH")
   {
      if(bearPct >= 70) dirDesc = "Strong Bearish";
      else if(bearPct >= 55) dirDesc = "Moderate Bearish";
      else dirDesc = "Mild Bearish";
   }
   else
   {
      dirDesc = "Neutral / Mixed";
   }
   
   string result = strengthDesc;
   result += " - ";
   result += dirDesc;
   result += " (Score: ";
   result += IntegerToString(totalScore);
   result += "/45)";
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Narrative                                                   |
//+------------------------------------------------------------------+
string CMtfModule::GetNarrative(string direction, int totalScore, double bullPct, double bearPct, double confidence)
{
   string narrative = "";
   
   if(direction == "BULLISH")
   {
      if(totalScore >= 35)
      {
         narrative = "Strong bullish alignment across M5, M15, and H1. ";
         narrative += "All major EMAs are stacked bullishly with clear upward momentum. ";
         if(confidence >= 60)
            narrative += "Very high conviction in the bullish trend across all timeframes.";
         else
            narrative += "Some divergence between timeframes suggests caution.";
      }
      else if(totalScore >= 25)
      {
         narrative = "Good bullish alignment across timeframes. ";
         narrative += "M5 and M15 are showing bullish structure with H1 support. ";
         if(confidence >= 50)
            narrative += "Confidence in the move is reasonable with H1 starting to align.";
         else
            narrative += "Mixed signals on H1 suggest potential consolidation.";
      }
      else if(totalScore >= 18)
      {
         narrative = "Moderate bullish bias with some alignment. ";
         narrative += "Higher timeframe (H1) support exists but momentum is building. ";
         narrative += "Watch for additional confirmation on H1.";
      }
      else if(totalScore >= 10)
      {
         narrative = "Weak bullish signals with limited alignment. ";
         narrative += "Some timeframes suggest bullish structure but not consistently. ";
         narrative += "Wait for stronger confirmation before entering.";
      }
      else
      {
         narrative = "No significant bullish alignment detected. ";
         narrative += "Timeframes are conflicting with no clear direction. ";
         narrative += "Market likely range-bound or consolidating.";
      }
   }
   else if(direction == "BEARISH")
   {
      if(totalScore >= 35)
      {
         narrative = "Strong bearish alignment across M5, M15, and H1. ";
         narrative += "All major EMAs are stacked bearishly with clear downward momentum. ";
         if(confidence >= 60)
            narrative += "Very high conviction in the bearish trend across all timeframes.";
         else
            narrative += "Some divergence between timeframes suggests caution.";
      }
      else if(totalScore >= 25)
      {
         narrative = "Good bearish alignment across timeframes. ";
         narrative += "M5 and M15 are showing bearish structure with H1 support. ";
         if(confidence >= 50)
            narrative += "Confidence in the move is reasonable with H1 starting to align.";
         else
            narrative += "Mixed signals on H1 suggest potential consolidation.";
      }
      else if(totalScore >= 18)
      {
         narrative = "Moderate bearish bias with some alignment. ";
         narrative += "Higher timeframe (H1) support exists but momentum is building. ";
         narrative += "Watch for additional confirmation on H1.";
      }
      else if(totalScore >= 10)
      {
         narrative = "Weak bearish signals with limited alignment. ";
         narrative += "Some timeframes suggest bearish structure but not consistently. ";
         narrative += "Wait for stronger confirmation before entering.";
      }
      else
      {
         narrative = "No significant bearish alignment detected. ";
         narrative += "Timeframes are conflicting with no clear direction. ";
         narrative += "Market likely range-bound or consolidating.";
      }
   }
   else
   {
      narrative = "Market shows mixed or neutral signals across timeframes. ";
      narrative += "No strong alignment between M5, M15, and H1. ";
      
      if(totalScore >= 15 && totalScore < 18)
         narrative += "Slight bias exists but not enough for high confidence entry.";
      else
         narrative += "Market is in consolidation phase. Wait for clear breakout direction.";
   }
   
   narrative += " (Bulls: " + DoubleToString(bullPct, 1) + "%, Bears: " + DoubleToString(bearPct, 1) + "%, Confidence: " + DoubleToString(confidence, 1) + "%, Score: " + IntegerToString(totalScore) + "/45)";
   
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Complete Direction Result - ALL IN ONE!                     |
//+------------------------------------------------------------------+
SMTFDirectionResult CMtfModule::GetDirectionResult(int tradeDirection, double currentPrice)
{
   LOG_DEBUG("=== GETTING COMPLETE DIRECTION RESULT ===", g_debugMtfModule);
   
   SMTFDirectionResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.errorMessage = "";
   
   // Calculate scores (uses cache internally)
   int totalScore = CalculateMTFScore(tradeDirection, currentPrice);
   result.totalScore = totalScore;
   result.m5Score = m_m5Score;
   result.m15Score = m_m15Score;
   result.h1Score = m_h1Score;
   result.m5Description = m_m5Desc;
   result.m15Description = m_m15Desc;
   result.h1Description = m_h1Desc;
   
   // Calculate percentages
   result.bullPercentage = CalculateBullPercentageInternal(tradeDirection, totalScore);
   result.bearPercentage = 100.0 - result.bullPercentage;
   
   // Normalize
   double total = result.bullPercentage + result.bearPercentage;
   if(MathAbs(total - 100.0) > 0.01 && total > 0)
   {
      result.bullPercentage = (result.bullPercentage / total) * 100.0;
      result.bearPercentage = (result.bearPercentage / total) * 100.0;
   }
   
   // Calculate enhanced confidence
   result.confidence = CalculateConfidenceInternal(totalScore, m_m5Score, m_m15Score, m_h1Score);
   result.consistency = (m_m5Score > 0 || m_m15Score > 0 || m_h1Score > 0) ? 
                        ((m_m5Score + m_m15Score + m_h1Score) / 3.0 / MathMax(m_m5Score, MathMax(m_m15Score, m_h1Score))) * 100.0 : 0;
   
   // Get direction
   result.direction = GetDirection(tradeDirection, totalScore);
   result.alignmentScore = (double)totalScore / 45.0 * 100.0;
   
   // Get description and narrative
   result.description = GetDescription(totalScore, result.direction, 
                                      result.bullPercentage, result.bearPercentage);
   result.narrative = GetNarrative(result.direction, totalScore, 
                                  result.bullPercentage, result.bearPercentage, 
                                  result.confidence);
   
   result.isValid = true;
   
   // Log results
   LOG_INFO("Direction Result Complete", g_debugMtfModule);
   LOG_INFO("  Direction: " + result.direction, g_debugMtfModule);
   LOG_INFO("  Confidence: " + DoubleToString(result.confidence, 1) + "%", g_debugMtfModule);
   LOG_INFO("  Score: " + IntegerToString(totalScore) + "/45 (Cached)", g_debugMtfModule);
   LOG_INFO("  Description: " + result.description, g_debugMtfModule);
   LOG_DEBUG("=== END DIRECTION RESULT ===", g_debugMtfModule);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get MTF Summary - For Component Manager                         |
//+------------------------------------------------------------------+
SMTFSummary CMtfModule::GetMTFSummary(int tradeDirection, double currentPrice)
{
   LOG_DEBUG("Getting MTF Summary...", g_debugMtfModule);
   
   SMTFSummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   SMTFDirectionResult result = GetDirectionResult(tradeDirection, currentPrice);
   if(!result.isValid)
   {
      LOG("Failed to get MTF summary", true);
      return summary;
   }
   
   summary.direction = result.direction;
   summary.confidence = result.confidence;
   summary.bullPercentage = result.bullPercentage;
   summary.bearPercentage = result.bearPercentage;
   summary.totalScore = result.totalScore;
   summary.scoreDisplay = IntegerToString(result.totalScore) + "/45";
   summary.timeframeDetails = "M5: " + IntegerToString(m_m5Score) + "/20 | M15: " + IntegerToString(m_m15Score) + "/11 | H1: " + IntegerToString(m_h1Score) + "/8";
   
   // Short description
   string shortDesc = "";
   if(result.totalScore >= 35) shortDesc = "Strong " + result.direction + " alignment";
   else if(result.totalScore >= 25) shortDesc = result.direction + " with good alignment";
   else if(result.totalScore >= 18) shortDesc = "Moderate " + result.direction + " bias";
   else if(result.totalScore >= 10) shortDesc = "Weak " + result.direction + " signals";
   else shortDesc = "No clear direction / Conflict";
   
   if(result.confidence >= 60) shortDesc += " (High confidence)";
   else if(result.confidence >= 40) shortDesc += " (Medium confidence)";
   else shortDesc += " (Low confidence)";
   
   summary.shortDescription = shortDesc;
   summary.fullDescription = result.description;
   summary.isValid = true;
   
   LOG_DEBUG("  Summary: " + shortDesc, g_debugMtfModule);
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get MTF Summary String                                           |
//+------------------------------------------------------------------+
string CMtfModule::GetMTFSummaryString(int tradeDirection, double currentPrice)
{
   SMTFSummary summary = GetMTFSummary(tradeDirection, currentPrice);
   if(!summary.isValid)
      return "MTF: N/A";
   
   string directionSymbol = "";
   if(summary.direction == "BULLISH") directionSymbol = "📈";
   else if(summary.direction == "BEARISH") directionSymbol = "📉";
   else directionSymbol = "➡️";
   
   return "MTF: " + directionSymbol + " " + summary.direction + " | Score: " + summary.scoreDisplay + " | Conf: " + DoubleToString(summary.confidence, 0) + "% | " + summary.timeframeDetails;
}

//+------------------------------------------------------------------+
//| Print Status - Full debug output                                |
//+------------------------------------------------------------------+
void CMtfModule::PrintStatus(int tradeDirection, double currentPrice)
{
   string separator = "=== ";
   string indent = "   ";
   
   Print(separator + "MTF MODULE STATUS " + separator);
   Print(indent + "Symbol: " + m_symbol);
   Print(indent + "Last Error: " + m_lastError);
   Print(indent + "Initialized: " + (IsInitialized() ? "YES" : "NO"));
   Print(indent + "Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s");
   Print(indent + "Cache Valid: " + (m_cacheValid ? "YES" : "NO"));
   Print(indent + "Cache Age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s");
   
   SMTFDirectionResult result = GetDirectionResult(tradeDirection, currentPrice);
   if(result.isValid)
   {
      Print(indent + "Direction: " + result.direction);
      Print(indent + "Confidence: " + DoubleToString(result.confidence, 1) + "%");
      Print(indent + "Bull%: " + DoubleToString(result.bullPercentage, 1) + "%");
      Print(indent + "Bear%: " + DoubleToString(result.bearPercentage, 1) + "%");
      Print(indent + "Total Score: " + IntegerToString(result.totalScore) + "/45");
      Print(indent + "Consistency: " + DoubleToString(result.consistency, 1) + "%");
      Print(indent + "M5 Score: " + IntegerToString(result.m5Score) + "/20");
      Print(indent + "M15 Score: " + IntegerToString(result.m15Score) + "/11");
      Print(indent + "H1 Score: " + IntegerToString(result.h1Score) + "/8");
      Print(indent + "Description: " + result.description);
      Print(indent + "Narrative: " + result.narrative);
      Print(indent + "M5: " + result.m5Description);
      Print(indent + "M15: " + result.m15Description);
      Print(indent + "H1: " + result.h1Description);
   }
   else
   {
      Print(indent + "Unable to get MTF values");
      Print(indent + "Error: " + result.errorMessage);
   }
   Print(separator + "END STATUS " + separator);
}

//+------------------------------------------------------------------+
//| Debug MTF - Shows all values for debugging                      |
//+------------------------------------------------------------------+
void CMtfModule::DebugMTF(int tradeDirection, double currentPrice)
{
   LOG_INFO("=== DEBUG MTF ===", g_debugMtfModule);
   
   double m5_ma21 = GetMAValue(m_maM5_21);
   double m5_ma50 = GetMAValue(m_maM5_50);
   double m5_ma60 = GetMAValue(m_maM5_60);
   double m5_ma120 = GetMAValue(m_maM5_120);
   
   double m15_ma21 = GetMAValue(m_maM15_21);
   double m15_ma50 = GetMAValue(m_maM15_50);
   double m15_ma60 = GetMAValue(m_maM15_60);
   double m15_ma120 = GetMAValue(m_maM15_120);
   
   double h1_ma21 = GetMAValue(m_maH1_21);
   double h1_ma50 = GetMAValue(m_maH1_50);
   double h1_ma60 = GetMAValue(m_maH1_60);
   double h1_ma120 = GetMAValue(m_maH1_120);
   
   Print("=== MTF DEBUG (EMA - M5, M15, H1) ===");
   Print("Trade Direction: ", tradeDirection == 1 ? "LONG" : tradeDirection == -1 ? "SHORT" : "NEUTRAL");
   Print("Current Price: ", DoubleToString(currentPrice, _Digits));
   Print("Cache Status: ", m_cacheValid ? "VALID (age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)" : "INVALID");
   Print("");
   
   Print("M5 (Entry TF - 20pts max):");
   Print("  EMA21: ", DoubleToString(m5_ma21, _Digits), " | EMA50: ", DoubleToString(m5_ma50, _Digits));
   Print("  EMA60: ", DoubleToString(m5_ma60, _Digits), " | EMA120: ", DoubleToString(m5_ma120, _Digits));
   Print("");
   
   Print("M15 (Confirmation TF - 11pts max):");
   Print("  EMA21: ", DoubleToString(m15_ma21, _Digits), " | EMA50: ", DoubleToString(m15_ma50, _Digits));
   Print("  EMA60: ", DoubleToString(m15_ma60, _Digits), " | EMA120: ", DoubleToString(m15_ma120, _Digits));
   Print("");
   
   Print("H1 (Context TF - 8pts max):");
   Print("  EMA21: ", DoubleToString(h1_ma21, _Digits), " | EMA50: ", DoubleToString(h1_ma50, _Digits));
   Print("  EMA60: ", DoubleToString(h1_ma60, _Digits), " | EMA120: ", DoubleToString(h1_ma120, _Digits));
   Print("");
   
   int score = CalculateMTFScore(tradeDirection, currentPrice);
   double confidence = GetConfidence(tradeDirection, currentPrice);
   string direction = GetDirection(tradeDirection, score);
   
   Print("Total Score: ", score, "/45");
   Print("Confidence: ", DoubleToString(confidence, 1), "%");
   Print("Direction: ", direction);
   Print("=================");
   
   LOG_INFO("=== DEBUG COMPLETE ===", g_debugMtfModule);
}