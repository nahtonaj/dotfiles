# Bilateral Home Row Mods Configuration

## Overview
Your Karabiner-Elements configuration uses **bilateral home row mods with 80ms activation threshold**. Modifiers only activate when:
1. You hold a home row key for 80ms
2. AND press a key from the opposite hand

This prevents accidental activations while still feeling responsive.

## Key Features
- **80ms activation threshold**: Modifier activates after holding for 80ms
- **Bilateral requirement**: Must use opposite hands for combos
- **Works with ALL keys**: Alpha, special keys (Tab, Esc), arrows, function keys, etc.
- **Fast typing friendly**: Tap and release within 80ms types the key normally

## Modifier Mappings

### Left Hand (A-S-D-F) - GACS Layout
- **A** = Shift (when held with right hand keys)
- **S** = Cmd (when held with right hand keys)
- **D** = Alt/Option (when held with right hand keys)
- **F** = Ctrl (when held with right hand keys)

### Right Hand (J-K-L-;) - GACS Layout
- **J** = Ctrl (when held with left hand keys)
- **K** = Alt/Option (when held with left hand keys)
- **L** = Cmd (when held with left hand keys)
- **;** = Shift (when held with left hand keys)

## How It Works

### Bilateral Activation
Modifiers **only** work when combining opposite hands:
- Hold **F** (left) + press **Y** (right) = Ctrl+Y
- Hold **J** (right) + press **Q** (left) = Ctrl+Q
- Hold **S** (left) + press **N** (right) = Cmd+N
- Hold **A** (left) + press **U** (right) = Shift+U (capital U)

### Rollover Protection (80ms threshold)
The configuration handles fast typing naturally:
- If you press a home row key and release it within 80ms without pressing an opposite-hand key, it types normally
- If you press a home row key and then press an opposite-hand key within 80ms, it applies the modifier
- This allows for natural typing overlap that occurs during fast typing

### Normal Typing
When typing normally:
- Pressing **A** alone = types 'a'
- Pressing **S** alone = types 's'
- Fast typing (like typing "as") works naturally even if keys overlap slightly

### Why Bilateral with Rollover Protection?
1. **No Accidental Activations**: Can't accidentally trigger modifiers while typing normally
2. **Handles Fast Typing**: 80ms rollover threshold accommodates natural typing speed
3. **More Ergonomic**: Natural two-handed key combinations
4. **No Timing Stress**: The delay is quick enough to feel instant but handles rollover
5. **Touch-Typing Friendly**: Works naturally with proper touch-typing technique

## Testing Your Configuration

### Test Ctrl (F or J)
```
Hold F + press Y = Ctrl+Y (undo in most apps)
Hold J + press Q = Ctrl+Q (quit in most apps)
Hold F + press N = Ctrl+N (new window)
```

### Test Alt/Option (D or K)
```
Hold D + press P = Alt+P
Hold K + press Q = Alt+Q
Hold D + press U = Alt+U
```

### Test Cmd (S or L)
```
Hold S + press N = Cmd+N (new window in most apps)
Hold L + press Q = Cmd+Q (quit app)
Hold S + press C = Cmd+C (copy)
Hold L + press V = Cmd+V (paste)
```

### Test Shift (A or ;)
```
Hold A + press Y = Y (capital)
Hold ; + press Q = Q (capital)
Hold A + press H = H (capital)
```

### Test Fast Typing
```
Type "as" quickly = "as" (not Shift+S)
Type "asd" quickly = "asd" (not Shift+D)
Type "fast" quickly = "fast" (no modifiers triggered)
```

## Configuration Files

- `karabiner.json` - Main configuration with bilateral rules
- `generate_bilateral.py` - Script to generate bilateral rules
- `update_karabiner.py` - Script to update karabiner.json with new rules

## Regenerating Configuration

If you need to modify the bilateral rules:

```bash
cd ~/.config/karabiner
python3 generate_bilateral.py > bilateral_rules.json
python3 update_karabiner.py
```

## Rules Breakdown

The configuration includes 3 rule sets with 200 total manipulator rules:

1. **Bilateral Home Row Mods with Rollover Protection** (8 rules)
   - Tracks when home row keys (A/S/D/F/J/K/L/;) are held
   - Sets up delayed activation with 80ms threshold
   - Manages state variables for rollover detection

2. **Bilateral Combos - Apply Modifiers** (184 rules)
   - Applies appropriate modifiers when opposite-hand keys are pressed
   - Left hand modifiers × Right hand keys = 92 rules
   - Right hand modifiers × Left hand keys = 92 rules
   - Automatically cancels the "alone" state when combo is detected

3. **Rollover Protection for Home Row Keys** (8 rules)
   - Handles cases where keys are pressed and released quickly
   - Outputs the key normally if no opposite-hand key was pressed within threshold
   - Ensures fast typing doesn't get interpreted as modifier attempts

## Tips

1. **Start Slow**: Practice simple combinations like Cmd+C (S+C or L+C)
2. **Use Both Sides**: You can use either hand for the modifier (e.g., Cmd+C = S+C or L+V)
3. **Minimal Timing Required**: 80ms is very fast - just hold the modifier slightly before pressing the other key
4. **Natural Flow**: Works best with touch-typing where hands naturally alternate
5. **Common Shortcuts**:
   - Copy: S+C (left Cmd) or L+C (right Cmd)
   - Paste: S+V (left Cmd) or L+V (right Cmd)
   - Undo: F+Z (left Ctrl) or J+Z (right Ctrl)
   - Save: S+S... wait, that won't work! Use L+S (right Cmd + left S)
6. **Adjust Threshold**: If 80ms doesn't feel right, edit `ROLLOVER_THRESHOLD` in generate_bilateral.py

## Troubleshooting

### Modifiers not working?
1. Make sure Karabiner-Elements is running
2. Check that the "Bilateral Home Row Mods" rule is enabled in Karabiner-Elements preferences
3. Restart Karabiner-Elements: `System Preferences > Extensions > Karabiner-Elements`

### Keys typing instead of acting as modifiers?
This is normal for bilateral mode! The modifier only activates when:
- You hold the home row key AND
- Press a key from the opposite hand

### Want to go back to traditional home row mods?
Check the `automatic_backups` directory for previous configurations.
