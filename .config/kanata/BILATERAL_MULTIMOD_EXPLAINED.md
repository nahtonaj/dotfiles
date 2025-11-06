# Bilateral + Multi-Modifier Support - How It Works

## 🎯 The Goal

Get the **best of both worlds**:
- ✅ Bilateral protection: Single modifiers require opposite hand (prevents accidental activation)
- ✅ Multi-mod support: Multiple modifiers can be from same hand (enables combos like Shift+Cmd)

## 🧠 The Clever Solution

This configuration uses **dynamic layer switching** to temporarily disable bilateral restrictions when you're stacking modifiers.

### Two Layers Strategy

```
┌─────────────────────────────────────────────────────────┐
│ BASE LAYER                                              │
│ • Home row mods have bilateral restrictions             │
│ • Require opposite-hand keys to activate                │
│ • When you TAP a home row key:                          │
│   → Outputs the letter (a, s, d, f, etc.)              │
│   → Switches to NOMODS layer for 20ms                   │
└─────────────────────────────────────────────────────────┘
                           │
                           ↓ (on tap)
┌─────────────────────────────────────────────────────────┐
│ NOMODS LAYER (temporary)                                │
│ • Home row mods have NO bilateral restrictions          │
│ • Can activate with ANY key (including same-hand)       │
│ • Auto-returns to BASE after 20ms idle                  │
└─────────────────────────────────────────────────────────┘
```

## 📋 How It Works in Practice

### Scenario 1: Normal Typing (Bilateral Protection Active)
```
Type "sad":
1. Press S → outputs 's', briefly switches to nomods, returns to base
2. Press A → outputs 'a', briefly switches to nomods, returns to base  
3. Press D → outputs 'd', briefly switches to nomods, returns to base

Result: "sad" (no accidental modifiers) ✅
Bilateral protection prevents same-hand accidental activation!
```

### Scenario 2: Single Modifier (Bilateral Required)
```
Hold S, press T (Cmd+T):
1. Hold S → waiting for opposite-hand key (bilateral active)
2. Press T (right hand) → Cmd modifier activates
3. Release both

Result: Cmd+T (new tab) ✅
Bilateral requirement satisfied!
```

### Scenario 3: Same-Hand Multi-Modifier (Magic Happens!)
```
Hold A+S, press C (Shift+Cmd+C):
1. Hold A → waits for opposite hand, but also switches to nomods
2. While in nomods: Hold S → S modifier activates WITHOUT bilateral!
3. Now both A (Shift) and S (Cmd) are active
4. Press C → Shift+Cmd+C

Result: Shift+Cmd+C ✅
Multi-mod works because we're temporarily in nomods layer!
```

### Scenario 4: Cross-Hand Multi-Modifier
```
Hold A+J, press R (Left Shift + Right Ctrl + R):
1. Hold A → waits for opposite hand
2. Hold J (right hand) → Both A and J activate as modifiers
3. Press R → Shift+Ctrl+R

Result: Shift+Ctrl+R ✅
Works in both base and nomods layers!
```

## 🔧 Technical Implementation

### The Key Components

#### 1. The `@tap` Alias
```lisp
tap (multi
  (layer-switch nomods)
  (on-idle-fakekey to-base tap 20)
)
```

This does two things:
- Switches to nomods layer immediately
- Sets up an idle timer: if nothing happens for 20ms, return to base

#### 2. Base Layer Home Row Mods (Bilateral)
```lisp
a (tap-hold-release-keys $tap-timeout $hold-timeout 
    (multi a @tap) lsft $right-hand-keys)
```

Breaking this down:
- `tap-hold-release-keys`: Bilateral-aware tap-hold
- `$tap-timeout $hold-timeout`: Timing parameters
- `(multi a @tap)`: On tap → output 'a' AND execute @tap (layer switch)
- `lsft`: On hold → Left Shift modifier
- `$right-hand-keys`: Only activate with right-hand keys (bilateral!)

#### 3. Nomods Layer Home Row Mods (No Bilateral)
```lisp
an (tap-hold-release $tap-timeout $hold-timeout a lsft)
```

Breaking this down:
- `tap-hold-release`: Regular tap-hold (NO -keys suffix)
- No key list = activates with ANY key (no bilateral restriction)
- Used when you're already holding one home row mod

### The State Machine

```
State 1: BASE LAYER
  ├─ Hold A → waiting for right-hand key (bilateral)
  │   ├─ Press T → Shift+T ✅
  │   └─ Press S → Switches to nomods, now S can activate!
  │
  └─ Tap A → outputs 'a', brief nomods switch, back to base

State 2: NOMODS LAYER (temporary, 20ms timeout)
  ├─ Hold A → activates Shift with ANY key
  │   └─ Press S → Both A and S now active as modifiers!
  │
  └─ Idle for 20ms → auto-return to BASE
```

## 🧪 Testing Guide

### Test 1: Bilateral Protection (Same-Hand Rolls)
Type these quickly - should output normal text, no modifiers:
```
"sad" "fast" "adds" "junk" "kill"
```
✅ If you get plain text → bilateral protection working!

### Test 2: Single Modifier (Cross-Hand)
Try these shortcuts:
```
S + T = Cmd+T (hold S on left, press T on right)
F + R = Ctrl+R (hold F on left, press R on right)
L + Z = Cmd+Z (hold L on right, press Z on left)
```
✅ If shortcuts work → bilateral activation working!

### Test 3: Multi-Modifier (Same-Hand)
The magic test:
```
Hold A+S, press C = Shift+Cmd+C
Hold D+F, press R = Alt+Ctrl+R
Hold A+S+D, press T = Shift+Cmd+Alt+T (yes, triple!)
```
✅ If these work → multi-mod support working!

### Test 4: Multi-Modifier (Cross-Hand)
Should also work:
```
Hold A+J, press R = Shift+Ctrl+R (left Shift + right Ctrl)
```
✅ If this works → full multi-mod flexibility!

## ⚖️ Trade-offs

### Advantages
- ✅ Bilateral protection for single modifiers
- ✅ Same-hand multi-mod combinations work
- ✅ Cross-hand multi-mod combinations work
- ✅ Best of both worlds!

### Disadvantages
- ⚠️ More complex configuration (harder to understand/debug)
- ⚠️ Slight additional latency from layer switching (20ms)
- ⚠️ The 20ms nomods window could potentially allow accidental same-hand activation if you're VERY fast
- ⚠️ Requires understanding of layer system to customize

## 🎛️ Tuning Parameters

### The 20ms Timer
```lisp
(on-idle-fakekey to-base tap 20)
                              ^^-- This is the nomods layer timeout
```

- **Too short** (< 10ms): Multi-mods might not register in time
- **Too long** (> 50ms): Bilateral protection weakens (more time for accidental same-hand activation)
- **Recommended**: 20-30ms (sweet spot)

### Timeout Values
```lisp
tap-timeout 200
hold-timeout 200
```

Same tuning as before:
- **Increase** (250-280ms): More protection, slower activation
- **Decrease** (150-180ms): Faster activation, less protection

## 🆚 Comparison with Other Configs

| Feature | Original Bilateral | Hybrid | Bilateral-MultiMod |
|---------|-------------------|---------|-------------------|
| Same-hand rolling protection | 🟢 Perfect | 🟡 Timing only | 🟢 Excellent |
| Same-hand multi-mods | ❌ No | ✅ Yes | ✅ Yes |
| Cross-hand multi-mods | ✅ Yes | ✅ Yes | ✅ Yes |
| Complexity | 🟢 Simple | 🟢 Simple | 🔴 Complex |
| Latency | 🟢 None | 🟢 None | 🟡 +20ms |
| Best for | Single-mod users | Multi-mod speed | Best of both |

## 💡 When to Use This Config

**Use `kanata-bilateral-multimod.kbd` if:**
- ✅ You want bilateral protection against accidental mods
- ✅ You also need same-hand multi-mod combos (Shift+Cmd, etc.)
- ✅ You're willing to accept slight additional complexity
- ✅ 20ms additional latency is acceptable to you

**Don't use if:**
- ❌ You want the simplest possible config → use `kanata-hybrid.kbd`
- ❌ You never use multi-mod combos → use `kanata.kbd` (original bilateral)
- ❌ You need the absolute lowest latency → use `kanata-tap-hold-press.kbd`

## 🔬 Advanced: How Layer Switching Enables Multi-Mod

The brilliant insight is that when you hold multiple home row mods:

1. **First mod** is held → switches to nomods (via @tap)
2. **Second mod** is pressed while in nomods → activates WITHOUT bilateral check
3. Both mods are now active, and you can press your target key
4. When everything is released, system returns to base layer

This creates a "grace period" where bilateral restrictions are suspended, but ONLY when you're actively holding modifiers (intentional multi-mod), not during fast same-hand typing (accidental).

The 20ms timeout is short enough that normal typing doesn't trigger it, but long enough for deliberate multi-mod combinations to work!

## 🎯 Verdict

This is the **most sophisticated** home row mod configuration, providing both safety and flexibility. It's the closest you can get to "having your cake and eating it too" with home row mods!

Try it and see if it fits your workflow! 🎹


