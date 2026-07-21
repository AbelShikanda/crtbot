//+------------------------------------------------------------------+
//|                                                       MarketData |
//|                        Core market data access and manipulation  |
//|                        v2.1 - FIXED & COMPLETE                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.1"

#include "../Headers/Structures.mqh"
#include "../PackageManagers/TrendManager.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Debug toggle for MarketData file                               |
//+------------------------------------------------------------------+
bool g_marketDataDebugMode = false;

//+------------------------------------------------------------------+
//| Market Data Class - Complete Data Hub                          |
//+------------------------------------------------------------------+
class MarketData
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   MqlTick           m_lastTick;
   datetime          m_lastUpdate;
   datetime          m_lastBarTime;
   int               m_barsCached;
   bool              m_isInitialized;
   
   // Cache for OHLC data
   struct OHLCData
   {
      double open[];
      double high[];
      double low[];
      double close[];
      datetime time[];
      long volume[];
      int size;
      datetime lastUpdate;
   };
   
   OHLCData m_ohlcCache;
   
   // Cache for derived data
   struct DerivedData
   {
      double atr;
      double atrMultiplier;
      double averageRange;
      double volatility;
      double momentum;
      double rsi;
      double macdMain;
      double macdSignal;
      double macdHistogram;
      datetime lastUpdate;
   };
   
   DerivedData m_derivedCache;
   
   // Point and pip values
   double m_point;
   double m_tickValue;
   double m_pipSize;
   double m_minLot;
   double m_maxLot;
   double m_lotStep;
   double m_stopLevel;
   double m_freezeLevel;
   
   // Internal helper methods
   bool UpdateOHLCCache(int bars = 100);
   bool UpdateDerivedCache();
   double CalculateATR(int period = 14);
   double CalculateAverageRange(int bars = 20);
   double CalculateVolatility(int bars = 20);
   double CalculateMomentum(int period = 14);
   double CalculateRSI(int period = 14);
   bool CalculateMACD(double &main, double &signal, double &histogram, int fast = 12, int slow = 26, int signalPeriod = 9);
   
public:
   // Constructor / Destructor
   MarketData(string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   ~MarketData();
   
   // Initialization
   bool Initialize();
   bool IsInitialized() const { return m_isInitialized; }
   
   // ──────────────────────────────────────────────────────────────
   // PRICE DATA - Direct access
   // ──────────────────────────────────────────────────────────────
   double GetBid(string symbol = NULL);
   double GetAsk(string symbol = NULL);
   double GetMid(string symbol = NULL);
   double GetSpread(string symbol = NULL);
   double GetSpreadInPips(string symbol = NULL);
   MqlTick GetTick(string symbol = NULL);
   
   // ──────────────────────────────────────────────────────────────
   // OHLC DATA - Complete bar data
   // ──────────────────────────────────────────────────────────────
   double GetOpen(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetHigh(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetLow(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetClose(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   long   GetVolume(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   datetime GetTime(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   
   bool GetOHLC(int shift, double &open, double &high, double &low, double &close, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool GetOHLCArray(double &open[], double &high[], double &low[], double &close[], int count = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   
   // ──────────────────────────────────────────────────────────────
   // SYMBOL PROPERTIES - Complete set
   // ──────────────────────────────────────────────────────────────
   double GetPoint(string symbol = NULL);
   double GetPipSize(string symbol = NULL);
   double GetTickValue(string symbol = NULL);
   double GetMinLot(string symbol = NULL);
   double GetMaxLot(string symbol = NULL);
   double GetLotStep(string symbol = NULL);
   double GetStopLevel(string symbol = NULL);
   double GetFreezeLevel(string symbol = NULL);
   int    GetDigits(string symbol = NULL);
   int    GetPointDigits(string symbol = NULL);
   double GetSwapLong(string symbol = NULL);
   double GetSwapShort(string symbol = NULL);
   double GetContractSize(string symbol = NULL);
   string GetCurrencyProfit(string symbol = NULL);
   string GetCurrencyMargin(string symbol = NULL);
   
   // ──────────────────────────────────────────────────────────────
   // DERIVED INDICATORS - Built-in calculations
   // ──────────────────────────────────────────────────────────────
   double GetATR(int period = 14);
   double GetAverageRange(int bars = 20);
   double GetVolatility(int bars = 20);
   double GetMomentum(int period = 14);
   double GetRSI(int period = 14);
   bool GetMACDValues(double &main, double &signal, double &histogram, int fast = 12, int slow = 26, int signalPeriod = 9);
   
   // ──────────────────────────────────────────────────────────────
   // BAR STATE & PATTERN DETECTION
   // ──────────────────────────────────────────────────────────────
   bool IsNewBar(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsBullishBar(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsBearishBar(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsDojiBar(int shift = 0, double threshold = 0.1, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsPinBar(int shift = 0, double threshold = 0.6, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsEngulfing(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsInsideBar(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool IsOutsideBar(int shift = 0, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   
   // ──────────────────────────────────────────────────────────────
   // MARKET CONDITIONS
   // ──────────────────────────────────────────────────────────────
   bool IsMarketOpen(string symbol = NULL);
   bool IsTradingAllowed(string symbol = NULL);
   bool IsSessionActive(int session = 0, string symbol = NULL);
   int  GetMarketHours(string symbol = NULL);
   bool IsHighVolatility(int threshold = 50);
   bool IsLowVolatility(int threshold = 20);
   bool IsBreakout(double threshold = 0.0, int lookback = 20);
   bool IsRangeBound(double threshold = 0.5, int lookback = 20);
   double GetDayRange(int lookback = 1);
   double GetAverageDayRange(int days = 20);
   
   // ──────────────────────────────────────────────────────────────
   // RISK & POSITION SIZING
   // ──────────────────────────────────────────────────────────────
   double CalculateLotSize(double riskPercent, double stopLossPips, double accountBalance = 0);
   double CalculateStopLossPips(double riskPercent, double lotSize, double accountBalance = 0);
   double GetPipValue(double lotSize = 0, string symbol = NULL);
   double GetPositionValue(double lotSize = 0, string symbol = NULL);
   double GetMarginRequirement(double lotSize, string symbol = NULL);
   double GetFreeMargin();
   double GetAccountBalance();
   double GetAccountEquity();
   
   // ──────────────────────────────────────────────────────────────
   // DATA MANAGEMENT
   // ──────────────────────────────────────────────────────────────
   void Refresh();
   void ClearCache();
   bool IsFresh() const;
   bool IsDataValid() const;
   int GetBarsAvailable(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   datetime GetLastBarTime(string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   
   // ──────────────────────────────────────────────────────────────
   // STATISTICS & UTILITIES
   // ──────────────────────────────────────────────────────────────
   double GetMaxPrice(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetMinPrice(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetRange(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double GetRangeInPips(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double CalculateMean(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double CalculateStdDev(int bars = 100, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double CalculateCorrelation(string symbol2, int bars = 100);
   
   // ──────────────────────────────────────────────────────────────
   // CONVENIENCE METHODS
   // ──────────────────────────────────────────────────────────────
   double NormalizePrice(double price);
   double NormalizeLot(double lotSize);
   bool IsPriceValid(double price);
   bool IsLotValid(double lotSize);
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   void SetTimeframe(ENUM_TIMEFRAMES tf) { m_timeframe = tf; }
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
MarketData::MarketData(string symbol, ENUM_TIMEFRAMES timeframe)
{
   LOG_DEBUG("MarketData constructor called", g_marketDataDebugMode);
   m_symbol = (symbol == NULL) ? Symbol() : symbol;
   m_timeframe = (timeframe == PERIOD_CURRENT) ? Period() : timeframe;
   m_lastUpdate = 0;
   m_lastBarTime = 0;
   m_barsCached = 0;
   m_isInitialized = false;
   
   // Initialize cache arrays
   ArrayResize(m_ohlcCache.open, 0);
   ArrayResize(m_ohlcCache.high, 0);
   ArrayResize(m_ohlcCache.low, 0);
   ArrayResize(m_ohlcCache.close, 0);
   ArrayResize(m_ohlcCache.time, 0);
   ArrayResize(m_ohlcCache.volume, 0);
   m_ohlcCache.size = 0;
   m_ohlcCache.lastUpdate = 0;
   
   // Initialize derived cache
   m_derivedCache.atr = 0;
   m_derivedCache.atrMultiplier = 0;
   m_derivedCache.averageRange = 0;
   m_derivedCache.volatility = 0;
   m_derivedCache.momentum = 0;
   m_derivedCache.rsi = 0;
   m_derivedCache.macdMain = 0;
   m_derivedCache.macdSignal = 0;
   m_derivedCache.macdHistogram = 0;
   m_derivedCache.lastUpdate = 0;
   
   // Initialize symbol properties
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   m_pipSize = m_point * 10;  // For 5-digit brokers, point = 0.00001, pip = 0.0001
   if(StringFind(SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE), "JPY") >= 0)
      m_pipSize = m_point * 100;  // For JPY pairs
   
   m_minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   m_maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   m_lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   m_stopLevel = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   m_freezeLevel = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   
   LOG_DEBUG("MarketData constructor completed for symbol: " + m_symbol, g_marketDataDebugMode);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
MarketData::~MarketData()
{
   LOG_DEBUG("MarketData destructor called", g_marketDataDebugMode);
   // Clean up arrays
   ArrayResize(m_ohlcCache.open, 0);
   ArrayResize(m_ohlcCache.high, 0);
   ArrayResize(m_ohlcCache.low, 0);
   ArrayResize(m_ohlcCache.close, 0);
   ArrayResize(m_ohlcCache.time, 0);
   ArrayResize(m_ohlcCache.volume, 0);
}

//+------------------------------------------------------------------+
//| Initialize - Load initial data                                  |
//+------------------------------------------------------------------+
bool MarketData::Initialize()
{
   LOG_DEBUG("MarketData Initialize called", g_marketDataDebugMode);
   if(m_isInitialized) return true;
   
   // Load OHLC cache
   if(!UpdateOHLCCache(200))
   {
      LOG_ERROR("Failed to initialize OHLC cache for " + m_symbol);
      return false;
   }
   
   // Update derived data
   UpdateDerivedCache();
   
   // Get current tick
   GetTick(m_symbol);
   
   m_isInitialized = true;
   LOG_INFO("MarketData initialized for " + m_symbol + " (" + EnumToString(m_timeframe) + ")", g_marketDataDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Update OHLC Cache                                               |
//+------------------------------------------------------------------+
bool MarketData::UpdateOHLCCache(int bars)
{
   LOG_DEBUG("Updating OHLC cache with " + IntegerToString(bars) + " bars", g_marketDataDebugMode);
   if(bars <= 0) bars = 100;
   
   // Resize arrays
   ArrayResize(m_ohlcCache.open, bars);
   ArrayResize(m_ohlcCache.high, bars);
   ArrayResize(m_ohlcCache.low, bars);
   ArrayResize(m_ohlcCache.close, bars);
   ArrayResize(m_ohlcCache.time, bars);
   ArrayResize(m_ohlcCache.volume, bars);
   
   // Copy data - FIXED: Use proper Copy functions
   if(CopyOpen(m_symbol, m_timeframe, 0, bars, m_ohlcCache.open) < bars) 
   {
      LOG_ERROR("Failed to copy Open data for " + m_symbol);
      return false;
   }
   if(CopyHigh(m_symbol, m_timeframe, 0, bars, m_ohlcCache.high) < bars) 
   {
      LOG_ERROR("Failed to copy High data for " + m_symbol);
      return false;
   }
   if(CopyLow(m_symbol, m_timeframe, 0, bars, m_ohlcCache.low) < bars) 
   {
      LOG_ERROR("Failed to copy Low data for " + m_symbol);
      return false;
   }
   if(CopyClose(m_symbol, m_timeframe, 0, bars, m_ohlcCache.close) < bars) 
   {
      LOG_ERROR("Failed to copy Close data for " + m_symbol);
      return false;
   }
   if(CopyTime(m_symbol, m_timeframe, 0, bars, m_ohlcCache.time) < bars) 
   {
      LOG_ERROR("Failed to copy Time data for " + m_symbol);
      return false;
   }
   
   // Volume - CopyVolume doesn't exist, use CopyTickVolume or CopyRealVolume
   if(CopyTickVolume(m_symbol, m_timeframe, 0, bars, m_ohlcCache.volume) < bars)
   {
      // Fallback to CopyRealVolume if tick volume not available
      if(CopyRealVolume(m_symbol, m_timeframe, 0, bars, m_ohlcCache.volume) < bars)
      {
         // If both fail, set volume to 0
         ArrayInitialize(m_ohlcCache.volume, 0);
         LOG_WARNING("Volume data not available for " + m_symbol);
      }
   }
   
   m_ohlcCache.size = bars;
   m_ohlcCache.lastUpdate = TimeCurrent();
   m_barsCached = bars;
   
   LOG_DEBUG("OHLC cache updated successfully with " + IntegerToString(bars) + " bars", g_marketDataDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Update Derived Cache                                            |
//+------------------------------------------------------------------+
bool MarketData::UpdateDerivedCache()
{
   LOG_DEBUG("Updating derived cache", g_marketDataDebugMode);
   if(TimeCurrent() - m_derivedCache.lastUpdate < 5 && m_derivedCache.lastUpdate > 0)
      return true;  // Cache is fresh
   
   m_derivedCache.atr = CalculateATR(14);
   m_derivedCache.averageRange = CalculateAverageRange(20);
   m_derivedCache.volatility = CalculateVolatility(20);
   m_derivedCache.momentum = CalculateMomentum(14);
   m_derivedCache.rsi = CalculateRSI(14);
   CalculateMACD(m_derivedCache.macdMain, m_derivedCache.macdSignal, m_derivedCache.macdHistogram);
   m_derivedCache.lastUpdate = TimeCurrent();
   
   LOG_DEBUG("Derived cache updated successfully", g_marketDataDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Get Bid                                                         |
//+------------------------------------------------------------------+
double MarketData::GetBid(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   LOG_DEBUG("GetBid for " + sym + ": " + DoubleToString(bid, GetDigits(sym)), g_marketDataDebugMode);
   return bid;
}

//+------------------------------------------------------------------+
//| Get Ask                                                         |
//+------------------------------------------------------------------+
double MarketData::GetAsk(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   LOG_DEBUG("GetAsk for " + sym + ": " + DoubleToString(ask, GetDigits(sym)), g_marketDataDebugMode);
   return ask;
}

//+------------------------------------------------------------------+
//| Get Mid Price                                                    |
//+------------------------------------------------------------------+
double MarketData::GetMid(string symbol = NULL)
{
   double mid = (GetBid(symbol) + GetAsk(symbol)) / 2.0;
   LOG_DEBUG("GetMid for " + (symbol == NULL ? m_symbol : symbol) + ": " + DoubleToString(mid, GetDigits(symbol)), g_marketDataDebugMode);
   return mid;
}

//+------------------------------------------------------------------+
//| Get Spread                                                       |
//+------------------------------------------------------------------+
double MarketData::GetSpread(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double spread = (double)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   LOG_DEBUG("GetSpread for " + sym + ": " + DoubleToString(spread, 0), g_marketDataDebugMode);
   return spread;
}

//+------------------------------------------------------------------+
//| Get Spread in Pips                                              |
//+------------------------------------------------------------------+
double MarketData::GetSpreadInPips(string symbol = NULL)
{
   double spread = GetSpread(symbol);
   double point = GetPoint(symbol);
   if(point <= 0) return 0;
   double spreadInPips = spread * point / GetPipSize(symbol);
   LOG_DEBUG("GetSpreadInPips for " + (symbol == NULL ? m_symbol : symbol) + ": " + DoubleToString(spreadInPips, 1), g_marketDataDebugMode);
   return spreadInPips;
}

//+------------------------------------------------------------------+
//| Get Tick Data                                                   |
//+------------------------------------------------------------------+
MqlTick MarketData::GetTick(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   MqlTick tick;
   if(SymbolInfoTick(sym, tick))
   {
      m_lastTick = tick;
      m_lastUpdate = TimeCurrent();
      LOG_DEBUG("Tick updated for " + sym + ": Bid=" + DoubleToString(tick.bid, GetDigits(sym)) + ", Ask=" + DoubleToString(tick.ask, GetDigits(sym)), g_marketDataDebugMode);
   }
   else
   {
      LOG_ERROR("Failed to get tick for " + sym);
   }
   return m_lastTick;
}

//+------------------------------------------------------------------+
//| Get Open Price                                                  |
//+------------------------------------------------------------------+
double MarketData::GetOpen(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetOpen from cache shift=" + IntegerToString(shift) + ": " + DoubleToString(m_ohlcCache.open[shift], GetDigits(sym)), g_marketDataDebugMode);
      return m_ohlcCache.open[shift];
   }
   
   double open = iOpen(sym, t, shift);
   LOG_DEBUG("GetOpen from iOpen shift=" + IntegerToString(shift) + ": " + DoubleToString(open, GetDigits(sym)), g_marketDataDebugMode);
   return open;
}

//+------------------------------------------------------------------+
//| Get High Price                                                  |
//+------------------------------------------------------------------+
double MarketData::GetHigh(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetHigh from cache shift=" + IntegerToString(shift) + ": " + DoubleToString(m_ohlcCache.high[shift], GetDigits(sym)), g_marketDataDebugMode);
      return m_ohlcCache.high[shift];
   }
   
   double high = iHigh(sym, t, shift);
   LOG_DEBUG("GetHigh from iHigh shift=" + IntegerToString(shift) + ": " + DoubleToString(high, GetDigits(sym)), g_marketDataDebugMode);
   return high;
}

//+------------------------------------------------------------------+
//| Get Low Price                                                   |
//+------------------------------------------------------------------+
double MarketData::GetLow(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetLow from cache shift=" + IntegerToString(shift) + ": " + DoubleToString(m_ohlcCache.low[shift], GetDigits(sym)), g_marketDataDebugMode);
      return m_ohlcCache.low[shift];
   }
   
   double low = iLow(sym, t, shift);
   LOG_DEBUG("GetLow from iLow shift=" + IntegerToString(shift) + ": " + DoubleToString(low, GetDigits(sym)), g_marketDataDebugMode);
   return low;
}

//+------------------------------------------------------------------+
//| Get Close Price                                                 |
//+------------------------------------------------------------------+
double MarketData::GetClose(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetClose from cache shift=" + IntegerToString(shift) + ": " + DoubleToString(m_ohlcCache.close[shift], GetDigits(sym)), g_marketDataDebugMode);
      return m_ohlcCache.close[shift];
   }
   
   double close = iClose(sym, t, shift);
   LOG_DEBUG("GetClose from iClose shift=" + IntegerToString(shift) + ": " + DoubleToString(close, GetDigits(sym)), g_marketDataDebugMode);
   return close;
}

//+------------------------------------------------------------------+
//| Get Volume                                                      |
//+------------------------------------------------------------------+
long MarketData::GetVolume(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetVolume from cache shift=" + IntegerToString(shift) + ": " + IntegerToString(m_ohlcCache.volume[shift]), g_marketDataDebugMode);
      return m_ohlcCache.volume[shift];
   }
   
   // Try tick volume first, then real volume
   long volumeArray[1];
   if(CopyTickVolume(sym, t, shift, 1, volumeArray) > 0)
   {
      LOG_DEBUG("GetVolume from tick volume shift=" + IntegerToString(shift) + ": " + IntegerToString(volumeArray[0]), g_marketDataDebugMode);
      return volumeArray[0];
   }
   
   if(CopyRealVolume(sym, t, shift, 1, volumeArray) > 0)
   {
      LOG_DEBUG("GetVolume from real volume shift=" + IntegerToString(shift) + ": " + IntegerToString(volumeArray[0]), g_marketDataDebugMode);
      return volumeArray[0];
   }
   
   LOG_WARNING("GetVolume failed for " + sym + " shift=" + IntegerToString(shift));
   return 0;
}

//+------------------------------------------------------------------+
//| Get Time                                                        |
//+------------------------------------------------------------------+
datetime MarketData::GetTime(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   if(shift < m_ohlcCache.size && t == m_timeframe && symbol == NULL)
   {
      LOG_DEBUG("GetTime from cache shift=" + IntegerToString(shift) + ": " + TimeToString(m_ohlcCache.time[shift]), g_marketDataDebugMode);
      return m_ohlcCache.time[shift];
   }
   
   datetime time = iTime(sym, t, shift);
   LOG_DEBUG("GetTime from iTime shift=" + IntegerToString(shift) + ": " + TimeToString(time), g_marketDataDebugMode);
   return time;
}

//+------------------------------------------------------------------+
//| Get Complete OHLC                                               |
//+------------------------------------------------------------------+
bool MarketData::GetOHLC(int shift, double &open, double &high, double &low, double &close, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("GetOHLC called shift=" + IntegerToString(shift), g_marketDataDebugMode);
   open = GetOpen(shift, symbol, tf);
   high = GetHigh(shift, symbol, tf);
   low = GetLow(shift, symbol, tf);
   close = GetClose(shift, symbol, tf);
   
   bool result = (open > 0 && high > 0 && low > 0 && close > 0);
   if(result)
   {
      LOG_DEBUG("GetOHLC successful: O=" + DoubleToString(open, GetDigits(symbol)) + ", H=" + DoubleToString(high, GetDigits(symbol)) + 
                ", L=" + DoubleToString(low, GetDigits(symbol)) + ", C=" + DoubleToString(close, GetDigits(symbol)), g_marketDataDebugMode);
   }
   else
   {
      LOG_WARNING("GetOHLC failed for shift=" + IntegerToString(shift) + " on " + (symbol == NULL ? m_symbol : symbol));
   }
   return result;
}

//+------------------------------------------------------------------+
//| Get OHLC Array                                                  |
//+------------------------------------------------------------------+
bool MarketData::GetOHLCArray(double &open[], double &high[], double &low[], double &close[], int count, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("GetOHLCArray called count=" + IntegerToString(count), g_marketDataDebugMode);
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyOpen(sym, t, 0, count, open) < count) 
   {
      LOG_ERROR("Failed to copy Open array for " + sym);
      return false;
   }
   if(CopyHigh(sym, t, 0, count, high) < count) 
   {
      LOG_ERROR("Failed to copy High array for " + sym);
      return false;
   }
   if(CopyLow(sym, t, 0, count, low) < count) 
   {
      LOG_ERROR("Failed to copy Low array for " + sym);
      return false;
   }
   if(CopyClose(sym, t, 0, count, close) < count) 
   {
      LOG_ERROR("Failed to copy Close array for " + sym);
      return false;
   }
   
   LOG_DEBUG("GetOHLCArray successful for " + sym + " with " + IntegerToString(count) + " bars", g_marketDataDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Get Point Size                                                  |
//+------------------------------------------------------------------+
double MarketData::GetPoint(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   LOG_DEBUG("GetPoint for " + sym + ": " + DoubleToString(point, 8), g_marketDataDebugMode);
   return point;
}

//+------------------------------------------------------------------+
//| Get Pip Size                                                    |
//+------------------------------------------------------------------+
double MarketData::GetPipSize(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double pipSize;
   if(StringFind(SymbolInfoString(sym, SYMBOL_CURRENCY_BASE), "JPY") >= 0)
      pipSize = point * 100;
   else
      pipSize = point * 10;
   LOG_DEBUG("GetPipSize for " + sym + ": " + DoubleToString(pipSize, 8), g_marketDataDebugMode);
   return pipSize;
}

//+------------------------------------------------------------------+
//| Get Tick Value                                                  |
//+------------------------------------------------------------------+
double MarketData::GetTickValue(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   LOG_DEBUG("GetTickValue for " + sym + ": " + DoubleToString(tickValue, 4), g_marketDataDebugMode);
   return tickValue;
}

//+------------------------------------------------------------------+
//| Get Minimum Lot Size                                            |
//+------------------------------------------------------------------+
double MarketData::GetMinLot(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   LOG_DEBUG("GetMinLot for " + sym + ": " + DoubleToString(minLot, 2), g_marketDataDebugMode);
   return minLot;
}

//+------------------------------------------------------------------+
//| Get Maximum Lot Size                                            |
//+------------------------------------------------------------------+
double MarketData::GetMaxLot(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   LOG_DEBUG("GetMaxLot for " + sym + ": " + DoubleToString(maxLot, 2), g_marketDataDebugMode);
   return maxLot;
}

//+------------------------------------------------------------------+
//| Get Lot Step                                                    |
//+------------------------------------------------------------------+
double MarketData::GetLotStep(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   LOG_DEBUG("GetLotStep for " + sym + ": " + DoubleToString(lotStep, 4), g_marketDataDebugMode);
   return lotStep;
}

//+------------------------------------------------------------------+
//| Get Stop Level                                                  |
//+------------------------------------------------------------------+
double MarketData::GetStopLevel(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double stopLevel = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   LOG_DEBUG("GetStopLevel for " + sym + ": " + DoubleToString(stopLevel, 0), g_marketDataDebugMode);
   return stopLevel;
}

//+------------------------------------------------------------------+
//| Get Freeze Level                                                |
//+------------------------------------------------------------------+
double MarketData::GetFreezeLevel(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double freezeLevel = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   LOG_DEBUG("GetFreezeLevel for " + sym + ": " + DoubleToString(freezeLevel, 0), g_marketDataDebugMode);
   return freezeLevel;
}

//+------------------------------------------------------------------+
//| Get Digits                                                      |
//+------------------------------------------------------------------+
int MarketData::GetDigits(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   LOG_DEBUG("GetDigits for " + sym + ": " + IntegerToString(digits), g_marketDataDebugMode);
   return digits;
}

//+------------------------------------------------------------------+
//| Get Point Digits                                                |
//+------------------------------------------------------------------+
int MarketData::GetPointDigits(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   int pointDigits;
   if(StringFind(SymbolInfoString(sym, SYMBOL_CURRENCY_BASE), "JPY") >= 0)
      pointDigits = digits - 2;
   else
      pointDigits = digits - 1;
   LOG_DEBUG("GetPointDigits for " + sym + ": " + IntegerToString(pointDigits), g_marketDataDebugMode);
   return pointDigits;
}

//+------------------------------------------------------------------+
//| Get Swap Long                                                   |
//+------------------------------------------------------------------+
double MarketData::GetSwapLong(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double swapLong = SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
   LOG_DEBUG("GetSwapLong for " + sym + ": " + DoubleToString(swapLong, 4), g_marketDataDebugMode);
   return swapLong;
}

//+------------------------------------------------------------------+
//| Get Swap Short                                                  |
//+------------------------------------------------------------------+
double MarketData::GetSwapShort(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double swapShort = SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
   LOG_DEBUG("GetSwapShort for " + sym + ": " + DoubleToString(swapShort, 4), g_marketDataDebugMode);
   return swapShort;
}

//+------------------------------------------------------------------+
//| Get Contract Size                                               |
//+------------------------------------------------------------------+
double MarketData::GetContractSize(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   double contractSize = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
   LOG_DEBUG("GetContractSize for " + sym + ": " + DoubleToString(contractSize, 0), g_marketDataDebugMode);
   return contractSize;
}

//+------------------------------------------------------------------+
//| Get Currency Profit                                             |
//+------------------------------------------------------------------+
string MarketData::GetCurrencyProfit(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   string currencyProfit = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
   LOG_DEBUG("GetCurrencyProfit for " + sym + ": " + currencyProfit, g_marketDataDebugMode);
   return currencyProfit;
}

//+------------------------------------------------------------------+
//| Get Currency Margin                                             |
//+------------------------------------------------------------------+
string MarketData::GetCurrencyMargin(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   string currencyMargin = SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN);
   LOG_DEBUG("GetCurrencyMargin for " + sym + ": " + currencyMargin, g_marketDataDebugMode);
   return currencyMargin;
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                   |
//+------------------------------------------------------------------+
double MarketData::CalculateATR(int period)
{
   LOG_DEBUG("Calculating ATR period=" + IntegerToString(period), g_marketDataDebugMode);
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int bars = period + 1;
   if(CopyHigh(m_symbol, m_timeframe, 0, bars, high) < bars) 
   {
      LOG_ERROR("Failed to copy High for ATR calculation");
      return 0;
   }
   if(CopyLow(m_symbol, m_timeframe, 0, bars, low) < bars) 
   {
      LOG_ERROR("Failed to copy Low for ATR calculation");
      return 0;
   }
   if(CopyClose(m_symbol, m_timeframe, 0, bars, close) < bars) 
   {
      LOG_ERROR("Failed to copy Close for ATR calculation");
      return 0;
   }
   
   double sum = 0;
   for(int i = 1; i <= period; i++)
   {
      double hl = high[i] - low[i];
      double hc = MathAbs(high[i] - close[i]);
      double lc = MathAbs(low[i] - close[i]);
      double tr = MathMax(hl, MathMax(hc, lc));
      sum += tr;
   }
   
   double atr = sum / period;
   LOG_DEBUG("ATR calculated: " + DoubleToString(atr, GetDigits()), g_marketDataDebugMode);
   return atr;
}

//+------------------------------------------------------------------+
//| Calculate Average Range                                         |
//+------------------------------------------------------------------+
double MarketData::CalculateAverageRange(int bars)
{
   LOG_DEBUG("Calculating Average Range bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(m_symbol, m_timeframe, 0, bars + 1, high) < bars + 1) 
   {
      LOG_ERROR("Failed to copy High for Average Range calculation");
      return 0;
   }
   if(CopyLow(m_symbol, m_timeframe, 0, bars + 1, low) < bars + 1) 
   {
      LOG_ERROR("Failed to copy Low for Average Range calculation");
      return 0;
   }
   
   double sum = 0;
   for(int i = 0; i < bars; i++)
      sum += high[i] - low[i];
   
   double avgRange = sum / bars;
   LOG_DEBUG("Average Range calculated: " + DoubleToString(avgRange, GetDigits()), g_marketDataDebugMode);
   return avgRange;
}

//+------------------------------------------------------------------+
//| Calculate Volatility                                            |
//+------------------------------------------------------------------+
double MarketData::CalculateVolatility(int bars)
{
   LOG_DEBUG("Calculating Volatility bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(m_symbol, m_timeframe, 0, bars + 1, close) < bars + 1) 
   {
      LOG_ERROR("Failed to copy Close for Volatility calculation");
      return 0;
   }
   
   double sum = 0;
   for(int i = 0; i < bars; i++)
      sum += close[i];
   
   double mean = sum / bars;
   double variance = 0;
   
   for(int i = 0; i < bars; i++)
      variance += MathPow(close[i] - mean, 2);
   
   variance /= bars;
   double volatility = MathSqrt(variance);
   LOG_DEBUG("Volatility calculated: " + DoubleToString(volatility, GetDigits()), g_marketDataDebugMode);
   return volatility;
}

//+------------------------------------------------------------------+
//| Calculate Momentum                                              |
//+------------------------------------------------------------------+
double MarketData::CalculateMomentum(int period)
{
   LOG_DEBUG("Calculating Momentum period=" + IntegerToString(period), g_marketDataDebugMode);
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(m_symbol, m_timeframe, 0, period + 1, close) < period + 1) 
   {
      LOG_ERROR("Failed to copy Close for Momentum calculation");
      return 0;
   }
   
   double momentum = close[0] - close[period];
   LOG_DEBUG("Momentum calculated: " + DoubleToString(momentum, GetDigits()), g_marketDataDebugMode);
   return momentum;
}

//+------------------------------------------------------------------+
//| Calculate RSI                                                   |
//+------------------------------------------------------------------+
double MarketData::CalculateRSI(int period)
{
   LOG_DEBUG("Calculating RSI period=" + IntegerToString(period), g_marketDataDebugMode);
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(m_symbol, m_timeframe, 0, period + 1, close) < period + 1) 
   {
      LOG_ERROR("Failed to copy Close for RSI calculation");
      return 50;
   }
   
   double gain = 0, loss = 0;
   
   for(int i = 1; i <= period; i++)
   {
      double diff = close[i-1] - close[i];
      if(diff > 0)
         gain += diff;
      else
         loss -= diff;
   }
   
   if(loss == 0) return 100;
   
   double rs = gain / loss;
   double rsi = 100 - (100 / (1 + rs));
   LOG_DEBUG("RSI calculated: " + DoubleToString(rsi, 2), g_marketDataDebugMode);
   return rsi;
}

//+------------------------------------------------------------------+
//| Calculate MACD - Renamed to avoid conflict                      |
//+------------------------------------------------------------------+
bool MarketData::CalculateMACD(double &main, double &signal, double &histogram, int fast, int slow, int signalPeriod)
{
   LOG_DEBUG("Calculating MACD fast=" + IntegerToString(fast) + ", slow=" + IntegerToString(slow) + ", signal=" + IntegerToString(signalPeriod), g_marketDataDebugMode);
   // Use built-in MACD handle for accurate calculation
   int handle = iMACD(m_symbol, m_timeframe, fast, slow, signalPeriod, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
   {
      LOG_ERROR("Failed to create MACD handle for " + m_symbol);
      main = signal = histogram = 0;
      return false;
   }
   
   double mainBuffer[1], signalBuffer[1];
   
   if(CopyBuffer(handle, 0, 0, 1, mainBuffer) < 1 ||
      CopyBuffer(handle, 1, 0, 1, signalBuffer) < 1)
   {
      LOG_ERROR("Failed to copy MACD buffers for " + m_symbol);
      main = signal = histogram = 0;
      IndicatorRelease(handle);
      return false;
   }
   
   main = mainBuffer[0];
   signal = signalBuffer[0];
   histogram = main - signal;
   
   IndicatorRelease(handle);
   LOG_DEBUG("MACD calculated: Main=" + DoubleToString(main, 4) + ", Signal=" + DoubleToString(signal, 4) + ", Hist=" + DoubleToString(histogram, 4), g_marketDataDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Get MACD Values - Public interface                              |
//+------------------------------------------------------------------+
bool MarketData::GetMACDValues(double &main, double &signal, double &histogram, int fast, int slow, int signalPeriod)
{
   LOG_DEBUG("GetMACDValues called fast=" + IntegerToString(fast) + ", slow=" + IntegerToString(slow) + ", signal=" + IntegerToString(signalPeriod), g_marketDataDebugMode);
   // Check cache first
   if(m_derivedCache.lastUpdate > 0 && 
      TimeCurrent() - m_derivedCache.lastUpdate < 5)
   {
      main = m_derivedCache.macdMain;
      signal = m_derivedCache.macdSignal;
      histogram = m_derivedCache.macdHistogram;
      LOG_DEBUG("GetMACDValues from cache: Main=" + DoubleToString(main, 4) + ", Signal=" + DoubleToString(signal, 4) + ", Hist=" + DoubleToString(histogram, 4), g_marketDataDebugMode);
      return true;
   }
   
   // Calculate fresh
   bool result = CalculateMACD(main, signal, histogram, fast, slow, signalPeriod);
   LOG_DEBUG("GetMACDValues calculated fresh: " + (result ? "success" : "failed"), g_marketDataDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get ATR (cached)                                                |
//+------------------------------------------------------------------+
double MarketData::GetATR(int period)
{
   LOG_DEBUG("GetATR called period=" + IntegerToString(period), g_marketDataDebugMode);
   if(period == 14 && m_derivedCache.lastUpdate > 0)
   {
      LOG_DEBUG("GetATR from cache: " + DoubleToString(m_derivedCache.atr, GetDigits()), g_marketDataDebugMode);
      return m_derivedCache.atr;
   }
   double atr = CalculateATR(period);
   LOG_DEBUG("GetATR calculated: " + DoubleToString(atr, GetDigits()), g_marketDataDebugMode);
   return atr;
}

//+------------------------------------------------------------------+
//| Get Average Range                                               |
//+------------------------------------------------------------------+
double MarketData::GetAverageRange(int bars)
{
   LOG_DEBUG("GetAverageRange called bars=" + IntegerToString(bars), g_marketDataDebugMode);
   if(bars == 20 && m_derivedCache.lastUpdate > 0)
   {
      LOG_DEBUG("GetAverageRange from cache: " + DoubleToString(m_derivedCache.averageRange, GetDigits()), g_marketDataDebugMode);
      return m_derivedCache.averageRange;
   }
   double avgRange = CalculateAverageRange(bars);
   LOG_DEBUG("GetAverageRange calculated: " + DoubleToString(avgRange, GetDigits()), g_marketDataDebugMode);
   return avgRange;
}

//+------------------------------------------------------------------+
//| Get Volatility                                                  |
//+------------------------------------------------------------------+
double MarketData::GetVolatility(int bars)
{
   LOG_DEBUG("GetVolatility called bars=" + IntegerToString(bars), g_marketDataDebugMode);
   if(bars == 20 && m_derivedCache.lastUpdate > 0)
   {
      LOG_DEBUG("GetVolatility from cache: " + DoubleToString(m_derivedCache.volatility, GetDigits()), g_marketDataDebugMode);
      return m_derivedCache.volatility;
   }
   double volatility = CalculateVolatility(bars);
   LOG_DEBUG("GetVolatility calculated: " + DoubleToString(volatility, GetDigits()), g_marketDataDebugMode);
   return volatility;
}

//+------------------------------------------------------------------+
//| Get Momentum                                                    |
//+------------------------------------------------------------------+
double MarketData::GetMomentum(int period)
{
   LOG_DEBUG("GetMomentum called period=" + IntegerToString(period), g_marketDataDebugMode);
   if(period == 14 && m_derivedCache.lastUpdate > 0)
   {
      LOG_DEBUG("GetMomentum from cache: " + DoubleToString(m_derivedCache.momentum, GetDigits()), g_marketDataDebugMode);
      return m_derivedCache.momentum;
   }
   double momentum = CalculateMomentum(period);
   LOG_DEBUG("GetMomentum calculated: " + DoubleToString(momentum, GetDigits()), g_marketDataDebugMode);
   return momentum;
}

//+------------------------------------------------------------------+
//| Get RSI                                                         |
//+------------------------------------------------------------------+
double MarketData::GetRSI(int period)
{
   LOG_DEBUG("GetRSI called period=" + IntegerToString(period), g_marketDataDebugMode);
   if(period == 14 && m_derivedCache.lastUpdate > 0)
   {
      LOG_DEBUG("GetRSI from cache: " + DoubleToString(m_derivedCache.rsi, 2), g_marketDataDebugMode);
      return m_derivedCache.rsi;
   }
   double rsi = CalculateRSI(period);
   LOG_DEBUG("GetRSI calculated: " + DoubleToString(rsi, 2), g_marketDataDebugMode);
   return rsi;
}

//+------------------------------------------------------------------+
//| Check if New Bar                                                |
//+------------------------------------------------------------------+
bool MarketData::IsNewBar(string symbol, ENUM_TIMEFRAMES tf)
{
   datetime currentBarTime = GetTime(0, symbol, tf);
   if(currentBarTime == 0) return false;
   
   if(currentBarTime != m_lastBarTime)
   {
      m_lastBarTime = currentBarTime;
      LOG_DEBUG("New bar detected: " + TimeToString(currentBarTime), g_marketDataDebugMode);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if Bullish Bar                                            |
//+------------------------------------------------------------------+
bool MarketData::IsBullishBar(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   double open = GetOpen(shift, symbol, tf);
   double close = GetClose(shift, symbol, tf);
   bool bullish = (close > open);
   LOG_DEBUG("IsBullishBar shift=" + IntegerToString(shift) + ": " + (bullish ? "true" : "false"), g_marketDataDebugMode);
   return bullish;
}

//+------------------------------------------------------------------+
//| Check if Bearish Bar                                            |
//+------------------------------------------------------------------+
bool MarketData::IsBearishBar(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   double open = GetOpen(shift, symbol, tf);
   double close = GetClose(shift, symbol, tf);
   bool bearish = (close < open);
   LOG_DEBUG("IsBearishBar shift=" + IntegerToString(shift) + ": " + (bearish ? "true" : "false"), g_marketDataDebugMode);
   return bearish;
}

//+------------------------------------------------------------------+
//| Check if Doji Bar                                               |
//+------------------------------------------------------------------+
bool MarketData::IsDojiBar(int shift, double threshold, string symbol, ENUM_TIMEFRAMES tf)
{
   double open = GetOpen(shift, symbol, tf);
   double high = GetHigh(shift, symbol, tf);
   double low = GetLow(shift, symbol, tf);
   double close = GetClose(shift, symbol, tf);
   
   double body = MathAbs(close - open);
   double range = high - low;
   
   if(range == 0) return false;
   bool doji = (body / range) <= threshold;
   LOG_DEBUG("IsDojiBar shift=" + IntegerToString(shift) + ": " + (doji ? "true" : "false"), g_marketDataDebugMode);
   return doji;
}

//+------------------------------------------------------------------+
//| Check if Pin Bar                                                |
//+------------------------------------------------------------------+
bool MarketData::IsPinBar(int shift, double threshold, string symbol, ENUM_TIMEFRAMES tf)
{
   double open = GetOpen(shift, symbol, tf);
   double high = GetHigh(shift, symbol, tf);
   double low = GetLow(shift, symbol, tf);
   double close = GetClose(shift, symbol, tf);
   
   double body = MathAbs(close - open);
   double range = high - low;
   
   if(range == 0) return false;
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   
   // Pin bar has one wick at least threshold of the range
   bool pinBar = (upperWick / range >= threshold || lowerWick / range >= threshold);
   LOG_DEBUG("IsPinBar shift=" + IntegerToString(shift) + ": " + (pinBar ? "true" : "false"), g_marketDataDebugMode);
   return pinBar;
}

//+------------------------------------------------------------------+
//| Check if Engulfing                                              |
//+------------------------------------------------------------------+
bool MarketData::IsEngulfing(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   bool currBull = IsBullishBar(shift, symbol, tf);
   bool prevBull = IsBullishBar(shift + 1, symbol, tf);
   
   double currHigh = GetHigh(shift, symbol, tf);
   double currLow = GetLow(shift, symbol, tf);
   double prevHigh = GetHigh(shift + 1, symbol, tf);
   double prevLow = GetLow(shift + 1, symbol, tf);
   
   bool engulfing = false;
   if(currBull && !prevBull)
      engulfing = (currHigh > prevHigh && currLow < prevLow);
   else if(!currBull && prevBull)
      engulfing = (currHigh > prevHigh && currLow < prevLow);
   
   LOG_DEBUG("IsEngulfing shift=" + IntegerToString(shift) + ": " + (engulfing ? "true" : "false"), g_marketDataDebugMode);
   return engulfing;
}

//+------------------------------------------------------------------+
//| Check if Inside Bar                                             |
//+------------------------------------------------------------------+
bool MarketData::IsInsideBar(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   double currHigh = GetHigh(shift, symbol, tf);
   double currLow = GetLow(shift, symbol, tf);
   double prevHigh = GetHigh(shift + 1, symbol, tf);
   double prevLow = GetLow(shift + 1, symbol, tf);
   
   bool inside = (currHigh <= prevHigh && currLow >= prevLow);
   LOG_DEBUG("IsInsideBar shift=" + IntegerToString(shift) + ": " + (inside ? "true" : "false"), g_marketDataDebugMode);
   return inside;
}

//+------------------------------------------------------------------+
//| Check if Outside Bar                                            |
//+------------------------------------------------------------------+
bool MarketData::IsOutsideBar(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
   double currHigh = GetHigh(shift, symbol, tf);
   double currLow = GetLow(shift, symbol, tf);
   double prevHigh = GetHigh(shift + 1, symbol, tf);
   double prevLow = GetLow(shift + 1, symbol, tf);
   
   bool outside = (currHigh > prevHigh && currLow < prevLow);
   LOG_DEBUG("IsOutsideBar shift=" + IntegerToString(shift) + ": " + (outside ? "true" : "false"), g_marketDataDebugMode);
   return outside;
}

//+------------------------------------------------------------------+
//| Check if Market Open                                            |
//+------------------------------------------------------------------+
bool MarketData::IsMarketOpen(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   // Check if we can get a tick
   MqlTick tick;
   bool marketOpen = false;
   if(SymbolInfoTick(sym, tick))
      marketOpen = (tick.bid > 0 && tick.ask > 0);
   LOG_DEBUG("IsMarketOpen for " + sym + ": " + (marketOpen ? "true" : "false"), g_marketDataDebugMode);
   return marketOpen;
}

//+------------------------------------------------------------------+
//| Check if Trading Allowed                                        |
//+------------------------------------------------------------------+
bool MarketData::IsTradingAllowed(string symbol = NULL)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   bool tradingAllowed = (bool)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL;
   LOG_DEBUG("IsTradingAllowed for " + sym + ": " + (tradingAllowed ? "true" : "false"), g_marketDataDebugMode);
   return tradingAllowed;
}

//+------------------------------------------------------------------+
//| Check if Session Active - Simplified                            |
//+------------------------------------------------------------------+
bool MarketData::IsSessionActive(int session = 0, string symbol = NULL)
{
   // Simplified - always return true for now
   // Can be expanded with actual session detection
   return true;
}

//+------------------------------------------------------------------+
//| Get Market Hours - Simplified                                   |
//+------------------------------------------------------------------+
int MarketData::GetMarketHours(string symbol = NULL)
{
   // Return 24 hours by default
   return 24;
}

//+------------------------------------------------------------------+
//| Get Day Range                                                   |
//+------------------------------------------------------------------+
double MarketData::GetDayRange(int lookback)
{
   if(lookback <= 0) lookback = 1;
   
   double high = GetHigh(0);
   double low = GetLow(0);
   
   // For daily range, we need the high/low of the current day
   // Simple implementation using current bar
   double dayRange = high - low;
   LOG_DEBUG("GetDayRange: " + DoubleToString(dayRange, GetDigits()), g_marketDataDebugMode);
   return dayRange;
}

//+------------------------------------------------------------------+
//| Get Average Day Range                                           |
//+------------------------------------------------------------------+
double MarketData::GetAverageDayRange(int days)
{
   if(days <= 0) days = 20;
   
   double sum = 0;
   for(int i = 0; i < days; i++)
   {
      double high = GetHigh(i);
      double low = GetLow(i);
      if(high > 0 && low > 0)
         sum += high - low;
   }
   
   double avgDayRange = sum / days;
   LOG_DEBUG("GetAverageDayRange: " + DoubleToString(avgDayRange, GetDigits()), g_marketDataDebugMode);
   return avgDayRange;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                              |
//+------------------------------------------------------------------+
double MarketData::CalculateLotSize(double riskPercent, double stopLossPips, double accountBalance)
{
   LOG_DEBUG("CalculateLotSize riskPercent=" + DoubleToString(riskPercent, 2) + ", stopLossPips=" + DoubleToString(stopLossPips, 2), g_marketDataDebugMode);
   if(accountBalance <= 0)
      accountBalance = GetAccountBalance();
   
   if(riskPercent <= 0 || stopLossPips <= 0 || accountBalance <= 0)
   {
      LOG_WARNING("Invalid parameters for CalculateLotSize");
      return 0;
   }
   
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pipValue = GetPipValue(1.0, m_symbol);
   
   if(pipValue <= 0 || stopLossPips <= 0)
   {
      LOG_WARNING("Invalid pipValue or stopLossPips for CalculateLotSize");
      return 0;
   }
   
   double lotSize = riskAmount / (pipValue * stopLossPips);
   lotSize = NormalizeLot(lotSize);
   LOG_DEBUG("CalculateLotSize result: " + DoubleToString(lotSize, 2), g_marketDataDebugMode);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss Pips                                        |
//+------------------------------------------------------------------+
double MarketData::CalculateStopLossPips(double riskPercent, double lotSize, double accountBalance)
{
   LOG_DEBUG("CalculateStopLossPips riskPercent=" + DoubleToString(riskPercent, 2) + ", lotSize=" + DoubleToString(lotSize, 2), g_marketDataDebugMode);
   if(accountBalance <= 0)
      accountBalance = GetAccountBalance();
   
   if(riskPercent <= 0 || lotSize <= 0 || accountBalance <= 0)
   {
      LOG_WARNING("Invalid parameters for CalculateStopLossPips");
      return 0;
   }
   
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pipValue = GetPipValue(lotSize, m_symbol);
   
   if(pipValue <= 0)
   {
      LOG_WARNING("Invalid pipValue for CalculateStopLossPips");
      return 0;
   }
   
   double stopLoss = riskAmount / pipValue;
   LOG_DEBUG("CalculateStopLossPips result: " + DoubleToString(stopLoss, 2), g_marketDataDebugMode);
   return stopLoss;
}

//+------------------------------------------------------------------+
//| Get Pip Value                                                   |
//+------------------------------------------------------------------+
double MarketData::GetPipValue(double lotSize, string symbol)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   if(lotSize <= 0) lotSize = 1.0;
   
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double pipSize = GetPipSize(sym);
   
   if(tickValue <= 0 || tickSize <= 0)
   {
      LOG_WARNING("Invalid tickValue or tickSize for " + sym);
      return 0;
   }
   
   double pipValue = tickValue * (pipSize / tickSize) * lotSize;
   LOG_DEBUG("GetPipValue for " + sym + ": " + DoubleToString(pipValue, 4), g_marketDataDebugMode);
   return pipValue;
}

//+------------------------------------------------------------------+
//| Get Position Value                                              |
//+------------------------------------------------------------------+
double MarketData::GetPositionValue(double lotSize, string symbol)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   if(lotSize <= 0) lotSize = 1.0;
   
   double contractSize = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
   double bid = GetBid(sym);
   
   double positionValue = contractSize * bid * lotSize;
   LOG_DEBUG("GetPositionValue for " + sym + ": " + DoubleToString(positionValue, 2), g_marketDataDebugMode);
   return positionValue;
}

//+------------------------------------------------------------------+
//| Get Margin Requirement                                          |
//+------------------------------------------------------------------+
double MarketData::GetMarginRequirement(double lotSize, string symbol)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   if(lotSize <= 0) return 0;
   
   double marginReq = SymbolInfoDouble(sym, SYMBOL_MARGIN_INITIAL);
   if(marginReq <= 0)
      marginReq = SymbolInfoDouble(sym, SYMBOL_MARGIN_MAINTENANCE);
   
   double margin = marginReq * lotSize;
   LOG_DEBUG("GetMarginRequirement for " + sym + ": " + DoubleToString(margin, 2), g_marketDataDebugMode);
   return margin;
}

//+------------------------------------------------------------------+
//| Get Account Balance                                             |
//+------------------------------------------------------------------+
double MarketData::GetAccountBalance()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   LOG_DEBUG("GetAccountBalance: " + DoubleToString(balance, 2), g_marketDataDebugMode);
   return balance;
}

//+------------------------------------------------------------------+
//| Get Account Equity                                              |
//+------------------------------------------------------------------+
double MarketData::GetAccountEquity()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   LOG_DEBUG("GetAccountEquity: " + DoubleToString(equity, 2), g_marketDataDebugMode);
   return equity;
}

//+------------------------------------------------------------------+
//| Get Free Margin - Fixed deprecated warning                      |
//+------------------------------------------------------------------+
double MarketData::GetFreeMargin()
{
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   LOG_DEBUG("GetFreeMargin: " + DoubleToString(freeMargin, 2), g_marketDataDebugMode);
   return freeMargin;
}

//+------------------------------------------------------------------+
//| Get Max Price                                                   |
//+------------------------------------------------------------------+
double MarketData::GetMaxPrice(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("GetMaxPrice bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double maxPrice = 0;
   for(int i = 0; i < bars; i++)
   {
      double high = GetHigh(i, symbol, tf);
      if(high > maxPrice) maxPrice = high;
   }
   LOG_DEBUG("GetMaxPrice: " + DoubleToString(maxPrice, GetDigits(symbol)), g_marketDataDebugMode);
   return maxPrice;
}

//+------------------------------------------------------------------+
//| Get Min Price                                                   |
//+------------------------------------------------------------------+
double MarketData::GetMinPrice(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("GetMinPrice bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double minPrice = DBL_MAX;
   for(int i = 0; i < bars; i++)
   {
      double low = GetLow(i, symbol, tf);
      if(low < minPrice) minPrice = low;
   }
   LOG_DEBUG("GetMinPrice: " + DoubleToString(minPrice, GetDigits(symbol)), g_marketDataDebugMode);
   return minPrice;
}

//+------------------------------------------------------------------+
//| Get Range                                                       |
//+------------------------------------------------------------------+
double MarketData::GetRange(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   double maxPrice = GetMaxPrice(bars, symbol, tf);
   double minPrice = GetMinPrice(bars, symbol, tf);
   double range = maxPrice - minPrice;
   LOG_DEBUG("GetRange: " + DoubleToString(range, GetDigits(symbol)), g_marketDataDebugMode);
   return range;
}

//+------------------------------------------------------------------+
//| Get Range in Pips                                               |
//+------------------------------------------------------------------+
double MarketData::GetRangeInPips(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   double range = GetRange(bars, symbol, tf);
   double pipSize = GetPipSize(symbol);
   if(pipSize <= 0) return 0;
   double rangeInPips = range / pipSize;
   LOG_DEBUG("GetRangeInPips: " + DoubleToString(rangeInPips, 2), g_marketDataDebugMode);
   return rangeInPips;
}

//+------------------------------------------------------------------+
//| Calculate Mean                                                  |
//+------------------------------------------------------------------+
double MarketData::CalculateMean(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("CalculateMean bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double sum = 0;
   int count = 0;
   for(int i = 0; i < bars; i++)
   {
      double close = GetClose(i, symbol, tf);
      if(close > 0)
      {
         sum += close;
         count++;
      }
   }
   double mean = (count > 0) ? sum / count : 0;
   LOG_DEBUG("CalculateMean: " + DoubleToString(mean, GetDigits(symbol)), g_marketDataDebugMode);
   return mean;
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                    |
//+------------------------------------------------------------------+
double MarketData::CalculateStdDev(int bars, string symbol, ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("CalculateStdDev bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double mean = CalculateMean(bars, symbol, tf);
   if(mean <= 0) return 0;
   
   double sum = 0;
   int count = 0;
   for(int i = 0; i < bars; i++)
   {
      double close = GetClose(i, symbol, tf);
      if(close > 0)
      {
         sum += MathPow(close - mean, 2);
         count++;
      }
   }
   double stdDev = (count > 0) ? MathSqrt(sum / count) : 0;
   LOG_DEBUG("CalculateStdDev: " + DoubleToString(stdDev, GetDigits(symbol)), g_marketDataDebugMode);
   return stdDev;
}

//+------------------------------------------------------------------+
//| Calculate Correlation                                           |
//+------------------------------------------------------------------+
double MarketData::CalculateCorrelation(string symbol2, int bars)
{
   LOG_DEBUG("CalculateCorrelation symbol2=" + symbol2 + ", bars=" + IntegerToString(bars), g_marketDataDebugMode);
   double close1[], close2[];
   ArraySetAsSeries(close1, true);
   ArraySetAsSeries(close2, true);
   
   if(CopyClose(m_symbol, m_timeframe, 0, bars, close1) < bars) 
   {
      LOG_ERROR("Failed to copy Close for " + m_symbol + " in correlation calculation");
      return 0;
   }
   if(CopyClose(symbol2, m_timeframe, 0, bars, close2) < bars) 
   {
      LOG_ERROR("Failed to copy Close for " + symbol2 + " in correlation calculation");
      return 0;
   }
   
   double mean1 = 0, mean2 = 0;
   for(int i = 0; i < bars; i++)
   {
      mean1 += close1[i];
      mean2 += close2[i];
   }
   mean1 /= bars;
   mean2 /= bars;
   
   double covariance = 0, variance1 = 0, variance2 = 0;
   for(int i = 0; i < bars; i++)
   {
      covariance += (close1[i] - mean1) * (close2[i] - mean2);
      variance1 += MathPow(close1[i] - mean1, 2);
      variance2 += MathPow(close2[i] - mean2, 2);
   }
   
   if(variance1 <= 0 || variance2 <= 0) 
   {
      LOG_WARNING("Zero variance in correlation calculation");
      return 0;
   }
   double correlation = covariance / MathSqrt(variance1 * variance2);
   LOG_DEBUG("CalculateCorrelation: " + DoubleToString(correlation, 4), g_marketDataDebugMode);
   return correlation;
}

//+------------------------------------------------------------------+
//| Normalize Price                                                 |
//+------------------------------------------------------------------+
double MarketData::NormalizePrice(double price)
{
   int digits = GetDigits(m_symbol);
   double normalizedPrice = NormalizeDouble(price, digits);
   LOG_DEBUG("NormalizePrice: " + DoubleToString(price, digits) + " -> " + DoubleToString(normalizedPrice, digits), g_marketDataDebugMode);
   return normalizedPrice;
}

//+------------------------------------------------------------------+
//| Normalize Lot                                                   |
//+------------------------------------------------------------------+
double MarketData::NormalizeLot(double lotSize)
{
   LOG_DEBUG("NormalizeLot input: " + DoubleToString(lotSize, 2), g_marketDataDebugMode);
   double step = GetLotStep(m_symbol);
   if(step <= 0) return lotSize;
   
   double minLot = GetMinLot(m_symbol);
   double maxLot = GetMaxLot(m_symbol);
   
   lotSize = MathRound(lotSize / step) * step;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = NormalizeDouble(lotSize, 2);
   LOG_DEBUG("NormalizeLot output: " + DoubleToString(lotSize, 2), g_marketDataDebugMode);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if Price Valid - Fixed MathIsNaN/MathIsInf issues        |
//+------------------------------------------------------------------+
bool MarketData::IsPriceValid(double price)
{
   bool valid = (price > 0 && price < DBL_MAX);
   if(!valid)
      LOG_WARNING("Invalid price: " + DoubleToString(price, 2));
   return valid;
}

//+------------------------------------------------------------------+
//| Check if Lot Valid                                              |
//+------------------------------------------------------------------+
bool MarketData::IsLotValid(double lotSize)
{
   double minLot = GetMinLot(m_symbol);
   double maxLot = GetMaxLot(m_symbol);
   double step = GetLotStep(m_symbol);
   
   bool valid = true;
   if(lotSize < minLot || lotSize > maxLot) valid = false;
   if(MathAbs(lotSize / step - MathRound(lotSize / step)) > 0.0001) valid = false;
   
   if(!valid)
      LOG_WARNING("Invalid lot size: " + DoubleToString(lotSize, 2));
   return valid;
}

//+------------------------------------------------------------------+
//| Refresh Data                                                    |
//+------------------------------------------------------------------+
void MarketData::Refresh()
{
   LOG_DEBUG("Refresh called", g_marketDataDebugMode);
   GetTick(m_symbol);
   UpdateOHLCCache(m_barsCached);
   UpdateDerivedCache();
   LOG_DEBUG("Refresh completed", g_marketDataDebugMode);
}

//+------------------------------------------------------------------+
//| Clear Cache                                                     |
//+------------------------------------------------------------------+
void MarketData::ClearCache()
{
   LOG_DEBUG("ClearCache called", g_marketDataDebugMode);
   m_derivedCache.lastUpdate = 0;
   m_ohlcCache.lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Check if Data is Fresh                                          |
//+------------------------------------------------------------------+
bool MarketData::IsFresh() const
{
   bool fresh = (TimeCurrent() - m_lastUpdate) <= 1;
   if(!fresh)
      LOG_DEBUG("Data is not fresh, last update: " + TimeToString(m_lastUpdate), g_marketDataDebugMode);
   return fresh;
}

//+------------------------------------------------------------------+
//| Check if Data is Valid                                          |
//+------------------------------------------------------------------+
bool MarketData::IsDataValid() const
{
   bool valid = m_isInitialized && m_ohlcCache.size > 0 && m_lastUpdate > 0;
   if(!valid)
      LOG_WARNING("Data is not valid: initialized=" + (m_isInitialized ? "true" : "false") + 
                  ", cacheSize=" + IntegerToString(m_ohlcCache.size) + 
                  ", lastUpdate=" + TimeToString(m_lastUpdate));
   return valid;
}

//+------------------------------------------------------------------+
//| Get Bars Available                                              |
//+------------------------------------------------------------------+
int MarketData::GetBarsAvailable(string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   int bars = Bars(sym, t);
   LOG_DEBUG("GetBarsAvailable for " + sym + ": " + IntegerToString(bars), g_marketDataDebugMode);
   return bars;
}

//+------------------------------------------------------------------+
//| Get Last Bar Time                                               |
//+------------------------------------------------------------------+
datetime MarketData::GetLastBarTime(string symbol, ENUM_TIMEFRAMES tf)
{
   string sym = (symbol == NULL) ? m_symbol : symbol;
   ENUM_TIMEFRAMES t = (tf == PERIOD_CURRENT) ? m_timeframe : tf;
   datetime time[];
   ArraySetAsSeries(time, true);
   datetime lastBarTime = 0;
   if(CopyTime(sym, t, 0, 1, time) < 1) 
   {
      LOG_ERROR("Failed to get last bar time for " + sym);
      return 0;
   }
   lastBarTime = time[0];
   LOG_DEBUG("GetLastBarTime for " + sym + ": " + TimeToString(lastBarTime), g_marketDataDebugMode);
   return lastBarTime;
}

//+------------------------------------------------------------------+
//| Check if High Volatility                                        |
//+------------------------------------------------------------------+
bool MarketData::IsHighVolatility(int threshold)
{
   double atr = GetATR(14);
   double price = GetClose(0);
   if(price <= 0) return false;
   
   double atrPercent = (atr / price) * 100;
   bool highVol = atrPercent > threshold;
   LOG_DEBUG("IsHighVolatility: " + DoubleToString(atrPercent, 2) + "% > " + IntegerToString(threshold) + " = " + (highVol ? "true" : "false"), g_marketDataDebugMode);
   return highVol;
}

//+------------------------------------------------------------------+
//| Check if Low Volatility                                         |
//+------------------------------------------------------------------+
bool MarketData::IsLowVolatility(int threshold)
{
   double atr = GetATR(14);
   double price = GetClose(0);
   if(price <= 0) return false;
   
   double atrPercent = (atr / price) * 100;
   bool lowVol = atrPercent < threshold;
   LOG_DEBUG("IsLowVolatility: " + DoubleToString(atrPercent, 2) + "% < " + IntegerToString(threshold) + " = " + (lowVol ? "true" : "false"), g_marketDataDebugMode);
   return lowVol;
}

//+------------------------------------------------------------------+
//| Check if Breakout                                               |
//+------------------------------------------------------------------+
bool MarketData::IsBreakout(double threshold, int lookback)
{
   if(threshold <= 0)
      threshold = 2.0;  // Default: 2x ATR
   
   double atr = GetATR(14);
   double currentHigh = GetHigh(0);
   double highLookback = GetMaxPrice(lookback + 1);
   double lowLookback = GetMinPrice(lookback + 1);
   
   double breakoutLevel = highLookback + (atr * threshold);
   bool breakout = currentHigh > breakoutLevel;
   LOG_DEBUG("IsBreakout: " + DoubleToString(currentHigh, GetDigits()) + " > " + DoubleToString(breakoutLevel, GetDigits()) + " = " + (breakout ? "true" : "false"), g_marketDataDebugMode);
   return breakout;
}

//+------------------------------------------------------------------+
//| Check if Range Bound                                            |
//+------------------------------------------------------------------+
bool MarketData::IsRangeBound(double threshold, int lookback)
{
   if(threshold <= 0)
      threshold = 0.5;  // Default: 50% of ATR
   
   double atr = GetATR(14);
   double range = GetRange(lookback);
   double midRange = (GetMaxPrice(lookback) + GetMinPrice(lookback)) / 2.0;
   
   // Check if price is within threshold of the range middle
   double deviation = MathAbs(GetClose(0) - midRange);
   bool rangeBound = deviation < (range * threshold);
   LOG_DEBUG("IsRangeBound: " + DoubleToString(deviation, GetDigits()) + " < " + DoubleToString(range * threshold, GetDigits()) + " = " + (rangeBound ? "true" : "false"), g_marketDataDebugMode);
   return rangeBound;
}