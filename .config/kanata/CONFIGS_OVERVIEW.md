# Kanata Configurations - Visual Overview

## 🗺️ Configuration Landscape

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KANATA HOME ROW MODS                            │
│                         4 Complete Configs                              │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│  kanata.kbd          │  │ kanata-hybrid.kbd ⭐ │  │ kanata-tap-hold-     │
│  (ORIGINAL)          │  │ (RECOMMENDED)        │  │  press.kbd           │
├──────────────────────┤  ├──────────────────────┤  ├──────────────────────┤
│ BILATERAL ONLY       │  │ MULTI-MOD + TIMING   │  │ MULTI-MOD + SPEED    │
│                      │  │                      │  │                      │
│ Safety:     🟢🟢🟢    │  │ Safety:     🟢🟢      │  │ Safety:     🟡        │
│ Multi-Mod:  ❌       │  │ Multi-Mod:  ✅       │  │ Multi-Mod:  ✅       │
│ Speed:      🟡       │  │ Speed:      🟡       │  │ Speed:      🟢🟢🟢    │
│ Complexity: 🟢       │  │ Complexity: 🟢       │  │ Complexity: 🟢       │
│                      │  │                      │  │                      │
│ USE WHEN:            │  │ USE WHEN:            │  │ USE WHEN:            │
│ • Safety critical    │  │ • Need multi-mods    │  │ • Need speed         │
│ • No multi-mods      │  │ • Want simplicity    │  │ • Careful typing     │
│   needed             │  │ • Most users         │  │ • Advanced users     │
└──────────────────────┘  └──────────────────────┘  └──────────────────────┘

                  ┌────────────────────────────────────┐
                  │ kanata-bilateral-multimod.kbd 🌟  │
                  │ (ADVANCED - BEST OF BOTH WORLDS)   │
                  ├────────────────────────────────────┤
                  │ BILATERAL + MULTI-MOD              │
                  │                                    │
                  │ Safety:     🟢🟢🟢                  │
                  │ Multi-Mod:  ✅                     │
                  │ Speed:      🟡 (-20ms)             │
                  │ Complexity: 🔴 (layer switching)   │
                  │                                    │
                  │ USE WHEN:                          │
                  │ • Want maximum safety              │
                  │ • AND need multi-mods              │
                  │ • Willing to accept complexity     │
                  │ • Power user                       │
                  └────────────────────────────────────┘
```

---

## 🎨 Feature Matrix

```
Feature                    │ Original │ Hybrid ⭐ │ Tap-Hold-Press │ Bilateral-MM 🌟
───────────────────────────┼──────────┼──────────┼────────────────┼─────────────────
Same-hand multi-mods       │    ❌    │    ✅    │       ✅       │       ✅
Cross-hand multi-mods      │    ✅    │    ✅    │       ✅       │       ✅
Bilateral protection       │    ✅    │    ❌    │       ❌       │       ✅
Same-hand roll safety      │  Perfect │  Timing  │    Timing      │   Excellent
Activation speed           │  Normal  │  Normal  │     Fast       │   Normal-20ms
Configuration complexity   │  Simple  │  Simple  │    Simple      │    Complex
Learning curve             │   Easy   │  Medium  │     Hard       │    Medium
───────────────────────────┼──────────┼──────────┼────────────────┼─────────────────
Recommended for            │  Safety  │   Most   │     Speed      │  Power users
                          │   first  │  users   │   demons       │  want it all
```

---

## 🧭 Navigation Guide

### Start Here
```
SUMMARY.md (overview) → QUICK_REFERENCE.md (decision) → Choose config
```

### Full Journey
```
1. SUMMARY.md
   └─ Overview of all 4 configs
   
2. QUICK_REFERENCE.md
   └─ Quick decision tree
   
3. MULTI_MODIFIER_SOLUTIONS.md
   └─ Comprehensive comparison
   
4. BILATERAL_MULTIMOD_EXPLAINED.md (if choosing advanced)
   └─ Deep technical explanation
   
5. README.md
   └─ Installation and usage
   
6. IMPROVEMENTS.md
   └─ Details on anti-accident measures
```

---

## 🎯 Quick Selection

### I want... → Use this config

```
Maximum safety only
  → kanata.kbd (original)

Multi-mod + simplicity
  → kanata-hybrid.kbd ⭐

Multi-mod + speed
  → kanata-tap-hold-press.kbd

Multi-mod + bilateral safety
  → kanata-bilateral-multimod.kbd 🌟

Not sure / beginner
  → kanata-hybrid.kbd ⭐
```

---

## 📦 Files Included

### Configuration Files (4)
```
kanata.kbd                      - Original bilateral
kanata-hybrid.kbd              - Multi-mod with safety ⭐
kanata-tap-hold-press.kbd      - Multi-mod with speed
kanata-bilateral-multimod.kbd  - Bilateral + multi-mod 🌟
```

### Documentation Files (7)
```
README.md                      - Main docs, installation
SUMMARY.md                     - Overview of all configs
QUICK_REFERENCE.md             - Quick decision guide
MULTI_MODIFIER_SOLUTIONS.md    - Comprehensive comparison
BILATERAL_MULTIMOD_EXPLAINED.md - Advanced config explained
IMPROVEMENTS.md                - Anti-accident improvements
CONFIGS_OVERVIEW.md           - This file! Visual overview
```

---

## 🔄 Migration Path

### From Original to Hybrid
```bash
# Easy upgrade for multi-mod support
cp kanata-hybrid.kbd kanata.kbd
pkill kanata && kanata --cfg kanata.kbd
```

### From Original to Bilateral-MultiMod
```bash
# Advanced upgrade: keep bilateral, gain multi-mod
cp kanata-bilateral-multimod.kbd kanata.kbd
pkill kanata && kanata --cfg kanata.kbd
```

### From Hybrid to Bilateral-MultiMod
```bash
# Add bilateral protection
cp kanata-bilateral-multimod.kbd kanata.kbd
pkill kanata && kanata --cfg kanata.kbd
```

### From Hybrid to Tap-Hold-Press
```bash
# Optimize for speed
cp kanata-tap-hold-press.kbd kanata.kbd
pkill kanata && kanata --cfg kanata.kbd
```

---

## 🧪 Testing Matrix

| Test | Original | Hybrid | Tap-Hold-Press | Bilateral-MM |
|------|----------|--------|----------------|--------------|
| Type "sad" → "sad" | ✅ | ✅ | ✅ | ✅ |
| S+T → Cmd+T | ✅ | ✅ | ✅ | ✅ |
| A+S+C → Shift+Cmd+C | ❌ | ✅ | ✅ | ✅ |
| A+J+R → Shift+Ctrl+R | ✅ | ✅ | ✅ | ✅ |
| Fast roll "fast" | ✅ No mods | ⚠️ Rare mods | ⚠️ May trigger | ✅ No mods |

---

## 💭 Design Philosophy

### Original (kanata.kbd)
```
Philosophy: Safety through bilateral activation
Motto: "No accidental mods, ever"
Trade-off: Limited to cross-hand multi-mods
```

### Hybrid (kanata-hybrid.kbd) ⭐
```
Philosophy: Balance through timing
Motto: "Multi-mod without complexity"
Trade-off: Timing-based safety only
```

### Tap-Hold-Press (kanata-tap-hold-press.kbd)
```
Philosophy: Speed through immediate activation
Motto: "Fast as lightning"
Trade-off: Requires careful typing
```

### Bilateral-MultiMod (kanata-bilateral-multimod.kbd) 🌟
```
Philosophy: Best of both through layer switching
Motto: "Why not both?"
Trade-off: Complexity and slight latency
```

---

## 🎓 Skill Level Recommendations

```
┌─────────────────────────────────────────────────────────┐
│ Beginner (new to home row mods)                         │
│ → Start with: kanata-hybrid.kbd ⭐                       │
│   Why: Simple, forgiving, full functionality            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Intermediate (comfortable with HRM)                      │
│ → Upgrade to: kanata-bilateral-multimod.kbd 🌟          │
│   Why: Better protection, same functionality            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Advanced (touch typist, fast and accurate)              │
│ → Options:                                               │
│   • kanata-bilateral-multimod.kbd (best protection)     │
│   • kanata-tap-hold-press.kbd (best speed)              │
│   Why: Can handle more aggressive configs               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Prefer simplicity (KISS principle)                       │
│ → Use: kanata-hybrid.kbd ⭐                              │
│   Why: Does everything, simple to understand            │
└─────────────────────────────────────────────────────────┘
```

---

## 🎬 Quick Start (30 seconds)

```bash
# 1. Choose config (most users: hybrid)
CONFIG="kanata-hybrid.kbd"

# 2. Back up and install
cd ~/.config/kanata
cp kanata.kbd kanata.kbd.backup
cp $CONFIG kanata.kbd

# 3. Restart kanata
pkill kanata
kanata --cfg kanata.kbd &

# 4. Test it
# Type "sad" → should get "sad"
# Hold S, press T → should get Cmd+T
# Hold A+S, press C → should get Shift+Cmd+C (except original)
```

---

## 🏆 The Winner For Most Users

```
🥇 kanata-hybrid.kbd ⭐

Why:
✅ Simple configuration (easy to understand)
✅ Full multi-mod support (A+S+C works)
✅ Good safety (250ms timeouts)
✅ No layer switching complexity
✅ Works for 90% of users

Only upgrade if:
• You get frequent accidental mods → bilateral-multimod
• You need maximum speed → tap-hold-press
• You never use multi-mods → original
```

---

## 📞 Quick Help

```
Problem: Accidental modifiers
Solution: 
  1. Increase timeouts to 280ms
  2. Try bilateral-multimod.kbd
  3. Go back to kanata.kbd (original)

Problem: Modifiers too slow
Solution:
  1. Decrease timeouts to 180ms
  2. Try tap-hold-press.kbd

Problem: Multi-mods don't work
Check: Are you using hybrid/bilateral-multimod/tap-hold-press?
       (Original doesn't support same-hand multi-mods)

Problem: Too complex
Solution: Use kanata-hybrid.kbd (simplest with multi-mod)
```

---

## 🎉 Summary

You have **4 expertly crafted configs** covering every use case:

1. **Original** - Safety purist
2. **Hybrid** ⭐ - Balanced & simple (recommended)
3. **Tap-Hold-Press** - Speed demon
4. **Bilateral-MultiMod** 🌟 - Best of both worlds

**Most users should use `kanata-hybrid.kbd` ⭐**

**Power users should try `kanata-bilateral-multimod.kbd` 🌟**

Happy typing! 🎹


