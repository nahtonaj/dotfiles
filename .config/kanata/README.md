# Kanata Configuration - Bilateral Home Row Mods

This configuration implements home row modifiers with bilateral combo support, inspired by the [kenkyo configuration](https://github.com/argenkiwi/kenkyo).

## ⚠️ Multi-Modifier Support

**Note:** The default `kanata.kbd` uses bilateral home row mods which **do not support same-hand multi-modifier combinations** (like Shift+Cmd+Key). If you need multi-mod support, see:

📖 **[MULTI_MODIFIER_SOLUTIONS.md](MULTI_MODIFIER_SOLUTIONS.md)** for alternative configurations:
- `kanata-bilateral-multimod.kbd` 🌟 - **BEST**: Bilateral + multi-mod (advanced)
- `kanata-hybrid.kbd` ⭐ - **SIMPLE**: Multi-mod support with longer timeouts
- `kanata-tap-hold-press.kbd` - Fast multi-mod response

Choose based on your needs:
- **Current config** = Maximum safety, no same-hand multi-mods
- **Bilateral-multimod** = Best of both worlds (bilateral + multi-mod) 🌟
- **Hybrid config** = Multi-mod support with good safety ⭐
- **Tap-hold-press** = Fast multi-mod response, requires discipline

📖 Read **[BILATERAL_MULTIMOD_EXPLAINED.md](BILATERAL_MULTIMOD_EXPLAINED.md)** for details on the advanced config!

## Installation

### macOS

```bash
# Install Kanata via Homebrew
brew install kanata

# Or build from source
git clone https://github.com/jtroo/kanata.git
cd kanata
cargo build --release
```

### Running Kanata

```bash
# Run with the configuration file
kanata --cfg ~/.config/kanata/kanata.kbd

# Or run as a background service
kanata --cfg ~/.config/kanata/kanata.kbd &
```

For automatic startup on macOS, create a LaunchAgent:

```bash
# Create the LaunchAgent directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Create a plist file for Kanata (see below for content)
```

## Home Row Mods

The home row keys act as modifiers when held, and as regular keys when tapped:

### Left Hand (activates ONLY when pressing right-hand keys)
- **A** = Tap: a | Hold: Shift (⇧)
- **S** = Tap: s | Hold: Command (⌘)
- **D** = Tap: d | Hold: Option (⌥)
- **F** = Tap: f | Hold: Control (⌃)

### Right Hand (activates ONLY when pressing left-hand keys)
- **J** = Tap: j | Hold: Control (⌃)
- **K** = Tap: k | Hold: Option (⌥)
- **L** = Tap: l | Hold: Command (⌘)
- **;** = Tap: ; | Hold: Shift (⇧)

### Bilateral Activation (KEY FEATURE)
**This configuration uses bilateral home row mods**, which means:
- Modifiers ONLY activate when you press keys from the **opposite hand**
- Same-hand key rolls (like "as", "df", "jk") will NOT trigger modifiers
- This dramatically reduces accidental modifier activation during fast typing
- Example: Holding 'a' + pressing 'y' = Shift+Y, but 'a'+'s' = just "as"

### Timing (Optimized to Reduce Accidents)
- **Tap timeout**: 200ms (220ms for pinkies, 180ms for index fingers)
- **Hold timeout**: 200ms (220ms for pinkies, 180ms for index fingers)
- These increased timeouts reduce false modifier triggers during normal typing

## Bilateral Combos

Bilateral combos are key combinations that only trigger when keys from **opposite hands** are pressed simultaneously. This prevents accidental activation when typing normally.

### Top Row Combos
- **W + E** → Escape
- **I + O** → Backspace

### Bottom Row Combos
- **X + C** → Tab
- **Z + X** → Left Control
- **, + .** → Return/Enter
- **. + /** → Right Control

### Chord Timing
- **Chord timeout**: 50ms - Both keys must be pressed within 50ms of each other

## Layers

### Main Layer
Your default QWERTY layout with home row mods active.

### Extend Layer (Hold Space)
Navigation and cursor movement layer:
- **Arrow keys**: I/J/K/L cluster (Up/Left/Down/Right)
- **Home/End**: H/; keys
- **Page Up/Down**: U/O keys
- **Modifiers**: Home row (A/S/D/F maintain their modifier functions)

### Fumbol Layer (Hold Tab)
Function keys and symbols:
- **Numbers**: 1-0 on home row and number row
- **Symbols**: ! @ # $ % ^ & * ( ) on top row
- **Brackets/Operators**: - = [ ] \ on bottom row

## Tips for Learning

1. **Start Slowly**: Begin by just using the home row mods for common shortcuts
2. **Focus on One Hand**: Master left-hand mods (Cmd, Opt, Shift, Ctrl) first
3. **Practice Combos**: W+E for Escape is particularly useful
4. **Adjust Timing**: If you have issues with false triggers, adjust the timing variables in the config

## Customization

Edit `~/.config/kanata/kanata.kbd` to customize:

- **Timing**: Modify `tap-timeout`, `hold-timeout`, or `chord-timeout` values
- **Key Positions**: Rearrange which fingers control which modifiers
- **Additional Combos**: Add more bilateral combos in the `defchords` sections
- **Layers**: Customize the extend and fumbol layers for your workflow

## Troubleshooting

### Keys Not Working
- Make sure Kanata has accessibility permissions in System Preferences
- Check that no other keyboard customization software is running (like Karabiner)

### Accidental Modifier Activation
If you're still getting accidental modifiers:
- **Increase both timeout values together** (try tap: 250ms, hold: 250ms)
- The bilateral activation should prevent most same-hand false triggers
- Check that you're not pressing keys from opposite hands unintentionally
- For pinkies, increase `tap-timeout-pinky` and `hold-timeout-pinky` further

### Slow Modifier Response
If modifiers feel too slow to activate:
- **Decrease both timeout values together** (try tap: 150ms, hold: 150ms)
- Don't go below 150ms or you'll get more false triggers
- Index fingers can use shorter timeouts (they're faster and more accurate)

### Double Key Presses / Key Chatter
If you experience repeated characters when pressing once:
- This is a hardware issue (mechanical switch bounce)
- Your keyboard might need cleaning or switch replacement
- Software debounce in kanata has limited effectiveness for this

### Combos Not Triggering
- Increase the `chord-timeout` value (try 100ms)
- Practice pressing both keys more simultaneously
- Make sure bilateral combos are uncommented in the config

## References

- [Kanata Documentation](https://github.com/jtroo/kanata)
- [Kenkyo Configuration](https://github.com/argenkiwi/kenkyo)
- [Home Row Mods Guide](https://precondition.github.io/home-row-mods)
