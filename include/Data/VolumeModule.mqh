//+------------------------------------------------------------------+
//|                        VolumeModule.mqh                          |
//|                    Volume Calculation Module                     |
//|                    v2.2 - WITH CACHING                          |
//|                    Returns: Direction, Confidence, Desc,         |
//|                    Narrative, and Full Volume Info              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.2"

#include "../Utils/Logger.mqh"

// ============================================================
// VOLUME MODULE INDEPENDENT TOGGLE
// ============================================================
bool g_volumeDebugMode = false;  // Set to true to enable volume module logging

//+------------------------------------------------------------------+
//| Volume Condition Enum                                            |
//+------------------------------------------------------------------+
enum ENUM_VOLUME_CONDITION
{
   VOL_SURGING,
   VOL_ELEVATED,
   VOL_NORMAL,
   VOL_DECLINING,
   VOL_DROPPING
};

//+------------------------------------------------------------------+
//| Volume Direction Result Structure                                |
//| COMPLETE - All info needed for Component Manager                |
//+------------------------------------------------------------------+
struct SVolumeDirectionResult
{
   // --- CORE COMPONENT MANAGER FIELDS ---
   string   direction;           // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;          // 0-100 (IMPROVED - accounts for volume strength & price)
   string   description;         // Brief description of market condition
   string   narrative;           // Detailed narrative explaining the situation
   
   // --- PERCENTAGES FOR WEIGHTING ---
   double   bullPercentage;      // 0-100
   double   bearPercentage;      // 0-100
   
   // --- RAW VOLUME VALUES ---
   double   currentVolume;       // Current tick volume
   double   averageVolume;       // Average volume over 20 periods
   double   volumeRatio;         // Current/Average ratio (1.0 = normal)
   double   priceChange;         // Price change percentage
   
   // --- METRICS FOR ANALYSIS ---
   double   volumeScore;         // Volume strength score (0-100)
   string   volumeCondition;     // "SURGING", "ELEVATED", "NORMAL", "DECLINING", "DROPPING"
   ENUM_VOLUME_CONDITION volumeConditionEnum;
   bool     isVolumeSpike;       // Volume ratio >= 1.5
   bool     isVolumeSurge;       // Volume ratio >= 2.0
   bool     isVolumeDrying;      // Volume ratio <= 0.5
   double   momentumStrength;    // How strong is the volume momentum (0-100)
   double   convictionLevel;     // Conviction level of the move (0-100)
   
   // --- VALIDATION ---
   bool     isValid;
   string   errorMessage;
};

//+------------------------------------------------------------------+
//| Volume Summary Structure for Component Manager                   |
//+------------------------------------------------------------------+
struct SVolumeSummary
{
   // --- CORE ---
   string   direction;          // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;         // 0-100
   string   shortDescription;   // Brief description (max 50 chars)
   string   fullDescription;    // Full description
   
   // --- PERCENTAGES ---
   double   bullPercentage;     // 0-100
   double   bearPercentage;     // 0-100
   
   // --- RAW VALUES ---
   double   currentVolume;      // Current tick volume
   double   averageVolume;      // Average volume over 20 periods
   double   volumeRatio;        // Current/Average ratio
   double   priceChange;        // Price change percentage
   string   volumeCondition;    // SURGING, ELEVATED, etc.
   double   convictionLevel;    // 0-100
   
   // --- VALIDATION ---
   bool     isValid;
};

//+------------------------------------------------------------------+
//| Volume Module Class                                             |
//+------------------------------------------------------------------+
class CVolumeModule
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool     m_initialized;
   bool     m_debug;
   string   m_lastError;
   int      m_cacheTimeout;      // Cache timeout in seconds (default: 5)
   
   // ──────────────────────────────────────────────────────────────
   // CACHE
   // ──────────────────────────────────────────────────────────────
   bool     m_cacheValid;
   datetime m_cacheTime;
   double   m_cachedVolume;
   double   m_cachedAvgVolume;
   double   m_cachedPriceChange;
   double   m_cachedBullPct;
   double   m_cachedBearPct;
   double   m_cachedConfidence;
   string   m_cachedDirection;
   string   m_cachedCondition;
   double   m_cachedMomentum;
   double   m_cachedConviction;
   double   m_cachedVolumeRatio;
   
   // ──────────────────────────────────────────────────────────────
   // CONFIGURABLE THRESHOLDS
   // ──────────────────────────────────────────────────────────────
   double   m_surgeThreshold;     // Default: 2.0
   double   m_spikeThreshold;     // Default: 1.5
   double   m_normalThreshold;    // Default: 0.8
   double   m_decliningThreshold; // Default: 0.5
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   void     GetVolumeData(double &volume, double &avgVolume, double &priceChange);
   void     InvalidateCache();
   bool     IsCacheValid();
   void     UpdateCache();
   
   // Private calculation methods
   double   CalculateBullPercentage(double volRatio, double priceChange);
   double   CalculateBearPercentage(double volRatio, double priceChange);
   double   CalculateConfidenceInternal(double volRatio, double priceChange, double bullPct, double bearPct);
   double   CalculateMomentumStrength(double volRatio);
   double   CalculateConvictionLevel(double volRatio, double priceChange);
   string   DetermineDirection(double priceChange, double volRatio, double bullPct, double bearPct);
   
   // Condition helpers
   ENUM_VOLUME_CONDITION GetVolumeConditionEnum(double volRatio);
   string   GetVolumeConditionString(ENUM_VOLUME_CONDITION condition);
   string   GetVolumeLevel(double volRatio);
   
   // Description and narrative generators
   string   GenerateDescription(double volRatio, ENUM_VOLUME_CONDITION condition, double bullPct, double bearPct);
   string   GenerateNarrative(string direction, double volRatio, double priceChange, 
                              double bullPct, double bearPct, double confidence, 
                              double momentumStrength, double convictionLevel);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CVolumeModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   ~CVolumeModule();
   
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
   void SetThresholds(double surge, double spike, double normal, double declining);
   void SetCacheTimeout(int seconds);
   
   // ──────────────────────────────────────────────────────────────
   // DATA ACCESS - Raw Values (Public getters)
   // ──────────────────────────────────────────────────────────────
   double GetCurrentVolume();
   double GetAverageVolume();
   double GetVolumeRatio();
   double GetPriceChange();
   bool IsVolumeSpike();
   bool IsVolumeSurge();
   bool IsVolumeDrying();
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT MANAGER METHODS - Returns ALL needed info
   // ──────────────────────────────────────────────────────────────
   string GetDirection();
   string GetDirection(int trend);
   double GetConfidence();
   double GetConfidence(int trend);
   string GetDescription();
   string GetDescription(int trend);
   string GetNarrative();
   string GetNarrative(int trend);
   SVolumeDirectionResult GetDirectionResult(int trend = 0);
   SVolumeSummary GetVolumeSummary(int trend = 0);
   string GetSummaryString(int trend = 0);
   
   // ──────────────────────────────────────────────────────────────
   // ADDITIONAL METRICS
   // ──────────────────────────────────────────────────────────────
   double GetBullPercentage();
   double GetBearPercentage();
   double GetMomentumStrength();
   double GetConvictionLevel();
   double GetVolumeScore();
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY METHODS
   // ──────────────────────────────────────────────────────────────
   void SetDebug(bool enable);
   bool GetDebug() const { return m_debug; }
   void Refresh();
   void PrintStatus(int trend = 0);
   void DebugPrintVolume(int trend = 0);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CVolumeModule::CVolumeModule(string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("Constructor called", g_volumeDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? PERIOD_H1 : tf;
   m_initialized = true;
   m_debug = g_volumeDebugMode;
   m_lastError = "";
   m_cacheTimeout = 5;
   
   // Default thresholds
   m_surgeThreshold = 2.0;
   m_spikeThreshold = 1.5;
   m_normalThreshold = 0.8;
   m_decliningThreshold = 0.5;
   
   // Initialize cache
   InvalidateCache();
   
   string msg = "Volume Module created - Symbol: ";
   msg += m_symbol;
   msg += ", Timeframe: ";
   msg += EnumToString(m_timeframe);
   msg += ", Cache Timeout: ";
   msg += IntegerToString(m_cacheTimeout);
   msg += "s";
   LOG_DEBUG(msg, g_volumeDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CVolumeModule::~CVolumeModule()
{
   LOG_DEBUG("Destructor called", g_volumeDebugMode);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Invalidate Cache                                                |
//+------------------------------------------------------------------+
void CVolumeModule::InvalidateCache()
{
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cachedVolume = 0;
   m_cachedAvgVolume = 0;
   m_cachedPriceChange = 0;
   m_cachedBullPct = 50;
   m_cachedBearPct = 50;
   m_cachedConfidence = 0;
   m_cachedDirection = "NEUTRAL";
   m_cachedCondition = "NORMAL";
   m_cachedMomentum = 0;
   m_cachedConviction = 50;
   m_cachedVolumeRatio = 1.0;
}

//+------------------------------------------------------------------+
//| Is Cache Valid                                                  |
//+------------------------------------------------------------------+
bool CVolumeModule::IsCacheValid()
{
   if(!m_cacheValid) return false;
   if((TimeCurrent() - m_cacheTime) > m_cacheTimeout) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Update Cache                                                    |
//+------------------------------------------------------------------+
void CVolumeModule::UpdateCache()
{
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
}

//+------------------------------------------------------------------+
//| Set Cache Timeout                                               |
//+------------------------------------------------------------------+
void CVolumeModule::SetCacheTimeout(int seconds)
{
   if(seconds > 0)
   {
      m_cacheTimeout = seconds;
      LOG_DEBUG("Cache timeout set to " + IntegerToString(seconds) + " seconds", g_volumeDebugMode);
   }
}

//+------------------------------------------------------------------+
//| Refresh - Force cache invalidation                              |
//+------------------------------------------------------------------+
void CVolumeModule::Refresh()
{
   LOG_DEBUG("Refreshing Volume data (cache invalidated)", g_volumeDebugMode);
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CVolumeModule::Initialize()
{
   LOG_INFO("=== INITIALIZATION START ===", g_volumeDebugMode);
   LOG_INFO("Volume Module initialized (no handles needed)", g_volumeDebugMode);
   m_initialized = true;
   InvalidateCache();
   LOG_INFO("✅ Volume Module initialized successfully", g_volumeDebugMode);
   LOG_INFO("=== END INITIALIZATION ===", g_volumeDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CVolumeModule::Deinitialize()
{
   LOG_DEBUG("Deinitializing...", g_volumeDebugMode);
   m_initialized = false;
   InvalidateCache();
   LOG_DEBUG("Deinitialization complete", g_volumeDebugMode);
}

//+------------------------------------------------------------------+
//| Set Thresholds                                                  |
//+------------------------------------------------------------------+
void CVolumeModule::SetThresholds(double surge, double spike, double normal, double declining)
{
   LOG_DEBUG("Setting thresholds: Surge=" + DoubleToString(surge, 1) + 
             ", Spike=" + DoubleToString(spike, 1) + 
             ", Normal=" + DoubleToString(normal, 1) + 
             ", Declining=" + DoubleToString(declining, 1), g_volumeDebugMode);
   
   if(surge > spike && spike > normal && normal > declining)
   {
      m_surgeThreshold = surge;
      m_spikeThreshold = spike;
      m_normalThreshold = normal;
      m_decliningThreshold = declining;
      InvalidateCache();
   }
}

//+------------------------------------------------------------------+
//| Get Volume Data - WITH CACHING                                  |
//+------------------------------------------------------------------+
void CVolumeModule::GetVolumeData(double &volume, double &avgVolume, double &priceChange)
{
   LOG_DEBUG("Getting volume data...", g_volumeDebugMode);
   
   // Check cache first
   if(IsCacheValid())
   {
      LOG_DEBUG("  Using cached volume data", g_volumeDebugMode);
      volume = m_cachedVolume;
      avgVolume = m_cachedAvgVolume;
      priceChange = m_cachedPriceChange;
      return;
   }
   
   LOG_DEBUG("  Cache invalid, fetching fresh data...", g_volumeDebugMode);
   
   long volumeBuffer[1];
   if(CopyTickVolume(m_symbol, m_timeframe, 0, 1, volumeBuffer) < 1) 
   { 
      volume = 0; 
      avgVolume = 0; 
      priceChange = 0; 
      LOG_WARNING("Failed to get volume data");
      return; 
   }
   
   long volumeArray[20];
   if(CopyTickVolume(m_symbol, m_timeframe, 1, 20, volumeArray) < 20) 
   { 
      volume = (double)volumeBuffer[0];
      avgVolume = volume;
      priceChange = 0; 
      LOG_WARNING("Failed to get 20 bars, using current volume only");
      return; 
   }
   
   long sum = 0;
   int validCount = 0;
   for(int i = 0; i < 20; i++) 
   {
      if(volumeArray[i] > 0)
      {
         sum += volumeArray[i];
         validCount++;
      }
   }
   
   if(validCount > 0)
      avgVolume = (double)sum / (double)validCount;
   else
      avgVolume = (double)volumeBuffer[0];
   
   if(avgVolume <= 0) avgVolume = 1.0;
   volume = (double)volumeBuffer[0];
   if(volume <= 0) volume = avgVolume;
   
   double closeBuffer[2];
   if(CopyClose(m_symbol, m_timeframe, 0, 2, closeBuffer) < 2) 
   { 
      priceChange = 0; 
      LOG_WARNING("Failed to get price data");
      return; 
   }
   priceChange = (closeBuffer[0] - closeBuffer[1]) / closeBuffer[1] * 100;
   
   // Store in cache
   m_cachedVolume = volume;
   m_cachedAvgVolume = avgVolume;
   m_cachedPriceChange = priceChange;
   UpdateCache();
   
   LOG_DEBUG("  Volume: " + DoubleToString(volume, 0) + 
             ", Avg: " + DoubleToString(avgVolume, 0) + 
             ", Price Change: " + DoubleToString(priceChange, 2) + "%", g_volumeDebugMode);
}

//+------------------------------------------------------------------+
//| Get Volume Ratio - Public                                       |
//+------------------------------------------------------------------+
double CVolumeModule::GetVolumeRatio()
{
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   
   if(m_cacheValid && m_cachedVolumeRatio > 0)
      return m_cachedVolumeRatio;
   
   double ratio = avgVolume > 0 ? volume / avgVolume : 1.0;
   m_cachedVolumeRatio = ratio;
   LOG_DEBUG("Volume Ratio: " + DoubleToString(ratio, 2) + "x", g_volumeDebugMode);
   return ratio;
}

//+------------------------------------------------------------------+
//| Get Price Change - Public                                       |
//+------------------------------------------------------------------+
double CVolumeModule::GetPriceChange()
{
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   LOG_DEBUG("Price Change: " + DoubleToString(priceChange, 2) + "%", g_volumeDebugMode);
   return priceChange;
}

//+------------------------------------------------------------------+
//| Get Current Volume                                              |
//+------------------------------------------------------------------+
double CVolumeModule::GetCurrentVolume()
{
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   return volume;
}

//+------------------------------------------------------------------+
//| Get Average Volume                                              |
//+------------------------------------------------------------------+
double CVolumeModule::GetAverageVolume()
{
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   return avgVolume;
}

//+------------------------------------------------------------------+
//| Is Volume Spike                                                 |
//+------------------------------------------------------------------+
bool CVolumeModule::IsVolumeSpike()
{
   double ratio = GetVolumeRatio();
   bool result = ratio >= m_spikeThreshold;
   LOG_DEBUG("IsVolumeSpike: " + (result ? "YES" : "NO"), g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Is Volume Surge                                                 |
//+------------------------------------------------------------------+
bool CVolumeModule::IsVolumeSurge()
{
   double ratio = GetVolumeRatio();
   bool result = ratio >= m_surgeThreshold;
   LOG_DEBUG("IsVolumeSurge: " + (result ? "YES" : "NO"), g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Is Volume Drying                                                |
//+------------------------------------------------------------------+
bool CVolumeModule::IsVolumeDrying()
{
   double ratio = GetVolumeRatio();
   bool result = ratio <= m_decliningThreshold;
   LOG_DEBUG("IsVolumeDrying: " + (result ? "YES" : "NO"), g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Volume Condition Enum                                       |
//+------------------------------------------------------------------+
ENUM_VOLUME_CONDITION CVolumeModule::GetVolumeConditionEnum(double volRatio)
{
   if(volRatio >= m_surgeThreshold) return VOL_SURGING;
   else if(volRatio >= m_spikeThreshold) return VOL_ELEVATED;
   else if(volRatio >= m_normalThreshold) return VOL_NORMAL;
   else if(volRatio >= m_decliningThreshold) return VOL_DECLINING;
   else return VOL_DROPPING;
}

//+------------------------------------------------------------------+
//| Get Volume Condition String                                     |
//+------------------------------------------------------------------+
string CVolumeModule::GetVolumeConditionString(ENUM_VOLUME_CONDITION condition)
{
   switch(condition)
   {
      case VOL_SURGING:   return "SURGING";
      case VOL_ELEVATED:  return "ELEVATED";
      case VOL_NORMAL:    return "NORMAL";
      case VOL_DECLINING: return "DECLINING";
      case VOL_DROPPING:  return "DROPPING";
      default:            return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Get Volume Level                                                |
//+------------------------------------------------------------------+
string CVolumeModule::GetVolumeLevel(double volRatio)
{
   if(volRatio >= 2.0) return "VERY HIGH";
   else if(volRatio >= 1.5) return "HIGH";
   else if(volRatio >= 1.0) return "GOOD";
   else if(volRatio >= 0.8) return "MODERATE";
   else if(volRatio >= 0.5) return "LOW";
   else return "VERY LOW";
}

//+------------------------------------------------------------------+
//| Calculate Bull Percentage                                       |
//+------------------------------------------------------------------+
double CVolumeModule::CalculateBullPercentage(double volRatio, double priceChange)
{
   LOG_DEBUG("Calculating Bull Percentage...", g_volumeDebugMode);
   
   double bullPct = 50.0;
   
   // Base bull percentage from price change
   if(priceChange > 0)
   {
      double normalized = MathMin(priceChange / 2.0, 1.0);
      bullPct = 50.0 + (normalized * 40.0);
   }
   else if(priceChange < 0)
   {
      double normalized = MathMin(MathAbs(priceChange) / 2.0, 1.0);
      bullPct = 50.0 - (normalized * 40.0);
   }
   
   // Volume adjustment
   if(volRatio >= m_spikeThreshold)
   {
      if(priceChange > 0)
         bullPct += 10.0;
      else if(priceChange < 0)
         bullPct -= 10.0;
   }
   else if(volRatio <= m_decliningThreshold)
   {
      if(priceChange > 0)
         bullPct -= 10.0;
      else if(priceChange < 0)
         bullPct += 10.0;
   }
   
   double result = MathMin(100.0, MathMax(0.0, bullPct));
   LOG_DEBUG("  Bull%: " + DoubleToString(result, 1) + "%", g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Bull Percentage - Public                                    |
//+------------------------------------------------------------------+
double CVolumeModule::GetBullPercentage()
{
   double volRatio = GetVolumeRatio();
   double priceChange = GetPriceChange();
   
   if(m_cacheValid && m_cachedBullPct > 0)
      return m_cachedBullPct;
   
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   m_cachedBullPct = bullPct;
   return bullPct;
}

//+------------------------------------------------------------------+
//| Calculate Bear Percentage                                       |
//+------------------------------------------------------------------+
double CVolumeModule::CalculateBearPercentage(double volRatio, double priceChange)
{
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   return MathMin(100.0, MathMax(0.0, 100.0 - bullPct));
}

//+------------------------------------------------------------------+
//| Get Bear Percentage - Public                                    |
//+------------------------------------------------------------------+
double CVolumeModule::GetBearPercentage()
{
   if(m_cacheValid && m_cachedBearPct > 0)
      return m_cachedBearPct;
   
   double bearPct = 100.0 - GetBullPercentage();
   m_cachedBearPct = bearPct;
   return bearPct;
}

//+------------------------------------------------------------------+
//| Calculate Momentum Strength (0-100)                             |
//+------------------------------------------------------------------+
double CVolumeModule::CalculateMomentumStrength(double volRatio)
{
   double strength = 0;
   if(volRatio >= 2.5) strength = 100;
   else if(volRatio >= 2.0) strength = 80 + (volRatio - 2.0) / 0.5 * 20;
   else if(volRatio >= 1.5) strength = 60 + (volRatio - 1.5) / 0.5 * 20;
   else if(volRatio >= 1.0) strength = 40 + (volRatio - 1.0) / 0.5 * 20;
   else if(volRatio >= 0.8) strength = 30 + (volRatio - 0.8) / 0.2 * 10;
   else if(volRatio >= 0.5) strength = 15 + (volRatio - 0.5) / 0.3 * 15;
   else strength = 0;
   
   return MathMin(100.0, MathMax(0.0, strength));
}

//+------------------------------------------------------------------+
//| Get Momentum Strength - Public                                  |
//+------------------------------------------------------------------+
double CVolumeModule::GetMomentumStrength()
{
   if(m_cacheValid && m_cachedMomentum > 0)
      return m_cachedMomentum;
   
   double volRatio = GetVolumeRatio();
   double strength = CalculateMomentumStrength(volRatio);
   m_cachedMomentum = strength;
   LOG_DEBUG("Momentum Strength: " + DoubleToString(strength, 1) + "%", g_volumeDebugMode);
   return strength;
}

//+------------------------------------------------------------------+
//| Calculate Conviction Level (0-100)                              |
//+------------------------------------------------------------------+
double CVolumeModule::CalculateConvictionLevel(double volRatio, double priceChange)
{
   double conviction = 50.0;
   
   // Price direction conviction
   if(MathAbs(priceChange) > 1.0)
      conviction += 20.0;
   else if(MathAbs(priceChange) > 0.5)
      conviction += 10.0;
   else if(MathAbs(priceChange) < 0.1)
      conviction -= 10.0;
   
   // Volume conviction
   if(volRatio >= m_surgeThreshold)
      conviction += 30.0;
   else if(volRatio >= m_spikeThreshold)
      conviction += 20.0;
   else if(volRatio >= m_normalThreshold)
      conviction += 5.0;
   else if(volRatio <= m_decliningThreshold)
      conviction -= 20.0;
   
   // Direction alignment
   if((priceChange > 0 && volRatio >= m_spikeThreshold) ||
      (priceChange < 0 && volRatio >= m_spikeThreshold))
      conviction += 10.0;
   else if((priceChange > 0 && volRatio <= m_decliningThreshold) ||
           (priceChange < 0 && volRatio <= m_decliningThreshold))
      conviction -= 15.0;
   
   return MathMin(100.0, MathMax(0.0, conviction));
}

//+------------------------------------------------------------------+
//| Get Conviction Level - Public                                   |
//+------------------------------------------------------------------+
double CVolumeModule::GetConvictionLevel()
{
   if(m_cacheValid && m_cachedConviction > 0)
      return m_cachedConviction;
   
   double volRatio = GetVolumeRatio();
   double priceChange = GetPriceChange();
   double conviction = CalculateConvictionLevel(volRatio, priceChange);
   m_cachedConviction = conviction;
   LOG_DEBUG("Conviction Level: " + DoubleToString(conviction, 1) + "%", g_volumeDebugMode);
   return conviction;
}

//+------------------------------------------------------------------+
//| Get Volume Strength Score                                       |
//+------------------------------------------------------------------+
double CVolumeModule::GetVolumeScore()
{
   return GetMomentumStrength();
}

//+------------------------------------------------------------------+
//| Calculate Confidence - ENHANCED                                 |
//+------------------------------------------------------------------+
double CVolumeModule::CalculateConfidenceInternal(double volRatio, double priceChange, 
                                                   double bullPct, double bearPct)
{
   LOG_DEBUG("Calculating enhanced confidence...", g_volumeDebugMode);
   
   LOG_DEBUG("  VolRatio: " + DoubleToString(volRatio, 2) + "x, Price Change: " + 
             DoubleToString(priceChange, 2) + "%", g_volumeDebugMode);
   
   LOG_DEBUG("  Bull%: " + DoubleToString(bullPct, 1) + "%, Bear%: " + 
             DoubleToString(bearPct, 1) + "%", g_volumeDebugMode);
   
   // 1. Direction clarity (0-100)
   double directionClarity = MathAbs(bullPct - bearPct);
   LOG_DEBUG("  Direction Clarity: " + DoubleToString(directionClarity, 1) + "%", g_volumeDebugMode);
   
   // 2. Volume momentum strength (0-100)
   double momentumStrength = CalculateMomentumStrength(volRatio);
   LOG_DEBUG("  Momentum Strength: " + DoubleToString(momentumStrength, 1) + "%", g_volumeDebugMode);
   
   // 3. Conviction level (0-100)
   double conviction = CalculateConvictionLevel(volRatio, priceChange);
   LOG_DEBUG("  Conviction Level: " + DoubleToString(conviction, 1) + "%", g_volumeDebugMode);
   
   // 4. Base confidence (40% clarity + 40% momentum + 20% conviction)
   double baseConfidence = (directionClarity * 0.4) + (momentumStrength * 0.4) + (conviction * 0.2);
   LOG_DEBUG("  Base Confidence: " + DoubleToString(baseConfidence, 1) + "%", g_volumeDebugMode);
   
   // 5. Adjust for price movement magnitude
   if(MathAbs(priceChange) > 1.0 && volRatio >= m_normalThreshold)
   {
      baseConfidence += 10.0;
      LOG_DEBUG("  Large move with volume bonus: +10%", g_volumeDebugMode);
   }
   else if(MathAbs(priceChange) > 0.5 && volRatio >= m_spikeThreshold)
   {
      baseConfidence += 5.0;
      LOG_DEBUG("  Moderate move with high volume bonus: +5%", g_volumeDebugMode);
   }
   else if(MathAbs(priceChange) < 0.1 && volRatio >= m_spikeThreshold)
   {
      baseConfidence -= 10.0;
      LOG_DEBUG("  High volume with flat price penalty: -10%", g_volumeDebugMode);
   }
   
   // 6. Penalty for divergence
   if((priceChange > 0 && volRatio <= m_decliningThreshold) ||
      (priceChange < 0 && volRatio <= m_decliningThreshold))
   {
      baseConfidence -= 15.0;
      LOG_DEBUG("  Price/Volume divergence penalty: -15%", g_volumeDebugMode);
   }
   
   // 7. Minimum confidence
   if(directionClarity > 0 && baseConfidence < 5)
   {
      baseConfidence = 5.0;
      LOG_DEBUG("  Minimum confidence applied: 5%", g_volumeDebugMode);
   }
   
   double result = MathMin(100.0, MathMax(0.0, baseConfidence));
   LOG_DEBUG("  Final Confidence: " + DoubleToString(result, 1) + "%", g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Confidence - Public                                         |
//+------------------------------------------------------------------+
double CVolumeModule::GetConfidence()
{
   if(m_cacheValid && m_cachedConfidence > 0)
      return m_cachedConfidence;
   
   double volRatio = GetVolumeRatio();
   double priceChange = GetPriceChange();
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   double bearPct = CalculateBearPercentage(volRatio, priceChange);
   double confidence = CalculateConfidenceInternal(volRatio, priceChange, bullPct, bearPct);
   m_cachedConfidence = confidence;
   return confidence;
}

//+------------------------------------------------------------------+
//| Get Confidence - With Trend                                     |
//+------------------------------------------------------------------+
double CVolumeModule::GetConfidence(int trend)
{
   return GetConfidence();
}

//+------------------------------------------------------------------+
//| Determine Direction                                             |
//+------------------------------------------------------------------+
string CVolumeModule::DetermineDirection(double priceChange, double volRatio, double bullPct, double bearPct)
{
   LOG_DEBUG("Determining direction...", g_volumeDebugMode);
   
   // Primary: Check price direction with volume confirmation
   if(priceChange > 0.1 && volRatio >= m_normalThreshold)
   {
      LOG_DEBUG("  Price UP with good volume → BULLISH", g_volumeDebugMode);
      return "BULLISH";
   }
   else if(priceChange < -0.1 && volRatio >= m_normalThreshold)
   {
      LOG_DEBUG("  Price DOWN with good volume → BEARISH", g_volumeDebugMode);
      return "BEARISH";
   }
   
   // Secondary: Check percentage difference
   double diff = bullPct - bearPct;
   if(diff > 15)
   {
      LOG_DEBUG("  Bull% > Bear% by " + DoubleToString(diff, 1) + " → BULLISH", g_volumeDebugMode);
      return "BULLISH";
   }
   else if(diff < -15)
   {
      LOG_DEBUG("  Bear% > Bull% by " + DoubleToString(MathAbs(diff), 1) + " → BEARISH", g_volumeDebugMode);
      return "BEARISH";
   }
   
   // Tertiary: Price direction with low volume (weak signal)
   if(priceChange > 0.3)
   {
      LOG_DEBUG("  Price UP (weak volume) → BULLISH", g_volumeDebugMode);
      return "BULLISH";
   }
   else if(priceChange < -0.3)
   {
      LOG_DEBUG("  Price DOWN (weak volume) → BEARISH", g_volumeDebugMode);
      return "BEARISH";
   }
   
   LOG_DEBUG("  No clear direction → NEUTRAL", g_volumeDebugMode);
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Direction - Public                                          |
//+------------------------------------------------------------------+
string CVolumeModule::GetDirection()
{
   if(m_cacheValid && m_cachedDirection != "")
      return m_cachedDirection;
   
   double volRatio = GetVolumeRatio();
   double priceChange = GetPriceChange();
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   double bearPct = CalculateBearPercentage(volRatio, priceChange);
   string direction = DetermineDirection(priceChange, volRatio, bullPct, bearPct);
   m_cachedDirection = direction;
   LOG_DEBUG("Direction: " + direction, g_volumeDebugMode);
   return direction;
}

//+------------------------------------------------------------------+
//| Get Direction - With Trend                                      |
//+------------------------------------------------------------------+
string CVolumeModule::GetDirection(int trend)
{
   return GetDirection();
}

//+------------------------------------------------------------------+
//| Generate Description                                            |
//+------------------------------------------------------------------+
string CVolumeModule::GenerateDescription(double volRatio, ENUM_VOLUME_CONDITION condition, double bullPct, double bearPct)
{
   string volLevel = GetVolumeConditionString(condition);
   double priceChange = GetPriceChange();
   string priceDir = priceChange > 0 ? "UP" : (priceChange < 0 ? "DOWN" : "FLAT");
   
   string desc = "Volume ";
   desc += volLevel;
   desc += " (";
   desc += DoubleToString(volRatio, 2);
   desc += "x avg) with price ";
   desc += priceDir;
   
   if(bullPct > 60)
      desc += " - Bullish conviction";
   else if(bearPct > 60)
      desc += " - Bearish conviction";
   else
      desc += " - Mixed conviction";
   
   LOG_DEBUG("Description: " + desc, g_volumeDebugMode);
   return desc;
}

//+------------------------------------------------------------------+
//| Get Description - Public                                        |
//+------------------------------------------------------------------+
string CVolumeModule::GetDescription()
{
   double volRatio = GetVolumeRatio();
   ENUM_VOLUME_CONDITION condition = GetVolumeConditionEnum(volRatio);
   double bullPct = CalculateBullPercentage(volRatio, GetPriceChange());
   double bearPct = CalculateBearPercentage(volRatio, GetPriceChange());
   return GenerateDescription(volRatio, condition, bullPct, bearPct);
}

//+------------------------------------------------------------------+
//| Get Description - With Trend                                    |
//+------------------------------------------------------------------+
string CVolumeModule::GetDescription(int trend)
{
   return GetDescription();
}

//+------------------------------------------------------------------+
//| Generate Narrative                                              |
//+------------------------------------------------------------------+
string CVolumeModule::GenerateNarrative(string direction, double volRatio, double priceChange,
                                         double bullPct, double bearPct, double confidence,
                                         double momentumStrength, double convictionLevel)
{
   LOG_DEBUG("Generating narrative...", g_volumeDebugMode);
   string narrative = "";
   
   ENUM_VOLUME_CONDITION condition = GetVolumeConditionEnum(volRatio);
   string emoji;
   if(volRatio >= m_surgeThreshold) emoji = "🔥";
   else if(volRatio >= m_spikeThreshold) emoji = "⬆️";
   else if(volRatio >= m_normalThreshold) emoji = "➡️";
   else if(volRatio >= m_decliningThreshold) emoji = "⬇️";
   else emoji = "❄️";
   
   string priceDir = priceChange > 0 ? "up" : (priceChange < 0 ? "down" : "flat");
   string conditionStr = GetVolumeConditionString(condition);
   
   if(condition == VOL_SURGING)
   {
      narrative = emoji;
      narrative += " VOLUME SURGE! Volume is ";
      narrative += DoubleToString(volRatio, 2);
      narrative += "x the average. This indicates EXTREME conviction in the move. ";
      if(priceChange > 0)
      {
         narrative += "Strong buying pressure with institutional interest. ";
         if(convictionLevel >= 60)
            narrative += "High conviction in continued upward momentum.";
         else
            narrative += "Monitor for exhaustion - surges can be unsustainable.";
      }
      else if(priceChange < 0)
      {
         narrative += "Strong selling pressure with panic selling. ";
         if(convictionLevel >= 60)
            narrative += "High conviction in continued downward momentum.";
         else
            narrative += "Monitor for capitulation - sell-offs can be unsustainable.";
      }
      else
      {
         narrative += "Price is flat despite high volume - battle between buyers and sellers.";
      }
   }
   else if(condition == VOL_ELEVATED)
   {
      narrative = emoji;
      narrative += " Volume is ELEVATED at ";
      narrative += DoubleToString(volRatio, 2);
      narrative += "x average. This shows good participation in the move. ";
      if(priceChange > 0)
      {
         narrative += "Buyers are active with reasonable conviction. ";
         if(convictionLevel >= 50)
            narrative += "Confidence is good for continued upward movement.";
         else
            narrative += "Some hesitation in the buying pressure.";
      }
      else if(priceChange < 0)
      {
         narrative += "Sellers are active with reasonable conviction. ";
         if(convictionLevel >= 50)
            narrative += "Confidence is good for continued downward movement.";
         else
            narrative += "Some hesitation in the selling pressure.";
      }
      else
      {
         narrative += "Price flat with elevated volume - potential accumulation/distribution.";
      }
   }
   else if(condition == VOL_NORMAL)
   {
      narrative = emoji;
      narrative += " Volume is NORMAL (";
      narrative += DoubleToString(volRatio, 2);
      narrative += "x average). Price is moving with average participation. ";
      if(MathAbs(priceChange) > 0.5)
         narrative += "Move has normal conviction. Confidence is moderate.";
      else
         narrative += "Market is in a consolidation phase. Confidence is neutral - wait for volume expansion.";
   }
   else if(condition == VOL_DECLINING)
   {
      narrative = emoji;
      narrative += " Volume is DECLINING (";
      narrative += DoubleToString(volRatio, 2);
      narrative += "x average). Participation is decreasing. ";
      if(priceChange > 0)
      {
         narrative += "Upward move lacks conviction - buyers are fading. ";
         narrative += "Confidence is low for continued upward movement.";
      }
      else if(priceChange < 0)
      {
         narrative += "Downward move lacks conviction - sellers are fading. ";
         narrative += "Confidence is low for continued downward movement.";
      }
      else
      {
         narrative += "Market is in quiet consolidation - breakouts may be false.";
      }
   }
   else
   {
      narrative = emoji;
      narrative += " VOLUME COLLAPSED! (";
      narrative += DoubleToString(volRatio, 2);
      narrative += "x average). Extremely low participation. ";
      narrative += "Market is in a lull - low confidence in any directional move. ";
      narrative += "Be cautious of sudden breakouts with low volume.";
   }
   
   // Add confidence assessment
   if(confidence >= 60)
      narrative += " Overall confidence is HIGH.";
   else if(confidence >= 40)
      narrative += " Overall confidence is MODERATE.";
   else
      narrative += " Overall confidence is LOW - wait for volume confirmation.";
   
   // Add metrics
   string metrics = " (Bulls: ";
   metrics += DoubleToString(bullPct, 1);
   metrics += "%, Bears: ";
   metrics += DoubleToString(bearPct, 1);
   metrics += "%, Conf: ";
   metrics += DoubleToString(confidence, 1);
   metrics += "%, Conviction: ";
   metrics += DoubleToString(convictionLevel, 1);
   metrics += "%, Momentum: ";
   metrics += DoubleToString(momentumStrength, 1);
   metrics += "%)";
   narrative += metrics;
   
   LOG_DEBUG("  Narrative: " + narrative, g_volumeDebugMode);
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Narrative - Public                                          |
//+------------------------------------------------------------------+
string CVolumeModule::GetNarrative()
{
   double volRatio = GetVolumeRatio();
   double priceChange = GetPriceChange();
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   double bearPct = CalculateBearPercentage(volRatio, priceChange);
   string direction = DetermineDirection(priceChange, volRatio, bullPct, bearPct);
   double confidence = CalculateConfidenceInternal(volRatio, priceChange, bullPct, bearPct);
   double momentum = CalculateMomentumStrength(volRatio);
   double conviction = CalculateConvictionLevel(volRatio, priceChange);
   return GenerateNarrative(direction, volRatio, priceChange, bullPct, bearPct, confidence, momentum, conviction);
}

//+------------------------------------------------------------------+
//| Get Narrative - With Trend                                      |
//+------------------------------------------------------------------+
string CVolumeModule::GetNarrative(int trend)
{
   return GetNarrative();
}

//+------------------------------------------------------------------+
//| Get Complete Direction Result - ALL IN ONE!                     |
//+------------------------------------------------------------------+
SVolumeDirectionResult CVolumeModule::GetDirectionResult(int trend = 0)
{
   LOG_INFO("=== GETTING COMPLETE DIRECTION RESULT ===", g_volumeDebugMode);
   
   SVolumeDirectionResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.errorMessage = "";
   
   // Get volume data (uses cache)
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   
   if(volume <= 0 || avgVolume <= 0)
   {
      result.errorMessage = "Invalid volume data: Volume=" + DoubleToString(volume, 0) + ", Avg=" + DoubleToString(avgVolume, 0);
      LOG(result.errorMessage, true);
      return result;
   }
   
   // --- CORE COMPONENT MANAGER FIELDS ---
   result.currentVolume = volume;
   result.averageVolume = avgVolume;
   result.volumeRatio = avgVolume > 0 ? volume / avgVolume : 1.0;
   result.priceChange = priceChange;
   
   // Volume condition
   ENUM_VOLUME_CONDITION conditionEnum = GetVolumeConditionEnum(result.volumeRatio);
   result.volumeConditionEnum = conditionEnum;
   result.volumeCondition = GetVolumeConditionString(conditionEnum);
   result.isVolumeSpike = (result.volumeRatio >= m_spikeThreshold);
   result.isVolumeSurge = (result.volumeRatio >= m_surgeThreshold);
   result.isVolumeDrying = (result.volumeRatio <= m_decliningThreshold);
   
   // Calculate metrics (uses cache where possible)
   result.volumeScore = CalculateMomentumStrength(result.volumeRatio);
   result.momentumStrength = result.volumeScore;
   result.convictionLevel = CalculateConvictionLevel(result.volumeRatio, priceChange);
   
   // Calculate percentages (uses cache where possible)
   result.bullPercentage = CalculateBullPercentage(result.volumeRatio, priceChange);
   result.bearPercentage = CalculateBearPercentage(result.volumeRatio, priceChange);
   
   // Normalize to ensure total is 100%
   double total = result.bullPercentage + result.bearPercentage;
   if(total > 0 && MathAbs(total - 100.0) > 0.01)
   {
      result.bullPercentage = (result.bullPercentage / total) * 100.0;
      result.bearPercentage = (result.bearPercentage / total) * 100.0;
   }
   
   // Calculate confidence (uses cache where possible)
   result.confidence = CalculateConfidenceInternal(result.volumeRatio, priceChange,
                                                    result.bullPercentage, result.bearPercentage);
   
   // Determine direction (uses cache where possible)
   result.direction = DetermineDirection(priceChange, result.volumeRatio,
                                         result.bullPercentage, result.bearPercentage);
   
   // Generate description and narrative
   result.description = GenerateDescription(result.volumeRatio, conditionEnum,
                                             result.bullPercentage, result.bearPercentage);
   result.narrative = GenerateNarrative(result.direction, result.volumeRatio, priceChange,
                                         result.bullPercentage, result.bearPercentage,
                                         result.confidence, result.momentumStrength,
                                         result.convictionLevel);
   
   result.isValid = true;
   
   // Update cache with all calculated values
   m_cachedDirection = result.direction;
   m_cachedConfidence = result.confidence;
   m_cachedBullPct = result.bullPercentage;
   m_cachedBearPct = result.bearPercentage;
   m_cachedCondition = result.volumeCondition;
   m_cachedMomentum = result.momentumStrength;
   m_cachedConviction = result.convictionLevel;
   m_cachedVolumeRatio = result.volumeRatio;
   UpdateCache();
   
   // Log results
   LOG_DEBUG("✅ Direction Result Complete", g_volumeDebugMode);
   LOG_DEBUG("  Direction: " + result.direction, g_volumeDebugMode);
   LOG_DEBUG("  Confidence: " + DoubleToString(result.confidence, 1) + "%", g_volumeDebugMode);
   LOG_DEBUG("  Volume Ratio: " + DoubleToString(result.volumeRatio, 2) + "x", g_volumeDebugMode);
   LOG_DEBUG("  Description: " + result.description, g_volumeDebugMode);
   LOG_DEBUG("=== END DIRECTION RESULT ===", g_volumeDebugMode);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Volume Summary - For Component Manager                      |
//+------------------------------------------------------------------+
SVolumeSummary CVolumeModule::GetVolumeSummary(int trend = 0)
{
   LOG_DEBUG("Getting Volume Summary...", g_volumeDebugMode);
   
   SVolumeSummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   SVolumeDirectionResult result = GetDirectionResult(trend);
   if(!result.isValid)
   {
      LOG("Failed to get volume summary", true);
      return summary;
   }
   
   summary.direction = result.direction;
   summary.confidence = result.confidence;
   summary.bullPercentage = result.bullPercentage;
   summary.bearPercentage = result.bearPercentage;
   summary.currentVolume = result.currentVolume;
   summary.averageVolume = result.averageVolume;
   summary.volumeRatio = result.volumeRatio;
   summary.priceChange = result.priceChange;
   summary.volumeCondition = result.volumeCondition;
   summary.convictionLevel = result.convictionLevel;
   
   // Generate short description
   string emoji;
   if(result.volumeRatio >= m_surgeThreshold) emoji = "🔥";
   else if(result.volumeRatio >= m_spikeThreshold) emoji = "⬆️";
   else if(result.volumeRatio >= m_normalThreshold) emoji = "➡️";
   else if(result.volumeRatio >= m_decliningThreshold) emoji = "⬇️";
   else emoji = "❄️";
   
   string directionEmoji;
   if(summary.direction == "BULLISH") directionEmoji = "📈";
   else if(summary.direction == "BEARISH") directionEmoji = "📉";
   else directionEmoji = "➡️";
   
   string shortDesc = directionEmoji;
   shortDesc += " ";
   shortDesc += summary.direction;
   shortDesc += " | Vol: ";
   shortDesc += DoubleToString(summary.volumeRatio, 2);
   shortDesc += "x ";
   shortDesc += emoji;
   shortDesc += " | Bulls: ";
   shortDesc += DoubleToString(summary.bullPercentage, 0);
   shortDesc += "% | Bears: ";
   shortDesc += DoubleToString(summary.bearPercentage, 0);
   shortDesc += "%";
   
   if(summary.confidence >= 60)
      shortDesc += " - High confidence";
   else if(summary.confidence >= 40)
      shortDesc += " - Medium confidence";
   else
      shortDesc += " - Low confidence";
   
   summary.shortDescription = shortDesc;
   summary.fullDescription = result.description;
   summary.isValid = true;
   
   LOG_DEBUG("  Summary: " + shortDesc, g_volumeDebugMode);
   return summary;
}

//+------------------------------------------------------------------+
//| Get Summary String - Quick display                              |
//+------------------------------------------------------------------+
string CVolumeModule::GetSummaryString(int trend = 0)
{
   LOG_DEBUG("Getting Summary String...", g_volumeDebugMode);
   
   SVolumeSummary summary = GetVolumeSummary(trend);
   if(!summary.isValid)
   {
      LOG_WARNING("Invalid summary");
      return "Volume: N/A";
   }
   
   string directionSymbol = "";
   if(summary.direction == "BULLISH") directionSymbol = "📈";
   else if(summary.direction == "BEARISH") directionSymbol = "📉";
   else directionSymbol = "➡️";
   
   string result = "Vol: ";
   result += DoubleToString(summary.volumeRatio, 2);
   result += "x | ";
   result += directionSymbol;
   result += " ";
   result += summary.direction;
   result += " | Conf: ";
   result += DoubleToString(summary.confidence, 0);
   result += "% | ";
   result += summary.volumeCondition;
   
   LOG_DEBUG("  Summary: " + result, g_volumeDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Set Debug                                                       |
//+------------------------------------------------------------------+
void CVolumeModule::SetDebug(bool enable)
{
   LOG_INFO("Setting debug mode to: " + (enable ? "ON" : "OFF"), g_volumeDebugMode);
   m_debug = enable;
   LOG_INFO("Debug mode " + (enable ? "ENABLED" : "DISABLED"), g_volumeDebugMode);
}

//+------------------------------------------------------------------+
//| Print Status - Full debug output                                |
//+------------------------------------------------------------------+
void CVolumeModule::PrintStatus(int trend = 0)
{
   string separator = "=== ";
   string indent = "   ";
   
   Print(separator + "VOLUME MODULE STATUS " + separator);
   Print(indent + "Symbol: " + m_symbol);
   Print(indent + "Timeframe: " + EnumToString(m_timeframe));
   Print(indent + "Initialized: " + (m_initialized ? "YES" : "NO"));
   Print(indent + "Debug: " + (m_debug ? "ON" : "OFF"));
   Print(indent + "Last Error: " + m_lastError);
   Print(indent + "Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s");
   Print(indent + "Cache Valid: " + (m_cacheValid ? "YES" : "NO"));
   Print(indent + "Cache Age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s");
   Print(indent + "Thresholds: Surge=" + DoubleToString(m_surgeThreshold, 1) + 
         ", Spike=" + DoubleToString(m_spikeThreshold, 1) +
         ", Normal=" + DoubleToString(m_normalThreshold, 1) +
         ", Declining=" + DoubleToString(m_decliningThreshold, 1));
   
   SVolumeDirectionResult result = GetDirectionResult(trend);
   if(result.isValid)
   {
      Print(indent + "Current Volume: " + DoubleToString(result.currentVolume, 0));
      Print(indent + "Average Volume: " + DoubleToString(result.averageVolume, 0));
      Print(indent + "Volume Ratio: " + DoubleToString(result.volumeRatio, 2) + "x");
      Print(indent + "Price Change: " + DoubleToString(result.priceChange, 2) + "%");
      Print(indent + "Condition: " + result.volumeCondition);
      Print(indent + "Direction: " + result.direction);
      Print(indent + "Confidence: " + DoubleToString(result.confidence, 1) + "%");
      Print(indent + "Bull%: " + DoubleToString(result.bullPercentage, 1) + "%");
      Print(indent + "Bear%: " + DoubleToString(result.bearPercentage, 1) + "%");
      Print(indent + "Volume Score: " + DoubleToString(result.volumeScore, 1) + "%");
      Print(indent + "Momentum: " + DoubleToString(result.momentumStrength, 1) + "%");
      Print(indent + "Conviction: " + DoubleToString(result.convictionLevel, 1) + "%");
      Print(indent + "Volume Spike: " + (result.isVolumeSpike ? "YES" : "NO"));
      Print(indent + "Volume Surge: " + (result.isVolumeSurge ? "YES" : "NO"));
      Print(indent + "Volume Drying: " + (result.isVolumeDrying ? "YES" : "NO"));
      Print(indent + "Description: " + result.description);
      Print(indent + "Narrative: " + result.narrative);
   }
   else
   {
      Print(indent + "❌ Unable to get Volume values");
      Print(indent + "Error: " + result.errorMessage);
   }
   Print(separator + "END STATUS " + separator);
}

//+------------------------------------------------------------------+
//| Debug Print Volume - Detailed debug output                      |
//+------------------------------------------------------------------+
void CVolumeModule::DebugPrintVolume(int trend = 0)
{
   LOG_INFO("=== DEBUG PRINT VOLUME ===", g_volumeDebugMode);
   
   double volume, avgVolume, priceChange;
   GetVolumeData(volume, avgVolume, priceChange);
   
   if(volume <= 0 || avgVolume <= 0)
   {
      LOG("Invalid volume data", true);
      return;
   }
   
   double volRatio = avgVolume > 0 ? volume / avgVolume : 1.0;
   double bullPct = CalculateBullPercentage(volRatio, priceChange);
   double bearPct = CalculateBearPercentage(volRatio, priceChange);
   double confidence = CalculateConfidenceInternal(volRatio, priceChange, bullPct, bearPct);
   double momentum = CalculateMomentumStrength(volRatio);
   double conviction = CalculateConvictionLevel(volRatio, priceChange);
   string direction = DetermineDirection(priceChange, volRatio, bullPct, bearPct);
   ENUM_VOLUME_CONDITION condition = GetVolumeConditionEnum(volRatio);
   string conditionStr = GetVolumeConditionString(condition);
   
   Print("=== VOLUME DEBUG ===");
   Print("  Symbol: " + m_symbol);
   Print("  Timeframe: " + EnumToString(m_timeframe));
   Print("  Cache Status: " + (m_cacheValid ? "VALID (age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)" : "INVALID"));
   Print("  Current Volume: " + DoubleToString(volume, 0));
   Print("  Average Volume: " + DoubleToString(avgVolume, 0));
   Print("  Volume Ratio: " + DoubleToString(volRatio, 2) + "x");
   Print("  Price Change: " + DoubleToString(priceChange, 2) + "%");
   Print("  Condition: " + conditionStr);
   Print("  Direction: " + direction);
   Print("  Confidence: " + DoubleToString(confidence, 1) + "%");
   Print("  Bull%: " + DoubleToString(bullPct, 1) + "%");
   Print("  Bear%: " + DoubleToString(bearPct, 1) + "%");
   Print("  Volume Score: " + DoubleToString(CalculateMomentumStrength(volRatio), 1) + "%");
   Print("  Conviction: " + DoubleToString(conviction, 1) + "%");
   Print("  Momentum: " + DoubleToString(momentum, 1) + "%");
   Print("  Spike: " + (volRatio >= m_spikeThreshold ? "YES" : "NO"));
   Print("  Surge: " + (volRatio >= m_surgeThreshold ? "YES" : "NO"));
   Print("  Drying: " + (volRatio <= m_decliningThreshold ? "YES" : "NO"));
   Print("  Description: " + GetDescription());
   Print("=================");
   
   LOG_INFO("=== DEBUG PRINT COMPLETE ===", g_volumeDebugMode);
}