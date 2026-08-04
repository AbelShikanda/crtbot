//+------------------------------------------------------------------+
//|                        Dashboard.mqh                            |
//|                    Dashboard Display Module                      |
//|                    v4.1 - DETAILED RISK STATUS                  |
//|                    SHOWS EXACT BLOCKING REASON                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "4.1"

// ============================================================
// INCLUDES
// ============================================================
#include "../Core/ScenarioNarrative.mqh"
#include "../PackageManagers/ComponentManager.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include "../PackageManagers/Riskmanager.mqh"
#include "../PackageManagers/PositionManager.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// DASHBOARD INDEPENDENT TOGGLE
// ============================================================
bool g_dashboardDebugMode = false;

//+------------------------------------------------------------------+
//| Progress Check Structure                                        |
//+------------------------------------------------------------------+
struct SProgressCheck
{
   int      step;
   string   name;
   bool     passed;
   bool     isActive;
   string   message;
   string   statusText;
   int      colorCode;
};

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
   int      m_dashWidth;
   double   m_lotSize;
   bool     m_debugEnabled;
   
   ScenarioNarrative m_narrativeEngine;
   CTrendManager* m_trendManager;
   CComponentManager* m_componentManager;
   CRiskManager* m_riskManager;
   CPositionManager* m_positionManager;
   
   double   m_minConfidenceThreshold;
   
   // ═══ PROGRESS TRACKING - 8 STEPS ═══
   SProgressCheck m_progress[8];
   int      m_currentStep;
   bool     m_allChecksPassed;
   bool     m_tradeExecuted;
   datetime m_lastBarTime;
   string   m_overallStatus;
   int      m_overallColorCode;
   
   void CreateLabel(string name, string text, int x, int y, int clr, int fontSize, bool bold);
   void CreateRect(string name, int x, int y, int width, int height, int clr, bool fill);
   void ClearDashboard();
   
   // ═══ PROGRESS METHODS ═══
   void InitializeProgress();
   void DrawProgressChecks(int x, int y);
   string GetOverallStatus();
   int GetOverallColor();
   int GetProgressPercent();
   string GetStatusEmoji(bool passed);
   int GetStatusColor(bool passed);
   string PadRight(string text, int width);
   
   // ═══ NEW: DETAILED RISK STATUS ═══
   string GetDetailedRiskStatus();
   
   // ═══ COLOR HELPERS ═══
   int GetComponentColor(string direction);
   int GetScenarioColor(ENUM_MARKET_SCENARIO scenario);
   int GetTrendColor(string direction);
   string GetBoostEmoji(double boost);
   string GetScenarioName(ENUM_MARKET_SCENARIO scenario);
   
public:
   CDashboard(string symbol = NULL);
   ~CDashboard();
   
   void SetLotSize(double lotSize) { m_lotSize = lotSize; }
   void SetTrendManager(CTrendManager* trendManager) { m_trendManager = trendManager; }
   void SetComponentManager(CComponentManager* componentManager) { m_componentManager = componentManager; }
   void SetRiskManager(CRiskManager* riskManager) { m_riskManager = riskManager; }
   void SetPositionManager(CPositionManager* positionManager) { m_positionManager = positionManager; }
   void SetMinConfidenceThreshold(double threshold) { m_minConfidenceThreshold = threshold; }
   void SetDebug(bool enable) { m_debugEnabled = enable; }
   void Initialize() { InitializeProgress(); m_lastBarTime = 0; m_tradeExecuted = false; }
   void ShowNoRange();
   
   // ═══ PROGRESS UPDATE METHODS ═══
   void SetCheckPassed(int step, string message);
   void SetCheckFailed(int step, string message);
   void SetCheckPending(int step, string message);
   void SetTradeExecuted() { m_tradeExecuted = true; m_lastBarTime = iTime(m_symbol, PERIOD_M5, 0); }
   void ResetProgress() { InitializeProgress(); }
   
   // ═══ MAIN UPDATE ═══
   void Update(
      RangeData &range,
      SComponentData &componentData,
      ScenarioResult &scenarioResult,
      PrescribedTrade &trade,
      SComponentResult &compResult,
      SMarketAnalysis &analysis
   );
   
   // ═══ GETTERS ═══
   string GetProgressStatus() const { return m_overallStatus; }
   int GetProgressColor() const { return m_overallColorCode; }
   int GetCurrentStep() const { return m_currentStep; }
   bool GetAllChecksPassed() const { return m_allChecksPassed; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CDashboard::CDashboard(string symbol)
{
   LOG_DEBUG("Dashboard v4.1 Constructor called", g_dashboardDebugMode);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_prefix = "DASH_" + m_symbol + "_";
   m_lotSize = 0.01;
   m_trendManager = NULL;
   m_componentManager = NULL;
   m_riskManager = NULL;
   m_positionManager = NULL;
   m_minConfidenceThreshold = 70.0;
   m_debugEnabled = g_dashboardDebugMode;
   
   m_startX = 8;
   m_startY = 35;
   m_lineHeight = 16;
   m_dashWidth = 540;
   
   m_currentStep = 0;
   m_allChecksPassed = false;
   m_tradeExecuted = false;
   m_lastBarTime = 0;
   m_overallColorCode = clrYellow;
   
   InitializeProgress();
   
   LOG_DEBUG("Dashboard v4.1 created - Shows detailed risk blocking reasons", g_dashboardDebugMode);
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
//| Initialize Progress - 8 STEPS                                  |
//+------------------------------------------------------------------+
void CDashboard::InitializeProgress()
{
   string stepNames[8] = {
      "Risk Manager",      // Step 1: Cooldown, daily limits
      "Priority",          // Step 2: Crossover Priority 1-3
      "Direction",         // Step 3: BULLISH/BEARISH (not NEUTRAL)
      "Strength",          // Step 4: Trend strength >= threshold
      "Exhaustion",        // Step 5: CandleModule exhaustion
      "Confidence",        // Step 6: ComponentManager confidence
      "Alignment",         // Step 7: Signal aligns with trend
      "Execution"          // Step 8: PositionManager executes
   };
   
   for(int i = 0; i < 8; i++)
   {
      m_progress[i].step = i + 1;
      m_progress[i].name = stepNames[i];
      m_progress[i].passed = false;
      m_progress[i].isActive = false;
      m_progress[i].message = "Waiting...";
      m_progress[i].statusText = "⏳ WAITING";
      m_progress[i].colorCode = clrGray;
   }
   
   m_currentStep = 0;
   m_allChecksPassed = false;
   m_overallStatus = "⏳ WAITING FOR SIGNAL...";
   m_overallColorCode = clrYellow;
}

//+------------------------------------------------------------------+
//| GET DETAILED RISK STATUS - SHOWS EXACT BLOCKING REASON         |
//+------------------------------------------------------------------+
string CDashboard::GetDetailedRiskStatus()
{
   if(m_riskManager == NULL) 
      return "⚠️ Risk Manager: NOT INITIALIZED";
   
   // --- Check 1: Day Stopped ---
   if(m_riskManager.IsDayStoppedFlag())
   {
      if(m_riskManager.GetDailyTradeCount() >= m_riskManager.GetMaxDailyTrades())
         return "🛑 DAY STOPPED - Daily limit: " + IntegerToString(m_riskManager.GetDailyTradeCount()) + "/" + IntegerToString(m_riskManager.GetMaxDailyTrades());
      else
         return "🛑 DAY STOPPED - Big profit/Manual stop";
   }
   
   // --- Check 2: Cooldown ---
   if(m_riskManager.IsInCooldown())
   {
      string remaining = m_riskManager.GetCooldownRemaining();
      return "⏳ COOLDOWN - " + remaining;
   }
   
   // --- Check 3: Daily Limit ---
   if(m_riskManager.GetDailyTradeCount() >= m_riskManager.GetMaxDailyTrades())
   {
      return "📊 DAILY LIMIT - " + IntegerToString(m_riskManager.GetDailyTradeCount()) + "/" + IntegerToString(m_riskManager.GetMaxDailyTrades());
   }
   
   // --- Check 4: Max Drawdown ---
   double drawdown = m_riskManager.GetCurrentDrawdown();
   double maxDrawdown = m_riskManager.GetMaxDrawdown();
   if(drawdown >= maxDrawdown)
   {
      return "⚠️ MAX DRAWDOWN - " + DoubleToString(drawdown, 1) + "% ≥ " + DoubleToString(maxDrawdown, 1) + "%";
   }
   
   // --- Check 5: Max Positions ---
   int positions = PositionsTotal();
   if(positions >= InpMaxPositions)
   {
      return "📊 MAX POSITIONS - " + IntegerToString(positions) + "/" + IntegerToString(InpMaxPositions);
   }
   
   // --- All checks passed ---
   return "✅ READY - " + IntegerToString(m_riskManager.GetDailyTradeCount()) + "/" + IntegerToString(m_riskManager.GetMaxDailyTrades()) + " today";
}

//+------------------------------------------------------------------+
//| Set Check Passed                                                |
//+------------------------------------------------------------------+
void CDashboard::SetCheckPassed(int step, string message)
{
   if(step < 1 || step > 8) return;
   
   int idx = step - 1;
   m_progress[idx].passed = true;
   m_progress[idx].isActive = false;
   m_progress[idx].message = message;
   m_progress[idx].statusText = "✅ PASSED";
   m_progress[idx].colorCode = clrLimeGreen;
   
   if(step > m_currentStep)
      m_currentStep = step;
   
   bool allPassed = true;
   for(int i = 0; i < 8; i++)
   {
      if(!m_progress[i].passed)
      {
         allPassed = false;
         break;
      }
   }
   
   if(allPassed)
   {
      m_allChecksPassed = true;
      m_overallStatus = "✅ READY FOR EXECUTION";
      m_overallColorCode = clrLimeGreen;
   }
}

//+------------------------------------------------------------------+
//| Set Check Failed                                                |
//+------------------------------------------------------------------+
void CDashboard::SetCheckFailed(int step, string message)
{
   if(step < 1 || step > 8) return;
   
   int idx = step - 1;
   m_progress[idx].passed = false;
   m_progress[idx].isActive = true;
   m_progress[idx].message = message;
   m_progress[idx].statusText = "❌ FAILED";
   m_progress[idx].colorCode = clrRed;
   
   m_currentStep = step;
   m_allChecksPassed = false;
   m_overallStatus = "❌ BLOCKED - " + m_progress[idx].name;
   m_overallColorCode = clrRed;
}

//+------------------------------------------------------------------+
//| Set Check Pending                                               |
//+------------------------------------------------------------------+
void CDashboard::SetCheckPending(int step, string message)
{
   if(step < 1 || step > 8) return;
   
   int idx = step - 1;
   m_progress[idx].passed = false;
   m_progress[idx].isActive = true;
   m_progress[idx].message = message;
   m_progress[idx].statusText = "⏳ CHECKING...";
   m_progress[idx].colorCode = clrYellow;
   
   m_currentStep = step;
   m_allChecksPassed = false;
   m_overallStatus = "⏳ CHECKING - " + m_progress[idx].name;
   m_overallColorCode = clrYellow;
}

//+------------------------------------------------------------------+
//| Get Overall Status                                              |
//+------------------------------------------------------------------+
string CDashboard::GetOverallStatus()
{
   if(m_tradeExecuted)
   {
      datetime currentBar = iTime(m_symbol, PERIOD_M5, 0);
      if(currentBar == m_lastBarTime)
         return "✅ EXECUTED - Position OPEN";
      else
      {
         m_tradeExecuted = false;
         m_lastBarTime = currentBar;
         InitializeProgress();
         return "⏳ RESET - New bar detected";
      }
   }
   
   return m_overallStatus;
}

//+------------------------------------------------------------------+
//| Get Overall Color                                               |
//+------------------------------------------------------------------+
int CDashboard::GetOverallColor()
{
   if(m_tradeExecuted)
   {
      datetime currentBar = iTime(m_symbol, PERIOD_M5, 0);
      if(currentBar == m_lastBarTime)
         return clrLimeGreen;
   }
   return m_overallColorCode;
}

//+------------------------------------------------------------------+
//| Get Progress Percent - 8 STEPS                                 |
//+------------------------------------------------------------------+
int CDashboard::GetProgressPercent()
{
   if(m_tradeExecuted) return 100;
   if(m_currentStep == 0) return 0;
   
   int passedCount = 0;
   for(int i = 0; i < m_currentStep; i++)
   {
      if(m_progress[i].passed) passedCount++;
   }
   return (passedCount * 100) / 8;
}

//+------------------------------------------------------------------+
//| Get Status Emoji                                                |
//+------------------------------------------------------------------+
string CDashboard::GetStatusEmoji(bool passed)
{
   return passed ? "✅" : "❌";
}

//+------------------------------------------------------------------+
//| Get Status Color                                                |
//+------------------------------------------------------------------+
int CDashboard::GetStatusColor(bool passed)
{
   return passed ? clrLimeGreen : clrRed;
}

//+------------------------------------------------------------------+
//| Get Scenario Name                                               |
//+------------------------------------------------------------------+
string CDashboard::GetScenarioName(ENUM_MARKET_SCENARIO scenario)
{
   return m_narrativeEngine.GetScenarioName(scenario);
}

//+------------------------------------------------------------------+
//| Get Scenario Color                                              |
//+------------------------------------------------------------------+
int CDashboard::GetScenarioColor(ENUM_MARKET_SCENARIO scenario)
{
   return m_narrativeEngine.GetScenarioColor(scenario);
}

//+------------------------------------------------------------------+
//| Get Component Color                                             |
//+------------------------------------------------------------------+
int CDashboard::GetComponentColor(string direction)
{
   if(direction == "BULLISH") return clrLimeGreen;
   else if(direction == "BEARISH") return clrRed;
   else return clrYellow;
}

//+------------------------------------------------------------------+
//| Get Trend Color                                                 |
//+------------------------------------------------------------------+
int CDashboard::GetTrendColor(string direction)
{
   if(direction == "BULLISH") return clrLimeGreen;
   else if(direction == "BEARISH") return clrRed;
   else return clrYellow;
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
//| Pad Right                                                       |
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
//| Create Label                                                    |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, string text, int x, int y, int clr, int fontSize, bool bold)
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
void CDashboard::CreateRect(string name, int x, int y, int width, int height, int clr, bool fill)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, fill);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
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
//| Show No Range                                                   |
//+------------------------------------------------------------------+
void CDashboard::ShowNoRange()
{
   LOG_DEBUG("Showing 'No Range' message", g_dashboardDebugMode);
   int y = m_startY;
   int x = m_startX;
   
   CreateLabel(m_prefix + "TopLeft", "┌", x, y, clrGray, 9, false);
   CreateLabel(m_prefix + "TopLine", "──────────────────────────────────────────────────────", x + 8, y, clrGray, 9, false);
   CreateLabel(m_prefix + "TopRight", "┐", x + 248, y, clrGray, 9, false);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Title", "│ ◆ PULLBACK DASHBOARD ◆ " + m_symbol, x, y, clrWhite, 10, true);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Sep1", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 9, false);
   y += m_lineHeight + 2;
   
   CreateLabel(m_prefix + "Error", "│ ⛔ NO VALID RANGE DETECTED", x, y, clrOrangeRed, 10, true);
   y += m_lineHeight + 2;
   
   CreateLabel(m_prefix + "BottomLine", "└──────────────────────────────────────────────────────┘", x, y, clrGray, 9, false);
}

//+------------------------------------------------------------------+
//| Draw Progress Checks - WITH DETAILED RISK STATUS               |
//+------------------------------------------------------------------+
void CDashboard::DrawProgressChecks(int x, int y)
{
   int checkY = y;
   int indent = 4;
   int barWidth = 55;
   int percent = GetProgressPercent();
   
   // ─── PROGRESS BAR ───
   string progressBar = "";
   int filled = (percent * barWidth) / 100;
   
   progressBar = "[";
   for(int i = 0; i < barWidth; i++)
   {
      if(i < filled)
         progressBar += "█";
      else
         progressBar += "░";
   }
   progressBar += "]";
   
   int progressColor;
   if(percent <= 33)
      progressColor = clrRed;
   else if(percent <= 66)
      progressColor = clrOrange;
   else
      progressColor = clrLimeGreen;
   
   if(m_tradeExecuted)
      progressColor = clrLimeGreen;
   
   CreateLabel(m_prefix + "ProgressBar", progressBar, x + indent, checkY, progressColor, 8, false);
   checkY += m_lineHeight - 2;
   
   // ─── CHECK LIST - SHOW CURRENT CHECK WITH DETAILED STATUS ───
   if(m_currentStep == 0 && !m_tradeExecuted)
   {
      string riskStatus = GetDetailedRiskStatus();
      string waitingText = "⏳ " + riskStatus;
      if(StringLen(waitingText) > 58) waitingText = StringSubstr(waitingText, 0, 58) + "...";
      CreateLabel(m_prefix + "Check0", waitingText, x + indent, checkY, clrYellow, 8, false);
      return;
   }
   
   if(m_tradeExecuted)
   {
      string execText = "✅ EXECUTED - Position OPEN";
      CreateLabel(m_prefix + "CheckExec", execText, x + indent, checkY, clrLimeGreen, 8, false);
      return;
   }
   
   int currentIdx = m_currentStep - 1;
   
   if(currentIdx >= 0 && currentIdx < 8)
   {
      string checkText = "";
      int checkColor = m_progress[currentIdx].colorCode;
      
      // ─── STEP 1: RISK MANAGER - SHOW DETAILED REASON ───
      if(currentIdx == 0)
      {
         string riskStatus = GetDetailedRiskStatus();
         if(m_progress[currentIdx].passed)
         {
            checkText = "✅ " + riskStatus;
            checkColor = clrLimeGreen;
         }
         else if(m_progress[currentIdx].isActive)
         {
            checkText = "⏳ " + riskStatus;
            checkColor = clrYellow;
         }
         else
         {
            checkText = "❌ " + riskStatus;
            checkColor = clrRed;
         }
      }
      else if(m_progress[currentIdx].passed)
      {
         checkText = "✅ Step " + IntegerToString(m_currentStep) + "/8: " + m_progress[currentIdx].name + " - " + m_progress[currentIdx].message;
         checkColor = clrLimeGreen;
      }
      else if(m_progress[currentIdx].isActive)
      {
         checkText = "⏳ Step " + IntegerToString(m_currentStep) + "/8: " + m_progress[currentIdx].name + " - " + m_progress[currentIdx].message;
         checkColor = clrYellow;
      }
      else
      {
         checkText = "⏳ Step " + IntegerToString(m_currentStep) + "/8: " + m_progress[currentIdx].name + " - " + m_progress[currentIdx].message;
         checkColor = clrYellow;
      }
      
      if(StringLen(checkText) > 58)
         checkText = StringSubstr(checkText, 0, 58) + "...";
      
      CreateLabel(m_prefix + "CheckCurrent", checkText, x + indent, checkY, checkColor, 8, false);
   }
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD - WITH DETAILED RISK STATUS                   |
//+------------------------------------------------------------------+
void CDashboard::Update(
   RangeData &range,
   SComponentData &componentData,
   ScenarioResult &scenarioResult,
   PrescribedTrade &trade,
   SComponentResult &compResult,
   SMarketAnalysis &analysis
)
{
   LOG_DEBUG("=== DASHBOARD UPDATE (v4.1) ===", g_dashboardDebugMode);
   
   ClearDashboard();
   
   if(!range.isValid)
   {
      LOG_WARNING("⚠️ No valid range - showing 'No Range' message");
      ShowNoRange();
      return;
   }
   
   // ═══ UPDATE BAR TIME ═══
   datetime currentBar = iTime(m_symbol, PERIOD_M5, 0);
   if(currentBar != m_lastBarTime && m_tradeExecuted)
   {
      m_tradeExecuted = false;
      InitializeProgress();
      LOG_DEBUG("🔄 New bar detected - Progress reset", g_dashboardDebugMode);
   }
   if(currentBar != m_lastBarTime)
      m_lastBarTime = currentBar;
   
   int y = m_startY;
   int x = m_startX;
   
   int fs = 9;
   int fsSmall = 8;
   int fsTitle = 10;
   
   // Top border
   CreateLabel(m_prefix + "TopLeft", "┌", x, y, clrGray, 9, false);
   CreateLabel(m_prefix + "TopLine", "──────────────────────────────────────────────────────", x + 8, y, clrGray, 9, false);
   CreateLabel(m_prefix + "TopRight", "┐", x + 248, y, clrGray, 9, false);
   y += m_lineHeight;
   
   // Title with Risk Status
   string riskStatus = GetDetailedRiskStatus();
   string titleText = "│ ◆ PULLBACK v4.1 ◆ " + m_symbol + " | " + riskStatus;
   if(StringLen(titleText) > 55) titleText = StringSubstr(titleText, 0, 55);
   CreateLabel(m_prefix + "Title", titleText, x, y, clrWhite, fsTitle, true);
   y += m_lineHeight;
   
   CreateLabel(m_prefix + "Sep1", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 9, false);
   y += m_lineHeight + 1;
   
   // SCENARIO + DESCRIPTION
   ENUM_MARKET_SCENARIO currentScenario = scenarioResult.scenario;
   int scenarioColor = GetScenarioColor(currentScenario);
   string scenarioName = GetScenarioName(currentScenario);
   
   string scenarioDisplay = "│ SCENARIO #" + IntegerToString((int)currentScenario) + ": " + scenarioName + " | " + scenarioResult.description;
   if(StringLen(scenarioDisplay) > 55) scenarioDisplay = StringSubstr(scenarioDisplay, 0, 55) + "...";
   CreateLabel(m_prefix + "Scenario", scenarioDisplay, x, y, scenarioColor, fs, true);
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "Sep2", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 9, false);
   y += m_lineHeight + 1;
   
   // COMPONENTS + TREND
   if(m_trendManager != NULL)
   {
      string trendDir = m_trendManager.GetDirection();
      double trendStrength = m_trendManager.GetStrength();
      double trendConfidence = m_trendManager.GetTrendConfidence();
      int priority = m_trendManager.GetCrossoverPriority();
      string scenario = m_trendManager.GetCrossoverScenarioName();
      string arrow = (trendDir == "BULLISH") ? "▲" : (trendDir == "BEARISH") ? "▼" : "●";
      int trendColor = GetTrendColor(trendDir);
      
      string trendDisplay = "│ CROSSOVER: " + scenario + " (P" + IntegerToString(priority) + ") | " + arrow + " " + trendDir + " | Stren: " + DoubleToString(trendStrength, 1) + "%";
      CreateLabel(m_prefix + "Trend", trendDisplay, x, y, trendColor, fsSmall, false);
      y += m_lineHeight;
   }
   
   // Component lines
   string pbArrow = compResult.pb.direction;
   if(pbArrow == "") pbArrow = "●";
   string line1 = pbArrow + StringFormat("%.2f", compResult.pb.weight) + "PB:" + StringFormat("%.0f%%", compResult.pb.score) + "●";
   
   string mtfArrow = compResult.mtf.direction;
   if(mtfArrow == "") mtfArrow = "●";
   line1 += " | " + mtfArrow + StringFormat("%.2f", compResult.mtf.weight) + "MTF:" + StringFormat("%.0f%%", compResult.mtf.confidence) + "●";
   
   string macdArrow = compResult.macd.direction;
   if(macdArrow == "") macdArrow = "●";
   line1 += " | " + macdArrow + StringFormat("%.2f", compResult.macd.weight) + "MACD:" + StringFormat("%.0f%%", compResult.macd.confidence) + "●";
   
   string line2 = "";
   string adxArrow = compResult.adx.direction;
   if(adxArrow == "") adxArrow = "●";
   line2 += adxArrow + StringFormat("%.2f", compResult.adx.weight) + "ADX:" + StringFormat("%.0f%%", compResult.adx.confidence) + "●";
   
   string rsiArrow = compResult.rsi.direction;
   if(rsiArrow == "") rsiArrow = "●";
   line2 += " | " + rsiArrow + StringFormat("%.2f", compResult.rsi.weight) + "RSI:" + StringFormat("%.0f%%", compResult.rsi.confidence) + "●";
   
   string volArrow = compResult.vol.direction;
   if(volArrow == "") volArrow = "●";
   line2 += " | " + volArrow + StringFormat("%.2f", compResult.vol.weight) + "VOL:" + StringFormat("%.0f%%", compResult.vol.confidence) + "●";
   
   CreateLabel(m_prefix + "Components1", "│   " + line1, x + 2, y, clrLightGray, fsSmall, false);
   y += m_lineHeight;
   CreateLabel(m_prefix + "Components2", "│   " + line2, x + 2, y, clrLightGray, fsSmall, false);
   y += m_lineHeight;
   
   // AGGREGATED SECTION
   int aggColor = GetComponentColor(compResult.direction);
   string aggLine1 = "│   " + compResult.direction + " | Base Conf: " + DoubleToString(compResult.confidence, 1) + "% | Active: " + IntegerToString(compResult.activeComponents) + "/6 | Agree: " + IntegerToString(compResult.agreeingComponents) + " | Disagree: " + IntegerToString(compResult.disagreeingComponents);
   CreateLabel(m_prefix + "Agg1", aggLine1, x + 2, y, aggColor, fsSmall, false);
   y += m_lineHeight;
   
   // THRESHOLD DISPLAY
   double finalConf = componentData.finalConfidence;
   double boost = componentData.portfolioBoost;
   double threshold = 70.0;
   if(m_componentManager != NULL)
   {
      if(compResult.direction == "BULLISH")
         threshold = m_componentManager.GetBuyThreshold();
      else if(compResult.direction == "BEARISH")
         threshold = m_componentManager.GetSellThreshold();
   }
   
   string boostDisplay = "";
   if(boost != 0)
   {
      string boostEmoji = GetBoostEmoji(boost);
      string boostSign = (boost > 0) ? "+" : "";
      boostDisplay = boostEmoji + " " + boostSign + DoubleToString(boost, 1) + "%";
   }
   else
      boostDisplay = "✅ 0.0%";
   
   string thresholdLine = "│   Final Conf: " + DoubleToString(finalConf, 1) + "% " + (finalConf >= threshold ? "✅" : "⏳") + " | Boost: " + boostDisplay + " | Threshold: " + compResult.direction + " " + DoubleToString(threshold, 0) + "% " + (finalConf >= threshold ? "✅ CONFIRMED" : "⏳ WAITING");
   CreateLabel(m_prefix + "Threshold", thresholdLine, x + 2, y, finalConf >= threshold ? clrLimeGreen : clrYellow, fsSmall, false);
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "Sep3", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 9, false);
   y += m_lineHeight + 1;
   
   // ═══ PROGRESS SECTION (8 STEPS) ═══
   string statusText = GetOverallStatus();
   int statusColor = GetOverallColor();
   string statusDisplay = "│ " + statusText;
   if(StringLen(statusDisplay) > 55) statusDisplay = StringSubstr(statusDisplay, 0, 55);
   CreateLabel(m_prefix + "ProgressStatus", statusDisplay, x, y, statusColor, fs, true);
   y += m_lineHeight;
   
   DrawProgressChecks(x, y);
   y += 6;
   
   CreateLabel(m_prefix + "Sep4", "├──────────────────────────────────────────────────────┤", x, y, clrGray, 9, false);
   y += m_lineHeight + 1;
   
   // TRADE SECTION
   // CreateLabel(m_prefix + "TradeHeader", "│ TRADE:", x, y, clrWhite, fs, true);
   y += m_lineHeight;
   
   if(trade.signal != 0)
   {
      int dirColor = trade.signal == 1 ? clrLimeGreen : clrRed;
      string dirSymbol = trade.signal == 1 ? "▲ BUY" : "▼ SELL";
      
      bool isOpenPosition = (trade.entryPrice > 0 && trade.stopLoss > 0);
      string statusText2 = isOpenPosition ? "📊 OPEN" : "📈 SIGNAL";
      string lotText = "LOT: " + DoubleToString(m_lotSize, 2);
      string rrText = "R:R: " + DoubleToString(trade.riskRewardRatio, 2);
      
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
      
      string slText = "SL: " + (trade.stopLoss > 0 ? DoubleToString(trade.stopLoss, _Digits) : "N/A");
      string tpText = "TP: " + (trade.takeProfit > 0 ? DoubleToString(trade.takeProfit, _Digits) : "N/A");
      
      string tradeLine = "│ " + statusText2 + " " + dirSymbol + "│ " + lotText + "│ " + rrText + "│ Profit: " + profitText;
      CreateLabel(m_prefix + "TradeDir", tradeLine, x, y, dirColor, fs, false);
      y += m_lineHeight;
      
      string sltpLine = "│   " + slText + " | " + tpText;
      CreateLabel(m_prefix + "TradeSLTP", sltpLine, x + 2, y, clrGray, fsSmall, false);
      y += m_lineHeight;
   }
   else
   {
      string tradeLine = "│ ● HOLDING / NO POSITION │ LOT: 0.00 │ R:R: 0.00 │ Profit: 0.0 pips";
      CreateLabel(m_prefix + "TradeHold", tradeLine, x, y, clrGray, fs, false);
      y += m_lineHeight;
   }
   y += m_lineHeight + 1;
   
   CreateLabel(m_prefix + "BottomLine", "└──────────────────────────────────────────────────────┘", x, y, clrGray, 9, false);
   
   LOG_DEBUG("✅ Dashboard update complete (v4.1 - Shows detailed risk blocking reasons)", g_dashboardDebugMode);
}