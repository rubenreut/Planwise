#!/usr/bin/env python3
import re

with open('Momentum/Momentum/ViewModels/ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

depth = 0
class_started = False
class_line = 0

for i, line in enumerate(lines):
    clean_line = re.sub(r'"[^"]*"', '""', line)
    
    if 'class ChatViewModel' in line:
        class_started = True
        class_line = i + 1
        print(f"Class starts at line {class_line}, depth={depth}")
    
    open_count = clean_line.count('{')
    close_count = clean_line.count('}')
    
    old_depth = depth
    depth += open_count - close_count
    
    # If we're in the class and depth returns to 0, class is closed
    if class_started and depth == 0 and old_depth > 0:
        print(f"Class appears to close at line {i+1}")
        # Check if there's more code after
        remaining_code = any(line.strip() and not line.strip().startswith('//') 
                           for line in lines[i+1:i+10])
        if remaining_code:
            print("WARNING: There's code after the class closes!")
            for j in range(i+1, min(i+10, len(lines))):
                if lines[j].strip():
                    print(f"  Line {j+1}: {lines[j].strip()[:60]}")
        break

print(f"\nFinal depth: {depth}")