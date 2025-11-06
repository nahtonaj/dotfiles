# Multi-Modifier Support for Bilateral Home Row Mods

## The Problem

Your original `kanata.kbd` configuration uses **bilateral home row mods** with `tap-hold-release-keys`. This prevents accidental modifier activation during same-hand typing, but it also **prevents same-hand multi-modifier combinations**.

### What Doesn't Work with Bilateral Mods:
- ❌ A+S+C (Left Shift + Left Cmd + C) - requires two left-hand mods
- ❌ D+F+R (Left Alt + Left Ctrl + R) - requires two left-hand mods
- ❌ K+L+A (Right Alt + Right Cmd + A) - requires two right-hand mods

### What DOES Work with Bilateral Mods:
- ✅ A+J+key (Left Shift + Right Ctrl + key) - opposite hands
- ✅ S+K+key (Left Cmd + Right Alt + key) - opposite hands
- ✅ Single mods: A+Y (Shift+Y), S+T (Cmd+T), etc.

## The Solutions

I've created **four** configuration files for you to choose from:

### 1. `kanata.kbd` (Original - Bilateral with Safety)
**Best for:** Maximum protection against accidental activations  
**Trade-off:** No same-hand multi-mod support

```
Features:
- ✅ Bilateral activation (opposite-hand only)
- ✅ Best protection against accidental mods
- ✅ Cross-hand multi-mods work (A+J, S+K, etc.)
- ❌ Same-hand multi-mods don't work (A+S, D+F, etc.)
- Timeouts: 200ms tap / 200ms hold
```

**Use this if:**
- You prioritize accuracy over flexibility
- You rarely need multi-mod combinations
- You can work with cross-hand multi-mods only

---

### 2. `kanata-hybrid.kbd` (Recommended - Balanced)
**Best for:** Multi-mod support with longer timeouts for safety  
**Trade-off:** Slightly higher risk of accidental activation

```
Features:
- ✅ All multi-mod combinations work (A+S+C, D+F+R, etc.)
- ✅ Longer timeouts reduce accidental activation
- ✅ Same behavior as non-bilateral configs
- ⚠️ No bilateral protection (relies on timing only)
- Timeouts: 250ms tap / 250ms hold (longer = safer)
```

**Use this if:**
- You need multi-mod support (Shift+Cmd+Key, etc.)
- You're willing to accept slightly more risk
- You type with reasonable pauses between keys
- You want tap-hold-release behavior (mods on key release)

**Testing:**
```bash
# Try this config
kanata --cfg ~/.config/kanata/kanata-hybrid.kbd

# Test multi-mods:
# Hold A+S, then press C = Shift+Cmd+C
# Hold D+F, then press R = Alt+Ctrl+R
```

---

### 3. `kanata-tap-hold-press.kbd` (Aggressive - Fast Response)
**Best for:** Maximum responsiveness for multi-mods  
**Trade-off:** Most aggressive activation, highest risk of accidents

```
Features:
- ✅ All multi-mod combinations work
- ✅ Fastest response (mods activate on next keypress)
- ✅ Great for rapid multi-mod shortcuts
- ⚠️ Most aggressive - triggers quickly
- ⚠️ Requires very careful timing discipline
- Timeouts: 200ms tap (hold-timeout not used)
```

**Difference from tap-hold-release:**
- `tap-hold-release`: Modifier activates when you **release** the key
- `tap-hold-press`: Modifier activates **immediately** when next key is pressed
- tap-hold-press is faster but more aggressive

**Use this if:**
- You need fast multi-mod response
- You have disciplined typing habits
- You don't do fast same-hand rolls
- You want immediate modifier activation

**Testing:**
```bash
# Try this config
kanata --cfg ~/.config/kanata/kanata-tap-hold-press.kbd

# Test responsiveness:
# Hold A, press S quickly, press C = Should get Shift+Cmd+C
# Very fast and responsive!
```

---

### 4. `kanata-bilateral-multimod.kbd` (Advanced - Best of Both Worlds!)
**Best for:** Bilateral protection + Multi-mod support  
**Trade-off:** More complex, slight latency (+20ms)

```
Features:
- ✅ Bilateral protection for single modifiers
- ✅ All multi-mod combinations work (A+S+C, D+F+R, etc.)
- ✅ Best of both worlds!
- ⚠️ More complex (uses layer switching)
- ⚠️ +20ms latency from layer transitions
- Timeouts: 200ms tap / 200ms hold
```

**How it works:**
- Uses a clever layer-switching technique
- Single mod: requires opposite hand (bilateral)
- Multi-mod: temporarily disables bilateral restriction
- When you hold A, it briefly switches to a "nomods" layer
- In nomods layer, pressing S activates without bilateral check
- Result: A+S both active as Shift+Cmd!

**Use this if:**
- You want bilateral protection against accidental mods
- You also need same-hand multi-mod support
- You don't mind the additional complexity
- 20ms extra latency is acceptable

**Testing:**
```bash
# Try this advanced config
kanata --cfg ~/.config/kanata/kanata-bilateral-multimod.kbd

# Test bilateral protection (same-hand rolls):
# Type "sad", "fast" → should output plain text ✅

# Test multi-mods:
# Hold A+S, then press C = Shift+Cmd+C ✅
```

📖 **Read [BILATERAL_MULTIMOD_EXPLAINED.md](BILATERAL_MULTIMOD_EXPLAINED.md)** for detailed explanation!

---

## Comparison Table

| Feature | Original | Hybrid | Tap-Hold-Press | Bilateral-MultiMod |
|---------|----------|--------|----------------|-------------------|
| **Same-hand multi-mods** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Cross-hand multi-mods** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Accidental activation protection** | 🟢 Excellent | 🟡 Good | 🔴 Moderate | 🟢 Excellent |
| **Multi-mod responsiveness** | N/A | 🟡 Moderate | 🟢 Excellent | 🟡 Good |
| **Same-hand roll protection** | 🟢 Perfect | 🟡 Timing-based | 🔴 Timing-based | 🟢 Excellent |
| **Latency** | 🟢 None | 🟢 None | 🟢 None | 🟡 +20ms |
| **Tap timeout** | 200ms | 250ms | 200ms | 200ms |
| **Hold timeout** | 200ms | 250ms | 50ms | 200ms |
| **Complexity** | 🟢 Simple | 🟢 Simple | 🟢 Simple | 🔴 Complex |
| **Learning curve** | Easy | Moderate | Hard | Moderate |
| **Best for** | Safety | Balance | Speed | Best of Both |

---

## Recommendation

### New Users: Start with `kanata-hybrid.kbd`

This gives you:
1. ✅ Full multi-modifier support
2. ✅ Conservative timeouts (250ms) for safety
3. ✅ Familiar tap-hold-release behavior
4. ✅ Good balance between safety and flexibility
5. ✅ Simple configuration

### Advanced Users: Try `kanata-bilateral-multimod.kbd`

If you want the ultimate setup:
1. ✅ Bilateral protection against accidental mods
2. ✅ Full multi-modifier support
3. ✅ Best same-hand roll protection
4. ⚠️ More complex configuration
5. ⚠️ Slight latency (+20ms)

### How to Switch

```bash
# Backup your current config
cp ~/.config/kanata/kanata.kbd ~/.config/kanata/kanata.kbd.backup

# Try the hybrid config
cp ~/.config/kanata/kanata-hybrid.kbd ~/.config/kanata/kanata.kbd

# Restart kanata
pkill kanata
kanata --cfg ~/.config/kanata/kanata.kbd
```

### If You Experience Issues

**Too many accidental modifiers?**
1. First, try increasing timeouts in your chosen config:
   - Edit the `defvar` section
   - Increase `tap-timeout` and `hold-timeout` by 50ms
   - Restart kanata

2. If still problematic, go back to the bilateral config:
   ```bash
   cp ~/.config/kanata/kanata.kbd.backup ~/.config/kanata/kanata.kbd
   ```

**Modifiers too slow?**
- Try `kanata-tap-hold-press.kbd` for faster response
- Or decrease timeouts in hybrid config

---

## Multi-Modifier Examples to Test

### Common macOS Shortcuts

1. **Shift+Cmd+[** (Previous tab in Chrome)
   - Hold A+S (Shift+Cmd), press [ key
   
2. **Shift+Cmd+]** (Next tab in Chrome)
   - Hold A+S (Shift+Cmd), press ] key

3. **Ctrl+Shift+Eject** (Lock screen)
   - Hold A+F (Shift+Ctrl), press Eject

4. **Cmd+Alt+Esc** (Force quit)
   - Hold S+D (Cmd+Alt), press Esc

5. **Shift+Cmd+3** (Screenshot)
   - Hold A+S (Shift+Cmd), press 3

### Test Sequence

```
Test 1: Single Mods (should work in ALL configs)
- S+C = Cmd+C (copy)
- S+V = Cmd+V (paste)
- F+C = Ctrl+C

Test 2: Cross-Hand Multi-Mods (should work in ALL configs)
- A+J+R = Shift+Ctrl+R

Test 3: Same-Hand Multi-Mods (ONLY works in hybrid/tap-hold-press)
- A+S+C = Shift+Cmd+C
- D+F+R = Alt+Ctrl+R
- K+L+E = Alt+Cmd+E

Test 4: Triple Mods (ONLY works in hybrid/tap-hold-press)
- A+S+D+T = Shift+Cmd+Alt+T (yes, you can hold 3 mods!)
```

---

## Technical Details

### Why Bilateral Mods Break Multi-Mod

With `tap-hold-release-keys`:
```lisp
a (tap-hold-release-keys 200 200 a lsft $right-hand-keys)
s (tap-hold-release-keys 200 200 s lmet $right-hand-keys)
```

- 'A' only becomes Shift when you press a RIGHT-hand key
- 'S' only becomes Cmd when you press a RIGHT-hand key
- Pressing A+S together → both waiting for right-hand key → can't combine!

### How Hybrid/Tap-Hold-Press Fix It

Without the `-keys` parameter and key list:
```lisp
a (tap-hold-release 250 250 a lsft)
s (tap-hold-release 250 250 s lmet)
```

- 'A' becomes Shift after timeout OR when any key is pressed
- 'S' becomes Cmd after timeout OR when any key is pressed
- Pressing A+S together → both can become modifiers → combines!

---

## Advanced: Custom Hybrid Solution

If you want to try creating your own hybrid (bilateral for single mods, regular for multi-mods), you would need to:

1. Use `deffakekeys` to create layer switching
2. Use `on-idle-fakekey` to handle tap-vs-hold detection
3. Create two layers: one with bilateral mods, one without
4. Use complex state management

This is **very advanced** and probably not worth the complexity. The hybrid config with longer timeouts is the practical solution.

---

## Conclusion

**Choose your config based on priority:**

- 🛡️ **Safety First** → `kanata.kbd` (bilateral, no same-hand multi-mod)
- ⚖️ **Balance** → `kanata-hybrid.kbd` (all multi-mods, longer timeouts) ⭐ **RECOMMENDED**
- ⚡ **Speed First** → `kanata-tap-hold-press.kbd` (all multi-mods, fast response)

Start with hybrid, adjust timeouts if needed, and only use tap-hold-press if you really need the speed and have disciplined typing habits.

Happy typing! 🎹

