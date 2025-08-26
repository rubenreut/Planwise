#!/usr/bin/env python3
import re

with open('ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

# Find functions and track their depth
depth = 0
in_function = None
function_start_depth = None

for i, line in enumerate(lines):
    clean_line = re.sub(r'"[^"]*"', '""', line)
    
    # Check for function starts
    if re.search(r'(private |public )?func ', line):
        if in_function and depth > function_start_depth:
            print(f"Warning: Function '{in_function}' may not be closed before line {i+1}")
        
        match = re.search(r'func\s+(\w+)', line)
        if match:
            in_function = match.group(1)
            function_start_depth = depth
    
    # Update depth
    open_count = clean_line.count('{')
    close_count = clean_line.count('}')
    depth += open_count - close_count
    
    # Special check for lines around 8330 where depth increases to 3
    if 8325 <= i <= 8335:
        print(f"Line {i+1} depth={depth}: {line.strip()[:80]}")