//+------------------------------------------------------------------+
//|                                 Range_Pullback_DayTrader.mq5     |
//|                                   Day Trading - M15/H1          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>

//--- Input parameters - DAY TRADING FOCUS (15-hour lookback)
input int      MA_Fast_Period     = 120;         // Fast MA Period (Entry - M15) - 30 hours
input int      MA_Slow_Period     = 120;         // Slow MA Period (Entry - M15) - 30 hours
input int      MA_Trend_Period    = 60;          // Trend MA Period (H1) - 60 hours (2.5 days)
input int      Range_Period       = 60;          // Range Detection Period (15 hours on M15)
input int      SL_Structure_Bars  = 20;          // Bars for SL Structure (5 hours on M15)
input double   Pullback_Threshold = 0.25;        // Fibonacci Pullback Level
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H1; // Trend Timeframe
input ENUM_TIMEFRAMES Entry_Timeframe  = PERIOD_M15; // Entry Timeframe
input double   Fixed_Lot_Size     = 0.01;        // Fixed Lot Size (FIXED at 0.01)
input int      Slippage           = 10;          // Slippage in points
input double   MinRR              = 1.0;         // Minimum Risk/Reward Ratio
input double   Target_RR          = 2.0;         // Target RR for TP-based SL
input int      Confidence_Threshold = 55;        // Minimum confidence to enter (0-100)

//--- NEW: Volume & Pattern Confirmations
input bool     Enable_Volume_Filter = true;      // Enable volume confirmation
input double   Min_Volume_Ratio = 1.2;           // Minimum volume vs average (1.0 = average)
input int      Volume_Period = 20;               // Period for average volume calculation
input bool     Enable_Pattern_Filter = true;     // Enable candlestick pattern confirmation
input int      Pattern_Bonus = 10;               // Points to add for valid patterns

//--- Colors
input color    MA_Fast_Color      = clrMagenta;  // Fast MA Color (M15)
input color    MA_Slow_Color      = clrDodgerBlue; // Slow MA Color (M15)
input color    MA_Trend_Color     = clrGold;     // Trend MA Color (H1)

//--- Profit Management Inputs
input bool     Enable_Smart_Profit_Management = true;
input double   Breakeven_Threshold = 50.0;       // % to TP to move SL to breakeven
input double   Breakeven_Buffer_Points = 5;      // Buffer above breakeven in points
input double   SL_20Percent_Threshold = 70.0;    // % to TP to move SL to 20% profit
input double   SL_50Percent_Threshold = 95.0;    // % to TP to move SL to 50% profit
input double   Min_Volume_For_Partials = 0.02;

//--- Day Trading Filters
input bool     Enable_Spread_Filter = true;
input double   Max_Spread_Pips = 5.0;
input bool     Enable_Time_Filter = false;       // DISABLED - Trade 24/7
input bool     Enable_Daily_Limit = false;
input int      Max_Daily_Trades = 3;

//--- Logging & Display Toggles
input bool     Enable_Logging = true;            // Enable detailed logging to Experts tab
input bool     Enable_Chart_Comments = true;     // Enable trade markers on chart

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
int handle_ATR;
int handle_ADX;

double range_high, range_low, range_mid;
bool in_range = false;
bool pullback_detected = false;
ulong positionTicket = 0;
bool has_open_position = false;
ENUM_TREND_DIRECTION current_trade_direction = TREND_NONE;
ENUM_TREND_DIRECTION trend_bias = TREND_NONE;
ENUM_TREND_DIRECTION trend_entry = TREND_NONE;

//--- Pause/Monitoring flags
bool buys_paused = false;
bool sells_paused = false;
bool monitoring_buys = false;
bool monitoring_sells = false;

//--- Daily trade counter
int daily_trades = 0;
datetime last_trade_date = 0;

//--- Status variables
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
string status_buys_paused = "NO";
string status_sells_paused = "NO";
string status_monitoring = "NONE";
string status_ma_cross = "N/A";
string status_daily_trades = "0/3";

//--- NEW: Volume & Pattern Status
string status_volume = "N/A";
string status_pattern = "N/A";
int volume_score = 0;
int pattern_score = 0;
double volume_ratio = 0;

//--- Profit Tracker Structure
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
};

ProfitTracker profitTrackers[];
int trackerCount = 0;

int ma_fast_handle;
int ma_slow_handle;
int ma_trend_handle;
int last_candle_time = 0;

//--- Failed trades storage for display
struct FailedTrade
{
    datetime time;
    double price;
    ENUM_TREND_DIRECTION direction;
    string reason;
    int confidence;
    double pullback_pct;
};

FailedTrade failedTrades[];
int failedTradeCount = 0;

//--- Forward declarations
void ClosePosition();
void CheckOpenPositions();
void DrawStatusPanel();
void DetectRange(MqlRates &rates[]);
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score, int adx_score,
                  int vol_score, int pat_score,
                  string pullback_desc, string mtf_desc, string adx_desc, 
                  string volume_desc, string pattern_desc, string price_pos_desc,
                  bool is_rejected = false, string reject_reason = "");
void InitializeProfitTracker(ulong posTicket);
void CleanupProfitTrackers();
void ManageProfits();
void DrawSwingHighLow(MqlRates &rates[]);
void UpdatePauseStatus(double current_price, double ma89, double ma21_m15, double ma50_m15, ENUM_TREND_DIRECTION trend);
bool CheckDailyTradeLimit();
void ResetDailyCounter();
int GetMaxPositions();
bool CanAddNewPosition();
void LogMessage(string message, bool isError = false);
void DrawTradeMarker(double price, ENUM_TREND_DIRECTION direction, string label, bool isFailed = false);

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
//| Draw Trade Marker                                                |
//+------------------------------------------------------------------+
void DrawTradeMarker(double price, ENUM_TREND_DIRECTION direction, string label, bool isFailed = false)
{
   if(!Enable_Chart_Comments) return;
   
   static int markerCount = 0;
   markerCount++;
   
   string prefix = "Trade_" + IntegerToString(markerCount) + "_";
   color arrow_color = isFailed ? clrYellow : (direction == TREND_UP ? clrLime : clrRed);
   int arrow_code = (direction == TREND_UP) ? 241 : 242;
   
   datetime time = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double offset = (direction == TREND_UP) ? -25 * point : 25 * point;
   string icon = isFailed ? "❌" : "✅";
   
   if(ObjectCreate(0, prefix + "Arrow", OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, prefix + "Arrow", OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, prefix + "Arrow", OBJPROP_COLOR, arrow_color);
      ObjectSetInteger(0, prefix + "Arrow", OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, prefix + "Arrow", OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
   
   if(ObjectCreate(0, prefix + "Label", OBJ_TEXT, 0, time + PeriodSeconds(Entry_Timeframe)*3, price + offset))
   {
      ObjectSetString(0, prefix + "Label", OBJPROP_TEXT, icon + " " + label);
      ObjectSetInteger(0, prefix + "Label", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, prefix + "Label", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, prefix + "Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, prefix + "Label", OBJPROP_BACK, true);
      ObjectSetInteger(0, prefix + "Label", OBJPROP_BGCOLOR, clrBlack);
      ObjectSetString(0, prefix + "Label", OBJPROP_FONT, "Arial");
   }
   
   string priceLabel = DoubleToString(price, _Digits);
   if(ObjectCreate(0, prefix + "Price", OBJ_TEXT, 0, time + PeriodSeconds(Entry_Timeframe)*1, price))
   {
      ObjectSetString(0, prefix + "Price", OBJPROP_TEXT, priceLabel);
      ObjectSetInteger(0, prefix + "Price", OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, prefix + "Price", OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, prefix + "Price", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetString(0, prefix + "Price", OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Store Failed Trade                                               |
//+------------------------------------------------------------------+
void StoreFailedTrade(double price, ENUM_TREND_DIRECTION direction, string reason, 
                      int confidence, double pullback_pct)
{
   string label = StringFormat("C:%d | PB:%.1f%% | %s", confidence, pullback_pct, reason);
   DrawTradeMarker(price, direction, label, true);
}

//+------------------------------------------------------------------+
//| Store Successful Trade                                           |
//+------------------------------------------------------------------+
void StoreSuccessfulTrade(double price, ENUM_TREND_DIRECTION direction, 
                          int confidence, double pullback_pct)
{
   string label = StringFormat("C:%d | PB:%.1f%% | +", confidence, pullback_pct);
   DrawTradeMarker(price, direction, label, false);
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
   handle_ATR = iATR(_Symbol, Entry_Timeframe, 14);
   handle_ADX = iADX(_Symbol, Entry_Timeframe, 14);
   
   if(handle_MA_Fast == INVALID_HANDLE || handle_MA_Slow == INVALID_HANDLE || 
      handle_MA_Trend == INVALID_HANDLE || handle_MA_H1_50 == INVALID_HANDLE ||
      handle_MA_H1_21 == INVALID_HANDLE || handle_MA_M15_50 == INVALID_HANDLE ||
      handle_MA_M15_21 == INVALID_HANDLE || handle_ATR == INVALID_HANDLE || 
      handle_ADX == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles!");
      return(INIT_FAILED);
   }
   
   ArrayResize(profitTrackers, 100);
   trackerCount = 0;
   ArrayResize(failedTrades, 100);
   failedTradeCount = 0;
   
   LogMessage("=========================================");
   LogMessage("   DAY TRADING RANGE PULLBACK EXECUTOR   ");
   LogMessage("=========================================");
   LogMessage("Entry Timeframe: M15 (15-minute candles)");
   LogMessage("Trend Timeframe: H1 (1-hour candles)");
   LogMessage("Fast MA: " + IntegerToString(MA_Fast_Period) + " bars = 30 hours");
   LogMessage("Slow MA: " + IntegerToString(MA_Slow_Period) + " bars = 30 hours");
   LogMessage("Trend MA: " + IntegerToString(MA_Trend_Period) + " bars = 60 hours (2.5 days)");
   LogMessage("Range Period: " + IntegerToString(Range_Period) + " bars = 15 hours");
   LogMessage("Max Daily Trades: " + IntegerToString(Max_Daily_Trades));
   LogMessage("Fixed Lot Size: 0.01");
   LogMessage("Max Positions: " + IntegerToString(GetMaxPositions()) + " (based on account balance)");
   LogMessage("Volume Filter: " + (Enable_Volume_Filter ? "ON" : "OFF"));
   LogMessage("Pattern Filter: " + (Enable_Pattern_Filter ? "ON" : "OFF"));
   LogMessage("Time Filter: " + (Enable_Time_Filter ? "ON" : "OFF (24/7 Trading)"));
   LogMessage("Logging: " + (Enable_Logging ? "ON" : "OFF"));
   LogMessage("Chart Comments: " + (Enable_Chart_Comments ? "ON" : "OFF"));
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
   if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
   if(handle_ADX != INVALID_HANDLE) IndicatorRelease(handle_ADX);
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
         DrawStatusPanel();
         return;
      }
   }
   
   if(Enable_Daily_Limit && !CheckDailyTradeLimit())
   {
      status_reason = "DAILY LIMIT REACHED (" + IntegerToString(daily_trades) + "/" + IntegerToString(Max_Daily_Trades) + ")";
      DrawStatusPanel();
      return;
   }
   
   datetime current_bar_time = iTime(_Symbol, Entry_Timeframe, 0);
   bool new_bar = (current_bar_time != last_candle_time);
   
   if(Enable_Smart_Profit_Management && has_open_position)
   {
      ManageProfits();
   }
   
   if(!new_bar) 
   {
      DrawStatusPanel();
      return;
   }
   last_candle_time = (int)current_bar_time;
   
   CheckOpenPositions();
   UpdateStatus();
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int rates_copied = CopyRates(_Symbol, Entry_Timeframe, 0, Range_Period + 100, rates);
   
   if(rates_copied < Range_Period + 10) 
   {
      status_reason = "INSUFFICIENT DATA (" + IntegerToString(rates_copied) + " bars)";
      status_progress = "DATA ERROR";
      DrawStatusPanel();
      return;
   }
   
   DrawSwingHighLow(rates);
   
   MqlRates rates_h1[];
   ArraySetAsSeries(rates_h1, true);
   if(CopyRates(_Symbol, Trend_Timeframe, 0, 10, rates_h1) < 5) 
   {
      status_reason = "H1 DATA ERROR";
      DrawStatusPanel();
      return;
   }
   
   double ma_fast[], ma_slow[], ma_trend[], ma_h1_50[], ma_h1_21[], ma_m15_50[], ma_m15_21[], atr[];
   double adx_main[], adx_plus[], adx_minus[];
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(ma_trend, true);
   ArraySetAsSeries(ma_h1_50, true);
   ArraySetAsSeries(ma_h1_21, true);
   ArraySetAsSeries(ma_m15_50, true);
   ArraySetAsSeries(ma_m15_21, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx_main, true);
   ArraySetAsSeries(adx_plus, true);
   ArraySetAsSeries(adx_minus, true);
   
   if(CopyBuffer(handle_MA_Fast, 0, 0, 10, ma_fast) < 10) 
   {
      status_reason = "MA_FAST DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_Slow, 0, 0, 10, ma_slow) < 10) 
   {
      status_reason = "MA_SLOW DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_Trend, 0, 0, 10, ma_trend) < 10) 
   {
      status_reason = "MA_TREND DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_H1_50, 0, 0, 10, ma_h1_50) < 5) 
   {
      status_reason = "MA_H1_50 DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_H1_21, 0, 0, 10, ma_h1_21) < 5) 
   {
      status_reason = "MA_H1_21 DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_M15_50, 0, 0, 10, ma_m15_50) < 5) 
   {
      status_reason = "MA_M15_50 DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_MA_M15_21, 0, 0, 10, ma_m15_21) < 5) 
   {
      status_reason = "MA_M15_21 DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_ATR, 0, 0, 10, atr) < 10) 
   {
      status_reason = "ATR DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_ADX, 0, 0, 5, adx_main) < 5) 
   {
      status_reason = "ADX DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_ADX, 1, 0, 5, adx_plus) < 5) 
   {
      status_reason = "ADX+ DATA ERROR";
      DrawStatusPanel();
      return;
   }
   if(CopyBuffer(handle_ADX, 2, 0, 5, adx_minus) < 5) 
   {
      status_reason = "ADX- DATA ERROR";
      DrawStatusPanel();
      return;
   }
   
   DetectRange(rates);
   
   double current_price = rates[0].close;
   double current_ma_fast = ma_fast[0];
   double current_ma_slow = ma_slow[0];
   double current_ma_trend = ma_trend[0];
   double current_ma50_h1 = ma_h1_50[0];
   double current_ma50_m15 = ma_m15_50[0];
   double current_ma21_m15 = ma_m15_21[0];
   
   if(current_price > current_ma_trend)
      trend_bias = TREND_UP;
   else if(current_price < current_ma_trend)
      trend_bias = TREND_DOWN;
   else
      trend_bias = TREND_NONE;
   
   if(current_price > current_ma_fast)
      trend_entry = TREND_UP;
   else if(current_price < current_ma_fast)
      trend_entry = TREND_DOWN;
   else
      trend_entry = TREND_NONE;
   
   UpdatePauseStatus(current_price, current_ma_fast, current_ma21_m15, current_ma50_m15, trend_bias);
   
   if(trend_bias == TREND_UP)
      status_trend = "BULLISH ▲ (Price>H1 MA60)";
   else if(trend_bias == TREND_DOWN)
      status_trend = "BEARISH ▼ (Price<H1 MA60)";
   else
      status_trend = "NEUTRAL";
   
   double pullback_percent = 0;
   if(range_high > range_low)
   {
      if(trend_bias == TREND_UP)
         pullback_percent = (range_high - current_price) / (range_high - range_low) * 100;
      else if(trend_bias == TREND_DOWN)
         pullback_percent = (current_price - range_low) / (range_high - range_low) * 100;
   }
   status_pullback = DoubleToString(pullback_percent, 1) + "%";
   
   if(current_ma21_m15 > current_ma50_m15)
      status_ma_cross = "MA21 > MA50 (BULLISH)";
   else if(current_ma21_m15 < current_ma50_m15)
      status_ma_cross = "MA21 < MA50 (BEARISH)";
   else
      status_ma_cross = "MA21 = MA50";
   
   status_daily_trades = IntegerToString(daily_trades) + "/" + IntegerToString(Max_Daily_Trades);
   
   DetectPullbackAndExecute(rates, rates_h1, ma_fast, ma_slow, ma_trend, ma_h1_50, ma_h1_21, 
                            ma_m15_50, ma_m15_21, atr, adx_main, adx_plus, adx_minus);
   
   DrawStatusPanel();
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
//| Update Pause Status                                              |
//+------------------------------------------------------------------+
void UpdatePauseStatus(double current_price, double ma_fast, double ma21_m15, double ma50_m15, ENUM_TREND_DIRECTION trend)
{
   if(trend == TREND_NONE)
   {
      buys_paused = false;
      sells_paused = false;
      monitoring_buys = false;
      monitoring_sells = false;
      status_monitoring = "NONE";
      return;
   }
   
   if(trend == TREND_UP)
   {
      if(current_price < ma_fast && !buys_paused)
      {
         buys_paused = true;
         monitoring_buys = true;
         LogMessage("⏸️ BUYS PAUSED: Price dropped below Fast MA (30h)");
      }
      
      if(buys_paused && monitoring_buys)
      {
         if(ma21_m15 > ma50_m15)
         {
            buys_paused = false;
            monitoring_buys = false;
            LogMessage("✅ BUYS RESUMED: MA21 > MA50");
         }
      }
   }
   
   if(trend == TREND_DOWN)
   {
      if(current_price > ma_fast && !sells_paused)
      {
         sells_paused = true;
         monitoring_sells = true;
         LogMessage("⏸️ SELLS PAUSED: Price rose above Fast MA (30h)");
      }
      
      if(sells_paused && monitoring_sells)
      {
         if(ma21_m15 < ma50_m15)
         {
            sells_paused = false;
            monitoring_sells = false;
            LogMessage("✅ SELLS RESUMED: MA21 < MA50");
         }
      }
   }
   
   status_buys_paused = buys_paused ? "YES" : "NO";
   status_sells_paused = sells_paused ? "YES" : "NO";
}

//+------------------------------------------------------------------+
//| Draw Status Panel                                                |
//+------------------------------------------------------------------+
void DrawStatusPanel()
{
   string text = "";
   text += "╔══════════════════════════════════╗\n";
   text += "║       DAY TRADING BOT           ║\n";
   text += "╠══════════════════════════════════╣\n";
   text += "║ TREND:     " + PadRight(status_trend, 20) + "║\n";
   text += "║ MA CROSS:  " + PadRight(status_ma_cross, 20) + "║\n";
   text += "║ IN TRADE:  " + PadRight(status_in_trade, 20) + "║\n";
   text += "║ PULLBACK:  " + PadRight(status_pullback, 20) + "║\n";
   text += "║ ENDING:    " + PadRight(status_pullback_ending, 20) + "║\n";
   text += "║ CONFIDENCE:" + PadRight(status_confidence, 20) + "║\n";
   text += "║ VOLUME:    " + PadRight(status_volume, 20) + "║\n";
   text += "║ PATTERN:   " + PadRight(status_pattern, 20) + "║\n";
   text += "║ DAILY TRD: " + PadRight(status_daily_trades, 20) + "║\n";
   text += "║ BUYS PAUSED:" + PadRight(status_buys_paused, 19) + "║\n";
   text += "║ SELLS PAUSED:" + PadRight(status_sells_paused, 18) + "║\n";
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
//| Helper function to pad string                                    |
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
   }
   
   if(ObjectCreate(0, "SwingLow_Label", OBJ_TEXT, 0, low_time, low - label_offset))
   {
      ObjectSetString(0, "SwingLow_Label", OBJPROP_TEXT, "🟢 SWING LOW");
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "SwingLow_Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetString(0, "SwingLow_Label", OBJPROP_FONT, "Arial Bold");
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
//| Calculate Pullback Score                                         |
//+------------------------------------------------------------------+
int CalculatePullbackScore(double pullback_percent)
{
   if(pullback_percent < 25.0 || pullback_percent > 85.0)
      return 0;
   
   if(pullback_percent >= 25.0 && pullback_percent <= 38.2)
      return 30;
   else if(pullback_percent > 38.2 && pullback_percent <= 50.0)
      return 35;
   else if(pullback_percent > 50.0 && pullback_percent <= 61.8)
      return 30;
   else if(pullback_percent > 61.8 && pullback_percent <= 78.6)
      return 20;
   else if(pullback_percent > 78.6 && pullback_percent <= 85.0)
      return 15;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Pullback Description                                         |
//+------------------------------------------------------------------+
string GetPullbackDescription(double pullback_percent)
{
   if(pullback_percent >= 25.0 && pullback_percent <= 38.2)
      return "EARLY ZONE (25-38.2%)";
   else if(pullback_percent > 38.2 && pullback_percent <= 50.0)
      return "GOLDEN ZONE (38.2-50%)";
   else if(pullback_percent > 50.0 && pullback_percent <= 61.8)
      return "GOOD ZONE (50-61.8%)";
   else if(pullback_percent > 61.8 && pullback_percent <= 78.6)
      return "DEEP ZONE (61.8-78.6%)";
   else if(pullback_percent > 78.6 && pullback_percent <= 85.0)
      return "RISKY ZONE (78.6-85%)";
   else if(pullback_percent < 25.0)
      return "TOO SHALLOW (<25%)";
   else if(pullback_percent > 85.0)
      return "TOO DEEP (>85%)";
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Calculate MTF Score                                              |
//+------------------------------------------------------------------+
int CalculateMTFScore(MqlRates &rates_h1[], ENUM_TREND_DIRECTION trend)
{
   int score = 0;
   
   bool h1_bullish = (rates_h1[0].close > rates_h1[0].open);
   bool h1_bearish = (rates_h1[0].close < rates_h1[0].open);
   
   double current_body = MathAbs(rates_h1[0].close - rates_h1[0].open);
   double prev_body = MathAbs(rates_h1[1].close - rates_h1[1].open);
   
   double h1_ma50 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   double h1_close = rates_h1[0].close;
   
   if(trend == TREND_UP)
   {
      if(h1_bullish && current_body > prev_body * 1.5)
         score += 20;
      else if(h1_bullish)
         score += 15;
      
      if(h1_close > h1_ma50)
         score += 5;
   }
   else if(trend == TREND_DOWN)
   {
      if(h1_bearish && current_body > prev_body * 1.5)
         score += 20;
      else if(h1_bearish)
         score += 15;
      
      if(h1_close < h1_ma50)
         score += 5;
   }
   
   return MathMin(25, score);
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
      score = 12;
      level = 5;
   }
   else if(adx_main >= 40)
   {
      score = 10;
      level = 4;
   }
   else if(adx_main >= 30)
   {
      score = 8;
      level = 3;
   }
   else if(adx_main >= 25)
   {
      score = 5;
      level = 2;
   }
   else if(adx_main >= 20)
   {
      score = 3;
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
         score += 3;
      else if(level >= 3)
         score += 2;
      else if(level >= 2)
         score += 1;
      else if(level >= 1)
         score += 1;
   }
   
   return MathMin(15, score);
}

//+------------------------------------------------------------------+
//| Calculate Volume Score                                           |
//+------------------------------------------------------------------+
int CalculateVolumeScore(MqlRates &rates[], int period, double &ratio)
{
    if(ArraySize(rates) < period + 1) 
    {
        ratio = 1.0;
        return 4;
    }
    
    double avg_volume = 0;
    int count = 0;
    for(int i = 1; i <= period && i < ArraySize(rates); i++)
    {
        long vol = rates[i].tick_volume;
        
        if(vol > 0)
        {
            avg_volume += (double)vol;
            count++;
        }
    }
    
    if(count == 0 || avg_volume == 0)
    {
        ratio = 1.0;
        return 4;
    }
    
    avg_volume /= count;
    
    long current_vol = rates[0].tick_volume;
    
    if(current_vol == 0)
    {
        ratio = 1.0;
        return 4;
    }
    
    ratio = (double)current_vol / avg_volume;
    
    if(ratio >= 2.5) return 15;
    if(ratio >= 1.8) return 13;
    if(ratio >= 1.4) return 10;
    if(ratio >= 1.1) return 7;
    if(ratio >= 0.8) return 4;
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate Pattern Score                                          |
//+------------------------------------------------------------------+
int CalculatePatternScore(MqlRates &rates[], ENUM_TREND_DIRECTION trend)
{
    if(ArraySize(rates) < 2) return 0;
    
    double body = MathAbs(rates[0].close - rates[0].open);
    double lower_wick = MathMin(rates[0].close, rates[0].open) - rates[0].low;
    double upper_wick = rates[0].high - MathMax(rates[0].close, rates[0].open);
    double candle_range = rates[0].high - rates[0].low;
    
    if(candle_range == 0 || body == 0) return 0;
    
    bool bullish_engulfing = false;
    if(rates[1].close < rates[1].open && rates[0].close > rates[0].open)
    {
        if(rates[0].close > rates[1].open && rates[0].open < rates[1].close)
            bullish_engulfing = true;
    }
    
    bool hammer = (lower_wick > body * 2.0 && upper_wick < body * 0.5);
    bool bullish_pinbar = (lower_wick > body * 2.5 && upper_wick < body * 0.3);
    
    bool bearish_engulfing = false;
    if(rates[1].close > rates[1].open && rates[0].close < rates[0].open)
    {
        if(rates[0].close < rates[1].open && rates[0].open > rates[1].close)
            bearish_engulfing = true;
    }
    
    bool shooting_star = (upper_wick > body * 2.0 && lower_wick < body * 0.5);
    bool bearish_pinbar = (upper_wick > body * 2.5 && lower_wick < body * 0.3);
    
    if(trend == TREND_UP)
    {
        if(bullish_engulfing)
            return 10;
        else if(hammer || bullish_pinbar)
            return 8;
        else if(rates[0].close > rates[0].open && body > MathAbs(rates[1].close - rates[1].open) * 1.5)
            return 5;
        else if(rates[0].close > rates[0].open)
            return 3;
    }
    else if(trend == TREND_DOWN)
    {
        if(bearish_engulfing)
            return 10;
        else if(shooting_star || bearish_pinbar)
            return 8;
        else if(rates[0].close < rates[0].open && body > MathAbs(rates[1].close - rates[1].open) * 1.5)
            return 5;
        else if(rates[0].close < rates[0].open)
            return 3;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Get Volume Description                                           |
//+------------------------------------------------------------------+
string GetVolumeDescription(double ratio)
{
    if(ratio >= 2.5) return "EXTREME 💥";
    if(ratio >= 1.8) return "VERY HIGH 🔥";
    if(ratio >= 1.4) return "HIGH ✅";
    if(ratio >= 1.1) return "ABOVE AVG 📈";
    if(ratio >= 0.8) return "AVERAGE";
    return "LOW ⚠️";
}

//+------------------------------------------------------------------+
//| Get Pattern Description                                          |
//+------------------------------------------------------------------+
string GetPatternDescription(MqlRates &rates[], ENUM_TREND_DIRECTION trend)
{
    if(ArraySize(rates) < 2) return "NONE";
    
    double body = MathAbs(rates[0].close - rates[0].open);
    double lower_wick = MathMin(rates[0].close, rates[0].open) - rates[0].low;
    double upper_wick = rates[0].high - MathMax(rates[0].close, rates[0].open);
    double candle_range = rates[0].high - rates[0].low;
    
    if(candle_range == 0 || body == 0) return "DOJI";
    
    bool bullish_engulfing = (rates[1].close < rates[1].open && 
                              rates[0].close > rates[0].open &&
                              rates[0].close > rates[1].open && 
                              rates[0].open < rates[1].close);
    
    bool bearish_engulfing = (rates[1].close > rates[1].open && 
                              rates[0].close < rates[0].open &&
                              rates[0].close < rates[1].open && 
                              rates[0].open > rates[1].close);
    
    bool hammer = (lower_wick > body * 2.0 && upper_wick < body * 0.5);
    bool shooting_star = (upper_wick > body * 2.0 && lower_wick < body * 0.5);
    bool bullish_pinbar = (lower_wick > body * 2.5 && upper_wick < body * 0.3);
    bool bearish_pinbar = (upper_wick > body * 2.5 && lower_wick < body * 0.3);
    
    if(trend == TREND_UP)
    {
        if(bullish_engulfing) return "BULLISH ENGULFING ✅";
        if(hammer) return "HAMMER ✅";
        if(bullish_pinbar) return "BULLISH PINBAR ✅";
        if(rates[0].close > rates[0].open) return "BULLISH CANDLE";
    }
    else if(trend == TREND_DOWN)
    {
        if(bearish_engulfing) return "BEARISH ENGULFING ✅";
        if(shooting_star) return "SHOOTING STAR ✅";
        if(bearish_pinbar) return "BEARISH PINBAR ✅";
        if(rates[0].close < rates[0].open) return "BEARISH CANDLE";
    }
    
    return "NONE";
}

//+------------------------------------------------------------------+
//| Get MTF Description                                              |
//+------------------------------------------------------------------+
string GetMTFDescription(MqlRates &rates_h1[], ENUM_TREND_DIRECTION trend)
{
   string result = "";
   
   bool h1_bullish = (rates_h1[0].close > rates_h1[0].open);
   bool h1_bearish = (rates_h1[0].close < rates_h1[0].open);
   bool h1_doji = (MathAbs(rates_h1[0].close - rates_h1[0].open) < (rates_h1[0].high - rates_h1[0].low) * 0.1);
   
   double current_body = MathAbs(rates_h1[0].close - rates_h1[0].open);
   double prev_body = MathAbs(rates_h1[1].close - rates_h1[1].open);
   
   double h1_ma50 = iMA(_Symbol, Trend_Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   double h1_close = rates_h1[0].close;
   
   if(trend == TREND_UP)
   {
      if(h1_bullish && current_body > prev_body * 1.5)
         result = "STRONG BULLISH H1 ✅";
      else if(h1_bullish)
         result = "BULLISH H1 ✅";
      else if(h1_doji)
         result = "H1 DOJI ⏳";
      else if(h1_bearish)
         result = "BEARISH H1 ❌";
      
      if(h1_close > h1_ma50)
         result += " | Above MA50 (Strong)";
      else
         result += " | Below MA50 (Weak)";
   }
   else if(trend == TREND_DOWN)
   {
      if(h1_bearish && current_body > prev_body * 1.5)
         result = "STRONG BEARISH H1 ✅";
      else if(h1_bearish)
         result = "BEARISH H1 ✅";
      else if(h1_doji)
         result = "H1 DOJI ⏳";
      else if(h1_bullish)
         result = "BULLISH H1 ❌";
      
      if(h1_close < h1_ma50)
         result += " | Below MA50 (Strong)";
      else
         result += " | Above MA50 (Weak)";
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
      result = "LEVEL 5: EXTREME TREND";
   else if(adx_main >= 40)
      result = "LEVEL 4: STRONG TREND";
   else if(adx_main >= 30)
      result = "LEVEL 3: GOOD TREND";
   else if(adx_main >= 25)
      result = "LEVEL 2: MODERATE TREND";
   else if(adx_main >= 20)
      result = "LEVEL 1: WEAK TREND";
   else
      result = "LEVEL 0: NO TREND";
   
   if(trend == TREND_UP)
   {
      if(adx_plus > adx_minus)
         result += " | +DI > -DI ✅";
      else
         result += " | +DI < -DI ⚠️";
   }
   else if(trend == TREND_DOWN)
   {
      if(adx_minus > adx_plus)
         result += " | -DI > +DI ✅";
      else
         result += " | -DI < +DI ⚠️";
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
//| Calculate Optimal Stop Loss                                      |
//+------------------------------------------------------------------+
double CalculateOptimalSL(ENUM_TREND_DIRECTION trend, double entry_price, double tp_price,
                          double current_ma_fast, double atr_value, double target_rr,
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
      double sl_ma_fast = current_ma_fast - (atr_value * 0.5);
      
      double recent_low = rates[0].low;
      for(int i = 1; i < SL_Structure_Bars; i++)
      {
         if(rates[i].low < recent_low)
            recent_low = rates[i].low;
      }
      double sl_structure = recent_low - (atr_value * 0.4);
      
      structure_sl = MathMax(sl_ma_fast, sl_structure) - (atr_value * 0.15);
      sl_price = MathMax(structure_sl, tp_based_sl);
   }
   else if(trend == TREND_DOWN)
   {
      double sl_ma_fast = current_ma_fast + (atr_value * 0.5);
      
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
//| Calculate Dynamic Lot Size - FIXED at 0.01                      |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   return 0.01;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_TREND_DIRECTION trend, double entry_price, double sl_price, double tp_price,
                  int total_confidence, int pullback_score, int mtf_score, int adx_score,
                  int vol_score, int pat_score,
                  string pullback_desc, string mtf_desc, string adx_desc, 
                  string volume_desc, string pattern_desc, string price_pos_desc,
                  bool is_rejected = false, string reject_reason = "")
{
   double pb_pct = ((trend == TREND_UP) ? 
                     (range_high - entry_price) / (range_high - range_low) * 100 : 
                     (entry_price - range_low) / (range_high - range_low) * 100);
   
   if(is_rejected)
   {
      StoreFailedTrade(entry_price, trend, reject_reason, total_confidence, pb_pct);
      return;
   }
   
   if(trend == TREND_UP && buys_paused)
   {
      status_reason = "BUYS PAUSED";
      status_progress = "PAUSED";
      return;
   }
   
   if(trend == TREND_DOWN && sells_paused)
   {
      status_reason = "SELLS PAUSED";
      status_progress = "PAUSED";
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
      status_reason = "MAX POSITIONS REACHED (" + IntegerToString(GetMaxPositions()) + ")";
      status_progress = "LIMIT";
      StoreFailedTrade(entry_price, trend, "Max Positions", total_confidence, pb_pct);
      return;
   }
   
   if(Enable_Daily_Limit && !CheckDailyTradeLimit())
   {
      status_reason = "DAILY LIMIT REACHED";
      status_progress = "LIMIT";
      StoreFailedTrade(entry_price, trend, "Daily Limit", total_confidence, pb_pct);
      return;
   }
   
   double risk = MathAbs(entry_price - sl_price);
   double reward = MathAbs(tp_price - entry_price);
   double rr_ratio = reward / risk;
   
   if(rr_ratio < MinRR)
   {
      status_reason = "RR TOO LOW (" + DoubleToString(rr_ratio, 2) + ")";
      status_progress = "REJECTED: RR";
      StoreFailedTrade(entry_price, trend, "RR " + DoubleToString(rr_ratio, 2), total_confidence, pb_pct);
      return;
   }
   
   double lot_size = CalculateLotSize();
   
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
      success = trade.Buy(lot_size, _Symbol, price, sl, tp, "DayTrade_Buy");
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = sl_price;
      tp = tp_price;
      type_str = "SELL";
      success = trade.Sell(lot_size, _Symbol, price, sl, tp, "DayTrade_Sell");
   }
   
   if(success)
   {
      positionTicket = trade.ResultOrder();
      has_open_position = true;
      current_trade_direction = trend;
      
      daily_trades++;
      
      StoreSuccessfulTrade(price, trend, total_confidence, pb_pct);
      
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
      else if(total_confidence >= 50)
         confidence_label = "LOW";
      else
         confidence_label = "VERY LOW";
      
      status_in_trade = "YES";
      status_reason = type_str + " OPENED";
      status_progress = type_str + " @ " + DoubleToString(price, _Digits);
      status_confidence = IntegerToString(total_confidence) + "/100 (" + confidence_label + ")";
      status_lot = DoubleToString(lot_size, 2);
      status_rr = DoubleToString(rr_ratio, 2) + ":1";
      
      LogMessage("=========================================");
      LogMessage("   🟢 DAY TRADE ENTERED   ");
      LogMessage("=========================================");
      LogMessage("Type: " + type_str);
      LogMessage("Ticket: " + IntegerToString(positionTicket));
      LogMessage("Entry: " + DoubleToString(price, _Digits));
      LogMessage("SL: " + DoubleToString(sl, _Digits));
      LogMessage("TP: " + DoubleToString(tp, _Digits));
      LogMessage("RR: " + DoubleToString(rr_ratio, 2) + ":1");
      LogMessage("Lot Size: " + DoubleToString(lot_size, 2));
      LogMessage("Daily Trades: " + IntegerToString(daily_trades) + "/" + IntegerToString(Max_Daily_Trades));
      LogMessage("Max Positions Allowed: " + IntegerToString(GetMaxPositions()));
      
      LogMessage("--- 🎯 Entry Reasons ---");
      LogMessage("Trend: " + (string)((trend_bias == TREND_UP) ? "BULLISH (Price>H1 MA60)" : "BEARISH (Price<H1 MA60)"));
      LogMessage("Entry Signal: Price " + (string)((trend_entry == TREND_UP) ? "ABOVE" : "BELOW") + " M15 MA120");
      LogMessage("Pullback: " + DoubleToString(pb_pct, 1) + "%");
      LogMessage("Range: " + DoubleToString(range_low, _Digits) + " - " + DoubleToString(range_high, _Digits));
      LogMessage("Price Position: " + price_pos_desc);
      
      LogMessage("--- 📊 Confidence Score: " + IntegerToString(total_confidence) + "/100 (" + confidence_label + ") ---");
      LogMessage("📈 Pullback Score: " + IntegerToString(pullback_score) + "/35 - " + pullback_desc);
      LogMessage("⏰ MTF (H1) Score: " + IntegerToString(mtf_score) + "/25 - " + mtf_desc);
      LogMessage("📉 ADX Score: " + IntegerToString(adx_score) + "/15 - " + adx_desc);
      LogMessage("📊 Volume Score: " + IntegerToString(vol_score) + "/15 - " + volume_desc);
      LogMessage("📐 Pattern Score: " + IntegerToString(pat_score) + "/10 - " + pattern_desc);
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
//| Detect Pullback And Execute                                      |
//+------------------------------------------------------------------+
void DetectPullbackAndExecute(MqlRates &rates[], MqlRates &rates_h1[], double &ma_fast[], double &ma_slow[], double &ma_trend[],
                              double &ma_h1_50[], double &ma_h1_21[], double &ma_m15_50[], double &ma_m15_21[], 
                              double &atr[], double &adx_main[], double &adx_plus[], double &adx_minus[])
{
   double current_price = rates[0].close;
   double current_ma_fast = ma_fast[0];
   double current_ma_slow = ma_slow[0];
   double current_ma_trend = ma_trend[0];
   double current_atr = atr[0];
   double current_adx = adx_main[0];
   double current_adx_plus = adx_plus[0];
   double current_adx_minus = adx_minus[0];
   
   ENUM_TREND_DIRECTION final_trend = TREND_NONE;
   
   if(trend_bias == TREND_UP && trend_entry == TREND_UP && !buys_paused)
      final_trend = TREND_UP;
   else if(trend_bias == TREND_DOWN && trend_entry == TREND_DOWN && !sells_paused)
      final_trend = TREND_DOWN;
   
   if(final_trend == TREND_NONE)
   {
      if(!has_open_position)
      {
         if(trend_bias == TREND_NONE)
            status_reason = "NO H1 TREND";
         else if(trend_entry == TREND_NONE)
            status_reason = "AT MA120";
         else if(buys_paused || sells_paused)
            status_reason = "PAUSED";
         else
            status_reason = "TREND MISMATCH";
      }
      return;
   }
   
   double swing_high = rates[0].high;
   double swing_low = rates[0].low;
   for(int i = 1; i < Range_Period && i < ArraySize(rates); i++)
   {
      if(rates[i].high > swing_high) swing_high = rates[i].high;
      if(rates[i].low < swing_low) swing_low = rates[i].low;
   }
   
   if(swing_high <= swing_low) return;
   
   double pullback_percent = 0;
   double entry_price = 0;
   double tp_price = 0;
   double sl_price = 0;
   bool is_pullback = false;
   int pullback_score = 0;
   int mtf_score = 0;
   int adx_score = 0;
   int total_confidence = 0;
   
   //--- Bullish: 25-85% pullback
   if(final_trend == TREND_UP && current_price < swing_high)
   {
      pullback_percent = (swing_high - current_price) / (swing_high - swing_low);
      if(pullback_percent >= 0.25 && pullback_percent <= 0.85)
      {
         is_pullback = true;
         entry_price = current_price;
         tp_price = swing_high;
      }
   }
   //--- Bearish: 35-85% pullback
   else if(final_trend == TREND_DOWN && current_price > swing_low)
   {
      pullback_percent = (current_price - swing_low) / (swing_high - swing_low);
      if(pullback_percent >= 0.35 && pullback_percent <= 0.85)
      {
         is_pullback = true;
         entry_price = current_price;
         tp_price = swing_low;
      }
   }
   
   double pb_pct = pullback_percent * 100;
   status_pullback = DoubleToString(pb_pct, 1) + "%";
   
   if(is_pullback && !has_open_position)
   {
      pullback_score = CalculatePullbackScore(pb_pct);
      mtf_score = CalculateMTFScore(rates_h1, final_trend);
      adx_score = CalculateADXScore(current_adx, current_adx_plus, current_adx_minus, final_trend);
      
      double vol_ratio = 0;
      volume_score = CalculateVolumeScore(rates, Volume_Period, vol_ratio);
      volume_ratio = vol_ratio;
      pattern_score = CalculatePatternScore(rates, final_trend);
      
      total_confidence = pullback_score + mtf_score + adx_score + volume_score + pattern_score;
      
      bool pullback_ending = (mtf_score >= 15 || adx_score >= 12 || pattern_score >= 8 || volume_score >= 10);
      status_pullback_ending = pullback_ending ? "YES" : "NO";
      
      status_volume = GetVolumeDescription(volume_ratio);
      status_pattern = GetPatternDescription(rates, final_trend);
      
      string pullback_desc = GetPullbackDescription(pb_pct);
      string mtf_desc = GetMTFDescription(rates_h1, final_trend);
      string adx_desc = GetADXDescription(current_adx, current_adx_plus, current_adx_minus, final_trend);
      string adx_level = GetADXLevelLabel(current_adx);
      
      double diff_fast = (current_price - current_ma_fast) / current_ma_fast * 100;
      double diff_trend = (current_price - current_ma_trend) / current_ma_trend * 100;
      string price_pos_desc = StringFormat("Price is %.2f%% %s M15 MA120 and %.2f%% %s H1 MA60",
         MathAbs(diff_fast), (diff_fast > 0) ? "ABOVE" : "BELOW",
         MathAbs(diff_trend), (diff_trend > 0) ? "ABOVE" : "BELOW");
      
      DrawPullbackMarker(current_price, final_trend, pullback_percent, total_confidence);
      
      status_confidence = IntegerToString(total_confidence) + "/100";
      
      if(Enable_Volume_Filter && volume_ratio > 0.01)
      {
         if(volume_ratio < 0.8)
         {
            status_reason = "LOW VOLUME (" + DoubleToString(volume_ratio, 1) + "x)";
            status_progress = "REJECTED: VOLUME";
            LogMessage("❌ REJECTED: Volume too low (" + DoubleToString(volume_ratio, 1) + "x avg)", true);
            ExecuteTrade(final_trend, entry_price, 0, tp_price, total_confidence, 
                         pullback_score, mtf_score, adx_score,
                         volume_score, pattern_score,
                         pullback_desc, mtf_desc, adx_desc, 
                         GetVolumeDescription(volume_ratio), 
                         GetPatternDescription(rates, final_trend), 
                         price_pos_desc, true, "Low Volume");
            return;
         }
      }
      
      if(total_confidence >= Confidence_Threshold && pullback_ending)
      {
         status_reason = "CONFIDENCE MET ✅ - ENTERING";
         status_progress = "ENTERING " + (final_trend == TREND_UP ? "BUY" : "SELL");
         
         LogMessage("✅ CONFIDENCE MET + PULLBACK ENDING - ENTERING TRADE");
         
         sl_price = CalculateOptimalSL(final_trend, entry_price, tp_price, current_ma_fast, current_atr, Target_RR, rates);
         
         ExecuteTrade(final_trend, entry_price, sl_price, tp_price, total_confidence, 
                      pullback_score, mtf_score, adx_score,
                      volume_score, pattern_score,
                      pullback_desc, mtf_desc, adx_desc, 
                      GetVolumeDescription(volume_ratio), 
                      GetPatternDescription(rates, final_trend), 
                      price_pos_desc);
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
            status_reason = "WAITING FOR ENDING";
            status_progress = "WAITING: ENDING";
         }
         
         if(total_confidence >= Confidence_Threshold - 10 && !pullback_ending)
         {
            ExecuteTrade(final_trend, entry_price, 0, tp_price, total_confidence, 
                         pullback_score, mtf_score, adx_score,
                         volume_score, pattern_score,
                         pullback_desc, mtf_desc, adx_desc, 
                         GetVolumeDescription(volume_ratio), 
                         GetPatternDescription(rates, final_trend), 
                         price_pos_desc, true, "Pullback Not Ending");
         }
         else if(total_confidence < Confidence_Threshold - 5)
         {
            ExecuteTrade(final_trend, entry_price, 0, tp_price, total_confidence, 
                         pullback_score, mtf_score, adx_score,
                         volume_score, pattern_score,
                         pullback_desc, mtf_desc, adx_desc, 
                         GetVolumeDescription(volume_ratio), 
                         GetPatternDescription(rates, final_trend), 
                         price_pos_desc, true, "Low Conf");
         }
         
         LogMessage("=== 📊 PULLBACK DETECTED ===");
         LogMessage("Pullback: " + DoubleToString(pb_pct, 1) + "%");
         LogMessage("Pullback Score: " + IntegerToString(pullback_score) + "/35");
         LogMessage("MTF (H1) Score: " + IntegerToString(mtf_score) + "/25");
         LogMessage("ADX Score: " + IntegerToString(adx_score) + "/15 (" + adx_level + ")");
         LogMessage("Volume Score: " + IntegerToString(volume_score) + "/15 (" + GetVolumeDescription(volume_ratio) + ")");
         LogMessage("Pattern Score: " + IntegerToString(pattern_score) + "/10 (" + GetPatternDescription(rates, final_trend) + ")");
         LogMessage("Total Confidence: " + IntegerToString(total_confidence) + "/100");
         LogMessage("Pullback Ending: " + (pullback_ending ? "YES ✅" : "NO ⏳"));
      }
   }
   else if(!is_pullback && !has_open_position)
   {
      double raw_percent = 0;
      if(final_trend == TREND_UP)
         raw_percent = (swing_high - current_price) / (swing_high - swing_low) * 100;
      else if(final_trend == TREND_DOWN)
         raw_percent = (current_price - swing_low) / (swing_high - swing_low) * 100;
      
      if(raw_percent < 25.0 && final_trend == TREND_UP)
      {
         status_reason = "PULLBACK TOO SHALLOW (" + DoubleToString(raw_percent, 1) + "%)";
         status_progress = "WAITING: PULLBACK";
      }
      else if(raw_percent < 35.0 && final_trend == TREND_DOWN)
      {
         status_reason = "PULLBACK TOO SHALLOW (" + DoubleToString(raw_percent, 1) + "%)";
         status_progress = "WAITING: PULLBACK";
      }
      else if(raw_percent > 85.0)
      {
         status_reason = "PULLBACK TOO DEEP (" + DoubleToString(raw_percent, 1) + "%)";
         status_progress = "WAITING: RETEST";
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
   ObjectSetInteger(0, prefix + "Label", OBJPROP_FONTSIZE, 11);
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
   
   if(PositionSelectByTicket(posTicket))
   {
      profitTrackers[index].posTicket = posTicket;
      profitTrackers[index].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      profitTrackers[index].tpPrice = PositionGetDouble(POSITION_TP);
      profitTrackers[index].posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   }
   
   profitTrackers[index].highestPercentSeen = 0;
   profitTrackers[index].breakevenProcessed = false;
   profitTrackers[index].sl20PercentProcessed = false;
   profitTrackers[index].sl50PercentProcessed = false;
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
   
   targetProfit = ((tp - entry) / tickSize) * tickValue * volume;
   
   if(targetProfit <= 0)
      return 0;
   
   double percentToTP = (profit / targetProfit) * 100.0;
   return MathMax(0, MathMin(100, percentToTP));
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Breakeven (FIXED)                              |
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
      LogMessage("✅ [30%] Breakeven + buffer at " + DoubleToString(newSL, _Digits));
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
//| Move Stop Loss to Percentage of Target Profit (FIXED)           |
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
      string label = (percentProfit == 20.0) ? "[50%] 20% profit locked" : "[75%] 50% profit locked";
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
//| Manage Profits                                                   |
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
   
   status_profit = "$" + DoubleToString(profit, 2);
   
   if(tpPrice <= 0 || profit <= 0)
      return;
   
   double targetProfit = 0;
   double percentToTP = CalculatePercentToTP(positionTicket, targetProfit);
   
   if(percentToTP <= 0)
      return;
   
   if(percentToTP > profitTrackers[trackerIdx].highestPercentSeen)
      profitTrackers[trackerIdx].highestPercentSeen = percentToTP;
   
   double currentPercent = percentToTP;
   
   //--- 1. BREAKEVEN at 30%
   if(!profitTrackers[trackerIdx].breakevenProcessed && currentPercent >= Breakeven_Threshold)
   {
      bool slBelowEntry = (posType == POSITION_TYPE_BUY && slPrice < entryPrice);
      bool slAboveEntry = (posType == POSITION_TYPE_SELL && slPrice > entryPrice);
      
      if(slBelowEntry || slAboveEntry)
      {
         if(MoveToBreakeven(positionTicket, entryPrice, tpPrice))
         {
            profitTrackers[trackerIdx].breakevenProcessed = true;
            LogMessage("📊 [30%] Breakeven + buffer locked at " + DoubleToString(currentPercent, 1) + "% of TP");
         }
      }
   }
   
   //--- 2. SL TO 20% PROFIT at 50%
   if(profitTrackers[trackerIdx].breakevenProcessed && 
      !profitTrackers[trackerIdx].sl20PercentProcessed && 
      currentPercent >= SL_20Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 20.0))
      {
         profitTrackers[trackerIdx].sl20PercentProcessed = true;
         LogMessage("📊 [50%] 20% profit locked at " + DoubleToString(currentPercent, 1) + "% of TP");
      }
   }
   
   //--- 3. SL TO 50% PROFIT at 75%
   if(profitTrackers[trackerIdx].sl20PercentProcessed && 
      !profitTrackers[trackerIdx].sl50PercentProcessed && 
      currentPercent >= SL_50Percent_Threshold)
   {
      if(MoveSLToProfitPercent(positionTicket, entryPrice, tpPrice, 50.0))
      {
         profitTrackers[trackerIdx].sl50PercentProcessed = true;
         LogMessage("📊 [75%] 50% profit locked at " + DoubleToString(currentPercent, 1) + "% of TP");
      }
   }
}
//+------------------------------------------------------------------+