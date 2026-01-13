# ChaiApp Acceptance Test Results

**Date:** 2026-01-13
**Container:** `dxkb/chai-bvbrc:latest-gpu`
**Platform:** 8x NVIDIA H100 NVL (lambda13)

---

## Test Summary

| Test | Description | Status |
|:----:|-------------|:------:|
| 1 | Service Script Syntax Check | ✅ PASS |
| 2 | Simple Protein via BV-BRC Workspace | ✅ PASS |
| 3 | Protein-Ligand with Constraints | ⚠️ BLOCKED |
| 4 | Multimer via Service Script | ✅ PASS |
| 5 | Templates Server Option | ✅ PASS |
| 6 | Multiple Samples | ✅ PASS |
| 7 | Error Handling - Missing Input | ✅ PASS |

**Result: 6/7 Tests Passed** (1 blocked by known issue)

---

## Test Details

### Test 1: Service Script Syntax Check ✅
```
App-ChaiLab.pl syntax OK
```

### Test 2: Simple Protein (Workspace) ✅
- **Input:** 384 residue protein from BV-BRC workspace
- **MSA depth:** 2,134 sequences
- **Score:** 0.1809
- **Output:** `pred.model_idx_0.cif`

### Test 3: Protein-Ligand with Constraints ⚠️
- **Blocked by:** Issue #7 (`--constraints` → `--constraint-path`)
- Container rebuild required

### Test 4: Multimer Prediction ✅
- **Input:** 2-chain homodimer (768 total residues)
- **Score:** 0.8886
- **Chains detected:** protein|A, protein|B

### Test 5: Templates Server ✅
- **Template hits found:** 287
- **Templates server:** ColabFold API
- Verified downloading from RCSB PDB

### Test 6: Multiple Samples ✅
- **Samples requested:** 3
- **CLI:** `--num-diffn-samples 3`
- **Outputs:**
  - `pred.model_idx_0.cif` (Score=0.1804)
  - `pred.model_idx_1.cif` (Score=0.1808)
  - `pred.model_idx_2.cif` (Score=0.1808)

### Test 7: Error Handling ✅
- **Test:** Missing input file
- **Response:** `Workspace object not found for '/awilke@bvbrc/home/.../nonexistent.fasta'`

---

## Acceptance Criteria

> **Minimum for acceptance:** Tests 1-4 and 7 pass.

| Requirement | Status |
|-------------|:------:|
| Test 1 (Syntax) | ✅ |
| Test 2 (Simple Protein) | ✅ |
| Test 3 (Constraints) | ⚠️ Known Issue |
| Test 4 (Multimer) | ✅ |
| Test 7 (Error Handling) | ✅ |

**Acceptance: CONDITIONAL PASS** (pending Issue #7 fix)

---

## Open Issues

| Issue | Title | Impact |
|:-----:|-------|--------|
| [#7](https://github.com/wilke/ChaiApp/issues/7) | CLI option mismatches | Blocks constraints |
| [#8](https://github.com/wilke/ChaiApp/issues/8) | Workspace permissions | Output folder errors |
| [#9](https://github.com/wilke/ChaiApp/issues/9) | Non-empty output directory | Requires TMPDIR workaround |

---

## Next Steps

1. Rebuild container with Issue #7 fixes
2. Re-run Test 3 (Protein-Ligand with Constraints)
3. Address Issue #9 in service script
