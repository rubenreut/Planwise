#!/usr/bin/env python3

def find_brace_mismatches(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    brace_stack = []
    for line_num, line in enumerate(lines, 1):
        # Skip comments and strings
        in_string = False
        in_comment = False
        escaped = False
        
        i = 0
        while i < len(line):
            if escaped:
                escaped = False
                i += 1
                continue
                
            if line[i] == '\\':
                escaped = True
                i += 1
                continue
            
            # Check for comments
            if i < len(line) - 1 and line[i:i+2] == '//':
                break  # Rest of line is comment
                
            # Check for strings
            if line[i] == '"' and not in_string:
                in_string = True
            elif line[i] == '"' and in_string:
                in_string = False
            
            if not in_string and not in_comment:
                if line[i] == '{':
                    brace_stack.append((line_num, i, line.strip()))
                elif line[i] == '}':
                    if brace_stack:
                        brace_stack.pop()
                    else:
                        print(f"ERROR: Extra closing brace at line {line_num}:")
                        print(f"  {line.strip()}")
                        print()
            
            i += 1
    
    if brace_stack:
        print(f"\nFound {len(brace_stack)} unclosed braces:")
        print("-" * 80)
        for line_num, col, line_content in brace_stack[-10:]:  # Show last 10
            print(f"Line {line_num}: {line_content}")
        print("-" * 80)
        print(f"\nTotal unclosed braces: {len(brace_stack)}")
        
        # Show context around the first few unclosed braces
        print("\nContext for first unclosed braces:")
        for line_num, col, line_content in brace_stack[:3]:
            print(f"\n=== Unclosed brace at line {line_num} ===")
            start = max(0, line_num - 3)
            end = min(len(lines), line_num + 3)
            for i in range(start, end):
                marker = " >>> " if i == line_num - 1 else "     "
                print(f"{marker}{i+1}: {lines[i].rstrip()}")

if __name__ == "__main__":
    find_brace_mismatches("/Users/rubenreut/Momentum/Momentum/Momentum/ViewModels/ChatViewModel.swift")