//+------------------------------------------------------------------+
//|                        Structures.mqh                           |
//|                    Core Structure Definitions                    |
//|                    v3.20 - All Structs in One Place            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.20"

#include "../Headers/Enums.mqh"

// ============================================================
// TREND STRUCTURES
// ============================================================

//+------------------------------------------------------------------+
//| TREND RESULT STRUCTURE                                          |
//+------------------------------------------------------------------+
struct STrendResult
{
   string   direction;           // "BULLISH", "BEARISH", "NEUTRAL"
   double   strength;            // 0-100 (Overall trend strength)
   double   ema50Slope;          // Slope of EMA50
   double   ema120Slope;         // Slope of EMA120
   bool     priceAboveMA200;     // Price vs MA200 (for v3.20)
   bool     maStackedBullish;    // 21 > 89 > 200
   bool     maStackedBearish;    // 21 < 89 < 200
   double   bullSignals;         // Number of bullish confirmations
   double   bearSignals;         // Number of bearish confirmations
   double   signalRatio;         // Bull signals / Total signals (0-1)
   double   trendConfidence;     // 0-100 confidence in current trend
   string   description;         // Human-readable description
   string   narrative;           // Detailed narrative
   datetime lastUpdate;
   
   // Additional fields for v3.20
   double   ma21Slope;
   double   ma89Slope;
};

//+------------------------------------------------------------------+
//| TIMEFRAME DATA STRUCTURE                                        |
//+------------------------------------------------------------------+
struct STFData
{
   string   direction;           // "BULLISH", "BEARISH", "NEUTRAL"
   double   strength;            // 0-100
   double   ma21;                // MA21 value
   double   ma89;                // MA89 value
   double   ma200;               // MA200 value
   bool     maStacked;           // 21>89>200 or 21<89<200
   double   slope;               // MA slope
};

//+------------------------------------------------------------------+
//| MARKET FEATURES STRUCTURE                                       |
//+------------------------------------------------------------------+
struct SMarketFeatures
{
   // Timeframe data
   STFData  m15;
   STFData  m5;
   STFData  m1;
   
   // Derived metrics
   double   weightedScore;       // 0-100
   double   confidence;          // 0-100
   double   alignment;           // 0-100
   double   momentum;            // -100 to 100
   double   pullbackDepth;       // 0-100
   double   trendDuration;       // Number of bars
   double   volatility;          // 0-100
   
   // Meta
   datetime timestamp;
   double   currentPrice;
   bool     isAligned;
   string   dominantDirection;
   double   dominanceLevel;
};

//+------------------------------------------------------------------+
//| TREND RECOMMENDATION STRUCTURE                                  |
//+------------------------------------------------------------------+
struct STrendRecommendation
{
   // Action
   string   action;              // "ENTER_LONG", "ENTER_SHORT", "HOLD"
   int      actionCode;          // 1, -1, 0
   
   // Position
   double   positionSize;        // 0-3 lots
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   riskReward;
   
   // Timing
   string   timing;              // "NOW", "SOON", "WAIT", "NEVER"
   int      waitBars;
   
   // Risk
   string   riskLevel;           // "LOW", "MEDIUM", "HIGH", "VERY_HIGH"
   double   riskPercent;         // 0-1
   
   // Confidence
   string   confidenceLevel;     // "HIGH", "MEDIUM", "LOW"
   double   confidenceScore;     // 0-100
   
   // Ready check
   bool     isReady;
   bool     isRejected;
   string   rejectionReason;
   
   // Reasoning
   string   primaryReason;
   string   secondaryReasons[5];
   int      reasonCount;
   string   fullNarrative;
   
   // Data
   SMarketFeatures features;
   datetime timestamp;
   double   currentPrice;
};

//+------------------------------------------------------------------+
//| CROSSOVER RESULT STRUCTURE                                      |
//+------------------------------------------------------------------+
struct SCrossoverResult
{
   // M15
   ENUM_CROSS_STATE    m15_21_89;
   ENUM_CROSS_STATE    m15_89_200;
   bool                m15_21_89_justCrossed;
   bool                m15_89_200_justCrossed;
   
   // M5
   ENUM_CROSS_STATE    m5_21_89;
   bool                m5_21_89_justCrossed;
   
   // M1
   string              m1_position;     // "ABOVE", "NEAR", "BELOW"
   double              m1_distance;     // Points from MA21
   
   // MA Values
   double              ma21_M15;
   double              ma89_M15;
   double              ma200_M15;
   double              ma21_M5;
   double              ma89_M5;
   double              ma200_M5;
   double              ma21_M1;
   double              currentPrice;
   double              pointValue;
   
   // Derived
   bool                isGoldenCross;
   bool                isDeathCross;
   bool                allBullish;
   bool                allBearish;
   bool                isDivergence;
   int                 scenarioNumber;  // 1-27
   string              scenarioName;    // "STRONG_BUY", "BUY_DIP", etc.
   int                 priority;        // 1-6 (1 = highest)
};

// ============================================================
// PULLBACK STRUCTURES
// ============================================================

//+------------------------------------------------------------------+
//| Momentum Scores Structure                                       |
//+------------------------------------------------------------------+
struct MomentumScores
{
   double   mtfBull;
   double   mtfBear;
   double   rsiBull;
   double   rsiBear;
   double   macdBull;
   double   macdBear;
   double   adxBull;
   double   adxBear;
   double   volBull;
   double   volBear;
   double   pbBull;
   double   pbBear;
   
   double   mtfWeightedBull;
   double   mtfWeightedBear;
   double   rsiWeightedBull;
   double   rsiWeightedBear;
   double   macdWeightedBull;
   double   macdWeightedBear;
   double   adxWeightedBull;
   double   adxWeightedBear;
   double   volWeightedBull;
   double   volWeightedBear;
   double   pbWeightedBull;
   double   pbWeightedBear;
   
   int      mtfM5Score;
   int      mtfM15Score;
   int      mtfM30Score;
   string   mtfM5Desc;
   string   mtfM15Desc;
   string   mtfM30Desc;
   
   double   totalBull;
   double   totalBear;
   double   netScore;
   double   confidence;
   string   direction;
   string   narrative;
};

//+------------------------------------------------------------------+
//| Prescribed Trade Structure                                      |
//+------------------------------------------------------------------+
struct PrescribedTrade
{
   int      signal;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   takeProfit2;
   double   partialLevel75;
   double   riskRewardRatio;
   double   riskRewardRatio2;
   string   entryReason;
   string   pullbackDescription;
   double   pullbackPercent;
   int      pullbackScore;
   MomentumScores momentum;
};

//+------------------------------------------------------------------+
//| Range Data Structure                                            |
//+------------------------------------------------------------------+
struct RangeData
{
   double   rangeHigh;
   double   rangeLow;
   double   rangeSize;
   double   currentPrice;
   double   pullbackPercent;
   int      pullbackScore;
   string   pullbackZone;
   bool     isValid;
};

//+------------------------------------------------------------------+
//| Scenario Result Structure                                       |
//+------------------------------------------------------------------+
struct ScenarioResult
{
   ENUM_MARKET_SCENARIO scenario;
   double   confidence;
   string   description;
   string   conditions;
   string   action;
   string   riskLevel;
   string   narrative;
   string   shortNarrative;
   color    displayColor;
   string   displayEmoji;
};

//+------------------------------------------------------------------+
//| Component Data Structure                                        |
//+------------------------------------------------------------------+
struct SComponentData
{
   double   pbConfidence;
   double   pbPercent;
   double   pbAdjustedPercent;
   string   pbZone;
   double   mtfConfidence;
   int      mtfTotalScore;
   int      mtfM5Score;
   int      mtfM15Score;
   int      mtfH1Score;
   double   macdConfidence;
   double   macdHistogram;
   double   macdScore;
   double   adxConfidence;
   double   adxValue;
   string   adxDirection;
   double   rsiConfidence;
   double   rsiValue;
   string   rsiCondition;
   double   volConfidence;
   double   volScore;
   double   volRatio;
   string   volCondition;
   double   priceChange;
   double   finalConfidence;
   string   finalDirection;
   int      activeComponents;
   double   overallScore;
   double   bullPercentage;
   double   bearPercentage;
   double   baseConfidence;
   double   portfolioBoost;
};

//+------------------------------------------------------------------+
//| Pullback Analysis Result Structure                              |
//+------------------------------------------------------------------+
struct SPullbackAnalysisResult
{
   double   confidence;
   double   pullbackScore;
   double   zoneProximity;
   double   pullbackPercent;
   double   adjustedPercent;
   string   pullbackZone;
   string   zoneCategory;
   int      zoneLevel;
   bool     inSweetZone;
   bool     inPerfectZone;
   string   description;
   string   narrative;
   string   shortNarrative;
   string   action;
   string   riskLevel;
   string   chartLabel;
   bool     showOnChart;
   double   currentPrice;
   double   rangeHigh;
   double   rangeLow;
   double   line40;
   double   line80;
   double   linePerfectLow;
   double   linePerfectHigh;
};

//+------------------------------------------------------------------+
//| Pullback Drawing Data Structure                                 |
//+------------------------------------------------------------------+
struct SPullbackDrawingData
{
   double rangeHigh;
   double rangeLow;
   double currentPrice;
   double rangeSize;
   double line40;
   double line80;
   double linePerfectLow;
   double linePerfectHigh;
   double adjustedPercent;
   string zoneCategory;
   int    zoneLevel;
   bool isValid;
   int trend;
};

//+------------------------------------------------------------------+
//| Pullback Summary Structure                                      |
//+------------------------------------------------------------------+
struct SPullbackSummary
{
   double   pullbackPercent;
   double   pullbackScore;
   double   adjustedPercent;
   string   zoneCategory;
   string   shortDescription;
   string   actionSuggestion;
   bool     isValid;
   int      trend;
};

//+------------------------------------------------------------------+
//| Component Display Structure                                     |
//+------------------------------------------------------------------+
struct SComponentDisplay
{
   string   name;
   string   direction;
   string   directionText;
   double   confidence;
   double   score;
   double   rawScore;
   double   weight;
   bool     isActive;
   string   alignment;
};

//+------------------------------------------------------------------+
//| Component Result Structure                                      |
//+------------------------------------------------------------------+
struct SComponentResult
{
   SComponentDisplay pb;
   SComponentDisplay mtf;
   SComponentDisplay macd;
   SComponentDisplay adx;
   SComponentDisplay rsi;
   SComponentDisplay vol;
   string   direction;
   double   confidence;
   double   overallScore;
   double   rawConfidenceTotal;
   double   rawAgreeTotal;
   double   rawDisagreeTotal;
   double   rawScoreTotal;
   double   activeWeight;
   int      activeComponents;
   int      agreeingComponents;
   int      disagreeingComponents;
   int      neutralComponents;
   string   description;
   datetime timestamp;
};

//+------------------------------------------------------------------+
//| Position State Structure                                        |
//+------------------------------------------------------------------+
struct PositionState
{
   ulong  ticket;
   int    signal;
   double entryPrice;
   double stopLoss;
   double takeProfit1;
   double takeProfit2;
   double partialLevel75;
   bool   isBreakevenSet;
   bool   isTrailingActive;
   bool   isPartialCloseDone;
   double openVolume;
   double lastTrailSL;
   double lastTrailTP;
   double partialClosePrice;
   double originalVolume;
   bool   boostActive;
   double boostTPDistance;
   double lastBoostTP;
};

//+------------------------------------------------------------------+
//| Session Information Structure                                    |
//+------------------------------------------------------------------+
struct SessionInfo
{
   int      sessionId;           // 0=Off-Hours, 1=London, 2=NY, 3=Asia
   string   name;                // "London", "New York", "Asia"
   string   shortName;           // "LONDON", "NY", "ASIA"
   string   hours;               // "10:30-18:30 UTC"
   int      adjustment;          // +3 bars
   datetime startTime;           // Session start time
   datetime endTime;             // Session end time
   double   high;                // Session high price
   double   low;                 // Session low price
   bool     isValid;             // Whether session data is valid
};

//+------------------------------------------------------------------+
//| Order Block Structure                                            |
//+------------------------------------------------------------------+
struct OrderBlock
{
   double high;
   double low;
   double open;
   double close;
   datetime time;
   bool isValid;
   bool isBullish;      // true = bullish OB, false = bearish OB
   bool isMitigated;    // true = already tested
   int strength;        // 1-3 (based on size)
   int index;           // Position in array
   double distance;     // Distance from current price
   int methodType;      // 1=Engulfing, 2=Reversal, 3=Trend
};


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