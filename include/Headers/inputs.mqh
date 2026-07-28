//+------------------------------------------------------------------+
//|                        Inputs.mqh                                |
//|                    Input Parameters                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.02"

// ============================================================
// EA CONTROLS
// ============================================================
input bool     InpEnableTrading     = true;
input double   InpLotSize           = 0.01;
input int      InpMaxPositions      = 1;
input int      InpMagicNumber       = 123456;

// ============================================================
// DISPLAY SETTINGS
// ============================================================
input bool     InpShowChart         = true;
input bool     InpShowDashboard     = true;
input int      InpRangeBars         = 60;
input ENUM_TIMEFRAMES InpEntryTF    = PERIOD_M5;

// ============================================================
// PULLBACK MODULE INPUTS
// ============================================================
input int      InpTrendEMA          = 89;
input int      InpADXPeriod         = 14;
input int      InpRSIPeriod         = 14;
input int      InpATRPeriod         = 14;
input int      InpMACD_Fast         = 12;
input int      InpMACD_Slow         = 26;
input int      InpMACD_Signal       = 9;

// ============================================================
// WEIGHTS
// ============================================================
input double   InpWeight_PB          = 0.30;
input double   InpWeight_MTF         = 0.20;
input double   InpWeight_MACD        = 0.15;
input double   InpWeight_RSI         = 0.15;
input double   InpWeight_Volume      = 0.10;
input double   InpWeight_ADX         = 0.10;

// ============================================================
// POSITION MANAGEMENT
// ============================================================
input int      InpMaxSlippage       = 10;

//+------------------------------------------------------------------+
//| BREAKEVEN SETTINGS                                              |
//+------------------------------------------------------------------+
input bool   InpUseBreakeven = true;        // Use Breakeven Stop
input int    InpBreakevenPips = 500;         // Breakeven after X pips
input int    InpBreakevenBuffer = 100;        // Breakeven buffer in pips

//+------------------------------------------------------------------+
//| TRAILING STOP SETTINGS                                          |
//+------------------------------------------------------------------+
input bool   InpUseTrailingStop = true;     // Use Trailing Stop
input int    InpTrailingStartPips = 1000;     // Start trailing after X pips
input int    InpTrailingStopPips = 1000;      // Trail SL X pips behind

// ============================================================
// PARTIAL CLOSE SETTINGS
// ============================================================
input double   InpPartialAtTP1      = 50.0;
input double   InpPartialAt75       = 25.0;
input double   InpPartialAtTP2      = 25.0;

// ============================================================
// RISK MANAGEMENT
// ============================================================
input double   InpMinConfidence     = 20.0;
input double   InpATRStopMultiplier = 1.5;
input double   InpATRTargetMultipler= 2.5;
input double   InpTrendBuffer       = 0.005;
input double   InpATRBuffer         = 0.5;
input double   InpMinRR             = 1.0;
input double   InpMaxDrawdown       = 20.0;
input bool     InpUseRiskBasedLot   = true;
input double   InpRiskPerTrade      = 1.0;
input double   InpMaxLotSize        = 1.0;
input double   InpMinLotSize        = 0.01;

// ============================================================
//| Input Parameters - Trend Filter                                  
// ============================================================
input group "=== TREND FILTER (H1+) ==="
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;      // Trend Timeframe
input double InpMinTrendStrength = 40.0;            // Minimum Trend Strength (%)
input bool InpRequireStrongTrend = false;           // Require Strong Trend (60%+)
input bool InpAllowNeutralTrend = false;            // Allow trades in neutral trend
input bool InpTrendPositionSizeScaling = false;      // Scale position with trend strength

// ============================================================
//| Input Parameters - Trade Management                     
// ============================================================
input group "=== TRADE MANAGEMENT ==="
input double InpStopLossMultiplier = 1.5;      // Stop Loss Multiplier (ATR)
input double InpTakeProfitMultiplier = 2.5;    // Take Profit Multiplier (ATR)
input double InpTakeProfit2Multiplier = 4.0;   // Take Profit 2 Multiplier (ATR)

// ============================================================
// CONFIDENCE THRESHOLDS (Global Inputs)
// ============================================================
input group "=== CONFIDENCE THRESHOLDS ==="
input double   InpBuyThreshold       = 30.0;   // Minimum confidence for BUY signals (0-100)
input double   InpSellThreshold      = 30.0;   // Minimum confidence for SELL signals (0-100)
input double   InpNeutralThreshold   = 60.0;   // Minimum confidence for NEUTRAL trend (0-100)