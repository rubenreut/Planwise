#!/usr/bin/env python3

import re

def analyze_structure(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    brace_count = 0
    current_function = None
    function_stack = []
    issues = []
    
    for i, line in enumerate(lines):
        # Skip comment lines
        if line.strip().startswith('//'):
            continue
            
        # Remove string literals to avoid counting braces in strings
        clean_line = re.sub(r'"[^"]*"', '""', line)
        
        # Count braces
        open_braces = clean_line.count('{')
        close_braces = clean_line.count('}')
        
        # Check for function declarations
        func_match = re.search(r'(private |public |internal )?\s*func\s+(\w+)', line)
        if func_match and '{' in line:
            func_name = func_match.group(2)
            function_stack.append({
                'name': func_name,
                'line': i + 1,
                'start_depth': brace_count
            })
            current_function = func_name
        
        # Update brace count
        brace_count += open_braces - close_braces
        
        # Check if we closed a function
        if function_stack and brace_count <= function_stack[-1]['start_depth']:
            closed_func = function_stack.pop()
            # Check if this function was closed too early or too late
            if i - closed_func['line'] < 3:  # Function closed too quickly
                issues.append(f"Line {i+1}: Function '{closed_func['name']}' might be empty or missing body")
            current_function = function_stack[-1]['name'] if function_stack else None
        
        # Check for issues
        if brace_count < 0:
            issues.append(f"Line {i+1}: Extra closing brace (depth went negative)")
        
        # Check if we're too deep
        if brace_count > 5:  # Unusually deep nesting
            issues.append(f"Line {i+1}: Very deep nesting (depth={brace_count})")
    
    # Report unclosed functions
    for func in function_stack:
        issues.append(f"Function '{func['name']}' starting at line {func['line']} was never closed")
    
    print(f"Final brace count: {brace_count} (should be 0)")
    print(f"\nFound {len(issues)} potential issues:\n")
    for issue in issues[:20]:  # Show first 20 issues
        print(f"  - {issue}")
    
    if len(issues) > 20:
        print(f"  ... and {len(issues) - 20} more issues")
    
    # Find where class should close
    print("\n\nAnalyzing class structure:")
    class_depth = 0
    for i, line in enumerate(lines):
        clean_line = re.sub(r'"[^"]*"', '""', line)
        class_depth += clean_line.count('{') - clean_line.count('}')
        
        if 'class ChatViewModel' in line:
            print(f"Class starts at line {i+1}")
        
        if class_depth == 0 and i > 100:  # After class started
            print(f"Class appears to close at line {i+1}")
            # Check if there's more code after
            remaining_code = any(line.strip() and not line.strip().startswith('//') 
                               for line in lines[i+1:])
            if remaining_code:
                print("WARNING: There's code after the class closes!")
            break

if __name__ == "__main__":
    analyze_structure("/Users/rubenreut/Momentum/Momentum/Momentum/ViewModels/ChatViewModel.swift")