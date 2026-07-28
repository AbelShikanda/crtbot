//+------------------------------------------------------------------+
//|                        Dashboard.mqh                            |
//|                    Dashboard Display Module                      |
//|                    v2.8 - COMPACT DASHBOARD LAYOUT             |
//|                    Shows RSI/VOL/ADX/MACD boost breakdown     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.8"

// ============================================================
// INCLUDES
// ============================================================
#include "../Core/ScenarioNarrative.mqh"
#include "../PackageManagers/ComponentManager.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// DASHBOARD INDEPENDENT TOGGLE
// ============================================================
bool g_dashboardDebugMode = false;  // Set to true to enable dashboard logging

//+------------------------------------------------------------------+
//| Dashboard Class                                                 |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   string   m_symbol;
   string   m_prefix;
   int      m_startX;
   int      m_startY;
   int      m_lineHeight;
   int      m_col1X;
   int      m_col2X;
   int      m_col3X;
   int      m_col4X;
   double   m_lotSize;
   int      m_dashWidth;
   bool     m_debugEnabled;
   
   ScenarioNarrative m_narrativeEngine;
   CTrendManager* m_trendManager;
   CComponentManager* m_componentManager;
   
   double   m_minConfidenceThreshold;
   
   void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool bold);
   void CreateRect(string name, int x, int y, int width, int height, color clr, bool fill);
   
   color GetComponentColor(string direction);
   color GetZoneColor(string zone);
   color GetScenarioColor(ENUM_MARKET_SCENARIO scenario);
   color GetRRColor(double rr);
   color GetConfidenceColor(double conf);
   color GetScoreColor(double score);
   color GetRiskColor(string riskLevel);
   color GetTrendColor(string direction);
   color GetAlignmentColor(string alignment);
   string GetAlignmentSymbol(string alignment);
   string GetBoostEmoji(double boost);
   
   void BuildComponentLines(SComponentResult &compResult, SComponentData &componentData, string &line1, string &line2);
   string GetThresholdDisplay(SMarketAnalysis &analysis, double finalConfidence, double portfolioBoost);
   string PadRight(string text, int width);
   
public:
   CDashboard(string symbol = NULL);
   ~CDashboard();
   
   void SetLotSize(double lotSize);
   void SetTrendManager(CTrendManager* trendManager);
   void SetComponentManager(CComponentManager* componentManager) { m_componentManager = componentManager; }
   void SetMinConfidenceThreshold(double threshold) { m_minConfidenceThreshold = threshold; }
   void ClearDashboard();
   void ShowNoRange();
   void Initialize() {}
   void SetDebug(bool enable) { m_debugEnabled = enable; }
   
   void Update(
      RangeData &range,
      SComponentData &componentData,
      ScenarioResult &scenarioResult,
      PrescribedTrade &trade,
      SComponentResult &compResult,
      SMarketAnalysis &analysis
   );
   
   string GetDashboardText(
      RangeData &range,
      SComponentData &componentData,
      ScenarioResult &scenarioResult,
      PrescribedTrade &trade,
      SComponentResult &compResult,
      SMarketAnalysis &analysis
   );
   
   string GetScenarioName(ENUM_MARKET_SCENARIO scenario);
   string GetRiskLevel(ENUM_MARKET_SCENARIO scenario);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CDashboard::CDashboard(string symbol)
{
   LOG_DEBUG("Constructor called", g_dashboardDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_prefix = "DASH_" + m_symbol + "_";
   m_lotSize = 0.01;
   m_trendManager = NULL;
   m_componentManager = NULL;
   m_minConfidenceThreshold = 70.0;
   m_debugEnabled = g_dashboardDebugMode;
   
   m_startX = 8;
   m_startY = 35;
   m_lineHeight = 14;
   m_col1X = 8;
   m_col2X = 130;
   m_col3X = 250;
   m_col4X = 380;
   m_dashWidth = 520;
   
   LOG_DEBUG("Dashboard created - Symbol: " + m_symbol, g_dashboardDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CDashboard::~CDashboard()
{
   LOG_DEBUG("Destructor called", g_dashboardDebugMode);
   ClearDashboard();
}

//+------------------------------------------------------------------+
//| Set Trend Manager                                               |
//+------------------------------------------------------------------+
void CDashboard::SetTrendManager(CTrendManager* trendManager)
{
   m_trendManager = trendManager;
   if(m_trendManager != NULL)
      LOG_DEBUG("TrendManager set", g_dashboardDebugMode);
   else
      LOG_DEBUG("TrendManager set to NULL", g_dashboardDebugMode);
}

//+------------------------------------------------------------------+
//| Set Lot Size                                                    |
//+------------------------------------------------------------------+
void CDashboard::SetLotSize(double lotSize)
{
   m_lotSize = lotSize;
   LOG_DEBUG("Lot size set to: " + DoubleToString(lotSize, 2), g_dashboardDebugMode);
}

//+------------------------------------------------------------------+
//| Clear Dashboard                                                 |
//+------------------------------------------------------------------+
void CDashboard::ClearDashboard()
{
   int count = ObjectsDeleteAll(0, m_prefix);
   if(count > 0)
   {
      LOG_DEBUG("Cleared " + IntegerToString(count) + " dashboard objects", g_dashboardDebugMode);
   }
}

//+------------------------------------------------------------------+
//| Create Label                                                    |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool bold)
{
   if(text == "") return;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Rectangle                                                |
//+------------------------------------------------------------------+
void CDashboard::CreateRect(string name, int x, int y, int width, int height, color clr, bool fill)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fill ? clr : clrNONE);
   ObjectSetInteger(0, name, OBJPROP_BACK, fill);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Pad Right - Helper for alignment                                |
//+------------------------------------------------------------------+
string CDashboard::PadRight(string text, int width)
{
   string result = text;
   int len = StringLen(text);
   if(len >= width) return result;
   for(int i = len; i < width; i++)
      result += " ";
   return result;
}

//+------------------------------------------------------------------+
//| Get Boost Emoji                                                 |
//+------------------------------------------------------------------+
string CDashboard::GetBoostEmoji(double boost)
{
   if(boost >= 10.0) return "🚀";
   else if(boost >= 5.0) return "📈";
   else if(boost >= 2.0) return "⬆️";
   else if(boost > -2.0) return "✅";
   else if(boost >= -5.0) return "⚠️";
   else return "🔻";
}

//+------------------------------------------------------------------+
//| Show No Range                                                   |
//+------------------------------------------------------------------+
void CDashboard::ShowNoRange()
{
   LOG_DEBUG("Showing 'No Range' message", g_dashboardDebugMode);
   int y = m_startY;
   int x = m_startX;
   
   CreateLabel(m_prefix + "TopLeft", "┌", x, y, clrGray, 8, false);
   CreateLabel(m_prefix + "TopLine", "──────────────────────────────────────────────────────", x + 8, y, clrGray, 8, false);
   CreateLabel(m_prefix + "TopRight", "┐", x + 248, y, clrGray, 8, false);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Title", "│ ◆ PULLBACK DASHBOARD ◆ " + m_symbol, x, y, clrWhite, 9, true);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Sep1", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 8, false);
   y += m_lineHeight + 2;
   
   CreateLabel(m_prefix + "Error", "│ ⛔ NO VALID RANGE DETECTED", x, y, clrOrangeRed, 9, true);
   y += m_lineHeight + 2;
   
   CreateLabel(m_prefix + "BottomLine", "└──────────────────────────────────────────────────────┘", x, y, clrGray, 8, false);
}

// ============================================================
// COLOR HELPERS
// ============================================================

color CDashboard::GetComponentColor(string direction)
{
   if(direction == "BULLISH") return clrLimeGreen;
   else if(direction == "BEARISH") return clrRed;
   else return clrYellow;
}

color CDashboard::GetZoneColor(string zone)
{
   if(zone == "PERFECT") return clrLimeGreen;
   else if(zone == "SWEET") return clrDodgerBlue;
   else if(zone == "EDGE") return clrGold;
   else if(zone == "TRANSITION" || zone == "TRANSITION EDGE") return clrOrange;
   else return clrRed;
}

color CDashboard::GetScenarioColor(ENUM_MARKET_SCENARIO scenario)
{
   return m_narrativeEngine.GetScenarioColor(scenario);
}

color CDashboard::GetRRColor(double rr)
{
   if(rr >= 2.5) return clrLimeGreen;
   if(rr >= 1.5) return clrYellow;
   if(rr >= 1.0) return clrOrange;
   return clrRed;
}

color CDashboard::GetConfidenceColor(double conf)
{
   if(conf >= 85) return clrLimeGreen;
   else if(conf >= 70) return clrGreen;
   else if(conf >= 60) return clrYellow;
   else if(conf >= 40) return clrOrange;
   else return clrRed;
}

color CDashboard::GetScoreColor(double score)
{
   if(score >= 90) return clrLimeGreen;
   else if(score >= 75) return clrGreen;
   else if(score >= 60) return clrYellow;
   else if(score >= 40) return clrOrange;
   else return clrRed;
}

color CDashboard::GetRiskColor(string riskLevel)
{
   if(riskLevel == "LOW" || riskLevel == "LOW-MEDIUM") return clrLimeGreen;
   else if(riskLevel == "MEDIUM" || riskLevel == "FULL RISK") return clrYellow;
   else if(riskLevel == "HIGH") return clrOrange;
   else return clrRed;
}

color CDashboard::GetTrendColor(string direction)
{
   if(direction == "BULLISH") return clrLimeGreen;
   else if(direction == "BEARISH") return clrRed;
   else return clrYellow;
}

color CDashboard::GetAlignmentColor(string alignment)
{
   if(alignment == "AGREE") return clrLimeGreen;
   else if(alignment == "DISAGREE") return clrOrangeRed;
   else return clrYellow;
}

string CDashboard::GetAlignmentSymbol(string alignment)
{
   if(alignment == "AGREE") return "✓";
   else if(alignment == "DISAGREE") return "✗";
   else return "●";
}

string CDashboard::GetScenarioName(ENUM_MARKET_SCENARIO scenario)
{
   return m_narrativeEngine.GetScenarioName(scenario);
}

string CDashboard::GetRiskLevel(ENUM_MARKET_SCENARIO scenario)
{
   return m_narrativeEngine.GetScenarioRiskLevel(scenario);
}

//+------------------------------------------------------------------+
//| Get Threshold Display - WITH ENHANCED BOOST                    |
//+------------------------------------------------------------------+
string CDashboard::GetThresholdDisplay(SMarketAnalysis &analysis, double finalConfidence, double portfolioBoost)
{
   if(m_componentManager == NULL)
      return "Threshold: N/A";
   
   string direction = analysis.overallSentiment;
   double threshold = 0;
   
   if(direction == "BULLISH")
      threshold = m_componentManager.GetBuyThreshold();
   else if(direction == "BEARISH")
      threshold = m_componentManager.GetSellThreshold();
   else
      threshold = 70.0;
   
   string thresholdStatus = "";
   if(finalConfidence >= threshold)
   {
      if(finalConfidence >= threshold + 20)
         thresholdStatus = "✅ STRONG";
      else
         thresholdStatus = "✅ CONFIRMED";
   }
   else
   {
      thresholdStatus = "⏳ WAITING";
   }
   
   // Build boost display
   string boostDisplay = "";
   if(portfolioBoost != 0)
   {
      string boostEmoji = GetBoostEmoji(portfolioBoost);
      string boostSign = (portfolioBoost > 0) ? "+" : "";
      boostDisplay = boostEmoji + " " + boostSign + DoubleToString(portfolioBoost, 1) + "%";
   }
   else
   {
      boostDisplay = "✅ 0.0%";
   }
   
   return StringFormat("Final Conf: %.1f%% %s | Boost: %s | Threshold: %s%.0f%% %s", 
                      finalConfidence,
                      (finalConfidence >= threshold ? "✅" : "⏳"),
                      boostDisplay,
                      (direction == "BULLISH") ? "BUY " : (direction == "BEARISH") ? "SELL " : "",
                      threshold, thresholdStatus);
}

//+------------------------------------------------------------------+
//| Build Component Lines                                           |
//+------------------------------------------------------------------+
void CDashboard::BuildComponentLines(SComponentResult &compResult, SComponentData &componentData, string &line1, string &line2)
{
   LOG_DEBUG("Building component lines...", g_dashboardDebugMode);
   
   line1 = "";
   line2 = "";
   
   // PB: Uses SCORE (for display)
   string pbArrow = compResult.pb.direction;
   if(pbArrow == "") pbArrow = "●";
   line1 += pbArrow + StringFormat("%.2f", compResult.pb.weight) + "PB";
   line1 += ":" + StringFormat("%.0f%%", compResult.pb.score);
   line1 += GetAlignmentSymbol(compResult.pb.alignment);
   
   // MTF
   string mtfArrow = compResult.mtf.direction;
   if(mtfArrow == "") mtfArrow = "●";
   line1 += " | " + mtfArrow + StringFormat("%.2f", compResult.mtf.weight) + "MTF";
   line1 += ":" + StringFormat("%.0f%%", compResult.mtf.confidence);
   line1 += GetAlignmentSymbol(compResult.mtf.alignment);
   
   // MACD
   string macdArrow = compResult.macd.direction;
   if(macdArrow == "") macdArrow = "●";
   line1 += " | " + macdArrow + StringFormat("%.2f", compResult.macd.weight) + "MACD";
   line1 += ":" + StringFormat("%.0f%%", compResult.macd.confidence);
   line1 += GetAlignmentSymbol(compResult.macd.alignment);
   
   // ADX
   string adxArrow = compResult.adx.direction;
   if(adxArrow == "") adxArrow = "●";
   line2 += adxArrow + StringFormat("%.2f", compResult.adx.weight) + "ADX";
   line2 += ":" + StringFormat("%.0f%%", compResult.adx.confidence);
   line2 += GetAlignmentSymbol(compResult.adx.alignment);
   
   // RSI
   string rsiArrow = compResult.rsi.direction;
   if(rsiArrow == "") rsiArrow = "●";
   line2 += " | " + rsiArrow + StringFormat("%.2f", compResult.rsi.weight) + "RSI";
   line2 += ":" + StringFormat("%.0f%%", compResult.rsi.confidence);
   line2 += GetAlignmentSymbol(compResult.rsi.alignment);
   
   // VOL
   string volArrow = compResult.vol.direction;
   if(volArrow == "") volArrow = "●";
   line2 += " | " + volArrow + StringFormat("%.2f", compResult.vol.weight) + "VOL";
   line2 += ":" + StringFormat("%.0f%%", compResult.vol.confidence);
   line2 += GetAlignmentSymbol(compResult.vol.alignment);
   
   LOG_DEBUG("  Component line1: " + line1, g_dashboardDebugMode);
   LOG_DEBUG("  Component line2: " + line2, g_dashboardDebugMode);
}

// ============================================================
// GET DASHBOARD TEXT
// ============================================================
string CDashboard::GetDashboardText(
   RangeData &range,
   SComponentData &componentData,
   ScenarioResult &scenarioResult,
   PrescribedTrade &trade,
   SComponentResult &compResult,
   SMarketAnalysis &analysis
)
{
   LOG_DEBUG("Generating dashboard text...", g_dashboardDebugMode);
   
   string output = "";
   
   output += "┌─────────────────────────────────────────────────────────────────────────────┐\n";
   output += "│ ◆ PULLBACK DASHBOARD ◆ " + m_symbol + PadRight("", 40 - StringLen(m_symbol)) + "│\n";
   output += "├─────────────────────────────────────────────────────────────────────────────┤\n";
   
   // MERGED SCENARIO + DESCRIPTION
   string scenarioDisplay = "│ SCENARIO #" + IntegerToString((int)scenarioResult.scenario) + ": " + GetScenarioName(scenarioResult.scenario) + " | " + scenarioResult.description;
   if(StringLen(scenarioDisplay) > 74) scenarioDisplay = StringSubstr(scenarioDisplay, 0, 74) + "...";
   output += scenarioDisplay + PadRight("", 74 - StringLen(scenarioDisplay)) + "│\n";
   
   output += "├─────────────────────────────────────────────────────────────────────────────┤\n";
   
   // COMPONENTS + TREND merged into one section
   if(m_trendManager != NULL)
   {
      string trendDir = m_trendManager.GetDirection();
      double trendStrength = m_trendManager.GetStrength();
      double trendConfidence = m_trendManager.GetTrendConfidence();
      string arrow = (trendDir == "BULLISH") ? "▲" : (trendDir == "BEARISH") ? "▼" : "●";
      output += "│ COMPONENTS:    TREND: " + arrow + " " + trendDir + " | Stren: " + DoubleToString(trendStrength, 1) + "% | Conf: " + DoubleToString(trendConfidence, 1) + "%\n";
   }
   else
   {
      output += "│ COMPONENTS:    TREND: ● NEUTRAL | Stren: 0.0% | Conf: 0.0%\n";
   }
   
   string compLine1, compLine2;
   BuildComponentLines(compResult, componentData, compLine1, compLine2);
   output += "│   " + compLine1 + "\n";
   output += "│   " + compLine2 + "\n";
   
   // MERGED AGGREGATED SECTION
   output += "│   " + compResult.direction + " | Base Conf: " + DoubleToString(compResult.confidence, 1) + "% | Active: " + IntegerToString(compResult.activeComponents) + "/6 | Agree: " + IntegerToString(compResult.agreeingComponents) + " | Disagree: " + IntegerToString(compResult.disagreeingComponents) + "\n";
   
   // Threshold display (includes final confidence and boost)
   double finalConf = componentData.finalConfidence;
   double boost = componentData.portfolioBoost;
   string thresholdDisplay = GetThresholdDisplay(analysis, finalConf, boost);
   output += "│   " + thresholdDisplay + "\n";
   
   output += "├─────────────────────────────────────────────────────────────────────────────┤\n";
   output += "│ TRADE:\n";
   
   if(trade.signal != 0)
   {
      string dirSymbol = trade.signal == 1 ? "▲ BUY" : "▼ SELL";
      bool isOpenPosition = (trade.entryPrice > 0 && trade.stopLoss > 0);
      string statusText = isOpenPosition ? "📊 OPEN" : "📈 SIGNAL";
      
      // Calculate profit if position is open
      double profitPips = 0;
      if(isOpenPosition)
      {
         double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         if(trade.signal == 1)
            profitPips = (currentPrice - trade.entryPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         else
            profitPips = (trade.entryPrice - currentPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      }
      
      string profitText = isOpenPosition ? StringFormat("%.1f pips", profitPips) : "0.0 pips";
      color profitColor = (isOpenPosition && profitPips >= 0) ? clrLimeGreen : clrRed;
      
      output += StringFormat("│ %s %s │ LOT: %-8.2f │ R:R: %-8.2f │ Profit: %s\n", 
                             statusText, dirSymbol, m_lotSize, trade.riskRewardRatio, profitText);
   }
   else
   {
      output += "│ ● HOLDING / NO POSITION │ LOT: 0.00 │ R:R: 0.00 │ Profit: 0.0 pips\n";
   }
   
   output += "└─────────────────────────────────────────────────────────────────────────────┘";
   
   LOG_DEBUG("Dashboard text generated (" + IntegerToString(StringLen(output)) + " chars)", g_dashboardDebugMode);
   return output;
}

// ============================================================
// UPDATE DASHBOARD - COMPACT LAYOUT
// ============================================================
void CDashboard::Update(
   RangeData &range,
   SComponentData &componentData,
   ScenarioResult &scenarioResult,
   PrescribedTrade &trade,
   SComponentResult &compResult,
   SMarketAnalysis &analysis
)
{
   LOG_DEBUG("=== DASHBOARD UPDATE ===", g_dashboardDebugMode);
   
   ClearDashboard();
   
   if(!range.isValid)
   {
      LOG_WARNING("⚠️ No valid range - showing 'No Range' message");
      ShowNoRange();
      return;
   }
   
   int y = m_startY;
   int x = m_startX;
   int fs = 8;
   int fsSmall = 7;
   int fsTitle = 9;
   
   // Top border
   CreateLabel(m_prefix + "TopLeft", "┌", x, y, clrGray, 8, false);
   CreateLabel(m_prefix + "TopLine", "──────────────────────────────────────────────────────", x + 8, y, clrGray, 8, false);
   CreateLabel(m_prefix + "TopRight", "┐", x + 248, y, clrGray, 8, false);
   y += m_lineHeight;
   
   // Title
   CreateLabel(m_prefix + "Title", "│ ◆ PULLBACK DASHBOARD ◆ " + m_symbol, x, y, clrWhite, fsTitle, true);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Sep1", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 8, false);
   y += m_lineHeight + 1;
   
   // MERGED SCENARIO + DESCRIPTION
   ENUM_MARKET_SCENARIO currentScenario = scenarioResult.scenario;
   color scenarioColor = GetScenarioColor(currentScenario);
   string scenarioName = GetScenarioName(currentScenario);
   
   string scenarioDisplay = "│ SCENARIO #" + IntegerToString((int)currentScenario) + ": " + scenarioName + " | " + scenarioResult.description;
   if(StringLen(scenarioDisplay) > 55) scenarioDisplay = StringSubstr(scenarioDisplay, 0, 55) + "...";
   CreateLabel(m_prefix + "Scenario", scenarioDisplay, x, y, scenarioColor, fs, true);
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "Sep2", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 8, false);
   y += m_lineHeight + 1;
   
   // COMPONENTS + TREND merged into one line
   if(m_trendManager != NULL)
   {
      string trendDir = m_trendManager.GetDirection();
      double trendStrength = m_trendManager.GetStrength();
      double trendConfidence = m_trendManager.GetTrendConfidence();
      string arrow = (trendDir == "BULLISH") ? "▲" : (trendDir == "BEARISH") ? "▼" : "●";
      color trendColor = GetTrendColor(trendDir);
      
      string trendDisplay = "│ COMPONENTS:    TREND: " + arrow + " " + trendDir + " | Stren: " + DoubleToString(trendStrength, 1) + "% | Conf: " + DoubleToString(trendConfidence, 1) + "%";
      CreateLabel(m_prefix + "Trend", trendDisplay, x, y, trendColor, fsSmall, false);
      y += m_lineHeight;
   }
   else
   {
      CreateLabel(m_prefix + "Trend", "│ COMPONENTS:    TREND: ● NEUTRAL | Stren: 0.0% | Conf: 0.0%", x, y, clrYellow, fsSmall, false);
      y += m_lineHeight;
   }
   
   CreateLabel(m_prefix + "Legend", "│   Format: ▲WeightName:Score%✓  (PB=Score, Others=Confidence)", x + 2, y, clrGray, 6, false);
   y += m_lineHeight;
   
   string compLine1, compLine2;
   BuildComponentLines(compResult, componentData, compLine1, compLine2);
   
   CreateLabel(m_prefix + "Components1", "│   " + compLine1, x + 2, y, clrLightGray, fsSmall, false);
   y += m_lineHeight;
   CreateLabel(m_prefix + "Components2", "│   " + compLine2, x + 2, y, clrLightGray, fsSmall, false);
   y += m_lineHeight;
   
   // AGGREGATED SECTION
   color aggColor = GetComponentColor(compResult.direction);
   
   string aggLine1 = "│   " + compResult.direction + " | Base Conf: " + DoubleToString(compResult.confidence, 1) + "% | Active: " + IntegerToString(compResult.activeComponents) + "/6 | Agree: " + IntegerToString(compResult.agreeingComponents) + " | Disagree: " + IntegerToString(compResult.disagreeingComponents);
   CreateLabel(m_prefix + "Agg1", aggLine1, x + 2, y, aggColor, fsSmall, false);
   y += m_lineHeight;
   
   // THRESHOLD DISPLAY (includes final confidence and boost)
   double finalConf = componentData.finalConfidence;
   double boost = componentData.portfolioBoost;
   
   string direction = compResult.direction;
   double threshold = 70.0;
   if(m_componentManager != NULL)
   {
      if(direction == "BULLISH")
         threshold = m_componentManager.GetBuyThreshold();
      else if(direction == "BEARISH")
         threshold = m_componentManager.GetSellThreshold();
   }
   
   string thresholdStatus = "";
   color thresholdColor;
   if(finalConf >= threshold)
   {
      if(finalConf >= threshold + 20)
      {
         thresholdStatus = "✅ STRONG (≥" + DoubleToString(threshold, 0) + "%)";
         thresholdColor = clrLimeGreen;
      }
      else
      {
         thresholdStatus = "✅ CONFIRMED (≥" + DoubleToString(threshold, 0) + "%)";
         thresholdColor = clrGreen;
      }
   }
   else
   {
      thresholdStatus = "⏳ WAITING (<" + DoubleToString(threshold, 0) + "%)";
      thresholdColor = clrYellow;
   }
   
   string boostEmoji = GetBoostEmoji(boost);
   string boostSign = (boost > 0) ? "+" : "";
   string boostDisplay = "";
   if(boost != 0)
      boostDisplay = boostEmoji + " " + boostSign + DoubleToString(boost, 1) + "%";
   else
      boostDisplay = "✅ 0.0%";
   
   string dirLabel = (direction == "BULLISH") ? "BUY" : (direction == "BEARISH") ? "SELL" : "";
   string thresholdLine = "│   Final Conf: " + DoubleToString(finalConf, 1) + "% | Boost: " + boostDisplay + " | Threshold: " + dirLabel + " " + thresholdStatus;
   CreateLabel(m_prefix + "Threshold", thresholdLine, x + 2, y, thresholdColor, fsSmall, false);
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "Sep3", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 8, false);
   y += m_lineHeight + 1;
   
   // TRADE SECTION - Compact with profit
   CreateLabel(m_prefix + "TradeHeader", "│ TRADE:", x, y, clrWhite, fs, true);
   y += m_lineHeight;
   
   if(trade.signal != 0)
   {
      color dirColor = trade.signal == 1 ? clrLimeGreen : clrRed;
      string dirSymbol = trade.signal == 1 ? "▲ BUY" : "▼ SELL";
      
      bool isOpenPosition = (trade.entryPrice > 0 && trade.stopLoss > 0);
      string statusText = isOpenPosition ? "📊 OPEN" : "📈 SIGNAL";
      string lotText = "LOT: " + DoubleToString(m_lotSize, 2);
      string rrText = "R:R: " + DoubleToString(trade.riskRewardRatio, 2);
      
      // Calculate profit if position is open
      double profitPips = 0;
      if(isOpenPosition)
      {
         double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         if(trade.signal == 1)
            profitPips = (currentPrice - trade.entryPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         else
            profitPips = (trade.entryPrice - currentPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      }
      
      string profitText = isOpenPosition ? StringFormat("%.1f pips", profitPips) : "0.0 pips";
      color profitColor = (isOpenPosition && profitPips >= 0) ? clrLimeGreen : clrRed;
      
      string tradeLine = "│ " + statusText + " " + dirSymbol + "│ " + lotText + "│ " + rrText + "│ Profit: " + profitText;
      CreateLabel(m_prefix + "TradeDir", tradeLine, x, y, dirColor, fs, false);
      y += m_lineHeight;
   }
   else
   {
      string tradeLine = "│ ● HOLDING / NO POSITION │ LOT: 0.00 │ R:R: 0.00 │ Profit: 0.0 pips";
      CreateLabel(m_prefix + "TradeHold", tradeLine, x, y, clrGray, fs, false);
      y += m_lineHeight;
   }
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "BottomLine", "└──────────────────────────────────────────────────────┘", x, y, clrGray, 8, false);
   
   LOG_DEBUG("✅ Dashboard update complete (COMPACT LAYOUT)", g_dashboardDebugMode);
   LOG_DEBUG("=== DASHBOARD UPDATE END ===", g_dashboardDebugMode);
}