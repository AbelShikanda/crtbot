

# 📋 Updated TODO List - CRT Bot v4.0.5

## 📍 Current Status Summary

### ✅ Completed - All Major Features (100%)

| Category | Status | Progress |
|----------|--------|----------|
| M1 Migration | ✅ Complete | 28/28 (100%) |
| **TrendManager v3.00** | ✅ **Complete** | **All features** |
| **TrendSetter (File 2)** | ✅ **Ready** | **All features** |
| **UltimateTrendSetter (File 3)** | ✅ **Ready** | **All features** |
| Risk Management | ✅ Complete | 5/5 (100%) |
| Position Management | ✅ Complete | 4/4 (100%) |
| Portfolio Management | ✅ Complete | 3/3 (100%) |
| Scenario Narrative | ✅ Complete | 6/6 (100%) |
| Confidence System | ✅ Complete | 5/5 (100%) |
| Visual Display | ✅ Complete | 5/5 (100%) |
| Compact Status Logging | ✅ Complete | 5/5 (100%) |
| R:R Filter | ✅ Complete | 3/3 (100%) |
| Dynamic Range (RangeManager) | ✅ Complete | 5/5 (100%) |
| Candle Direction Filter | ✅ Complete | 2/2 (100%) |
| Session Management | 🔶 In Progress | 2/3 (67%) |
| Dashboard | 🔶 In Progress | 1/3 (33%) |

**Overall Progress: ~95% Complete**

---

## 🚀 NEW: TrendManager Family - Complete! ✅

### ✅ File 1: TrendManager.mqh (v3.00)
**Status:** ✅ COMPLETE
**File:** TrendManager.mqh

**Features:**
- ✅ M15 Primary Trend Detection
- ✅ M5 Support (foundational)
- ✅ Configurable Thresholds (STrendThresholds)
- ✅ Constructor Overloads (default + custom thresholds)
- ✅ Momentum Check (`HasMomentum()`)
- ✅ Exhaustion Detection (`IsTrendExhausted()`)
- ✅ Confirmation Bars (`GetConfirmationBars()`)
- ✅ Trend Confirmation (`IsTrendConfirmed()`)
- ✅ Multi-TF Alignment (`IsMultiTFAligned()`)
- ✅ Infinite Loop Fix (GetDirection)
- ✅ Enhanced Reporting (Summary + Detailed)
- ✅ M5 Methods (GetDirection_M5, IsBullish_M5, etc.)
- ✅ Backward Compatible

### ✅ File 2: TrendSetter.mqh (v1.10)
**Status:** ✅ COMPLETE
**File:** TrendSetter.mqh

**Features:**
- ✅ Extends CTrendManager
- ✅ State Machine (7 States)
- ✅ Markov Predictor (ML)
- ✅ Q-Learning Engine (RL)
- ✅ State History (200 states)
- ✅ Pullback Tracking (depth, duration, count)
- ✅ Reversal Detection (expected vs unexpected)
- ✅ Predictive Signals (Long/Short/Exit)
- ✅ Position Management
- ✅ Dynamic Position Sizing
- ✅ Full Reports (GetFullReport, GetStateTimeline)

**States:**
| State | Description |
|-------|-------------|
| STATE_STRONG_BULL | All bullish |
| STATE_BULL_PULLBACK | Bullish with pullback |
| STATE_BULL_REVERSAL | Bullish reversing |
| STATE_NEUTRAL | No clear direction |
| STATE_BEAR_REVERSAL | Bearish reversing |
| STATE_BEAR_PULLBACK | Bearish with pullback |
| STATE_STRONG_BEAR | All bearish |

### ✅ File 3: UltimateTrendSetter.mqh (v1.00)
**Status:** ✅ COMPLETE
**File:** UltimateTrendSetter.mqh

**Features:**
- ✅ Extends CTrendSetter
- ✅ Multi-Timeframe (M1, M5, M15)
- ✅ Experience Replay (1000 memories)
- ✅ Market Modes (5 modes)
- ✅ Situation Scoring
- ✅ Dynamic Position Sizing
- ✅ Continuous Learning

**Market Modes:**
| Mode | Description | M15 | M5 | M1 |
|------|-------------|-----|----|----|
| STRONG_TREND | All aligned | ↑ | ↑ | ↑ |
| PULLBACK | M15 trend, M1 against | ↑ | ↑ | ↓ |
| REVERSAL | M15 trend, M5/M1 against | ↑ | ↓ | ↓ |
| REVERSAL_CONFIRMED | New trend confirmed | ↑ | ↑ | ↑ |
| NEUTRAL | No clear direction | - | - | - |

---

## ✅ Completed Today (2026-07-24)

| Item | File | Status |
|------|------|--------|
| **TrendManager v3.00 Upgrade** | TrendManager.mqh | ✅ |
| **TrendSetter v1.10** | TrendSetter.mqh (NEW) | ✅ |
| **UltimateTrendSetter v1.00** | UltimateTrendSetter.mqh (NEW) | ✅ |
| All three files compatible | - | ✅ |
| Inheritance chain complete | - | ✅ |
| Backward compatible | - | ✅ |

---

## 🎯 PRIORITY - Critical Bugs to Fix (HIGHEST)

| # | Bug | Impact | File |
|---|-----|--------|------|
| 1 | **RR color not changing** | Medium - Visual feedback missing | Dashboard.mqh |
| 2 | TrendManager NULL inconsistency | Critical - Can break trading logic | ComponentManager.mqh |
| 3 | Pullback logic fails when TrendManager is NULL | Critical - Entry signals lost | PullbackModule.mqh |
| 4 | POI lines blinking in/out | Medium - Visual annoyance | ChartModule.mqh |

---

## 🚀 Dashboard & Display Tasks

| # | Task | Priority | File |
|---|------|----------|------|
| 1 | **RR color coding** | HIGH | Dashboard.mqh |
| 2 | Add RR range display | HIGH | Dashboard.mqh |
| 3 | Add Range Bars display | HIGH | Dashboard.mqh |
| 4 | Add TrendSetter status | MEDIUM | Dashboard.mqh |
| 5 | Add State Machine display | MEDIUM | Dashboard.mqh |

---

## 🚀 NEW: TrendSetter Integration Tasks

| # | Task | Priority | File |
|---|------|----------|------|
| 1 | Replace CTrendManager with CTrendSetter | MEDIUM | crt_bot.mq5 |
| 2 | Integrate State Machine into main loop | MEDIUM | crt_bot.mq5 |
| 3 | Use Predictive Signals for entries | MEDIUM | PullbackModule.mqh |
| 4 | Use RL for position sizing | LOW | RiskManager.mqh |
| 5 | Add TrendSetter status to Dashboard | LOW | Dashboard.mqh |

---

## 🎯 Suggested Implementation Order

### Session 1 - Dashboard Fixes (1-2 hours)
1. **Fix RR color coding** - Show PASS/FAIL with color
2. **Add RR range display** - Show current RR and range
3. **Add Range Bars display** - Show dynamic bars

### Session 2 - Critical Fixes (1-2 hours)
4. **Fix TrendManager NULL** - Critical
5. **Fix Pullback logic** - Depends on TrendManager fix

### Session 3 - TrendSetter Integration (Optional)
6. **Replace CTrendManager with CTrendSetter**
7. **Integrate State Machine**
8. **Add TrendSetter to Dashboard**

---

## 🎯 Quick Start Options

| Option | Focus | Type | Est. Time |
|--------|-------|------|-----------|
| 🔴 1 | Fix RR color coding | Bug Fix | 15-30 min |
| 🟢 2 | Add RR range display | New Feature | 30-45 min |
| 🟢 3 | Add Range Bars display | New Feature | 30-45 min |
| 🔴 4 | Fix TrendManager NULL | Critical Bug | 15-30 min |
| 🟡 5 | TrendSetter Integration | New Feature | 1-2 hours |

---

## 📝 Implementation Checklist

### Dashboard - RR Color Fix
- [ ] Check RR calculation logic
- [ ] Add color coding (green = PASS, red = FAIL)
- [ ] Add dynamic color update
- [ ] Test with different RR values

### Dashboard - RR Display
- [ ] Add RR range display area
- [ ] Show current RR value: `RR: 2.85`
- [ ] Show range: `[1.5 - 5.0]`
- [ ] Show PASS/FAIL status with color

### Dashboard - Range Bars Display
- [ ] Add range bars display area
- [ ] Show current bar count: `Range: 24 bars`
- [ ] Show session adjustment: `Adj: +8`
- [ ] Show session name: `Session: London/NY Overlap`

### TrendSetter Integration
- [ ] Replace `CTrendManager` with `CTrendSetter`
- [ ] Update ComponentManager
- [ ] Test State Machine
- [ ] Test Predictive Signals

---

## 📊 Version History

| Version | Date | Changes |
|---------|------|---------|
| v4.00 | 2024-07-22 | Initial M1 Migration complete |
| v4.01 | 2024-07-22 | Chart font size increased (8→12) |
| v4.02 | 2024-07-22 | Compact status logging added |
| v4.03 | 2024-07-23 | R:R Filter + Dynamic Range + Candle Filter |
| **v4.04** | **2024-07-24** | **TrendManager v3.00 + TrendSetter + UltimateTrendSetter** |
| v4.05 | Planned | Dashboard RR/Range display + Bug fixes |
| v4.06 | Planned | TrendSetter Integration |

---

## 🔗 Related Files

| File | Purpose | Status |
|------|---------|--------|
| **TrendManager.mqh** | **Base trend detection** | **✅ v3.00 COMPLETE** |
| **TrendSetter.mqh** | **State Machine + ML + RL** | **✅ v1.10 COMPLETE** |
| **UltimateTrendSetter.mqh** | **Multi-TF + Replay** | **✅ v1.00 COMPLETE** |
| PositionManager.mqh | SL management | 🔴 Needs SL fix |
| ComponentManager.mqh | Component initialization | 🔴 Needs NULL fix |
| PullbackModule.mqh | Entry signals | 🔴 Needs TrendManager fix |
| RangeManager.mqh | Dynamic range bars | ✅ COMPLETE |
| Dashboard.mqh | Visual display | 🟡 Needs RR/Range display |

---

## 📌 Daily Check

### Before Starting:
- [ ] Review critical bugs
- [ ] Check current priority
- [ ] Set daily goal
- [ ] Backup current code

### After Implementation:
- [ ] Test with live data
- [ ] Update documentation
- [ ] Log changes
- [ ] Update TODO list

---

## 📝 Notes for Next Session

### TrendManager Family - Quick Reference

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TRENDMANAGER FAMILY QUICK REFERENCE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FILE 1: CTrendManager                                                      │
│  ───────────────────                                                        │
│  • Base class - Reads trend from MAs                                       │
│  • Outputs: Direction, Strength, M1 Compatibility                          │
│  • No learning                                                             │
│                                                                              │
│  FILE 2: CTrendSetter : public CTrendManager                               │
│  ─────────────────────────────────                                         │
│  • Adds: State Machine (7 states)                                          │
│  • Adds: Markov Predictor (ML)                                             │
│  • Adds: Q-Learning (RL)                                                   │
│  • Adds: Pullback/Reversal tracking                                        │
│  • Adds: Predictive signals                                                │
│                                                                              │
│  FILE 3: CUltimateTrendSetter : public CTrendSetter                       │
│  ───────────────────────────────────                                        │
│  • Adds: Multi-TF (M1, M5, M15)                                            │
│  • Adds: Experience Replay                                                  │
│  • Adds: Market Modes (5 modes)                                            │
│  • Adds: Situation Scoring                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

---
*Last Updated: 2026-07-24*
*Version: v4.0.5*
*Status: TrendManager Family COMPLETE | Dashboard display next*

TrendManager
note (. struct already exists in struct file.)
. Add constructor overload:
. Make thresholds configurable:
. add Momentum Filter/Momentum Confirmation
. Add constructor overload:
. remove infinite loopo possiblity from the getdirection()
. retain threasholds as they are.
. Use M15 as your primary trend timeframe which i know this is already true
. add MA for M5 for the rest of the upcomming upgrades
. add any other things that wii berequired foundatoinaly like the M5

i am thinking 
turning trendmanager into a Self-Learning Trendsetting State Machine
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CTRENDSETTER - NEW FILE                              │
│                   (ADDS STATE MACHINE + ML + RL)                          │
│                  (PRESERVES ALL CTRENDMANAGER OUTPUTS)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  ADDS: STATE MACHINE (7 States)                                     │    │
│  │  ├─ STATE_STRONG_BULL    (All bullish)                              │    │
│  │  ├─ STATE_BULL_PULLBACK  (Bullish with pullback)                    │    │
│  │  ├─ STATE_BULL_REVERSAL  (Bullish reversing)                        │    │
│  │  ├─ STATE_NEUTRAL        (No clear direction)                       │    │
│  │  ├─ STATE_BEAR_REVERSAL  (Bearish reversing)                        │    │
│  │  ├─ STATE_BEAR_PULLBACK  (Bearish with pullback)                    │    │
│  │  └─ STATE_STRONG_BEAR    (All bearish)                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  ADDS: ML PREDICTORS (Simple + Fast)                               │    │
│  │  ├─ CMarkovPredictor     (Transition probability)                  │    │
│  │  │  • Trains on state history                                      │    │
│  │  │  • Predicts next state                                          │    │
│  │  │  • Confidence score                                             │    │
│  │  └─ Simple Pattern Detection                                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  ADDS: REINFORCEMENT LEARNING (Q-Learning)                         │    │
│  │  ├─ Q-Table: 7 states × 9 actions                                  │    │
│  │  ├─ Actions: Hold, Enter_Long, Enter_Short, etc                   │    │
│  │  ├─ Reward: Profit/Loss feedback                                   │    │
│  │  ├─ Exploration/Exploitation balance                               │    │
│  │  └─ Learns from every trade                                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  ADDS: SEQUENCE & PATTERN TRACKING                                  │    │
│  │  ├─ State history (last 200 states)                                 │    │
│  │  ├─ Pullback tracking (depth, duration, count)                      │    │
│  │  ├─ Reversal detection (expected vs unexpected)                     │    │
│  │  └─ Pattern recognition (winning sequences)                         │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  NEW OUTPUTS (ADDED):                                              │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │  STATE QUERIES           │  ML PREDICTIONS                         │    │
│  │  ├─ GetStateName()       │  ├─ GetPredictedState()                 │    │
│  │  ├─ GetBarsInState()     │  └─ GetPredictionConfidence()           │    │
│  │  └─ GetStateStartTime()  │                                         │    │
│  │                          │  RL STATS                               │    │
│  │  PULLBACK QUERIES        │  ├─ GetRLWinRate()                      │    │
│  │  ├─ IsInPullback()       │  ├─ GetTotalTrades()                    │    │
│  │  ├─ GetPullbackDepth()   │  └─ GetAveragePnL()                     │    │
│  │  └─ GetPullbackCount()   │                                         │    │
│  │                          │  PREDICTIVE SIGNALS                     │    │
│  │  REVERSAL QUERIES        │  ├─ ShouldEnterPredictiveLong()         │    │
│  │  ├─ IsReversing()        │  └─ ShouldEnterPredictiveShort()        │    │
│  │  └─ GetReversalInfo()    │                                         │    │
│  │                          │  ENHANCED REPORTS                       │    │
│  │  ACTION QUERIES          │  └─ GetFullReport()                     │    │
│  │  └─ GetRecommendedAction()│  (All CTrendManager + New)             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ═════════════════════════════════════════════════════════════════════════  │
│  PURPOSE: Predict winning situations + Learn from trades                    │
│  OUTPUT COUNT: ~35 methods (All parent + 10 new)                           │
│  LEARNING: ML + RL (Gets smarter over time)                                │
└─────────────────────────────────────────────────────────────────────────────┘

Time    M15 Trend    M5 Trend     M1 Sentiment    Mode           Action
────────────────────────────────────────────────────────────────────────────
09:00   BULLISH      BULLISH      BULLISH         STRONG TREND   Hold
09:15   BULLISH      BULLISH      BULLISH         STRONG TREND   Hold
09:30   BULLISH      BULLISH      BEARISH         PULLBACK       🔄 Wait
09:45   BULLISH      BULLISH      BEARISH         PULLBACK       📉 Hit support
10:00   BULLISH      BULLISH      BULLISH         STRONG TREND   ✅ ENTRY!
10:15   BULLISH      BULLISH      BULLISH         STRONG TREND   Hold
10:30   BULLISH      BEARISH      BEARISH         REVERSAL       ⚠️ Watch
10:45   BULLISH      BEARISH      BEARISH         REVERSAL       ❌ Exit (warning)
11:00   NEUTRAL      BEARISH      BEARISH         NEUTRAL        No trade
11:15   BEARISH      BEARISH      BEARISH         REVERSAL CONFIRMED ✅ NEW TREND!
11:30   BEARISH      BEARISH      BEARISH         STRONG TREND   Hold
11:45   BEARISH      BEARISH      BULLISH         PULLBACK       🔄 Wait
12:00   BEARISH      BEARISH      BULLISH         PULLBACK       📈 Bounce
12:15   BEARISH      BEARISH      BEARISH         STRONG TREND   ✅ ENTRY SHORT!


┌─────────────────────────────────────────────────────────────────────────────┐
│                    THREE FILE COMPARISON - AT A GLANCE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  FILE 1: TrendManager.mqh (YOUR CURRENT FILE)                      │    │
│  │  ─────────────────────────────────────────                          │    │
│  │  • What it does: Reads trend from MAs                              │    │
│  │  • Role: PASSIVE OBSERVER                                          │    │
│  │  • Learning: NONE                                                  │    │
│  │  • Outputs: Direction, Strength, M1 Compatibility                  │    │
│  │  • Complexity: LOW                                                 │    │
│  │  • Best for: Simple trend following, no learning needed            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  FILE 2: TrendSetter.mqh (NEW - EXTENDS TrendManager)              │    │
│  │  ─────────────────────────────────────────                          │    │
│  │  • What it does: Predicts winning situations + Learns from trades  │    │
│  │  • Role: ACTIVE PREDICTOR                                          │    │
│  │  • Learning: ML (Markov) + RL (Q-Learning)                        │    │
│  │  • Outputs: ALL File 1 + State, Pullback, Reversal, Predictions   │    │
│  │  • Complexity: MEDIUM                                              │    │
│  │  • Best for: Learning systems, pullback/reversal trading          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  FILE 3: UltimateTrendSetter.mqh (NEW - EXTENDS TrendSetter)       │    │
│  │  ─────────────────────────────────────────                          │    │
│  │  • What it does: Multi-TF + Experience Replay + Market Modes       │    │
│  │  • Role: MASTER STRATEGIST                                         │    │
│  │  • Learning: ML + RL + Experience Replay + Continuous Learning    │    │
│  │  • Outputs: ALL File 1 + File 2 + Multi-TF, Modes, Scores         │    │
│  │  • Complexity: HIGH                                                │    │
│  │  • Best for: Professional systems, full self-learning             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘


// FILE 1: TrendManager.mqh
class CTrendManager
{
   // Base class - reads trend
};

// FILE 2: TrendSetter.mqh
#include "TrendManager.mqh"

class CTrendSetter : public CTrendManager  // INHERITS File 1
{
   // Has ALL of File 1 + new features
};

// FILE 3: UltimateTrendSetter.mqh
#include "TrendSetter.mqh"

class CUltimateTrendSetter : public CTrendSetter  // INHERITS File 2
{
   // Has ALL of File 1 + File 2 + new features
};

┌─────────────────────────────────────────────────────────────────────────────┐
│                    NEW CHECKS ADDED TO EACH CHECKPOINT                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CHECKPOINT 1: TREND (Now 15+ checks instead of 3)                        │
│  ─────────────────────────────────────────────────                         │
│  🆕 State Machine (7 states)                                               │
│  🆕 Reversal detection                                                     │
│  🆕 Pullback detection + depth                                             │
│  🆕 Trend confirmation (3+ bars)                                           │
│  🆕 Momentum check (accelerating)                                          │
│  🆕 Exhaustion check (not dying)                                           │
│  🆕 Pattern detection + success rate                                       │
│  🆕 ML prediction + confidence                                             │
│  🆕 Multi-TF alignment (M15/M5/M1)                                         │
│  🆕 Market Mode (5 modes)                                                  │
│  🆕 Situation scoring                                                      │
│  🆕 Decision explanation                                                   │
│                                                                              │
│  CHECKPOINT 2: COMPONENT ANALYSIS (Unchanged)                              │
│  ───────────────────────────────────                                         │
│  • MTF, MACD, ADX, RSI, Volume, Pullback                                   │
│  • Overall confidence                                                      │
│                                                                              │
│  CHECKPOINT 3: MACD OPPOSITION (Unchanged)                                 │
│  ─────────────────────────────                                              │
│  • Reject if MACD opposes trend ≥10%                                       │
│                                                                              │
│  CHECKPOINT 4: CANDLE DIRECTION (Unchanged)                                │
│  ─────────────────────────────                                              │
│  • Candle exhaustion detection                                             │
│                                                                              │
│  CHECKPOINT 5: RISK-REWARD (Unchanged)                                     │
│  ─────────────────────────                                                  │
│  • RR calculation 1.5-5.0                                                  │
│                                                                              │
│  CHECKPOINT 6: POSITION SIZING (Now 7+ adjustments)                       │
│  ─────────────────────────────────                                        │
│  🆕 Pattern success rate adjustment                                        │
│  🆕 Situation score adjustment                                             │
│  🆕 Mode-based adjustment                                                  │
│  🆕 Multi-TF alignment adjustment                                          │
│  🆕 Momentum adjustment                                                    │
│  🆕 Exhaustion adjustment                                                  │
│  🆕 Confidence adjustment                                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
. use ultimatetrendsetter for range bars.
. range manager essentially becomes a session manager.
. turn initialization information on on main to make sure i see success message.

#include "../PackageManagers/TrendManagement/TrendManager.mqh"
#include "../PackageManagers/TrendManagement/TrendSetter.mqh"
#include "../Headers/Structures.mqh"  // For SPullbackAnalysisResult
#include "../PackageManagers/ComponentManager.mqh"
#include "../PackageManagers/PositionManager.mqh"
#include "../PackageManagers/Riskmanager.mqh"




















Portfoliomanager
1. remove:
Updated constructor log to reflect "Removed Emergency Exits"
Updated component report to show "v3.7 - Removed Emergency Exits"


PositionManager
1. remove:
Updated ManagePositions() to only get m_lossManagementEnabled from PortfolioManager (not the confidence value)
3. stop logging the sl movements.

Dashboard
1. place desc in its own line.
2. add a section for rr.
3. RISK LIMITS CheckRiskLimits.
4. Signal alignment.
5. 

Mainfile
1. add a buffer to sl
2. bias entries to the ob nearest or at the asian range high or low depending on direction

Riskmanager