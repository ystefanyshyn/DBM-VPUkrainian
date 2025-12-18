#!/bin/bash

# DBM-VPUkrainian Voice Files Comparison Script
# Compares voice files in this repository against the DBM-Voicepack-Demo reference
# to identify which files are missing and need to be recorded in Ukrainian

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEMO_REPO_URL="https://raw.githubusercontent.com/DeadlyBossMods/DBM-Voicepack-Demo/master/DBM-VPDemo"
VOICE_TEXT_URL="${DEMO_REPO_URL}/%21VoiceText.txt"
TEMP_FILE="/tmp/dbm_voicetext_$$.txt"

echo "=========================================="
echo "DBM Voice Pack Comparison Tool"
echo "=========================================="
echo ""

# Download the latest VoiceText.txt from Demo repo
echo "[1/3] Downloading latest voice file reference from Demo repository..."
if ! curl -sS "$VOICE_TEXT_URL" -o "$TEMP_FILE"; then
    echo "Error: Failed to download VoiceText.txt from Demo repository"
    exit 1
fi

# Extract all voice file names from the VoiceText.txt
# Format is: "filename" => "description"
echo "[2/3] Extracting voice file references..."
VOICE_FILES=$(grep -oE '"[^"]+"\s*=>' "$TEMP_FILE" | sed 's/"//g' | sed 's/\s*=>//g' | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g' | sort | uniq)

# Count totals
TOTAL_FILES=$(echo "$VOICE_FILES" | wc -l | tr -d ' ')
echo "  → Found $TOTAL_FILES unique voice files in Demo reference"

# Check which files exist in our repository
echo "[3/3] Checking Ukrainian repository for existing files..."
echo "  → Project root: $PROJECT_ROOT"
echo ""

MISSING_COUNT=0
EXISTING_COUNT=0
MISSING_FILES=""
MISSING_FILES_SIMPLE=""

# Debug: show first few filenames being checked
DEBUG_COUNT=0

while IFS= read -r filename; do
    # Skip empty lines
    [ -z "$filename" ] && continue
    
    # Handle special cases with folder paths
    if [[ "$filename" == *"/"* ]]; then
        # Files in subfolders (e.g., "count/1" or "Thogar/A1")
        file_path="$PROJECT_ROOT/${filename}.ogg"
    else
        # Regular root-level files
        file_path="$PROJECT_ROOT/${filename}.ogg"
    fi
    
    # Debug output for first 3 files
    if [ $DEBUG_COUNT -lt 3 ]; then
        echo "  [DEBUG] Checking: $filename -> $file_path (exists: $([ -f "$file_path" ] && echo 'YES' || echo 'NO'))"
        ((DEBUG_COUNT++))
    fi
    
    if [ -f "$file_path" ]; then
        ((EXISTING_COUNT++))
    else
        ((MISSING_COUNT++))
        MISSING_FILES+="${filename}\n"
        MISSING_FILES_SIMPLE+="${filename}.ogg "
    fi
done <<< "$VOICE_FILES"

echo ""

# Clean up
rm -f "$TEMP_FILE"

# Display results
echo "=========================================="
echo "COMPARISON RESULTS"
echo "=========================================="
echo ""
echo "Total voice files in Demo:     $TOTAL_FILES"
echo "Existing in Ukrainian repo:    $EXISTING_COUNT"
echo "Missing from Ukrainian repo:   $MISSING_COUNT"
echo ""
if [ $TOTAL_FILES -gt 0 ]; then
    COMPLETION=$(awk -v existing="$EXISTING_COUNT" -v total="$TOTAL_FILES" 'BEGIN {printf "%.1f%%", (existing/total)*100}')
    echo "Completion: $COMPLETION"
fi
echo ""

if [ $MISSING_COUNT -gt 0 ]; then
    echo "=========================================="
    echo "MISSING FILES (need Ukrainian recording)"
    echo "=========================================="
    echo ""
    echo -e "$MISSING_FILES" | head -50
    
    if [ $MISSING_COUNT -gt 50 ]; then
        echo "..."
        echo "(Showing first 50 of $MISSING_COUNT missing files)"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "To save full list to a file, run:"
    echo "  $0 > missing_voices.txt"
    echo "----------------------------------------"
else
    echo "✓ All voice files from Demo repository are present!"
fi

echo ""
