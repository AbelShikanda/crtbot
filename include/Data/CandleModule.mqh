//+------------------------------------------------------------------+
//|                        CandleModule.mqh                         |
//|                    Pullback Exhaustion Detection                 |
//|                    v1.08 - FIXED: CANDLE CLOSE EVENT TRACKING  |
//|                    Cooldown Mode: Wait 1-3 candles             |
//|                    Trading Mode: Check when candle closes      |
//|                    ENSURES DATA ALIGNMENT                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.08"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugCandleModule = false;

//+------------------------------------------------------------------+
//| ENUM: Candle Module Mode                                        |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_MODE
{
   CANDLE_MODE_COOLDOWN,    // Wait 1-3 candles, higher confidence threshold
   CANDLE_MODE_TRADING      // Check when candle closes, lower threshold
};

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
   ENUM_CANDLE_MODE mode;         // Which mode was used
   string   modeName;             // "COOLDOWN" or "TRADING"
   bool     waitingForCandleClose;// True if waiting for current candle to close
   bool     candleJustClosed;     // True if a candle just closed
   datetime checkedCandleTime;    // Time of the candle that was checked
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
   datetime m_cooldownStartCandleTime;
   bool     m_cooldownCandleInitialized;
   bool     m_waitForNextCandle;
   int      m_candlesWaited;
   datetime m_lastWaitLogTime;
   bool     m_waitingForClose;
   
   // ═══ CANDLE CLOSE EVENT TRACKING ═══
   datetime m_lastCheckedCandleTime;  // Time of the last candle we checked
   bool     m_hasCheckedCandle;       // Whether we've checked the current candle
   datetime m_candleCloseCheckTime;   // When we last checked for a close
   
   // ═══ MODE CONFIGURATION ═══
   double   m_cooldownConfidenceThreshold;  // Default: 60%
   double   m_tradingConfidenceThreshold;   // Default: 50%
   
   // ═══ METHODS ═══
   bool     FetchCandleData(int shift = 0);
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
   bool     IsCandleClosed(ENUM_TIMEFRAMES tf) const;
   bool     DidCandleJustClose(ENUM_TIMEFRAMES tf);
   datetime GetCandleTime(ENUM_TIMEFRAMES tf, int shift);
   SExhaustionResult AnalyzeExhaustionInternal(int trendDirection, ENUM_CANDLE_MODE mode, int candleShift = 0);
   
public:
   CCandleModule(string symbol = NULL, 
                 ENUM_TIMEFRAMES htfTF = PERIOD_M15,
                 ENUM_TIMEFRAMES ltfTF = PERIOD_M1);
   ~CCandleModule();
   
   void SetDebug(bool enable) { m_debugEnabled = enable; g_debugCandleModule = enable; }
   static void SetGlobalDebug(bool enable) { g_debugCandleModule = enable; }
   
   // ═══ CONFIGURATION ═══
   void SetWaitCandles(int count) { m_waitCandleCount = MathMax(1, MathMin(3, count)); }
   int GetWaitCandles() const { return m_waitCandleCount; }
   void SetConfidenceThresholds(double cooldownThreshold, double tradingThreshold);
   
   // ═══ INITIALIZATION ═══
   bool Initialize();
   void Shutdown();
   
   // ═══ COOLDOWN CANDLE TRACKING ═══
   void ResetCooldownCandleTracking();
   string GetCandleWaitStatus();
   bool IsWaitingForCandle() const { return m_waitForNextCandle || m_waitingForClose; }
   int GetCandlesWaited() const { return m_candlesWaited; }
   int GetCandlesRequired() const { return m_waitCandleCount; }
   
   // ═══ MAIN ANALYSIS - DUAL MODE ═══
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
   bool IsCurrentCandleClosed() const { return IsCandleClosed(m_htfTF); }
   string GetCurrentCandleStatus() const { 
      return IsCandleClosed(m_htfTF) ? "CLOSED" : "OPEN";
   }
   datetime GetLastCheckedCandleTime() const { return m_lastCheckedCandleTime; }
   bool HasCheckedCurrentCandle() const { return m_hasCheckedCandle; }
   
   // ═══ REPORTS ═══
   string GetStatusReport();
   string GetExhaustionReport(SExhaustionResult &result);
};

//=============================================================================
// CONSTRUCTOR
//=============================================================================
CCandleModule::CCandleModule(string symbol, ENUM_TIMEFRAMES htfTF, ENUM_TIMEFRAMES ltfTF)
{
   LOG_DEBUG("🔧 CCandleModule v1.08 constructor called", g_debugCandleModule);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_htfTF = (htfTF == PERIOD_CURRENT) ? PERIOD_M15 : htfTF;
   m_ltfTF = (ltfTF == PERIOD_CURRENT) ? PERIOD_M1 : ltfTF;
   m_debugEnabled = g_debugCandleModule;
   m_pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tolerance = m_pointValue * 2;
   m_waitCandleCount = MathMax(1, MathMin(3, InpCandleWaitCandles));
   
   // ═══ DEFAULT CONFIDENCE THRESHOLDS ═══
   m_cooldownConfidenceThreshold = 60.0;   // Cooldown mode: need higher confidence
   m_tradingConfidenceThreshold = 50.0;    // Trading mode: lower threshold for entry
   
   // Clear cached values
   m_htfOpen = 0; m_htfClose = 0; m_htfHigh = 0; m_htfLow = 0;
   m_htfPrevClose = 0; m_htfPrevHigh = 0; m_htfPrevLow = 0;
   m_htfPrevPrevHigh = 0; m_htfPrevPrevLow = 0;
   m_htfHighestHigh = 0; m_htfLowestLow = 0;
   m_ltfOpen = 0; m_ltfPrevClose = 0;
   m_ltfPrevHigh = 0; m_ltfPrevLow = 0;
   m_ltfPrevPrevHigh = 0; m_ltfPrevPrevLow = 0;
   
   m_cooldownStartCandleTime = 0;
   m_cooldownCandleInitialized = false;
   m_waitForNextCandle = false;
   m_waitingForClose = false;
   m_candlesWaited = 0;
   m_lastWaitLogTime = 0;
   
   // ═══ INITIALIZE CANDLE CLOSE TRACKING ═══
   m_lastCheckedCandleTime = 0;
   m_hasCheckedCandle = false;
   m_candleCloseCheckTime = 0;
   
   LOG_DEBUG("✅ CCandleModule v1.08 created", g_debugCandleModule);
   LOG_DEBUG("   HTF: M15 | LTF: M1", g_debugCandleModule);
   LOG_DEBUG("   Cooldown Mode: Wait " + IntegerToString(m_waitCandleCount) + " candles, Threshold: " + DoubleToString(m_cooldownConfidenceThreshold, 0) + "%", g_debugCandleModule);
   LOG_DEBUG("   Trading Mode: Check when candle closes, Threshold: " + DoubleToString(m_tradingConfidenceThreshold, 0) + "%", g_debugCandleModule);
   LOG_DEBUG("   📋 Mode selected based on cooldownRemaining > 0", g_debugCandleModule);
   LOG_DEBUG("   🔧 FIX v1.08: Track candle close events - check immediately when candle closes", g_debugCandleModule);
}

//=============================================================================
// DESTRUCTOR
//=============================================================================
CCandleModule::~CCandleModule()
{
   LOG_DEBUG("CCandleModule destructor called", g_debugCandleModule);
   Shutdown();
}

//=============================================================================
// SET CONFIDENCE THRESHOLDS
//=============================================================================
void CCandleModule::SetConfidenceThresholds(double cooldownThreshold, double tradingThreshold)
{
   m_cooldownConfidenceThreshold = MathMax(30.0, MathMin(90.0, cooldownThreshold));
   m_tradingConfidenceThreshold = MathMax(30.0, MathMin(90.0, tradingThreshold));
   LOG_DEBUG("Confidence thresholds: Cooldown=" + DoubleToString(m_cooldownConfidenceThreshold, 0) + 
             "% Trading=" + DoubleToString(m_tradingConfidenceThreshold, 0) + "%", m_debugEnabled);
}

//=============================================================================
// INITIALIZE
//=============================================================================
bool CCandleModule::Initialize()
{
   LOG_DEBUG("CCandleModule Initialize called", g_debugCandleModule);
   return true;
}

//=============================================================================
// SHUTDOWN
//=============================================================================
void CCandleModule::Shutdown()
{
   LOG_DEBUG("CCandleModule shutdown", g_debugCandleModule);
}

//=============================================================================
// RESET COOLDOWN CANDLE TRACKING
//=============================================================================
void CCandleModule::ResetCooldownCandleTracking()
{
   m_cooldownStartCandleTime = iTime(m_symbol, m_htfTF, 0);
   m_cooldownCandleInitialized = true;
   m_waitForNextCandle = true;
   m_waitingForClose = true;
   m_candlesWaited = 0;
   m_lastWaitLogTime = 0;
   
   LOG_DEBUG("🕯️ COOLDOWN STARTED", m_debugEnabled);
   LOG_DEBUG("   Start Candle Time: " + TimeToString(m_cooldownStartCandleTime), m_debugEnabled);
   LOG_DEBUG("   Will wait: " + IntegerToString(m_waitCandleCount) + " M15 candles", m_debugEnabled);
   LOG_DEBUG("   Mode: COOLDOWN (cooldownRemaining > 0)", m_debugEnabled);
}

//=============================================================================
// GET CANDLE WAIT STATUS
//=============================================================================
string CCandleModule::GetCandleWaitStatus()
{
   if(!m_waitForNextCandle && !m_waitingForClose) return "✅ Ready - checking exhaustion";
   if(!m_cooldownCandleInitialized) return "⏳ Not initialized";
   
   datetime currentTime = TimeCurrent();
   datetime currentCandleTime = iTime(m_symbol, m_htfTF, 0);
   bool candleClosed = IsCandleClosed(m_htfTF);
   
   int closedCandlesWaited = 0;
   if(m_cooldownStartCandleTime > 0)
   {
      int shift = 0;
      if(!candleClosed) shift = 1;
      
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
      return StringFormat("✅ Ready - have %d of %d closed candles", closedCandlesWaited, m_waitCandleCount);
   
   int candlesNeeded = m_waitCandleCount - closedCandlesWaited;
   return StringFormat("⏳ Waiting for %d more closed candle(s) (have %d of %d)", 
                      candlesNeeded, closedCandlesWaited, m_waitCandleCount);
}

//=============================================================================
// IS CANDLE CLOSED
//=============================================================================
bool CCandleModule::IsCandleClosed(ENUM_TIMEFRAMES tf) const
{
   datetime candleTime = iTime(m_symbol, tf, 0);
   datetime currentTime = TimeCurrent();
   int secondsPerCandle = PeriodSeconds(tf);
   return (currentTime >= candleTime + secondsPerCandle);
}

//=============================================================================
// GET CANDLE TIME
//=============================================================================
datetime CCandleModule::GetCandleTime(ENUM_TIMEFRAMES tf, int shift)
{
   return iTime(m_symbol, tf, shift);
}

//=============================================================================
// DID CANDLE JUST CLOSE?
//=============================================================================
bool CCandleModule::DidCandleJustClose(ENUM_TIMEFRAMES tf)
{
   datetime currentCandleTime = GetCandleTime(tf, 0);
   datetime currentTime = TimeCurrent();
   int secondsPerCandle = PeriodSeconds(tf);
   
   // Check if we have a new candle time
   if(currentCandleTime != m_lastCheckedCandleTime)
   {
      // The previous candle closed
      datetime previousCandleTime = GetCandleTime(tf, 1);
      
      // Check if the previous candle is fully closed
      if(currentTime >= previousCandleTime + secondsPerCandle)
      {
         // Previous candle is closed
         m_lastCheckedCandleTime = currentCandleTime;
         m_hasCheckedCandle = false;
         return true;
      }
   }
   return false;
}

//=============================================================================
// GET CLOSED CANDLE SHIFT
//=============================================================================
int CCandleModule::GetClosedCandleShift(ENUM_TIMEFRAMES tf)
{
   // Always return the most recent closed candle
   return IsCandleClosed(tf) ? 0 : 1;
}

//=============================================================================
// FETCH CANDLE DATA
//=============================================================================
bool CCandleModule::FetchCandleData(int shift)
{
   int htfShift = shift;
   int ltfShift = GetClosedCandleShift(m_ltfTF);
   
   // If shift is 0 and candle is not closed, use shift 1
   if(htfShift == 0 && !IsCandleClosed(m_htfTF))
      htfShift = 1;
   
   m_htfOpen = iOpen(m_symbol, m_htfTF, htfShift);
   m_htfClose = iClose(m_symbol, m_htfTF, htfShift);
   m_htfHigh = iHigh(m_symbol, m_htfTF, htfShift);
   m_htfLow = iLow(m_symbol, m_htfTF, htfShift);
   m_htfPrevClose = iClose(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevHigh = iHigh(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevLow = iLow(m_symbol, m_htfTF, htfShift + 1);
   m_htfPrevPrevHigh = iHigh(m_symbol, m_htfTF, htfShift + 2);
   m_htfPrevPrevLow = iLow(m_symbol, m_htfTF, htfShift + 2);
   
   m_ltfOpen = iOpen(m_symbol, m_ltfTF, ltfShift);
   m_ltfPrevClose = iClose(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevHigh = iHigh(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevLow = iLow(m_symbol, m_ltfTF, ltfShift + 1);
   m_ltfPrevPrevHigh = iHigh(m_symbol, m_ltfTF, ltfShift + 2);
   m_ltfPrevPrevLow = iLow(m_symbol, m_ltfTF, ltfShift + 2);
   
   if(m_htfOpen == 0 || m_htfClose == 0 || m_ltfOpen == 0)
   {
      LOG_DEBUG("❌ Failed to fetch candle data", m_debugEnabled);
      return false;
   }
   
   return true;
}

//=============================================================================
// IS EXHAUSTION CANDLE
//=============================================================================
bool CCandleModule::IsExhaustionCandle(ENUM_TIMEFRAMES tf, int direction)
{
   int closedShift = GetClosedCandleShift(tf);
   
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   double prevHigh = iHigh(m_symbol, tf, closedShift + 1);
   double prevLow = iLow(m_symbol, tf, closedShift + 1);
   
   if(open == 0 || close == 0) return false;
   
   double range = high - low;
   double body = MathAbs(close - open);
   double tolerance = m_tolerance;
   
   if(direction == 1) // Bullish exhaustion
   {
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      bool smallBody = body < range * 0.3;
      bool longUpperWick = upperWick > range * 0.5;
      bool openNearPrevHigh = open >= prevHigh - tolerance;
      bool closeNearOpen = MathAbs(close - open) < tolerance * 2;
      return (smallBody && longUpperWick) || (openNearPrevHigh && closeNearOpen) || (upperWick > lowerWick * 2 && smallBody);
   }
   else if(direction == -1) // Bearish exhaustion
   {
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      bool smallBody = body < range * 0.3;
      bool longLowerWick = lowerWick > range * 0.5;
      bool openNearPrevLow = open <= prevLow + tolerance;
      bool closeNearOpen = MathAbs(close - open) < tolerance * 2;
      return (smallBody && longLowerWick) || (openNearPrevLow && closeNearOpen) || (lowerWick > upperWick * 2 && smallBody);
   }
   
   return false;
}

//=============================================================================
// IS DOJI CANDLE
//=============================================================================
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

//=============================================================================
// IS PIN BAR CANDLE
//=============================================================================
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
   return (upperWick > body * 2 && upperWick > range * 0.6) ||
          (lowerWick > body * 2 && lowerWick > range * 0.6);
}

//=============================================================================
// GET CANDLE PATTERN
//=============================================================================
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

//=============================================================================
// IS ENGULFING CANDLE
//=============================================================================
bool CCandleModule::IsEngulfingCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   double open = iOpen(m_symbol, tf, closedShift);
   double close = iClose(m_symbol, tf, closedShift);
   double prevOpen = iOpen(m_symbol, tf, closedShift + 1);
   double prevClose = iClose(m_symbol, tf, closedShift + 1);
   if(open == 0 || close == 0 || prevOpen == 0 || prevClose == 0) return false;
   bool bullishEngulf = close > open && prevClose < prevOpen && close > prevOpen && open < prevClose;
   bool bearishEngulf = close < open && prevClose > prevOpen && close < prevOpen && open > prevClose;
   return bullishEngulf || bearishEngulf;
}

//=============================================================================
// IS INSIDE CANDLE
//=============================================================================
bool CCandleModule::IsInsideCandle(ENUM_TIMEFRAMES tf)
{
   int closedShift = GetClosedCandleShift(tf);
   double high = iHigh(m_symbol, tf, closedShift);
   double low = iLow(m_symbol, tf, closedShift);
   double prevHigh = iHigh(m_symbol, tf, closedShift + 1);
   double prevLow = iLow(m_symbol, tf, closedShift + 1);
   return high < prevHigh && low > prevLow;
}

//=============================================================================
// GET PATTERN STRENGTH
//=============================================================================
double CCandleModule::GetPatternStrength(ENUM_TIMEFRAMES tf)
{
   string pattern = GetCandlePattern(tf);
   if(pattern == "BULLISH_EXHAUSTION" || pattern == "BEARISH_EXHAUSTION") return 80.0;
   if(pattern == "ENGULFING") return 85.0;
   if(pattern == "PIN_BAR") return 75.0;
   if(pattern == "DOJI") return 60.0;
   if(pattern == "INSIDE") return 50.0;
   return 30.0;
}

//=============================================================================
// GET PATTERN DISPLAY
//=============================================================================
string CCandleModule::GetPatternDisplay(ENUM_TIMEFRAMES tf)
{
   string pattern = GetCandlePattern(tf);
   double strength = GetPatternStrength(tf);
   string emoji = "";
   if(pattern == "ENGULFING") emoji = "🔥";
   else if(pattern == "BULLISH_EXHAUSTION" || pattern == "BEARISH_EXHAUSTION") emoji = "💪";
   else if(pattern == "PIN_BAR") emoji = "📌";
   else if(pattern == "DOJI") emoji = "⚖️";
   else if(pattern == "INSIDE") emoji = "📦";
   else emoji = "➖";
   string note = !IsCandleClosed(tf) ? " (prev)" : "";
   return StringFormat("%s %s (%.0f%%)%s", emoji, pattern, strength, note);
}

//=============================================================================
// GET PULLBACK DEPTH
//=============================================================================
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

//=============================================================================
// ANALYZE EXHAUSTION INTERNAL - Core Analysis Logic
//=============================================================================
SExhaustionResult CCandleModule::AnalyzeExhaustionInternal(int trendDirection, ENUM_CANDLE_MODE mode, int candleShift)
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
   result.mode = mode;
   result.modeName = (mode == CANDLE_MODE_COOLDOWN) ? "COOLDOWN" : "TRADING";
   result.candlesRequired = (mode == CANDLE_MODE_COOLDOWN) ? m_waitCandleCount : 1;
   result.waitingForCandleClose = false;
   result.candleJustClosed = false;
   result.checkedCandleTime = 0;
   
   LOG_DEBUG("📋 INTERNAL ANALYSIS - Mode: " + result.modeName + " (Shift: " + IntegerToString(candleShift) + ")", m_debugEnabled);
   
   // ─── FETCH DATA ───
   if(!FetchCandleData(candleShift))
   {
      result.description = "Failed to fetch candle data";
      LOG_DEBUG("❌ " + result.description, m_debugEnabled);
      return result;
   }
   
   // Store the candle time we're checking
   result.checkedCandleTime = GetCandleTime(m_htfTF, candleShift);
   
   LOG_DEBUG("✅ Candle data fetched for candle at: " + TimeToString(result.checkedCandleTime), m_debugEnabled);
   
   // ─── CALCULATE PULLBACK DEPTHS ───
   result.htfPullbackDepth = GetPullbackDepth(m_htfTF, 5);
   result.ltfPullbackDepth = GetPullbackDepth(m_ltfTF, 3);
   LOG_DEBUG("   HTF Pullback: " + DoubleToString(result.htfPullbackDepth, 1) + "%", m_debugEnabled);
   LOG_DEBUG("   LTF Pullback: " + DoubleToString(result.ltfPullbackDepth, 1) + "%", m_debugEnabled);
   
   // ─── GET PATTERNS ───
   result.htfPattern = GetCandlePattern(m_htfTF);
   result.ltfPattern = GetCandlePattern(m_ltfTF);
   result.htfPatternStrength = GetPatternStrength(m_htfTF);
   result.ltfPatternStrength = GetPatternStrength(m_ltfTF);
   LOG_DEBUG("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
   LOG_DEBUG("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
   
   // ─── EXHAUSTION CHECKS ───
   double tol = m_tolerance;
   
   // HTF Exhaustion
   bool htfOpenInFavorBull = (m_htfOpen >= m_htfPrevClose - tol);
   bool htfPullbackSlowingBull = (m_htfPrevLow >= m_htfPrevPrevLow);
   bool htfExhaustionBull = htfOpenInFavorBull && htfPullbackSlowingBull;
   htfExhaustionBull = htfExhaustionBull || IsExhaustionCandle(m_htfTF, 1);
   htfExhaustionBull = htfExhaustionBull || IsPinBarCandle(m_htfTF);
   htfExhaustionBull = htfExhaustionBull || IsDojiCandle(m_htfTF);
   
   bool htfOpenInFavorBear = (m_htfOpen <= m_htfPrevClose + tol);
   bool htfPullbackSlowingBear = (m_htfPrevHigh <= m_htfPrevPrevHigh);
   bool htfExhaustionBear = htfOpenInFavorBear && htfPullbackSlowingBear;
   htfExhaustionBear = htfExhaustionBear || IsExhaustionCandle(m_htfTF, -1);
   htfExhaustionBear = htfExhaustionBear || IsPinBarCandle(m_htfTF);
   htfExhaustionBear = htfExhaustionBear || IsDojiCandle(m_htfTF);
   
   LOG_DEBUG("   HTF Exhaustion (Bull): " + (htfExhaustionBull ? "✅" : "❌"), m_debugEnabled);
   LOG_DEBUG("   HTF Exhaustion (Bear): " + (htfExhaustionBear ? "✅" : "❌"), m_debugEnabled);
   
   // LTF Exhaustion
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
   
   LOG_DEBUG("   LTF Exhaustion (Bull): " + (ltfExhaustionBull ? "✅" : "❌"), m_debugEnabled);
   LOG_DEBUG("   LTF Exhaustion (Bear): " + (ltfExhaustionBear ? "✅" : "❌"), m_debugEnabled);
   
   // ─── DECISION BASED ON TREND DIRECTION ───
   if(trendDirection == 1)
   {
      LOG_DEBUG("📊 TREND: BULLISH", m_debugEnabled);
      result.htfExhaustion = htfExhaustionBull;
      result.ltfExhaustion = ltfExhaustionBull || ltfPullbackSlowingBull;
      
      if(!htfExhaustionBull)
      {
         result.description = "HTF NO EXHAUSTION ❌";
         LOG_DEBUG("❌ " + result.description, m_debugEnabled);
         return result;
      }
      LOG_DEBUG("✅ HTF Exhaustion confirmed", m_debugEnabled);
      
      if(ltfExhaustionBull || ltfPullbackSlowingBull)
      {
         result.isValid = true;
         result.isBullish = true;
         result.isBearish = false;
         result.type = ltfExhaustionBull ? "EXHAUSTION" : "SLOWING";
         result.description = (ltfExhaustionBull) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         
         // Confidence calculation
         result.confidence = ltfExhaustionBull ? 85.0 : 70.0;
         string pattern = GetCandlePattern(m_htfTF);
         if(pattern == "ENGULFING" || pattern == "PIN_BAR") result.confidence += 10.0;
         if(IsDojiCandle(m_htfTF)) result.confidence += 5.0;
         result.confidence = MathMin(100.0, result.confidence);
         
         result.cooldownReset = true;
         result.resetReason = "Bullish exhaustion detected" + 
                              StringFormat(" (Conf: %.0f%%)", result.confidence);
         
         LOG_DEBUG("✅ RESULT: " + result.description, m_debugEnabled);
         LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
         LOG_DEBUG("   Type: " + result.type, m_debugEnabled);
         return result;
      }
      else
      {
         result.description = "LTF ACTIVE PULLBACK ❌";
         LOG_DEBUG("❌ " + result.description, m_debugEnabled);
         return result;
      }
   }
   else if(trendDirection == -1)
   {
      LOG_DEBUG("📊 TREND: BEARISH", m_debugEnabled);
      result.htfExhaustion = htfExhaustionBear;
      result.ltfExhaustion = ltfExhaustionBear || ltfPullbackSlowingBear;
      
      if(!htfExhaustionBear)
      {
         result.description = "HTF NO EXHAUSTION ❌";
         LOG_DEBUG("❌ " + result.description, m_debugEnabled);
         return result;
      }
      LOG_DEBUG("✅ HTF Exhaustion confirmed", m_debugEnabled);
      
      if(ltfExhaustionBear || ltfPullbackSlowingBear)
      {
         result.isValid = true;
         result.isBullish = false;
         result.isBearish = true;
         result.type = ltfExhaustionBear ? "EXHAUSTION" : "SLOWING";
         result.description = (ltfExhaustionBear) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         
         result.confidence = ltfExhaustionBear ? 85.0 : 70.0;
         string pattern = GetCandlePattern(m_htfTF);
         if(pattern == "ENGULFING" || pattern == "PIN_BAR") result.confidence += 10.0;
         if(IsDojiCandle(m_htfTF)) result.confidence += 5.0;
         result.confidence = MathMin(100.0, result.confidence);
         
         result.cooldownReset = true;
         result.resetReason = "Bearish exhaustion detected" + 
                              StringFormat(" (Conf: %.0f%%)", result.confidence);
         
         LOG_DEBUG("✅ RESULT: " + result.description, m_debugEnabled);
         LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
         LOG_DEBUG("   Type: " + result.type, m_debugEnabled);
         return result;
      }
      else
      {
         result.description = "LTF ACTIVE PULLBACK ❌";
         LOG_DEBUG("❌ " + result.description, m_debugEnabled);
         return result;
      }
   }
   else
   {
      result.description = "NEUTRAL TREND (skipped)";
      result.isValid = true;
      LOG_DEBUG("📊 TREND: NEUTRAL - Skipping exhaustion check", m_debugEnabled);
      return result;
   }
}

//=============================================================================
// ANALYZE EXHAUSTION - DUAL MODE ENTRY POINT
// ═══ FIX v1.08: Track candle close events ═══
//=============================================================================
SExhaustionResult CCandleModule::AnalyzeExhaustion(int trendDirection, double cooldownRemaining)
{
   SExhaustionResult result;
   ZeroMemory(result);
   
   LOG_DEBUG("═══════════════════════════════════════════", m_debugEnabled);
   LOG_DEBUG("🕯️ ANALYZE EXHAUSTION - v1.08", m_debugEnabled);
   LOG_DEBUG("   Trend Direction: " + (trendDirection == 1 ? "BULLISH" : trendDirection == -1 ? "BEARISH" : "NEUTRAL"), m_debugEnabled);
   LOG_DEBUG("   Cooldown Remaining: " + DoubleToString(cooldownRemaining, 0) + "s", m_debugEnabled);
   LOG_DEBUG("   Last Checked Candle: " + TimeToString(m_lastCheckedCandleTime), m_debugEnabled);
   LOG_DEBUG("═══════════════════════════════════════════", m_debugEnabled);
   
   // ─── DETERMINE MODE ───
   bool isCooldown = (cooldownRemaining > 0);
   ENUM_CANDLE_MODE mode = isCooldown ? CANDLE_MODE_COOLDOWN : CANDLE_MODE_TRADING;
   
   string modeName = (mode == CANDLE_MODE_COOLDOWN) ? "COOLDOWN" : "TRADING";
   string modeReason = isCooldown ? 
                       "cooldownRemaining = " + DoubleToString(cooldownRemaining, 0) + "s > 0" : 
                       "cooldownRemaining = 0 (not in cooldown)";
   
   LOG_DEBUG("📋 MODE SELECTION:", m_debugEnabled);
   LOG_DEBUG("   Selected Mode: " + modeName, m_debugEnabled);
   LOG_DEBUG("   Reason: " + modeReason, m_debugEnabled);
   LOG_DEBUG("   Threshold: " + DoubleToString((mode == CANDLE_MODE_COOLDOWN) ? m_cooldownConfidenceThreshold : m_tradingConfidenceThreshold, 0) + "%", m_debugEnabled);
   LOG_DEBUG("   Candles Required: " + IntegerToString((mode == CANDLE_MODE_COOLDOWN) ? m_waitCandleCount : 1), m_debugEnabled);
   
   if(mode == CANDLE_MODE_COOLDOWN)
   {
      // ═══════════════════════════════════════════════════════════════
      // ═══ COOLDOWN MODE: Wait 1-3 candles, higher threshold ═══
      // ═══════════════════════════════════════════════════════════════
      
      LOG_DEBUG("───────────────────────────────────────────", m_debugEnabled);
      LOG_DEBUG("🔄 COOLDOWN MODE ACTIVE", m_debugEnabled);
      LOG_DEBUG("   Waiting: " + IntegerToString(m_waitCandleCount) + " M15 candles", m_debugEnabled);
      LOG_DEBUG("   Confidence Threshold: " + DoubleToString(m_cooldownConfidenceThreshold, 0) + "%", m_debugEnabled);
      LOG_DEBUG("───────────────────────────────────────────", m_debugEnabled);
      
      // ─── COOLDOWN WAIT CHECK ───
      bool candleClosed = IsCandleClosed(m_htfTF);
      int closedCandlesWaited = 0;
      
      if(m_cooldownStartCandleTime > 0)
      {
         int shift = candleClosed ? 0 : 1;
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
         m_candlesWaited = closedCandlesWaited;
      }
      
      result.candlesWaited = closedCandlesWaited;
      result.candlesRequired = m_waitCandleCount;
      result.waitingForCandleClose = false;
      result.candleJustClosed = false;
      
      LOG_DEBUG("📊 Cooldown Progress:", m_debugEnabled);
      LOG_DEBUG("   Candles Waited: " + IntegerToString(closedCandlesWaited) + "/" + IntegerToString(m_waitCandleCount), m_debugEnabled);
      
      if(closedCandlesWaited < m_waitCandleCount)
      {
         int needed = m_waitCandleCount - closedCandlesWaited;
         result.waitStatus = StringFormat("⏳ Cooldown: Waiting for %d more candle(s) (have %d of %d)", 
                                          needed, closedCandlesWaited, m_waitCandleCount);
         result.description = "WAITING: " + result.waitStatus;
         result.isValid = false;
         LOG_DEBUG("⏳ " + result.waitStatus, m_debugEnabled);
         LOG_DEBUG("❌ Cooldown: Not enough candles yet - EXITING", m_debugEnabled);
         return result;
      }
      
      result.waitStatus = "✅ Cooldown: Ready - " + IntegerToString(closedCandlesWaited) + " candles waited";
      LOG_DEBUG("✅ " + result.waitStatus, m_debugEnabled);
      
      // ─── RUN ANALYSIS ───
      LOG_DEBUG("🔍 Running exhaustion analysis (Cooldown Mode)...", m_debugEnabled);
      result = AnalyzeExhaustionInternal(trendDirection, mode, 0);
      
      // ─── APPLY COOLDOWN THRESHOLD ───
      if(result.isValid && result.confidence < m_cooldownConfidenceThreshold)
      {
         result.isValid = false;
         result.description = "Cooldown: Confidence below threshold (" + 
                              DoubleToString(result.confidence, 0) + "% < " + 
                              DoubleToString(m_cooldownConfidenceThreshold, 0) + "%)";
         result.cooldownReset = false;
         LOG_DEBUG("❌ Cooldown: " + result.description, m_debugEnabled);
      }
      
      if(result.isValid)
      {
         LOG_DEBUG("✅ COOLDOWN EXHAUSTION CONFIRMED!", m_debugEnabled);
         LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
         LOG_DEBUG("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
         LOG_DEBUG("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
         LOG_DEBUG("   Reset Reason: " + result.resetReason, m_debugEnabled);
      }
      else
      {
         LOG_DEBUG("❌ Cooldown: No exhaustion or confidence too low", m_debugEnabled);
      }
   }
   else
   {
      // ═══════════════════════════════════════════════════════════════
      // ═══ TRADING MODE: Check when candle closes ═══
      // ═══ FIX v1.08: Track candle close events ═══
      // ═══════════════════════════════════════════════════════════════
      
      LOG_DEBUG("───────────────────────────────────────────", m_debugEnabled);
      LOG_DEBUG("📈 TRADING MODE ACTIVE", m_debugEnabled);
      LOG_DEBUG("   Strategy: Check when M15 candle closes", m_debugEnabled);
      LOG_DEBUG("   Confidence Threshold: " + DoubleToString(m_tradingConfidenceThreshold, 0) + "%", m_debugEnabled);
      LOG_DEBUG("───────────────────────────────────────────", m_debugEnabled);
      
      // ─── STEP 1: CHECK IF A CANDLE JUST CLOSED ───
      bool candleJustClosed = DidCandleJustClose(m_htfTF);
      
      if(candleJustClosed)
      {
         // ─── A CANDLE JUST CLOSED - CHECK IT! ───
         datetime closedCandleTime = GetCandleTime(m_htfTF, 1);
         LOG_DEBUG("✅ CANDLE JUST CLOSED! Checking exhaustion on candle at: " + TimeToString(closedCandleTime), m_debugEnabled);
         LOG_DEBUG("   This is the candle that just closed - analyzing now!", m_debugEnabled);
         
         result.candleJustClosed = true;
         result.checkedCandleTime = closedCandleTime;
         result.candlesWaited = 1;
         result.candlesRequired = 1;
         result.waitingForCandleClose = false;
         result.waitStatus = "✅ Candle just closed - checking exhaustion now!";
         
         // ─── RUN ANALYSIS ON THE CLOSED CANDLE (shift 1) ───
         result = AnalyzeExhaustionInternal(trendDirection, mode, 1);
         
         // Mark that we've checked this candle
         m_hasCheckedCandle = true;
         
         // ─── APPLY TRADING THRESHOLD ───
         if(result.isValid && result.confidence < m_tradingConfidenceThreshold)
         {
            result.isValid = false;
            result.description = "Trading: Confidence below threshold (" + 
                                 DoubleToString(result.confidence, 0) + "% < " + 
                                 DoubleToString(m_tradingConfidenceThreshold, 0) + "%)";
            result.cooldownReset = false;
            LOG_DEBUG("❌ Trading: " + result.description, m_debugEnabled);
         }
         
         if(result.isValid)
         {
            LOG_DEBUG("✅ TRADING EXHAUSTION CONFIRMED ON CLOSED CANDLE!", m_debugEnabled);
            LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
            LOG_DEBUG("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
            LOG_DEBUG("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
            LOG_DEBUG("   Type: " + result.type, m_debugEnabled);
            LOG_DEBUG("   ✅ Data aligned: Same candle used for both Trend and Exhaustion", m_debugEnabled);
         }
         else
         {
            LOG_DEBUG("❌ Trading: No exhaustion on closed candle or confidence too low", m_debugEnabled);
         }
         
         return result;
      }
      
      // ─── STEP 2: CHECK IF CURRENT CANDLE IS CLOSED ───
      bool currentCandleClosed = IsCandleClosed(m_htfTF);
      
      if(currentCandleClosed)
      {
         // ─── CURRENT CANDLE IS CLOSED - CHECK IT ───
         datetime currentCandleTime = GetCandleTime(m_htfTF, 0);
         LOG_DEBUG("✅ Current candle is closed! Checking exhaustion at: " + TimeToString(currentCandleTime), m_debugEnabled);
         
         result.candleJustClosed = false;
         result.checkedCandleTime = currentCandleTime;
         result.candlesWaited = 1;
         result.candlesRequired = 1;
         result.waitingForCandleClose = false;
         result.waitStatus = "✅ Current candle is closed - checking exhaustion";
         
         // ─── RUN ANALYSIS ───
         result = AnalyzeExhaustionInternal(trendDirection, mode, 0);
         
         // ─── APPLY TRADING THRESHOLD ───
         if(result.isValid && result.confidence < m_tradingConfidenceThreshold)
         {
            result.isValid = false;
            result.description = "Trading: Confidence below threshold (" + 
                                 DoubleToString(result.confidence, 0) + "% < " + 
                                 DoubleToString(m_tradingConfidenceThreshold, 0) + "%)";
            result.cooldownReset = false;
            LOG_DEBUG("❌ Trading: " + result.description, m_debugEnabled);
         }
         
         if(result.isValid)
         {
            LOG_DEBUG("✅ TRADING EXHAUSTION CONFIRMED!", m_debugEnabled);
            LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
            LOG_DEBUG("   HTF Pattern: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
            LOG_DEBUG("   LTF Pattern: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
            LOG_DEBUG("   Type: " + result.type, m_debugEnabled);
         }
         else
         {
            LOG_DEBUG("❌ Trading: No exhaustion or confidence too low", m_debugEnabled);
         }
         
         return result;
      }
      
      // ─── STEP 3: WAIT FOR CANDLE CLOSE ───
      datetime currentCandleTime = GetCandleTime(m_htfTF, 0);
      datetime currentTime = TimeCurrent();
      int secondsPerCandle = PeriodSeconds(m_htfTF);
      int secondsRemaining = (int)((currentCandleTime + secondsPerCandle) - currentTime);
      int minutesRemaining = secondsRemaining / 60;
      int secondsLeft = secondsRemaining % 60;
      
      result.candleJustClosed = false;
      result.waitingForCandleClose = true;
      result.isValid = false;
      result.candlesWaited = 0;
      result.candlesRequired = 1;
      result.waitStatus = StringFormat("⏳ Trading Mode: Waiting for current M15 candle to close (%dm %ds remaining)",
                                       minutesRemaining, secondsLeft);
      result.description = "WAITING: " + result.waitStatus;
      result.checkedCandleTime = currentCandleTime;
      
      LOG_DEBUG("⏳ " + result.waitStatus, m_debugEnabled);
      LOG_DEBUG("   Current Candle Time: " + TimeToString(currentCandleTime), m_debugEnabled);
      LOG_DEBUG("   Current Time: " + TimeToString(currentTime), m_debugEnabled);
      LOG_DEBUG("   Will close at: " + TimeToString(currentCandleTime + secondsPerCandle), m_debugEnabled);
      LOG_DEBUG("   ❌ Trading Mode: Waiting for candle close - EXITING", m_debugEnabled);
      
      return result;
   }
   
   LOG_DEBUG("═══════════════════════════════════════════", m_debugEnabled);
   LOG_DEBUG("🕯️ ANALYZE EXHAUSTION COMPLETE", m_debugEnabled);
   LOG_DEBUG("   Mode: " + result.modeName, m_debugEnabled);
   LOG_DEBUG("   Valid: " + (result.isValid ? "✅ YES" : "❌ NO"), m_debugEnabled);
   LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
   LOG_DEBUG("   Candle Just Closed: " + (result.candleJustClosed ? "✅ YES" : "❌ NO"), m_debugEnabled);
   LOG_DEBUG("   Waiting for Candle Close: " + (result.waitingForCandleClose ? "✅ YES" : "❌ NO"), m_debugEnabled);
   LOG_DEBUG("═══════════════════════════════════════════", m_debugEnabled);
   
   return result;
}

//=============================================================================
// SHOULD RESET COOLDOWN - Uses Cooldown Mode
//=============================================================================
bool CCandleModule::ShouldResetCooldown(int trendDirection, double cooldownRemaining)
{
   LOG_DEBUG("🔄 ShouldResetCooldown called", m_debugEnabled);
   LOG_DEBUG("   Trend: " + (trendDirection == 1 ? "BULLISH" : trendDirection == -1 ? "BEARISH" : "NEUTRAL"), m_debugEnabled);
   LOG_DEBUG("   Cooldown Remaining: " + DoubleToString(cooldownRemaining, 0) + "s", m_debugEnabled);
   
   if(cooldownRemaining <= 0) 
   {
      LOG_DEBUG("❌ No cooldown - skipping reset check", m_debugEnabled);
      return false;
   }
   if(cooldownRemaining < 1800) 
   {
      LOG_DEBUG("⏳ Cooldown almost over (" + DoubleToString(cooldownRemaining/60, 0) + " min) - waiting it out", m_debugEnabled);
      return false;
   }
   
   LOG_DEBUG("📋 Cooldown > 30 min - checking for exhaustion reset", m_debugEnabled);
   SExhaustionResult result = AnalyzeExhaustion(trendDirection, cooldownRemaining);
   
   if(result.isValid && result.cooldownReset && result.confidence >= 60.0)
   {
      LOG_DEBUG("🔄 COOLDOWN RESET RECOMMENDED!", m_debugEnabled);
      LOG_DEBUG("   Reason: " + result.resetReason, m_debugEnabled);
      LOG_DEBUG("   Confidence: " + DoubleToString(result.confidence, 0) + "%", m_debugEnabled);
      LOG_DEBUG("   HTF: " + result.htfPattern + " (" + DoubleToString(result.htfPatternStrength, 0) + "%)", m_debugEnabled);
      LOG_DEBUG("   LTF: " + result.ltfPattern + " (" + DoubleToString(result.ltfPatternStrength, 0) + "%)", m_debugEnabled);
      return true;
   }
   
   LOG_DEBUG("❌ No reset needed - continuing cooldown", m_debugEnabled);
   return false;
}

//=============================================================================
// GET RESET REASON
//=============================================================================
string CCandleModule::GetResetReason(int trendDirection)
{
   SExhaustionResult result = AnalyzeExhaustion(trendDirection, 7200);
   return (result.isValid && result.cooldownReset) ? result.resetReason : "No exhaustion detected";
}

//=============================================================================
// GET STATUS REPORT
//=============================================================================
string CCandleModule::GetStatusReport()
{
   if(!FetchCandleData(0)) return "Failed to fetch candle data";
   
   string report = "";
   report += "═══════════════════════════════════════════\n";
   report += "🕯️ CANDLE MODULE STATUS REPORT (v1.08)\n";
   report += "───────────────────────────────────────────\n";
   report += "COOLDOWN MODE: Wait " + IntegerToString(m_waitCandleCount) + " candles, Threshold " + 
             DoubleToString(m_cooldownConfidenceThreshold, 0) + "%\n";
   report += "TRADING MODE:  Check when candle closes, Threshold " + 
             DoubleToString(m_tradingConfidenceThreshold, 0) + "%\n";
   report += "───────────────────────────────────────────\n";
   report += "Last Checked Candle: " + TimeToString(m_lastCheckedCandleTime) + "\n";
   report += "Has Checked Current Candle: " + (m_hasCheckedCandle ? "YES" : "NO") + "\n";
   report += "Current M15 Candle: " + GetCurrentCandleStatus() + "\n";
   if(!IsCurrentCandleClosed())
   {
      datetime currentCandleTime = iTime(m_symbol, m_htfTF, 0);
      datetime currentTime = TimeCurrent();
      int secondsPerCandle = PeriodSeconds(m_htfTF);
      int secondsRemaining = (int)((currentCandleTime + secondsPerCandle) - currentTime);
      report += "   Time remaining: " + IntegerToString(secondsRemaining / 60) + "m " + 
                IntegerToString(secondsRemaining % 60) + "s\n";
   }
   report += "───────────────────────────────────────────\n";
   report += StringFormat("HTF (M15): Open %.2f | Close %.2f | High %.2f | Low %.2f\n", 
                          m_htfOpen, m_htfClose, m_htfHigh, m_htfLow);
   report += StringFormat("LTF (M1):  Open %.2f\n", m_ltfOpen);
   report += StringFormat("HTF Pattern: %s\n", GetPatternDisplay(m_htfTF));
   report += StringFormat("LTF Pattern: %s\n", GetPatternDisplay(m_ltfTF));
   report += StringFormat("HTF Pullback: %.1f%%\n", GetPullbackDepth(m_htfTF, 5));
   report += StringFormat("LTF Pullback: %.1f%%\n", GetPullbackDepth(m_ltfTF, 3));
   report += "═══════════════════════════════════════════\n";
   
   return report;
}

//=============================================================================
// GET EXHAUSTION REPORT
//=============================================================================
string CCandleModule::GetExhaustionReport(SExhaustionResult &result)
{
   string report = "";
   report += "═══════════════════════════════════════════\n";
   report += "🕯️ EXHAUSTION REPORT\n";
   report += "───────────────────────────────────────────\n";
   report += StringFormat("Mode: %s\n", result.modeName);
   report += StringFormat("Valid: %s\n", result.isValid ? "✅ YES" : "❌ NO");
   report += StringFormat("Type: %s\n", result.type);
   report += StringFormat("Description: %s\n", result.description);
   report += StringFormat("Confidence: %.1f%%\n", result.confidence);
   report += StringFormat("HTF Exhaustion: %s\n", result.htfExhaustion ? "✅" : "❌");
   report += StringFormat("LTF Exhaustion: %s\n", result.ltfExhaustion ? "✅" : "❌");
   report += StringFormat("HTF Pattern: %s (%.0f%%)\n", result.htfPattern, result.htfPatternStrength);
   report += StringFormat("LTF Pattern: %s (%.0f%%)\n", result.ltfPattern, result.ltfPatternStrength);
   report += StringFormat("Reset Cooldown: %s\n", result.cooldownReset ? "✅ YES" : "❌ NO");
   report += StringFormat("Candles Waited: %d / %d\n", result.candlesWaited, result.candlesRequired);
   report += StringFormat("Candle Just Closed: %s\n", result.candleJustClosed ? "✅ YES" : "❌ NO");
   report += StringFormat("Waiting for Candle Close: %s\n", result.waitingForCandleClose ? "✅ YES" : "❌ NO");
   report += StringFormat("Checked Candle Time: %s\n", TimeToString(result.checkedCandleTime));
   if(result.waitingForCandleClose)
   {
      datetime currentCandleTime = iTime(m_symbol, m_htfTF, 0);
      datetime currentTime = TimeCurrent();
      int secondsPerCandle = PeriodSeconds(m_htfTF);
      int secondsRemaining = (int)((currentCandleTime + secondsPerCandle) - currentTime);
      report += StringFormat("   Time remaining: %dm %ds\n", secondsRemaining / 60, secondsRemaining % 60);
   }
   report += "═══════════════════════════════════════════\n";
   return report;
}