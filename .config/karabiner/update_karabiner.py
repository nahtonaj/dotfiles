#!/usr/bin/env python3
"""Update karabiner.json with bilateral home row mod rules."""

import json

def main():
    # Load the karabiner.json file
    with open('karabiner.json', 'r') as f:
        config = json.load(f)

    # Load the generated bilateral rules
    with open('bilateral_rules.json', 'r') as f:
        new_rules = json.load(f)

    # Find and replace the bilateral rules in the first profile
    profile = config['profiles'][0]
    rules = profile['complex_modifications']['rules']

    # Remove all existing bilateral rules
    rules_to_remove = []
    for i, rule in enumerate(rules):
        desc = rule.get('description', '')
        if any(keyword in desc for keyword in ['Bilateral', 'bilateral', 'Home row mods', 'Rollover protection']):
            rules_to_remove.append(i)

    # Remove in reverse order to maintain indices
    for i in reversed(rules_to_remove):
        rules.pop(i)

    # Add new rules
    rules.extend(new_rules)

    # Write back to karabiner.json
    with open('karabiner.json', 'w') as f:
        json.dump(config, f, indent=4)

    # Calculate statistics
    total_manipulators = sum(len(rule['manipulators']) for rule in new_rules)
    print(f"✓ Updated karabiner.json with bilateral home row mods")
    print(f"✓ Added {len(new_rules)} rule sets:")
    for rule in new_rules:
        print(f"  - {rule['description']}: {len(rule['manipulators'])} rules")
    print(f"✓ Total: {total_manipulators} manipulator rules")
    print(f"✓ Rollover threshold: 80ms")
    print(f"\nNew modifier layout:")
    print(f"  Left:  A=Shift, S=Cmd, D=Alt, F=Ctrl")
    print(f"  Right: J=Ctrl,  K=Alt, L=Cmd, ;=Shift")

if __name__ == "__main__":
    main()
