//+------------------------------------------------------------------+
//|                    NarrativeEngine.mqh                           |
//|                    v2.0 - LOGIC ONLY!                           |
//|                    All content moved to NarrativeContent.mqh    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.0"

#include "NarrativeDataExtractor.mqh"
#include "NarrativeContent.mqh"

//+------------------------------------------------------------------+
//| Scenario Types                                                   |
//+------------------------------------------------------------------+
enum ENUM_SCENARIO_TYPE
{
   SCENARIO_STRONG_TREND,
   SCENARIO_PULLBACK_ENTRY,
   SCENARIO_DIVERGENCE,
   SCENARIO_BREAKOUT,
   SCENARIO_CONFLICT,
   SCENARIO_CONSOLIDATION,
   SCENARIO_REVERSAL,
   SCENARIO_EXTREME_CAUTION
};

//+------------------------------------------------------------------+
//| Scenario Structure                                              |
//+------------------------------------------------------------------+
struct SScenario
{
   ENUM_SCENARIO_TYPE type;
   string name;
   string description;
   string tradeAction;
   double confidence;
   string riskLevel;
   string timeHorizon;
   string narrative;
   string keyEvidence[10];
   string warnings[5];
   int evidenceCount;
   int warningCount;
   datetime timestamp;
   string symbol;
};

//+------------------------------------------------------------------+
//| Narrative Engine Class - Logic Only!                            |
//+------------------------------------------------------------------+
class CNarrativeEngine
{
private:
   CNarrativeDataExtractor* m_extractor;
   SComponentSnapshot m_snapshot;
   bool m_hasData;
   string m_symbol;
   bool m_debugEnabled;
   bool m_quickMode;
   
   // Scenario detection methods - ALL LOGIC, NO CONTENT!
   bool DetectStrongTrend(SScenario &scenario);
   bool DetectPullbackEntry(SScenario &scenario);
   bool DetectDivergence(SScenario &scenario);
   bool DetectBreakout(SScenario &scenario);
   bool DetectConflict(SScenario &scenario);
   bool DetectConsolidation(SScenario &scenario);
   bool DetectReversal(SScenario &scenario);
   bool DetectExtremeCaution(SScenario &scenario);
   
   // Helper methods - pure logic
   string GetRiskLevel(ENUM_SCENARIO_TYPE type);
   string GetTimeHorizon(ENUM_SCENARIO_TYPE type);
   string GetConfidenceLevel(double confidence);
   void AddEvidence(string &array[], int &count, string evidence, int maxSize);
   void AddWarning(string &array[], int &count, string warning, int maxSize);
   string BuildEvidenceString();
   string BuildWarningsString();
   
public:
   CNarrativeEngine(CComponentManager* manager, string symbol = NULL);
   ~CNarrativeEngine();
   
   bool Initialize();
   void EnableDebug(bool enable) { m_debugEnabled = enable; }
   void SetQuickMode(bool quick) { m_quickMode = quick; }
   void Refresh() { m_hasData = false; }
   
   // Main analysis methods
   SScenario AnalyzeScenario();
   string GenerateNarrative();
   void PrintScenario(SScenario &scenario);
   string GetQuickSummary();
   
   // Individual scenario getters (for testing)
   SScenario GetStrongTrendScenario();
   SScenario GetPullbackEntryScenario();
   SScenario GetDivergenceScenario();
   SScenario GetBreakoutScenario();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNarrativeEngine::CNarrativeEngine(CComponentManager* manager, string symbol)
{
   m_extractor = new CNarrativeDataExtractor(manager);
   m_hasData = false;
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_debugEnabled = false;
   m_quickMode = false;
   ZeroMemory(m_snapshot);
   
   if(m_extractor != NULL)
      m_extractor.EnableDebug(m_debugEnabled);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNarrativeEngine::~CNarrativeEngine()
{
   if(m_extractor != NULL)
   {
      delete m_extractor;
      m_extractor = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CNarrativeEngine::Initialize()
{
   Print("═══════════════════════════════════════════════════");
   Print("📊 NARRATIVE ENGINE v2.0 INITIALIZED");
   Print("═══════════════════════════════════════════════════");
   Print("Symbol: ", m_symbol);
   Print("Mode: ", m_quickMode ? "QUICK" : "FULL");
   Print("Narratives loaded from NarrativeContent.mqh");
   Print("Logic: Pure algorithmic detection");
   Print("═══════════════════════════════════════════════════");
   return true;
}

//+------------------------------------------------------------------+
//| Analyze Scenario - Main Entry Point                             |
//+------------------------------------------------------------------+
SScenario CNarrativeEngine::AnalyzeScenario()
{
   if(m_debugEnabled) Print("🔍 Analyzing scenarios... (logic only)");
   
   // Get fresh data
   if(!m_hasData)
   {
      if(!m_extractor.ExtractData(m_snapshot))
      {
         if(m_debugEnabled) Print("❌ Failed to extract data");
         SScenario empty;
         ZeroMemory(empty);
         empty.name = "NO DATA";
         empty.description = "Unable to extract data from components";
         empty.narrative = "Unable to analyze market - component data not available.";
         return empty;
      }
      m_hasData = true;
   }
   else
   {
      m_snapshot = m_extractor.GetLatestSnapshot();
   }
   
   SScenario bestScenario;
   ZeroMemory(bestScenario);
   bestScenario.timestamp = TimeCurrent();
   bestScenario.symbol = m_symbol;
   
   // Check all scenarios and collect them
   SScenario scenarios[8];
   int scenarioCount = 0;
   
   if(DetectStrongTrend(scenarios[scenarioCount])) scenarioCount++;
   if(DetectPullbackEntry(scenarios[scenarioCount])) scenarioCount++;
   if(DetectDivergence(scenarios[scenarioCount])) scenarioCount++;
   if(DetectBreakout(scenarios[scenarioCount])) scenarioCount++;
   if(DetectConflict(scenarios[scenarioCount])) scenarioCount++;
   if(DetectConsolidation(scenarios[scenarioCount])) scenarioCount++;
   if(DetectReversal(scenarios[scenarioCount])) scenarioCount++;
   if(DetectExtremeCaution(scenarios[scenarioCount])) scenarioCount++;
   
   if(m_debugEnabled)
   {
      Print("📊 Scenarios detected: ", scenarioCount);
   }
   
   // If no scenario detected, return consolidation as default
   if(scenarioCount == 0)
   {
      bestScenario.type = SCENARIO_CONSOLIDATION;
      bestScenario.name = "Market Consolidation";
      bestScenario.description = "No clear scenario detected - market in consolidation";
      bestScenario.confidence = 30;
      bestScenario.riskLevel = "LOW";
      bestScenario.timeHorizon = "SHORT";
      bestScenario.tradeAction = "WAIT";
      
      AddEvidence(bestScenario.keyEvidence, bestScenario.evidenceCount, 
                  "Mixed signals from components", 10);
      AddWarning(bestScenario.warnings, bestScenario.warningCount,
                 "No clear direction", 5);
      
      // Generate narrative from content
      bestScenario.narrative = GetNarrative(bestScenario.type,
                                           m_snapshot.trendDirection,
                                           bestScenario.tradeAction,
                                           bestScenario.confidence,
                                           m_snapshot.pbZone,
                                           m_snapshot.pbPercent,
                                           m_snapshot.rsiZone,
                                           m_snapshot.rsiValue,
                                           m_snapshot.adxStrength,
                                           m_snapshot.adxValue,
                                           m_snapshot.volStatus,
                                           m_snapshot.volRatio,
                                           m_snapshot.macdSignal,
                                           m_snapshot.agreeingComponents,
                                           m_snapshot.disagreeingComponents,
                                           m_snapshot.neutralComponents,
                                           m_snapshot.activeComponents,
                                           bestScenario.riskLevel,
                                           m_quickMode);
      
      return bestScenario;
   }
   
   // Choose scenario with highest confidence
   bestScenario = scenarios[0];
   for(int i = 1; i < scenarioCount; i++)
   {
      if(scenarios[i].confidence > bestScenario.confidence)
      {
         bestScenario = scenarios[i];
      }
   }
   
   // Generate the narrative from content file
   bestScenario.narrative = GetNarrative(bestScenario.type,
                                        m_snapshot.trendDirection,
                                        bestScenario.tradeAction,
                                        bestScenario.confidence,
                                        m_snapshot.pbZone,
                                        m_snapshot.pbPercent,
                                        m_snapshot.rsiZone,
                                        m_snapshot.rsiValue,
                                        m_snapshot.adxStrength,
                                        m_snapshot.adxValue,
                                        m_snapshot.volStatus,
                                        m_snapshot.volRatio,
                                        m_snapshot.macdSignal,
                                        m_snapshot.agreeingComponents,
                                        m_snapshot.disagreeingComponents,
                                        m_snapshot.neutralComponents,
                                        m_snapshot.activeComponents,
                                        bestScenario.riskLevel,
                                        m_quickMode);
   
   if(m_debugEnabled)
   {
      Print("✅ Selected scenario: ", bestScenario.name);
      Print("   Confidence: ", DoubleToString(bestScenario.confidence, 1), "%");
      Print("   Action: ", bestScenario.tradeAction);
   }
   
   return bestScenario;
}

//+------------------------------------------------------------------+
//| Generate Narrative - Returns formatted full narrative            |
//+------------------------------------------------------------------+
string CNarrativeEngine::GenerateNarrative()
{
   SScenario scenario = AnalyzeScenario();
   
   string output = "\n";
   output += "═══════════════════════════════════════════════════\n";
   output += "📊 NARRATIVE ENGINE v2.0 - MARKET STORY\n";
   output += "═══════════════════════════════════════════════════\n";
   output += "Symbol: " + scenario.symbol + "\n";
   output += "Time: " + TimeToString(scenario.timestamp) + "\n";
   output += "───────────────────────────────────────────────────\n";
   output += scenario.narrative + "\n";
   output += "───────────────────────────────────────────────────\n";
   
   if(scenario.evidenceCount > 0)
   {
      output += "📌 EVIDENCE:\n";
      for(int i = 0; i < scenario.evidenceCount; i++)
      {
         output += "  ✓ " + scenario.keyEvidence[i] + "\n";
      }
   }
   
   if(scenario.warningCount > 0)
   {
      output += "\n⚠️ WARNINGS:\n";
      for(int i = 0; i < scenario.warningCount; i++)
      {
         output += "  ⚠ " + scenario.warnings[i] + "\n";
      }
   }
   
   output += "───────────────────────────────────────────────────\n";
   output += StringFormat("📊 Confidence: %.1f%%", scenario.confidence) + "\n";
   output += StringFormat("🎯 Action: %s", scenario.tradeAction) + "\n";
   output += StringFormat("⚠️ Risk Level: %s", scenario.riskLevel) + "\n";
   output += StringFormat("⏰ Time Horizon: %s", scenario.timeHorizon) + "\n";
   output += "═══════════════════════════════════════════════════\n";
   
   return output;
}

//+------------------------------------------------------------------+
//| Print Scenario                                                   |
//+------------------------------------------------------------------+
void CNarrativeEngine::PrintScenario(SScenario &scenario)
{
   Print(GenerateNarrative());
}

//+------------------------------------------------------------------+
//| Get Quick Summary                                                |
//+------------------------------------------------------------------+
string CNarrativeEngine::GetQuickSummary()
{
   SScenario scenario = AnalyzeScenario();
   return StringFormat("[%s] %s | Conf:%.0f%% | Risk:%s | %s",
                       scenario.name,
                       scenario.tradeAction,
                       scenario.confidence,
                       scenario.riskLevel,
                       scenario.timeHorizon);
}

//+------------------------------------------------------------------+
//| SCENARIO DETECTION - PURE LOGIC!                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Strong Trend                                              |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectStrongTrend(SScenario &scenario)
{
   // Conditions for strong trend
   if(m_snapshot.trendDirection == "NEUTRAL") return false;
   if(m_snapshot.overallConfidence < 60) return false;
   if(m_snapshot.agreeingComponents < 4) return false;
   if(m_snapshot.adxStrength == "NO TREND" || m_snapshot.adxStrength == "WEAK") return false;
   
   scenario.type = SCENARIO_STRONG_TREND;
   scenario.name = StringFormat("Strong %s Trend", m_snapshot.trendDirection);
   scenario.description = StringFormat("Strong %s trend confirmed by multiple components",
                                       m_snapshot.trendDirection);
   scenario.confidence = m_snapshot.overallConfidence;
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = m_snapshot.tradeAction;
   
   // Build evidence (for display)
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Trend direction: %s", m_snapshot.trendDirection), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Overall confidence: %.1f%%", m_snapshot.overallConfidence), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Agreeing components: %d/6", m_snapshot.agreeingComponents), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("ADX strength: %s (%.1f)", m_snapshot.adxStrength, m_snapshot.adxValue), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Volume: %s", m_snapshot.volStatus), 10);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Pullback Entry                                            |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectPullbackEntry(SScenario &scenario)
{
   // Conditions for pullback entry
   if(m_snapshot.trendDirection == "NEUTRAL") return false;
   if(m_snapshot.pbZone != "PULLBACK" && m_snapshot.pbZone != "SWING") return false;
   if(m_snapshot.pbConfidence < 50) return false;
   if(m_snapshot.overallConfidence < 50) return false;
   if(m_snapshot.agreeingComponents < 3) return false;
   
   scenario.type = SCENARIO_PULLBACK_ENTRY;
   scenario.name = StringFormat("Pullback Entry - %s Zone", m_snapshot.pbZone);
   scenario.description = StringFormat("%s pullback offers entry opportunity in %s trend",
                                       m_snapshot.pbZone, m_snapshot.trendDirection);
   scenario.confidence = MathMax(m_snapshot.pbConfidence, m_snapshot.overallConfidence);
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = m_snapshot.tradeAction;
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Trend: %s", m_snapshot.trendDirection), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("PB Zone: %s (%.1f%% pullback)", m_snapshot.pbZone, m_snapshot.pbPercent), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("PB Confidence: %.1f%%", m_snapshot.pbConfidence), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Total confidence: %.1f%%", m_snapshot.overallConfidence), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Agreeing components: %d/6", m_snapshot.agreeingComponents), 10);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Divergence                                                |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectDivergence(SScenario &scenario)
{
   if(m_snapshot.trendDirection == "NEUTRAL") return false;
   
   // Check for RSI divergence
   bool rsiDisagrees = (m_snapshot.trendDirection == "BULLISH" && 
                        (m_snapshot.rsiZone == "OVERBOUGHT" || m_snapshot.rsiZone == "EXTREME OVERBOUGHT")) ||
                       (m_snapshot.trendDirection == "BEARISH" && 
                        (m_snapshot.rsiZone == "OVERSOLD" || m_snapshot.rsiZone == "EXTREME OVERSOLD"));
   
   // Check for MACD divergence
   bool macdDisagrees = (m_snapshot.trendDirection == "BULLISH" && 
                         (m_snapshot.macdDirection == "BEARISH" || m_snapshot.macdDirection == "NEUTRAL")) ||
                        (m_snapshot.trendDirection == "BEARISH" && 
                         (m_snapshot.macdDirection == "BULLISH" || m_snapshot.macdDirection == "NEUTRAL"));
   
   if(!rsiDisagrees && !macdDisagrees) return false;
   
   scenario.type = SCENARIO_DIVERGENCE;
   scenario.name = "Divergence Detected";
   scenario.description = "Potential reversal setup - indicators disagreeing with price";
   scenario.confidence = 50 + (m_snapshot.overallConfidence * 0.3);
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = "CAUTION - Monitor for reversal";
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Trend: %s", m_snapshot.trendDirection), 10);
   if(rsiDisagrees)
      AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
                  StringFormat("RSI in %s zone (%.1f) - potential exhaustion", 
                               m_snapshot.rsiZone, m_snapshot.rsiValue), 10);
   if(macdDisagrees)
      AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
                  StringFormat("MACD %s vs trend", m_snapshot.macdDirection), 10);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Divergence may indicate trend reversal", 5);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Wait for confirmation before trading", 5);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Breakout                                                  |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectBreakout(SScenario &scenario)
{
   // Conditions for breakout
   if(m_snapshot.volStatus != "SURGING" && m_snapshot.volStatus != "ABOVE AVERAGE" && m_snapshot.volStatus != "EXPLOSIVE")
      return false;
   if(m_snapshot.adxStrength == "NO TREND" || m_snapshot.adxStrength == "WEAK")
      return false;
   if(m_snapshot.overallConfidence < 60) return false;
   if(m_snapshot.trendDirection == "NEUTRAL") return false;
   
   scenario.type = SCENARIO_BREAKOUT;
   scenario.name = StringFormat("%s Breakout", m_snapshot.trendDirection);
   scenario.description = StringFormat("Strong %s breakout with volume confirmation",
                                       m_snapshot.trendDirection);
   scenario.confidence = m_snapshot.overallConfidence;
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = m_snapshot.tradeAction;
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Breakout direction: %s", m_snapshot.trendDirection), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Volume: %s (%.2fx average)", m_snapshot.volStatus, m_snapshot.volRatio), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("ADX: %s (%.1f)", m_snapshot.adxStrength, m_snapshot.adxValue), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Confidence: %.1f%%", m_snapshot.overallConfidence), 10);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Conflict                                                  |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectConflict(SScenario &scenario)
{
   if(m_snapshot.disagreeingComponents < 2 && m_snapshot.neutralComponents < 2)
      return false;
   if(m_snapshot.trendDirection == "NEUTRAL") return false;
   
   scenario.type = SCENARIO_CONFLICT;
   scenario.name = "Component Conflict";
   scenario.description = "Mixed signals from components - caution advised";
   scenario.confidence = 30;
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = "WAIT - No clear signal";
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Disagreeing: %d", m_snapshot.disagreeingComponents), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Neutral: %d", m_snapshot.neutralComponents), 10);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Mixed signals - wait for resolution", 5);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Risk of false signals", 5);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Consolidation                                             |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectConsolidation(SScenario &scenario)
{
   // Conditions for consolidation
   if(m_snapshot.adxStrength != "NO TREND" && m_snapshot.adxStrength != "WEAK")
      return false;
   if(m_snapshot.overallConfidence > 50) return false;
   if(m_snapshot.pbZone != "TRANSITION" && m_snapshot.pbZone != "TRANSITION EDGE")
      return false;
   
   scenario.type = SCENARIO_CONSOLIDATION;
   scenario.name = "Market Consolidation";
   scenario.description = "Market in consolidation - waiting for direction";
   scenario.confidence = 20;
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = "WAIT - No clear setup";
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("ADX: %s (%.1f)", m_snapshot.adxStrength, m_snapshot.adxValue), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Confidence: %.1f%%", m_snapshot.overallConfidence), 10);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Wait for breakout or breakdown", 5);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Reversal                                                  |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectReversal(SScenario &scenario)
{
   // Conditions for reversal
   if(m_snapshot.rsiZone != "OVERBOUGHT" && m_snapshot.rsiZone != "EXTREME OVERBOUGHT" && 
      m_snapshot.rsiZone != "OVERSOLD" && m_snapshot.rsiZone != "EXTREME OVERSOLD")
      return false;
   if(m_snapshot.adxStrength != "EXTREME STRONG" && m_snapshot.adxStrength != "STRONG")
      return false;
   if(m_snapshot.overallConfidence < 50) return false;
   
   scenario.type = SCENARIO_REVERSAL;
   scenario.name = StringFormat("Potential Reversal from %s", m_snapshot.rsiZone);
   scenario.description = StringFormat("Potential trend reversal from %s conditions",
                                       m_snapshot.rsiZone);
   scenario.confidence = 45 + (m_snapshot.overallConfidence * 0.3);
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = "CAUTION - Monitor for reversal";
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("RSI: %s (%.1f)", m_snapshot.rsiZone, m_snapshot.rsiValue), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("ADX: %s (%.1f)", m_snapshot.adxStrength, m_snapshot.adxValue), 10);
   AddWarning(scenario.warnings, scenario.warningCount,
              "High risk - wait for confirmation", 5);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Consider reducing position size", 5);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Extreme Caution                                           |
//+------------------------------------------------------------------+
bool CNarrativeEngine::DetectExtremeCaution(SScenario &scenario)
{
   if(m_snapshot.pbZone != "EXTREME") return false;
   if(m_snapshot.overallConfidence > 60) return false;
   
   scenario.type = SCENARIO_EXTREME_CAUTION;
   scenario.name = "Extreme Caution Required";
   scenario.description = "Market showing extreme conditions - high risk";
   scenario.confidence = 10;
   scenario.riskLevel = GetRiskLevel(scenario.type);
   scenario.timeHorizon = GetTimeHorizon(scenario.type);
   scenario.tradeAction = "NO TRADE - Extreme conditions";
   
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("PB Zone: EXTREME (%.1f%% pullback)", m_snapshot.pbPercent), 10);
   AddEvidence(scenario.keyEvidence, scenario.evidenceCount,
               StringFormat("Confidence: %.1f%%", m_snapshot.overallConfidence), 10);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Extreme conditions - stay out", 5);
   AddWarning(scenario.warnings, scenario.warningCount,
              "Wait for normal conditions", 5);
   
   return true;
}

//+------------------------------------------------------------------+
//| HELPER METHODS - Pure Logic                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Risk Level                                                   |
//+------------------------------------------------------------------+
string CNarrativeEngine::GetRiskLevel(ENUM_SCENARIO_TYPE type)
{
   switch(type)
   {
      case SCENARIO_STRONG_TREND:      return "LOW";
      case SCENARIO_PULLBACK_ENTRY:    return "MEDIUM";
      case SCENARIO_BREAKOUT:          return "MEDIUM";
      case SCENARIO_CONSOLIDATION:     return "LOW";
      case SCENARIO_DIVERGENCE:        return "HIGH";
      case SCENARIO_CONFLICT:          return "HIGH";
      case SCENARIO_REVERSAL:          return "EXTREME";
      case SCENARIO_EXTREME_CAUTION:   return "EXTREME";
      default:                         return "MEDIUM";
   }
}

//+------------------------------------------------------------------+
//| Get Time Horizon                                                 |
//+------------------------------------------------------------------+
string CNarrativeEngine::GetTimeHorizon(ENUM_SCENARIO_TYPE type)
{
   switch(type)
   {
      case SCENARIO_STRONG_TREND:      return "MEDIUM";
      case SCENARIO_PULLBACK_ENTRY:    return "SHORT";
      case SCENARIO_BREAKOUT:          return "MEDIUM";
      case SCENARIO_CONSOLIDATION:     return "SHORT";
      case SCENARIO_DIVERGENCE:        return "SHORT";
      case SCENARIO_CONFLICT:          return "SHORT";
      case SCENARIO_REVERSAL:          return "SHORT";
      case SCENARIO_EXTREME_CAUTION:   return "SHORT";
      default:                         return "SHORT";
   }
}

//+------------------------------------------------------------------+
//| Get Confidence Level                                             |
//+------------------------------------------------------------------+
string CNarrativeEngine::GetConfidenceLevel(double confidence)
{
   if(confidence >= 80) return "VERY HIGH";
   else if(confidence >= 70) return "HIGH";
   else if(confidence >= 60) return "MODERATE";
   else if(confidence >= 50) return "LOW";
   else return "VERY LOW";
}

//+------------------------------------------------------------------+
//| Add Evidence                                                     |
//+------------------------------------------------------------------+
void CNarrativeEngine::AddEvidence(string &array[], int &count, string evidence, int maxSize)
{
   if(count < maxSize)
   {
      array[count] = evidence;
      count++;
   }
}

//+------------------------------------------------------------------+
//| Add Warning                                                      |
//+------------------------------------------------------------------+
void CNarrativeEngine::AddWarning(string &array[], int &count, string warning, int maxSize)
{
   if(count < maxSize)
   {
      array[count] = warning;
      count++;
   }
}

//+------------------------------------------------------------------+
//| Individual Scenario Getters (for testing/analysis)               |
//+------------------------------------------------------------------+
SScenario CNarrativeEngine::GetStrongTrendScenario()
{
   SScenario scenario;
   ZeroMemory(scenario);
   DetectStrongTrend(scenario);
   return scenario;
}

SScenario CNarrativeEngine::GetPullbackEntryScenario()
{
   SScenario scenario;
   ZeroMemory(scenario);
   DetectPullbackEntry(scenario);
   return scenario;
}

SScenario CNarrativeEngine::GetDivergenceScenario()
{
   SScenario scenario;
   ZeroMemory(scenario);
   DetectDivergence(scenario);
   return scenario;
}

SScenario CNarrativeEngine::GetBreakoutScenario()
{
   SScenario scenario;
   ZeroMemory(scenario);
   DetectBreakout(scenario);
   return scenario;
}