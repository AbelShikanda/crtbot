//+------------------------------------------------------------------+
//|                      RiskManager.mqh                            |
//|                    Risk Management Module                        |
//|                    BRACKET-BASED LOT SIZING                     |
//|                    Version 2.00                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.00"

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
   
   double NormalizeLotSize(double lotSize);
   double GetPipValue();
   double GetLotSizeForBracket(double balance);
   string GetBracketName(double balance);
   void   LogBracketInfo(double balance, double lotSize);
   
public:
   CRiskManager(string symbol);
   ~CRiskManager();
   
   // Risk checks
   bool CheckRiskLimits();
   bool CheckMaxDrawdown();
   bool CheckMaxPositions();
   bool CheckMinConfidence(double confidence);
   bool CheckMinRR(double rr);
   
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
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(string symbol)
{
   LOG_DEBUG("CRiskManager constructor called for " + symbol, g_debugRiskManager);
   
   m_symbol = symbol;
   m_maxDrawdown = InpMaxDrawdown;
   m_maxLotSize = InpMaxLotSize;
   m_minLotSize = InpMinLotSize;
   m_riskPerTrade = InpRiskPerTrade;
   m_useRiskBasedLot = false;  // ← NOW USING BRACKET SYSTEM BY DEFAULT
   m_debugEnabled = g_debugRiskManager;
   
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("RISK MANAGER v2.00 - BRACKET LOT SIZING", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("========================================", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("Lot size determined by account balance bracket:", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $0 - $49       → 0.01 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $50 - $499     → 0.02 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $500 - $1,499  → 0.04 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $1,500 - $4,999→ 0.06 lots", g_debugRiskManager || m_debugEnabled);
   LOG_DEBUG("  $5,000+        → 0.08 lots", g_debugRiskManager || m_debugEnabled);
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
   LOG_DEBUG("NormalizeLotSize input: " + DoubleToString(lotSize, 4), g_debugRiskManager || m_debugEnabled);
   
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) return lotSize;
   
   double min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathRound(lotSize / step) * step;
   lotSize = MathMax(min, MathMin(max, lotSize));
   
   double normalized = NormalizeDouble(lotSize, 2);
   LOG_DEBUG("NormalizeLotSize output: " + DoubleToString(normalized, 2), g_debugRiskManager || m_debugEnabled);
   return normalized;
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
   
   double pipValue = (tickValue / tickSize) * point;
   LOG_DEBUG("Pip value for " + m_symbol + ": " + DoubleToString(pipValue, 6), g_debugRiskManager || m_debugEnabled);
   return pipValue;
}

//+------------------------------------------------------------------+
//| Get Lot Size For Account Bracket - PRIMARY METHOD              |
//+------------------------------------------------------------------+
double CRiskManager::GetLotSizeForBracket(double balance)
{
   LOG_DEBUG("GetLotSizeForBracket called with balance: " + DoubleToString(balance, 2), g_debugRiskManager || m_debugEnabled);
   
   // Fixed lot sizes per account bracket (NO CAPPING)
   double lotSize;
   if(balance < 50)
      lotSize = 0.01;   // $0 - $49
   else if(balance < 500)
      lotSize = 0.02;   // $50 - $499
   else if(balance < 1500)
      lotSize = 0.04;   // $500 - $1,499
   else if(balance < 5000)
      lotSize = 0.06;   // $1,500 - $4,999
   else
      lotSize = 0.08;   // $5,000+
   
   LOG_DEBUG("Bracket lot size: " + DoubleToString(lotSize, 2) + " for bracket " + GetBracketName(balance), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Bracket Name                                                |
//+------------------------------------------------------------------+
string CRiskManager::GetBracketName(double balance)
{
   if(balance < 50)
      return "MICRO ($0-49)";
   else if(balance < 500)
      return "TINY ($50-499)";
   else if(balance < 1500)
      return "SMALL ($500-1,499)";
   else if(balance < 5000)
      return "MEDIUM ($1,500-4,999)";
   else
      return "LARGE ($5,000+)";
}

//+------------------------------------------------------------------+
//| Log Bracket Info                                                |
//+------------------------------------------------------------------+
void CRiskManager::LogBracketInfo(double balance, double lotSize)
{
   string bracketName = GetBracketName(balance);
   LOG_INFO("═══════════════════════════════════════════════════════════", g_debugRiskManager || m_debugEnabled);
   LOG_INFO("📊 ACCOUNT BRACKET: " + bracketName, g_debugRiskManager || m_debugEnabled);
   LOG_INFO(StringFormat("   Balance: $%.2f", balance), g_debugRiskManager || m_debugEnabled);
   LOG_INFO(StringFormat("   Lot Size: %.2f lots", lotSize), g_debugRiskManager || m_debugEnabled);
   LOG_INFO("═══════════════════════════════════════════════════════════", g_debugRiskManager || m_debugEnabled);
}

//+------------------------------------------------------------------+
//| Get Current Bracket - Public Access                             |
//+------------------------------------------------------------------+
string CRiskManager::GetCurrentBracket()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   string bracket = GetBracketName(balance);
   LOG_DEBUG("Current bracket: " + bracket, g_debugRiskManager || m_debugEnabled);
   return bracket;
}

//+------------------------------------------------------------------+
//| Get Current Bracket Lot Size - Public Access                    |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentBracketLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lotSize = GetLotSizeForBracket(balance);
   LOG_DEBUG("Current bracket lot size: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Bracket For Balance - Public Access                         |
//+------------------------------------------------------------------+
string CRiskManager::GetBracketForBalance(double balance)
{
   return GetBracketName(balance);
}

//+------------------------------------------------------------------+
//| Check Risk Limits                                               |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRiskLimits()
{
   LOG_DEBUG("CheckRiskLimits called", g_debugRiskManager || m_debugEnabled);
   
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
   LOG_DEBUG("CheckMaxDrawdown: " + DoubleToString(drawdown, 1) + "% < " + DoubleToString(m_maxDrawdown, 1) + "% = " + (result ? "PASS" : "FAIL"), g_debugRiskManager || m_debugEnabled);
   return result;
}

//+------------------------------------------------------------------+
//| Check Max Positions                                             |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMaxPositions()
{
   int positions = PositionsTotal();
   bool result = (positions < InpMaxPositions);
   LOG_DEBUG("CheckMaxPositions: " + IntegerToString(positions) + " < " + IntegerToString(InpMaxPositions) + " = " + (result ? "PASS" : "FAIL"), g_debugRiskManager || m_debugEnabled);
   return result;
}

//+------------------------------------------------------------------+
//| Check Min Confidence                                            |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMinConfidence(double confidence)
{
   bool result = (confidence >= InpMinConfidence);
   LOG_DEBUG("CheckMinConfidence: " + DoubleToString(confidence, 1) + "% >= " + DoubleToString(InpMinConfidence, 1) + "% = " + (result ? "PASS" : "FAIL"), g_debugRiskManager || m_debugEnabled);
   return result;
}

//+------------------------------------------------------------------+
//| Check Min RR                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMinRR(double rr)
{
   bool result = (rr >= InpMinRR);
   LOG_DEBUG("CheckMinRR: " + DoubleToString(rr, 2) + " >= " + DoubleToString(InpMinRR, 2) + " = " + (result ? "PASS" : "FAIL"), g_debugRiskManager || m_debugEnabled);
   return result;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size - PRIMARY ENTRY POINT                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(PrescribedTrade &signal)
{
   LOG_DEBUG("CalculateLotSize called for signal " + IntegerToString(signal.signal), g_debugRiskManager || m_debugEnabled);
   
   // PRIMARY METHOD: Bracket-based lot sizing
   double lotSize = CalculateBracketBasedLot(signal);
   
   // Log the bracket info
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   LogBracketInfo(balance, lotSize);
   
   LOG_DEBUG("CalculateLotSize result: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Bracket Based Lot - PRIMARY SIZING METHOD            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateBracketBasedLot(PrescribedTrade &signal)
{
   LOG_DEBUG("CalculateBracketBasedLot called", g_debugRiskManager || m_debugEnabled);
   
   // STEP 1: Get account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   LOG_DEBUG("Account balance: " + DoubleToString(accountBalance, 2), g_debugRiskManager || m_debugEnabled);
   
   // STEP 2: Get the FIXED lot size for this account bracket
   double lotSize = GetLotSizeForBracket(accountBalance);
   LOG_DEBUG("Base lot from bracket: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   
   // STEP 3: Normalize and apply limits
   lotSize = NormalizeLotSize(lotSize);
   if(lotSize < m_minLotSize) 
   {
      LOG_DEBUG("Lot below minimum, adjusting from " + DoubleToString(lotSize, 2) + " to " + DoubleToString(m_minLotSize, 2), g_debugRiskManager || m_debugEnabled);
      lotSize = m_minLotSize;
   }
   if(lotSize > m_maxLotSize) 
   {
      LOG_DEBUG("Lot above maximum, adjusting from " + DoubleToString(lotSize, 2) + " to " + DoubleToString(m_maxLotSize, 2), g_debugRiskManager || m_debugEnabled);
      lotSize = m_maxLotSize;
   }
   
   LOG_DEBUG("Final lot size: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Risk Based Lot - LEGACY METHOD (Kept for reference)   |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskBasedLot(PrescribedTrade &signal)
{
   LOG_DEBUG("CalculateRiskBasedLot called (legacy method)", g_debugRiskManager || m_debugEnabled);
   
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
   LOG_DEBUG("Risk-based lot before normalization: " + DoubleToString(lotSize, 4), g_debugRiskManager || m_debugEnabled);
   
   lotSize = NormalizeLotSize(lotSize);
   
   if(lotSize < m_minLotSize) lotSize = m_minLotSize;
   if(lotSize > m_maxLotSize) lotSize = m_maxLotSize;
   
   LOG_DEBUG("Risk-based lot result: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Fixed Lot Size                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetFixedLotSize()
{
   double lotSize = NormalizeLotSize(InpLotSize);
   LOG_DEBUG("Fixed lot size: " + DoubleToString(lotSize, 2), g_debugRiskManager || m_debugEnabled);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Current Drawdown                                            |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 0) return 0;
   double drawdown = ((balance - equity) / balance) * 100;
   LOG_DEBUG("Current drawdown: " + DoubleToString(drawdown, 1) + "%", g_debugRiskManager || m_debugEnabled);
   return drawdown;
}

//+------------------------------------------------------------------+
//| Get Equity Percent                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetEquityPercent()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 0) return 0;
   double equityPct = (equity / balance) * 100;
   LOG_DEBUG("Equity percent: " + DoubleToString(equityPct, 1) + "%", g_debugRiskManager || m_debugEnabled);
   return equityPct;
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
   
   LOG_DEBUG("Total profit for " + m_symbol + ": " + DoubleToString(totalProfit, 2), g_debugRiskManager || m_debugEnabled);
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
   
   double riskAmount = risk * pipValue * lotSize;
   LOG_DEBUG("Risk amount: " + DoubleToString(riskAmount, 2) + " (lot=" + DoubleToString(lotSize, 2) + ", risk=" + DoubleToString(risk, 6) + ", pipValue=" + DoubleToString(pipValue, 6) + ")", g_debugRiskManager || m_debugEnabled);
   return riskAmount;
}

//+------------------------------------------------------------------+
//| Get Max Risk Amount                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxRiskAmount()
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxRisk = accountBalance * (m_riskPerTrade / 100.0);
   LOG_DEBUG("Max risk amount: " + DoubleToString(maxRisk, 2), g_debugRiskManager || m_debugEnabled);
   return maxRisk;
}