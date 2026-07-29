//+------------------------------------------------------------------+
//|                     PositionManager.mqh                          |
//|              WITH PARTIAL CLOSE AT BREAKEVEN                    |
//|              v3.5 - RISK MANAGER INTEGRATION                   |
//|              Reports trade results to RiskManager              |
//|              SL MOVEMENT LOGGING CAN BE TOGGLED               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.5"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"
#include "PortfolioManager.mqh"
#include "Riskmanager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE - SL MOVEMENT LOGGING                      |
//+------------------------------------------------------------------+
bool g_debugPositionManager = false;      // SET TO TRUE TO TRACE SL MOVEMENTS
bool g_logSLMovements = false;            // ═══ NEW: SEPARATE TOGGLE FOR SL LOGS ═══

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
   CRiskManager     *m_riskManager;        // ═══ NEW: RISK MANAGER ═══
   PositionState    m_states[];
   
   // Boost-aware TP trailing settings
   double            m_boostTPDistance;     // Fixed 100 points when boost active
   double            m_currentBoost;        // Cached boost value
   datetime          m_lastBoostCheck;      // Last time boost was checked
   int               m_boostCheckInterval;  // How often to check boost (seconds)
   
   // Loss Management Settings
   bool              m_lossManagementEnabled;
   
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
   
   // ═══ NEW: TRADE CLOSE HANDLING ═══
   void OnPositionClosed(ulong ticket, double profit);
   void CheckAndReportClosedPositions();
   datetime m_lastPositionCheck;
   
   // ═══ SL MOVEMENT LOGGING - NOW WITH TOGGLE ═══
   bool m_logSLMovements;                  // Instance-level toggle
   void LogSLMovement(ulong ticket, string source, double oldSL, double newSL, double profitPips, string reason);
   
public:
   CPositionManager(string symbol, int magicNumber, CTrade &trade);
   ~CPositionManager();
   
   void SetPortfolioManager(CPortfolioManager* portfolioManager) 
   { 
      m_portfolioManager = portfolioManager; 
   }
   
   // ═══ NEW: SET RISK MANAGER ═══
   void SetRiskManager(CRiskManager* riskManager)
   {
      m_riskManager = riskManager;
   }
   
   // ═══ NEW: TOGGLE SL MOVEMENT LOGGING ═══
   void SetLogSLMovements(bool enable) { m_logSLMovements = enable; }
   bool GetLogSLMovements() const { return m_logSLMovements; }
   static void SetGlobalLogSLMovements(bool enable) { g_logSLMovements = enable; }
   static bool GetGlobalLogSLMovements() { return g_logSLMovements; }
   
   void SetLossManagementEnabled(bool enable) { m_lossManagementEnabled = enable; }
   bool IsLossManagementEnabled() const { return m_lossManagementEnabled; }
   
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
   
   static void SetGlobalDebug(bool enable) { g_debugPositionManager = enable; }
   static bool GetGlobalDebug() { return g_debugPositionManager; }
   
   void SetBoostCheckInterval(int seconds) { m_boostCheckInterval = seconds; }
   void SetBoostTPDistance(double points) { m_boostTPDistance = points; }
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
   m_logSLMovements = false;      // ═══ DEFAULT: SL LOGGING OFF ═══
   ArrayResize(m_states, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager()
{
   // Cleanup
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
   {
      return false;
   }
   
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
//| ═══ ON POSITION CLOSED - REPORT TO RISK MANAGER ═══           |
//+------------------------------------------------------------------+
void CPositionManager::OnPositionClosed(ulong ticket, double profit)
{
   LOG_DEBUG("📊 Position #" + IntegerToString(ticket) + " closed with profit: $" + 
             DoubleToString(profit, 2), g_debugPositionManager);
   
   RemoveState(ticket);
   
   if(m_riskManager != NULL)
   {
      LOG_DEBUG("📊 Reporting trade result to RiskManager: $" + DoubleToString(profit, 2), 
                g_debugPositionManager);
      m_riskManager.OnTradeClosed(profit);
   }
   else
   {
      LOG_DEBUG("⚠️ No RiskManager set - trade result not reported", g_debugPositionManager);
   }
}

//+------------------------------------------------------------------+
//| ═══ CHECK AND REPORT CLOSED POSITIONS ═══                     |
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
         // ═══ POSITION CLOSED - GET PROFIT FROM HISTORY ═══
         double profit = 0;
         
         // Try to get profit from history
         HistorySelect(0, TimeCurrent());
         int totalHistory = HistoryDealsTotal();
         
         for(int h = totalHistory - 1; h >= 0; h--)
         {
            ulong historyTicket = HistoryDealGetTicket(h);
            if(historyTicket <= 0) continue;
            
            // Check if this deal is related to our position
            ulong positionId = HistoryDealGetInteger(historyTicket, DEAL_POSITION_ID);
            if(positionId == ticket)
            {
               profit = HistoryDealGetDouble(historyTicket, DEAL_PROFIT);
               LOG_DEBUG("📊 Found closed position #" + IntegerToString(ticket) + 
                         " with profit: $" + DoubleToString(profit, 2), 
                         g_debugPositionManager);
               break;
            }
         }
         
         // Remove state first
         RemoveState(ticket);
         
         // ═══ REPORT TO RISK MANAGER ═══
         if(m_riskManager != NULL)
         {
            LOG_DEBUG("📊 Reporting closed position #" + IntegerToString(ticket) + 
                      " to RiskManager: $" + DoubleToString(profit, 2), 
                      g_debugPositionManager);
            m_riskManager.OnTradeClosed(profit);
         }
         else
         {
            LOG_DEBUG("⚠️ No RiskManager set - trade result not reported", 
                      g_debugPositionManager);
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
//| Execute Trade                                                   |
//+------------------------------------------------------------------+
bool CPositionManager::ExecuteTrade(PrescribedTrade &signal, double lotSize)
{
   if(PositionsTotal() >= InpMaxPositions) return false;
   
   lotSize = NormalizeLotSize(lotSize);
   if(lotSize <= 0) return false;
   
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
   
   if(!m_trade.OrderSend(request, result)) return false;
   
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      AddState(result.order, signal, lotSize);
      
      if(m_portfolioManager != NULL)
      {
         m_portfolioManager.OnTradeOpened(result.order, signal.entryPrice, signal.stopLoss);
      }
      
      // ═══ NOTIFY RISK MANAGER OF EXECUTION ═══
      if(m_riskManager != NULL)
      {
         m_riskManager.OnTradeExecuted();
      }
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Add State                                                       |
//+------------------------------------------------------------------+
void CPositionManager::AddState(ulong ticket, PrescribedTrade &signal, double lotSize)
{
   int idx = FindStateIndex(ticket);
   if(idx != -1) return;
   
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
//| ═══ SL MOVEMENT LOG - NOW WITH TOGGLE ═══                     |
//+------------------------------------------------------------------+
void CPositionManager::LogSLMovement(ulong ticket, string source, double oldSL, double newSL, double profitPips, string reason)
{
   // ═══ CHECK BOTH INSTANCE AND GLOBAL TOGGLES ═══
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
   // ═══ CHECK FOR CLOSED POSITIONS FIRST ═══
   CheckAndReportClosedPositions();
   
   // Update boost status
   bool hasBoost = IsBoostActive();
   
   if(m_portfolioManager != NULL)
   {
      m_lossManagementEnabled = m_portfolioManager.IsLossManagementEnabled();
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!IsOurPosition(ticket)) continue;
      
      PositionState state;
      if(!GetState(ticket, state))
      {
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
//| Manage Single Position - WITH SL TRACING                        |
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
                  {
                     m_states[idx].openVolume = PositionGetDouble(POSITION_VOLUME);
                  }
               }
            }
         }
         
         double newSL = isBuy ? openPrice + (5 * point) : openPrice - (5 * point);
         
         // ═══ LOG BREAKEVEN SL MOVEMENT (TOGGLED) ═══
         if(newSL != oldSL)
         {
            LogSLMovement(ticket, "BREAKEVEN", oldSL, newSL, profitPips, "Breakeven triggered at " + IntegerToString(InpBreakevenPips) + " pips");
         }
         
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
            // ═══ LOG TRAILING SL MOVEMENT (TOGGLED) ═══
            LogSLMovement(ticket, "TRAILING_STOP", currentSL, newSL, profitPips, "Trailing stop at " + IntegerToString(InpTrailingStopPips) + " pips behind price");
            
            double newTP = currentTP;
            
            if(hasBoost)
            {
               newTP = ApplyTrailingTP(ticket, isBuy);
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
                  if(hasBoost) m_states[idx].lastBoostTP = newTP;
               }
            }
         }
      }
   }
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
   
   double breakevenSL = isBuy ? entryPrice + bufferPoints 
                               : entryPrice - bufferPoints;
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) 
                                : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   
   if(isBuy)
   {
      if(breakevenSL >= currentPrice)
      {
         breakevenSL = currentPrice - (10 * point);
         LOG_DEBUG("⚠️ Breakeven SL adjusted below current price", g_debugPositionManager);
      }
      
      if(breakevenSL <= entryPrice)
      {
         breakevenSL = entryPrice + (MathMax(InpBreakevenBuffer, 10) * point);
         LOG_DEBUG("⚠️ Breakeven SL adjusted above entry", g_debugPositionManager);
      }
   }
   else
   {
      if(breakevenSL <= currentPrice)
      {
         breakevenSL = currentPrice + (10 * point);
         LOG_DEBUG("⚠️ Breakeven SL adjusted above current price", g_debugPositionManager);
      }
      
      if(breakevenSL >= entryPrice)
      {
         breakevenSL = entryPrice - (MathMax(InpBreakevenBuffer, 10) * point);
         LOG_DEBUG("⚠️ Breakeven SL adjusted below entry", g_debugPositionManager);
      }
   }
   
   double profitPips = 0;
   if(isBuy)
      profitPips = (currentPrice - entryPrice) / point;
   else
      profitPips = (entryPrice - currentPrice) / point;
   
   // ═══ LOG BREAKEVEN SL MOVEMENT (TOGGLED) ═══
   if(breakevenSL != currentSL)
   {
      LogSLMovement(ticket, "SET_BREAKEVEN_FUNCTION", currentSL, breakevenSL, profitPips, 
                    "Breakeven with buffer: " + IntegerToString(InpBreakevenBuffer) + " pips");
   }
   
   LOG_DEBUG("🔴 SetBreakeven: entry=" + DoubleToString(entryPrice, _Digits) + 
             " | buffer=" + IntegerToString(InpBreakevenBuffer) + " pips" +
             " | newSL=" + DoubleToString(breakevenSL, _Digits) + 
             " | oldSL=" + DoubleToString(currentSL, _Digits), g_debugPositionManager);
   
   ModifySLTP(ticket, breakevenSL, currentTP);
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop - KEPT FOR BACKWARD COMPATIBILITY          |
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
   
   // ═══ ONLY LOG IF TOGGLED ON ═══
   if(m_logSLMovements || g_logSLMovements || g_debugPositionManager)
   {
      Print("🔴🔴🔴 ApplyTrailingStop() CALLED! 🔴🔴🔴");
      Print("   Position #", ticket);
      Print("   Current Price: ", DoubleToString(currentPrice, _Digits));
      Print("   Current SL: ", DoubleToString(currentSL, _Digits));
      Print("   Profit: ", DoubleToString(profitPips, 1), " pips");
      Print("   ⚠️⚠️⚠️ NO THRESHOLD CHECK IN THIS FUNCTION! ⚠️⚠️⚠️");
      Print("   CHECK WHAT CALLED THIS FUNCTION!");
   }
   
   double trailDistance = InpTrailingStopPips * point;
   double newSL = isBuy ? currentPrice - trailDistance 
                        : currentPrice + trailDistance;
   
   bool shouldMove = isBuy ? (newSL > currentSL) : (newSL < currentSL);
   
   if(shouldMove)
   {
      // ═══ LOG SL MOVEMENT (TOGGLED) ═══
      LogSLMovement(ticket, "APPLY_TRAILING_STOP_FUNCTION", currentSL, newSL, profitPips, "Direct call to ApplyTrailingStop() - NO THRESHOLD CHECK!");
      
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
            " | BE: ", m_states[i].isBreakevenSet ? "✅" : "❌",
            " | Trail: ", m_states[i].isTrailingActive ? "✅" : "❌");
   }
   Print("==========================");
}

//+------------------------------------------------------------------+
//| Getters                                                         |
//+------------------------------------------------------------------+
double CPositionManager::GetOpenPrice(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PRICE_OPEN);
}

double CPositionManager::GetCurrentSL(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_SL);
}

double CPositionManager::GetCurrentTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_TP);
}

ENUM_POSITION_TYPE CPositionManager::GetPositionType(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return POSITION_TYPE_BUY;
   return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
}

double CPositionManager::GetPositionProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT);
}

double CPositionManager::GetPositionVolume(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_VOLUME);
}