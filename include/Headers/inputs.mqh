//+------------------------------------------------------------------+
//|                        Inputs.mqh                                |
//|                    Input Parameters                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "1.03"

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
input int      InpRangeBars         = 50;
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
input bool   InpUseBreakeven        = true;        // Use Breakeven Stop
input int    InpBreakevenPips       = 500;         // Breakeven after X pips
input int    InpBreakevenBuffer     = 100;        // Breakeven buffer in pips
input int    InpSLBufferPoints      = 30;   // SL Buffer in points

//+------------------------------------------------------------------+
//| TRAILING STOP SETTINGS                                          |
//+------------------------------------------------------------------+
input bool   InpUseTrailingStop = true;     // Use Trailing Stop
input int    InpTrailingStartPips = 1000;     // Start trailing after X pips
input int    InpTrailingStopPips = 500;      // Trail SL X pips behind

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
// RISK MANAGEMENT COOLDOWN SETTINGS
// ============================================================
input group "=== COOLDOWN SETTINGS ==="
input int      InpCooldownLoss = 2;          // Cooldown hours after a LOSS
input int      InpCooldownWin = 1;           // Cooldown hours after a WIN
input int      InpCooldownBE = 1;            // Cooldown hours after BREAKEVEN
input bool     InpCooldownEnable = true;     // Enable cooldown system

// ============================================================
//| Input Parameters - Trend Filter                                  
// ============================================================
input group "=== TREND FILTER (H1+) ==="
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_M15;      // Trend Timeframe
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

// ============================================================
// ORDER BLOCK DISPLAY
// ============================================================
input group "=== ORDER BLOCK DISPLAY ==="
input bool     InpShowOrderBlocks = true;        // Show Order Blocks on Chart
input int      InpMaxOrderBlocks = 10;           // Max OBs above and below price
input ENUM_TIMEFRAMES InpOrderBlockTF = PERIOD_H4;  // Timeframe for OB detection

// ============================================================
// ORDER BLOCK DISPLAY
// ============================================================
input int       InpCandleWaitCandles = 2;

// ============================================================
// POSITION SIZING AND SL/TP SETTINGS (STRUCTURE-BASED WITH FALLBACK)
// ============================================================

// ─── FIXED VALUES (FALLBACK) ───
input int      InpFallbackSLPips = 1000;           // Fallback SL (points) - used if ATR fails
input int      InpFallbackTPPips = 1500;           // Fallback TP (points) - 1.5:1 RR

// ─── STRUCTURE SETTINGS (PREFERRED) ───
input bool     InpUseStructureSLTP = true;       // Use adaptive SL/TP (recommended)
input int      InpStructureMinSLPips = 1000;       // Minimum SL (points)
input int      InpStructureMaxSLPips = 1500;       // Maximum SL (points)
input int      InpStructureMinTPPips = 2000;       // Minimum TP (points)
input int      InpStructureMaxTPPips = 5000;      // Maximum TP (points)
input double   InpStructureMinRR = 1.5;          // Minimum Risk-Reward ratio
input double   InpStructureMaxRR = 3.0;          // Maximum Risk-Reward ratio

// ─── ATR SETTINGS (FOR STRUCTURE) ───
input bool     InpUseATR = true;                 // Use ATR for dynamic sizing
input double   InpATRMultiplierSL = 1.5;         // SL = ATR × multiplier
input double   InpATRMultiplierTP = 2.5;         // TP = ATR × multiplier
input int      InpATRTimeframe = 5;              // ATR timeframe (5=M5)

// ─── BUFFER SETTINGS (TO AVOID WHIPSAWS) ───
input int      InpSLBufferPips = 5;              // SL buffer (points) - adds safety
input int      InpTPBufferPips = 5;              // TP buffer (points) - adds safety
input bool     InpUseBuffer = true;              // Enable buffer protection
