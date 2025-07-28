#!/usr/bin/env python3
import re

with open('ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

# Track brace depth and look for problematic areas
depth = 0
function_starts = []
for i, line in enumerate(lines):
    clean_line = re.sub(r'"[^"]*"', '""', line)
    
    # Track function starts
    if 'func ' in line and '{' in line:
        function_starts.append((i + 1, depth, line.strip()))
    
    depth += clean_line.count('{') - clean_line.count('}')
    
    # If depth becomes 0 or negative in unexpected places
    if depth == 0 and 100 < i < 8700:
        print(f"Warning: Depth 0 at line {i+1}")

# Show functions that never closed properly
open_functions = [(line_no, d, func) for line_no, d, func in function_starts if d >= 2]
if open_functions:
    print("\nFunctions with high starting depth (possibly inside other functions):")
    for line_no, depth, func in open_functions[-10:]:
        print(f"  Line {line_no} (depth {depth}): {func[:80]}")

print(f"\nFinal depth: {depth}")