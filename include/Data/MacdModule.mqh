//+------------------------------------------------------------------+
//|                        MacdModule.mqh                             |
//|                    MACD Calculation Module                        |
//|                    v2.2 - FIXED STRING CONCATENATION             |
//|                    Returns: Direction, Confidence, Desc,         |
//|                    Narrative, and Full MACD Info                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.2"

#include "../Utils/Logger.mqh"

// ============================================================
// MACD MODULE INDEPENDENT TOGGLE
// ============================================================
bool g_macdDebugMode = false;  // Set to true to enable MACD module logging

//+------------------------------------------------------------------+
//| MACD Direction Result Structure                                  |
//| COMPLETE - All info needed for Component Manager                |
//+------------------------------------------------------------------+
struct SMACDDirectionResult
{
   // --- CORE COMPONENT MANAGER FIELDS ---
   string   direction;        // "BULLISH", "BEARISH", or "NEUTRAL"
   double   confidence;       // 0-100 (IMPROVED - accounts for momentum strength)
   string   description;      // Brief description of market condition
   string   narrative;        // Detailed narrative explaining the situation
   
   // --- PERCENTAGES FOR WEIGHTING ---
   double   bullPercentage;   // 0-100
   double   bearPercentage;   // 0-100
   
   // --- RAW MACD VALUES ---
   double   macdValue;        // Raw MACD main line value
   double   signalValue;      // Raw signal line value
   double   histogramValue;   // Histogram value (MACD - Signal)
   
   // --- METRICS FOR ANALYSIS ---
   double   macdScore;        // Calculated MACD score (0-100)
   double   momentumStrength; // How strong is the momentum (0-100)
   double   divergence;       // Divergence strength (0-100)
   double   crossoverSignal;  // Crossover strength (0-100)
   
   // --- VALIDATION ---
   bool     isValid;          // Whether the result is valid
   string   errorMessage;     // Error message if invalid
};

//+------------------------------------------------------------------+
//| MACD Summary Structure for Component Manager                    |
//+------------------------------------------------------------------+
struct SMACDSummary
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
   double   macdValue;          // Raw MACD main line value
   double   signalValue;        // Raw signal line value
   double   histogramValue;     // Histogram value (MACD - Signal)
   
   // --- METRICS ---
   double   macdScore;          // 0-100
   double   momentumStrength;   // 0-100
   
   // --- VALIDATION ---
   bool     isValid;
};

//+------------------------------------------------------------------+
//| MACD Module Class                                               |
//+------------------------------------------------------------------+
class CMacdModule
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   string              m_symbol;
   ENUM_TIMEFRAMES     m_timeframe;
   int                 m_fastEMA;
   int                 m_slowEMA;
   int                 m_signalSMA;
   int                 m_macdHandle;
   bool                m_initialized;
   bool                m_debug;
   string              m_lastError;
   
   // ──────────────────────────────────────────────────────────────
   // CACHE FOR HISTORICAL DATA
   // ──────────────────────────────────────────────────────────────
   double              m_cachedHistBuffer[];
   int                 m_cacheSize;
   datetime            m_cacheTime;
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   void UpdateCache();
   double GetMean(double &buffer[], int count);
   double GetStdDev(double &buffer[], int count, double mean);
   double NormalizeUsingStdDev(double hist);
   double NormalizeFallback(double hist);
   
   // ──────────────────────────────────────────────────────────────
   // ENHANCED CALCULATION METHODS
   // ──────────────────────────────────────────────────────────────
   double CalculateMomentumStrength(double histogram);
   double CalculateDivergenceStrength();
   double CalculateCrossoverStrength(double macd, double signal, double prevMacd, double prevSignal);
   double CalculateMACDScore(double histogram, double momentumStrength);
   double CalculateConfidenceInternal(double bullPct, double bearPct, double momentumStrength, double divergence);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CMacdModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int fast = 12, int slow = 26, int signal = 9);
   ~CMacdModule();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize();
   void Deinitialize();
   bool IsInitialized() const { return m_initialized; }
   string GetLastError() const { return m_lastError; }
   
   // ──────────────────────────────────────────────────────────────
   // DATA ACCESS - Raw Values
   // ──────────────────────────────────────────────────────────────
   bool GetMACDValues(double &macd, double &signal, double &histogram);
   double GetMACDValue();
   double GetSignalValue();
   double GetHistogramValue();
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT MANAGER METHODS - Returns ALL needed info
   // ──────────────────────────────────────────────────────────────
   
   // 1. DIRECTION - What's the signal?
   string GetDirection();
   string GetDirection(double macd, double signal);
   
   // 2. CONFIDENCE - How strong is the signal? (IMPROVED)
   double GetConfidence();
   double GetConfidence(double macd, double signal, double histogram);
   
   // 3. DESCRIPTION - Brief summary
   string GetDescription();
   string GetDescription(double bullPct, double bearPct, string direction, double confidence);
   
   // 4. NARRATIVE - Detailed explanation
   string GetNarrative();
   string GetNarrative(string direction, double bullPct, double bearPct, double confidence, 
                       double momentumStrength, double histogram);
   
   // 5. COMPLETE RESULT - Everything in one struct
   SMACDDirectionResult GetDirectionResult();
   
   // 6. SUMMARY - For quick display
   SMACDSummary GetMACDSummary();
   string GetSummaryString();
   
   // ──────────────────────────────────────────────────────────────
   // ADDITIONAL METRICS
   // ──────────────────────────────────────────────────────────────
   double GetBullPercentage();
   double GetBearPercentage();
   double GetMACDScore();
   double GetMomentumStrength();
   double GetDivergenceStrength();
   double GetCrossoverStrength();
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY METHODS
   // ──────────────────────────────────────────────────────────────
   void SetDebug(bool enable);
   bool GetDebug() const { return m_debug; }
   void PrintStatus();
   void DebugPrintMACD();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CMacdModule::CMacdModule(string symbol, ENUM_TIMEFRAMES tf, int fast, int slow, int signal)
{
   LOG_DEBUG("Constructor called", g_macdDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? PERIOD_H1 : tf;
   m_fastEMA = fast;
   m_slowEMA = slow;
   m_signalSMA = signal;
   m_macdHandle = INVALID_HANDLE;
   m_initialized = false;
   m_debug = g_macdDebugMode;
   m_lastError = "";
   
   m_cacheSize = 0;
   m_cacheTime = 0;
   
   string msg = "MACD Module created - Symbol: " + m_symbol + 
                ", Timeframe: " + EnumToString(m_timeframe) +
                ", Fast: " + IntegerToString(fast) +
                ", Slow: " + IntegerToString(slow) +
                ", Signal: " + IntegerToString(signal);
   LOG_DEBUG(msg, g_macdDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CMacdModule::~CMacdModule()
{
   LOG_DEBUG("Destructor called", g_macdDebugMode);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CMacdModule::Initialize()
{
   LOG_DEBUG("=== INITIALIZATION START ===", g_macdDebugMode);
   
   if(m_macdHandle != INVALID_HANDLE)
   {
      LOG_DEBUG("Releasing existing MACD handle", g_macdDebugMode);
      IndicatorRelease(m_macdHandle);
   }
   
   string msg = "Creating MACD handle for " + m_symbol + " on " + EnumToString(m_timeframe);
   LOG_DEBUG(msg, g_macdDebugMode);
   
   m_macdHandle = iMACD(m_symbol, m_timeframe, m_fastEMA, m_slowEMA, m_signalSMA, PRICE_CLOSE);
   
   if(m_macdHandle == INVALID_HANDLE)
   {
      m_lastError = "Failed to create MACD handle";
      LOG("Failed to create MACD handle", true);
      m_initialized = false;
      return false;
   }
   
   m_initialized = true;
   LOG_INFO("✅ MACD initialized successfully", g_macdDebugMode);
   LOG_DEBUG("=== END INITIALIZATION ===", g_macdDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CMacdModule::Deinitialize()
{
   LOG_DEBUG("Deinitializing...", g_macdDebugMode);
   
   if(m_macdHandle != INVALID_HANDLE)
   {
      LOG_DEBUG("Releasing MACD handle", g_macdDebugMode);
      IndicatorRelease(m_macdHandle);
      m_macdHandle = INVALID_HANDLE;
   }
   m_initialized = false;
   
   LOG_DEBUG("Deinitialization complete", g_macdDebugMode);
}

//+------------------------------------------------------------------+
//| Get MACD Values                                                 |
//+------------------------------------------------------------------+
bool CMacdModule::GetMACDValues(double &macd, double &signal, double &histogram)
{
   LOG_DEBUG("Getting MACD values...", g_macdDebugMode);
   
   macd = 0;
   signal = 0;
   histogram = 0;
   
   if(!m_initialized)
   {
      LOG_DEBUG("Not initialized, calling Initialize...", g_macdDebugMode);
      if(!Initialize())
      {
         LOG("Failed to initialize MACD", true);
         return false;
      }
   }
   
   double macdBuffer[1], signalBuffer[1];
   
   if(CopyBuffer(m_macdHandle, 0, 0, 1, macdBuffer) < 1)
   {
      m_lastError = "Failed to copy MACD buffer";
      LOG("Failed to copy MACD buffer", true);
      return false;
   }
   
   if(CopyBuffer(m_macdHandle, 1, 0, 1, signalBuffer) < 1)
   {
      m_lastError = "Failed to copy Signal buffer";
      LOG("Failed to copy Signal buffer", true);
      return false;
   }
   
   macd = macdBuffer[0];
   signal = signalBuffer[0];
   histogram = macd - signal;
   
   string msg = "  MACD: " + DoubleToString(macd, 5) + 
                ", Signal: " + DoubleToString(signal, 5) + 
                ", Hist: " + DoubleToString(histogram, 5);
   LOG_DEBUG(msg, g_macdDebugMode);
   
   return true;
}

//+------------------------------------------------------------------+
//| Get MACD Value                                                  |
//+------------------------------------------------------------------+
double CMacdModule::GetMACDValue()
{
   LOG_DEBUG("Getting MACD value...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD value, returning 0", g_macdDebugMode);
      return 0;
   }
   LOG_DEBUG("  MACD: " + DoubleToString(macd, 5), g_macdDebugMode);
   return macd;
}

//+------------------------------------------------------------------+
//| Get Signal Value                                                |
//+------------------------------------------------------------------+
double CMacdModule::GetSignalValue()
{
   LOG_DEBUG("Getting Signal value...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get Signal value, returning 0", g_macdDebugMode);
      return 0;
   }
   LOG_DEBUG("  Signal: " + DoubleToString(signal, 5), g_macdDebugMode);
   return signal;
}

//+------------------------------------------------------------------+
//| Get Histogram Value                                             |
//+------------------------------------------------------------------+
double CMacdModule::GetHistogramValue()
{
   LOG_DEBUG("Getting Histogram value...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get Histogram value, returning 0", g_macdDebugMode);
      return 0;
   }
   LOG_DEBUG("  Histogram: " + DoubleToString(histogram, 5), g_macdDebugMode);
   return histogram;
}

//+------------------------------------------------------------------+
//| Update Cache - Load historical histogram values                 |
//+------------------------------------------------------------------+
void CMacdModule::UpdateCache()
{
   LOG_DEBUG("Updating cache...", g_macdDebugMode);
   
   if(!m_initialized)
   {
      LOG_DEBUG("  Not initialized, skipping cache update", g_macdDebugMode);
      return;
   }
   
   datetime currentTime = iTime(m_symbol, m_timeframe, 0);
   if(currentTime == m_cacheTime && m_cacheSize > 0)
   {
      LOG_DEBUG("  Cache is already up to date", g_macdDebugMode);
      return;
   }
   
   m_cacheTime = currentTime;
   m_cacheSize = 100;
   ArrayResize(m_cachedHistBuffer, m_cacheSize);
   
   // ============================================================
   // FIX: RETRY WITH WAITING
   // ============================================================
   int maxRetries = 10;
   int retryDelay = 100; // milliseconds
   int barsLoaded = 0;
   
   for(int attempt = 0; attempt < maxRetries; attempt++)
   {
      LOG_DEBUG("  Attempt " + IntegerToString(attempt+1) + " to load histogram data...", g_macdDebugMode);
      
      barsLoaded = CopyBuffer(m_macdHandle, 2, 1, m_cacheSize, m_cachedHistBuffer);
      
      if(barsLoaded >= m_cacheSize)
      {
         LOG_DEBUG("  Loaded " + IntegerToString(barsLoaded) + " bars successfully", g_macdDebugMode);
         break;
      }
      
      // If we got some data but not enough, try with smaller size
      if(barsLoaded > 0)
      {
         LOG_DEBUG("  Got " + IntegerToString(barsLoaded) + " bars, trying smaller size...", g_macdDebugMode);
         m_cacheSize = barsLoaded;
         ArrayResize(m_cachedHistBuffer, m_cacheSize);
         
         barsLoaded = CopyBuffer(m_macdHandle, 2, 1, m_cacheSize, m_cachedHistBuffer);
         if(barsLoaded >= m_cacheSize)
         {
            LOG_DEBUG("  Loaded " + IntegerToString(barsLoaded) + " bars successfully", g_macdDebugMode);
            break;
         }
      }
      
      if(attempt < maxRetries - 1)
      {
         LOG_DEBUG("  Waiting for data... (" + IntegerToString(attempt+1) + "/" + IntegerToString(maxRetries) + ")", g_macdDebugMode);
         Sleep(retryDelay);
      }
   }
   
   if(barsLoaded < 20)
   {
      LOG_DEBUG("  Failed to load enough data, using fallback normalization", g_macdDebugMode);
      m_cacheSize = 0;
   }
   else
   {
      m_cacheSize = barsLoaded;
      ArrayResize(m_cachedHistBuffer, m_cacheSize);
      LOG_DEBUG("  Cache updated with " + IntegerToString(m_cacheSize) + " bars", g_macdDebugMode);
   }
}

//+------------------------------------------------------------------+
//| Calculate Mean                                                   |
//+------------------------------------------------------------------+
double CMacdModule::GetMean(double &buffer[], int count)
{
   if(count <= 0) return 0;
   double sum = 0;
   for(int i = 0; i < count; i++)
      sum += buffer[i];
   return sum / count;
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double CMacdModule::GetStdDev(double &buffer[], int count, double mean)
{
   if(count <= 1) return 1.0;
   double sumSq = 0;
   for(int i = 0; i < count; i++)
      sumSq += MathPow(buffer[i] - mean, 2);
   return MathSqrt(sumSq / (count - 1));
}

//+------------------------------------------------------------------+
//| Normalize using Standard Deviation                               |
//+------------------------------------------------------------------+
double CMacdModule::NormalizeUsingStdDev(double hist)
{
   LOG_DEBUG("Normalizing using StdDev...", g_macdDebugMode);
   UpdateCache();
   
   if(m_cacheSize >= 20)
   {
      double mean = GetMean(m_cachedHistBuffer, m_cacheSize);
      double stdDev = GetStdDev(m_cachedHistBuffer, m_cacheSize, mean);
      
      LOG_DEBUG("  Mean: " + DoubleToString(mean, 5) + ", StdDev: " + DoubleToString(stdDev, 5), g_macdDebugMode);
      
      if(stdDev < 0.0000001)
      {
         LOG_DEBUG("  StdDev too small, using fallback", g_macdDebugMode);
         stdDev = 0.001;
      }
      
      double normalized = (hist - mean) / (stdDev * 2.0);
      normalized = MathMax(-1.0, MathMin(1.0, normalized));
      double bullPct = 50.0 + (normalized * 50.0);
      
      LOG_DEBUG("  Bull%: " + DoubleToString(bullPct, 1) + "%", g_macdDebugMode);
      return MathMax(0.0, MathMin(100.0, bullPct));
   }
   
   LOG_DEBUG("  Not enough cache data, using fallback", g_macdDebugMode);
   return NormalizeFallback(hist);
}

//+------------------------------------------------------------------+
//| Fallback Normalization                                          |
//+------------------------------------------------------------------+
double CMacdModule::NormalizeFallback(double hist)
{
   LOG_DEBUG("Using fallback normalization...", g_macdDebugMode);
   
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(price <= 0) price = 1.0;
   
   double atr = 0;
   int atrHandle = iATR(m_symbol, m_timeframe, 14);
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
         atr = atrBuffer[0];
      IndicatorRelease(atrHandle);
   }
   
   if(atr <= 0) atr = price * 0.005;
   if(atr <= 0) atr = 1.0;
   
   LOG_DEBUG("  Price: " + DoubleToString(price, 2) + ", ATR: " + DoubleToString(atr, 2), g_macdDebugMode);
   
   double normalized = hist / atr;
   normalized = MathMax(-1.0, MathMin(1.0, normalized));
   double bullPct = 50.0 + (normalized * 50.0);
   
   LOG_DEBUG("  Bull%: " + DoubleToString(bullPct, 1) + "%", g_macdDebugMode);
   return MathMax(0.0, MathMin(100.0, bullPct));
}

//+------------------------------------------------------------------+
//| Calculate Bull Percentage                                       |
//+------------------------------------------------------------------+
double CMacdModule::GetBullPercentage()
{
   LOG_DEBUG("Calculating Bull Percentage...", g_macdDebugMode);
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 50%", g_macdDebugMode);
      return 50.0;
   }
   
   if(MathAbs(histogram) < 0.0000001)
   {
      LOG_DEBUG("  Histogram near zero, returning 50%", g_macdDebugMode);
      return 50.0;
   }
   
   double bullPct = NormalizeUsingStdDev(histogram);
   
   if(histogram > 0 && bullPct < 50.0)
      bullPct = 50.0 + (50.0 - bullPct);
   else if(histogram < 0 && bullPct > 50.0)
      bullPct = 50.0 - (bullPct - 50.0);
   
   double result = MathMax(0.0, MathMin(100.0, bullPct));
   LOG_DEBUG("  Bull%: " + DoubleToString(result, 1) + "%", g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Calculate Bear Percentage                                       |
//+------------------------------------------------------------------+
double CMacdModule::GetBearPercentage()
{
   double bullPct = GetBullPercentage();
   double bearPct = MathMax(0.0, MathMin(100.0, 100.0 - bullPct));
   LOG_DEBUG("  Bear%: " + DoubleToString(bearPct, 1) + "%", g_macdDebugMode);
   return bearPct;
}

//+------------------------------------------------------------------+
//| Calculate Momentum Strength (0-100)                             |
//+------------------------------------------------------------------+
double CMacdModule::CalculateMomentumStrength(double histogram)
{
   LOG_DEBUG("Calculating Momentum Strength...", g_macdDebugMode);
   
   double bullPct = NormalizeUsingStdDev(histogram);
   double strength = MathAbs(bullPct - 50.0) / 50.0;
   double result = MathMin(100.0, strength * 100.0);
   
   LOG_DEBUG("  Momentum Strength: " + DoubleToString(result, 1) + "%", g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Calculate Momentum Strength - Public                            |
//+------------------------------------------------------------------+
double CMacdModule::GetMomentumStrength()
{
   LOG_DEBUG("Getting Momentum Strength...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 0", g_macdDebugMode);
      return 0;
   }
   return CalculateMomentumStrength(histogram);
}

//+------------------------------------------------------------------+
//| Calculate Divergence Strength (0-100)                           |
//+------------------------------------------------------------------+
double CMacdModule::CalculateDivergenceStrength()
{
   LOG_DEBUG("Calculating Divergence Strength...", g_macdDebugMode);
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 0", g_macdDebugMode);
      return 0;
   }
   
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double prevPrice = iClose(m_symbol, m_timeframe, 1);
   double priceChange = (prevPrice > 0) ? (price - prevPrice) / prevPrice * 100 : 0;
   
   double prevMacd = 0;
   double macdBuffer[2];
   if(CopyBuffer(m_macdHandle, 0, 0, 2, macdBuffer) >= 2)
      prevMacd = macdBuffer[1];
   double macdChange = (prevMacd != 0) ? (macd - prevMacd) / MathAbs(prevMacd) * 100 : 0;
   
   LOG_DEBUG("  Price Change: " + DoubleToString(priceChange, 2) + "%, MACD Change: " + DoubleToString(macdChange, 2) + "%", g_macdDebugMode);
   
   bool bullishDivergence = (priceChange < 0 && macdChange > 0);
   bool bearishDivergence = (priceChange > 0 && macdChange < 0);
   
   if(bullishDivergence || bearishDivergence)
   {
      double strength = MathMin(100.0, MathAbs(macdChange) * 10);
      LOG_DEBUG("  Divergence detected! Strength: " + DoubleToString(strength, 1) + "%", g_macdDebugMode);
      return MathMin(100.0, strength);
   }
   
   LOG_DEBUG("  No divergence detected", g_macdDebugMode);
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate Divergence Strength - Public                          |
//+------------------------------------------------------------------+
double CMacdModule::GetDivergenceStrength()
{
   LOG_DEBUG("Getting Divergence Strength...", g_macdDebugMode);
   return CalculateDivergenceStrength();
}

//+------------------------------------------------------------------+
//| Calculate Crossover Strength (0-100)                            |
//+------------------------------------------------------------------+
double CMacdModule::CalculateCrossoverStrength(double macd, double signal, double prevMacd, double prevSignal)
{
   LOG_DEBUG("Calculating Crossover Strength...", g_macdDebugMode);
   
   bool crossedAbove = (prevMacd <= prevSignal && macd > signal);
   bool crossedBelow = (prevMacd >= prevSignal && macd < signal);
   
   if(crossedAbove || crossedBelow)
   {
      double diff = MathAbs(macd - signal);
      double prevDiff = MathAbs(prevMacd - prevSignal);
      double angle = (prevDiff > 0) ? diff / prevDiff : diff;
      double strength = MathMin(100.0, MathMin(100.0, angle * 50));
      
      LOG_DEBUG("  Crossover detected! Strength: " + DoubleToString(strength, 1) + "%", g_macdDebugMode);
      return strength;
   }
   
   double diff = MathAbs(macd - signal);
   double hist = GetHistogramValue();
   double bullPct = NormalizeUsingStdDev(hist);
   double strength = MathAbs(bullPct - 50.0) / 50.0;
   double result = MathMin(100.0, strength * 30);
   
   LOG_DEBUG("  No crossover, strength: " + DoubleToString(result, 1) + "%", g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Calculate Crossover Strength - Public                           |
//+------------------------------------------------------------------+
double CMacdModule::GetCrossoverStrength()
{
   LOG_DEBUG("Getting Crossover Strength...", g_macdDebugMode);
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 0", g_macdDebugMode);
      return 0;
   }
   
   double prevMacd = 0, prevSignal = 0;
   double macdBuffer[2], signalBuffer[2];
   if(CopyBuffer(m_macdHandle, 0, 0, 2, macdBuffer) >= 2 &&
      CopyBuffer(m_macdHandle, 1, 0, 2, signalBuffer) >= 2)
   {
      prevMacd = macdBuffer[1];
      prevSignal = signalBuffer[1];
   }
   
   return CalculateCrossoverStrength(macd, signal, prevMacd, prevSignal);
}

//+------------------------------------------------------------------+
//| Calculate MACD Score (0-100)                                    |
//+------------------------------------------------------------------+
double CMacdModule::CalculateMACDScore(double histogram, double momentumStrength)
{
   LOG_DEBUG("Calculating MACD Score...", g_macdDebugMode);
   double bullPct = NormalizeUsingStdDev(histogram);
   double strength = MathAbs(bullPct - 50.0) / 50.0;
   double result = MathMin(100.0, strength * 100.0);
   LOG_DEBUG("  MACD Score: " + DoubleToString(result, 1) + "%", g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get MACD Score - Public                                         |
//+------------------------------------------------------------------+
double CMacdModule::GetMACDScore()
{
   LOG_DEBUG("Getting MACD Score...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 0", g_macdDebugMode);
      return 0;
   }
   double momentum = CalculateMomentumStrength(histogram);
   return CalculateMACDScore(histogram, momentum);
}

//+------------------------------------------------------------------+
//| Get Direction                                                   |
//+------------------------------------------------------------------+
string CMacdModule::GetDirection()
{
   LOG_DEBUG("Getting Direction...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning NEUTRAL", g_macdDebugMode);
      return "NEUTRAL";
   }
   string direction = GetDirection(macd, signal);
   LOG_DEBUG("  Direction: " + direction, g_macdDebugMode);
   return direction;
}

//+------------------------------------------------------------------+
//| Get Direction - With Values                                     |
//+------------------------------------------------------------------+
string CMacdModule::GetDirection(double macd, double signal)
{
   double hist = macd - signal;
   double threshold = 0.0001;
   
   if(hist > threshold) return "BULLISH";
   else if(hist < -threshold) return "BEARISH";
   else return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Calculate Confidence - IMPROVED                                 |
//| Accounts for:                                                    |
//| 1. Direction clarity (bull% - bear%)                             |
//| 2. Momentum strength                                             |
//| 3. Divergence (if present)                                       |
//+------------------------------------------------------------------+
double CMacdModule::CalculateConfidenceInternal(double bullPct, double bearPct, 
                                                double momentumStrength, double divergence)
{
   LOG_DEBUG("Calculating Confidence...", g_macdDebugMode);
   
   LOG_DEBUG("  Bull%: " + DoubleToString(bullPct, 1) + "%, Bear%: " + DoubleToString(bearPct, 1) + "%", g_macdDebugMode);
   LOG_DEBUG("  Momentum Strength: " + DoubleToString(momentumStrength, 1) + "%, Divergence: " + DoubleToString(divergence, 1) + "%", g_macdDebugMode);
   
   double directionClarity = MathAbs(bullPct - bearPct);
   LOG_DEBUG("  Direction Clarity: " + DoubleToString(directionClarity, 1) + "%", g_macdDebugMode);
   
   double baseConfidence = (directionClarity * 0.6) + (momentumStrength * 0.4);
   LOG_DEBUG("  Base Confidence: " + DoubleToString(baseConfidence, 1) + "%", g_macdDebugMode);
   
   if(divergence > 30)
   {
      baseConfidence += divergence * 0.15;
      LOG_DEBUG("  Divergence bonus applied: +" + DoubleToString(divergence * 0.15, 1) + "%", g_macdDebugMode);
   }
   
   if(momentumStrength < 30 && baseConfidence > 40)
   {
      baseConfidence = MathMin(40.0, baseConfidence);
      LOG_DEBUG("  Cap applied due to weak momentum: " + DoubleToString(baseConfidence, 1) + "%", g_macdDebugMode);
   }
   
   if(directionClarity > 0 && baseConfidence < 5)
   {
      baseConfidence = 5.0;
      LOG_DEBUG("  Minimum confidence applied: 5%", g_macdDebugMode);
   }
   
   double result = MathMin(100.0, baseConfidence);
   LOG_DEBUG("  Final Confidence: " + DoubleToString(result, 1) + "%", g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Confidence - Public                                         |
//+------------------------------------------------------------------+
double CMacdModule::GetConfidence()
{
   LOG_DEBUG("Getting Confidence...", g_macdDebugMode);
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values, returning 0", g_macdDebugMode);
      return 0;
   }
   
   double bullPct = GetBullPercentage();
   double bearPct = GetBearPercentage();
   double momentum = CalculateMomentumStrength(histogram);
   double divergence = CalculateDivergenceStrength();
   
   return CalculateConfidenceInternal(bullPct, bearPct, momentum, divergence);
}

//+------------------------------------------------------------------+
//| Get Description                                                 |
//+------------------------------------------------------------------+
string CMacdModule::GetDescription()
{
   LOG_DEBUG("Getting Description...", g_macdDebugMode);
   double bullPct = GetBullPercentage();
   double bearPct = GetBearPercentage();
   string direction = GetDirection();
   double confidence = GetConfidence();
   string desc = GetDescription(bullPct, bearPct, direction, confidence);
   LOG_DEBUG("  Description: " + desc, g_macdDebugMode);
   return desc;
}

//+------------------------------------------------------------------+
//| Get Description - With Values                                   |
//+------------------------------------------------------------------+
string CMacdModule::GetDescription(double bullPct, double bearPct, string direction, double confidence)
{
   string strengthDesc;
   if(confidence >= 70) strengthDesc = "Very Strong";
   else if(confidence >= 50) strengthDesc = "Strong";
   else if(confidence >= 30) strengthDesc = "Moderate";
   else if(confidence >= 15) strengthDesc = "Weak";
   else strengthDesc = "No Momentum";
   
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
      dirDesc = "Neutral / Sideways";
   }
   
   string result = strengthDesc + " - " + dirDesc + " (Confidence: " + DoubleToString(confidence, 1) + "%)";
   return result;
}

//+------------------------------------------------------------------+
//| Get Narrative                                                   |
//+------------------------------------------------------------------+
string CMacdModule::GetNarrative()
{
   LOG_DEBUG("Getting Narrative...", g_macdDebugMode);
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG_DEBUG("  Failed to get MACD values", g_macdDebugMode);
      return "Unable to get MACD analysis";
   }
   
   double bullPct = GetBullPercentage();
   double bearPct = GetBearPercentage();
   string direction = GetDirection();
   double confidence = GetConfidence();
   double momentum = CalculateMomentumStrength(histogram);
   
   string narrative = GetNarrative(direction, bullPct, bearPct, confidence, momentum, histogram);
   LOG_DEBUG("  Narrative: " + narrative, g_macdDebugMode);
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Narrative - With Values                                     |
//+------------------------------------------------------------------+
string CMacdModule::GetNarrative(string direction, double bullPct, double bearPct, 
                                 double confidence, double momentumStrength, double histogram)
{
   string narrative = "";
   
   if(direction == "BULLISH")
   {
      if(confidence >= 50)
      {
         narrative = "✅ Strong bullish momentum with MACD above signal line. ";
         if(momentumStrength >= 50)
            narrative += "The widening histogram confirms increasing buying pressure and strong conviction.";
         else
            narrative += "Momentum is building but still needs confirmation.";
      }
      else if(confidence >= 30)
      {
         narrative = "📈 Positive momentum developing as MACD moves above signal. ";
         narrative += "Bulls are gaining control but may face resistance ahead.";
      }
      else
      {
         narrative = "📊 Slight bullish bias with limited momentum. ";
         narrative += "Market may be transitioning but lacks strong conviction.";
      }
   }
   else if(direction == "BEARISH")
   {
      if(confidence >= 50)
      {
         narrative = "✅ Strong bearish momentum with MACD below signal line. ";
         if(momentumStrength >= 50)
            narrative += "The widening histogram confirms increasing selling pressure and strong conviction.";
         else
            narrative += "Momentum is building but still needs confirmation.";
      }
      else if(confidence >= 30)
      {
         narrative = "📉 Negative momentum developing as MACD moves below signal. ";
         narrative += "Bears are gaining control but may face support ahead.";
      }
      else
      {
         narrative = "📊 Slight bearish bias with limited momentum. ";
         narrative += "Market may be transitioning but lacks strong conviction.";
      }
   }
   else
   {
      narrative = "➡️ Market is in a neutral/sideways phase with little momentum. ";
      narrative += "MACD and signal line are close together. ";
      narrative += "Watch for crossovers to indicate potential direction change.";
   }
   
   if(MathAbs(histogram) > 0.5)
      narrative += " Strong momentum in current direction.";
   else if(MathAbs(histogram) > 0.2)
      narrative += " Moderate momentum continues.";
   else
      narrative += " Momentum is weakening, watch for potential reversal.";
   
   double divergence = CalculateDivergenceStrength();
   if(divergence > 30)
   {
      if(direction == "BULLISH")
         narrative += " ⚠️ Bullish divergence detected - potential reversal up!";
      else if(direction == "BEARISH")
         narrative += " ⚠️ Bearish divergence detected - potential reversal down!";
   }
   
   narrative += " (Bulls: " + DoubleToString(bullPct, 1) + "%, Bears: " + DoubleToString(bearPct, 1) + 
                "%, Confidence: " + DoubleToString(confidence, 1) + "%, Momentum: " + 
                DoubleToString(momentumStrength, 1) + "%)";
   
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Complete Direction Result - ALL IN ONE!                     |
//+------------------------------------------------------------------+
SMACDDirectionResult CMacdModule::GetDirectionResult()
{
   LOG_DEBUG("=== GETTING COMPLETE DIRECTION RESULT ===", g_macdDebugMode);
   
   SMACDDirectionResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.errorMessage = "";
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      result.errorMessage = "Failed to get MACD values";
      LOG("Failed to get MACD values", true);
      return result;
   }
   
   LOG_DEBUG("  MACD: " + DoubleToString(macd, 5) + ", Signal: " + DoubleToString(signal, 5) + ", Hist: " + DoubleToString(histogram, 5), g_macdDebugMode);
   
   result.macdValue = macd;
   result.signalValue = signal;
   result.histogramValue = histogram;
   
   result.bullPercentage = GetBullPercentage();
   result.bearPercentage = GetBearPercentage();
   
   LOG_DEBUG("  Bull%: " + DoubleToString(result.bullPercentage, 1) + "%, Bear%: " + DoubleToString(result.bearPercentage, 1) + "%", g_macdDebugMode);
   
   double total = result.bullPercentage + result.bearPercentage;
   if(MathAbs(total - 100.0) > 0.01 && total > 0)
   {
      result.bullPercentage = (result.bullPercentage / total) * 100.0;
      result.bearPercentage = (result.bearPercentage / total) * 100.0;
      LOG_DEBUG("  Normalized: Bull%: " + DoubleToString(result.bullPercentage, 1) + "%, Bear%: " + DoubleToString(result.bearPercentage, 1) + "%", g_macdDebugMode);
   }
   
   result.momentumStrength = CalculateMomentumStrength(histogram);
   result.divergence = CalculateDivergenceStrength();
   result.macdScore = CalculateMACDScore(histogram, result.momentumStrength);
   
   LOG_DEBUG("  Momentum: " + DoubleToString(result.momentumStrength, 1) + "%, Divergence: " + DoubleToString(result.divergence, 1) + "%, Score: " + DoubleToString(result.macdScore, 1) + "%", g_macdDebugMode);
   
   result.direction = GetDirection(macd, signal);
   LOG_DEBUG("  Direction: " + result.direction, g_macdDebugMode);
   
   result.confidence = CalculateConfidenceInternal(result.bullPercentage, result.bearPercentage,
                                                   result.momentumStrength, result.divergence);
   
   LOG_DEBUG("  Confidence: " + DoubleToString(result.confidence, 1) + "%", g_macdDebugMode);
   
   result.description = GetDescription(result.bullPercentage, result.bearPercentage,
                                       result.direction, result.confidence);
   result.narrative = GetNarrative(result.direction, result.bullPercentage, result.bearPercentage,
                                   result.confidence, result.momentumStrength, histogram);
   
   result.isValid = true;
   
   LOG_DEBUG("✅ Direction Result Complete", g_macdDebugMode);
   LOG_DEBUG("  Direction: " + result.direction, g_macdDebugMode);
   LOG_DEBUG("  Confidence: " + DoubleToString(result.confidence, 1) + "%", g_macdDebugMode);
   LOG_DEBUG("  Description: " + result.description, g_macdDebugMode);
   LOG_DEBUG("=== END DIRECTION RESULT ===", g_macdDebugMode);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get MACD Summary - For Component Manager                        |
//+------------------------------------------------------------------+
SMACDSummary CMacdModule::GetMACDSummary()
{
   LOG_DEBUG("Getting MACD Summary...", g_macdDebugMode);
   
   SMACDSummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   SMACDDirectionResult result = GetDirectionResult();
   if(!result.isValid)
   {
      LOG("Failed to get MACD summary", true);
      return summary;
   }
   
   summary.direction = result.direction;
   summary.confidence = result.confidence;
   summary.bullPercentage = result.bullPercentage;
   summary.bearPercentage = result.bearPercentage;
   summary.macdValue = result.macdValue;
   summary.signalValue = result.signalValue;
   summary.histogramValue = result.histogramValue;
   summary.macdScore = result.macdScore;
   summary.momentumStrength = result.momentumStrength;
   
   string shortDesc = "";
   if(summary.direction == "BULLISH")
   {
      if(summary.confidence >= 60) shortDesc = "Strong Bullish";
      else if(summary.confidence >= 40) shortDesc = "Moderate Bullish";
      else shortDesc = "Weak Bullish";
   }
   else if(summary.direction == "BEARISH")
   {
      if(summary.confidence >= 60) shortDesc = "Strong Bearish";
      else if(summary.confidence >= 40) shortDesc = "Moderate Bearish";
      else shortDesc = "Weak Bearish";
   }
   else
   {
      shortDesc = "Neutral/Sideways";
   }
   
   if(summary.momentumStrength >= 70)
      shortDesc = "🔥 " + shortDesc;
   else if(summary.momentumStrength >= 50)
      shortDesc = "✓ " + shortDesc;
   
   summary.shortDescription = shortDesc;
   summary.fullDescription = result.description;
   summary.isValid = true;
   
   LOG_DEBUG("  Summary: " + summary.shortDescription + " | Conf: " + DoubleToString(summary.confidence, 1) + "%", g_macdDebugMode);
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Summary String - Quick display                              |
//+------------------------------------------------------------------+
string CMacdModule::GetSummaryString()
{
   LOG_DEBUG("Getting Summary String...", g_macdDebugMode);
   
   SMACDSummary summary = GetMACDSummary();
   if(!summary.isValid)
   {
      LOG_DEBUG("  Invalid summary", g_macdDebugMode);
      return "MACD: N/A";
   }
   
   string directionSymbol = "";
   if(summary.direction == "BULLISH") directionSymbol = "📈";
   else if(summary.direction == "BEARISH") directionSymbol = "📉";
   else directionSymbol = "➡️";
   
   string result = "MACD: " + DoubleToString(summary.macdValue, 4) + 
                   " | " + directionSymbol + " " + summary.direction + 
                   " | Conf: " + DoubleToString(summary.confidence, 0) + 
                   "% | Bulls: " + DoubleToString(summary.bullPercentage, 0) + "%";
   
   LOG_DEBUG("  Summary: " + result, g_macdDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Set Debug                                                       |
//+------------------------------------------------------------------+
void CMacdModule::SetDebug(bool enable)
{
   LOG_DEBUG("Setting debug mode to: " + (enable ? "ON" : "OFF"), g_macdDebugMode);
   m_debug = enable;
   LOG_DEBUG("Debug mode " + (enable ? "ENABLED" : "DISABLED"), g_macdDebugMode);
}

//+------------------------------------------------------------------+
//| Print Status - Full debug output                                |
//+------------------------------------------------------------------+
void CMacdModule::PrintStatus()
{
   string separator = "=== ";
   string indent = "   ";
   
   Print(separator + "MACD MODULE STATUS " + separator);
   Print(indent + "Symbol: " + m_symbol);
   Print(indent + "Timeframe: " + EnumToString(m_timeframe));
   Print(indent + "Fast EMA: " + IntegerToString(m_fastEMA));
   Print(indent + "Slow EMA: " + IntegerToString(m_slowEMA));
   Print(indent + "Signal SMA: " + IntegerToString(m_signalSMA));
   Print(indent + "Initialized: " + (m_initialized ? "YES" : "NO"));
   Print(indent + "Debug: " + (m_debug ? "ON" : "OFF"));
   Print(indent + "Last Error: " + m_lastError);
   
   SMACDDirectionResult result = GetDirectionResult();
   if(result.isValid)
   {
      Print(indent + "MACD: " + DoubleToString(result.macdValue, 5));
      Print(indent + "Signal: " + DoubleToString(result.signalValue, 5));
      Print(indent + "Histogram: " + DoubleToString(result.histogramValue, 5));
      Print(indent + "Direction: " + result.direction);
      Print(indent + "Confidence: " + DoubleToString(result.confidence, 1) + "%");
      Print(indent + "Bull%: " + DoubleToString(result.bullPercentage, 1) + "%");
      Print(indent + "Bear%: " + DoubleToString(result.bearPercentage, 1) + "%");
      Print(indent + "Score: " + DoubleToString(result.macdScore, 1) + "%");
      Print(indent + "Momentum: " + DoubleToString(result.momentumStrength, 1) + "%");
      Print(indent + "Divergence: " + DoubleToString(result.divergence, 1) + "%");
      Print(indent + "Description: " + result.description);
      Print(indent + "Narrative: " + result.narrative);
   }
   else
   {
      Print(indent + "❌ Unable to get MACD values");
      Print(indent + "Error: " + result.errorMessage);
   }
   Print(separator + "END STATUS " + separator);
}

//+------------------------------------------------------------------+
//| Debug Print MACD - Detailed debug output                        |
//+------------------------------------------------------------------+
void CMacdModule::DebugPrintMACD()
{
   LOG_DEBUG("=== DEBUG PRINT MACD ===", g_macdDebugMode);
   
   double macd, signal, histogram;
   if(!GetMACDValues(macd, signal, histogram))
   {
      LOG("Failed to get MACD values", true);
      return;
   }
   
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   UpdateCache();
   
   Print("=== MACD DEBUG ===");
   Print("  Symbol: " + m_symbol);
   Print("  Timeframe: " + EnumToString(m_timeframe));
   Print("  Price: " + DoubleToString(price, _Digits));
   Print("  MACD: " + DoubleToString(macd, 5));
   Print("  Signal: " + DoubleToString(signal, 5));
   Print("  Histogram: " + DoubleToString(histogram, 5));
   Print("  Bull%: " + DoubleToString(GetBullPercentage(), 1) + "%");
   Print("  Bear%: " + DoubleToString(GetBearPercentage(), 1) + "%");
   Print("  Confidence: " + DoubleToString(GetConfidence(), 1) + "%");
   Print("  Momentum: " + DoubleToString(GetMomentumStrength(), 1) + "%");
   Print("  Divergence: " + DoubleToString(GetDivergenceStrength(), 1) + "%");
   Print("  Crossover: " + DoubleToString(GetCrossoverStrength(), 1) + "%");
   Print("  Score: " + DoubleToString(GetMACDScore(), 1) + "%");
   Print("  Direction: " + GetDirection());
   Print("  Description: " + GetDescription());
   
   if(m_cacheSize >= 20)
   {
      double mean = GetMean(m_cachedHistBuffer, m_cacheSize);
      double stdDev = GetStdDev(m_cachedHistBuffer, m_cacheSize, mean);
      Print("  Hist Mean (100 bars): " + DoubleToString(mean, 5));
      Print("  Hist Std Dev: " + DoubleToString(stdDev, 5));
      Print("  Z-Score: " + DoubleToString((histogram - mean) / (stdDev + 0.00001), 2));
   }
   Print("=================");
   
   LOG_DEBUG("=== DEBUG PRINT COMPLETE ===", g_macdDebugMode);
}