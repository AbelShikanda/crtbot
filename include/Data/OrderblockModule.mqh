//+------------------------------------------------------------------+
//|                        OrderblockModule.mqh                     |
//|                    H4 Order Block Display Module                 |
//|                    Shows ONLY Reversal and Engulfing OBs        |
//|                    v2.05 - CLEAN - NO DEBUG                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.05"

#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| DEBUG TOGGLE - Set to false to disable all debug output         |
//+------------------------------------------------------------------+
bool g_debugOB = false;

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
//| Order Block Display Class                                        |
//+------------------------------------------------------------------+
class COrderBlockDisplay
{
private:
   string m_symbol;
   string m_prefix;
   ENUM_TIMEFRAMES m_tf;
   int m_maxBlocks;
   bool m_debug;
   
   OrderBlock m_blocksAboveArray[];
   OrderBlock m_blocksBelowArray[];
   int m_totalBlocksAbove;
   int m_totalBlocksBelow;
   
   int m_method1Count;
   int m_method2Count;
   int m_method3Count;
   
   void DetectOrderBlocks();
   bool IsBullishEngulfing(int index, double &open[], double &high[], double &low[], double &close[]);
   bool IsBearishEngulfing(int index, double &open[], double &high[], double &low[], double &close[]);
   bool IsStrongReversalCandle(int index, double &open[], double &high[], double &low[], double &close[]);
   bool IsStrongTrendCandle(int index, double &open[], double &high[], double &low[], double &close[]);
   bool ConfirmMove(int index, double &close[], double &high[], double &low[], bool isBullish);
   bool ConfirmMoveQuick(int index, double &close[], double &high[], double &low[], bool isBullish);
   void AddOrderBlock(double high, double low, double open, double close, datetime time, bool isCandleBullish, int strength, int methodType);
   void SortBlocks();
   void ClearBlocks();
   void DrawOrderBlock(OrderBlock &ob, int position, bool isAbove);
   color GetOrderBlockColor(bool isBullish, bool isMitigated);
   bool ShouldIncludeBlock(int methodType);
   
public:
   COrderBlockDisplay(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_H4);
   ~COrderBlockDisplay();
   
   void SetMaxBlocks(int blocks) { m_maxBlocks = blocks; }
   void EnableDebug(bool enable) { m_debug = enable; }
   void Update();
   void ClearDrawings();
   void PrintOrderBlocks();
   
   int GetTotalBlocksAbove() { return m_totalBlocksAbove; }
   int GetTotalBlocksBelow() { return m_totalBlocksBelow; }
   OrderBlock GetBlockAbove(int index);
   OrderBlock GetBlockBelow(int index);
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
COrderBlockDisplay::COrderBlockDisplay(string symbol, ENUM_TIMEFRAMES tf)
{
   m_symbol = (symbol == NULL) ? _Symbol : symbol;
   m_tf = tf;
   m_prefix = "OB_" + m_symbol + "_";
   m_maxBlocks = 10;
   m_debug = false;
   m_totalBlocksAbove = 0;
   m_totalBlocksBelow = 0;
   
   m_method1Count = 0;
   m_method2Count = 0;
   m_method3Count = 0;
   
   ArrayResize(m_blocksAboveArray, 0);
   ArrayResize(m_blocksBelowArray, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
COrderBlockDisplay::~COrderBlockDisplay()
{
   ClearDrawings();
}

//+------------------------------------------------------------------+
//| SHOULD INCLUDE BLOCK                                             |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::ShouldIncludeBlock(int methodType)
{
   return (methodType == 1 || methodType == 2);
}

//+------------------------------------------------------------------+
//| DETECT ORDER BLOCKS                                              |
//+------------------------------------------------------------------+
void COrderBlockDisplay::DetectOrderBlocks()
{
   ClearBlocks();
   
   m_method1Count = 0;
   m_method2Count = 0;
   m_method3Count = 0;
   
   int bars = 100;
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyOpen(m_symbol, m_tf, 0, bars, open) < bars ||
      CopyHigh(m_symbol, m_tf, 0, bars, high) < bars ||
      CopyLow(m_symbol, m_tf, 0, bars, low) < bars ||
      CopyClose(m_symbol, m_tf, 0, bars, close) < bars)
   {
      return;
   }
   
   for(int i = 10; i < bars - 10; i++)
   {
      bool isCandleBullish = (close[i] > open[i]);
      
      if(IsBullishEngulfing(i, open, high, low, close) || 
         IsBearishEngulfing(i, open, high, low, close))
      {
         if(ConfirmMove(i, close, high, low, isCandleBullish))
         {
            AddOrderBlock(high[i], low[i], open[i], close[i], 
                         iTime(m_symbol, m_tf, i), isCandleBullish, 3, 1);
            m_method1Count++;
            continue;
         }
      }
      
      if(IsStrongReversalCandle(i, open, high, low, close))
      {
         if(ConfirmMove(i, close, high, low, isCandleBullish))
         {
            AddOrderBlock(high[i], low[i], open[i], close[i], 
                         iTime(m_symbol, m_tf, i), isCandleBullish, 2, 2);
            m_method2Count++;
            continue;
         }
      }
      
      if(IsStrongTrendCandle(i, open, high, low, close))
      {
         if(ConfirmMoveQuick(i, close, high, low, isCandleBullish))
         {
            m_method3Count++;
            continue;
         }
      }
   }
   
   SortBlocks();
}

//+------------------------------------------------------------------+
//| CHECK BULLISH ENGULFING                                         |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::IsBullishEngulfing(int index, double &open[], double &high[], double &low[], double &close[])
{
   if(index + 1 >= ArraySize(close)) return false;
   if(index + 1 >= ArraySize(open)) return false;
   if(index + 1 >= ArraySize(high)) return false;
   if(index + 1 >= ArraySize(low)) return false;
   
   if(close[index] <= open[index]) return false;
   if(close[index+1] >= open[index+1]) return false;
   if(close[index] <= high[index+1]) return false;
   if(open[index] >= low[index+1]) return false;
   
   double bodySize = close[index] - open[index];
   double rangeSize = high[index] - low[index];
   if(rangeSize <= 0) return false;
   if(bodySize < rangeSize * 0.5) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| CHECK BEARISH ENGULFING                                         |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::IsBearishEngulfing(int index, double &open[], double &high[], double &low[], double &close[])
{
   if(index + 1 >= ArraySize(close)) return false;
   if(index + 1 >= ArraySize(open)) return false;
   if(index + 1 >= ArraySize(high)) return false;
   if(index + 1 >= ArraySize(low)) return false;
   
   if(close[index] >= open[index]) return false;
   if(close[index+1] <= open[index+1]) return false;
   if(close[index] >= low[index+1]) return false;
   if(open[index] <= high[index+1]) return false;
   
   double bodySize = open[index] - close[index];
   double rangeSize = high[index] - low[index];
   if(rangeSize <= 0) return false;
   if(bodySize < rangeSize * 0.5) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| CHECK STRONG REVERSAL CANDLE                                    |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::IsStrongReversalCandle(int index, double &open[], double &high[], double &low[], double &close[])
{
   if(index + 1 >= ArraySize(close)) return false;
   if(index + 1 >= ArraySize(open)) return false;
   
   bool isBullish = (close[index] > open[index]);
   bool isBearish = (close[index] < open[index]);
   
   if(!isBullish && !isBearish) return false;
   if(isBullish && close[index+1] >= open[index+1]) return false;
   if(isBearish && close[index+1] <= open[index+1]) return false;
   
   double bodySize = isBullish ? (close[index] - open[index]) : (open[index] - close[index]);
   double rangeSize = high[index] - low[index];
   if(rangeSize <= 0) return false;
   if(bodySize < rangeSize * 0.4) return false;
   if(isBullish && close[index] <= close[index+1]) return false;
   if(isBearish && close[index] >= close[index+1]) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| CHECK STRONG TREND CANDLE                                       |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::IsStrongTrendCandle(int index, double &open[], double &high[], double &low[], double &close[])
{
   bool isBullish = (close[index] > open[index]);
   bool isBearish = (close[index] < open[index]);
   
   if(!isBullish && !isBearish) return false;
   
   double bodySize = isBullish ? (close[index] - open[index]) : (open[index] - close[index]);
   double rangeSize = high[index] - low[index];
   if(rangeSize <= 0) return false;
   if(bodySize < rangeSize * 0.3) return false;
   
   double upperWick = high[index] - MathMax(open[index], close[index]);
   double lowerWick = MathMin(open[index], close[index]) - low[index];
   
   if(isBullish && upperWick > bodySize) return false;
   if(isBearish && lowerWick > bodySize) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| CONFIRM MOVE                                                    |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::ConfirmMove(int index, double &close[], double &high[], double &low[], bool isBullish)
{
   int confirmBars = 5;
   if(index - confirmBars < 0) confirmBars = index;
   if(confirmBars < 2) return false;
   
   double moveTotal = 0;
   int validBars = 0;
   
   for(int i = 1; i <= confirmBars; i++)
   {
      if(index - i < 0 || index - i - 1 < 0) continue;
      if(index - i >= ArraySize(close)) continue;
      if(index - i - 1 >= ArraySize(close)) continue;
      
      if(isBullish)
         moveTotal += close[index - i] - close[index - i - 1];
      else
         moveTotal += close[index - i - 1] - close[index - i];
      validBars++;
   }
   
   if(validBars < 2) return false;
   
   double avgRange = 0;
   int rangeBars = 0;
   for(int i = 0; i < 5; i++)
   {
      if(index - i < 0 || index - i >= ArraySize(high) || index - i >= ArraySize(low)) continue;
      avgRange += high[index - i] - low[index - i];
      rangeBars++;
   }
   if(rangeBars == 0) return false;
   avgRange /= rangeBars;
   
   if(avgRange <= 0) return false;
   
   return (moveTotal > avgRange * 0.3);
}

//+------------------------------------------------------------------+
//| QUICK CONFIRM MOVE                                              |
//+------------------------------------------------------------------+
bool COrderBlockDisplay::ConfirmMoveQuick(int index, double &close[], double &high[], double &low[], bool isBullish)
{
   int confirmBars = 3;
   if(index - confirmBars < 0) confirmBars = index;
   if(confirmBars < 2) return false;
   
   double moveTotal = 0;
   int validBars = 0;
   
   for(int i = 1; i <= confirmBars; i++)
   {
      if(index - i < 0 || index - i - 1 < 0) continue;
      if(index - i >= ArraySize(close)) continue;
      if(index - i - 1 >= ArraySize(close)) continue;
      
      if(isBullish)
         moveTotal += close[index - i] - close[index - i - 1];
      else
         moveTotal += close[index - i - 1] - close[index - i];
      validBars++;
   }
   
   if(validBars < 2) return false;
   
   double avgRange = 0;
   int rangeBars = 0;
   for(int i = 0; i < 3; i++)
   {
      if(index - i < 0 || index - i >= ArraySize(high) || index - i >= ArraySize(low)) continue;
      avgRange += high[index - i] - low[index - i];
      rangeBars++;
   }
   if(rangeBars == 0) return false;
   avgRange /= rangeBars;
   
   if(avgRange <= 0) return false;
   
   return (moveTotal > avgRange * 0.2);
}

//+------------------------------------------------------------------+
//| ADD ORDER BLOCK                                                  |
//+------------------------------------------------------------------+
void COrderBlockDisplay::AddOrderBlock(double high, double low, double open, double close, 
                                       datetime time, bool isCandleBullish, int strength, int methodType)
{
   if(!ShouldIncludeBlock(methodType)) return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double blockCenter = (high + low) / 2;
   
   OrderBlock newBlock;
   newBlock.high = high;
   newBlock.low = low;
   newBlock.open = open;
   newBlock.close = close;
   newBlock.time = time;
   newBlock.isMitigated = false;
   newBlock.strength = strength;
   newBlock.isValid = true;
   newBlock.distance = MathAbs(blockCenter - currentPrice);
   newBlock.methodType = methodType;
   
   // Bullish OB = formed from DOWN candle (isCandleBullish = false)
   // Bearish OB = formed from UP candle (isCandleBullish = true)
   newBlock.isBullish = !isCandleBullish;
   
   int testBars = 50;
   double testHigh[], testLow[];
   ArraySetAsSeries(testHigh, true);
   ArraySetAsSeries(testLow, true);
   if(CopyHigh(m_symbol, m_tf, 0, testBars, testHigh) > 0 &&
      CopyLow(m_symbol, m_tf, 0, testBars, testLow) > 0)
   {
      for(int i = 0; i < testBars; i++)
      {
         if(testHigh[i] >= low && testLow[i] <= high)
         {
            newBlock.isMitigated = true;
            break;
         }
      }
   }
   
   if(blockCenter > currentPrice)
   {
      int idx = ArraySize(m_blocksAboveArray);
      ArrayResize(m_blocksAboveArray, idx + 1);
      m_blocksAboveArray[idx] = newBlock;
   }
   else
   {
      int idx = ArraySize(m_blocksBelowArray);
      ArrayResize(m_blocksBelowArray, idx + 1);
      m_blocksBelowArray[idx] = newBlock;
   }
}

//+------------------------------------------------------------------+
//| SORT BLOCKS                                                     |
//+------------------------------------------------------------------+
void COrderBlockDisplay::SortBlocks()
{
   int countAbove = ArraySize(m_blocksAboveArray);
   for(int i = 0; i < countAbove - 1; i++)
   {
      for(int j = i + 1; j < countAbove; j++)
      {
         if(m_blocksAboveArray[i].distance > m_blocksAboveArray[j].distance)
         {
            OrderBlock temp = m_blocksAboveArray[i];
            m_blocksAboveArray[i] = m_blocksAboveArray[j];
            m_blocksAboveArray[j] = temp;
         }
      }
   }
   
   int countBelow = ArraySize(m_blocksBelowArray);
   for(int i = 0; i < countBelow - 1; i++)
   {
      for(int j = i + 1; j < countBelow; j++)
      {
         if(m_blocksBelowArray[i].distance > m_blocksBelowArray[j].distance)
         {
            OrderBlock temp = m_blocksBelowArray[i];
            m_blocksBelowArray[i] = m_blocksBelowArray[j];
            m_blocksBelowArray[j] = temp;
         }
      }
   }
   
   m_totalBlocksAbove = MathMin(countAbove, m_maxBlocks);
   m_totalBlocksBelow = MathMin(countBelow, m_maxBlocks);
}

//+------------------------------------------------------------------+
//| CLEAR BLOCKS                                                    |
//+------------------------------------------------------------------+
void COrderBlockDisplay::ClearBlocks()
{
   ArrayResize(m_blocksAboveArray, 0);
   ArrayResize(m_blocksBelowArray, 0);
   m_totalBlocksAbove = 0;
   m_totalBlocksBelow = 0;
}

//+------------------------------------------------------------------+
//| GET ORDER BLOCK COLOR                                           |
//+------------------------------------------------------------------+
color COrderBlockDisplay::GetOrderBlockColor(bool isBullish, bool isMitigated)
{
   if(isMitigated)
      return clrGray;
   
   if(isBullish)
      return clrDodgerBlue;
   else
      return clrOrange;
}

//+------------------------------------------------------------------+
//| DRAW ORDER BLOCK - Single Line at OPEN - NO LABELS             |
//+------------------------------------------------------------------+
void COrderBlockDisplay::DrawOrderBlock(OrderBlock &ob, int position, bool isAbove)
{
   color blockColor = GetOrderBlockColor(ob.isBullish, ob.isMitigated);
   
   datetime now = TimeCurrent();
   datetime time1 = ob.time;
   datetime time2 = now + (30 * 24 * 3600);
   double linePrice = ob.open;
   
   string lineName = m_prefix + "Line_" + (isAbove ? "A" : "B") + "_" + IntegerToString(position);
   ObjectDelete(0, lineName);
   
   if(ObjectCreate(0, lineName, OBJ_TREND, 0, time1, linePrice, time2, linePrice))
   {
      ENUM_LINE_STYLE lineStyle = ob.isMitigated ? STYLE_DASH : STYLE_SOLID;
      int lineWidth = ob.isMitigated ? 1 : 2;
      
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, blockColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, linePrice);
   }
}

//+------------------------------------------------------------------+
//| UPDATE                                                          |
//+------------------------------------------------------------------+
void COrderBlockDisplay::Update()
{
   ClearDrawings();
   DetectOrderBlocks();
   
   if(m_totalBlocksAbove == 0 && m_totalBlocksBelow == 0)
      return;
   
   for(int i = 0; i < m_totalBlocksAbove; i++)
      DrawOrderBlock(m_blocksAboveArray[i], i, true);
   
   for(int i = 0; i < m_totalBlocksBelow; i++)
      DrawOrderBlock(m_blocksBelowArray[i], i, false);
}

//+------------------------------------------------------------------+
//| CLEAR DRAWINGS                                                  |
//+------------------------------------------------------------------+
void COrderBlockDisplay::ClearDrawings()
{
   ObjectsDeleteAll(0, m_prefix);
}

//+------------------------------------------------------------------+
//| PRINT ORDER BLOCKS                                              |
//+------------------------------------------------------------------+
void COrderBlockDisplay::PrintOrderBlocks()
{
   if(!m_debug) return;
   
   Print("═══════════════════════════════════════════════════");
   Print("📊 ORDER BLOCKS REPORT");
   Print("═══════════════════════════════════════════════════");
   
   Print("--- ABOVE PRICE (", m_totalBlocksAbove, " blocks) ---");
   for(int i = 0; i < m_totalBlocksAbove; i++)
   {
      OrderBlock ob = m_blocksAboveArray[i];
      Print(StringFormat("  %d. %s | OPEN: %.5f | %s",
                        i+1,
                        ob.isBullish ? "BULL" : "BEAR",
                        ob.open,
                        ob.isMitigated ? "MITIGATED" : "ACTIVE"));
   }
   
   Print("");
   Print("--- BELOW PRICE (", m_totalBlocksBelow, " blocks) ---");
   for(int i = 0; i < m_totalBlocksBelow; i++)
   {
      OrderBlock ob = m_blocksBelowArray[i];
      Print(StringFormat("  %d. %s | OPEN: %.5f | %s",
                        i+1,
                        ob.isBullish ? "BULL" : "BEAR",
                        ob.open,
                        ob.isMitigated ? "MITIGATED" : "ACTIVE"));
   }
   Print("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| GETTERS                                                        |
//+------------------------------------------------------------------+
OrderBlock COrderBlockDisplay::GetBlockAbove(int index)
{
   if(index >= 0 && index < m_totalBlocksAbove)
      return m_blocksAboveArray[index];
   
   OrderBlock empty;
   ZeroMemory(empty);
   empty.isValid = false;
   return empty;
}

OrderBlock COrderBlockDisplay::GetBlockBelow(int index)
{
   if(index >= 0 && index < m_totalBlocksBelow)
      return m_blocksBelowArray[index];
   
   OrderBlock empty;
   ZeroMemory(empty);
   empty.isValid = false;
   return empty;
}