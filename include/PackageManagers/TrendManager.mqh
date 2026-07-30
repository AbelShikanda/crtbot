//+------------------------------------------------------------------+
//|                        TrendManager.mqh                          |
//|                    Multi-TF Trend Detection + Crossover          |
//|                    v3.20 - NO INDICATOR MANAGER DEPENDENCY      |
//|                    M1 Optimized | Entry: M1 | Trend: M15        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.20"

#include "../Utils/Logger.mqh"
#include "../Headers/Structures.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugTrendManager = false;

//+------------------------------------------------------------------+
//| Trend Manager Class - v3.20 Multi-TF + Crossover               |
//+------------------------------------------------------------------+
class CTrendManager
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_trendTF;      // M15 - Primary trend
    ENUM_TIMEFRAMES m_confTF;       // M5  - Confirmation
    ENUM_TIMEFRAMES m_entryTF;      // M1  - Entry timing
    
    // ═══ INDICATOR HANDLES - M15 ═══
    int m_ma21_handle;
    int m_ma89_handle;
    int m_ma200_handle;
    
    // ═══ INDICATOR HANDLES - M5 ═══
    int m_ma21_M5_handle;
    int m_ma89_M5_handle;
    int m_ma200_M5_handle;
    
    // ═══ INDICATOR HANDLES - M1 ═══
    int m_ma21_M1_handle;
    int m_ma89_M1_handle;
    int m_ma200_M1_handle;
    
    // ═══ Cached Values - M15 ═══
    double m_cacheMA21;
    double m_cacheMA89;
    double m_cacheMA200;
    double m_cachePrice;
    
    // ═══ Cached Values - M5 ═══
    double m_cacheMA21_M5;
    double m_cacheMA89_M5;
    double m_cacheMA200_M5;
    double m_cachePrice_M5;
    
    // ═══ Cached Values - M1 ═══
    double m_cacheMA21_M1;
    double m_cacheMA89_M1;
    double m_cacheMA200_M1;
    double m_cachePrice_M1;
    
    // ═══ Previous Values for Crossover Detection ═══
    double m_prevMA21_M15;
    double m_prevMA89_M15;
    double m_prevMA200_M15;
    double m_prevMA21_M5;
    double m_prevMA89_M5;
    double m_prevMA200_M5;
    
    // State
    STrendResult m_lastResult;
    SMarketFeatures m_lastFeatures;
    STrendRecommendation m_lastRecommendation;
    SCrossoverResult m_lastCrossover;
    datetime m_lastBarTime;
    datetime m_lastBarTime_M5;
    datetime m_lastBarTime_M1;
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
    double m_m1Weight;
    double m_m5Weight;
    double m_m15Weight;
    
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
    
    // ═══ CROSSOVER DETECTION METHODS ═══
    ENUM_CROSS_STATE GetCrossoverState(double ma1, double ma2);
    bool JustCrossed(double ma1, double ma2, double prevMA1, double prevMA2);
    SCrossoverResult DetectCrossover();
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
                  ENUM_TIMEFRAMES confTF = PERIOD_M15,
                  ENUM_TIMEFRAMES entryTF = PERIOD_M15);
    ~CTrendManager();
    
    // ═══ SETTERS ═══
    void SetWeights(double m1, double m5, double m15);
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
    
    // ═══ M1-SPECIFIC ═══
    bool IsTrending();
    bool IsM1Compatible();
    bool IsTrendClear();
    double GetM1TrendScore();
    string GetM1TrendLabel();
    
    // ═══ TRADING FILTERS ═══
    bool ShouldAllowLongs();
    bool ShouldAllowShorts();
    bool ShouldAllowEntries();
    bool IsM1EntryAllowed();
    bool ShouldAllowM1Entry();
    
    // ═══ FEATURE GETTERS ═══
    SMarketFeatures GetLastFeatures() const { return m_lastFeatures; }
    STrendRecommendation GetLastRecommendation() const { return m_lastRecommendation; }
    SCrossoverResult GetLastCrossover() const { return m_lastCrossover; }
    
    // ═══ COMPONENT GETTERS ═══
    double GetMA21_M15() const { return m_cacheMA21; }
    double GetMA89_M15() const { return m_cacheMA89; }
    double GetMA200_M15() const { return m_cacheMA200; }
    double GetMA21_M5() const { return m_cacheMA21_M5; }
    double GetMA89_M5() const { return m_cacheMA89_M5; }
    double GetMA200_M5() const { return m_cacheMA200_M5; }
    double GetMA21_M1() const { return m_cacheMA21_M1; }
    double GetMA89_M1() const { return m_cacheMA89_M1; }
    double GetMA200_M1() const { return m_cacheMA200_M1; }
    double GetCurrentPrice() const { return m_cachePrice; }
    
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
    
    // ═══ M5 METHODS ═══
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
};

//=============================================================================
// CONSTRUCTOR
//=============================================================================
CTrendManager::CTrendManager(string symbol, ENUM_TIMEFRAMES trendTF, 
                             ENUM_TIMEFRAMES confTF, ENUM_TIMEFRAMES entryTF)
{
    LOG_DEBUG("CTrendManager v3.20 constructor called", g_debugTrendManager);
    
    m_symbol = (symbol == NULL) ? _Symbol : symbol;
    m_trendTF = (trendTF == PERIOD_CURRENT) ? PERIOD_M15 : trendTF;
    m_confTF = (confTF == PERIOD_CURRENT) ? PERIOD_M5 : confTF;
    m_entryTF = (entryTF == PERIOD_CURRENT) ? PERIOD_M1 : entryTF;
    
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
    
    // Clear caches
    m_cacheMA21 = m_cacheMA89 = m_cacheMA200 = m_cachePrice = 0;
    m_cacheMA21_M5 = m_cacheMA89_M5 = m_cacheMA200_M5 = m_cachePrice_M5 = 0;
    m_cacheMA21_M1 = m_cacheMA89_M1 = m_cacheMA200_M1 = m_cachePrice_M1 = 0;
    
    // Clear previous values
    m_prevMA21_M15 = m_prevMA89_M15 = m_prevMA200_M15 = 0;
    m_prevMA21_M5 = m_prevMA89_M5 = m_prevMA200_M5 = 0;
    
    m_lastBarTime = m_lastBarTime_M5 = m_lastBarTime_M1 = 0;
    m_isInitialized = false;
    m_hasValidDirection = false;
    m_lastValidDirection = "NEUTRAL";
    m_lastValidTime = 0;
    
    // ═══ THRESHOLDS - MADE LOOSE ═══
    m_strongThreshold = 50.0;
    m_moderateThreshold = 35.0;    // Lowered from 40
    m_weakThreshold = 20.0;        // Lowered from 25
    m_minConfidence = 25.0;        // Lowered from 30
    m_slopePeriods = 3;
    
    // ═══ CROSSOVER SETTINGS ═══
    m_crossoverBufferPips = 10;
    m_crossoverBufferPoints = 10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    // ═══ WEIGHTS (M15 dominant) ═══
    m_m1Weight = 0.10;
    m_m5Weight = 0.25;
    m_m15Weight = 0.65;
    
    // Initialize results
    ZeroMemory(m_lastResult);
    m_lastResult.direction = "NEUTRAL";
    m_lastResult.description = "Not initialized";
    
    ZeroMemory(m_lastFeatures);
    ZeroMemory(m_lastRecommendation);
    ZeroMemory(m_lastCrossover);
    
    LOG_DEBUG("========================================", g_debugTrendManager);
    LOG_DEBUG("TREND MANAGER v3.20 - MULTI-TF + CROSSOVER", g_debugTrendManager);
    LOG_DEBUG("========================================", g_debugTrendManager);
    LOG_DEBUG("  Symbol: " + m_symbol, g_debugTrendManager);
    LOG_DEBUG("  Trend TF: " + EnumToString(m_trendTF), g_debugTrendManager);
    LOG_DEBUG("  Conf TF: " + EnumToString(m_confTF), g_debugTrendManager);
    LOG_DEBUG("  Entry TF: " + EnumToString(m_entryTF), g_debugTrendManager);
    LOG_DEBUG("  Weights: M1=10%, M5=25%, M15=65%", g_debugTrendManager);
    LOG_DEBUG("  Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips", g_debugTrendManager);
    LOG_DEBUG("  Thresholds: Strong=50%, Moderate=35%, Weak=20%", g_debugTrendManager);
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
// CREATE HANDLES
//=============================================================================
void CTrendManager::CreateHandles()
{
    ReleaseHandles();
    
    // ─── M15 Handles ───
    m_ma21_handle = iMA(m_symbol, m_trendTF, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_handle = iMA(m_symbol, m_trendTF, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_handle = iMA(m_symbol, m_trendTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M15 Handles: MA21=" + IntegerToString(m_ma21_handle) + 
              " MA89=" + IntegerToString(m_ma89_handle) + 
              " MA200=" + IntegerToString(m_ma200_handle), g_debugTrendManager);
    
    // ─── M5 Handles ───
    m_ma21_M5_handle = iMA(m_symbol, m_confTF, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_M5_handle = iMA(m_symbol, m_confTF, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_M5_handle = iMA(m_symbol, m_confTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M5 Handles: MA21=" + IntegerToString(m_ma21_M5_handle) + 
              " MA89=" + IntegerToString(m_ma89_M5_handle) + 
              " MA200=" + IntegerToString(m_ma200_M5_handle), g_debugTrendManager);
    
    // ─── M1 Handles ───
    m_ma21_M1_handle = iMA(m_symbol, m_entryTF, 21, 0, MODE_EMA, PRICE_CLOSE);
    m_ma89_M1_handle = iMA(m_symbol, m_entryTF, 89, 0, MODE_EMA, PRICE_CLOSE);
    m_ma200_M1_handle = iMA(m_symbol, m_entryTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    LOG_DEBUG("M1 Handles: MA21=" + IntegerToString(m_ma21_M1_handle) + 
              " MA89=" + IntegerToString(m_ma89_M1_handle) + 
              " MA200=" + IntegerToString(m_ma200_M1_handle), g_debugTrendManager);
    
    // ─── VALIDATE HANDLES ───
    bool m5Valid = (m_ma21_M5_handle != INVALID_HANDLE && 
                    m_ma89_M5_handle != INVALID_HANDLE &&
                    m_ma200_M5_handle != INVALID_HANDLE);
    
    bool m1Valid = (m_ma21_M1_handle != INVALID_HANDLE && 
                    m_ma89_M1_handle != INVALID_HANDLE &&
                    m_ma200_M1_handle != INVALID_HANDLE);
    
    if(!m5Valid)
        LOG_WARNING("⚠️ M5 handles are INVALID! M5 data will be 0.", g_debugTrendManager);
    
    if(!m1Valid)
        LOG_WARNING("⚠️ M1 handles are INVALID! M1 data will be 0.", g_debugTrendManager);
}

//=============================================================================
// RELEASE HANDLES
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
    
    m_ma21_handle = INVALID_HANDLE;
    m_ma89_handle = INVALID_HANDLE;
    m_ma200_handle = INVALID_HANDLE;
    m_ma21_M5_handle = INVALID_HANDLE;
    m_ma89_M5_handle = INVALID_HANDLE;
    m_ma200_M5_handle = INVALID_HANDLE;
    m_ma21_M1_handle = INVALID_HANDLE;
    m_ma89_M1_handle = INVALID_HANDLE;
    m_ma200_M1_handle = INVALID_HANDLE;
}

//=============================================================================
// SET CROSSOVER BUFFER
//=============================================================================
void CTrendManager::SetCrossoverBuffer(int pips)
{
    m_crossoverBufferPips = pips;
    m_crossoverBufferPoints = pips * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    LOG_DEBUG("Crossover buffer set to " + IntegerToString(pips) + " pips", g_debugTrendManager);
}

//=============================================================================
// SET WEIGHTS
//=============================================================================
void CTrendManager::SetWeights(double m1, double m5, double m15)
{
    double total = m1 + m5 + m15;
    if(total > 0)
    {
        m_m1Weight = m1 / total;
        m_m5Weight = m5 / total;
        m_m15Weight = m15 / total;
    }
    LOG_DEBUG("Weights set: M1=" + DoubleToString(m_m1Weight*100,0) + 
              "% M5=" + DoubleToString(m_m5Weight*100,0) + 
              "% M15=" + DoubleToString(m_m15Weight*100,0) + "%", g_debugTrendManager);
}

//=============================================================================
// SET THRESHOLDS
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
// GET MA VALUE - Direct indicator access
//=============================================================================
//=============================================================================
// GET MA VALUE - Direct indicator access
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
// CHECK NEW BAR
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
// UPDATE CACHE
//=============================================================================
void CTrendManager::UpdateCache(ENUM_TIMEFRAMES tf)
{
    if(!m_isInitialized) return;
    
    if(tf == m_trendTF || tf == PERIOD_M15)
    {
        // Store previous values before updating
        m_prevMA21_M15 = m_cacheMA21;
        m_prevMA89_M15 = m_cacheMA89;
        m_prevMA200_M15 = m_cacheMA200;
        
        m_cacheMA21 = GetMAValue(m_ma21_handle, 0) ? GetMAValue(m_ma21_handle, 0) : GetMAValue(m_ma21_handle, 1);
        m_cacheMA89 = GetMAValue(m_ma89_handle, 0) ? GetMAValue(m_ma89_handle, 0) : GetMAValue(m_ma89_handle, 1);
        m_cacheMA200 = GetMAValue(m_ma200_handle, 0) ? GetMAValue(m_ma200_handle, 0) : GetMAValue(m_ma200_handle, 1);
        m_cachePrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    else if(tf == m_confTF || tf == PERIOD_M5)
    {
        // Store previous values before updating
        m_prevMA21_M5 = m_cacheMA21_M5;
        m_prevMA89_M5 = m_cacheMA89_M5;
        m_prevMA200_M5 = m_cacheMA200_M5;
        
        m_cacheMA21_M5 = GetMAValue(m_ma21_M5_handle, 0) ? GetMAValue(m_ma21_M5_handle, 0) : GetMAValue(m_ma21_M5_handle, 1);
        m_cacheMA89_M5 = GetMAValue(m_ma89_M5_handle, 0) ? GetMAValue(m_ma89_M5_handle, 0) : GetMAValue(m_ma89_M5_handle, 1);
        m_cacheMA200_M5 = GetMAValue(m_ma200_M5_handle, 0) ? GetMAValue(m_ma200_M5_handle, 0) : GetMAValue(m_ma200_M5_handle, 1);
        m_cachePrice_M5 = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    else if(tf == m_entryTF || tf == PERIOD_M1)
    {
        m_cacheMA21_M1 = GetMAValue(m_ma21_M1_handle, 0) ? GetMAValue(m_ma21_M1_handle, 0) : GetMAValue(m_ma21_M1_handle, 1);
        m_cacheMA89_M1 = GetMAValue(m_ma89_M1_handle, 0) ? GetMAValue(m_ma89_M1_handle, 0) : GetMAValue(m_ma89_M1_handle, 1);
        m_cacheMA200_M1 = GetMAValue(m_ma200_M1_handle, 0) ? GetMAValue(m_ma200_M1_handle, 0) : GetMAValue(m_ma200_M1_handle, 1);
        m_cachePrice_M1 = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
}

//=============================================================================
// UPDATE PREVIOUS VALUES
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
// CALCULATE MA SLOPE
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
    else if(tf == m_confTF || tf == PERIOD_M5)
    {
        if(maPeriod == 21) handle = m_ma21_M5_handle;
        else if(maPeriod == 89) handle = m_ma89_M5_handle;
        else return 0;
    }
    else if(tf == m_entryTF || tf == PERIOD_M1)
    {
        if(maPeriod == 21) handle = m_ma21_M1_handle;
        else if(maPeriod == 89) handle = m_ma89_M1_handle;
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
// CHECK PRICE ABOVE MA
//=============================================================================
bool CTrendManager::CheckPriceAboveMA(double price, double maValue)
{
    if(maValue == 0) return false;
    return price > maValue;
}

//=============================================================================
// CHECK MA STACKING
//=============================================================================
bool CTrendManager::CheckMAStacking(double ma21, double ma89, double ma200)
{
    if(ma21 == 0 || ma89 == 0 || ma200 == 0) return false;
    return (ma21 > ma89 && ma89 > ma200) || (ma21 < ma89 && ma89 < ma200);
}

//=============================================================================
// ═══ CROSSOVER DETECTION METHODS ═══
//=============================================================================

//+------------------------------------------------------------------+
//| Get Crossover State                                             |
//+------------------------------------------------------------------+
ENUM_CROSS_STATE CTrendManager::GetCrossoverState(double ma1, double ma2)
{
    double diff = ma1 - ma2;
    
    if(diff > m_crossoverBufferPoints)
        return CLEAR_UP;
    else if(diff < -m_crossoverBufferPoints)
        return CLEAR_DOWN;
    else if(diff > 0)
        return CROSS_UP;      // In zone, above
    else if(diff < 0)
        return CROSS_DOWN;    // In zone, below
    else
        return CROSS_ZONE;    // Very close
}

//+------------------------------------------------------------------+
//| Check if Just Crossed                                           |
//+------------------------------------------------------------------+
bool CTrendManager::JustCrossed(double ma1, double ma2, double prevMA1, double prevMA2)
{
    if(prevMA1 == 0 || prevMA2 == 0) return false;
    bool currentBull = ma1 > ma2;
    bool prevBull = prevMA1 > prevMA2;
    return (currentBull != prevBull);
}

//+------------------------------------------------------------------+
//| Get State Name                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Detect Crossover - BALANCED (Not too loose, not too tight)      |
//+------------------------------------------------------------------+
SCrossoverResult CTrendManager::DetectCrossover()
{
    SCrossoverResult result;
    ZeroMemory(result);
    result.priority = 6;  // Default: WAIT
    
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
    
    // ─── Check if M5 data is valid ───
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
        // ═══ FALLBACK: If M5 invalid, use M15 ═══
        result.m5_21_89 = result.m15_21_89;
        result.m5_21_89_justCrossed = result.m15_21_89_justCrossed;
    }
    
    // ─── M1 POSITION (BALANCED: 10 points) ───
    if(m1Valid)
    {
        double diffM1 = m_cachePrice - m_cacheMA21_M1;
        double diffPoints = diffM1 / result.pointValue;
        result.m1_distance = diffPoints;
        
        // ═══ BALANCED: 10 points (was 15 original, 5 simplified) ═══
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
    // ═══ BALANCED: Stacking requires ALL three MAs in order ═══
    bool m15Bullish = (m_cacheMA21 > m_cacheMA89);
    bool m15Bearish = (m_cacheMA21 < m_cacheMA89);
    bool m15StackedBullish = (m_cacheMA21 > m_cacheMA89 && m_cacheMA89 > m_cacheMA200);
    bool m15StackedBearish = (m_cacheMA21 < m_cacheMA89 && m_cacheMA89 < m_cacheMA200);
    
    // ═══ BALANCED: M5 must also confirm (unless invalid, then use M15) ═══
    bool m5Bullish = m5Valid ? (m_cacheMA21_M5 > m_cacheMA89_M5) : m15Bullish;
    bool m5Bearish = m5Valid ? (m_cacheMA21_M5 < m_cacheMA89_M5) : m15Bearish;
    bool m5StackedBullish = m5Valid ? (m_cacheMA21_M5 > m_cacheMA89_M5 && m_cacheMA89_M5 > m_cacheMA200_M5) : m15StackedBullish;
    bool m5StackedBearish = m5Valid ? (m_cacheMA21_M5 < m_cacheMA89_M5 && m_cacheMA89_M5 < m_cacheMA200_M5) : m15StackedBearish;
    
    // ═══ BALANCED: Golden/Death Cross requires CLEAR_UP/CLEAR_DOWN OR JUST_CROSSED ═══
    result.isGoldenCross = (result.m15_21_89 == CLEAR_UP || result.m15_21_89 == CROSS_UP) && 
                           (result.m15_89_200 == CLEAR_UP);
    result.isDeathCross = (result.m15_21_89 == CLEAR_DOWN || result.m15_21_89 == CROSS_DOWN) && 
                          (result.m15_89_200 == CLEAR_DOWN);
    
    // ═══ BALANCED: All Bullish requires M15 bullish AND (M5 bullish OR M5 just crossed) ═══
    result.allBullish = m15Bullish && (m5Bullish || result.m5_21_89_justCrossed);
    result.allBearish = m15Bearish && (m5Bearish || result.m5_21_89_justCrossed);
    
    // ═══ BALANCED: Divergence detection ═══
    result.isDivergence = (m15Bullish && m5Bearish) || (m15Bearish && m5Bullish);
    
    // ─── DETERMINE SCENARIO ───
    result.scenarioNumber = 0;
    result.scenarioName = "WAIT";
    result.priority = 6;
    
    // ─── BULLISH SCENARIOS ───
    if(m15Bullish && m15StackedBullish && m5StackedBullish)
    {
        // PERFECT: M15 stacked + M5 stacked
        if(result.m1_position == "ABOVE")
        {
            result.scenarioNumber = 1;
            result.scenarioName = "STRONG_BUY";
            result.priority = 1;
        }
        else if(result.m1_position == "NEAR")
        {
            result.scenarioNumber = 2;
            result.scenarioName = "BUY_DIP";
            result.priority = 2;
        }
        else // BELOW
        {
            result.scenarioNumber = 3;
            result.scenarioName = "BUY_PULLBACK";
            result.priority = 3;
        }
    }
    else if(m15Bullish && m15StackedBullish && (result.m5_21_89_justCrossed || m5Bullish))
    {
        // GOOD: M15 stacked, M5 confirms or just crossed
        if(result.m1_position == "ABOVE")
        {
            result.scenarioNumber = 2;
            result.scenarioName = "BUY_DIP";
            result.priority = 2;
        }
        else if(result.m1_position == "NEAR" || result.m1_position == "BELOW")
        {
            result.scenarioNumber = 3;
            result.scenarioName = "BUY_PULLBACK";
            result.priority = 3;
        }
    }
    else if(m15Bullish && (result.m15_21_89_justCrossed || m15StackedBullish))
    {
        // WATCH: M15 bullish but waiting for confirmation
        result.scenarioNumber = 13;
        result.scenarioName = "WATCH_BULLISH";
        result.priority = 4;
    }
    
    // ─── BEARISH SCENARIOS ───
    else if(m15Bearish && m15StackedBearish && m5StackedBearish)
    {
        // PERFECT: M15 stacked + M5 stacked
        if(result.m1_position == "BELOW")
        {
            result.scenarioNumber = 22;
            result.scenarioName = "STRONG_SELL";
            result.priority = 1;
        }
        else if(result.m1_position == "NEAR")
        {
            result.scenarioNumber = 23;
            result.scenarioName = "SELL_RALLY";
            result.priority = 2;
        }
        else // ABOVE
        {
            result.scenarioNumber = 24;
            result.scenarioName = "SELL_RALLY_DEEP";
            result.priority = 3;
        }
    }
    else if(m15Bearish && m15StackedBearish && (result.m5_21_89_justCrossed || m5Bearish))
    {
        // GOOD: M15 stacked, M5 confirms or just crossed
        if(result.m1_position == "BELOW")
        {
            result.scenarioNumber = 23;
            result.scenarioName = "SELL_RALLY";
            result.priority = 2;
        }
        else if(result.m1_position == "NEAR" || result.m1_position == "ABOVE")
        {
            result.scenarioNumber = 24;
            result.scenarioName = "SELL_RALLY_DEEP";
            result.priority = 3;
        }
    }
    else if(m15Bearish && (result.m15_21_89_justCrossed || m15StackedBearish))
    {
        // WATCH: M15 bearish but waiting for confirmation
        result.scenarioNumber = 13;
        result.scenarioName = "WATCH_BEARISH";
        result.priority = 4;
    }
    
    // ─── DIVERGENCE: M15 and M5 disagree ───
    if(result.isDivergence && result.priority <= 3)
    {
        // Downgrade divergence scenarios
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
    return result;
}

//=============================================================================
// GET FALLBACK TREND
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
// ═══ FEATURE EXTRACTION - The 7 Core Features ═══
//=============================================================================
SMarketFeatures CTrendManager::ExtractFeatures()
{
    SMarketFeatures features;
    ZeroMemory(features);
    
    // ─── STEP 1: Get Raw Data from each TF ───
    // M15 (Trend TF)
    features.m15.direction = m_lastResult.direction;
    features.m15.strength = m_lastResult.strength;
    features.m15.ma21 = m_cacheMA21;
    features.m15.ma89 = m_cacheMA89;
    features.m15.ma200 = m_cacheMA200;
    features.m15.maStacked = CheckMAStacking(m_cacheMA21, m_cacheMA89, m_cacheMA200);
    features.m15.slope = CalculateMASlope(m_trendTF, 21, m_slopePeriods);
    
    // M5 (Confirmation TF)
    features.m5.direction = GetDirection_M5();
    features.m5.strength = GetStrength_M5();
    features.m5.ma21 = m_cacheMA21_M5;
    features.m5.ma89 = m_cacheMA89_M5;
    features.m5.ma200 = m_cacheMA200_M5;
    features.m5.maStacked = CheckMAStacking(m_cacheMA21_M5, m_cacheMA89_M5, m_cacheMA200_M5);
    features.m5.slope = CalculateMASlope(m_confTF, 21, m_slopePeriods);
    
    // M1 (Entry TF)
    features.m1.direction = (m_cachePrice_M1 > m_cacheMA21_M1) ? "BULLISH" : 
                            (m_cachePrice_M1 < m_cacheMA21_M1) ? "BEARISH" : "NEUTRAL";
    features.m1.strength = MathAbs(features.m1.direction == "BULLISH" ? 35.0 : 
                                   features.m1.direction == "BEARISH" ? 35.0 : 0);
    features.m1.ma21 = m_cacheMA21_M1;
    features.m1.ma89 = m_cacheMA89_M1;
    features.m1.ma200 = m_cacheMA200_M1;
    features.m1.maStacked = CheckMAStacking(m_cacheMA21_M1, m_cacheMA89_M1, m_cacheMA200_M1);
    features.m1.slope = CalculateMASlope(m_entryTF, 21, m_slopePeriods);
    
    // ─── STEP 2: Calculate Weighted Score ───
    double m1Dir = (features.m1.direction == "BULLISH") ? 1 : 
                   (features.m1.direction == "BEARISH") ? -1 : 0;
    double m5Dir = (features.m5.direction == "BULLISH") ? 1 : 
                   (features.m5.direction == "BEARISH") ? -1 : 0;
    double m15Dir = (features.m15.direction == "BULLISH") ? 1 : 
                    (features.m15.direction == "BEARISH") ? -1 : 0;
    
    double weightedDir = (m1Dir * m_m1Weight) + (m5Dir * m_m5Weight) + (m15Dir * m_m15Weight);
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
    features.dominanceLevel = (features.m15.strength / 100 * 60) +
                              (features.m5.strength / 100 * 30) +
                              (features.m1.strength / 100 * 10);
    
    m_lastFeatures = features;
    
    return features;
}

//=============================================================================
// CALCULATE CONFIDENCE
//=============================================================================
double CTrendManager::CalculateConfidence(SMarketFeatures &features)
{
    double conf = 0;
    int factors = 0;
    
    // Factor 1: Alignment
    if(features.alignment >= 80) { conf += 20; factors++; }
    else if(features.alignment >= 60) { conf += 15; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 2: M15 Strength
    if(features.m15.strength >= 60) { conf += 20; factors++; }
    else if(features.m15.strength >= 40) { conf += 15; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 3: MA Stacking
    if(features.m15.maStacked) { conf += 15; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 4: Momentum
    if(features.momentum > 20) { conf += 15; factors++; }
    else if(features.momentum > 0) { conf += 10; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 5: Pullback Health
    if(features.pullbackDepth >= 3.0 && features.pullbackDepth <= 5.0) { conf += 15; factors++; }
    else if(features.pullbackDepth < 8.0) { conf += 10; factors++; }
    else { conf += 5; factors++; }
    
    // Factor 6: Volatility
    if(features.volatility < 20) { conf += 15; factors++; }
    else if(features.volatility < 30) { conf += 10; factors++; }
    else { conf += 5; factors++; }
    
    return (factors > 0) ? MathMin(100, MathMax(0, conf / factors * 100)) : 50;
}

//=============================================================================
// CALCULATE ALIGNMENT
//=============================================================================
double CTrendManager::CalculateAlignment(SMarketFeatures &features)
{
    double align = 0;
    int factors = 0;
    
    // M15 vs M5
    if(features.m15.direction == features.m5.direction) { align += 40; factors++; }
    else { align += 10; factors++; }
    
    // M15 vs M1
    if(features.m15.direction == features.m1.direction) { align += 30; factors++; }
    else { align += 10; factors++; }
    
    // M5 vs M1
    if(features.m5.direction == features.m1.direction) { align += 30; factors++; }
    else { align += 10; factors++; }
    
    return (factors > 0) ? align : 50;
}

//=============================================================================
// CALCULATE MOMENTUM
//=============================================================================
double CTrendManager::CalculateMomentum(SMarketFeatures &features)
{
    double mom = 0;
    int factors = 0;
    
    // M15 slope
    mom += features.m15.slope * 100; factors++;
    
    // M5 slope
    mom += features.m5.slope * 100; factors++;
    
    // M1 slope
    mom += features.m1.slope * 100; factors++;
    
    return (factors > 0) ? mom / factors : 0;
}

//=============================================================================
// CALCULATE PULLBACK DEPTH
//=============================================================================
double CTrendManager::CalculatePullbackDepth(SMarketFeatures &features)
{
    // If M15 bullish and M1 bearish = pullback
    if(features.m15.direction == "BULLISH" && features.m1.direction == "BEARISH")
    {
        double m15High = features.m15.ma21;
        double m1Low = features.m1.ma21;
        if(m15High > m1Low && m15High > 0)
            return ((m15High - m1Low) / m15High) * 100;
    }
    // If M15 bearish and M1 bullish = pullback
    else if(features.m15.direction == "BEARISH" && features.m1.direction == "BULLISH")
    {
        double m15Low = features.m15.ma21;
        double m1High = features.m1.ma21;
        if(m1High > m15Low && m15Low > 0)
            return ((m1High - m15Low) / m15Low) * 100;
    }
    return 0;
}

//=============================================================================
// CALCULATE TREND DURATION
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
// CALCULATE VOLATILITY
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
    
    // ─── STEP 6: SL/TP (will be set by main EA) ───
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
// CALCULATE POSITION SIZE
//=============================================================================
double CTrendManager::CalculatePositionSize(SMarketFeatures &features)
{
    double size = 1.0;
    
    // Factor 1: Weighted Score
    if(features.weightedScore >= 60) size *= 1.5;
    else if(features.weightedScore >= 45) size *= 1.0;
    else if(features.weightedScore >= 30) size *= 0.5;
    else size = 0;
    
    // Factor 2: Confidence
    if(features.confidence >= 70) size *= 1.3;
    else if(features.confidence >= 50) size *= 1.0;
    else size *= 0.5;
    
    // Factor 3: Alignment
    if(features.alignment >= 80) size *= 1.2;
    else if(features.alignment < 50) size *= 0.7;
    
    // Factor 4: Pullback (if in pullback)
    if(features.pullbackDepth >= 3.0 && features.pullbackDepth <= 5.0)
        size *= 1.2;
    else if(features.pullbackDepth > 8.0)
        size = 0;
    
    // Factor 5: Volatility
    if(features.volatility >= 30) size = 0;
    else if(features.volatility >= 20) size *= 0.7;
    
    return MathMin(3.0, MathMax(0.0, size));
}

//=============================================================================
// GET TIMING
//=============================================================================
string CTrendManager::GetTiming(double momentum)
{
    if(momentum > 20) return "NOW";
    else if(momentum > 0) return "SOON";
    else if(momentum > -20) return "WAIT";
    else return "NEVER";
}

//=============================================================================
// GET RISK LEVEL
//=============================================================================
string CTrendManager::GetRiskLevel(double volatility)
{
    if(volatility < 15) return "LOW";
    else if(volatility < 25) return "MEDIUM";
    else if(volatility < 35) return "HIGH";
    else return "VERY_HIGH";
}

//=============================================================================
// GET CONFIDENCE LEVEL
//=============================================================================
string CTrendManager::GetConfidenceLevel(double confidence)
{
    if(confidence >= 70) return "HIGH";
    else if(confidence >= 50) return "MEDIUM";
    else return "LOW";
}

//=============================================================================
// GENERATE PRIMARY REASON
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
    
    // Add key factors
    if(features.m15.strength >= 50)
        reason += StringFormat("Strong M15 trend (%.0f%%), ", features.m15.strength);
    else if(features.m15.strength >= 30)
        reason += StringFormat("Moderate M15 trend (%.0f%%), ", features.m15.strength);
    
    if(features.pullbackDepth >= 3.0 && features.pullbackDepth <= 5.0)
        reason += StringFormat("optimal pullback (%.1f%%), ", features.pullbackDepth);
    else if(features.pullbackDepth > 0)
        reason += StringFormat("pullback at %.1f%%, ", features.pullbackDepth);
    
    if(features.alignment >= 70)
        reason += "strong alignment between timeframes, ";
    
    if(features.confidence >= 70)
        reason += "high confidence (" + DoubleToString(features.confidence, 0) + "%)";
    else if(features.confidence >= 50)
        reason += "moderate confidence (" + DoubleToString(features.confidence, 0) + "%)";
    else
        reason += "low confidence (" + DoubleToString(features.confidence, 0) + "%)";
    
    return reason;
}

//=============================================================================
// GENERATE SECONDARY REASONS
//=============================================================================
void CTrendManager::GenerateSecondaryReasons(SMarketFeatures &features, STrendRecommendation &rec)
{
    rec.reasonCount = 0;
    
    // Reason 1: Momentum
    if(features.momentum > 0)
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Momentum positive (+%.1f)", features.momentum);
    else
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Momentum negative (%.1f)", features.momentum);
    
    // Reason 2: Volatility
    if(features.volatility < 20)
        rec.secondaryReasons[rec.reasonCount++] = "Low volatility - favorable";
    else if(features.volatility < 30)
        rec.secondaryReasons[rec.reasonCount++] = "Normal volatility";
    else
        rec.secondaryReasons[rec.reasonCount++] = "High volatility - caution";
    
    // Reason 3: Trend duration
    if(features.trendDuration < 10)
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Fresh trend (%.0f bars)", features.trendDuration);
    else if(features.trendDuration < 25)
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Mature trend (%.0f bars)", features.trendDuration);
    else
        rec.secondaryReasons[rec.reasonCount++] = StringFormat("Old trend (%.0f bars) - careful", features.trendDuration);
    
    // Reason 4: Alignment detail
    if(features.alignment >= 80)
        rec.secondaryReasons[rec.reasonCount++] = "All timeframes aligned";
    else if(features.alignment >= 60)
        rec.secondaryReasons[rec.reasonCount++] = "Most timeframes aligned";
    else
        rec.secondaryReasons[rec.reasonCount++] = "Timeframes conflicting - reduce size";
    
    // Reason 5: MA status
    if(features.m15.maStacked)
        rec.secondaryReasons[rec.reasonCount++] = "MAs stacked on M15 (21>89>200)";
    else
        rec.secondaryReasons[rec.reasonCount++] = "MAs not stacked - weaker trend";
}

//=============================================================================
// GENERATE FULL NARRATIVE
//=============================================================================
string CTrendManager::GenerateFullNarrative(SMarketFeatures &features, STrendRecommendation &rec)
{
    string narrative = "";
    
    narrative += StringFormat("M15: %s (%.0f%%), M5: %s (%.0f%%), M1: %s (%.0f%%). ",
        features.m15.direction, features.m15.strength,
        features.m5.direction, features.m5.strength,
        features.m1.direction, features.m1.strength);
    
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
// GET REJECTION REASON
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
// ═══ PRIMARY ANALYSIS - AnalyzeTrend ═══
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
    if(IsNewBar(m_trendTF, m_lastBarTime)) UpdateCache(m_trendTF);
    if(IsNewBar(m_confTF, m_lastBarTime_M5)) UpdateCache(m_confTF);
    if(IsNewBar(m_entryTF, m_lastBarTime_M1)) UpdateCache(m_entryTF);
    
    // Ensure previous values exist
    UpdatePreviousValues();
    
    if(m_cacheMA21 == 0 || m_cacheMA89 == 0 || m_cacheMA200 == 0 || m_cachePrice == 0)
    {
        UpdateCache(m_trendTF);
        if(m_cacheMA21 == 0 || m_cacheMA89 == 0 || m_cacheMA200 == 0 || m_cachePrice == 0)
            return GetFallbackTrend();
    }
    
    // ─── GATHER SIGNALS ───
    double bullSignals = 0, bearSignals = 0;
    
    // 1. Price vs MA200 (Weight: 3.0)
    bool priceAboveMA200 = CheckPriceAboveMA(m_cachePrice, m_cacheMA200);
    if(priceAboveMA200) bullSignals += 3.0; else bearSignals += 3.0;
    result.priceAboveMA200 = priceAboveMA200;
    
    // 2. MA Stacking (Weight: 2.0)
    bool maStackBull = (m_cacheMA21 > m_cacheMA89 && m_cacheMA89 > m_cacheMA200);
    bool maStackBear = (m_cacheMA21 < m_cacheMA89 && m_cacheMA89 < m_cacheMA200);
    if(maStackBull) { bullSignals += 2.0; result.maStackedBullish = true; }
    if(maStackBear) { bearSignals += 2.0; result.maStackedBearish = true; }
    
    // 3. MA Slopes (Weight: 1.0)
    double ma21Slope = CalculateMASlope(m_trendTF, 21, m_slopePeriods);
    double ma89Slope = CalculateMASlope(m_trendTF, 89, m_slopePeriods);
    result.ma21Slope = ma21Slope;
    result.ma89Slope = ma89Slope;
    
    if(ma21Slope > 0 && ma89Slope > 0) bullSignals += 1.0;
    else if(ma21Slope < 0 && ma89Slope < 0) bearSignals += 1.0;
    
    // 4. Price vs MA21 (Weight: 1.5)
    if(CheckPriceAboveMA(m_cachePrice, m_cacheMA21)) bullSignals += 1.5;
    else bearSignals += 1.5;
    
    // 5. Price vs MA89 (Weight: 1.5)
    if(CheckPriceAboveMA(m_cachePrice, m_cacheMA89)) bullSignals += 1.5;
    else bearSignals += 1.5;
    
    // Store signals
    result.bullSignals = bullSignals;
    result.bearSignals = bearSignals;
    
    // ─── CALCULATE SIGNAL RATIO ───
    double totalSignals = bullSignals + bearSignals;
    double signalRatio = (totalSignals > 0) ? bullSignals / totalSignals : 0.5;
    result.signalRatio = signalRatio;
    
    // ─── CALCULATE STRENGTH ───
    result.strength = MathAbs(signalRatio - 0.5) * 200.0;
    result.strength = MathMin(100.0, result.strength);
    result.trendConfidence = result.strength;
    
    // ─── DETERMINE DIRECTION - LOOSE THRESHOLDS ═══
    // Bullish: signalRatio >= 0.55 (55%)
    // Bearish: signalRatio <= 0.45 (45%)
    // Neutral: 0.45 - 0.55 (10% neutral zone)
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
    
    // ─── APPLY WEAKNESS FILTER ───
    // If strength is below weak threshold, force NEUTRAL
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
            result.description = "Strong Bullish Trend";
        else if(result.strength >= m_moderateThreshold) 
            result.description = "Bullish Trend";
        else if(result.strength >= m_weakThreshold) 
            result.description = "Mild Bullish Bias";
        else 
            result.description = "Very Weak Bullish (Filtered)";
    }
    else if(result.direction == "BEARISH")
    {
        if(result.strength >= m_strongThreshold) 
            result.description = "Strong Bearish Trend";
        else if(result.strength >= m_moderateThreshold) 
            result.description = "Bearish Trend";
        else if(result.strength >= m_weakThreshold) 
            result.description = "Mild Bearish Bias";
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
    result.lastUpdate = m_lastBarTime;
    m_lastResult = result;
    
    // ─── DETECT CROSSOVER ───
    m_lastCrossover = DetectCrossover();
    
    // ─── EXTRACT FEATURES AND MAKE DECISION ───
    m_lastFeatures = ExtractFeatures();
    m_lastRecommendation = MakeDecision(m_lastFeatures);
    
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
// GENERATE NARRATIVE
//=============================================================================
string CTrendManager::GenerateNarrative(const STrendResult &result)
{
    string narrative = "";
    
    if(result.direction == "BULLISH")
    {
        narrative = "Bullish trend confirmed. ";
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
        narrative = "Bearish trend confirmed. ";
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
// QUICK ACCESS METHODS
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
// M1-SPECIFIC METHODS
//=============================================================================
bool CTrendManager::IsTrending()
{
    return GetStrength() >= m_weakThreshold;
}

bool CTrendManager::IsM1Compatible()
{
    return GetStrength() >= m_moderateThreshold;
}

bool CTrendManager::IsTrendClear()
{
    return GetStrength() >= m_strongThreshold;
}

double CTrendManager::GetM1TrendScore()
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

string CTrendManager::GetM1TrendLabel()
{
    string direction = GetDirection();
    double strength = GetStrength();
    
    if(direction == "NEUTRAL") return "NEUTRAL (Dead Zone)";
    if(strength >= m_strongThreshold) return direction + " STRONG (Ideal)";
    if(strength >= m_moderateThreshold) return direction + " MODERATE (Compatible)";
    if(strength >= m_weakThreshold) return direction + " WEAK (Caution)";
    return direction + " VERY WEAK (Avoid)";
}

//=============================================================================
// TRADING FILTERS
//=============================================================================
bool CTrendManager::ShouldAllowLongs()
{
    return IsBullish() && IsM1Compatible();
}

bool CTrendManager::ShouldAllowShorts()
{
    return IsBearish() && IsM1Compatible();
}

bool CTrendManager::ShouldAllowEntries()
{
    return IsM1EntryAllowed();
}

bool CTrendManager::IsM1EntryAllowed()
{
    string direction = GetDirection();
    if(direction == "NEUTRAL") return false;
    return GetStrength() >= m_moderateThreshold;
}

bool CTrendManager::ShouldAllowM1Entry()
{
    return IsM1EntryAllowed();
}

//=============================================================================
// M5 METHODS
//=============================================================================
string CTrendManager::GetDirection_M5()
{
    if(!m_isInitialized) return "NEUTRAL";
    UpdateCache(m_confTF);
    
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
// INITIALIZE
//=============================================================================
bool CTrendManager::Initialize()
{
    LOG_DEBUG("Initialize called for " + m_symbol, g_debugTrendManager);
    
    if(m_isInitialized) return true;
    
    // Create indicator handles
    CreateHandles();
    
    // Verify handles
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
    m_lastBarTime = iTime(m_symbol, m_trendTF, 0);
    m_lastBarTime_M5 = iTime(m_symbol, m_confTF, 0);
    m_lastBarTime_M1 = iTime(m_symbol, m_entryTF, 0);
    
    UpdateCache(m_trendTF);
    UpdateCache(m_confTF);
    UpdateCache(m_entryTF);
    UpdatePreviousValues();
    
    m_lastResult = AnalyzeTrend();
    
    if(m_lastResult.direction != "NEUTRAL")
    {
        m_hasValidDirection = true;
        m_lastValidDirection = m_lastResult.direction;
        m_lastValidTime = TimeCurrent();
    }
    
    LOG_INFO("TrendManager v3.20 initialized for " + m_symbol, g_debugTrendManager);
    LOG_INFO("  Initial trend: " + m_lastResult.direction + " (Strength: " + 
             DoubleToString(m_lastResult.strength, 1) + "%)", g_debugTrendManager);
    LOG_INFO("  M1 Compatible: " + (IsM1Compatible() ? "YES" : "NO"), g_debugTrendManager);
    LOG_INFO("  Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips", g_debugTrendManager);
    
    return true;
}

//=============================================================================
// SHUTDOWN
//=============================================================================
void CTrendManager::Shutdown()
{
    ReleaseHandles();
    m_isInitialized = false;
    LOG_DEBUG("TrendManager shutdown for " + m_symbol, g_debugTrendManager);
}

//=============================================================================
// REPORTS
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
    output += " | M1: " + GetM1TrendLabel();
    output += " | M1 Score: " + DoubleToString(GetM1TrendScore(), 1) + "%";
    output += " | Allow: " + (ShouldAllowEntries() ? "✅" : "❌");
    output += " | MAs: 21,89,200";
    output += " | Crossover: " + m_lastCrossover.scenarioName;
    output += " | Priority: " + IntegerToString(m_lastCrossover.priority);
    return output;
}

string CTrendManager::GetDetailedReport()
{
    if(!m_isInitialized && !m_hasValidDirection)
        return "TrendManager: Not initialized";
    
    AnalyzeTrend();
    
    string report = "\n========== TREND ANALYSIS REPORT (v3.20) ==========\n";
    report += "Symbol: " + m_symbol + "\n";
    report += "Timeframes: M15 (trend), M5 (conf), M1 (entry)\n";
    report += "MAs: 21, 89, 200\n";
    report += "Weights: M1=10%, M5=25%, M15=65%\n";
    report += "Crossover Buffer: " + IntegerToString(m_crossoverBufferPips) + " pips\n";
    report += "Initialized: " + (m_isInitialized ? "Yes" : "No") + "\n";
    report += "Has Valid Direction: " + (m_hasValidDirection ? "Yes" : "No") + "\n";
    report += "\n--- CURRENT TREND ---\n";
    report += "Direction: " + GetDirection() + "\n";
    report += "Strength: " + DoubleToString(GetStrength(), 1) + "%\n";
    report += "Confidence: " + DoubleToString(GetTrendConfidence(), 1) + "%\n";
    report += "M1 Compatible: " + (IsM1Compatible() ? "YES" : "NO") + "\n";
    report += "Allow Entries: " + (ShouldAllowEntries() ? "YES" : "NO") + "\n";
    
    if(m_isInitialized)
    {
        report += "\n--- MA VALUES (M15) ---\n";
        report += "Price: " + DoubleToString(m_cachePrice, _Digits) + "\n";
        report += "MA21: " + DoubleToString(m_cacheMA21, _Digits) + "\n";
        report += "MA89: " + DoubleToString(m_cacheMA89, _Digits) + "\n";
        report += "MA200: " + DoubleToString(m_cacheMA200, _Digits) + "\n";
        
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
    report += "📊 FEATURE EXTRACTION REPORT\n";
    report += "───────────────────────────────────────────\n";
    report += StringFormat("M15: %s %.0f%% %s\n", features.m15.direction, features.m15.strength,
                          features.m15.maStacked ? "STACKED" : "CROSSED");
    report += StringFormat("M5:  %s %.0f%% %s\n", features.m5.direction, features.m5.strength,
                          features.m5.maStacked ? "STACKED" : "CROSSED");
    report += StringFormat("M1:  %s %.0f%% %s\n", features.m1.direction, features.m1.strength,
                          features.m1.maStacked ? "STACKED" : "CROSSED");
    report += "───────────────────────────────────────────\n";
    report += StringFormat("Weighted Score: %.1f%%\n", features.weightedScore);
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
    report += "⚡ RECOMMENDATION REPORT\n";
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
    report += "🔄 CROSSOVER DETECTION REPORT\n";
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