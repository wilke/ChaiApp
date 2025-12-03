#!/bin/bash
# Validate Chai-Lab prediction output
# Usage: ./validate_output.sh <output_directory>

set -e

OUTPUT_DIR="${1:-.}"

echo "Validating Chai-Lab output in: $OUTPUT_DIR"

ERRORS=0

# Check for structure files (CIF or PDB)
CIF_FILES=$(find "$OUTPUT_DIR" -name "*.cif" 2>/dev/null | wc -l)
PDB_FILES=$(find "$OUTPUT_DIR" -name "*.pdb" 2>/dev/null | wc -l)

if [ "$CIF_FILES" -gt 0 ] || [ "$PDB_FILES" -gt 0 ]; then
    echo "[OK] Structure file(s) found: $CIF_FILES CIF, $PDB_FILES PDB"
else
    echo "[FAIL] No structure files found"
    ERRORS=$((ERRORS + 1))
fi

# Check for scores/confidence files
SCORE_FILES=$(find "$OUTPUT_DIR" -name "scores*.json" -o -name "*confidence*.json" 2>/dev/null | wc -l)
if [ "$SCORE_FILES" -gt 0 ]; then
    echo "[OK] Score/confidence file(s) found: $SCORE_FILES"
else
    echo "[WARN] No score/confidence files found"
fi

# List all output files
echo ""
echo "Output files:"
find "$OUTPUT_DIR" -type f -name "*.cif" -o -name "*.pdb" -o -name "*.json" 2>/dev/null | head -20

# Summary
echo ""
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo "Validation PASSED"
    exit 0
else
    echo "Validation FAILED with $ERRORS error(s)"
    exit 1
fi
