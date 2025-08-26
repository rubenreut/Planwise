#!/usr/bin/env python3

def validate_swift_file(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    # Track scope
    scope_stack = []
    
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Skip empty lines and comments
        if not stripped or stripped.startswith('//'):
            continue
            
        # Track class/struct/enum/func declarations
        if any(stripped.startswith(keyword) for keyword in ['class ', 'struct ', 'enum ', 'func ', 'private func ', '@MainActor']):
            if i < 20:
                print(f"Line {i}: {stripped[:60]}...")
        
        # Check for @Published inside wrong scope
        if '@Published' in line and i < 50:
            print(f"Line {i}: Found @Published - Current scope depth: {len(scope_stack)}")
            if len(scope_stack) > 1:
                print(f"  WARNING: @Published at depth {len(scope_stack)} - should be at depth 1")
                
    print("\nChecking line 17 specifically...")
    if len(lines) > 16:
        for i in range(max(0, 10), min(25, len(lines))):
            print(f"Line {i+1}: {lines[i].rstrip()}")

validate_swift_file("/Users/rubenreut/Momentum/Momentum/Momentum/ViewModels/ChatViewModel.swift")