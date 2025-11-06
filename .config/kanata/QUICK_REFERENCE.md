# Kanata Configs - Quick Reference Card

## 🎯 Which Config Should You Use?

```
┌─────────────────────────────────────────────────────────────────┐
│ Question: Do you need same-hand multi-mod combos?              │
│ (e.g., Shift+Cmd+Key, Alt+Ctrl+Key from same hand)            │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ├─── NO ──→ Use: kanata.kbd (default)
                           │           • Best safety
                           │           • Bilateral protection
                           │           • Cross-hand multi-mods work
                           │
                           └─── YES ──→ Do you want bilateral protection too?
                                        │
                                        ├─── YES! Both! ──→ kanata-bilateral-multimod.kbd 🌟
                                        │                   • Bilateral protection
                                        │                   • All multi-mods work
                                        │                   • +20ms latency
                                        │                   • Complex config
                                        │
                                        └─── No, just multi-mod ──→ Do you type with discipline?
                                                                    │
                                                                    ├─── Not really ──→ kanata-hybrid.kbd ⭐
                                                                    │                   • Longer timeouts
                                                                    │                   • Good safety
                                                                    │                   • Simple
                                                                    │
                                                                    └─── Yes, careful ──→ kanata-tap-hold-press.kbd
                                                                                        • Fastest response
                                                                                        • All multi-mods
                                                                                        • Requires precision
```

---

## 📊 At a Glance

| Config | Safety | Multi-Mod | Speed | Complexity | Best For |
|--------|--------|-----------|-------|------------|----------|
| **kanata.kbd** | 🟢🟢🟢 | ⚠️ Cross-hand only | 🟡 | 🟢 Simple | Safety |
| **kanata-hybrid.kbd** ⭐ | 🟢🟢 | ✅ All | 🟡 | 🟢 Simple | Balance |
| **kanata-tap-hold-press.kbd** | 🟡 | ✅ All | 🟢🟢🟢 | 🟢 Simple | Speed |
| **kanata-bilateral-multimod.kbd** 🌟 | 🟢🟢🟢 | ✅ All | 🟡 (-20ms) | 🔴 Complex | Best of Both |

---

## 🧪 Quick Test

After switching configs, test these:

### Test 1: Basic (all configs should work)
- `S + T` → Cmd+T (new tab)
- `A + Y` → Shift+Y (capital Y)

### Test 2: Same-Hand Multi-Mod (only hybrid/tap-hold-press)
- Hold `A + S`, press `C` → Shift+Cmd+C
- Hold `D + F`, press `R` → Alt+Ctrl+R

---

## ⚙️ How to Switch

```bash
# See what you currently have
head -n 3 ~/.config/kanata/kanata.kbd

# Backup current config
cp ~/.config/kanata/kanata.kbd ~/.config/kanata/kanata.kbd.backup

# Switch to hybrid (recommended)
cp ~/.config/kanata/kanata-hybrid.kbd ~/.config/kanata/kanata.kbd

# OR switch to tap-hold-press
cp ~/.config/kanata/kanata-tap-hold-press.kbd ~/.config/kanata/kanata.kbd

# OR restore original
cp ~/.config/kanata/kanata.kbd.backup ~/.config/kanata/kanata.kbd

# Restart kanata
pkill kanata
kanata --cfg ~/.config/kanata/kanata.kbd
```

---

## 🔧 Quick Tuning

### If Getting Accidental Modifiers

Edit your chosen config, find this section:
```lisp
(defvar
  tap-timeout 200      ;; ← Increase by 50 (to 250)
  hold-timeout 200     ;; ← Increase by 50 (to 250)
  ...
)
```

Then restart kanata.

### If Modifiers Too Slow

Decrease the same values by 20-50ms (but not below 150ms).

---

## 📖 Full Details

Read **[MULTI_MODIFIER_SOLUTIONS.md](MULTI_MODIFIER_SOLUTIONS.md)** for:
- Detailed explanations
- Testing procedures
- Technical background
- Advanced customization

---

## 💡 Recommendation

### For Most Users: `kanata-hybrid.kbd` ⭐
Simple multi-mod support with good safety (250ms timeouts).

### For Advanced Users: `kanata-bilateral-multimod.kbd` 🌟
The ultimate config - bilateral protection + multi-mod support!
- Best safety against accidental activations
- Full multi-mod functionality
- Slight complexity and +20ms latency

### If Getting Accidental Modifiers:
1. Increase timeouts to 280-300ms in your config, OR
2. Go back to `kanata.kbd` (original bilateral), OR
3. Try `kanata-bilateral-multimod.kbd` for better protection

### If Need More Speed:
Try `kanata-tap-hold-press.kbd` (requires careful typing).

---

**Current Config:** (check with `head -n 2 ~/.config/kanata/kanata.kbd`)
- Line 1 contains "Bilateral Home Row Mods and Combos" = Original (bilateral)
- Line 1 contains "Hybrid Approach" = Hybrid (multi-mod with safety)
- Line 1 contains "tap-hold-press" = Tap-hold-press (fast multi-mod)
- Line 1 contains "Bilateral + Multi-Modifier" = Bilateral-MultiMod (best of both)

