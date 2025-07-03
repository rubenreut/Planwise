#!/bin/bash

# Create a new directory for legal documents
mkdir -p Planwise-legal
cd Planwise-legal

# Copy the HTML files
cp ../privacy-policy.html .
cp ../terms-of-service.html .

# Initialize git repository
git init

# Add the files
git add privacy-policy.html terms-of-service.html

# Create initial commit
git commit -m "Add privacy policy and terms of service"

# Add the remote repository
git remote add origin https://github.com/rubenreut/Planwise-legal.git

# Set branch to main
git branch -M main

# Push to GitHub
git push -u origin main

echo "✅ Files uploaded to GitHub!"
echo "🔧 Now enable GitHub Pages:"
echo "1. Go to https://github.com/rubenreut/Planwise-legal/settings/pages"
echo "2. Under 'Source', select 'Deploy from a branch'"
echo "3. Select 'main' branch and '/ (root)' folder"
echo "4. Click Save"
echo ""
echo "Your URLs will be:"
echo "- https://rubenreut.github.io/Planwise-legal/privacy-policy.html"
echo "- https://rubenreut.github.io/Planwise-legal/terms-of-service.html"