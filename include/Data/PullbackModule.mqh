//+------------------------------------------------------------------+
//|                      PullbackModule.mqh                         |
//|                    Pullback Calculation Module                   |
//|                    v3.1 - CLEAN ZONE SCORING ONLY              |
//|                    FIXED SCORES - NO CALCULATIONS              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.1"

#include "../Headers/Enums.mqh"
#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// PULLBACK MODULE INDEPENDENT TOGGLE
// ============================================================
bool g_pullbackDebugMode = false;

//+------------------------------------------------------------------+
//| Pullback Module Class                                           |
//+------------------------------------------------------------------+
class CPullbackModule
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_rangeBars;
   CTrendManager* m_trendManager;
   bool     m_debugEnabled;
   
   // ================================================================
   // SINGLE SOURCE OF TRUTH FOR TREND
   // ================================================================
   int      m_currentTrend;          // 1=BULLISH, -1=BEARISH, 0=NEUTRAL
   datetime m_currentTrendTime;
   bool     m_hasValidTrend;
   int      m_lastValidTrend;
   datetime m_lastValidTrendTime;
   
   // ================================================================
   // CACHED VALUES FOR SPEED
   // ================================================================
   double   m_lastPullbackPercent;
   int      m_lastPullbackScore;
   string   m_lastPullbackZone;
   RangeData m_cachedRange;
   datetime m_lastRangeTime;
   bool     m_hasCachedRange;
   
   // ================================================================
   // ZONE DEFINITIONS - FIXED SCORES (NO CALCULATIONS)
   // ================================================================
   struct ZoneDefinition
   {
      double low;
      double high;
      int score;
      string name;
      string shortName;
   };
   
   ZoneDefinition m_zones[9];  // 9 zones
   int m_zoneCount;
   
   // ================================================================
   // PRIVATE METHODS
   // ================================================================
   void     UpdateTrend();
   int      GetTrend();
   int      GetTrendForCalculation();
   bool     IsTrendValid();
   string   TrendToString(int trend);
   
   // Zone initialization - FIXED SCORES
   void     AddZone(double low, double high, int score, string name, string shortName);
   void     InitializeZones();
   
   // Scoring - DIRECT LOOKUP ONLY (NO CALCULATIONS)
   int      GetScoreByZone(double pullbackPercent);
   
   // Range detection with caching
   bool     DetectRangeCached(RangeData &range);
   double   GetRangeInPips(RangeData &range);
   string   GetZoneCategory(double adjustedPercent);
   int      GetZoneLevel(double adjustedPercent);
   string   GetPullbackZoneDescription(double pullbackPercent, int trend);
   string   GenerateAction(double adjustedPercent, double confidence);
   string   GenerateRiskLevel(double adjustedPercent, double confidence);
   string   GenerateDetailedNarrative(RangeData &range, int trend, double confidence);
   
public:
   CPullbackModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int rangeBars = 25);
   ~CPullbackModule();
   
   bool Initialize();
   void SetTrendManager(CTrendManager* trendManager);
   void EnableDebug(bool enable) { m_debugEnabled = enable; }
   
   // Static debug control
   static void SetGlobalDebug(bool enable) { g_pullbackDebugMode = enable; }
   static bool GetGlobalDebug() { return g_pullbackDebugMode; }
   
   // Main public methods
   RangeData DetectRange();
   bool IsInSweetZone(RangeData &range, int trend);
   int GetPullbackScore(RangeData &range, int trend);
   string GetPullbackZone(RangeData &range, int trend);
   double GetPullbackScoreProximity(int trend, RangeData &range);
   void GetDrawLines(RangeData &range, double &line40, double &line80, int trend);
   
   // Direct access
   int GetLastPullbackScore() const { return m_lastPullbackScore; }
   double GetLastPullbackPercent() const { return m_lastPullbackPercent; }
   string GetLastPullbackZone() const { return m_lastPullbackZone; }
   
   // Analysis methods
   SPullbackAnalysisResult GetPullbackAnalysis();
   SPullbackSummary GetPullbackSummary();
   SPullbackDrawingData GetDrawingData();
   
   // Utility methods
   double GetWeightedDisagreement() { return 0.0; }
   double GetWeightedAgreement() { return 0.0; }
   double GetPositionMultiplier() { return 1.0; }
   double GetBaseConfidence();
   double GetFinalConfidence();
   int GetTrendPublic();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CPullbackModule::CPullbackModule(string symbol, ENUM_TIMEFRAMES tf, int rangeBars)
{
   LOG_DEBUG("🔧 CPullbackModule v3.1 (Clean Zone) initializing for " + (symbol == NULL ? _Symbol : symbol), 
             g_pullbackDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_rangeBars = rangeBars;
   m_trendManager = NULL;
   m_debugEnabled = g_pullbackDebugMode;
   m_hasCachedRange = false;
   m_lastRangeTime = 0;
   m_zoneCount = 0;
   
   // Trend state
   m_currentTrend = 0;
   m_currentTrendTime = 0;
   m_hasValidTrend = false;
   m_lastValidTrend = 0;
   m_lastValidTrendTime = 0;
   
   // Last values
   m_lastPullbackPercent = 0;
   m_lastPullbackScore = 0;
   m_lastPullbackZone = "UNKNOWN";
   
   // Initialize zones
   InitializeZones();
   
   LOG_DEBUG("🔧 CPullbackModule v3.1 (Clean Zone) initialized for " + m_symbol + 
             " | Range Bars: " + IntegerToString(m_rangeBars), 
             g_pullbackDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CPullbackModule::~CPullbackModule() 
{
   LOG_DEBUG("🔧 CPullbackModule destroyed for " + m_symbol, g_pullbackDebugMode);
}

//+------------------------------------------------------------------+
//| INITIALIZE ZONES - FIXED SCORES (NO CALCULATIONS)              |
//| Each zone has a pre-defined score. No math involved.           |
//+------------------------------------------------------------------+
void CPullbackModule::InitializeZones()
{
   m_zoneCount = 0;
   
   // ──────────────────────────────────────────────────────────────
   // ZONE DEFINITIONS - FIXED SCORES ONLY
   // No calculations, just direct lookup by pullback percentage
   // ──────────────────────────────────────────────────────────────
   
   // Zone 1: PERFECT PEAK (76-80%) → Score 100
   AddZone(76.0, 80.0, 100, "PERFECT PEAK ★★★", "PEAK");
   
   // Zone 2: EXCELLENT (72-84%) → Score 92
   AddZone(72.0, 84.0, 92, "EXCELLENT ★★", "EXCL");
   
   // Zone 3: SWEET (65-90%) → Score 80
   AddZone(65.0, 90.0, 80, "SWEET ★", "SWEET");
   
   // Zone 4: NEAR SWEET (60-95%) → Score 72
   AddZone(60.0, 95.0, 72, "NEAR SWEET", "N-SWT");
   
   // Zone 5: EDGE (55-95%) → Score 65
   AddZone(55.0, 95.0, 65, "EDGE", "EDGE");
   
   // Zone 6: TRANSITION (40-98%) → Score 45
   AddZone(40.0, 98.0, 45, "TRANSITION", "TRANS");
   
   // Zone 7: TRANSITION EDGE (25-100%) → Score 35
   AddZone(25.0, 100.0, 35, "TRANSITION EDGE", "T-EDGE");
   
   // Zone 8: EXTREME (10-100%) → Score 25
   AddZone(10.0, 100.0, 25, "EXTREME", "EXT");
   
   // Zone 9: VERY EXTREME (0-20%) → Score 15
   AddZone(0.0, 20.0, 15, "VERY EXTREME", "V-EXT");
   
   LOG_DEBUG("✅ " + IntegerToString(m_zoneCount) + " zones initialized with fixed scores", 
             g_pullbackDebugMode);
}

//+------------------------------------------------------------------+
//| Helper to add zone definition                                   |
//+------------------------------------------------------------------+
void CPullbackModule::AddZone(double low, double high, int score, 
                              string name, string shortName)
{
   if(m_zoneCount >= 9) return;
   
   m_zones[m_zoneCount].low = low;
   m_zones[m_zoneCount].high = high;
   m_zones[m_zoneCount].score = score;
   m_zones[m_zoneCount].name = name;
   m_zones[m_zoneCount].shortName = shortName;
   m_zoneCount++;
}

//+------------------------------------------------------------------+
//| GET SCORE BY ZONE - DIRECT LOOKUP (NO CALCULATIONS)            |
//| O(n) where n = number of zones (max 9)                         |
//| Returns: FIXED score from zone definition                       |
//+------------------------------------------------------------------+
int CPullbackModule::GetScoreByZone(double pullbackPercent)
{
   // Direct zone lookup - no calculations
   for(int i = 0; i < m_zoneCount; i++)
   {
      if(pullbackPercent >= m_zones[i].low && pullbackPercent <= m_zones[i].high)
         return m_zones[i].score;
   }
   
   // Fallback: if no zone matches, return 0
   return 0;
}

//+------------------------------------------------------------------+
//| GET PULLBACK SCORE - Direct lookup only                        |
//+------------------------------------------------------------------+
int CPullbackModule::GetPullbackScore(RangeData &range, int trend)
{
   double p = range.pullbackPercent;
   
   // DIRECT ZONE LOOKUP - NO CALCULATIONS
   int score = GetScoreByZone(p);
   
   // Store for later
   m_lastPullbackScore = score;
   m_lastPullbackPercent = p;
   
   LOG_DEBUG(StringFormat("🎯 Score: %.1f%% → %d (Fixed zone lookup)", p, score),
             g_pullbackDebugMode);
   
   return score;
}

//+------------------------------------------------------------------+
//| DETECT RANGE WITH CACHING                                      |
//+------------------------------------------------------------------+
bool CPullbackModule::DetectRangeCached(RangeData &range)
{
   datetime currentTime = TimeCurrent();
   
   // Return cached range if less than 1 second old
   if(m_hasCachedRange && (currentTime - m_lastRangeTime) < 1)
   {
      range = m_cachedRange;
      return range.isValid;
   }
   
   // Detect new range
   range = DetectRange();
   
   // Cache the result
   if(range.isValid)
   {
      m_cachedRange = range;
      m_lastRangeTime = currentTime;
      m_hasCachedRange = true;
   }
   
   return range.isValid;
}

//+------------------------------------------------------------------+
//| DETECT RANGE                                                   |
//+------------------------------------------------------------------+
RangeData CPullbackModule::DetectRange()
{
   RangeData range;
   range.rangeHigh = 0;
   range.rangeLow = DBL_MAX;
   range.rangeSize = 0;
   range.currentPrice = 0;
   range.pullbackPercent = 0;
   range.pullbackScore = 0;
   range.pullbackZone = "";
   range.isValid = false;
   
   double highBuffer[], lowBuffer[];
   ArraySetAsSeries(highBuffer, true);
   ArraySetAsSeries(lowBuffer, true);
   
   // Use cache if available
   if(m_hasCachedRange)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime - m_lastRangeTime < 1)
      {
         double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double priceMove = MathAbs(currentPrice - m_cachedRange.currentPrice) / 
                           (m_cachedRange.rangeSize + 0.00001);
         
         if(priceMove < 0.05)
            return m_cachedRange;
      }
   }
   
   // Copy data
   if(CopyHigh(m_symbol, m_timeframe, 0, m_rangeBars, highBuffer) < m_rangeBars ||
      CopyLow(m_symbol, m_timeframe, 0, m_rangeBars, lowBuffer) < m_rangeBars)
   {
      LOG_WARNING("⚠️ Failed to copy price data for " + m_symbol);
      return range;
   }
   
   // Find range
   for(int i = 0; i < m_rangeBars; i++)
   {
      if(highBuffer[i] > range.rangeHigh) range.rangeHigh = highBuffer[i];
      if(lowBuffer[i] < range.rangeLow) range.rangeLow = lowBuffer[i];
   }
   
   range.rangeSize = range.rangeHigh - range.rangeLow;
   double pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   if(range.rangeSize < pointValue * 10)
   {
      range.isValid = false;
      LOG_DEBUG("⚠️ Range too small: " + DoubleToString(range.rangeSize/pointValue, 1) + " pips", 
                g_pullbackDebugMode);
      return range;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   range.currentPrice = currentPrice;
   
   // Get trend
   int trend = GetTrendForCalculation();
   
   if(range.rangeSize > 0)
   {
      double rawPercent = ((range.rangeHigh - currentPrice) / range.rangeSize) * 100;
      rawPercent = MathMax(0.0, MathMin(100.0, rawPercent));
      
      if(trend == 1)
         range.pullbackPercent = rawPercent;
      else if(trend == -1)
         range.pullbackPercent = 100 - rawPercent;
      else
         range.pullbackPercent = rawPercent;
   }
   
   // FIXED SCORE LOOKUP - NO CALCULATIONS
   range.pullbackScore = GetScoreByZone(range.pullbackPercent);
   range.pullbackZone = GetPullbackZoneDescription(range.pullbackPercent, trend);
   range.isValid = true;
   
   // Store last values
   m_lastPullbackPercent = range.pullbackPercent;
   m_lastPullbackScore = range.pullbackScore;
   m_lastPullbackZone = range.pullbackZone;
   
   LOG_DEBUG(StringFormat("📊 Range: %.1f pips | Pullback: %.1f%% → Score: %d (Fixed)",
                          range.rangeSize/pointValue, range.pullbackPercent, range.pullbackScore),
             g_pullbackDebugMode);
   
   return range;
}

//+------------------------------------------------------------------+
//| TREND MANAGEMENT                                                |
//+------------------------------------------------------------------+
void CPullbackModule::UpdateTrend()
{
   bool needsUpdate = false;
   datetime currentTime = TimeCurrent();
   
   if(m_currentTrendTime == 0) 
      needsUpdate = true;
   if(currentTime - m_currentTrendTime > 60) 
      needsUpdate = true;
   if(m_trendManager != NULL && m_currentTrend == 0 && m_currentTrendTime > 0) 
      needsUpdate = true;
   
   if(!needsUpdate)
   {
      if(m_currentTrend == 0 && m_hasValidTrend && m_lastValidTrend != 0)
      {
         int cacheAgeSeconds = (int)(currentTime - m_lastValidTrendTime);
         if(cacheAgeSeconds < 3600)
         {
            m_currentTrend = m_lastValidTrend;
            m_currentTrendTime = m_lastValidTrendTime;
         }
      }
      return;
   }
   
   if(m_trendManager != NULL)
   {
      string direction = m_trendManager.GetDirection();
      int newTrend = 0;
      
      if(direction == "BULLISH") newTrend = 1;
      else if(direction == "BEARISH") newTrend = -1;
      else newTrend = 0;
      
      if(newTrend != 0)
      {
         m_currentTrend = newTrend;
         m_currentTrendTime = currentTime;
         m_hasValidTrend = true;
         m_lastValidTrend = newTrend;
         m_lastValidTrendTime = currentTime;
         LOG_DEBUG("📈 Trend updated: " + TrendToString(newTrend), g_pullbackDebugMode);
      }
      else
      {
         if(m_hasValidTrend && m_lastValidTrend != 0)
         {
            int cacheAgeSeconds = (int)(currentTime - m_lastValidTrendTime);
            if(cacheAgeSeconds < 3600)
            {
               m_currentTrend = m_lastValidTrend;
               m_currentTrendTime = m_lastValidTrendTime;
               LOG_DEBUG("📈 Using cached trend: " + TrendToString(m_currentTrend), 
                         g_pullbackDebugMode);
               return;
            }
         }
         m_currentTrend = 0;
         m_currentTrendTime = currentTime;
         LOG_DEBUG("⚠️ No valid trend - set to NEUTRAL", g_pullbackDebugMode);
      }
   }
   else
   {
      if(m_hasValidTrend && m_lastValidTrend != 0)
      {
         int cacheAgeSeconds = (int)(currentTime - m_lastValidTrendTime);
         if(cacheAgeSeconds < 3600)
         {
            m_currentTrend = m_lastValidTrend;
            m_currentTrendTime = m_lastValidTrendTime;
            LOG_DEBUG("📈 Using fallback trend: " + TrendToString(m_currentTrend), 
                      g_pullbackDebugMode);
         }
         else
         {
            m_currentTrend = 0;
            m_currentTrendTime = currentTime;
            LOG_DEBUG("⚠️ Trend cache expired - set to NEUTRAL", g_pullbackDebugMode);
         }
      }
      else if(m_currentTrendTime == 0)
      {
         m_currentTrend = 0;
         m_currentTrendTime = currentTime;
         LOG_DEBUG("⚠️ No TrendManager - set to NEUTRAL", g_pullbackDebugMode);
      }
   }
}

int CPullbackModule::GetTrend()
{
   UpdateTrend();
   return m_currentTrend;
}

int CPullbackModule::GetTrendForCalculation()
{
   int trend = GetTrend();
   if(trend == 0 && m_hasValidTrend && m_lastValidTrend != 0)
   {
      int cacheAge = (int)(TimeCurrent() - m_lastValidTrendTime);
      if(cacheAge < 3600) return m_lastValidTrend;
   }
   return trend;
}

bool CPullbackModule::IsTrendValid()
{
   return (GetTrend() != 0);
}

string CPullbackModule::TrendToString(int trend)
{
   if(trend == 1) return "BULLISH";
   if(trend == -1) return "BEARISH";
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| ZONE HELPERS                                                    |
//+------------------------------------------------------------------+
string CPullbackModule::GetPullbackZoneDescription(double pullbackPercent, int trend)
{
   string zone = "";
   
   for(int i = 0; i < m_zoneCount; i++)
   {
      if(pullbackPercent >= m_zones[i].low && pullbackPercent <= m_zones[i].high)
      {
         zone = m_zones[i].name;
         break;
      }
   }
   
   if(zone == "") zone = "UNKNOWN";
   
   string prefix = "";
   if(trend == 1) prefix = "BULLISH: ";
   else if(trend == -1) prefix = "BEARISH: ";
   else prefix = "NEUTRAL: ";
   
   string result = prefix + zone;
   m_lastPullbackZone = result;
   return result;
}

string CPullbackModule::GetZoneCategory(double adjustedPercent)
{
   for(int i = 0; i < m_zoneCount; i++)
   {
      if(adjustedPercent >= m_zones[i].low && adjustedPercent <= m_zones[i].high)
         return m_zones[i].name;
   }
   return "UNKNOWN";
}

int CPullbackModule::GetZoneLevel(double adjustedPercent)
{
   for(int i = 0; i < m_zoneCount; i++)
   {
      if(adjustedPercent >= m_zones[i].low && adjustedPercent <= m_zones[i].high)
         return m_zoneCount - i;
   }
   return 1;
}

//+------------------------------------------------------------------+
//| GENERATE NARRATIVE                                              |
//+------------------------------------------------------------------+
string CPullbackModule::GenerateDetailedNarrative(RangeData &range, int trend, double confidence)
{
   double adjustedPercent = range.pullbackPercent;
   string zoneCategory = GetZoneCategory(adjustedPercent);
   string trendText = trend == 1 ? "bullish" : (trend == -1 ? "bearish" : "neutral");
   string trendArrow = trend == 1 ? "📈" : (trend == -1 ? "📉" : "➡️");
   string narrative = "";
   
   int level = GetZoneLevel(adjustedPercent);
   
   switch(level)
   {
      case 9:
         narrative = StringFormat("%s PERFECT PEAK ZONE! Price at optimal %.1f%% retracement (76-80%%). "
                                  "This is the HIGHEST PROBABILITY entry point for %s continuation.",
                                  trendArrow, adjustedPercent, trendText);
         if(confidence >= 60) narrative += " Exceptional conditions - strong confidence.";
         else if(confidence >= 45) narrative += " Good setup with favorable risk-reward.";
         else narrative += " Monitor for confirmation before entering.";
         break;
      case 8:
         narrative = StringFormat("%s EXCELLENT ZONE. Price at %.1f%% retracement (72-84%%) - very strong area.",
                                  trendArrow, adjustedPercent);
         if(confidence >= 55) narrative += " High confidence setup with excellent risk-reward.";
         else if(confidence >= 40) narrative += " Good setup, near optimal levels.";
         else narrative += " Consider waiting for the perfect peak (76-80%).";
         break;
      case 7:
         narrative = StringFormat("%s SWEET ZONE at %.1f%%. Price well within the sweet spot (65-90%%).",
                                  trendArrow, adjustedPercent);
         if(confidence >= 45) narrative += " Confident setup with favorable risk-reward.";
         else if(confidence >= 30) narrative += " Moderate confidence - acceptable entry.";
         else narrative += " Monitor for better entry closer to 78%.";
         break;
      case 6:
         narrative = StringFormat("%s NEAR SWEET ZONE at %.1f%%. Price approaching the sweet zone (60-95%%).",
                                  trendArrow, adjustedPercent);
         if(confidence >= 40) narrative += " Good setup - consider reduced position size.";
         else narrative += " Better to wait for price to enter the sweet zone (65-90%).";
         break;
      case 5:
         narrative = StringFormat("%s EDGE ZONE at %.1f%%. Price at the edge of the sweet zone (55-95%%).",
                                  trendArrow, adjustedPercent);
         if(confidence >= 35) narrative += " Consider reduced position size or wait for deeper pullback.";
         else narrative += " Better to wait for price to enter the sweet zone (65-90%).";
         break;
      case 4:
         narrative = StringFormat("%s TRANSITION ZONE at %.1f%%. Price is transitioning between zones.",
                                  trendArrow, adjustedPercent);
         narrative += " Wait for price to reach the sweet zone (65-90%) before entering.";
         break;
      case 3:
         narrative = StringFormat("%s TRANSITION EDGE at %.1f%%. Price is near the transition boundary.",
                                  trendArrow, adjustedPercent);
         narrative += " Strongly consider waiting for better entry conditions.";
         break;
      case 2:
         narrative = StringFormat("%s EXTREME ZONE at %.1f%%. Price is at extreme levels.",
                                  trendArrow, adjustedPercent);
         narrative += " Avoid entering - wait for price to move into better zones.";
         break;
      default:
         narrative = StringFormat("%s VERY EXTREME ZONE at %.1f%%. Price is at very extreme levels.",
                                  trendArrow, adjustedPercent);
         narrative += " AVOID entering - very poor risk-reward.";
         break;
   }
   
   if(confidence >= 60) narrative += " Overall confidence is HIGH.";
   else if(confidence >= 40) narrative += " Overall confidence is MODERATE.";
   else if(confidence >= 25) narrative += " Overall confidence is LOW.";
   else narrative += " Overall confidence is VERY LOW.";
   
   return narrative;
}

//+------------------------------------------------------------------+
//| GENERATE ACTION                                                 |
//+------------------------------------------------------------------+
string CPullbackModule::GenerateAction(double adjustedPercent, double confidence)
{
   // Use zone lookup
   int score = GetScoreByZone(adjustedPercent);
   
   if(score >= 100 && confidence >= 55) return "ENTER FULL - PERFECT PEAK";
   if(score >= 92 && confidence >= 45)  return "ENTER STD - EXCELLENT";
   if(score >= 80 && confidence >= 35)  return "ENTER STD - SWEET ZONE";
   if(score >= 72 && confidence >= 30)  return "REDUCED POSITION - NEAR SWEET";
   if(score >= 65 && confidence >= 25)  return "REDUCED POSITION - EDGE";
   if(score >= 45 && confidence >= 20)  return "WAIT - MONITOR";
   return "AVOID - POOR CONDITIONS";
}

//+------------------------------------------------------------------+
//| GENERATE RISK LEVEL                                             |
//+------------------------------------------------------------------+
string CPullbackModule::GenerateRiskLevel(double adjustedPercent, double confidence)
{
   int score = GetScoreByZone(adjustedPercent);
   
   if(score >= 100 && confidence >= 55) return "Very Low";
   if(score >= 92 && confidence >= 45)  return "Low";
   if(score >= 80 && confidence >= 35)  return "Low-Medium";
   if(score >= 72 && confidence >= 30)  return "Medium";
   if(score >= 65 && confidence >= 25)  return "Medium-High";
   if(score >= 45 && confidence >= 20)  return "High";
   return "Very High";
}

//+------------------------------------------------------------------+
//| OTHER PUBLIC METHODS                                            |
//+------------------------------------------------------------------+

bool CPullbackModule::IsInSweetZone(RangeData &range, int trend)
{
   double p = range.pullbackPercent;
   return (p >= 65 && p <= 90);
}

double CPullbackModule::GetPullbackScoreProximity(int trend, RangeData &range)
{
   double p = range.pullbackPercent;
   
   // Direct zone lookup
   int score = GetScoreByZone(p);
   
   // Convert score to proximity (0-100)
   return (double)score;
}

void CPullbackModule::GetDrawLines(RangeData &range, double &line40, double &line80, int trend)
{
   if(trend == 1)
   {
      line40 = range.rangeHigh - (range.rangeSize * 0.40);
      line80 = range.rangeHigh - (range.rangeSize * 0.80);
   }
   else if(trend == -1)
   {
      line40 = range.rangeLow + (range.rangeSize * 0.40);
      line80 = range.rangeLow + (range.rangeSize * 0.80);
   }
   else
   {
      line40 = range.rangeLow + (range.rangeSize * 0.40);
      line80 = range.rangeLow + (range.rangeSize * 0.40);
   }
}

string CPullbackModule::GetPullbackZone(RangeData &range, int trend)
{
   return GetPullbackZoneDescription(range.pullbackPercent, trend);
}

//+------------------------------------------------------------------+
//| GET PULLBACK ANALYSIS                                           |
//+------------------------------------------------------------------+
SPullbackAnalysisResult CPullbackModule::GetPullbackAnalysis()
{
   SPullbackAnalysisResult result;
   ZeroMemory(result);
   
   RangeData range;
   if(!DetectRangeCached(range))
   {
      result.confidence = 0;
      result.description = "No valid range";
      result.narrative = "Wait for range to form";
      result.action = "Wait";
      result.riskLevel = "High";
      result.showOnChart = false;
      return result;
   }
   
   int trend = GetTrendForCalculation();
   double adjustedPercent = range.pullbackPercent;
   int pullbackScore = range.pullbackScore;
   double zoneProximity = (double)pullbackScore;
   
   result.confidence = MathMin(100.0, MathMax(0.0, (double)pullbackScore));
   result.pullbackScore = pullbackScore;
   result.zoneProximity = zoneProximity;
   result.pullbackPercent = range.pullbackPercent;
   result.adjustedPercent = adjustedPercent;
   result.pullbackZone = range.pullbackZone;
   result.zoneCategory = GetZoneCategory(adjustedPercent);
   result.zoneLevel = GetZoneLevel(adjustedPercent);
   result.inSweetZone = IsInSweetZone(range, trend);
   result.inPerfectZone = (adjustedPercent >= 76 && adjustedPercent <= 80);
   result.currentPrice = range.currentPrice;
   result.rangeHigh = range.rangeHigh;
   result.rangeLow = range.rangeLow;
   
   GetDrawLines(range, result.line40, result.line80, trend);
   result.linePerfectLow = result.line40 + (range.rangeSize * 0.35);
   result.linePerfectHigh = result.line40 + (range.rangeSize * 0.45);
   
   string trendText = TrendToString(trend);
   result.description = StringFormat("%s Pullback: %.1f%% (Score: %d) | Zone: %s", 
                                    trendText, adjustedPercent, pullbackScore, result.zoneCategory);
   result.shortNarrative = StringFormat("%s %.0f%% (Score: %d)", 
                                       result.zoneCategory, adjustedPercent, pullbackScore);
   result.action = GenerateAction(adjustedPercent, result.confidence);
   result.riskLevel = GenerateRiskLevel(adjustedPercent, result.confidence);
   result.showOnChart = true;
   result.chartLabel = result.shortNarrative;
   result.narrative = GenerateDetailedNarrative(range, trend, result.confidence);
   
   return result;
}

//+------------------------------------------------------------------+
//| GET PULLBACK SUMMARY                                            |
//+------------------------------------------------------------------+
SPullbackSummary CPullbackModule::GetPullbackSummary()
{
   SPullbackSummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   RangeData range;
   if(!DetectRangeCached(range))
   {
      summary.shortDescription = "No valid range";
      return summary;
   }
   
   int trend = GetTrendForCalculation();
   summary.pullbackPercent = range.pullbackPercent;
   summary.pullbackScore = range.pullbackScore;
   summary.adjustedPercent = range.pullbackPercent;
   summary.zoneCategory = GetZoneCategory(range.pullbackPercent);
   summary.trend = trend;
   summary.isValid = true;
   
   summary.shortDescription = StringFormat("%s: %.1f%% (Score: %d)", 
                                          summary.zoneCategory, 
                                          range.pullbackPercent, 
                                          range.pullbackScore);
   summary.actionSuggestion = GenerateAction(range.pullbackPercent, range.pullbackScore);
   
   return summary;
}

//+------------------------------------------------------------------+
//| GET DRAWING DATA                                                |
//+------------------------------------------------------------------+
SPullbackDrawingData CPullbackModule::GetDrawingData()
{
   SPullbackDrawingData data;
   ZeroMemory(data);
   data.isValid = false;
   
   RangeData range;
   if(!DetectRangeCached(range)) return data;
   
   int trend = GetTrendForCalculation();
   data.isValid = true;
   data.trend = trend;
   data.rangeHigh = range.rangeHigh;
   data.rangeLow = range.rangeLow;
   data.currentPrice = range.currentPrice;
   data.rangeSize = range.rangeSize;
   data.adjustedPercent = range.pullbackPercent;
   data.zoneCategory = GetZoneCategory(range.pullbackPercent);
   data.zoneLevel = GetZoneLevel(range.pullbackPercent);
   
   GetDrawLines(range, data.line40, data.line80, trend);
   data.linePerfectLow = data.line40 + (range.rangeSize * 0.35);
   data.linePerfectHigh = data.line40 + (range.rangeSize * 0.45);
   
   return data;
}

//+------------------------------------------------------------------+
//| BASE CONFIDENCE                                                 |
//+------------------------------------------------------------------+
double CPullbackModule::GetBaseConfidence()
{
   RangeData range;
   if(!DetectRangeCached(range)) return 0;
   return (double)range.pullbackScore;
}

double CPullbackModule::GetFinalConfidence() { return GetBaseConfidence(); }
int CPullbackModule::GetTrendPublic() { return GetTrend(); }

bool CPullbackModule::Initialize()
{
   LOG_DEBUG("✅ CPullbackModule v3.1 (Clean Zone) ready", g_pullbackDebugMode);
   return true;
}

double CPullbackModule::GetRangeInPips(RangeData &range)
{
   double pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   return (pointValue > 0) ? range.rangeSize / pointValue : 0;
}

void CPullbackModule::SetTrendManager(CTrendManager* trendManager)
{
   m_trendManager = trendManager;
   if(m_trendManager != NULL)
   {
      m_currentTrendTime = 0;
      UpdateTrend();
   }
}