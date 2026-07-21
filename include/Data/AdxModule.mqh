//+------------------------------------------------------------------+
//|                        AdxModule.mqh                             |
//|                    ADX Calculation Module                        |
//|                    INTEGRATED WITH INDICATOR MANAGER             |
//|                    v3.2 - IMPROVED CONFIDENCE                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "3.2"

#include "../PackageManagers/IndicatorManager.mqh"
#include "../Utils/Logger.mqh"

// ============================================================
// ADX MODULE INDEPENDENT TOGGLE
// ============================================================
bool g_adxDebugMode = false;

//+------------------------------------------------------------------+
//| Direction Result Structure                                       |
//+------------------------------------------------------------------+
struct SADXDirectionResult
{
   string   direction;        // "BULLISH", "BEARISH", or "NEUTRAL"
   double   bullPercentage;   // 0-100
   double   bearPercentage;   // 0-100
   double   confidence;       // Improved confidence (0-100) - accounts for ADX strength
   string   description;      // Brief description of market condition
   string   narrative;        // Detailed narrative explaining the situation
   double   adxValue;         // Raw ADX value
   double   diPlus;           // +DI value
   double   diMinus;          // -DI value
   bool     isValid;          // Whether the result is valid
   double   trendStrength;    // ADX-based trend strength (0-100)
   double   directionClarity; // How clear the direction is (0-100)
};

//+------------------------------------------------------------------+
//| ADX Summary Result Structure                                     |
//+------------------------------------------------------------------+
struct SADXSummary
{
   double   bullPercentage;   // 0-100
   double   bearPercentage;   // 0-100
   double   adxValue;         // Raw ADX value
   string   description;      // Short description
   bool     isValid;          // Whether the summary is valid
   double   confidence;       // Improved confidence
   double   trendStrength;    // ADX-based trend strength
};

//+------------------------------------------------------------------+
//| ADX Module Class                                                |
//| Uses IndicatorManager for ADX data access                       |
//+------------------------------------------------------------------+
class CAdxModule
{
private:
   // ──────────────────────────────────────────────────────────────
   // CORE MEMBERS
   // ──────────────────────────────────────────────────────────────
   CIndicatorManager*  m_indicatorManager;
   string              m_symbol;
   ENUM_TIMEFRAMES     m_timeframe;
   int                 m_adxPeriod;
   bool                m_initialized;
   bool                m_ownsIndicatorManager;
   string              m_lastError;
   bool                m_initializing;  // Prevent recursion
   bool                m_debug;         // Debug flag (default true for full logging)
   
   // ──────────────────────────────────────────────────────────────
   // CACHED VALUES
   // ──────────────────────────────────────────────────────────────
   double              m_cachedADX;
   double              m_cachedDIPlus;
   double              m_cachedDIMinus;
   datetime            m_cacheTime;
   bool                m_cacheValid;
   int                 m_cacheExpirationSeconds;  // Cache TTL in seconds
   
   // ──────────────────────────────────────────────────────────────
   // PRIVATE METHODS
   // ──────────────────────────────────────────────────────────────
   bool UpdateCache();
   string GetDirectionInternal(double diPlus, double diMinus, double adx);
   double CalculateBullPercentageInternal(double diPlus, double diMinus);
   double CalculateBearPercentageInternal(double diPlus, double diMinus);
   double CalculateConfidenceInternal(double adx, double diPlus, double diMinus);
   double CalculateTrendStrengthInternal(double adx);
   double CalculateDirectionClarityInternal(double diPlus, double diMinus);
   string GetDescriptionInternal(double adx, double bullPct, double bearPct, string direction, double confidence);
   string GetNarrativeInternal(string direction, double adx, double bullPct, double bearPct, double confidence, double trendStrength);
   string GetTimeframeName(ENUM_TIMEFRAMES tf);
   bool EnsureIndicatorManagerInitialized();
   bool TryFallbackTimeframe();
   bool GetADXValuesDirect(double &adx, double &diPlus, double &diMinus);
   bool IsCacheFresh();
   
public:
   // ──────────────────────────────────────────────────────────────
   // CONSTRUCTOR / DESTRUCTOR
   // ──────────────────────────────────────────────────────────────
   CAdxModule();
   CAdxModule(CIndicatorManager* indicatorManager, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int period = 14);
   ~CAdxModule();
   
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   bool Initialize(CIndicatorManager* indicatorManager = NULL, string symbol = NULL, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int period = 14);
   void Deinitialize();
   bool IsInitialized() const { return m_initialized; }
   string GetLastError() const { return m_lastError; }
   
   // ──────────────────────────────────────────────────────────────
   // DATA ACCESS - Primary Methods
   // ──────────────────────────────────────────────────────────────
   bool GetADXValues(double &adx, double &diPlus, double &diMinus);
   double GetADXValue();
   double GetDIPlus();
   double GetDIMinus();
   double GetADXStrength();
   string GetADXDescription();
   
   // ──────────────────────────────────────────────────────────────
   // ENHANCED ANALYSIS METHODS
   // ──────────────────────────────────────────────────────────────
   SADXDirectionResult GetDirectionResult();
   string GetDirection();
   double GetBullPercentage();
   double GetBearPercentage();
   double GetConfidence();           // Uses improved calculation
   double GetTrendStrength();        // New: ADX-based trend strength
   double GetDirectionClarity();     // New: How clear the direction is
   string GetMarketNarrative();
   
   // ──────────────────────────────────────────────────────────────
   // SUMMARY METHODS
   // ──────────────────────────────────────────────────────────────
   SADXSummary GetADXSummary();
   string GetSummaryString();
   
   // ──────────────────────────────────────────────────────────────
   // UTILITY METHODS
   // ──────────────────────────────────────────────────────────────
   void SetTimeframe(ENUM_TIMEFRAMES tf);
   void SetPeriod(int period);
   void SetCacheExpiration(int seconds);
   void ClearCache();
   void Refresh();
   void SetDebug(bool enable);
   bool GetDebug() const { return m_debug; }
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   int GetPeriod() const { return m_adxPeriod; }
   void PrintStatus();
};

//+------------------------------------------------------------------+
//| Constructor - Default                                            |
//+------------------------------------------------------------------+
CAdxModule::CAdxModule()
{
   LOG_DEBUG("Default constructor called", g_adxDebugMode);
   
   m_indicatorManager = NULL;
   m_symbol = Symbol();
   m_timeframe = PERIOD_H1;
   m_adxPeriod = 14;
   m_initialized = false;
   m_ownsIndicatorManager = false;
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cacheExpirationSeconds = 5;  // Default: 5 second cache
   m_cachedADX = 0;
   m_cachedDIPlus = 0;
   m_cachedDIMinus = 0;
   m_lastError = "";
   m_initializing = false;
   m_debug = g_adxDebugMode;
   
   LOG_DEBUG("Default constructor completed - Symbol: " + m_symbol + ", Timeframe: H1, Cache Expiration: " + IntegerToString(m_cacheExpirationSeconds) + "s", g_adxDebugMode);
}

//+------------------------------------------------------------------+
//| Constructor - With IndicatorManager                              |
//+------------------------------------------------------------------+
CAdxModule::CAdxModule(CIndicatorManager* indicatorManager, string symbol = NULL, 
                       ENUM_TIMEFRAMES tf = PERIOD_CURRENT, int period = 14)
{
   LOG_DEBUG("Parameterized constructor called", g_adxDebugMode);
   
   string indicatorManagerStatus = (indicatorManager != NULL) ? "provided" : "NULL";
   string symbolStatus = (symbol != NULL) ? symbol : "default";
   string tfName = GetTimeframeName(tf);
   string periodStr = IntegerToString(period);
   
   LOG_DEBUG("  IndicatorManager: " + indicatorManagerStatus, g_adxDebugMode);
   LOG_DEBUG("  Symbol: " + symbolStatus, g_adxDebugMode);
   LOG_DEBUG("  Timeframe: " + tfName, g_adxDebugMode);
   LOG_DEBUG("  Period: " + periodStr, g_adxDebugMode);
   
   m_indicatorManager = indicatorManager;
   m_symbol = (symbol == NULL) ? Symbol() : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? PERIOD_H1 : tf;
   m_adxPeriod = period;
   m_initialized = false;
   m_ownsIndicatorManager = false;
   m_cacheValid = false;
   m_cacheTime = 0;
   m_cacheExpirationSeconds = 5;  // Default: 5 second cache
   m_cachedADX = 0;
   m_cachedDIPlus = 0;
   m_cachedDIMinus = 0;
   m_lastError = "";
   m_initializing = false;
   m_debug = false;
   
   LOG_DEBUG("Parameterized constructor completed - Symbol: " + m_symbol + ", Timeframe: " + GetTimeframeName(m_timeframe) + ", Cache Expiration: " + IntegerToString(m_cacheExpirationSeconds) + "s", g_adxDebugMode);
   
   if(m_indicatorManager != NULL)
   {
      LOG_DEBUG("IndicatorManager provided, calling Initialize...", g_adxDebugMode);
      Initialize(m_indicatorManager, m_symbol, m_timeframe, m_adxPeriod);
   }
   else
   {
      LOG_DEBUG("No IndicatorManager provided, will create on demand", g_adxDebugMode);
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CAdxModule::~CAdxModule()
{
   LOG_DEBUG("Destructor called", g_adxDebugMode);
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Set Timeframe                                                   |
//+------------------------------------------------------------------+
void CAdxModule::SetTimeframe(ENUM_TIMEFRAMES tf)
{
   LOG_DEBUG("Setting timeframe to " + GetTimeframeName(tf), g_adxDebugMode);
   m_timeframe = tf;
   m_cacheValid = false;
}

//+------------------------------------------------------------------+
//| Set Period                                                      |
//+------------------------------------------------------------------+
void CAdxModule::SetPeriod(int period)
{
   LOG_DEBUG("Setting ADX period to " + IntegerToString(period), g_adxDebugMode);
   m_adxPeriod = period;
   m_cacheValid = false;
}

//+------------------------------------------------------------------+
//| Set Cache Expiration                                            |
//+------------------------------------------------------------------+
void CAdxModule::SetCacheExpiration(int seconds)
{
   if(seconds < 1) seconds = 1;
   LOG_DEBUG("Setting cache expiration to " + IntegerToString(seconds) + " seconds", g_adxDebugMode);
   m_cacheExpirationSeconds = seconds;
}

//+------------------------------------------------------------------+
//| Clear Cache                                                     |
//+------------------------------------------------------------------+
void CAdxModule::ClearCache()
{
   LOG_DEBUG("Clearing cache", g_adxDebugMode);
   m_cacheValid = false;
}

//+------------------------------------------------------------------+
//| Refresh                                                         |
//+------------------------------------------------------------------+
void CAdxModule::Refresh()
{
   LOG_DEBUG("Refreshing ADX data", g_adxDebugMode);
   m_cacheValid = false;
   UpdateCache();
}

//+------------------------------------------------------------------+
//| Check if Cache is Fresh                                          |
//+------------------------------------------------------------------+
bool CAdxModule::IsCacheFresh()
{
   if(!m_cacheValid) return false;
   datetime age = TimeCurrent() - m_cacheTime;
   return (age < m_cacheExpirationSeconds);
}

//+------------------------------------------------------------------+
//| Ensure IndicatorManager is Initialized                          |
//+------------------------------------------------------------------+
bool CAdxModule::EnsureIndicatorManagerInitialized()
{
   LOG_DEBUG("Ensuring IndicatorManager is initialized...", g_adxDebugMode);
   
   if(m_indicatorManager != NULL && m_indicatorManager.IsInitialized())
   {
      LOG_DEBUG("IndicatorManager already initialized", g_adxDebugMode);
      return true;
   }
   
   if(m_indicatorManager == NULL)
   {
      LOG_DEBUG("IndicatorManager is NULL - creating new instance", g_adxDebugMode);
      m_indicatorManager = new CIndicatorManager();
      m_ownsIndicatorManager = true;
      
      LOG_DEBUG("Initializing IndicatorManager for symbol: " + m_symbol, g_adxDebugMode);
      
      if(!m_indicatorManager.Initialize(NULL, m_symbol))
      {
         m_lastError = "Failed to initialize IndicatorManager";
         LOG("Failed to initialize IndicatorManager", true);
         return false;
      }
      LOG_DEBUG("IndicatorManager initialized successfully", g_adxDebugMode);
   }
   
   if(!m_indicatorManager.IsInitialized())
   {
      LOG_DEBUG("IndicatorManager is not initialized - re-initializing", g_adxDebugMode);
      if(!m_indicatorManager.Initialize(NULL, m_symbol))
      {
         m_lastError = "Failed to re-initialize IndicatorManager";
         LOG("Failed to re-initialize IndicatorManager", true);
         return false;
      }
      LOG_DEBUG("IndicatorManager re-initialized successfully", g_adxDebugMode);
   }
   
   LOG_DEBUG("IndicatorManager is ready", g_adxDebugMode);
   return true;
}

//+------------------------------------------------------------------+
//| Try Fallback Timeframe                                          |
//+------------------------------------------------------------------+
bool CAdxModule::TryFallbackTimeframe()
{
   LOG_DEBUG("Attempting fallback timeframe...", g_adxDebugMode);
   
   ENUM_TIMEFRAMES fallbacks[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_M15, PERIOD_M30};
   string fallbackNames[];
   ArrayResize(fallbackNames, ArraySize(fallbacks));
   
   for(int i = 0; i < ArraySize(fallbacks); i++)
   {
      fallbackNames[i] = GetTimeframeName(fallbacks[i]);
   }
   
   string fallbackList = "";
   for(int i = 0; i < ArraySize(fallbackNames); i++)
   {
      if(i > 0) fallbackList += ", ";
      fallbackList += fallbackNames[i];
   }
   
   LOG_DEBUG("Fallback timeframes: " + fallbackList, g_adxDebugMode);
   
   for(int i = 0; i < ArraySize(fallbacks); i++)
   {
      if(fallbacks[i] == m_timeframe)
      {
         LOG_DEBUG("  Skipping current timeframe: " + GetTimeframeName(fallbacks[i]), g_adxDebugMode);
         continue;
      }
      
      LOG_DEBUG("  Trying fallback: " + GetTimeframeName(fallbacks[i]), g_adxDebugMode);
      
      double adx = 0;
      double diPlus = 0;
      double diMinus = 0;
      
      if(m_indicatorManager.GetADXValues(fallbacks[i], adx, diPlus, diMinus))
      {
         m_timeframe = fallbacks[i];
         
         LOG_INFO("✅ SUCCESS: Using fallback timeframe " + GetTimeframeName(m_timeframe), g_adxDebugMode);
         LOG_DEBUG("  ADX: " + DoubleToString(adx, 2) + ", +DI: " + DoubleToString(diPlus, 2) + ", -DI: " + DoubleToString(diMinus, 2), g_adxDebugMode);
         return true;
      }
      else
      {
         LOG_DEBUG("  ❌ Failed on " + GetTimeframeName(fallbacks[i]), g_adxDebugMode);
      }
   }
   
   LOG_WARNING("No timeframe with sufficient data found");
   return false;
}

//+------------------------------------------------------------------+
//| Get ADX Values Direct - No recursion, for initialization only   |
//+------------------------------------------------------------------+
bool CAdxModule::GetADXValuesDirect(double &adx, double &diPlus, double &diMinus)
{
   LOG_DEBUG("Getting ADX values directly (for initialization)...", g_adxDebugMode);
   
   adx = 0;
   diPlus = 0;
   diMinus = 0;
   
   if(m_indicatorManager == NULL)
   {
      LOG("IndicatorManager is NULL", true);
      return false;
   }
   
   bool result = m_indicatorManager.GetADXValues(m_timeframe, adx, diPlus, diMinus);
   
   if(result)
   {
      LOG_DEBUG("  Direct ADX: " + DoubleToString(adx, 2) + ", +DI: " + DoubleToString(diPlus, 2) + ", -DI: " + DoubleToString(diMinus, 2), g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("  ❌ Failed to get ADX values directly", g_adxDebugMode);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CAdxModule::Initialize(CIndicatorManager* indicatorManager = NULL, 
                           string symbol = NULL, 
                           ENUM_TIMEFRAMES tf = PERIOD_CURRENT, 
                           int period = 14)
{
   LOG_INFO("=== INITIALIZATION START ===", g_adxDebugMode);
   
   if(m_initializing)
   {
      LOG_DEBUG("Already initializing, skipping...", g_adxDebugMode);
      return false;
   }
   
   m_initializing = true;
   m_lastError = "";
   
   if(symbol != NULL && symbol != "")
   {
      m_symbol = symbol;
      LOG_DEBUG("Symbol set to: " + m_symbol, g_adxDebugMode);
   }
   else if(m_symbol == "")
   {
      m_symbol = Symbol();
      LOG_DEBUG("Symbol defaulted to: " + m_symbol, g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("Using existing symbol: " + m_symbol, g_adxDebugMode);
   }
   
   if(tf != PERIOD_CURRENT)
   {
      m_timeframe = tf;
      LOG_DEBUG("Timeframe set to: " + GetTimeframeName(m_timeframe), g_adxDebugMode);
   }
   else
   {
      m_timeframe = PERIOD_H1;
      LOG_DEBUG("Timeframe defaulted to: H1", g_adxDebugMode);
   }
   
   if(period > 0)
   {
      m_adxPeriod = period;
      LOG_DEBUG("ADX Period set to: " + IntegerToString(m_adxPeriod), g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("Using existing period: " + IntegerToString(m_adxPeriod), g_adxDebugMode);
   }
   
   if(indicatorManager != NULL)
   {
      m_indicatorManager = indicatorManager;
      LOG_DEBUG("Using provided IndicatorManager", g_adxDebugMode);
   }
   else if(m_indicatorManager == NULL)
   {
      LOG_DEBUG("Creating new IndicatorManager...", g_adxDebugMode);
      m_indicatorManager = new CIndicatorManager();
      m_ownsIndicatorManager = true;
      
      LOG_DEBUG("Initializing new IndicatorManager for symbol: " + m_symbol, g_adxDebugMode);
      
      if(!m_indicatorManager.Initialize(NULL, m_symbol))
      {
         m_lastError = "Failed to initialize IndicatorManager";
         LOG("Failed to initialize IndicatorManager", true);
         m_initializing = false;
         Deinitialize();
         return false;
      }
      LOG_DEBUG("✅ IndicatorManager initialized", g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("Using existing IndicatorManager", g_adxDebugMode);
   }
   
   if(!m_indicatorManager.IsInitialized())
   {
      m_lastError = "IndicatorManager is not initialized";
      LOG("IndicatorManager is not initialized", true);
      m_initializing = false;
      Deinitialize();
      return false;
   }
   
   int barsAvailable = iBars(m_symbol, m_timeframe);
   LOG_DEBUG("Data availability: " + IntegerToString(barsAvailable) + " bars on " + m_symbol + " " + GetTimeframeName(m_timeframe), g_adxDebugMode);
   
   if(barsAvailable < 20)
   {
      LOG_WARNING("⚠️ Insufficient data on " + GetTimeframeName(m_timeframe) + " (only " + IntegerToString(barsAvailable) + " bars)");
      LOG_DEBUG("Trying fallback timeframes...", g_adxDebugMode);
      if(!TryFallbackTimeframe())
      {
         m_lastError = "No timeframe with sufficient data found";
         LOG("No timeframe with sufficient data found", true);
         m_initializing = false;
         Deinitialize();
         return false;
      }
      LOG_DEBUG("✅ Fallback successful: using " + GetTimeframeName(m_timeframe), g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("✅ Sufficient data available on " + GetTimeframeName(m_timeframe), g_adxDebugMode);
   }
   
   LOG_DEBUG("Testing ADX values...", g_adxDebugMode);
   double adx = 0;
   double diPlus = 0;
   double diMinus = 0;
   bool success = false;
   int maxRetries = 3;
   
   for(int retry = 0; retry < maxRetries; retry++)
   {
      LOG_DEBUG("  Attempt " + IntegerToString(retry + 1) + " of " + IntegerToString(maxRetries), g_adxDebugMode);
      
      if(GetADXValuesDirect(adx, diPlus, diMinus))
      {
         success = true;
         LOG_DEBUG("  ✅ ADX test successful on attempt " + IntegerToString(retry + 1), g_adxDebugMode);
         break;
      }
      
      if(retry < maxRetries - 1)
      {
         LOG_DEBUG("  ⚠️ Retry " + IntegerToString(retry + 1) + " failed, waiting 100ms...", g_adxDebugMode);
         Sleep(100);
      }
   }
   
   m_initializing = false;
   
   if(!success)
   {
      m_lastError = "Failed to get ADX values - check symbol and timeframe";
      LOG("Failed to get ADX values - Symbol: " + m_symbol + ", Timeframe: " + GetTimeframeName(m_timeframe) + ", Period: " + IntegerToString(m_adxPeriod), true);
      Deinitialize();
      return false;
   }
   
   m_initialized = true;
   m_cacheValid = false;
   
   LOG_INFO("✅ INITIALIZATION COMPLETE", g_adxDebugMode);
   LOG_DEBUG("  Symbol: " + m_symbol, g_adxDebugMode);
   LOG_DEBUG("  Timeframe: " + GetTimeframeName(m_timeframe), g_adxDebugMode);
   LOG_DEBUG("  ADX Period: " + IntegerToString(m_adxPeriod), g_adxDebugMode);
   LOG_DEBUG("  Initial ADX: " + DoubleToString(adx, 2), g_adxDebugMode);
   LOG_DEBUG("  Initial +DI: " + DoubleToString(diPlus, 2), g_adxDebugMode);
   LOG_DEBUG("  Initial -DI: " + DoubleToString(diMinus, 2), g_adxDebugMode);
   LOG_INFO("=== END INITIALIZATION ===", g_adxDebugMode);
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CAdxModule::Deinitialize()
{
   LOG_DEBUG("Deinitializing...", g_adxDebugMode);
   
   if(m_ownsIndicatorManager && m_indicatorManager != NULL)
   {
      LOG_DEBUG("Deleting owned IndicatorManager", g_adxDebugMode);
      delete m_indicatorManager;
      m_indicatorManager = NULL;
   }
   else if(m_indicatorManager != NULL)
   {
      LOG_DEBUG("Not deleting external IndicatorManager", g_adxDebugMode);
   }
   
   m_initialized = false;
   m_cacheValid = false;
   
   LOG_DEBUG("Deinitialization complete", g_adxDebugMode);
}

//+------------------------------------------------------------------+
//| Update Cache - Gets fresh ADX values                            |
//+------------------------------------------------------------------+
bool CAdxModule::UpdateCache()
{
   LOG_DEBUG("Updating cache...", g_adxDebugMode);
   
   if(!m_initialized)
   {
      LOG_DEBUG("Not initialized, attempting initialization...", g_adxDebugMode);
      if(!m_initializing)
      {
         if(!EnsureIndicatorManagerInitialized())
         {
            LOG("Cannot update cache - IndicatorManager not ready", true);
            return false;
         }
         
         if(!Initialize(m_indicatorManager, m_symbol, m_timeframe, m_adxPeriod))
         {
            LOG("Cannot update cache - initialization failed", true);
            return false;
         }
      }
      else
      {
         LOG_DEBUG("Already initializing, skipping cache update", g_adxDebugMode);
         return false;
      }
   }
   
   if(m_indicatorManager == NULL)
   {
      LOG("IndicatorManager is NULL", true);
      return false;
   }
   
   double adx = 0;
   double plusDI = 0;
   double minusDI = 0;
   
   LOG_DEBUG("Fetching ADX values from IndicatorManager...", g_adxDebugMode);
   
   if(!m_indicatorManager.GetADXValues(m_timeframe, adx, plusDI, minusDI))
   {
      LOG_DEBUG("❌ Failed to get ADX values, trying fallback...", g_adxDebugMode);
      
      if(!TryFallbackTimeframe())
      {
         m_lastError = "Failed to get ADX values from IndicatorManager";
         LOG("Failed to get ADX values from IndicatorManager", true);
         return false;
      }
      
      LOG_DEBUG("Retrying ADX values on fallback timeframe...", g_adxDebugMode);
      if(!m_indicatorManager.GetADXValues(m_timeframe, adx, plusDI, minusDI))
      {
         m_lastError = "Failed to get ADX values from IndicatorManager after fallback";
         LOG("Failed to get ADX values from IndicatorManager after fallback", true);
         return false;
      }
   }
   
   if(adx < 0 || plusDI < 0 || minusDI < 0)
   {
      m_lastError = "Invalid ADX values: ADX=" + DoubleToString(adx, 2) + ", +DI=" + DoubleToString(plusDI, 2) + ", -DI=" + DoubleToString(minusDI, 2);
      LOG("Invalid ADX values", true);
      return false;
   }
   
   m_cachedADX = adx;
   m_cachedDIPlus = plusDI;
   m_cachedDIMinus = minusDI;
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
   
   LOG_DEBUG("✅ Cache updated: ADX=" + DoubleToString(adx, 2) + ", +DI=" + DoubleToString(plusDI, 2) + ", -DI=" + DoubleToString(minusDI, 2) + " (age: 0s)", g_adxDebugMode);
   
   return true;
}

//+------------------------------------------------------------------+
//| Get ADX Values - Primary method                                  |
//| FIXED: Proper cache expiration logic                             |
//+------------------------------------------------------------------+
bool CAdxModule::GetADXValues(double &adx, double &diPlus, double &diMinus)
{
   LOG_DEBUG("Getting ADX values...", g_adxDebugMode);
   
   adx = 0;
   diPlus = 0;
   diMinus = 0;
   
   if(!m_initialized)
   {
      LOG_DEBUG("Not initialized, attempting initialization...", g_adxDebugMode);
      if(!m_initializing)
      {
         if(!EnsureIndicatorManagerInitialized())
         {
            LOG("Cannot get ADX values - IndicatorManager not ready", true);
            return false;
         }
         
         if(!Initialize(m_indicatorManager, m_symbol, m_timeframe, m_adxPeriod))
         {
            LOG("Cannot get ADX values - initialization failed", true);
            return false;
         }
      }
      else
      {
         LOG_DEBUG("Already initializing, returning false", g_adxDebugMode);
         return false;
      }
   }
   
   if(m_indicatorManager == NULL)
   {
      LOG("IndicatorManager is NULL", true);
      return false;
   }
   
   // ============================================================
   // FIX: Check if cache is valid AND fresh (not just valid)
   // ============================================================
   if(IsCacheFresh())
   {
      datetime age = TimeCurrent() - m_cacheTime;
      LOG_DEBUG("Using fresh cached values (age: " + IntegerToString(age) + "s)", g_adxDebugMode);
      adx = m_cachedADX;
      diPlus = m_cachedDIPlus;
      diMinus = m_cachedDIMinus;
      return true;
   }
   
   // Cache is stale or invalid - refresh it
   if(m_cacheValid)
   {
      datetime age = TimeCurrent() - m_cacheTime;
      LOG_DEBUG("Cache expired (age: " + IntegerToString(age) + "s, TTL: " + IntegerToString(m_cacheExpirationSeconds) + "s) - refreshing...", g_adxDebugMode);
   }
   else
   {
      LOG_DEBUG("No valid cache - fetching fresh values...", g_adxDebugMode);
   }
   
   // Fetch fresh values from IndicatorManager
   if(!m_indicatorManager.GetADXValues(m_timeframe, adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get ADX values, trying fallback...", g_adxDebugMode);
      if(!TryFallbackTimeframe())
      {
         LOG("Failed to get ADX values after fallback attempt", true);
         return false;
      }
      
      LOG_DEBUG("Retrying ADX values on fallback timeframe...", g_adxDebugMode);
      if(!m_indicatorManager.GetADXValues(m_timeframe, adx, diPlus, diMinus))
      {
         LOG("Failed to get ADX values after fallback attempt", true);
         return false;
      }
   }
   
   // Update cache with fresh values
   m_cachedADX = adx;
   m_cachedDIPlus = diPlus;
   m_cachedDIMinus = diMinus;
   m_cacheTime = TimeCurrent();
   m_cacheValid = true;
   
   LOG_DEBUG("✅ ADX values retrieved and cached: ADX=" + DoubleToString(adx, 2) + ", +DI=" + DoubleToString(diPlus, 2) + ", -DI=" + DoubleToString(diMinus, 2), g_adxDebugMode);
   
   return true;
}

//+------------------------------------------------------------------+
//| Get ADX Value                                                   |
//+------------------------------------------------------------------+
double CAdxModule::GetADXValue()
{
   LOG_DEBUG("Getting ADX value...", g_adxDebugMode);
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get ADX value, returning 0", g_adxDebugMode);
      return 0;
   }
   LOG_DEBUG("ADX: " + DoubleToString(adx, 2), g_adxDebugMode);
   return adx;
}

//+------------------------------------------------------------------+
//| Get DI+                                                         |
//+------------------------------------------------------------------+
double CAdxModule::GetDIPlus()
{
   LOG_DEBUG("Getting +DI value...", g_adxDebugMode);
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get +DI value, returning 0", g_adxDebugMode);
      return 0;
   }
   LOG_DEBUG("+DI: " + DoubleToString(diPlus, 2), g_adxDebugMode);
   return diPlus;
}

//+------------------------------------------------------------------+
//| Get DI-                                                         |
//+------------------------------------------------------------------+
double CAdxModule::GetDIMinus()
{
   LOG_DEBUG("Getting -DI value...", g_adxDebugMode);
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get -DI value, returning 0", g_adxDebugMode);
      return 0;
   }
   LOG_DEBUG("-DI: " + DoubleToString(diMinus, 2), g_adxDebugMode);
   return diMinus;
}

//+------------------------------------------------------------------+
//| Get ADX Strength (0-100)                                        |
//+------------------------------------------------------------------+
double CAdxModule::GetADXStrength()
{
   double adx = GetADXValue();
   if(adx <= 0) 
   {
      LOG_DEBUG("ADX <= 0, returning 0 strength", g_adxDebugMode);
      return 0;
   }
   double strength = MathMin(adx / 40.0, 1.0) * 100;
   LOG_DEBUG("ADX Strength: " + DoubleToString(strength, 1) + "%", g_adxDebugMode);
   return strength;
}

//+------------------------------------------------------------------+
//| Get Trend Strength - New: ADX-based trend strength (0-100)      |
//+------------------------------------------------------------------+
double CAdxModule::GetTrendStrength()
{
   double adx = GetADXValue();
   double strength = CalculateTrendStrengthInternal(adx);
   LOG_DEBUG("Trend Strength: " + DoubleToString(strength, 1) + "%", g_adxDebugMode);
   return strength;
}

//+------------------------------------------------------------------+
//| Calculate Trend Strength Internal                                |
//+------------------------------------------------------------------+
double CAdxModule::CalculateTrendStrengthInternal(double adx)
{
   if(adx <= 0) return 0;
   
   // ADX ranges:
   // 0-15: No trend
   // 15-20: Weak trend
   // 20-25: Moderate trend
   // 25-40: Strong trend
   // 40+: Very strong trend
   
   if(adx >= 40) return 100.0;
   if(adx >= 25) return 75.0 + ((adx - 25) / 15.0) * 25.0;  // 75-100
   if(adx >= 20) return 50.0 + ((adx - 20) / 5.0) * 25.0;   // 50-75
   if(adx >= 15) return 25.0 + ((adx - 15) / 5.0) * 25.0;   // 25-50
   return (adx / 15.0) * 25.0;  // 0-25
}

//+------------------------------------------------------------------+
//| Get Direction Clarity - New: How clear the direction is (0-100) |
//+------------------------------------------------------------------+
double CAdxModule::GetDirectionClarity()
{
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("Failed to get ADX values for direction clarity", g_adxDebugMode);
      return 0;
   }
   double clarity = CalculateDirectionClarityInternal(diPlus, diMinus);
   LOG_DEBUG("Direction Clarity: " + DoubleToString(clarity, 1) + "%", g_adxDebugMode);
   return clarity;
}

//+------------------------------------------------------------------+
//| Calculate Direction Clarity Internal                             |
//+------------------------------------------------------------------+
double CAdxModule::CalculateDirectionClarityInternal(double diPlus, double diMinus)
{
   double totalDI = diPlus + diMinus;
   if(totalDI <= 0) return 0;
   
   // How far apart are the DI lines? (0-100)
   double clarity = MathAbs(diPlus - diMinus) / totalDI * 100.0;
   return MathMin(100.0, clarity);
}

//+------------------------------------------------------------------+
//| Calculate Confidence - IMPROVED: Accounts for ADX strength      |
//+------------------------------------------------------------------+
double CAdxModule::CalculateConfidenceInternal(double adx, double diPlus, double diMinus)
{
   LOG_DEBUG("Calculating improved confidence...", g_adxDebugMode);
   
   // 1. Direction Clarity (0-100) - how clear is the direction?
   double directionClarity = CalculateDirectionClarityInternal(diPlus, diMinus);
   
   // 2. Trend Strength (0-100) - from ADX
   double trendStrength = CalculateTrendStrengthInternal(adx);
   
   // 3. Calculate confidence using weighted combination
   // When trend is strong, direction clarity matters more
   // When trend is weak, confidence should be low regardless
   double confidence = 0;
   
   if(trendStrength >= 75)  // Very strong trend (ADX >= 40)
   {
      // Strong trend: direction clarity is very reliable
      confidence = (directionClarity * 0.7) + (trendStrength * 0.3);
   }
   else if(trendStrength >= 50)  // Strong trend (ADX >= 25)
   {
      // Moderate to strong trend: balanced weighting
      confidence = (directionClarity * 0.6) + (trendStrength * 0.4);
   }
   else if(trendStrength >= 25)  // Weak to moderate trend (ADX >= 15)
   {
      // Weak trend: trend strength is less reliable
      confidence = (directionClarity * 0.4) + (trendStrength * 0.6);
   }
   else  // No trend (ADX < 15)
   {
      // No trend: confidence should be very low
      confidence = (directionClarity * 0.3) + (trendStrength * 0.7);
   }
   
   // 4. Cap confidence if trend is too weak
   if(trendStrength < 25 && confidence > 30)
   {
      confidence = 30.0;  // Max 30% when no trend
   }
   else if(trendStrength < 50 && confidence > 60)
   {
      confidence = MathMin(60.0, confidence);  // Cap at 60% for weak trends
   }
   
   // 5. Minimum confidence if there's any direction
   if(directionClarity > 0 && confidence < 5)
   {
      confidence = 5.0;
   }
   
   double result = MathMin(100.0, confidence);
   
   LOG_DEBUG("  Confidence: Direction Clarity=" + DoubleToString(directionClarity, 1) + "%, Trend Strength=" + DoubleToString(trendStrength, 1) + "% → Confidence=" + DoubleToString(result, 1) + "%", g_adxDebugMode);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Confidence - Public method                                   |
//+------------------------------------------------------------------+
double CAdxModule::GetConfidence()
{
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("Failed to get ADX values for confidence", g_adxDebugMode);
      return 0;
   }
   double confidence = CalculateConfidenceInternal(adx, diPlus, diMinus);
   LOG_DEBUG("Confidence: " + DoubleToString(confidence, 1) + "%", g_adxDebugMode);
   return confidence;
}

//+------------------------------------------------------------------+
//| Get ADX Description                                             |
//+------------------------------------------------------------------+
string CAdxModule::GetADXDescription()
{
   double adx = GetADXValue();
   string desc;
   if(adx >= 40) desc = "Very Strong Trend";
   else if(adx >= 25) desc = "Strong Trend";
   else if(adx >= 20) desc = "Moderate Trend";
   else if(adx >= 15) desc = "Weak Trend";
   else desc = "No Trend";
   LOG_DEBUG("ADX Description: " + desc + " (ADX: " + DoubleToString(adx, 2) + ")", g_adxDebugMode);
   return desc;
}

//+------------------------------------------------------------------+
//| Get Direction (Bull, Bear, or Neutral)                          |
//+------------------------------------------------------------------+
string CAdxModule::GetDirection()
{
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get ADX values, returning NEUTRAL", g_adxDebugMode);
      return "NEUTRAL";
   }
   
   string direction = GetDirectionInternal(diPlus, diMinus, adx);
   LOG_DEBUG("Direction: " + direction + " (ADX=" + DoubleToString(adx, 2) + ", +DI=" + DoubleToString(diPlus, 2) + ", -DI=" + DoubleToString(diMinus, 2) + ")", g_adxDebugMode);
   return direction;
}

//+------------------------------------------------------------------+
//| Get Direction Internal                                           |
//+------------------------------------------------------------------+
string CAdxModule::GetDirectionInternal(double diPlus, double diMinus, double adx)
{
   LOG_DEBUG("Calculating direction: ADX=" + DoubleToString(adx, 2) + ", +DI=" + DoubleToString(diPlus, 2) + ", -DI=" + DoubleToString(diMinus, 2), g_adxDebugMode);
   
   if(adx < 20) 
   {
      LOG_DEBUG("  ADX < 20 → NEUTRAL (trend too weak)", g_adxDebugMode);
      return "NEUTRAL";
   }
   
   if(diPlus > diMinus && diPlus - diMinus > 0.5) 
   {
      LOG_DEBUG("  +DI > -DI by " + DoubleToString(diPlus - diMinus, 2) + " → BULLISH", g_adxDebugMode);
      return "BULLISH";
   }
   
   if(diMinus > diPlus && diMinus - diPlus > 0.5) 
   {
      LOG_DEBUG("  -DI > +DI by " + DoubleToString(diMinus - diPlus, 2) + " → BEARISH", g_adxDebugMode);
      return "BEARISH";
   }
   
   LOG_DEBUG("  No clear direction → NEUTRAL", g_adxDebugMode);
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get Bull Percentage                                             |
//+------------------------------------------------------------------+
double CAdxModule::GetBullPercentage()
{
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get ADX values, returning 50%", g_adxDebugMode);
      return 50.0;
   }
   
   double bullPct = CalculateBullPercentageInternal(diPlus, diMinus);
   LOG_DEBUG("Bull Percentage: " + DoubleToString(bullPct, 1) + "%", g_adxDebugMode);
   return bullPct;
}

//+------------------------------------------------------------------+
//| Get Bear Percentage                                             |
//+------------------------------------------------------------------+
double CAdxModule::GetBearPercentage()
{
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG_DEBUG("❌ Failed to get ADX values, returning 50%", g_adxDebugMode);
      return 50.0;
   }
   
   double bearPct = CalculateBearPercentageInternal(diPlus, diMinus);
   LOG_DEBUG("Bear Percentage: " + DoubleToString(bearPct, 1) + "%", g_adxDebugMode);
   return bearPct;
}

//+------------------------------------------------------------------+
//| Calculate Bullish Percentage                                    |
//+------------------------------------------------------------------+
double CAdxModule::CalculateBullPercentageInternal(double diPlus, double diMinus)
{
   if(diPlus + diMinus <= 0) 
   {
      LOG_DEBUG("  diPlus+diMinus <= 0, returning 50%", g_adxDebugMode);
      return 50.0;
   }
   double ratio = diPlus / (diPlus + diMinus);
   double result = MathMin(100.0, ratio * 100.0);
   LOG_DEBUG("  Bull% calculation: " + DoubleToString(diPlus, 2) + " / (" + DoubleToString(diPlus, 2) + " + " + DoubleToString(diMinus, 2) + ") = " + DoubleToString(result, 1) + "%", g_adxDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Calculate Bearish Percentage                                    |
//+------------------------------------------------------------------+
double CAdxModule::CalculateBearPercentageInternal(double diPlus, double diMinus)
{
   if(diPlus + diMinus <= 0) 
   {
      LOG_DEBUG("  diPlus+diMinus <= 0, returning 50%", g_adxDebugMode);
      return 50.0;
   }
   double ratio = diMinus / (diPlus + diMinus);
   double result = MathMin(100.0, ratio * 100.0);
   LOG_DEBUG("  Bear% calculation: " + DoubleToString(diMinus, 2) + " / (" + DoubleToString(diPlus, 2) + " + " + DoubleToString(diMinus, 2) + ") = " + DoubleToString(result, 1) + "%", g_adxDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Description - Updated with confidence                       |
//+------------------------------------------------------------------+
string CAdxModule::GetDescriptionInternal(double adx, double bullPct, double bearPct, string direction, double confidence)
{
   LOG_DEBUG("Generating description...", g_adxDebugMode);
   
   string strengthDesc;
   if(adx >= 40) strengthDesc = "Very Strong";
   else if(adx >= 25) strengthDesc = "Strong";
   else if(adx >= 20) strengthDesc = "Moderate";
   else if(adx >= 15) strengthDesc = "Weak";
   else strengthDesc = "No Trend";
   
   string dirDesc = "";
   if(direction == "BULLISH")
   {
      if(confidence >= 60) dirDesc = "Strong Bullish";
      else if(confidence >= 40) dirDesc = "Moderate Bullish";
      else dirDesc = "Weak Bullish";
   }
   else if(direction == "BEARISH")
   {
      if(confidence >= 60) dirDesc = "Strong Bearish";
      else if(confidence >= 40) dirDesc = "Moderate Bearish";
      else dirDesc = "Weak Bearish";
   }
   else
   {
      dirDesc = "Neutral / Sideways";
   }
   
   string result = strengthDesc + " - " + dirDesc + " (Confidence: " + DoubleToString(confidence, 1) + "%)";
   LOG_DEBUG("  Description: " + result, g_adxDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Get Narrative - Updated with trend strength                    |
//+------------------------------------------------------------------+
string CAdxModule::GetNarrativeInternal(string direction, double adx, double bullPct, double bearPct, double confidence, double trendStrength)
{
   LOG_DEBUG("Generating narrative...", g_adxDebugMode);
   string narrative = "";
   
   string strengthLevel;
   if(trendStrength >= 75) strengthLevel = "very strong";
   else if(trendStrength >= 50) strengthLevel = "strong";
   else if(trendStrength >= 25) strengthLevel = "moderate";
   else strengthLevel = "weak";
   
   if(direction == "BULLISH")
   {
      if(confidence >= 60)
      {
         narrative = "✅ Strong bullish signal with " + strengthLevel + " conviction. Buyers are firmly in control with high confidence in the upward move.";
      }
      else if(confidence >= 40)
      {
         narrative = "📈 Moderate bullish signal with " + strengthLevel + " conviction. Buyers are gaining traction but some caution is warranted.";
      }
      else
      {
         narrative = "📊 Weak bullish bias with " + strengthLevel + " conviction. Market may be consolidating or lacks clear direction.";
      }
   }
   else if(direction == "BEARISH")
   {
      if(confidence >= 60)
      {
         narrative = "✅ Strong bearish signal with " + strengthLevel + " conviction. Sellers are firmly in control with high confidence in the downward move.";
      }
      else if(confidence >= 40)
      {
         narrative = "📉 Moderate bearish signal with " + strengthLevel + " conviction. Sellers are gaining traction but some caution is warranted.";
      }
      else
      {
         narrative = "📊 Weak bearish bias with " + strengthLevel + " conviction. Market may be consolidating or lacks clear direction.";
      }
   }
   else
   {
      narrative = "➡️ Market is in a neutral/sideways phase with " + strengthLevel + " trend strength. ";
      
      if(adx < 15)
         narrative += "ADX indicates very low trend strength. Expect range-bound movement.";
      else if(adx < 20)
         narrative += "Weak trend signals. Price may break out soon but direction is unclear.";
      else
         narrative += "Mixed signals. Wait for clearer direction with stronger confidence.";
   }
   
   narrative += " (Bulls: " + DoubleToString(bullPct, 1) + "%, Bears: " + DoubleToString(bearPct, 1) + "%, Confidence: " + DoubleToString(confidence, 1) + "%, Trend Strength: " + DoubleToString(trendStrength, 1) + "%)";
   
   LOG_DEBUG("  Narrative: " + narrative, g_adxDebugMode);
   return narrative;
}

//+------------------------------------------------------------------+
//| Get Direction Result - Complete Analysis with improved metrics |
//+------------------------------------------------------------------+
SADXDirectionResult CAdxModule::GetDirectionResult()
{
   LOG_DEBUG("Getting complete direction result...", g_adxDebugMode);
   
   SADXDirectionResult result;
   ZeroMemory(result);
   result.isValid = false;
   
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG("Failed to get ADX values for direction result", true);
      return result;
   }
   
   result.adxValue = adx;
   result.diPlus = diPlus;
   result.diMinus = diMinus;
   
   result.bullPercentage = CalculateBullPercentageInternal(diPlus, diMinus);
   result.bearPercentage = CalculateBearPercentageInternal(diPlus, diMinus);
   
   double total = result.bullPercentage + result.bearPercentage;
   if(total > 0)
   {
      result.bullPercentage = (result.bullPercentage / total) * 100.0;
      result.bearPercentage = (result.bearPercentage / total) * 100.0;
   }
   else
   {
      result.bullPercentage = 50.0;
      result.bearPercentage = 50.0;
   }
   
   // Calculate trend strength and direction clarity
   result.trendStrength = CalculateTrendStrengthInternal(adx);
   result.directionClarity = CalculateDirectionClarityInternal(diPlus, diMinus);
   
   // Calculate improved confidence
   result.confidence = CalculateConfidenceInternal(adx, diPlus, diMinus);
   
   result.direction = GetDirectionInternal(diPlus, diMinus, adx);
   result.description = GetDescriptionInternal(adx, result.bullPercentage, result.bearPercentage, 
                                               result.direction, result.confidence);
   result.narrative = GetNarrativeInternal(result.direction, adx, result.bullPercentage, 
                                          result.bearPercentage, result.confidence, 
                                          result.trendStrength);
   
   result.isValid = true;
   
   LOG_DEBUG("Direction result complete: " + result.direction + " (ADX=" + DoubleToString(adx, 2) + ")", g_adxDebugMode);
   LOG_DEBUG("  Bulls: " + DoubleToString(result.bullPercentage, 1) + "%, Bears: " + DoubleToString(result.bearPercentage, 1) + "%, Confidence: " + DoubleToString(result.confidence, 1) + "%, Trend Strength: " + DoubleToString(result.trendStrength, 1) + "%, Direction Clarity: " + DoubleToString(result.directionClarity, 1) + "%", g_adxDebugMode);
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Market Narrative                                             |
//+------------------------------------------------------------------+
string CAdxModule::GetMarketNarrative()
{
   LOG_DEBUG("Getting market narrative...", g_adxDebugMode);
   SADXDirectionResult result = GetDirectionResult();
   if(!result.isValid)
   {
      LOG("Unable to get ADX analysis", true);
      return "Unable to get ADX analysis";
   }
   LOG_DEBUG("Market narrative: " + result.narrative, g_adxDebugMode);
   return result.narrative;
}

//+------------------------------------------------------------------+
//| Get ADX Summary - Returns bull%, bear%, ADX value and description|
//+------------------------------------------------------------------+
SADXSummary CAdxModule::GetADXSummary()
{
   LOG_DEBUG("Getting ADX summary...", g_adxDebugMode);
   
   SADXSummary summary;
   ZeroMemory(summary);
   summary.isValid = false;
   
   double adx, diPlus, diMinus;
   if(!GetADXValues(adx, diPlus, diMinus))
   {
      LOG("Failed to get ADX values for summary", true);
      return summary;
   }
   
   summary.adxValue = adx;
   summary.bullPercentage = CalculateBullPercentageInternal(diPlus, diMinus);
   summary.bearPercentage = CalculateBearPercentageInternal(diPlus, diMinus);
   
   double total = summary.bullPercentage + summary.bearPercentage;
   if(total > 0)
   {
      summary.bullPercentage = (summary.bullPercentage / total) * 100.0;
      summary.bearPercentage = (summary.bearPercentage / total) * 100.0;
   }
   else
   {
      summary.bullPercentage = 50.0;
      summary.bearPercentage = 50.0;
   }
   
   // Calculate improved metrics
   summary.trendStrength = CalculateTrendStrengthInternal(adx);
   summary.confidence = CalculateConfidenceInternal(adx, diPlus, diMinus);
   
   string direction = GetDirectionInternal(diPlus, diMinus, adx);
   string strengthDesc;
   
   if(adx >= 40) strengthDesc = "Very Strong";
   else if(adx >= 25) strengthDesc = "Strong";
   else if(adx >= 20) strengthDesc = "Moderate";
   else if(adx >= 15) strengthDesc = "Weak";
   else strengthDesc = "No Trend";
   
   string dirDesc = "";
   if(direction == "BULLISH")
   {
      if(summary.confidence >= 60) dirDesc = "Strong Bullish";
      else if(summary.confidence >= 40) dirDesc = "Moderate Bullish";
      else dirDesc = "Weak Bullish";
   }
   else if(direction == "BEARISH")
   {
      if(summary.confidence >= 60) dirDesc = "Strong Bearish";
      else if(summary.confidence >= 40) dirDesc = "Moderate Bearish";
      else dirDesc = "Weak Bearish";
   }
   else
   {
      dirDesc = "Neutral";
   }
   
   summary.description = strengthDesc + " " + dirDesc + " (ADX: " + DoubleToString(adx, 1) + ", Conf: " + DoubleToString(summary.confidence, 1) + "%)";
   summary.isValid = true;
   
   LOG_DEBUG("Summary: " + summary.description + " | Bulls: " + DoubleToString(summary.bullPercentage, 1) + "% | Bears: " + DoubleToString(summary.bearPercentage, 1) + "%", g_adxDebugMode);
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Summary String                                              |
//+------------------------------------------------------------------+
string CAdxModule::GetSummaryString()
{
   LOG_DEBUG("Getting summary string...", g_adxDebugMode);
   SADXSummary summary = GetADXSummary();
   if(!summary.isValid)
   {
      LOG_DEBUG("  Summary invalid, returning N/A", g_adxDebugMode);
      return "ADX: N/A";
   }
   
   string direction = "";
   if(summary.bullPercentage > summary.bearPercentage)
      direction = "📈 BULLISH";
   else if(summary.bearPercentage > summary.bullPercentage)
      direction = "📉 BEARISH";
   else
      direction = "➡️ NEUTRAL";
   
   string result = "ADX: " + DoubleToString(summary.adxValue, 1) + " | " + direction + " | Bulls: " + DoubleToString(summary.bullPercentage, 0) + "% | Bears: " + DoubleToString(summary.bearPercentage, 0) + "% | Conf: " + DoubleToString(summary.confidence, 0) + "%";
   
   LOG_DEBUG("  Summary: " + result, g_adxDebugMode);
   return result;
}

//+------------------------------------------------------------------+
//| Set Debug - Controls logging                                     |
//+------------------------------------------------------------------+
void CAdxModule::SetDebug(bool enable)
{
   LOG_DEBUG("Setting debug mode to: " + (enable ? "ON" : "OFF"), g_adxDebugMode);
   m_debug = enable;
   
   if(m_indicatorManager != NULL)
   {
      LOG_DEBUG("Updating IndicatorManager debug mode", g_adxDebugMode);
      m_indicatorManager.SetDebug(enable);
   }
   
   LOG_INFO("Debug mode " + (enable ? "ENABLED" : "DISABLED"), g_adxDebugMode);
}

//+------------------------------------------------------------------+
//| Print Status                                                    |
//+------------------------------------------------------------------+
void CAdxModule::PrintStatus()
{
   string separator = "=== ";
   string indent = "   ";
   
   Print(separator + "CAdxModule STATUS " + separator);
   Print(indent + "Symbol: " + m_symbol);
   Print(indent + "Timeframe: " + GetTimeframeName(m_timeframe));
   Print(indent + "ADX Period: " + IntegerToString(m_adxPeriod));
   Print(indent + "Initialized: " + (m_initialized ? "YES" : "NO"));
   Print(indent + "Cache Valid: " + (m_cacheValid ? "YES" : "NO"));
   Print(indent + "Cache TTL: " + IntegerToString(m_cacheExpirationSeconds) + "s");
   if(m_cacheValid)
   {
      datetime age = TimeCurrent() - m_cacheTime;
      Print(indent + "Cache Age: " + IntegerToString(age) + "s");
      Print(indent + "Cache Fresh: " + (IsCacheFresh() ? "YES" : "NO"));
   }
   Print(indent + "Debug Mode: " + (m_debug ? "ON" : "OFF"));
   Print(indent + "Last Error: " + m_lastError);
   
   SADXDirectionResult result = GetDirectionResult();
   if(result.isValid)
   {
      Print(indent + "ADX Value: " + DoubleToString(result.adxValue, 2));
      Print(indent + "+DI: " + DoubleToString(result.diPlus, 2));
      Print(indent + "-DI: " + DoubleToString(result.diMinus, 2));
      Print(indent + "Direction: " + result.direction);
      Print(indent + "Bull%: " + DoubleToString(result.bullPercentage, 1) + "%");
      Print(indent + "Bear%: " + DoubleToString(result.bearPercentage, 1) + "%");
      Print(indent + "Trend Strength: " + DoubleToString(result.trendStrength, 1) + "%");
      Print(indent + "Direction Clarity: " + DoubleToString(result.directionClarity, 1) + "%");
      Print(indent + "Confidence: " + DoubleToString(result.confidence, 1) + "%");
      Print(indent + "Description: " + result.description);
   }
   else
   {
      Print(indent + "❌ Unable to get ADX values");
   }
   Print(separator + "END STATUS " + separator);
}

//+------------------------------------------------------------------+
//| Helper: Get Timeframe Name                                      |
//+------------------------------------------------------------------+
string CAdxModule::GetTimeframeName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "TF" + IntegerToString(tf);
   }
}