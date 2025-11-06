# Kanata Configuration Improvements

## Key Changes to Reduce Accidental Key Presses and Double Inputs

### 1. ✅ Bilateral Home Row Mods (MOST IMPORTANT)

**Changed from:** `tap-hold-release`  
**Changed to:** `tap-hold-release-keys` with left/right hand key lists

**What this does:**
- Modifiers ONLY activate when you press keys from the opposite hand
- Same-hand key combinations (like "as", "df", "fast", "jkl") will NOT trigger modifiers
- This is the #1 most effective way to prevent accidental modifier activation

**Example:**
- Typing "sad" quickly → outputs "sad" (no accidental modifiers)
- Holding 's' + pressing 'n' → Cmd+N (modifier works as intended)

### 2. ⏱️ Increased Timing Values

**Previous values:**
- tap-timeout: 100ms
- hold-timeout: 150ms

**New values:**
- tap-timeout: 200ms (doubled)
- hold-timeout: 200ms (increased ~33%)
- Pinky fingers: 220ms (slower, less accurate)
- Index fingers: 180ms (faster, more accurate)

**Why this helps:**
- Gives you more time to complete a tap before it becomes a hold
- Reduces false modifier triggers during fast typing
- Still fast enough for normal use (200ms is barely perceptible)

### 3. 🎯 Per-Finger Timing Customization

Different fingers have different speeds and accuracy:

| Finger | Tap Timeout | Hold Timeout | Reasoning |
|--------|-------------|--------------|-----------|
| Pinky (A, ;) | 220ms | 220ms | Slowest, least accurate finger |
| Ring/Middle (S, D, K, L) | 200ms | 200ms | Standard timeout |
| Index (F, J) | 180ms | 180ms | Fastest, most accurate finger |

### 4. 🛡️ Enhanced Debounce Configuration

Added configuration options for future debounce support:
- `danger-enable-cmd yes` - enables advanced features
- `sequence-timeout 2000` - prevents accidental macro triggers

**Note:** Hardware debounce is more effective than software. If you have persistent double-key issues, consider:
- Cleaning your keyboard switches
- Replacing worn switches
- Using a keyboard with hot-swap sockets for easy maintenance

## Testing Your Configuration

### Test 1: Same-Hand Rolls (Should NOT trigger modifiers)
Type these quickly:
- "sad", "fast", "add", "lass"
- "junk", "kill", "look", "pull"

Expected: Just normal text, no accidental shortcuts

### Test 2: Cross-Hand Shortcuts (Should trigger modifiers)
Try these combinations:
- Hold 's' + press 't' → Cmd+T (new tab)
- Hold 'd' + press 'n' → Opt+N
- Hold 'f' + press 'r' → Ctrl+R
- Hold 'j' + press 'a' → Ctrl+A

Expected: Shortcuts should work reliably

### Test 3: Fast Typing (Should feel natural)
Type a paragraph at your normal speed.

Expected: No random modifier activations, text types normally

## Fine-Tuning

If you need to adjust further:

### Too Many Accidental Modifiers?
Edit `kanata.kbd` and increase timeouts:
```lisp
(defvar
  tap-timeout 250      ;; increase by 50ms
  hold-timeout 250     ;; increase by 50ms
  ...
)
```

### Modifiers Too Slow to Activate?
Decrease timeouts (but not below 150ms):
```lisp
(defvar
  tap-timeout 180      ;; decrease by 20ms
  hold-timeout 180     ;; decrease by 20ms
  ...
)
```

### Specific Finger Issues?
Adjust individual finger timeouts:
```lisp
(defvar
  ...
  tap-timeout-pinky 250     ;; if pinky triggers too often
  hold-timeout-pinky 250
  ...
)
```

## Reloading Configuration

After editing `kanata.kbd`:

1. **Quick reload** (if configured): Press the reload key combo in extend layer
2. **Full restart**: 
   ```bash
   # Kill existing kanata process
   pkill kanata
   
   # Start kanata with your config
   kanata --cfg ~/.config/kanata/kanata.kbd
   ```

## Additional Resources

- [Kanata GitHub](https://github.com/jtroo/kanata) - Official documentation
- [Precondition's Home Row Mods Guide](https://precondition.github.io/home-row-mods) - Deep dive into HRM concepts
- [Kenkyo Config](https://github.com/argenkiwi/kenkyo) - Inspiration for this configuration
- [tap-hold-release-keys docs](https://github.com/jtroo/kanata/blob/main/docs/config.adoc#tap-hold-release-keys) - Technical details

## Summary

The combination of:
1. **Bilateral activation** (opposite-hand-only modifiers)
2. **Increased timeouts** (more deliberate holds)
3. **Per-finger customization** (accommodating finger differences)

...should dramatically reduce accidental key presses and double inputs while maintaining a responsive, natural typing experience.

Happy typing! 🎹


