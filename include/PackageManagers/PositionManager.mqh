//+------------------------------------------------------------------+
//|                     PositionManager.mqh                          |
//|              WITH PARTIAL CLOSE AT BREAKEVEN                    |
//|              v3.1 - LOSS MANAGEMENT SUPPORT                     |
//|              TP trails at 100 points when boost is active      |
//|              NEVER moves TP backward                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.1"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "PortfolioManager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE - SINGLE MAIN SWITCH                       |
//+------------------------------------------------------------------+
bool g_debugPositionManager = false;  // Set to true to enable all PositionManager debug logs

//+------------------------------------------------------------------+
//| Position Manager Class - With Boost-Aware TP Trailing          |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   string            m_symbol;
   int               m_magicNumber;
   int               m_maxSlippage;
   CTrade           *m_trade;
   CPortfolioManager *m_portfolioManager;
   PositionState    m_states[];
   
   // Boost-aware TP trailing settings
   double            m_boostTPDistance;     // Fixed 100 points when boost active
   double            m_currentBoost;        // Cached boost value
   datetime          m_lastBoostCheck;      // Last time boost was checked
   int               m_boostCheckInterval;  // How often to check boost (seconds)
   
   // ═══ NEW: Loss Management Settings (mirrored from PortfolioManager) ═══
   bool              m_lossManagementEnabled;
   double            m_lossCloseConfidence;
   
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
   
public:
   CPositionManager(string symbol, int magicNumber, CTrade &trade);
   ~CPositionManager();
   
   // Set Portfolio Manager reference
   void SetPortfolioManager(CPortfolioManager* portfolioManager) 
   { 
      m_portfolioManager = portfolioManager; 
      LOG_INFO("Portfolio Manager connected to Position Manager", g_debugPositionManager);
   }
   
   // ═══ NEW: Loss Management Configuration ═══
   void SetLossManagementEnabled(bool enable) { m_lossManagementEnabled = enable; }
   void SetLossCloseConfidence(double confidence) { m_lossCloseConfidence = confidence; }
   bool IsLossManagementEnabled() const { return m_lossManagementEnabled; }
   double GetLossCloseConfidence() const { return m_lossCloseConfidence; }
   
   bool ExecuteTrade(PrescribedTrade &signal, double lotSize);
   void ManagePositions();
   void CloseAllPositions();
   void ClosePosition(ulong ticket);
   
   void SetBreakeven(ulong ticket, bool isBuy);
   void ApplyTrailingStop(ulong ticket, bool isBuy);
   double ApplyTrailingTP(ulong ticket, bool isBuy);
   void ModifySLTP(ulong ticket, double newSL, double newTP);
   
   void AddState(ulong ticket, PrescribedTrade &signal, double lotSize);
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
   
   // Debug control
   static void SetGlobalDebug(bool enable) { g_debugPositionManager = enable; }
   static bool GetGlobalDebug() { return g_debugPositionManager; }
   
   // Boost control
   void SetBoostCheckInterval(int seconds) { m_boostCheckInterval = seconds; }
   void SetBoostTPDistance(double points) { m_boostTPDistance = points; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager(string symbol, int magicNumber, CTrade &trade)
{
   LOG_DEBUG("CPositionManager constructor called for " + symbol, g_debugPositionManager);
   
   m_symbol = symbol;
   m_magicNumber = magicNumber;
   m_trade = &trade;
   m_maxSlippage = InpMaxSlippage;
   m_portfolioManager = NULL;
   m_currentBoost = 0;
   m_lastBoostCheck = 0;
   m_boostCheckInterval = 2;
   m_boostTPDistance = 100.0;
   
   // ═══ NEW: Loss Management Settings ═══
   m_lossManagementEnabled = true;
   m_lossCloseConfidence = 30.0;
   
   ArrayResize(m_states, 0);
   
   LOG_INFO("Position Manager v3.1 initialized for " + symbol + " (Magic: " + IntegerToString(magicNumber) + ")", true);
   LOG_INFO("Boost TP distance: " + DoubleToString(m_boostTPDistance, 0) + " points", g_debugPositionManager);
   LOG_INFO("Loss Management: " + (m_lossManagementEnabled ? "ENABLED" : "DISABLED"), g_debugPositionManager);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager()
{
   LOG_DEBUG("CPositionManager destructor called", g_debugPositionManager);
   LOG_INFO("Position Manager destroyed", g_debugPositionManager);
}

//+------------------------------------------------------------------+
//| Update Boost - Check Portfolio Manager for boost               |
//+------------------------------------------------------------------+
void CPositionManager::UpdateBoost()
{
   g_debugPositionManager = false;  // Enable debug for this method
   if(m_portfolioManager == NULL)
   {
      LOG_DEBUG("Portfolio Manager not connected - boost unavailable", g_debugPositionManager);
      return;
   }
   
   datetime now = TimeCurrent();
   if(now - m_lastBoostCheck < m_boostCheckInterval)
      return;
   
   m_lastBoostCheck = now;
   
   bool wasBoostActive = (m_currentBoost > 0);
   
   m_currentBoost = m_portfolioManager.GetBoostPercentage();
   bool isBoostActive = (m_currentBoost > 0);
   
   if(isBoostActive && !wasBoostActive)
   {
      LOG_TRADE("🚀🚀🚀 BOOST STARTED! TP will trail at " + DoubleToString(m_boostTPDistance, 0) + " points");
   }
   else if(!isBoostActive && wasBoostActive)
   {
      LOG_WARNING("⛔⛔⛔ BOOST ENDED! TP trailing stopped");
   }
   else if(isBoostActive && g_debugPositionManager)
   {
      LOG_DEBUG("📊 Boost ACTIVE: +" + DoubleToString(m_currentBoost, 1) + "%", g_debugPositionManager);
   }
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
//| Get Boost TP Distance - Always 100 points when boost active    |
//+------------------------------------------------------------------+
double CPositionManager::GetBoostTPDistance()
{
   return m_boostTPDistance;
}

//+------------------------------------------------------------------+
//| Is Our Position                                                 |
//+------------------------------------------------------------------+
bool CPositionManager::IsOurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      LOG_DEBUG("Cannot select position #" + IntegerToString(ticket), g_debugPositionManager);
      return false;
   }
   
   int magic = (int)PositionGetInteger(POSITION_MAGIC);
   string symbol = PositionGetString(POSITION_SYMBOL);
   
   bool isOurs = (magic == m_magicNumber && symbol == m_symbol);
   LOG_DEBUG("Position #" + IntegerToString(ticket) + " is ours: " + (isOurs ? "YES" : "NO"), g_debugPositionManager);
   return isOurs;
}

//+------------------------------------------------------------------+
//| Is Position Still Open                                          |
//+------------------------------------------------------------------+
bool CPositionManager::IsPositionStillOpen(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      LOG_DEBUG("Position #" + IntegerToString(ticket) + " no longer open", g_debugPositionManager);
      return false;
   }
   
   return IsOurPosition(ticket);
}

//+------------------------------------------------------------------+
//| Find State Index                                                |
//+------------------------------------------------------------------+
int CPositionManager::FindStateIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(m_states); i++)
   {
      if(m_states[i].ticket == ticket)
         return i;
   }
   LOG_DEBUG("State not found for ticket #" + IntegerToString(ticket), g_debugPositionManager);
   return -1;
}

//+------------------------------------------------------------------+
//| Remove State                                                    |
//+------------------------------------------------------------------+
void CPositionManager::RemoveState(ulong ticket)
{
   int idx = FindStateIndex(ticket);
   if(idx == -1) 
   {
      LOG_DEBUG("Cannot remove state - not found for #" + IntegerToString(ticket), g_debugPositionManager);
      return;
   }
   
   for(int i = idx; i < ArraySize(m_states) - 1; i++)
      m_states[i] = m_states[i + 1];
   
   ArrayResize(m_states, ArraySize(m_states) - 1);
   LOG_DEBUG("State removed for #" + IntegerToString(ticket), g_debugPositionManager);
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
   
   double normalized = NormalizeDouble(lotSize, 2);
   LOG_DEBUG("Lot normalized: " + DoubleToString(lotSize, 2) + " -> " + DoubleToString(normalized, 2), g_debugPositionManager);
   return normalized;
}

//+------------------------------------------------------------------+
//| Calculate Partial Close Volume                                  |
//+------------------------------------------------------------------+
double CPositionManager::CalculatePartialCloseVolume(double currentVolume, double closePercent)
{
   LOG_DEBUG("CalculatePartialCloseVolume: currentVolume=" + DoubleToString(currentVolume, 2) + ", closePercent=" + DoubleToString(closePercent * 100, 0) + "%", g_debugPositionManager);
   
   double closeVolume = currentVolume * closePercent;
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   if(closeVolume < minLot)
   {
      LOG_WARNING("⚠️ Partial close volume (" + DoubleToString(closeVolume, 2) + 
          ") below minimum lot (" + DoubleToString(minLot, 2) + ")");
      return 0;
   }
   
   closeVolume = MathRound(closeVolume / step) * step;
   closeVolume = NormalizeDouble(closeVolume, 2);
   
   double remainingVolume = currentVolume - closeVolume;
   if(remainingVolume < minLot)
   {
      LOG_WARNING("⚠️ Remaining volume (" + DoubleToString(remainingVolume, 2) + 
          ") below minimum lot (" + DoubleToString(minLot, 2) + ")");
      return 0;
   }
   
   if(currentVolume < minLot * 2)
   {
      LOG_WARNING("⚠️ Position volume (" + DoubleToString(currentVolume, 2) + 
          ") too small for partial close (need at least " + 
          DoubleToString(minLot * 2, 2) + ")");
      return 0;
   }
   
   LOG_DEBUG("Partial close volume: " + DoubleToString(closeVolume, 2), g_debugPositionManager);
   return closeVolume;
}

//+------------------------------------------------------------------+
//| Partial Close Position                                          |
//+------------------------------------------------------------------+
bool CPositionManager::PartialClosePosition(ulong ticket, double closePercent)
{
   LOG_DEBUG("PartialClosePosition called for #" + IntegerToString(ticket) + " with " + DoubleToString(closePercent * 100, 0) + "%", g_debugPositionManager);
   
   if(!PositionSelectByTicket(ticket))
   {
      LOG_ERROR("Cannot select position #" + IntegerToString(ticket));
      return false;
   }
   
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = CalculatePartialCloseVolume(currentVolume, closePercent);
   
   if(closeVolume <= 0)
   {
      LOG_ERROR("Partial close volume invalid: " + DoubleToString(closeVolume, 2));
      return false;
   }
   
   double remainingVolume = currentVolume - closeVolume;
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   
   if(remainingVolume < minLot)
   {
      LOG_ERROR("Remaining volume too small: " + DoubleToString(remainingVolume, 2));
      return false;
   }
   
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   LOG_TRADE("📊📊📊 PARTIAL CLOSE EXECUTED! 📊📊📊");
   LOG_TRADE("   Position #" + IntegerToString(ticket));
   LOG_TRADE("   Closing: " + DoubleToString(closePercent * 100, 0) + "% (" + 
       DoubleToString(closeVolume, 2) + " lots)");
   LOG_TRADE("   Remaining: " + DoubleToString(remainingVolume, 2) + " lots");
   LOG_TRADE("═══════════════════════════════════════════════════════════");
   
   if(!m_trade.PositionClosePartial(ticket, closeVolume))
   {
      LOG_ERROR("Partial close failed for #" + IntegerToString(ticket));
      return false;
   }
   
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
   
   LOG_DEBUG("Partial close successful for #" + IntegerToString(ticket), g_debugPositionManager);
   return true;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                   |
//+------------------------------------------------------------------+
bool CPositionManager::ExecuteTrade(PrescribedTrade &signal, double lotSize)
{
   g_debugPositionManager = true;  // Enable debug for this method
   LOG_DEBUG("ExecuteTrade called for signal " + IntegerToString(signal.signal), g_debugPositionManager);
   
   if(PositionsTotal() >= InpMaxPositions)
   {
      LOG_WARNING("⚠️ Max positions reached");
      return false;
   }
   
   lotSize = NormalizeLotSize(lotSize);
   if(lotSize <= 0)
   {
      LOG_ERROR("Invalid lot size");
      return false;
   }
   
   LOG_DEBUG("🔍🔍🔍 POSITION MANAGER RECEIVED:", g_debugPositionManager);
   LOG_DEBUG("   signal.signal = " + IntegerToString(signal.signal), g_debugPositionManager);
   LOG_DEBUG("   signal.entryPrice = " + DoubleToString(signal.entryPrice, _Digits), g_debugPositionManager);
   LOG_DEBUG("   signal.stopLoss = " + DoubleToString(signal.stopLoss, _Digits), g_debugPositionManager);
   LOG_DEBUG("   signal.takeProfit = " + DoubleToString(signal.takeProfit, _Digits), g_debugPositionManager);
   LOG_DEBUG("   lotSize = " + DoubleToString(lotSize, 2), g_debugPositionManager);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.symbol = m_symbol;
   request.volume = lotSize;
   request.deviation = m_maxSlippage;
   request.magic = m_magicNumber;
   request.comment = "PBR " + (signal.signal == 1 ? "BUY" : "SELL");
   
   if(signal.signal == 1)
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      request.sl = signal.stopLoss;
      request.tp = signal.takeProfit;
   }
   else
   {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      request.sl = signal.stopLoss;
      request.tp = signal.takeProfit;
   }
   
   if(!m_trade.OrderSend(request, result))
   {
      LOG_ERROR("Trade failed: " + IntegerToString(result.retcode));
      return false;
   }
   
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      LOG_TRADE("✅ Trade executed at " + DoubleToString(request.price, _Digits));
      LOG_INFO("📊 SL: " + DoubleToString(signal.stopLoss, _Digits) + 
          " | TP: " + DoubleToString(signal.takeProfit, _Digits), g_debugPositionManager);
      
      AddState(result.order, signal, lotSize);
      
      // ============================================================
      // ═══ FIX: NOTIFY PORTFOLIO MANAGER ABOUT NEW POSITION ═══
      // ============================================================
      if(m_portfolioManager != NULL)
      {
         m_portfolioManager.OnTradeOpened(result.order, signal.entryPrice, signal.stopLoss);
         LOG_DEBUG("✅ PortfolioManager notified about position #" + IntegerToString(result.order), g_debugPositionManager);
      }
      else
      {
         LOG_WARNING("⚠️ PortfolioManager is NULL - position not being monitored");
      }
      
      return true;
   }
   else
   {
      LOG_ERROR("Trade failed: " + IntegerToString(result.retcode));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Add State                                                       |
//+------------------------------------------------------------------+
void CPositionManager::AddState(ulong ticket, PrescribedTrade &signal, double lotSize)
{
   LOG_DEBUG("AddState called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   int idx = FindStateIndex(ticket);
   if(idx != -1)
   {
      LOG_WARNING("⚠️ State already exists for #" + IntegerToString(ticket));
      return;
   }
   
   int newIdx = ArraySize(m_states);
   ArrayResize(m_states, newIdx + 1);
   
   m_states[newIdx].ticket = ticket;
   m_states[newIdx].signal = signal.signal;
   m_states[newIdx].entryPrice = signal.entryPrice;
   m_states[newIdx].stopLoss = signal.stopLoss;
   m_states[newIdx].takeProfit1 = signal.takeProfit;
   m_states[newIdx].takeProfit2 = signal.takeProfit2;
   m_states[newIdx].partialLevel75 = signal.partialLevel75;
   m_states[newIdx].isBreakevenSet = false;
   m_states[newIdx].isTrailingActive = false;
   m_states[newIdx].isPartialCloseDone = false;
   m_states[newIdx].openVolume = lotSize;
   m_states[newIdx].originalVolume = lotSize;
   m_states[newIdx].lastTrailSL = signal.stopLoss;
   m_states[newIdx].lastTrailTP = signal.takeProfit;
   m_states[newIdx].partialClosePrice = 0;
   m_states[newIdx].boostActive = false;
   m_states[newIdx].boostTPDistance = m_boostTPDistance;
   m_states[newIdx].lastBoostTP = signal.takeProfit;
   
   LOG_INFO("✅ State added for #" + IntegerToString(ticket) + " (Volume: " + DoubleToString(lotSize, 2) + ")", g_debugPositionManager);
}

//+------------------------------------------------------------------+
//| Get State                                                       |
//+------------------------------------------------------------------+
bool CPositionManager::GetState(ulong ticket, PositionState &state)
{
   LOG_DEBUG("GetState called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   if(!IsPositionStillOpen(ticket))
   {
      LOG_DEBUG("Position #" + IntegerToString(ticket) + " not open, removing state", g_debugPositionManager);
      RemoveState(ticket);
      return false;
   }
   
   int idx = FindStateIndex(ticket);
   if(idx == -1)
   {
      LOG_DEBUG("State not found for #" + IntegerToString(ticket), g_debugPositionManager);
      return false;
   }
   
   state = m_states[idx];
   LOG_DEBUG("State retrieved for #" + IntegerToString(ticket), g_debugPositionManager);
   return true;
}

//+------------------------------------------------------------------+
//| Get Open Position Count                                         |
//+------------------------------------------------------------------+
int CPositionManager::GetOpenPositionCount()
{
   int count = PositionsTotal();
   LOG_DEBUG("Open position count: " + IntegerToString(count), g_debugPositionManager);
   return count;
}

//+------------------------------------------------------------------+
//| Has Open Positions                                              |
//+------------------------------------------------------------------+
bool CPositionManager::HasOpenPositions()
{
   bool hasPos = PositionsTotal() > 0;
   LOG_DEBUG("Has open positions: " + (hasPos ? "YES" : "NO"), g_debugPositionManager);
   return hasPos;
}

//+------------------------------------------------------------------+
//| Manage Positions                                                |
//+------------------------------------------------------------------+
void CPositionManager::ManagePositions()
{
   LOG_DEBUG("ManagePositions called - " + IntegerToString(PositionsTotal()) + " total positions", g_debugPositionManager);
   
   // Update boost status at start of each cycle
   bool hasBoost = IsBoostActive();
   
   // ═══ NEW: Sync loss management settings from PortfolioManager ═══
   if(m_portfolioManager != NULL)
   {
      m_lossManagementEnabled = m_portfolioManager.IsLossManagementEnabled();
      m_lossCloseConfidence = m_portfolioManager.GetLossCloseConfidence();
   }
   
   if(hasBoost && g_debugPositionManager)
   {
      LOG_DEBUG("🚀 BOOST ACTIVE: +" + DoubleToString(m_currentBoost, 1) + "% - TP trailing at " + 
          DoubleToString(m_boostTPDistance, 0) + " points", g_debugPositionManager);
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!IsOurPosition(ticket))
         continue;
      
      PositionState state;
      if(!GetState(ticket, state))
      {
         LOG_WARNING("⚠️ Position #" + IntegerToString(ticket) + " has no state - creating...");
         PositionSelectByTicket(ticket);
         
         PrescribedTrade tempSignal;
         tempSignal.signal = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
         tempSignal.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         tempSignal.stopLoss = PositionGetDouble(POSITION_SL);
         tempSignal.takeProfit = 0;
         tempSignal.takeProfit2 = PositionGetDouble(POSITION_TP);
         tempSignal.partialLevel75 = 0;
         
         double volume = PositionGetDouble(POSITION_VOLUME);
         AddState(ticket, tempSignal, volume);
         continue;
      }
      
      ManageSinglePosition(ticket);
   }
}

//+------------------------------------------------------------------+
//| Manage Single Position - WITH BOOST-AWARE TP TRAILING          |
//+------------------------------------------------------------------+
void CPositionManager::ManageSinglePosition(ulong ticket)
{
   g_debugPositionManager = false;  // Enable debug for this method
   LOG_DEBUG("ManageSinglePosition called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   if(!PositionSelectByTicket(ticket))
   {
      LOG_DEBUG("Cannot select position #" + IntegerToString(ticket) + " - removing state", g_debugPositionManager);
      RemoveState(ticket);
      return;
   }
   
   PositionState state;
   if(!GetState(ticket, state))
      return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   bool isBuy = (type == POSITION_TYPE_BUY);
   
   bool hasBoost = IsBoostActive();
   double profitPips = isBuy ? (currentPrice - openPrice) / point 
                             : (openPrice - currentPrice) / point;
   
   LOG_DEBUG("Position #" + IntegerToString(ticket) + " | Profit: " + DoubleToString(profitPips, 1) + " pips | Boost: " + (hasBoost ? "ACTIVE" : "INACTIVE"), g_debugPositionManager);
   
   // ═══════════════════════════════════════════════════════════
   // STEP 1: BREAKEVEN MANAGEMENT WITH PARTIAL CLOSE
   // ═══════════════════════════════════════════════════════════
   if(InpUseBreakeven && !state.isBreakevenSet)
   {
      if(profitPips >= InpBreakevenPips)
      {
         LOG_TRADE("═══════════════════════════════════════════════════════════");
         LOG_TRADE("📈📈📈 BREAKEVEN TRIGGERED! 📈📈📈");
         LOG_TRADE("   Position #" + IntegerToString(ticket));
         LOG_TRADE("   Profit: " + DoubleToString(profitPips, 1) + " pips");
         LOG_TRADE("   Threshold: " + IntegerToString(InpBreakevenPips) + " pips");
         LOG_TRADE("═══════════════════════════════════════════════════════════");
         
         if(!state.isPartialCloseDone && state.openVolume > 0)
         {
            double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
            
            if(state.openVolume >= minLot * 2)
            {
               LOG_TRADE("🔹🔹🔹 ATTEMPTING PARTIAL CLOSE (50%) 🔹🔹🔹");
               
               if(PartialClosePosition(ticket, 0.5))
               {
                  LOG_TRADE("✅ 50% partial close executed successfully!");
                  
                  int idx = FindStateIndex(ticket);
                  if(idx != -1)
                  {
                     m_states[idx].isPartialCloseDone = true;
                     m_states[idx].isBreakevenSet = true;
                     
                     if(PositionSelectByTicket(ticket))
                     {
                        m_states[idx].openVolume = PositionGetDouble(POSITION_VOLUME);
                     }
                  }
               }
               else
               {
                  LOG_ERROR("❌ Partial close failed - continuing with breakeven only");
               }
            }
            else
            {
               LOG_WARNING("⚠️ Position too small for partial close (" + 
                   DoubleToString(state.openVolume, 2) + " lots)");
            }
         }
         
         SetBreakeven(ticket, isBuy);
         
         int idx = FindStateIndex(ticket);
         if(idx != -1)
         {
            m_states[idx].isBreakevenSet = true;
            m_states[idx].lastTrailSL = PositionGetDouble(POSITION_SL);
         }
         
         LOG_INFO("📈 Breakeven set for position #" + IntegerToString(ticket), g_debugPositionManager);
      }
   }
   
   // ═══════════════════════════════════════════════════════════
   // STEP 2: TRAILING STOP MANAGEMENT
   // ═══════════════════════════════════════════════════════════
   if(InpUseTrailingStop)
   {
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      if(profitPips >= InpTrailingStartPips)
      {
         double newSL = 0;
         double trailDistance = InpTrailingStopPips * point;
         bool slMoved = false;
         
         if(isBuy)
         {
            newSL = currentPrice - trailDistance;
            if(newSL > currentSL)
            {
               slMoved = true;
            }
         }
         else
         {
            newSL = currentPrice + trailDistance;
            if(newSL < currentSL)
            {
               slMoved = true;
            }
         }
         
         if(slMoved)
         {
            LOG_TRADE("═══════════════════════════════════════════════════════════");
            LOG_TRADE("🔹🔹🔹 TRAILING STOP MOVED! 🔹🔹🔹");
            LOG_TRADE("   Position #" + IntegerToString(ticket));
            LOG_TRADE("   Old SL: " + DoubleToString(currentSL, _Digits));
            LOG_TRADE("   New SL: " + DoubleToString(newSL, _Digits));
            LOG_TRADE("   Profit: " + DoubleToString(profitPips, 1) + " pips");
            LOG_TRADE("═══════════════════════════════════════════════════════════");
            
            double newTP = currentTP;
            
            // ═══════════════════════════════════════════════════════════
            // STEP 3: TP TRAILING - ONLY WHEN BOOST ACTIVE
            // Keeps TP at fixed 100 points from current price
            // NEVER moves backward
            // ═══════════════════════════════════════════════════════════
            if(hasBoost)
            {
               newTP = ApplyTrailingTP(ticket, isBuy);
            }
            else
            {
               if(g_debugPositionManager)
               {
                  LOG_DEBUG("⛔ Boost ended - TP frozen at " + DoubleToString(currentTP, _Digits), g_debugPositionManager);
               }
            }
            
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
                  if(hasBoost)
                  {
                     m_states[idx].lastBoostTP = newTP;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing TP - ONLY when boost active                      |
//| Keeps TP at fixed 100 points from current price                |
//| NEVER moves backward                                            |
//+------------------------------------------------------------------+
double CPositionManager::ApplyTrailingTP(ulong ticket, bool isBuy)
{
   LOG_DEBUG("ApplyTrailingTP called for #" + IntegerToString(ticket) + " (isBuy=" + (isBuy ? "true" : "false") + ")", g_debugPositionManager);
   
   if(!PositionSelectByTicket(ticket))
   {
      LOG_ERROR("Cannot select position #" + IntegerToString(ticket));
      return 0;
   }
   
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
      if(newTP > currentTP)
      {
         shouldMove = true;
      }
   }
   else
   {
      newTP = currentPrice - tpDistance;
      if(newTP < currentTP)
      {
         shouldMove = true;
      }
   }
   
   if(shouldMove)
   {
      LOG_TRADE("═══════════════════════════════════════════════");
      LOG_TRADE("📈📈📈 TP TRAILING (BOOST ACTIVE) 📈📈📈");
      LOG_TRADE("   Position #" + IntegerToString(ticket));
      LOG_TRADE("   TP Distance: " + DoubleToString(m_boostTPDistance, 0) + " points");
      LOG_TRADE("   Current Price: " + DoubleToString(currentPrice, _Digits));
      LOG_TRADE("   Old TP: " + DoubleToString(currentTP, _Digits));
      LOG_TRADE("   New TP: " + DoubleToString(newTP, _Digits));
      LOG_TRADE("   Move: " + (isBuy ? "UP (BUY)" : "DOWN (SELL)"));
      LOG_TRADE("═══════════════════════════════════════════════");
      
      return newTP;
   }
   else
   {
      if(g_debugPositionManager)
      {
         LOG_DEBUG("⏳ TP NOT MOVED - would move backward", g_debugPositionManager);
         LOG_DEBUG("   Current TP: " + DoubleToString(currentTP, _Digits), g_debugPositionManager);
         LOG_DEBUG("   Proposed TP: " + DoubleToString(newTP, _Digits), g_debugPositionManager);
      }
   }
   
   return currentTP;
}

//+------------------------------------------------------------------+
//| Set Breakeven                                                   |
//+------------------------------------------------------------------+
void CPositionManager::SetBreakeven(ulong ticket, bool isBuy)
{
   LOG_DEBUG("SetBreakeven called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   if(!PositionSelectByTicket(ticket))
   {
      LOG_ERROR("Cannot select position #" + IntegerToString(ticket));
      return;
   }
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double currentTP = PositionGetDouble(POSITION_TP);
   
   double breakevenSL = isBuy ? entryPrice + (5 * point) 
                               : entryPrice - (5 * point);
   
   LOG_DEBUG("Breakeven SL: " + DoubleToString(breakevenSL, _Digits), g_debugPositionManager);
   ModifySLTP(ticket, breakevenSL, currentTP);
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                             |
//+------------------------------------------------------------------+
void CPositionManager::ApplyTrailingStop(ulong ticket, bool isBuy)
{
   LOG_DEBUG("ApplyTrailingStop called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   if(!PositionSelectByTicket(ticket))
   {
      LOG_ERROR("Cannot select position #" + IntegerToString(ticket));
      return;
   }
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
                                : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);
   
   double trailDistance = InpTrailingStopPips * point;
   double newSL = isBuy ? currentPrice - trailDistance 
                        : currentPrice + trailDistance;
   
   bool shouldMove = isBuy ? (newSL > currentSL) : (newSL < currentSL);
   
   if(shouldMove)
   {
      double newTP = currentTP;
      
      if(IsBoostActive())
      {
         newTP = ApplyTrailingTP(ticket, isBuy);
      }
      
      ModifySLTP(ticket, newSL, newTP);
   }
}

//+------------------------------------------------------------------+
//| Modify SLTP                                                     |
//+------------------------------------------------------------------+
void CPositionManager::ModifySLTP(ulong ticket, double newSL, double newTP)
{
   LOG_DEBUG("ModifySLTP called for #" + IntegerToString(ticket) + " | SL: " + DoubleToString(newSL, _Digits) + " | TP: " + DoubleToString(newTP, _Digits), g_debugPositionManager);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.symbol = m_symbol;
   request.position = ticket;
   request.sl = newSL;
   request.tp = newTP;
   
   if(!m_trade.OrderSend(request, result))
   {
      LOG_ERROR("Failed to modify position #" + IntegerToString(ticket) + 
                ": " + IntegerToString(result.retcode));
   }
   else
   {
      LOG_DEBUG("Modify successful for #" + IntegerToString(ticket), g_debugPositionManager);
   }
}

//+------------------------------------------------------------------+
//| Close Position                                                  |
//+------------------------------------------------------------------+
void CPositionManager::ClosePosition(ulong ticket)
{
   LOG_DEBUG("ClosePosition called for #" + IntegerToString(ticket), g_debugPositionManager);
   
   if(!m_trade.PositionClose(ticket))
   {
      LOG_ERROR("Failed to close position #" + IntegerToString(ticket));
      return;
   }
   
   LOG_TRADE("✅ Position #" + IntegerToString(ticket) + " closed");
   RemoveState(ticket);
}

//+------------------------------------------------------------------+
//| Close All Positions                                             |
//+------------------------------------------------------------------+
void CPositionManager::CloseAllPositions()
{
   LOG_WARNING("🔴 Closing all positions...");
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(IsOurPosition(ticket))
      {
         LOG_DEBUG("Closing position #" + IntegerToString(ticket), g_debugPositionManager);
         m_trade.PositionClose(ticket);
      }
   }
   
   ArrayResize(m_states, 0);
   LOG_INFO("✅ All positions closed", g_debugPositionManager);
}

//+------------------------------------------------------------------+
//| Print States                                                    |
//+------------------------------------------------------------------+
void CPositionManager::PrintStates()
{
   if(!g_debugPositionManager)
   {
      Print("[PositionManager] Debug logging disabled - use SetGlobalDebug(true)");
      return;
   }
   
   Print("=== Position States (", ArraySize(m_states), ") ===");
   for(int i = 0; i < ArraySize(m_states); i++)
   {
      Print("#", m_states[i].ticket, 
            " | Signal: ", (m_states[i].signal == 1 ? "BUY" : "SELL"),
            " | Entry: ", m_states[i].entryPrice,
            " | BE: ", m_states[i].isBreakevenSet ? "✅" : "❌",
            " | Partial: ", m_states[i].isPartialCloseDone ? "✅" : "❌",
            " | Trail: ", m_states[i].isTrailingActive ? "✅" : "❌",
            " | Boost TP: ", m_states[i].boostActive ? "✅" : "❌",
            " | TP Dist: ", DoubleToString(m_states[i].boostTPDistance, 0),
            " | Volume: ", DoubleToString(m_states[i].openVolume, 2));
   }
   Print("==========================");
}

//+------------------------------------------------------------------+
//| Getters                                                         |
//+------------------------------------------------------------------+
double CPositionManager::GetOpenPrice(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetOpenPrice: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return 0;
   }
   double price = PositionGetDouble(POSITION_PRICE_OPEN);
   LOG_DEBUG("GetOpenPrice #" + IntegerToString(ticket) + ": " + DoubleToString(price, _Digits), g_debugPositionManager);
   return price;
}

double CPositionManager::GetCurrentSL(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetCurrentSL: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return 0;
   }
   double sl = PositionGetDouble(POSITION_SL);
   LOG_DEBUG("GetCurrentSL #" + IntegerToString(ticket) + ": " + DoubleToString(sl, _Digits), g_debugPositionManager);
   return sl;
}

double CPositionManager::GetCurrentTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetCurrentTP: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return 0;
   }
   double tp = PositionGetDouble(POSITION_TP);
   LOG_DEBUG("GetCurrentTP #" + IntegerToString(ticket) + ": " + DoubleToString(tp, _Digits), g_debugPositionManager);
   return tp;
}

ENUM_POSITION_TYPE CPositionManager::GetPositionType(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetPositionType: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return POSITION_TYPE_BUY;
   }
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   LOG_DEBUG("GetPositionType #" + IntegerToString(ticket) + ": " + (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), g_debugPositionManager);
   return type;
}

double CPositionManager::GetPositionProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetPositionProfit: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return 0;
   }
   double profit = PositionGetDouble(POSITION_PROFIT);
   LOG_DEBUG("GetPositionProfit #" + IntegerToString(ticket) + ": " + DoubleToString(profit, 2), g_debugPositionManager);
   return profit;
}

double CPositionManager::GetPositionVolume(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) 
   {
      LOG_DEBUG("GetPositionVolume: Cannot select #" + IntegerToString(ticket), g_debugPositionManager);
      return 0;
   }
   double volume = PositionGetDouble(POSITION_VOLUME);
   LOG_DEBUG("GetPositionVolume #" + IntegerToString(ticket) + ": " + DoubleToString(volume, 2), g_debugPositionManager);
   return volume;
}