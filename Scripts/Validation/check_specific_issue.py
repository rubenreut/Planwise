#!/usr/bin/env python3
import re

with open('Momentum/Momentum/ViewModels/ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

# Look for specific patterns that might indicate missing braces
for i in range(len(lines) - 1):
    line = lines[i].strip()
    next_line = lines[i+1].strip() if i < len(lines) - 1 else ""
    
    # Check for guard statements without closing brace
    if line.endswith(')') and 'return FunctionCallResult' in line:
        if next_line and not next_line.startswith('}') and 'guard' not in next_line and 'let' not in next_line:
            # Check if this is inside a guard statement
            # Look back for guard
            found_guard = False
            for j in range(max(0, i-10), i):
                if 'guard ' in lines[j]:
                    found_guard = True
                    break
            
            if found_guard and next_line and not next_line.startswith('}'):
                print(f"Line {i+2}: Possible missing closing brace after guard return")
                print(f"  Current line: {line[:80]}")
                print(f"  Next line: {next_line[:80]}")