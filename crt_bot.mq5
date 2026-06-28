//+------------------------------------------------------------------+
//|                                          Range_Pullback_Executor.mq5 |
//|                                    Copyright 2024, Your Name      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>

//--- Input parameters
input int      MA_Fast_Period     = 89;          // Fast MA Period (Entry - H1)
input int      MA_Slow_Period     = 200;         // Slow MA Period (Trend Bias - H4)
input int      Range_Period       = 72;          // Range Detection Period (bars for swing)
input int      SL_Structure_Bars  = 20;          // Bars for SL Structure
input double   Pullback_Threshold = 0.382;       // Fibonacci Pullback Level
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H4; // Trend Timeframe
input ENUM_TIMEFRAMES Entry_Timeframe  = PERIOD_H1; // Entry Timeframe
input double   Fixed_Lot_Size     = 0.0;          // Fixed Lot Size (0 = use dynamic)
input int      Slippage           = 10;           // Slippage in points
input double   MinRR              = 1.0;          // Minimum Risk/Reward Ratio
input double   Target_RR          = 2.0;          // Target RR for TP-based SL
input int      Confidence_Threshold = 65;         // Minimum confidence to enter (0-100)
input color    MA89_Color         = clrMagenta;    // MA89 Color (H1)
input color    MA200_Color        = clrGold;       // MA200 Color (H4)

//--- Profit Management Inputs
input bool     Enable_Smart_Profit_Management = true;  // Enable Smart Profit Management
input double   Breakeven_Threshold = 50.0;              // % to TP to move SL to breakeven
input double   SL_20Percent_Threshold = 70.0;           // % to TP to move SL to 20% profit
input double   SL_50Percent_Threshold = 90.0;           // % to TP to move SL to 50% profit
input double   Partial_Close_Interval = 20.0;           // Partial close interval (%) - 20, 40, 60, 80
input double   Min_Volume_For_Partials = 0.02;          // Minimum volume for partial closes

//--- Enumeration for trend direction
enum ENUM_TREND_DIRECTION
{
   TREND_NONE,
   TREND_UP,
   TREND_DOWN
};

//--- Global variables
int handle_MA_Fast;      // H1 MA89
int handle_MA_Slow;      // H4 MA200
int handle_MA_H4;        // H4 MA50 (MTF)
int handle_ATR;
int handle_ADX;
double range_high, range_low, range_mid;
bool in_range = false;
bool pullback_detected = false;
ulong positionTicket = 0;
bool has_open_position = false;
ENUM_TREND_DIRECTION current_trade_direction = TREND_NONE;
ENUM_TREND_DIRECTION trend_bias = TREND_NONE;  // H4 MA200 trend bias
ENUM_TREND_DIRECTION trend_entry = TREND_NONE; // H1 MA89 entry direction

//--- Variables for range percentage display (updated on candle close)
double current_range_percentage = 0.0;
datetime last_candle_time = 0;  // Track last processed candle

//--- Status variables for chart display
string status_in_trade = "NO";
string status_reason = "WAITING FOR SIGNAL";
string status_pullback = "0.0%";
string status_trend = "NEUTRAL";
string status_confidence = "0/100";
string status_progress = "IDLE";
string status_profit = "$0.00";
string status_lot = "0.00";
string status_rr = "0.00";
string status_pullback_ending = "N/A";

//--- Profit Tracker Structure
struct ProfitTracker
{
    ulong posTicket;
    double highestPercentSeen;
    double totalClosedPercent;
    bool hasSecuredProfit;
    bool breakevenProcessed;
    bool sl20PercentProcessed;
    bool sl50PercentProcessed;
    bool milestoneProcessed[4]; // Track milestones: 20%, 40%, 60%, 80%
};

//--- Profit Tracking Arrays
ProfitTracker profitTrackers[];
int trackerCount = 0;

//--- Forward declarations
void ClosePosition();
void CheckOpenPositions();
void DrawStatusPanel();
void DetectRange(MqlRates &rates[]);
void DetectPullbackAndExecute(MqlRates &rates[], MqlRates &rates_h4[], double &ma_fast[], double &ma_slow[], double &ma_h4[],
                              double &atr[], double &adx_main[], double &adx_plus[], double &adx_minus[]);
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score, int adx_score,
                  string pullback_desc, string mtf_desc, string adx_desc, string price_pos_desc);
void InitializeProfitTracker(ulong posTicket);
void CleanupProfitTrackers();
void ManageProfits();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Create MA handles
   handle_MA_Fast = iMA(_Symbol, Entry_Timeframe, MA_Fast_Period, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_Slow = iMA(_Symbol, Trend_Timeframe, MA_Slow_Period, 0, MODE_SMA, PRICE_CLOSE);
   handle_MA_H4 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   handle_ATR = iATR(_Symbol, Entry_Timeframe, 14);
   handle_ADX = iADX(_Symbol, Entry_Timeframe, 14);
   
   if(handle_MA_Fast == INVALID_HANDLE || handle_MA_Slow == INVALID_HANDLE || 
      handle_MA_H4 == INVALID_HANDLE || handle_ATR == INVALID_HANDLE || 
      handle_ADX == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles!");
      return(INIT_FAILED);
   }
   
   //--- Initialize profit tracker array
   ArrayResize(profitTrackers, 100);
   trackerCount = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handle_MA_Fast != INVALID_HANDLE) IndicatorRelease(handle_MA_Fast);
   if(handle_MA_Slow != INVALID_HANDLE) IndicatorRelease(handle_MA_Slow);
   if(handle_MA_H4 != INVALID_HANDLE) IndicatorRelease(handle_MA_H4);
   if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
   if(handle_ADX != INVALID_HANDLE) IndicatorRelease(handle_ADX);
   ObjectsDeleteAll(0);
   Comment(""); // Clear chart comment on deinit
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime current_bar_time = iTime(_Symbol, Entry_Timeframe, 0);
   bool new_bar = (current_bar_time != last_candle_time);
   
   //--- Manage profits on every tick (if enabled and position exists)
   if(Enable_Smart_Profit_Management && has_open_position)
   {
      ManageProfits();
   }
   
   //--- If no new bar, return after profit management
   if(!new_bar) return;
   
   //--- Update last candle time
   last_candle_time = current_bar_time;
   
   //--- Check if we already have a position
   CheckOpenPositions();
   
   //--- Update status
   UpdateStatus();
   
   //--- Get data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, Entry_Timeframe, 0, Range_Period + 50, rates) < Range_Period) return;
   
   //--- Get H4 data for MTF
   MqlRates rates_h4[];
   ArraySetAsSeries(rates_h4, true);
   if(CopyRates(_Symbol, Trend_Timeframe, 0, 10, rates_h4) < 5) return;
   
   //--- Get indicator data
   double ma_fast[], ma_slow[], ma_h4[], atr[];
   double adx_main[], adx_plus[], adx_minus[];
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(ma_h4, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx_main, true);
   ArraySetAsSeries(adx_plus, true);
   ArraySetAsSeries(adx_minus, true);
   
   if(CopyBuffer(handle_MA_Fast, 0, 0, 10, ma_fast) < 10) return;
   if(CopyBuffer(handle_MA_Slow, 0, 0, 10, ma_slow) < 10) return;
   if(CopyBuffer(handle_MA_H4, 0, 0, 10, ma_h4) < 5) return;
   if(CopyBuffer(handle_ATR, 0, 0, 10, atr) < 10) return;
   if(CopyBuffer(handle_ADX, 0, 0, 5, adx_main) < 5) return;
   if(CopyBuffer(handle_ADX, 1, 0, 5, adx_plus) < 5) return;
   if(CopyBuffer(handle_ADX, 2, 0, 5, adx_minus) < 5) return;
   
   //--- Draw MAs on chart
   DrawMAs();
   
   //--- Detect range (internal only, no drawing)
   DetectRange(rates);
   
   //--- Detect trend bias for display
   double current_price = rates[0].close;
   double current_ma200 = ma_slow[0];
   
   if(current_price > current_ma200)
      trend_bias = TREND_UP;
   else if(current_price < current_ma200)
      trend_bias = TREND_DOWN;
   else
      trend_bias = TREND_NONE;
   
   //--- Update status trend
   if(trend_bias == TREND_UP)
      status_trend = "BULLISH ▲";
   else if(trend_bias == TREND_DOWN)
      status_trend = "BEARISH ▼";
   else
      status_trend = "NEUTRAL";
   
   //--- Calculate pullback percentage
   double pullback_percent = 0;
   if(range_high > range_low)
   {
      double swing_high = range_high;
      double swing_low = range_low;
      
      if(trend_bias == TREND_UP)
         pullback_percent = (swing_high - current_price) / (swing_high - swing_low) * 100;
      else if(trend_bias == TREND_DOWN)
         pullback_percent = (current_price - swing_low) / (swing_high - swing_low) * 100;
   }
   
   status_pullback = DoubleToString(pullback_percent, 1) + "%";
   
   //--- Detect pullback and execute (ONLY on new bars)
   DetectPullbackAndExecute(rates, rates_h4, ma_fast, ma_slow, ma_h4, atr, 
                            adx_main, adx_plus, adx_minus);
   
   //--- Update chart display using Comment()
   DrawStatusPanel();
}

//+------------------------------------------------------------------+
//| Draw MAs on Chart                                                |
//+------------------------------------------------------------------+
void DrawMAs()
{
   //--- Get MA89 values (H1 Entry Timeframe)
   double ma_fast[];
   ArraySetAsSeries(ma_fast, true);
   if(CopyBuffer(handle_MA_Fast, 0, 0, 100, ma_fast) < 100) return;
   
   //--- Get MA200 values (H4 Trend Timeframe)
   double ma_slow[];
   ArraySetAsSeries(ma_slow, true);
   if(CopyBuffer(handle_MA_Slow, 0, 0, 100, ma_slow) < 100) return;
   
   //--- Get bar times for Entry Timeframe (for MA89)
   datetime times_entry[];
   ArraySetAsSeries(times_entry, true);
   if(CopyTime(_Symbol, Entry_Timeframe, 0, 100, times_entry) < 100) return;
   
   //--- Get bar times for Trend Timeframe (for MA200)
   datetime times_trend[];
   ArraySetAsSeries(times_trend, true);
   if(CopyTime(_Symbol, Trend_Timeframe, 0, 100, times_trend) < 100) return;
   
   //--- Delete old MA objects
   ObjectsDeleteAll(0, "MA89_");
   ObjectsDeleteAll(0, "MA200_");
   
   //--- Draw MA89 (H1 - Entry Timeframe)
   for(int i = 0; i < 99; i++)
   {
      string name = "MA89_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_TREND, 0, times_entry[i], ma_fast[i], times_entry[i+1], ma_fast[i+1]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, MA89_Color);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
   
   //--- Draw MA200 (H4 - Trend Timeframe)
   for(int i = 0; i < 99; i++)
   {
      string name = "MA200_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_TREND, 0, times_trend[i], ma_slow[i], times_trend[i+1], ma_slow[i+1]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, MA200_Color);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
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
      
      //--- Clean up tracker
      CleanupProfitTrackers();
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
         
         //--- Calculate RR
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
//| Draw Status Panel - Using Comment() for simplicity               |
//+------------------------------------------------------------------+
void DrawStatusPanel()
{
   string text = "";
   text += "╔══════════════════════════════════╗\n";
   text += "║           CRT_BOT                ║\n";
   text += "╠══════════════════════════════════╣\n";
   text += "║ TREND:     " + PadRight(status_trend, 20) + "║\n";
   text += "║ IN TRADE:  " + PadRight(status_in_trade, 20) + "║\n";
   text += "║ PULLBACK:  " + PadRight(status_pullback, 20) + "║\n";
   text += "║ ENDING:    " + PadRight(status_pullback_ending, 20) + "║\n";
   text += "║ CONFIDENCE:" + PadRight(status_confidence, 20) + "║\n";
   text += "║ STATUS:    " + PadRight(status_reason, 20) + "║\n";
   text += "║ PROGRESS:  " + PadRight(status_progress, 20) + "║\n";
   
   if(has_open_position)
   {
      text += "╠══════════════════════════════════╣\n";
      text += "║ LOT:       " + PadRight(status_lot, 20) + "║\n";
      text += "║ R:R:       " + PadRight(status_rr, 20) + "║\n";
      text += "║ P/L:       " + PadRight(status_profit, 20) + "║\n";
   }
   
   text += "╚══════════════════════════════════╝";
   
   Comment(text);
}

//+------------------------------------------------------------------+
//| Helper function to pad string to fixed width                     |
//+------------------------------------------------------------------+
string PadRight(string text, int width)
{
   if(StringLen(text) >= width)
      return text;
   
   string result = text;
   for(int i = StringLen(text); i < width; i++)
      result += " ";
   return result;
}

//+------------------------------------------------------------------+
//| Detect Range Function (Internal Only - No Drawing)               |
//+------------------------------------------------------------------+
void DetectRange(MqlRates &rates[])
{
   //--- Calculate swing high and low from Range_Period bars
   double high = rates[0].high;
   double low = rates[0].low;
   
   for(int i = 1; i < Range_Period; i++)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   
   range_high = high;
   range_low = low;
   range_mid = (high + low) / 2;
}

//+------------------------------------------------------------------+
//| Get Pullback Level Description                                   |
//+------------------------------------------------------------------+
string GetPullbackDescription(double pullback_percent)
{
   if(pullback_percent >= 38.2 && pullback_percent <= 50.0)
      return "GOLDEN ZONE (38.2-50%) - Ideal retracement for trend continuation";
   else if(pullback_percent > 50.0 && pullback_percent <= 61.8)
      return "GOOD ZONE (50-61.8%) - Healthy pullback, strong trend";
   else if(pullback_percent > 61.8 && pullback_percent <= 78.6)
      return "DEEP ZONE (61.8-78.6%) - Deeper pullback, still acceptable";
   else if(pullback_percent > 78.6 && pullback_percent <= 95.0)
      return "RISKY ZONE (78.6-95%) - Very deep, possible trend reversal";
   else if(pullback_percent < 38.2)
      return "SHALLOW (<38.2%) - Not deep enough, waiting for more pullback";
   else if(pullback_percent > 95.0)
      return "TOO DEEP (>95%) - Almost at swing low, trend may be reversing";
   else
      return "UNKNOWN - Invalid pullback level";
}

//+------------------------------------------------------------------+
//| Get MTF (H4) Description                                         |
//+------------------------------------------------------------------+
string GetMTFDescription(MqlRates &rates_h4[], ENUM_TREND_DIRECTION trend)
{
   string result = "";
   
   bool h4_bullish = (rates_h4[0].close > rates_h4[0].open);
   bool h4_bearish = (rates_h4[0].close < rates_h4[0].open);
   bool h4_doji = (MathAbs(rates_h4[0].close - rates_h4[0].open) < (rates_h4[0].high - rates_h4[0].low) * 0.1);
   
   double current_body = MathAbs(rates_h4[0].close - rates_h4[0].open);
   double prev_body = MathAbs(rates_h4[1].close - rates_h4[1].open);
   
   double h4_ma50 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   double h4_close = rates_h4[0].close;
   
   if(trend == TREND_UP)
   {
      if(h4_bullish && current_body > prev_body * 1.5)
         result = "STRONG BULLISH H4 CANDLE - Confirms pullback ending ✅";
      else if(h4_bullish)
         result = "BULLISH H4 CANDLE - Pullback likely ending ✅";
      else if(h4_doji)
         result = "H4 DOJI - Indecision, waiting for confirmation ⏳";
      else if(h4_bearish)
         result = "BEARISH H4 CANDLE - Pullback may continue ❌";
      
      if(h4_close > h4_ma50)
         result += " | Price above H4 MA50 (Strong)";
      else
         result += " | Price below H4 MA50 (Weak)";
   }
   else if(trend == TREND_DOWN)
   {
      if(h4_bearish && current_body > prev_body * 1.5)
         result = "STRONG BEARISH H4 CANDLE - Confirms pullback ending ✅";
      else if(h4_bearish)
         result = "BEARISH H4 CANDLE - Pullback likely ending ✅";
      else if(h4_doji)
         result = "H4 DOJI - Indecision, waiting for confirmation ⏳";
      else if(h4_bullish)
         result = "BULLISH H4 CANDLE - Pullback may continue ❌";
      
      if(h4_close < h4_ma50)
         result += " | Price below H4 MA50 (Strong)";
      else
         result += " | Price above H4 MA50 (Weak)";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get ADX Description                                              |
//+------------------------------------------------------------------+
string GetADXDescription(double adx_main, double adx_plus, double adx_minus, ENUM_TREND_DIRECTION trend)
{
   string result = "";
   
   if(adx_main >= 50)
      result = "LEVEL 5: EXTREME TREND (ADX ≥ 50) - Maximum confidence";
   else if(adx_main >= 40)
      result = "LEVEL 4: STRONG TREND (ADX 40-50) - High confidence";
   else if(adx_main >= 30)
      result = "LEVEL 3: GOOD TREND (ADX 30-40) - Good confidence";
   else if(adx_main >= 25)
      result = "LEVEL 2: MODERATE TREND (ADX 25-30) - Moderate confidence";
   else if(adx_main >= 20)
      result = "LEVEL 1: WEAK TREND (ADX 20-25) - Low confidence";
   else
      result = "LEVEL 0: NO TREND (ADX < 20) - No confidence";
   
   if(trend == TREND_UP)
   {
      if(adx_plus > adx_minus)
         result += " | +DI > -DI (BULLISH ✅)";
      else
         result += " | +DI < -DI (BEARISH - CAUTION ⚠️)";
   }
   else if(trend == TREND_DOWN)
   {
      if(adx_minus > adx_plus)
         result += " | -DI > +DI (BEARISH ✅)";
      else
         result += " | -DI < +DI (BULLISH - CAUTION ⚠️)";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get ADX Level Label                                              |
//+------------------------------------------------------------------+
string GetADXLevelLabel(double adx_main)
{
   if(adx_main >= 50)
      return "LEVEL 5: EXTREME TREND";
   else if(adx_main >= 40)
      return "LEVEL 4: STRONG TREND";
   else if(adx_main >= 30)
      return "LEVEL 3: GOOD TREND";
   else if(adx_main >= 25)
      return "LEVEL 2: MODERATE TREND";
   else if(adx_main >= 20)
      return "LEVEL 1: WEAK TREND";
   else
      return "LEVEL 0: NO TREND";
}

//+------------------------------------------------------------------+
//| Calculate Pullback Score                                         |
//+------------------------------------------------------------------+
int CalculatePullbackScore(double pullback_percent)
{
   if(pullback_percent < 38.2 || pullback_percent > 95.0)
      return 0;
   
   if(pullback_percent >= 38.2 && pullback_percent <= 50.0)
      return 50;
   else if(pullback_percent > 50.0 && pullback_percent <= 61.8)
      return 45;
   else if(pullback_percent > 61.8 && pullback_percent <= 78.6)
      return 30;
   else if(pullback_percent > 78.6 && pullback_percent <= 95.0)
      return 20;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate MTF Score                                              |
//+------------------------------------------------------------------+
int CalculateMTFScore(MqlRates &rates_h4[], ENUM_TREND_DIRECTION trend)
{
   int score = 0;
   
   bool h4_bullish = (rates_h4[0].close > rates_h4[0].open);
   bool h4_bearish = (rates_h4[0].close < rates_h4[0].open);
   
   double current_body = MathAbs(rates_h4[0].close - rates_h4[0].open);
   double prev_body = MathAbs(rates_h4[1].close - rates_h4[1].open);
   
   double h4_ma50 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   double h4_close = rates_h4[0].close;
   
   if(trend == TREND_UP)
   {
      if(h4_bullish && current_body > prev_body * 1.5)
         score += 25;
      else if(h4_bullish)
         score += 20;
      else
         score += 0;
      
      if(h4_close > h4_ma50)
         score += 5;
   }
   else if(trend == TREND_DOWN)
   {
      if(h4_bearish && current_body > prev_body * 1.5)
         score += 25;
      else if(h4_bearish)
         score += 20;
      else
         score += 0;
      
      if(h4_close < h4_ma50)
         score += 5;
   }
   
   return MathMin(30, score);
}

//+------------------------------------------------------------------+
//| Calculate ADX Score                                              |
//+------------------------------------------------------------------+
int CalculateADXScore(double adx_main, double adx_plus, double adx_minus, ENUM_TREND_DIRECTION trend)
{
   int score = 0;
   int level = 0;
   
   if(adx_main >= 50)
   {
      score = 20;
      level = 5;
   }
   else if(adx_main >= 40)
   {
      score = 16;
      level = 4;
   }
   else if(adx_main >= 30)
   {
      score = 12;
      level = 3;
   }
   else if(adx_main >= 25)
   {
      score = 8;
      level = 2;
   }
   else if(adx_main >= 20)
   {
      score = 4;
      level = 1;
   }
   else
   {
      score = 0;
      level = 0;
   }
   
   bool aligned = false;
   if(trend == TREND_UP && adx_plus > adx_minus)
      aligned = true;
   else if(trend == TREND_DOWN && adx_minus > adx_plus)
      aligned = true;
   
   if(aligned)
   {
      if(level >= 4)
         score += 5;
      else if(level >= 3)
         score += 4;
      else if(level >= 2)
         score += 3;
      else if(level >= 1)
         score += 2;
   }
   
   return MathMin(25, score);
}

//+------------------------------------------------------------------+
//| Calculate Optimal Stop Loss                                      |
//+------------------------------------------------------------------+
double CalculateOptimalSL(ENUM_TREND_DIRECTION trend, double entry_price, double tp_price,
                          double current_ma89, double atr_value, double target_rr,
                          MqlRates &rates[])
{
   double sl_price = 0;
   
   double reward = MathAbs(tp_price - entry_price);
   double tp_based_risk = reward / target_rr;
   double tp_based_sl = 0;
   
   if(trend == TREND_UP)
      tp_based_sl = entry_price - tp_based_risk;
   else if(trend == TREND_DOWN)
      tp_based_sl = entry_price + tp_based_risk;
   
   double structure_sl = 0;
   
   if(trend == TREND_UP)
   {
      double sl_ma89 = current_ma89 - (atr_value * 0.5);
      
      double recent_low = rates[0].low;
      for(int i = 1; i < SL_Structure_Bars; i++)
      {
         if(rates[i].low < recent_low)
            recent_low = rates[i].low;
      }
      double sl_structure = recent_low - (atr_value * 0.4);
      
      structure_sl = MathMax(sl_ma89, sl_structure) - (atr_value * 0.15);
      sl_price = MathMax(structure_sl, tp_based_sl);
   }
   else if(trend == TREND_DOWN)
   {
      double sl_ma89 = current_ma89 + (atr_value * 0.5);
      
      double recent_high = rates[0].high;
      for(int i = 1; i < SL_Structure_Bars; i++)
      {
         if(rates[i].high > recent_high)
            recent_high = rates[i].high;
      }
      double sl_structure = recent_high + (atr_value * 0.4);
      
      structure_sl = sl_structure + (atr_value * 0.15);
      sl_price = MathMin(structure_sl, tp_based_sl);
   }
   
   return sl_price;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size                                       |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(Fixed_Lot_Size > 0)
      return Fixed_Lot_Size;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = 0.01;
   
   if(balance <= 100)
      lot = 0.02;
   else if(balance <= 500)
      lot = 0.05;
   else if(balance <= 1000)
      lot = 0.10;
   else if(balance <= 2000)
      lot = 0.20;
   else if(balance <= 5000)
      lot = 0.50;
   else if(balance <= 10000)
      lot = 1.00;
   else if(balance <= 25000)
      lot = 2.00;
   else
      lot = 3.00;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(min_lot, MathMin(max_lot, lot));
   
   if(lot_step > 0)
      lot = MathRound(lot / lot_step) * lot_step;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score, int adx_score,
                  string pullback_desc, string mtf_desc, string adx_desc, string price_pos_desc)
{
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
   
   double risk = MathAbs(entry_price - sl_price);
   double reward = MathAbs(tp_price - entry_price);
   double rr_ratio = reward / risk;
   
   if(rr_ratio < MinRR)
   {
      status_reason = "RR TOO LOW (" + DoubleToString(rr_ratio, 2) + ")";
      status_progress = "REJECTED: RR";
      return;
   }
   
   double lot_size = CalculateLotSize();
   
   if(lot_size <= 0)
   {
      status_reason = "INVALID LOT SIZE";
      status_progress = "REJECTED: LOT";
      return;
   }
   
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   double price = 0, sl = 0, tp = 0;
   string type_str = "";
   bool success = false;
   
   if(trend == TREND_UP)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = sl_price;
      tp = tp_price;
      type_str = "BUY";
      success = trade.Buy(lot_size, _Symbol, price, sl, tp, "Range_Pullback_Buy");
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = sl_price;
      tp = tp_price;
      type_str = "SELL";
      success = trade.Sell(lot_size, _Symbol, price, sl, tp, "Range_Pullback_Sell");
   }
   
   if(success)
   {
      positionTicket = trade.ResultOrder();
      has_open_position = true;
      current_trade_direction = trend;
      
      //--- Initialize profit tracker for this position
      InitializeProfitTracker(positionTicket);
      
      ObjectsDeleteAll(0, "Pullback_");
      
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      string confidence_label = "";
      if(total_confidence >= 90)
         confidence_label = "VERY HIGH";
      else if(total_confidence >= 80)
         confidence_label = "HIGH";
      else if(total_confidence >= 70)
         confidence_label = "GOOD";
      else if(total_confidence >= 60)
         confidence_label = "MODERATE";
      else if(total_confidence >= 55)
         confidence_label = "LOW";
      else
         confidence_label = "VERY LOW";
      
      status_in_trade = "YES";
      status_reason = type_str + " OPENED";
      status_progress = type_str + " @ " + DoubleToString(price, _Digits);
      status_confidence = IntegerToString(total_confidence) + "/100 (" + confidence_label + ")";
      status_lot = DoubleToString(lot_size, 2);
      status_rr = DoubleToString(rr_ratio, 2) + ":1";
      
      Print("=== 🟢 TRADE ENTERED ===");
      Print("Type: ", type_str);
      Print("Ticket: ", positionTicket);
      Print("Entry: ", DoubleToString(price, _Digits));
      Print("SL: ", DoubleToString(sl, _Digits));
      Print("TP: ", DoubleToString(tp, _Digits));
      Print("Risk: ", DoubleToString(risk / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0), " points");
      Print("Reward: ", DoubleToString(reward / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0), " points");
      Print("RR: ", DoubleToString(rr_ratio, 2), ":1");
      Print("Lot Size: ", DoubleToString(lot_size, 2));
      Print("Balance: $", DoubleToString(balance, 2));
      
      Print("--- 🎯 Entry Reasons ---");
      Print("Trend: ", (trend_bias == TREND_UP) ? "BULLISH (Price > H4 MA200)" : "BEARISH (Price < H4 MA200)");
      Print("Entry Signal: Price ", (trend_entry == TREND_UP) ? "ABOVE" : "BELOW", " H1 MA89");
      Print("Pullback: ", DoubleToString(((trend == TREND_UP) ? 
         (range_high - price) / (range_high - range_low) * 100 : 
         (price - range_low) / (range_high - range_low) * 100), 1), "%");
      Print("Range: ", DoubleToString(range_low, _Digits), " - ", DoubleToString(range_high, _Digits));
      Print("Price Position: ", price_pos_desc);
      
      Print("--- 📊 Confidence Score: ", total_confidence, "/100 (", confidence_label, ") ---");
      Print("📈 Pullback Score: ", pullback_score, "/50 - ", pullback_desc);
      Print("⏰ MTF (H4) Score: ", mtf_score, "/30 - ", mtf_desc);
      Print("📉 ADX Score: ", adx_score, "/25 - ", adx_desc);
      Print("SL Placement: MAX(Structure, TP-based) with target RR: ", DoubleToString(Target_RR, 1), ":1");
      
      Print("--- 📊 Profit Management Active ---");
      Print("Breakeven at: ", Breakeven_Threshold, "% of TP");
      Print("SL to 20% profit at: ", SL_20Percent_Threshold, "% of TP");
      Print("SL to 50% profit at: ", SL_50Percent_Threshold, "% of TP");
      Print("Partial closes at: ", Partial_Close_Interval, "% intervals");
   }
   else
   {
      int error = GetLastError();
      status_reason = "TRADE FAILED (Error " + IntegerToString(error) + ")";
      status_progress = "FAILED";
      Print("=== TRADE FAILED ===");
      Print("Error: ", error);
   }
}

//+------------------------------------------------------------------+
//| Detect Pullback And Execute                                      |
//+------------------------------------------------------------------+
void DetectPullbackAndExecute(MqlRates &rates[], MqlRates &rates_h4[], double &ma_fast[], double &ma_slow[], double &ma_h4[],
                              double &atr[], double &adx_main[], double &adx_plus[], double &adx_minus[])
{
   double current_price = rates[0].close;
   double current_ma89 = ma_fast[0];
   double current_ma200 = ma_slow[0];
   double current_atr = atr[0];
   double current_adx = adx_main[0];
   double current_adx_plus = adx_plus[0];
   double current_adx_minus = adx_minus[0];
   
   //--- Determine TREND BIAS using H4 MA200
   if(current_price > current_ma200)
      trend_bias = TREND_UP;
   else if(current_price < current_ma200)
      trend_bias = TREND_DOWN;
   else
      trend_bias = TREND_NONE;
   
   //--- Determine ENTRY DIRECTION using H1 MA89
   if(current_price > current_ma89)
      trend_entry = TREND_UP;
   else if(current_price < current_ma89)
      trend_entry = TREND_DOWN;
   else
      trend_entry = TREND_NONE;
   
   //--- Final trade direction (BOTH must align)
   ENUM_TREND_DIRECTION final_trend = TREND_NONE;
   if(trend_bias == TREND_UP && trend_entry == TREND_UP)
      final_trend = TREND_UP;
   else if(trend_bias == TREND_DOWN && trend_entry == TREND_DOWN)
      final_trend = TREND_DOWN;
   else
      final_trend = TREND_NONE;
   
   //--- Update trend in status
   if(trend_bias == TREND_UP)
      status_trend = "BULLISH ▲";
   else if(trend_bias == TREND_DOWN)
      status_trend = "BEARISH ▼";
   else
      status_trend = "NEUTRAL";
   
   if(final_trend == TREND_NONE)
   {
      if(!has_open_position)
      {
         if(trend_bias != TREND_NONE && trend_entry == TREND_NONE)
         {
            status_reason = "PRICE AT MA89";
            status_pullback_ending = "N/A";
         }
         else if(trend_bias == TREND_NONE && trend_entry != TREND_NONE)
         {
            status_reason = "NO H4 TREND";
            status_pullback_ending = "N/A";
         }
         else
         {
            status_reason = "TREND MISALIGNMENT";
            status_pullback_ending = "N/A";
         }
      }
      return;
   }
   
   //--- Calculate swing high/low for pullback
   double swing_high = rates[0].high;
   double swing_low = rates[0].low;
   for(int i = 1; i < Range_Period; i++)
   {
      if(rates[i].high > swing_high) swing_high = rates[i].high;
      if(rates[i].low < swing_low) swing_low = rates[i].low;
   }
   
   if(swing_high <= swing_low) return;
   
   //--- Calculate pullback
   double pullback_percent = 0;
   double entry_price = 0;
   double tp_price = 0;
   double sl_price = 0;
   bool is_pullback = false;
   int pullback_score = 0;
   int mtf_score = 0;
   int adx_score = 0;
   int total_confidence = 0;
   
   if(final_trend == TREND_UP && current_price < swing_high)
   {
      pullback_percent = (swing_high - current_price) / (swing_high - swing_low);
      if(pullback_percent >= Pullback_Threshold && pullback_percent <= 0.95)
      {
         is_pullback = true;
         entry_price = current_price;
         tp_price = swing_high;
      }
   }
   else if(final_trend == TREND_DOWN && current_price > swing_low)
   {
      pullback_percent = (current_price - swing_low) / (swing_high - swing_low);
      if(pullback_percent >= Pullback_Threshold && pullback_percent <= 0.95)
      {
         is_pullback = true;
         entry_price = current_price;
         tp_price = swing_low;
      }
   }
   
   //--- Update pullback status
   double pb_pct = pullback_percent * 100;
   status_pullback = DoubleToString(pb_pct, 1) + "%";
   
   //--- Calculate confidence scores
   if(is_pullback && !has_open_position)
   {
      pullback_score = CalculatePullbackScore(pb_pct);
      mtf_score = CalculateMTFScore(rates_h4, final_trend);
      adx_score = CalculateADXScore(current_adx, current_adx_plus, current_adx_minus, final_trend);
      
      total_confidence = pullback_score + mtf_score + adx_score;
      
      bool pullback_ending = false;
      bool mtf_confirmed = (mtf_score >= 15);
      bool adx_confirmed = (adx_score >= 12);
      
      if(mtf_confirmed || adx_confirmed)
         pullback_ending = true;
      
      //--- Update pullback ending status
      status_pullback_ending = pullback_ending ? "YES" : "NO";
      
      string pullback_desc = GetPullbackDescription(pb_pct);
      string mtf_desc = GetMTFDescription(rates_h4, final_trend);
      string adx_desc = GetADXDescription(current_adx, current_adx_plus, current_adx_minus, final_trend);
      string adx_level = GetADXLevelLabel(current_adx);
      
      double diff_89 = (current_price - current_ma89) / current_ma89 * 100;
      double diff_200 = (current_price - current_ma200) / current_ma200 * 100;
      string price_pos_desc = StringFormat("Price is %.2f%% %s H1 MA89 and %.2f%% %s H4 MA200",
         MathAbs(diff_89), (diff_89 > 0) ? "ABOVE" : "BELOW",
         MathAbs(diff_200), (diff_200 > 0) ? "ABOVE" : "BELOW");
      
      DrawPullbackMarker(current_price, final_trend, pullback_percent, total_confidence);
      
      //--- Update status
      status_confidence = IntegerToString(total_confidence) + "/100";
      
      if(total_confidence >= Confidence_Threshold && pullback_ending)
      {
         status_reason = "CONFIDENCE MET ✅ - ENTERING";
         status_progress = "ENTERING " + (final_trend == TREND_UP ? "BUY" : "SELL");
         
         Print("✅ CONFIDENCE MET + PULLBACK ENDING - ENTERING TRADE");
         
         sl_price = CalculateOptimalSL(final_trend, entry_price, tp_price, current_ma89, current_atr, Target_RR, rates);
         
         ExecuteTrade(final_trend, entry_price, sl_price, tp_price, total_confidence, 
                      pullback_score, mtf_score, adx_score,
                      pullback_desc, mtf_desc, adx_desc, price_pos_desc);
      }
      else
      {
         if(total_confidence < Confidence_Threshold)
         {
            status_reason = "LOW CONFIDENCE (" + IntegerToString(total_confidence) + "/" + IntegerToString(Confidence_Threshold) + ")";
            status_progress = "WAITING: CONFIDENCE";
         }
         else if(!pullback_ending)
         {
            if(!mtf_confirmed && !adx_confirmed)
               status_reason = "PULLBACK NOT ENDING (MTF/ADX)";
            else if(!mtf_confirmed)
               status_reason = "WAITING FOR MTF CONFIRMATION";
            else
               status_reason = "WAITING FOR ADX CONFIRMATION";
            status_progress = "WAITING: ENDING";
         }
         
         Print("=== 📊 PULLBACK DETECTED ===");
         Print("Pullback: ", DoubleToString(pb_pct, 1), "%");
         Print("Pullback Score: ", pullback_score, "/50");
         Print("MTF (H4) Score: ", mtf_score, "/30");
         Print("ADX Score: ", adx_score, "/25 (", adx_level, ")");
         Print("Total Confidence: ", total_confidence, "/100 (", 
               DoubleToString((double)total_confidence, 1), "%)");
         Print("Pullback Ending: ", pullback_ending ? "YES ✅" : "NO ⏳");
         Print("Price Position: ", price_pos_desc);
         Print("=== ⏳ TRADE OPPORTUNITY MISSED ===");
         
         if(total_confidence < Confidence_Threshold)
         {
            Print("Reason: Confidence Below Threshold");
            Print("Current: ", total_confidence, "/100 | Required: ", Confidence_Threshold, "/100");
         }
         
         if(!pullback_ending)
         {
            Print("Reason: Pullback Not Yet Ending");
            Print("MTF (H4): ", mtf_desc);
            Print("ADX: ", adx_desc);
         }
      }
   }
   else if(!is_pullback && !has_open_position)
   {
      double raw_percent = 0;
      if(final_trend == TREND_UP)
         raw_percent = (swing_high - current_price) / (swing_high - swing_low) * 100;
      else if(final_trend == TREND_DOWN)
         raw_percent = (current_price - swing_low) / (swing_high - swing_low) * 100;
      
      if(raw_percent < Pullback_Threshold * 100)
      {
         status_reason = "PULLBACK TOO SHALLOW (" + DoubleToString(raw_percent, 1) + "%)";
         status_progress = "WAITING: PULLBACK";
         status_pullback_ending = "N/A";
      }
      else if(raw_percent > 95.0)
      {
         status_reason = "PULLBACK TOO DEEP (" + DoubleToString(raw_percent, 1) + "%)";
         status_progress = "WAITING: RETEST";
         status_pullback_ending = "N/A";
      }
      else
      {
         status_reason = "WAITING FOR SIGNAL";
         status_progress = "IDLE";
         status_pullback_ending = "N/A";
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Pullback Marker                                             |
//+------------------------------------------------------------------+
void DrawPullbackMarker(double current_price, ENUM_TREND_DIRECTION trend, double pullback_percent,
                        int total_confidence)
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
   
   string label_text = DoubleToString(pullback_percent * 100, 1) + "% | C: " + 
                       IntegerToString(total_confidence) + "/100";
   
   if(total_confidence >= Confidence_Threshold)
      label_text += " ✅";
   else if(total_confidence >= 55)
      label_text += " 🟠";
   else
      label_text += " 🔴";
   
   ObjectCreate(0, prefix + "Label", OBJ_TEXT, 0, now + PeriodSeconds(Entry_Timeframe)*2, current_price);
   ObjectSetString(0, prefix + "Label", OBJPROP_TEXT, label_text);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_COLOR, signal_color);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_BACK, true);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, prefix + "Label", OBJPROP_BORDER_COLOR, signal_color);
   ObjectSetString(0, prefix + "Label", OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| ==================== PROFIT MANAGEMENT FUNCTIONS ================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Profit Tracker                                        |
//+------------------------------------------------------------------+
void InitializeProfitTracker(ulong posTicket)
{
   //--- Check if tracker already exists
   int index = -1;
   for(int i = 0; i < trackerCount; i++)
   {
      if(profitTrackers[i].posTicket == posTicket)
      {
         index = i;
         break;
      }
   }
   
   //--- If not found, create new tracker
   if(index == -1)
   {
      if(trackerCount >= ArraySize(profitTrackers))
         ArrayResize(profitTrackers, trackerCount + 50);
      
      index = trackerCount;
      trackerCount++;
   }
   
   //--- Initialize tracker
   profitTrackers[index].posTicket = posTicket;
   profitTrackers[index].highestPercentSeen = 0;
   profitTrackers[index].totalClosedPercent = 0;
   profitTrackers[index].hasSecuredProfit = false;
   profitTrackers[index].breakevenProcessed = false;
   profitTrackers[index].sl20PercentProcessed = false;
   profitTrackers[index].sl50PercentProcessed = false;
   
   //--- Initialize milestone array (20%, 40%, 60%, 80%)
   for(int i = 0; i < 4; i++)
      profitTrackers[index].milestoneProcessed[i] = false;
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
         //--- Shift array to remove closed position
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
   
   double distance = MathAbs(tp - entry);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize <= 0 || tickValue <= 0)
      return 0;
   
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
   
   //--- Check if already at breakeven
   if(MathAbs(currentSL - entryPrice) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
      return false;
   
   double newSL = entryPrice;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(posType == POSITION_TYPE_BUY)
      newSL += point * 5;
   else if(posType == POSITION_TYPE_SELL)
      newSL -= point * 5;
   
   newSL = NormalizeDouble(newSL, _Digits);
   double normalizedTP = NormalizeDouble(tpPrice, _Digits);
   
   //--- Use CTrade for reliable modification
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionModify(posTicket, newSL, normalizedTP))
   {
      status_progress = "BREAKEVEN @ " + DoubleToString(newSL, _Digits);
      Print("✅ Breakeven reached! SL moved to entry: ", DoubleToString(newSL, _Digits));
      return true;
   }
   else
   {
      int error = GetLastError();
      Print("❌ Failed to move to breakeven. Error: ", error);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Percentage of Target Profit                    |
//+------------------------------------------------------------------+
bool MoveSLToProfitPercent(ulong posTicket, double entryPrice, double tpPrice, double percentProfit)
{
   if(!PositionSelectByTicket(posTicket))
      return false;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double distance = MathAbs(tpPrice - entryPrice);
   double profitDistance = distance * (percentProfit / 100.0);
   double newSL = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = entryPrice + profitDistance;
      //--- Ensure new SL is above current SL and below current price with buffer
      if(newSL <= currentSL + point || newSL >= currentPrice - point * 10)
      {
         Print("❌ SL move rejected: newSL=", DoubleToString(newSL, _Digits), 
               " currentSL=", DoubleToString(currentSL, _Digits),
               " currentPrice=", DoubleToString(currentPrice, _Digits));
         return false;
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      newSL = entryPrice - profitDistance;
      //--- Ensure new SL is below current SL and above current price with buffer
      if(newSL >= currentSL - point || newSL <= currentPrice + point * 10)
      {
         Print("❌ SL move rejected: newSL=", DoubleToString(newSL, _Digits), 
               " currentSL=", DoubleToString(currentSL, _Digits),
               " currentPrice=", DoubleToString(currentPrice, _Digits));
         return false;
      }
   }
   
   newSL = NormalizeDouble(newSL, _Digits);
   double normalizedTP = NormalizeDouble(tpPrice, _Digits);
   
   //--- Use CTrade for reliable modification
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionModify(posTicket, newSL, normalizedTP))
   {
      status_progress = "SL LOCKED " + DoubleToString(percentProfit, 0) + "%";
      Print("✅ SL moved to ", DoubleToString(percentProfit, 1), "% profit: ", DoubleToString(newSL, _Digits));
      return true;
   }
   else
   {
      int error = GetLastError();
      Print("❌ Failed to move SL. Error: ", error);
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
   double volumeToClose = currentVolume * closePercent;
   
   //--- Normalize volume
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotStep > 0)
      volumeToClose = MathRound(volumeToClose / lotStep) * lotStep;
   
   volumeToClose = MathMax(minLot, volumeToClose);
   
   //--- Ensure we don't close the whole position
   if(volumeToClose >= currentVolume - minLot)
      return false;
   
   //--- Use CTrade for reliable partial closing
   CTrade trade;
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(Slippage);
   
   if(trade.PositionClosePartial(posTicket, volumeToClose))
   {
      status_progress = "PARTIAL " + DoubleToString(closePercent * 100, 0) + "%";
      Print("✅ Partial close: ", DoubleToString(volumeToClose, 2), " lots (", DoubleToString(closePercent * 100, 1), "%)");
      return true;
   }
   else
   {
      int error = GetLastError();
      Print("❌ Failed to close partial. Error: ", error);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Manage Profits - Main Function                                   |
//+------------------------------------------------------------------+
void ManageProfits()
{
   if(!has_open_position || positionTicket == 0)
      return;
   
   //--- Clean up trackers first
   CleanupProfitTrackers();
   
   //--- Get tracker index
   int trackerIdx = GetProfitTrackerIndex(positionTicket);
   if(trackerIdx < 0)
   {
      //--- If no tracker exists, try to find position and create one
      CheckOpenPositions();
      if(has_open_position && positionTicket > 0)
      {
         InitializeProfitTracker(positionTicket);
         trackerIdx = GetProfitTrackerIndex(positionTicket);
      }
      if(trackerIdx < 0)
         return;
   }
   
   //--- Get position data
   if(!PositionSelectByTicket(positionTicket))
      return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double tpPrice = PositionGetDouble(POSITION_TP);
   double slPrice = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   //--- Update status with current profit
   status_profit = "$" + DoubleToString(profit, 2);
   
   //--- Check if we have profit and TP is valid
   if(profit <= 0 || tpPrice <= 0)
   {
      //--- Reset flags if profit goes negative so we can try again
      if(profitTrackers[trackerIdx].breakevenProcessed && profit < -1.0)
      {
         profitTrackers[trackerIdx].breakevenProcessed = false;
      }
      return;
   }
   
   //--- Calculate percent to TP
   double targetProfit = 0;
   double percentToTP = CalculatePercentToTP(positionTicket, targetProfit);
   
   if(percentToTP <= 0)
      return;
   
   //--- Update highest percentage seen
   if(percentToTP > profitTrackers[trackerIdx].highestPercentSeen)
      profitTrackers[trackerIdx].highestPercentSeen = percentToTP;
   
   //--- ================ 1. BREAKEVEN AT 50% OF TP ================
   if(!profitTrackers[trackerIdx].breakevenProcessed && percentToTP >= Breakeven_Threshold)
   {
      //--- Only move if SL is still below entry (for buy) or above entry (for sell)
      bool slBelowEntry = (posType == POSITION_TYPE_BUY && slPrice < entryPrice);
      bool slAboveEntry = (posType == POSITION_TYPE_SELL && slPrice > entryPrice);
      
      if(slBelowEntry || slAboveEntry)
      {
         if(MoveToBreakeven(positionTicket, entryPrice, tpPrice))
         {
            profitTrackers[trackerIdx].breakevenProcessed = true;
            Print("📊 Breakeven activated at ", DoubleToString(percentToTP, 1), "% of TP");
         }
      }
   }
   
   //--- ================ 2. SL TO 20% PROFIT AT 70% OF TP ================
   if(!profitTrackers[trackerIdx].sl20PercentProcessed && percentToTP >= SL_20Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 20.0))
      {
         profitTrackers[trackerIdx].sl20PercentProcessed = true;
         Print("📊 SL moved to 20% profit at ", DoubleToString(percentToTP, 1), "% of TP");
      }
   }
   
   //--- ================ 3. SL TO 50% PROFIT AT 90% OF TP ================
   if(!profitTrackers[trackerIdx].sl50PercentProcessed && percentToTP >= SL_50Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 50.0))
      {
         profitTrackers[trackerIdx].sl50PercentProcessed = true;
         Print("📊 SL moved to 50% profit at ", DoubleToString(percentToTP, 1), "% of TP");
      }
   }
   
   //--- ================ 4. PARTIAL CLOSES AT 20% INTERVALS ================
   //--- Skip if volume is too small or we've closed too much
   if(volume < Min_Volume_For_Partials || profitTrackers[trackerIdx].totalClosedPercent >= 0.80)
      return;
   
   //--- Milestones: 20%, 40%, 60%, 80%
   double milestones[] = {20.0, 40.0, 60.0, 80.0};
   int milestoneIndex = -1;
   
   for(int i = 0; i < 4; i++)
   {
      if(percentToTP >= milestones[i] && !profitTrackers[trackerIdx].milestoneProcessed[i])
      {
         milestoneIndex = i;
         break;
      }
   }
   
   if(milestoneIndex < 0)
      return;
   
   //--- Calculate how much to close (20% of remaining position)
   double remainingPercent = 1.0 - profitTrackers[trackerIdx].totalClosedPercent;
   double closePercent = 0.20; // Close 20% at each milestone
   
   //--- Ensure we don't close too much
   if(profitTrackers[trackerIdx].totalClosedPercent + closePercent > 0.80)
      closePercent = 0.80 - profitTrackers[trackerIdx].totalClosedPercent;
   
   if(closePercent <= 0.01)
      return;
   
   //--- Execute partial close
   if(ClosePartialPosition(positionTicket, closePercent))
   {
      profitTrackers[trackerIdx].milestoneProcessed[milestoneIndex] = true;
      profitTrackers[trackerIdx].totalClosedPercent += closePercent;
      
      Print("📊 Partial close at ", DoubleToString(milestones[milestoneIndex], 0), "% of TP: ", 
            DoubleToString(closePercent * 100, 1), "% of position");
   }
}
//+------------------------------------------------------------------+