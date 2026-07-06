//+------------------------------------------------------------------+
//|                                 Range_Pullback_DayTrader.mq5     |
//|                                   Day Trading - M15/H1          |
//|                    SCORING SYSTEM (NEW WEIGHTS):                 |
//|                    MTF: 45, Pullback: 25, MACD: 15,             |
//|                    RSI: 10, Alignment: 5                        |
//|                    MTF: D1-45%, H1-35%, M15-20%                 |
//|                    UPGRADED: RSI/MACD Exit Protection           |
//|                    V2.0 - STRUCTURE SL + 2R TP + DYNAMIC SIZING|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "2.0"

#include <Trade/Trade.mqh>

//--- Input parameters - DAY TRADING FOCUS (15-hour lookback)
input int      MA_Fast_Period     = 120;         // Fast MA Period (Entry - M15) - 30 hours
input int      MA_Slow_Period     = 120;         // Slow MA Period (Entry - M15) - 30 hours
input int      MA_Trend_Period    = 60;          // Trend MA Period (H1) - 60 hours (2.5 days)
input int      Range_Period       = 250;         // Range Detection Period (62.5 hours on M15)
input int      SL_Structure_Bars  = 20;          // Bars for SL Structure (5 hours on M15)
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H1; // Trend Timeframe
input ENUM_TIMEFRAMES Entry_Timeframe  = PERIOD_M15; // Entry Timeframe

//--- POSITION SIZING
input double   Risk_Per_Trade_Pct = 2.0;         // Risk per trade (% of account)
input double   Max_Lot_Size = 0.1;               // Maximum lot size (cap for safety)
input double   Min_Lot_Size = 0.01;              // Minimum lot size

//--- SL/TP Parameters
input int      Slippage           = 10;          // Slippage in points
input double   Target_RR          = 2.0;         // Target R:R (2.0 = 2R)
input double   SL_ATR_Multiplier  = 0.5;         // ATR multiplier for SL buffer
input double   Max_SL_ATR         = 2.0;         // Max SL in ATR terms
input double   Min_SL_Distance    = 20.0;        // Minimum SL distance in points

//--- Confidence Threshold
input int      Confidence_Threshold = 70;        // Minimum confidence (0-100)

//--- MACD/RSI BOOST
input bool     Enable_MACD_RSI_Boost = true;     // Allow low confidence entries when both RSI & MACD > 60%
input double   MACD_RSI_Boost_Threshold = 60.0;  // Minimum % for both to trigger boost
input int      Boost_Confidence_Reduction = 20;  // Reduce required confidence by this % when boosted

//--- Trade Direction Controls
input bool     Enable_Buy_Trades   = true;       // Enable BUY trades
input bool     Enable_Sell_Trades  = false;      // Enable SELL trades (set to true to enable sells)

//--- Colors
input color    MA_Fast_Color      = clrMagenta;
input color    MA_Slow_Color      = clrDodgerBlue;
input color    MA_Trend_Color     = clrGold;

//--- Profit Management Inputs
input bool     Enable_Smart_Profit_Management = true;
input bool     Enable_Partial_Closes = true;     // Enable partial profit taking
input int      Partial_Close_Interval = 10;      // Close % every X% of TP
input double   Min_Volume_For_Partial = 0.01;    // Minimum volume to leave
input double   Breakeven_Threshold = 40.0;       // Move SL to breakeven (40%)
input double   Breakeven_Buffer_Points = 5;      // Buffer above breakeven in points
input double   SL_20Percent_Threshold = 60.0;    // Lock 20% profit (60%)
input double   SL_50Percent_Threshold = 80.0;    // Lock 50% profit (80%)

//--- Day Trading Filters
input bool     Enable_Spread_Filter = true;
input double   Max_Spread_Pips = 5.0;
input bool     Enable_Time_Filter = false;
input bool     Enable_Daily_Limit = false;
input int      Max_Daily_Trades = 3;

//--- Logging & Display Toggles
input bool     Enable_Logging = true;
input bool     Enable_Chart_Comments = true;

//--- RSI/MACD Exit Protection Inputs
input bool     Enable_RSI_MACD_Exit_Protection = true;
input double   RSI_Exit_Threshold = 40.0;
input double   MACD_Exit_Threshold = 40.0;
input double   RSI_Hard_Exit_Threshold = 35.0;
input double   MACD_Hard_Exit_Threshold = 30.0;
input bool     Require_Both_For_Exit = false;

//--- Entry Protection Inputs
input bool     Enable_Entry_Indicator_Filter = true;
input double   Entry_Min_RSI = 40.0;
input double   Entry_Min_MACD = 40.0;

//--- Enumeration
enum ENUM_TREND_DIRECTION
{
   TREND_NONE,
   TREND_UP,
   TREND_DOWN
};

//--- Global variables
int handle_MA_Fast;
int handle_MA_Slow;
int handle_MA_Trend;
int handle_MA_H1_50;
int handle_MA_H1_21;
int handle_MA_M15_50;
int handle_MA_M15_21;
int handle_MA_D1_89;
int handle_ATR;
int handle_RSI;
int handle_MACD;

double range_high, range_low, range_mid;
bool in_range = false;
bool pullback_detected = false;
ulong positionTicket = 0;
bool has_open_position = false;
ENUM_TREND_DIRECTION current_trade_direction = TREND_NONE;
ENUM_TREND_DIRECTION trend_bias = TREND_NONE;
ENUM_TREND_DIRECTION trend_entry = TREND_NONE;

//--- Daily trade counter
int daily_trades = 0;
datetime last_trade_date = 0;

//--- Time-based control for confidence checks
datetime last_confidence_check = 0;
int confidence_check_interval = 5;

//--- Cache variables for 5-second updates
double cached_price = 0;
double cached_pullback_percent = 0;
int cached_pullback_score = 0;
int cached_mtf_score = 0;
int cached_alignment_score = 0;
int cached_rsi_score = 0;
int cached_macd_score = 0;
int cached_total_confidence = 0;
bool cached_has_signal = false;
bool cached_boost_active = false;
ENUM_TREND_DIRECTION cached_final_trend = TREND_NONE;
double cached_entry_price = 0;
double cached_sl_price = 0;
double cached_tp_price = 0;
string cached_pullback_desc = "";
string cached_mtf_desc = "";
string cached_price_pos_desc = "";
string cached_alignment_desc = "";

//--- Status variables
string status_in_trade = "NO";
string status_reason = "WAITING FOR SIGNAL";
string status_pullback = "N/A";
string status_trend = "NEUTRAL";
string status_entry = "N/A";
string status_confidence = "0/100";
string status_progress = "IDLE";
string status_profit = "$0.00";
string status_lot = "0.00";
string status_rr = "0.00";
string status_pullback_ending = "N/A";
string status_ma_cross = "N/A";
string status_daily_trades = "0/3";
string status_alignment = "N/A";
string status_rsi = "N/A";
string status_macd = "N/A";
string status_exit_warning = "NONE";
string status_boost = "OFF";
string trade_signature_display = "";

//--- Component Scores
int display_pullback_score = 0;
int display_mtf_score = 0;
int display_alignment_score = 0;
int display_rsi_score = 0;
int display_macd_score = 0;
int display_total_confidence = 0;
double display_pullback_pct = 0;
string display_pullback_zone = "N/A";

//--- RSI & MACD Support Percentages
double rsi_value = 0;
double macd_value = 0;
double macd_signal_value = 0;
int rsi_score = 0;
int macd_score = 0;
double rsi_bullish_support = 0;
double rsi_bearish_support = 0;
double rsi_display_pct = 50;
double macd_bullish_support = 0;
double macd_bearish_support = 0;
double macd_display_pct = 50;

//--- MTF Status
int mtf_total_score = 0;
string mtf_quality = "N/A";

//--- D1 Score tracking
int d1_score_value = 0;
int h1_score_value = 0;
int m15_score_value = 0;
string d1_status = "N/A";

//--- Profit Tracker Structure - ENHANCED
struct ProfitTracker
{
    ulong posTicket;
    double highestPercentSeen;
    bool breakevenProcessed;
    bool sl20PercentProcessed;
    bool sl50PercentProcessed;
    double entryPrice;
    double tpPrice;
    ENUM_POSITION_TYPE posType;
    double initialVolume;
    double currentVolume;
    bool partialsProcessed[];
    double partialLevelsProcessed[];
    int partialCount;
    bool partialClosesComplete;
    double lastPartialPercent;
};

ProfitTracker profitTrackers[];
int trackerCount = 0;
int last_candle_time = 0;

//--- Forward declarations
void ClosePosition();
void CheckOpenPositions();
void DrawChartInfo();
void DetectRange(MqlRates &rates[]);
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score,
                  int rsi_score_val, int macd_score_val, int alignment_score,
                  string pullback_desc, string mtf_desc, 
                  string price_pos_desc,
                  string alignment_desc,
                  bool is_rejected = false, string reject_reason = "",
                  bool boost_active = false);
void InitializeProfitTracker(ulong posTicket);
void CleanupProfitTrackers();
void ManageProfits();
void DrawSwingHighLow(MqlRates &rates[]);
bool CheckDailyTradeLimit();
void ResetDailyCounter();
int GetMaxPositions();
bool CanAddNewPosition();
void LogMessage(string message, bool isError = false);
void UpdateTradeSignatureDisplay();
void RunFullAnalysis();
void RunConfidenceCheck();
bool CheckExitConditions();
bool CheckEntryConditions();
double CalculateDynamicLotSize(double entry_price, double sl_price);
bool ClosePartialPosition(ulong posTicket, double closePercent);
bool ProcessPartialCloses(ulong posTicket, double currentPercentToTP);
double CalculateStructureSL(ENUM_TREND_DIRECTION trend, double entry_price, MqlRates &rates[], double atr_value);
double Calculate2R_TP(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price);

//--- MTF Functions
int CalculateUnifiedMTFScore(ENUM_TREND_DIRECTION tradeDirection,
                             double h1_price, double h1_ma60, double h1_ma21, double h1_ma50,
                             double h1_close, double h1_open, double h1_prev_close, double h1_prev_open,
                             double m15_price, double m15_ma60, double m15_ma21, double m15_ma50, double m15_ma120,
                             double d1_price, double d1_ema89, double atr_value,
                             string &h1_desc, string &m15_desc, string &d1_desc,
                             int &d1_score, int &h1_score, int &m15_score);

//--- Pullback Scoring Function
int CalculatePullbackScore(double pullback_percent);

//--- Trend Alignment Scoring Function
int CalculateTrendAlignmentScore(ENUM_TREND_DIRECTION h1_trend, 
                                 ENUM_TREND_DIRECTION m15_trend,
                                 double current_price,
                                 double h1_ma60,
                                 double m15_ma120,
                                 string &alignment_desc);

//--- RSI Scoring Function
int CalculateRSIScore(double rsi, ENUM_TREND_DIRECTION trend, double &bullish_support, double &bearish_support, double &display_pct);

//--- MACD Scoring Function
int CalculateMACDScore(double macd_main, double macd_signal, ENUM_TREND_DIRECTION trend, 
                       double &bullish_support, double &bearish_support, double &display_pct);

//--- Boost Check
bool CheckMACD_RSI_Boost();

//+------------------------------------------------------------------+
//| Get Confidence Threshold - WITH BOOST SUPPORT                    |
//+------------------------------------------------------------------+
int GetConfidenceThreshold(ENUM_TREND_DIRECTION direction)
{
   int baseThreshold = Confidence_Threshold;
   
   if(Enable_MACD_RSI_Boost && CheckMACD_RSI_Boost())
   {
      int boostedThreshold = baseThreshold - Boost_Confidence_Reduction;
      if(boostedThreshold < 30) boostedThreshold = 30;
      return boostedThreshold;
   }
   
   return baseThreshold;
}

//+------------------------------------------------------------------+
//| Check MACD/RSI Boost - Returns true if both > threshold        |
//+------------------------------------------------------------------+
bool CheckMACD_RSI_Boost()
{
   if(!Enable_MACD_RSI_Boost) return false;
   if(cached_final_trend != TREND_UP) return false;
   
   if(rsi_display_pct >= MACD_RSI_Boost_Threshold && 
      macd_display_pct >= MACD_RSI_Boost_Threshold)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Log Message                                                      |
//+------------------------------------------------------------------+
void LogMessage(string message, bool isError = false)
{
   if(!Enable_Logging && !isError) return;
   if(isError)
      Print("❌ ", message);
   else
      Print(message);
}

//+------------------------------------------------------------------+
//| Update Trade Signature Display                                   |
//+------------------------------------------------------------------+
void UpdateTradeSignatureDisplay()
{
   string boostStr = cached_boost_active ? "⚡BOOST" : "";
   trade_signature_display = StringFormat(
       "PB:%.0f%%|MTF:%d/45|AL:%d/5|RSI:%d/10|MCD:%d/15|C:%d%%%s",
       display_pullback_pct, display_mtf_score, display_alignment_score,
       display_rsi_score, display_macd_score, display_total_confidence,
       boostStr
   );
}

//+------------------------------------------------------------------+
//| Store Failed Trade                                               |
//+------------------------------------------------------------------+
void StoreFailedTrade(double price, ENUM_TREND_DIRECTION direction, string reason, 
                      int confidence, double pullback_pct,
                      int pullback_score = 0, int alignment_score = 0, 
                      int mtf_score = 0, int rsi_score_val = 0, int macd_score_val = 0)
{
   LogMessage("🚫 FAILED TRADE: " + reason + " | PB:" + DoubleToString(pullback_pct, 0) + 
              "% | C:" + IntegerToString(confidence) + "%");
}

//+------------------------------------------------------------------+
//| Store Successful Trade                                           |
//+------------------------------------------------------------------+
void StoreSuccessfulTrade(double price, ENUM_TREND_DIRECTION direction, 
                          int confidence, double pullback_pct,
                          int pullback_score = 0, int alignment_score = 0, 
                          int mtf_score = 0, int rsi_score_val = 0, int macd_score_val = 0)
{
   return;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   handle_MA_Fast = iMA(_Symbol, Entry_Timeframe, MA_Fast_Period, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_Slow = iMA(_Symbol, Entry_Timeframe, MA_Slow_Period, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_Trend = iMA(_Symbol, Trend_Timeframe, MA_Trend_Period, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_H1_50 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_H1_21 = iMA(_Symbol, Trend_Timeframe, 21, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_M15_50 = iMA(_Symbol, Entry_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_M15_21 = iMA(_Symbol, Entry_Timeframe, 21, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_D1_89 = iMA(_Symbol, PERIOD_D1, 89, 0, MODE_EMA, PRICE_CLOSE);
   handle_ATR = iATR(_Symbol, Entry_Timeframe, 14);
   handle_RSI = iRSI(_Symbol, Entry_Timeframe, 14, PRICE_CLOSE);
   handle_MACD = iMACD(_Symbol, Entry_Timeframe, 12, 26, 9, PRICE_CLOSE);
   
   if(handle_MA_Fast == INVALID_HANDLE || handle_MA_Slow == INVALID_HANDLE || 
      handle_MA_Trend == INVALID_HANDLE || handle_MA_H1_50 == INVALID_HANDLE ||
      handle_MA_H1_21 == INVALID_HANDLE || handle_MA_M15_50 == INVALID_HANDLE ||
      handle_MA_M15_21 == INVALID_HANDLE || handle_MA_D1_89 == INVALID_HANDLE ||
      handle_ATR == INVALID_HANDLE || handle_RSI == INVALID_HANDLE ||
      handle_MACD == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles!");
      return(INIT_FAILED);
   }
   
   ArrayResize(profitTrackers, 100);
   trackerCount = 0;
   
   LogMessage("=========================================");
   LogMessage("   DAY TRADING RANGE PULLBACK EXECUTOR   ");
   LogMessage("   VERSION 2.0 - STRUCTURE SL + 2R TP   ");
   LogMessage("=========================================");
   LogMessage("🔵 POSITION SIZING:");
   LogMessage("   Risk per trade: " + DoubleToString(Risk_Per_Trade_Pct, 1) + "%");
   LogMessage("   Min Lot: " + DoubleToString(Min_Lot_Size, 2));
   LogMessage("   Max Lot: " + DoubleToString(Max_Lot_Size, 2));
   LogMessage("🔵 SL/TP: STRUCTURE SL + 2R TP");
   LogMessage("   SL ATR Multiplier: " + DoubleToString(SL_ATR_Multiplier, 1));
   LogMessage("   Target RR: " + DoubleToString(Target_RR, 1) + "R");
   LogMessage("🔵 PROFIT MANAGEMENT:");
   LogMessage("   Partial Closes: Every " + IntegerToString(Partial_Close_Interval) + "%");
   LogMessage("   Breakeven: " + DoubleToString(Breakeven_Threshold, 0) + "%");
   LogMessage("   Lock 20%: " + DoubleToString(SL_20Percent_Threshold, 0) + "%");
   LogMessage("   Lock 50%: " + DoubleToString(SL_50Percent_Threshold, 0) + "%");
   LogMessage("=========================================");
   
   ResetDailyCounter();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handle_MA_Fast != INVALID_HANDLE) IndicatorRelease(handle_MA_Fast);
   if(handle_MA_Slow != INVALID_HANDLE) IndicatorRelease(handle_MA_Slow);
   if(handle_MA_Trend != INVALID_HANDLE) IndicatorRelease(handle_MA_Trend);
   if(handle_MA_H1_50 != INVALID_HANDLE) IndicatorRelease(handle_MA_H1_50);
   if(handle_MA_H1_21 != INVALID_HANDLE) IndicatorRelease(handle_MA_H1_21);
   if(handle_MA_M15_50 != INVALID_HANDLE) IndicatorRelease(handle_MA_M15_50);
   if(handle_MA_M15_21 != INVALID_HANDLE) IndicatorRelease(handle_MA_M15_21);
   if(handle_MA_D1_89 != INVALID_HANDLE) IndicatorRelease(handle_MA_D1_89);
   if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
   if(handle_RSI != INVALID_HANDLE) IndicatorRelease(handle_RSI);
   if(handle_MACD != INVALID_HANDLE) IndicatorRelease(handle_MACD);
   ObjectsDeleteAll(0);
   Comment("");
}

//+------------------------------------------------------------------+
//| Get Maximum Positions                                            |
//+------------------------------------------------------------------+
int GetMaxPositions()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 1000)
      return 1;
   else if(balance <= 5000)
      return 3;
   else
      return 5;
}

//+------------------------------------------------------------------+
//| Check if we can add a new position                               |
//+------------------------------------------------------------------+
bool CanAddNewPosition()
{
   int maxPos = GetMaxPositions();
   int currentPos = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong pos_ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(pos_ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            currentPos++;
      }
   }
   
   return (currentPos < maxPos);
}

//+------------------------------------------------------------------+
//| Calculate Unified MTF Score (OPTIMIZED - 0-45)                  |
//+------------------------------------------------------------------+
int CalculateUnifiedMTFScore(ENUM_TREND_DIRECTION tradeDirection,
                             double h1_price, double h1_ma60, double h1_ma21, double h1_ma50,
                             double h1_close, double h1_open, double h1_prev_close, double h1_prev_open,
                             double m15_price, double m15_ma60, double m15_ma21, double m15_ma50, double m15_ma120,
                             double d1_price, double d1_ema89, double atr_value,
                             string &h1_desc, string &m15_desc, string &d1_desc,
                             int &d1_score, int &h1_score, int &m15_score)
{
   int h1Score = 0;
   int m15Score = 0;
   int d1Score = 0;
   
   // D1 SCORE (0-20)
   d1_desc = "";
   bool d1AboveEMA89 = (d1_price > d1_ema89);
   bool d1BelowEMA89 = (d1_price < d1_ema89);
   bool d1NearEMA89 = (MathAbs(d1_price - d1_ema89) < atr_value);
   
   if(d1NearEMA89)
   {
      d1Score = 0;
      d1_desc = "D1: Neutral (near 89 EMA) [0]";
   }
   else if((tradeDirection == TREND_UP && d1AboveEMA89) ||
           (tradeDirection == TREND_DOWN && d1BelowEMA89))
   {
      d1Score = 20;
      d1_desc = "D1: STRONGLY ALIGNED [+20]";
   }
   else
   {
      d1Score = -4;
      d1_desc = "D1: MISALIGNED [-4]";
   }
   
   // H1 SCORE (0-16)
   h1_desc = "";
   h1Score += 4;
   h1_desc = "Trend: " + (tradeDirection == TREND_UP ? "BULLISH" : "BEARISH") + " [+4]";
   
   bool h1MA21AboveMA50 = (h1_ma21 > h1_ma50);
   bool h1MA21BelowMA50 = (h1_ma21 < h1_ma50);
   
   if((tradeDirection == TREND_UP && h1MA21AboveMA50) ||
      (tradeDirection == TREND_DOWN && h1MA21BelowMA50))
   {
      h1Score += 6;
      h1_desc += " | MA21>MA50 [+6]";
   }
   else
   {
      h1_desc += " | MA21 not aligned [0]";
   }
   
   double h1_body = MathAbs(h1_close - h1_open);
   double h1_prev_body = MathAbs(h1_prev_close - h1_prev_open);
   if(h1_body > h1_prev_body * 1.5)
   {
      h1Score += 4;
      h1_desc += " | Momentum [+4]";
   }
   else
   {
      h1_desc += " | No momentum [0]";
   }
   
   if((tradeDirection == TREND_UP && h1_close > h1_ma50) ||
      (tradeDirection == TREND_DOWN && h1_close < h1_ma50))
   {
      h1Score += 2;
      h1_desc += " | Price>MA50 [+2]";
   }
   else
   {
      h1_desc += " | Price not >MA50 [0]";
   }
   
   h1Score = MathMin(16, h1Score);
   h1_desc = "H1: " + IntegerToString(h1Score) + "/16 - " + h1_desc;
   
   // M15 SCORE (0-9)
   m15_desc = "";
   m15Score += 3;
   m15_desc = "Trend match [+3]";
   
   bool m15MA21AboveMA50 = (m15_ma21 > m15_ma50);
   bool m15MA21BelowMA50 = (m15_ma21 < m15_ma50);
   
   if((tradeDirection == TREND_UP && m15MA21AboveMA50) ||
      (tradeDirection == TREND_DOWN && m15MA21BelowMA50))
   {
      m15Score += 4;
      m15_desc += " | MA21>MA50 [+4]";
   }
   else
   {
      m15_desc += " | MA21 not aligned [0]";
   }
   
   bool m15MA60AboveMA120 = (m15_ma60 > m15_ma120);
   bool m15MA60BelowMA120 = (m15_ma60 < m15_ma120);
   
   if((tradeDirection == TREND_UP && m15MA60AboveMA120) ||
      (tradeDirection == TREND_DOWN && m15MA60BelowMA120))
   {
      m15Score += 2;
      m15_desc += " | MA60>MA120 [+2]";
   }
   else
   {
      m15_desc += " | MA60 not stacked [0]";
   }
   
   m15Score = MathMin(9, m15Score);
   m15_desc = "M15: " + IntegerToString(m15Score) + "/9 - " + m15_desc;
   
   d1_score = d1Score;
   h1_score = h1Score;
   m15_score = m15Score;
   
   int totalScore = h1Score + m15Score + d1Score;
   totalScore = MathMax(0, MathMin(45, totalScore));
   
   return totalScore;
}

//+------------------------------------------------------------------+
//| Calculate Pullback Score (OPTIMIZED - 0-25)                     |
//+------------------------------------------------------------------+
int CalculatePullbackScore(double pullback_percent)
{
    double pb = pullback_percent;
    
    if(pb < 10.0 || pb > 95.0) return 0;
    
    // GOLDEN ZONE (38.2-50%)
    if(pb >= 38.2 && pb <= 50.0)
    {
        double distanceFromCenter = MathAbs(pb - 44.1);
        double score = 25 - (distanceFromCenter / 5.9) * 4;
        return (int)MathMax(21, MathMin(25, score));
    }
    
    // ENHANCED: 50-61.8%
    if(pb > 50.0 && pb <= 61.8)
    {
        double score = 22 - ((pb - 50.0) / 11.8) * 4;
        return (int)MathMax(18, MathMin(22, score));
    }
    
    // ENHANCED: 61.8-78.6%
    if(pb > 61.8 && pb <= 78.6)
    {
        double score = 18 - ((pb - 61.8) / 16.8) * 8;
        return (int)MathMax(10, MathMin(18, score));
    }
    
    // ENHANCED: 78.6-85%
    if(pb > 78.6 && pb <= 85.0)
    {
        double score = 10 - ((pb - 78.6) / 6.4) * 5;
        return (int)MathMax(5, MathMin(10, score));
    }
    
    // EARLY ZONE (25-38.2%)
    if(pb >= 25.0 && pb < 38.2)
    {
        double score = 16 + ((pb - 25.0) / 13.2) * 5;
        return (int)MathMax(16, MathMin(21, score));
    }
    
    // TOO SHALLOW (<25%)
    if(pb >= 15.0 && pb < 25.0)
    {
        double score = 1 + ((pb - 15.0) / 10.0) * 2;
        return (int)MathMax(1, MathMin(3, score));
    }
    
    // TOO DEEP (>85%)
    if(pb > 85.0 && pb <= 90.0)
    {
        double score = 3 + ((90.0 - pb) / 5.0) * 2;
        return (int)MathMax(3, MathMin(5, score));
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Get Pullback Zone Description                                    |
//+------------------------------------------------------------------+
string GetPullbackZoneDescription(double pullback_percent)
{
   if(pullback_percent >= 25.0 && pullback_percent <= 38.2)
      return "EARLY ZONE";
   else if(pullback_percent > 38.2 && pullback_percent <= 50.0)
      return "GOLDEN ZONE ★";
   else if(pullback_percent > 50.0 && pullback_percent <= 61.8)
      return "GOOD ZONE";
   else if(pullback_percent > 61.8 && pullback_percent <= 78.6)
      return "DEEP ZONE";
   else if(pullback_percent > 78.6 && pullback_percent <= 85.0)
      return "RISKY ZONE";
   else if(pullback_percent < 25.0)
      return "TOO SHALLOW";
   else if(pullback_percent > 85.0)
      return "TOO DEEP";
   return "INVALID ZONE";
}

//+------------------------------------------------------------------+
//| Calculate Trend Alignment Score (REDUCED - 0-5)                 |
//+------------------------------------------------------------------+
int CalculateTrendAlignmentScore(ENUM_TREND_DIRECTION h1_trend, 
                                 ENUM_TREND_DIRECTION m15_trend,
                                 double current_price,
                                 double h1_ma60,
                                 double m15_ma120,
                                 string &alignment_desc)
{
    int score = 0;
    alignment_desc = "";
    
    if(h1_trend == m15_trend && h1_trend != TREND_NONE)
    {
        double h1_distance = MathAbs(current_price - h1_ma60) / h1_ma60 * 100;
        double m15_distance = MathAbs(current_price - m15_ma120) / m15_ma120 * 100;
        
        if(h1_distance > 3.0 && m15_distance > 2.0)
        {
            score = 5;
            alignment_desc = "Perfect Alignment + Strong Trend";
        }
        else if(h1_distance > 1.5 && m15_distance > 1.0)
        {
            score = 4;
            alignment_desc = "Perfect Alignment + Moderate Trend";
        }
        else
        {
            score = 3;
            alignment_desc = "Perfect Alignment + Weak Trend";
        }
    }
    else if(h1_trend != TREND_NONE && m15_trend != TREND_NONE)
    {
        double h1_distance = MathAbs(current_price - h1_ma60) / h1_ma60 * 100;
        
        if(h1_distance > 3.0)
        {
            score = 2;
            alignment_desc = "Misaligned - H1 Strong (H1 dominates)";
        }
        else if(h1_distance > 1.5)
        {
            score = 1;
            alignment_desc = "Misaligned - H1 Moderate (conflict)";
        }
        else
        {
            score = 1;
            alignment_desc = "Misaligned - H1 Weak (M15 may dominate)";
        }
    }
    else if((h1_trend != TREND_NONE && m15_trend == TREND_NONE) ||
            (h1_trend == TREND_NONE && m15_trend != TREND_NONE))
    {
        if(h1_trend != TREND_NONE)
        {
            double h1_distance = MathAbs(current_price - h1_ma60) / h1_ma60 * 100;
            if(h1_distance > 2.0)
                score = 1;
            else
                score = 1;
        }
        else
        {
            score = 1;
        }
    }
    else
    {
        score = 0;
        alignment_desc = "No Clear Trend - CHOPPY";
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Calculate RSI Score (RECALIBRATED - 0-10)                       |
//+------------------------------------------------------------------+
int CalculateRSIScore(double rsi, ENUM_TREND_DIRECTION trend, double &bullish_support, double &bearish_support, double &display_pct)
{
    bullish_support = 0;
    bearish_support = 0;
    display_pct = 50;
    
    if(rsi < 50)
    {
        double distance = (50 - rsi) / 50.0;
        
        bullish_support = 50 - (distance * 50);
        bearish_support = 50 + (distance * 50);
        display_pct = bullish_support;
        
        if(bearish_support >= 85) return 1;
        if(bearish_support >= 70) return 3;
        if(bearish_support >= 60) return 5;
        if(bearish_support >= 55) return 7;
        return 8;
    }
    else if(rsi > 50)
    {
        double distance = (rsi - 50) / 50.0;
        
        bullish_support = 50 + (distance * 50);
        bearish_support = 50 - (distance * 50);
        display_pct = bullish_support;
        
        if(bullish_support >= 85) return 10;
        if(bullish_support >= 70) return 8;
        if(bullish_support >= 60) return 6;
        if(bullish_support >= 55) return 4;
        return 2;
    }
    else
    {
        bullish_support = 50;
        bearish_support = 50;
        display_pct = 50;
        return 5;
    }
}

//+------------------------------------------------------------------+
//| Calculate MACD Score (RECALIBRATED - 0-15)                      |
//+------------------------------------------------------------------+
int CalculateMACDScore(double macd_main, double macd_signal, ENUM_TREND_DIRECTION trend, 
                       double &bullish_support, double &bearish_support, double &display_pct)
{
    double diff = macd_main - macd_signal;
    double absDiff = MathAbs(diff);
    
    bullish_support = 0;
    bearish_support = 0;
    display_pct = 50;
    
    if(absDiff < 0.0001) 
    {
        bullish_support = 50;
        bearish_support = 50;
        display_pct = 50;
        return 7;
    }
    
    double maxDiff = 5.0;
    double scale = MathMin(absDiff / maxDiff, 1.0);
    
    if(diff < 0)
    {
        bullish_support = 50 - (scale * 50);
        bearish_support = 50 + (scale * 50);
        display_pct = bullish_support;
        
        if(bearish_support >= 85) return 2;
        if(bearish_support >= 70) return 5;
        if(bearish_support >= 60) return 8;
        if(bearish_support >= 55) return 11;
        return 13;
    }
    else
    {
        bullish_support = 50 + (scale * 50);
        bearish_support = 50 - (scale * 50);
        display_pct = bullish_support;
        
        if(bullish_support >= 85) return 15;
        if(bullish_support >= 70) return 12;
        if(bullish_support >= 60) return 9;
        if(bullish_support >= 55) return 6;
        return 3;
    }
}

//+------------------------------------------------------------------+
//| Check Exit Conditions - RSI/MACD Exit Protection                |
//+------------------------------------------------------------------+
bool CheckExitConditions()
{
   if(!Enable_RSI_MACD_Exit_Protection) return false;
   if(!has_open_position) return false;
   if(current_trade_direction != TREND_UP) return false;
   
   bool rsiBearish = (rsi_display_pct < RSI_Exit_Threshold);
   bool macdBearish = (macd_display_pct < MACD_Exit_Threshold);
   bool rsiHardBearish = (rsi_display_pct < RSI_Hard_Exit_Threshold);
   bool macdHardBearish = (macd_display_pct < MACD_Hard_Exit_Threshold);
   
   if(rsiHardBearish || macdHardBearish)
   {
      status_exit_warning = "🔴 HARD EXIT: " + 
                            (rsiHardBearish ? "RSI " + DoubleToString(rsi_display_pct, 0) + "%" : "") +
                            (rsiHardBearish && macdHardBearish ? " & " : "") +
                            (macdHardBearish ? "MACD " + DoubleToString(macd_display_pct, 0) + "%" : "");
      LogMessage("🔴 EXIT TRIGGERED: Hard exit condition - " + status_exit_warning);
      return true;
   }
   
   bool exitTriggered = false;
   
   if(Require_Both_For_Exit)
   {
      exitTriggered = (rsiBearish && macdBearish);
   }
   else
   {
      exitTriggered = (rsiBearish || macdBearish);
   }
   
   if(exitTriggered)
   {
      status_exit_warning = "⚠️ EXIT SIGNAL: " + 
                            (rsiBearish ? "RSI " + DoubleToString(rsi_display_pct, 0) + "%" : "") +
                            (rsiBearish && macdBearish ? " & " : "") +
                            (macdBearish ? "MACD " + DoubleToString(macd_display_pct, 0) + "%" : "");
      LogMessage("🔴 EXIT TRIGGERED: " + status_exit_warning);
      return true;
   }
   
   status_exit_warning = "NONE";
   return false;
}

//+------------------------------------------------------------------+
//| Check Entry Conditions - RSI/MACD Entry Filter                  |
//+------------------------------------------------------------------+
bool CheckEntryConditions()
{
   if(!Enable_Entry_Indicator_Filter) return true;
   if(cached_final_trend != TREND_UP) return true;
   
   if(rsi_display_pct < Entry_Min_RSI)
   {
      status_reason = "ENTRY BLOCKED: RSI too low (" + DoubleToString(rsi_display_pct, 0) + "% < " + DoubleToString(Entry_Min_RSI, 0) + "%)";
      LogMessage("🚫 Entry blocked: RSI " + DoubleToString(rsi_display_pct, 0) + "% below minimum " + DoubleToString(Entry_Min_RSI, 0) + "%");
      return false;
   }
   
   if(macd_display_pct < Entry_Min_MACD)
   {
      status_reason = "ENTRY BLOCKED: MACD too low (" + DoubleToString(macd_display_pct, 0) + "% < " + DoubleToString(Entry_Min_MACD, 0) + "%)";
      LogMessage("🚫 Entry blocked: MACD " + DoubleToString(macd_display_pct, 0) + "% below minimum " + DoubleToString(Entry_Min_MACD, 0) + "%");
      return false;
   }
   
   bool nearExitRSI = (rsi_display_pct < RSI_Exit_Threshold);
   bool nearExitMACD = (macd_display_pct < MACD_Exit_Threshold);
   
   if(nearExitRSI || nearExitMACD)
   {
      status_reason = "ENTRY BLOCKED: Bearish divergence (RSI/MACD near exit threshold)";
      LogMessage("🚫 Entry blocked: RSI " + DoubleToString(rsi_display_pct, 0) + "% / MACD " + DoubleToString(macd_display_pct, 0) + "% - waiting for neutral/bullish");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyCounter();
   
   if(Enable_Spread_Filter)
   {
      double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(spread > Max_Spread_Pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
      {
         status_reason = "SPREAD TOO HIGH";
         DrawChartInfo();
         return;
      }
   }
   
   if(Enable_Daily_Limit && !CheckDailyTradeLimit())
   {
      status_reason = "DAILY LIMIT REACHED";
      DrawChartInfo();
      return;
   }
   
   if(Enable_RSI_MACD_Exit_Protection && has_open_position)
   {
      if(CheckExitConditions())
      {
         ClosePosition();
         status_reason = "EXITED: RSI/MACD PROTECTION";
         status_progress = "EXIT TRIGGERED";
         DrawChartInfo();
         return;
      }
   }
   
   if(Enable_Smart_Profit_Management && has_open_position)
   {
      ManageProfits();
   }
   
   datetime current_bar_time = iTime(_Symbol, Entry_Timeframe, 0);
   bool new_bar = (current_bar_time != last_candle_time);
   
   if(new_bar)
   {
      last_candle_time = (int)current_bar_time;
      last_confidence_check = TimeCurrent();
      
      RunFullAnalysis();
      DrawChartInfo();
      return;
   }
   
   datetime current_time = TimeCurrent();
   if(current_time - last_confidence_check >= confidence_check_interval)
   {
      last_confidence_check = current_time;
      RunConfidenceCheck();
      DrawChartInfo();
   }
   else
   {
      DrawChartInfo();
   }
}

//+------------------------------------------------------------------+
//| Run Full Analysis - NEW BAR ONLY                                 |
//+------------------------------------------------------------------+
void RunFullAnalysis()
{
   CheckOpenPositions();
   UpdateStatus();
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int rates_copied = CopyRates(_Symbol, Entry_Timeframe, 0, Range_Period + 100, rates);
   
   if(rates_copied < Range_Period + 10) 
   {
      status_reason = "INSUFFICIENT DATA";
      status_progress = "DATA ERROR";
      return;
   }
   
   DrawSwingHighLow(rates);
   
   MqlRates rates_h1[];
   ArraySetAsSeries(rates_h1, true);
   if(CopyRates(_Symbol, Trend_Timeframe, 0, 10, rates_h1) < 5) 
   {
      status_reason = "H1 DATA ERROR";
      return;
   }
   
   MqlRates rates_d1[];
   ArraySetAsSeries(rates_d1, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 5, rates_d1) < 3)
   {
      status_reason = "D1 DATA ERROR";
      return;
   }
   
   double ma_fast[], ma_slow[], ma_trend[], ma_h1_50[], ma_h1_21[], ma_m15_50[], ma_m15_21[], ma_d1_89[], atr[];
   double rsi_buffer[], macd_main[], macd_signal_buffer[], macd_hist[];
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(ma_trend, true);
   ArraySetAsSeries(ma_h1_50, true);
   ArraySetAsSeries(ma_h1_21, true);
   ArraySetAsSeries(ma_m15_50, true);
   ArraySetAsSeries(ma_m15_21, true);
   ArraySetAsSeries(ma_d1_89, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal_buffer, true);
   ArraySetAsSeries(macd_hist, true);
   
   if(CopyBuffer(handle_MA_Fast, 0, 0, 10, ma_fast) < 10 ||
      CopyBuffer(handle_MA_Slow, 0, 0, 10, ma_slow) < 10 ||
      CopyBuffer(handle_MA_Trend, 0, 0, 10, ma_trend) < 10 ||
      CopyBuffer(handle_MA_H1_50, 0, 0, 10, ma_h1_50) < 5 ||
      CopyBuffer(handle_MA_H1_21, 0, 0, 10, ma_h1_21) < 5 ||
      CopyBuffer(handle_MA_M15_50, 0, 0, 10, ma_m15_50) < 5 ||
      CopyBuffer(handle_MA_M15_21, 0, 0, 10, ma_m15_21) < 5 ||
      CopyBuffer(handle_MA_D1_89, 0, 0, 5, ma_d1_89) < 3 ||
      CopyBuffer(handle_ATR, 0, 0, 10, atr) < 10 ||
      CopyBuffer(handle_RSI, 0, 0, 5, rsi_buffer) < 3 ||
      CopyBuffer(handle_MACD, 0, 0, 5, macd_main) < 3 ||
      CopyBuffer(handle_MACD, 1, 0, 5, macd_signal_buffer) < 3)
   {
      status_reason = "INDICATOR DATA ERROR";
      return;
   }
   
   cached_price = rates[0].close;
   rsi_value = rsi_buffer[0];
   macd_value = macd_main[0];
   macd_signal_value = macd_signal_buffer[0];
   
   int temp_rsi_score = CalculateRSIScore(rsi_value, TREND_UP, rsi_bullish_support, rsi_bearish_support, rsi_display_pct);
   int temp_macd_score = CalculateMACDScore(macd_value, macd_signal_value, TREND_UP, macd_bullish_support, macd_bearish_support, macd_display_pct);
   
   DetectRange(rates);
   
   if(cached_price > ma_trend[0])
      trend_bias = TREND_UP;
   else if(cached_price < ma_trend[0])
      trend_bias = TREND_DOWN;
   else
      trend_bias = TREND_NONE;
   
   if(cached_price > ma_fast[0])
      trend_entry = TREND_UP;
   else if(cached_price < ma_fast[0])
      trend_entry = TREND_DOWN;
   else
      trend_entry = TREND_NONE;
   
   if(trend_bias == TREND_UP)
      status_trend = "BULLISH ▲";
   else if(trend_bias == TREND_DOWN)
      status_trend = "BEARISH ▼";
   else
      status_trend = "CHOPPY";
   
   if(trend_entry == TREND_UP)
      status_entry = "BULLISH ▲";
   else if(trend_entry == TREND_DOWN)
      status_entry = "BEARISH ▼";
   else
      status_entry = "NEUTRAL";
   
   if(trend_bias != TREND_NONE && trend_bias != trend_entry)
      status_entry += " ⚠️ MISALIGNED";
   
   int alignment_score = 0;
   string alignment_desc = "";
   alignment_score = CalculateTrendAlignmentScore(
       trend_bias, trend_entry, cached_price,
       ma_trend[0], ma_fast[0], alignment_desc
   );
   cached_alignment_score = alignment_score;
   cached_alignment_desc = alignment_desc;
   status_alignment = alignment_desc;
   
   ENUM_TREND_DIRECTION final_trend = TREND_NONE;
   if(trend_bias == trend_entry && trend_bias != TREND_NONE)
       final_trend = trend_bias;
   else if(trend_bias != TREND_NONE)
       final_trend = trend_bias;
   else if(trend_entry != TREND_NONE)
       final_trend = trend_entry;
   else
   {
       if(!has_open_position)
       {
           status_reason = "NO CLEAR TREND";
           status_alignment = "CHOPPY";
       }
       return;
   }
   cached_final_trend = final_trend;
   
   double swing_high = rates[0].high;
   double swing_low = rates[0].low;
   for(int i = 1; i < Range_Period && i < ArraySize(rates); i++)
   {
      if(rates[i].high > swing_high) swing_high = rates[i].high;
      if(rates[i].low < swing_low) swing_low = rates[i].low;
   }
   
   if(swing_high <= swing_low) return;
   
   double entry_price = 0;
   double pullback_percent = 0;
   
   if(final_trend == TREND_UP)
   {
       if(cached_price < swing_high && cached_price > swing_low)
       {
           pullback_percent = (swing_high - cached_price) / (swing_high - swing_low) * 100;
           entry_price = cached_price;
       }
       else
       {
           if(!has_open_position)
           {
               if(cached_price >= swing_high)
                   status_reason = "PRICE ABOVE SWING HIGH (BREAKOUT)";
               else if(cached_price <= swing_low)
                   status_reason = "PRICE BELOW SWING LOW (BREAKDOWN)";
           }
           return;
       }
   }
   else if(final_trend == TREND_DOWN)
   {
       if(cached_price > swing_low && cached_price < swing_high)
       {
           pullback_percent = (cached_price - swing_low) / (swing_high - swing_low) * 100;
           entry_price = cached_price;
       }
       else
       {
           if(!has_open_position)
           {
               if(cached_price <= swing_low)
                   status_reason = "PRICE BELOW SWING LOW (BREAKDOWN)";
               else if(cached_price >= swing_high)
                   status_reason = "PRICE ABOVE SWING HIGH (BREAKOUT)";
           }
           return;
       }
   }
   
   cached_entry_price = entry_price;
   cached_pullback_percent = pullback_percent;
   display_pullback_pct = pullback_percent;
   display_pullback_zone = GetPullbackZoneDescription(pullback_percent);
   status_pullback = display_pullback_zone;
   
   cached_pullback_score = CalculatePullbackScore(pullback_percent);
   display_pullback_score = cached_pullback_score;
   
   string h1_desc, m15_desc, d1_desc;
   int d1_score_tmp = 0, h1_score_tmp = 0, m15_score_tmp = 0;
   double current_ma120_m15 = iMA(_Symbol, Entry_Timeframe, 120, 0, MODE_SMA, PRICE_CLOSE);
   cached_mtf_score = CalculateUnifiedMTFScore(final_trend,
                                        rates_h1[0].close, ma_trend[0], ma_h1_21[0], ma_h1_50[0],
                                        rates_h1[0].close, rates_h1[0].open, rates_h1[1].close, rates_h1[1].open,
                                        cached_price, ma_fast[0], ma_m15_21[0], ma_m15_50[0], current_ma120_m15,
                                        rates_d1[0].close, ma_d1_89[0], atr[0],
                                        h1_desc, m15_desc, d1_desc, d1_score_tmp, h1_score_tmp, m15_score_tmp);
   d1_score_value = d1_score_tmp;
   h1_score_value = h1_score_tmp;
   m15_score_value = m15_score_tmp;
   cached_mtf_desc = h1_desc + " | " + m15_desc + " | " + d1_desc;
   display_mtf_score = cached_mtf_score;
   
   cached_rsi_score = CalculateRSIScore(rsi_value, final_trend, rsi_bullish_support, rsi_bearish_support, rsi_display_pct);
   display_rsi_score = cached_rsi_score;
   
   cached_macd_score = CalculateMACDScore(macd_value, macd_signal_value, final_trend, macd_bullish_support, macd_bearish_support, macd_display_pct);
   display_macd_score = cached_macd_score;
   
   if(rsi_display_pct > 55)
      status_rsi = "BULLISH";
   else if(rsi_display_pct < 45)
      status_rsi = "BEARISH";
   else
      status_rsi = "NEUTRAL";
   
   if(macd_display_pct > 55)
      status_macd = "BULLISH";
   else if(macd_display_pct < 45)
      status_macd = "BEARISH";
   else
      status_macd = "NEUTRAL";
   
   display_alignment_score = cached_alignment_score;
   
   cached_boost_active = CheckMACD_RSI_Boost();
   status_boost = cached_boost_active ? "⚡ACTIVE" : "OFF";
   
   cached_total_confidence = cached_mtf_score + cached_pullback_score + cached_macd_score + cached_rsi_score + cached_alignment_score;
   display_total_confidence = cached_total_confidence;
   status_confidence = IntegerToString(cached_total_confidence) + "/100";
   
   int threshold = GetConfidenceThreshold(final_trend);
   cached_has_signal = (cached_total_confidence >= threshold);
   status_pullback_ending = cached_has_signal ? "YES" : "NO";
   
   double diff_fast = (cached_price - ma_fast[0]) / ma_fast[0] * 100;
   double diff_trend = (cached_price - ma_trend[0]) / ma_trend[0] * 100;
   cached_price_pos_desc = StringFormat("Price is %.2f%% %s M15 MA120 and %.2f%% %s H1 MA60",
      MathAbs(diff_fast), (diff_fast > 0) ? "ABOVE" : "BELOW",
      MathAbs(diff_trend), (diff_trend > 0) ? "ABOVE" : "BELOW");
   
   if(ma_m15_21[0] > ma_m15_50[0])
      status_ma_cross = "MA21 > MA50 (BULLISH)";
   else if(ma_m15_21[0] < ma_m15_50[0])
      status_ma_cross = "MA21 < MA50 (BEARISH)";
   else
      status_ma_cross = "MA21 = MA50";
   
   status_daily_trades = IntegerToString(daily_trades) + "/" + IntegerToString(Max_Daily_Trades);
   
   DrawPullbackMarker(cached_price, final_trend, pullback_percent, cached_total_confidence, threshold);
   
   if(cached_has_signal && !has_open_position)
   {
      if(!CheckEntryConditions())
      {
         return;
      }
      
      double sl_price = 0;
      double tp_price = 0;
      
      sl_price = CalculateStructureSL(final_trend, entry_price, rates, atr[0]);
      tp_price = Calculate2R_TP(final_trend, entry_price, sl_price);
      
      cached_sl_price = sl_price;
      cached_tp_price = tp_price;
      
      string direction_str = (final_trend == TREND_UP) ? "BUY" : "SELL";
      string boost_str = cached_boost_active ? " (⚡BOOST ACTIVE)" : "";
      status_reason = direction_str + " CONFIDENCE MET ✅ - ENTERING" + boost_str;
      status_progress = "ENTERING " + direction_str;
      
      ExecuteTrade(final_trend, entry_price, sl_price, tp_price, cached_total_confidence, 
                   cached_pullback_score, cached_mtf_score,
                   cached_rsi_score, cached_macd_score, cached_alignment_score,
                   cached_pullback_desc, cached_mtf_desc, 
                   cached_price_pos_desc,
                   cached_alignment_desc, false, "", cached_boost_active);
   }
   else
   {
      string direction_str = (final_trend == TREND_UP) ? "BUY" : "SELL";
      string boost_str = cached_boost_active ? " (⚡BOOST REDUCED THRESHOLD)" : "";
      status_reason = "LOW " + direction_str + " CONFIDENCE (" + IntegerToString(cached_total_confidence) + "/" + IntegerToString(threshold) + ")" + boost_str;
      status_progress = "WAITING: " + direction_str + " CONFIDENCE";
   }
}

//+------------------------------------------------------------------+
//| Run Confidence Check - Every 5 Seconds                          |
//+------------------------------------------------------------------+
void RunConfidenceCheck()
{
   if(has_open_position)
   {
      if(Enable_RSI_MACD_Exit_Protection)
      {
         if(CheckExitConditions())
         {
            ClosePosition();
            status_reason = "EXITED: RSI/MACD PROTECTION";
            status_progress = "EXIT TRIGGERED";
            return;
         }
      }
      return;
   }
   
   if(cached_final_trend == TREND_NONE)
      return;
   
   MqlTick current_tick;
   if(!SymbolInfoTick(_Symbol, current_tick))
      return;
   
   double current_price = current_tick.bid;
   
   if(range_high > range_low)
   {
      if(cached_final_trend == TREND_UP)
         cached_pullback_percent = (range_high - current_price) / (range_high - range_low) * 100;
      else if(cached_final_trend == TREND_DOWN)
         cached_pullback_percent = (current_price - range_low) / (range_high - range_low) * 100;
   }
   
   display_pullback_pct = cached_pullback_percent;
   display_pullback_zone = GetPullbackZoneDescription(cached_pullback_percent);
   status_pullback = display_pullback_zone;
   
   cached_pullback_score = CalculatePullbackScore(cached_pullback_percent);
   display_pullback_score = cached_pullback_score;
   
   display_mtf_score = cached_mtf_score;
   display_alignment_score = cached_alignment_score;
   display_rsi_score = cached_rsi_score;
   display_macd_score = cached_macd_score;
   
   cached_boost_active = CheckMACD_RSI_Boost();
   status_boost = cached_boost_active ? "⚡ACTIVE" : "OFF";
   
   cached_total_confidence = cached_mtf_score + cached_pullback_score + cached_macd_score + cached_rsi_score + cached_alignment_score;
   display_total_confidence = cached_total_confidence;
   status_confidence = IntegerToString(cached_total_confidence) + "/100";
   
   int threshold = GetConfidenceThreshold(cached_final_trend);
   bool signal_now = (cached_total_confidence >= threshold);
   cached_has_signal = signal_now;
   status_pullback_ending = signal_now ? "YES" : "NO";
   
   if(signal_now)
   {
      cached_entry_price = current_price;
      display_pullback_pct = cached_pullback_percent;
   }
   
   string direction_str = (cached_final_trend == TREND_UP) ? "BUY" : "SELL";
   
   if(signal_now && !has_open_position)
   {
      if(!CheckEntryConditions())
      {
         return;
      }
      
      string boost_str = cached_boost_active ? " (⚡BOOST ACTIVE)" : "";
      status_reason = direction_str + " CONFIDENCE MET ✅ - ENTERING (5sec check)" + boost_str;
      status_progress = "ENTERING " + direction_str;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, Entry_Timeframe, 0, SL_Structure_Bars + 5, rates) >= SL_Structure_Bars + 5)
      {
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         if(CopyBuffer(handle_ATR, 0, 0, 5, atr_buffer) >= 5)
         {
            double current_atr = atr_buffer[0];
            
            double sl_price = 0;
            double tp_price = 0;
            
            sl_price = CalculateStructureSL(cached_final_trend, cached_entry_price, rates, current_atr);
            tp_price = Calculate2R_TP(cached_final_trend, cached_entry_price, sl_price);
            
            cached_sl_price = sl_price;
            cached_tp_price = tp_price;
         }
      }
      
      ExecuteTrade(cached_final_trend, cached_entry_price, cached_sl_price, cached_tp_price, 
                   cached_total_confidence, 
                   cached_pullback_score, cached_mtf_score,
                   cached_rsi_score, cached_macd_score, cached_alignment_score,
                   cached_pullback_desc, cached_mtf_desc, 
                   cached_price_pos_desc,
                   cached_alignment_desc, false, "", cached_boost_active);
   }
   else if(signal_now && has_open_position)
   {
      status_reason = direction_str + " CONFIDENCE MET ✅ - ALREADY IN TRADE";
   }
   else
   {
      string boost_str = cached_boost_active ? " (⚡BOOST REDUCED THRESHOLD)" : "";
      status_reason = "LOW " + direction_str + " CONFIDENCE (" + IntegerToString(cached_total_confidence) + "/" + IntegerToString(threshold) + ")" + boost_str;
      status_progress = "WAITING: " + direction_str + " CONFIDENCE";
   }
}

//+------------------------------------------------------------------+
//| Reset Daily Counter                                              |
//+------------------------------------------------------------------+
void ResetDailyCounter()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   datetime today_start = StringToTime(IntegerToString(dt.year) + "." + 
                                       IntegerToString(dt.mon) + "." + 
                                       IntegerToString(dt.day) + " 00:00");
   
   if(last_trade_date == 0 || last_trade_date < today_start)
   {
      daily_trades = 0;
      last_trade_date = now;
   }
}

//+------------------------------------------------------------------+
//| Check Daily Trade Limit                                          |
//+------------------------------------------------------------------+
bool CheckDailyTradeLimit()
{
   return (daily_trades < Max_Daily_Trades);
}

//+------------------------------------------------------------------+
//| Draw Chart Info                                                  |
//+------------------------------------------------------------------+
void DrawChartInfo()
{
   if(!Enable_Chart_Comments) return;
   
   int yPos = 10;
   int xPos = 20;
   int lineHeight = 18;
   int col2_x = 220;
   int col3_x = 380;
   
   yPos += lineHeight + 2;
   
   string boostText = "⚡BOOST: " + status_boost;
   ObjectCreate(0, "ChartInfo_Boost", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_Boost", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_Boost", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_Boost", OBJPROP_TEXT, boostText);
   ObjectSetInteger(0, "ChartInfo_Boost", OBJPROP_COLOR, cached_boost_active ? clrLime : clrGray);
   ObjectSetInteger(0, "ChartInfo_Boost", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_Boost", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_Boost", OBJPROP_BACK, false);
   
   string rrText = StringFormat("💵 R:R: %s", status_rr);
   ObjectCreate(0, "ChartInfo_RR", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_RR", OBJPROP_XDISTANCE, col2_x);
   ObjectSetInteger(0, "ChartInfo_RR", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_RR", OBJPROP_TEXT, rrText);
   ObjectSetInteger(0, "ChartInfo_RR", OBJPROP_COLOR, clrCyan);
   ObjectSetInteger(0, "ChartInfo_RR", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_RR", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_RR", OBJPROP_BACK, false);
   
   string balText = StringFormat("💰 BAL: %s", status_profit);
   ObjectCreate(0, "ChartInfo_Bal", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_Bal", OBJPROP_XDISTANCE, col3_x);
   ObjectSetInteger(0, "ChartInfo_Bal", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_Bal", OBJPROP_TEXT, balText);
   ObjectSetInteger(0, "ChartInfo_Bal", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "ChartInfo_Bal", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_Bal", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_Bal", OBJPROP_BACK, false);
   
   yPos += lineHeight;
   
   ObjectCreate(0, "ChartInfo_Sep1", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_Sep1", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_Sep1", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_Sep1", OBJPROP_TEXT, "═══════════════════════════════════════════════════════");
   ObjectSetInteger(0, "ChartInfo_Sep1", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "ChartInfo_Sep1", OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, "ChartInfo_Sep1", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_Sep1", OBJPROP_BACK, false);
   
   yPos += lineHeight;
   
   string mtfText = StringFormat("📊 MTF: %d/45 (D1:%d H1:%d M15:%d)", 
                                display_mtf_score,
                                d1_score_value, h1_score_value, m15_score_value);
   color mtfColor = display_mtf_score >= 35 ? clrLime : (display_mtf_score >= 25 ? clrYellow : clrRed);
   ObjectCreate(0, "ChartInfo_MTF", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_MTF", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_MTF", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_MTF", OBJPROP_TEXT, mtfText);
   ObjectSetInteger(0, "ChartInfo_MTF", OBJPROP_COLOR, mtfColor);
   ObjectSetInteger(0, "ChartInfo_MTF", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_MTF", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_MTF", OBJPROP_BACK, false);
   yPos += lineHeight;
   
   string pbText = StringFormat("📈 PB: %d/25  (%.1f%%)  %s", 
                                display_pullback_score, 
                                display_pullback_pct,
                                display_pullback_zone);
   color pbColor = display_pullback_score >= 21 ? clrLime : (display_pullback_score >= 15 ? clrYellow : clrRed);
   ObjectCreate(0, "ChartInfo_PB", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_PB", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_PB", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_PB", OBJPROP_TEXT, pbText);
   ObjectSetInteger(0, "ChartInfo_PB", OBJPROP_COLOR, pbColor);
   ObjectSetInteger(0, "ChartInfo_PB", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_PB", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_PB", OBJPROP_BACK, false);
   yPos += lineHeight;
   
   string macd_display_status = "";
   if(macd_display_pct > 55)
      macd_display_status = "📈" + DoubleToString(macd_display_pct, 0) + "% (Bullish)";
   else if(macd_display_pct < 45)
      macd_display_status = "📉" + DoubleToString(macd_display_pct, 0) + "% (Bearish)";
   else
      macd_display_status = "➡️" + DoubleToString(macd_display_pct, 0) + "% (Neutral)";
   
   string macdText = StringFormat("📊 MACD: %d/15 (%.2f)  %s", 
                                 display_macd_score, 
                                 macd_value,
                                 macd_display_status);
   color macdColor = display_macd_score >= 12 ? clrLime : (display_macd_score >= 8 ? clrYellow : clrRed);
   ObjectCreate(0, "ChartInfo_MACD", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_MACD", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_MACD", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_MACD", OBJPROP_TEXT, macdText);
   ObjectSetInteger(0, "ChartInfo_MACD", OBJPROP_COLOR, macdColor);
   ObjectSetInteger(0, "ChartInfo_MACD", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_MACD", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_MACD", OBJPROP_BACK, false);
   yPos += lineHeight;
   
   string rsi_display_status = "";
   if(rsi_display_pct > 55)
      rsi_display_status = "📈" + DoubleToString(rsi_display_pct, 0) + "% (Bullish)";
   else if(rsi_display_pct < 45)
      rsi_display_status = "📉" + DoubleToString(rsi_display_pct, 0) + "% (Bearish)";
   else
      rsi_display_status = "➡️" + DoubleToString(rsi_display_pct, 0) + "% (Neutral)";
   
   string rsiText = StringFormat("📊 RSI: %d/10 (%.1f)  %s", 
                                display_rsi_score, 
                                rsi_value,
                                rsi_display_status);
   color rsiColor = display_rsi_score >= 8 ? clrLime : (display_rsi_score >= 5 ? clrYellow : clrRed);
   ObjectCreate(0, "ChartInfo_RSI", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_RSI", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_RSI", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_RSI", OBJPROP_TEXT, rsiText);
   ObjectSetInteger(0, "ChartInfo_RSI", OBJPROP_COLOR, rsiColor);
   ObjectSetInteger(0, "ChartInfo_RSI", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_RSI", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_RSI", OBJPROP_BACK, false);
   yPos += lineHeight;
   
   string alText = StringFormat("🔗 AL: %d/5  %s", 
                                display_alignment_score,
                                status_alignment);
   color alColor = display_alignment_score >= 4 ? clrLime : (display_alignment_score >= 2 ? clrYellow : clrRed);
   ObjectCreate(0, "ChartInfo_AL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_AL", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_AL", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_AL", OBJPROP_TEXT, alText);
   ObjectSetInteger(0, "ChartInfo_AL", OBJPROP_COLOR, alColor);
   ObjectSetInteger(0, "ChartInfo_AL", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_AL", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_AL", OBJPROP_BACK, false);
   yPos += lineHeight + 2;
   
   if(Enable_RSI_MACD_Exit_Protection)
   {
      string exitStatus = "🛡️ EXIT: " + status_exit_warning;
      color exitColor = clrLime;
      if(status_exit_warning != "NONE")
      {
         if(StringFind(status_exit_warning, "HARD") >= 0)
            exitColor = clrRed;
         else
            exitColor = clrOrange;
      }
      ObjectCreate(0, "ChartInfo_Exit", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_Exit", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "ChartInfo_Exit", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_Exit", OBJPROP_TEXT, exitStatus);
      ObjectSetInteger(0, "ChartInfo_Exit", OBJPROP_COLOR, exitColor);
      ObjectSetInteger(0, "ChartInfo_Exit", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_Exit", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_Exit", OBJPROP_BACK, false);
      yPos += lineHeight;
   }
   
   ObjectCreate(0, "ChartInfo_Sep2", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_Sep2", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_Sep2", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_Sep2", OBJPROP_TEXT, "───────────────────────────────────────────────────────");
   ObjectSetInteger(0, "ChartInfo_Sep2", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "ChartInfo_Sep2", OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, "ChartInfo_Sep2", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_Sep2", OBJPROP_BACK, false);
   
   yPos += lineHeight;
   
   double confPercent = (double)display_total_confidence;
   string confText = StringFormat("🎯 TOTAL: %d/100 (%.0f%%)", 
                                  display_total_confidence,
                                  confPercent);
   color confColor = clrRed;
   if(confPercent >= Confidence_Threshold)
      confColor = clrLime;
   else if(confPercent >= 45)
      confColor = clrYellow;
   
   int currentThreshold = GetConfidenceThreshold(cached_final_trend);
   string threshText = StringFormat("🎯 THRESHOLD: %d%%%s", currentThreshold, 
                                    (currentThreshold < Confidence_Threshold) ? " ⚡" : "");
   
   ObjectCreate(0, "ChartInfo_CONF", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_CONF", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_CONF", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_CONF", OBJPROP_TEXT, confText);
   ObjectSetInteger(0, "ChartInfo_CONF", OBJPROP_COLOR, confColor);
   ObjectSetInteger(0, "ChartInfo_CONF", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_CONF", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_CONF", OBJPROP_BACK, false);
   
   ObjectCreate(0, "ChartInfo_THRESH", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_THRESH", OBJPROP_XDISTANCE, xPos + 200);
   ObjectSetInteger(0, "ChartInfo_THRESH", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_THRESH", OBJPROP_TEXT, threshText);
   ObjectSetInteger(0, "ChartInfo_THRESH", OBJPROP_COLOR, (currentThreshold < Confidence_Threshold) ? clrLime : clrGray);
   ObjectSetInteger(0, "ChartInfo_THRESH", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_THRESH", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_THRESH", OBJPROP_BACK, false);
   
   yPos += lineHeight;
   
   string endStatus = "⏳ WAITING";
   color endColor = clrGray;
   if(confPercent >= currentThreshold && confPercent > 0)
   {
      endStatus = "✅ YES (" + IntegerToString((int)confPercent) + "%)";
      endColor = clrLime;
   }
   else if(confPercent > 0 && confPercent < currentThreshold)
   {
      endStatus = "❌ NO (" + IntegerToString((int)confPercent) + "%)";
      endColor = clrRed;
   }
   
   string statusText = StringFormat("📈 %s | ✅ %s | 🔄 %s | ⚡ %s", 
                                    status_trend, 
                                    status_entry, 
                                    endStatus,
                                    status_reason);
   ObjectCreate(0, "ChartInfo_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "ChartInfo_Status", OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, "ChartInfo_Status", OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, "ChartInfo_Status", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "ChartInfo_Status", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "ChartInfo_Status", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "ChartInfo_Status", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "ChartInfo_Status", OBJPROP_BACK, false);
   
   yPos += lineHeight + 2;
   
   if(!Enable_Sell_Trades)
   {
      ObjectCreate(0, "ChartInfo_SellDisabled", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_SellDisabled", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "ChartInfo_SellDisabled", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_SellDisabled", OBJPROP_TEXT, "🔴 SELL TRADES DISABLED");
      ObjectSetInteger(0, "ChartInfo_SellDisabled", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "ChartInfo_SellDisabled", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_SellDisabled", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_SellDisabled", OBJPROP_BACK, false);
      yPos += lineHeight;
   }
   
   if(!Enable_Buy_Trades)
   {
      ObjectCreate(0, "ChartInfo_BuyDisabled", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_BuyDisabled", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "ChartInfo_BuyDisabled", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_BuyDisabled", OBJPROP_TEXT, "🔴 BUY TRADES DISABLED");
      ObjectSetInteger(0, "ChartInfo_BuyDisabled", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "ChartInfo_BuyDisabled", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_BuyDisabled", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_BuyDisabled", OBJPROP_BACK, false);
      yPos += lineHeight;
   }
   
   if(has_open_position)
   {
      ObjectCreate(0, "ChartInfo_Sep3", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_Sep3", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "ChartInfo_Sep3", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_Sep3", OBJPROP_TEXT, "─── IN TRADE ───");
      ObjectSetInteger(0, "ChartInfo_Sep3", OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, "ChartInfo_Sep3", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "ChartInfo_Sep3", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_Sep3", OBJPROP_BACK, false);
      yPos += lineHeight;
      
      string lotText = StringFormat("LOT: %s", status_lot);
      ObjectCreate(0, "ChartInfo_Lot", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_Lot", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "ChartInfo_Lot", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_Lot", OBJPROP_TEXT, lotText);
      ObjectSetInteger(0, "ChartInfo_Lot", OBJPROP_COLOR, clrCyan);
      ObjectSetInteger(0, "ChartInfo_Lot", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_Lot", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_Lot", OBJPROP_BACK, false);
      
      string plText = StringFormat("P/L: %s", status_profit);
      color plColor = clrGray;
      if(StringFind(status_profit, "-") >= 0)
         plColor = clrRed;
      else if(StringToDouble(status_profit) > 0)
         plColor = clrLime;
      
      ObjectCreate(0, "ChartInfo_PL", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_PL", OBJPROP_XDISTANCE, xPos + 100);
      ObjectSetInteger(0, "ChartInfo_PL", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_PL", OBJPROP_TEXT, plText);
      ObjectSetInteger(0, "ChartInfo_PL", OBJPROP_COLOR, plColor);
      ObjectSetInteger(0, "ChartInfo_PL", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_PL", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_PL", OBJPROP_BACK, false);
      
      string dirText = StringFormat("DIR: %s", status_in_trade == "YES" ? (current_trade_direction == TREND_UP ? "▲ BUY" : "▼ SELL") : "NONE");
      ObjectCreate(0, "ChartInfo_Dir", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ChartInfo_Dir", OBJPROP_XDISTANCE, xPos + 200);
      ObjectSetInteger(0, "ChartInfo_Dir", OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, "ChartInfo_Dir", OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, "ChartInfo_Dir", OBJPROP_COLOR, current_trade_direction == TREND_UP ? clrLime : clrRed);
      ObjectSetInteger(0, "ChartInfo_Dir", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "ChartInfo_Dir", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "ChartInfo_Dir", OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| Draw Swing High and Low Arrows                                   |
//+------------------------------------------------------------------+
void DrawSwingHighLow(MqlRates &rates[])
{
   ObjectsDeleteAll(0, "SwingHigh_");
   ObjectsDeleteAll(0, "SwingLow_");
   ObjectsDeleteAll(0, "SwingHigh_NoData");
   
   int arraySize = ArraySize(rates);
   if(arraySize < Range_Period) 
   {
      datetime now = rates[0].time;
      double price = rates[0].close;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      ObjectCreate(0, "SwingHigh_NoData", OBJ_TEXT, 0, now, price + (20 * point));
      ObjectSetString(0, "SwingHigh_NoData", OBJPROP_TEXT, "⚠️ INSUFFICIENT DATA");
      ObjectSetInteger(0, "SwingHigh_NoData", OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, "SwingHigh_NoData", OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, "SwingHigh_NoData", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetString(0, "SwingHigh_NoData", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SwingHigh_NoData", OBJPROP_BACK, false);
      return;
   }
   
   double high = rates[0].high;
   double low = rates[0].low;
   int highIndex = 0;
   int lowIndex = 0;
   
   int period = MathMin(Range_Period, arraySize);
   for(int i = 1; i < period; i++)
   {
      if(rates[i].high > high)
      {
         high = rates[i].high;
         highIndex = i;
      }
      if(rates[i].low < low)
      {
         low = rates[i].low;
         lowIndex = i;
      }
   }
   
   datetime high_time = rates[highIndex].time;
   datetime low_time = rates[lowIndex].time;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double label_offset = 20 * point;
   
   if(ObjectCreate(0, "SwingHigh_Arrow", OBJ_ARROW, 0, high_time, high))
   {
      ObjectSetInteger(0, "SwingHigh_Arrow", OBJPROP_ARROWCODE, 242);
      ObjectSetInteger(0, "SwingHigh_Arrow", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "SwingHigh_Arrow", OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, "SwingHigh_Arrow", OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
   
   if(ObjectCreate(0, "SwingLow_Arrow", OBJ_ARROW, 0, low_time, low))
   {
      ObjectSetInteger(0, "SwingLow_Arrow", OBJPROP_ARROWCODE, 241);
      ObjectSetInteger(0, "SwingLow_Arrow", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SwingLow_Arrow", OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, "SwingLow_Arrow", OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
   
   if(ObjectCreate(0, "SwingHigh_Label", OBJ_TEXT, 0, high_time, high + label_offset))
   {
      ObjectSetString(0, "SwingHigh_Label", OBJPROP_TEXT, "🔴 SWING HIGH");
      ObjectSetInteger(0, "SwingHigh_Label", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "SwingHigh_Label", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "SwingHigh_Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetString(0, "SwingHigh_Label", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SwingHigh_Label", OBJPROP_BACK, false);
   }
   
   if(ObjectCreate(0, "SwingLow_Label", OBJ_TEXT, 0, low_time, low - label_offset))
   {
      ObjectSetString(0, "SwingLow_Label", OBJPROP_TEXT, "🟢 SWING LOW");
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetString(0, "SwingLow_Label", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| Close Position                                                   |
//+------------------------------------------------------------------+
void ClosePosition()
{
   if(!has_open_position || positionTicket == 0) return;
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionClose(positionTicket))
   {
      has_open_position = false;
      positionTicket = 0;
      current_trade_direction = TREND_NONE;
      CleanupProfitTrackers();
      trade_signature_display = "";
   }
}

//+------------------------------------------------------------------+
//| Check Open Positions                                             |
//+------------------------------------------------------------------+
void CheckOpenPositions()
{
   has_open_position = false;
   positionTicket = 0;
   current_trade_direction = TREND_NONE;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong pos_ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(pos_ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            has_open_position = true;
            positionTicket = pos_ticket;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               current_trade_direction = TREND_UP;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               current_trade_direction = TREND_DOWN;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Status                                                    |
//+------------------------------------------------------------------+
void UpdateStatus()
{
   if(has_open_position)
   {
      status_in_trade = "YES";
      
      if(PositionSelectByTicket(positionTicket))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         double risk = MathAbs(entry - sl);
         double reward = MathAbs(tp - entry);
         double rr = (risk > 0) ? reward / risk : 0;
         
         status_profit = "$" + DoubleToString(profit, 2);
         status_lot = DoubleToString(volume, 2);
         status_rr = DoubleToString(rr, 2) + ":1";
         
         if(profit > 0)
            status_progress = "IN PROFIT ▲";
         else if(profit < 0)
            status_progress = "IN LOSS ▼";
         else
            status_progress = "BREAKEVEN";
      }
   }
   else
   {
      status_in_trade = "NO";
      status_profit = "$0.00";
      status_lot = "0.00";
      status_rr = "0.00";
   }
}

//+------------------------------------------------------------------+
//| Detect Range Function                                            |
//+------------------------------------------------------------------+
void DetectRange(MqlRates &rates[])
{
   if(ArraySize(rates) < Range_Period) return;
   
   double high = rates[0].high;
   double low = rates[0].low;
   
   for(int i = 1; i < Range_Period && i < ArraySize(rates); i++)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   
   range_high = high;
   range_low = low;
   range_mid = (high + low) / 2;
}

//+------------------------------------------------------------------+
//| Calculate Structure Stop Loss - STRUCTURE BASED ONLY            |
//+------------------------------------------------------------------+
double CalculateStructureSL(ENUM_TREND_DIRECTION trend, double entry_price,
                            MqlRates &rates[], double atr_value)
{
   double sl_price = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(trend == TREND_UP)
   {
      double lowest_low = rates[0].low;
      for(int i = 1; i < SL_Structure_Bars && i < ArraySize(rates); i++)
      {
         if(rates[i].low < lowest_low)
            lowest_low = rates[i].low;
      }
      
      sl_price = lowest_low - (atr_value * SL_ATR_Multiplier);
      
      double min_distance = Min_SL_Distance * point;
      double min_allowed_sl = entry_price - min_distance;
      if(sl_price > min_allowed_sl)
         sl_price = min_allowed_sl;
      
      double max_allowed_sl = entry_price - (atr_value * Max_SL_ATR);
      if(sl_price < max_allowed_sl)
         sl_price = max_allowed_sl;
   }
   else if(trend == TREND_DOWN)
   {
      double highest_high = rates[0].high;
      for(int i = 1; i < SL_Structure_Bars && i < ArraySize(rates); i++)
      {
         if(rates[i].high > highest_high)
            highest_high = rates[i].high;
      }
      
      sl_price = highest_high + (atr_value * SL_ATR_Multiplier);
      
      double min_distance = Min_SL_Distance * point;
      double min_allowed_sl = entry_price + min_distance;
      if(sl_price < min_allowed_sl)
         sl_price = min_allowed_sl;
      
      double max_allowed_sl = entry_price + (atr_value * Max_SL_ATR);
      if(sl_price > max_allowed_sl)
         sl_price = max_allowed_sl;
   }
   
   sl_price = NormalizeDouble(sl_price, _Digits);
   return sl_price;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit - 2x Risk (2R)                             |
//+------------------------------------------------------------------+
double Calculate2R_TP(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price)
{
   double risk = MathAbs(entry_price - sl_price);
   double tp_price = 0;
   
   if(trend == TREND_UP)
   {
      tp_price = entry_price + (risk * Target_RR);
   }
   else if(trend == TREND_DOWN)
   {
      tp_price = entry_price - (risk * Target_RR);
   }
   
   tp_price = NormalizeDouble(tp_price, _Digits);
   return tp_price;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size - ACCOUNT BASED - FIXED              |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double entry_price, double sl_price)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (Risk_Per_Trade_Pct / 100.0);
   
   double slDistance = MathAbs(entry_price - sl_price);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(slDistance <= 0 || point <= 0) return Min_Lot_Size;
   
   //--- For XAUUSD: 1 point = $0.01 per 0.01 lot = $1.00 per 1 lot
   double slPoints = slDistance / point; // Number of points in SL
   double valuePerPointPerLot = 1.0; // $1.00 per point per 1 lot (XAUUSD)
   
   //--- Lot size = Risk / (SL_points * value_per_point_per_lot)
   double lotSize = riskAmount / (slPoints * valuePerPointPerLot);
   
   //--- Account-based scaling (graduated sizing)
   double maxAllowed = 0;
   if(accountBalance <= 50)      maxAllowed = 0.02;
   else if(accountBalance <= 100) maxAllowed = 0.05;
   else if(accountBalance <= 200) maxAllowed = 0.10;
   else if(accountBalance <= 500) maxAllowed = 0.30;
   else if(accountBalance <= 1000) maxAllowed = 0.50;
   else                           maxAllowed = 1.00;
   
   //--- Apply limits
   lotSize = MathMax(Min_Lot_Size, MathMin(maxAllowed, lotSize));
   lotSize = MathMin(Max_Lot_Size, lotSize);
   
   //--- Round to valid lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep > 0)
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   lotSize = MathMax(Min_Lot_Size, lotSize);
   lotSize = MathMin(Max_Lot_Size, lotSize);
   
   //--- Debug logging
   if(Enable_Logging)
   {
      Print("=== LOT SIZE CALCULATION ===");
      Print("Account Balance: $" + DoubleToString(accountBalance, 2));
      Print("Risk %: " + DoubleToString(Risk_Per_Trade_Pct, 1) + "%");
      Print("Risk Amount: $" + DoubleToString(riskAmount, 2));
      Print("SL Distance: " + DoubleToString(slDistance, _Digits) + " (" + DoubleToString(slPoints, 1) + " points)");
      Print("Calculated Lot: " + DoubleToString(lotSize, 2));
      Print("Max Allowed: " + DoubleToString(maxAllowed, 2));
      Print("=============================");
   }
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score,
                  int rsi_score_val, int macd_score_val, int alignment_score,
                  string pullback_desc, string mtf_desc, 
                  string price_pos_desc,
                  string alignment_desc,
                  bool is_rejected = false, string reject_reason = "",
                  bool boost_active = false)
{
   if(trend == TREND_UP && !Enable_Buy_Trades)
   {
      status_reason = "BUY TRADES DISABLED";
      status_progress = "DISABLED";
      LogMessage("🚫 BUY TRADES DISABLED - Trade rejected");
      return;
   }
   
   if(trend == TREND_DOWN && !Enable_Sell_Trades)
   {
      status_reason = "SELL TRADES DISABLED";
      status_progress = "DISABLED";
      LogMessage("🚫 SELL TRADES DISABLED - Trade rejected");
      return;
   }
   
   double pb_pct = ((trend == TREND_UP) ? 
                     (range_high - entry_price) / (range_high - range_low) * 100 : 
                     (entry_price - range_low) / (range_high - range_low) * 100);
   
   mtf_total_score = (int)((double)mtf_score / 45.0 * 100);
  
   if(is_rejected)
   {
      LogMessage("🚫 Trade rejected: " + reject_reason);
      return;
   }
   
   if(has_open_position && current_trade_direction == trend)
      return;
   
   if(has_open_position && current_trade_direction != trend)
   {
      ClosePosition();
      Sleep(100);
      return;
   }
   
   if(has_open_position)
      return;
   
   if(!CanAddNewPosition())
   {
      status_reason = "MAX POSITIONS REACHED";
      status_progress = "LIMIT";
      LogMessage("🚫 Max positions reached - Trade rejected");
      return;
   }
   
   if(Enable_Daily_Limit && !CheckDailyTradeLimit())
   {
      status_reason = "DAILY LIMIT REACHED";
      status_progress = "LIMIT";
      LogMessage("🚫 Daily limit reached - Trade rejected");
      return;
   }
   
   double risk = MathAbs(entry_price - sl_price);
   double reward = MathAbs(tp_price - entry_price);
   double rr_ratio = reward / risk;
   
   double lot_size = CalculateDynamicLotSize(entry_price, sl_price);
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (Risk_Per_Trade_Pct / 100.0);
   
   LogMessage("📊 POSITION SIZING:");
   LogMessage("   Account Balance: $" + DoubleToString(accountBalance, 2));
   LogMessage("   Risk %: " + DoubleToString(Risk_Per_Trade_Pct, 1) + "%");
   LogMessage("   Risk Amount: $" + DoubleToString(riskAmount, 2));
   LogMessage("   Calculated Lot: " + DoubleToString(lot_size, 2));
   LogMessage("   SL Distance: " + DoubleToString(risk, _Digits) + " points");
   LogMessage("   RR: " + DoubleToString(rr_ratio, 2) + ":1");
   
   if(rr_ratio < 1.0)
   {
      status_reason = "RR TOO LOW (" + DoubleToString(rr_ratio, 2) + ")";
      status_progress = "REJECTED: RR";
      LogMessage("🚫 RR too low: " + DoubleToString(rr_ratio, 2));
      return;
   }
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   double price = 0, sl = 0, tp = 0;
   string type_str = "";
   bool success = false;
   
   string direction_indicator = (trend == TREND_UP) ? "▲BUY" : "▼SELL";
   string boost_indicator = boost_active ? "⚡" : "";
   
   string rsi_compact = StringFormat("RSI:%d/10(%s%.0f%%)", 
                                     rsi_score_val,
                                     rsi_display_pct >= 50 ? "📈" : "📉",
                                     rsi_display_pct >= 50 ? rsi_display_pct : rsi_display_pct);
   
   string macd_compact = StringFormat("MCD:%d/15(%s%.0f%%)", 
                                      macd_score_val,
                                      macd_display_pct >= 50 ? "📈" : "📉",
                                      macd_display_pct >= 50 ? macd_display_pct : macd_display_pct);
   
   string comment = StringFormat("%s%s|PB:%.0f%%|MTF:%d/45|AL:%d/5|%s|%s|C:%d%%|LOT:%.2f",
                                  boost_indicator,
                                  direction_indicator,
                                  pb_pct,
                                  mtf_score,
                                  alignment_score,
                                  rsi_compact,
                                  macd_compact,
                                  total_confidence,
                                  lot_size);
   
   if(trend == TREND_UP)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = sl_price;
      tp = tp_price;
      type_str = "BUY";
      success = trade.Buy(lot_size, _Symbol, price, sl, tp, comment);
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = sl_price;
      tp = tp_price;
      type_str = "SELL";
      success = trade.Sell(lot_size, _Symbol, price, sl, tp, comment);
   }
   
   if(success)
   {
      positionTicket = trade.ResultOrder();
      has_open_position = true;
      current_trade_direction = trend;
      
      daily_trades++;
      
      StoreSuccessfulTrade(price, trend, total_confidence, pb_pct,
                           pullback_score, alignment_score, mtf_score, 
                           rsi_score_val, macd_score_val);
      
      InitializeProfitTracker(positionTicket);
      ObjectsDeleteAll(0, "Pullback_");
      
      string confidence_label = "";
      if(total_confidence >= 85)
         confidence_label = "VERY HIGH";
      else if(total_confidence >= 70)
         confidence_label = "HIGH";
      else if(total_confidence >= 60)
         confidence_label = "GOOD";
      else if(total_confidence >= 50)
         confidence_label = "MODERATE";
      else if(total_confidence >= 40)
         confidence_label = "LOW";
      else
         confidence_label = "VERY LOW";
      
      status_in_trade = "YES";
      status_reason = type_str + " OPENED" + (boost_active ? " ⚡BOOST" : "");
      status_progress = type_str + " @ " + DoubleToString(price, _Digits) + 
                        " | LOT: " + DoubleToString(lot_size, 2);
      status_confidence = IntegerToString(total_confidence) + "/100 (" + confidence_label + ")";
      status_lot = DoubleToString(lot_size, 2);
      status_rr = DoubleToString(rr_ratio, 2) + ":1";
      
      UpdateTradeSignatureDisplay();
      
      LogMessage("=========================================");
      LogMessage("   🟢 DAY TRADE ENTERED   ");
      if(boost_active) LogMessage("   ⚡ BOOST ACTIVE - REDUCED THRESHOLD");
      LogMessage("=========================================");
      LogMessage("Type: " + type_str);
      LogMessage("Ticket: " + IntegerToString(positionTicket));
      LogMessage("Entry: " + DoubleToString(price, _Digits));
      LogMessage("SL: " + DoubleToString(sl, _Digits));
      LogMessage("TP: " + DoubleToString(tp, _Digits));
      LogMessage("RR: " + DoubleToString(rr_ratio, 2) + ":1");
      LogMessage("Lot Size: " + DoubleToString(lot_size, 2));
      LogMessage("Account Balance: $" + DoubleToString(accountBalance, 2));
      LogMessage("Risk %: " + DoubleToString(Risk_Per_Trade_Pct, 1) + "%");
      LogMessage("Daily Trades: " + IntegerToString(daily_trades) + "/" + IntegerToString(Max_Daily_Trades));
      LogMessage("Trade Comment: " + comment);
      LogMessage("--- 📊 Entry RSI/MACD Status ---");
      LogMessage("RSI: " + DoubleToString(rsi_display_pct, 0) + "% (" + status_rsi + ")");
      LogMessage("MACD: " + DoubleToString(macd_display_pct, 0) + "% (" + status_macd + ")");
      
      LogMessage("--- 🎯 Entry Reasons ---");
      LogMessage("Trend: " + (string)((trend_bias == TREND_UP) ? "BULLISH (H1>MA60)" : "BEARISH (H1<MA60)"));
      LogMessage("Entry Signal: Price " + (string)((trend_entry == TREND_UP) ? "ABOVE" : "BELOW") + " M15 MA120");
      LogMessage("Pullback: " + DoubleToString(pb_pct, 1) + "%");
      LogMessage("Range: " + DoubleToString(range_low, _Digits) + " - " + DoubleToString(range_high, _Digits));
      LogMessage("Price Position: " + price_pos_desc);
      
      LogMessage("--- 📊 Confidence Score: " + IntegerToString(total_confidence) + "/100 (" + confidence_label + ") ---");
      LogMessage("📊 MTF Score: " + IntegerToString(mtf_score) + "/45 - " + mtf_desc + " (PRIMARY)");
      LogMessage("📈 Pullback Score: " + IntegerToString(pullback_score) + "/25 - " + pullback_desc + " (ENTRY TRIGGER)");
      LogMessage("📊 MACD Score: " + IntegerToString(macd_score_val) + "/15 - Display: " + DoubleToString(macd_display_pct, 0) + "% (MOMENTUM)");
      LogMessage("📊 RSI Score: " + IntegerToString(rsi_score_val) + "/10 - Display: " + DoubleToString(rsi_display_pct, 0) + "% (MOMENTUM)");
      LogMessage("🔗 Alignment Score: " + IntegerToString(alignment_score) + "/5 - " + alignment_desc + " (SUPPORTING)");
      LogMessage("=========================================");
   }
   else
   {
      int error = GetLastError();
      status_reason = "TRADE FAILED (Error " + IntegerToString(error) + ")";
      status_progress = "FAILED";
      LogMessage("=== TRADE FAILED ===");
      LogMessage("Error: " + IntegerToString(error), true);
   }
}

//+------------------------------------------------------------------+
//| Draw Pullback Marker                                             |
//+------------------------------------------------------------------+
void DrawPullbackMarker(double current_price, ENUM_TREND_DIRECTION trend, double pullback_percent,
                        int total_confidence, int threshold)
{
   string prefix = "Pullback_";
   datetime now = TimeCurrent();
   
   ObjectsDeleteAll(0, prefix);
   
   color signal_color = (trend == TREND_UP) ? clrLime : clrRed;
   int arrow_code = (trend == TREND_UP) ? 241 : 242;
   
   ObjectCreate(0, prefix + "Arrow", OBJ_ARROW, 0, now, current_price);
   ObjectSetInteger(0, prefix + "Arrow", OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, prefix + "Arrow", OBJPROP_COLOR, signal_color);
   ObjectSetInteger(0, prefix + "Arrow", OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, prefix + "Arrow", OBJPROP_ANCHOR, ANCHOR_CENTER);
   
   string boost_label = cached_boost_active ? " ⚡" : "";
   string label_text = DoubleToString(pullback_percent, 1) + "% | C: " + 
                       IntegerToString(total_confidence) + "/100" + boost_label;
   
   if(total_confidence >= threshold)
      label_text += " ✅";
   else if(total_confidence >= 55)
      label_text += " 🟠";
   else
      label_text += " 🔴";
   
   ObjectCreate(0, prefix + "Label", OBJ_TEXT, 0, now + PeriodSeconds(Entry_Timeframe)*2, current_price);
   ObjectSetString(0, prefix + "Label", OBJPROP_TEXT, label_text);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_COLOR, signal_color);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_BACK, false);
   ObjectSetString(0, prefix + "Label", OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| ==================== PROFIT MANAGEMENT FUNCTIONS ================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Profit Tracker - ENHANCED                            |
//+------------------------------------------------------------------+
void InitializeProfitTracker(ulong posTicket)
{
   int index = -1;
   for(int i = 0; i < trackerCount; i++)
   {
      if(profitTrackers[i].posTicket == posTicket)
      {
         index = i;
         break;
      }
   }
   
   if(index == -1)
   {
      if(trackerCount >= ArraySize(profitTrackers))
         ArrayResize(profitTrackers, trackerCount + 50);
      
      index = trackerCount;
      trackerCount++;
   }
   
   profitTrackers[index].posTicket = posTicket;
   profitTrackers[index].highestPercentSeen = 0;
   profitTrackers[index].breakevenProcessed = false;
   profitTrackers[index].sl20PercentProcessed = false;
   profitTrackers[index].sl50PercentProcessed = false;
   profitTrackers[index].partialClosesComplete = false;
   profitTrackers[index].lastPartialPercent = 0;
   profitTrackers[index].partialCount = 0;
   
   bool dataFound = false;
   for(int attempt = 0; attempt < 10; attempt++)
   {
      if(PositionSelectByTicket(posTicket))
      {
         profitTrackers[index].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         profitTrackers[index].tpPrice = PositionGetDouble(POSITION_TP);
         profitTrackers[index].posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         profitTrackers[index].initialVolume = PositionGetDouble(POSITION_VOLUME);
         profitTrackers[index].currentVolume = profitTrackers[index].initialVolume;
         dataFound = true;
         break;
      }
      Sleep(10);
   }
   
   ArrayResize(profitTrackers[index].partialsProcessed, 0);
   ArrayResize(profitTrackers[index].partialLevelsProcessed, 0);
   
   if(!dataFound)
   {
      if(index == trackerCount - 1)
         trackerCount--;
      else
      {
         for(int i = index; i < trackerCount - 1; i++)
            profitTrackers[i] = profitTrackers[i + 1];
         trackerCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| Get Profit Tracker Index                                         |
//+------------------------------------------------------------------+
int GetProfitTrackerIndex(ulong posTicket)
{
   for(int i = 0; i < trackerCount; i++)
   {
      if(profitTrackers[i].posTicket == posTicket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Cleanup Profit Trackers                                          |
//+------------------------------------------------------------------+
void CleanupProfitTrackers()
{
   for(int i = trackerCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(profitTrackers[i].posTicket))
      {
         for(int j = i; j < trackerCount - 1; j++)
            profitTrackers[j] = profitTrackers[j + 1];
         trackerCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Percent to Target Profit                               |
//+------------------------------------------------------------------+
double CalculatePercentToTP(ulong posTicket, double &targetProfit)
{
   if(!PositionSelectByTicket(posTicket))
      return 0;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp = PositionGetDouble(POSITION_TP);
   double volume = PositionGetDouble(POSITION_VOLUME);
   
   if(tp <= 0 || volume <= 0)
      return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize <= 0 || tickValue <= 0)
      return 0;
   
   double distance = MathAbs(tp - entry);
   targetProfit = (distance / tickSize) * tickValue * volume;
   
   if(targetProfit <= 0)
      return 0;
   
   double percentToTP = (profit / targetProfit) * 100.0;
   return MathMax(0, MathMin(100, percentToTP));
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Breakeven                                      |
//+------------------------------------------------------------------+
bool MoveToBreakeven(ulong posTicket, double entryPrice, double tpPrice)
{
   if(!PositionSelectByTicket(posTicket))
      return false;
   
   double currentSL = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer = Breakeven_Buffer_Points * point;
   
   if(posType == POSITION_TYPE_BUY)
   {
      if(currentSL >= entryPrice + buffer)
         return false;
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      if(currentSL <= entryPrice - buffer)
         return false;
   }
   
   double newSL = entryPrice;
   double normalizedTP = NormalizeDouble(tpPrice, _Digits);
   
   if(posType == POSITION_TYPE_BUY)
      newSL += buffer;
   else if(posType == POSITION_TYPE_SELL)
      newSL -= buffer;
   
   newSL = NormalizeDouble(newSL, _Digits);
   
   if(posType == POSITION_TYPE_BUY)
   {
      if(newSL <= currentSL)
         return false;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(newSL >= currentPrice - point * 10)
         return false;
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      if(newSL >= currentSL)
         return false;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(newSL <= currentPrice + point * 10)
         return false;
   }
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionModify(posTicket, newSL, normalizedTP))
   {
      status_progress = "BREAKEVEN +" + DoubleToString(Breakeven_Buffer_Points, 0) + "pts @ " + DoubleToString(newSL, _Digits);
      LogMessage("✅ [40%] Breakeven + buffer at " + DoubleToString(newSL, _Digits));
      return true;
   }
   else
   {
      int error = GetLastError();
      LogMessage("Failed to move to breakeven. Error: " + IntegerToString(error), true);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Percentage of Target Profit                   |
//+------------------------------------------------------------------+
bool MoveSLToProfitPercent(ulong posTicket, double entryPrice, double tpPrice, double percentProfit)
{
   if(!PositionSelectByTicket(posTicket))
      return false;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currentSL = PositionGetDouble(POSITION_SL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double distance = MathAbs(tpPrice - entryPrice);
   double profitDistance = distance * (percentProfit / 100.0);
   double newSL = 0;
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = entryPrice + profitDistance;
      if(newSL <= currentSL + point)
         return false;
      if(newSL >= currentPrice - point * 10)
         return false;
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      newSL = entryPrice - profitDistance;
      if(newSL >= currentSL - point)
         return false;
      if(newSL <= currentPrice + point * 10)
         return false;
   }
   
   newSL = NormalizeDouble(newSL, _Digits);
   double normalizedTP = NormalizeDouble(tpPrice, _Digits);
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionModify(posTicket, newSL, normalizedTP))
   {
      string label = (percentProfit == 20.0) ? "[60%] 20% profit locked" : "[80%] 50% profit locked";
      status_progress = "SL LOCKED " + DoubleToString(percentProfit, 0) + "% @ " + DoubleToString(newSL, _Digits);
      LogMessage("✅ " + label + " at " + DoubleToString(newSL, _Digits));
      return true;
   }
   else
   {
      int error = GetLastError();
      LogMessage("Failed to move SL to " + DoubleToString(percentProfit, 0) + "% profit. Error: " + IntegerToString(error), true);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close Partial Position                                           |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong posTicket, double closePercent)
{
   if(!PositionSelectByTicket(posTicket))
      return false;
   
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = currentVolume * (closePercent / 100.0);
   
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
   closeVolume = MathMax(minLot, closeVolume);
   
   double remainingVolume = currentVolume - closeVolume;
   if(remainingVolume < Min_Volume_For_Partial)
      return false;
   
   if(closeVolume <= 0 || closeVolume > currentVolume)
      return false;
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionClosePartial(posTicket, closeVolume))
   {
      LogMessage("📊 PARTIAL CLOSE: " + DoubleToString(closePercent, 0) + 
                 "% of position (" + DoubleToString(closeVolume, 2) + " lots) at " + 
                 DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
      return true;
   }
   else
   {
      int error = GetLastError();
      LogMessage("Failed to close partial. Error: " + IntegerToString(error), true);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Process Partial Closes - Every 10%                              |
//+------------------------------------------------------------------+
bool ProcessPartialCloses(ulong posTicket, double currentPercentToTP)
{
   if(!Enable_Partial_Closes) return false;
   if(!PositionSelectByTicket(posTicket)) return false;
   
   int trackerIdx = GetProfitTrackerIndex(posTicket);
   if(trackerIdx < 0) return false;
   
   if(profitTrackers[trackerIdx].partialClosesComplete) return false;
   if(profitTrackers[trackerIdx].currentVolume <= Min_Volume_For_Partial * 1.5) return false;
   
   int currentInterval = (int)(currentPercentToTP / Partial_Close_Interval);
   if(currentInterval < 1) return false;
   
   bool alreadyProcessed = false;
   for(int i = 0; i < profitTrackers[trackerIdx].partialCount; i++)
   {
      if(profitTrackers[trackerIdx].partialLevelsProcessed[i] == currentInterval)
      {
         alreadyProcessed = true;
         break;
      }
   }
   
   if(alreadyProcessed) return false;
   
   double remainingVolume = profitTrackers[trackerIdx].currentVolume;
   double closePercent = 10.0;
   
   double closeVolume = remainingVolume * (closePercent / 100.0);
   double afterCloseVolume = remainingVolume - closeVolume;
   
   if(afterCloseVolume <= Min_Volume_For_Partial * 1.1)
   {
      closeVolume = remainingVolume - Min_Volume_For_Partial;
      if(closeVolume <= 0) return false;
      
      if(ClosePartialPosition(posTicket, (closeVolume / remainingVolume) * 100.0))
      {
         profitTrackers[trackerIdx].currentVolume = Min_Volume_For_Partial;
         profitTrackers[trackerIdx].partialClosesComplete = true;
         profitTrackers[trackerIdx].partialCount++;
         ArrayResize(profitTrackers[trackerIdx].partialLevelsProcessed, profitTrackers[trackerIdx].partialCount);
         profitTrackers[trackerIdx].partialLevelsProcessed[profitTrackers[trackerIdx].partialCount - 1] = currentInterval;
         
         LogMessage("📊 FINAL PARTIAL: Remaining " + DoubleToString(Min_Volume_For_Partial, 2) + 
                    " lots protected at " + DoubleToString(currentPercentToTP, 1) + "% of TP");
         return true;
      }
      return false;
   }
   
   if(ClosePartialPosition(posTicket, closePercent))
   {
      profitTrackers[trackerIdx].currentVolume = afterCloseVolume;
      profitTrackers[trackerIdx].partialCount++;
      ArrayResize(profitTrackers[trackerIdx].partialLevelsProcessed, profitTrackers[trackerIdx].partialCount);
      profitTrackers[trackerIdx].partialLevelsProcessed[profitTrackers[trackerIdx].partialCount - 1] = currentInterval;
      
      LogMessage("📊 PARTIAL CLOSE: " + DoubleToString(closePercent, 0) + 
                 "% closed at " + DoubleToString(currentPercentToTP, 1) + "% of TP");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage Profits - UPDATED                                       |
//+------------------------------------------------------------------+
void ManageProfits()
{
   if(!has_open_position || positionTicket == 0)
      return;
   
   int trackerIdx = GetProfitTrackerIndex(positionTicket);
   if(trackerIdx < 0)
   {
      CheckOpenPositions();
      if(has_open_position && positionTicket > 0)
      {
         InitializeProfitTracker(positionTicket);
         trackerIdx = GetProfitTrackerIndex(positionTicket);
      }
      if(trackerIdx < 0)
         return;
   }
   
   if(!PositionSelectByTicket(positionTicket))
      return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double tpPrice = PositionGetDouble(POSITION_TP);
   double slPrice = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   
   profitTrackers[trackerIdx].currentVolume = currentVolume;
   
   status_profit = "$" + DoubleToString(profit, 2);
   status_lot = DoubleToString(currentVolume, 2);
   
   if(tpPrice <= 0 || profit <= 0)
      return;
   
   double targetProfit = 0;
   double percentToTP = CalculatePercentToTP(positionTicket, targetProfit);
   
   if(percentToTP <= 0)
      return;
   
   if(percentToTP > profitTrackers[trackerIdx].highestPercentSeen)
      profitTrackers[trackerIdx].highestPercentSeen = percentToTP;
   
   double currentPercent = percentToTP;
   
   //--- 1. PARTIAL CLOSES (Every 10%)
   if(Enable_Partial_Closes && currentVolume > Min_Volume_For_Partial)
   {
      if(ProcessPartialCloses(positionTicket, currentPercent))
      {
         status_progress = "PARTIAL @" + DoubleToString(currentPercent, 0) + "%";
         return;
      }
   }
   
   //--- 2. BREAKEVEN at 40%
   if(!profitTrackers[trackerIdx].breakevenProcessed && currentPercent >= Breakeven_Threshold)
   {
      bool slBelowEntry = (posType == POSITION_TYPE_BUY && slPrice < entryPrice);
      bool slAboveEntry = (posType == POSITION_TYPE_SELL && slPrice > entryPrice);
      
      if(slBelowEntry || slAboveEntry)
      {
         if(MoveToBreakeven(positionTicket, entryPrice, tpPrice))
         {
            profitTrackers[trackerIdx].breakevenProcessed = true;
            LogMessage("📊 [40%] Breakeven + buffer locked at " + DoubleToString(currentPercent, 1) + "% of TP");
         }
      }
   }
   
   //--- 3. SL TO 20% PROFIT at 60%
   if(profitTrackers[trackerIdx].breakevenProcessed && 
      !profitTrackers[trackerIdx].sl20PercentProcessed && 
      currentPercent >= SL_20Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 20.0))
      {
         profitTrackers[trackerIdx].sl20PercentProcessed = true;
         LogMessage("📊 [60%] 20% profit locked at " + DoubleToString(currentPercent, 1) + "% of TP");
      }
   }
   
   //--- 4. SL TO 50% PROFIT at 80%
   if(profitTrackers[trackerIdx].sl20PercentProcessed && 
      !profitTrackers[trackerIdx].sl50PercentProcessed && 
      currentPercent >= SL_50Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 50.0))
      {
         profitTrackers[trackerIdx].sl50PercentProcessed = true;
         LogMessage("📊 [80%] 50% profit locked at " + DoubleToString(currentPercent, 1) + "% of TP");
      }
   }
}
//+------------------------------------------------------------------+