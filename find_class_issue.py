#!/usr/bin/env python3
import re

with open('Momentum/Momentum/ViewModels/ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

depth = 0
class_depth = None
for i, line in enumerate(lines):
    clean_line = re.sub(r'"[^"]*"', '""', line)
    
    if 'class ChatViewModel' in line:
        class_depth = depth
        print(f"Class starts at line {i+1}, depth={depth}")
    
    open_count = clean_line.count('{')
    close_count = clean_line.count('}')
    depth += open_count - close_count
    
    # If we're tracking class depth and it closes
    if class_depth is not None and depth == class_depth and i > 100:
        # Check next few lines to see if there are more class methods
        has_methods = False
        for j in range(i+1, min(i+10, len(lines))):
            if 'private func' in lines[j] or 'func ' in lines[j]:
                has_methods = True
                break
        
        if has_methods:
            print(f"WARNING: Class appears to close at line {i+1} but there are methods after!")
            print(f"Current line: {line.strip()[:80]}")
            # Look for what might be causing early closure
            for j in range(max(0, i-20), i):
                if lines[j].strip() == '}':
                    check_depth = 0
                    for k in range(j):
                        clean = re.sub(r'"[^"]*"', '""', lines[k])
                        check_depth += clean.count('{') - clean.count('}')
                    print(f"  Possible extra brace at line {j+1}, depth there: {check_depth}")
            break