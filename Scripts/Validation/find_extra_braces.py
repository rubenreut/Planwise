#!/usr/bin/env python3
import re

with open('ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

depth = 0
for i, line in enumerate(lines):
    clean_line = re.sub(r'"[^"]*"', '""', line)
    
    open_count = clean_line.count('{')
    close_count = clean_line.count('}')
    
    old_depth = depth
    depth += open_count - close_count
    
    # If depth goes negative, we have extra closing braces
    if depth < 0:
        print(f"Line {i+1}: Extra closing brace detected (depth went from {old_depth} to {depth})")
        print(f"  {line.strip()}")