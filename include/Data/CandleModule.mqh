//+------------------------------------------------------------------+
//|                        CandleModule.mqh                         |
//|                    Pullback Exhaustion Detection                 |
//|                    v1.04 - Cooldown Reset Module                |
//|                    Monitors M15 for exhaustion signals          |
//|                    + Pattern display with percentages           |
//|                    + Wait for next M15 candle on cooldown      |
//|                    + CLOSED CANDLE ONLY for all patterns       |
//|                    + CONFIGURABLE WAIT PERIOD (Input)          |
//|                    + Displays stats while waiting              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.04"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugCandleModule = false;

//+------------------------------------------------------------------+
//| Exhaustion Result Structure                                     |
//+------------------------------------------------------------------+
struct SExhaustionResult
{
   bool     isValid;              // Valid exhaustion signal detected
   bool     isBullish;            // Bullish exhaustion
   bool     isBearish;            // Bearish exhaustion
   bool     htfExhaustion;        // HTF (M15) exhaustion
   bool     ltfExhaustion;        // LTF (M1) exhaustion
   string   type;                 // "EXHAUSTION", "SLOWING", "NONE"
   string   description;          // Human-readable description
   double   confidence;           // 0-100 confidence in exhaustion
   double   htfPullbackDepth;     // HTF pullback depth (%)
   double   ltfPullbackDepth;     // LTF pullback depth (%)
   datetime timestamp;
   int      htfDirection;         // 1=BULLISH, -1=BEARISH, 0=NEUTRAL
   bool     cooldownReset;        // Should cooldown be reset?
   string   resetReason;          // Why cooldown should be reset
   string   htfPattern;           // HTF pattern name
   string   ltfPattern;           // LTF pattern name
   double   htfPatternStrength;   // HTF pattern strength
   double   ltfPatternStrength;   // LTF pattern strength
   int      candlesWaited;        // Number of M15 candles waited so far
   int      candlesRequired;      // Number of candles required before checking
   string   waitStatus;           // Human-readable wait status
};

//+------------------------------------------------------------------+
//| Candle Module Class                                             |
//+------------------------------------------------------------------+
class CCandleModule
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_htfTF;        // M15 - Higher timeframe
   ENUM_TIMEFRAMES m_ltfTF;        // M1  - Lower timeframe
   bool     m_debugEnabled;
   double   m_pointValue;
   double   m_tolerance;           // 2 pips tolerance
   int      m_waitCandleCount;     // Number of candles to wait (from input)
   
   // ═══ CACHED VALUES ═══
   // These are always from CLOSED candles
   double   m_htfOpen;
   double   m_htfClose;
   double   m_htfHigh;
   double   m_htfLow;
   double   m_htfPrevClose;
   double   m_htfPrevHigh;
   double   m_htfPrevLow;
   double   m_htfPrevPrevHigh;
   double   m_htfPrevPrevLow;
   double   m_htfHighestHigh;
   double   m_htfLowestLow;
   
   double   m_ltfOpen;
   double   m_ltfPrevClose;
   double   m_ltfPrevHigh;
   double   m_ltfPrevLow;
   double   m_ltfPrevPrevHigh;
   double   m_ltfPrevPrevLow;
   
   // ═══ COOLDOWN CANDLE TRACKING ═══
   datetime m_cooldownStartCandleTime;    // M15 candle time when cooldown started
   bool     m_cooldownCandleInitialized;  // Has the first candle been set?
   bool     m_waitForNextCandle;          // Flag to wait for next candle
   int      m_candlesWaited;              // Number of M15 candles waited
   datetime m_lastWaitLogTime;            // Last time wait status was logged
   bool     m_waitingForClose;            // Flag to wait for current candle to close
   
   // ═══ METHODS ═══
   bool     FetchCandleData();
   int      GetClosedCandleShift(ENUM_TIMEFRAMES tf);
   double   GetCandleRange(ENUM_TIMEFRAMES tf, int shift);
   double   GetPullbackDepth(ENUM_TIMEFRAMES tf, int lookback);
   bool     IsExhaustionCandle(ENUM_TIMEFRAMES tf, int direction);
   bool     IsDojiCandle(ENUM_TIMEFRAMES tf);
   bool     IsInsideCandle(ENUM_TIMEFRAMES tf);
   bool     IsEngulfingCandle(ENUM_TIMEFRAMES tf);
   bool     IsPinBarCandle(ENUM_TIMEFRAMES tf);
   string   GetCandlePattern(ENUM_TIMEFRAMES tf);
   double   GetPatternStrength(ENUM_TIMEFRAMES tf);
   string   GetPatternDisplay(ENUM_TIMEFRAMES tf);
   bool     IsCandleClosed(ENUM_TIMEFRAMES tf);
   
public:
   CCandleModule(string symbol = NULL, 
                 ENUM_TIMEFRAMES htfTF = PERIOD_M15,
                 ENUM_TIMEFRAMES ltfTF = PERIOD_M1);
   ~CCandleModule();
   
   void SetDebug(bool enable) { m_debugEnabled = enable; m_debugEnabled = g_debugCandleModule; }
   static void SetGlobalDebug(bool enable) { g_debugCandleModule = enable; }
   
   // ═══ CONFIGURATION ═══
   void SetWaitCandles(int count) { m_waitCandleCount = MathMax(1, MathMin(3, count)); }  // Clamp 1-3
   int GetWaitCandles() const { return m_waitCandleCount; }
   
   // ═══ INITIALIZATION ═══
   bool Initialize();
   void Shutdown();
   
   // ═══ COOLDOWN CANDLE TRACKING ═══
   void ResetCooldownCandleTracking();
   string GetCandleWaitStatus();
   bool IsWaitingForCandle() const { return m_waitForNextCandle || m_waitingForClose; }
   int GetCandlesWaited() const { return m_candlesWaited; }
   int GetCandlesRequired() const { return m_waitCandleCount; }
   
   // ═══ MAIN ANALYSIS ═══
   SExhaustionResult AnalyzeExhaustion(int trendDirection, double cooldownRemaining = 0);
   
   // ═══ COOLDOWN RESET CHECK ═══
   bool ShouldResetCooldown(int trendDirection, double cooldownRemaining);
   string GetResetReason(int trendDirection);
   
   // ═══ GETTERS ═══
   double GetHTFOpen() const { return m_htfOpen; }
   double GetHTFClose() const { return m_htfClose; }
   double GetLTFOpen() const { return m_ltfOpen; }
   double GetPointValue() const { return m_pointValue; }
   datetime GetCooldownStartCandleTime() const { return m_cooldownStartCandleTime; }
   
   // ═══ REPORTS ═══
   string GetStatusReport();
   string GetExhaustionReport(SExhaustionResult &result);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CCandleModule::CCandleModule(string symbol, ENUM_TIMEFRAMES htfTF, ENUM_TIMEFRAMES ltfTF)
{
   LOG_DEBUG("🔧 CCandleModule v1.04 constructor called", g_debugCandleModule);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_htfTF = (htfTF == PERIOD_CURRENT) ? PERIOD_M15 : htfTF;
   m_ltfTF = (ltfTF == PERIOD_CURRENT) ? PERIOD_M1 : ltfTF;
   m_debugEnabled = g_debugCandleModule;
   m_pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tolerance = m_pointValue * 2;
   
   // ═══ Use input value for wait count, clamped to 1-3 ═══
   m_waitCandleCount = MathMax(1, MathMin(3, InpCandleWaitCandles));
   
   // Clear cached values
   m_htfOpen = 0; m_htfClose = 0; m_htfHigh = 0; m_htfLow = 0;
   m_htfPrevClose = 0; m_htfPrevHigh = 0; m_htfPrevLow = 0;
   m_htfPrevPrevHigh = 0; m_htfPrevPrevLow = 0;
   m_htfHighestHigh = 0; m_htfLowestLow = 0;
   m_ltfOpen = 0; m_ltfPrevClose = 0;
   m_ltfPrevHigh = 0; m_ltfPrevLow = 0;
   m_ltfPrevPrevHigh = 0; m_ltfPrevPrevLow = 0;
   
   // ═══ COOLDOWN CANDLE TRACKING ═══
   m_cooldownStartCandleTime = 0;
   m_cooldownCandleInitialized = false;
   m_waitForNextCandle = false;
   m_waitingForClose = false;
   m_candlesWaited = 0;
   m_lastWaitLogTime = 0;
   
   LOG_DEBUG("✅ CCandleModule v1.04 created for " + m_symbol + " | HTF: M15 | LTF: M1", g_debugCandleModule);
   LOG_DEBUG("   Wait Period: " + IntegerToString(m_waitCandleCount) + " M15 candle(s) after cooldown", g_debugCandleModule);
   LOG_DEBUG("   NOTE: Only CLOSED candles are used for pattern detection", g_debugCandleModule);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CCandleModule::~CCandleModule()
{
   LOG_DEBUG("CCandleModule destructor called", g_debugCandleModule);
   Shutdown();
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CCandleModule::Initialize()
{
   LOG_DEBUG("CCandleModule Initialize called", g_debugCandleModule);
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown                                                        |
//+------------------------------------------------------------------+
void CCandleModule::Shutdown()
{
   LOG_DEBUG("CCandleModule shutdown", g_debugCandleModule);
}

//+------------------------------------------------------------------+
//| Reset Cooldown Candle Tracking - Call when cooldown starts      |
//+------------------------------------------------------------------+
void CCandleModule::ResetCooldownCandleTracking()
{
   // Record the current M15 candle time when cooldown starts
   m_cooldownStartCandleTime = iTime(m_symbol, m_htfTF, 0);
   m_cooldownCandleInitialized = true;
   m_waitForNextCandle = true;
   m_waitingForClose = true;  // Need to wait for current candle to close first
   m_candlesWaited = 0;
   m_lastWaitLogTime = 0;
   
   LOG_DEBUG("🕯️ Cooldown started at M15 candle: " + TimeToString(m_cooldownStartCandleTime), m_debugEnabled);
   LOG_DEBUG("   Will wait for " + IntegerToString(m_waitCandleCount) + " M15 candle(s) before checking exhaustion", m_debugEnabled);
}

//+------------------------------------------------------------------+
//| Get Candle Wait Status - FIXED DISPLAY                          |
//+------------------------------------------------------------------+
string CCandleModule::GetCandleWaitStatus()
{
   if(!m_waitForNextCandle && !m_waitingForClose) return "✅ Ready - checking exhaustion";
   
   if(!m_cooldownCandleInitialized) return "⏳ Not initialized";
   
   datetime currentTime = TimeCurrent();
   datetime currentCandleTime = iTime(m_symbol, m_htfTF, 0);
   bool candleClosed = IsCandleClosed(m_htfTF);
   
   // Calculate how many closed candles we have
   int closedCandlesWaited = 0;
   if(m_cooldownStartCandleTime > 0)
   {
      // Get the most recent closed candle time
      int shift = 0;
      if(!candleClosed)
         shift = 1;
      
      datetime lastClosedCandleTime = iTime(m_symbol, m_htfTF, shift);
      
      if(lastClosedCandleTime > m_cooldownStartCandleTime)
      {
         int diffSeconds = (int)(lastClosedCandleTime - m_cooldownStartCandleTime);
         closedCandlesWaited = diffSeconds / 900;
      }
      else if(lastClosedCandleTime == m_cooldownStartCandleTime)
      {
         closedCandlesWaited = 1;
      }
      else if(lastClosedCandleTime < m_cooldownStartCandleTime)
      {
         closedCandlesWaited = 0;
      }
      
      m_candlesWaited = closedCandlesWaited;
   }
   
   // ═══ FIXED: Check if we're ready ═══
   if(closedCandlesWaited >= m_waitCandleCount)
   {
      // We have enough closed candles - ready to check!
      return StringFormat("✅ Ready - have %d of %d closed candles", 
                         closedCandlesWaited, m_waitCandleCount);
   }
   
   // Still waiting for more candles
   int candlesNeeded = m_waitCandleCount - closedCandlesWaited;
   return StringFormat("⏳ Waiting for %d more closed candle(s) (have %d of %d)", 
                      candlesNeeded, closedCandlesWaited, m_waitCandleCount);
}

//+------------------------------------------------------------------+
//| Check if Candle is Closed                                       |
//+------------------------------------------------------------------+
bool CCandleModule::IsCandleClosed(ENUM_TIMEFRAMES tf)
{
   datetime candleTime = iTime(m_symbol, tf, 0);
   datetime currentTime = TimeCurrent();
   int secondsPerCandle = PeriodSeconds(tf);
   
   // If current time is past the candle close time, it's closed
   return (currentTime >= candleTime + secondsPerCandle);
}

//+------------------------------------------------------------------+
//| Get Closed Candle Shift - Returns shift for closed candle       |
//+------------------------------------------------------------------+
int CCandleModule::GetClosedCandleShift(ENUM_TIMEFRAMES tf)
{
   // If current candle is closed, use shift 0
   if(IsCandleClosed(tf))
      return 0;
   
   // Otherwise use shift 1 (previous closed candle)
   return 1;
}

//+------------------------------------------------------------------+
//| Fetch Candle Data - ALWAYS uses CLOSED candles                  |
//+------------------------------------------------------------------+
bool CCandleModule::FetchCandleData()
{
   // ═══ Get shifts for closed candles ═══
   int htfShift = GetClosedCandleShift(m_htfTF);
   int ltfShift = GetClosedCandleShift(m_ltfTF);
   
   // ═══ HTF (M15) DATA - ALWAYS from closed candle ═══
   m_htfOpen = iOpen(m_symbol, m_htfTF, htfShift);
   m_htfClose = iClose(m_symbol, m_htfTF, htfShift);
   m_htfHigh = iHigh(m_symbol, m_htfTF, htfShift);
   m_htfLow = iLow(m_symbol, m_htfTF, htfShift);
   m_htfPrevClose = iClose(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevHigh = iHigh(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevLow = iLow(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevPrevHigh = iHigh(m_symbol, m_htfTF, htfShift + 2);
   m_htfPrevPrevLow = iLow(m_symbol, m_htfTF, htfShift + 2);
   
   // ═══ LTF (M1) DATA - ALWAYS from closed candle ═══
   m_ltfOpen = iOpen(m_symbol, m_ltfTF, ltfShift);
   m_ltfPrevClose = iClose(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevHigh = iHigh(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevLow = iLow(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevPrevHigh = iHigh(m_symbol, m_ltfTF, ltfShift + 2);
   m_ltfPrevPrevLow = iLow(m_symbol, m_ltfTF, ltfShift + 2);
   
   if(m_htfOpen == 0 || m_htfClose == 0 || m_ltfOpen == 0)
   {
      LOG_DEBUG("❌ Failed to fetch candle data (shift: HTF=" + IntegerToString(htfShift) + 
                ", LTF=" + IntegerToString(ltfShift) + ")", m_debugEnabled);
      return false;
   }
   
   if(m_debugEnabled)
   {
      string htfStatus = IsCandleClosed(m_htfTF) ? "CLOSED" : "OPEN (using previous)";
      string ltfStatus = IsCandleClosed(m_ltfTF) ? "CLOSED" : "OPEN (using previous)";
      LOG_DEBUG("📊 Candle data fetched: HTF " + htfStatus + " (shift=" + IntegerToString(htfShift) + 
                "), LTF " + ltfStatus + " (shift=" + IntegerToString(ltfShift) + ")", m_debugEnabled);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Candle Range                                                |
//+------------------------------------------------------------------+
double CCandleModule::GetCandleRange(ENUM_TIMEFRAMES tf, int shift)
{
   // Always use the closed candle shift internally
   int closedShift = shift + GetClosedCandleShift(tf);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   return (high - low) / m_pointValue;
}

//+------------------------------------------------------------------+
//| Get Pullback Depth                                              |
//+------------------------------------------------------------------+
double CCandleModule::GetPullbackDepth(ENUM_TIMEFRAMES tf, int lookback)
{
   int closedShift = GetClosedCandleShift(tf);
   double high = 0, low = DBL_MAX;
   
   for(int i = 0; i < lookback; i++)
   {
      int shift = closedShift + i;
      double h = iHigh(m_symbol, tf, shift);
      double l = iLow(m_symbol, tf, shift);
      if(h > high) high = h;
      if(l < low) low = l;
   }
   
   if(high == low) return 0;
   double currentClose = iClose(m_symbol, tf, closedShift);
   double range = high - low;
   return ((high - currentClose) / range) * 100;
}

//+------------------------------------------------------------------+
//| Is Exhaustion Candle                                            |
//+------------------------------------------------------------------+
bool CCandleModule::IsExhaustionCandle(ENUM_TIMEFRAMES tf, int direction)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   double prevClose = iClose(m_symbol, tf, closedShift + 1);
   double prevHigh = iHigh(m_symbol, tf, closedShift + 1);
   double prevLow = iLow(m_symbol, tf, closedShift + 1);
   
   if(open == 0 || close == 0) return false;
   
   double range = high - low;
   double body = MathAbs(close - open);
   double tolerance = m_tolerance;
   
   if(direction == 1) // Bullish exhaustion
   {
      // Check if candle is near high (small body, long wick)
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      
      // Bullish exhaustion: small body, long upper wick, or doji
      bool smallBody = body < range * 0.3;
      bool longUpperWick = upperWick > range * 0.5;
      bool openNearPrevHigh = open >= prevHigh - tolerance;
      bool closeNearOpen = MathAbs(close - open) < tolerance * 2;
      
      return (smallBody && longUpperWick) || 
             (openNearPrevHigh && closeNearOpen) ||
             (upperWick > lowerWick * 2 && smallBody);
   }
   else if(direction == -1) // Bearish exhaustion
   {
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      
      // Bearish exhaustion: small body, long lower wick, or doji
      bool smallBody = body < range * 0.3;
      bool longLowerWick = lowerWick > range * 0.5;
      bool openNearPrevLow = open <= prevLow + tolerance;
      bool closeNearOpen = MathAbs(close - open) < tolerance * 2;
      
      return (smallBody && longLowerWick) || 
             (openNearPrevLow && closeNearOpen) ||
             (lowerWick > upperWick * 2 && smallBody);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Is Doji Candle                                                  |
//+------------------------------------------------------------------+
bool CCandleModule::IsDojiCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   
   if(open == 0 || close == 0) return false;
   
   double range = high - low;
   if(range == 0) return false;
   
   return MathAbs(close - open) < range * 0.1;
}

//+------------------------------------------------------------------+
//| Is Inside Candle                                                |
//+------------------------------------------------------------------+
bool CCandleModule::IsInsideCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   double prevHigh = iHigh(m_symbol, tf, closedShift + 1);
   double prevLow = iLow(m_symbol, tf, closedShift + 1);
   
   return high < prevHigh && low > prevLow;
}

//+------------------------------------------------------------------+
//| Is Engulfing Candle                                             |
//+------------------------------------------------------------------+
bool CCandleModule::IsEngulfingCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double prevOpen = iOpen(m_symbol, tf, closedShift + 1);
   double prevClose = iClose(m_symbol, tf, closedShift + 1);
   
   if(open == 0 || close == 0 || prevOpen == 0 || prevClose == 0) return false;
   
   bool bullishEngulf = close > open && prevClose < prevOpen && 
                        close > prevOpen && open < prevClose;
   bool bearishEngulf = close < open && prevClose > prevOpen && 
                        close < prevOpen && open > prevClose;
   
   return bullishEngulf || bearishEngulf;
}

//+------------------------------------------------------------------+
//| Is Pin Bar Candle                                               |
//+------------------------------------------------------------------+
bool CCandleModule::IsPinBarCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   
   if(open == 0 || close == 0) return false;
   
   double range = high - low;
   if(range == 0) return false;
   
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double body = MathAbs(close - open);
   
   // Pin bar: long wick (> 2x body) on one side
   return (upperWick > body * 2 && upperWick > range * 0.6) ||
          (lowerWick > body * 2 && lowerWick > range * 0.6);
}

//+------------------------------------------------------------------+
//| Get Candle Pattern                                              |
//+------------------------------------------------------------------+
string CCandleModule::GetCandlePattern(ENUM_TIMEFRAMES tf)
{
   if(IsDojiCandle(tf)) return "DOJI";
   if(IsEngulfingCandle(tf)) return "ENGULFING";
   if(IsInsideCandle(tf)) return "INSIDE";
   if(IsPinBarCandle(tf)) return "PIN_BAR";
   if(IsExhaustionCandle(tf, 1)) return "BULLISH_EXHAUSTION";
   if(IsExhaustionCandle(tf, -1)) return "BEARISH_EXHAUSTION";
   return "NORMAL";
}

//+------------------------------------------------------------------+
//| Get Pattern Strength                                            |
//+------------------------------------------------------------------+
double CCandleModule::GetPatternStrength(ENUM_TIMEFRAMES tf)
{
   string pattern = GetCandlePattern(tf);
   
   if(pattern == "BULLISH_EXHAUSTION" || pattern == "BEARISH_EXHAUSTION")
      return 80.0;
   if(pattern == "ENGULFING")
      return 85.0;
   if(pattern == "PIN_BAR")
      return 75.0;
   if(pattern == "DOJI")
      return 60.0;
   if(pattern == "INSIDE")
      return 50.0;
   return 30.0;
}

//+------------------------------------------------------------------+
//| Get Pattern Display - Returns pattern with strength percentage  |
//+------------------------------------------------------------------+
string CCandleModule::GetPatternDisplay(ENUM_TIMEFRAMES tf)
{
   string pattern = GetCandlePattern(tf);
   double strength = GetPatternStrength(tf);
   
   // Add emoji for visual distinction
   string emoji = "";
   if(pattern == "ENGULFING") emoji = "🔥";
   else if(pattern == "BULLISH_EXHAUSTION" || pattern == "BEARISH_EXHAUSTION") emoji = "💪";
   else if(pattern == "PIN_BAR") emoji = "📌";
   else if(pattern == "DOJI") emoji = "⚖️";
   else if(pattern == "INSIDE") emoji = "📦";
   else emoji = "➖";
   
   // Add a note if using previous candle (candle still open)
   string note = "";
   if(!IsCandleClosed(tf))
      note = " (prev)";
   
   return StringFormat("%s %s (%.0f%%)%s", emoji, pattern, strength, note);
}

//+------------------------------------------------------------------+
//| Analyze Exhaustion - MAIN FUNCTION (FIXED WAIT LOGIC)          |
//+------------------------------------------------------------------+
SExhaustionResult CCandleModule::AnalyzeExhaustion(int trendDirection, double cooldownRemaining)
{
   SExhaustionResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.isBullish = false;
   result.isBearish = false;
   result.htfExhaustion = false;
   result.ltfExhaustion = false;
   result.type = "NONE";
   result.description = "No exhaustion detected";
   result.confidence = 0;
   result.cooldownReset = false;
   result.resetReason = "";
   result.timestamp = TimeCurrent();
   result.htfDirection = trendDirection;
   result.htfPullbackDepth = 0;
   result.ltfPullbackDepth = 0;
   result.htfPattern = "NORMAL";
   result.ltfPattern = "NORMAL";
   result.htfPatternStrength = 30.0;
   result.ltfPatternStrength = 30.0;
   result.candlesWaited = 0;
   result.candlesRequired = m_waitCandleCount;
   result.waitStatus = "Checking...";
   
   // ─── FETCH CANDLE DATA ───
   if(!FetchCandleData())
   {
      result.description = "Failed to fetch candle data";
      return result;
   }
   
   // ═══ CHECK COOLDOWN CANDLE WAIT STATUS ═══
   datetime currentTime = TimeCurrent();
   datetime currentCandleTime = iTime(m_symbol, m_htfTF, 0);
   bool candleClosed = IsCandleClosed(m_htfTF);
   
   // ═══ FIXED: Calculate closed candles correctly ═══
   // We need to count how many M15 candles have COMPLETELY CLOSED since cooldown started
   // The cooldown started at m_cooldownStartCandleTime
   // A candle is considered "waited" only when it is fully closed
   
   int closedCandlesWaited = 0;
   
   if(m_cooldownStartCandleTime > 0)
   {
      // Get the time of the most recent closed candle
      int shift = 0;
      if(!candleClosed)
         shift = 1;  // Current candle is open, use previous closed candle
      
      datetime lastClosedCandleTime = iTime(m_symbol, m_htfTF, shift);
      
      // Count how many 15-minute intervals have passed between cooldown start and last closed candle
      if(lastClosedCandleTime > m_cooldownStartCandleTime)
      {
         int diffSeconds = (int)(lastClosedCandleTime - m_cooldownStartCandleTime);
         closedCandlesWaited = diffSeconds / 900; // 15 minutes = 900 seconds
      }
      else if(lastClosedCandleTime == m_cooldownStartCandleTime)
      {
         // The cooldown started on a candle that is now closed
         // This means we've waited for that candle to close
         closedCandlesWaited = 1;
      }
      
      // Ensure we don't count the current candle if it's not closed yet
      if(!candleClosed && closedCandlesWaited > 0)
      {
         // The current candle is open, so we're still waiting for it to close
         // The count should be the number of fully closed candles
         // No adjustment needed - we already used the previous closed candle
      }
      
      m_candlesWaited = closedCandlesWaited;
   }
   result.candlesWaited = closedCandlesWaited;
   result.candlesRequired = m_waitCandleCount;
   
   // ═══ Check if we have enough CLOSED candles ═══
   bool enoughCandlesWaited = (closedCandlesWaited >= m_waitCandleCount);
   
   if(!enoughCandlesWaited)
   {
      // Build wait status description
      int candlesNeeded = m_waitCandleCount - closedCandlesWaited;
      string waitDesc = StringFormat("Waiting for %d more closed candle(s) (have %d of %d)", 
                                     candlesNeeded, closedCandlesWaited, m_waitCandleCount);
      result.waitStatus = StringFormat("⏳ %s", waitDesc);
      result.description = "WAITING: " + result.waitStatus;
      result.isValid = false;
      result.cooldownReset = false;
      return result;
   }
   
   // ═══ WE HAVE ENOUGH CLOSED CANDLES - PROCEED WITH ANALYSIS ═══
   result.waitStatus = "✅ Ready - analyzing " + IntegerToString(m_waitCandleCount) + " closed candle(s)";
   
   // ─── CALCULATE PULLBACK DEPTHS ───
   result.htfPullbackDepth = GetPullbackDepth(m_htfTF, 5);
   result.ltfPullbackDepth = GetPullbackDepth(m_ltfTF, 3);
   
   // ─── GET PATTERNS ───
   result.htfPattern = GetCandlePattern(m_htfTF);
   result.ltfPattern = GetCandlePattern(m_ltfTF);
   result.htfPatternStrength = GetPatternStrength(m_htfTF);
   result.ltfPatternStrength = GetPatternStrength(m_ltfTF);
   
   // ─── HTF EXHAUSTION CHECK ───
   double tol = m_tolerance;
   
   // Bullish exhaustion: Open near previous close + pullback slowing
   bool htfOpenInFavorBull = (m_htfOpen >= m_htfPrevClose - tol);
   bool htfPullbackSlowingBull = (m_htfPrevLow >= m_htfPrevPrevLow);
   bool htfExhaustionBull = htfOpenInFavorBull && htfPullbackSlowingBull;
   htfExhaustionBull = htfExhaustionBull || IsExhaustionCandle(m_htfTF, 1);
   htfExhaustionBull = htfExhaustionBull || IsPinBarCandle(m_htfTF);
   htfExhaustionBull = htfExhaustionBull || IsDojiCandle(m_htfTF);
   
   // Bearish exhaustion: Open near previous close + pullback slowing
   bool htfOpenInFavorBear = (m_htfOpen <= m_htfPrevClose + tol);
   bool htfPullbackSlowingBear = (m_htfPrevHigh <= m_htfPrevPrevHigh);
   bool htfExhaustionBear = htfOpenInFavorBear && htfPullbackSlowingBear;
   htfExhaustionBear = htfExhaustionBear || IsExhaustionCandle(m_htfTF, -1);
   htfExhaustionBear = htfExhaustionBear || IsPinBarCandle(m_htfTF);
   htfExhaustionBear = htfExhaustionBear || IsDojiCandle(m_htfTF);
   
   // ─── LTF EXHAUSTION CHECK ───
   bool ltfOpenInFavorBull = (m_ltfOpen >= m_ltfPrevClose - tol);
   bool ltfPullbackSlowingBull = (m_ltfPrevLow >= m_ltfPrevPrevLow);
   bool ltfExhaustionBull = ltfOpenInFavorBull && ltfPullbackSlowingBull;
   ltfExhaustionBull = ltfExhaustionBull || IsExhaustionCandle(m_ltfTF, 1);
   ltfExhaustionBull = ltfExhaustionBull || IsPinBarCandle(m_ltfTF);
   ltfExhaustionBull = ltfExhaustionBull || IsDojiCandle(m_ltfTF);
   
   bool ltfOpenInFavorBear = (m_ltfOpen <= m_ltfPrevClose + tol);
   bool ltfPullbackSlowingBear = (m_ltfPrevHigh <= m_ltfPrevPrevHigh);
   bool ltfExhaustionBear = ltfOpenInFavorBear && ltfPullbackSlowingBear;
   ltfExhaustionBear = ltfExhaustionBear || IsExhaustionCandle(m_ltfTF, -1);
   ltfExhaustionBear = ltfExhaustionBear || IsPinBarCandle(m_ltfTF);
   ltfExhaustionBear = ltfExhaustionBear || IsDojiCandle(m_ltfTF);
   
   // ─── DECISION: BULLISH TREND ───
   if(trendDirection == 1)
   {
      result.htfExhaustion = htfExhaustionBull;
      result.ltfExhaustion = ltfExhaustionBull || ltfPullbackSlowingBull;
      
      // HTF must show exhaustion
      if(!htfExhaustionBull)
      {
         result.description = "HTF NO EXHAUSTION ❌";
         result.isValid = false;
         return result;
      }
      
      // LTF must show exhaustion or pullback slowing
      if(ltfExhaustionBull || ltfPullbackSlowingBull)
      {
         result.isValid = true;
         result.isBullish = true;
         result.isBearish = false;
         result.type = ltfExhaustionBull ? "EXHAUSTION" : "SLOWING";
         result.description = (ltfExhaustionBull) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         result.confidence = ltfExhaustionBull ? 85.0 : 70.0;
         result.cooldownReset = true;
         result.resetReason = "Bullish exhaustion detected - cooldown reset recommended";
         
         // Boost confidence with pattern detection
         string pattern = GetCandlePattern(m_htfTF);
         if(pattern == "ENGULFING" || pattern == "PIN_BAR")
            result.confidence += 10.0;
         if(IsDojiCandle(m_htfTF))
            result.confidence += 5.0;
         result.confidence = MathMin(100.0, result.confidence);
         
         return result;
      }
      else
      {
         result.description = "LTF ACTIVE PULLBACK ❌";
         result.isValid = false;
         return result;
      }
   }
   
   // ─── DECISION: BEARISH TREND ───
   else if(trendDirection == -1)
   {
      result.htfExhaustion = htfExhaustionBear;
      result.ltfExhaustion = ltfExhaustionBear || ltfPullbackSlowingBear;
      
      // HTF must show exhaustion
      if(!htfExhaustionBear)
      {
         result.description = "HTF NO EXHAUSTION ❌";
         result.isValid = false;
         return result;
      }
      
      // LTF must show exhaustion or pullback slowing
      if(ltfExhaustionBear || ltfPullbackSlowingBear)
      {
         result.isValid = true;
         result.isBullish = false;
         result.isBearish = true;
         result.type = ltfExhaustionBear ? "EXHAUSTION" : "SLOWING";
         result.description = (ltfExhaustionBear) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         result.confidence = ltfExhaustionBear ? 85.0 : 70.0;
         result.cooldownReset = true;
         result.resetReason = "Bearish exhaustion detected - cooldown reset recommended";
         
         // Boost confidence with pattern detection
         string pattern = GetCandlePattern(m_htfTF);
         if(pattern == "ENGULFING" || pattern == "PIN_BAR")
            result.confidence += 10.0;
         if(IsDojiCandle(m_htfTF))
            result.confidence += 5.0;
         result.confidence = MathMin(100.0, result.confidence);
         
         return result;
      }
      else
      {
         result.description = "LTF ACTIVE PULLBACK ❌";
         result.isValid = false;
         return result;
      }
   }
   else
   {
      result.description = "NEUTRAL TREND (skipped)";
      result.isValid = true;
      return result;
   }
}

//+------------------------------------------------------------------+
//| Should Reset Cooldown                                           |
//+------------------------------------------------------------------+
bool CCandleModule::ShouldResetCooldown(int trendDirection, double cooldownRemaining)
{
   // If no cooldown, no need to reset
   if(cooldownRemaining <= 0) return false;
   
   // If cooldown is almost over (less than 30 min), wait it out
   if(cooldownRemaining < 1800) return false;
   
   // Call AnalyzeExhaustion which handles the wait logic internally
   SExhaustionResult result = AnalyzeExhaustion(trendDirection, cooldownRemaining);
   
   // Log wait status periodically
   if(m_debugEnabled || g_debugCandleModule)
   {
      static datetime lastWaitLog = 0;
      if(TimeCurrent() - lastWaitLog >= 60)  // Log every minute
      {
         lastWaitLog = TimeCurrent();
         if(!result.isValid && result.candlesWaited < m_waitCandleCount)
         {
            LOG_DEBUG("🕯️ " + result.waitStatus, m_debugEnabled);
         }
      }
   }
   
   if(result.isValid && result.cooldownReset && result.confidence >= 60.0)
   {
      LOG_DEBUG("🔄 Cooldown reset recommended: " + result.resetReason, m_debugEnabled);
      LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 1) + "%", m_debugEnabled);
      LOG_DEBUG("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
      LOG_DEBUG("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
      LOG_DEBUG("   Candles Waited: " + IntegerToString(result.candlesWaited) + "/" + IntegerToString(result.candlesRequired), m_debugEnabled);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Reset Reason                                                |
//+------------------------------------------------------------------+
string CCandleModule::GetResetReason(int trendDirection)
{
   SExhaustionResult result = AnalyzeExhaustion(trendDirection, 0);
   
   if(result.isValid && result.cooldownReset)
      return result.resetReason;
   
   return "No exhaustion detected - continue cooldown";
}

//+------------------------------------------------------------------+
//| Get Status Report - FIXED with proper wait status               |
//+------------------------------------------------------------------+
string CCandleModule::GetStatusReport()
{
   if(!FetchCandleData())
      return "Failed to fetch candle data";
   
   string report = "";
   report += "═══════════════════════════════════════════\n";
   report += "🕯️ CANDLE MODULE STATUS REPORT\n";
   report += "───────────────────────────────────────────\n";
   report += StringFormat("HTF (M15): Open %.2f | Close %.2f | High %.2f | Low %.2f\n", 
                          m_htfOpen, m_htfClose, m_htfHigh, m_htfLow);
   report += StringFormat("LTF (M1):  Open %.2f\n", m_ltfOpen);
   
   // ═══ Show pattern with percentage ═══
   report += StringFormat("HTF Pattern: %s\n", GetPatternDisplay(m_htfTF));
   report += StringFormat("LTF Pattern: %s\n", GetPatternDisplay(m_ltfTF));
   
   // ═══ Show candle status (closed/open) ═══
   string htfStatus = IsCandleClosed(m_htfTF) ? "CLOSED" : "OPEN (using prev)";
   string ltfStatus = IsCandleClosed(m_ltfTF) ? "CLOSED" : "OPEN (using prev)";
   report += StringFormat("HTF Status: %s\n", htfStatus);
   report += StringFormat("LTF Status: %s\n", ltfStatus);
   
   report += StringFormat("HTF Pullback Depth: %.1f%%\n", GetPullbackDepth(m_htfTF, 5));
   report += StringFormat("LTF Pullback Depth: %.1f%%\n", GetPullbackDepth(m_ltfTF, 3));
   
   // ═══ FIXED: Show proper wait status using closed candles ═══
   if(m_waitForNextCandle || m_waitingForClose || m_candlesWaited < m_waitCandleCount)
   {
      // Calculate closed candles properly
      datetime currentTime = TimeCurrent();
      bool candleClosed = IsCandleClosed(m_htfTF);
      int closedCandlesWaited = 0;
      
      if(m_cooldownStartCandleTime > 0)
      {
         int shift = 0;
         if(!candleClosed)
            shift = 1;
         
         datetime lastClosedCandleTime = iTime(m_symbol, m_htfTF, shift);
         
         if(lastClosedCandleTime > m_cooldownStartCandleTime)
         {
            int diffSeconds = (int)(lastClosedCandleTime - m_cooldownStartCandleTime);
            closedCandlesWaited = diffSeconds / 900;
         }
         else if(lastClosedCandleTime == m_cooldownStartCandleTime)
         {
            closedCandlesWaited = 1;
         }
         else if(lastClosedCandleTime < m_cooldownStartCandleTime)
         {
            closedCandlesWaited = 0;
         }
         
         m_candlesWaited = closedCandlesWaited;
      }
      
      if(closedCandlesWaited >= m_waitCandleCount)
      {
         report += "───────────────────────────────────────────\n";
         report += "✅ Ready - have " + IntegerToString(closedCandlesWaited) + 
                   " of " + IntegerToString(m_waitCandleCount) + " closed candles\n";
      }
      else
      {
         report += "───────────────────────────────────────────\n";
         report += StringFormat("⏳ Waiting: %d of %d closed candles\n", 
                               closedCandlesWaited, m_waitCandleCount);
         int candlesNeeded = m_waitCandleCount - closedCandlesWaited;
         report += "   " + StringFormat("Waiting for %d more closed candle(s)", candlesNeeded) + "\n";
      }
   }
   else if(m_cooldownCandleInitialized)
   {
      report += "───────────────────────────────────────────\n";
      report += "✅ Ready - " + IntegerToString(m_candlesWaited) + " candles waited\n";
   }
   
   report += "═══════════════════════════════════════════\n";
   
   return report;
}

//+------------------------------------------------------------------+
//| Get Exhaustion Report - UPDATED with pattern displays          |
//+------------------------------------------------------------------+
string CCandleModule::GetExhaustionReport(SExhaustionResult &result)
{
   string report = "";
   report += "═══════════════════════════════════════════\n";
   report += "🕯️ EXHAUSTION DETECTION REPORT\n";
   report += "───────────────────────────────────────────\n";
   report += StringFormat("Valid: %s\n", result.isValid ? "✅ YES" : "❌ NO");
   report += StringFormat("Type: %s\n", result.type);
   report += StringFormat("Description: %s\n", result.description);
   report += StringFormat("Confidence: %.1f%%\n", result.confidence);
   report += StringFormat("HTF Exhaustion: %s\n", result.htfExhaustion ? "✅" : "❌");
   report += StringFormat("LTF Exhaustion: %s\n", result.ltfExhaustion ? "✅" : "❌");
   
   // ═══ Show patterns with percentages ═══
   report += StringFormat("HTF Pattern: %s (%.0f%%)\n", result.htfPattern, result.htfPatternStrength);
   report += StringFormat("LTF Pattern: %s (%.0f%%)\n", result.ltfPattern, result.ltfPatternStrength);
   
   report += StringFormat("HTF Pullback Depth: %.1f%%\n", result.htfPullbackDepth);
   report += StringFormat("LTF Pullback Depth: %.1f%%\n", result.ltfPullbackDepth);
   report += StringFormat("Reset Cooldown: %s\n", result.cooldownReset ? "✅ YES" : "❌ NO");
   if(result.cooldownReset)
      report += StringFormat("Reset Reason: %s\n", result.resetReason);
   
   // ═══ Show candle wait status ═══
   report += "───────────────────────────────────────────\n";
   report += StringFormat("Candles Waited: %d / %d\n", result.candlesWaited, result.candlesRequired);
   report += "Status: " + result.waitStatus + "\n";
   
   report += "═══════════════════════════════════════════\n";
   
   return report;
}