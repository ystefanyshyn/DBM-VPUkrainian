#!/bin/bash

# DBM-VPUkrainian TOC Metadata Sync Script
# Fetches metadata from DBM-Voicepack-Demo and updates all Ukrainian .toc files
# Updates: Interface versions and X-DBM-Voice-Version
# Preserves: Author, Version, Voice names, and other Ukrainian-specific settings

set -e -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEMO_REPO_API="https://api.github.com/repos/DeadlyBossMods/DBM-Voicepack-Demo/contents/DBM-VPDemo"
TEMP_DIR="/tmp/dbm_sync_$$"

echo "=========================================="
echo "DBM TOC Metadata Sync Tool"
echo "=========================================="
echo ""

mkdir -p "$TEMP_DIR"

# Function to extract metadata from TOC file
extract_metadata() {
    local file=$1
    local key=$2
    grep "^## ${key}:" "$file" 2>/dev/null | sed "s/^## ${key}:\s*//" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g' || true
}

# Download the Demo repository's TOC files via GitHub API
echo "[1/4] Fetching Demo repository TOC files..."

# Get list of TOC files in the Demo repo
TOC_FILES=$(curl -sS "$DEMO_REPO_API" | grep -oE '"name": "DBM-VPDemo[^"]*\.toc"' | sed 's/"name": "//g' | sed 's/"//g')

if [ -z "$TOC_FILES" ]; then
    echo "Error: Could not find TOC files in Demo repository"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "  → Found Demo TOC files:"
echo "$TOC_FILES" | sed 's/^/      /g'
echo ""

# Download all Demo TOC files for metadata extraction
echo "[2/4] Downloading Demo TOC files..."
for demo_toc in $TOC_FILES; do
    demo_url="https://raw.githubusercontent.com/DeadlyBossMods/DBM-Voicepack-Demo/master/DBM-VPDemo/$demo_toc"
    if ! curl -sS "$demo_url" -o "$TEMP_DIR/$demo_toc"; then
        echo "Warning: Failed to download $demo_toc"
    else
        echo "  → Downloaded: $demo_toc"
    fi
done
echo ""

# Find all Ukrainian TOC files
echo "[3/4] Finding Ukrainian TOC files..."
UKRAINIAN_TOCS=$(find "$PROJECT_ROOT" -maxdepth 1 -name "DBM-VPUkrainian*.toc" -type f)

if [ -z "$UKRAINIAN_TOCS" ]; then
    echo "Error: No Ukrainian TOC files found in $PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "  → Found Ukrainian TOC files:"
echo "$UKRAINIAN_TOCS" | sed 's/^/      /g'
echo ""

# Function to find matching Demo TOC file
find_demo_toc() {
    local ukrainian_toc=$1
    local basename=$(basename "$ukrainian_toc")
    
    # Map Ukrainian TOC names to Demo TOC names
    # Note: Demo repo uses underscores in all TOC filenames
    if [[ "$basename" == *"-Mainline.toc" ]] || [[ "$basename" == *"_Mainline.toc" ]]; then
        echo "DBM-VPDemo_Mainline.toc"
    elif [[ "$basename" == *"-Cata.toc" ]] || [[ "$basename" == *"_Cata.toc" ]]; then
        echo "DBM-VPDemo_Cata.toc"
    elif [[ "$basename" == *"-Wrath.toc" ]] || [[ "$basename" == *"_Wrath.toc" ]]; then
        echo "DBM-VPDemo_Wrath.toc"
    elif [[ "$basename" == *"-TBC.toc" ]] || [[ "$basename" == *"_TBC.toc" ]]; then
        echo "DBM-VPDemo_TBC.toc"
    elif [[ "$basename" == *"-Vanilla.toc" ]] || [[ "$basename" == *"_Vanilla.toc" ]]; then
        echo "DBM-VPDemo_Vanilla.toc"
    elif [[ "$basename" == *"_Mists.toc" ]] || [[ "$basename" == *"-Mists.toc" ]]; then
        echo "DBM-VPDemo_Mists.toc"
    else
        # No match found - return empty string
        echo ""
    fi
}

# Update each Ukrainian TOC file
echo "[4/4] Updating Ukrainian TOC files..."
echo ""

UPDATED_COUNT=0
for toc_file in $UKRAINIAN_TOCS; do
    toc_basename=$(basename "$toc_file")
    echo "  Processing: $toc_basename"
    
    # Find corresponding Demo TOC file
    DEMO_TOC=$(find_demo_toc "$toc_file")
    
    if [ -z "$DEMO_TOC" ]; then
        echo "    ⚠️  Warning: No matching pattern found for $toc_basename"
        echo "    ✗ Skipping"
        echo ""
        continue
    fi
    
    DEMO_TOC_PATH="$TEMP_DIR/$DEMO_TOC"
    
    if [ ! -f "$DEMO_TOC_PATH" ]; then
        echo "    ⚠️  Warning: Could not find Demo TOC file ($DEMO_TOC)"
        echo "       Looking in: $TEMP_DIR"
        echo "       Available files:"
        ls -1 "$TEMP_DIR/" 2>/dev/null | sed 's/^/         /'
        echo "    ✗ Skipping"
        echo ""
        continue
    fi
    
    echo "    → Matched with: $DEMO_TOC"
    
    # Extract metadata from Demo TOC
    DEMO_VOICE_VERSION=$(extract_metadata "$DEMO_TOC_PATH" "X-DBM-Voice-Version")
    DEMO_INTERFACE=$(extract_metadata "$DEMO_TOC_PATH" "Interface")
    
    # Extract current metadata from Ukrainian TOC
    CURRENT_VOICE_VERSION=$(extract_metadata "$toc_file" "X-DBM-Voice-Version")
    CURRENT_INTERFACE=$(extract_metadata "$toc_file" "Interface")
    
    # Debug output
    echo "    → Demo Voice Version: [$DEMO_VOICE_VERSION]"
    echo "    → Current Voice Version: [$CURRENT_VOICE_VERSION]"
    echo "    → Demo Interface: [$DEMO_INTERFACE]"
    echo "    → Current Interface: [$CURRENT_INTERFACE]"
    
    CHANGES_MADE=false
    
    # Update X-DBM-Voice-Version if different
    if [ "$CURRENT_VOICE_VERSION" != "$DEMO_VOICE_VERSION" ]; then
        echo "    → Updating X-DBM-Voice-Version: $CURRENT_VOICE_VERSION → $DEMO_VOICE_VERSION"
        
        set +e  # Temporarily disable exit on error
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^## X-DBM-Voice-Version:.*$/## X-DBM-Voice-Version: $DEMO_VOICE_VERSION/" "$toc_file"
        else
            sed -i "s/^## X-DBM-Voice-Version:.*$/## X-DBM-Voice-Version: $DEMO_VOICE_VERSION/" "$toc_file"
        fi
        SED_EXIT=$?
        set -e  # Re-enable exit on error
        
        if [ $SED_EXIT -eq 0 ]; then
            CHANGES_MADE=true
        else
            echo "    ⚠️  Warning: Failed to update X-DBM-Voice-Version in $toc_basename"
        fi
    fi
    
    # Update Interface versions if different (or if current is empty)
    if [ -z "$CURRENT_INTERFACE" ] || [ "$CURRENT_INTERFACE" != "$DEMO_INTERFACE" ]; then
        echo "    → Updating Interface: $CURRENT_INTERFACE → $DEMO_INTERFACE"
        
        set +e  # Temporarily disable exit on error
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^## Interface:.*$/## Interface: $DEMO_INTERFACE/" "$toc_file"
        else
            sed -i "s/^## Interface:.*$/## Interface: $DEMO_INTERFACE/" "$toc_file"
        fi
        SED_EXIT=$?
        set -e  # Re-enable exit on error
        
        if [ $SED_EXIT -eq 0 ]; then
            CHANGES_MADE=true
            echo "    ✓ Interface updated"
        else
            echo "    ⚠️  Warning: Failed to update Interface in $toc_basename (sed returned $SED_EXIT)"
        fi
    fi
    
    if [ "$CHANGES_MADE" = true ]; then
        ((UPDATED_COUNT++))
        echo "    ✓ Updated successfully"
    else
        echo "    ✓ Already up to date"
    fi
    
    echo ""
done

# Clean up
rm -rf "$TEMP_DIR"

# Summary
echo "=========================================="
echo "SYNC COMPLETE"
echo "=========================================="
echo ""
echo "TOC files processed:  $(echo "$UKRAINIAN_TOCS" | wc -l | tr -d ' ')"
echo "TOC files updated:    $UPDATED_COUNT"
echo ""

if [ $UPDATED_COUNT -gt 0 ]; then
    echo "✓ Metadata sync completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes with: git diff"
    echo "  2. Test your addon in-game"
    echo "  3. Commit the changes if everything works correctly"
else
    echo "✓ All TOC files are already synchronized with Demo repository"
fi

echo ""
