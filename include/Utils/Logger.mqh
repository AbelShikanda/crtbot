//+------------------------------------------------------------------+
//|                        Logger.mqh                                |
//|                    Complete Logger Module                        |
//|              v2.0 - Full Context Logging                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version "2.0"

// ============================================================
// LOGGING MACROS
// ============================================================

// Main log with toggle (auto module + function name)
#define LOG(msg, toggle)           Logger::Log(__FUNCTION__, msg, toggle)
#define LOG_DEBUG(msg, toggle)     Logger::Log(__FUNCTION__, "DEBUG", msg, toggle)
#define LOG_INFO(msg, toggle)      Logger::Log(__FUNCTION__, "INFO", msg, toggle)
#define LOG_WARNING(msg)           Logger::Log(__FUNCTION__, "WARNING", msg, false)
#define LOG_ERROR(msg)             Logger::LogError(__FUNCTION__, msg, GetLastError())
#define LOG_TRADE(msg)             Logger::Log(__FUNCTION__, "TRADE", msg, false)

// ============================================================
// LOGGER CLASS
// ============================================================
class Logger
{
private:
   static string m_logFile;
   static bool m_initialized;
   
   // Get module name from function
   static string GetModuleName(string functionName)
   {
      int pos = StringFind(functionName, "::");
      if(pos > 0)
      {
         string className = StringSubstr(functionName, 0, pos);
         if(StringFind(className, "C") == 0 && StringLen(className) > 1)
            className = StringSubstr(className, 1);
         return className;
      }
      return functionName;
   }
   
   // Get function name only (without class)
   static string GetFunctionName(string functionName)
   {
      int pos = StringFind(functionName, "::");
      if(pos > 0)
         return StringSubstr(functionName, pos + 2);
      return functionName;
   }
   
   // Get timestamp
   static string GetTimestamp()
   {
      return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   }
   
   // Write to log file (optional - comment out if not needed)
   static void WriteToFile(string message)
   {
      if(!m_initialized) return;
      
      int handle = FileOpen(m_logFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, message);
         FileClose(handle);
      }
   }

public:
   // ──────────────────────────────────────────────────────────────
   // INITIALIZATION
   // ──────────────────────────────────────────────────────────────
   static void Initialize(string logFileName = "")
   {
      if(logFileName == "")
         m_logFile = "Log_" + IntegerToString(TimeCurrent()) + ".txt";
      else
         m_logFile = logFileName;
      
      m_initialized = true;
      Log("Logger", "✅ Logger initialized - File: " + m_logFile, true);
   }
   
   // ──────────────────────────────────────────────────────────────
   // MAIN LOG METHODS
   // ──────────────────────────────────────────────────────────────
   
   // Main log with toggle
   static void Log(string functionName, string message, bool toggle)
   {
      if(!toggle) return;
      
      string module = GetModuleName(functionName);
      string func = GetFunctionName(functionName);
      string fullMessage =" [" + module + "] [" + func + "] " + message;
      
      Print(fullMessage);
      WriteToFile(fullMessage);
   }
   
   // Log with level
   static void Log(string functionName, string level, string message, bool toggle)
   {
      if(!toggle) return;
      
      string module = GetModuleName(functionName);
      string func = GetFunctionName(functionName);
      string fullMessage =" [" + level + "] [" + module + "] [" + func + "] " + message;
      
      Print(fullMessage);
      WriteToFile(fullMessage);
   }
   
   // Error log (always shows)
   static void LogError(string functionName, string message, int errorCode = 0)
   {
      string module = GetModuleName(functionName);
      string func = GetFunctionName(functionName);
      
      string errorMsg = message;
      if(errorCode != 0)
         errorMsg += " (Error: " + IntegerToString(errorCode) + " - " + GetErrorDescription(errorCode) + ")";
      
      string fullMessage = " [ERROR] [" + module + "] [" + func + "] ❌ " + errorMsg;
      
      Print(fullMessage);
      WriteToFile(fullMessage);
   }
   
   // ──────────────────────────────────────────────────────────────
   // ERROR UTILITIES
   // ──────────────────────────────────────────────────────────────
   
   // Get error description
   static string GetErrorDescription(int errorCode)
   {
      switch(errorCode)
      {
         case 0:           return "No error";
         case 1:           return "No result";
         case 2:           return "Common error";
         case 3:           return "Invalid trade parameters";
         case 4:           return "Server busy";
         case 5:           return "Old version";
         case 6:           return "No connection";
         case 7:           return "Not enough rights";
         case 8:           return "Too frequent requests";
         case 9:           return "Malfunctional trade";
         case 64:          return "Account disabled";
         case 65:          return "Invalid account";
         case 128:         return "Trade timeout";
         case 129:         return "Invalid price";
         case 130:         return "Invalid stops";
         case 131:         return "Invalid trade volume";
         case 132:         return "Market closed";
         case 133:         return "Trade disabled";
         case 134:         return "Not enough money";
         case 135:         return "Price changed";
         case 136:         return "Requote";
         case 137:         return "Order locked";
         case 138:         return "Long positions only allowed";
         case 139:         return "Too many requests";
         case 145:         return "Trade modify denied";
         case 146:         return "Trade context busy";
         case 147:         return "Trade expiration denied";
         case 148:         return "Too many orders";
         case 149:         return "Hedge prohibited";
         case 150:         return "Trade prohibited by FIFO";
         default:          return "Unknown error";
      }
   }
   
   // Check if error is recoverable
   static bool IsRecoverableError(int errorCode)
   {
      return (errorCode == 4 ||  // Server busy
              errorCode == 8 ||  // Too frequent requests
              errorCode == 128 || // Trade timeout
              errorCode == 135 || // Price changed
              errorCode == 136 || // Requote
              errorCode == 146);  // Trade context busy
   }
   
   // ──────────────────────────────────────────────────────────────
   // SHUTDOWN
   // ──────────────────────────────────────────────────────────────
   static void Shutdown()
   {
      Log("Logger", "Shutdown complete", true);
      m_initialized = false;
   }
};

// Static member initialization
string Logger::m_logFile = "";
bool Logger::m_initialized = false;





// UseCase
// LOG_DEBUG("Initializing module", g_chartDebugMode);
// LOG_INFO("=== EA INITIALIZATION START ===", g_mainDebugMode);
// LOG_WARNING("Drawdown exceeded threshold: " + DoubleToString(drawdown, 2) + "%");
// LOG_TRADE("Order #" + IntegerToString(ticket) + " modified");
// LOG("Data received: " + IntegerToString(dataCount) + " records", g_mainDebugMode); //use this for errors with toggle as true