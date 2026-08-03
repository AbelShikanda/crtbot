//+------------------------------------------------------------------+
//|                        TrendManager.mqh                          |
//|                    Multi-TF Trend Detection + Crossover          |
//|                    v4.02 - CROSSOVER OVERHAUL                   |
//|                    ENTRY: M5 | TREND: M15 | CONTEXT: M1+H1      |
//|                    FOCUS: M15 Stack + M5 Pullback to MA89       |
//|                    LOGGING: ONLY ON CROSSOVERS                  |
//|                    WEIGHTS: H1=10%, M15=40%, M5=35%, M1=15%    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "4.02"

#include "../Utils/Logger.mqh"
#include "../Headers/Structures.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugTrendManager = false;

//+------------------------------------------------------------------+
//| Trend Manager Class - v4.02 Crossover Overhaul                 |
//+------------------------------------------------------------------+
class CTrendManager
{
private:
    string m_symbol;
    
    // ═══ TIMEFRAME ROLES ═══
    ENUM_TIMEFRAMES m_trendTF;      // M15 - Primary trend
    ENUM_TIMEFRAMES m_entryTF;      // M5  - Main entry timeframe
    ENUM_TIMEFRAMES m_contextTF1;   // M1  - Fine-tuning context
    ENUM_TIMEFRAMES m_contextTF2;   // H1  - Macro filter
    
    // ═══ INDICATOR HANDLES - M15 (TREND) ═══
    int m_ma21_handle;
    int m_ma89_handle;
    int m_ma200_handle;
    
    // ═══ INDICATOR HANDLES - M5 (ENTRY) ═══
    int m_ma21_M5_handle;
    int m_ma89_M5_handle;
    int m_ma200_M5_handle;
    
    // ═══ INDICATOR HANDLES - M1 (CONTEXT) ═══
    int m_ma21_M1_handle;
    int m_ma89_M1_handle;
    int m_ma200_M1_handle;
    
    // ═══ INDICATOR HANDLES - H1 (CONTEXT) ═══
    int m_ma21_H1_handle;
    int m_ma89_H1_handle;
    int m_ma200_H1_handle;
    
    // ═══ Cached Values - M15 (TREND) ═══
    double m_cacheMA21;
    double m_cacheMA89;
    double m_cacheMA200;
    double m_cachePrice;
    
    // ═══ Cached Values - M5 (ENTRY) ═══
    double m_cacheMA21_M5;
    double m_cacheMA89_M5;
    double m_cacheMA200_M5;
    double m_cachePrice_M5;
    
    // ═══ Cached Values - M1 (CONTEXT) ═══
    double m_cacheMA21_M1;
    double m_cacheMA89_M1;
    double m_cacheMA200_M1;
    double m_cachePrice_M1;
    
    // ═══ Cached Values - H1 (CONTEXT) ═══
    double m_cacheMA21_H1;
    double m_cacheMA89_H1;
    double m_cacheMA200_H1;
    double m_cachePrice_H1;
    
    // ═══ Previous Values for Crossover Detection ═══
    double m_prevMA21_M15;
    double m_prevMA89_M15;
    double m_prevMA200_M15;
    double m_prevMA21_M5;
    double m_prevMA89_M5;
    double m_prevMA200_M5;
    double m_prevPrice_M5;        // Added for M5 price cross detection
    
    // ═══ CROSSOVER STATE TRACKING (for logging only on changes) ═══
    bool m_lastLoggedM15_21_89_Bullish;
    bool m_lastLoggedM15_21_89_Bearish;
    bool m_lastLoggedM15_89_200_Bullish;
    bool m_lastLoggedM15_89_200_Bearish;
    bool m_lastLoggedM5_Price_89_Bullish;
    bool m_lastLoggedM5_Price_89_Bearish;
    bool m_lastLoggedM5_89_200_Bullish;
    bool m_lastLoggedM5_89_200_Bearish;
    string m_lastLoggedM1Position;
    
    // State
    STrendResult m_lastResult;
    SMarketFeatures m_lastFeatures;
    STrendRecommendation m_lastRecommendation;
    SCrossoverResult m_lastCrossover;
    datetime m_lastBarTime_M15;
    datetime m_lastBarTime_M5;
    datetime m_lastBarTime_M1;
    datetime m_lastBarTime_H1;
    bool m_isInitialized;
    
    // Fallback
    string m_lastValidDirection;
    datetime m_lastValidTime;
    bool m_hasValidDirection;
    
    // ═══ THRESHOLDS ═══
    double m_strongThreshold;
    double m_moderateThreshold;
    double m_weakThreshold;
    double m_minConfidence;
    int m_slopePeriods;
    
    // ═══ CROSSOVER BUFFER ═══
    int m_crossoverBufferPips;
    double m_crossoverBufferPoints;
    
    // ═══ WEIGHTS ═══
    double m_m1Weight;      // 15% - Context
    double m_m5Weight;      // 35% - Entry
    double m_m15Weight;     // 40% - Trend
    double m_h1Weight;      // 10% - Context
    
    // Private Methods
    bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &lastTime);
    void UpdateCache(ENUM_TIMEFRAMES tf);
    double GetMAValue(int handle, int shift);
    double CalculateMASlope(ENUM_TIMEFRAMES tf, int maPeriod, int periods);
    bool CheckPriceAboveMA(double price, double maValue);
    bool CheckMAStacking(double ma21, double ma89, double ma200);
    STrendResult GetFallbackTrend();
    string GenerateNarrative(const STrendResult &result);
    void CreateHandles();
    void ReleaseHandles();
    void UpdatePreviousValues();
    void InitLogState();
    
    // ═══ NEW: CROSSOVER DETECTION METHODS (OVERHAULED) ═══
    bool CheckM15TrendStack(ENUM_TREND_DIRECTION dir);
    bool CheckM5Pullback(ENUM_TREND_DIRECTION dir);
    void LogCrossings();
    SCrossoverResult DetectCrossoverEnhanced();
    ENUM_CROSS_STATE GetCrossoverState(double ma1, double ma2);
    bool JustCrossed(double ma1, double ma2, double prevMA1, double prevMA2);
    string GetStateName(ENUM_CROSS_STATE state);
    
    // ═══ FEATURE EXTRACTION ═══
    SMarketFeatures ExtractFeatures();
    double CalculateConfidence(SMarketFeatures &features);
    double CalculateAlignment(SMarketFeatures &features);
    double CalculateMomentum(SMarketFeatures &features);
    double CalculatePullbackDepth(SMarketFeatures &features);
    double CalculateTrendDuration(SMarketFeatures &features);
    double CalculateVolatility(SMarketFeatures &features);
    
    // ═══ DECISION ENGINE ═══
    STrendRecommendation MakeDecision(SMarketFeatures &features);
    double CalculatePositionSize(SMarketFeatures &features);
    string GetTiming(double momentum);
    string GetRiskLevel(double volatility);
    string GetConfidenceLevel(double confidence);
    string GeneratePrimaryReason(SMarketFeatures &features, STrendRecommendation &rec);
    void GenerateSecondaryReasons(SMarketFeatures &features, STrendRecommendation &rec);
    string GenerateFullNarrative(SMarketFeatures &features, STrendRecommendation &rec);
    string GetRejectionReason(SMarketFeatures &features);
    
protected:
    bool HasMomentum();
    bool IsTrendExhausted();
    int GetConfirmationBars();
    
public:
    // ═══ CONSTRUCTOR ═══
    CTrendManager(string symbol = NULL, 
                  ENUM_TIMEFRAMES trendTF = PERIOD_M15,
                  ENUM_TIMEFRAMES entryTF = PERIOD_M5,
                  ENUM_TIMEFRAMES contextTF1 = PERIOD_M1,
                  ENUM_TIMEFRAMES contextTF2 = PERIOD_H1);
    ~CTrendManager();
    
    // ═══ SETTERS ═══
    void SetWeights(double m1, double m5, double m15, double h1);
    void SetThresholds(double strong, double moderate, double weak, double minConf, int slopePeriods);
    void SetCrossoverBuffer(int pips);
    
    // ═══ INITIALIZATION ═══
    bool Initialize();
    void Shutdown();
    bool IsInitialized() const { return m_isInitialized; }
    bool HasValidDirection() const { return m_hasValidDirection; }
    
    // ═══ DEBUG ═══
    static void SetGlobalDebug(bool enable) { g_debugTrendManager = enable; }
    static bool GetGlobalDebug() { return g_debugTrendManager; }
    
    // ═══ PRIMARY ANALYSIS ═══
    STrendResult AnalyzeTrend();
    void AnalyzeFull(SMarketFeatures &features, STrendRecommendation &recommendation);
    
    // ═══ QUICK ACCESS ═══
    string GetDirection();
    double GetStrength();
    bool IsBullish();
    bool IsBearish();
    bool IsStrongTrend();
    double GetTrendConfidence();
    double GetSignalRatio();
    
    // ═══ ENTRY-SPECIFIC (M5) ═══
    bool IsTrending();
    bool IsEntryCompatible();
    bool IsTrendClear();
    double GetEntryScore();
    string GetEntryLabel();
    
    // ═══ TRADING FILTERS ═══
    bool ShouldAllowLongs();
    bool ShouldAllowShorts();
    bool ShouldAllowEntries();
    bool IsEntryAllowed();
    bool ShouldAllowEntry();
    
    // ═══ FEATURE GETTERS ═══
    SMarketFeatures GetLastFeatures() const { return m_lastFeatures; }
    STrendRecommendation GetLastRecommendation() const { return m_lastRecommendation; }
    SCrossoverResult GetLastCrossover() const { return m_lastCrossover; }
    
    // ═══ COMPONENT GETTERS ═══
    double GetMA21_M15() const { return m_cacheMA21; }
    double GetMA89_M15() const { return m_cacheMA89; }
    double GetMA200_M15() const { return m_cacheMA200; }
    double GetCurrentPrice() const { return m_cachePrice; }
    double GetMA21_M5() const { return m_cacheMA21_M5; }
    double GetMA89_M5() const { return m_cacheMA89_M5; }
    double GetMA200_M5() const { return m_cacheMA200_M5; }
    double GetMA21_M1() const { return m_cacheMA21_M1; }
    double GetMA89_M1() const { return m_cacheMA89_M1; }
    double GetMA200_M1() const { return m_cacheMA200_M1; }
    double GetMA21_H1() const { return m_cacheMA21_H1; }
    double GetMA89_H1() const { return m_cacheMA89_H1; }
    double GetMA200_H1() const { return m_cacheMA200_H1; }
    
    // ═══ CROSSOVER GETTERS ═══
    bool IsGoldenCross() const { return m_lastCrossover.isGoldenCross; }
    bool IsDeathCross() const { return m_lastCrossover.isDeathCross; }
    bool IsCrossoverDivergence() const { return m_lastCrossover.isDivergence; }
    int GetCrossoverPriority() const { return m_lastCrossover.priority; }
    string GetCrossoverScenarioName() const { return m_lastCrossover.scenarioName; }
    ENUM_CROSS_STATE GetM15CrossState() const { return m_lastCrossover.m15_21_89; }
    ENUM_CROSS_STATE GetM5CrossState() const { return m_lastCrossover.m5_21_89; }
    string GetM1Position() const { return m_lastCrossover.m1_position; }
    
    // ═══ BACKWARD COMPATIBLE ═══
    double GetMA21() const { return m_cacheMA21; }
    double GetMA89() const { return m_cacheMA89; }
    double GetMA200() const { return m_cacheMA200; }
    
    // ═══ M5 ENTRY METHODS ═══
    string GetDirection_M5();
    double GetStrength_M5();
    bool IsBullish_M5();
    bool IsBearish_M5();
    
    // ═══ REPORTS ═══
    STrendResult GetLastResult() const { return m_lastResult; }
    string GetSummaryString();
    string GetDetailedReport();
    string GetFeaturesReport(SMarketFeatures &features);
    string GetRecommendationReport(STrendRecommendation &rec);
    string GetCrossoverReport();

    // ═══ BACKWARD COMPATIBILITY ═══
    bool IsM1Compatible() { return IsEntryCompatible(); }
    bool IsM1EntryAllowed() { return IsEntryAllowed(); }
    bool ShouldAllowM1Entry() { return ShouldAllowEntry(); }
    double GetM1TrendScore() { return GetEntryScore(); }
    string GetM1TrendLabel() { return GetEntryLabel(); }
};

//=============================================================================
// CONSTRUCTOR
//=============================================================================
CTrendManager::CTrendManager(string symbol, ENUM_TIMEFRAMES trendTF, 
                             ENUM_TIMEFRAMES entryTF,
                             ENUM_TIMEFRAMES contextTF1,
                             ENUM_TIMEFRAMES contextTF2)
{
    LOG_DEBUG("CTrendManager v4.02 constructor called", g_debugTrendManager);
    
    m_symbol = (symbol == NULL) ? _Symbol : symbol;
    m_trendTF = (trendTF == PERIOD_CURRENT) ? PERIOD_M15 : trendTF;
    m_entryTF = (entryTF == PERIOD_CURRENT) ? PERIOD_M5 : entryTF;
    m_contextTF1 = (contextTF1 == PERIOD_CURRENT) ? PERIOD_M1 : contextTF1;
    m_contextTF2 = (contextTF2 == PERIOD_CURRENT) ? PERIOD_H1 : contextTF2;
    
    // Initialize handles
    m_ma21_handle = INVALID_HANDLE;
    m_ma89_handle = INVALID_HANDLE;
    m_ma200_handle = INVALID_HANDLE;
    m_ma21_M5_handle = INVALID_HANDLE;
    m_ma89_M5_handle = INVALID_HANDLE;
    m_ma200_M5_handle = INVALID_HANDLE;
    m_ma21_M1_handle = INVALID_HANDLE;
    m_ma89_M1_handle = INVALID_HANDLE;
    m_ma200_M1_handle = INVALID_HANDLE;
    m_ma21_H1_handle = INVALID_HANDLE;
    m_ma89_H1_handle = INVALID_HANDLE;
    m_ma200_H1_handle = INVALID_HANDLE;
    
    // Clear caches
    m_cacheMA21 = m_cacheMA89 = m_cacheMA200 = m_cachePrice = 0;
    m_cacheMA21_M5 = m_cacheMA89_M5 = m_cacheMA200_M5 = m_cachePrice_M5 = 0;
    m_cacheMA21_M1 = m_cacheMA89_M1 = m_cacheMA200_M1 = m_cachePrice_M1 = 0;
    m_cacheMA21_H1 = m_cacheMA89_H1 = m_cacheMA200_H1 = m_cachePrice_H1 = 0;
    m_prevPrice_M5 = 0;
    
    // Clear previous values
    m_prevMA21_M15 = m_prevMA89_M15 = m_prevMA200_M15 = 0;
    m_prevMA21_M5 = m_prevMA89_M5 = m_prevMA200_M5 = 0;
    
    m_lastBarTime_M15 = m_lastBarTime_M5 = m_lastBarTime_M1 = m_lastBarTime_H1 = 0;
    m_isInitialized = false;
    m_hasValidDirection = false;
    m_lastValidDirection = "NEUTRAL";
    m_lastValidTime = 0;
    
    // ═══ THRESHOLDS ═══
    m_strongThreshold = 50.0;
    m_moderateThreshold = 35.0;
    m_weakThreshold = 20.0;
    m_minConfidence = 25.0;
    m_slopePeriods = 3;
    
    // ═══ CROSSOVER SETTINGS ═══
    m_crossoverBufferPips = 10;
    m_crossoverBufferPoints = 10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    // ═══ WEIGHTS ═══
    m_m1Weight = 0.15;
    m_m5Weight = 0.35;
    m_m15Weight = 0.40;
    m_h1Weight = 0.10;
    
    // Initialize log state
    InitLogState();
    
    // Initialize results
    ZeroMemory(m_lastResult);
    m_lastResult.direction = "NEUTRAL";
    m_lastResult.description = "Not initialized";
    
    ZeroMemory(m_lastFeatures);
    ZeroMemory(m_lastRecommendation);
    ZeroMemory(m_lastCrossover);
    
    LOG_DEBUG("========================================", g_debugTrendManager);
    LOG_DEBUG("TREND MANAGER v4.02 - CROSSOVER OVERHAUL", g_debugTrendManager);
    LOG_DEBUG("========================================", g_debugTrendManager);
    LOG_DEBUG("  Symbol: " + m_symbol, g_debugTrendManager);
    LOG_DEBUG("  Trend TF: " + EnumToString(m_trendTF) + " (Stack Check)", g_debugTrendManager);
    LOG_DEBUG("  Entry TF: " + EnumToString(m_entryTF) + " (Pullback to MA89)", g_debugTrendManager);
    LOG_DEBUG("  Context TF1: " + EnumToString(m_contextTF1) + " (Fine-tuning)", g_debugTrendManager);
    LOG_DEBUG("  Context TF2: " + EnumToString(m_contextTF2) + " (Macro Filter)", g_debugTrendManager);
    LOG_DEBUG("  Weights: M1=15%, M5=35%, M15=40%, H1=10%", g_debugTrendManager);
    LOG_DEBUG("  Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips", g_debugTrendManager);
    LOG_DEBUG("  Logging: ONLY on crossovers (efficient)", g_debugTrendManager);
    LOG_DEBUG("========================================", g_debugTrendManager);
}

//=============================================================================
// DESTRUCTOR
//=============================================================================
CTrendManager::~CTrendManager()
{
    LOG_DEBUG("CTrendManager destructor called", g_debugTrendManager);
    Shutdown();
}

//=============================================================================
// INIT LOG STATE
//=============================================================================
void CTrendManager::InitLogState()
{
    m_lastLoggedM15_21_89_Bullish = false;
    m_lastLoggedM15_21_89_Bearish = false;
    m_lastLoggedM15_89_200_Bullish = false;
    m_lastLoggedM15_89_200_Bearish = false;
    m_lastLoggedM5_Price_89_Bullish = false;
    m_lastLoggedM5_Price_89_Bearish = false;
    m_lastLoggedM5_89_200_Bullish = false;
    m_lastLoggedM5_89_200_Bearish = false;
    m_lastLoggedM1Position = "";
}

//=============================================================================
// CREATE HANDLES (Unchanged)
//=============================================================================
void CTrendManager::CreateHandles()
{
    ReleaseHandles();
    
    m_ma21_handle = iMA(m_symbol, m_trendTF, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_handle = iMA(m_symbol, m_trendTF, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_handle = iMA(m_symbol, m_trendTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M15 Handles: MA21=" + IntegerToString(m_ma21_handle) + 
              " MA89=" + IntegerToString(m_ma89_handle) + 
              " MA200=" + IntegerToString(m_ma200_handle), g_debugTrendManager);
    
    m_ma21_M5_handle = iMA(m_symbol, m_entryTF, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_M5_handle = iMA(m_symbol, m_entryTF, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_M5_handle = iMA(m_symbol, m_entryTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M5 Handles: MA21=" + IntegerToString(m_ma21_M5_handle) + 
              " MA89=" + IntegerToString(m_ma89_M5_handle) + 
              " MA200=" + IntegerToString(m_ma200_M5_handle), g_debugTrendManager);
    
    m_ma21_M1_handle = iMA(m_symbol, m_contextTF1, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_M1_handle = iMA(m_symbol, m_contextTF1, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_M1_handle = iMA(m_symbol, m_contextTF1, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M1 Handles: MA21=" + IntegerToString(m_ma21_M1_handle) + 
              " MA89=" + IntegerToString(m_ma89_M1_handle) + 
              " MA200=" + IntegerToString(m_ma200_M1_handle), g_debugTrendManager);
    
    m_ma21_H1_handle = iMA(m_symbol, m_contextTF2, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_H1_handle = iMA(m_symbol, m_contextTF2, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_H1_handle = iMA(m_symbol, m_contextTF2, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("H1 Handles: MA21=" + IntegerToString(m_ma21_H1_handle) + 
              " MA89=" + IntegerToString(m_ma89_H1_handle) + 
              " MA200=" + IntegerToString(m_ma200_H1_handle), g_debugTrendManager);
    
    bool m5Valid = (m_ma21_M5_handle != INVALID_HANDLE && 
                    m_ma89_M5_handle != INVALID_HANDLE &&
                    m_ma200_M5_handle != INVALID_HANDLE);
    
    bool m1Valid = (m_ma21_M1_handle != INVALID_HANDLE && 
                    m_ma89_M1_handle != INVALID_HANDLE &&
                    m_ma200_M1_handle != INVALID_HANDLE);
    
    bool h1Valid = (m_ma21_H1_handle != INVALID_HANDLE && 
                    m_ma89_H1_handle != INVALID_HANDLE &&
                    m_ma200_H1_handle != INVALID_HANDLE);
    
    if(!m5Valid)
        LOG_WARNING("⚠️ M5 handles are INVALID! M5 data will be 0.");
    
    if(!m1Valid)
        LOG_WARNING("⚠️ M1 handles are INVALID! M1 data will be 0.");
    
    if(!h1Valid)
        LOG_WARNING("⚠️ H1 handles are INVALID! H1 data will be 0.");
}

//=============================================================================
// RELEASE HANDLES (Unchanged)
//=============================================================================
void CTrendManager::ReleaseHandles()
{
    if(m_ma21_handle != INVALID_HANDLE) IndicatorRelease(m_ma21_handle);
    if(m_ma89_handle != INVALID_HANDLE) IndicatorRelease(m_ma89_handle);
    if(m_ma200_handle != INVALID_HANDLE) IndicatorRelease(m_ma200_handle);
    if(m_ma21_M5_handle != INVALID_HANDLE) IndicatorRelease(m_ma21_M5_handle);
    if(m_ma89_M5_handle != INVALID_HANDLE) IndicatorRelease(m_ma89_M5_handle);
    if(m_ma200_M5_handle != INVALID_HANDLE) IndicatorRelease(m_ma200_M5_handle);
    if(m_ma21_M1_handle != INVALID_HANDLE) IndicatorRelease(m_ma21_M1_handle);
    if(m_ma89_M1_handle != INVALID_HANDLE) IndicatorRelease(m_ma89_M1_handle);
    if(m_ma200_M1_handle != INVALID_HANDLE) IndicatorRelease(m_ma200_M1_handle);
    if(m_ma21_H1_handle != INVALID_HANDLE) IndicatorRelease(m_ma21_H1_handle);
    if(m_ma89_H1_handle != INVALID_HANDLE) IndicatorRelease(m_ma89_H1_handle);
    if(m_ma200_H1_handle != INVALID_HANDLE) IndicatorRelease(m_ma200_H1_handle);
    
    m_ma21_handle = INVALID_HANDLE;
    m_ma89_handle = INVALID_HANDLE;
    m_ma200_handle = INVALID_HANDLE;
    m_ma21_M5_handle = INVALID_HANDLE;
    m_ma89_M5_handle = INVALID_HANDLE;
    m_ma200_M5_handle = INVALID_HANDLE;
    m_ma21_M1_handle = INVALID_HANDLE;
    m_ma89_M1_handle = INVALID_HANDLE;
    m_ma200_M1_handle = INVALID_HANDLE;
    m_ma21_H1_handle = INVALID_HANDLE;
    m_ma89_H1_handle = INVALID_HANDLE;
    m_ma200_H1_handle = INVALID_HANDLE;
}

//=============================================================================
// SET CROSSOVER BUFFER (Unchanged)
//=============================================================================
void CTrendManager::SetCrossoverBuffer(int pips)
{
    m_crossoverBufferPips = pips;
    m_crossoverBufferPoints = pips * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    LOG_DEBUG("Crossover buffer set to " + IntegerToString(pips) + " pips", g_debugTrendManager);
}

//=============================================================================
// SET WEIGHTS (Unchanged)
//=============================================================================
void CTrendManager::SetWeights(double m1, double m5, double m15, double h1)
{
    double total = m1 + m5 + m15 + h1;
    if(total > 0)
    {
        m_m1Weight = m1 / total;
        m_m5Weight = m5 / total;
        m_m15Weight = m15 / total;
        m_h1Weight = h1 / total;
    }
    LOG_DEBUG("Weights set: M1=" + DoubleToString(m_m1Weight*100,0) + 
              "% M5=" + DoubleToString(m_m5Weight*100,0) + 
              "% M15=" + DoubleToString(m_m15Weight*100,0) + 
              "% H1=" + DoubleToString(m_h1Weight*100,0) + "%", g_debugTrendManager);
}

//=============================================================================
// SET THRESHOLDS (Unchanged)
//=============================================================================
void CTrendManager::SetThresholds(double strong, double moderate, double weak, 
                                  double minConf, int slopePeriods)
{
    m_strongThreshold = strong;
    m_moderateThreshold = moderate;
    m_weakThreshold = weak;
    m_minConfidence = minConf;
    m_slopePeriods = slopePeriods;
}

//=============================================================================
// GET MA VALUE (Unchanged)
//=============================================================================
double CTrendManager::GetMAValue(int handle, int shift)
{
    if(handle == INVALID_HANDLE) 
    {
        LOG_DEBUG("❌ GetMAValue: Invalid handle", g_debugTrendManager);
        return 0;
    }
    
    double buffer[1];
    if(CopyBuffer(handle, 0, shift, 1, buffer) < 1) 
    {
        LOG_DEBUG("❌ GetMAValue: CopyBuffer failed for handle " + IntegerToString(handle), 
                  g_debugTrendManager);
        return 0;
    }
    
    if(!MathIsValidNumber(buffer[0]) || buffer[0] == 0)
    {
        LOG_DEBUG("❌ GetMAValue: Invalid value: " + DoubleToString(buffer[0], _Digits), 
                  g_debugTrendManager);
        return 0;
    }
    
    return buffer[0];
}

//=============================================================================
// CHECK NEW BAR (Unchanged)
//=============================================================================
bool CTrendManager::IsNewBar(ENUM_TIMEFRAMES tf, datetime &lastTime)
{
    if(!m_isInitialized) return false;
    datetime currentTime = iTime(m_symbol, tf, 0);
    if(currentTime == 0) return false;
    if(currentTime != lastTime)
    {
        lastTime = currentTime;
        return true;
    }
    return false;
}

//=============================================================================
// UPDATE CACHE (Unchanged)
//=============================================================================
void CTrendManager::UpdateCache(ENUM_TIMEFRAMES tf)
{
    if(!m_isInitialized) return;
    
    if(tf == m_trendTF || tf == PERIOD_M15)
    {
        m_prevMA21_M15 = m_cacheMA21;
        m_prevMA89_M15 = m_cacheMA89;
        m_prevMA200_M15 = m_cacheMA200;
        
        m_cacheMA21 = GetMAValue(m_ma21_handle, 0);
        m_cacheMA89 = GetMAValue(m_ma89_handle, 0);
        m_cacheMA200 = GetMAValue(m_ma200_handle, 0);
        m_cachePrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    else if(tf == m_entryTF || tf == PERIOD_M5)
    {
        m_prevMA21_M5 = m_cacheMA21_M5;
        m_prevMA89_M5 = m_cacheMA89_M5;
        m_prevMA200_M5 = m_cacheMA200_M5;
        m_prevPrice_M5 = m_cachePrice_M5;
        
        m_cacheMA21_M5 = GetMAValue(m_ma21_M5_handle, 0);
        m_cacheMA89_M5 = GetMAValue(m_ma89_M5_handle, 0);
        m_cacheMA200_M5 = GetMAValue(m_ma200_M5_handle, 0);
        m_cachePrice_M5 = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    else if(tf == m_contextTF1 || tf == PERIOD_M1)
    {
        m_cacheMA21_M1 = GetMAValue(m_ma21_M1_handle, 0);
        m_cacheMA89_M1 = GetMAValue(m_ma89_M1_handle, 0);
        m_cacheMA200_M1 = GetMAValue(m_ma200_M1_handle, 0);
        m_cachePrice_M1 = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    else if(tf == m_contextTF2 || tf == PERIOD_H1)
    {
        m_cacheMA21_H1 = GetMAValue(m_ma21_H1_handle, 0);
        m_cacheMA89_H1 = GetMAValue(m_ma89_H1_handle, 0);
        m_cacheMA200_H1 = GetMAValue(m_ma200_H1_handle, 0);
        m_cachePrice_H1 = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
}

//=============================================================================
// UPDATE PREVIOUS VALUES (Unchanged)
//=============================================================================
void CTrendManager::UpdatePreviousValues()
{
    if(m_prevMA21_M15 == 0 && m_cacheMA21 != 0)
    {
        m_prevMA21_M15 = m_cacheMA21;
        m_prevMA89_M15 = m_cacheMA89;
        m_prevMA200_M15 = m_cacheMA200;
    }
    if(m_prevMA21_M5 == 0 && m_cacheMA21_M5 != 0)
    {
        m_prevMA21_M5 = m_cacheMA21_M5;
        m_prevMA89_M5 = m_cacheMA89_M5;
        m_prevMA200_M5 = m_cacheMA200_M5;
    }
}

//=============================================================================
// CALCULATE MA SLOPE (Unchanged)
//=============================================================================
double CTrendManager::CalculateMASlope(ENUM_TIMEFRAMES tf, int maPeriod, int periods)
{
    int handle = 0;
    
    if(tf == m_trendTF || tf == PERIOD_M15)
    {
        if(maPeriod == 21) handle = m_ma21_handle;
        else if(maPeriod == 89) handle = m_ma89_handle;
        else return 0;
    }
    else if(tf == m_entryTF || tf == PERIOD_M5)
    {
        if(maPeriod == 21) handle = m_ma21_M5_handle;
        else if(maPeriod == 89) handle = m_ma89_M5_handle;
        else return 0;
    }
    else if(tf == m_contextTF1 || tf == PERIOD_M1)
    {
        if(maPeriod == 21) handle = m_ma21_M1_handle;
        else if(maPeriod == 89) handle = m_ma89_M1_handle;
        else return 0;
    }
    else if(tf == m_contextTF2 || tf == PERIOD_H1)
    {
        if(maPeriod == 21) handle = m_ma21_H1_handle;
        else if(maPeriod == 89) handle = m_ma89_H1_handle;
        else return 0;
    }
    
    if(handle == INVALID_HANDLE) return 0;
    
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = periods;
    bool valid = true;
    
    for(int i = 0; i < n; i++)
    {
        double y = GetMAValue(handle, i);
        if(y == 0) { valid = false; break; }
        double x = i;
        sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x;
    }
    
    if(!valid || n == 0) return 0;
    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
}

//=============================================================================
// CHECK PRICE ABOVE MA (Unchanged)
//=============================================================================
bool CTrendManager::CheckPriceAboveMA(double price, double maValue)
{
    if(maValue == 0) return false;
    return price > maValue;
}

//=============================================================================
// CHECK MA STACKING (Unchanged)
//=============================================================================
bool CTrendManager::CheckMAStacking(double ma21, double ma89, double ma200)
{
    if(ma21 == 0 || ma89 == 0 || ma200 == 0) return false;
    return (ma21 > ma89 && ma89 > ma200) || (ma21 < ma89 && ma89 < ma200);
}

//=============================================================================
// GET STATE NAME (Unchanged)
//=============================================================================
string CTrendManager::GetStateName(ENUM_CROSS_STATE state)
{
    switch(state)
    {
        case CROSS_UP:   return "↗ CROSS UP";
        case CROSS_ZONE: return "≈ ZONE";
        case CROSS_DOWN: return "↘ CROSS DOWN";
        case CLEAR_UP:   return "▲ CLEAR UP";
        case CLEAR_DOWN: return "▼ CLEAR DOWN";
        default:         return "UNKNOWN";
    }
}

//=============================================================================
// ═══ NEW: CHECK M15 TREND STACK ═══
//=============================================================================
bool CTrendManager::CheckM15TrendStack(ENUM_TREND_DIRECTION dir)
{
    double ma21 = m_cacheMA21;
    double ma89 = m_cacheMA89;
    double ma200 = m_cacheMA200;
    
    if(ma21 == 0 || ma89 == 0 || ma200 == 0) return false;
    
    double diff21_89 = ma21 - ma89;
    double diff89_200 = ma89 - ma200;
    
    // Check for perfect stack: 21 > 89 > 200
    bool perfectBullish = (ma21 > ma89 && ma89 > ma200);
    bool perfectBearish = (ma21 < ma89 && ma89 < ma200);
    
    // Check for minimal stack (within buffer): 21 ≈ 89 > 200 (bullish) or 21 ≈ 89 < 200 (bearish)
    bool withinBuffer = (MathAbs(diff21_89) <= m_crossoverBufferPoints);
    bool ma89Above200 = (ma89 > ma200);
    bool ma89Below200 = (ma89 < ma200);
    
    bool minimalBullish = withinBuffer && ma89Above200;
    bool minimalBearish = withinBuffer && ma89Below200;
    
    // Final result based on direction
    if(dir == TREND_BULLISH)
    {
        return (perfectBullish || minimalBullish);
    }
    else if(dir == TREND_BEARISH)
    {
        return (perfectBearish || minimalBearish);
    }
    
    return false;
}

//=============================================================================
// ═══ NEW: CHECK M5 PULLBACK ═══
//=============================================================================
bool CTrendManager::CheckM5Pullback(ENUM_TREND_DIRECTION dir)
{
    double price = m_cachePrice_M5;
    double ma89 = m_cacheMA89_M5;
    double ma200 = m_cacheMA200_M5;
    
    if(price == 0 || ma89 == 0 || ma200 == 0) return false;
    
    double priceToMA89 = price - ma89;
    double ma89ToMA200 = ma89 - ma200;
    
    bool priceNearMA89 = (MathAbs(priceToMA89) <= m_crossoverBufferPoints);
    bool ma89Above200 = (ma89 > ma200);
    bool ma89Below200 = (ma89 < ma200);
    
    // Bullish: Price ≈ MA89 > MA200 (or slightly below)
    if(dir == TREND_BULLISH)
    {
        // Price can be slightly below MA89 (within buffer) or above
        bool priceAtOrNearMA89 = (price >= ma89 - m_crossoverBufferPoints);
        return priceAtOrNearMA89 && ma89Above200;
    }
    // Bearish: Price ≈ MA89 < MA200 (or slightly above)
    else if(dir == TREND_BEARISH)
    {
        // Price can be slightly above MA89 (within buffer) or below
        bool priceAtOrNearMA89 = (price <= ma89 + m_crossoverBufferPoints);
        return priceAtOrNearMA89 && ma89Below200;
    }
    
    return false;
}

//=============================================================================
// ═══ NEW: LOG CROSSINGS (ONLY ON VALID SIGNALS) ═══
//=============================================================================
void CTrendManager::LogCrossings()
{
   // ─── ONLY LOG ON VALID SIGNALS (Priority 1-2 AND Direction != NEUTRAL) ───
   // Check if we have a valid signal
   bool isValidSignal = false;
   
   // Check priority from m_lastCrossover
   if(m_lastCrossover.priority == 1 || m_lastCrossover.priority == 2)
   {
      // Check direction from m_lastResult
      if(m_lastResult.direction != "NEUTRAL")
      {
         isValidSignal = true;
      }
   }
   
   // If not a valid signal, skip ALL logging
   if(!isValidSignal)
      return;
   
   // ─── ONLY PROCEED IF VALID SIGNAL ───
   double ma21 = m_cacheMA21;
   double ma89 = m_cacheMA89;
   double ma200 = m_cacheMA200;
   double ma21_M5 = m_cacheMA21_M5;
   double ma89_M5 = m_cacheMA89_M5;
   double ma200_M5 = m_cacheMA200_M5;
   double priceM5 = m_cachePrice_M5;
   
   // ═══ M15: MA21 vs MA89 CROSS ═══
   bool m15_21_89_Bullish = (ma21 > ma89);
   bool m15_21_89_Bearish = (ma21 < ma89);
   
   if(m15_21_89_Bullish != m_lastLoggedM15_21_89_Bullish)
   {
      if(m15_21_89_Bullish)
         LOG_INFO("🔀 M15: MA21 CROSSED ABOVE MA89 (Bullish)", g_debugTrendManager);
      else
         LOG_INFO("🔀 M15: MA21 CROSSED BELOW MA89 (Bearish)", g_debugTrendManager);
      m_lastLoggedM15_21_89_Bullish = m15_21_89_Bullish;
      m_lastLoggedM15_21_89_Bearish = m15_21_89_Bearish;
   }
   
   // ═══ M15: MA89 vs MA200 CROSS ═══
   bool m15_89_200_Bullish = (ma89 > ma200);
   bool m15_89_200_Bearish = (ma89 < ma200);
   
   if(m15_89_200_Bullish != m_lastLoggedM15_89_200_Bullish)
   {
      if(m15_89_200_Bullish)
         LOG_INFO("🔀 M15: MA89 CROSSED ABOVE MA200 (Bullish)", g_debugTrendManager);
      else
         LOG_INFO("🔀 M15: MA89 CROSSED BELOW MA200 (Bearish)", g_debugTrendManager);
      m_lastLoggedM15_89_200_Bullish = m15_89_200_Bullish;
      m_lastLoggedM15_89_200_Bearish = m15_89_200_Bearish;
   }
   
   // ═══ M5: PRICE vs MA89 CROSS/PROXIMITY ═══
   double diff = priceM5 - ma89_M5;
   bool priceAbove89 = (priceM5 > ma89_M5);
   bool priceBelow89 = (priceM5 < ma89_M5);
   bool priceInBuffer = (MathAbs(diff) <= m_crossoverBufferPoints);
   
   if(priceInBuffer)
   {
      if(!m_lastLoggedM5_Price_89_Bullish && !m_lastLoggedM5_Price_89_Bearish)
      {
         LOG_INFO("📍 M5: Price ENTERED BUFFER ZONE around MA89 (Diff: " + 
                  DoubleToString(diff, _Digits) + ")", g_debugTrendManager);
      }
      if(priceAbove89 != m_lastLoggedM5_Price_89_Bullish && priceAbove89)
      {
         LOG_INFO("📍 M5: Price CROSSED ABOVE MA89 (Diff: " + 
                  DoubleToString(diff, _Digits) + ")", g_debugTrendManager);
      }
      if(priceBelow89 != m_lastLoggedM5_Price_89_Bearish && priceBelow89)
      {
         LOG_INFO("📍 M5: Price CROSSED BELOW MA89 (Diff: " + 
                  DoubleToString(diff, _Digits) + ")", g_debugTrendManager);
      }
   }
   else
   {
      if(m_lastLoggedM5_Price_89_Bullish || m_lastLoggedM5_Price_89_Bearish)
      {
         LOG_INFO("📍 M5: Price LEFT BUFFER ZONE around MA89 (Diff: " + 
                  DoubleToString(diff, _Digits) + ")", g_debugTrendManager);
      }
   }
   
   m_lastLoggedM5_Price_89_Bullish = priceAbove89;
   m_lastLoggedM5_Price_89_Bearish = priceBelow89;
   
   // ═══ M5: MA89 vs MA200 CROSS ═══
   bool m5_89_200_Bullish = (ma89_M5 > ma200_M5);
   bool m5_89_200_Bearish = (ma89_M5 < ma200_M5);
   
   if(m5_89_200_Bullish != m_lastLoggedM5_89_200_Bullish)
   {
      if(m5_89_200_Bullish)
         LOG_INFO("🔀 M5: MA89 CROSSED ABOVE MA200 (Bullish)", g_debugTrendManager);
      else
         LOG_INFO("🔀 M5: MA89 CROSSED BELOW MA200 (Bearish)", g_debugTrendManager);
      m_lastLoggedM5_89_200_Bullish = m5_89_200_Bullish;
      m_lastLoggedM5_89_200_Bearish = m5_89_200_Bearish;
   }
   
   // ═══ M1: POSITION ═══
   string m1Pos = "";
   double diffM1 = m_cachePrice - m_cacheMA21_M1;
   double diffPoints = diffM1 / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   if(diffPoints > 10)
      m1Pos = "ABOVE";
   else if(diffPoints < -10)
      m1Pos = "BELOW";
   else
      m1Pos = "NEAR";
   
   if(m1Pos != m_lastLoggedM1Position)
   {
      LOG_INFO("📍 M1: Price " + m1Pos + " MA21 (" + 
               DoubleToString(diffPoints, 1) + " pts)", g_debugTrendManager);
      m_lastLoggedM1Position = m1Pos;
   }
}

//=============================================================================
// ═══ NEW: DETECT CROSSOVER ENHANCED ═══
//=============================================================================
SCrossoverResult CTrendManager::DetectCrossoverEnhanced()
{
    SCrossoverResult result;
    ZeroMemory(result);
    result.priority = 6;
    
    // Store MA values
    result.ma21_M15 = m_cacheMA21;
    result.ma89_M15 = m_cacheMA89;
    result.ma200_M15 = m_cacheMA200;
    result.ma21_M5 = m_cacheMA21_M5;
    result.ma89_M5 = m_cacheMA89_M5;
    result.ma200_M5 = m_cacheMA200_M5;
    result.ma21_M1 = m_cacheMA21_M1;
    result.currentPrice = m_cachePrice;
    result.pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    // ─── Check data validity ───
    bool m5Valid = (m_cacheMA21_M5 != 0 && m_cacheMA89_M5 != 0);
    bool m1Valid = (m_cacheMA21_M1 != 0);
    
    // ─── M15 CROSSOVER STATES ───
    result.m15_21_89 = GetCrossoverState(m_cacheMA21, m_cacheMA89);
    result.m15_89_200 = GetCrossoverState(m_cacheMA89, m_cacheMA200);
    
    result.m15_21_89_justCrossed = JustCrossed(m_cacheMA21, m_cacheMA89, m_prevMA21_M15, m_prevMA89_M15);
    result.m15_89_200_justCrossed = JustCrossed(m_cacheMA89, m_cacheMA200, m_prevMA89_M15, m_prevMA200_M15);
    
    // ─── M5 CROSSOVER STATES ───
    if(m5Valid)
    {
        result.m5_21_89 = GetCrossoverState(m_cacheMA21_M5, m_cacheMA89_M5);
        result.m5_21_89_justCrossed = JustCrossed(m_cacheMA21_M5, m_cacheMA89_M5, m_prevMA21_M5, m_prevMA89_M5);
    }
    else
    {
        result.m5_21_89 = result.m15_21_89;
        result.m5_21_89_justCrossed = result.m15_21_89_justCrossed;
    }
    
    // ─── M1 POSITION ───
    if(m1Valid)
    {
        double diffM1 = m_cachePrice - m_cacheMA21_M1;
        double diffPoints = diffM1 / result.pointValue;
        result.m1_distance = diffPoints;
        
        if(diffPoints > 10)
            result.m1_position = "ABOVE";
        else if(diffPoints < -10)
            result.m1_position = "BELOW";
        else
            result.m1_position = "NEAR";
    }
    else
    {
        double diffM15 = m_cachePrice - m_cacheMA21;
        double diffPoints = diffM15 / result.pointValue;
        result.m1_distance = diffPoints;
        result.m1_position = "NEAR";
    }
    
    // ─── DERIVED STATES ───
    bool m15Bullish = (m_cacheMA21 > m_cacheMA89);
    bool m15Bearish = (m_cacheMA21 < m_cacheMA89);
    bool m15StackedBullish = (m_cacheMA21 > m_cacheMA89 && m_cacheMA89 > m_cacheMA200);
    bool m15StackedBearish = (m_cacheMA21 < m_cacheMA89 && m_cacheMA89 < m_cacheMA200);
    
    bool m5Bullish = m5Valid ? (m_cacheMA21_M5 > m_cacheMA89_M5) : m15Bullish;
    bool m5Bearish = m5Valid ? (m_cacheMA21_M5 < m_cacheMA89_M5) : m15Bearish;
    bool m5StackedBullish = m5Valid ? (m_cacheMA21_M5 > m_cacheMA89_M5 && m_cacheMA89_M5 > m_cacheMA200_M5) : m15StackedBullish;
    bool m5StackedBearish = m5Valid ? (m_cacheMA21_M5 < m_cacheMA89_M5 && m_cacheMA89_M5 < m_cacheMA200_M5) : m15StackedBearish;
    
    result.isGoldenCross = (result.m15_21_89 == CLEAR_UP || result.m15_21_89 == CROSS_UP) && 
                           (result.m15_89_200 == CLEAR_UP);
    result.isDeathCross = (result.m15_21_89 == CLEAR_DOWN || result.m15_21_89 == CROSS_DOWN) && 
                          (result.m15_89_200 == CLEAR_DOWN);
    
    result.allBullish = m15Bullish && (m5Bullish || result.m5_21_89_justCrossed);
    result.allBearish = m15Bearish && (m5Bearish || result.m5_21_89_justCrossed);
    result.isDivergence = (m15Bullish && m5Bearish) || (m15Bearish && m5Bullish);
    
    // ─── NEW: CHECK M15 STACK + M5 PULLBACK ───
    bool m15StackValid = false;
    string stackDirection = "";
    
    // Check bullish stack
    if(CheckM15TrendStack(TREND_BULLISH))
    {
        m15StackValid = true;
        stackDirection = "BULLISH";
    }
    // Check bearish stack
    else if(CheckM15TrendStack(TREND_BEARISH))
    {
        m15StackValid = true;
        stackDirection = "BEARISH";
    }
    
    // Check M5 pullback
    bool m5PullbackValid = false;
    string pullbackDirection = "";
    
    if(m15StackValid && stackDirection == "BULLISH")
    {
        if(CheckM5Pullback(TREND_BULLISH))
        {
            m5PullbackValid = true;
            pullbackDirection = "BULLISH";
        }
    }
    else if(m15StackValid && stackDirection == "BEARISH")
    {
        if(CheckM5Pullback(TREND_BEARISH))
        {
            m5PullbackValid = true;
            pullbackDirection = "BEARISH";
        }
    }
    
    // ─── DETERMINE SCENARIO (NEW PRIORITY SYSTEM) ───
    result.scenarioNumber = 0;
    result.scenarioName = "WAIT";
    result.priority = 6;
    
    // ─── BULLISH SCENARIOS ───
    if(m15StackValid && stackDirection == "BULLISH" && m5PullbackValid && pullbackDirection == "BULLISH")
    {
        // STRONG BUY: M15 Stacked + M5 Price at MA89
        if(result.m1_position == "ABOVE" || result.m1_position == "NEAR")
        {
            result.scenarioNumber = 1;
            result.scenarioName = "STRONG_BUY";
            result.priority = 1;
        }
        else // BELOW
        {
            result.scenarioNumber = 2;
            result.scenarioName = "BUY_PULLBACK";
            result.priority = 2;
        }
    }
    else if(m15StackValid && stackDirection == "BULLISH" && !m5PullbackValid)
    {
        // TREND VALID BUT PRICE NOT AT MA89 - WATCH
        result.scenarioNumber = 13;
        result.scenarioName = "WATCH_BULLISH";
        result.priority = 4;
    }
    
    // ─── BEARISH SCENARIOS ───
    else if(m15StackValid && stackDirection == "BEARISH" && m5PullbackValid && pullbackDirection == "BEARISH")
    {
        // STRONG SELL: M15 Stacked + M5 Price at MA89
        if(result.m1_position == "BELOW" || result.m1_position == "NEAR")
        {
            result.scenarioNumber = 22;
            result.scenarioName = "STRONG_SELL";
            result.priority = 1;
        }
        else // ABOVE
        {
            result.scenarioNumber = 23;
            result.scenarioName = "SELL_RALLY";
            result.priority = 2;
        }
    }
    else if(m15StackValid && stackDirection == "BEARISH" && !m5PullbackValid)
    {
        // TREND VALID BUT PRICE NOT AT MA89 - WATCH
        result.scenarioNumber = 14;
        result.scenarioName = "WATCH_BEARISH";
        result.priority = 4;
    }
    
    // ─── DIVERGENCE ───
    if(result.isDivergence && result.priority <= 3)
    {
        result.priority = 4;
        result.scenarioName = "WATCH_DIVERGENCE";
        result.scenarioNumber = 13;
    }
    else if(result.isDivergence)
    {
        result.scenarioNumber = 7;
        result.scenarioName = "AVOID";
        result.priority = 5;
    }
    
    m_lastCrossover = result;
    
    // ─── LOG CROSSINGS ───
    LogCrossings();

    return result;
}

//=============================================================================
// GET CROSSOVER STATE (Unchanged)
//=============================================================================
ENUM_CROSS_STATE CTrendManager::GetCrossoverState(double ma1, double ma2)
{
    double diff = ma1 - ma2;
    
    if(diff > m_crossoverBufferPoints)
        return CLEAR_UP;
    else if(diff < -m_crossoverBufferPoints)
        return CLEAR_DOWN;
    else if(diff > 0)
        return CROSS_UP;
    else if(diff < 0)
        return CROSS_DOWN;
    else
        return CROSS_ZONE;
}

//=============================================================================
// JUST CROSSED (Unchanged)
//=============================================================================
bool CTrendManager::JustCrossed(double ma1, double ma2, double prevMA1, double prevMA2)
{
    if(prevMA1 == 0 || prevMA2 == 0) return false;
    bool currentBull = ma1 > ma2;
    bool prevBull = prevMA1 > prevMA2;
    return (currentBull != prevBull);
}

//=============================================================================
// GET FALLBACK TREND (Unchanged)
//=============================================================================
STrendResult CTrendManager::GetFallbackTrend()
{
    STrendResult result;
    ZeroMemory(result);
    
    double closeBuffer[];
    ArraySetAsSeries(closeBuffer, true);
    
    if(CopyClose(m_symbol, m_trendTF, 0, 50, closeBuffer) < 50)
    {
        result.direction = m_hasValidDirection ? m_lastValidDirection : "NEUTRAL";
        result.strength = 25.0;
        result.trendConfidence = 25.0;
        result.description = "Fallback trend (price action)";
        return result;
    }
    
    double sma21 = 0;
    for(int i = 0; i < 21; i++) sma21 += closeBuffer[i];
    sma21 /= 21;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    m_cachePrice = currentPrice;
    
    if(currentPrice > sma21 * 1.003)
    {
        result.direction = "BULLISH";
        result.strength = 35.0;
        result.trendConfidence = 35.0;
        result.description = "Fallback: Price above 21-SMA (Bullish)";
    }
    else if(currentPrice < sma21 * 0.997)
    {
        result.direction = "BEARISH";
        result.strength = 35.0;
        result.trendConfidence = 35.0;
        result.description = "Fallback: Price below 21-SMA (Bearish)";
    }
    else
    {
        result.direction = m_hasValidDirection ? m_lastValidDirection : "NEUTRAL";
        result.strength = 20.0;
        result.trendConfidence = 20.0;
        result.description = "Fallback: Price near SMA - using last known direction";
    }
    
    if(result.direction != "NEUTRAL")
    {
        m_hasValidDirection = true;
        m_lastValidDirection = result.direction;
        m_lastValidTime = TimeCurrent();
    }
    
    return result;
}

//=============================================================================
// ═══ FEATURE EXTRACTION ═══
//=============================================================================
SMarketFeatures CTrendManager::ExtractFeatures()
{
    SMarketFeatures features;
    ZeroMemory(features);
    
    // ─── STEP 1: Get Raw Data from each TF ───
    // M15 (TREND)
    features.m15.direction = m_lastResult.direction;
    features.m15.strength = m_lastResult.strength;
    features.m15.ma21 = m_cacheMA21;
    features.m15.ma89 = m_cacheMA89;
    features.m15.ma200 = m_cacheMA200;
    features.m15.maStacked = CheckMAStacking(m_cacheMA21, m_cacheMA89, m_cacheMA200);
    features.m15.slope = CalculateMASlope(m_trendTF, 21, m_slopePeriods);
    
    // M5 (ENTRY)
    features.m5.direction = GetDirection_M5();
    features.m5.strength = GetStrength_M5();
    features.m5.ma21 = m_cacheMA21_M5;
    features.m5.ma89 = m_cacheMA89_M5;
    features.m5.ma200 = m_cacheMA200_M5;
    features.m5.maStacked = CheckMAStacking(m_cacheMA21_M5, m_cacheMA89_M5, m_cacheMA200_M5);
    features.m5.slope = CalculateMASlope(m_entryTF, 21, m_slopePeriods);
    
    // M1 (CONTEXT)
    features.m1.direction = (m_cachePrice_M1 > m_cacheMA21_M1) ? "BULLISH" : 
                            (m_cachePrice_M1 < m_cacheMA21_M1) ? "BEARISH" : "NEUTRAL";
    features.m1.strength = MathAbs(features.m1.direction == "BULLISH" ? 35.0 : 
                                   features.m1.direction == "BEARISH" ? 35.0 : 0);
    features.m1.ma21 = m_cacheMA21_M1;
    features.m1.ma89 = m_cacheMA89_M1;
    features.m1.ma200 = m_cacheMA200_M1;
    features.m1.maStacked = CheckMAStacking(m_cacheMA21_M1, m_cacheMA89_M1, m_cacheMA200_M1);
    features.m1.slope = CalculateMASlope(m_contextTF1, 21, m_slopePeriods);
    
    // H1 (CONTEXT)
    features.h1.direction = (m_cachePrice_H1 > m_cacheMA21_H1) ? "BULLISH" : 
                            (m_cachePrice_H1 < m_cacheMA21_H1) ? "BEARISH" : "NEUTRAL";
    features.h1.strength = MathAbs(features.h1.direction == "BULLISH" ? 35.0 : 
                                   features.h1.direction == "BEARISH" ? 35.0 : 0);
    features.h1.ma21 = m_cacheMA21_H1;
    features.h1.ma89 = m_cacheMA89_H1;
    features.h1.ma200 = m_cacheMA200_H1;
    features.h1.maStacked = CheckMAStacking(m_cacheMA21_H1, m_cacheMA89_H1, m_cacheMA200_H1);
    features.h1.slope = CalculateMASlope(m_contextTF2, 21, m_slopePeriods);
    
    // ─── STEP 2: Calculate Weighted Score ───
    double m1Dir = (features.m1.direction == "BULLISH") ? 1 : 
                   (features.m1.direction == "BEARISH") ? -1 : 0;
    double m5Dir = (features.m5.direction == "BULLISH") ? 1 : 
                   (features.m5.direction == "BEARISH") ? -1 : 0;
    double m15Dir = (features.m15.direction == "BULLISH") ? 1 : 
                    (features.m15.direction == "BEARISH") ? -1 : 0;
    double h1Dir = (features.h1.direction == "BULLISH") ? 1 : 
                   (features.h1.direction == "BEARISH") ? -1 : 0;
    
    double weightedDir = (m1Dir * m_m1Weight) + (m5Dir * m_m5Weight) + 
                         (m15Dir * m_m15Weight) + (h1Dir * m_h1Weight);
    features.weightedScore = 50 + (weightedDir * 50);
    features.weightedScore = MathMin(100, MathMax(0, features.weightedScore));
    
    // ─── STEP 3: Calculate Confidence ───
    features.confidence = CalculateConfidence(features);
    
    // ─── STEP 4: Calculate Alignment ───
    features.alignment = CalculateAlignment(features);
    
    // ─── STEP 5: Calculate Momentum ───
    features.momentum = CalculateMomentum(features);
    
    // ─── STEP 6: Calculate Pullback Depth ───
    features.pullbackDepth = CalculatePullbackDepth(features);
    
    // ─── STEP 7: Calculate Trend Duration ───
    features.trendDuration = CalculateTrendDuration(features);
    
    // ─── STEP 8: Calculate Volatility ───
    features.volatility = CalculateVolatility(features);
    
    // ─── STEP 9: Meta ───
    features.timestamp = TimeCurrent();
    features.currentPrice = m_cachePrice;
    features.isAligned = (features.alignment >= 70);
    features.dominantDirection = (features.m15.strength >= 50) ? features.m15.direction :
                                 (features.m5.strength >= 40) ? features.m5.direction :
                                 features.m1.direction;
    features.dominanceLevel = (features.m15.strength / 100 * 40) +
                              (features.m5.strength / 100 * 35) +
                              (features.m1.strength / 100 * 15) +
                              (features.h1.strength / 100 * 10);
    
    m_lastFeatures = features;
    
    return features;
}

//=============================================================================
// CALCULATE CONFIDENCE (Unchanged)
//=============================================================================
double CTrendManager::CalculateConfidence(SMarketFeatures &features)
{
    double conf = 0;
    int factors = 0;
    
    // Factor 1: M15 Strength (25%)
    if(features.m15.strength >= 60) { conf += 25; factors++; }
    else if(features.m15.strength >= 40) { conf += 18; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 2: M5 Strength (20%)
    if(features.m5.strength >= 60) { conf += 20; factors++; }
    else if(features.m5.strength >= 40) { conf += 15; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 3: M15 vs M5 Alignment (15%)
    if(features.m15.direction == features.m5.direction) { conf += 15; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 4: H1 Context (10%)
    if(features.h1.direction == features.m15.direction) { conf += 10; factors++; }
    else { conf += 3; factors++; }
    
    // Factor 5: M1 Context (10%)
    if(features.m1.direction == features.m5.direction) { conf += 10; factors++; }
    else if(features.m1.direction == "NEUTRAL") { conf += 5; factors++; }
    else { conf += 2; factors++; }
    
    // Factor 6: Momentum (10%)
    if(features.momentum > 20) { conf += 10; factors++; }
    else if(features.momentum > 0) { conf += 7; factors++; }
    else { conf += 3; factors++; }
    
    // Factor 7: Volatility (10%)
    if(features.volatility < 20) { conf += 10; factors++; }
    else if(features.volatility < 30) { conf += 5; factors++; }
    else { conf += 2; factors++; }
    
    return (factors > 0) ? MathMin(100, MathMax(0, conf / factors * 100)) : 50;
}

//=============================================================================
// CALCULATE ALIGNMENT (Unchanged)
//=============================================================================
double CTrendManager::CalculateAlignment(SMarketFeatures &features)
{
    double align = 0;
    int factors = 0;
    
    // M15 vs M5 (40%)
    if(features.m15.direction == features.m5.direction) { align += 40; factors++; }
    else { align += 5; factors++; }
    
    // M15 vs H1 (25%)
    if(features.m15.direction == features.h1.direction) { align += 25; factors++; }
    else { align += 5; factors++; }
    
    // M5 vs M1 (20%)
    if(features.m5.direction == features.m1.direction) { align += 20; factors++; }
    else { align += 5; factors++; }
    
    // M5 vs H1 (15%)
    if(features.m5.direction == features.h1.direction) { align += 15; factors++; }
    else { align += 5; factors++; }
    
    return (factors > 0) ? align : 50;
}

//=============================================================================
// CALCULATE MOMENTUM (Unchanged)
//=============================================================================
double CTrendManager::CalculateMomentum(SMarketFeatures &features)
{
    double mom = 0;
    int factors = 0;
    
    mom += features.m15.slope * 100; factors++;
    mom += features.m5.slope * 100; factors++;
    mom += features.m1.slope * 100; factors++;
    mom += features.h1.slope * 100; factors++;
    
    return (factors > 0) ? mom / factors : 0;
}

//=============================================================================
// CALCULATE PULLBACK DEPTH (Unchanged)
//=============================================================================
double CTrendManager::CalculatePullbackDepth(SMarketFeatures &features)
{
    if(features.m5.direction == "BULLISH" && features.m1.direction == "BEARISH")
    {
        double m5High = features.m5.ma21;
        double m1Low = features.m1.ma21;
        if(m5High > m1Low && m5High > 0)
            return ((m5High - m1Low) / m5High) * 100;
    }
    else if(features.m5.direction == "BEARISH" && features.m1.direction == "BULLISH")
    {
        double m5Low = features.m5.ma21;
        double m1High = features.m1.ma21;
        if(m1High > m5Low && m5Low > 0)
            return ((m1High - m5Low) / m5Low) * 100;
    }
    return 0;
}

//=============================================================================
// CALCULATE TREND DURATION (Unchanged)
//=============================================================================
double CTrendManager::CalculateTrendDuration(SMarketFeatures &features)
{
    int count = 0;
    string dir = features.m15.direction;
    if(dir == "NEUTRAL") return 0;
    
    for(int i = 0; i < 30; i++)
    {
        double ma21 = GetMAValue(m_ma21_handle, i);
        double ma89 = GetMAValue(m_ma89_handle, i);
        double ma200 = GetMAValue(m_ma200_handle, i);
        if(ma21 == 0 || ma89 == 0 || ma200 == 0) break;
        
        bool isBullish = (ma21 > ma89 && ma89 > ma200);
        bool isBearish = (ma21 < ma89 && ma89 < ma200);
        string d = isBullish ? "BULLISH" : isBearish ? "BEARISH" : "NEUTRAL";
        
        if(d == dir) count++;
        else break;
    }
    return count;
}

//=============================================================================
// CALCULATE VOLATILITY (Unchanged)
//=============================================================================
double CTrendManager::CalculateVolatility(SMarketFeatures &features)
{
    double atr = iATR(m_symbol, m_trendTF, 14);
    if(atr == 0) return 15.0;
    
    double avgATR = 0;
    int count = 0;
    for(int i = 1; i < 100; i++)
    {
        double atr_i = iATR(m_symbol, m_trendTF, 14);
        if(atr_i > 0) { avgATR += atr_i; count++; }
    }
    if(count > 0) avgATR /= count;
    else avgATR = atr;
    
    if(avgATR == 0) return 15.0;
    return (atr / avgATR) * 100;
}

//=============================================================================
// ═══ DECISION ENGINE ═══
//=============================================================================
STrendRecommendation CTrendManager::MakeDecision(SMarketFeatures &features)
{
    STrendRecommendation rec;
    ZeroMemory(rec);
    rec.features = features;
    rec.timestamp = TimeCurrent();
    rec.currentPrice = features.currentPrice;
    
    // ─── STEP 1: Direction ───
    if(features.weightedScore >= 50 && features.confidence >= 30)
    {
        rec.action = "ENTER_LONG";
        rec.actionCode = 1;
    }
    else if(features.weightedScore < 50 && features.confidence >= 30)
    {
        rec.action = "ENTER_SHORT";
        rec.actionCode = -1;
    }
    else
    {
        rec.action = "HOLD";
        rec.actionCode = 0;
    }
    
    // ─── STEP 2: Position Size ───
    rec.positionSize = CalculatePositionSize(features);
    
    // ─── STEP 3: Timing ───
    rec.timing = GetTiming(features.momentum);
    rec.waitBars = (rec.timing == "NOW") ? 0 : (rec.timing == "SOON") ? 2 : 5;
    
    // ─── STEP 4: Risk ───
    rec.riskLevel = GetRiskLevel(features.volatility);
    rec.riskPercent = (rec.riskLevel == "LOW") ? 1.0 : 
                      (rec.riskLevel == "MEDIUM") ? 0.5 : 0.25;
    
    // ─── STEP 5: Confidence ───
    rec.confidenceLevel = GetConfidenceLevel(features.confidence);
    rec.confidenceScore = features.confidence;
    
    // ─── STEP 6: SL/TP ───
    rec.entryPrice = features.currentPrice;
    rec.stopLoss = 0;
    rec.takeProfit = 0;
    rec.riskReward = 0;
    
    // ─── STEP 7: Ready Check ───
    rec.isReady = (rec.actionCode != 0 && 
                   rec.positionSize > 0 && 
                   features.confidence >= 30 &&
                   features.alignment >= 40);
    
    rec.isRejected = !rec.isReady;
    rec.rejectionReason = rec.isReady ? "" : GetRejectionReason(features);
    
    // ─── STEP 8: Reasoning ───
    rec.primaryReason = GeneratePrimaryReason(features, rec);
    GenerateSecondaryReasons(features, rec);
    rec.fullNarrative = GenerateFullNarrative(features, rec);
    
    m_lastRecommendation = rec;
    
    return rec;
}

//=============================================================================
// CALCULATE POSITION SIZE (Unchanged)
//=============================================================================
double CTrendManager::CalculatePositionSize(SMarketFeatures &features)
{
    double size = 1.0;
    
    if(features.weightedScore >= 60) size *= 1.5;
    else if(features.weightedScore >= 45) size *= 1.0;
    else if(features.weightedScore >= 30) size *= 0.5;
    else size = 0;
    
    if(features.confidence >= 70) size *= 1.3;
    else if(features.confidence >= 50) size *= 1.0;
    else size *= 0.5;
    
    if(features.m15.direction == features.m5.direction) size *= 1.2;
    else size *= 0.7;
    
    if(features.h1.direction == features.m15.direction) size *= 1.1;
    else if(features.h1.direction == "NEUTRAL") size *= 1.0;
    else size = 0;
    
    if(features.pullbackDepth >= 3.0 && features.pullbackDepth <= 5.0)
        size *= 1.2;
    else if(features.pullbackDepth > 8.0)
        size = 0;
    
    if(features.volatility >= 30) size = 0;
    else if(features.volatility >= 20) size *= 0.7;
    
    return MathMin(3.0, MathMax(0.0, size));
}

//=============================================================================
// GET TIMING (Unchanged)
//=============================================================================
string CTrendManager::GetTiming(double momentum)
{
    if(momentum > 20) return "NOW";
    else if(momentum > 0) return "SOON";
    else if(momentum > -20) return "WAIT";
    else return "NEVER";
}

//=============================================================================
// GET RISK LEVEL (Unchanged)
//=============================================================================
string CTrendManager::GetRiskLevel(double volatility)
{
    if(volatility < 15) return "LOW";
    else if(volatility < 25) return "MEDIUM";
    else if(volatility < 35) return "HIGH";
    else return "VERY_HIGH";
}

//=============================================================================
// GET CONFIDENCE LEVEL (Unchanged)
//=============================================================================
string CTrendManager::GetConfidenceLevel(double confidence)
{
    if(confidence >= 70) return "HIGH";
    else if(confidence >= 50) return "MEDIUM";
    else return "LOW";
}

//=============================================================================
// GENERATE PRIMARY REASON (Unchanged)
//=============================================================================
string CTrendManager::GeneratePrimaryReason(SMarketFeatures &features, STrendRecommendation &rec)
{
    string reason = "";
    
    if(rec.actionCode == 1)
        reason = "BULLISH setup: ";
    else if(rec.actionCode == -1)
        reason = "BEARISH setup: ";
    else
        return "No clear direction - waiting for better conditions";
    
    if(features.m15.strength >= 50)
        reason += StringFormat("Strong M15 trend (%.0f%%), ", features.m15.strength);
    else if(features.m15.strength >= 30)
        reason += StringFormat("Moderate M15 trend (%.0f%%), ", features.m15.strength);
    
    if(features.m5.strength >= 50)
        reason += StringFormat("M5 confirms (%.0f%%), ", features.m5.strength);
    
    if(features.h1.direction == features.m15.direction)
        reason += "H1 aligns, ";
    else if(features.h1.direction != "NEUTRAL")
        reason += "H1 opposes - CAUTION, ";
    
    if(features.pullbackDepth >= 3.0 && features.pullbackDepth <= 5.0)
        reason += StringFormat("optimal pullback (%.1f%%), ", features.pullbackDepth);
    else if(features.pullbackDepth > 0)
        reason += StringFormat("pullback at %.1f%%, ", features.pullbackDepth);
    
    if(features.confidence >= 70)
        reason += "high confidence (" + DoubleToString(features.confidence, 0) + "%)";
    else if(features.confidence >= 50)
        reason += "moderate confidence (" + DoubleToString(features.confidence, 0) + "%)";
    else
        reason += "low confidence (" + DoubleToString(features.confidence, 0) + "%)";
    
    return reason;
}

//=============================================================================
// GENERATE SECONDARY REASONS (Unchanged)
//=============================================================================
void CTrendManager::GenerateSecondaryReasons(SMarketFeatures &features, STrendRecommendation &rec)
{
    rec.reasonCount = 0;
    
    if(features.h1.direction == features.m15.direction)
        rec.secondaryReasons[rec.reasonCount++] = "H1 aligns with trend (macro support)";
    else if(features.h1.direction != "NEUTRAL")
        rec.secondaryReasons[rec.reasonCount++] = "H1 opposes trend - CAUTION";
    else
        rec.secondaryReasons[rec.reasonCount++] = "H1 neutral - no macro filter";
    
    if(features.m5.direction == features.m15.direction)
        rec.secondaryReasons[rec.reasonCount++] = "M5 confirms trend (entry ready)";
    else
        rec.secondaryReasons[rec.reasonCount++] = "M5 divergence - wait for alignment";
    
    if(features.momentum > 20)
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Strong momentum (+%.1f)", features.momentum);
    else if(features.momentum > 0)
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Positive momentum (%.1f)", features.momentum);
    else
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Negative momentum (%.1f)", features.momentum);
    
    if(features.volatility < 20)
        rec.secondaryReasons[rec.reasonCount++] = "Low volatility - favorable";
    else if(features.volatility < 30)
        rec.secondaryReasons[rec.reasonCount++] = "Normal volatility";
    else
        rec.secondaryReasons[rec.reasonCount++] = "High volatility - caution";
    
    if(features.m15.maStacked)
        rec.secondaryReasons[rec.reasonCount++] = "MAs stacked on M15 (21>89>200)";
    else
        rec.secondaryReasons[rec.reasonCount++] = "MAs not stacked - weaker trend";
    
    if(features.m1.direction == features.m5.direction)
        rec.secondaryReasons[rec.reasonCount++] = "M1 fine-tunes entry";
    else if(features.m1.direction != "NEUTRAL")
        rec.secondaryReasons[rec.reasonCount++] = "M1 opposes - wait for entry signal";
}

//=============================================================================
// GENERATE FULL NARRATIVE (Unchanged)
//=============================================================================
string CTrendManager::GenerateFullNarrative(SMarketFeatures &features, STrendRecommendation &rec)
{
    string narrative = "";
    
    narrative += StringFormat("M15: %s (%.0f%%), M5: %s (%.0f%%), M1: %s (%.0f%%), H1: %s (%.0f%%). ",
        features.m15.direction, features.m15.strength,
        features.m5.direction, features.m5.strength,
        features.m1.direction, features.m1.strength,
        features.h1.direction, features.h1.strength);
    
    narrative += StringFormat("Score: %.1f%%, Confidence: %.1f%%, Alignment: %.1f%%. ",
        features.weightedScore, features.confidence, features.alignment);
    
    if(features.pullbackDepth > 0)
        narrative += StringFormat("Pullback: %.1f%%. ", features.pullbackDepth);
    
    narrative += StringFormat("Duration: %.0f bars, Volatility: %.1f%%. ",
        features.trendDuration, features.volatility);
    
    if(rec.actionCode == 1)
        narrative += "Recommendation: ENTER_LONG with " + DoubleToString(rec.positionSize, 2) + " lots. ";
    else if(rec.actionCode == -1)
        narrative += "Recommendation: ENTER_SHORT with " + DoubleToString(rec.positionSize, 2) + " lots. ";
    else
        narrative += "Recommendation: HOLD - wait for better conditions. ";
    
    narrative += rec.primaryReason;
    
    return narrative;
}

//=============================================================================
// GET REJECTION REASON (Unchanged)
//=============================================================================
string CTrendManager::GetRejectionReason(SMarketFeatures &features)
{
    string reasons = "";
    int count = 0;
    
    if(features.weightedScore < 30 || features.weightedScore > 70)
    {
        if(count > 0) reasons += " | ";
        reasons += "Score outside optimal range (" + DoubleToString(features.weightedScore, 0) + "%)";
        count++;
    }
    
    if(features.confidence < 30)
    {
        if(count > 0) reasons += " | ";
        reasons += "Confidence too low (" + DoubleToString(features.confidence, 0) + "%)";
        count++;
    }
    
    if(features.alignment < 40)
    {
        if(count > 0) reasons += " | ";
        reasons += "Alignment too low (" + DoubleToString(features.alignment, 0) + "%)";
        count++;
    }
    
    if(features.m15.direction != features.m5.direction)
    {
        if(count > 0) reasons += " | ";
        reasons += "M15/M5 divergence";
        count++;
    }
    
    if(features.h1.direction != features.m15.direction && features.h1.direction != "NEUTRAL")
    {
        if(count > 0) reasons += " | ";
        reasons += "H1 opposes trend";
        count++;
    }
    
    if(features.pullbackDepth > 8.0 && features.pullbackDepth > 0)
    {
        if(count > 0) reasons += " | ";
        reasons += "Pullback too deep (" + DoubleToString(features.pullbackDepth, 1) + "%)";
        count++;
    }
    
    if(features.volatility >= 30)
    {
        if(count > 0) reasons += " | ";
        reasons += "Volatility too high (" + DoubleToString(features.volatility, 0) + "%)";
        count++;
    }
    
    return (reasons == "") ? "Unknown reason" : reasons;
}

//=============================================================================
// ═══ PRIMARY ANALYSIS - AnalyzeTrend v4.02 ═══
//=============================================================================
STrendResult CTrendManager::AnalyzeTrend()
{
    LOG_DEBUG("AnalyzeTrend called for " + m_symbol, g_debugTrendManager);
    
    STrendResult result;
    ZeroMemory(result);
    
    if(!m_isInitialized)
    {
        if(!Initialize())
            return GetFallbackTrend();
    }
    
    // Check for new bars and update caches
    if(IsNewBar(m_trendTF, m_lastBarTime_M15)) UpdateCache(m_trendTF);
    if(IsNewBar(m_entryTF, m_lastBarTime_M5)) UpdateCache(m_entryTF);
    if(IsNewBar(m_contextTF1, m_lastBarTime_M1)) UpdateCache(m_contextTF1);
    if(IsNewBar(m_contextTF2, m_lastBarTime_H1)) UpdateCache(m_contextTF2);
    
    // Ensure previous values exist
    UpdatePreviousValues();
    
    // Validate data
    if(m_cacheMA21 == 0 || m_cacheMA89 == 0 || m_cacheMA200 == 0 || m_cachePrice == 0)
    {
        UpdateCache(m_trendTF);
        if(m_cacheMA21 == 0 || m_cacheMA89 == 0 || m_cacheMA200 == 0 || m_cachePrice == 0)
            return GetFallbackTrend();
    }
    
    // ─── STEP 1: COLLECT SIGNALS (10 signals, total weight = 10.0) ───
    double bullSignals = 0, bearSignals = 0;
    
    // ═══════════════════════════════════════════════════════════════
    // H1 (10%) - MACRO CONTEXT
    // ═══════════════════════════════════════════════════════════════
    if(m_cacheMA200_H1 > 0)
    {
        if(CheckPriceAboveMA(m_cachePrice_H1, m_cacheMA200_H1))
            bullSignals += 1.0;
        else
            bearSignals += 1.0;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // M15 (40%) - PRIMARY TREND
    // ═══════════════════════════════════════════════════════════════
    if(CheckPriceAboveMA(m_cachePrice, m_cacheMA200))
        bullSignals += 1.33;
    else
        bearSignals += 1.33;
    
    bool m15BullStack = (m_cacheMA21 > m_cacheMA89 && m_cacheMA89 > m_cacheMA200);
    bool m15BearStack = (m_cacheMA21 < m_cacheMA89 && m_cacheMA89 < m_cacheMA200);
    if(m15BullStack) bullSignals += 1.33;
    else if(m15BearStack) bearSignals += 1.33;
    
    double m15Slope21 = CalculateMASlope(m_trendTF, 21, m_slopePeriods);
    double m15Slope89 = CalculateMASlope(m_trendTF, 89, m_slopePeriods);
    if(m15Slope21 > 0 && m15Slope89 > 0) bullSignals += 1.34;
    else if(m15Slope21 < 0 && m15Slope89 < 0) bearSignals += 1.34;
    
    // ═══════════════════════════════════════════════════════════════
    // M5 (35%) - MAIN ENTRY
    // ═══════════════════════════════════════════════════════════════
    if(m_cacheMA200_M5 > 0)
    {
        if(CheckPriceAboveMA(m_cachePrice_M5, m_cacheMA200_M5))
            bullSignals += 0.875;
        else
            bearSignals += 0.875;
    }
    
    if(m_cacheMA21_M5 > 0)
    {
        if(CheckPriceAboveMA(m_cachePrice_M5, m_cacheMA21_M5))
            bullSignals += 0.875;
        else
            bearSignals += 0.875;
    }
    
    if(m_cacheMA89_M5 > 0)
    {
        if(CheckPriceAboveMA(m_cachePrice_M5, m_cacheMA89_M5))
            bullSignals += 0.875;
        else
            bearSignals += 0.875;
    }
    
    bool m5BullStack = (m_cacheMA21_M5 > m_cacheMA89_M5 && m_cacheMA89_M5 > m_cacheMA200_M5);
    bool m5BearStack = (m_cacheMA21_M5 < m_cacheMA89_M5 && m_cacheMA89_M5 < m_cacheMA200_M5);
    if(m5BullStack) bullSignals += 0.875;
    else if(m5BearStack) bearSignals += 0.875;
    
    // ═══════════════════════════════════════════════════════════════
    // M1 (15%) - CONTEXT (Fine-tuning)
    // ═══════════════════════════════════════════════════════════════
    if(m_cacheMA21_M1 > 0)
    {
        if(CheckPriceAboveMA(m_cachePrice_M1, m_cacheMA21_M1))
            bullSignals += 0.75;
        else
            bearSignals += 0.75;
    }
    
    bool m1BullStack = (m_cacheMA21_M1 > m_cacheMA89_M1 && m_cacheMA89_M1 > m_cacheMA200_M1);
    bool m1BearStack = (m_cacheMA21_M1 < m_cacheMA89_M1 && m_cacheMA89_M1 < m_cacheMA200_M1);
    if(m1BullStack) bullSignals += 0.75;
    else if(m1BearStack) bearSignals += 0.75;
    
    // Store signals
    result.bullSignals = bullSignals;
    result.bearSignals = bearSignals;
    
    // ─── STEP 2: CALCULATE SIGNAL RATIO ───
    double totalSignals = bullSignals + bearSignals;
    double signalRatio = (totalSignals > 0) ? bullSignals / totalSignals : 0.5;
    result.signalRatio = signalRatio;
    
    // ─── STEP 3: DETERMINE DIRECTION ───
    if(signalRatio >= 0.55)
    {
        result.direction = "BULLISH";
    }
    else if(signalRatio <= 0.45)
    {
        result.direction = "BEARISH";
    }
    else
    {
        result.direction = "NEUTRAL";
        result.strength = 0;
        result.trendConfidence = 0;
    }
    
    // ─── STEP 4: CALCULATE STRENGTH ───
    result.strength = MathAbs(signalRatio - 0.5) * 200.0;
    result.strength = MathMin(100.0, result.strength);
    result.trendConfidence = result.strength;
    
    // ─── STEP 5: APPLY WEAKNESS FILTER ───
    if(result.strength < m_weakThreshold && result.direction != "NEUTRAL")
    {
        result.direction = "NEUTRAL";
        result.strength = 0;
        result.trendConfidence = 0;
        result.description = "Trend too weak - filtered out";
    }
    
    // ─── DESCRIPTION ───
    if(result.direction == "BULLISH")
    {
        if(result.strength >= m_strongThreshold) 
            result.description = "Strong Bullish Trend (M15)";
        else if(result.strength >= m_moderateThreshold) 
            result.description = "Bullish Trend (M15)";
        else if(result.strength >= m_weakThreshold) 
            result.description = "Mild Bullish Bias (M15)";
        else 
            result.description = "Very Weak Bullish (Filtered)";
    }
    else if(result.direction == "BEARISH")
    {
        if(result.strength >= m_strongThreshold) 
            result.description = "Strong Bearish Trend (M15)";
        else if(result.strength >= m_moderateThreshold) 
            result.description = "Bearish Trend (M15)";
        else if(result.strength >= m_weakThreshold) 
            result.description = "Mild Bearish Bias (M15)";
        else 
            result.description = "Very Weak Bearish (Filtered)";
    }
    else
        result.description = "Neutral / Sideways";
    
    // ─── STORE VALID DIRECTION ───
    if(result.direction != "NEUTRAL")
    {
        m_hasValidDirection = true;
        m_lastValidDirection = result.direction;
        m_lastValidTime = TimeCurrent();
    }
    else if(m_hasValidDirection)
        result.description += " (Last known: " + m_lastValidDirection + ")";
    
    // ─── NARRATIVE ───
    result.narrative = GenerateNarrative(result);
    result.lastUpdate = m_lastBarTime_M15;
    m_lastResult = result;
    
    // ─── DETECT CROSSOVER ENHANCED ───
    m_lastCrossover = DetectCrossoverEnhanced();

    // ─── EXTRACT FEATURES AND MAKE DECISION ───
    m_lastFeatures = ExtractFeatures();
    m_lastRecommendation = MakeDecision(m_lastFeatures);

    // ─── LOG ONLY ON VALID SIGNALS (Priority 1-2 AND Direction != NEUTRAL) ───
    if((m_lastCrossover.priority == 1 || m_lastCrossover.priority == 2) && 
        result.direction != "NEUTRAL")
    {
    LOG_INFO("========================================", g_debugTrendManager);
    LOG_INFO("✅✅✅ TRADE SIGNAL DETECTED ✅✅✅", g_debugTrendManager);
    LOG_INFO("  Direction: " + result.direction + " | Strength: " + DoubleToString(result.strength, 1) + "%", g_debugTrendManager);
    LOG_INFO("  Scenario: " + m_lastCrossover.scenarioName + " (Priority " + IntegerToString(m_lastCrossover.priority) + ")", g_debugTrendManager);
    LOG_INFO("  M15: MA21=" + DoubleToString(m_cacheMA21, _Digits) + 
                " MA89=" + DoubleToString(m_cacheMA89, _Digits) + 
                " MA200=" + DoubleToString(m_cacheMA200, _Digits), g_debugTrendManager);
    LOG_INFO("  M5: Price=" + DoubleToString(m_cachePrice_M5, _Digits) + 
                " MA89=" + DoubleToString(m_cacheMA89_M5, _Digits) + 
                " MA200=" + DoubleToString(m_cacheMA200_M5, _Digits), g_debugTrendManager);
    LOG_INFO("  M1 Position: " + m_lastCrossover.m1_position + 
                " (" + DoubleToString(m_lastCrossover.m1_distance, 1) + " pts)", g_debugTrendManager);
    LOG_INFO("  Action: " + m_lastRecommendation.action + 
                " | Size: " + DoubleToString(m_lastRecommendation.positionSize, 2) + " lots", g_debugTrendManager);
    LOG_INFO("========================================", g_debugTrendManager);
    }
    else if(m_lastCrossover.priority == 3)
    {
    // Priority 3 - Only log briefly (pullback entries are weaker)
    LOG_DEBUG("🔵 Priority 3 signal: " + m_lastCrossover.scenarioName + 
                " | Direction: " + result.direction, g_debugTrendManager);
    }
    else if(m_lastCrossover.priority >= 4)
    {
    // Priority 4-6 - Log only if in debug mode
    LOG_DEBUG("⏳ Priority " + IntegerToString(m_lastCrossover.priority) + 
                ": " + m_lastCrossover.scenarioName + " (Waiting)", g_debugTrendManager);
    }

    LOG_DEBUG("Analysis complete - Direction: " + result.direction + 
            " Strength: " + DoubleToString(result.strength, 1) + "%", g_debugTrendManager);
    LOG_DEBUG("Crossover - Scenario: " + m_lastCrossover.scenarioName + 
            " Priority: " + IntegerToString(m_lastCrossover.priority), g_debugTrendManager);
    
    return result;
}

//=============================================================================
// ═══ ANALYZE FULL - Returns Features + Recommendation ═══
//=============================================================================
void CTrendManager::AnalyzeFull(SMarketFeatures &features, STrendRecommendation &recommendation)
{
    AnalyzeTrend();
    features = m_lastFeatures;
    recommendation = m_lastRecommendation;
}

//=============================================================================
// GENERATE NARRATIVE (Unchanged)
//=============================================================================
string CTrendManager::GenerateNarrative(const STrendResult &result)
{
    string narrative = "";
    
    if(result.direction == "BULLISH")
    {
        narrative = "Bullish trend confirmed (M15). ";
        if(result.strength >= m_strongThreshold)
            narrative += "Strong momentum with MA21>MA89>MA200 and price above MA200. ";
        else if(result.strength >= m_moderateThreshold)
            narrative += "Positive momentum with price above MA200 and bullish MA alignment. ";
        else if(result.strength >= m_weakThreshold)
            narrative += "Mild bullish bias with some confirmations. ";
        else
            narrative += "Very weak bullish signals - likely filtered. ";
    }
    else if(result.direction == "BEARISH")
    {
        narrative = "Bearish trend confirmed (M15). ";
        if(result.strength >= m_strongThreshold)
            narrative += "Strong downward momentum with price below all MAs. ";
        else if(result.strength >= m_moderateThreshold)
            narrative += "Negative momentum with price below MA200 and bearish MA alignment. ";
        else if(result.strength >= m_weakThreshold)
            narrative += "Mild bearish bias with some confirmations. ";
        else
            narrative += "Very weak bearish signals - likely filtered. ";
    }
    else
    {
        narrative = "Market is neutral with conflicting signals. ";
        if(m_hasValidDirection)
            narrative += "Last known direction: " + m_lastValidDirection + ". ";
        narrative += StringFormat("Signal ratio: %.1f%%. ", result.signalRatio * 100);
        narrative += "Market is in the 45-55% neutral zone. Wait for clearer direction.";
    }
    
    narrative += StringFormat(" Confidence: %.1f%%, Strength: %.1f%%.", 
                            result.trendConfidence, result.strength);
    
    return narrative;
}

//=============================================================================
// QUICK ACCESS METHODS (Unchanged)
//=============================================================================
string CTrendManager::GetDirection()
{
    if(m_isInitialized)
    {
        AnalyzeTrend();
        if(m_lastResult.direction != "NEUTRAL")
            return m_lastResult.direction;
    }
    return m_hasValidDirection ? m_lastValidDirection : "NEUTRAL";
}

double CTrendManager::GetStrength()
{
    if(m_isInitialized)
    {
        AnalyzeTrend();
        if(m_lastResult.strength > 0) return m_lastResult.strength;
    }
    return 20.0;
}

bool CTrendManager::IsBullish() { return GetDirection() == "BULLISH"; }
bool CTrendManager::IsBearish() { return GetDirection() == "BEARISH"; }

bool CTrendManager::IsStrongTrend()
{
    double strength = GetStrength();
    return strength >= m_strongThreshold;
}

double CTrendManager::GetTrendConfidence() { return GetStrength(); }
double CTrendManager::GetSignalRatio()
{
    if(m_isInitialized)
    {
        AnalyzeTrend();
        if(m_lastResult.signalRatio > 0) return m_lastResult.signalRatio;
    }
    return 0.5;
}

//=============================================================================
// ENTRY-SPECIFIC METHODS (M5)
//=============================================================================
bool CTrendManager::IsTrending()
{
    return GetStrength() >= m_weakThreshold;
}

bool CTrendManager::IsEntryCompatible()
{
    return GetStrength() >= m_moderateThreshold;
}

bool CTrendManager::IsTrendClear()
{
    return GetStrength() >= m_strongThreshold;
}

double CTrendManager::GetEntryScore()
{
    double strength = GetStrength();
    string direction = GetDirection();
    if(direction == "NEUTRAL") return 0;
    
    double score = 0;
    if(strength >= m_strongThreshold)
        score = 83 + (strength - m_strongThreshold) / (100 - m_strongThreshold) * 17;
    else if(strength >= m_moderateThreshold)
        score = 66 + (strength - m_moderateThreshold) / (m_strongThreshold - m_moderateThreshold) * 17;
    else if(strength >= m_weakThreshold)
        score = 33 + (strength - m_weakThreshold) / (m_moderateThreshold - m_weakThreshold) * 33;
    else
        score = strength / m_weakThreshold * 33;
    
    return MathMin(100.0, MathMax(0, score));
}

string CTrendManager::GetEntryLabel()
{
    string direction = GetDirection();
    double strength = GetStrength();
    
    if(direction == "NEUTRAL") return "NEUTRAL (No Entry)";
    if(strength >= m_strongThreshold) return direction + " STRONG (Ideal Entry)";
    if(strength >= m_moderateThreshold) return direction + " MODERATE (Entry OK)";
    if(strength >= m_weakThreshold) return direction + " WEAK (Caution)";
    return direction + " VERY WEAK (Avoid)";
}

//=============================================================================
// TRADING FILTERS (Unchanged)
//=============================================================================
bool CTrendManager::ShouldAllowLongs()
{
    if(!IsBullish()) return false;
    if(!IsBullish_M5()) return false;
    
    if(m_cacheMA200_H1 > 0)
    {
        string h1Dir = (m_cachePrice_H1 > m_cacheMA200_H1) ? "BULLISH" : "BEARISH";
        if(h1Dir == "BEARISH") return false;
    }
    
    return IsEntryCompatible();
}

bool CTrendManager::ShouldAllowShorts()
{
    if(!IsBearish()) return false;
    if(!IsBearish_M5()) return false;
    
    if(m_cacheMA200_H1 > 0)
    {
        string h1Dir = (m_cachePrice_H1 > m_cacheMA200_H1) ? "BULLISH" : "BEARISH";
        if(h1Dir == "BULLISH") return false;
    }
    
    return IsEntryCompatible();
}

bool CTrendManager::ShouldAllowEntries()
{
    return IsEntryAllowed();
}

bool CTrendManager::IsEntryAllowed()
{
    string direction = GetDirection();
    if(direction == "NEUTRAL") return false;
    
    string m5Dir = GetDirection_M5();
    if(m5Dir != direction) return false;
    
    if(m_cacheMA200_H1 > 0)
    {
        string h1Dir = (m_cachePrice_H1 > m_cacheMA200_H1) ? "BULLISH" : "BEARISH";
        if(h1Dir != direction && h1Dir != "NEUTRAL") return false;
    }
    
    return GetStrength() >= m_moderateThreshold;
}

bool CTrendManager::ShouldAllowEntry()
{
    return IsEntryAllowed();
}

//=============================================================================
// M5 ENTRY METHODS (Unchanged)
//=============================================================================
string CTrendManager::GetDirection_M5()
{
    if(!m_isInitialized) return "NEUTRAL";
    UpdateCache(m_entryTF);
    
    if(m_cacheMA21_M5 == 0 || m_cacheMA200_M5 == 0) return "NEUTRAL";
    
    bool bullStack = (m_cacheMA21_M5 > m_cacheMA89_M5 && m_cacheMA89_M5 > m_cacheMA200_M5);
    bool bearStack = (m_cacheMA21_M5 < m_cacheMA89_M5 && m_cacheMA89_M5 < m_cacheMA200_M5);
    
    if(bullStack && m_cachePrice_M5 > m_cacheMA200_M5) return "BULLISH";
    if(bearStack && m_cachePrice_M5 < m_cacheMA200_M5) return "BEARISH";
    return "NEUTRAL";
}

double CTrendManager::GetStrength_M5()
{
    string dir = GetDirection_M5();
    if(dir == "BULLISH") return 45.0;
    if(dir == "BEARISH") return 45.0;
    return 25.0;
}

bool CTrendManager::IsBullish_M5() { return GetDirection_M5() == "BULLISH"; }
bool CTrendManager::IsBearish_M5() { return GetDirection_M5() == "BEARISH"; }

//=============================================================================
// INITIALIZE (Unchanged)
//=============================================================================
bool CTrendManager::Initialize()
{
    LOG_DEBUG("Initialize called for " + m_symbol, g_debugTrendManager);
    
    if(m_isInitialized) return true;
    
    CreateHandles();
    
    if(m_ma21_handle == INVALID_HANDLE || m_ma89_handle == INVALID_HANDLE || 
       m_ma200_handle == INVALID_HANDLE)
    {
        LOG_ERROR("❌ Failed to create M15 indicator handles");
        return false;
    }
    
    if(Bars(m_symbol, m_trendTF) < 200)
    {
        LOG_WARNING("Not enough bars for " + m_symbol + " - Need 200 for MA200");
        return false;
    }
    
    m_isInitialized = true;
    m_lastBarTime_M15 = iTime(m_symbol, m_trendTF, 0);
    m_lastBarTime_M5 = iTime(m_symbol, m_entryTF, 0);
    m_lastBarTime_M1 = iTime(m_symbol, m_contextTF1, 0);
    m_lastBarTime_H1 = iTime(m_symbol, m_contextTF2, 0);
    
    UpdateCache(m_trendTF);
    UpdateCache(m_entryTF);
    UpdateCache(m_contextTF1);
    UpdateCache(m_contextTF2);
    UpdatePreviousValues();
    
    // Initialize log state
    InitLogState();
    
    m_lastResult = AnalyzeTrend();
    
    if(m_lastResult.direction != "NEUTRAL")
    {
        m_hasValidDirection = true;
        m_lastValidDirection = m_lastResult.direction;
        m_lastValidTime = TimeCurrent();
    }
    
    LOG_INFO("TrendManager v4.02 initialized for " + m_symbol, g_debugTrendManager);
    LOG_INFO("  Initial trend: " + m_lastResult.direction + " (Strength: " + 
             DoubleToString(m_lastResult.strength, 1) + "%)", g_debugTrendManager);
    LOG_INFO("  Entry Compatible: " + (IsEntryCompatible() ? "YES" : "NO"), g_debugTrendManager);
    LOG_INFO("  Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips", g_debugTrendManager);
    LOG_INFO("  Weights: H1=10%, M15=40%, M5=35%, M1=15%", g_debugTrendManager);
    
    return true;
}

//=============================================================================
// SHUTDOWN (Unchanged)
//=============================================================================
void CTrendManager::Shutdown()
{
    ReleaseHandles();
    m_isInitialized = false;
    LOG_DEBUG("TrendManager shutdown for " + m_symbol, g_debugTrendManager);
}

//=============================================================================
// REPORTS (Unchanged)
//=============================================================================
string CTrendManager::GetSummaryString()
{
    if(!m_isInitialized && !m_hasValidDirection)
        return "TrendManager: Not initialized";
    
    AnalyzeTrend();
    
    string output = "";
    output += "Trend: " + GetDirection();
    output += " | Str: " + DoubleToString(GetStrength(), 1) + "%";
    output += " | Conf: " + DoubleToString(GetTrendConfidence(), 1) + "%";
    output += " | Entry: " + GetEntryLabel();
    output += " | Entry Score: " + DoubleToString(GetEntryScore(), 1) + "%";
    output += " | Allow: " + (ShouldAllowEntries() ? "✅" : "❌");
    output += " | Crossover: " + m_lastCrossover.scenarioName;
    output += " | Priority: " + IntegerToString(m_lastCrossover.priority);
    return output;
}

string CTrendManager::GetDetailedReport()
{
    if(!m_isInitialized && !m_hasValidDirection)
        return "TrendManager: Not initialized";
    
    AnalyzeTrend();
    
    string report = "\n========== TREND ANALYSIS REPORT (v4.02) ==========\n";
    report += "Symbol: " + m_symbol + "\n";
    report += "Timeframes: M15 (trend - 40%), M5 (entry - 35%), M1 (context - 15%), H1 (context - 10%)\n";
    report += "MAs: 21, 89, 200\n";
    report += "Weights: H1=10%, M15=40%, M5=35%, M1=15%\n";
    report += "Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips\n";
    report += "Initialized: " + (m_isInitialized ? "Yes" : "No") + "\n";
    report += "Has Valid Direction: " + (m_hasValidDirection ? "Yes" : "No") + "\n";
    report += "\n--- CURRENT TREND ---\n";
    report += "Direction: " + GetDirection() + "\n";
    report += "Strength: " + DoubleToString(GetStrength(), 1) + "%\n";
    report += "Confidence: " + DoubleToString(GetTrendConfidence(), 1) + "%\n";
    report += "Entry Compatible: " + (IsEntryCompatible() ? "YES" : "NO") + "\n";
    report += "Allow Entries: " + (ShouldAllowEntries() ? "YES" : "NO") + "\n";
    
    if(m_isInitialized)
    {
        report += "\n--- MA VALUES (M15 - TREND) ---\n";
        report += "Price: " + DoubleToString(m_cachePrice, _Digits) + "\n";
        report += "MA21: " + DoubleToString(m_cacheMA21, _Digits) + "\n";
        report += "MA89: " + DoubleToString(m_cacheMA89, _Digits) + "\n";
        report += "MA200: " + DoubleToString(m_cacheMA200, _Digits) + "\n";
        
        report += "\n--- MA VALUES (M5 - ENTRY) ---\n";
        report += "Price: " + DoubleToString(m_cachePrice_M5, _Digits) + "\n";
        report += "MA21: " + DoubleToString(m_cacheMA21_M5, _Digits) + "\n";
        report += "MA89: " + DoubleToString(m_cacheMA89_M5, _Digits) + "\n";
        report += "MA200: " + DoubleToString(m_cacheMA200_M5, _Digits) + "\n";
        
        report += "\n--- CROSSOVER STATUS ---\n";
        report += "M15 21 vs 89: " + GetStateName(m_lastCrossover.m15_21_89) + "\n";
        report += "M15 89 vs 200: " + GetStateName(m_lastCrossover.m15_89_200) + "\n";
        report += "M5 21 vs 89: " + GetStateName(m_lastCrossover.m5_21_89) + "\n";
        report += "M1 Position: " + m_lastCrossover.m1_position + " (" + DoubleToString(m_lastCrossover.m1_distance, 1) + " pts)\n";
        report += "Golden Cross: " + (m_lastCrossover.isGoldenCross ? "YES" : "NO") + "\n";
        report += "Death Cross: " + (m_lastCrossover.isDeathCross ? "YES" : "NO") + "\n";
        report += "Scenario: " + m_lastCrossover.scenarioName + "\n";
        report += "Priority: " + IntegerToString(m_lastCrossover.priority) + "\n";
        
        report += "\n--- FEATURES ---\n";
        report += "Weighted Score: " + DoubleToString(m_lastFeatures.weightedScore, 1) + "%\n";
        report += "Confidence: " + DoubleToString(m_lastFeatures.confidence, 1) + "%\n";
        report += "Alignment: " + DoubleToString(m_lastFeatures.alignment, 1) + "%\n";
        report += "Momentum: " + DoubleToString(m_lastFeatures.momentum, 1) + "\n";
        report += "Pullback Depth: " + DoubleToString(m_lastFeatures.pullbackDepth, 1) + "%\n";
        report += "Trend Duration: " + DoubleToString(m_lastFeatures.trendDuration, 0) + " bars\n";
        report += "Volatility: " + DoubleToString(m_lastFeatures.volatility, 1) + "%\n";
        
        report += "\n--- RECOMMENDATION ---\n";
        report += "Action: " + m_lastRecommendation.action + "\n";
        report += "Position Size: " + DoubleToString(m_lastRecommendation.positionSize, 2) + "\n";
        report += "Timing: " + m_lastRecommendation.timing + "\n";
        report += "Risk: " + m_lastRecommendation.riskLevel + "\n";
        report += "Ready: " + (m_lastRecommendation.isReady ? "YES" : "NO") + "\n";
        if(!m_lastRecommendation.isReady)
            report += "Rejection: " + m_lastRecommendation.rejectionReason + "\n";
    }
    
    report += "============================================================\n";
    return report;
}

string CTrendManager::GetFeaturesReport(SMarketFeatures &features)
{
    string report = "";
    report += "\n═══════════════════════════════════════════\n";
    report += "📊 FEATURE EXTRACTION REPORT (v4.02)\n";
    report += "───────────────────────────────────────────\n";
    report += StringFormat("M15: %s %.0f%% %s\n", features.m15.direction, features.m15.strength,
                          features.m15.maStacked ? "STACKED" : "CROSSED");
    report += StringFormat("M5:  %s %.0f%% %s\n", features.m5.direction, features.m5.strength,
                          features.m5.maStacked ? "STACKED" : "CROSSED");
    report += StringFormat("M1:  %s %.0f%% %s\n", features.m1.direction, features.m1.strength,
                          features.m1.maStacked ? "STACKED" : "CROSSED");
    report += StringFormat("H1:  %s %.0f%% %s\n", features.h1.direction, features.h1.strength,
                          features.h1.maStacked ? "STACKED" : "CROSSED");
    report += "───────────────────────────────────────────\n";
    report += StringFormat("Weighted Score: %.1f%% (H1=10%% M15=40%% M5=35%% M1=15%%)\n", features.weightedScore);
    report += StringFormat("Confidence:     %.1f%%\n", features.confidence);
    report += StringFormat("Alignment:      %.1f%%\n", features.alignment);
    report += StringFormat("Momentum:       %+.1f\n", features.momentum);
    report += StringFormat("Pullback Depth: %.1f%%\n", features.pullbackDepth);
    report += StringFormat("Trend Duration: %.0f bars\n", features.trendDuration);
    report += StringFormat("Volatility:     %.1f%%\n", features.volatility);
    report += StringFormat("Aligned:        %s\n", features.isAligned ? "YES" : "NO");
    report += StringFormat("Dominant:       %s (%.0f%%)\n", features.dominantDirection, features.dominanceLevel);
    report += "═══════════════════════════════════════════\n";
    return report;
}

string CTrendManager::GetRecommendationReport(STrendRecommendation &rec)
{
    string report = "";
    report += "\n═══════════════════════════════════════════\n";
    report += "⚡ RECOMMENDATION REPORT (v4.02)\n";
    report += "───────────────────────────────────────────\n";
    report += StringFormat("Action:         %s\n", rec.action);
    report += StringFormat("Position Size:  %.2f lots\n", rec.positionSize);
    report += StringFormat("Timing:         %s\n", rec.timing);
    report += StringFormat("Risk Level:     %s\n", rec.riskLevel);
    report += StringFormat("Confidence:     %s (%.1f%%)\n", rec.confidenceLevel, rec.confidenceScore);
    report += StringFormat("Ready:          %s\n", rec.isReady ? "✅ YES" : "❌ NO");
    if(!rec.isReady)
        report += StringFormat("Rejection:      %s\n", rec.rejectionReason);
    report += "───────────────────────────────────────────\n";
    report += "Reason: " + rec.primaryReason + "\n";
    if(rec.reasonCount > 0)
    {
        report += "Secondary:\n";
        for(int i = 0; i < rec.reasonCount; i++)
            report += "  • " + rec.secondaryReasons[i] + "\n";
    }
    report += "═══════════════════════════════════════════\n";
    return report;
}

string CTrendManager::GetCrossoverReport()
{
    string report = "";
    report += "\n═══════════════════════════════════════════\n";
    report += "🔄 CROSSOVER DETECTION REPORT (v4.02)\n";
    report += "───────────────────────────────────────────\n";
    report += "M15 21 vs 89: " + GetStateName(m_lastCrossover.m15_21_89) + 
              (m_lastCrossover.m15_21_89_justCrossed ? " 🔥 JUST CROSSED!" : "") + "\n";
    report += "M15 89 vs 200: " + GetStateName(m_lastCrossover.m15_89_200) + 
              (m_lastCrossover.m15_89_200_justCrossed ? " 🔥 JUST CROSSED!" : "") + "\n";
    report += "M5 21 vs 89: " + GetStateName(m_lastCrossover.m5_21_89) + 
              (m_lastCrossover.m5_21_89_justCrossed ? " 🔥 JUST CROSSED!" : "") + "\n";
    report += "M1 Position: " + m_lastCrossover.m1_position + " (" + DoubleToString(m_lastCrossover.m1_distance, 1) + " pts)\n";
    report += "───────────────────────────────────────────\n";
    report += "Golden Cross: " + (m_lastCrossover.isGoldenCross ? "✅ YES" : "❌ NO") + "\n";
    report += "Death Cross: " + (m_lastCrossover.isDeathCross ? "✅ YES" : "❌ NO") + "\n";
    report += "All Bullish: " + (m_lastCrossover.allBullish ? "✅ YES" : "❌ NO") + "\n";
    report += "All Bearish: " + (m_lastCrossover.allBearish ? "✅ YES" : "❌ NO") + "\n";
    report += "Divergence: " + (m_lastCrossover.isDivergence ? "⚠️ YES" : "✅ NO") + "\n";
    report += "───────────────────────────────────────────\n";
    report += "Scenario: " + m_lastCrossover.scenarioName + "\n";
    report += "Priority: " + IntegerToString(m_lastCrossover.priority) + "\n";
    report += "═══════════════════════════════════════════\n";
    return report;
}