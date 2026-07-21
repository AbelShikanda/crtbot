//+------------------------------------------------------------------+
//|                    NarrativeContent.mqh                           |
//|                    All narratives/stories in one place            |
//|                    v1.0 - EASY TO EDIT - NON-PROGRAMMERS WELCOME |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.0"

//+------------------------------------------------------------------+
//| NARRATIVE TEMPLATES                                              |
//| All stories are stored here - edit freely!                       |
//| Use {PLACEHOLDER} for dynamic data                              |
//+------------------------------------------------------------------+

// ─── STRONG TREND NARRATIVES ──────────────────────────────────────

string STRONG_TREND_BULLISH = 
   "📈 **STRONG BULLISH TREND DETECTED** 📈\n\n"
   "The market is charging higher with impressive momentum! Multiple "
   "indicators are aligned in perfect harmony, confirming the strong "
   "upward trajectory. This is what institutional accumulation looks like.\n\n"
   "**🔍 Key Drivers:**\n"
   "• {ADX_STRENGTH} trend strength at {ADX_VALUE}\n"
   "• {VOLUME_STATUS} volume supporting the move\n"
   "• {PB_ZONE} pullback of {PB_PERCENT}%\n"
   "• RSI at {RSI_VALUE} in {RSI_ZONE} territory\n"
   "• MACD showing {MACD_SIGNAL}\n\n"
   "**📊 Technical Analysis:**\n"
   "The {TREND_DIRECTION} trend is confirmed by {AGREEING}/6 components "
   "with confidence at {CONFIDENCE}%. The ADX at {ADX_VALUE} indicates "
   "strong directional momentum. Volume is {VOLUME_STATUS}, suggesting "
   "institutional participation.\n\n"
   "**🎯 Trading Strategy:**\n"
   "With {RISK_LEVEL} risk, this is a favorable environment for trend-"
   "following strategies. Look for pullbacks to the {PB_ZONE} zone "
   "for optimal entry. Consider scaling into positions as the trend "
   "continues to prove itself.\n\n"
   "**⚠️ Risk Management:**\n"
   "Place stops below recent swing lows. Consider trailing stops to "
   "protect profits as the trend develops. Monitor for signs of "
   "exhaustion or divergence.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

string STRONG_TREND_BEARISH = 
   "📉 **STRONG BEARISH TREND DETECTED** 📉\n\n"
   "The market is in freefall with powerful downward momentum! Multiple "
   "indicators confirm the strong bearish pressure. Sellers are in "
   "complete control of this market.\n\n"
   "**🔍 Key Drivers:**\n"
   "• {ADX_STRENGTH} trend strength at {ADX_VALUE}\n"
   "• {VOLUME_STATUS} volume accelerating the drop\n"
   "• {PB_ZONE} rally of {PB_PERCENT}%\n"
   "• RSI at {RSI_VALUE} in {RSI_ZONE} territory\n"
   "• MACD showing {MACD_SIGNAL}\n\n"
   "**📊 Technical Analysis:**\n"
   "The {TREND_DIRECTION} trend is confirmed by {AGREEING}/6 components "
   "with confidence at {CONFIDENCE}%. The ADX at {ADX_VALUE} indicates "
   "strong directional momentum to the downside. Volume is {VOLUME_STATUS}, "
   "confirming institutional selling.\n\n"
   "**🎯 Trading Strategy:**\n"
   "With {RISK_LEVEL} risk, this is favorable for short positions. "
   "Look for rallies to {PB_ZONE} zones for optimal entry points. "
   "Consider scaling into shorts as the downtrend confirms.\n\n"
   "**⚠️ Risk Management:**\n"
   "Place stops above recent swing highs. Use trailing stops to "
   "protect profits. Watch for potential reversal signals at key "
   "support levels.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── PULLBACK ENTRY NARRATIVES ────────────────────────────────────

string PULLBACK_ENTRY = 
   "🎯 **PULLBACK ENTRY OPPORTUNITY** 🎯\n\n"
   "The market is giving you a gift - a healthy {PB_PERCENT}% "
   "pullback in the {TREND_DIRECTION} trend! This is exactly what "
   "disciplined traders wait for. A {PB_ZONE} pullback offers "
   "high-probability entry in the direction of the trend.\n\n"
   "**🔍 Setup Analysis:**\n"
   "• Pullback zone: {PB_ZONE} ({PB_PERCENT}% retracement)\n"
   "• Trend strength: {ADX_STRENGTH} (ADX: {ADX_VALUE})\n"
   "• Components aligned: {AGREEING}/6\n"
   "• Volume: {VOLUME_STATUS}\n"
   "• RSI: {RSI_VALUE} ({RSI_ZONE})\n\n"
   "**📊 Why This Works:**\n"
   "The {PB_ZONE} zone suggests this is a healthy retracement, "
   "not a reversal. With the overall trend being {TREND_DIRECTION} "
   "and confidence at {CONFIDENCE}%, this is a textbook entry setup. "
   "The {VOLUME_STATUS} volume indicates the pullback is likely "
   "just profit-taking, not a trend change.\n\n"
   "**🎯 Entry Strategy:**\n"
   "Enter on confirmation of pullback completion:\n"
   "• Bullish reversal candle patterns (hammer, engulfing)\n"
   "• RSI turning up from {RSI_ZONE} territory\n"
   "• Volume picking up on the reversal\n"
   "• Break of pullback trendline\n\n"
   "**⚠️ Risk Management:**\n"
   "Place stop-loss beyond the pullback extreme. Target previous "
   "high/low or use a risk-reward ratio of at least 1:2.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── DIVERGENCE NARRATIVES ────────────────────────────────────────

string DIVERGENCE_WARNING = 
   "⚠️ **DIVERGENCE ALERT - CAUTION REQUIRED** ⚠️\n\n"
   "Warning! Warning! The market is showing classic divergence "
   "signals - a potential reversal could be brewing! This is one "
   "of the most reliable leading indicators in technical analysis.\n\n"
   "**🔍 Divergence Details:**\n"
   "• Price making {TREND_DIRECTION} moves\n"
   "• RSI at {RSI_VALUE} in {RSI_ZONE} zone\n"
   "• MACD showing {MACD_SIGNAL}\n"
   "• Components disagreeing: {DISAGREEING}/6\n\n"
   "**📊 What This Means:**\n"
   "Divergence is the market's way of saying 'I'm tired.' The trend "
   "may be losing steam as momentum diverges from price. This often "
   "precedes a trend reversal or significant pullback.\n\n"
   "**🎯 Strategy Options:**\n"
   "1. Tighten stops on existing positions\n"
   "2. Take partial profits if in profit\n"
   "3. Wait for confirmation before new entries\n"
   "4. Consider counter-trend trades with strict risk control\n\n"
   "**⚠️ Important:**\n"
   "Divergence can last longer than expected. Always wait for "
   "confirmation before acting. Look for:\n"
   "• Break of trendline\n"
   "• Key level break\n"
   "• Candlestick reversal patterns\n"
   "• Volume confirmation\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── BREAKOUT NARRATIVES ──────────────────────────────────────────

string BREAKOUT_BULLISH = 
   "🚀 **BULLISH BREAKOUT CONFIRMED** 🚀\n\n"
   "Boom! The market has exploded through resistance with "
   "{VOLUME_STATUS} volume and {ADX_STRENGTH} momentum! This is "
   "a breakout with conviction, suggesting significant new positions "
   "being established by institutional traders.\n\n"
   "**🔍 Breakout Analysis:**\n"
   "• Direction: {TREND_DIRECTION}\n"
   "• Volume: {VOLUME_STATUS} ({VOLUME_RATIO}x average)\n"
   "• Momentum: {ADX_STRENGTH} (ADX: {ADX_VALUE})\n"
   "• Component agreement: {AGREEING}/6\n"
   "• RSI: {RSI_VALUE} in {RSI_ZONE}\n\n"
   "**📊 Why This Matters:**\n"
   "Breakouts with strong volume have the highest probability of "
   "success. With {AGREEING}/6 components confirming and confidence "
   "at {CONFIDENCE}%, this breakout has institutional backing.\n\n"
   "**🎯 Trading Strategy:**\n"
   "Consider entering on:\n"
   "• Retest of breakout level\n"
   "• Pullback to former resistance (now support)\n"
   "• Continued momentum with volume confirmation\n\n"
   "**⚠️ Risk Management:**\n"
   "Place stops below the breakout level. Consider a trailing stop "
   "to ride the trend. Watch for volume to sustain.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

string BREAKOUT_BEARISH = 
   "📊 **BEARISH BREAKOUT CONFIRMED** 📊\n\n"
   "Crash! The market has broken below key support with "
   "{VOLUME_STATUS} volume confirming the breakdown! This is a "
   "significant technical event that could lead to accelerated selling.\n\n"
   "**🔍 Breakout Analysis:**\n"
   "• Direction: {TREND_DIRECTION}\n"
   "• Volume: {VOLUME_STATUS} ({VOLUME_RATIO}x average)\n"
   "• Momentum: {ADX_STRENGTH} (ADX: {ADX_VALUE})\n"
   "• Component agreement: {AGREEING}/6\n"
   "• RSI: {RSI_VALUE} in {RSI_ZONE}\n\n"
   "**📊 Why This Matters:**\n"
   "Breakdowns with strong volume indicate genuine selling pressure "
   "rather than just noise. The {VOLUME_STATUS} volume suggests "
   "institutional sellers are active.\n\n"
   "**🎯 Trading Strategy:**\n"
   "Consider short entries on:\n"
   "• Retest of breakdown level\n"
   "• Rallies to former support (now resistance)\n"
   "• Continued momentum with volume confirmation\n\n"
   "**⚠️ Risk Management:**\n"
   "Place stops above the breakdown level. Use trailing stops to "
   "protect profits. Watch for potential reversal patterns.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── CONFLICT NARRATIVES ──────────────────────────────────────────

string CONFLICT_NARRATIVE = 
   "🔄 **MIXED SIGNALS - WAIT FOR CLARITY** 🔄\n\n"
   "The market is confused! Components are fighting each other "
   "like cats and dogs. This is NOT the time to trade. Let the "
   "market resolve its internal conflict first.\n\n"
   "**🔍 The Current State:**\n"
   "• Agreeing: {AGREEING} components\n"
   "• Disagreeing: {DISAGREEING} components\n"
   "• Neutral: {NEUTRAL} components\n"
   "• Overall confidence: {CONFIDENCE}%\n"
   "• Trend: {TREND_DIRECTION}\n\n"
   "**📊 What's Happening:**\n"
   "The market is at a decision point. Some indicators are saying "
   "one thing while others say the opposite. This usually happens "
   "during:\n"
   "• Key support/resistance levels\n"
   "• Trend exhaustion periods\n"
   "• News-driven volatility\n"
   "• Market uncertainty\n\n"
   "**🎯 The Smart Move:**\n"
   "When the market can't decide, you shouldn't either. Wait for "
   "components to realign. The best trades happen when all components "
   "are in agreement. Patience is a trader's superpower.\n\n"
   "**⚠️ Warning:**\n"
   "Trading during conflict increases the risk of false signals and "
   "whipsaws. Protect your capital and wait for clarity.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── CONSOLIDATION NARRATIVES ─────────────────────────────────────

string CONSOLIDATION_NARRATIVE = 
   "⚪ **MARKET CONSOLIDATION - NO DIRECTION** ⚪\n\n"
   "The market is taking a breather. After the recent move, "
   "it's consolidating and building energy for the next big move. "
   "This is the calm before the storm.\n\n"
   "**🔍 Consolidation Analysis:**\n"
   "• ADX: {ADX_STRENGTH} ({ADX_VALUE}) - no momentum\n"
   "• Confidence: {CONFIDENCE}%\n"
   "• PB Zone: {PB_ZONE}\n"
   "• Active components: {ACTIVE}/6\n\n"
   "**📊 What's Happening:**\n"
   "The market is compressing. Price is moving sideways as bulls "
   "and bears battle for control. This consolidation will eventually "
   "resolve with a breakout or breakdown.\n\n"
   "**🎯 The Waiting Game:**\n"
   "During consolidation:\n"
   "1. Watch for the direction of the eventual breakout\n"
   "2. Monitor ADX for increasing strength\n"
   "3. Look for volume to confirm the direction\n"
   "4. Be patient - don't force trades\n\n"
   "**⚠️ Opportunity:**\n"
   "The next directional move could be significant. Be ready to "
   "act when the market chooses its direction.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── REVERSAL NARRATIVES ──────────────────────────────────────────

string REVERSAL_WARNING = 
   "🔔 **POTENTIAL REVERSAL - HIGH ALERT** 🔔\n\n"
   "Red alert! The market is showing classic reversal patterns. "
   "This could be the beginning of a major turn in the trend!\n\n"
   "**🔍 Reversal Signals:**\n"
   "• RSI: {RSI_VALUE} in {RSI_ZONE} zone\n"
   "• ADX: {ADX_STRENGTH} ({ADX_VALUE})\n"
   "• Current trend: {TREND_DIRECTION}\n"
   "• Confidence: {CONFIDENCE}%\n\n"
   "**📊 Technical Context:**\n"
   "A potential reversal is developing with multiple indicators "
   "suggesting the trend may be ending. Key signs include:\n"
   "• Extreme RSI levels ({RSI_ZONE})\n"
   "• ADX showing {ADX_STRENGTH} momentum\n"
   "• Components starting to disagree\n\n"
   "**🎯 Strategy Options:**\n"
   "1. Tighten stops significantly\n"
   "2. Take partial or full profits\n"
   "3. Wait for confirmation of reversal\n"
   "4. Consider counter-trend position with tight stops\n\n"
   "**⚠️ Critical Warning:**\n"
   "Reversals are high-risk, high-reward setups. NEVER enter a "
   "reversal trade without confirmation. Look for:\n"
   "• Break of trendline or key S/R level\n"
   "• Candlestick reversal patterns\n"
   "• Volume confirmation\n"
   "• Multiple components flipping\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── EXTREME CAUTION NARRATIVES ───────────────────────────────────

string EXTREME_CAUTION = 
   "🚨 **EXTREME CAUTION - STAY OUT** 🚨\n\n"
   "DANGER! DANGER! The market is in extreme territory. "
   "This is NOT the place for new positions. Protect your capital!\n\n"
   "**🔍 Warning Signs:**\n"
   "• PB Zone: EXTREME ({PB_PERCENT}% pullback)\n"
   "• Confidence: {CONFIDENCE}%\n"
   "• Active components: {ACTIVE}/6\n"
   "• Trend: {TREND_DIRECTION}\n\n"
   "**📊 What's Happening:**\n"
   "The market has moved to an extreme level where risk-reward "
   "ratios are severely unfavorable. This often happens at:\n"
   "• Climax points in trends\n"
   "• Parabolic moves\n"
   "• Panic selling or buying\n\n"
   "**🎯 The Smart Play:**\n"
   "In extreme zones:\n"
   "1. DO NOT chase the move\n"
   "2. DO NOT add to positions\n"
   "3. Consider taking profits\n"
   "4. Wait for the market to normalize\n\n"
   "**⚠️ Remember:**\n"
   "The best trades are made when the market is calm and in "
   "normal zones. Extreme zones are for exiting, not entering.\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── UNKNOWN / DEFAULT NARRATIVE ──────────────────────────────────

string UNKNOWN_NARRATIVE = 
   "❓ **UNCLEAR MARKET CONDITIONS** ❓\n\n"
   "The market is giving mixed signals that don't fit any of my "
   "scenarios. This happens occasionally when the market is in a "
   "unique or unusual state.\n\n"
   "**🔍 Current State:**\n"
   "• Trend: {TREND_DIRECTION}\n"
   "• Confidence: {CONFIDENCE}%\n"
   "• Active: {ACTIVE}/6 components\n"
   "• PB Zone: {PB_ZONE}\n\n"
   "**📊 What To Do:**\n"
   "When the market is unclear:\n"
   "1. Reduce position sizes\n"
   "2. Narrow stops\n"
   "3. Wait for clarity\n"
   "4. Focus on risk management\n\n"
   "**Risk Level:** {RISK_LEVEL}\n"
   "**Action:** {ACTION}";

// ─── ADDITIONAL CONTENT VARIATIONS ────────────────────────────────

// Short version for quick updates
string QUICK_STRONG_TREND_BULLISH = 
   "🚀 Strong Bullish Trend | Conf:{CONFIDENCE}% | {ADX_STRENGTH} | {VOLUME_STATUS} | {ACTION}";

string QUICK_PULLBACK_ENTRY = 
   "🎯 Pullback Entry | {PB_ZONE} ({PB_PERCENT}%) | Conf:{CONFIDENCE}% | {ACTION}";

string QUICK_DIVERGENCE = 
   "⚠️ Divergence | RSI:{RSI_VALUE} {RSI_ZONE} | Disagree:{DISAGREEING}/6 | CAUTION";

//+------------------------------------------------------------------+
//| NARRATIVE HELPER FUNCTIONS                                       |
//| These format the narratives with actual data                     |
//+------------------------------------------------------------------+

string FormatNarrative(string template_str, 
                       string trendDirection,
                       string tradeAction,
                       double confidence,
                       string pbZone,
                       double pbPercent,
                       string rsiZone,
                       double rsiValue,
                       string adxStrength,
                       double adxValue,
                       string volStatus,
                       double volRatio,
                       string macdSignal,
                       int agreeing,
                       int disagreeing,
                       int neutral,
                       int active,
                       string riskLevel)
{
   string result = template_str;
   
   // Replace all placeholders with actual values
   StringReplace(result, "{TREND_DIRECTION}", trendDirection);
   StringReplace(result, "{ACTION}", tradeAction);
   StringReplace(result, "{CONFIDENCE}", DoubleToString(confidence, 1));
   StringReplace(result, "{PB_ZONE}", pbZone);
   StringReplace(result, "{PB_PERCENT}", DoubleToString(pbPercent, 1));
   StringReplace(result, "{RSI_ZONE}", rsiZone);
   StringReplace(result, "{RSI_VALUE}", DoubleToString(rsiValue, 1));
   StringReplace(result, "{ADX_STRENGTH}", adxStrength);
   StringReplace(result, "{ADX_VALUE}", DoubleToString(adxValue, 1));
   StringReplace(result, "{VOLUME_STATUS}", volStatus);
   StringReplace(result, "{VOLUME_RATIO}", DoubleToString(volRatio, 1));
   StringReplace(result, "{MACD_SIGNAL}", macdSignal);
   StringReplace(result, "{AGREEING}", IntegerToString(agreeing));
   StringReplace(result, "{DISAGREEING}", IntegerToString(disagreeing));
   StringReplace(result, "{NEUTRAL}", IntegerToString(neutral));
   StringReplace(result, "{ACTIVE}", IntegerToString(active));
   StringReplace(result, "{RISK_LEVEL}", riskLevel);
   
   return result;
}

//+------------------------------------------------------------------+
//| Main narrative retrieval function                                |
//+------------------------------------------------------------------+
string GetNarrative(ENUM_SCENARIO_TYPE type, 
                    string trendDirection,
                    string tradeAction,
                    double confidence,
                    string pbZone,
                    double pbPercent,
                    string rsiZone,
                    double rsiValue,
                    string adxStrength,
                    double adxValue,
                    string volStatus,
                    double volRatio,
                    string macdSignal,
                    int agreeing,
                    int disagreeing,
                    int neutral,
                    int active,
                    string riskLevel,
                    bool quickVersion = false)
{
   string template_str = "";
   
   if(quickVersion)
   {
      // Return quick versions
      if(type == SCENARIO_STRONG_TREND && trendDirection == "BULLISH")
         return FormatNarrative(QUICK_STRONG_TREND_BULLISH, trendDirection, tradeAction,
                                confidence, pbZone, pbPercent, rsiZone, rsiValue,
                                adxStrength, adxValue, volStatus, volRatio,
                                macdSignal, agreeing, disagreeing, neutral, active, riskLevel);
      else if(type == SCENARIO_STRONG_TREND)
         return FormatNarrative(QUICK_STRONG_TREND_BULLISH, trendDirection, tradeAction,
                                confidence, pbZone, pbPercent, rsiZone, rsiValue,
                                adxStrength, adxValue, volStatus, volRatio,
                                macdSignal, agreeing, disagreeing, neutral, active, riskLevel);
      else if(type == SCENARIO_PULLBACK_ENTRY)
         return FormatNarrative(QUICK_PULLBACK_ENTRY, trendDirection, tradeAction,
                                confidence, pbZone, pbPercent, rsiZone, rsiValue,
                                adxStrength, adxValue, volStatus, volRatio,
                                macdSignal, agreeing, disagreeing, neutral, active, riskLevel);
      else if(type == SCENARIO_DIVERGENCE)
         return FormatNarrative(QUICK_DIVERGENCE, trendDirection, tradeAction,
                                confidence, pbZone, pbPercent, rsiZone, rsiValue,
                                adxStrength, adxValue, volStatus, volRatio,
                                macdSignal, agreeing, disagreeing, neutral, active, riskLevel);
   }
   
   // Full versions
   switch(type)
   {
      case SCENARIO_STRONG_TREND:
         if(trendDirection == "BULLISH")
            template_str = STRONG_TREND_BULLISH;
         else
            template_str = STRONG_TREND_BEARISH;
         break;
         
      case SCENARIO_PULLBACK_ENTRY:
         template_str = PULLBACK_ENTRY;
         break;
         
      case SCENARIO_DIVERGENCE:
         template_str = DIVERGENCE_WARNING;
         break;
         
      case SCENARIO_BREAKOUT:
         if(trendDirection == "BULLISH")
            template_str = BREAKOUT_BULLISH;
         else
            template_str = BREAKOUT_BEARISH;
         break;
         
      case SCENARIO_CONFLICT:
         template_str = CONFLICT_NARRATIVE;
         break;
         
      case SCENARIO_CONSOLIDATION:
         template_str = CONSOLIDATION_NARRATIVE;
         break;
         
      case SCENARIO_REVERSAL:
         template_str = REVERSAL_WARNING;
         break;
         
      case SCENARIO_EXTREME_CAUTION:
         template_str = EXTREME_CAUTION;
         break;
         
      default:
         template_str = UNKNOWN_NARRATIVE;
         break;
   }
   
   return FormatNarrative(template_str, 
                          trendDirection,
                          tradeAction,
                          confidence,
                          pbZone,
                          pbPercent,
                          rsiZone,
                          rsiValue,
                          adxStrength,
                          adxValue,
                          volStatus,
                          volRatio,
                          macdSignal,
                          agreeing,
                          disagreeing,
                          neutral,
                          active,
                          riskLevel);
}

//+------------------------------------------------------------------+
//| Quick summary narrative                                           |
//+------------------------------------------------------------------+
string GetQuickNarrative(ENUM_SCENARIO_TYPE type,
                         string trendDirection,
                         string tradeAction,
                         double confidence,
                         string pbZone,
                         double pbPercent,
                         string rsiZone,
                         double rsiValue,
                         string adxStrength,
                         double adxValue,
                         string volStatus,
                         double volRatio,
                         string macdSignal,
                         int agreeing,
                         int disagreeing,
                         int neutral,
                         int active,
                         string riskLevel)
{
   return GetNarrative(type, trendDirection, tradeAction, confidence,
                       pbZone, pbPercent, rsiZone, rsiValue,
                       adxStrength, adxValue, volStatus, volRatio,
                       macdSignal, agreeing, disagreeing, neutral,
                       active, riskLevel, true);
}