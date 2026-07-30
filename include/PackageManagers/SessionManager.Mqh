//+------------------------------------------------------------------+
//|                         RangeManager.mqh                         |
//|                    Dynamic Range Bar Manager                     |
//|                    v1.13 - SESSIONS ONLY                        |
//|                    Session detection and management             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.13"

#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "../Headers/Enums.mqh"
#include "../Headers/Structures.mqh"

//+------------------------------------------------------------------+
//| 📊 LOG TOGGLES - Master control for all RangeManager logs      |
//+------------------------------------------------------------------+
bool g_enableRangeManagerLogs = false;     // Master toggle - ALL logs
bool g_enableRangeManagerDebug = false;    // Debug logs
bool g_enableRangeManagerStatus = false;   // Status logs (5-second interval)

//+------------------------------------------------------------------+
//| Range Manager Class - SESSIONS ONLY                             |
//+------------------------------------------------------------------+
class CSessionManager
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool     m_debugEnabled;
   
   // ═══ SESSION TRACKING ═══
   SessionInfo m_currentSessionInfo;
   datetime    m_lastSessionUpdate;
   
   // ═══ SESSION METHODS ═══
   void     UpdateSessionInfo();
   datetime GetSessionStartTime(datetime time, int sessionId);
   datetime GetSessionEndTime(datetime time, int sessionId);
   void     CalculateSessionHighLow();
   
public:
   CSessionManager(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_M1);
   ~CSessionManager();
   
   // Main methods
   bool     Initialize();
   
   // Configuration
   void     EnableDebug(bool enable) { m_debugEnabled = enable; }
   
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

   // ═══ SESSION GETTERS WITH ID ═══
   datetime GetSessionStartTimeForId(int sessionId);
   datetime GetSessionEndTimeForId(int sessionId);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CSessionManager::CSessionManager(string symbol, ENUM_TIMEFRAMES tf)
{
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_debugEnabled = g_enableRangeManagerDebug;
   
   // ═══ Session info initialization ═══
   ZeroMemory(m_currentSessionInfo);
   m_currentSessionInfo.isValid = false;
   m_lastSessionUpdate = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CSessionManager::~CSessionManager()
{
   // SILENT
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CSessionManager::Initialize()
{
   UpdateSessionInfo();  // Initialize session data
   return true;
}

//+------------------------------------------------------------------+
//| Get Current Session ID - NO SEPARATE OVERLAP                   |
//| Returns: 0=Off-Hours, 1=London, 2=NY, 3=Asia                   |
//+------------------------------------------------------------------+
int CSessionManager::GetCurrentSessionId()
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
string CSessionManager::GetSessionName()
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
string CSessionManager::GetSessionShortName()
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
string CSessionManager::GetSessionHours()
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
int CSessionManager::GetSessionAdjustment()
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
color CSessionManager::GetSessionColor()
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
datetime CSessionManager::GetSessionStartTime()
{
   datetime now = TimeCurrent();
   return GetSessionStartTime(now, GetCurrentSessionId());
}

datetime CSessionManager::GetSessionStartTime(datetime time, int sessionId)
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
datetime CSessionManager::GetSessionEndTime()
{
   datetime now = TimeCurrent();
   return GetSessionEndTime(now, GetCurrentSessionId());
}

datetime CSessionManager::GetSessionEndTime(datetime time, int sessionId)
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
void CSessionManager::CalculateSessionHighLow()
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
void CSessionManager::UpdateSessionInfo()
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
double CSessionManager::GetSessionHigh()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.high;
}

//+------------------------------------------------------------------+
//| Get Session Low                                                 |
//+------------------------------------------------------------------+
double CSessionManager::GetSessionLow()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.low;
}

//+------------------------------------------------------------------+
//| Is Session Valid                                                |
//+------------------------------------------------------------------+
bool CSessionManager::IsSessionValid()
{
   UpdateSessionInfo();
   return m_currentSessionInfo.isValid;
}

//+------------------------------------------------------------------+
//| Get Session Info                                                |
//+------------------------------------------------------------------+
SessionInfo CSessionManager::GetSessionInfo()
{
   UpdateSessionInfo();
   return m_currentSessionInfo;
}

//+------------------------------------------------------------------+
//| Get Session Start Time For ID - Public wrapper                  |
//+------------------------------------------------------------------+
datetime CSessionManager::GetSessionStartTimeForId(int sessionId)
{
   datetime now = TimeCurrent();
   return GetSessionStartTime(now, sessionId);
}

//+------------------------------------------------------------------+
//| Get Session End Time For ID - Public wrapper                    |
//+------------------------------------------------------------------+
datetime CSessionManager::GetSessionEndTimeForId(int sessionId)
{
   datetime now = TimeCurrent();
   return GetSessionEndTime(now, sessionId);
}