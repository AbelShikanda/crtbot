#include "../Headers/Enums.mqh"

//+------------------------------------------------------------------+
//| Pullback Structure Definitions                                   |
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

// ============================================================
// SCENARIO RESULT STRUCTURE
// ============================================================

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
//| Component Data Structure - For Dashboard and Scenario Detection |
//+------------------------------------------------------------------+
// In Structures.mqh - Add these fields to SComponentData
struct SComponentData
{
   // --- Existing fields ---
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
   
   // --- Existing final fields ---
   double   finalConfidence;
   string   finalDirection;
   int      activeComponents;
   double   overallScore;
   double   bullPercentage;
   double   bearPercentage;
   
   // --- NEW FIELDS for Portfolio Boost ---
   double   baseConfidence;      // Original confidence before boost
   double   portfolioBoost;      // Boost/penalty from PortfolioManager
};

//+------------------------------------------------------------------+
//| Pullback Analysis Result Structure                               |
//+------------------------------------------------------------------+
struct SPullbackAnalysisResult
{
   // Confidence (score-based, not bull/bear)
   double   confidence;          // Overall confidence score (0-100)
   double   pullbackScore;       // Pullback zone score (0-100)
   double   zoneProximity;       // Proximity to perfect zone (0-100)
   
   // Regional pullback data
   double   pullbackPercent;     // Current pullback percentage
   double   adjustedPercent;     // Trend-adjusted percentage
   string   pullbackZone;        // Zone description
   string   zoneCategory;        // PERFECT, SWEET, EDGE, TRANSITION, EXTREME
   int      zoneLevel;           // 5=Perfect, 4=Sweet, 3=Edge, 2=Transition, 1=Extreme
   bool     inSweetZone;         // Is pullback in sweet zone (40-80%)
   bool     inPerfectZone;       // Is pullback in perfect zone (55-65%)
   
   // Description and narrative
   string   description;         // Brief description of what's happening
   string   narrative;           // Detailed narrative
   string   shortNarrative;      // Short version for display
   string   action;              // Recommended action
   string   riskLevel;           // Risk level assessment
   
   // Chart display data - PURE DATA ONLY (no visual decisions)
   string   chartLabel;          // Label text (data only, no emojis)
   bool     showOnChart;         // Whether to show on chart
   
   // Price levels
   double   currentPrice;        // Current price
   double   rangeHigh;           // Range high
   double   rangeLow;            // Range low
   double   line40;              // 40% retracement line
   double   line80;              // 80% retracement line
   double   linePerfectLow;      // Perfect zone low (55%)
   double   linePerfectHigh;     // Perfect zone high (65%)
};

//+------------------------------------------------------------------+
//| Pullback Drawing Data Structure - PURE DATA ONLY                |
//| NO visual decisions (colors, emojis, etc.)                      |
//+------------------------------------------------------------------+
struct SPullbackDrawingData
{
   // Range data
   double rangeHigh;
   double rangeLow;
   double currentPrice;
   double rangeSize;
   
   // Pullback lines (mathematical calculations only)
   double line40;
   double line80;
   double linePerfectLow;
   double linePerfectHigh;
   
   // Raw zone data (no visual decisions)
   double adjustedPercent;
   string zoneCategory;          // PERFECT, SWEET, EDGE, TRANSITION, EXTREME
   int    zoneLevel;             // 5=Perfect, 4=Sweet, 3=Edge, 2=Transition, 1=Extreme
   
   // Validity
   bool isValid;
   int trend;
};

//+------------------------------------------------------------------+
//| Pullback Summary Structure for Component Manager                |
//+------------------------------------------------------------------+
struct SPullbackSummary
{
   double   pullbackPercent;     // Current pullback percentage (0-100)
   double   pullbackScore;       // Pullback zone score (0-100)
   double   adjustedPercent;     // Trend-adjusted percentage
   string   zoneCategory;        // PERFECT, SWEET, EDGE, TRANSITION, EXTREME
   string   shortDescription;    // Brief one-line description
   string   actionSuggestion;    // Recommended action
   bool     isValid;             // Whether the analysis is valid
   int      trend;               // 1=Bullish, -1=Bearish, 0=Neutral
};

//+------------------------------------------------------------------+
//| Component Display Structure - SINGLE DEFINITION                 |
//+------------------------------------------------------------------+
struct SComponentDisplay
{
   string   name;
   string   direction;
   string   directionText;
   double   confidence;      // Confidence for calculations (0-100)
   double   score;           // Score for display only (0-100)
   double   rawScore;        // Underlying raw value (e.g., percentage)
   double   weight;
   bool     isActive;
   string   alignment;       // AGREE, DISAGREE, NEUTRAL
};

//+------------------------------------------------------------------+
//| Component Result Structure                                       |
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
   double   confidence;          // Overall confidence for calculations (weighted avg)
   double   overallScore;        // Overall score for display only (weighted avg)
   
   // Mathematical breakdown for debugging
   double   rawConfidenceTotal;  // Sum of weighted confidences (agree - disagree)
   double   rawAgreeTotal;       // Sum of agreeing weighted confidences
   double   rawDisagreeTotal;    // Sum of disagreeing weighted confidences
   double   rawScoreTotal;       // Sum of weighted scores (agree - disagree)
   double   activeWeight;        // Total weight of active components (AGREE + DISAGREE)
   
   int      activeComponents;
   int      agreeingComponents;
   int      disagreeingComponents;
   int      neutralComponents;
   string   description;
   datetime timestamp;
};

//+------------------------------------------------------------------+
//| Position State - Tracks position flags                          |
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
   double boostTPDistance;      // Fixed 100 points when boost active
   double lastBoostTP;           // Last TP value set during boost
};