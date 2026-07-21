//+------------------------------------------------------------------+
//|                        RsiModule.mqh                             |
//|                    RSI Calculation Module                        |
//|                    v2.1 - WITH CACHING                          |
//|                    Returns: Direction, Confidence, Desc,         |
//|                    Narrative, and Full RSI Info                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.1"

#include "../Utils/Logger.mqh"

// ============================================================
// RSI MODULE INDEPENDENT TOGGLE - SINGLE MAIN SWITCH
// ============================================================
bool g_debugRsiModule = false;  // Set to true to enable all RSI module debug logs

//+------------------------------------------------------------------+
//| RSI Condition Enum                                              |
//+------------------------------------------------------------------+
enum ENUM_RSI_CONDITION
{
   RSI_OVERBOUGHT,
   RSI_OVERSOLD,
   RSI_BULLISH,
   RSI_BEARISH,
   RSI_NEUTRAL
};

//+------------------------------------------------------------------+
//| RSI Direction Result Structure                                  |
//+------------------------------------------------------------------+
struct SRSIDirectionResult
{
   // --- CORE COMPONENT MANAGER FIELDS ---
   string   direction;           // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;          // 0-100 (IMPROVED)
   string   description;         // Brief description
   string   narrative;           // Detailed narrative
   
   // --- PERCENTAGES ---
   double   bullPercentage;      // 0-100
   double   bearPercentage;      // 0-100
   
   // --- RAW RSI VALUES ---
   double   rsiValue;            // Current RSI value (0-100)
   double   rsiScore;            // RSI score based on trend (0-100)
   
   // --- METRICS ---
   string   rsiCondition;        // "OVERBOUGHT", "OVERSOLD", etc.
   ENUM_RSI_CONDITION rsiConditionEnum;
   bool     isOverbought;
   bool     isOversold;
   bool     isExtreme;
   bool     isDiverging;
   double   momentumStrength;
   double   reversalProbability;
   
   // --- VALIDATION ---
   bool     isValid;
   string   errorMessage;
};

//+------------------------------------------------------------------+
//| RSI Summary Structure                                           |
//+------------------------------------------------------------------+
struct SRSISummary
{
   string   direction;
   double   confidence;
   string   shortDescription;
   string   fullDescription;
   double   bullPercentage;
   double   bearPercentage;
   double   rsiValue;
   string   condition;
   bool     isOverbought;
   bool     isOversold;
   bool     isExtreme;
   double   momentumStrength;
   bool     isValid;
};

//+------------------------------------------------------------------+
//| RSI Module Class                                               |
//+------------------------------------------------------------------+
class CRsiModule
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_rsiPeriod;
   int      m_rsiHandle;
   bool     m_initialized;
   string   m_lastError;
   int      m_cacheTimeout;      // Cache timeout in seconds (default: 5)
   
   // ──────────────────────────────────────────────────────────────
   // CACHE
   // ──────────────────────────────────────────────────────────────
   bool     m_cacheValid;
   datetime m_cacheTime;
   double   m_cachedRSI;
   double   m_cachedBullPct;
   double   m_cachedBearPct;
   double   m_cachedMomentum;
   double   m_cachedReversal;
   string   m_cachedDirection;
   ENUM_RSI_CONDITION m_cachedCondition;
   bool     m_cachedDivergence;
   
   // ──────────────────────────────────────────────────────────────
   // CONFIGURABLE THRESHOLDS
   // ──────────────────────────────────────────────────────────────
   double   m_overboughtThreshold;
   double   m_oversoldThreshold;
   double   m_bullishThreshold;
   double   m_bearishThreshold;
   double   m_divergenceLookback;
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   double   GetRSI();
   void     InvalidateCache();
   bool     IsCacheValid();
   void     UpdateCache();
   
   ENUM_RSI_CONDITION GetRSIConditionEnum(double rsi);
   string   GetRSIConditionString(ENUM_RSI_CONDITION condition);
   
   double   CalculateBullPercentage(double rsi);
   double   CalculateBearPercentage(double rsi);
   double   CalculateConfidenceInternal(double rsi, double bullPct, double bearPct);
   double   CalculateMomentumStrength(double rsi);
   double   CalculateReversalProbability(double rsi);
   bool     CheckDivergence();
   string   DetermineDirection(double rsi, double bullPct, double bearPct);
   
   string   GenerateDescription(double rsi, ENUM_RSI_CONDITION condition, double bullPct, double bearPct);
   string   GenerateNarrative(string direction, double rsi, double bullPct, double bearPct, 
                              double confidence, double momentumStrength, double reversalProb);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CRsiModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int period = 14);
   ~CRsiModule();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize();
   void Deinitialize();
   bool IsInitialized() const { return m_initialized; }
   string GetLastError() const { return m_lastError; }
   
   // ──────────────────────────────────────────────────────────────
   // CONFIGURATION
   // ──────────────────────────────────────────────────────────────
   void SetThresholds(double overbought, double oversold, double bullish, double bearish);
   void SetCacheTimeout(int seconds);
   
   // ──────────────────────────────────────────────────────────────
   // DATA ACCESS - Raw Values
   // ──────────────────────────────────────────────────────────────
   double GetRSIValue();
   bool IsOverbought();
   bool IsOversold();
   bool IsExtreme();
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT MANAGER METHODS
   // ──────────────────────────────────────────────────────────────
   string GetDirection();
   string GetDirection(int trend);
   double GetConfidence();
   double GetConfidence(int trend);
   string GetDescription();
   string GetDescription(int trend);
   string GetNarrative();
   string GetNarrative(int trend);
   SRSIDirectionResult GetDirectionResult(int trend = 0);
   SRSISummary GetRSISummary(int trend = 0);
   string GetSummaryString(int trend = 0);
   
   // ──────────────────────────────────────────────────────────────
   // ADDITIONAL METRICS
   // ──────────────────────────────────────────────────────────────
   double GetBullPercentage();
   double GetBearPercentage();
   double GetMomentumStrength();
   double GetReversalProbability();
   double GetRSIScore(int trend = 0);
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY METHODS
   // ──────────────────────────────────────────────────────────────
   static void SetGlobalDebug(bool enable) { g_debugRsiModule = enable; }
   static bool GetGlobalDebug() { return g_debugRsiModule; }
   void Refresh();
   void PrintStatus(int trend = 0);
   void DebugPrintRSI(int trend = 0);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CRsiModule::CRsiModule(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   LOG_DEBUG("Constructor called", g_debugRsiModule);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? PERIOD_H1 : tf;
   m_rsiPeriod = period;
   m_rsiHandle = INVALID_HANDLE;
   m_initialized = false;
   m_lastError = "";
   m_cacheTimeout = 5;
   
   // Default thresholds
   m_overboughtThreshold = 70.0;
   m_oversoldThreshold = 30.0;
   m_bullishThreshold = 55.0;
   m_bearishThreshold = 45.0;
   m_divergenceLookback = 5;
   
   // Initialize cache
   InvalidateCache();
   
   LOG_DEBUG("RSI Module created - Symbol: " + m_symbol + 
             ", Timeframe: " + EnumToString(m_timeframe) + 
             ", Period: " + IntegerToString(period) + 
             ", Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s", g_debugRsiModule);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CRsiModule::~CRsiModule()
{
   LOG_DEBUG("Destructor called", g_debugRsiModule);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Invalidate Cache                                                |
//+------------------------------------------------------------------+
void CRsiModule::InvalidateCache()
{
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cachedRSI = 50;
   m_cachedBullPct = 50;
   m_cachedBearPct = 50;
   m_cachedMomentum = 0;
   m_cachedReversal = 0;
   m_cachedDirection = "NEUTRAL";
   m_cachedCondition = RSI_NEUTRAL;
   m_cachedDivergence = false;
}

//+------------------------------------------------------------------+
//| Is Cache Valid                                                  |
//+------------------------------------------------------------------+
bool CRsiModule::IsCacheValid()
{
   if(!m_cacheValid) return false;
   if((TimeCurrent() - m_cacheTime) > m_cacheTimeout) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Update Cache                                                    |
//+------------------------------------------------------------------+
void CRsiModule::UpdateCache()
{
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
}

//+------------------------------------------------------------------+
//| Set Cache Timeout                                               |
//+------------------------------------------------------------------+
void CRsiModule::SetCacheTimeout(int seconds)
{
   if(seconds > 0)
   {
      m_cacheTimeout = seconds;
      LOG_DEBUG("Cache timeout set to " + IntegerToString(seconds) + " seconds", g_debugRsiModule);
   }
}

//+------------------------------------------------------------------+
//| Refresh - Force cache invalidation                              |
//+------------------------------------------------------------------+
void CRsiModule::Refresh()
{
   LOG_DEBUG("Refreshing RSI data (cache invalidated)", g_debugRsiModule);
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Set Thresholds                                                  |
//+------------------------------------------------------------------+
void CRsiModule::SetThresholds(double overbought, double oversold, double bullish, double bearish)
{
   LOG_DEBUG("Setting thresholds: OB=" + DoubleToString(overbought, 1) + 
             ", OS=" + DoubleToString(oversold, 1) + 
             ", Bull=" + DoubleToString(bullish, 1) + 
             ", Bear=" + DoubleToString(bearish, 1), g_debugRsiModule);
   
   if(overbought > oversold && overbought <= 100 && oversold >= 0)
   {
      m_overboughtThreshold = overbought;
      m_oversoldThreshold = oversold;
   }
   if(bullish > bearish && bullish <= 100 && bearish >= 0)
   {
      m_bullishThreshold = bullish;
      m_bearishThreshold = bearish;
   }
   
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CRsiModule::Initialize()
{
   LOG_INFO("=== INITIALIZATION START ===", g_debugRsiModule);
   
   if(m_rsiHandle != INVALID_HANDLE)
   {
      LOG_DEBUG("Releasing existing RSI handle", g_debugRsiModule);
      IndicatorRelease(m_rsiHandle);
   }
   
   LOG_DEBUG("Creating RSI handle for " + m_symbol + 
             " on " + EnumToString(m_timeframe) + 
             " with period " + IntegerToString(m_rsiPeriod), g_debugRsiModule);
   
   m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
   
   if(m_rsiHandle == INVALID_HANDLE)
   {
      m_lastError = "Failed to create RSI handle";
      LOG_INFO("Failed to create RSI handle", g_debugRsiModule);
      m_initialized = false;
      return false;
   }
   
   m_initialized = true;
   InvalidateCache();
   LOG_INFO("✅ RSI initialized successfully", g_debugRsiModule);
   LOG_INFO("=== END INITIALIZATION ===", g_debugRsiModule);
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CRsiModule::Deinitialize()
{
   LOG_DEBUG("Deinitializing...", g_debugRsiModule);
   
   if(m_rsiHandle != INVALID_HANDLE)
   {
      LOG_DEBUG("Releasing RSI handle", g_debugRsiModule);
      IndicatorRelease(m_rsiHandle);
      m_rsiHandle = INVALID_HANDLE;
   }
   m_initialized = false;
   InvalidateCache();
   
   LOG_DEBUG("Deinitialization complete", g_debugRsiModule);
}

//+------------------------------------------------------------------+
//| Get RSI - WITH CACHING                                          |
//+------------------------------------------------------------------+
double CRsiModule::GetRSI()
{
   if(!m_initialized)
   {
      if(!Initialize())
         return 50;
   }
   
   // Check cache
   if(IsCacheValid())
   {
      LOG_DEBUG("Using cached RSI: " + DoubleToString(m_cachedRSI, 2), g_debugRsiModule);
      return m_cachedRSI;
   }
   
   double rsiBuffer[1];
   if(CopyBuffer(m_rsiHandle, 0, 0, 1, rsiBuffer) < 1)
   {
      LOG_DEBUG("Failed to copy RSI buffer", g_debugRsiModule);
      return 50;
   }
   
   m_cachedRSI = rsiBuffer[0];
   UpdateCache();
   
   return m_cachedRSI;
}

//+------------------------------------------------------------------+
//| Get RSI Value - Public                                          |
//+------------------------------------------------------------------+
double CRsiModule::GetRSIValue()
{
   double rsi = GetRSI();
   LOG_DEBUG("RSI Value: " + DoubleToString(rsi, 2), g_debugRsiModule);
   return rsi;
}

//+------------------------------------------------------------------+
//| Is Overbought                                                   |
//+------------------------------------------------------------------+
bool CRsiModule::IsOverbought()
{
   bool result = GetRSI() >= m_overboughtThreshold;
   LOG_DEBUG("IsOverbought: " + (result ? "YES" : "NO"), g_debugRsiModule);
   return result;
}

//+------------------------------------------------------------------+
//| Is Oversold                                                    |
//+------------------------------------------------------------------+
bool CRsiModule::IsOversold()
{
   bool result = GetRSI() <= m_oversoldThreshold;
   LOG_DEBUG("IsOversold: " + (result ? "YES" : "NO"), g_debugRsiModule);
   return result;
}

//+------------------------------------------------------------------+
//| Is Extreme                                                      |
//+------------------------------------------------------------------+
bool CRsiModule::IsExtreme()
{
   double rsi = GetRSI();
   bool result = (rsi >= m_overboughtThreshold || rsi <= m_oversoldThreshold);
   LOG_DEBUG("IsExtreme: " + (result ? "YES" : "NO"), g_debugRsiModule);
   return result;
}

//+------------------------------------------------------------------+
//| Get RSI Condition Enum                                          |
//+------------------------------------------------------------------+
ENUM_RSI_CONDITION CRsiModule::GetRSIConditionEnum(double rsi)
{
   if(rsi >= m_overboughtThreshold) return RSI_OVERBOUGHT;
   else if(rsi <= m_oversoldThreshold) return RSI_OVERSOLD;
   else if(rsi >= m_bullishThreshold) return RSI_BULLISH;
   else if(rsi <= m_bearishThreshold) return RSI_BEARISH;
   else return RSI_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Get RSI Condition String                                        |
//+------------------------------------------------------------------+
string CRsiModule::GetRSIConditionString(ENUM_RSI_CONDITION condition)
{
   switch(condition)
   {
      case RSI_OVERBOUGHT: return "OVERBOUGHT";
      case RSI_OVERSOLD:   return "OVERSOLD";
      case RSI_BULLISH:    return "BULLISH";
      case RSI_BEARISH:    return "BEARISH";
      case RSI_NEUTRAL:    return "NEUTRAL";
      default:             return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Calculate Bull Percentage                                       |
//+------------------------------------------------------------------+
double CRsiModule::CalculateBullPercentage(double rsi)
{
   return MathMin(100.0, MathMax(0.0, rsi));
}

//+------------------------------------------------------------------+
//| Get Bull Percentage - Public                                    |
//+------------------------------------------------------------------+
double CRsiModule::GetBullPercentage()
{
   double rsi = GetRSI();
   double bullPct = CalculateBullPercentage(rsi);
   LOG_DEBUG("Bull%: " + DoubleToString(bullPct, 1) + "%", g_debugRsiModule);
   return bullPct;
}

//+------------------------------------------------------------------+
//| Calculate Bear Percentage                                       |
//+------------------------------------------------------------------+
double CRsiModule::CalculateBearPercentage(double rsi)
{
   return 100.0 - CalculateBullPercentage(rsi);
}

//+------------------------------------------------------------------+
//| Get Bear Percentage - Public                                    |
//+------------------------------------------------------------------+
double CRsiModule::GetBearPercentage()
{
   double bearPct = 100.0 - GetBullPercentage();
   LOG_DEBUG("Bear%: " + DoubleToString(bearPct, 1) + "%", g_debugRsiModule);
   return bearPct;
}

//+------------------------------------------------------------------+
//| Calculate Momentum Strength                                     |
//+------------------------------------------------------------------+
double CRsiModule::CalculateMomentumStrength(double rsi)
{
   double strength = MathAbs(rsi - 50.0) / 50.0 * 100.0;
   return MathMin(100.0, strength);
}

//+------------------------------------------------------------------+
//| Get Momentum Strength - Public                                  |
//+------------------------------------------------------------------+
double CRsiModule::GetMomentumStrength()
{
   double rsi = GetRSI();
   double strength = CalculateMomentumStrength(rsi);
   LOG_DEBUG("Momentum Strength: " + DoubleToString(strength, 1) + "%", g_debugRsiModule);
   return strength;
}

//+------------------------------------------------------------------+
//| Calculate Reversal Probability                                  |
//+------------------------------------------------------------------+
double CRsiModule::CalculateReversalProbability(double rsi)
{
   double prob = 0;
   
   if(rsi >= m_overboughtThreshold)
   {
      prob = (rsi - m_overboughtThreshold) / (100.0 - m_overboughtThreshold) * 100.0;
   }
   else if(rsi <= m_oversoldThreshold)
   {
      prob = (m_oversoldThreshold - rsi) / m_oversoldThreshold * 100.0;
   }
   else if(rsi >= m_bullishThreshold)
   {
      prob = (rsi - m_bullishThreshold) / (m_overboughtThreshold - m_bullishThreshold) * 30.0;
   }
   else if(rsi <= m_bearishThreshold)
   {
      prob = (m_bearishThreshold - rsi) / (m_bearishThreshold - m_oversoldThreshold) * 30.0;
   }
   else
   {
      prob = MathAbs(rsi - 50.0) / 10.0 * 10.0;
   }
   
   return MathMin(100.0, prob);
}

//+------------------------------------------------------------------+
//| Get Reversal Probability - Public                               |
//+------------------------------------------------------------------+
double CRsiModule::GetReversalProbability()
{
   double rsi = GetRSI();
   double prob = CalculateReversalProbability(rsi);
   LOG_DEBUG("Reversal Probability: " + DoubleToString(prob, 1) + "%", g_debugRsiModule);
   return prob;
}

//+------------------------------------------------------------------+
//| Calculate Confidence - ENHANCED                                 |
//+------------------------------------------------------------------+
double CRsiModule::CalculateConfidenceInternal(double rsi, double bullPct, double bearPct)
{
   LOG_DEBUG("Calculating enhanced confidence...", g_debugRsiModule);
   LOG_DEBUG("  RSI: " + DoubleToString(rsi, 2), g_debugRsiModule);
   LOG_DEBUG("  Bull%: " + DoubleToString(bullPct, 1) + "%, Bear%: " + DoubleToString(bearPct, 1) + "%", g_debugRsiModule);
   
   double directionClarity = MathAbs(bullPct - bearPct);
   LOG_DEBUG("  Direction Clarity: " + DoubleToString(directionClarity, 1) + "%", g_debugRsiModule);
   
   double momentumStrength = CalculateMomentumStrength(rsi);
   LOG_DEBUG("  Momentum Strength: " + DoubleToString(momentumStrength, 1) + "%", g_debugRsiModule);
   
   double baseConfidence = (directionClarity * 0.6) + (momentumStrength * 0.4);
   LOG_DEBUG("  Base Confidence: " + DoubleToString(baseConfidence, 1) + "%", g_debugRsiModule);
   
   if(rsi >= m_overboughtThreshold || rsi <= m_oversoldThreshold)
   {
      double reduction = 20.0;
      baseConfidence = MathMax(0, baseConfidence - reduction);
      LOG_DEBUG("  Extreme adjustment: -20% → " + DoubleToString(baseConfidence, 1) + "%", g_debugRsiModule);
   }
   
   if(CheckDivergence())
   {
      baseConfidence = MathMax(0, baseConfidence - 15);
      LOG_DEBUG("  Divergence adjustment: -15% → " + DoubleToString(baseConfidence, 1) + "%", g_debugRsiModule);
   }
   
   if(directionClarity > 0 && baseConfidence < 5)
   {
      baseConfidence = 5.0;
      LOG_DEBUG("  Minimum confidence applied: 5%", g_debugRsiModule);
   }
   
   double result = MathMin(100.0, MathMax(0.0, baseConfidence));
   LOG_DEBUG("  Final Confidence: " + DoubleToString(result, 1) + "%", g_debugRsiModule);
   return result;
}

//+------------------------------------------------------------------+
//| Get Confidence - Public                                         |
//+------------------------------------------------------------------+
double CRsiModule::GetConfidence()
{
   double rsi = GetRSI();
   double bullPct = CalculateBullPercentage(rsi);
   double bearPct = CalculateBearPercentage(rsi);
   return CalculateConfidenceInternal(rsi, bullPct, bearPct);
}

//+------------------------------------------------------------------+
//| Get Confidence - With Trend                                     |
//+------------------------------------------------------------------+
double CRsiModule::GetConfidence(int trend)
{
   return GetConfidence();
}

//+------------------------------------------------------------------+
//| Check Divergence (simplified)                                   |
//+------------------------------------------------------------------+
bool CRsiModule::CheckDivergence()
{
   LOG_DEBUG("Checking for divergence...", g_debugRsiModule);
   
   int lookback = (int)m_divergenceLookback;
   double rsiBuffer[];
   double highBuffer[];
   double lowBuffer[];
   
   ArrayResize(rsiBuffer, lookback);
   ArrayResize(highBuffer, lookback);
   ArrayResize(lowBuffer, lookback);
   
   if(CopyBuffer(m_rsiHandle, 0, 0, lookback, rsiBuffer) < lookback)
   {
      LOG_DEBUG("  Failed to copy RSI buffer for divergence check", g_debugRsiModule);
      return false;
   }
   if(CopyHigh(m_symbol, m_timeframe, 0, lookback, highBuffer) < lookback)
   {
      LOG_DEBUG("  Failed to copy High buffer for divergence check", g_debugRsiModule);
      return false;
   }
   if(CopyLow(m_symbol, m_timeframe, 0, lookback, lowBuffer) < lookback)
   {
      LOG_DEBUG("  Failed to copy Low buffer for divergence check", g_debugRsiModule);
      return false;
   }
   
   if(highBuffer[0] > highBuffer[2] && highBuffer[1] > highBuffer[2])
   {
      if(rsiBuffer[0] < rsiBuffer[2] && rsiBuffer[1] < rsiBuffer[2])
      {
         LOG_WARNING("⚡ Bearish divergence detected!");
         return true;
      }
   }
   
   if(lowBuffer[0] < lowBuffer[2] && lowBuffer[1] < lowBuffer[2])
   {
      if(rsiBuffer[0] > rsiBuffer[2] && rsiBuffer[1] > rsiBuffer[2])
      {
         LOG_WARNING("⚡ Bullish divergence detected!");
         return true;
      }
   }
   
   LOG_DEBUG("  No divergence detected", g_debugRsiModule);
   return false;
}

//+------------------------------------------------------------------+
//| Determine Direction                                             |
//+------------------------------------------------------------------+
string CRsiModule::DetermineDirection(double rsi, double bullPct, double bearPct)
{
   LOG_DEBUG("Determining direction...", g_debugRsiModule);
   
   if(rsi >= m_bullishThreshold)
   {
      LOG_DEBUG("  RSI >= " + DoubleToString(m_bullishThreshold, 1) + " → BULLISH", g_debugRsiModule);
      return "BULLISH";
   }
   else if(rsi <= m_bearishThreshold)
   {
      LOG_DEBUG("  RSI <= " + DoubleToString(m_bearishThreshold, 1) + " → BEARISH", g_debugRsiModule);
      return "BEARISH";
   }
   
   if(bullPct > bearPct + 10)
   {
      LOG_DEBUG("  Bull% > Bear% by 10+ → BULLISH", g_debugRsiModule);
      return "BULLISH";
   }
   else if(bearPct > bullPct + 10)
   {
      LOG_DEBUG("  Bear% > Bull% by 10+ → BEARISH", g_debugRsiModule);
      return "BEARISH";
   }
   
   LOG_DEBUG("  No clear direction → NEUTRAL", g_debugRsiModule);
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Direction - Public                                          |
//+------------------------------------------------------------------+
string CRsiModule::GetDirection()
{
   double rsi = GetRSI();
   double bullPct = CalculateBullPercentage(rsi);
   double bearPct = CalculateBearPercentage(rsi);
   string direction = DetermineDirection(rsi, bullPct, bearPct);
   LOG_DEBUG("Direction: " + direction, g_debugRsiModule);
   return direction;
}

//+------------------------------------------------------------------+
//| Get Direction - With Trend                                      |
//+------------------------------------------------------------------+
string CRsiModule::GetDirection(int trend)
{
   return GetDirection();
}

//+------------------------------------------------------------------+
//| Get RSI Score                                                   |
//+------------------------------------------------------------------+
double CRsiModule::GetRSIScore(int trend = 0)
{
   double rsi = GetRSI();
   
   double idealMin, idealMax, maxDistance;
   if(trend == 1)
   {
      idealMin = m_bullishThreshold;
      idealMax = 70;
      maxDistance = 30;
   }
   else if(trend == -1)
   {
      idealMin = 30;
      idealMax = m_bearishThreshold;
      maxDistance = 30;
   }
   else
   {
      idealMin = 40;
      idealMax = 60;
      maxDistance = 30;
   }
   
   double score;
   if(rsi >= idealMin && rsi <= idealMax)
      score = 100.0;
   else
   {
      double distance = 0;
      if(rsi < idealMin)
         distance = idealMin - rsi;
      else if(rsi > idealMax)
         distance = rsi - idealMax;
      
      score = 100.0 - (distance / maxDistance * 100.0);
      score = MathMax(0.0, MathMin(100.0, score));
   }
   
   LOG_DEBUG("RSI Score: " + DoubleToString(score, 1) + "%", g_debugRsiModule);
   return score;
}

//+------------------------------------------------------------------+
//| Generate Description                                            |
//+------------------------------------------------------------------+
string CRsiModule::GenerateDescription(double rsi, ENUM_RSI_CONDITION condition, double bullPct, double bearPct)
{
   string desc = "";
   
   switch(condition)
   {
      case RSI_OVERBOUGHT:
         desc = "Overbought RSI " + DoubleToString(rsi, 1) + 
                " - Bulls " + DoubleToString(bullPct, 0) + 
                "% / Bears " + DoubleToString(bearPct, 0) + 
                "% - Potential reversal";
         break;
      case RSI_OVERSOLD:
         desc = "Oversold RSI " + DoubleToString(rsi, 1) + 
                " - Bulls " + DoubleToString(bullPct, 0) + 
                "% / Bears " + DoubleToString(bearPct, 0) + 
                "% - Potential bounce";
         break;
      case RSI_BULLISH:
         desc = "Bullish RSI " + DoubleToString(rsi, 1) + 
                " - Bulls " + DoubleToString(bullPct, 0) + 
                "% / Bears " + DoubleToString(bearPct, 0) + 
                "% - Momentum up";
         break;
      case RSI_BEARISH:
         desc = "Bearish RSI " + DoubleToString(rsi, 1) + 
                " - Bulls " + DoubleToString(bullPct, 0) + 
                "% / Bears " + DoubleToString(bearPct, 0) + 
                "% - Momentum down";
         break;
      case RSI_NEUTRAL:
      default:
         desc = "Neutral RSI " + DoubleToString(rsi, 1) + 
                " - Bulls " + DoubleToString(bullPct, 0) + 
                "% / Bears " + DoubleToString(bearPct, 0) + 
                "% - No clear direction";
         break;
   }
   
   LOG_DEBUG("Description: " + desc, g_debugRsiModule);
   return desc;
}

//+------------------------------------------------------------------+
//| Get Description - Public                                        |
//+------------------------------------------------------------------+
string CRsiModule::GetDescription()
{
   double rsi = GetRSI();
   ENUM_RSI_CONDITION condition = GetRSIConditionEnum(rsi);
   double bullPct = CalculateBullPercentage(rsi);
   double bearPct = CalculateBearPercentage(rsi);
   return GenerateDescription(rsi, condition, bullPct, bearPct);
}

//+------------------------------------------------------------------+
//| Get Description - With Trend                                    |
//+------------------------------------------------------------------+
string CRsiModule::GetDescription(int trend)
{
   return GetDescription();
}

//+------------------------------------------------------------------+
//| Generate Narrative                                              |
//+------------------------------------------------------------------+
string CRsiModule::GenerateNarrative(string direction, double rsi, double bullPct, double bearPct, 
                                     double confidence, double momentumStrength, double reversalProb)
{
   LOG_DEBUG("Generating narrative...", g_debugRsiModule);
   string narrative = "";
   
   string emoji;
   if(direction == "BULLISH") emoji = "📈";
   else if(direction == "BEARISH") emoji = "📉";
   else emoji = "➡️";
   
   if(direction == "BULLISH")
   {
      if(rsi >= m_overboughtThreshold)
      {
         narrative = emoji + " RSI at " + DoubleToString(rsi, 1) + 
                     " indicates OVERBOUGHT conditions. " +
                     "While bulls are firmly in control (" + DoubleToString(bullPct, 0) + "%), " +
                     "the market may be overextended. " +
                     (reversalProb > 50 ? "⚠️ High reversal probability - consider taking profits or tightening stops." : 
                                          "Strong momentum but extreme levels suggest caution.");
      }
      else if(rsi >= m_bullishThreshold)
      {
         narrative = emoji + " RSI at " + DoubleToString(rsi, 1) + 
                     " shows BULLISH momentum. " +
                     "Bulls are gaining control (" + DoubleToString(bullPct, 0) + "%) " +
                     "with room to move higher. " +
                     (confidence >= 50 ? "Good confidence in the bullish move. Trend may continue." : 
                                         "Moderate confidence - confirm with other indicators.");
      }
      else
      {
         narrative = "Slight bullish bias with RSI at " + DoubleToString(rsi, 1) + 
                     ". Market may be transitioning but lacks strong conviction.";
      }
   }
   else if(direction == "BEARISH")
   {
      if(rsi <= m_oversoldThreshold)
      {
         narrative = emoji + " RSI at " + DoubleToString(rsi, 1) + 
                     " indicates OVERSOLD conditions. " +
                     "While bears are in control (" + DoubleToString(bearPct, 0) + "%), " +
                     "the market may be oversold. " +
                     (reversalProb > 50 ? "⚠️ High reversal probability - consider taking profits or tightening stops." : 
                                          "Strong momentum but extreme levels suggest caution.");
      }
      else if(rsi <= m_bearishThreshold)
      {
         narrative = emoji + " RSI at " + DoubleToString(rsi, 1) + 
                     " shows BEARISH momentum. " +
                     "Bears are gaining control (" + DoubleToString(bearPct, 0) + "%) " +
                     "with room to move lower. " +
                     (confidence >= 50 ? "Good confidence in the bearish move. Trend may continue." : 
                                         "Moderate confidence - confirm with other indicators.");
      }
      else
      {
         narrative = "Slight bearish bias with RSI at " + DoubleToString(rsi, 1) + 
                     ". Market may be transitioning but lacks strong conviction.";
      }
   }
   else
   {
      narrative = "Market is in a neutral/sideways phase with RSI at " + DoubleToString(rsi, 1) + 
                  ". Neither bulls (" + DoubleToString(bullPct, 0) + "%) nor bears (" + 
                  DoubleToString(bearPct, 0) + "%) have clear control. " +
                  (rsi >= 45 && rsi <= 55 ? "Market is consolidating. Wait for clear direction." : 
                                            "Slight bias exists but not decisive. Monitor for breakout.");
   }
   
   if(confidence >= 60)
      narrative += " Overall confidence is HIGH.";
   else if(confidence >= 40)
      narrative += " Overall confidence is MODERATE.";
   else
      narrative += " Overall confidence is LOW - wait for better conditions.";
   
   if(CheckDivergence())
   {
      if(direction == "BULLISH")
         narrative += " ⚠️ Bullish divergence detected - potential reversal up!";
      else if(direction == "BEARISH")
         narrative += " ⚠️ Bearish divergence detected - potential reversal down!";
   }
   
   narrative += " (Bulls: " + DoubleToString(bullPct, 1) + 
                "%, Bears: " + DoubleToString(bearPct, 1) + 
                "%, Conf: " + DoubleToString(confidence, 1) + 
                "%, Momentum: " + DoubleToString(momentumStrength, 1) + 
                "%, Reversal: " + DoubleToString(reversalProb, 1) + "%)";
   
   LOG_DEBUG("  Narrative: " + narrative, g_debugRsiModule);
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Narrative - Public                                          |
//+------------------------------------------------------------------+
string CRsiModule::GetNarrative()
{
   double rsi = GetRSI();
   double bullPct = CalculateBullPercentage(rsi);
   double bearPct = CalculateBearPercentage(rsi);
   string direction = DetermineDirection(rsi, bullPct, bearPct);
   double confidence = CalculateConfidenceInternal(rsi, bullPct, bearPct);
   double momentum = CalculateMomentumStrength(rsi);
   double reversal = CalculateReversalProbability(rsi);
   return GenerateNarrative(direction, rsi, bullPct, bearPct, confidence, momentum, reversal);
}

//+------------------------------------------------------------------+
//| Get Narrative - With Trend                                      |
//+------------------------------------------------------------------+
string CRsiModule::GetNarrative(int trend)
{
   return GetNarrative();
}

//+------------------------------------------------------------------+
//| Get Complete Direction Result - ALL IN ONE!                     |
//+------------------------------------------------------------------+
SRSIDirectionResult CRsiModule::GetDirectionResult(int trend = 0)
{
   LOG_DEBUG("=== GETTING COMPLETE DIRECTION RESULT ===", g_debugRsiModule);
   
   SRSIDirectionResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.errorMessage = "";
   
   double rsi = GetRSI();
   if(rsi <= 0 || rsi > 100)
   {
      result.errorMessage = "Invalid RSI value: " + DoubleToString(rsi, 2);
      LOG_INFO(result.errorMessage, g_debugRsiModule);
      return result;
   }
   
   result.rsiValue = rsi;
   
   ENUM_RSI_CONDITION conditionEnum = GetRSIConditionEnum(rsi);
   result.rsiConditionEnum = conditionEnum;
   result.rsiCondition = GetRSIConditionString(conditionEnum);
   result.isOverbought = (rsi >= m_overboughtThreshold);
   result.isOversold = (rsi <= m_oversoldThreshold);
   result.isExtreme = (rsi >= m_overboughtThreshold || rsi <= m_oversoldThreshold);
   result.isDiverging = CheckDivergence();
   result.rsiScore = GetRSIScore(trend);
   
   result.bullPercentage = CalculateBullPercentage(rsi);
   result.bearPercentage = CalculateBearPercentage(rsi);
   
   double total = result.bullPercentage + result.bearPercentage;
   if(total > 0 && MathAbs(total - 100.0) > 0.01)
   {
      result.bullPercentage = (result.bullPercentage / total) * 100.0;
      result.bearPercentage = (result.bearPercentage / total) * 100.0;
   }
   
   result.momentumStrength = CalculateMomentumStrength(rsi);
   result.reversalProbability = CalculateReversalProbability(rsi);
   result.confidence = CalculateConfidenceInternal(rsi, result.bullPercentage, result.bearPercentage);
   result.direction = DetermineDirection(rsi, result.bullPercentage, result.bearPercentage);
   result.description = GenerateDescription(rsi, conditionEnum, result.bullPercentage, result.bearPercentage);
   result.narrative = GenerateNarrative(result.direction, rsi, result.bullPercentage, result.bearPercentage,
                                        result.confidence, result.momentumStrength, result.reversalProbability);
   
   result.isValid = true;
   
   LOG_DEBUG("✅ Direction Result Complete", g_debugRsiModule);
   LOG_DEBUG("  Direction: " + result.direction, g_debugRsiModule);
   LOG_DEBUG("  Confidence: " + DoubleToString(result.confidence, 1) + "%", g_debugRsiModule);
   LOG_DEBUG("  RSI: " + DoubleToString(rsi, 2), g_debugRsiModule);
   LOG_DEBUG("  Description: " + result.description, g_debugRsiModule);
   LOG_DEBUG("=== END DIRECTION RESULT ===", g_debugRsiModule);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get RSI Summary - For Component Manager                         |
//+------------------------------------------------------------------+
SRSISummary CRsiModule::GetRSISummary(int trend = 0)
{
   LOG_DEBUG("Getting RSI Summary...", g_debugRsiModule);
   
   SRSISummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   SRSIDirectionResult result = GetDirectionResult(trend);
   if(!result.isValid)
   {
      LOG_INFO("Failed to get RSI summary", g_debugRsiModule);
      return summary;
   }
   
   summary.direction = result.direction;
   summary.confidence = result.confidence;
   summary.bullPercentage = result.bullPercentage;
   summary.bearPercentage = result.bearPercentage;
   summary.rsiValue = result.rsiValue;
   summary.condition = result.rsiCondition;
   summary.isOverbought = result.isOverbought;
   summary.isOversold = result.isOversold;
   summary.isExtreme = result.isExtreme;
   summary.momentumStrength = result.momentumStrength;
   
   string emoji;
   if(summary.direction == "BULLISH") emoji = "📈";
   else if(summary.direction == "BEARISH") emoji = "📉";
   else emoji = "➡️";
   
   string shortDesc = emoji + " RSI " + DoubleToString(summary.rsiValue, 1) + " - ";
   
   if(summary.isOverbought)
      shortDesc += "Overbought (Bulls " + DoubleToString(summary.bullPercentage, 0) + "%)";
   else if(summary.isOversold)
      shortDesc += "Oversold (Bears " + DoubleToString(summary.bearPercentage, 0) + "%)";
   else if(summary.direction == "BULLISH")
      shortDesc += "Bullish momentum";
   else if(summary.direction == "BEARISH")
      shortDesc += "Bearish momentum";
   else
      shortDesc += "Neutral/Sideways";
   
   if(summary.confidence >= 60)
      shortDesc += " - High confidence";
   else if(summary.confidence >= 40)
      shortDesc += " - Medium confidence";
   else
      shortDesc += " - Low confidence";
   
   summary.shortDescription = shortDesc;
   summary.fullDescription = result.description;
   summary.isValid = true;
   
   LOG_DEBUG("  Summary: " + shortDesc, g_debugRsiModule);
   return summary;
}

//+------------------------------------------------------------------+
//| Get Summary String - Quick display                              |
//+------------------------------------------------------------------+
string CRsiModule::GetSummaryString(int trend = 0)
{
   LOG_DEBUG("Getting Summary String...", g_debugRsiModule);
   
   SRSISummary summary = GetRSISummary(trend);
   if(!summary.isValid)
   {
      LOG_DEBUG("  Invalid summary", g_debugRsiModule);
      return "RSI: N/A";
   }
   
   string directionSymbol = "";
   if(summary.direction == "BULLISH") directionSymbol = "📈";
   else if(summary.direction == "BEARISH") directionSymbol = "📉";
   else directionSymbol = "➡️";
   
   string result = "RSI: " + DoubleToString(summary.rsiValue, 1) + 
                   " | " + directionSymbol + " " + summary.direction + 
                   " | Conf: " + DoubleToString(summary.confidence, 0) + 
                   "% | " + summary.condition;
   
   LOG_DEBUG("  Summary: " + result, g_debugRsiModule);
   return result;
}

//+------------------------------------------------------------------+
//| Print Status - Full debug output                                |
//+------------------------------------------------------------------+
void CRsiModule::PrintStatus(int trend = 0)
{
   string separator = "=== ";
   string indent = "   ";
   
   LOG_INFO(separator + "RSI MODULE STATUS " + separator, g_debugRsiModule);
   LOG_INFO(indent + "Symbol: " + m_symbol, g_debugRsiModule);
   LOG_INFO(indent + "Timeframe: " + EnumToString(m_timeframe), g_debugRsiModule);
   LOG_INFO(indent + "Period: " + IntegerToString(m_rsiPeriod), g_debugRsiModule);
   LOG_INFO(indent + "Initialized: " + (m_initialized ? "YES" : "NO"), g_debugRsiModule);
   LOG_INFO(indent + "Last Error: " + m_lastError, g_debugRsiModule);
   LOG_INFO(indent + "Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s", g_debugRsiModule);
   LOG_INFO(indent + "Cache Valid: " + (m_cacheValid ? "YES" : "NO"), g_debugRsiModule);
   LOG_INFO(indent + "Cache Age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s", g_debugRsiModule);
   LOG_INFO(indent + "Thresholds: OB=" + DoubleToString(m_overboughtThreshold, 1) + 
            ", OS=" + DoubleToString(m_oversoldThreshold, 1) +
            ", Bull=" + DoubleToString(m_bullishThreshold, 1) +
            ", Bear=" + DoubleToString(m_bearishThreshold, 1), g_debugRsiModule);
   
   SRSIDirectionResult result = GetDirectionResult(trend);
   if(result.isValid)
   {
      LOG_INFO(indent + "RSI Value: " + DoubleToString(result.rsiValue, 2), g_debugRsiModule);
      LOG_INFO(indent + "Condition: " + result.rsiCondition, g_debugRsiModule);
      LOG_INFO(indent + "Direction: " + result.direction, g_debugRsiModule);
      LOG_INFO(indent + "Confidence: " + DoubleToString(result.confidence, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Bull%: " + DoubleToString(result.bullPercentage, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Bear%: " + DoubleToString(result.bearPercentage, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Overbought: " + (result.isOverbought ? "YES" : "NO"), g_debugRsiModule);
      LOG_INFO(indent + "Oversold: " + (result.isOversold ? "YES" : "NO"), g_debugRsiModule);
      LOG_INFO(indent + "Extreme: " + (result.isExtreme ? "YES" : "NO"), g_debugRsiModule);
      LOG_INFO(indent + "Divergence: " + (result.isDiverging ? "YES" : "NO"), g_debugRsiModule);
      LOG_INFO(indent + "Momentum: " + DoubleToString(result.momentumStrength, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Reversal Prob: " + DoubleToString(result.reversalProbability, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Score: " + DoubleToString(result.rsiScore, 1) + "%", g_debugRsiModule);
      LOG_INFO(indent + "Description: " + result.description, g_debugRsiModule);
      LOG_INFO(indent + "Narrative: " + result.narrative, g_debugRsiModule);
   }
   else
   {
      LOG_INFO(indent + "❌ Unable to get RSI values", g_debugRsiModule);
      LOG_INFO(indent + "Error: " + result.errorMessage, g_debugRsiModule);
   }
   LOG_INFO(separator + "END STATUS " + separator, g_debugRsiModule);
}

//+------------------------------------------------------------------+
//| Debug Print RSI - Detailed debug output                         |
//+------------------------------------------------------------------+
void CRsiModule::DebugPrintRSI(int trend = 0)
{
   LOG_DEBUG("=== DEBUG PRINT RSI ===", g_debugRsiModule);
   
   double rsi = GetRSI();
   if(rsi <= 0 || rsi > 100)
   {
      LOG_INFO("Invalid RSI value: " + DoubleToString(rsi, 2), g_debugRsiModule);
      return;
   }
   
   double bullPct = CalculateBullPercentage(rsi);
   double bearPct = CalculateBearPercentage(rsi);
   double confidence = CalculateConfidenceInternal(rsi, bullPct, bearPct);
   double momentum = CalculateMomentumStrength(rsi);
   double reversal = CalculateReversalProbability(rsi);
   string direction = DetermineDirection(rsi, bullPct, bearPct);
   ENUM_RSI_CONDITION condition = GetRSIConditionEnum(rsi);
   string conditionStr = GetRSIConditionString(condition);
   bool divergence = CheckDivergence();
   double score = GetRSIScore(trend);
   
   LOG_INFO("=== RSI DEBUG ===", g_debugRsiModule);
   LOG_INFO("  Symbol: " + m_symbol, g_debugRsiModule);
   LOG_INFO("  Timeframe: " + EnumToString(m_timeframe), g_debugRsiModule);
   LOG_INFO("  Period: " + IntegerToString(m_rsiPeriod), g_debugRsiModule);
   LOG_INFO("  Cache Status: " + (m_cacheValid ? "VALID (age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)" : "INVALID"), g_debugRsiModule);
   LOG_INFO("  RSI Value: " + DoubleToString(rsi, 2), g_debugRsiModule);
   LOG_INFO("  Condition: " + conditionStr, g_debugRsiModule);
   LOG_INFO("  Direction: " + direction, g_debugRsiModule);
   LOG_INFO("  Confidence: " + DoubleToString(confidence, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Bull%: " + DoubleToString(bullPct, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Bear%: " + DoubleToString(bearPct, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Momentum Strength: " + DoubleToString(momentum, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Reversal Probability: " + DoubleToString(reversal, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Divergence: " + (divergence ? "YES ⚠️" : "NO"), g_debugRsiModule);
   LOG_INFO("  Score: " + DoubleToString(score, 1) + "%", g_debugRsiModule);
   LOG_INFO("  Overbought: " + (rsi >= m_overboughtThreshold ? "YES" : "NO"), g_debugRsiModule);
   LOG_INFO("  Oversold: " + (rsi <= m_oversoldThreshold ? "YES" : "NO"), g_debugRsiModule);
   LOG_INFO("  Extreme: " + ((rsi >= m_overboughtThreshold || rsi <= m_oversoldThreshold) ? "YES" : "NO"), g_debugRsiModule);
   LOG_INFO("  Description: " + GetDescription(), g_debugRsiModule);
   LOG_INFO("=================", g_debugRsiModule);
   
   LOG_DEBUG("=== DEBUG PRINT COMPLETE ===", g_debugRsiModule);
}