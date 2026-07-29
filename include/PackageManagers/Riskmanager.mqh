//+------------------------------------------------------------------+
//|                      RiskManager.mqh                            |
//|                    Risk Management Module                        |
//|                    BRACKET-BASED LOT SIZING                     |
//|                    Version 2.10                                 |
//|                    + COOLDOWN ON LOSS                          |
//|                    + DAILY TRADE LIMIT (3)                     |
//|                    + PROFIT THRESHOLDS ($20)                  |
//|                    + AUTO-CLOSE ALL POSITIONS ON LOSS         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.10"

#include "../Headers/Structures.mqh"
#include "../Headers/Inputs.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| GLOBAL DEBUG TOGGLE                                             |
//+------------------------------------------------------------------+
bool g_debugRiskManager = false;

//+------------------------------------------------------------------+
//| Risk Manager Class                                              |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   string   m_symbol;
   double   m_maxDrawdown;
   double   m_maxLotSize;
   double   m_minLotSize;
   double   m_riskPerTrade;
   bool     m_useRiskBasedLot;
   bool     m_debugEnabled;
   
   // ═══ NEW: COOLDOWN & DAILY LIMIT TRACKING ═══
   datetime m_cooldownEndTime;        // When cooldown ends
   bool     m_inCooldown;             // Currently in cooldown?
   datetime m_lastLossTime;           // When last loss occurred
   
   int      m_dailyTradeCount;        // Trades executed today
   int      m_maxDailyTrades;         // Max trades per day (3)
   datetime m_dailyResetTime;         // 3:00 AM reset time
   datetime m_lastResetDate;          // Last reset date
   
   bool     m_dayStopped;             // Day stopped due to big profit or daily limit
   
   double   m_profitThreshold;         // $20 profit threshold
   
   // Private methods
   double NormalizeLotSize(double lotSize);
   double GetPipValue();
   double GetLotSizeForBracket(double balance);
   string GetBracketName(double balance);
   void   LogBracketInfo(double balance, double lotSize);
   
   // ═══ NEW: COOLDOWN & DAILY LIMIT METHODS ═══
   void   ResetDailyCounter();
   bool   IsCooldownActive();
   bool   IsDayStopped();
   bool   IsDailyLimitReached();
   void   StartCooldown();
   void   StopDay();
   void   CheckAndResetDaily();
   void   CloseAllPositions();        // ═══ FIXED: Now uses PositionSelect and OrderSend directly ═══
   void   LogTradeResult(double profit);
   
public:
   CRiskManager(string symbol);
   ~CRiskManager();
   
   // Risk checks
   bool CheckRiskLimits();
   bool CheckMaxDrawdown();
   bool CheckMaxPositions();
   bool CheckMinConfidence(double confidence);
   bool CheckMinRR(double rr);
   
   // ═══ NEW: TRADE RESULT HANDLING ═══
   void OnTradeClosed(double profit);
   void OnTradeExecuted();
   bool CanTrade();
   string GetStatusMessage();
   
   // Lot sizing - PRIMARY METHOD
   double CalculateLotSize(PrescribedTrade &signal);
   double CalculateBracketBasedLot(PrescribedTrade &signal);
   double CalculateRiskBasedLot(PrescribedTrade &signal);
   double GetFixedLotSize();
   
   // Risk metrics
   double GetCurrentDrawdown();
   double GetEquityPercent();
   double GetTotalProfit();
   double GetRiskAmount(PrescribedTrade &signal);
   double GetMaxRiskAmount();
   
   // Getters/Setters
   void SetMaxDrawdown(double maxDrawdown) { m_maxDrawdown = maxDrawdown; }
   void SetMaxLotSize(double maxLot) { m_maxLotSize = maxLot; }
   void SetMinLotSize(double minLot) { m_minLotSize = minLot; }
   void SetRiskPerTrade(double risk) { m_riskPerTrade = risk; }
   void SetUseRiskBasedLot(bool use) { m_useRiskBasedLot = use; }
   void EnableDebug(bool enable) { m_debugEnabled = enable; }
   static void SetGlobalDebug(bool enable) { g_debugRiskManager = enable; }
   static bool GetGlobalDebug() { return g_debugRiskManager; }
   
   // Bracket info
   string GetCurrentBracket();
   double GetCurrentBracketLotSize();
   string GetBracketForBalance(double balance);
   
   // ═══ NEW: STATUS GETTERS ═══
   int    GetDailyTradeCount() const { return m_dailyTradeCount; }
   int    GetMaxDailyTrades() const { return m_maxDailyTrades; }
   bool   IsInCooldown() const { return m_inCooldown; }
   bool   IsDayStoppedFlag() const { return m_dayStopped; }
   string GetCooldownRemaining();
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(string symbol)
{
   LOG_DEBUG("CRiskManager v2.10 constructor called for " + symbol, g_debugRiskManager);
   
   m_symbol = symbol;
   m_maxDrawdown = InpMaxDrawdown;
   m_maxLotSize = InpMaxLotSize;
   m_minLotSize = InpMinLotSize;
   m_riskPerTrade = InpRiskPerTrade;
   m_useRiskBasedLot = false;
   m_debugEnabled = g_debugRiskManager;
   
   // ═══ INITIALIZE COOLDOWN & DAILY LIMIT ═══
   m_cooldownEndTime = 0;
   m_inCooldown = false;
   m_lastLossTime = 0;
   m_dailyTradeCount = 0;
   m_maxDailyTrades = 3;           // Max 3 trades per day
   m_profitThreshold = 20.0;       // $20 profit threshold
   m_dayStopped = false;
   m_lastResetDate = 0;
   
   // Initialize daily reset time to 3:00 AM
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 3;
   dt.min = 0;
   dt.sec = 0;
   m_dailyResetTime = StructToTime(dt);
   
   // Check if we need to reset immediately
   CheckAndResetDaily();
   
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("RISK MANAGER v2.10 - BRACKET LOT SIZING", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("Lot size determined by account balance bracket:", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $0 - $49       → 0.01 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $50 - $499     → 0.02 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $500 - $1,499  → 0.04 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $1,500 - $4,999→ 0.06 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $5,000+        → 0.08 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("📋 RISK RULES:", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("   Max Daily Trades: " + IntegerToString(m_maxDailyTrades), g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("   Profit Threshold: $" + DoubleToString(m_profitThreshold, 0), g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("   Cooldown on Loss: 2 hours", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("   Daily Reset: 3:00 AM", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   LOG_DEBUG("CRiskManager destructor called for " + m_symbol, g_debugRiskManager || m_debugEnabled);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size                                              |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLotSize(double lotSize)
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
//| Get Pip Value                                                   |
//+------------------------------------------------------------------+
double CRiskManager::GetPipValue()
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize <= 0 || point <= 0) 
   {
      LOG_WARNING("Invalid tickSize or point for " + m_symbol);
      return 0;
   }
   
   return (tickValue / tickSize) * point;
}

//+------------------------------------------------------------------+
//| Get Lot Size For Account Bracket - PRIMARY METHOD              |
//+------------------------------------------------------------------+
double CRiskManager::GetLotSizeForBracket(double balance)
{
   double lotSize;
   if(balance < 50)
      lotSize = 0.01;
   else if(balance < 500)
      lotSize = 0.02;
   else if(balance < 1500)
      lotSize = 0.04;
   else if(balance < 5000)
      lotSize = 0.06;
   else
      lotSize = 0.08;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Bracket Name                                                |
//+------------------------------------------------------------------+
string CRiskManager::GetBracketName(double balance)
{
   if(balance < 50)      return "MICRO ($0-49)";
   else if(balance < 500) return "TINY ($50-499)";
   else if(balance < 1500) return "SMALL ($500-1,499)";
   else if(balance < 5000) return "MEDIUM ($1,500-4,999)";
   else                  return "LARGE ($5,000+)";
}

//+------------------------------------------------------------------+
//| Log Bracket Info                                                |
//+------------------------------------------------------------------+
void CRiskManager::LogBracketInfo(double balance, double lotSize)
{
   LOG_INFO("═══════════════════════════════════════════════════════════", g_debugRiskManager || m_debugEnabled);
   LOG_INFO("📊 ACCOUNT BRACKET: " + GetBracketName(balance), g_debugRiskManager || m_debugEnabled);
   LOG_INFO(StringFormat("   Balance: $%.2f", balance), g_debugRiskManager || m_debugEnabled);
   LOG_INFO(StringFormat("   Lot Size: %.2f lots", lotSize), g_debugRiskManager || m_debugEnabled);
   LOG_INFO("═══════════════════════════════════════════════════════════", g_debugRiskManager || m_debugEnabled);
}

//+------------------------------------------------------------------+
//| ═══ NEW: CLOSE ALL POSITIONS - FIXED ═══                      |
//+------------------------------------------------------------------+
void CRiskManager::CloseAllPositions()
{
   int closed = 0;
   LOG_WARNING("🔒 Closing all positions due to loss...");
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(symbol == m_symbol)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // ═══ FIXED: Use OrderSend directly instead of g_trade ═══
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = m_symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = 10;
            
            if(posType == POSITION_TYPE_BUY)
            {
               request.type = ORDER_TYPE_SELL;
               request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            }
            else
            {
               request.type = ORDER_TYPE_BUY;
               request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            }
            
            bool closedOk = false;
            if(OrderSend(request, result))
            {
               if(result.retcode == TRADE_RETCODE_DONE)
               {
                  closedOk = true;
                  closed++;
                  LOG_DEBUG("   Closed position #" + IntegerToString(ticket), 
                            g_debugRiskManager || m_debugEnabled);
               }
            }
            
            if(!closedOk)
            {
               LOG_WARNING("   Failed to close position #" + IntegerToString(ticket));
            }
         }
      }
   }
   
   if(closed > 0)
      LOG_WARNING("✅ Closed " + IntegerToString(closed) + " position(s)");
}

//+------------------------------------------------------------------+
//| ═══ NEW: CHECK AND RESET DAILY COUNTER ═══                    |
//+------------------------------------------------------------------+
void CRiskManager::CheckAndResetDaily()
{
   MqlDateTime currentDt;
   TimeCurrent(currentDt);
   
   // Build today's 3:00 AM time
   MqlDateTime resetDt = currentDt;
   resetDt.hour = 3;
   resetDt.min = 0;
   resetDt.sec = 0;
   datetime todayReset = StructToTime(resetDt);
   
   // If current time is before 3:00 AM today, use yesterday's 3:00 AM
   if(TimeCurrent() < todayReset)
   {
      resetDt.day--;
      todayReset = StructToTime(resetDt);
   }
   
   // Reset if last reset was before today's 3:00 AM
   if(m_lastResetDate < todayReset)
   {
      m_dailyTradeCount = 0;
      m_dayStopped = false;
      m_lastResetDate = todayReset;
      
      // Clear cooldown if it was active from previous day
      if(m_inCooldown)
      {
         m_inCooldown = false;
         m_cooldownEndTime = 0;
         LOG_DEBUG("⏰ Daily reset at 3:00 AM - Cooldown cleared", g_debugRiskManager || m_debugEnabled);
      }
      
      LOG_DEBUG("⏰ Daily reset at 3:00 AM - Trade count reset to 0", g_debugRiskManager || m_debugEnabled);
   }
}

//+------------------------------------------------------------------+
//| ═══ NEW: IS COOLDOWN ACTIVE? ═══                              |
//+------------------------------------------------------------------+
bool CRiskManager::IsCooldownActive()
{
   if(!m_inCooldown) return false;
   
   datetime currentTime = TimeCurrent();
   
   if(currentTime >= m_cooldownEndTime)
   {
      // Cooldown has expired
      m_inCooldown = false;
      m_cooldownEndTime = 0;
      LOG_INFO("✅ Cooldown period ended - Trading resumed", g_debugRiskManager || m_debugEnabled);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ═══ NEW: START COOLDOWN ═══                                   |
//+------------------------------------------------------------------+
void CRiskManager::StartCooldown()
{
   if(m_inCooldown) return;  // Already in cooldown
   
   m_cooldownEndTime = TimeCurrent() + (2 * 3600);  // 2 hours
   m_inCooldown = true;
   m_lastLossTime = TimeCurrent();
   
   LOG_WARNING("⏳⏳⏳ COOLDOWN STARTED - 2 hours");
   LOG_WARNING("   No new trades allowed until " + TimeToString(m_cooldownEndTime));
   
   // Close all positions
   CloseAllPositions();
}

//+------------------------------------------------------------------+
//| ═══ NEW: STOP DAY ═══                                        |
//+------------------------------------------------------------------+
void CRiskManager::StopDay()
{
   if(m_dayStopped) return;
   
   m_dayStopped = true;
   LOG_WARNING("🛑🛑🛑 DAY STOPPED - No more trades until 3:00 AM");
}

//+------------------------------------------------------------------+
//| ═══ NEW: GET COOLDOWN REMAINING ═══                          |
//+------------------------------------------------------------------+
string CRiskManager::GetCooldownRemaining()
{
   if(!m_inCooldown) return "No cooldown";
   
   datetime currentTime = TimeCurrent();
   int remaining = (int)(m_cooldownEndTime - currentTime);
   
   if(remaining <= 0) return "Cooldown expired";
   
   int hours = remaining / 3600;
   int minutes = (remaining % 3600) / 60;
   int seconds = remaining % 60;
   
   return StringFormat("%02d:%02d:%02d remaining", hours, minutes, seconds);
}

//+------------------------------------------------------------------+
//| ═══ NEW: IS DAY STOPPED? ═══                                 |
//+------------------------------------------------------------------+
bool CRiskManager::IsDayStopped()
{
   CheckAndResetDaily();  // Check for 3:00 AM reset
   return m_dayStopped;
}

//+------------------------------------------------------------------+
//| ═══ NEW: IS DAILY LIMIT REACHED? ═══                         |
//+------------------------------------------------------------------+
bool CRiskManager::IsDailyLimitReached()
{
   CheckAndResetDaily();  // Check for 3:00 AM reset
   return (m_dailyTradeCount >= m_maxDailyTrades);
}

//+------------------------------------------------------------------+
//| ═══ NEW: CAN TRADE? - MAIN GATEKEEPER ═══                    |
//+------------------------------------------------------------------+
bool CRiskManager::CanTrade()
{
   // Step 1: Check daily reset
   CheckAndResetDaily();
   
   // Step 2: Check if day is stopped (big profit or daily limit)
   if(m_dayStopped)
   {
      LOG_DEBUG("❌ Day stopped - No trades until 3:00 AM", g_debugRiskManager || m_debugEnabled);
      return false;
   }
   
   // Step 3: Check daily limit
   if(m_dailyTradeCount >= m_maxDailyTrades)
   {
      LOG_DEBUG("❌ Daily limit reached: " + IntegerToString(m_dailyTradeCount) + 
                "/" + IntegerToString(m_maxDailyTrades), g_debugRiskManager || m_debugEnabled);
      return false;
   }
   
   // Step 4: Check cooldown
   if(IsCooldownActive())
   {
      LOG_DEBUG("❌ Cooldown active: " + GetCooldownRemaining(), 
                g_debugRiskManager || m_debugEnabled);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ═══ NEW: ON TRADE CLOSED ═══                                  |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeClosed(double profit)
{
   LOG_INFO("📊 Trade closed with profit: $" + DoubleToString(profit, 2), 
            g_debugRiskManager || m_debugEnabled);
   
   // Step 1: Always increment daily counter (unless day already stopped)
   if(!m_dayStopped)
   {
      m_dailyTradeCount++;
      LOG_DEBUG("   Daily trade count: " + IntegerToString(m_dailyTradeCount) + 
                "/" + IntegerToString(m_maxDailyTrades), g_debugRiskManager || m_debugEnabled);
   }
   
   // Step 2: Check for LOSS - triggers cooldown
   if(profit < 0)
   {
      LOG_WARNING("⚠️ LOSS detected: $" + DoubleToString(profit, 2));
      
      // Start cooldown (this also closes all positions)
      StartCooldown();
      
      // Check if drawdown is exceeded
      if(GetCurrentDrawdown() >= m_maxDrawdown)
      {
         LOG_ERROR("❌❌❌ MAX DRAWDOWN EXCEEDED: " + 
                   DoubleToString(GetCurrentDrawdown(), 1) + "%");
         // Stop day completely
         StopDay();
      }
      
      return;  // Loss handled, exit
   }
   
   // Step 3: Check for BIG PROFIT >= $20
   if(profit >= m_profitThreshold)
   {
      LOG_INFO("💰💰💰 BIG PROFIT: $" + DoubleToString(profit, 2) + 
               " (>= $" + DoubleToString(m_profitThreshold, 0) + ")", 
               g_debugRiskManager || m_debugEnabled);
      LOG_INFO("   This does NOT count toward daily limit", 
               g_debugRiskManager || m_debugEnabled);
      LOG_INFO("   Stopping trading for the day", 
               g_debugRiskManager || m_debugEnabled);
      
      // Decrement daily count since big profit doesn't count
      if(m_dailyTradeCount > 0)
      {
         m_dailyTradeCount--;
         LOG_DEBUG("   Daily count adjusted: " + IntegerToString(m_dailyTradeCount) + 
                   "/" + IntegerToString(m_maxDailyTrades), 
                   g_debugRiskManager || m_debugEnabled);
      }
      
      // Stop day
      StopDay();
      return;
   }
   
   // Step 4: Small profit (< $20) - Continue trading
   if(profit > 0 && profit < m_profitThreshold)
   {
      LOG_DEBUG("✅ Small profit: $" + DoubleToString(profit, 2) + 
                " (< $" + DoubleToString(m_profitThreshold, 0) + 
                ") - Continue trading", g_debugRiskManager || m_debugEnabled);
   }
   
   // Step 5: Check if daily limit reached after this trade
   if(m_dailyTradeCount >= m_maxDailyTrades)
   {
      LOG_WARNING("📊 Daily limit reached: " + IntegerToString(m_dailyTradeCount) + 
                  "/" + IntegerToString(m_maxDailyTrades));
      StopDay();
   }
}

//+------------------------------------------------------------------+
//| ═══ NEW: ON TRADE EXECUTED ═══                               |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeExecuted()
{
   // Trade execution is handled in OnTradeClosed
   // This is just a placeholder for symmetry
   LOG_DEBUG("Trade executed - Daily count: " + IntegerToString(m_dailyTradeCount) + 
             "/" + IntegerToString(m_maxDailyTrades), g_debugRiskManager || m_debugEnabled);
}

//+------------------------------------------------------------------+
//| ═══ NEW: GET STATUS MESSAGE ═══                              |
//+------------------------------------------------------------------+
string CRiskManager::GetStatusMessage()
{
   string status = "";
   
   if(m_dayStopped)
   {
      status = "🛑 DAY STOPPED - Resume at 3:00 AM";
   }
   else if(IsCooldownActive())
   {
      status = "⏳ COOLDOWN - " + GetCooldownRemaining();
   }
   else if(m_dailyTradeCount >= m_maxDailyTrades)
   {
      status = "📊 DAILY LIMIT REACHED - Resume at 3:00 AM";
   }
   else
   {
      status = StringFormat("✅ READY - Trades: %d/%d", 
                           m_dailyTradeCount, m_maxDailyTrades);
   }
   
   return status;
}

//+------------------------------------------------------------------+
//| Check Risk Limits - UPDATED WITH CANTRADE()                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRiskLimits()
{
   LOG_DEBUG("CheckRiskLimits called", g_debugRiskManager || m_debugEnabled);
   
   // ═══ NEW: Check cooldown, daily limit, day stopped ═══
   if(!CanTrade())
   {
      LOG_DEBUG("❌ CanTrade() returned false", g_debugRiskManager || m_debugEnabled);
      return false;
   }
   
   // Check positions count
   if(!CheckMaxPositions())
   {
      LOG_WARNING("⚠️ Max positions reached");
      return false;
   }
   
   // Check drawdown
   if(!CheckMaxDrawdown())
   {
      double drawdown = GetCurrentDrawdown();
      LOG_WARNING("⚠️ Max drawdown reached: " + DoubleToString(drawdown, 1) + "%");
      StopDay();
      return false;
   }
   
   LOG_DEBUG("Risk limits check passed", g_debugRiskManager || m_debugEnabled);
   return true;
}

//+------------------------------------------------------------------+
//| Check Max Drawdown                                              |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMaxDrawdown()
{
   double drawdown = GetCurrentDrawdown();
   bool result = (drawdown < m_maxDrawdown);
   return result;
}

//+------------------------------------------------------------------+
//| Check Max Positions                                             |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMaxPositions()
{
   int positions = PositionsTotal();
   bool result = (positions < InpMaxPositions);
   return result;
}

//+------------------------------------------------------------------+
//| Check Min Confidence                                            |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMinConfidence(double confidence)
{
   return (confidence >= InpMinConfidence);
}

//+------------------------------------------------------------------+
//| Check Min RR                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMinRR(double rr)
{
   return (rr >= InpMinRR);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size - PRIMARY ENTRY POINT                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(PrescribedTrade &signal)
{
   LOG_DEBUG("CalculateLotSize called for signal " + IntegerToString(signal.signal), 
             g_debugRiskManager || m_debugEnabled);
   
   double lotSize = CalculateBracketBasedLot(signal);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   LogBracketInfo(balance, lotSize);
   
   LOG_DEBUG("CalculateLotSize result: " + DoubleToString(lotSize, 2), 
             g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Bracket Based Lot - PRIMARY SIZING METHOD            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateBracketBasedLot(PrescribedTrade &signal)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lotSize = GetLotSizeForBracket(accountBalance);
   
   lotSize = NormalizeLotSize(lotSize);
   if(lotSize < m_minLotSize) lotSize = m_minLotSize;
   if(lotSize > m_maxLotSize) lotSize = m_maxLotSize;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Risk Based Lot - LEGACY METHOD (Kept for reference)   |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskBasedLot(PrescribedTrade &signal)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (m_riskPerTrade / 100.0);
   double risk = MathAbs(signal.stopLoss - signal.entryPrice);
   double pipValue = GetPipValue();
   
   if(risk <= 0 || pipValue <= 0) 
   {
      LOG_WARNING("Invalid risk or pipValue, returning min lot");
      return m_minLotSize;
   }
   
   double lotSize = riskAmount / (risk * pipValue);
   lotSize = NormalizeLotSize(lotSize);
   
   if(lotSize < m_minLotSize) lotSize = m_minLotSize;
   if(lotSize > m_maxLotSize) lotSize = m_maxLotSize;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Fixed Lot Size                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetFixedLotSize()
{
   return NormalizeLotSize(InpLotSize);
}

//+------------------------------------------------------------------+
//| Get Current Drawdown                                            |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 0) return 0;
   return ((balance - equity) / balance) * 100;
}

//+------------------------------------------------------------------+
//| Get Equity Percent                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetEquityPercent()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 0) return 0;
   return (equity / balance) * 100;
}

//+------------------------------------------------------------------+
//| Get Total Profit                                                |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalProfit()
{
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(symbol == m_symbol)
            totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Get Risk Amount                                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetRiskAmount(PrescribedTrade &signal)
{
   double lotSize = CalculateLotSize(signal);
   double risk = MathAbs(signal.stopLoss - signal.entryPrice);
   double pipValue = GetPipValue();
   
   return risk * pipValue * lotSize;
}

//+------------------------------------------------------------------+
//| Get Max Risk Amount                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxRiskAmount()
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return accountBalance * (m_riskPerTrade / 100.0);
}

//+------------------------------------------------------------------+
//| Get Current Bracket - Public Access                             |
//+------------------------------------------------------------------+
string CRiskManager::GetCurrentBracket()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return GetBracketName(balance);
}

//+------------------------------------------------------------------+
//| Get Current Bracket Lot Size - Public Access                    |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentBracketLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return GetLotSizeForBracket(balance);
}

//+------------------------------------------------------------------+
//| Get Bracket For Balance - Public Access                         |
//+------------------------------------------------------------------+
string CRiskManager::GetBracketForBalance(double balance)
{
   return GetBracketName(balance);
}