# UI Team Hand-off Document: ChaiLab

**Application:** Chai-1 Molecular Structure Prediction
**App ID:** ChaiLab
**Version:** 2.1.0
**Date:** 2026-01-21

---

## Overview

ChaiLab integrates Chai-1, a state-of-the-art molecular structure prediction model, into the BV-BRC platform. This document provides all information needed for UI integration.

---

## App Specification

**Location:** `app_specs/ChaiLab.json`

### Basic Information

```json
{
    "id": "ChaiLab",
    "script": "App-ChaiLab",
    "label": "Chai-1 Molecular Structure Prediction",
    "description": "Predict molecular structures using Chai-1..."
}
```

### Parameters Summary

| Parameter | Type | Required | Default | UI Element |
|-----------|------|----------|---------|------------|
| `input_file` | wsfile | Yes | - | File picker (FASTA) |
| `constraints_file` | wsfile | No | - | File picker (JSON) |
| `use_msa_server` | bool | No | true | Checkbox |
| `use_templates_server` | bool | No | false | Checkbox |
| `num_samples` | int | No | 5 | Number input / Slider |
| `msa_files` | list:wsfile | No | - | Multi-file picker |
| `msa_directory` | folder | No | - | Folder picker |
| `template_hits_file` | wsfile | No | - | File picker (m8) |
| `output_path` | folder | Yes | - | Folder picker |
| `dry_run` | bool | No | false | Checkbox (advanced) |

---

## Parameter Details

### 1. Input File (Required)

```json
{
    "id": "input_file",
    "type": "wsfile",
    "required": 1,
    "label": "Input FASTA File",
    "desc": "Input file in FASTA format describing the molecular complex..."
}
```

**UI Considerations:**
- File picker filtered to FASTA files (`.fasta`, `.fa`, `.faa`)
- Show file preview with sequence count
- Validate: Must have at least one `>` header line

**Example Input:**
```
>protein|A
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAP...
>ligand|L
N[C@@H](Cc1ccc(O)cc1)C(=O)O
```

**Supported Entity Types:**
- `protein|<chain_id>` - Amino acid sequence
- `ligand|<chain_id>` - SMILES notation for small molecules
- `dna|<chain_id>` - DNA sequence
- `rna|<chain_id>` - RNA sequence

### 2. Constraints File (Optional)

```json
{
    "id": "constraints_file",
    "type": "wsfile",
    "required": 0,
    "label": "Constraints File (JSON)",
    "desc": "Optional JSON file specifying distance restraints..."
}
```

**UI Considerations:**
- File picker filtered to JSON files
- Consider providing a constraint builder UI
- Show constraint count after file selection

**Example Constraints:**
```json
{
    "restraints": [
        {
            "type": "pocket",
            "binder_chain": "L",
            "pocket_residues": [
                {"chain": "A", "residue": 120},
                {"chain": "A", "residue": 145}
            ],
            "max_distance": 6.0
        }
    ],
    "covalent_bonds": []
}
```

### 3. MSA Server Toggle

```json
{
    "id": "use_msa_server",
    "type": "bool",
    "default": true,
    "label": "Use MSA Server",
    "desc": "Automatically generate Multiple Sequence Alignments..."
}
```

**UI Considerations:**
- Default: ON (checked)
- Tooltip: "Recommended for best accuracy. Adds ~15-30 minutes."
- When OFF, consider prompting for pre-computed MSA files

### 4. Templates Server Toggle

```json
{
    "id": "use_templates_server",
    "type": "bool",
    "default": false,
    "label": "Use Templates Server",
    "desc": "Automatically search for structural templates..."
}
```

**UI Considerations:**
- Default: OFF (unchecked)
- Tooltip: "Can improve accuracy for proteins with known homologs. Adds ~10-20 minutes."

### 5. Number of Samples

```json
{
    "id": "num_samples",
    "type": "int",
    "default": 5,
    "label": "Number of Samples",
    "desc": "Number of structure samples to generate..."
}
```

**UI Considerations:**
- Input type: Number field or slider
- Range: 1-20 (recommend max 10 for typical use)
- Default: 5
- Warning at >10: "High sample counts significantly increase runtime"

**Runtime Impact:**
| Samples | Approx. Runtime |
|---------|-----------------|
| 1 | ~30 min |
| 3 | ~75 min |
| 5 | ~2 hours |
| 10 | ~4 hours |

### 6. Pre-computed MSA Files (Advanced)

```json
{
    "id": "msa_files",
    "type": "list:wsfile",
    "required": 0,
    "label": "Pre-computed MSA Files",
    "desc": "Optional list of pre-computed MSA files..."
}
```

**UI Considerations:**
- Multi-select file picker
- Filter: `.pqt` files
- Only show when `use_msa_server` is OFF
- Place in "Advanced Options" section

### 7. Pre-computed MSA Directory (Advanced)

```json
{
    "id": "msa_directory",
    "type": "folder",
    "required": 0,
    "label": "Pre-computed MSA Directory"
}
```

**UI Considerations:**
- Folder picker
- Only show when `use_msa_server` is OFF
- Mutually exclusive with `msa_files`

### 8. Template Hits File (Advanced)

```json
{
    "id": "template_hits_file",
    "type": "wsfile",
    "required": 0,
    "label": "Template Hits File (m8)"
}
```

**UI Considerations:**
- File picker filtered to `.m8` files
- Only relevant when `use_templates_server` is ON
- Place in "Advanced Options" section

### 9. Output Path (Required)

```json
{
    "id": "output_path",
    "type": "folder",
    "required": 1,
    "label": "Output Folder"
}
```

**UI Considerations:**
- Folder picker/creator
- Suggest default: `/user/home/ChaiLab_Results/`
- Validate: User must have write access

### 10. Dry Run (Advanced/Debug)

```json
{
    "id": "dry_run",
    "type": "bool",
    "default": false,
    "label": "Dry Run"
}
```

**UI Considerations:**
- Hide in production UI or place in "Debug" section
- Useful for testing workspace integration without GPU

---

## Suggested UI Layout

### Basic Mode

```
┌─────────────────────────────────────────────────────┐
│  Chai-1 Molecular Structure Prediction              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Input FASTA File *          [Browse...]            │
│  ┌─────────────────────────────────────────────┐   │
│  │ /user/home/proteins/my_protein.fasta        │   │
│  │ (2 sequences: protein|A, ligand|L)          │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  Constraints File            [Browse...]            │
│  (Optional - guide structure prediction)            │
│                                                     │
│  ☑ Use MSA Server (recommended)                     │
│  ☐ Use Templates Server                             │
│                                                     │
│  Number of Samples:  [5 ▾]                          │
│  (More samples = better coverage, longer runtime)   │
│                                                     │
│  Output Folder *             [Browse...]            │
│  ┌─────────────────────────────────────────────┐   │
│  │ /user/home/ChaiLab_Results/job_001          │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  [▼ Advanced Options]                               │
│                                                     │
│         [Submit Job]        [Reset]                 │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Advanced Options (Collapsed)

```
┌─────────────────────────────────────────────────────┐
│  [▲ Advanced Options]                               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Pre-computed MSA Files      [Browse Multiple...]   │
│  (Use instead of MSA server)                        │
│                                                     │
│  Pre-computed MSA Directory  [Browse Folder...]     │
│  (Alternative to individual MSA files)              │
│                                                     │
│  Template Hits File          [Browse...]            │
│  (Custom template search results)                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Output Files

The job produces these outputs in the specified output folder:

| File Pattern | Description | Viewer |
|--------------|-------------|--------|
| `pred.model_idx_N.cif` | Structure in mmCIF format | Mol* / 3Dmol.js |
| `scores.json` | Confidence scores | JSON viewer |
| `summary.json` | Job metadata | JSON viewer |

### Structure Visualization

- **Recommended viewer:** Mol* (https://molstar.org/)
- **Alternative:** 3Dmol.js, NGL Viewer
- **File format:** mmCIF (`.cif`)

---

## Test Data for Development

Test data is available at:

**Repository:** `https://github.com/wilke/ChaiApp`
**Directory:** `test_data/`

| File | Description | Use Case |
|------|-------------|----------|
| `simple_protein.fasta` | 384-residue single chain | Basic test |
| `multimer.fasta` | 2-chain homodimer (768 res) | Multimer test |
| `protein_ligand.fasta` | Protein + ligand SMILES | Ligand docking |
| `constraints.json` | Pocket restraints | Constraint test |

### Sample Parameter Sets

**Location:** `tests/`

| File | Scenario |
|------|----------|
| `params_ws.json` | Minimal required parameters |
| `params_ws_ligand.json` | Protein-ligand with constraints |
| `params_ws_multimer.json` | Multimer prediction |
| `params_ws_multisamples.json` | Multiple samples (3) |

---

## Validation Rules

### Input File Validation

```javascript
function validateFasta(content) {
    // Must have at least one header
    if (!content.includes('>')) {
        return { valid: false, error: "Missing FASTA header (>)" };
    }

    // Parse headers
    const headers = content.match(/^>(.*)$/gm);
    if (headers.length === 0) {
        return { valid: false, error: "No sequences found" };
    }

    // Validate entity format
    const validTypes = ['protein', 'ligand', 'dna', 'rna'];
    for (const header of headers) {
        const match = header.match(/^>(\w+)\|(\w+)/);
        if (!match || !validTypes.includes(match[1])) {
            return {
                valid: false,
                error: `Invalid header format: ${header}. Expected >type|chain_id`
            };
        }
    }

    return { valid: true, sequences: headers.length };
}
```

### Constraints File Validation

```javascript
function validateConstraints(json) {
    if (!json.restraints && !json.covalent_bonds) {
        return { valid: false, error: "Missing restraints or covalent_bonds" };
    }
    return { valid: true };
}
```

---

## Error Messages

| Error Code | Message | UI Action |
|------------|---------|-----------|
| `INPUT_NOT_FOUND` | Input file not found in workspace | Highlight input field |
| `INVALID_FASTA` | Input file is not valid FASTA format | Show format help |
| `OUTPUT_EXISTS` | Output directory is not empty | Offer to clear or choose new |
| `GPU_UNAVAILABLE` | No GPU resources available | Show queue status |
| `MSA_SERVER_ERROR` | MSA server unreachable | Suggest retry or local MSA |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| `docs/CHAI_INPUTS.md` | Comprehensive input format reference |
| `docs/INPUT_FORMATS.md` | FASTA format specification |
| `docs/MSA_SERVER.md` | MSA server usage details |
| `docs/RUNTIME_METRICS.md` | Resource requirements and scaling |

---

## Contact

For questions about this hand-off:
- **Backend:** See `HANDOFF_DEPLOYMENT_TEAM.md`
- **Repository:** https://github.com/wilke/ChaiApp
- **Issues:** https://github.com/wilke/ChaiApp/issues
