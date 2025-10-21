# Kanata Configuration - Bilateral Home Row Mods

This configuration implements home row modifiers with bilateral combo support, inspired by the [kenkyo configuration](https://github.com/argenkiwi/kenkyo).

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

### Left Hand
- **A** = Tap: a | Hold: Command (⌘)
- **S** = Tap: s | Hold: Option (⌥)
- **D** = Tap: d | Hold: Shift (⇧)
- **F** = Tap: f | Hold: Control (⌃)

### Right Hand
- **J** = Tap: j | Hold: Control (⌃)
- **K** = Tap: k | Hold: Shift (⇧)
- **L** = Tap: l | Hold: Option (⌥)
- **;** = Tap: ; | Hold: Command (⌘)

### Timing
- **Tap timeout**: 200ms - If you release within 200ms, it's a tap
- **Hold timeout**: 500ms - If you hold longer than 200ms, it becomes a modifier

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
- Increase the `tap-timeout` value (try 250ms)
- Decrease the `hold-timeout` value (try 400ms)

### Combos Not Triggering
- Increase the `chord-timeout` value (try 100ms)
- Practice pressing both keys more simultaneously

## References

- [Kanata Documentation](https://github.com/jtroo/kanata)
- [Kenkyo Configuration](https://github.com/argenkiwi/kenkyo)
- [Home Row Mods Guide](https://precondition.github.io/home-row-mods)
