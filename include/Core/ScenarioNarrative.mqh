//+------------------------------------------------------------------+
//|                        ScenarioNarrative.mqh                     |
//|                    Enhanced Scenario Narrative Engine            |
//|                    v2.2 - FIXED COMPILATION ERRORS              |
//|                    Prompts all components for narratives        |
//|                    Synthesizes into plausible scenarios         |
//|                    Returns formatted for Dashboard              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.2"

#include "../Headers/Enums.mqh"
#include "../Headers/Structures.mqh"
#include "../Utils/Logger.mqh"
#include "../Data/AdxModule.mqh"

// Forward declaration for ADX module
class CAdxModule;

//+------------------------------------------------------------------+
//| Component Narrative Result Structure                             |
//+------------------------------------------------------------------+
struct SComponentNarrative
{
   string   componentName;      // "PB", "MTF", "MACD", "ADX", "RSI", "VOL"
   string   direction;          // "BULLISH", "BEARISH", "NEUTRAL"
   string   narrative;          // Component-specific narrative
   string   shortNarrative;     // Short version for display
   double   confidence;         // Component confidence
   string   strength;           // "STRONG", "MODERATE", "WEAK"
   string   emoji;              // Component emoji
   bool     isActive;           // Whether component is active
   string   alignment;          // "AGREE", "DISAGREE", "NEUTRAL"
};

//+------------------------------------------------------------------+
//| Synthesized Scenario Result                                      |
//+------------------------------------------------------------------+
struct SSynthesizedScenario
{
   string   scenarioName;       // Name of the scenario
   string   scenarioEmoji;      // Emoji for the scenario
   color    scenarioColor;      // Color for display
   double   confidence;         // Overall confidence
   string   direction;          // "BULLISH", "BEARISH", "NEUTRAL"
   string   description;        // Brief description
   string   narrative;          // Full synthesized narrative
   string   shortNarrative;     // Short version
   string   action;             // Recommended action
   string   riskLevel;          // Risk level
   SComponentNarrative componentNarratives[6]; // All component narratives
   int      componentCount;     // Number of active components
   int      agreeingCount;      // Number agreeing
   int      disagreeingCount;   // Number disagreeing
   string   marketState;        // "TRENDING", "RANGING", "BREAKING OUT", "CONSOLIDATING"
   string   momentum;           // "STRONG", "MODERATE", "WEAK", "NONE"
   string   warning;            // Any warnings
   bool     isValid;
};

//+------------------------------------------------------------------+
//| Scenario Narrative Class                                        |
//+------------------------------------------------------------------+
class ScenarioNarrative
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   bool     m_debug;
   bool     m_initialized;
   string   m_lastError;
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_cacheTimeout;      // Cache timeout in seconds (default: 10)
   
   // ──────────────────────────────────────────────────────────────
   // CACHE
   // ──────────────────────────────────────────────────────────────
   bool     m_cacheValid;
   datetime m_cacheTime;
   SSynthesizedScenario m_cachedScenario;
   SComponentData m_cachedData;
   string   m_cachedDirection;
   
   // ──────────────────────────────────────────────────────────────
   // SCENARIO ARRAYS
   // ──────────────────────────────────────────────────────────────
   string   m_scenarioNames[];
   string   m_scenarioDescriptions[];
   string   m_scenarioConditions[];
   string   m_scenarioActions[];
   string   m_scenarioRiskLevels[];
   string   m_scenarioNarratives[];
   string   m_scenarioShortNarratives[];
   string   m_scenarioEmojis[];
   color    m_scenarioColors[];
   
   // ──────────────────────────────────────────────────────────────
   // MODULE REFERENCES (for ADX)
   // ──────────────────────────────────────────────────────────────
   CAdxModule* m_adxModule;
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   void     InitializeArrays();
   string   GetStrengthLabel(double confidence);
   string   GetMomentumLabel(double value);
   string   GetMarketStateLabel(double adx, double volRatio);
   string   SynthesizeNarrative(SSynthesizedScenario &scenario);
   string   GenerateWarning(SComponentData &data);
   
   // ──────────────────────────────────────────────────────────────
   // CACHE METHODS
   // ──────────────────────────────────────────────────────────────
   void     InvalidateCache();
   bool     IsCacheValid(string direction);
   void     UpdateCache(string direction, SSynthesizedScenario &scenario, SComponentData &data);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   ScenarioNarrative(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   ~ScenarioNarrative();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize();
   bool IsInitialized() const { return m_initialized; }
   string GetLastError() const { return m_lastError; }
   void SetAdxModule(CAdxModule* adxModule);
   
   // ──────────────────────────────────────────────────────────────
   // CONFIGURATION
   // ──────────────────────────────────────────────────────────────
   void SetCacheTimeout(int seconds);
   void SetDebug(bool enable);
   bool GetDebug() const { return m_debug; }
   void Refresh();
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT NARRATIVE GENERATION - PROMPTS EACH COMPONENT
   // ──────────────────────────────────────────────────────────────
   SComponentNarrative GeneratePBNarrative(SComponentData &data);
   SComponentNarrative GenerateMTFNarrative(SComponentData &data);
   SComponentNarrative GenerateMACDNarrative(SComponentData &data);
   SComponentNarrative GenerateADXNarrative(SComponentData &data);
   SComponentNarrative GenerateRSINarrative(SComponentData &data);
   SComponentNarrative GenerateVolNarrative(SComponentData &data);
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT NARRATIVE COLLECTION - GETS ALL NARRATIVES
   // ──────────────────────────────────────────────────────────────
   void GetAllComponentNarratives(SComponentData &data, SComponentNarrative &narratives[]);
   
   // ──────────────────────────────────────────────────────────────
   // SCENARIO SYNTHESIS - COMBINES ALL NARRATIVES
   // ──────────────────────────────────────────────────────────────
   SSynthesizedScenario SynthesizeScenario(SComponentData &data);
   SSynthesizedScenario SynthesizeScenarioWithNarratives(SComponentData &data, SComponentNarrative &narratives[]);
   
   // ──────────────────────────────────────────────────────────────
   // SCENARIO ATTRIBUTE GETTERS
   // ──────────────────────────────────────────────────────────────
   string GetScenarioName(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioDescription(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioConditions(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioAction(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioRiskLevel(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioNarrative(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioShortNarrative(ENUM_MARKET_SCENARIO scenario);
   string GetScenarioEmoji(ENUM_MARKET_SCENARIO scenario);
   color  GetScenarioColor(ENUM_MARKET_SCENARIO scenario);
   
   // ──────────────────────────────────────────────────────────────
   // SCENARIO DETECTION
   // ──────────────────────────────────────────────────────────────
   ScenarioResult DetectScenario(SComponentData &data);
   
   // ──────────────────────────────────────────────────────────────
   // OUTPUT GENERATION
   // ──────────────────────────────────────────────────────────────
   string GenerateFullNarrative(SSynthesizedScenario &scenario);
   string GenerateDashboardText(SSynthesizedScenario &scenario);
   string GenerateComponentSummaryTable(SComponentNarrative &narratives[], int count);
   string GenerateQuickStatus(SSynthesizedScenario &scenario);
   string GetCachedScenarioString();
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY
   // ──────────────────────────────────────────────────────────────
   void PrintStatus();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
ScenarioNarrative::ScenarioNarrative(string symbol, ENUM_TIMEFRAMES tf)
{
   LOG("ScenarioNarrative Constructor called", true);
   
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? PERIOD_H1 : tf;
   m_debug = false;
   m_initialized = false;
   m_lastError = "";
   m_cacheTimeout = 10;
   m_adxModule = NULL;
   
   InvalidateCache();
   InitializeArrays();
   
   string msg = "ScenarioNarrative created - Symbol: ";
   msg += m_symbol;
   msg += ", Timeframe: ";
   msg += EnumToString(m_timeframe);
   msg += ", Cache Timeout: ";
   msg += IntegerToString(m_cacheTimeout);
   msg += "s";
   LOG(msg, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
ScenarioNarrative::~ScenarioNarrative()
{
   LOG("ScenarioNarrative Destructor called", true);
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool ScenarioNarrative::Initialize()
{
   LOG("=== SCENARIO NARRATIVE INITIALIZATION START ===", true);
   m_initialized = true;
   InvalidateCache();
   LOG("✅ Scenario Narrative initialized successfully", true);
   LOG("=== SCENARIO NARRATIVE INITIALIZATION COMPLETE ===", true);
   return true;
}

//+------------------------------------------------------------------+
//| Set Adx Module                                                  |
//+------------------------------------------------------------------+
void ScenarioNarrative::SetAdxModule(CAdxModule* adxModule)
{
   m_adxModule = adxModule;
   if(m_adxModule != NULL)
      LOG("ADX Module reference set", m_debug);
   else
      LOG("ADX Module reference set to NULL", m_debug);
}

//+------------------------------------------------------------------+
//| Set Cache Timeout                                               |
//+------------------------------------------------------------------+
void ScenarioNarrative::SetCacheTimeout(int seconds)
{
   if(seconds > 0)
   {
      m_cacheTimeout = seconds;
      string msg = "Cache timeout set to ";
      msg += IntegerToString(seconds);
      msg += " seconds";
      LOG(msg, true);
      InvalidateCache();
   }
}

//+------------------------------------------------------------------+
//| Set Debug                                                       |
//+------------------------------------------------------------------+
void ScenarioNarrative::SetDebug(bool enable)
{
   string msg = "Setting debug mode to: ";
   msg += (enable ? "ON" : "OFF");
   LOG(msg, true);
   m_debug = enable;
}

//+------------------------------------------------------------------+
//| Refresh - Force cache invalidation                              |
//+------------------------------------------------------------------+
void ScenarioNarrative::Refresh()
{
   LOG("Refreshing Scenario Narrative (cache invalidated)", m_debug);
   InvalidateCache();
}

//+------------------------------------------------------------------+
//| Invalidate Cache                                                |
//+------------------------------------------------------------------+
void ScenarioNarrative::InvalidateCache()
{
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cachedDirection = "";
   ZeroMemory(m_cachedScenario);
   ZeroMemory(m_cachedData);
   LOG("Cache invalidated", m_debug);
}

//+------------------------------------------------------------------+
//| Is Cache Valid                                                  |
//+------------------------------------------------------------------+
bool ScenarioNarrative::IsCacheValid(string direction)
{
   if(!m_cacheValid) return false;
   if((TimeCurrent() - m_cacheTime) > m_cacheTimeout) return false;
   if(m_cachedDirection != direction) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Update Cache                                                    |
//+------------------------------------------------------------------+
void ScenarioNarrative::UpdateCache(string direction, SSynthesizedScenario &scenario, SComponentData &data)
{
   m_cachedScenario = scenario;
   m_cachedData = data;
   m_cachedDirection = direction;
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
   LOG("Cache updated (age: 0s)", m_debug);
}

//+------------------------------------------------------------------+
//| Get Cached Scenario String                                      |
//+------------------------------------------------------------------+
string ScenarioNarrative::GetCachedScenarioString()
{
   if(!m_cacheValid)
      return "No cached scenario";
   
   string result = "Cached: ";
   result += m_cachedScenario.scenarioName;
   result += " | Conf: ";
   result += DoubleToString(m_cachedScenario.confidence, 1);
   result += "% | Age: ";
   result += IntegerToString((int)(TimeCurrent() - m_cacheTime));
   result += "s";
   return result;
}

//+------------------------------------------------------------------+
//| Initialize Scenario Arrays                                      |
//+------------------------------------------------------------------+
void ScenarioNarrative::InitializeArrays()
{
   LOG("Initializing scenario arrays...", m_debug);
   
   int size = 10;
   ArrayResize(m_scenarioNames, size);
   ArrayResize(m_scenarioDescriptions, size);
   ArrayResize(m_scenarioConditions, size);
   ArrayResize(m_scenarioActions, size);
   ArrayResize(m_scenarioRiskLevels, size);
   ArrayResize(m_scenarioNarratives, size);
   ArrayResize(m_scenarioShortNarratives, size);
   ArrayResize(m_scenarioEmojis, size);
   ArrayResize(m_scenarioColors, size);
   
   // ============================================================
   // SCENARIO 0: UNKNOWN
   // ============================================================
   m_scenarioNames[0] = "UNKNOWN";
   m_scenarioDescriptions[0] = "Mixed signals. No clear scenario identified.";
   m_scenarioConditions[0] = "Components not meeting any defined scenario criteria";
   m_scenarioActions[0] = "Wait for clearer conditions";
   m_scenarioRiskLevels[0] = "NO TRADE";
   m_scenarioNarratives[0] = "Market conditions are unclear. Multiple indicators are giving conflicting signals. The safest approach is to wait for a clearer picture to emerge before considering any positions.";
   m_scenarioShortNarratives[0] = "❓ UNKNOWN - Wait";
   m_scenarioEmojis[0] = "❓";
   m_scenarioColors[0] = clrGray;
   
   // ============================================================
   // SCENARIO 1: FULL ALIGNMENT
   // ============================================================
   m_scenarioNames[1] = "FULL ALIGNMENT";
   m_scenarioDescriptions[1] = "Full alignment. Strong trend. Momentum and participation expanding.";
   m_scenarioConditions[1] = "MTF aligned | MACD expanding | RSI 55-70 (or 30-45) | ADX >25 | Pullback shallow | Volume increasing";
   m_scenarioActions[1] = "Enter trend";
   m_scenarioRiskLevels[1] = "FULL RISK";
   m_scenarioNarratives[1] = 
      "=== IDEAL ENTRY CONDITIONS ===\n"
      "All indicators are in perfect alignment:\n"
      "• Multi-timeframe analysis shows bullish/bearish agreement across M5, M15, and M30\n"
      "• MACD is expanding in the direction of the trend, confirming momentum\n"
      "• RSI is in the ideal zone (55-70 for bulls, 30-45 for bears) - not overbought/oversold\n"
      "• ADX above 25 confirms a strong trending market\n"
      "• Pullback is shallow (55-65% retracement) - price is respecting the trend\n"
      "• Volume is increasing, confirming participation\n\n"
      "RECOMMENDED ACTION: Enter with full position size. All conditions favor a continuation of the established trend.";
   m_scenarioShortNarratives[1] = "🚀 FULL ALIGNMENT - Enter";
   m_scenarioEmojis[1] = "🚀";
   m_scenarioColors[1] = clrLimeGreen;
   
   // ============================================================
   // SCENARIO 2: TREND CONTINUATION
   // ============================================================
   m_scenarioNames[2] = "TREND CONTINUATION";
   m_scenarioDescriptions[2] = "Trend intact. Pullback complete. Momentum returning with participation.";
   m_scenarioConditions[2] = "M5/M15 aligned | MACD re-cross | RSI bounce from 40-50 (or 50-60) | ADX 20-30 | Pullback respected | Volume rising";
   m_scenarioActions[2] = "Enter continuation";
   m_scenarioRiskLevels[2] = "FULL RISK";
   m_scenarioNarratives[2] = 
      "=== PULLBACK COMPLETE - CONTINUATION ===\n"
      "The trend has paused for a healthy pullback and is now resuming:\n"
      "• M5 and M15 are aligned with the trend, while M30 is re-aligning\n"
      "• MACD has re-crossed in the trend direction after pulling back\n"
      "• RSI has bounced from the 40-50 zone (bullish) or 50-60 zone (bearish)\n"
      "• ADX between 20-30 confirms a stable trending market\n"
      "• Pullback has respected key structure levels (40-80% retracement)\n"
      "• Volume is rising as price resumes the trend\n\n"
      "RECOMMENDED ACTION: Enter continuation with full risk. This is a classic pullback-entry setup.";
   m_scenarioShortNarratives[2] = "📈 CONTINUATION - Enter";
   m_scenarioEmojis[2] = "📈";
   m_scenarioColors[2] = clrGreen;
   
   // ============================================================
   // SCENARIO 3: EARLY TREND FORMING
   // ============================================================
   m_scenarioNames[3] = "EARLY TREND FORMING";
   m_scenarioDescriptions[3] = "Early trend forming. Lower TF leads. Momentum building, not confirmed.";
   m_scenarioConditions[3] = "M5 aligned, M15 partial | MACD fresh cross | RSI crossing 50 | ADX 15-22 | Volume picking up";
   m_scenarioActions[3] = "Enter small";
   m_scenarioRiskLevels[3] = "REDUCED RISK";
   m_scenarioNarratives[3] = 
      "=== EARLY TREND DEVELOPMENT ===\n"
      "A new trend is attempting to form at the lower timeframe:\n"
      "• M5 is aligned with the emerging direction, M15 is showing partial alignment\n"
      "• MACD has just crossed in the potential trend direction\n"
      "• RSI is crossing the 50 level, indicating momentum shift\n"
      "• ADX between 15-22 suggests a trend is beginning to develop\n"
      "• Volume is starting to pick up, confirming interest\n\n"
      "RECOMMENDED ACTION: Enter with reduced position size. The trend is not yet confirmed at higher timeframes.";
   m_scenarioShortNarratives[3] = "🌱 EARLY TREND - Small";
   m_scenarioEmojis[3] = "🌱";
   m_scenarioColors[3] = clrYellowGreen;
   
   // ============================================================
   // SCENARIO 4: STRONG TREND EXHAUSTION
   // ============================================================
   m_scenarioNames[4] = "STRONG TREND EXHAUSTION";
   m_scenarioDescriptions[4] = "Strong trend. Momentum extended. Signs of exhaustion emerging.";
   m_scenarioConditions[4] = "MTF aligned but stretched | MACD high/flattening | RSI >70 or <30 | ADX >35 | No meaningful pullbacks | Volume spike";
   m_scenarioActions[4] = "Avoid entries / manage positions";
   m_scenarioRiskLevels[4] = "AVOID";
   m_scenarioNarratives[4] = 
      "=== TREND EXHAUSTION WARNING ===\n"
      "The trend is extremely extended and showing signs of exhaustion:\n"
      "• MTF alignment is stretched - price is far above/below moving averages\n"
      "• MACD is high but flattening - momentum is no longer accelerating\n"
      "• RSI is in extreme territory (>70 or <30) - overbought/oversold\n"
      "• ADX above 35 confirms very strong trend, but this is often a sign of exhaustion\n"
      "• No meaningful pullbacks - price is moving without pauses\n"
      "• Volume spike suggests climax - potentially the final push\n\n"
      "RECOMMENDED ACTION: Avoid new entries. Consider managing existing positions.";
   m_scenarioShortNarratives[4] = "⚠️ EXHAUSTION - Avoid";
   m_scenarioEmojis[4] = "⚠️";
   m_scenarioColors[4] = clrOrange;
   
   // ============================================================
   // SCENARIO 5: TREND WEAKENING
   // ============================================================
   m_scenarioNames[5] = "TREND WEAKENING";
   m_scenarioDescriptions[5] = "Trend weakening. Momentum fading. Participation declining.";
   m_scenarioConditions[5] = "MTF still aligned but softening | MACD contracting | RSI drifting to 50 | ADX falling | Pullbacks deeper | Volume declining";
   m_scenarioActions[5] = "Reduce exposure / no new entries";
   m_scenarioRiskLevels[5] = "REDUCE";
   m_scenarioNarratives[5] = 
      "=== TREND WEAKENING - REDUCE EXPOSURE ===\n"
      "The trend is losing strength and momentum is fading:\n"
      "• MTF alignment is still present but softening - price is approaching moving averages\n"
      "• MACD is contracting - momentum is decreasing\n"
      "• RSI is drifting toward 50 - neutral zone\n"
      "• ADX is falling - trend strength is decreasing\n"
      "• Pullbacks are becoming deeper - sellers/buyers are stepping in\n"
      "• Volume is declining - participation is waning\n\n"
      "RECOMMENDED ACTION: Reduce exposure. Do not add new positions.";
   m_scenarioShortNarratives[5] = "📉 WEAKENING - Reduce";
   m_scenarioEmojis[5] = "📉";
   m_scenarioColors[5] = clrOrangeRed;
   
   // ============================================================
   // SCENARIO 6: MTF CONFLICT
   // ============================================================
   m_scenarioNames[6] = "MTF CONFLICT";
   m_scenarioDescriptions[6] = "MTF conflict. Momentum mixed. No clear control.";
   m_scenarioConditions[6] = "MTF misaligned | MACD crossing frequently | RSI ~50 | ADX <20 | Volume inconsistent";
   m_scenarioActions[6] = "Stay out";
   m_scenarioRiskLevels[6] = "NO TRADE";
   m_scenarioNarratives[6] = 
      "=== MTF CONFLICT - STAY OUT ===\n"
      "Timeframes are conflicting and there is no clear direction:\n"
      "• MTF is misaligned - M5 and M30 are moving in opposite directions\n"
      "• MACD is crossing frequently - no clear momentum direction\n"
      "• RSI is around 50 - neutral, no directional bias\n"
      "• ADX below 20 - no trend present\n"
      "• Volume is inconsistent - no clear participation\n\n"
      "RECOMMENDED ACTION: Stay out. This is a chop zone where the market is indecisive.";
   m_scenarioShortNarratives[6] = "🔀 MTF CONFLICT - Stay Out";
   m_scenarioEmojis[6] = "🔀";
   m_scenarioColors[6] = clrGray;
   
   // ============================================================
   // SCENARIO 7: RANGE CONDITIONS
   // ============================================================
   m_scenarioNames[7] = "RANGE CONDITIONS";
   m_scenarioDescriptions[7] = "Range conditions. Low momentum. Weak participation.";
   m_scenarioConditions[7] = "MTF flat | MACD flat | RSI 45-55 oscillation | ADX <15 | Small range | Low volume";
   m_scenarioActions[7] = "Avoid / mean reversion only";
   m_scenarioRiskLevels[7] = "AVOID";
   m_scenarioNarratives[7] = 
      "=== RANGE BOUND MARKET ===\n"
      "The market is in a tight range with no clear direction:\n"
      "• MTF is flat - no trend across timeframes\n"
      "• MACD is flat - no momentum\n"
      "• RSI oscillating 45-55 - no directional bias\n"
      "• ADX below 15 - very weak or no trend\n"
      "• Price range is small (<30 pips) - low volatility\n"
      "• Volume is low - weak participation\n\n"
      "RECOMMENDED ACTION: Avoid trend-following strategies. This is a range-bound environment.";
   m_scenarioShortNarratives[7] = "⬜ RANGE - Avoid";
   m_scenarioEmojis[7] = "⬜";
   m_scenarioColors[7] = clrGray;
   
   // ============================================================
   // SCENARIO 8: PULLBACK - PREPARE FOR CONTINUATION
   // ============================================================
   m_scenarioNames[8] = "PULLBACK - PREPARE";
   m_scenarioDescriptions[8] = "Pullback against trend. Higher TF still dominant. Momentum cooling.";
   m_scenarioConditions[8] = "M5/M15 aligned, M30 neutral | MACD retracing | RSI cooling from extremes | ADX >20 | Pullback orderly | Volume declining";
   m_scenarioActions[8] = "Prepare for continuation";
   m_scenarioRiskLevels[8] = "WAIT";
   m_scenarioNarratives[8] = 
      "=== PULLBACK IN PROGRESS ===\n"
      "Price is pulling back against the dominant higher timeframe trend:\n"
      "• M5 and M15 are aligned with the trend, M30 is neutral/counter\n"
      "• MACD is retracing (reducing in the trend direction) - not flipped yet\n"
      "• RSI is cooling from extremes - moving back toward neutral\n"
      "• ADX above 20 confirms the higher timeframe trend is still intact\n"
      "• Pullback is orderly (45-75% retracement) - respecting structure\n"
      "• Volume is declining - this is a healthy retracement\n\n"
      "RECOMMENDED ACTION: Prepare for continuation. Do not enter yet - wait for the pullback to complete.";
   m_scenarioShortNarratives[8] = "⏳ PULLBACK - Prepare";
   m_scenarioEmojis[8] = "⏳";
   m_scenarioColors[8] = clrYellow;
   
   // ============================================================
   // SCENARIO 9: SLOW GRIND TREND
   // ============================================================
   m_scenarioNames[9] = "SLOW GRIND TREND";
   m_scenarioDescriptions[9] = "Slow grind trend. Low volatility. Consistent direction.";
   m_scenarioConditions[9] = "MTF aligned | MACD steady (not explosive) | RSI stable trend zone | ADX 20-25 | Small pullbacks | Stable volume";
   m_scenarioActions[9] = "Enter cautiously";
   m_scenarioRiskLevels[9] = "REDUCED RISK";
   m_scenarioNarratives[9] = 
      "=== SLOW GRIND TREND ===\n"
      "A steady, low-volatility trend is in progress:\n"
      "• MTF aligned - all timeframes agree on direction\n"
      "• MACD is steady - not explosive, just consistent\n"
      "• RSI is in the stable trend zone (50-60 for bulls, 40-50 for bears)\n"
      "• ADX between 20-25 - moderate trend strength\n"
      "• Small pullbacks (45-75%) - healthy corrections\n"
      "• Volume is stable - consistent participation\n\n"
      "RECOMMENDED ACTION: Enter cautiously with reduced risk. This is a low-volatility environment.";
   m_scenarioShortNarratives[9] = "🐢 SLOW GRIND - Cautious";
   m_scenarioEmojis[9] = "🐢";
   m_scenarioColors[9] = clrYellow;
   
   LOG("Scenario arrays initialized: " + IntegerToString(size) + " scenarios", m_debug);
}

//+------------------------------------------------------------------+
//| GET STRENGTH LABEL                                              |
//+------------------------------------------------------------------+
string ScenarioNarrative::GetStrengthLabel(double confidence)
{
   if(confidence >= 70) return "STRONG";
   else if(confidence >= 50) return "MODERATE";
   else if(confidence >= 30) return "WEAK";
   else return "VERY WEAK";
}

//+------------------------------------------------------------------+
//| GET MOMENTUM LABEL                                              |
//+------------------------------------------------------------------+
string ScenarioNarrative::GetMomentumLabel(double value)
{
   if(value >= 0.5) return "STRONG";
   else if(value >= 0.2) return "MODERATE";
   else if(value >= 0.05) return "WEAK";
   else return "NONE";
}

//+------------------------------------------------------------------+
//| GET MARKET STATE LABEL                                          |
//+------------------------------------------------------------------+
string ScenarioNarrative::GetMarketStateLabel(double adx, double volRatio)
{
   if(adx >= 25 && volRatio >= 1.0) return "TRENDING";
   else if(adx >= 20 && volRatio >= 0.8) return "TRENDING";
   else if(adx >= 15) return "CONSOLIDATING";
   else if(volRatio >= 1.5) return "BREAKING OUT";
   else return "RANGING";
}

//+------------------------------------------------------------------+
//| GENERATE WARNING                                                |
//+------------------------------------------------------------------+
string ScenarioNarrative::GenerateWarning(SComponentData &data)
{
   string warnings = "";
   
   if(data.rsiValue >= 70)
      warnings += "⚠️ RSI OVERBOUGHT - potential reversal; ";
   else if(data.rsiValue <= 30)
      warnings += "⚠️ RSI OVERSOLD - potential bounce; ";
   
   if(data.adxValue >= 40)
      warnings += "⚠️ ADX VERY STRONG - possible exhaustion; ";
   else if(data.adxValue < 15)
      warnings += "⚠️ ADX VERY WEAK - no trend; ";
   
   if(data.volRatio >= 2.0)
      warnings += "⚠️ VOLUME SURGE - climax possible; ";
   else if(data.volRatio <= 0.5)
      warnings += "⚠️ VOLUME DRYING - low participation; ";
   
   if(data.mtfTotalScore < 15)
      warnings += "⚠️ MTF CONFLICT - timeframes disagree; ";
   else if(data.mtfTotalScore >= 35 && data.volRatio < 0.8)
      warnings += "⚠️ STRONG ALIGNMENT but LOW VOLUME - weak conviction; ";
   
   if(warnings == "")
      warnings = "✅ No major warnings";
   else
   {
      // Remove trailing "; " manually - FIXED: no Substring
      int len = StringLen(warnings);
      if(len > 2)
         warnings = StringSubstr(warnings, 0, len - 2);
   }
   
   return warnings;
}

//+------------------------------------------------------------------+
//| GENERATE PB NARRATIVE                                           |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GeneratePBNarrative(SComponentData &data)
{
   LOG("Generating PB Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "PB";
   result.direction = data.finalDirection;
   result.confidence = data.pbConfidence;
   result.isActive = (data.pbConfidence >= 30);
   result.alignment = "AGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   
   if(data.pbConfidence >= 70 && data.pbAdjustedPercent >= 55 && data.pbAdjustedPercent <= 65)
   {
      emoji = "✅";
      narrative = "PERFECT PULLBACK: Price has retraced ";
      narrative += DoubleToString(data.pbAdjustedPercent, 0);
      narrative += "% which is the ideal zone (55-65%). This suggests a healthy correction where buyers/sellers are stepping in at logical levels. The structure is clean and the trend is respected.";
      shortNarrative = "Perfect pullback at " + DoubleToString(data.pbAdjustedPercent, 0) + "%";
   }
   else if(data.pbConfidence >= 50 && data.pbAdjustedPercent >= 45 && data.pbAdjustedPercent <= 75)
   {
      emoji = "⭐";
      narrative = "GOOD PULLBACK: Price has retraced ";
      narrative += DoubleToString(data.pbAdjustedPercent, 0);
      narrative += "% which is within the acceptable range (45-75%). The pullback structure is reasonable and the trend remains intact. This is a valid entry zone.";
      shortNarrative = "Good pullback at " + DoubleToString(data.pbAdjustedPercent, 0) + "%";
   }
   else if(data.pbConfidence >= 30 && data.pbAdjustedPercent >= 30 && data.pbAdjustedPercent <= 85)
   {
      emoji = "⚡";
      narrative = "ACCEPTABLE PULLBACK: Price has retraced ";
      narrative += DoubleToString(data.pbAdjustedPercent, 0);
      narrative += "% which is marginal but still acceptable. The pullback is deeper than ideal, suggesting some weakness in the trend. Exercise caution.";
      shortNarrative = "Acceptable pullback at " + DoubleToString(data.pbAdjustedPercent, 0) + "%";
   }
   else
   {
      emoji = "🔴";
      narrative = "POOR PULLBACK: Price has retraced ";
      narrative += DoubleToString(data.pbAdjustedPercent, 0);
      narrative += "% which is outside ideal ranges. This suggests the pullback may be too deep (potential trend reversal) or too shallow (no room for entries). Avoid entering here.";
      shortNarrative = "Poor pullback at " + DoubleToString(data.pbAdjustedPercent, 0) + "%";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.pbConfidence);
   
   LOG("  PB: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GENERATE MTF NARRATIVE                                          |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GenerateMTFNarrative(SComponentData &data)
{
   LOG("Generating MTF Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "MTF";
   result.direction = data.finalDirection;
   result.confidence = data.mtfConfidence;
   result.isActive = (data.mtfTotalScore >= 20);
   result.alignment = (data.mtfConfidence >= 50) ? "AGREE" : "DISAGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   
   if(data.mtfConfidence >= 70 && data.mtfTotalScore >= 35)
   {
      emoji = "✅";
      narrative = "STRONG MTF ALIGNMENT: All timeframes (M5, M15, H1) are aligned with the trend. Score: ";
      narrative += IntegerToString(data.mtfTotalScore);
      narrative += "/45. This provides strong confirmation that the trend is valid across all timeframes. High conviction entry.";
      shortNarrative = "Strong MTF alignment (" + IntegerToString(data.mtfTotalScore) + "/45)";
   }
   else if(data.mtfConfidence >= 50 && data.mtfTotalScore >= 25)
   {
      emoji = "⭐";
      narrative = "GOOD MTF ALIGNMENT: Most timeframes are aligned with the trend. Score: ";
      narrative += IntegerToString(data.mtfTotalScore);
      narrative += "/45. There is reasonable agreement across timeframes, though some divergence exists at higher levels. Good for entry.";
      shortNarrative = "Good MTF alignment (" + IntegerToString(data.mtfTotalScore) + "/45)";
   }
   else if(data.mtfConfidence >= 30 && data.mtfTotalScore >= 15)
   {
      emoji = "⚡";
      narrative = "PARTIAL MTF ALIGNMENT: Some timeframes agree, others conflict. Score: ";
      narrative += IntegerToString(data.mtfTotalScore);
      narrative += "/45. The lower timeframes may be leading but higher timeframes are not yet confirming. Use reduced position size.";
      shortNarrative = "Partial MTF alignment (" + IntegerToString(data.mtfTotalScore) + "/45)";
   }
   else
   {
      emoji = "🔴";
      narrative = "MTF CONFLICT: Timeframes are in disagreement. Score: ";
      narrative += IntegerToString(data.mtfTotalScore);
      narrative += "/45. This suggests a chop zone or potential reversal. Avoid entering until timeframes realign.";
      shortNarrative = "MTF conflict (" + IntegerToString(data.mtfTotalScore) + "/45)";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.mtfConfidence);
   
   LOG("  MTF: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GENERATE MACD NARRATIVE                                         |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GenerateMACDNarrative(SComponentData &data)
{
   LOG("Generating MACD Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "MACD";
   result.confidence = data.macdConfidence;
   result.isActive = (MathAbs(data.macdHistogram) > 0.05);
   
   string dir = (data.macdHistogram > 0) ? "BULLISH" : "BEARISH";
   result.direction = dir;
   result.alignment = (dir == data.finalDirection) ? "AGREE" : "DISAGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   double histAbs = MathAbs(data.macdHistogram);
   
   if(data.macdConfidence >= 70 && histAbs > 0.5)
   {
      emoji = "✅";
      narrative = "STRONG MACD MOMENTUM: MACD is ";
      narrative += (data.macdHistogram > 0) ? "bullish " : "bearish ";
      narrative += "with histogram at ";
      narrative += DoubleToString(histAbs, 3);
      narrative += ". The histogram is widening, confirming accelerating momentum in the trend direction. Strong conviction signal.";
      shortNarrative = "Strong " + dir + " momentum (hist: " + DoubleToString(histAbs, 3) + ")";
   }
   else if(data.macdConfidence >= 50 && histAbs > 0.2)
   {
      emoji = "⭐";
      narrative = "POSITIVE MACD MOMENTUM: MACD is ";
      narrative += (data.macdHistogram > 0) ? "bullish " : "bearish ";
      narrative += "with histogram at ";
      narrative += DoubleToString(histAbs, 3);
      narrative += ". Momentum is building but not yet at full strength. Good for entry with confirmation.";
      shortNarrative = dir + " momentum building (hist: " + DoubleToString(histAbs, 3) + ")";
   }
   else if(data.macdConfidence >= 30 && histAbs > 0.05)
   {
      emoji = "⚡";
      narrative = "WEAK MACD MOMENTUM: MACD is ";
      narrative += (data.macdHistogram > 0) ? "bullish " : "bearish ";
      narrative += "but histogram is small (";
      narrative += DoubleToString(histAbs, 3);
      narrative += "). This suggests weak momentum that could fade quickly. Use reduced position size.";
      shortNarrative = "Weak " + dir + " momentum";
   }
   else
   {
      emoji = "🔴";
      narrative = "NO MACD MOMENTUM: MACD is near the signal line with histogram at ";
      narrative += DoubleToString(histAbs, 3);
      narrative += ". This indicates a lack of clear momentum. The market may be consolidating or reversing.";
      shortNarrative = "No momentum (hist: " + DoubleToString(histAbs, 3) + ")";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.macdConfidence);
   
   LOG("  MACD: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GENERATE ADX NARRATIVE - FIXED                                   |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GenerateADXNarrative(SComponentData &data)
{
   LOG("Generating ADX Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "ADX";
   result.confidence = data.adxConfidence;
   result.isActive = (data.adxValue >= 20);
   
   // Get ADX direction
   string adxDir = "NEUTRAL";
   if(m_adxModule != NULL)
   {
      // Use the ADX module's GetDirectionResult method
      SADXDirectionResult adxResult = m_adxModule.GetDirectionResult();
      adxDir = adxResult.direction;
   }
   else
   {
      // Fallback: use data direction
      adxDir = data.finalDirection;
      LOG("  ADX Module not set, using data direction: " + adxDir, m_debug);
   }
   
   result.direction = adxDir;
   result.alignment = (adxDir == data.finalDirection) ? "AGREE" : "DISAGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   
   if(data.adxValue >= 40)
   {
      emoji = "✅";
      narrative = "VERY STRONG TREND: ADX is ";
      narrative += DoubleToString(data.adxValue, 1);
      narrative += " which indicates a very strong trend. The trend is well-established with high conviction. However, be aware of potential exhaustion at these extreme levels.";
      shortNarrative = "Very strong trend (ADX: " + DoubleToString(data.adxValue, 1) + ")";
   }
   else if(data.adxValue >= 25)
   {
      emoji = "⭐";
      narrative = "STRONG TREND: ADX is ";
      narrative += DoubleToString(data.adxValue, 1);
      narrative += " which confirms a strong, healthy trend. This is the ideal zone for trend-following entries with good risk-reward.";
      shortNarrative = "Strong trend (ADX: " + DoubleToString(data.adxValue, 1) + ")";
   }
   else if(data.adxValue >= 20)
   {
      emoji = "⚡";
      narrative = "MODERATE TREND: ADX is ";
      narrative += DoubleToString(data.adxValue, 1);
      narrative += " which indicates a developing trend. The trend is present but not yet strong. Use reduced position size and look for confirmation.";
      shortNarrative = "Moderate trend (ADX: " + DoubleToString(data.adxValue, 1) + ")";
   }
   else
   {
      emoji = "🔴";
      narrative = "WEAK/NO TREND: ADX is ";
      narrative += DoubleToString(data.adxValue, 1);
      narrative += " which is below the threshold for a trending market. This suggests a range-bound or consolidating market. Avoid trend-following strategies.";
      shortNarrative = "Weak/no trend (ADX: " + DoubleToString(data.adxValue, 1) + ")";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.adxConfidence);
   
   LOG("  ADX: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GENERATE RSI NARRATIVE                                          |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GenerateRSINarrative(SComponentData &data)
{
   LOG("Generating RSI Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "RSI";
   result.confidence = data.rsiConfidence;
   result.isActive = (data.rsiValue >= 40 && data.rsiValue <= 60) ||
                      data.rsiValue >= 70 || data.rsiValue <= 30;
   
   string dir = "";
   if(data.rsiValue >= 70) dir = "BEARISH";
   else if(data.rsiValue <= 30) dir = "BULLISH";
   else if(data.rsiValue >= 55) dir = "BULLISH";
   else if(data.rsiValue <= 45) dir = "BEARISH";
   else dir = "NEUTRAL";
   result.direction = dir;
   result.alignment = (dir == data.finalDirection) ? "AGREE" : "DISAGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   
   if(data.rsiValue >= 70)
   {
      emoji = "🔴";
      narrative = "RSI OVERBOUGHT at ";
      narrative += DoubleToString(data.rsiValue, 1);
      narrative += ". This indicates strong bullish momentum but also suggests the market may be overextended. Watch for potential reversal or pullback. Consider taking profits or tightening stops.";
      shortNarrative = "Overbought (" + DoubleToString(data.rsiValue, 1) + ")";
   }
   else if(data.rsiValue <= 30)
   {
      emoji = "🟢";
      narrative = "RSI OVERSOLD at ";
      narrative += DoubleToString(data.rsiValue, 1);
      narrative += ". This indicates strong bearish momentum but also suggests the market may be oversold. Watch for potential bounce or reversal. Consider buying the dip.";
      shortNarrative = "Oversold (" + DoubleToString(data.rsiValue, 1) + ")";
   }
   else if(data.rsiValue >= 55)
   {
      emoji = "📈";
      narrative = "RSI BULLISH at ";
      narrative += DoubleToString(data.rsiValue, 1);
      narrative += ". This is in the bullish zone (55-70) with room to run. Momentum is positive and not yet overextended. Good for bullish entries.";
      shortNarrative = "Bullish (" + DoubleToString(data.rsiValue, 1) + ")";
   }
   else if(data.rsiValue <= 45)
   {
      emoji = "📉";
      narrative = "RSI BEARISH at ";
      narrative += DoubleToString(data.rsiValue, 1);
      narrative += ". This is in the bearish zone (30-45) with room to run. Momentum is negative and not yet oversold. Good for bearish entries.";
      shortNarrative = "Bearish (" + DoubleToString(data.rsiValue, 1) + ")";
   }
   else
   {
      emoji = "➡️";
      narrative = "RSI NEUTRAL at ";
      narrative += DoubleToString(data.rsiValue, 1);
      narrative += ". This is in the neutral zone (45-55) indicating no clear momentum. The market is consolidating or indecisive. Wait for a clear direction.";
      shortNarrative = "Neutral (" + DoubleToString(data.rsiValue, 1) + ")";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.rsiConfidence);
   
   LOG("  RSI: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GENERATE VOLUME NARRATIVE                                       |
//+------------------------------------------------------------------+
SComponentNarrative ScenarioNarrative::GenerateVolNarrative(SComponentData &data)
{
   LOG("Generating Volume Narrative...", m_debug);
   
   SComponentNarrative result;
   ZeroMemory(result);
   result.componentName = "VOL";
   result.confidence = data.volConfidence;
   result.direction = data.finalDirection;
   result.isActive = (data.volRatio >= 0.5 && data.volConfidence >= 20);
   result.alignment = "AGREE";
   
   string emoji = "";
   string narrative = "";
   string shortNarrative = "";
   
   if(data.volRatio >= 2.0)
   {
      emoji = "🔥";
      narrative = "VOLUME SURGE at ";
      narrative += DoubleToString(data.volRatio, 1);
      narrative += "x average. This indicates EXTREME participation and conviction. Price moves with this volume are typically strong and sustained, but beware of climax moves.";
      shortNarrative = "Surge (" + DoubleToString(data.volRatio, 1) + "x)";
   }
   else if(data.volRatio >= 1.5)
   {
      emoji = "⬆️";
      narrative = "ELEVATED VOLUME at ";
      narrative += DoubleToString(data.volRatio, 1);
      narrative += "x average. This shows strong participation and conviction in the move. Healthy volume confirms the trend.";
      shortNarrative = "Elevated (" + DoubleToString(data.volRatio, 1) + "x)";
   }
   else if(data.volRatio >= 0.8)
   {
      emoji = "➡️";
      narrative = "NORMAL VOLUME at ";
      narrative += DoubleToString(data.volRatio, 1);
      narrative += "x average. This is typical market participation. The move has average conviction - neither strong nor weak.";
      shortNarrative = "Normal (" + DoubleToString(data.volRatio, 1) + "x)";
   }
   else if(data.volRatio >= 0.5)
   {
      emoji = "⬇️";
      narrative = "DECLINING VOLUME at ";
      narrative += DoubleToString(data.volRatio, 1);
      narrative += "x average. This indicates decreasing participation. Price moves with low volume lack conviction - they may be false breakouts or lack sustainability.";
      shortNarrative = "Declining (" + DoubleToString(data.volRatio, 1) + "x)";
   }
   else
   {
      emoji = "❄️";
      narrative = "VOLUME DRYING at ";
      narrative += DoubleToString(data.volRatio, 1);
      narrative += "x average. This is extremely low participation. The market is in a lull - moves are likely to be false or lack follow-through. Avoid entering.";
      shortNarrative = "Drying (" + DoubleToString(data.volRatio, 1) + "x)";
   }
   
   result.emoji = emoji;
   result.narrative = narrative;
   result.shortNarrative = shortNarrative;
   result.strength = GetStrengthLabel(data.volConfidence);
   
   LOG("  VOL: " + shortNarrative, m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| GET ALL COMPONENT NARRATIVES                                   |
//+------------------------------------------------------------------+
void ScenarioNarrative::GetAllComponentNarratives(SComponentData &data, SComponentNarrative &narratives[])
{
   LOG("Collecting all component narratives...", m_debug);
   
   ArrayResize(narratives, 6);
   
   narratives[0] = GeneratePBNarrative(data);
   narratives[1] = GenerateMTFNarrative(data);
   narratives[2] = GenerateMACDNarrative(data);
   narratives[3] = GenerateADXNarrative(data);
   narratives[4] = GenerateRSINarrative(data);
   narratives[5] = GenerateVolNarrative(data);
   
   string msg = "  Collected ";
   msg += IntegerToString(ArraySize(narratives));
   msg += " component narratives";
   LOG(msg, m_debug);
}

//+------------------------------------------------------------------+
//| SYNTHESIZE SCENARIO                                             |
//+------------------------------------------------------------------+
SSynthesizedScenario ScenarioNarrative::SynthesizeScenario(SComponentData &data)
{
   LOG("=== SYNTHESIZING SCENARIO ===", m_debug);
   
   if(IsCacheValid(data.finalDirection))
   {
      LOG("✅ Using CACHED scenario (age: " + 
          IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s)", true);
      return m_cachedScenario;
   }
   
   LOG("Cache invalid or expired - recalculating...", m_debug);
   
   SComponentNarrative narratives[];
   GetAllComponentNarratives(data, narratives);
   
   SSynthesizedScenario result = SynthesizeScenarioWithNarratives(data, narratives);
   
   UpdateCache(data.finalDirection, result, data);
   
   LOG("=== SYNTHESIS COMPLETE ===", m_debug);
   return result;
}

//+------------------------------------------------------------------+
//| SYNTHESIZE SCENARIO WITH NARRATIVES                             |
//+------------------------------------------------------------------+
SSynthesizedScenario ScenarioNarrative::SynthesizeScenarioWithNarratives(SComponentData &data, SComponentNarrative &narratives[])
{
   LOG("Synthesizing scenario from " + IntegerToString(ArraySize(narratives)) + " component narratives...", m_debug);
   
   SSynthesizedScenario result;
   ZeroMemory(result);
   result.isValid = false;
   
   int count = MathMin(ArraySize(narratives), 6);
   result.componentCount = 0;
   result.agreeingCount = 0;
   result.disagreeingCount = 0;
   
   for(int i = 0; i < count; i++)
   {
      result.componentNarratives[i] = narratives[i];
      if(narratives[i].isActive)
      {
         result.componentCount++;
         if(narratives[i].alignment == "AGREE") result.agreeingCount++;
         else if(narratives[i].alignment == "DISAGREE") result.disagreeingCount++;
      }
   }
   
   LOG("  Component summary: Active=" + IntegerToString(result.componentCount) +
       ", Agree=" + IntegerToString(result.agreeingCount) +
       ", Disagree=" + IntegerToString(result.disagreeingCount), m_debug);
   
   result.direction = data.finalDirection;
   
   double totalConfidence = 0;
   int activeCount = 0;
   for(int i = 0; i < count; i++)
   {
      if(narratives[i].isActive)
      {
         totalConfidence += narratives[i].confidence;
         activeCount++;
      }
   }
   result.confidence = (activeCount > 0) ? totalConfidence / activeCount : 0;
   LOG("  Overall Confidence: " + DoubleToString(result.confidence, 1) + "%", m_debug);
   
   result.marketState = GetMarketStateLabel(data.adxValue, data.volRatio);
   result.momentum = GetMomentumLabel(MathAbs(data.macdHistogram));
   result.warning = GenerateWarning(data);
   
   ScenarioResult scenarioResult = DetectScenario(data);
   result.scenarioName = GetScenarioName(scenarioResult.scenario);
   result.scenarioEmoji = GetScenarioEmoji(scenarioResult.scenario);
   result.scenarioColor = GetScenarioColor(scenarioResult.scenario);
   result.description = scenarioResult.description;
   result.action = scenarioResult.action;
   result.riskLevel = scenarioResult.riskLevel;
   result.shortNarrative = scenarioResult.shortNarrative;
   
   result.narrative = SynthesizeNarrative(result);
   result.isValid = true;
   
   LOG("✅ Scenario synthesized: " + result.scenarioName, true);
   LOG("  Direction: " + result.direction + " | Confidence: " + 
       DoubleToString(result.confidence, 1) + "%", m_debug);
   
   return result;
}

//+------------------------------------------------------------------+
//| SYNTHESIZE NARRATIVE                                            |
//+------------------------------------------------------------------+
string ScenarioNarrative::SynthesizeNarrative(SSynthesizedScenario &scenario)
{
   LOG("Synthesizing full narrative...", m_debug);
   
   string output = "";
   
   output += "═══════════════════════════════════════════════════════════════════\n";
   output += "📊 MARKET SCENARIO: " + scenario.scenarioName + "\n";
   output += "   Direction: " + scenario.direction + " | Confidence: " + 
             DoubleToString(scenario.confidence, 1) + "%\n";
   output += "   Market State: " + scenario.marketState + " | Momentum: " + 
             scenario.momentum + "\n";
   output += "───────────────────────────────────────────────────────────────────\n";
   
   output += "📈 COMPONENT NARRATIVES:\n";
   for(int i = 0; i < scenario.componentCount && i < 6; i++)
   {
      SComponentNarrative comp = scenario.componentNarratives[i];
      if(comp.isActive)
      {
         output += "   " + comp.emoji + " " + comp.componentName + ": ";
         output += comp.shortNarrative + "\n";
      }
   }
   output += "───────────────────────────────────────────────────────────────────\n";
   
   output += "📋 SCENARIO DETAILS:\n";
   output += "   Description: " + scenario.description + "\n";
   output += "   Action: " + scenario.action + "\n";
   output += "   Risk: " + scenario.riskLevel + "\n";
   output += "───────────────────────────────────────────────────────────────────\n";
   
   if(scenario.warning != "✅ No major warnings")
   {
      output += "⚠️ WARNINGS:\n";
      output += "   " + scenario.warning + "\n";
      output += "───────────────────────────────────────────────────────────────────\n";
   }
   
   output += GetScenarioNarrative((ENUM_MARKET_SCENARIO)0) + "\n";
   output += "═══════════════════════════════════════════════════════════════════";
   
   LOG("Narrative synthesized (" + IntegerToString(StringLen(output)) + " chars)", m_debug);
   return output;
}

//+------------------------------------------------------------------+
//| SCENARIO DETECTION                                              |
//+------------------------------------------------------------------+
ScenarioResult ScenarioNarrative::DetectScenario(SComponentData &data)
{
   LOG("Detecting scenario...", m_debug);
   
   ScenarioResult result;
   ZeroMemory(result);
   
   result.scenario = SCENARIO_UNKNOWN;
   result.confidence = data.finalConfidence;
   result.displayColor = clrGray;
   result.displayEmoji = "❓";
   
   // Check for FULL ALIGNMENT
   if(data.mtfConfidence >= 70 && data.mtfTotalScore >= 35 &&
      data.macdConfidence >= 60 && MathAbs(data.macdHistogram) > 0.3 &&
      data.adxValue >= 25 &&
      data.rsiValue >= 55 && data.rsiValue <= 70 &&
      data.pbAdjustedPercent >= 55 && data.pbAdjustedPercent <= 65 &&
      data.volRatio >= 1.2 &&
      data.finalConfidence >= 50)
   {
      result.scenario = SCENARIO_FULL_ALIGNMENT;
      result.description = GetScenarioDescription(SCENARIO_FULL_ALIGNMENT);
      result.conditions = GetScenarioConditions(SCENARIO_FULL_ALIGNMENT);
      result.action = GetScenarioAction(SCENARIO_FULL_ALIGNMENT);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_FULL_ALIGNMENT);
      result.narrative = GetScenarioNarrative(SCENARIO_FULL_ALIGNMENT);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_FULL_ALIGNMENT);
      result.displayColor = GetScenarioColor(SCENARIO_FULL_ALIGNMENT);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_FULL_ALIGNMENT);
      result.confidence = MathMax(result.confidence, 70);
      LOG("  → FULL ALIGNMENT detected", m_debug);
      return result;
   }
   
   // Check for TREND CONTINUATION
   if(data.mtfConfidence >= 50 && data.mtfTotalScore >= 25 &&
      data.macdConfidence >= 50 &&
      data.adxValue >= 20 && data.adxValue <= 30 &&
      data.rsiValue >= 40 && data.rsiValue <= 60 &&
      data.pbAdjustedPercent >= 45 && data.pbAdjustedPercent <= 75 &&
      data.finalConfidence >= 40)
   {
      result.scenario = SCENARIO_TREND_CONTINUATION;
      result.description = GetScenarioDescription(SCENARIO_TREND_CONTINUATION);
      result.conditions = GetScenarioConditions(SCENARIO_TREND_CONTINUATION);
      result.action = GetScenarioAction(SCENARIO_TREND_CONTINUATION);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_TREND_CONTINUATION);
      result.narrative = GetScenarioNarrative(SCENARIO_TREND_CONTINUATION);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_TREND_CONTINUATION);
      result.displayColor = GetScenarioColor(SCENARIO_TREND_CONTINUATION);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_TREND_CONTINUATION);
      result.confidence = MathMax(result.confidence, 50);
      LOG("  → TREND CONTINUATION detected", m_debug);
      return result;
   }
   
   // Check for EARLY TREND
   if(data.mtfM5Score >= 12 && data.mtfConfidence >= 40 &&
      data.macdConfidence >= 40 && MathAbs(data.macdHistogram) > 0.1 &&
      data.adxValue >= 15 && data.adxValue <= 22 &&
      data.rsiValue >= 45 && data.rsiValue <= 55 &&
      data.finalConfidence >= 30)
   {
      result.scenario = SCENARIO_EARLY_TREND;
      result.description = GetScenarioDescription(SCENARIO_EARLY_TREND);
      result.conditions = GetScenarioConditions(SCENARIO_EARLY_TREND);
      result.action = GetScenarioAction(SCENARIO_EARLY_TREND);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_EARLY_TREND);
      result.narrative = GetScenarioNarrative(SCENARIO_EARLY_TREND);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_EARLY_TREND);
      result.displayColor = GetScenarioColor(SCENARIO_EARLY_TREND);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_EARLY_TREND);
      result.confidence = MathMax(result.confidence, 35);
      LOG("  → EARLY TREND detected", m_debug);
      return result;
   }
   
   // Check for TREND EXHAUSTION
   if(data.mtfConfidence >= 60 && data.mtfTotalScore >= 30 &&
      data.adxValue >= 35 &&
      (data.rsiValue >= 70 || data.rsiValue <= 30) &&
      data.volRatio >= 1.5 &&
      data.finalConfidence >= 40)
   {
      result.scenario = SCENARIO_STRONG_TREND_EXHAUSTION;
      result.description = GetScenarioDescription(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.conditions = GetScenarioConditions(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.action = GetScenarioAction(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.narrative = GetScenarioNarrative(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.displayColor = GetScenarioColor(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_STRONG_TREND_EXHAUSTION);
      result.confidence = MathMax(result.confidence, 45);
      LOG("  → TREND EXHAUSTION detected", m_debug);
      return result;
   }
   
   // Check for TREND WEAKENING
   if(data.mtfConfidence >= 40 && data.mtfTotalScore >= 20 &&
      data.macdConfidence < 50 &&
      data.adxValue >= 15 && data.adxValue <= 25 &&
      data.rsiValue >= 45 && data.rsiValue <= 55 &&
      data.finalConfidence >= 25)
   {
      result.scenario = SCENARIO_TREND_WEAKENING;
      result.description = GetScenarioDescription(SCENARIO_TREND_WEAKENING);
      result.conditions = GetScenarioConditions(SCENARIO_TREND_WEAKENING);
      result.action = GetScenarioAction(SCENARIO_TREND_WEAKENING);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_TREND_WEAKENING);
      result.narrative = GetScenarioNarrative(SCENARIO_TREND_WEAKENING);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_TREND_WEAKENING);
      result.displayColor = GetScenarioColor(SCENARIO_TREND_WEAKENING);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_TREND_WEAKENING);
      result.confidence = MathMax(result.confidence, 30);
      LOG("  → TREND WEAKENING detected", m_debug);
      return result;
   }
   
   // Check for MTF CONFLICT
   if(data.mtfTotalScore < 15 && data.mtfConfidence < 30 &&
      MathAbs(data.macdHistogram) < 0.1 &&
      data.adxValue < 20 &&
      data.rsiValue >= 45 && data.rsiValue <= 55 &&
      data.finalConfidence < 30)
   {
      result.scenario = SCENARIO_MTF_CONFLICT;
      result.description = GetScenarioDescription(SCENARIO_MTF_CONFLICT);
      result.conditions = GetScenarioConditions(SCENARIO_MTF_CONFLICT);
      result.action = GetScenarioAction(SCENARIO_MTF_CONFLICT);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_MTF_CONFLICT);
      result.narrative = GetScenarioNarrative(SCENARIO_MTF_CONFLICT);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_MTF_CONFLICT);
      result.displayColor = GetScenarioColor(SCENARIO_MTF_CONFLICT);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_MTF_CONFLICT);
      result.confidence = MathMax(result.confidence, 20);
      LOG("  → MTF CONFLICT detected", m_debug);
      return result;
   }
   
   // Check for RANGE CONDITIONS
   if(data.adxValue < 15 &&
      MathAbs(data.macdHistogram) < 0.1 &&
      data.rsiValue >= 45 && data.rsiValue <= 55 &&
      data.volRatio < 0.8 &&
      data.finalConfidence < 20)
   {
      result.scenario = SCENARIO_RANGE_CONDITIONS;
      result.description = GetScenarioDescription(SCENARIO_RANGE_CONDITIONS);
      result.conditions = GetScenarioConditions(SCENARIO_RANGE_CONDITIONS);
      result.action = GetScenarioAction(SCENARIO_RANGE_CONDITIONS);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_RANGE_CONDITIONS);
      result.narrative = GetScenarioNarrative(SCENARIO_RANGE_CONDITIONS);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_RANGE_CONDITIONS);
      result.displayColor = GetScenarioColor(SCENARIO_RANGE_CONDITIONS);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_RANGE_CONDITIONS);
      result.confidence = MathMax(result.confidence, 15);
      LOG("  → RANGE CONDITIONS detected", m_debug);
      return result;
   }
   
   // Check for PULLBACK PREPARE
   if(data.mtfTotalScore >= 20 && data.mtfConfidence >= 40 &&
      data.adxValue >= 20 &&
      data.pbAdjustedPercent >= 45 && data.pbAdjustedPercent <= 75 &&
      data.volRatio < 1.2 &&
      data.finalConfidence >= 30)
   {
      result.scenario = SCENARIO_PULLBACK_PREPARE;
      result.description = GetScenarioDescription(SCENARIO_PULLBACK_PREPARE);
      result.conditions = GetScenarioConditions(SCENARIO_PULLBACK_PREPARE);
      result.action = GetScenarioAction(SCENARIO_PULLBACK_PREPARE);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_PULLBACK_PREPARE);
      result.narrative = GetScenarioNarrative(SCENARIO_PULLBACK_PREPARE);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_PULLBACK_PREPARE);
      result.displayColor = GetScenarioColor(SCENARIO_PULLBACK_PREPARE);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_PULLBACK_PREPARE);
      result.confidence = MathMax(result.confidence, 30);
      LOG("  → PULLBACK PREPARE detected", m_debug);
      return result;
   }
   
   // Check for SLOW GRIND
   if(data.mtfTotalScore >= 25 && data.mtfConfidence >= 50 &&
      data.adxValue >= 20 && data.adxValue <= 25 &&
      data.rsiValue >= 50 && data.rsiValue <= 60 &&
      data.volRatio >= 0.8 && data.volRatio <= 1.2 &&
      data.finalConfidence >= 35)
   {
      result.scenario = SCENARIO_SLOW_GRIND;
      result.description = GetScenarioDescription(SCENARIO_SLOW_GRIND);
      result.conditions = GetScenarioConditions(SCENARIO_SLOW_GRIND);
      result.action = GetScenarioAction(SCENARIO_SLOW_GRIND);
      result.riskLevel = GetScenarioRiskLevel(SCENARIO_SLOW_GRIND);
      result.narrative = GetScenarioNarrative(SCENARIO_SLOW_GRIND);
      result.shortNarrative = GetScenarioShortNarrative(SCENARIO_SLOW_GRIND);
      result.displayColor = GetScenarioColor(SCENARIO_SLOW_GRIND);
      result.displayEmoji = GetScenarioEmoji(SCENARIO_SLOW_GRIND);
      result.confidence = MathMax(result.confidence, 35);
      LOG("  → SLOW GRIND detected", m_debug);
      return result;
   }
   
   // Default: UNKNOWN
   result.scenario = SCENARIO_UNKNOWN;
   result.description = GetScenarioDescription(SCENARIO_UNKNOWN);
   result.conditions = GetScenarioConditions(SCENARIO_UNKNOWN);
   result.action = GetScenarioAction(SCENARIO_UNKNOWN);
   result.riskLevel = GetScenarioRiskLevel(SCENARIO_UNKNOWN);
   result.narrative = GetScenarioNarrative(SCENARIO_UNKNOWN);
   result.shortNarrative = GetScenarioShortNarrative(SCENARIO_UNKNOWN);
   result.displayColor = GetScenarioColor(SCENARIO_UNKNOWN);
   result.displayEmoji = GetScenarioEmoji(SCENARIO_UNKNOWN);
   result.confidence = MathMax(result.confidence, 10);
   LOG("  → UNKNOWN scenario (no match)", m_debug);
   
   return result;
}

//+------------------------------------------------------------------+
//| SCENARIO ATTRIBUTE GETTERS                                      |
//+------------------------------------------------------------------+
string ScenarioNarrative::GetScenarioName(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioNames))
      return m_scenarioNames[idx];
   return "UNKNOWN";
}

string ScenarioNarrative::GetScenarioDescription(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioDescriptions))
      return m_scenarioDescriptions[idx];
   return "No description available";
}

string ScenarioNarrative::GetScenarioConditions(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioConditions))
      return m_scenarioConditions[idx];
   return "No conditions available";
}

string ScenarioNarrative::GetScenarioAction(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioActions))
      return m_scenarioActions[idx];
   return "Wait";
}

string ScenarioNarrative::GetScenarioRiskLevel(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioRiskLevels))
      return m_scenarioRiskLevels[idx];
   return "NO TRADE";
}

string ScenarioNarrative::GetScenarioNarrative(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioNarratives))
      return m_scenarioNarratives[idx];
   return "No narrative available for this scenario.";
}

string ScenarioNarrative::GetScenarioShortNarrative(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioShortNarratives))
      return m_scenarioShortNarratives[idx];
   return "❓ UNKNOWN";
}

string ScenarioNarrative::GetScenarioEmoji(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioEmojis))
      return m_scenarioEmojis[idx];
   return "❓";
}

color ScenarioNarrative::GetScenarioColor(ENUM_MARKET_SCENARIO scenario)
{
   int idx = (int)scenario;
   if(idx >= 0 && idx < ArraySize(m_scenarioColors))
      return m_scenarioColors[idx];
   return clrGray;
}

//+------------------------------------------------------------------+
//| GENERATE FULL NARRATIVE                                         |
//+------------------------------------------------------------------+
string ScenarioNarrative::GenerateFullNarrative(SSynthesizedScenario &scenario)
{
   LOG("Generating full narrative...", m_debug);
   return scenario.narrative;
}

//+------------------------------------------------------------------+
//| GENERATE DASHBOARD TEXT                                         |
//+------------------------------------------------------------------+
string ScenarioNarrative::GenerateDashboardText(SSynthesizedScenario &scenario)
{
   LOG("Generating dashboard text...", m_debug);
   
   string output = "";
   
   output += "═══════════════════════════════════════════════════════════════════\n";
   output += "SCENARIO: " + scenario.scenarioEmoji + " " + scenario.scenarioName + "\n";
   output += "DIRECTION: " + scenario.direction + " | CONFIDENCE: " + 
             DoubleToString(scenario.confidence, 1) + "%\n";
   output += "───────────────────────────────────────────────────────────────────\n";
   output += "ACTION: " + scenario.action + " | RISK: " + scenario.riskLevel + "\n";
   output += "───────────────────────────────────────────────────────────────────\n";
   output += "COMPONENTS:\n";
   
   for(int i = 0; i < scenario.componentCount && i < 6; i++)
   {
      SComponentNarrative comp = scenario.componentNarratives[i];
      if(comp.isActive)
      {
         output += "  " + comp.emoji + " " + comp.componentName + ": ";
         output += comp.shortNarrative + "\n";
      }
   }
   
   output += "───────────────────────────────────────────────────────────────────\n";
   if(scenario.warning != "✅ No major warnings")
      output += "⚠️ " + scenario.warning + "\n";
   output += "───────────────────────────────────────────────────────────────────\n";
   output += GetScenarioNarrative((ENUM_MARKET_SCENARIO)0) + "\n";
   output += "═══════════════════════════════════════════════════════════════════";
   
   return output;
}

//+------------------------------------------------------------------+
//| GENERATE COMPONENT SUMMARY TABLE                                 |
//+------------------------------------------------------------------+
string ScenarioNarrative::GenerateComponentSummaryTable(SComponentNarrative &narratives[], int count)
{
   LOG("Generating component summary table...", m_debug);
   
   string output = "";
   output += "┌─────────────────────────────────────────────────────────────────┐\n";
   output += "│ Component │ Direction │ Confidence │ Strength │ Alignment │\n";
   output += "├─────────────────────────────────────────────────────────────────┤\n";
   
   int maxCount = MathMin(count, 6);
   for(int i = 0; i < maxCount; i++)
   {
      SComponentNarrative comp = narratives[i];
      string status = comp.isActive ? "ACTIVE" : "INACTIVE";
      output += StringFormat("│ %-8s │ %-9s │ %8.0f%%  │ %-8s │ %-9s │ %-7s │\n",
                              comp.componentName,
                              comp.direction,
                              comp.confidence,
                              comp.strength,
                              comp.alignment,
                              status);
   }
   output += "└─────────────────────────────────────────────────────────────────┘";
   
   LOG("Component summary table generated", m_debug);
   return output;
}

//+------------------------------------------------------------------+
//| GENERATE QUICK STATUS                                            |
//+------------------------------------------------------------------+
string ScenarioNarrative::GenerateQuickStatus(SSynthesizedScenario &scenario)
{
   string result = "";
   result += scenario.scenarioEmoji;
   result += " ";
   result += scenario.scenarioName;
   result += " | Dir: ";
   result += scenario.direction;
   result += " | Conf: ";
   result += DoubleToString(scenario.confidence, 0);
   result += "% | ";
   result += scenario.action;
   return result;
}

//+------------------------------------------------------------------+
//| PRINT STATUS                                                    |
//+------------------------------------------------------------------+
void ScenarioNarrative::PrintStatus()
{
   LOG("=== SCENARIO NARRATIVE STATUS ===", true);
   LOG("  Symbol: " + m_symbol, true);
   LOG("  Timeframe: " + EnumToString(m_timeframe), true);
   LOG("  Initialized: " + (m_initialized ? "YES" : "NO"), true);
   LOG("  Debug: " + (m_debug ? "ON" : "OFF"), true);
   LOG("  Cache Timeout: " + IntegerToString(m_cacheTimeout) + "s", true);
   LOG("  Cache Valid: " + (m_cacheValid ? "YES" : "NO"), true);
   if(m_cacheValid)
   {
      LOG("  Cache Age: " + IntegerToString((int)(TimeCurrent() - m_cacheTime)) + "s", true);
      LOG("  Cached Scenario: " + m_cachedScenario.scenarioName, true);
   }
   LOG("  ADX Module: " + (m_adxModule != NULL ? "SET" : "NOT SET"), true);
   LOG("  Last Error: " + m_lastError, true);
   LOG("=== END STATUS ===", true);
}

//+------------------------------------------------------------------+
//| GLOBAL FUNCTIONS FOR DASHBOARD DISPLAY                          |
//+------------------------------------------------------------------+
string g_scenarioDisplayText = "";
string g_componentSummaryText = "";
string g_dashboardNarrative = "";
string g_lastScenarioName = "";

void UpdateScenarioGlobals(ScenarioResult &result, SComponentData &data)
{
   g_scenarioDisplayText = "SCENARIO: " + ScenarioNarrative().GetScenarioName(result.scenario) + 
                           " | CONF: " + DoubleToString(result.confidence, 0) + "% | " + 
                           data.finalDirection + " " + DoubleToString(data.bullPercentage, 0) + "/" + 
                           DoubleToString(data.bearPercentage, 0);
   
   g_componentSummaryText = "PB:" + DoubleToString(data.pbConfidence, 0) + "% " +
                            "MTF:" + DoubleToString(data.mtfConfidence, 0) + "% " +
                            "MACD:" + DoubleToString(data.macdConfidence, 0) + "% " +
                            "ADX:" + DoubleToString(data.adxConfidence, 0) + "% " +
                            "RSI:" + DoubleToString(data.rsiConfidence, 0) + "% " +
                            "VOL:" + DoubleToString(data.volConfidence, 0) + "%";
   
   g_dashboardNarrative = result.shortNarrative;
   g_lastScenarioName = ScenarioNarrative().GetScenarioName(result.scenario);
}