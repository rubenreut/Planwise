#!/usr/bin/env python3
import re

with open('Momentum/Momentum/ViewModels/ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

# Track brace depth
depth = 0
class_start_line = None
class_start_depth = None

for i, line in enumerate(lines):
    # Remove string literals to avoid false matches
    clean_line = re.sub(r'"[^"]*"', '""', line)
    clean_line = re.sub(r"'[^']*'", "''", clean_line)
    
    # Check for class declaration
    if 'class ChatViewModel' in line and class_start_line is None:
        class_start_line = i + 1
        class_start_depth = depth
        print(f"Class ChatViewModel starts at line {class_start_line}")
    
    # Count braces
    open_braces = clean_line.count('{')
    close_braces = clean_line.count('}')
    depth += open_braces - close_braces
    
    # Check if we're back to the class starting depth
    if class_start_line and depth == class_start_depth and i > class_start_line:
        # Check if this could be the class end
        # Look ahead to see if there are more class methods
        has_class_content = False
        for j in range(i+1, min(i+10, len(lines))):
            if 'private func' in lines[j] or 'func ' in lines[j]:
                has_class_content = True
                break
        
        if not has_class_content:
            print(f"Class ChatViewModel ends at line {i+1}")
            break
        else:
            print(f"Warning: Depth returned to {class_start_depth} at line {i+1} but there are more methods after")

print(f"\nFinal depth: {depth}")

# Double check by finding the actual closing brace
for i in range(len(lines)-1, 0, -1):
    if lines[i].strip() == '}' and '// MARK: - Extensions' in lines[i+1]:
        print(f"\nActual class closing brace found at line {i+1}")