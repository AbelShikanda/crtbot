//+------------------------------------------------------------------+
//|                         RangeManager.mqh                         |
//|                    Dynamic Range Bar Manager                     |
//|                    v1.12 - WITH RANGE COMPARISON               |
//|                    Uses direct iADX for ADX                    |
//|                    Uses IndicatorManager for ATR               |
//|                    SELF-LOGGING - CONTROLLED BY TOGGLE        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.12"

#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "../PackageManagers/IndicatorManager.mqh"

//+------------------------------------------------------------------+
//| 📊 LOG TOGGLES - Master control for all RangeManager logs      |
//+------------------------------------------------------------------+
bool g_enableRangeManagerLogs = false;     // Master toggle - ALL logs
bool g_enableRangeManagerDebug = false;    // Debug logs
bool g_enableRangeManagerStatus = false;   // Status logs (5-second interval)

//+------------------------------------------------------------------+
//| Session Information Structure                                    |
//+------------------------------------------------------------------+
struct SessionInfo
{
   int      sessionId;           // 0=Off-Hours, 1=London, 2=NY, 3=Asia
   string   name;                // "London", "New York", "Asia"
   string   shortName;           // "LONDON", "NY", "ASIA"
   string   hours;               // "10:30-18:30 UTC"
   int      adjustment;          // +3 bars
   datetime startTime;           // Session start time
   datetime endTime;             // Session end time
   double   high;                // Session high price
   double   low;                 // Session low price
   bool     isValid;             // Whether session data is valid
};

//+------------------------------------------------------------------+
//| Range Manager Class                                             |
//+------------------------------------------------------------------+
class CRangeManager
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool     m_debugEnabled;
   
   // ═══ REFERENCES TO EXTERNAL MANAGERS ═══
   CIndicatorManager*   m_indicatorManager;   // For ATR values only
   
   // Dynamic range settings
   int      m_minBars;
   int      m_maxBars;
   int      m_currentBars;
   bool     m_useDynamicBars;
   
   // Cached values for efficiency
   double   m_cachedATR;
   double   m_cachedADX;
   datetime m_lastCalculationTime;
   int      m_lastCalculatedBars;
   
   // ═══ SELF-LOGGING CONTROL ═══
   datetime m_lastLogTime;
   bool     m_initialized;
   
   // ═══ SESSION TRACKING ═══
   SessionInfo m_currentSessionInfo;
   datetime    m_lastSessionUpdate;
   
   // Private methods
   double   GetATRValue();
   double   GetADXValueInternal();  // ═══ RENAMED ═══
   double   GetATRPercentileInternal(int lookback = 100);  // ═══ RENAMED ═══
   int      CalculateBars();
   void     UpdateCache();
   void     LogStatus();
   
   // ═══ SESSION METHODS ═══
   void     UpdateSessionInfo();
   datetime GetSessionStartTime(datetime time, int sessionId);
   datetime GetSessionEndTime(datetime time, int sessionId);
   void     CalculateSessionHighLow();
   
public:
   CRangeManager(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_M1);
   ~CRangeManager();
   
   // ═══ SET MANAGERS ═══
   void     SetIndicatorManager(CIndicatorManager* manager) { m_indicatorManager = manager; }
   
   // Main methods
   bool     Initialize();
   int      GetRangeBars();
   int      GetCurrentBars() const { return m_currentBars; }
   void     ForceRecalculation() { m_lastCalculationTime = 0; }
   
   // Configuration
   void     SetMinBars(int min) { m_minBars = MathMax(5, min); }
   void     SetMaxBars(int max) { m_maxBars = MathMax(m_minBars, max); }
   void     SetDynamicMode(bool enable) { m_useDynamicBars = enable; }
   void     EnableDebug(bool enable) { m_debugEnabled = enable; }
   
   // ═══ GETTERS FOR RANGE COMPARISON ═══
   int      GetMinBars() const { return m_minBars; }
   int      GetMaxBars() const { return m_maxBars; }
   bool     IsDynamicMode() const { return m_useDynamicBars; }
   double   GetADXValue() { return GetADXValueInternal(); }  // ═══ PUBLIC WRAPPER ═══
   double   GetATRPercentile(int lookback = 100) { return GetATRPercentileInternal(lookback); }  // ═══ PUBLIC WRAPPER ═══
   datetime GetLastCalculationTime() const { return m_lastCalculationTime; }
   int      GetLastCalculatedBars() const { return m_lastCalculatedBars; }
   
   // ═══ SESSION GETTERS (FOR CHART MODULE) ═══
   int      GetCurrentSessionId();
   string   GetSessionName();
   string   GetSessionShortName();
   string   GetSessionHours();
   int      GetSessionAdjustment();
   color    GetSessionColor();
   datetime GetSessionStartTime();
   datetime GetSessionEndTime();
   double   GetSessionHigh();
   double   GetSessionLow();
   bool     IsSessionValid();
   SessionInfo GetSessionInfo();
   
   // ═══ STATUS METHODS ═══
   string   GetStatusString();
   string   GetDetailedReport();
   string   GetStatusLogString();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CRangeManager::CRangeManager(string symbol, ENUM_TIMEFRAMES tf)
{
   // SILENT - No constructor logging
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_debugEnabled = g_enableRangeManagerDebug;
   m_initialized = false;
   m_lastLogTime = 0;
   m_lastSessionUpdate = 0;
   
   // ═══ MANAGER REFERENCES ═══
   m_indicatorManager = NULL;
   
   // Default settings from inputs
   m_minBars = InpMinRangeBars;        // 10
   m_maxBars = InpMaxRangeBars;        // 50
   m_currentBars = 20;                 // Default
   m_useDynamicBars = InpUseDynamicRangeBars;
   
   // Cache
   m_cachedATR = 0;
   m_cachedADX = 0;
   m_lastCalculationTime = 0;
   m_lastCalculatedBars = 20;
   
   // ═══ Session info initialization ═══
   ZeroMemory(m_currentSessionInfo);
   m_currentSessionInfo.isValid = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CRangeManager::~CRangeManager()
{
   // SILENT - No destructor logging
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CRangeManager::Initialize()
{
   if(m_indicatorManager == NULL)
   {
      // Only log warning if debug enabled
      if(g_enableRangeManagerDebug)
         LOG_WARNING("⚠️ IndicatorManager not set - ATR will use fallback values");
   }
   
   m_initialized = true;
   UpdateSessionInfo();  // Initialize session data
   
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR Value - FROM INDICATORMANAGER                          |
//+------------------------------------------------------------------+
double CRangeManager::GetATRValue()
{
   if(m_indicatorManager != NULL)
   {
      double atr = m_indicatorManager.GetATRWithFallback(PERIOD_M1);
      if(atr > 0)
      {
         if(g_enableRangeManagerDebug)
            LOG_DEBUG("📊 ATR from IndicatorManager: " + DoubleToString(atr, 5), m_debugEnabled);
         return atr;
      }
   }
   
   int atrHandle = iATR(m_symbol, PERIOD_M1, 14);
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      {
         if(atrBuffer[0] > 0)
         {
            if(g_enableRangeManagerDebug)
               LOG_DEBUG("📊 ATR from direct calculation: " + DoubleToString(atrBuffer[0], 5), m_debugEnabled);
            return atrBuffer[0];
         }
      }
   }
   
   // Fallback - no logging by default
   return 0.0005;
}

//+------------------------------------------------------------------+
//| Get ADX Value - DIRECT iADX (Internal)                         |
//+------------------------------------------------------------------+
double CRangeManager::GetADXValueInternal()
{
   int adxHandle = iADX(m_symbol, PERIOD_M15, 14);
   if(adxHandle != INVALID_HANDLE)
   {
      double adxBuffer[];
      ArraySetAsSeries(adxBuffer, true);
      if(CopyBuffer(adxHandle, 0, 0, 1, adxBuffer) > 0)
      {
         if(adxBuffer[0] > 0)
         {
            if(g_enableRangeManagerDebug)
               LOG_DEBUG("📊 ADX from direct calculation: " + DoubleToString(adxBuffer[0], 1), m_debugEnabled);
            return adxBuffer[0];
         }
      }
   }
   
   // Fallback - no logging by default
   return 25.0;
}

//+------------------------------------------------------------------+
//| Get ATR Percentile - Internal                                   |
//+------------------------------------------------------------------+
double CRangeManager::GetATRPercentileInternal(int lookback = 100)
{
   double atr = GetATRValue();
   if(atr <= 0) return 50.0;
   
   int atrHandle = iATR(m_symbol, PERIOD_M1, 14);
   if(atrHandle == INVALID_HANDLE) return 50.0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(atrHandle, 0, 0, lookback, atrBuffer) < lookback)
      return 50.0;
   
   int count = 0;
   for(int i = 1; i < lookback; i++)
   {
      if(atrBuffer[i] < atr && atrBuffer[i] > 0)
         count++;
   }
   
   return (double)count / lookback * 100.0;
}

//+------------------------------------------------------------------+
//| Get Current Session ID - NO SEPARATE OVERLAP                   |
//| Returns: 0=Off-Hours, 1=London, 2=NY, 3=Asia                   |
//+------------------------------------------------------------------+
int CRangeManager::GetCurrentSessionId()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int hour = dt.hour;
   int minute = dt.min;
   double timeValue = hour + (minute / 60.0);
   
   // ═══ NO SEPARATE OVERLAP SESSION ═══
   // London and NY overlap naturally (16:30-18:30)
   // During overlap, BOTH sessions are active
   // The chart will show both boxes overlapping
   
   // ──────────────────────────────────────────────────────────────
   // 1. LONDON SESSION (10:30-18:30 UTC)
   // ──────────────────────────────────────────────────────────────
   if(timeValue >= 10.5 && timeValue < 18.5)
      return 1;  // London
   
   // ──────────────────────────────────────────────────────────────
   // 2. NEW YORK SESSION (16:30-23:00 UTC)
   // ──────────────────────────────────────────────────────────────
   if(timeValue >= 16.5 && timeValue < 23.0)
      return 2;  // NY
   
   // ──────────────────────────────────────────────────────────────
   // 3. ASIA SESSION (03:00-09:00 UTC)
   // ──────────────────────────────────────────────────────────────
   if(timeValue >= 3.0 && timeValue < 9.0)
      return 3;  // Asia
   
   // ──────────────────────────────────────────────────────────────
   // 4. OFF-HOURS (23:00-03:00 UTC)
   // ──────────────────────────────────────────────────────────────
   return 0;  // Off-Hours
}

//+------------------------------------------------------------------+
//| Get Session Name                                                |
//+------------------------------------------------------------------+
string CRangeManager::GetSessionName()
{
   int session = GetCurrentSessionId();
   switch(session)
   {
      case 0: return "Off-Hours";
      case 1: return "London";
      case 2: return "New York";
      case 3: return "Asia";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Get Session Short Name                                          |
//+------------------------------------------------------------------+
string CRangeManager::GetSessionShortName()
{
   int session = GetCurrentSessionId();
   switch(session)
   {
      case 0: return "OFF";
      case 1: return "LONDON";
      case 2: return "NY";
      case 3: return "ASIA";
      default: return "UNK";
   }
}

//+------------------------------------------------------------------+
//| Get Session Hours - NATURAL OVERLAP (No separate Overlap)      |
//+------------------------------------------------------------------+
string CRangeManager::GetSessionHours()
{
   int session = GetCurrentSessionId();
   switch(session)
   {
      case 0: return "23:00-03:00 UTC";
      case 1: return "10:30-18:30 UTC";
      case 2: return "16:30-23:00 UTC";
      case 3: return "03:00-09:00 UTC";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Get Session Adjustment                                          |
//+------------------------------------------------------------------+
int CRangeManager::GetSessionAdjustment()
{
   int session = GetCurrentSessionId();
   switch(session)
   {
      case 0: return -5;
      case 1: return +3;   // London
      case 2: return +5;   // NY
      case 3: return -3;   // Asia
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Get Session Color                                               |
//+------------------------------------------------------------------+
color CRangeManager::GetSessionColor()
{
   int session = GetCurrentSessionId();
   switch(session)
   {
      case 0: return clrSilver;
      case 1: return clrBlue;       // London
      case 2: return clrRed;        // NY
      case 3: return clrDarkGray;   // Asia
      default: return clrGray;
   }
}

//+------------------------------------------------------------------+
//| Get Session Start Time - NATURAL OVERLAP                       |
//+------------------------------------------------------------------+
datetime CRangeManager::GetSessionStartTime()
{
   datetime now = TimeCurrent();
   return GetSessionStartTime(now, GetCurrentSessionId());
}

datetime CRangeManager::GetSessionStartTime(datetime time, int sessionId)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   switch(sessionId)
   {
      case 0:  dt.hour = 23; dt.min = 0; dt.sec = 0; break;   // Off-Hours (23:00)
      case 1:  dt.hour = 10; dt.min = 30; dt.sec = 0; break;  // London (10:30)
      case 2:  dt.hour = 16; dt.min = 30; dt.sec = 0; break;  // NY (16:30)
      case 3:  dt.hour = 3; dt.min = 0; dt.sec = 0; break;    // Asia (03:00)
      default: dt.hour = 0; dt.min = 0; dt.sec = 0; break;
   }
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Get Session End Time - NATURAL OVERLAP                         |
//+------------------------------------------------------------------+
datetime CRangeManager::GetSessionEndTime()
{
   datetime now = TimeCurrent();
   return GetSessionEndTime(now, GetCurrentSessionId());
}

datetime CRangeManager::GetSessionEndTime(datetime time, int sessionId)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   switch(sessionId)
   {
      case 0:  dt.hour = 3; dt.min = 0; dt.sec = 0; dt.day++; break;   // Off-Hours (03:00 next day)
      case 1:  dt.hour = 18; dt.min = 30; dt.sec = 0; break;           // London (18:30)
      case 2:  dt.hour = 23; dt.min = 0; dt.sec = 0; break;            // NY (23:00)
      case 3:  dt.hour = 9; dt.min = 0; dt.sec = 0; break;             // Asia (09:00)
      default: dt.hour = 23; dt.min = 59; dt.sec = 59; break;
   }
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Calculate Session High/Low                                      |
//+------------------------------------------------------------------+
void CRangeManager::CalculateSessionHighLow()
{
   datetime startTime = GetSessionStartTime();
   datetime endTime = GetSessionEndTime();
   
   int startBar = iBarShift(m_symbol, m_timeframe, startTime);
   int endBar = iBarShift(m_symbol, m_timeframe, endTime);
   int totalBars = startBar - endBar;
   
   m_currentSessionInfo.high = 0;
   m_currentSessionInfo.low = DBL_MAX;
   m_currentSessionInfo.isValid = false;
   
   if(totalBars > 0 && totalBars < 1000)
   {
      double highBuffer[], lowBuffer[];
      ArraySetAsSeries(highBuffer, true);
      ArraySetAsSeries(lowBuffer, true);
      
      if(CopyHigh(m_symbol, m_timeframe, endBar, totalBars, highBuffer) > 0 &&
         CopyLow(m_symbol, m_timeframe, endBar, totalBars, lowBuffer) > 0)
      {
         for(int i = 0; i < totalBars; i++)
         {
            if(highBuffer[i] > m_currentSessionInfo.high) 
               m_currentSessionInfo.high = highBuffer[i];
            if(lowBuffer[i] < m_currentSessionInfo.low) 
               m_currentSessionInfo.low = lowBuffer[i];
         }
         m_currentSessionInfo.isValid = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Update Session Info                                             |
//+------------------------------------------------------------------+
void CRangeManager::UpdateSessionInfo()
{
   datetime now = TimeCurrent();
   int sessionId = GetCurrentSessionId();
   
   if(sessionId != m_currentSessionInfo.sessionId || 
      now - m_lastSessionUpdate > 300)
   {
      m_currentSessionInfo.sessionId = sessionId;
      m_currentSessionInfo.name = GetSessionName();
      m_currentSessionInfo.shortName = GetSessionShortName();
      m_currentSessionInfo.hours = GetSessionHours();
      m_currentSessionInfo.adjustment = GetSessionAdjustment();
      m_currentSessionInfo.startTime = GetSessionStartTime();
      m_currentSessionInfo.endTime = GetSessionEndTime();
      
      CalculateSessionHighLow();
      
      m_lastSessionUpdate = now;
      
      if(g_enableRangeManagerDebug)
         LOG_DEBUG("📊 Session Updated: " + m_currentSessionInfo.name + 
                   " | Start: " + TimeToString(m_currentSessionInfo.startTime) +
                   " | End: " + TimeToString(m_currentSessionInfo.endTime) +
                   " | High: " + DoubleToString(m_currentSessionInfo.high, _Digits) +
                   " | Low: " + DoubleToString(m_currentSessionInfo.low, _Digits), m_debugEnabled);
   }
}

//+------------------------------------------------------------------+
//| Get Session High                                                |
//+------------------------------------------------------------------+
double CRangeManager::GetSessionHigh()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.high;
}

//+------------------------------------------------------------------+
//| Get Session Low                                                 |
//+------------------------------------------------------------------+
double CRangeManager::GetSessionLow()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.low;
}

//+------------------------------------------------------------------+
//| Is Session Valid                                                |
//+------------------------------------------------------------------+
bool CRangeManager::IsSessionValid()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.isValid;
}

//+------------------------------------------------------------------+
//| Get Session Info                                                |
//+------------------------------------------------------------------+
SessionInfo CRangeManager::GetSessionInfo()
{
   UpdateSessionInfo();
   return m_currentSessionInfo;
}

//+------------------------------------------------------------------+
//| Log Status - ONLY LOGS WHEN ENABLED                             |
//+------------------------------------------------------------------+
void CRangeManager::LogStatus()
{
   if(!m_initialized) return;
   if(!g_enableRangeManagerStatus) return;  // ═══ TOGGLE CHECK ═══
   
   if(m_lastLogTime == 0) m_lastLogTime = TimeCurrent();
   
   datetime now = TimeCurrent();
   if(now - m_lastLogTime < 5) return;
   m_lastLogTime = now;
   
   int session = GetCurrentSessionId();
   double adx = GetADXValue();
   double atrPct = GetATRPercentile(100);
   int bars = m_currentBars;
   
   string sessionNames[] = {"Off-Hours", "London", "NY", "Asia"};
   string sessionName = (session >= 0 && session < 4) ? sessionNames[session] : "Unknown";
   string mode = m_useDynamicBars ? "DYNAMIC" : "FIXED";
   
   if(g_enableRangeManagerLogs)
   {
      LOG(StringFormat(
         "📊 RANGE: %d bars | Mode: %s | Session: %s | ADX: %.0f | ATR: %.0f%% | Min: %d | Max: %d",
         bars, mode, sessionName, adx, atrPct, m_minBars, m_maxBars
      ), true);
   }
}

//+------------------------------------------------------------------+
//| Get Range Bars                                                  |
//+------------------------------------------------------------------+
int CRangeManager::GetRangeBars()
{
   if(!m_useDynamicBars)
   {
      m_currentBars = m_minBars;
      LogStatus();  // Only logs if enabled
      return m_currentBars;
   }
   
   datetime now = TimeCurrent();
   if(now - m_lastCalculationTime > 5)
   {
      int newBars = CalculateBars();
      if(newBars != m_lastCalculatedBars)
      {
         m_lastCalculatedBars = newBars;
         m_currentBars = newBars;
         if(g_enableRangeManagerDebug)
            LOG_DEBUG("📊 Range bars updated: " + IntegerToString(m_currentBars), m_debugEnabled);
      }
      m_lastCalculationTime = now;
   }
   
   LogStatus();  // Only logs if enabled
   return m_currentBars;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Bars                                          |
//+------------------------------------------------------------------+
int CRangeManager::CalculateBars()
{
   double base = 20.0;
   
   double atrPercentile = GetATRPercentile(100);
   
   if(atrPercentile > 80)       base = 35.0;
   else if(atrPercentile > 60)  base = 28.0;
   else if(atrPercentile > 40)  base = 20.0;
   else if(atrPercentile > 20)  base = 15.0;
   else                         base = 12.0;
   
   double adx = GetADXValue();
   
   if(adx > 40)                 base *= 0.6;
   else if(adx > 30)            base *= 0.8;
   else if(adx > 20)            base *= 1.0;
   else if(adx > 15)            base *= 1.3;
   else                         base *= 1.6;
   
   int session = GetCurrentSessionId();
   
   if(session == 1)         base += 3.0;   // London
   else if(session == 2)    base += 5.0;   // NY
   else if(session == 3)    base -= 3.0;   // Asia
   else                     base -= 5.0;   // Off-Hours
   
   int bars = (int)MathRound(base);
   bars = MathMax(m_minBars, MathMin(m_maxBars, bars));
   
   if(g_enableRangeManagerDebug)
   {
      string sessionNames[] = {"Off-Hours", "London", "NY", "Asia"};
      string sessionName = (session >= 0 && session < 4) ? sessionNames[session] : "Unknown";
      
      LOG_DEBUG(StringFormat("📊 Dynamic Bars: %d | ATR: %.0f%% | ADX: %.0f | Session: %s", 
                            bars, atrPercentile, adx, sessionName), true);
   }
   
   return bars;
}

//+------------------------------------------------------------------+
//| Get Status String                                               |
//+------------------------------------------------------------------+
string CRangeManager::GetStatusString()
{
   if(!m_useDynamicBars)
      return "Range: FIXED (" + IntegerToString(m_currentBars) + " bars)";
   
   string sessionNames[] = {"Off-Hours", "London", "NY", "Asia"};
   int session = GetCurrentSessionId();
   string sessionName = (session >= 0 && session < 4) ? sessionNames[session] : "Unknown";
   
   double adx = GetADXValue();
   double atrPct = GetATRPercentile(100);
   
   return StringFormat("Range: %d bars | %s | ATR: %.0f%% | ADX: %.0f", 
                       m_currentBars, sessionName, atrPct, adx);
}

//+------------------------------------------------------------------+
//| Get Status Log String                                           |
//+------------------------------------------------------------------+
string CRangeManager::GetStatusLogString()
{
   int session = GetCurrentSessionId();
   double adx = GetADXValue();
   double atrPct = GetATRPercentile(100);
   int bars = m_currentBars;
   
   string sessionNames[] = {"Off-Hours", "London", "NY", "Asia"};
   string sessionName = (session >= 0 && session < 4) ? sessionNames[session] : "Unknown";
   string mode = m_useDynamicBars ? "DYNAMIC" : "FIXED";
   
   return StringFormat(
      "📊 RANGE: %d bars | Mode: %s | Session: %s | ADX: %.0f | ATR: %.0f%% | Min: %d | Max: %d",
      bars, mode, sessionName, adx, atrPct, m_minBars, m_maxBars
   );
}

//+------------------------------------------------------------------+
//| Get Detailed Report                                             |
//+------------------------------------------------------------------+
string CRangeManager::GetDetailedReport()
{
   double adx = GetADXValue();
   double atr = GetATRValue();
   double atrPct = GetATRPercentile(100);
   int session = GetCurrentSessionId();
   string sessionNames[] = {"Off-Hours", "London", "NY", "Asia"};
   string sessionName = (session >= 0 && session < 4) ? sessionNames[session] : "Unknown";
   
   string report = "\n═══════════════════════════════════════════════════\n";
   report += "RANGE MANAGER REPORT\n";
   report += "═══════════════════════════════════════════════════\n";
   report += "  Dynamic Mode: " + string(m_useDynamicBars ? "ENABLED" : "DISABLED") + "\n";
   report += "  Current Bars: " + IntegerToString(m_currentBars) + "\n";
   report += "  Min Bars: " + IntegerToString(m_minBars) + "\n";
   report += "  Max Bars: " + IntegerToString(m_maxBars) + "\n";
   report += "  ADX (direct iADX): " + DoubleToString(adx, 1) + "\n";
   report += "  ATR (from IndicatorManager): " + DoubleToString(atr, 5) + "\n";
   report += "  ATR Percentile: " + DoubleToString(atrPct, 1) + "%\n";
   report += "  Session: " + sessionName + "\n";
   report += "  Session Hours: ";
   switch(session)
   {
      case 0: report += "Off-Hours (23:00-03:00 UTC)"; break;
      case 1: report += "London (10:30-18:30 UTC)"; break;
      case 2: report += "NY (16:30-23:00 UTC)"; break;
      case 3: report += "Asia (03:00-09:00 UTC)"; break;
      default: report += "Unknown"; break;
   }
   report += "\n═══════════════════════════════════════════════════\n";
   
   return report;
}