// ============================================================
// Scenario ENUM DEFINITIONS
// ============================================================

enum ENUM_MARKET_SCENARIO
{
   SCENARIO_FULL_ALIGNMENT = 1,        // #1: Full alignment
   SCENARIO_TREND_CONTINUATION = 2,    // #2: Trend continuation
   SCENARIO_EARLY_TREND = 3,           // #3: Early trend forming
   SCENARIO_STRONG_TREND_EXHAUSTION = 4, // #4: Strong trend exhaustion
   SCENARIO_TREND_WEAKENING = 5,       // #5: Trend weakening
   SCENARIO_MTF_CONFLICT = 6,          // #6: MTF conflict
   SCENARIO_RANGE_CONDITIONS = 7,      // #7: Range conditions
   SCENARIO_PULLBACK_PREPARE = 8,      // #8: Pullback - prepare for continuation
   SCENARIO_SLOW_GRIND = 9,            // #9: Slow grind trend
   SCENARIO_UNKNOWN = 0
};

// ============================================================
// CROSSOVER ENUMS
// ============================================================
enum ENUM_CROSS_STATE
{
   CROSS_UP,           // ↗ MA just crossed ABOVE other
   CROSS_ZONE,         // ≈ MAs are close (within buffer)
   CROSS_DOWN,         // ↘ MA just crossed BELOW other
   CLEAR_UP,           // MA is clearly above (no crossing)
   CLEAR_DOWN          // MA is clearly below (no crossing)
};

//+------------------------------------------------------------------+
//| TREND DIRECTION ENUM - FOR CROSSOVER DETECTION                 |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH,      // Positive/Upward trend
   TREND_BEARISH,      // Negative/Downward trend
   TREND_NEUTRAL       // Sideways/No clear trend
};