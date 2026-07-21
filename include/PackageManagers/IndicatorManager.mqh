//+------------------------------------------------------------------+
//|                                       IndicatorManager.mqh       |
//|               Efficient multi-timeframe indicator management     |
//|                    WITH WEIGHT MATRIX INTEGRATION               |
//|                       v3.1 - WEIGHTED TIMEFRAMES               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024"
#property version "3.1"

#include "../Headers/Enums.mqh"
#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "DataManager.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// INDICATOR MANAGER INDEPENDENT TOGGLE
// ============================================================
bool g_indicatorDebugMode = false;

//+------------------------------------------------------------------+
//| COMPONENT TIMEFRAME WEIGHT MATRIX                               |
//| Based on: M5 Entry / H1 Trend System                           |
//+------------------------------------------------------------------+
//
//┌─────────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
//│ Component   │   M1     │   M5     │   M15    │   M30    │   H1     │   H4     │
//├─────────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
//│ ADX         │    -     │   1.5    │    -     │    -     │   2.5    │   3.0    │
//│ MTF         │   0.3    │   0.5    │   0.8    │   1.2    │   2.0    │   2.5    │
//│ RSI         │    -     │   1.0    │    -     │    -     │   1.5    │   2.0    │
//│ MACD        │    -     │   1.0    │    -     │    -     │   1.5    │   2.0    │
//│ Volume      │    -     │   0.5    │    -     │    -     │   1.0    │    -     │
//│ Pullback    │    -     │   1.0    │    -     │    -     │    -     │    -     │
//└─────────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

//+------------------------------------------------------------------+
//| Component Timeframe Arrays - Based on Weight Matrix             |
//+------------------------------------------------------------------+

// ──────────────────────────────────────────────────────────────────
// 1. ADX MODULE - Trend Strength (3 TFs: M5, H1, H4)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES ADX_TIMEFRAMES[] = {
   PERIOD_M5,   // Weight: 1.5
   PERIOD_H1,   // Weight: 2.5
   PERIOD_H4    // Weight: 3.0
};

// ──────────────────────────────────────────────────────────────────
// 2. MTF MODULE - Multi-Timeframe Analysis (7 TFs)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES MTF_TIMEFRAMES[] = {
   PERIOD_M1,   // Weight: 0.3
   PERIOD_M5,   // Weight: 0.5
   PERIOD_M15,  // Weight: 0.8
   PERIOD_M30,  // Weight: 1.2
   PERIOD_H1,   // Weight: 2.0
   PERIOD_H4,   // Weight: 2.5
   PERIOD_D1    // Weight: 3.0
};

// ──────────────────────────────────────────────────────────────────
// 3. RSI MODULE - Overbought/Oversold (3 TFs: M5, H1, H4)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES RSI_TIMEFRAMES[] = {
   PERIOD_M5,   // Weight: 1.0
   PERIOD_H1,   // Weight: 1.5
   PERIOD_H4    // Weight: 2.0
};

// ──────────────────────────────────────────────────────────────────
// 4. MACD MODULE - Momentum & Trend Direction (3 TFs: M5, H1, H4)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES MACD_TIMEFRAMES[] = {
   PERIOD_M5,   // Weight: 1.0
   PERIOD_H1,   // Weight: 1.5
   PERIOD_H4    // Weight: 2.0
};

// ──────────────────────────────────────────────────────────────────
// 5. VOLUME MODULE - Volume Confirmation (2 TFs: M5, H1)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES VOLUME_TIMEFRAMES[] = {
   PERIOD_M5,   // Weight: 0.5
   PERIOD_H1    // Weight: 1.0
};

// ──────────────────────────────────────────────────────────────────
// 6. PULLBACK MODULE - Price Action (1 TF: M5)
// ──────────────────────────────────────────────────────────────────
ENUM_TIMEFRAMES PULLBACK_TIMEFRAMES[] = {
   PERIOD_M5    // Weight: 1.0
};

//+------------------------------------------------------------------+
//| WEIGHT CONFIGURATION STRUCT                                     |
//+------------------------------------------------------------------+
struct SComponentWeights
{
   // ADX Weights
   double adxM5;
   double adxH1;
   double adxH4;
   
   // MTF Weights
   double mtfM1;
   double mtfM5;
   double mtfM15;
   double mtfM30;
   double mtfH1;
   double mtfH4;
   double mtfD1;
   
   // RSI Weights
   double rsiM5;
   double rsiH1;
   double rsiH4;
   
   // MACD Weights
   double macdM5;
   double macdH1;
   double macdH4;
   
   // Volume Weights
   double volM5;
   double volH1;
   
   // Pullback Weights
   double pbM5;
};

//+------------------------------------------------------------------+
//| Indicator Manager Class                                         |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   // ──────────────────────────────────────────────────────────────
   // CONSTANTS
   // ──────────────────────────────────────────────────────────────
   enum
   {
      MAX_MA_CACHE_SIZE = 30,
      MAX_TIMEFRAMES = 7
   };
   
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   MarketData*        m_marketData;
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframes[MAX_TIMEFRAMES];
   int                m_timeframeCount;
   bool               m_initialized;
   bool               m_ownsMarketData;
   string             m_lastError;
   ENUM_TIMEFRAMES    m_currentTimeframe;
   SComponentWeights  m_weights;
   
   // ──────────────────────────────────────────────────────────────
   // INDICATOR HANDLES
   // ──────────────────────────────────────────────────────────────
   struct IndicatorHandles
   {
      int ma_fast;
      int ma_medium;
      int ma_slow;
      int ma_50;
      int rsi;
      int macd;
      int adx;
      int stoch;
      int atr;
      int volume;
      int bbands;
      int awesome;
      int alligator;
      int fractals;
   };
   
   IndicatorHandles m_handles[MAX_TIMEFRAMES];
   
   // ──────────────────────────────────────────────────────────────
   // MA CACHE
   // ──────────────────────────────────────────────────────────────
   struct MACacheEntry
   {
      int period;
      int handle;
      datetime lastAccess;
   };
   
   MACacheEntry m_maCache[MAX_TIMEFRAMES][MAX_MA_CACHE_SIZE];
   int m_maCacheSizes[MAX_TIMEFRAMES];
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   bool CreateIndicators(ENUM_TIMEFRAMES tf, int index);
   bool ValidateHandle(int handle);
   void ResetHandles();
   void ReleaseHandles(int index);
   void ReleaseAllHandles();
   int GetTimeframeIndex(ENUM_TIMEFRAMES tf);
   string GetTimeframeName(ENUM_TIMEFRAMES tf);
   int GetMinimumBarsForTF(ENUM_TIMEFRAMES tf);
   double GetIndicatorValue(int handle, int bufferNum, int shift);
   double GetDefaultATR();
   bool EnsureDataLoaded(ENUM_TIMEFRAMES tf, int requiredBars);
   bool EnsureIndicatorsReady(ENUM_TIMEFRAMES tf);
   bool IsDataAvailable(ENUM_TIMEFRAMES tf, int minBars = 50);
   ENUM_TIMEFRAMES GetBestAvailableTimeframe(ENUM_TIMEFRAMES preferred);
   double CalculateWeightedAverage(double &values[], double &weights[], int count);
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT TIMEFRAME HELPERS
   // ──────────────────────────────────────────────────────────────
   bool IsTFInArray(ENUM_TIMEFRAMES &array[], ENUM_TIMEFRAMES tf);
   bool IsADXTimeframe(ENUM_TIMEFRAMES tf);
   bool IsMTFTimeframe(ENUM_TIMEFRAMES tf);
   bool IsRSITimeframe(ENUM_TIMEFRAMES tf);
   bool IsMACDTimeframe(ENUM_TIMEFRAMES tf);
   bool IsVolumeTimeframe(ENUM_TIMEFRAMES tf);
   bool IsPullbackTimeframe(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // COMPONENT INDICATOR CREATION METHODS
   // ──────────────────────────────────────────────────────────────
   bool CreateADXIndicators(ENUM_TIMEFRAMES tf, int index);
   bool CreateMTFIndicators(ENUM_TIMEFRAMES tf, int index);
   bool CreateRSIIndicators(ENUM_TIMEFRAMES tf, int index);
   bool CreateMACDIndicators(ENUM_TIMEFRAMES tf, int index);
   bool CreateVolumeIndicators(ENUM_TIMEFRAMES tf, int index);
   bool CreatePullbackIndicators(ENUM_TIMEFRAMES tf, int index);
   
   // ──────────────────────────────────────────────────────────────
   // MA CACHE METHODS
   // ──────────────────────────────────────────────────────────────
   int GetOrCreateMAHandle(ENUM_TIMEFRAMES tf, int period);
   void CleanMACache(int timeframeIndex);
   
   // ──────────────────────────────────────────────────────────────
   // SYMBOL DETECTION HELPERS
   // ──────────────────────────────────────────────────────────────
   bool IsGoldSymbol();
   bool IsForexSymbol();
   bool IsCryptoSymbol();
   
   // ──────────────────────────────────────────────────────────────
   // OHLC HELPERS
   // ──────────────────────────────────────────────────────────────
   double GetHigh(ENUM_TIMEFRAMES tf, int shift);
   double GetLow(ENUM_TIMEFRAMES tf, int shift);
   double GetClose(ENUM_TIMEFRAMES tf, int shift);
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CIndicatorManager();
   CIndicatorManager(MarketData* marketData, string symbol = NULL);
   ~CIndicatorManager();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize(MarketData* marketData = NULL, string symbol = NULL);
   void Deinitialize();
   bool IsInitialized() const { return m_initialized; }
   string GetLastErrorMessage() const { return m_lastError; }
   void SetCurrentTimeframe(ENUM_TIMEFRAMES tf) { m_currentTimeframe = tf; }
   void SetDefaultWeights();
   void SetWeights(SComponentWeights &weights);
   SComponentWeights GetWeights() const { return m_weights; }
   
   // ──────────────────────────────────────────────────────────────
   // DATA UPDATE METHODS
   // ──────────────────────────────────────────────────────────────
   void OnTick();
   void OnTimer();
   void Refresh();
   void Cleanup();
   
   // ──────────────────────────────────────────────────────────────
   // MOVING AVERAGES
   // ──────────────────────────────────────────────────────────────
   bool GetMAValues(ENUM_TIMEFRAMES tf, double &maFast, double &maMedium, double &maSlow, int shift = 0);
   bool GetMAValuesForRange(ENUM_TIMEFRAMES tf, double &ma9, double &ma21, double &ma50, double &ma89, int shift = 0);
   double GetMA(ENUM_TIMEFRAMES tf, int period, int shift = 0);
   bool GetMACrossovers(ENUM_TIMEFRAMES tf, bool &goldenCross, bool &deathCross);
   
   // ──────────────────────────────────────────────────────────────
   // RSI
   // ──────────────────────────────────────────────────────────────
   double GetRSI(ENUM_TIMEFRAMES tf, int shift = 0);
   bool IsOverbought(ENUM_TIMEFRAMES tf, int threshold = 70);
   bool IsOversold(ENUM_TIMEFRAMES tf, int threshold = 30);
   
   // ──────────────────────────────────────────────────────────────
   // WEIGHTED RSI
   // ──────────────────────────────────────────────────────────────
   double GetWeightedRSI();
   string GetWeightedRSIDirection();
   bool IsWeightedOverbought(int threshold = 70);
   bool IsWeightedOversold(int threshold = 30);
   
   // ──────────────────────────────────────────────────────────────
   // MACD
   // ──────────────────────────────────────────────────────────────
   bool GetMACDValues(ENUM_TIMEFRAMES tf, double &main, double &signal, int shift = 0);
   int GetMACDCrossover(ENUM_TIMEFRAMES tf);
   bool IsMACDBullish(ENUM_TIMEFRAMES tf);
   bool IsMACDBearish(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // WEIGHTED MACD
   // ──────────────────────────────────────────────────────────────
   double GetWeightedMACD();
   string GetWeightedMACDDirection();
   bool IsWeightedMACDBullish();
   bool IsWeightedMACDBearish();
   
   // ──────────────────────────────────────────────────────────────
   // ADX
   // ──────────────────────────────────────────────────────────────
   bool GetADXValues(ENUM_TIMEFRAMES tf, double &adx, double &plusDI, double &minusDI, int shift = 0);
   bool IsStrongTrend(ENUM_TIMEFRAMES tf, int threshold = 25);
   int GetADXTrendDirection(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // WEIGHTED ADX
   // ──────────────────────────────────────────────────────────────
   double GetWeightedADX();
   string GetWeightedADXDirection();
   bool IsWeightedStrongTrend(int threshold = 25);
   double GetWeightedADXStrength();
   
   // ──────────────────────────────────────────────────────────────
   // WEIGHTED VOLUME
   // ──────────────────────────────────────────────────────────────
   bool IsWeightedVolumeSpike(double multiplier = 2.0);
   double GetWeightedVolumeScore();
   
   // ──────────────────────────────────────────────────────────────
   // STOCHASTIC
   // ──────────────────────────────────────────────────────────────
   bool GetStochasticValues(ENUM_TIMEFRAMES tf, double &k, double &d, int shift = 0);
   bool IsStochasticOverbought(ENUM_TIMEFRAMES tf, int threshold = 80);
   bool IsStochasticOversold(ENUM_TIMEFRAMES tf, int threshold = 20);
   bool IsStochasticCrossover(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // ATR (VOLATILITY)
   // ──────────────────────────────────────────────────────────────
   double GetATR(ENUM_TIMEFRAMES tf, int shift = 0);
   double GetATRWithFallback(ENUM_TIMEFRAMES tf, int shift = 0);
   double GetATRInPips(ENUM_TIMEFRAMES tf, int shift = 0);
   bool IsHighVolatility(ENUM_TIMEFRAMES tf, double threshold = 1.5);
   bool IsLowVolatility(ENUM_TIMEFRAMES tf, double threshold = 0.5);
   
   // ──────────────────────────────────────────────────────────────
   // BOLLINGER BANDS
   // ──────────────────────────────────────────────────────────────
   bool GetBollingerBands(ENUM_TIMEFRAMES tf, double &upper, double &middle, double &lower, int shift = 0);
   int GetBBandsPosition(ENUM_TIMEFRAMES tf, double price, int shift = 0);
   bool IsBBandsSqueeze(ENUM_TIMEFRAMES tf, double threshold = 0.5);
   
   // ──────────────────────────────────────────────────────────────
   // VOLUME
   // ──────────────────────────────────────────────────────────────
   long GetVolume(ENUM_TIMEFRAMES tf, int shift = 0);
   bool IsVolumeSpike(ENUM_TIMEFRAMES tf, double multiplier = 2.0);
   double GetAverageVolume(ENUM_TIMEFRAMES tf, int period = 20);
   
   // ──────────────────────────────────────────────────────────────
   // AWESOME OSCILLATOR
   // ──────────────────────────────────────────────────────────────
   double GetAwesomeOscillator(ENUM_TIMEFRAMES tf, int shift = 0);
   bool IsAwesomeBullish(ENUM_TIMEFRAMES tf);
   bool IsAwesomeBearish(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // ALLIGATOR
   // ──────────────────────────────────────────────────────────────
   bool GetAlligatorValues(ENUM_TIMEFRAMES tf, double &jaw, double &teeth, double &lips, int shift = 0);
   int GetAlligatorState(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // FRACTALS
   // ──────────────────────────────────────────────────────────────
   bool IsFractalHigh(ENUM_TIMEFRAMES tf, int shift = 0);
   bool IsFractalLow(ENUM_TIMEFRAMES tf, int shift = 0);
   double GetFractalHigh(ENUM_TIMEFRAMES tf, int lookback = 10);
   double GetFractalLow(ENUM_TIMEFRAMES tf, int lookback = 10);
   
   // ──────────────────────────────────────────────────────────────
   // TREND ANALYSIS
   // ──────────────────────────────────────────────────────────────
   bool IsTrendBullish(ENUM_TIMEFRAMES tf);
   bool IsTrendBearish(ENUM_TIMEFRAMES tf);
   int GetTrendStrength(ENUM_TIMEFRAMES tf);
   bool GetMultiTimeframeConfirmation(int &bullishCount, int &bearishCount);
   double GetMarketScore();
   string GetMarketCondition(ENUM_TIMEFRAMES tf);
   
   // ──────────────────────────────────────────────────────────────
   // WEIGHTED OVERALL SCORE
   // ──────────────────────────────────────────────────────────────
   double GetWeightedOverallScore();
   string GetWeightedOverallDirection();
   
   // ──────────────────────────────────────────────────────────────
   // POSITION SIZING & RISK
   // ──────────────────────────────────────────────────────────────
   double CalculatePositionSize(double riskPercent, double stopLossPips, ENUM_TIMEFRAMES tf = PERIOD_M15);
   double GetAdjustedStopLoss(ENUM_TIMEFRAMES tf, double entryPrice, bool isBuy, double atrMultiplier = 2.0);
   double GetAdjustedTakeProfit(ENUM_TIMEFRAMES tf, double entryPrice, bool isBuy, double riskReward = 2.0);
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY METHODS
   // ──────────────────────────────────────────────────────────────
   string GetSymbol() const { return m_symbol; }
   void SetDebug(bool enable) { /* DEBUG_INDICATOR_ENABLED = enable; */ }
   bool GetTimeframeData(ENUM_TIMEFRAMES tf, MqlRates &rates[], int count = 100);
   void PrintStatus();
   void PrintWeightMatrix();
   void PrintWeightedStatus();
   void PrintAllTimeframesStatus();
};

//+------------------------------------------------------------------+
//| Constructor - Default                                            |
//+------------------------------------------------------------------+
CIndicatorManager::CIndicatorManager()
{
   LOG_DEBUG("Constructor called", g_indicatorDebugMode);
   
   m_marketData = NULL;
   m_symbol = Symbol();
   m_initialized = false;
   m_ownsMarketData = false;
   m_lastError = "";
   m_currentTimeframe = PERIOD_M5;
   m_timeframeCount = MAX_TIMEFRAMES;
   
   m_timeframes[0] = PERIOD_M1;
   m_timeframes[1] = PERIOD_M5;
   m_timeframes[2] = PERIOD_M15;
   m_timeframes[3] = PERIOD_M30;
   m_timeframes[4] = PERIOD_H1;
   m_timeframes[5] = PERIOD_H4;
   m_timeframes[6] = PERIOD_D1;
   
   ResetHandles();
   SetDefaultWeights();
    
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      m_maCacheSizes[i] = 0;
      for(int j = 0; j < MAX_MA_CACHE_SIZE; j++)
      {
         m_maCache[i][j].period = 0;
         m_maCache[i][j].handle = INVALID_HANDLE;
         m_maCache[i][j].lastAccess = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Constructor - With MarketData                                    |
//+------------------------------------------------------------------+
CIndicatorManager::CIndicatorManager(MarketData* marketData, string symbol = NULL)
{
   LOG_DEBUG("Constructor with MarketData called", g_indicatorDebugMode);
   
   m_marketData = marketData;
   m_symbol = (symbol == NULL) ? Symbol() : symbol;
   m_initialized = false;
   m_ownsMarketData = false;
   m_lastError = "";
   m_currentTimeframe = PERIOD_M5;
   m_timeframeCount = MAX_TIMEFRAMES;
   
   m_timeframes[0] = PERIOD_M1;
   m_timeframes[1] = PERIOD_M5;
   m_timeframes[2] = PERIOD_M15;
   m_timeframes[3] = PERIOD_M30;
   m_timeframes[4] = PERIOD_H1;
   m_timeframes[5] = PERIOD_H4;
   m_timeframes[6] = PERIOD_D1;
   
   ResetHandles();
   SetDefaultWeights();
    
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      m_maCacheSizes[i] = 0;
      for(int j = 0; j < MAX_MA_CACHE_SIZE; j++)
      {
         m_maCache[i][j].period = 0;
         m_maCache[i][j].handle = INVALID_HANDLE;
         m_maCache[i][j].lastAccess = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CIndicatorManager::~CIndicatorManager()
{
   LOG_DEBUG("Destructor called", g_indicatorDebugMode);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Set Default Weights                                             |
//+------------------------------------------------------------------+
void CIndicatorManager::SetDefaultWeights()
{
   LOG_DEBUG("Setting default weights", g_indicatorDebugMode);
   
   // ADX - Higher TFs get more weight
   m_weights.adxM5 = 1.5;
   m_weights.adxH1 = 2.5;
   m_weights.adxH4 = 3.0;
   
   // MTF - All 7 TFs with weights
   m_weights.mtfM1 = 0.3;
   m_weights.mtfM5 = 0.5;
   m_weights.mtfM15 = 0.8;
   m_weights.mtfM30 = 1.2;
   m_weights.mtfH1 = 2.0;
   m_weights.mtfH4 = 2.5;
   m_weights.mtfD1 = 3.0;
   
   // RSI
   m_weights.rsiM5 = 1.0;
   m_weights.rsiH1 = 1.5;
   m_weights.rsiH4 = 2.0;
   
   // MACD
   m_weights.macdM5 = 1.0;
   m_weights.macdH1 = 1.5;
   m_weights.macdH4 = 2.0;
   
   // Volume
   m_weights.volM5 = 0.5;
   m_weights.volH1 = 1.0;
   
   // Pullback
   m_weights.pbM5 = 1.0;
}

//+------------------------------------------------------------------+
//| Set Custom Weights                                              |
//+------------------------------------------------------------------+
void CIndicatorManager::SetWeights(SComponentWeights &weights)
{
   LOG_INFO("Setting custom weights", g_indicatorDebugMode);
   m_weights = weights;
}

//+------------------------------------------------------------------+
//| Calculate Weighted Average                                       |
//+------------------------------------------------------------------+
double CIndicatorManager::CalculateWeightedAverage(double &values[], double &weights[], int count)
{
   double sumWeighted = 0;
   double sumWeights = 0;
   
   for(int i = 0; i < count; i++)
   {
      sumWeighted += values[i] * weights[i];
      sumWeights += weights[i];
   }
   
   if(sumWeights == 0) return 0;
   return sumWeighted / sumWeights;
}

//+------------------------------------------------------------------+
//| COMPONENT TIMEFRAME HELPERS                                     |
//+------------------------------------------------------------------+

bool CIndicatorManager::IsTFInArray(ENUM_TIMEFRAMES &array[], ENUM_TIMEFRAMES tf)
{
   int size = ArraySize(array);
   for(int i = 0; i < size; i++)
   {
      if(array[i] == tf) return true;
   }
   return false;
}

bool CIndicatorManager::IsADXTimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(ADX_TIMEFRAMES, tf);
}

bool CIndicatorManager::IsMTFTimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(MTF_TIMEFRAMES, tf);
}

bool CIndicatorManager::IsRSITimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(RSI_TIMEFRAMES, tf);
}

bool CIndicatorManager::IsMACDTimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(MACD_TIMEFRAMES, tf);
}

bool CIndicatorManager::IsVolumeTimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(VOLUME_TIMEFRAMES, tf);
}

bool CIndicatorManager::IsPullbackTimeframe(ENUM_TIMEFRAMES tf)
{
   return IsTFInArray(PULLBACK_TIMEFRAMES, tf);
}

//+------------------------------------------------------------------+
//| COMPONENT INDICATOR CREATION METHODS                            |
//+------------------------------------------------------------------+

bool CIndicatorManager::CreateADXIndicators(ENUM_TIMEFRAMES tf, int index)
{
   string tfName = GetTimeframeName(tf);
   
   LOG_DEBUG("📊 Creating ADX indicators for " + tfName, g_indicatorDebugMode);
   
   m_handles[index].adx = iADX(m_symbol, tf, 14);
   if(!ValidateHandle(m_handles[index].adx))
   {
      LOG_ERROR("ADX: ADX (14) invalid for " + tfName);
      return false;
   }
   
   LOG_DEBUG("✅ ADX indicators created for " + tfName, g_indicatorDebugMode);
   return true;
}

bool CIndicatorManager::CreateMTFIndicators(ENUM_TIMEFRAMES tf, int index)
{
   bool valid = true;
   string tfName = GetTimeframeName(tf);
   
   LOG_DEBUG("📊 Creating MTF indicators for " + tfName, g_indicatorDebugMode);
   
   m_handles[index].ma_fast = iMA(m_symbol, tf, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(!ValidateHandle(m_handles[index].ma_fast))
   {
      LOG_ERROR("MTF: MA Fast (9 EMA) invalid for " + tfName);
      valid = false;
   }
   
   m_handles[index].ma_medium = iMA(m_symbol, tf, 21, 0, MODE_SMA, PRICE_CLOSE);
   if(!ValidateHandle(m_handles[index].ma_medium))
   {
      LOG_ERROR("MTF: MA Medium (21 SMA) invalid for " + tfName);
      valid = false;
   }
   
   m_handles[index].ma_slow = iMA(m_symbol, tf, 89, 0, MODE_SMA, PRICE_CLOSE);
   if(!ValidateHandle(m_handles[index].ma_slow))
   {
      LOG_ERROR("MTF: MA Slow (89 SMA) invalid for " + tfName);
      valid = false;
   }
   
   m_handles[index].rsi = iRSI(m_symbol, tf, 14, PRICE_CLOSE);
   if(!ValidateHandle(m_handles[index].rsi))
   {
      LOG_ERROR("MTF: RSI (14) invalid for " + tfName);
      valid = false;
   }
   
   m_handles[index].atr = iATR(m_symbol, tf, 14);
   if(!ValidateHandle(m_handles[index].atr))
   {
      LOG_ERROR("MTF: ATR (14) invalid for " + tfName);
   }
   
   if(valid)
      LOG_DEBUG("✅ MTF indicators created for " + tfName, g_indicatorDebugMode);
   
   return valid;
}

bool CIndicatorManager::CreateRSIIndicators(ENUM_TIMEFRAMES tf, int index)
{
   string tfName = GetTimeframeName(tf);
   
   LOG_DEBUG("📊 Creating RSI indicators for " + tfName, g_indicatorDebugMode);
   
   if(m_handles[index].rsi == INVALID_HANDLE)
   {
      m_handles[index].rsi = iRSI(m_symbol, tf, 14, PRICE_CLOSE);
      if(!ValidateHandle(m_handles[index].rsi))
      {
         LOG_ERROR("RSI: RSI (14) invalid for " + tfName);
         return false;
      }
   }
   
   LOG_DEBUG("✅ RSI indicators created for " + tfName, g_indicatorDebugMode);
   return true;
}

bool CIndicatorManager::CreateMACDIndicators(ENUM_TIMEFRAMES tf, int index)
{
   string tfName = GetTimeframeName(tf);
   
   LOG_DEBUG("📊 Creating MACD indicators for " + tfName, g_indicatorDebugMode);
   
   m_handles[index].macd = iMACD(m_symbol, tf, 12, 26, 9, PRICE_CLOSE);
   if(!ValidateHandle(m_handles[index].macd))
   {
      LOG_ERROR("MACD: MACD (12,26,9) invalid for " + tfName);
      return false;
   }
   
   LOG_DEBUG("✅ MACD indicators created for " + tfName, g_indicatorDebugMode);
   return true;
}

bool CIndicatorManager::CreateVolumeIndicators(ENUM_TIMEFRAMES tf, int index)
{
   string tfName = GetTimeframeName(tf);
   
   LOG_DEBUG("📊 Creating Volume indicators for " + tfName, g_indicatorDebugMode);
   
   m_handles[index].volume = iVolumes(m_symbol, tf, VOLUME_TICK);
   if(!ValidateHandle(m_handles[index].volume))
   {
      LOG_ERROR("Volume: Volume invalid for " + tfName);
      return false;
   }
   
   LOG_DEBUG("✅ Volume indicators created for " + tfName, g_indicatorDebugMode);
   return true;
}

bool CIndicatorManager::CreatePullbackIndicators(ENUM_TIMEFRAMES tf, int index)
{
   string tfName = GetTimeframeName(tf);
   LOG_DEBUG("📊 Pullback: Using price data on " + tfName + " (no indicators needed)", g_indicatorDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Is Data Available                                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsDataAvailable(ENUM_TIMEFRAMES tf, int minBars = 50)
{
   int bars = iBars(m_symbol, tf);
   LOG_DEBUG(GetTimeframeName(tf) + " has " + IntegerToString(bars) + " bars available", g_indicatorDebugMode);
   return (bars >= minBars);
}

//+------------------------------------------------------------------+
//| Get Best Available Timeframe                                    |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CIndicatorManager::GetBestAvailableTimeframe(ENUM_TIMEFRAMES preferred)
{
   if(IsDataAvailable(preferred, 50))
      return preferred;
   
   ENUM_TIMEFRAMES fallbacks[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_M15, PERIOD_M30};
   
   for(int i = 0; i < ArraySize(fallbacks); i++)
   {
      if(fallbacks[i] == preferred)
         continue;
      
      if(IsDataAvailable(fallbacks[i], 50))
      {
         LOG_DEBUG("Using fallback timeframe " + GetTimeframeName(fallbacks[i]) + 
                   " instead of " + GetTimeframeName(preferred), g_indicatorDebugMode);
         return fallbacks[i];
      }
   }
   
   return preferred;
}

//+------------------------------------------------------------------+
//| Ensure Indicators are Ready                                     |
//+------------------------------------------------------------------+
bool CIndicatorManager::EnsureIndicatorsReady(ENUM_TIMEFRAMES tf)
{
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
   {
      m_lastError = "Timeframe not found: " + GetTimeframeName(tf);
      LOG_ERROR(m_lastError);
      return false;
   }
   
   if(m_handles[idx].atr == INVALID_HANDLE || !ValidateHandle(m_handles[idx].atr))
   {
      LOG_DEBUG("Recreating indicators for " + GetTimeframeName(tf), g_indicatorDebugMode);
      
      if(!CreateIndicators(tf, idx))
      {
         m_lastError = "Failed to recreate indicators for " + GetTimeframeName(tf);
         LOG_ERROR(m_lastError);
         return false;
      }
   }
   
   double testValue[1];
   if(CopyBuffer(m_handles[idx].atr, 0, 0, 1, testValue) <= 0)
   {
      m_lastError = "Cannot get ATR values for " + GetTimeframeName(tf);
      LOG_ERROR(m_lastError);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CIndicatorManager::Initialize(MarketData* marketData = NULL, string symbol = NULL)
{
   if(m_initialized)
      return true;
   
   m_lastError = "";
   
   if(symbol != NULL)
      m_symbol = symbol;
   else if(m_symbol == "")
      m_symbol = Symbol();
   
   if(marketData != NULL)
   {
      m_marketData = marketData;
   }
   else if(m_marketData == NULL)
   {
      m_marketData = new MarketData(m_symbol);
      m_ownsMarketData = true;
      
      if(!m_marketData.Initialize())
      {
         m_lastError = "Failed to initialize MarketData";
         LOG_ERROR(m_lastError);
         return false;
      }
   }
   
   LOG_INFO("=== STARTING INDICATOR MANAGER INITIALIZATION (v3.1) ===", g_indicatorDebugMode);
   LOG_INFO("Symbol: " + m_symbol, g_indicatorDebugMode);
   LOG_INFO("Current Timeframe: " + GetTimeframeName(m_currentTimeframe), g_indicatorDebugMode);
   LOG_INFO("----------------------------------------", g_indicatorDebugMode);
   LOG_INFO("COMPONENT TIMEFRAME WEIGHT CONFIGURATION:", g_indicatorDebugMode);
   LOG_INFO("  ADX:   M5(1.5), H1(2.5), H4(3.0)", g_indicatorDebugMode);
   LOG_INFO("  MTF:   M1(0.3), M5(0.5), M15(0.8), M30(1.2), H1(2.0), H4(2.5), D1(3.0)", g_indicatorDebugMode);
   LOG_INFO("  RSI:   M5(1.0), H1(1.5), H4(2.0)", g_indicatorDebugMode);
   LOG_INFO("  MACD:  M5(1.0), H1(1.5), H4(2.0)", g_indicatorDebugMode);
   LOG_INFO("  Volume:M5(0.5), H1(1.0)", g_indicatorDebugMode);
   LOG_INFO("  Pullback:M5(1.0) - price data only", g_indicatorDebugMode);
   LOG_INFO("----------------------------------------", g_indicatorDebugMode);
   
   for(int i = 0; i < m_timeframeCount; i++)
   {
      if(!EnsureDataLoaded(m_timeframes[i], GetMinimumBarsForTF(m_timeframes[i])))
      {
         LOG_ERROR("Failed to load data for TF: " + GetTimeframeName(m_timeframes[i]));
      }
   }
   
   bool allSuccess = true;
   for(int i = 0; i < m_timeframeCount; i++)
   {
      if(!CreateIndicators(m_timeframes[i], i))
      {
         LOG_ERROR("Failed to create indicators for TF: " + GetTimeframeName(m_timeframes[i]));
         allSuccess = false;
      }
   }
   
   m_initialized = true;
   LOG_INFO("=== INDICATOR MANAGER INITIALIZATION COMPLETE ===", g_indicatorDebugMode);
   
   return allSuccess;
}

//+------------------------------------------------------------------+
//| Create Indicators for a timeframe - COMPONENT-BASED            |
//+------------------------------------------------------------------+
bool CIndicatorManager::CreateIndicators(ENUM_TIMEFRAMES tf, int index)
{
   if(index < 0 || index >= m_timeframeCount)
   {
      m_lastError = "Invalid index: " + IntegerToString(index);
      return false;
   }
   
   int bars = iBars(m_symbol, tf);
   int requiredBars = GetMinimumBarsForTF(tf);
   
   if(bars < requiredBars)
   {
      m_lastError = "Insufficient bars for " + GetTimeframeName(tf) + 
                    ": " + IntegerToString(bars) + " (need " + IntegerToString(requiredBars) + ")";
      LOG_ERROR(m_lastError);
      return false;
   }
   
   ReleaseHandles(index);
   
   bool allValid = true;
   string createdComponents = "";
   
   // 1. ADX MODULE - M5, H1, H4
   if(IsADXTimeframe(tf))
   {
      if(CreateADXIndicators(tf, index))
         createdComponents += "ADX ";
      else
         allValid = false;
   }
   
   // 2. MTF MODULE - ALL 7 TFs
   if(IsMTFTimeframe(tf))
   {
      if(CreateMTFIndicators(tf, index))
         createdComponents += "MTF ";
      else
         allValid = false;
   }
   
   // 3. RSI MODULE - M5, H1, H4
   if(IsRSITimeframe(tf))
   {
      if(CreateRSIIndicators(tf, index))
         createdComponents += "RSI ";
      else
         allValid = false;
   }
   
   // 4. MACD MODULE - M5, H1, H4
   if(IsMACDTimeframe(tf))
   {
      if(CreateMACDIndicators(tf, index))
         createdComponents += "MACD ";
      else
         allValid = false;
   }
   
   // 5. VOLUME MODULE - M5, H1
   if(IsVolumeTimeframe(tf))
   {
      if(CreateVolumeIndicators(tf, index))
         createdComponents += "VOL ";
      else
         allValid = false;
   }
   
   // 6. PULLBACK MODULE - M5 only
   if(IsPullbackTimeframe(tf))
   {
      if(CreatePullbackIndicators(tf, index))
         createdComponents += "PB ";
      else
         allValid = false;
   }
   
   // MA50 - Optional
   if(tf == m_currentTimeframe)
   {
      m_handles[index].ma_50 = iMA(m_symbol, tf, 50, 0, MODE_SMA, PRICE_CLOSE);
      if(ValidateHandle(m_handles[index].ma_50))
         createdComponents += "MA50 ";
   }
   
   string tfName = GetTimeframeName(tf);
   string status = allValid ? "✅" : "⚠️";
   
   if(createdComponents == "" || createdComponents == "PB ")
   {
      LOG_DEBUG("⏭️ No indicators needed for " + tfName, g_indicatorDebugMode);
      return true;
   }
   
   LOG_DEBUG(status + " Indicators for " + tfName + ": " + createdComponents, g_indicatorDebugMode);
   
   if(!allValid)
      LOG_ERROR("Some indicators failed to create on " + tfName);
   
   return allValid;
}

//+------------------------------------------------------------------+
//| Release Handles - Cleanup specific index                        |
//+------------------------------------------------------------------+
void CIndicatorManager::ReleaseHandles(int index)
{
   if(index < 0 || index >= m_timeframeCount) return;
   
   if(m_handles[index].ma_fast != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].ma_fast);
   if(m_handles[index].ma_medium != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].ma_medium);
   if(m_handles[index].ma_slow != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].ma_slow);
   if(m_handles[index].ma_50 != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].ma_50);
   if(m_handles[index].rsi != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].rsi);
   if(m_handles[index].macd != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].macd);
   if(m_handles[index].adx != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].adx);
   if(m_handles[index].stoch != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].stoch);
   if(m_handles[index].atr != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].atr);
   if(m_handles[index].volume != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].volume);
   if(m_handles[index].bbands != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].bbands);
   if(m_handles[index].awesome != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].awesome);
   if(m_handles[index].alligator != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].alligator);
   if(m_handles[index].fractals != INVALID_HANDLE)
      IndicatorRelease(m_handles[index].fractals);
   
   ZeroMemory(m_handles[index]);
}

//+------------------------------------------------------------------+
//| Validate Handle                                                  |
//+------------------------------------------------------------------+
bool CIndicatorManager::ValidateHandle(int handle)
{
   if(handle == INVALID_HANDLE)
      return false;
   
   double test[1];
   int copied = CopyBuffer(handle, 0, 0, 1, test);
   
   if(copied <= 0)
   {
      int error = GetLastError();
      LOG_DEBUG("Handle " + IntegerToString(handle) + 
                " invalid: copied=" + IntegerToString(copied) + 
                ", error=" + IntegerToString(error), g_indicatorDebugMode);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Reset All Handles                                               |
//+------------------------------------------------------------------+
void CIndicatorManager::ResetHandles()
{
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      m_handles[i].ma_fast = INVALID_HANDLE;
      m_handles[i].ma_medium = INVALID_HANDLE;
      m_handles[i].ma_slow = INVALID_HANDLE;
      m_handles[i].ma_50 = INVALID_HANDLE;
      m_handles[i].rsi = INVALID_HANDLE;
      m_handles[i].macd = INVALID_HANDLE;
      m_handles[i].adx = INVALID_HANDLE;
      m_handles[i].stoch = INVALID_HANDLE;
      m_handles[i].atr = INVALID_HANDLE;
      m_handles[i].volume = INVALID_HANDLE;
      m_handles[i].bbands = INVALID_HANDLE;
      m_handles[i].awesome = INVALID_HANDLE;
      m_handles[i].alligator = INVALID_HANDLE;
      m_handles[i].fractals = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Release All Handles                                             |
//+------------------------------------------------------------------+
void CIndicatorManager::ReleaseAllHandles()
{
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      ReleaseHandles(i);
   }
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CIndicatorManager::Deinitialize()
{
   if(!m_initialized)
      return;
   
   LOG_DEBUG("Deinitializing...", g_indicatorDebugMode);
   
   ReleaseAllHandles();
   ResetHandles();
   
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      for(int j = 0; j < m_maCacheSizes[i]; j++)
      {
         if(m_maCache[i][j].handle != INVALID_HANDLE)
         {
            IndicatorRelease(m_maCache[i][j].handle);
            m_maCache[i][j].handle = INVALID_HANDLE;
         }
      }
      m_maCacheSizes[i] = 0;
   }
   
   if(m_ownsMarketData && m_marketData != NULL)
   {
      delete m_marketData;
      m_marketData = NULL;
   }
   
   m_initialized = false;
   LOG_DEBUG("Deinitialized", g_indicatorDebugMode);
}

//+------------------------------------------------------------------+
//| Get Timeframe Index                                             |
//+------------------------------------------------------------------+
int CIndicatorManager::GetTimeframeIndex(ENUM_TIMEFRAMES tf)
{
   for(int i = 0; i < m_timeframeCount; i++)
   {
      if(m_timeframes[i] == tf)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Get Timeframe Name                                              |
//+------------------------------------------------------------------+
string CIndicatorManager::GetTimeframeName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "TF" + IntegerToString(tf);
   }
}

//+------------------------------------------------------------------+
//| Get Minimum Bars For Timeframe                                  |
//+------------------------------------------------------------------+
int CIndicatorManager::GetMinimumBarsForTF(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return 500;
      case PERIOD_M5: return 300;
      case PERIOD_M15: return 200;
      case PERIOD_M30: return 150;
      case PERIOD_H1: return 100;
      case PERIOD_H4: return 80;
      case PERIOD_D1: return 60;
      default: return 100;
   }
}

//+------------------------------------------------------------------+
//| Get Indicator Value                                             |
//+------------------------------------------------------------------+
double CIndicatorManager::GetIndicatorValue(int handle, int bufferNum, int shift)
{
   if(handle == INVALID_HANDLE)
      return EMPTY_VALUE;
   
   double buffer[1];
   ArrayInitialize(buffer, EMPTY_VALUE);
   
   int maxRetries = 3;
   for(int retry = 0; retry < maxRetries; retry++)
   {
      int copied = CopyBuffer(handle, bufferNum, shift, 1, buffer);
      
      if(copied > 0 && buffer[0] != EMPTY_VALUE && MathIsValidNumber(buffer[0]))
      {
         return buffer[0];
      }
      
      if(retry < maxRetries - 1)
         Sleep(10);
   }
   
   if(shift > 0)
   {
      for(int altShift = 1; altShift <= 3; altShift++)
      {
         int copied = CopyBuffer(handle, bufferNum, shift + altShift, 1, buffer);
         if(copied > 0 && buffer[0] != EMPTY_VALUE && MathIsValidNumber(buffer[0]))
            return buffer[0];
      }
   }
   
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Ensure Data Loaded                                              |
//+------------------------------------------------------------------+
bool CIndicatorManager::EnsureDataLoaded(ENUM_TIMEFRAMES tf, int requiredBars)
{
   int bars = iBars(m_symbol, tf);
   
   if(bars >= requiredBars)
      return true;
   
   LOG_DEBUG("Loading data for " + GetTimeframeName(tf) + 
             ": need " + IntegerToString(requiredBars) + 
             ", have " + IntegerToString(bars), g_indicatorDebugMode);
   
   MqlRates rates[];
   int toCopy = MathMax(requiredBars, 200);
   int copied = CopyRates(m_symbol, tf, 0, toCopy, rates);
   
   if(copied > 0)
   {
      bars = iBars(m_symbol, tf);
      LOG_DEBUG("After load: " + GetTimeframeName(tf) + 
                " has " + IntegerToString(bars) + " bars", g_indicatorDebugMode);
      return bars >= requiredBars;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Or Create MA Handle                                         |
//+------------------------------------------------------------------+
int CIndicatorManager::GetOrCreateMAHandle(ENUM_TIMEFRAMES tf, int period)
{
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return INVALID_HANDLE;
   
   for(int i = 0; i < m_maCacheSizes[idx]; i++)
   {
      if(m_maCache[idx][i].period == period)
      {
         m_maCache[idx][i].lastAccess = TimeCurrent();
         return m_maCache[idx][i].handle;
      }
   }
   
   int handle = iMA(m_symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE);
   
   if(handle == INVALID_HANDLE)
   {
      LOG_ERROR("Failed to create MA" + IntegerToString(period) + 
                " for " + GetTimeframeName(tf));
      return INVALID_HANDLE;
   }
   
   double test[1];
   if(CopyBuffer(handle, 0, 0, 1, test) <= 0)
   {
      LOG_ERROR("MA" + IntegerToString(period) + 
                " handle invalid for " + GetTimeframeName(tf));
      IndicatorRelease(handle);
      return INVALID_HANDLE;
   }
   
   if(m_maCacheSizes[idx] < MAX_MA_CACHE_SIZE)
   {
      m_maCache[idx][m_maCacheSizes[idx]].period = period;
      m_maCache[idx][m_maCacheSizes[idx]].handle = handle;
      m_maCache[idx][m_maCacheSizes[idx]].lastAccess = TimeCurrent();
      m_maCacheSizes[idx]++;
   }
   
   return handle;
}

//+------------------------------------------------------------------+
//| Get MA Values                                                   |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetMAValues(ENUM_TIMEFRAMES tf, double &maFast, double &maMedium, double &maSlow, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   maFast = GetIndicatorValue(m_handles[idx].ma_fast, 0, shift);
   maMedium = GetIndicatorValue(m_handles[idx].ma_medium, 0, shift);
   maSlow = GetIndicatorValue(m_handles[idx].ma_slow, 0, shift);
   
   return (maFast != EMPTY_VALUE && maMedium != EMPTY_VALUE && maSlow != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Get MA Values For Range Scanner                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetMAValuesForRange(ENUM_TIMEFRAMES tf, double &ma9, double &ma21, double &ma50, double &ma89, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   ma9 = GetIndicatorValue(m_handles[idx].ma_fast, 0, shift);
   ma21 = GetIndicatorValue(m_handles[idx].ma_medium, 0, shift);
   ma89 = GetIndicatorValue(m_handles[idx].ma_slow, 0, shift);
   
   int ma50Handle = GetOrCreateMAHandle(tf, 50);
   if(ma50Handle != INVALID_HANDLE)
      ma50 = GetIndicatorValue(ma50Handle, 0, shift);
   else
      ma50 = 0;
   
   return (ma9 != EMPTY_VALUE && ma21 != EMPTY_VALUE && ma50 != EMPTY_VALUE && ma89 != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Get MA (Single Period)                                          |
//+------------------------------------------------------------------+
double CIndicatorManager::GetMA(ENUM_TIMEFRAMES tf, int period, int shift = 0)
{
   if(!m_initialized)
      return 0;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return 0;
   
   if(period == 9)
      return GetIndicatorValue(m_handles[idx].ma_fast, 0, shift);
   else if(period == 21)
      return GetIndicatorValue(m_handles[idx].ma_medium, 0, shift);
   else if(period == 89)
      return GetIndicatorValue(m_handles[idx].ma_slow, 0, shift);
   else if(period == 50)
   {
      int handle = GetOrCreateMAHandle(tf, 50);
      if(handle != INVALID_HANDLE)
         return GetIndicatorValue(handle, 0, shift);
      return 0;
   }
   else
   {
      int handle = GetOrCreateMAHandle(tf, period);
      if(handle != INVALID_HANDLE)
         return GetIndicatorValue(handle, 0, shift);
      return 0;
   }
}

//+------------------------------------------------------------------+
//| Get MA Crossovers                                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetMACrossovers(ENUM_TIMEFRAMES tf, bool &goldenCross, bool &deathCross)
{
   goldenCross = false;
   deathCross = false;
   
   if(!m_initialized)
      return false;
   
   double maFast, maMedium, maSlow;
   double maFastPrev, maMediumPrev, maSlowPrev;
   
   if(!GetMAValues(tf, maFast, maMedium, maSlow, 0))
      return false;
   if(!GetMAValues(tf, maFastPrev, maMediumPrev, maSlowPrev, 1))
      return false;
   
   if(maFastPrev <= maSlowPrev && maFast > maSlow)
      goldenCross = true;
   
   if(maFastPrev >= maSlowPrev && maFast < maSlow)
      deathCross = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Get RSI                                                         |
//+------------------------------------------------------------------+
double CIndicatorManager::GetRSI(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return 50.0;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return 50.0;
   
   double rsi = GetIndicatorValue(m_handles[idx].rsi, 0, shift);
   
   if(rsi == EMPTY_VALUE || !MathIsValidNumber(rsi) || rsi < 0 || rsi > 100)
      return 50.0;
   
   return rsi;
}

//+------------------------------------------------------------------+
//| Is Overbought                                                   |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsOverbought(ENUM_TIMEFRAMES tf, int threshold = 70)
{
   double rsi = GetRSI(tf);
   double stochK, stochD;
   GetStochasticValues(tf, stochK, stochD);
   
   return (rsi > threshold && stochK > 80);
}

//+------------------------------------------------------------------+
//| Is Oversold                                                     |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsOversold(ENUM_TIMEFRAMES tf, int threshold = 30)
{
   double rsi = GetRSI(tf);
   double stochK, stochD;
   GetStochasticValues(tf, stochK, stochD);
   
   return (rsi < threshold && stochK < 20);
}

//+------------------------------------------------------------------+
//| WEIGHTED RSI METHODS                                            |
//+------------------------------------------------------------------+

double CIndicatorManager::GetWeightedRSI()
{
   double values[3];
   double weights[3];
   int count = 0;
   
   double rsi = GetRSI(PERIOD_M5);
   if(rsi != EMPTY_VALUE && rsi > 0 && rsi <= 100)
   {
      values[count] = rsi;
      weights[count] = m_weights.rsiM5;
      count++;
   }
   
   rsi = GetRSI(PERIOD_H1);
   if(rsi != EMPTY_VALUE && rsi > 0 && rsi <= 100)
   {
      values[count] = rsi;
      weights[count] = m_weights.rsiH1;
      count++;
   }
   
   rsi = GetRSI(PERIOD_H4);
   if(rsi != EMPTY_VALUE && rsi > 0 && rsi <= 100)
   {
      values[count] = rsi;
      weights[count] = m_weights.rsiH4;
      count++;
   }
   
   if(count == 0) return 50;
   return CalculateWeightedAverage(values, weights, count);
}

string CIndicatorManager::GetWeightedRSIDirection()
{
   double rsi = GetWeightedRSI();
   if(rsi > 60) return "BULLISH";
   if(rsi < 40) return "BEARISH";
   return "NEUTRAL";
}

bool CIndicatorManager::IsWeightedOverbought(int threshold = 70)
{
   return (GetWeightedRSI() > threshold);
}

bool CIndicatorManager::IsWeightedOversold(int threshold = 30)
{
   return (GetWeightedRSI() < threshold);
}

//+------------------------------------------------------------------+
//| Get MACD Values                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetMACDValues(ENUM_TIMEFRAMES tf, double &main, double &signal, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   main = GetIndicatorValue(m_handles[idx].macd, 0, shift);
   signal = GetIndicatorValue(m_handles[idx].macd, 1, shift);
   
   return (main != EMPTY_VALUE && signal != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Get MACD Crossover                                              |
//+------------------------------------------------------------------+
int CIndicatorManager::GetMACDCrossover(ENUM_TIMEFRAMES tf)
{
   double main, signal;
   double mainPrev, signalPrev;
   
   if(!GetMACDValues(tf, main, signal, 0))
      return 0;
   if(!GetMACDValues(tf, mainPrev, signalPrev, 1))
      return 0;
   
   if(mainPrev <= signalPrev && main > signal)
      return 1;
   if(mainPrev >= signalPrev && main < signal)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Is MACD Bullish                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsMACDBullish(ENUM_TIMEFRAMES tf)
{
   double main, signal;
   if(!GetMACDValues(tf, main, signal))
      return false;
   return (main > signal);
}

//+------------------------------------------------------------------+
//| Is MACD Bearish                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsMACDBearish(ENUM_TIMEFRAMES tf)
{
   double main, signal;
   if(!GetMACDValues(tf, main, signal))
      return false;
   return (main < signal);
}

//+------------------------------------------------------------------+
//| WEIGHTED MACD METHODS                                           |
//+------------------------------------------------------------------+

double CIndicatorManager::GetWeightedMACD()
{
   double values[3];
   double weights[3];
   int count = 0;
   
   double main, signal;
   if(GetMACDValues(PERIOD_M5, main, signal))
   {
      values[count] = main - signal;
      weights[count] = m_weights.macdM5;
      count++;
   }
   
   if(GetMACDValues(PERIOD_H1, main, signal))
   {
      values[count] = main - signal;
      weights[count] = m_weights.macdH1;
      count++;
   }
   
   if(GetMACDValues(PERIOD_H4, main, signal))
   {
      values[count] = main - signal;
      weights[count] = m_weights.macdH4;
      count++;
   }
   
   if(count == 0) return 0;
   return CalculateWeightedAverage(values, weights, count);
}

string CIndicatorManager::GetWeightedMACDDirection()
{
   double hist = GetWeightedMACD();
   double threshold = 0.0001;
   
   if(hist > threshold) return "BULLISH";
   if(hist < -threshold) return "BEARISH";
   return "NEUTRAL";
}

bool CIndicatorManager::IsWeightedMACDBullish()
{
   return (GetWeightedMACDDirection() == "BULLISH");
}

bool CIndicatorManager::IsWeightedMACDBearish()
{
   return (GetWeightedMACDDirection() == "BEARISH");
}

//+------------------------------------------------------------------+
//| Get ADX Values - IMPROVED WITH RETRY AND VALIDATION            |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetADXValues(ENUM_TIMEFRAMES tf, double &adx, double &plusDI, double &minusDI, int shift = 0)
{
   adx = 0;
   plusDI = 0;
   minusDI = 0;
   
   if(!m_initialized)
   {
      m_lastError = "IndicatorManager not initialized";
      LOG_ERROR(m_lastError);
      return false;
   }
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
   {
      m_lastError = "Timeframe " + GetTimeframeName(tf) + " not found";
      LOG_ERROR(m_lastError);
      return false;
   }
   
   if(!EnsureIndicatorsReady(tf))
   {
      LOG_ERROR("Indicators not ready for " + GetTimeframeName(tf));
      return false;
   }
   
   int maxRetries = 3;
   for(int retry = 0; retry < maxRetries; retry++)
   {
      adx = GetIndicatorValue(m_handles[idx].adx, 0, shift);
      plusDI = GetIndicatorValue(m_handles[idx].adx, 1, shift);
      minusDI = GetIndicatorValue(m_handles[idx].adx, 2, shift);
      
      if(adx != EMPTY_VALUE && plusDI != EMPTY_VALUE && minusDI != EMPTY_VALUE)
      {
         if(MathIsValidNumber(adx) && MathIsValidNumber(plusDI) && MathIsValidNumber(minusDI))
         {
            LOG_DEBUG("✅ Got ADX values for " + GetTimeframeName(tf) + 
                      ": ADX=" + DoubleToString(adx, 2) + 
                      ", +DI=" + DoubleToString(plusDI, 2) + 
                      ", -DI=" + DoubleToString(minusDI, 2), g_indicatorDebugMode);
            return true;
         }
      }
      
      if(retry < maxRetries - 1)
      {
         LOG_DEBUG("Retry " + IntegerToString(retry + 1) + " for " + GetTimeframeName(tf), g_indicatorDebugMode);
         Sleep(50);
      }
   }
   
   if(shift == 0)
   {
      LOG_DEBUG("Trying with shift 1 for " + GetTimeframeName(tf), g_indicatorDebugMode);
      adx = GetIndicatorValue(m_handles[idx].adx, 0, 1);
      plusDI = GetIndicatorValue(m_handles[idx].adx, 1, 1);
      minusDI = GetIndicatorValue(m_handles[idx].adx, 2, 1);
      
      if(adx != EMPTY_VALUE && plusDI != EMPTY_VALUE && minusDI != EMPTY_VALUE)
      {
         if(MathIsValidNumber(adx) && MathIsValidNumber(plusDI) && MathIsValidNumber(minusDI))
         {
            LOG_DEBUG("✅ Got ADX values from shift 1 for " + GetTimeframeName(tf), g_indicatorDebugMode);
            return true;
         }
      }
   }
   
   m_lastError = "Failed to get ADX values for " + GetTimeframeName(tf) + " after retries";
   LOG_ERROR(m_lastError);
   return false;
}

//+------------------------------------------------------------------+
//| Is Strong Trend                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsStrongTrend(ENUM_TIMEFRAMES tf, int threshold = 25)
{
   double adx, plusDI, minusDI;
   if(!GetADXValues(tf, adx, plusDI, minusDI))
      return false;
   return (adx > threshold);
}

//+------------------------------------------------------------------+
//| Get ADX Trend Direction                                         |
//+------------------------------------------------------------------+
int CIndicatorManager::GetADXTrendDirection(ENUM_TIMEFRAMES tf)
{
   double adx, plusDI, minusDI;
   if(!GetADXValues(tf, adx, plusDI, minusDI))
      return 0;
   
   if(plusDI > minusDI)
      return 1;
   else if(minusDI > plusDI)
      return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| WEIGHTED ADX METHODS                                            |
//+------------------------------------------------------------------+

double CIndicatorManager::GetWeightedADX()
{
   double values[3];
   double weights[3];
   int count = 0;
   
   double adx, plusDI, minusDI;
   if(GetADXValues(PERIOD_M5, adx, plusDI, minusDI) && adx > 0)
   {
      values[count] = adx;
      weights[count] = m_weights.adxM5;
      count++;
   }
   
   if(GetADXValues(PERIOD_H1, adx, plusDI, minusDI) && adx > 0)
   {
      values[count] = adx;
      weights[count] = m_weights.adxH1;
      count++;
   }
   
   if(GetADXValues(PERIOD_H4, adx, plusDI, minusDI) && adx > 0)
   {
      values[count] = adx;
      weights[count] = m_weights.adxH4;
      count++;
   }
   
   if(count == 0) return 0;
   return CalculateWeightedAverage(values, weights, count);
}

string CIndicatorManager::GetWeightedADXDirection()
{
   double weightedADX = GetWeightedADX();
   if(weightedADX < 20) return "NEUTRAL";
   
   double bullScore = 0;
   double bearScore = 0;
   
   double adx, plusDI, minusDI;
   if(GetADXValues(PERIOD_M5, adx, plusDI, minusDI))
   {
      if(plusDI > minusDI) bullScore += m_weights.adxM5;
      else if(minusDI > plusDI) bearScore += m_weights.adxM5;
   }
   
   if(GetADXValues(PERIOD_H1, adx, plusDI, minusDI))
   {
      if(plusDI > minusDI) bullScore += m_weights.adxH1;
      else if(minusDI > plusDI) bearScore += m_weights.adxH1;
   }
   
   if(GetADXValues(PERIOD_H4, adx, plusDI, minusDI))
   {
      if(plusDI > minusDI) bullScore += m_weights.adxH4;
      else if(minusDI > plusDI) bearScore += m_weights.adxH4;
   }
   
   if(bullScore > bearScore) return "BULLISH";
   if(bearScore > bullScore) return "BEARISH";
   return "NEUTRAL";
}

bool CIndicatorManager::IsWeightedStrongTrend(int threshold = 25)
{
   return (GetWeightedADX() > threshold);
}

double CIndicatorManager::GetWeightedADXStrength()
{
   double adx = GetWeightedADX();
   if(adx <= 0) return 0;
   return MathMin(adx / 40.0, 1.0) * 100;
}

//+------------------------------------------------------------------+
//| WEIGHTED VOLUME METHODS                                         |
//+------------------------------------------------------------------+

bool CIndicatorManager::IsWeightedVolumeSpike(double multiplier = 2.0)
{
   double score = 0;
   
   if(IsVolumeSpike(PERIOD_M5, multiplier))
      score += m_weights.volM5;
   
   if(IsVolumeSpike(PERIOD_H1, multiplier))
      score += m_weights.volH1;
   
   return (score >= 1.0);
}

double CIndicatorManager::GetWeightedVolumeScore()
{
   double score = 0;
   double totalWeight = 0;
   
   long volM5 = GetVolume(PERIOD_M5);
   double avgVolM5 = GetAverageVolume(PERIOD_M5, 20);
   if(avgVolM5 > 0)
   {
      double ratio = (double)volM5 / avgVolM5;
      score += MathMin(ratio, 3.0) * m_weights.volM5;
      totalWeight += m_weights.volM5;
   }
   
   long volH1 = GetVolume(PERIOD_H1);
   double avgVolH1 = GetAverageVolume(PERIOD_H1, 20);
   if(avgVolH1 > 0)
   {
      double ratio = (double)volH1 / avgVolH1;
      score += MathMin(ratio, 3.0) * m_weights.volH1;
      totalWeight += m_weights.volH1;
   }
   
   if(totalWeight == 0) return 0;
   return (score / totalWeight) * 100;
}

//+------------------------------------------------------------------+
//| Get Stochastic Values                                           |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetStochasticValues(ENUM_TIMEFRAMES tf, double &k, double &d, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   k = GetIndicatorValue(m_handles[idx].stoch, 0, shift);
   d = GetIndicatorValue(m_handles[idx].stoch, 1, shift);
   
   return (k != EMPTY_VALUE && d != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Is Stochastic Overbought                                        |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsStochasticOverbought(ENUM_TIMEFRAMES tf, int threshold = 80)
{
   double k, d;
   if(!GetStochasticValues(tf, k, d))
      return false;
   return (k > threshold);
}

//+------------------------------------------------------------------+
//| Is Stochastic Oversold                                          |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsStochasticOversold(ENUM_TIMEFRAMES tf, int threshold = 20)
{
   double k, d;
   if(!GetStochasticValues(tf, k, d))
      return false;
   return (k < threshold);
}

//+------------------------------------------------------------------+
//| Is Stochastic Crossover                                         |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsStochasticCrossover(ENUM_TIMEFRAMES tf)
{
   double k, d;
   double kPrev, dPrev;
   
   if(!GetStochasticValues(tf, k, d, 0))
      return false;
   if(!GetStochasticValues(tf, kPrev, dPrev, 1))
      return false;
   
   return ((kPrev <= dPrev && k > d) || (kPrev >= dPrev && k < d));
}

//+------------------------------------------------------------------+
//| Get ATR                                                         |
//+------------------------------------------------------------------+
double CIndicatorManager::GetATR(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return GetDefaultATR();
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return GetDefaultATR();
   
   if(m_handles[idx].atr == INVALID_HANDLE)
   {
      LOG_DEBUG("ATR handle invalid, recreating...", g_indicatorDebugMode);
      m_handles[idx].atr = iATR(m_symbol, tf, 14);
      if(m_handles[idx].atr == INVALID_HANDLE)
         return GetDefaultATR();
   }
   
   double atr = GetIndicatorValue(m_handles[idx].atr, 0, shift);
   
   if(atr == EMPTY_VALUE || atr <= 0)
   {
      LOG_DEBUG("ATR invalid: " + DoubleToString(atr) + ", using fallback", g_indicatorDebugMode);
      return GetDefaultATR();
   }
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   if(point <= 0)
      return atr;
   
   if(IsGoldSymbol())
   {
      double maxATR = (tf == PERIOD_M1) ? 0.8 : (tf == PERIOD_M5) ? 2.0 : (tf == PERIOD_M15) ? 3.0 : (tf == PERIOD_M30) ? 4.0 : 50.0;
      double minATR = 0.05;
      if(atr > maxATR) atr = maxATR;
      if(atr < minATR) atr = minATR;
   }
   else if(IsForexSymbol())
   {
      double maxATR = (tf == PERIOD_M1) ? 0.0003 : (tf == PERIOD_M5) ? 0.0008 : (tf == PERIOD_M15) ? 0.0015 : (tf == PERIOD_M30) ? 0.0020 : 0.01;
      double minATR = 0.00003;
      if(atr > maxATR) atr = maxATR;
      if(atr < minATR) atr = minATR;
   }
   
   return atr;
}

//+------------------------------------------------------------------+
//| Get ATR With Fallback                                           |
//+------------------------------------------------------------------+
double CIndicatorManager::GetATRWithFallback(ENUM_TIMEFRAMES tf, int shift = 0)
{
   double atr = GetATR(tf, shift);
   
   if(atr > 0)
      return atr;
   
   ENUM_TIMEFRAMES fallbackTFs[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(int i = 0; i < ArraySize(fallbackTFs); i++)
   {
      if(fallbackTFs[i] == tf)
         continue;
      
      double fallback = GetATR(fallbackTFs[i], shift);
      if(fallback > 0)
      {
         LOG_DEBUG("Using fallback TF " + GetTimeframeName(fallbackTFs[i]) + 
                   " ATR: " + DoubleToString(fallback, 5), g_indicatorDebugMode);
         return fallback;
      }
   }
   
   return GetDefaultATR();
}

//+------------------------------------------------------------------+
//| Get ATR In Pips                                                 |
//+------------------------------------------------------------------+
double CIndicatorManager::GetATRInPips(ENUM_TIMEFRAMES tf, int shift = 0)
{
   double atr = GetATRWithFallback(tf, shift);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   if(point <= 0 || atr <= 0)
      return 0;
   
   return atr / point;
}

//+------------------------------------------------------------------+
//| Is High Volatility                                              |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsHighVolatility(ENUM_TIMEFRAMES tf, double threshold = 1.5)
{
   double atr = GetATR(tf);
   double avgRange = GetAverageVolume(tf, 20) > 0 ? GetAverageVolume(tf, 20) : 1;
   
   if(avgRange <= 0)
      return false;
   
   return (atr / avgRange) > threshold;
}

//+------------------------------------------------------------------+
//| Is Low Volatility                                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsLowVolatility(ENUM_TIMEFRAMES tf, double threshold = 0.5)
{
   double atr = GetATR(tf);
   double avgRange = GetAverageVolume(tf, 20) > 0 ? GetAverageVolume(tf, 20) : 1;
   
   if(avgRange <= 0)
      return false;
   
   return (atr / avgRange) < threshold;
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands                                             |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetBollingerBands(ENUM_TIMEFRAMES tf, double &upper, double &middle, double &lower, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   upper = GetIndicatorValue(m_handles[idx].bbands, 0, shift);
   middle = GetIndicatorValue(m_handles[idx].bbands, 1, shift);
   lower = GetIndicatorValue(m_handles[idx].bbands, 2, shift);
   
   return (upper != EMPTY_VALUE && middle != EMPTY_VALUE && lower != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Get BBands Position                                             |
//+------------------------------------------------------------------+
int CIndicatorManager::GetBBandsPosition(ENUM_TIMEFRAMES tf, double price, int shift = 0)
{
   double upper, middle, lower;
   if(!GetBollingerBands(tf, upper, middle, lower, shift))
      return 0;
   
   if(price >= upper) return 1;
   if(price <= lower) return -1;
   if(price > middle) return 2;
   if(price < middle) return -2;
   return 0;
}

//+------------------------------------------------------------------+
//| Is BBands Squeeze                                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsBBandsSqueeze(ENUM_TIMEFRAMES tf, double threshold = 0.5)
{
   double upper, middle, lower;
   if(!GetBollingerBands(tf, upper, middle, lower))
      return false;
   
   double bandwidth = (upper - lower) / middle;
   double avgBandwidth = 0;
   int count = 0;
   
   for(int i = 1; i <= 20; i++)
   {
      double u, m, l;
      if(GetBollingerBands(tf, u, m, l, i))
      {
         avgBandwidth += (u - l) / m;
         count++;
      }
   }
   
   if(count == 0) return false;
   avgBandwidth /= count;
   
   return bandwidth < (avgBandwidth * threshold);
}

//+------------------------------------------------------------------+
//| Get Volume                                                      |
//+------------------------------------------------------------------+
long CIndicatorManager::GetVolume(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return 0;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return 0;
   
   double volume = GetIndicatorValue(m_handles[idx].volume, 0, shift);
   return (long)volume;
}

//+------------------------------------------------------------------+
//| Is Volume Spike                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsVolumeSpike(ENUM_TIMEFRAMES tf, double multiplier = 2.0)
{
   long currentVolume = GetVolume(tf, 0);
   double avgVolume = GetAverageVolume(tf, 20);
   
   if(avgVolume <= 0 || currentVolume <= 0)
      return false;
   
   return (currentVolume > avgVolume * multiplier);
}

//+------------------------------------------------------------------+
//| Get Average Volume                                              |
//+------------------------------------------------------------------+
double CIndicatorManager::GetAverageVolume(ENUM_TIMEFRAMES tf, int period = 20)
{
   if(!m_initialized)
      return 0;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return 0;
   
   double sum = 0.0;
   int count = 0;
   
   for(int i = 0; i < period; i++)
   {
      double vol = GetIndicatorValue(m_handles[idx].volume, 0, i);
      if(vol > 0 && vol != EMPTY_VALUE)
      {
         sum += vol;
         count++;
      }
   }
   
   return (count > 0) ? sum / count : 0;
}

//+------------------------------------------------------------------+
//| Get Awesome Oscillator                                          |
//+------------------------------------------------------------------+
double CIndicatorManager::GetAwesomeOscillator(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return 0;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return 0;
   
   return GetIndicatorValue(m_handles[idx].awesome, 0, shift);
}

//+------------------------------------------------------------------+
//| Is Awesome Bullish                                              |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsAwesomeBullish(ENUM_TIMEFRAMES tf)
{
   double current = GetAwesomeOscillator(tf, 0);
   double previous = GetAwesomeOscillator(tf, 1);
   
   return (current > 0 && current > previous);
}

//+------------------------------------------------------------------+
//| Is Awesome Bearish                                              |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsAwesomeBearish(ENUM_TIMEFRAMES tf)
{
   double current = GetAwesomeOscillator(tf, 0);
   double previous = GetAwesomeOscillator(tf, 1);
   
   return (current < 0 && current < previous);
}

//+------------------------------------------------------------------+
//| Get Alligator Values                                            |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetAlligatorValues(ENUM_TIMEFRAMES tf, double &jaw, double &teeth, double &lips, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   jaw = GetIndicatorValue(m_handles[idx].alligator, 0, shift);
   teeth = GetIndicatorValue(m_handles[idx].alligator, 1, shift);
   lips = GetIndicatorValue(m_handles[idx].alligator, 2, shift);
   
   return (jaw != EMPTY_VALUE && teeth != EMPTY_VALUE && lips != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Get Alligator State                                             |
//+------------------------------------------------------------------+
int CIndicatorManager::GetAlligatorState(ENUM_TIMEFRAMES tf)
{
   double jaw, teeth, lips;
   if(!GetAlligatorValues(tf, jaw, teeth, lips))
      return 0;
   
   if(jaw < teeth && teeth < lips)
      return 1;
   if(jaw > teeth && teeth > lips)
      return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Is Fractal High                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsFractalHigh(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   double fractal = GetIndicatorValue(m_handles[idx].fractals, 0, shift);
   return (fractal != EMPTY_VALUE && fractal > 0);
}

//+------------------------------------------------------------------+
//| Is Fractal Low                                                  |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsFractalLow(ENUM_TIMEFRAMES tf, int shift = 0)
{
   if(!m_initialized)
      return false;
   
   int idx = GetTimeframeIndex(tf);
   if(idx == -1)
      return false;
   
   double fractal = GetIndicatorValue(m_handles[idx].fractals, 1, shift);
   return (fractal != EMPTY_VALUE && fractal > 0);
}

//+------------------------------------------------------------------+
//| Get Fractal High                                                |
//+------------------------------------------------------------------+
double CIndicatorManager::GetFractalHigh(ENUM_TIMEFRAMES tf, int lookback = 10)
{
   for(int i = 0; i < lookback; i++)
   {
      if(IsFractalHigh(tf, i))
         return GetHigh(tf, i);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get Fractal Low                                                 |
//+------------------------------------------------------------------+
double CIndicatorManager::GetFractalLow(ENUM_TIMEFRAMES tf, int lookback = 10)
{
   for(int i = 0; i < lookback; i++)
   {
      if(IsFractalLow(tf, i))
         return GetLow(tf, i);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Is Trend Bullish                                                |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsTrendBullish(ENUM_TIMEFRAMES tf)
{
   double maFast, maMedium, maSlow;
   if(!GetMAValues(tf, maFast, maMedium, maSlow))
      return false;
   
   return (maFast > maMedium && maMedium > maSlow);
}

//+------------------------------------------------------------------+
//| Is Trend Bearish                                                |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsTrendBearish(ENUM_TIMEFRAMES tf)
{
   double maFast, maMedium, maSlow;
   if(!GetMAValues(tf, maFast, maMedium, maSlow))
      return false;
   
   return (maFast < maMedium && maMedium < maSlow);
}

//+------------------------------------------------------------------+
//| Get Trend Strength                                              |
//+------------------------------------------------------------------+
int CIndicatorManager::GetTrendStrength(ENUM_TIMEFRAMES tf)
{
   double adx, plusDI, minusDI;
   if(!GetADXValues(tf, adx, plusDI, minusDI))
      return 0;
   
   return (int)adx;
}

//+------------------------------------------------------------------+
//| Get Multi-Timeframe Confirmation                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetMultiTimeframeConfirmation(int &bullishCount, int &bearishCount)
{
   bullishCount = 0;
   bearishCount = 0;
   
   if(!m_initialized)
      return false;
   
   for(int i = 0; i < m_timeframeCount; i++)
   {
      if(IsTrendBullish(m_timeframes[i]))
         bullishCount++;
      else if(IsTrendBearish(m_timeframes[i]))
         bearishCount++;
   }
   
   return (bullishCount > 0 || bearishCount > 0);
}

//+------------------------------------------------------------------+
//| Get Market Score                                                |
//+------------------------------------------------------------------+
double CIndicatorManager::GetMarketScore()
{
   if(!m_initialized)
      return 0.5;
   
   int bullish, bearish;
   GetMultiTimeframeConfirmation(bullish, bearish);
   
   double score = 0.5;
   int total = bullish + bearish;
   
   if(total > 0)
   {
      score = (double)bullish / total;
   }
   
   double rsi = GetRSI(PERIOD_H1);
   if(rsi > 70) score -= 0.1;
   else if(rsi < 30) score += 0.1;
   
   return MathMax(0.0, MathMin(1.0, score));
}

//+------------------------------------------------------------------+
//| Get Market Condition                                            |
//+------------------------------------------------------------------+
string CIndicatorManager::GetMarketCondition(ENUM_TIMEFRAMES tf)
{
   if(!m_initialized)
      return "UNKNOWN";
   
   bool bullish = IsTrendBullish(tf);
   bool bearish = IsTrendBearish(tf);
   bool strong = IsStrongTrend(tf);
   bool overbought = IsOverbought(tf);
   bool oversold = IsOversold(tf);
   int adxDir = GetADXTrendDirection(tf);
   
   if(bullish && strong)
      return "STRONG_BULLISH";
   else if(bearish && strong)
      return "STRONG_BEARISH";
   else if(bullish)
      return "BULLISH";
   else if(bearish)
      return "BEARISH";
   else if(overbought)
      return "OVERBOUGHT";
   else if(oversold)
      return "OVERSOLD";
   else
      return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| WEIGHTED OVERALL SCORE                                          |
//+------------------------------------------------------------------+

double CIndicatorManager::GetWeightedOverallScore()
{
   double totalScore = 0;
   double totalWeight = 0;
   
   double adx = GetWeightedADX();
   double adxStrength = MathMin(adx / 40.0, 1.0);
   double adxWeight = 3.0;
   totalScore += adxStrength * adxWeight;
   totalWeight += adxWeight;
   
   double rsi = GetWeightedRSI();
   double rsiScore = 0;
   if(rsi > 50) rsiScore = (rsi - 50) / 50.0;
   else rsiScore = -(50 - rsi) / 50.0;
   double rsiWeight = 2.0;
   totalScore += rsiScore * rsiWeight;
   totalWeight += rsiWeight;
   
   double macd = GetWeightedMACD();
   double macdScore = 0;
   if(macd > 0) macdScore = MathMin(macd / 0.001, 1.0);
   else macdScore = MathMax(macd / 0.001, -1.0);
   double macdWeight = 2.0;
   totalScore += macdScore * macdWeight;
   totalWeight += macdWeight;
   
   double volScore = GetWeightedVolumeScore() / 100.0;
   double volWeight = 1.0;
   totalScore += volScore * volWeight;
   totalWeight += volWeight;
   
   if(totalWeight == 0) return 0.5;
   
   double finalScore = (totalScore / totalWeight);
   return (finalScore * 50) + 50;
}

string CIndicatorManager::GetWeightedOverallDirection()
{
   double score = GetWeightedOverallScore();
   if(score >= 65) return "STRONG_BULLISH";
   if(score >= 55) return "BULLISH";
   if(score >= 45) return "NEUTRAL";
   if(score >= 35) return "BEARISH";
   return "STRONG_BEARISH";
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                         |
//+------------------------------------------------------------------+
double CIndicatorManager::CalculatePositionSize(double riskPercent, double stopLossPips, ENUM_TIMEFRAMES tf = PERIOD_M15)
{
   if(!m_initialized)
      return 0.01;
   
   double atr = GetATRWithFallback(tf);
   if(atr <= 0)
      return 0.01;
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double atrPips = atr / point;
   
   if(stopLossPips < atrPips * 1.5)
      stopLossPips = atrPips * 1.5;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pipValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE) * 
                     (point / SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE));
   
   if(pipValue <= 0 || stopLossPips <= 0)
      return 0.01;
   
   double lotSize = riskAmount / (pipValue * stopLossPips);
   
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathRound(lotSize / step) * step;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = NormalizeDouble(lotSize, 2);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Adjusted Stop Loss                                          |
//+------------------------------------------------------------------+
double CIndicatorManager::GetAdjustedStopLoss(ENUM_TIMEFRAMES tf, double entryPrice, bool isBuy, double atrMultiplier = 2.0)
{
   if(!m_initialized)
      return 0;
   
   double atr = GetATRWithFallback(tf);
   if(atr <= 0)
      return 0;
   
   if(isBuy)
      return entryPrice - (atr * atrMultiplier);
   else
      return entryPrice + (atr * atrMultiplier);
}

//+------------------------------------------------------------------+
//| Get Adjusted Take Profit                                        |
//+------------------------------------------------------------------+
double CIndicatorManager::GetAdjustedTakeProfit(ENUM_TIMEFRAMES tf, double entryPrice, bool isBuy, double riskReward = 2.0)
{
   if(!m_initialized)
      return 0;
   
   double atr = GetATRWithFallback(tf);
   if(atr <= 0)
      return 0;
   
   double stopLoss = GetAdjustedStopLoss(tf, entryPrice, isBuy, 1.0);
   if(stopLoss <= 0)
      return 0;
   
   double risk = MathAbs(entryPrice - stopLoss);
   
   if(isBuy)
      return entryPrice + (risk * riskReward);
   else
      return entryPrice - (risk * riskReward);
}

//+------------------------------------------------------------------+
//| Helper: Get High Price                                          |
//+------------------------------------------------------------------+
double CIndicatorManager::GetHigh(ENUM_TIMEFRAMES tf, int shift)
{
   if(m_marketData != NULL)
      return m_marketData.GetHigh(shift, m_symbol, tf);
   
   return iHigh(m_symbol, tf, shift);
}

//+------------------------------------------------------------------+
//| Helper: Get Low Price                                           |
//+------------------------------------------------------------------+
double CIndicatorManager::GetLow(ENUM_TIMEFRAMES tf, int shift)
{
   if(m_marketData != NULL)
      return m_marketData.GetLow(shift, m_symbol, tf);
   
   return iLow(m_symbol, tf, shift);
}

//+------------------------------------------------------------------+
//| Helper: Get Close Price                                         |
//+------------------------------------------------------------------+
double CIndicatorManager::GetClose(ENUM_TIMEFRAMES tf, int shift)
{
   if(m_marketData != NULL)
      return m_marketData.GetClose(shift, m_symbol, tf);
   
   return iClose(m_symbol, tf, shift);
}

//+------------------------------------------------------------------+
//| Helper: Is Gold Symbol                                          |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsGoldSymbol()
{
   return (StringFind(m_symbol, "XAU") >= 0 || StringFind(m_symbol, "GOLD") >= 0);
}

//+------------------------------------------------------------------+
//| Helper: Is Forex Symbol                                         |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsForexSymbol()
{
   string baseCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
   return (StringLen(baseCurrency) == 3 && !IsGoldSymbol() && !IsCryptoSymbol());
}

//+------------------------------------------------------------------+
//| Helper: Is Crypto Symbol                                        |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsCryptoSymbol()
{
   return (StringFind(m_symbol, "BTC") >= 0 || StringFind(m_symbol, "ETH") >= 0 || 
           StringFind(m_symbol, "XRP") >= 0 || StringFind(m_symbol, "LTC") >= 0);
}

//+------------------------------------------------------------------+
//| Get Default ATR                                                 |
//+------------------------------------------------------------------+
double CIndicatorManager::GetDefaultATR()
{
   if(IsGoldSymbol())
      return 2.0;
   else if(IsCryptoSymbol())
      return 50.0;
   else
      return 0.0007;
}

//+------------------------------------------------------------------+
//| Get Timeframe Data                                              |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetTimeframeData(ENUM_TIMEFRAMES tf, MqlRates &rates[], int count = 100)
{
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, tf, 0, count, rates);
   return (copied == count);
}

//+------------------------------------------------------------------+
//| OnTick - Update indicators                                      |
//+------------------------------------------------------------------+
void CIndicatorManager::OnTick()
{
   if(!m_initialized)
      return;
   
   if(m_marketData != NULL)
      m_marketData.Refresh();
}

//+------------------------------------------------------------------+
//| OnTimer - Periodic updates                                      |
//+------------------------------------------------------------------+
void CIndicatorManager::OnTimer()
{
   if(!m_initialized)
      return;
   
   Cleanup();
}

//+------------------------------------------------------------------+
//| Refresh Data                                                    |
//+------------------------------------------------------------------+
void CIndicatorManager::Refresh()
{
   if(!m_initialized)
      return;
   
   if(m_marketData != NULL)
      m_marketData.Refresh();
}

//+------------------------------------------------------------------+
//| Cleanup                                                         |
//+------------------------------------------------------------------+
void CIndicatorManager::Cleanup()
{
   for(int i = 0; i < MAX_TIMEFRAMES; i++)
   {
      CleanMACache(i);
   }
}

//+------------------------------------------------------------------+
//| Clean MA Cache                                                  |
//+------------------------------------------------------------------+
void CIndicatorManager::CleanMACache(int timeframeIndex)
{
   datetime now = TimeCurrent();
   const int MAX_AGE = 3600;
   
   for(int i = 0; i < m_maCacheSizes[timeframeIndex]; i++)
   {
      if(now - m_maCache[timeframeIndex][i].lastAccess > MAX_AGE)
      {
         if(m_maCache[timeframeIndex][i].handle != INVALID_HANDLE)
            IndicatorRelease(m_maCache[timeframeIndex][i].handle);
         
         for(int j = i; j < m_maCacheSizes[timeframeIndex] - 1; j++)
         {
            m_maCache[timeframeIndex][j] = m_maCache[timeframeIndex][j + 1];
         }
         m_maCacheSizes[timeframeIndex]--;
         i--;
      }
   }
}

//+------------------------------------------------------------------+
//| Print Weight Matrix                                             |
//+------------------------------------------------------------------+
void CIndicatorManager::PrintWeightMatrix()
{
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("                    COMPLETE WEIGHT MATRIX", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("", g_indicatorDebugMode);
   LOG_INFO("┌─────────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐", g_indicatorDebugMode);
   LOG_INFO("│ Component   │   M1     │   M5     │   M15    │   M30    │   H1     │   H4     │", g_indicatorDebugMode);
   LOG_INFO("├─────────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤", g_indicatorDebugMode);
   LOG(StringFormat("│ ADX         │    -     │   %.1f    │    -     │    -     │   %.1f    │   %.1f    │",
                      m_weights.adxM5, m_weights.adxH1, m_weights.adxH4), g_indicatorDebugMode);
   LOG(StringFormat("│ MTF         │   %.1f    │   %.1f    │   %.1f    │   %.1f    │   %.1f    │   %.1f    │",
                      m_weights.mtfM1, m_weights.mtfM5, m_weights.mtfM15, 
                      m_weights.mtfM30, m_weights.mtfH1, m_weights.mtfH4), g_indicatorDebugMode);
   LOG(StringFormat("│ RSI         │    -     │   %.1f    │    -     │    -     │   %.1f    │   %.1f    │",
                      m_weights.rsiM5, m_weights.rsiH1, m_weights.rsiH4), g_indicatorDebugMode);
   LOG(StringFormat("│ MACD        │    -     │   %.1f    │    -     │    -     │   %.1f    │   %.1f    │",
                      m_weights.macdM5, m_weights.macdH1, m_weights.macdH4), g_indicatorDebugMode);
   LOG(StringFormat("│ Volume      │    -     │   %.1f    │    -     │    -     │   %.1f    │    -     │",
                      m_weights.volM5, m_weights.volH1), g_indicatorDebugMode);
   LOG(StringFormat("│ Pullback    │    -     │   %.1f    │    -     │    -     │    -     │    -     │",
                      m_weights.pbM5), g_indicatorDebugMode);
   LOG_INFO("└─────────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘", g_indicatorDebugMode);
   LOG_INFO("", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("                    PRIORITY LEGEND", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("🥇 HIGHEST: 2.5 - 3.0  (Trend direction & major alignment)", g_indicatorDebugMode);
   LOG_INFO("🥈 HIGH:    1.5 - 2.4  (Trend confirmation & strength)", g_indicatorDebugMode);
   LOG_INFO("🥉 MEDIUM:  1.0 - 1.4  (Entry signals & timing)", g_indicatorDebugMode);
   LOG_INFO("🔹 LOW:     0.0 - 0.9  (Noise filtering & secondary confirm)", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
}

//+------------------------------------------------------------------+
//| Print Weighted Status                                           |
//+------------------------------------------------------------------+
void CIndicatorManager::PrintWeightedStatus()
{
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("                    WEIGHTED INDICATOR STATUS", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("", g_indicatorDebugMode);
   LOG_INFO("📊 WEIGHTED VALUES:", g_indicatorDebugMode);
   LOG(StringFormat("  ADX:   %.1f  (%s)", GetWeightedADX(), GetWeightedADXDirection()), g_indicatorDebugMode);
   LOG(StringFormat("  RSI:   %.1f  (%s)", GetWeightedRSI(), GetWeightedRSIDirection()), g_indicatorDebugMode);
   LOG(StringFormat("  MACD:  %.5f (%s)", GetWeightedMACD(), GetWeightedMACDDirection()), g_indicatorDebugMode);
   LOG(StringFormat("  Volume:%.1f%%  (Spike: %s)", GetWeightedVolumeScore(), 
                      IsWeightedVolumeSpike() ? "✅ YES" : "❌ NO"), g_indicatorDebugMode);
   LOG_INFO("", g_indicatorDebugMode);
   LOG_INFO("📈 OVERALL:", g_indicatorDebugMode);
   LOG(StringFormat("  Score:     %.1f%%", GetWeightedOverallScore()), g_indicatorDebugMode);
   LOG(StringFormat("  Direction: %s", GetWeightedOverallDirection()), g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
}

//+------------------------------------------------------------------+
//| Print All Timeframes Status                                     |
//+------------------------------------------------------------------+
void CIndicatorManager::PrintAllTimeframesStatus()
{
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("              ALL TIMEFRAMES STATUS", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
   LOG_INFO("", g_indicatorDebugMode);
   LOG_INFO("┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐", g_indicatorDebugMode);
   LOG_INFO("│ TF       │   ADX    │   RSI    │   MACD   │   MA9    │   MA21   │   MA89   │", g_indicatorDebugMode);
   LOG_INFO("├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤", g_indicatorDebugMode);
   
   for(int i = 0; i < m_timeframeCount; i++)
   {
      ENUM_TIMEFRAMES tf = m_timeframes[i];
      string tfName = GetTimeframeName(tf);
      
      double adx, plusDI, minusDI;
      GetADXValues(tf, adx, plusDI, minusDI);
      
      double rsi = GetRSI(tf);
      
      double ma9 = GetMA(tf, 9);
      double ma21 = GetMA(tf, 21);
      double ma89 = GetMA(tf, 89);
      
      double main, signal;
      GetMACDValues(tf, main, signal);
      double macdVal = (main != EMPTY_VALUE && signal != EMPTY_VALUE) ? main - signal : 0;
      
      LOG(StringFormat("│ %-8s │ %6.1f  │ %6.1f  │ %6.4f │ %6.4f │ %6.4f │ %6.4f │",
                         tfName, adx, rsi, macdVal, ma9, ma21, ma89), g_indicatorDebugMode);
   }
   
   LOG_INFO("└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘", g_indicatorDebugMode);
   LOG_INFO("═══════════════════════════════════════════════════════════════════════════", g_indicatorDebugMode);
}

//+------------------------------------------------------------------+
//| Print Status                                                    |
//+------------------------------------------------------------------+
void CIndicatorManager::PrintStatus()
{
   LOG_INFO("=== INDICATOR MANAGER STATUS (v3.1 WEIGHTED) ===", g_indicatorDebugMode);
   LOG_INFO("Symbol: " + m_symbol, g_indicatorDebugMode);
   LOG_INFO("Current Timeframe: " + GetTimeframeName(m_currentTimeframe), g_indicatorDebugMode);
   LOG_INFO("Initialized: " + (m_initialized ? "YES" : "NO"), g_indicatorDebugMode);
   LOG_INFO("Timeframes: " + IntegerToString(m_timeframeCount), g_indicatorDebugMode);
   LOG_INFO("----------------------------------------", g_indicatorDebugMode);
   LOG_INFO("COMPONENT TIMEFRAMES:", g_indicatorDebugMode);
   LOG_INFO("  ADX: M5, H1, H4", g_indicatorDebugMode);
   LOG_INFO("  MTF: M1, M5, M15, M30, H1, H4, D1", g_indicatorDebugMode);
   LOG_INFO("  RSI: M5, H1, H4", g_indicatorDebugMode);
   LOG_INFO("  MACD: M5, H1, H4", g_indicatorDebugMode);
   LOG_INFO("  Volume: M5, H1", g_indicatorDebugMode);
   LOG_INFO("  Pullback: M5 (price data)", g_indicatorDebugMode);
   LOG_INFO("----------------------------------------", g_indicatorDebugMode);
   LOG_INFO("INDICATOR HANDLES:", g_indicatorDebugMode);
   
   for(int i = 0; i < m_timeframeCount; i++)
   {
      string tfName = GetTimeframeName(m_timeframes[i]);
      LOG_INFO("  " + tfName + ":", g_indicatorDebugMode);
      LOG_INFO("    MA Fast: " + (m_handles[i].ma_fast != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    MA Med: " + (m_handles[i].ma_medium != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    MA Slow: " + (m_handles[i].ma_slow != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    RSI: " + (m_handles[i].rsi != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    MACD: " + (m_handles[i].macd != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    ADX: " + (m_handles[i].adx != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    ATR: " + (m_handles[i].atr != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
      LOG_INFO("    Volume: " + (m_handles[i].volume != INVALID_HANDLE ? "✅" : "❌"), g_indicatorDebugMode);
   }
   LOG_INFO("----------------------------------------", g_indicatorDebugMode);
   LOG_INFO("MA Cache Sizes:", g_indicatorDebugMode);
   for(int i = 0; i < m_timeframeCount; i++)
   {
      LOG_INFO("  " + GetTimeframeName(m_timeframes[i]) + ": " + IntegerToString(m_maCacheSizes[i]), g_indicatorDebugMode);
   }
   LOG_INFO("=== END STATUS ===", g_indicatorDebugMode);
}