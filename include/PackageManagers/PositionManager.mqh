//+------------------------------------------------------------------+
//|                     PositionManager.mqh                          |
//|              WITH PARTIAL CLOSE AT BREAKEVEN                    |
//|              v4.0 - HYBRID SL/TP (Structure + Fallback)       |
//|              + BUFFER PROTECTION FOR WHIPSAWS                  |
//|              + FULL CONFIGURATION VIA INPUTS                   |
//|              + Reports trade results to RiskManager            |
//|              + SL MOVEMENT LOGGING CAN BE TOGGLED             |
//|              + DEBUG: FULL SL/TP CALCULATION LOGGING          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "4.0"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "PortfolioManager.mqh"
#include "Riskmanager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugPositionManager = false;  // ⬅️ FORCE DEBUG ON FOR TESTING
bool g_logSLMovements = false;

//+------------------------------------------------------------------+
//| SL/TP CONFIGURATION STRUCTURE                                   |
//+------------------------------------------------------------------+
struct S_SLTP_CONFIG
{
   // Structure settings (preferred)
   bool     useStructure;        // Use adaptive structure
   int      minSLPips;           // Minimum SL (pips)
   int      maxSLPips;           // Maximum SL (pips)
   int      minTPPips;           // Minimum TP (pips)
   int      maxTPPips;           // Maximum TP (pips)
   double   minRR;               // Minimum RR
   double   maxRR;               // Maximum RR
   
   // ATR settings
   bool     useATR;              // Use ATR for dynamic sizing
   int      atrPeriod;           // ATR period
   double   atrMultiplierSL;     // SL = ATR × multiplier
   double   atrMultiplierTP;     // TP = ATR × multiplier
   ENUM_TIMEFRAMES atrTF;        // ATR timeframe
   
   // Fallback settings
   int      fallbackSL;          // Fixed SL (pips)
   int      fallbackTP;          // Fixed TP (pips)
   
   // Buffer settings (avoid whipsaws)
   int      slBuffer;            // SL buffer (pips)
   int      tpBuffer;            // TP buffer (pips)
   bool     useBuffer;           // Enable buffer
};

//+------------------------------------------------------------------+
//| Position Manager Class - HYBRID SL/TP                          |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   string            m_symbol;
   int               m_magicNumber;
   int               m_maxSlippage;
   CTrade           *m_trade;
   CPortfolioManager *m_portfolioManager;
   CRiskManager     *m_riskManager;
   PositionState    m_states[];
   
   // ═══ SL/TP CONFIGURATION ═══
   S_SLTP_CONFIG    m_config;
   int              m_atrHandle;
   double           m_pointValue;
   double           m_pipValue;
   
   // Boost-aware TP trailing settings
   double            m_boostTPDistance;
   double            m_currentBoost;
   datetime          m_lastBoostCheck;
   int               m_boostCheckInterval;
   
   // Loss Management Settings
   bool              m_lossManagementEnabled;
   
   // Internal Methods
   int FindStateIndex(ulong ticket);
   void RemoveState(ulong ticket);
   double NormalizeLotSize(double lotSize);
   bool IsOurPosition(ulong ticket);
   bool IsPositionStillOpen(ulong ticket);
   void ManageSinglePosition(ulong ticket);
   bool PartialClosePosition(ulong ticket, double closePercent);
   double CalculatePartialCloseVolume(double currentVolume, double closePercent);
   
   // Boost methods
   void UpdateBoost();
   bool IsBoostActive();
   double GetBoostTPDistance();
   double GetCurrentBoost() const { return m_currentBoost; }
   
   // ═══ SL/TP CALCULATION METHODS ═══
   bool CalculateSLTP_Structured(int signal, double entryPrice, 
                                  double &stopLoss, double &takeProfit, 
                                  double &riskReward, string &methodUsed);
   bool CalculateSLTP_Fallback(int signal, double entryPrice,
                                double &stopLoss, double &takeProfit,
                                double &riskReward);
   double GetATRValue();
   void ApplyBuffer(double &stopLoss, double &takeProfit, int signal);
   void InitializeConfig();
   
   // Trade close handling
   void OnPositionClosed(ulong ticket, double profit);
   void CheckAndReportClosedPositions();
   datetime m_lastPositionCheck;
   
   // SL Movement logging
   bool m_logSLMovements;
   void LogSLMovement(ulong ticket, string source, double oldSL, double newSL, double profitPips, string reason);
   
public:
   CPositionManager(string symbol, int magicNumber, CTrade &trade);
   ~CPositionManager();
   
   void SetPortfolioManager(CPortfolioManager* portfolioManager) 
   { 
      m_portfolioManager = portfolioManager; 
   }
   
   void SetRiskManager(CRiskManager* riskManager)
   {
      m_riskManager = riskManager;
   }
   
   // ═══ CONFIGURATION ═══
   void SetConfig(S_SLTP_CONFIG &config);
   void SetLogSLMovements(bool enable) { m_logSLMovements = enable; }
   bool GetLogSLMovements() const { return m_logSLMovements; }
   static void SetGlobalLogSLMovements(bool enable) { g_logSLMovements = enable; }
   static bool GetGlobalLogSLMovements() { return g_logSLMovements; }
   
   void SetLossManagementEnabled(bool enable) { m_lossManagementEnabled = enable; }
   bool IsLossManagementEnabled() const { return m_lossManagementEnabled; }
   
   // ═══ MAIN EXECUTION - HYBRID ═══
   bool ExecuteTrade(int signal, double lotSize);
   bool ExecuteTrade(PrescribedTrade &signal, double lotSize);  // Legacy support
   
   void ManagePositions();
   void CloseAllPositions();
   void ClosePosition(ulong ticket);
   
   void SetBreakeven(ulong ticket, bool isBuy);
   void ApplyTrailingStop(ulong ticket, bool isBuy);
   double ApplyTrailingTP(ulong ticket, bool isBuy);
   void ModifySLTP(ulong ticket, double newSL, double newTP);
   
   void AddState(ulong ticket, int signal, double entryPrice, double stopLoss, double takeProfit, double lotSize);
   bool GetState(ulong ticket, PositionState &state);
   int GetOpenPositionCount();
   bool HasOpenPositions();
   
   double GetOpenPrice(ulong ticket);
   double GetCurrentSL(ulong ticket);
   double GetCurrentTP(ulong ticket);
   ENUM_POSITION_TYPE GetPositionType(ulong ticket);
   double GetPositionProfit(ulong ticket);
   double GetPositionVolume(ulong ticket);
   
   void PrintStates();
   void PrintConfig();
   void LoadConfigFromInputs();
   
   static void SetGlobalDebug(bool enable) { g_debugPositionManager = enable; }
   static bool GetGlobalDebug() { return g_debugPositionManager; }
   
   void SetBoostCheckInterval(int seconds) { m_boostCheckInterval = seconds; }
   void SetBoostTPDistance(double points) { m_boostTPDistance = points; }
   
   // Getters
   S_SLTP_CONFIG GetConfig() const { return m_config; }
   double GetPointValue() const { return m_pointValue; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager(string symbol, int magicNumber, CTrade &trade)
{
   m_symbol = symbol;
   m_magicNumber = magicNumber;
   m_trade = &trade;
   m_maxSlippage = InpMaxSlippage;
   m_portfolioManager = NULL;
   m_riskManager = NULL;
   m_currentBoost = 0;
   m_lastBoostCheck = 0;
   m_boostCheckInterval = 2;
   m_boostTPDistance = 100.0;
   m_lossManagementEnabled = true;
   m_lastPositionCheck = 0;
   m_logSLMovements = false;
   
   // ─── CRITICAL: GET POINT VALUE ═══
   m_pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_pipValue = m_pointValue * 10;
   m_atrHandle = INVALID_HANDLE;
   
   Print("🔍 PositionManager Constructor - Point Value: ", m_pointValue);
   
   // ─── INITIALIZE CONFIGURATION ───
   InitializeConfig();
   LoadConfigFromInputs();
   
   Print("🔍 PositionManager Constructor - Config Loaded:");
   Print("   useStructure: ", m_config.useStructure);
   Print("   fallbackSL: ", m_config.fallbackSL);
   Print("   fallbackTP: ", m_config.fallbackTP);
   Print("   minRR: ", m_config.minRR);
   Print("   useBuffer: ", m_config.useBuffer);
   
   // ─── CREATE ATR HANDLE ───
   m_atrHandle = iATR(m_symbol, m_config.atrTF, m_config.atrPeriod);
   if(m_atrHandle == INVALID_HANDLE)
   {
      Print("⚠️ Failed to create ATR handle - falling back to fixed SL/TP");
   }
   
   ArrayResize(m_states, 0);
   
   Print("🔧 PositionManager v4.0 initialized (HYBRID SL/TP)");
   Print("   Structure: " + (m_config.useStructure ? "ENABLED" : "DISABLED") + 
         " | ATR: " + (m_config.useATR ? "ENABLED" : "DISABLED"));
   Print("   Fallback SL: " + IntegerToString(m_config.fallbackSL) + 
         "p | TP: " + IntegerToString(m_config.fallbackTP) + "p");
   Print("   Min RR: " + DoubleToString(m_config.minRR, 1) + 
         ":1 | Buffer: " + (m_config.useBuffer ? IntegerToString(m_config.slBuffer) + "p" : "OFF"));
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager()
{
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);
}

//+------------------------------------------------------------------+
//| Initialize Config - DEFAULT VALUES                              |
//+------------------------------------------------------------------+
void CPositionManager::InitializeConfig()
{
   m_config.useStructure = true;
   m_config.minSLPips = 20;
   m_config.maxSLPips = 60;
   m_config.minTPPips = 30;
   m_config.maxTPPips = 120;
   m_config.minRR = 1.5;
   m_config.maxRR = 3.0;
   m_config.useATR = true;
   m_config.atrPeriod = 14;
   m_config.atrMultiplierSL = 1.5;
   m_config.atrMultiplierTP = 2.5;
   m_config.atrTF = PERIOD_M5;
   m_config.fallbackSL = 30;
   m_config.fallbackTP = 45;
   m_config.slBuffer = 5;
   m_config.tpBuffer = 5;
   m_config.useBuffer = true;
}

//+------------------------------------------------------------------+
//| Load Config From Inputs                                         |
//+------------------------------------------------------------------+
void CPositionManager::LoadConfigFromInputs()
{
   Print("🔍 Loading Config from Inputs...");
   Print("   InpUseStructureSLTP: ", InpUseStructureSLTP);
   Print("   InpFallbackSLPips: ", InpFallbackSLPips);
   Print("   InpFallbackTPPips: ", InpFallbackTPPips);
   Print("   InpStructureMinRR: ", InpStructureMinRR);
   
   m_config.useStructure = InpUseStructureSLTP;
   m_config.minSLPips = InpStructureMinSLPips;
   m_config.maxSLPips = InpStructureMaxSLPips;
   m_config.minTPPips = InpStructureMinTPPips;
   m_config.maxTPPips = InpStructureMaxTPPips;
   m_config.minRR = InpStructureMinRR;
   m_config.maxRR = InpStructureMaxRR;
   m_config.useATR = InpUseATR;
   m_config.atrPeriod = InpATRPeriod;
   m_config.atrMultiplierSL = InpATRMultiplierSL;
   m_config.atrMultiplierTP = InpATRMultiplierTP;
   m_config.atrTF = (ENUM_TIMEFRAMES)InpATRTimeframe;
   m_config.fallbackSL = InpFallbackSLPips;
   m_config.fallbackTP = InpFallbackTPPips;
   m_config.slBuffer = InpSLBufferPips;
   m_config.tpBuffer = InpTPBufferPips;
   m_config.useBuffer = InpUseBuffer;
   
   Print("🔍 Config Loaded:");
   Print("   useStructure: ", m_config.useStructure);
   Print("   fallbackSL: ", m_config.fallbackSL);
   Print("   fallbackTP: ", m_config.fallbackTP);
   Print("   minRR: ", m_config.minRR);
}

//+------------------------------------------------------------------+
//| Set Config                                                     |
//+------------------------------------------------------------------+
void CPositionManager::SetConfig(S_SLTP_CONFIG &config)
{
   m_config = config;
   
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);
   
   m_atrHandle = iATR(m_symbol, m_config.atrTF, m_config.atrPeriod);
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                   |
//+------------------------------------------------------------------+
double CPositionManager::GetATRValue()
{
   if(m_atrHandle == INVALID_HANDLE) return 0;
   
   double atr[1];
   if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) < 1) return 0;
   
   Print("🔍 ATR Value: ", atr[0]);
   return atr[0];
}

//+------------------------------------------------------------------+
//| Apply Buffer (Avoid Whipsaws)                                   |
//+------------------------------------------------------------------+
void CPositionManager::ApplyBuffer(double &stopLoss, double &takeProfit, int signal)
{
   if(!m_config.useBuffer) return;
   
   double slBuffer = m_config.slBuffer * m_pointValue;
   double tpBuffer = m_config.tpBuffer * m_pointValue;
   
   if(signal == 1)  // BUY
   {
      stopLoss -= slBuffer;
      takeProfit += tpBuffer;
   }
   else  // SELL
   {
      stopLoss += slBuffer;
      takeProfit -= tpBuffer;
   }
   
   Print("🔍 Buffer Applied: SL Buffer=", m_config.slBuffer, "p, TP Buffer=", m_config.tpBuffer, "p");
}

//+------------------------------------------------------------------+
//| CALCULATE SL/TP - STRUCTURED (PREFERRED)                       |
//+------------------------------------------------------------------+
bool CPositionManager::CalculateSLTP_Structured(int signal, double entryPrice, 
                                                  double &stopLoss, double &takeProfit, 
                                                  double &riskReward, string &methodUsed)
{
   Print("🔍 CalculateSLTP_Structured() called");
   Print("   signal: ", signal);
   Print("   entryPrice: ", entryPrice);
   Print("   m_pointValue: ", m_pointValue);
   
   if(signal == 0 || entryPrice <= 0 || m_pointValue <= 0) 
   {
      Print("❌ CalculateSLTP_Structured: Invalid inputs!");
      Print("   signal=", signal, " entryPrice=", entryPrice, " m_pointValue=", m_pointValue);
      return false;
   }
   
   double slPips = 0, tpPips = 0;
   methodUsed = "";
   
   // ─── STEP 1: DETERMINE SL USING STRUCTURE ───
   if(m_config.useATR)
   {
      Print("🔍 Using ATR for SL/TP calculation...");
      double atr = GetATRValue();
      if(atr > 0)
      {
         double atrSL = atr / m_pointValue * m_config.atrMultiplierSL;
         double atrTP = atr / m_pointValue * m_config.atrMultiplierTP;
         
         Print("   atrSL: ", atrSL, "p, atrTP: ", atrTP, "p");
         Print("   minSL: ", m_config.minSLPips, "p, maxSL: ", m_config.maxSLPips, "p");
         Print("   minTP: ", m_config.minTPPips, "p, maxTP: ", m_config.maxTPPips, "p");
         
         if(atrSL >= m_config.minSLPips && atrSL <= m_config.maxSLPips)
            slPips = atrSL;
         else
            slPips = MathMax(m_config.minSLPips, MathMin(m_config.maxSLPips, atrSL));
         
         if(atrTP >= m_config.minTPPips && atrTP <= m_config.maxTPPips)
            tpPips = atrTP;
         else
            tpPips = MathMax(m_config.minTPPips, MathMin(m_config.maxTPPips, atrTP));
         
         methodUsed = "ATR (SL: " + DoubleToString(atrSL, 0) + "p, TP: " + DoubleToString(atrTP, 0) + "p)";
         
         Print("   slPips: ", slPips, "p, tpPips: ", tpPips, "p");
      }
      else
      {
         Print("⚠️ ATR returned 0, falling back to structure defaults");
      }
   }
   else
   {
      Print("🔍 ATR disabled, using structure defaults");
   }
   
   // ─── STEP 2: IF ATR FAILED, USE STRUCTURE MIN/MAX ───
   if(slPips == 0 || tpPips == 0)
   {
      slPips = m_config.minSLPips + (m_config.maxSLPips - m_config.minSLPips) / 2;
      tpPips = slPips * m_config.minRR;
      tpPips = MathMax(m_config.minTPPips, MathMin(m_config.maxTPPips, tpPips));
      methodUsed = "Structure Default (mid-range)";
      Print("   Using defaults: slPips=", slPips, "p, tpPips=", tpPips, "p");
   }
   
   // ─── STEP 3: ENFORCE RR BOUNDARIES ───
   double currentRR = tpPips / slPips;
   Print("   currentRR: ", currentRR, ":1, minRR: ", m_config.minRR, ":1, maxRR: ", m_config.maxRR, ":1");
   
   if(currentRR < m_config.minRR)
   {
      tpPips = slPips * m_config.minRR;
      methodUsed += " (RR adjusted to min)";
      Print("   RR adjusted to min: ", tpPips, "p");
   }
   else if(currentRR > m_config.maxRR)
   {
      tpPips = slPips * m_config.maxRR;
      methodUsed += " (RR adjusted to max)";
      Print("   RR adjusted to max: ", tpPips, "p");
   }
   
   // ─── STEP 4: ENSURE WITHIN BOUNDS ───
   slPips = MathMax(m_config.minSLPips, MathMin(m_config.maxSLPips, slPips));
   tpPips = MathMax(m_config.minTPPips, MathMin(m_config.maxTPPips, tpPips));
   Print("   Final slPips: ", slPips, "p, tpPips: ", tpPips, "p");
   
   // ─── STEP 5: CALCULATE SL/TP ───
   double slDistance = slPips * m_pointValue;
   double tpDistance = tpPips * m_pointValue;
   Print("   slDistance: ", slDistance, ", tpDistance: ", tpDistance);
   
   if(signal == 1)  // BUY
   {
      stopLoss = entryPrice - slDistance;
      takeProfit = entryPrice + tpDistance;
   }
   else  // SELL
   {
      stopLoss = entryPrice + slDistance;
      takeProfit = entryPrice - tpDistance;
   }
   Print("   stopLoss (before buffer): ", stopLoss, ", takeProfit (before buffer): ", takeProfit);
   
   // ─── STEP 6: APPLY BUFFER ───
   ApplyBuffer(stopLoss, takeProfit, signal);
   Print("   stopLoss (after buffer): ", stopLoss, ", takeProfit (after buffer): ", takeProfit);
   
   riskReward = tpPips / slPips;
   Print("   riskReward: ", riskReward, ":1");
   
   Print("✅ STRUCTURED METHOD USED: " + methodUsed);
   Print("   SL: " + DoubleToString(stopLoss, _Digits) + 
         " (" + DoubleToString(slPips, 0) + "p + " + 
         (m_config.useBuffer ? IntegerToString(m_config.slBuffer) + "p buffer" : "0p buffer") + ")");
   Print("   TP: " + DoubleToString(takeProfit, _Digits) + 
         " (" + DoubleToString(tpPips, 0) + "p + " + 
         (m_config.useBuffer ? IntegerToString(m_config.tpBuffer) + "p buffer" : "0p buffer") + ")");
   Print("   RR: " + DoubleToString(riskReward, 1) + ":1");
   
   return true;
}

//+------------------------------------------------------------------+
//| CALCULATE SL/TP - FALLBACK (FIXED)                             |
//+------------------------------------------------------------------+
bool CPositionManager::CalculateSLTP_Fallback(int signal, double entryPrice,
                                                double &stopLoss, double &takeProfit,
                                                double &riskReward)
{
   Print("🔍 CalculateSLTP_Fallback() called");
   Print("   signal: ", signal);
   Print("   entryPrice: ", entryPrice);
   Print("   m_pointValue: ", m_pointValue);
   Print("   fallbackSL: ", m_config.fallbackSL);
   Print("   fallbackTP: ", m_config.fallbackTP);
   
   if(signal == 0 || entryPrice <= 0 || m_pointValue <= 0) 
   {
      Print("❌ CalculateSLTP_Fallback: Invalid inputs!");
      return false;
   }
   
   double slPips = m_config.fallbackSL;
   double tpPips = m_config.fallbackTP;
   
   Print("   Initial slPips: ", slPips, "p, tpPips: ", tpPips, "p");
   
   double currentRR = (double)tpPips / slPips;
   if(currentRR < m_config.minRR)
   {
      tpPips = slPips * m_config.minRR;
      Print("   RR adjusted to min: ", tpPips, "p");
   }
   
   double slDistance = slPips * m_pointValue;
   double tpDistance = tpPips * m_pointValue;
   Print("   slDistance: ", slDistance, ", tpDistance: ", tpDistance);
   
   if(signal == 1)  // BUY
   {
      stopLoss = entryPrice - slDistance;
      takeProfit = entryPrice + tpDistance;
   }
   else  // SELL
   {
      stopLoss = entryPrice + slDistance;
      takeProfit = entryPrice - tpDistance;
   }
   Print("   stopLoss (before buffer): ", stopLoss, ", takeProfit (before buffer): ", takeProfit);
   
   ApplyBuffer(stopLoss, takeProfit, signal);
   Print("   stopLoss (after buffer): ", stopLoss, ", takeProfit (after buffer): ", takeProfit);
   
   riskReward = tpPips / slPips;
   Print("   riskReward: ", riskReward, ":1");
   
   Print("⚠️ FALLBACK METHOD USED (fixed values)");
   Print("   SL: " + DoubleToString(stopLoss, _Digits) + 
         " (" + DoubleToString(slPips, 0) + "p + " + 
         (m_config.useBuffer ? IntegerToString(m_config.slBuffer) + "p buffer" : "0p buffer") + ")");
   Print("   TP: " + DoubleToString(takeProfit, _Digits) + 
         " (" + DoubleToString(tpPips, 0) + "p + " + 
         (m_config.useBuffer ? IntegerToString(m_config.tpBuffer) + "p buffer" : "0p buffer") + ")");
   Print("   RR: " + DoubleToString(riskReward, 1) + ":1");
   
   return true;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE - HYBRID (Structure Preferred, Fallback)         |
//+------------------------------------------------------------------+
bool CPositionManager::ExecuteTrade(int signal, double lotSize)
{
   Print("═══════════════════════════════════════════");
   Print("🔍 ExecuteTrade() called!");
   Print("   signal: ", signal);
   Print("   lotSize: ", lotSize);
   Print("═══════════════════════════════════════════");
   
   if(PositionsTotal() >= InpMaxPositions)
   {
      Print("❌ Max positions reached: " + IntegerToString(InpMaxPositions));
      return false;
   }
   
   lotSize = NormalizeLotSize(lotSize);
   if(lotSize <= 0)
   {
      Print("❌ Invalid lot size: " + DoubleToString(lotSize, 2));
      return false;
   }
   
   double currentPrice = (signal == 1) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) 
                                        : SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double entryPrice = currentPrice;
   
   Print("   currentPrice: ", currentPrice);
   Print("   entryPrice: ", entryPrice);
   
   if(entryPrice <= 0)
   {
      Print("❌ Invalid entry price");
      return false;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ═══ CALCULATE SL/TP - STRUCTURE PREFERRED ═══
   // ═══════════════════════════════════════════════════════════════
   double stopLoss = 0, takeProfit = 0, riskReward = 0;
   string methodUsed = "";
   bool success = false;
   
   Print("🔍 Starting SL/TP calculation...");
   Print("   m_config.useStructure: ", m_config.useStructure);
   
   // ─── ATTEMPT 1: STRUCTURE-BASED (PREFERRED) ───
   if(m_config.useStructure)
   {
      Print("🔍 Attempting STRUCTURE-BASED calculation...");
      success = CalculateSLTP_Structured(signal, entryPrice, stopLoss, takeProfit, riskReward, methodUsed);
      Print("   Structure success: ", success);
   }
   else
   {
      Print("⚠️ Structure disabled, skipping to fallback");
   }
   
   // ─── ATTEMPT 2: FALLBACK (if structure failed or disabled) ───
   if(!success)
   {
      Print("🔍 Attempting FALLBACK calculation...");
      success = CalculateSLTP_Fallback(signal, entryPrice, stopLoss, takeProfit, riskReward);
      Print("   Fallback success: ", success);
   }
   
   if(!success)
   {
      Print("❌ Failed to calculate SL/TP - BOTH methods failed!");
      return false;
   }
   
   Print("🔍 FINAL SL/TP VALUES:");
   Print("   stopLoss: ", stopLoss);
   Print("   takeProfit: ", takeProfit);
   Print("   riskReward: ", riskReward);
   Print("   methodUsed: ", methodUsed);
   
   // ─── BUILD REQUEST ───
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.symbol = m_symbol;
   request.volume = lotSize;
   request.deviation = m_maxSlippage;
   request.magic = m_magicNumber;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.comment = "PBR " + (signal == 1 ? "BUY" : "SELL");
   
   Print("🔍 Trade Request:");
   Print("   symbol: ", request.symbol);
   Print("   volume: ", request.volume);
   Print("   sl: ", request.sl);
   Print("   tp: ", request.tp);
   
   if(signal == 1)
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   }
   else
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }
   
   Print("📊 EXECUTING TRADE:");
   Print("   Method: " + (success ? methodUsed : "FALLBACK"));
   Print("   Signal: " + (signal == 1 ? "BUY" : "SELL"));
   Print("   Lot: " + DoubleToString(lotSize, 2));
   Print("   Entry: " + DoubleToString(entryPrice, _Digits));
   Print("   SL: " + DoubleToString(stopLoss, _Digits) + 
         " (" + DoubleToString(MathAbs(stopLoss - entryPrice) / m_pointValue, 0) + "p)");
   Print("   TP: " + DoubleToString(takeProfit, _Digits) + 
         " (" + DoubleToString(MathAbs(takeProfit - entryPrice) / m_pointValue, 0) + "p)");
   Print("   RR: " + DoubleToString(riskReward, 1) + ":1");
   
   if(!m_trade.OrderSend(request, result))
   {
      Print("❌ Order failed: " + IntegerToString(result.retcode));
      return false;
   }
   
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("✅ Trade executed - Ticket: " + IntegerToString(result.order));
      
      AddState(result.order, signal, entryPrice, stopLoss, takeProfit, lotSize);
      
      if(m_portfolioManager != NULL)
         m_portfolioManager.OnTradeOpened(result.order, entryPrice, stopLoss);
      
      if(m_riskManager != NULL)
         m_riskManager.OnTradeExecuted();
      
      Print("✅ Trade executed successfully with SL=", stopLoss, " TP=", takeProfit);
      return true;
   }
   else
   {
      Print("❌ Trade failed - Retcode: " + IntegerToString(result.retcode));
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| LEGACY: ExecuteTrade(PrescribedTrade) - Redirects              |
//+------------------------------------------------------------------+
bool CPositionManager::ExecuteTrade(PrescribedTrade &signal, double lotSize)
{
   Print("⚠️ Using legacy ExecuteTrade(PrescribedTrade) - redirecting");
   return ExecuteTrade(signal.signal, lotSize);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size                                              |
//+------------------------------------------------------------------+
double CPositionManager::NormalizeLotSize(double lotSize)
{
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) return lotSize;
   
   double min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathRound(lotSize / step) * step;
   lotSize = MathMax(min, MathMin(max, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Is Our Position                                                 |
//+------------------------------------------------------------------+
bool CPositionManager::IsOurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   int magic = (int)PositionGetInteger(POSITION_MAGIC);
   string symbol = PositionGetString(POSITION_SYMBOL);
   
   return (magic == m_magicNumber && symbol == m_symbol);
}

//+------------------------------------------------------------------+
//| Is Position Still Open                                          |
//+------------------------------------------------------------------+
bool CPositionManager::IsPositionStillOpen(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   return IsOurPosition(ticket);
}

//+------------------------------------------------------------------+
//| Find State Index                                                |
//+------------------------------------------------------------------+
int CPositionManager::FindStateIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(m_states); i++)
   {
      if(m_states[i].ticket == ticket) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Remove State                                                    |
//+------------------------------------------------------------------+
void CPositionManager::RemoveState(ulong ticket)
{
   int idx = FindStateIndex(ticket);
   if(idx == -1) return;
   
   for(int i = idx; i < ArraySize(m_states) - 1; i++)
      m_states[i] = m_states[i + 1];
   
   ArrayResize(m_states, ArraySize(m_states) - 1);
}

//+------------------------------------------------------------------+
//| Add State                                                       |
//+------------------------------------------------------------------+
void CPositionManager::AddState(ulong ticket, int signal, double entryPrice, 
                                 double stopLoss, double takeProfit, double lotSize)
{
   int idx = FindStateIndex(ticket);
   if(idx != -1) return;
   
   int newIdx = ArraySize(m_states);
   ArrayResize(m_states, newIdx + 1);
   
   m_states[newIdx].ticket = ticket;
   m_states[newIdx].signal = signal;
   m_states[newIdx].entryPrice = entryPrice;
   m_states[newIdx].stopLoss = stopLoss;
   m_states[newIdx].takeProfit1 = takeProfit;
   m_states[newIdx].takeProfit2 = 0;
   m_states[newIdx].partialLevel75 = 0;
   m_states[newIdx].isBreakevenSet = false;
   m_states[newIdx].isTrailingActive = false;
   m_states[newIdx].isPartialCloseDone = false;
   m_states[newIdx].openVolume = lotSize;
   m_states[newIdx].originalVolume = lotSize;
   m_states[newIdx].lastTrailSL = stopLoss;
   m_states[newIdx].lastTrailTP = takeProfit;
   m_states[newIdx].partialClosePrice = 0;
   m_states[newIdx].boostActive = false;
   m_states[newIdx].boostTPDistance = m_boostTPDistance;
   m_states[newIdx].lastBoostTP = takeProfit;
   
   Print("📊 State added: Ticket=", ticket, " SL=", stopLoss, " TP=", takeProfit);
}

//+------------------------------------------------------------------+
//| Get State                                                       |
//+------------------------------------------------------------------+
bool CPositionManager::GetState(ulong ticket, PositionState &state)
{
   if(!IsPositionStillOpen(ticket))
   {
      RemoveState(ticket);
      return false;
   }
   
   int idx = FindStateIndex(ticket);
   if(idx == -1) return false;
   
   state = m_states[idx];
   return true;
}

//+------------------------------------------------------------------+
//| Get Open Position Count                                         |
//+------------------------------------------------------------------+
int CPositionManager::GetOpenPositionCount()
{
   return PositionsTotal();
}

//+------------------------------------------------------------------+
//| Has Open Positions                                              |
//+------------------------------------------------------------------+
bool CPositionManager::HasOpenPositions()
{
   return PositionsTotal() > 0;
}

//+------------------------------------------------------------------+
//| Update Boost                                                    |
//+------------------------------------------------------------------+
void CPositionManager::UpdateBoost()
{
   if(m_portfolioManager == NULL) return;
   
   datetime now = TimeCurrent();
   if(now - m_lastBoostCheck < m_boostCheckInterval) return;
   
   m_lastBoostCheck = now;
   m_currentBoost = m_portfolioManager.GetBoostPercentage();
}

//+------------------------------------------------------------------+
//| Is Boost Active                                                 |
//+------------------------------------------------------------------+
bool CPositionManager::IsBoostActive()
{
   UpdateBoost();
   return m_currentBoost > 0;
}

//+------------------------------------------------------------------+
//| Get Boost TP Distance                                           |
//+------------------------------------------------------------------+
double CPositionManager::GetBoostTPDistance()
{
   return m_boostTPDistance;
}

//+------------------------------------------------------------------+
//| Calculate Partial Close Volume                                  |
//+------------------------------------------------------------------+
double CPositionManager::CalculatePartialCloseVolume(double currentVolume, double closePercent)
{
   double closeVolume = currentVolume * closePercent;
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   if(closeVolume < minLot) return 0;
   
   closeVolume = MathRound(closeVolume / step) * step;
   closeVolume = NormalizeDouble(closeVolume, 2);
   
   double remainingVolume = currentVolume - closeVolume;
   if(remainingVolume < minLot) return 0;
   
   if(currentVolume < minLot * 2) return 0;
   
   return closeVolume;
}

//+------------------------------------------------------------------+
//| Partial Close Position                                          |
//+------------------------------------------------------------------+
bool CPositionManager::PartialClosePosition(ulong ticket, double closePercent)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = CalculatePartialCloseVolume(currentVolume, closePercent);
   
   if(closeVolume <= 0) return false;
   
   if(!m_trade.PositionClosePartial(ticket, closeVolume)) return false;
   
   int idx = FindStateIndex(ticket);
   if(idx != -1)
   {
      if(PositionSelectByTicket(ticket))
      {
         m_states[idx].openVolume = PositionGetDouble(POSITION_VOLUME);
         m_states[idx].partialClosePrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         m_states[idx].isPartialCloseDone = true;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| On Position Closed - Report to Risk Manager                     |
//+------------------------------------------------------------------+
void CPositionManager::OnPositionClosed(ulong ticket, double profit)
{
   Print("📊 Position #" + IntegerToString(ticket) + " closed with profit: $" + 
         DoubleToString(profit, 2));
   
   RemoveState(ticket);
   
   if(m_riskManager != NULL)
   {
      Print("📊 Reporting trade result to RiskManager: $" + DoubleToString(profit, 2));
      m_riskManager.OnTradeClosed(profit);
   }
}

//+------------------------------------------------------------------+
//| Check And Report Closed Positions                               |
//+------------------------------------------------------------------+
void CPositionManager::CheckAndReportClosedPositions()
{
   datetime now = TimeCurrent();
   if(now - m_lastPositionCheck < 2) return;
   m_lastPositionCheck = now;
   
   for(int i = ArraySize(m_states) - 1; i >= 0; i--)
   {
      ulong ticket = m_states[i].ticket;
      
      if(!PositionSelectByTicket(ticket))
      {
         double profit = 0;
         
         HistorySelect(0, TimeCurrent());
         int totalHistory = HistoryDealsTotal();
         
         for(int h = totalHistory - 1; h >= 0; h--)
         {
            ulong historyTicket = HistoryDealGetTicket(h);
            if(historyTicket <= 0) continue;
            
            ulong positionId = HistoryDealGetInteger(historyTicket, DEAL_POSITION_ID);
            if(positionId == ticket)
            {
               profit = HistoryDealGetDouble(historyTicket, DEAL_PROFIT);
               break;
            }
         }
         
         RemoveState(ticket);
         
         if(m_riskManager != NULL)
         {
            m_riskManager.OnTradeClosed(profit);
         }
         continue;
      }
      
      if(!IsOurPosition(ticket))
      {
         RemoveState(ticket);
         continue;
      }
   }
}

//+------------------------------------------------------------------+
//| Log SL Movement                                                 |
//+------------------------------------------------------------------+
void CPositionManager::LogSLMovement(ulong ticket, string source, double oldSL, double newSL, 
                                      double profitPips, string reason)
{
   bool shouldLog = m_logSLMovements || g_logSLMovements || g_debugPositionManager;
   if(!shouldLog) return;
   
   Print("🔍🔍🔍 SL MOVEMENT DETECTED! 🔍🔍🔍");
   Print("   Position #", ticket);
   Print("   Source: ", source);
   Print("   Old SL: ", DoubleToString(oldSL, _Digits));
   Print("   New SL: ", DoubleToString(newSL, _Digits));
   Print("   Profit: ", DoubleToString(profitPips, 1), " pips");
   Print("   Reason: ", reason);
   Print("   ═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Manage Positions                                                |
//+------------------------------------------------------------------+
void CPositionManager::ManagePositions()
{
   CheckAndReportClosedPositions();
   
   bool hasBoost = IsBoostActive();
   
   if(m_portfolioManager != NULL)
      m_lossManagementEnabled = m_portfolioManager.IsLossManagementEnabled();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!IsOurPosition(ticket)) continue;
      
      PositionState state;
      if(!GetState(ticket, state))
      {
         PositionSelectByTicket(ticket);
         
         int signal = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double stopLoss = PositionGetDouble(POSITION_SL);
         double takeProfit = PositionGetDouble(POSITION_TP);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         AddState(ticket, signal, entryPrice, stopLoss, takeProfit, volume);
         continue;
      }
      
      ManageSinglePosition(ticket);
   }
}

//+------------------------------------------------------------------+
//| Manage Single Position                                          |
//+------------------------------------------------------------------+
void CPositionManager::ManageSinglePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      RemoveState(ticket);
      return;
   }
   
   PositionState state;
   if(!GetState(ticket, state)) return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   bool isBuy = (type == POSITION_TYPE_BUY);
   
   bool hasBoost = IsBoostActive();
   double profitPips = isBuy ? (currentPrice - openPrice) / point 
                             : (openPrice - currentPrice) / point;
   
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   
   // ═══════════════════════════════════════════════════════════
   // STEP 1: BREAKEVEN MANAGEMENT
   // ═══════════════════════════════════════════════════════════
   if(InpUseBreakeven && !state.isBreakevenSet)
   {
      if(profitPips >= InpBreakevenPips)
      {
         double oldSL = currentSL;
         
         if(!state.isPartialCloseDone && state.openVolume > 0)
         {
            double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
            if(state.openVolume >= minLot * 2)
            {
               PartialClosePosition(ticket, 0.5);
               
               int idx = FindStateIndex(ticket);
               if(idx != -1)
               {
                  m_states[idx].isPartialCloseDone = true;
                  m_states[idx].isBreakevenSet = true;
                  if(PositionSelectByTicket(ticket))
                     m_states[idx].openVolume = PositionGetDouble(POSITION_VOLUME);
               }
            }
         }
         
         double newSL = isBuy ? openPrice + (5 * point) : openPrice - (5 * point);
         
         if(newSL != oldSL)
            LogSLMovement(ticket, "BREAKEVEN", oldSL, newSL, profitPips, 
                          "Breakeven triggered at " + IntegerToString(InpBreakevenPips) + " pips");
         
         SetBreakeven(ticket, isBuy);
         
         int idx = FindStateIndex(ticket);
         if(idx != -1)
         {
            m_states[idx].isBreakevenSet = true;
            m_states[idx].lastTrailSL = PositionGetDouble(POSITION_SL);
         }
      }
   }
   
   // ═══════════════════════════════════════════════════════════
   // STEP 2: TRAILING STOP MANAGEMENT
   // ═══════════════════════════════════════════════════════════
   if(InpUseTrailingStop)
   {
      if(PositionSelectByTicket(ticket))
      {
         currentSL = PositionGetDouble(POSITION_SL);
         currentTP = PositionGetDouble(POSITION_TP);
      }
      
      if(profitPips >= InpTrailingStartPips)
      {
         double newSL = 0;
         double trailDistance = InpTrailingStopPips * point;
         bool slMoved = false;
         double oldSL = currentSL;
         
         if(isBuy)
         {
            newSL = currentPrice - trailDistance;
            if(newSL > currentSL) slMoved = true;
         }
         else
         {
            newSL = currentPrice + trailDistance;
            if(newSL < currentSL) slMoved = true;
         }
         
         if(slMoved)
         {
            LogSLMovement(ticket, "TRAILING_STOP", currentSL, newSL, profitPips, 
                          "Trailing stop at " + IntegerToString(InpTrailingStopPips) + " pips behind price");
            
            double newTP = currentTP;
            
            if(hasBoost)
               newTP = ApplyTrailingTP(ticket, isBuy);
            
            if(newSL != currentSL || newTP != currentTP)
            {
               ModifySLTP(ticket, newSL, newTP);
               
               int idx = FindStateIndex(ticket);
               if(idx != -1)
               {
                  m_states[idx].lastTrailSL = newSL;
                  m_states[idx].lastTrailTP = newTP;
                  m_states[idx].isTrailingActive = true;
                  m_states[idx].boostActive = hasBoost;
                  if(hasBoost) m_states[idx].lastBoostTP = newTP;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Set Breakeven                                                   |
//+------------------------------------------------------------------+
void CPositionManager::SetBreakeven(ulong ticket, bool isBuy)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);
   
   double bufferPoints = InpBreakevenBuffer * point;
   
   double breakevenSL = isBuy ? entryPrice + bufferPoints : entryPrice - bufferPoints;
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) 
                                : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   
   if(isBuy)
   {
      if(breakevenSL >= currentPrice)
         breakevenSL = currentPrice - (10 * point);
      
      if(breakevenSL <= entryPrice)
         breakevenSL = entryPrice + (MathMax(InpBreakevenBuffer, 10) * point);
   }
   else
   {
      if(breakevenSL <= currentPrice)
         breakevenSL = currentPrice + (10 * point);
      
      if(breakevenSL >= entryPrice)
         breakevenSL = entryPrice - (MathMax(InpBreakevenBuffer, 10) * point);
   }
   
   double profitPips = 0;
   if(isBuy)
      profitPips = (currentPrice - entryPrice) / point;
   else
      profitPips = (entryPrice - currentPrice) / point;
   
   if(breakevenSL != currentSL)
   {
      LogSLMovement(ticket, "SET_BREAKEVEN_FUNCTION", currentSL, breakevenSL, profitPips, 
                    "Breakeven with buffer: " + IntegerToString(InpBreakevenBuffer) + " pips");
   }
   
   ModifySLTP(ticket, breakevenSL, currentTP);
}

//+------------------------------------------------------------------+
//| Apply Trailing TP                                               |
//+------------------------------------------------------------------+
double CPositionManager::ApplyTrailingTP(ulong ticket, bool isBuy)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
                                : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   double tpDistance = m_boostTPDistance * point;
   double newTP = 0;
   bool shouldMove = false;
   
   if(isBuy)
   {
      newTP = currentPrice + tpDistance;
      if(newTP > currentTP) shouldMove = true;
   }
   else
   {
      newTP = currentPrice - tpDistance;
      if(newTP < currentTP) shouldMove = true;
   }
   
   if(shouldMove) return newTP;
   return currentTP;
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                             |
//+------------------------------------------------------------------+
void CPositionManager::ApplyTrailingStop(ulong ticket, bool isBuy)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
                                : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);
   
   double profitPips = isBuy ? (currentPrice - openPrice) / point 
                             : (openPrice - currentPrice) / point;
   
   double trailDistance = InpTrailingStopPips * point;
   double newSL = isBuy ? currentPrice - trailDistance 
                        : currentPrice + trailDistance;
   
   bool shouldMove = isBuy ? (newSL > currentSL) : (newSL < currentSL);
   
   if(shouldMove)
   {
      LogSLMovement(ticket, "APPLY_TRAILING_STOP_FUNCTION", currentSL, newSL, profitPips, 
                    "Direct call to ApplyTrailingStop()");
      
      double newTP = currentTP;
      
      if(IsBoostActive())
         newTP = ApplyTrailingTP(ticket, isBuy);
      
      ModifySLTP(ticket, newSL, newTP);
   }
}

//+------------------------------------------------------------------+
//| Modify SLTP                                                     |
//+------------------------------------------------------------------+
void CPositionManager::ModifySLTP(ulong ticket, double newSL, double newTP)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.symbol = m_symbol;
   request.position = ticket;
   request.sl = newSL;
   request.tp = newTP;
   
   if(!m_trade.OrderSend(request, result))
   {
      Print("❌ Failed to modify position #", ticket, ": ", IntegerToString(result.retcode));
   }
}

//+------------------------------------------------------------------+
//| Close Position                                                  |
//+------------------------------------------------------------------+
void CPositionManager::ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   
   if(m_trade.PositionClose(ticket))
   {
      OnPositionClosed(ticket, profit);
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                             |
//+------------------------------------------------------------------+
void CPositionManager::CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(IsOurPosition(ticket))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         if(m_trade.PositionClose(ticket))
         {
            OnPositionClosed(ticket, profit);
         }
      }
   }
   ArrayResize(m_states, 0);
}

//+------------------------------------------------------------------+
//| GetOpenPrice                                                    |
//+------------------------------------------------------------------+
double CPositionManager::GetOpenPrice(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PRICE_OPEN);
}

//+------------------------------------------------------------------+
//| GetCurrentSL                                                    |
//+------------------------------------------------------------------+
double CPositionManager::GetCurrentSL(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_SL);
}

//+------------------------------------------------------------------+
//| GetCurrentTP                                                    |
//+------------------------------------------------------------------+
double CPositionManager::GetCurrentTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_TP);
}

//+------------------------------------------------------------------+
//| GetPositionType                                                 |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE CPositionManager::GetPositionType(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return POSITION_TYPE_BUY;
   return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
}

//+------------------------------------------------------------------+
//| GetPositionProfit                                               |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT);
}

//+------------------------------------------------------------------+
//| GetPositionVolume                                               |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionVolume(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_VOLUME);
}

//+------------------------------------------------------------------+
//| Print States                                                    |
//+------------------------------------------------------------------+
void CPositionManager::PrintStates()
{
   if(!g_debugPositionManager) return;
   
   Print("=== Position States (", ArraySize(m_states), ") ===");
   for(int i = 0; i < ArraySize(m_states); i++)
   {
      Print("#", m_states[i].ticket, 
            " | Signal: ", (m_states[i].signal == 1 ? "BUY" : "SELL"),
            " | Entry: ", m_states[i].entryPrice,
            " | SL: ", m_states[i].stopLoss,
            " | TP: ", m_states[i].takeProfit1,
            " | BE: ", m_states[i].isBreakevenSet ? "✅" : "❌");
   }
   Print("==========================");
}

//+------------------------------------------------------------------+
//| Print Config                                                    |
//+------------------------------------------------------------------+
void CPositionManager::PrintConfig()
{
   if(!g_debugPositionManager) return;
   
   Print("═══════════════════════════════════════════");
   Print("📋 SL/TP CONFIGURATION");
   Print("───────────────────────────────────────────");
   Print("Structure Enabled: " + (m_config.useStructure ? "✅ YES" : "❌ NO"));
   Print("ATR Enabled: " + (m_config.useATR ? "✅ YES" : "❌ NO"));
   Print("Buffer Enabled: " + (m_config.useBuffer ? "✅ YES" : "❌ NO"));
   Print("");
   Print("📊 STRUCTURE SETTINGS:");
   Print("   Min SL: " + IntegerToString(m_config.minSLPips) + "p");
   Print("   Max SL: " + IntegerToString(m_config.maxSLPips) + "p");
   Print("   Min TP: " + IntegerToString(m_config.minTPPips) + "p");
   Print("   Max TP: " + IntegerToString(m_config.maxTPPips) + "p");
   Print("   Min RR: " + DoubleToString(m_config.minRR, 1) + ":1");
   Print("   Max RR: " + DoubleToString(m_config.maxRR, 1) + ":1");
   Print("");
   Print("📊 ATR SETTINGS:");
   Print("   Period: " + IntegerToString(m_config.atrPeriod));
   Print("   SL Multiplier: " + DoubleToString(m_config.atrMultiplierSL, 1));
   Print("   TP Multiplier: " + DoubleToString(m_config.atrMultiplierTP, 1));
   Print("   Timeframe: " + EnumToString(m_config.atrTF));
   Print("");
   Print("📊 FALLBACK SETTINGS:");
   Print("   SL: " + IntegerToString(m_config.fallbackSL) + "p");
   Print("   TP: " + IntegerToString(m_config.fallbackTP) + "p");
   Print("");
   Print("📊 BUFFER SETTINGS:");
   Print("   SL Buffer: " + IntegerToString(m_config.slBuffer) + "p");
   Print("   TP Buffer: " + IntegerToString(m_config.tpBuffer) + "p");
   Print("═══════════════════════════════════════════");
}