//+------------------------------------------------------------------+
//|                        TrendManager.mqh                          |
//|                    Primary Trend Detection Module                |
//|                    UPDATED: Robust NULL handling                 |
//|                    REMOVED: Position size multiplier             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.02"

#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugTrendManager = false;

//+------------------------------------------------------------------+
//| Trend Structure - Complete Trend Analysis Result                |
//+------------------------------------------------------------------+
struct STrendResult
{
   string   direction;           // "BULLISH", "BEARISH", "NEUTRAL"
   double   strength;            // 0-100 (Overall trend strength)
   double   ema50Slope;          // Slope of EMA50
   double   ema120Slope;         // Slope of EMA120
   bool     priceAboveEMA120;    // Price vs EMA120
   bool     maStackedBullish;    // 20 > 50 > 120
   bool     maStackedBearish;    // 20 < 50 < 120
   double   bullSignals;         // Number of bullish confirmations (0-6)
   double   bearSignals;         // Number of bearish confirmations (0-6)
   double   signalRatio;         // Bull signals / Total signals (0-1)
   double   trendConfidence;     // 0-100 confidence in current trend
   string   description;         // Human-readable description
   string   narrative;           // Detailed narrative
   datetime lastUpdate;
};

//+------------------------------------------------------------------+
//| Trend Manager Class                                             |
//+------------------------------------------------------------------+
class CTrendManager
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_trendTF;
   
   // EMA Handles
   int      m_ema20;
   int      m_ema50;
   int      m_ema120;
   
   // Cached Values
   double   m_cacheEMA20;
   double   m_cacheEMA50;
   double   m_cacheEMA120;
   double   m_cachePrice;
   
   // State
   STrendResult m_lastResult;
   datetime m_lastBarTime;
   bool m_isInitialized;
   
   // FALLBACK: Store last known direction even if indicators fail
   string   m_lastValidDirection;
   datetime m_lastValidTime;
   bool     m_hasValidDirection;
   
   // Private Methods
   double GetMAValue(int handle);
   bool IsNewBar();
   void UpdateCache();
   bool ValidateHandles();
   void RecreateHandles();
   
   // Core Analysis Methods
   bool CheckPriceAboveMA(double maValue);
   bool CheckMAStacking();
   double CalculateMASlope(int maHandle, int periods = 5);
   
   // Helper Methods
   string GenerateNarrative(const STrendResult &result);
   STrendResult GetFallbackTrend();
   
public:
   CTrendManager(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_H1);
   ~CTrendManager();
   
   // Initialization
   bool Initialize();
   void Shutdown();
   bool IsInitialized() const { return m_isInitialized; }
   bool HasValidDirection() const { return m_hasValidDirection; }
   
   // Debug control - Global only
   static void SetGlobalDebug(bool enable) { g_debugTrendManager = enable; }
   static bool GetGlobalDebug() { return g_debugTrendManager; }
   
   // Primary Analysis - Call this on each new bar
   STrendResult AnalyzeTrend();
   
   // Quick Access Methods - UPDATED to never return NULL
   string GetDirection();
   double GetStrength();
   bool IsBullish();
   bool IsBearish();
   bool IsStrongTrend();
   double GetTrendConfidence();
   double GetSignalRatio();
   
   // Trading Filters
   bool ShouldAllowLongs();
   bool ShouldAllowShorts();
   bool ShouldAllowEntries();
   
   // Detailed Analysis
   STrendResult GetLastResult() const { return m_lastResult; }
   string GetSummaryString();
   string GetDetailedReport();
   
   // Component Getters
   double GetEMA20() const { return m_cacheEMA20; }
   double GetEMA50() const { return m_cacheEMA50; }
   double GetEMA120() const { return m_cacheEMA120; }
   double GetCurrentPrice() const { return m_cachePrice; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CTrendManager::CTrendManager(string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("CTrendManager constructor called for " + (symbol == NULL ? "NULL" : symbol), g_debugTrendManager);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_trendTF = tf;
   
   // Initialize handles
   m_ema20 = INVALID_HANDLE;
   m_ema50 = INVALID_HANDLE;
   m_ema120 = INVALID_HANDLE;
   
   // Clear cache
   m_cacheEMA20 = 0;
   m_cacheEMA50 = 0;
   m_cacheEMA120 = 0;
   m_cachePrice = 0;
   
   m_lastBarTime = 0;
   m_isInitialized = false;
   m_hasValidDirection = false;
   m_lastValidDirection = "NEUTRAL";
   m_lastValidTime = 0;
   
   // Initialize result
   ZeroMemory(m_lastResult);
   m_lastResult.direction = "NEUTRAL";
   m_lastResult.description = "Not initialized";
   
   LOG_DEBUG("CTrendManager object created for " + m_symbol, g_debugTrendManager);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CTrendManager::~CTrendManager()
{
   LOG_DEBUG("CTrendManager destructor called for " + m_symbol, g_debugTrendManager);
   Shutdown();
}

//+------------------------------------------------------------------+
//| Initialize All Indicators                                       |
//+------------------------------------------------------------------+
bool CTrendManager::Initialize()
{
   LOG_DEBUG("Initialize called for " + m_symbol, g_debugTrendManager);
   
   if(m_isInitialized) 
   {
      LOG_DEBUG("Already initialized for " + m_symbol, g_debugTrendManager);
      return true;
   }
   
   LOG_DEBUG("Initializing TrendManager for " + m_symbol, g_debugTrendManager);
   
   // Create EMA Handles
   m_ema20 = iMA(m_symbol, m_trendTF, 20, 0, MODE_EMA, PRICE_CLOSE);
   m_ema50 = iMA(m_symbol, m_trendTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_ema120 = iMA(m_symbol, m_trendTF, 120, 0, MODE_EMA, PRICE_CLOSE);
   
   // Verify all handles
   if(m_ema20 == INVALID_HANDLE || m_ema50 == INVALID_HANDLE || 
      m_ema120 == INVALID_HANDLE)
   {
      LOG_WARNING("TrendManager: Failed to create indicators for " + m_symbol + " - Will use fallback method.");
      m_isInitialized = false;
      return false;
   }
   
   // Check for at least 150 bars of history
   if(Bars(m_symbol, m_trendTF) < 150)
   {
      LOG_WARNING("TrendManager: Not enough bars for " + m_symbol + " - Will use fallback method.");
      m_isInitialized = false;
      return false;
   }
   
   m_isInitialized = true;
   m_lastBarTime = iTime(m_symbol, m_trendTF, 0);
   
   // Initial analysis
   UpdateCache();
   m_lastResult = AnalyzeTrend();
   
   // Store the first valid direction
   if(m_lastResult.direction != "NEUTRAL")
   {
      m_hasValidDirection = true;
      m_lastValidDirection = m_lastResult.direction;
      m_lastValidTime = TimeCurrent();
   }
   
   LOG_INFO("TrendManager initialized for " + m_symbol + " on " + EnumToString(m_trendTF), g_debugTrendManager);
   LOG_INFO("Initial trend: " + m_lastResult.direction + " (Strength: " + DoubleToString(m_lastResult.strength, 1) + "%)", g_debugTrendManager);
   
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown - Release Indicators                                   |
//+------------------------------------------------------------------+
void CTrendManager::Shutdown()
{
   LOG_DEBUG("Shutdown called for " + m_symbol, g_debugTrendManager);
   
   if(m_ema20 != INVALID_HANDLE) IndicatorRelease(m_ema20);
   if(m_ema50 != INVALID_HANDLE) IndicatorRelease(m_ema50);
   if(m_ema120 != INVALID_HANDLE) IndicatorRelease(m_ema120);
   
   m_ema20 = INVALID_HANDLE;
   m_ema50 = INVALID_HANDLE;
   m_ema120 = INVALID_HANDLE;
   
   m_isInitialized = false;
   LOG_DEBUG("TrendManager shutdown for " + m_symbol, g_debugTrendManager);
}

//+------------------------------------------------------------------+
//| Validate Handles - Check if all handles are valid              |
//+------------------------------------------------------------------+
bool CTrendManager::ValidateHandles()
{
   bool valid = (m_ema20 != INVALID_HANDLE && m_ema50 != INVALID_HANDLE && 
                 m_ema120 != INVALID_HANDLE);
   
   if(!valid)
      LOG_DEBUG("Handles validation failed for " + m_symbol, g_debugTrendManager);
   
   return valid;
}

//+------------------------------------------------------------------+
//| Recreate Handles - Try to recreate invalid handles             |
//+------------------------------------------------------------------+
void CTrendManager::RecreateHandles()
{
   LOG_DEBUG("Recreating invalid handles for " + m_symbol, g_debugTrendManager);
   
   if(m_ema20 == INVALID_HANDLE)
      m_ema20 = iMA(m_symbol, m_trendTF, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(m_ema50 == INVALID_HANDLE)
      m_ema50 = iMA(m_symbol, m_trendTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(m_ema120 == INVALID_HANDLE)
      m_ema120 = iMA(m_symbol, m_trendTF, 120, 0, MODE_EMA, PRICE_CLOSE);
   
   m_isInitialized = ValidateHandles();
   
   if(m_isInitialized)
      LOG_DEBUG("Handles recreated successfully for " + m_symbol, g_debugTrendManager);
   else
      LOG_WARNING("Failed to recreate handles for " + m_symbol);
}

//+------------------------------------------------------------------+
//| Get MA Value                                                    |
//+------------------------------------------------------------------+
double CTrendManager::GetMAValue(int handle)
{
   if(handle == INVALID_HANDLE) 
   {
      LOG_DEBUG("Invalid handle in GetMAValue", g_debugTrendManager);
      return 0;
   }
   
   double buffer[1];
   if(CopyBuffer(handle, 0, 0, 1, buffer) < 1) 
   {
      LOG_DEBUG("Failed to copy buffer from handle", g_debugTrendManager);
      return 0;
   }
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Check if New Bar                                                |
//+------------------------------------------------------------------+
bool CTrendManager::IsNewBar()
{
   if(!m_isInitialized) return false;
   
   datetime currentTime = iTime(m_symbol, m_trendTF, 0);
   if(currentTime == 0) return false;
   
   if(currentTime != m_lastBarTime)
   {
      m_lastBarTime = currentTime;
      LOG_DEBUG("New bar detected for " + m_symbol + " at " + TimeToString(currentTime), g_debugTrendManager);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update Cache - Read all indicator values                        |
//+------------------------------------------------------------------+
void CTrendManager::UpdateCache()
{
   LOG_DEBUG("UpdateCache called for " + m_symbol, g_debugTrendManager);
   
   if(!m_isInitialized) 
   {
      LOG_DEBUG("Not initialized, skipping cache update", g_debugTrendManager);
      return;
   }
   
   // Check if handles are still valid
   if(!ValidateHandles())
   {
      RecreateHandles();
      if(!m_isInitialized) return;
   }
   
   m_cacheEMA20 = GetMAValue(m_ema20);
   m_cacheEMA50 = GetMAValue(m_ema50);
   m_cacheEMA120 = GetMAValue(m_ema120);
   m_cachePrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   LOG_DEBUG("Cache updated - EMA20: " + DoubleToString(m_cacheEMA20, _Digits) + 
             " EMA50: " + DoubleToString(m_cacheEMA50, _Digits) + 
             " EMA120: " + DoubleToString(m_cacheEMA120, _Digits), g_debugTrendManager);
}

//+------------------------------------------------------------------+
//| Calculate MA Slope                                              |
//+------------------------------------------------------------------+
double CTrendManager::CalculateMASlope(int maHandle, int periods = 5)
{
   LOG_DEBUG("CalculateMASlope called for handle " + IntegerToString(maHandle) + " with periods " + IntegerToString(periods), g_debugTrendManager);
   
   if(maHandle == INVALID_HANDLE) 
   {
      LOG_DEBUG("Invalid handle in CalculateMASlope", g_debugTrendManager);
      return 0;
   }
   
   double buffer[10];
   if(CopyBuffer(maHandle, 0, 0, periods + 1, buffer) < periods + 1)
   {
      LOG_DEBUG("Failed to copy buffer in CalculateMASlope", g_debugTrendManager);
      return 0;
   }
   
   // Linear regression slope
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = periods;
   
   for(int i = 0; i < n; i++)
   {
      double x = i;
      double y = buffer[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   
   double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
   LOG_DEBUG("Slope calculated: " + DoubleToString(slope, 6), g_debugTrendManager);
   return slope;
}

//+------------------------------------------------------------------+
//| Check Price vs MA                                               |
//+------------------------------------------------------------------+
bool CTrendManager::CheckPriceAboveMA(double maValue)
{
   bool above = m_cachePrice > maValue;
   LOG_DEBUG("CheckPriceAboveMA: " + DoubleToString(m_cachePrice, _Digits) + " > " + DoubleToString(maValue, _Digits) + " = " + (above ? "true" : "false"), g_debugTrendManager);
   return above;
}

//+------------------------------------------------------------------+
//| Check MA Stacking - EMA 20 > 50 > 120                           |
//+------------------------------------------------------------------+
bool CTrendManager::CheckMAStacking()
{
   bool bullStack = (m_cacheEMA20 > m_cacheEMA50 && 
                     m_cacheEMA50 > m_cacheEMA120);
   bool bearStack = (m_cacheEMA20 < m_cacheEMA50 && 
                     m_cacheEMA50 < m_cacheEMA120);
   bool stacked = (bullStack || bearStack);
   
   LOG_DEBUG("MA Stacking: " + (stacked ? (bullStack ? "BULLISH" : "BEARISH") : "NONE"), g_debugTrendManager);
   return stacked;
}

//+------------------------------------------------------------------+
//| Get Fallback Trend - Use price action when indicators fail      |
//+------------------------------------------------------------------+
STrendResult CTrendManager::GetFallbackTrend()
{
   LOG_WARNING("Using fallback trend detection for " + m_symbol);
   
   STrendResult result;
   ZeroMemory(result);
   
   // Simple price action fallback
   // Compare current price to 20-period SMA of close
   double closeBuffer[];
   ArraySetAsSeries(closeBuffer, true);
   
   if(CopyClose(m_symbol, m_trendTF, 0, 20, closeBuffer) < 20)
   {
      // If we can't even get price data, return last known direction
      LOG_ERROR("Cannot get price data for " + m_symbol + " - Using last known direction");
      result.direction = m_hasValidDirection ? m_lastValidDirection : "NEUTRAL";
      result.strength = 30.0;
      result.trendConfidence = 30.0;
      result.description = "Fallback trend (price action)";
      LOG_DEBUG("Fallback result: " + result.direction + " (last known)", g_debugTrendManager);
      return result;
   }
   
   // Calculate 20-period SMA
   double sma20 = 0;
   for(int i = 0; i < 20; i++)
      sma20 += closeBuffer[i];
   sma20 /= 20;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   m_cachePrice = currentPrice;
   
   // Determine direction based on price vs SMA
   if(currentPrice > sma20 * 1.005) // Price > SMA + 0.5%
   {
      result.direction = "BULLISH";
      result.strength = 40.0;
      result.trendConfidence = 40.0;
      result.description = "Fallback: Price above 20-SMA (Bullish)";
      LOG_DEBUG("Fallback detected BULLISH for " + m_symbol, g_debugTrendManager);
   }
   else if(currentPrice < sma20 * 0.995) // Price < SMA - 0.5%
   {
      result.direction = "BEARISH";
      result.strength = 40.0;
      result.trendConfidence = 40.0;
      result.description = "Fallback: Price below 20-SMA (Bearish)";
      LOG_DEBUG("Fallback detected BEARISH for " + m_symbol, g_debugTrendManager);
   }
   else
   {
      // If price is too close to SMA, use last known direction
      result.direction = m_hasValidDirection ? m_lastValidDirection : "NEUTRAL";
      result.strength = 25.0;
      result.trendConfidence = 25.0;
      result.description = "Fallback: Price near SMA - using last known direction";
      LOG_DEBUG("Fallback - price near SMA, using last known direction: " + result.direction, g_debugTrendManager);
   }
   
   // Store as valid direction
   if(result.direction != "NEUTRAL")
   {
      m_hasValidDirection = true;
      m_lastValidDirection = result.direction;
      m_lastValidTime = TimeCurrent();
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Analyze Trend - Main Analysis Function                          |
//+------------------------------------------------------------------+
STrendResult CTrendManager::AnalyzeTrend()
{
   LOG_DEBUG("AnalyzeTrend called for " + m_symbol, g_debugTrendManager);
   
   STrendResult result;
   ZeroMemory(result);
   
   // If not initialized, try to initialize first
   if(!m_isInitialized)
   {
      LOG_DEBUG("Not initialized, attempting initialization", g_debugTrendManager);
      if(!Initialize())
      {
         LOG_DEBUG("Initialization failed, using fallback", g_debugTrendManager);
         // Use fallback if initialization failed
         return GetFallbackTrend();
      }
   }
   
   // Update cache if new bar
   if(IsNewBar()) UpdateCache();
   
   // Check if we have valid data
   if(!ValidateHandles() || m_cacheEMA20 == 0 || m_cacheEMA50 == 0 || m_cacheEMA120 == 0)
   {
      LOG_WARNING("Invalid handles or cached values for " + m_symbol + " - Attempting recreation");
      // Try to recreate handles
      RecreateHandles();
      UpdateCache();
      
      // If still invalid, use fallback
      if(!ValidateHandles() || m_cacheEMA20 == 0 || m_cacheEMA50 == 0 || m_cacheEMA120 == 0)
      {
         LOG_ERROR("Still invalid after recreation for " + m_symbol + " - Using fallback");
         return GetFallbackTrend();
      }
   }
   
   // --- GATHER ALL SIGNALS ---
   double bullSignals = 0;
   double bearSignals = 0;
   
   // 1. Price vs EMA120 (MAJOR TREND) - Weight: ±3.0
   bool priceAboveEMA120 = CheckPriceAboveMA(m_cacheEMA120);
   if(priceAboveEMA120) 
      bullSignals += 3.0; 
   else 
      bearSignals += 3.0;
   result.priceAboveEMA120 = priceAboveEMA120;
   
   // 2. MA Stacking - Weight: ±2.0
   bool maStackBull = (m_cacheEMA20 > m_cacheEMA50 && 
                       m_cacheEMA50 > m_cacheEMA120);
   bool maStackBear = (m_cacheEMA20 < m_cacheEMA50 && 
                       m_cacheEMA50 < m_cacheEMA120);
   
   if(maStackBull) 
   { 
      bullSignals += 2.0; 
      result.maStackedBullish = true; 
   }
   if(maStackBear) 
   { 
      bearSignals += 2.0; 
      result.maStackedBearish = true; 
   }
   
   // 3. EMA Slopes - Weight: ±1.0
   double ema50Slope = CalculateMASlope(m_ema50, 5);
   double ema120Slope = CalculateMASlope(m_ema120, 5);
   result.ema50Slope = ema50Slope;
   result.ema120Slope = ema120Slope;
   
   bool bothSlopesPositive = (ema50Slope > 0 && ema120Slope > 0);
   bool bothSlopesNegative = (ema50Slope < 0 && ema120Slope < 0);
   
   if(bothSlopesPositive) 
      bullSignals += 1.0;
   else if(bothSlopesNegative) 
      bearSignals += 1.0;
   
   // Store signals
   result.bullSignals = bullSignals;
   result.bearSignals = bearSignals;
   
   // --- CALCULATE SIGNAL RATIO ---
   double totalSignals = bullSignals + bearSignals;
   double signalRatio = 0;
   if(totalSignals > 0)
      signalRatio = bullSignals / totalSignals;
   result.signalRatio = signalRatio;
   
   // --- DETERMINE DIRECTION ---
   if(signalRatio >= 0.55) 
      result.direction = "BULLISH";
   else if(signalRatio <= 0.45) 
      result.direction = "BEARISH";
   else 
      result.direction = "NEUTRAL";
   
   // --- CALCULATE STRENGTH ---
   result.strength = MathAbs(signalRatio - 0.5) * 200.0;
   result.strength = MathMin(100.0, result.strength);
   result.trendConfidence = result.strength;
   
   // --- GENERATE DESCRIPTION ---
   if(result.direction == "BULLISH")
   {
      if(result.strength >= 70.0) 
         result.description = "Strong Bullish Trend (High Confidence)";
      else if(result.strength >= 50.0) 
         result.description = "Bullish Trend (Medium Confidence)";
      else 
         result.description = "Mild Bullish Bias (Low Confidence)";
   }
   else if(result.direction == "BEARISH")
   {
      if(result.strength >= 70.0) 
         result.description = "Strong Bearish Trend (High Confidence)";
      else if(result.strength >= 50.0) 
         result.description = "Bearish Trend (Medium Confidence)";
      else 
         result.description = "Mild Bearish Bias (Low Confidence)";
   }
   else
      result.description = "Neutral / Sideways (Dead Zone)";
   
   // --- STORE VALID DIRECTION ---
   if(result.direction != "NEUTRAL")
   {
      m_hasValidDirection = true;
      m_lastValidDirection = result.direction;
      m_lastValidTime = TimeCurrent();
   }
   else if(m_hasValidDirection)
   {
      // If NEUTRAL but we have a previous direction, keep it as fallback
      // but still mark the current result as NEUTRAL
      result.description += " (Last known: " + m_lastValidDirection + ")";
   }
   
   // --- GENERATE NARRATIVE ---
   result.narrative = GenerateNarrative(result);
   
   // Store result
   result.lastUpdate = m_lastBarTime;
   m_lastResult = result;
   
   LOG_DEBUG("Analysis complete - Direction: " + result.direction + 
             " Strength: " + DoubleToString(result.strength, 1) + 
             "% Signals - Bull: " + DoubleToString(bullSignals, 1) + 
             " Bear: " + DoubleToString(bearSignals, 1), g_debugTrendManager);
   
   return result;
}

//+------------------------------------------------------------------+
//| Generate Narrative                                              |
//+------------------------------------------------------------------+
string CTrendManager::GenerateNarrative(const STrendResult &result)
{
   string narrative = "";
   
   if(result.direction == "BULLISH")
   {
      narrative = "Bullish trend confirmed. ";
      if(result.strength >= 70)
         narrative += "Strong momentum with EMA20>EMA50>EMA120 and price above EMA120. ";
      else if(result.strength >= 50)
         narrative += "Positive momentum with price above EMA120 and bullish EMA alignment. ";
      else
         narrative += "Mild bullish bias with some confirmations but not yet strong. ";
      
      if(result.priceAboveEMA120)
         narrative += "Price is trading above the 120-period EMA (key bull market indicator). ";
      if(result.maStackedBullish)
         narrative += "EMAs are perfectly stacked bullishly (20>50>120). ";
      if(result.ema50Slope > 0 && result.ema120Slope > 0)
         narrative += "Both EMA slopes are positive, confirming upward momentum. ";
   }
   else if(result.direction == "BEARISH")
   {
      narrative = "Bearish trend confirmed. ";
      if(result.strength >= 70)
         narrative += "Strong downward momentum with price below all EMAs. ";
      else if(result.strength >= 50)
         narrative += "Negative momentum with price below EMA120 and bearish EMA alignment. ";
      else
         narrative += "Mild bearish bias with some confirmations but not yet strong. ";
      
      if(!result.priceAboveEMA120)
         narrative += "Price is trading below the 120-period EMA (key bear market indicator). ";
      if(result.maStackedBearish)
         narrative += "EMAs are perfectly stacked bearishly (20<50<120). ";
      if(result.ema50Slope < 0 && result.ema120Slope < 0)
         narrative += "Both EMA slopes are negative, confirming downward momentum. ";
   }
   else
   {
      narrative = "Market is neutral with conflicting signals. ";
      if(m_hasValidDirection)
         narrative += "Last known direction: " + m_lastValidDirection + ". ";
      narrative += StringFormat("Bull signals: %.1f, Bear signals: %.1f. ", 
                               result.bullSignals, result.bearSignals);
      narrative += StringFormat("Signal ratio: %.1f%%. ", result.signalRatio * 100);
      narrative += "Market is in the 45-55% dead zone. Wait for clearer direction.";
   }
   
   narrative += StringFormat("Confidence: %.1f%%, Strength: %.1f%%.", 
                            result.trendConfidence, result.strength);
   
   LOG_DEBUG("Generated narrative: " + narrative, g_debugTrendManager);
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Direction - NEVER returns NULL                              |
//+------------------------------------------------------------------+
string CTrendManager::GetDirection()
{
   LOG_DEBUG("GetDirection called for " + m_symbol, g_debugTrendManager);
   
   // If we have a valid result, use it
   if(m_isInitialized)
   {
      AnalyzeTrend(); // Update if needed
      if(m_lastResult.direction != "NEUTRAL")
         return m_lastResult.direction;
   }
   
   // Fallback to last valid direction
   if(m_hasValidDirection)
   {
      LOG_DEBUG("Returning last valid direction: " + m_lastValidDirection, g_debugTrendManager);
      return m_lastValidDirection;
   }
   
   // Ultimate fallback - use price action to determine direction
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double closeBuffer[];
   ArraySetAsSeries(closeBuffer, true);
   
   if(CopyClose(m_symbol, m_trendTF, 0, 20, closeBuffer) >= 20)
   {
      double sma20 = 0;
      for(int i = 0; i < 20; i++)
         sma20 += closeBuffer[i];
      sma20 /= 20;
      
      if(currentPrice > sma20 * 1.005) 
      {
         LOG_DEBUG("Price action fallback: BULLISH", g_debugTrendManager);
         return "BULLISH";
      }
      if(currentPrice < sma20 * 0.995) 
      {
         LOG_DEBUG("Price action fallback: BEARISH", g_debugTrendManager);
         return "BEARISH";
      }
   }
   
   LOG_DEBUG("Returning NEUTRAL (default)", g_debugTrendManager);
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Strength                                                    |
//+------------------------------------------------------------------+
double CTrendManager::GetStrength()
{
   if(m_isInitialized)
   {
      AnalyzeTrend();
      if(m_lastResult.strength > 0) return m_lastResult.strength;
   }
   return 30.0; // Default low strength
}

//+------------------------------------------------------------------+
//| Get Signal Ratio                                                |
//+------------------------------------------------------------------+
double CTrendManager::GetSignalRatio()
{
   if(m_isInitialized)
   {
      AnalyzeTrend();
      if(m_lastResult.signalRatio > 0) return m_lastResult.signalRatio;
   }
   return 0.5; // Neutral
}

//+------------------------------------------------------------------+
//| Is Bullish                                                      |
//+------------------------------------------------------------------+
bool CTrendManager::IsBullish()
{
   string dir = GetDirection();
   bool result = (dir == "BULLISH");
   LOG_DEBUG("IsBullish: " + (result ? "true" : "false") + " for " + m_symbol, g_debugTrendManager);
   return result;
}

//+------------------------------------------------------------------+
//| Is Bearish                                                      |
//+------------------------------------------------------------------+
bool CTrendManager::IsBearish()
{
   string dir = GetDirection();
   bool result = (dir == "BEARISH");
   LOG_DEBUG("IsBearish: " + (result ? "true" : "false") + " for " + m_symbol, g_debugTrendManager);
   return result;
}

//+------------------------------------------------------------------+
//| Is Strong Trend                                                 |
//+------------------------------------------------------------------+
bool CTrendManager::IsStrongTrend()
{
   double strength = GetStrength();
   bool result = strength >= 60;
   LOG_DEBUG("IsStrongTrend: " + (result ? "true" : "false") + " (strength=" + DoubleToString(strength, 1) + "%)", g_debugTrendManager);
   return result;
}

//+------------------------------------------------------------------+
//| Get Trend Confidence                                             |
//+------------------------------------------------------------------+
double CTrendManager::GetTrendConfidence()
{
   return GetStrength();
}

//+------------------------------------------------------------------+
//| Should Allow Longs                                              |
//+------------------------------------------------------------------+
bool CTrendManager::ShouldAllowLongs()
{
   bool allow = IsBullish();
   LOG_DEBUG("ShouldAllowLongs: " + (allow ? "YES" : "NO") + " for " + m_symbol, g_debugTrendManager);
   return allow;
}

//+------------------------------------------------------------------+
//| Should Allow Shorts                                             |
//+------------------------------------------------------------------+
bool CTrendManager::ShouldAllowShorts()
{
   bool allow = IsBearish();
   LOG_DEBUG("ShouldAllowShorts: " + (allow ? "YES" : "NO") + " for " + m_symbol, g_debugTrendManager);
   return allow;
}

//+------------------------------------------------------------------+
//| Should Allow Entries                                            |
//+------------------------------------------------------------------+
bool CTrendManager::ShouldAllowEntries()
{
   string dir = GetDirection();
   bool allow = (dir != "NEUTRAL");
   LOG_DEBUG("ShouldAllowEntries: " + (allow ? "YES" : "NO") + " for " + m_symbol, g_debugTrendManager);
   return allow;
}

//+------------------------------------------------------------------+
//| Get Summary String                                              |
//+------------------------------------------------------------------+
string CTrendManager::GetSummaryString()
{
   if(!m_isInitialized && !m_hasValidDirection)
      return "TrendManager: Not initialized";
   
   AnalyzeTrend();
   
   string output = "";
   output += "Trend: " + GetDirection();
   output += " | Str: " + DoubleToString(GetStrength(), 1) + "%";
   output += " | Conf: " + DoubleToString(GetTrendConfidence(), 1) + "%";
   output += " | Last: " + (m_hasValidDirection ? m_lastValidDirection : "None");
   
   if(m_isInitialized)
   {
      output += " | Bull: " + DoubleToString(m_lastResult.bullSignals, 1);
      output += " Bear: " + DoubleToString(m_lastResult.bearSignals, 1);
   }
   
   LOG_DEBUG("Summary: " + output, g_debugTrendManager);
   return output;
}

//+------------------------------------------------------------------+
//| Get Detailed Report                                             |
//+------------------------------------------------------------------+
string CTrendManager::GetDetailedReport()
{
   if(!m_isInitialized && !m_hasValidDirection)
      return "TrendManager: Not initialized";
   
   AnalyzeTrend();
   
   string report = "\n========== TREND ANALYSIS REPORT ==========\n";
   report += "Symbol: " + m_symbol + "\n";
   report += "Timeframe: " + EnumToString(m_trendTF) + "\n";
   report += "Initialized: " + (m_isInitialized ? "Yes" : "No (fallback)") + "\n";
   report += "Has Valid Direction: " + (m_hasValidDirection ? "Yes" : "No") + "\n";
   report += "Last Valid Direction: " + m_lastValidDirection + "\n";
   report += "Last Valid Time: " + (m_lastValidTime > 0 ? TimeToString(m_lastValidTime) : "Never") + "\n";
   report += "\n--- CURRENT TREND ---\n";
   report += "Direction: " + GetDirection() + "\n";
   report += "Strength: " + DoubleToString(GetStrength(), 1) + "%\n";
   report += "Confidence: " + DoubleToString(GetTrendConfidence(), 1) + "%\n";
   report += "\n--- VALUES ---\n";
   report += "Price: " + DoubleToString(m_cachePrice, _Digits) + "\n";
   report += "EMA20: " + DoubleToString(m_cacheEMA20, _Digits) + "\n";
   report += "EMA50: " + DoubleToString(m_cacheEMA50, _Digits) + "\n";
   report += "EMA120: " + DoubleToString(m_cacheEMA120, _Digits) + "\n";
   report += "\n--- TRADING ---\n";
   report += "Allow Longs: " + (ShouldAllowLongs() ? "Yes" : "No") + "\n";
   report += "Allow Shorts: " + (ShouldAllowShorts() ? "Yes" : "No") + "\n";
   report += "=========================================\n";
   
   LOG_DEBUG("Detailed report generated", g_debugTrendManager);
   return report;
}