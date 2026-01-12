#!/usr/bin/env python3
"""Generate bilateral home row mods using Karabiner's modifier system."""

import json

# Modifier mappings - Layout: A=Shift, S=Cmd, D=Alt, F=Ctrl
LEFT_MODS = {
    "a": {"modifier": "left_shift", "display": "Shift"},
    "s": {"modifier": "left_command", "display": "Cmd"},
    "d": {"modifier": "left_option", "display": "Alt"},
    "f": {"modifier": "left_control", "display": "Ctrl"}
}

RIGHT_MODS = {
    "j": {"modifier": "right_control", "display": "Ctrl"},
    "k": {"modifier": "right_option", "display": "Alt"},
    "l": {"modifier": "right_command", "display": "Cmd"},
    "semicolon": {"modifier": "right_shift", "display": "Shift"}
}

# Time threshold in milliseconds
THRESHOLD = 80

def generate_simple_bilateral():
    """Generate simple bilateral rules using Karabiner's modifier keys directly."""
    manipulators = []

    all_mods = {**LEFT_MODS, **RIGHT_MODS}

    for key, mod_info in all_mods.items():
        # Simple approach: Convert key to modifier after threshold
        # The modifier will apply to ANY subsequently pressed key
        manipulator = {
            "description": f"{key.upper()} -> {mod_info['display']} (after {THRESHOLD}ms)",
            "from": {
                "key_code": key,
                "modifiers": {"optional": ["any"]}
            },
            "to_if_alone": [
                {"key_code": key}
            ],
            "to_if_held_down": [
                {
                    "key_code": mod_info["modifier"],
                    "lazy": True
                }
            ],
            "parameters": {
                "basic.to_if_held_down_threshold_milliseconds": THRESHOLD
            },
            "type": "basic"
        }
        manipulators.append(manipulator)

    return manipulators

def main():
    """Generate configuration."""
    manipulators = generate_simple_bilateral()

    output = {
        "description": f"Bilateral Home Row Mods - {THRESHOLD}ms threshold (simplified)",
        "manipulators": manipulators
    }

    print(json.dumps([output], indent=2))

if __name__ == "__main__":
    main()
