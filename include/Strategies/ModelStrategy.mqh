//+------------------------------------------------------------------+
//|                        CRT_Model1_EA.mq5                         |
//|                    CRT Model 1 Entry Strategy                     |
//|                    Time-Based Range + Liquidity Sweep            |
//|                    + Retracement Entry                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.00"
#property strict

// ============================================================
// INPUT PARAMETERS
// ============================================================
input group "=== CRT RANGE SETTINGS ==="
input int      InpRangeStartHour = 8;      // Range Start Hour (UTC)
input int      InpRangeStartMinute = 0;    // Range Start Minute
input int      InpRangeEndHour = 9;        // Range End Hour (UTC)
input int      InpRangeEndMinute = 0;      // Range End Minute

input group "=== ENTRY SETTINGS ==="
input int      InpSLBufferPips = 10;       // SL Buffer (pips)
input int      InpTPOption = 1;            // TP Option: 1=Opposite Side, 2=50% Range, 3=RR Multiple
input double   InpTPRRMultiple = 2.0;      // TP RR Multiple (if Option 3)
input int      InpTradingDeadlineHour = 16;// Trading Deadline Hour (UTC)
input int      InpTradingDeadlineMinute = 0;

input group "=== RISK MANAGEMENT ==="
input double   InpLotSize = 0.01;          // Lot Size
input int      InpMaxPositions = 1;        // Max Open Positions
input int      InpMaxSlippage = 10;        // Max Slippage (points)

input group "=== DISPLAY ==="
input bool     InpShowDashboard = true;    // Show Dashboard

// ============================================================
// INCLUDES
// ============================================================
#include <Trade\Trade.mqh>

// ============================================================
// GLOBAL VARIABLES
// ============================================================
CTrade          g_trade;
int             g_magicNumber = 123456;
string          g_symbol;
ENUM_TIMEFRAMES g_timeframe = PERIOD_M5;

// CRT Range Data
struct CRTData
{
   datetime    rangeStart;
   datetime    rangeEnd;
   double      rangeHigh;
   double      rangeLow;
   bool        isValid;
   bool        rangeActive;
   datetime    sweepTime;
   datetime    retracementTime;
   bool        entryTriggered;
   bool        positionOpened;
   int         direction;  // 1=Buy, -1=Sell, 0=None
};

CRTData g_crtData;

// Position tracking
ulong g_ticket = 0;
datetime g_lastBarTime = 0;

// Dashboard
string g_dashPrefix = "CRT_DASH_";

// ============================================================
// INITIALIZATION
// ============================================================
int OnInit()
{
   g_symbol = _Symbol;
   g_trade.SetExpertMagicNumber(g_magicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   
   ZeroMemory(g_crtData);
   
   Print("=== CRT MODEL 1 EA INITIALIZED ===");
   Print("   Range: ", InpRangeStartHour, ":", InpRangeStartMinute, " - ", 
         InpRangeEndHour, ":", InpRangeEndMinute, " UTC");
   Print("   TP Option: ", InpTPOption, " | RR: ", InpTPRRMultiple);
   Print("   Trading Deadline: ", InpTradingDeadlineHour, ":", InpTradingDeadlineMinute, " UTC");
   Print("   Lot Size: ", InpLotSize);
   Print("=========================================");
   
   if(InpShowDashboard)
      CreateDashboard();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_dashPrefix);
   Print("=== CRT MODEL 1 EA SHUTDOWN ===");
}

//+------------------------------------------------------------------+
//| TICK HANDLER                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we're past trading deadline
   if(IsPastDeadline())
      return;
   
   // Check for new bar (only process on new bar)
   datetime currentBarTime = iTime(g_symbol, g_timeframe, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;
   
   // Step 1: Define CRT Range
   UpdateCRTRange();
   
   // Step 2: Check for Liquidity Sweep
   CheckLiquiditySweep();
   
   // Step 3: Check for Retracement Entry
   CheckRetracementEntry();
   
   // Step 4: Manage Positions
   ManagePositions();
   
   // Update Dashboard
   if(InpShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| STEP 1: DEFINE CRT RANGE                                        |
//+------------------------------------------------------------------+
void UpdateCRTRange()
{
   datetime now = TimeCurrent();
   datetime todayStart = StringToTime(TimeToString(now, TIME_DATE));
   
   // Calculate range start and end times
   datetime rangeStart = todayStart + (InpRangeStartHour * 3600) + (InpRangeStartMinute * 60);
   datetime rangeEnd = todayStart + (InpRangeEndHour * 3600) + (InpRangeEndMinute * 60);
   
   // If range end is after start (normal case)
   if(rangeEnd <= rangeStart)
      rangeEnd = rangeStart + 3600;  // Default to 1 hour if invalid
   
   // Check if we're within range time
   bool inRangeTime = (now >= rangeStart && now < rangeEnd);
   
   // If range just started, reset data
   if(inRangeTime && !g_crtData.rangeActive)
   {
      g_crtData.rangeStart = rangeStart;
      g_crtData.rangeEnd = rangeEnd;
      g_crtData.rangeHigh = 0;
      g_crtData.rangeLow = DBL_MAX;
      g_crtData.isValid = false;
      g_crtData.rangeActive = true;
      g_crtData.entryTriggered = false;
      g_crtData.positionOpened = false;
      g_crtData.direction = 0;
      g_crtData.sweepTime = 0;
      g_crtData.retracementTime = 0;
      Print("🟦 CRT Range started: ", TimeToString(rangeStart), " - ", TimeToString(rangeEnd));
   }
   
   // Calculate range high/low if in range time
   if(g_crtData.rangeActive)
   {
      int startBar = iBarShift(g_symbol, g_timeframe, rangeStart);
      int endBar = iBarShift(g_symbol, g_timeframe, now);
      int totalBars = startBar - endBar;
      
      if(totalBars > 0)
      {
         double highBuffer[], lowBuffer[];
         ArraySetAsSeries(highBuffer, true);
         ArraySetAsSeries(lowBuffer, true);
         
         if(CopyHigh(g_symbol, g_timeframe, endBar, totalBars, highBuffer) > 0 &&
            CopyLow(g_symbol, g_timeframe, endBar, totalBars, lowBuffer) > 0)
         {
            g_crtData.rangeHigh = highBuffer[ArrayMaximum(highBuffer, 0, WHOLE_ARRAY)];
            g_crtData.rangeLow = lowBuffer[ArrayMinimum(lowBuffer, 0, WHOLE_ARRAY)];
            
            if(g_crtData.rangeHigh > 0 && g_crtData.rangeLow > 0 && 
               g_crtData.rangeHigh > g_crtData.rangeLow)
            {
               g_crtData.isValid = true;
            }
         }
      }
   }
   else
   {
      // Range time ended - deactivate
      if(g_crtData.rangeActive)
      {
         g_crtData.rangeActive = false;
         Print("🟦 CRT Range ended: ", TimeToString(rangeStart), " - ", TimeToString(rangeEnd));
         Print("   High: ", DoubleToString(g_crtData.rangeHigh, _Digits));
         Print("   Low: ", DoubleToString(g_crtData.rangeLow, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| STEP 2: CHECK LIQUIDITY SWEEP                                   |
//+------------------------------------------------------------------+
void CheckLiquiditySweep()
{
   // Skip if no valid range, or entry already triggered
   if(!g_crtData.isValid || g_crtData.entryTriggered)
      return;
   
   // Skip if we already have a position
   if(PositionsTotal() >= InpMaxPositions)
      return;
   
   // Get current price
   double currentPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double pointValue = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   
   // Get last 2 candles for sweep detection
   double closeBuffer[];
   ArraySetAsSeries(closeBuffer, true);
   if(CopyClose(g_symbol, g_timeframe, 0, 3, closeBuffer) < 3)
      return;
   
   double close0 = closeBuffer[0];  // Current bar close
   double close1 = closeBuffer[1];  // Previous bar close
   double close2 = closeBuffer[2];  // Bar before previous
   
   double highBuffer[], lowBuffer[];
   ArraySetAsSeries(highBuffer, true);
   ArraySetAsSeries(lowBuffer, true);
   if(CopyHigh(g_symbol, g_timeframe, 0, 2, highBuffer) < 2 ||
      CopyLow(g_symbol, g_timeframe, 0, 2, lowBuffer) < 2)
      return;
   
   double high1 = highBuffer[1];
   double low1 = lowBuffer[1];
   double high0 = highBuffer[0];
   double low0 = lowBuffer[0];
   
   // ═══════════════════════════════════════════════════════════════
   // BUY SETUP: Sweep BELOW CRT LOW, then retracement
   // ═══════════════════════════════════════════════════════════════
   if(g_crtData.direction != -1 && g_crtData.sweepTime == 0)
   {
      // Check if previous candle swept below CRT LOW
      if(low1 < g_crtData.rangeLow && close1 < g_crtData.rangeLow)
      {
         // Sweep detected - store the time
         g_crtData.sweepTime = TimeCurrent();
         g_crtData.direction = 1;  // BUY
         Print("🔵 BUY SWEEP DETECTED!");
         Print("   Price broke below CRT Low: ", DoubleToString(g_crtData.rangeLow, _Digits));
         Print("   Low: ", DoubleToString(low1, _Digits));
      }
   }
   
   // ═══════════════════════════════════════════════════════════════
   // SELL SETUP: Sweep ABOVE CRT HIGH, then retracement
   // ═══════════════════════════════════════════════════════════════
   if(g_crtData.direction != 1 && g_crtData.sweepTime == 0)
   {
      // Check if previous candle swept above CRT HIGH
      if(high1 > g_crtData.rangeHigh && close1 > g_crtData.rangeHigh)
      {
         // Sweep detected - store the time
         g_crtData.sweepTime = TimeCurrent();
         g_crtData.direction = -1;  // SELL
         Print("🔴 SELL SWEEP DETECTED!");
         Print("   Price broke above CRT High: ", DoubleToString(g_crtData.rangeHigh, _Digits));
         Print("   High: ", DoubleToString(high1, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| STEP 3: CHECK RETRACEMENT ENTRY                                 |
//+------------------------------------------------------------------+
void CheckRetracementEntry()
{
   // Skip if no sweep detected or entry already triggered
   if(g_crtData.sweepTime == 0 || g_crtData.entryTriggered)
      return;
   
   // Skip if we already have a position
   if(PositionsTotal() >= InpMaxPositions)
      return;
   
   // Get last 2 candles for retracement detection
   double closeBuffer[];
   ArraySetAsSeries(closeBuffer, true);
   if(CopyClose(g_symbol, g_timeframe, 0, 3, closeBuffer) < 3)
      return;
   
   double close0 = closeBuffer[0];  // Current bar close
   double close1 = closeBuffer[1];  // Previous bar close
   
   double highBuffer[], lowBuffer[];
   ArraySetAsSeries(highBuffer, true);
   ArraySetAsSeries(lowBuffer, true);
   if(CopyHigh(g_symbol, g_timeframe, 0, 2, highBuffer) < 2 ||
      CopyLow(g_symbol, g_timeframe, 0, 2, lowBuffer) < 2)
      return;
   
   double high0 = highBuffer[0];
   double low0 = lowBuffer[0];
   double high1 = highBuffer[1];
   double low1 = lowBuffer[1];
   
   double pointValue = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double currentPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   
   // ═══════════════════════════════════════════════════════════════
   // BUY ENTRY: Previous bar swept BELOW, now retracing ABOVE
   // ═══════════════════════════════════════════════════════════════
   if(g_crtData.direction == 1)
   {
      // Check if current/previous candle retraced back above CRT LOW
      if(close0 > g_crtData.rangeLow)
      {
         // Retracement detected - ENTER BUY
         g_crtData.retracementTime = TimeCurrent();
         g_crtData.entryTriggered = true;
         
         Print("🟢 BUY RETRACEMENT DETECTED!");
         Print("   Price retraced above CRT Low: ", DoubleToString(g_crtData.rangeLow, _Digits));
         Print("   Current: ", DoubleToString(currentPrice, _Digits));
         
         // Execute BUY trade
         ExecuteTrade(1);
      }
   }
   
   // ═══════════════════════════════════════════════════════════════
   // SELL ENTRY: Previous bar swept ABOVE, now retracing BELOW
   // ═══════════════════════════════════════════════════════════════
   if(g_crtData.direction == -1)
   {
      // Check if current/previous candle retraced back below CRT HIGH
      if(close0 < g_crtData.rangeHigh)
      {
         // Retracement detected - ENTER SELL
         g_crtData.retracementTime = TimeCurrent();
         g_crtData.entryTriggered = true;
         
         Print("🔴 SELL RETRACEMENT DETECTED!");
         Print("   Price retraced below CRT High: ", DoubleToString(g_crtData.rangeHigh, _Digits));
         Print("   Current: ", DoubleToString(currentPrice, _Digits));
         
         // Execute SELL trade
         ExecuteTrade(-1);
      }
   }
}

//+------------------------------------------------------------------+
//| STEP 4: EXECUTE TRADE                                           |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction)
{
   if(PositionsTotal() >= InpMaxPositions)
   {
      Print("❌ Max positions reached. Trade not executed.");
      return;
   }
   
   double pointValue = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double currentPrice = direction == 1 ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) 
                                        : SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double slBuffer = InpSLBufferPips * pointValue;
   
   double entryPrice = currentPrice;
   double stopLoss = 0;
   double takeProfit = 0;
   
   if(direction == 1)  // BUY
   {
      entryPrice = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      stopLoss = g_crtData.rangeLow - slBuffer;
      
      // Calculate TP based on selected option
      switch(InpTPOption)
      {
         case 1:  // Opposite side of range
            takeProfit = g_crtData.rangeHigh;
            break;
         case 2:  // 50% of range
            takeProfit = entryPrice + ((g_crtData.rangeHigh - g_crtData.rangeLow) * 0.5);
            break;
         case 3:  // RR Multiple
            takeProfit = entryPrice + ((entryPrice - stopLoss) * InpTPRRMultiple);
            break;
         default:
            takeProfit = g_crtData.rangeHigh;
      }
   }
   else  // SELL
   {
      entryPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      stopLoss = g_crtData.rangeHigh + slBuffer;
      
      // Calculate TP based on selected option
      switch(InpTPOption)
      {
         case 1:  // Opposite side of range
            takeProfit = g_crtData.rangeLow;
            break;
         case 2:  // 50% of range
            takeProfit = entryPrice - ((g_crtData.rangeHigh - g_crtData.rangeLow) * 0.5);
            break;
         case 3:  // RR Multiple
            takeProfit = entryPrice - ((stopLoss - entryPrice) * InpTPRRMultiple);
            break;
         default:
            takeProfit = g_crtData.rangeLow;
      }
   }
   
   // Validate TP and SL
   if(direction == 1)
   {
      if(stopLoss >= entryPrice || takeProfit <= entryPrice)
      {
         Print("❌ Invalid SL/TP levels for BUY");
         return;
      }
   }
   else
   {
      if(stopLoss <= entryPrice || takeProfit >= entryPrice)
      {
         Print("❌ Invalid SL/TP levels for SELL");
         return;
      }
   }
   
   // Execute trade
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.symbol = g_symbol;
   request.volume = InpLotSize;
   request.deviation = InpMaxSlippage;
   request.magic = g_magicNumber;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.comment = direction == 1 ? "CRT BUY" : "CRT SELL";
   
   if(direction == 1)
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   }
   else
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   }
   
   if(g_trade.OrderSend(request, result))
   {
      g_crtData.positionOpened = true;
      g_ticket = result.order;
      
      Print("✅ TRADE EXECUTED!");
      Print("   Ticket: ", result.order);
      Print("   Direction: ", direction == 1 ? "BUY" : "SELL");
      Print("   Entry: ", DoubleToString(entryPrice, _Digits));
      Print("   SL: ", DoubleToString(stopLoss, _Digits));
      Print("   TP: ", DoubleToString(takeProfit, _Digits));
      Print("   RR: ", DoubleToString((takeProfit - entryPrice) / (entryPrice - stopLoss), 2), ":1");
   }
   else
   {
      Print("❌ Trade failed: ", result.retcode, " - ", result.comment);
      g_crtData.entryTriggered = false;
   }
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS                                                |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // Check if position is still open
   if(g_ticket > 0)
   {
      if(!PositionSelectByTicket(g_ticket))
      {
         g_ticket = 0;
         g_crtData.positionOpened = false;
      }
   }
   
   // Check if we've reached trading deadline
   if(IsPastDeadline())
   {
      // Close any open positions if past deadline
      if(g_ticket > 0)
      {
         Print("⏰ Trading deadline reached. Closing position.");
         g_trade.PositionClose(g_ticket);
         g_ticket = 0;
         g_crtData.positionOpened = false;
      }
   }
}

//+------------------------------------------------------------------+
//| CHECK TRADING DEADLINE                                          |
//+------------------------------------------------------------------+
bool IsPastDeadline()
{
   datetime now = TimeCurrent();
   datetime todayStart = StringToTime(TimeToString(now, TIME_DATE));
   datetime deadline = todayStart + (InpTradingDeadlineHour * 3600) + (InpTradingDeadlineMinute * 60);
   
   return (now >= deadline);
}

//+------------------------------------------------------------------+
//| CREATE DASHBOARD                                                |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int x = 10;
   int y = 30;
   
   ObjectCreate(0, g_dashPrefix + "Box", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_YSIZE, 180);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_BACK, true);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_dashPrefix + "Box", OBJPROP_SELECTABLE, false);
   
   CreateLabel(g_dashPrefix + "Title", "CRT MODEL 1 EA", x, y, clrWhite, 11, true);
   y += 20;
   
   CreateLabel(g_dashPrefix + "Range", "Range: " + IntegerToString(InpRangeStartHour) + ":" + 
               IntegerToString(InpRangeStartMinute) + " - " + IntegerToString(InpRangeEndHour) + 
               ":" + IntegerToString(InpRangeEndMinute), x, y, clrLightGray, 9, false);
   y += 16;
   
   CreateLabel(g_dashPrefix + "Status", "Status: Waiting", x, y, clrYellow, 9, false);
   y += 16;
   
   CreateLabel(g_dashPrefix + "Direction", "Direction: None", x, y, clrGray, 9, false);
   y += 16;
   
   CreateLabel(g_dashPrefix + "Sweep", "Sweep: None", x, y, clrGray, 9, false);
   y += 16;
   
   CreateLabel(g_dashPrefix + "Entry", "Entry: None", x, y, clrGray, 9, false);
   y += 16;
   
   CreateLabel(g_dashPrefix + "Position", "Position: None", x, y, clrGray, 9, false);
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD                                                |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string status = "Waiting";
   color statusColor = clrYellow;
   
   if(g_crtData.entryTriggered)
   {
      status = "Entry Triggered";
      statusColor = clrLimeGreen;
   }
   else if(g_crtData.sweepTime > 0)
   {
      status = "Sweep Detected";
      statusColor = clrOrange;
   }
   else if(g_crtData.isValid && g_crtData.rangeActive)
   {
      status = "Range Active";
      statusColor = clrDodgerBlue;
   }
   
   string directionStr = "None";
   color dirColor = clrGray;
   if(g_crtData.direction == 1) { directionStr = "BUY"; dirColor = clrLimeGreen; }
   else if(g_crtData.direction == -1) { directionStr = "SELL"; dirColor = clrRed; }
   
   string sweepStr = g_crtData.sweepTime > 0 ? TimeToString(g_crtData.sweepTime, TIME_MINUTES) : "None";
   string entryStr = g_crtData.retracementTime > 0 ? TimeToString(g_crtData.retracementTime, TIME_MINUTES) : "None";
   string posStr = PositionsTotal() > 0 ? "Open" : "None";
   color posColor = PositionsTotal() > 0 ? clrLimeGreen : clrGray;
   
   CreateLabel(g_dashPrefix + "Status", "Status: " + status, 10, 66, statusColor, 9, false);
   CreateLabel(g_dashPrefix + "Direction", "Direction: " + directionStr, 10, 82, dirColor, 9, false);
   CreateLabel(g_dashPrefix + "Sweep", "Sweep: " + sweepStr, 10, 98, clrLightGray, 9, false);
   CreateLabel(g_dashPrefix + "Entry", "Entry: " + entryStr, 10, 114, clrLightGray, 9, false);
   CreateLabel(g_dashPrefix + "Position", "Position: " + posStr, 10, 130, posColor, 9, false);
}

//+------------------------------------------------------------------+
//| CREATE LABEL                                                    |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool bold)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| MANUAL FUNCTIONS FOR TESTING                                    |
//+------------------------------------------------------------------+
void ShowStatus()
{
   Print("=== CRT MODEL 1 STATUS ===");
   Print("Range Active: ", g_crtData.rangeActive);
   Print("Range High: ", DoubleToString(g_crtData.rangeHigh, _Digits));
   Print("Range Low: ", DoubleToString(g_crtData.rangeLow, _Digits));
   Print("Direction: ", g_crtData.direction == 1 ? "BUY" : g_crtData.direction == -1 ? "SELL" : "NONE");
   Print("Sweep: ", g_crtData.sweepTime > 0 ? TimeToString(g_crtData.sweepTime) : "None");
   Print("Entry: ", g_crtData.retracementTime > 0 ? TimeToString(g_crtData.retracementTime) : "None");
   Print("Position Open: ", g_crtData.positionOpened);
   Print("========================");
}