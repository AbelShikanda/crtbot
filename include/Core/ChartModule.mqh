//+------------------------------------------------------------------+
//|                        ChartModule.mqh                          |
//|                    Chart Drawing Module                          |
//|                    PURELY VISUAL - NO CALCULATIONS              |
//|                    ALL visual decisions (colors, emojis) here   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.05"

#include "../Data/PullbackModule.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// CHART MODULE INDEPENDENT TOGGLE
// ============================================================
bool g_chartDebugMode = false;  // Set to true to enable chart logging

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
   CPullbackModule* m_pullbackModule;  // Just a pointer - NOT a new class!
   
   // Object names
   string   m_rangeHighName;
   string   m_rangeLowName;
   string   m_line40Name;
   string   m_line80Name;
   string   m_rangeBoxName;
   string   m_pullbackLineName;
   string   m_perfectZoneName;
   string   m_labelName;
   
   // VISUAL DECISION METHODS
   color GetZoneColor(string zoneCategory);
   string GetZoneEmoji(string zoneCategory);
   string GetZoneLabel(string zoneCategory);
   color GetPullbackLineColor(double adjustedPercent);
   string GetTooltip(SPullbackDrawingData &data);
   
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
   void Update();
   void ClearDrawings();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CChartModule::CChartModule(string symbol, ENUM_TIMEFRAMES tf, int rangeBars)
{
   LOG_DEBUG("Initializing for " + (symbol == NULL ? _Symbol : symbol), g_chartDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   m_rangeBars = rangeBars;
   m_prefix = "PBR_" + m_symbol + "_";
   m_pullbackModule = NULL;
   
   m_rangeHighName = m_prefix + "RangeHigh";
   m_rangeLowName = m_prefix + "RangeLow";
   m_line40Name = m_prefix + "Line40";
   m_line80Name = m_prefix + "Line80";
   m_rangeBoxName = m_prefix + "RangeBox";
   m_pullbackLineName = m_prefix + "PullbackLine";
   m_perfectZoneName = m_prefix + "PerfectZone";
   m_labelName = m_prefix + "Label";
   
   LOG_DEBUG("Created with prefix " + m_prefix, g_chartDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CChartModule::~CChartModule()
{
   LOG_WARNING("Destructor - Clearing drawings");
   ClearDrawings();
}

//+------------------------------------------------------------------+
//| Clear Drawings                                                  |
//+------------------------------------------------------------------+
void CChartModule::ClearDrawings()
{
   LOG_DEBUG("Clearing all drawings with prefix " + m_prefix, g_chartDebugMode);
   int deleted = ObjectsDeleteAll(0, m_prefix);
   LOG_DEBUG("Deleted " + IntegerToString(deleted) + " objects", g_chartDebugMode);
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
   LOG_DEBUG("Creating horizontal line " + name + " at price " + DoubleToString(price, _Digits), g_chartDebugMode);
   
   if(!ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price))
   {
      LOG_ERROR("Failed to create line " + name);
      
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
   LOG_DEBUG("Creating rectangle " + name, g_chartDebugMode);
   
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
   {
      LOG_ERROR("Failed to create rectangle " + name);
      
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
   LOG_DEBUG("Creating label " + name + " with text: " + text, g_chartDebugMode);
   
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
   LOG_DEBUG("Update called", g_chartDebugMode);
   
   if(m_pullbackModule == NULL) 
   {
      LOG_WARNING("No pullback module set");
      return;
   }
   
   SPullbackDrawingData data = m_pullbackModule.GetDrawingData();
   LOG_DEBUG("Got drawing data, isValid = " + (data.isValid ? "true" : "false"), g_chartDebugMode);
   
   if(!data.isValid)
   {
      LOG_WARNING("Invalid data, clearing drawings");
      ClearDrawings();
      return;
   }
   
   LOG_INFO("Zone: " + data.zoneCategory + ", Pullback: " + DoubleToString(data.adjustedPercent, 1) + "%", g_chartDebugMode);
   
   color zoneColor = GetZoneColor(data.zoneCategory);
   string zoneEmoji = GetZoneEmoji(data.zoneCategory);
   string zoneLabel = GetZoneLabel(data.zoneCategory);
   color lineColor = GetPullbackLineColor(data.adjustedPercent);
   string tooltip = GetTooltip(data);
   
   ClearDrawings();
   
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
      LOG_DEBUG("Set tooltip for " + m_pullbackLineName, g_chartDebugMode);
   }
   
   LOG_DEBUG("Update complete", g_chartDebugMode);
}