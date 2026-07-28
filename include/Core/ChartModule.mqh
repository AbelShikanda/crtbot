//+------------------------------------------------------------------+
//|                        ChartModule.mqh                          |
//|                    Chart Drawing Module                          |
//|                    PURELY VISUAL - NO CALCULATIONS              |
//|                    ALL visual decisions (colors, emojis) here   |
//|                    v1.09 - ORDER BLOCK DISPLAY ON ANY TF       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.09"

#include "../Data/PullbackModule.mqh"
#include "../PackageManagers/SessionManager.mqh"
#include "../Data/OrderblockModule.mqh"

//+------------------------------------------------------------------+
//| Chart Module Class - ONLY Chart Module, NO PullbackModule      |
//+------------------------------------------------------------------+
class CChartModule
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   string   m_prefix;
   int      m_rangeBars;
   CPullbackModule* m_pullbackModule;
   CSessionManager* m_sessionManager;
   COrderBlockDisplay* m_orderBlockDisplay;  // ← NEW
   
   // Object names - Pullback
   string   m_rangeHighName;
   string   m_rangeLowName;
   string   m_line40Name;
   string   m_line80Name;
   string   m_rangeBoxName;
   string   m_pullbackLineName;
   string   m_perfectZoneName;
   string   m_labelName;
   
   // Object names - Sessions
   string   m_sessionPrefix;
   datetime m_lastSessionReset;
   
   // VISUAL DECISION METHODS
   color GetZoneColor(string zoneCategory);
   string GetZoneEmoji(string zoneCategory);
   string GetZoneLabel(string zoneCategory);
   color GetPullbackLineColor(double adjustedPercent);
   string GetTooltip(SPullbackDrawingData &data);
   
   // Session methods
   color GetSessionColor(int sessionId);
   color GetSessionDashedColor(int sessionId);
   string GetSessionShortName(int sessionId);
   string GetSessionHours(int sessionId);
   void DrawSessions();
   void ClearSessions();
   bool ShouldResetSessions();
   void ResetSessions();
   
   // ═══ ORDER BLOCK METHODS ═══
   void DrawOrderBlocks();
   void ClearOrderBlocks();
   
   // Helper methods
   void CreateHorizontalLine(string name, double price, datetime time1, datetime time2, 
                            color lineColor, ENUM_LINE_STYLE style = STYLE_SOLID, int width = 1);
   void CreateLabel(string name, string text, int x, int y, color textColor, int fontSize = 10);
   void CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2, 
                        color lineColor, bool fill = false, ENUM_LINE_STYLE style = STYLE_SOLID);
   
public:
   CChartModule(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int rangeBars = 20);
   ~CChartModule();
   
   void SetPullbackModule(CPullbackModule* pullbackModule) { m_pullbackModule = pullbackModule; }
   void SetSessionManager(CSessionManager* sessionManager) { m_sessionManager = sessionManager; }
   void SetOrderBlockDisplay(COrderBlockDisplay* orderBlockDisplay) { m_orderBlockDisplay = orderBlockDisplay; }
   void Update();
   void ClearDrawings();
   
   // ═══ NEW: Get timeframe ═══
   ENUM_TIMEFRAMES GetTimeframe() { return m_timeframe; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CChartModule::CChartModule(string symbol, ENUM_TIMEFRAMES tf, int rangeBars)
{
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_rangeBars = rangeBars;
   m_prefix = "PBR_" + m_symbol + "_";
   m_sessionPrefix = "SESS_" + m_symbol + "_";
   m_pullbackModule = NULL;
   m_sessionManager = NULL;
   m_orderBlockDisplay = NULL;
   m_lastSessionReset = 0;
   
   m_rangeHighName = m_prefix + "RangeHigh";
   m_rangeLowName = m_prefix + "RangeLow";
   m_line40Name = m_prefix + "Line40";
   m_line80Name = m_prefix + "Line80";
   m_rangeBoxName = m_prefix + "RangeBox";
   m_pullbackLineName = m_prefix + "PullbackLine";
   m_perfectZoneName = m_prefix + "PerfectZone";
   m_labelName = m_prefix + "Label";
   
   Print("📊 ChartModule CONSTRUCTOR called");
   Print("   Symbol: ", m_symbol);
   Print("   Timeframe: ", EnumToString(m_timeframe));
   Print("   Range Bars: ", m_rangeBars);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CChartModule::~CChartModule()
{
   ClearDrawings();
}

//+------------------------------------------------------------------+
//| Clear Drawings                                                  |
//+------------------------------------------------------------------+
void CChartModule::ClearDrawings()
{
   ObjectsDeleteAll(0, m_prefix);
   ObjectsDeleteAll(0, m_sessionPrefix);
   // OrderBlockDisplay handles its own clearing
}

//+------------------------------------------------------------------+
//| Clear Sessions                                                  |
//+------------------------------------------------------------------+
void CChartModule::ClearSessions()
{
   ObjectsDeleteAll(0, m_sessionPrefix);
}

//+------------------------------------------------------------------+
//| Clear Order Blocks                                              |
//+------------------------------------------------------------------+
void CChartModule::ClearOrderBlocks()
{
   if(m_orderBlockDisplay != NULL)
      m_orderBlockDisplay.ClearDrawings();
}

//+------------------------------------------------------------------+
//| Should Reset Sessions - Reset after 24 hours                    |
//+------------------------------------------------------------------+
bool CChartModule::ShouldResetSessions()
{
   datetime now = TimeCurrent();
   if(m_lastSessionReset == 0) return true;
   if(now - m_lastSessionReset >= 86400) return true;  // 24 hours
   return false;
}

//+------------------------------------------------------------------+
//| Reset Sessions                                                  |
//+------------------------------------------------------------------+
void CChartModule::ResetSessions()
{
   ClearSessions();
   m_lastSessionReset = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get Session Color - Solid color for reference                   |
//+------------------------------------------------------------------+
color CChartModule::GetSessionColor(int sessionId)
{
   switch(sessionId)
   {
      case 0: return clrSilver;      // Off-Hours
      case 1: return clrOrange;      // London
      case 2: return clrGreen;       // NY
      case 3: return clrBlue;        // Asia
      default: return clrGray;
   }
}

//+------------------------------------------------------------------+
//| Get Session Dashed Color - For transparent dashed outlines      |
//+------------------------------------------------------------------+
color CChartModule::GetSessionDashedColor(int sessionId)
{
   switch(sessionId)
   {
      case 0: return clrSilver;      // Off-Hours (faint)
      case 1: return clrOrange;      // London
      case 2: return clrGreen;       // NY
      case 3: return clrBlue;        // Asia
      default: return clrGray;
   }
}

//+------------------------------------------------------------------+
//| Get Session Short Name                                          |
//+------------------------------------------------------------------+
string CChartModule::GetSessionShortName(int sessionId)
{
   switch(sessionId)
   {
      case 0: return "OFF";
      case 1: return "LONDON";
      case 2: return "NY";
      case 3: return "ASIA";
      default: return "UNK";
   }
}

//+------------------------------------------------------------------+
//| Get Session Hours                                               |
//+------------------------------------------------------------------+
string CChartModule::GetSessionHours(int sessionId)
{
   switch(sessionId)
   {
      case 0: return "23:00-03:00";
      case 1: return "10:30-18:30";
      case 2: return "16:30-23:00";
      case 3: return "03:00-09:00";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Draw Sessions - Transparent dashed outlines that appear over time |
//| ALL sessions remain visible until 24-hour reset                  |
//+------------------------------------------------------------------+
void CChartModule::DrawSessions()
{
   if(m_sessionManager == NULL) return;
   
   datetime now = TimeCurrent();
   datetime todayStart = StringToTime(TimeToString(now, TIME_DATE));
   
   // Reset sessions every 24 hours (at midnight)
   if(ShouldResetSessions())
   {
      ResetSessions();
      todayStart = StringToTime(TimeToString(now, TIME_DATE));
   }
   
   // Get current session info for high/low calculation
   SessionInfo currentSession = m_sessionManager.GetSessionInfo();
   if(!currentSession.isValid) return;
   
   // ═══ DRAW ALL SESSIONS FOR TODAY ═══
   // Check each session type (0=Off-Hours, 1=London, 2=NY, 3=Asia)
   for(int sessionId = 0; sessionId <= 3; sessionId++)
   {
      // Get session times for today using public methods
      datetime startTime = m_sessionManager.GetSessionStartTimeForId(sessionId);
      datetime endTime = m_sessionManager.GetSessionEndTimeForId(sessionId);
      
      // Skip if session hasn't started yet today
      if(now < startTime) continue;
      
      // Skip if session ended before today started
      if(endTime < todayStart) continue;
      
      // Cap end time to current time if session is still active
      datetime drawEnd = (now < endTime) ? now : endTime;
      
      // Get session high/low (NO BUFFER)
      double high = 0;
      double low = 0;
      
      // Calculate session high/low for this specific session
      int startBar = iBarShift(m_symbol, m_timeframe, startTime);
      int endBar = iBarShift(m_symbol, m_timeframe, drawEnd);
      int totalBars = startBar - endBar;
      
      if(totalBars > 0 && totalBars < 1000)
      {
         double highBuffer[], lowBuffer[];
         ArraySetAsSeries(highBuffer, true);
         ArraySetAsSeries(lowBuffer, true);
         
         if(CopyHigh(m_symbol, m_timeframe, endBar, totalBars, highBuffer) > 0 &&
            CopyLow(m_symbol, m_timeframe, endBar, totalBars, lowBuffer) > 0)
         {
            high = highBuffer[ArrayMaximum(highBuffer, 0, WHOLE_ARRAY)];
            low = lowBuffer[ArrayMinimum(lowBuffer, 0, WHOLE_ARRAY)];
         }
      }
      
      // If no data, use current price with tiny buffer (fallback only)
      if(high == 0 || low == 0 || high <= low)
      {
         double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         high = currentPrice * 1.001;
         low = currentPrice * 0.999;
      }
      
      // NO BUFFER - use exact session high/low
      
      // Create transparent dashed rectangle for this session
      color dashedColor = GetSessionDashedColor(sessionId);
      string boxName = m_sessionPrefix + "Box_" + IntegerToString(sessionId);
      
      // Draw rectangle with transparent fill and dashed outline
      CreateRectangle(boxName, 
                      startTime, high, 
                      drawEnd, low, 
                      dashedColor, 
                      false,          // No fill (transparent)
                      STYLE_DASH);    // Dashed outline
      
      // Add session label at the left edge of the box
      string labelName = m_sessionPrefix + "Label_" + IntegerToString(sessionId);
      string labelText = GetSessionShortName(sessionId) + " " + GetSessionHours(sessionId);
      
      // Position label at top-left of session box
      int labelX = 10 + (sessionId * 90);  // Spread labels horizontally
      int labelY = 10 + (sessionId * 14);  // Stack vertically
      
      CreateLabel(labelName, labelText, labelX, labelY, dashedColor, 9);
   }
}

//+------------------------------------------------------------------+
//| DRAW ORDER BLOCKS - Delegate to OrderBlockDisplay              |
//| OrderBlockDisplay uses H4 for detection, but draws on ANY TF   |
//+------------------------------------------------------------------+
void CChartModule::DrawOrderBlocks()
{
   if(m_orderBlockDisplay != NULL)
   {
      m_orderBlockDisplay.Update();
   }
}

//+------------------------------------------------------------------+
//| VISUAL DECISION: Get Zone Color                                 |
//+------------------------------------------------------------------+
color CChartModule::GetZoneColor(string zoneCategory)
{
   if(zoneCategory == "PERFECT") return clrLimeGreen;
   else if(zoneCategory == "SWEET") return clrDodgerBlue;
   else if(zoneCategory == "EDGE") return clrGold;
   else if(zoneCategory == "TRANSITION" || zoneCategory == "TRANSITION EDGE") return clrOrange;
   else return clrRed;
}

//+------------------------------------------------------------------+
//| VISUAL DECISION: Get Zone Emoji                                 |
//+------------------------------------------------------------------+
string CChartModule::GetZoneEmoji(string zoneCategory)
{
   if(zoneCategory == "PERFECT") return "✅";
   else if(zoneCategory == "SWEET") return "⭐";
   else if(zoneCategory == "EDGE") return "⚡";
   else if(zoneCategory == "TRANSITION" || zoneCategory == "TRANSITION EDGE") return "⚠️";
   else return "🔴";
}

//+------------------------------------------------------------------+
//| VISUAL DECISION: Get Zone Label                                 |
//+------------------------------------------------------------------+
string CChartModule::GetZoneLabel(string zoneCategory)
{
   if(zoneCategory == "PERFECT") return "PERFECT";
   else if(zoneCategory == "SWEET") return "SWEET";
   else if(zoneCategory == "EDGE") return "EDGE";
   else if(zoneCategory == "TRANSITION" || zoneCategory == "TRANSITION EDGE") return "TRANSITION";
   else return "EXTREME";
}

//+------------------------------------------------------------------+
//| VISUAL DECISION: Get Pullback Line Color                        |
//+------------------------------------------------------------------+
color CChartModule::GetPullbackLineColor(double adjustedPercent)
{
   if(adjustedPercent >= 55 && adjustedPercent <= 65)
      return clrLimeGreen;
   else if((adjustedPercent >= 45 && adjustedPercent < 55) || (adjustedPercent > 65 && adjustedPercent <= 75))
      return clrDodgerBlue;
   else if((adjustedPercent >= 40 && adjustedPercent < 45) || (adjustedPercent > 75 && adjustedPercent <= 80))
      return clrGold;
   else if((adjustedPercent >= 25 && adjustedPercent < 40) || (adjustedPercent > 80 && adjustedPercent <= 90))
      return clrOrange;
   else
      return clrRed;
}

//+------------------------------------------------------------------+
//| VISUAL DECISION: Get Tooltip                                    |
//+------------------------------------------------------------------+
string CChartModule::GetTooltip(SPullbackDrawingData &data)
{
   return StringFormat(
      "Pullback Analysis\n"
      "=================\n"
      "Zone: %s\n"
      "Pullback: %.1f%%\n"
      "Trend: %s\n"
      "Range: %.4f - %.4f\n"
      "Current: %.4f",
      data.zoneCategory,
      data.adjustedPercent,
      data.trend == 1 ? "BULLISH" : data.trend == -1 ? "BEARISH" : "NEUTRAL",
      data.rangeLow,
      data.rangeHigh,
      data.currentPrice
   );
}

//+------------------------------------------------------------------+
//| Create Horizontal Line                                          |
//+------------------------------------------------------------------+
void CChartModule::CreateHorizontalLine(string name, double price, datetime time1, datetime time2,
                                       color lineColor, ENUM_LINE_STYLE style, int width)
{
   if(!ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price))
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Rectangle                                                |
//+------------------------------------------------------------------+
void CChartModule::CreateRectangle(string name, datetime time1, double price1, datetime time2, double price2,
                                  color lineColor, bool fill, ENUM_LINE_STYLE style)
{
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, fill);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   
   if(fill)
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Create Label                                                    |
//+------------------------------------------------------------------+
void CChartModule::CreateLabel(string name, string text, int x, int y, color textColor, int fontSize)
{
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
   {
      // If object already exists, just modify it
   }
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Update - Purely visual, no calculations                        |
//+------------------------------------------------------------------+
void CChartModule::Update()
{
   // ──────────────────────────────────────────────────────────────
   // 1. DRAW ORDER BLOCKS (First, so they appear behind everything)
   // ──────────────────────────────────────────────────────────────
   DrawOrderBlocks();
   
   // ──────────────────────────────────────────────────────────────
   // 2. DRAW SESSIONS
   // ──────────────────────────────────────────────────────────────
   DrawSessions();
   
   // ──────────────────────────────────────────────────────────────
   // 3. DRAW PULLBACK
   // ──────────────────────────────────────────────────────────────
   if(m_pullbackModule == NULL) 
      return;
   
   SPullbackDrawingData data = m_pullbackModule.GetDrawingData();
   
   if(!data.isValid)
   {
      // Don't clear all drawings - just pullback drawings
      ObjectsDeleteAll(0, m_prefix);
      return;
   }
   
   color zoneColor = GetZoneColor(data.zoneCategory);
   string zoneEmoji = GetZoneEmoji(data.zoneCategory);
   string zoneLabel = GetZoneLabel(data.zoneCategory);
   color lineColor = GetPullbackLineColor(data.adjustedPercent);
   string tooltip = GetTooltip(data);
   
   // Clear only pullback drawings (not sessions or order blocks)
   ObjectsDeleteAll(0, m_prefix);
   
   datetime currentTime = TimeCurrent();
   datetime startTime = currentTime - (m_rangeBars * PeriodSeconds(m_timeframe));
   
   // Range High/Low
   CreateHorizontalLine(m_rangeHighName, data.rangeHigh, startTime, currentTime, clrGray, STYLE_DOT, 1);
   CreateHorizontalLine(m_rangeLowName, data.rangeLow, startTime, currentTime, clrGray, STYLE_DOT, 1);
   
   // Range Box
   CreateRectangle(m_rangeBoxName, startTime, data.rangeLow, currentTime, data.rangeHigh, 
                  clrGray, false, STYLE_DOT);
   
   // 40% and 80% Lines
   CreateHorizontalLine(m_line40Name, data.line40, startTime, currentTime, clrWhite, STYLE_DOT, 1);
   CreateHorizontalLine(m_line80Name, data.line80, startTime, currentTime, clrWhite, STYLE_DOT, 1);
   
   // Current Price Line - MOVING LINE
   CreateHorizontalLine(m_pullbackLineName, data.currentPrice, startTime, currentTime, 
                       lineColor, STYLE_SOLID, 3);
   
   // Tooltip
   if(ObjectFind(0, m_pullbackLineName) >= 0)
   {
      ObjectSetString(0, m_pullbackLineName, OBJPROP_TOOLTIP, tooltip);
   }
}