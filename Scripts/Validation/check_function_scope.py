#!/usr/bin/env python3
with open('Momentum/Momentum/ViewModels/ChatViewModel.swift', 'r') as f:
    lines = f.readlines()

# Find the line numbers
create_event_line = None
find_best_line = None

for i, line in enumerate(lines):
    if 'private func createEvent' in line and 'async' in line:
        create_event_line = i + 1
    if 'private func findBestMatchingCategory' in line:
        find_best_line = i + 1

print(f"createEvent is at line: {create_event_line}")
print(f"findBestMatchingCategory is at line: {find_best_line}")

# Check if both are in the class
class_start = None
class_end = None
depth = 0

for i, line in enumerate(lines):
    if 'class ChatViewModel' in line:
        class_start = i + 1
        initial_depth = depth
    
    depth += line.count('{') - line.count('}')
    
    if class_start and depth == initial_depth and i > class_start + 10:
        class_end = i + 1
        break

print(f"\nClass starts at line: {class_start}")
print(f"Class ends at line: {class_end}")

if create_event_line and find_best_line:
    print(f"\ncreateEvent inside class: {class_start <= create_event_line <= class_end}")
    print(f"findBestMatchingCategory inside class: {class_start <= find_best_line <= class_end}")