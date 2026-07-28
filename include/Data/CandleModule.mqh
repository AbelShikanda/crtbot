

//+------------------------------------------------------------------+
//| CheckCandleDirectionHTF_LTF - HTF + LTF Exhaustion             |
//+------------------------------------------------------------------+
bool CheckCandleDirectionHTF_LTF(int trendDirection, string &candleType)
{
   if(!InpRequireCandleDirection)
   {
      candleType = "FILTER OFF";
      return true;
   }
   
   // ─── HTF (M15) CANDLE DATA ───
   double htfOpen = iOpen(_Symbol, InpTrendTF, 0);
   double htfClose = iClose(_Symbol, InpTrendTF, 0);
   double htfPrevClose = iClose(_Symbol, InpTrendTF, 1);
   double htfPrevLow = iLow(_Symbol, InpTrendTF, 1);
   double htfPrevPrevLow = iLow(_Symbol, InpTrendTF, 2);
   double htfPrevHigh = iHigh(_Symbol, InpTrendTF, 1);
   double htfPrevPrevHigh = iHigh(_Symbol, InpTrendTF, 2);
   
   // ─── LTF (M1) CANDLE DATA ───
   double ltfOpen = iOpen(_Symbol, InpEntryTF, 0);
   double ltfPrevClose = iClose(_Symbol, InpEntryTF, 1);
   double ltfPrevLow = iLow(_Symbol, InpEntryTF, 1);
   double ltfPrevPrevLow = iLow(_Symbol, InpEntryTF, 2);
   double ltfPrevHigh = iHigh(_Symbol, InpEntryTF, 1);
   double ltfPrevPrevHigh = iHigh(_Symbol, InpEntryTF, 2);
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(htfOpen == 0 || htfClose == 0 || ltfOpen == 0)
   {
      candleType = "NO DATA";
      return false;
   }
   
   double tol = pointValue * 2;
   
   // ─── HTF: EXHAUSTION CHECK ───
   bool htfOpenInFavorBull = (htfOpen >= htfPrevClose - tol);
   bool htfOpenInFavorBear = (htfOpen <= htfPrevClose + tol);
   bool htfPullbackSlowingBull = (htfPrevLow >= htfPrevPrevLow);
   bool htfPullbackSlowingBear = (htfPrevHigh <= htfPrevPrevHigh);
   bool htfExhaustionBull = htfOpenInFavorBull && htfPullbackSlowingBull;
   bool htfExhaustionBear = htfOpenInFavorBear && htfPullbackSlowingBear;
   
   // ─── LTF: EXHAUSTION CHECK ───
   bool ltfOpenInFavorBull = (ltfOpen >= ltfPrevClose - tol);
   bool ltfOpenInFavorBear = (ltfOpen <= ltfPrevClose + tol);
   bool ltfPullbackSlowingBull = (ltfPrevLow >= ltfPrevPrevLow);
   bool ltfPullbackSlowingBear = (ltfPrevHigh <= ltfPrevPrevHigh);
   bool ltfExhaustionBull = ltfOpenInFavorBull && ltfPullbackSlowingBull;
   bool ltfExhaustionBear = ltfOpenInFavorBear && ltfPullbackSlowingBear;
   
   // ─── DECISION: BULLISH TREND ───
   if(trendDirection == 1)
   {
      // HTF must show exhaustion OR strong momentum
      if(!htfExhaustionBull)
      {
         candleType = "HTF NO EXHAUSTION ❌";
         return false;
      }
      
      // LTF must show exhaustion OR pullback slowing
      if(ltfExhaustionBull || ltfPullbackSlowingBull)
      {
         candleType = (ltfExhaustionBull) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         return true;
      }
      else
      {
         candleType = "LTF ACTIVE PULLBACK ❌";
         return false;
      }
   }
   
   // ─── DECISION: BEARISH TREND ───
   else if(trendDirection == -1)
   {
      // HTF must show exhaustion OR strong momentum
      if(!htfExhaustionBear)
      {
         candleType = "HTF NO EXHAUSTION ❌";
         return false;
      }
      
      // LTF must show exhaustion OR pullback slowing
      if(ltfExhaustionBear || ltfPullbackSlowingBear)
      {
         candleType = (ltfExhaustionBear) ? "HTF+LTF EXHAUSTION ✅" : "HTF OK + LTF SLOWING ✅";
         return true;
      }
      else
      {
         candleType = "LTF ACTIVE PULLBACK ❌";
         return false;
      }
   }
   else
   {
      candleType = "NEUTRAL TREND (skipped)";
      return true;
   }
}