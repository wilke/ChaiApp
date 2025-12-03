# Chai-Lab Input Formats

## Overview

Chai-Lab (Chai-1 model) supports multiple input formats:
1. **FASTA** (default) - Simple sequence format for basic predictions
2. **JSON Constraints** - Additional file for specifying restraints and covalent bonds
3. **Python API** - Programmatic access for advanced use cases

## Comparison with Boltz YAML Format

| Feature | Chai-Lab FASTA | Chai-Lab JSON | Boltz YAML |
|---------|----------------|---------------|------------|
| Basic sequences | Yes | N/A | Yes |
| Ligands (SMILES) | Yes | N/A | Yes |
| Modified residues | Yes | N/A | Yes |
| Distance restraints | No | Yes | Yes (constraints) |
| Contact restraints | No | Yes | Yes (constraints) |
| Covalent bonds | No | Yes | Yes (constraints) |
| Pocket constraints | No | Yes | Yes |
| Templates | Separate files | N/A | Inline |
| Affinity prediction | No | No | Yes |

---

## FASTA Format (Default)

Chai-Lab uses an extended FASTA format that supports proteins, nucleic acids, ligands, and modified residues.

### Basic Structure

```
>CHAIN_ID|ENTITY_TYPE
SEQUENCE
```

### Entity Types

| Entity Type | Description | Sequence Format |
|-------------|-------------|-----------------|
| `protein` | Protein chain | Amino acid sequence |
| `dna` | DNA strand | Nucleotide sequence (ATCG) |
| `rna` | RNA strand | Nucleotide sequence (AUCG) |
| `smiles` | Small molecule | SMILES string |
| (implicit) | Protein default | Amino acids only |

### Examples

#### Simple Protein

```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

Or simply (protein is default):
```
>A
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Protein Homodimer

```
>A
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>B
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Protein-Ligand Complex

```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|smiles
CC1=CC=CC=C1
```

#### Multi-Chain Complex with DNA

```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>B|dna
ATCGATCGATCGATCG
>C|dna
CGATCGATCGATCGAT
```

#### With RNA

```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>R|rna
AUGCAUGCAUGCAUGC
```

### Modified Residues in FASTA

Chai-Lab supports modified residues using special notation in the sequence:

```
>A|protein
MVTPEGN[SEP]SLVDESLLVGVTDED[TPO]RAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

Where `[SEP]` is phosphoserine and `[TPO]` is phosphothreonine.

### Glycosylation

```
>A|protein
MVTPEGNVSLVDESLLVGVTN[NAG-FUC]DEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

---

## JSON Constraints Format

Chai-Lab supports additional constraints via a separate JSON file, enabling restraints and covalent bonds.

### File Naming Convention

For input `input.fasta`, create `input_constraints.json` or pass via `--constraints` flag.

### Structure

```json
{
  "restraints": [...],
  "covalent_bonds": [...]
}
```

### Distance Restraints

Specify expected distances between residues/atoms:

```json
{
  "restraints": [
    {
      "type": "distance",
      "chain1": "A",
      "residue1": 45,
      "atom1": "CA",
      "chain2": "B",
      "residue2": 67,
      "atom2": "CA",
      "distance": 8.0,
      "tolerance": 2.0
    }
  ]
}
```

### Contact Restraints

Specify that two residues should be in contact:

```json
{
  "restraints": [
    {
      "type": "contact",
      "chain1": "A",
      "residue1": 45,
      "chain2": "L",
      "residue2": 1,
      "max_distance": 6.0
    }
  ]
}
```

### Pocket Restraints

Define binding pocket residues:

```json
{
  "restraints": [
    {
      "type": "pocket",
      "binder_chain": "L",
      "pocket_residues": [
        {"chain": "A", "residue": 45},
        {"chain": "A", "residue": 67},
        {"chain": "A", "residue": 89},
        {"chain": "A", "residue": 112}
      ],
      "max_distance": 6.0
    }
  ]
}
```

### Covalent Bonds

Specify covalent connections between chains:

```json
{
  "covalent_bonds": [
    {
      "chain1": "A",
      "residue1": 123,
      "atom1": "SG",
      "chain2": "L",
      "residue2": 1,
      "atom2": "C1"
    }
  ]
}
```

### Complete Example

**input.fasta**:
```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|smiles
CC1=CC=CC=C1
```

**input_constraints.json**:
```json
{
  "restraints": [
    {
      "type": "pocket",
      "binder_chain": "L",
      "pocket_residues": [
        {"chain": "A", "residue": 12},
        {"chain": "A", "residue": 15},
        {"chain": "A", "residue": 34}
      ],
      "max_distance": 6.0
    },
    {
      "type": "contact",
      "chain1": "A",
      "residue1": 15,
      "chain2": "L",
      "residue2": 1,
      "max_distance": 4.0
    }
  ],
  "covalent_bonds": []
}
```

---

## Format Comparison: Chai-Lab JSON vs Boltz YAML

### Pocket Constraint

**Chai-Lab JSON**:
```json
{
  "restraints": [
    {
      "type": "pocket",
      "binder_chain": "L",
      "pocket_residues": [
        {"chain": "A", "residue": 45},
        {"chain": "A", "residue": 67}
      ],
      "max_distance": 6.0
    }
  ]
}
```

**Boltz YAML** (equivalent):
```yaml
constraints:
  - pocket:
      binder: L
      contacts:
        - [A, 45]
        - [A, 67]
      max_distance: 6.0
```

### Covalent Bond

**Chai-Lab JSON**:
```json
{
  "covalent_bonds": [
    {
      "chain1": "A",
      "residue1": 123,
      "atom1": "SG",
      "chain2": "L",
      "residue2": 1,
      "atom2": "C1"
    }
  ]
}
```

**Boltz YAML** (equivalent):
```yaml
constraints:
  - bond:
      atom1: [A, 123, SG]
      atom2: [L, 1, C1]
```

### Key Differences

| Aspect | Chai-Lab | Boltz |
|--------|----------|-------|
| Sequence format | FASTA | YAML inline |
| Constraints format | Separate JSON | Inline YAML |
| Templates | Separate .m8 + CIF files | Inline YAML reference |
| MSA format | aligned.pqt (Parquet) | A3M or CSV |
| Affinity prediction | Not supported | Supported via `properties:` |
| Chain IDs | Single characters | Single characters or lists |
| Modified residues | Inline `[CCD]` notation | Separate `modifications:` block |

---

## CLI Usage

### Basic Prediction

```bash
chai-lab fold input.fasta output_folder
```

### With MSA Server

```bash
chai-lab fold input.fasta output_folder --use-msa-server
```

### With Templates

```bash
chai-lab fold input.fasta output_folder \
  --use-msa-server \
  --use-templates-server
```

### With Constraints

```bash
chai-lab fold input.fasta output_folder \
  --use-msa-server \
  --constraints input_constraints.json
```

### Multiple Samples

```bash
chai-lab fold input.fasta output_folder \
  --use-msa-server \
  --num-samples 5
```

---

## Output Format

Chai-Lab outputs:
- `*.cif` - Structure files in mmCIF format
- `scores.json` - Confidence scores (pLDDT, pTM, ipTM)
- `*.pdb` - Optional PDB format output

### Confidence Scores

```json
{
  "plddt": 0.85,
  "ptm": 0.82,
  "iptm": 0.78,
  "ranking_score": 0.81
}
```

---

## Common Use Cases

### Protein Structure Prediction

```bash
# input.fasta
>myprotein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE

chai-lab fold input.fasta results/ --use-msa-server
```

### Protein-Ligand Docking

```bash
# input.fasta
>protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>ligand|smiles
CC(=O)OC1=CC=CC=C1C(=O)O

chai-lab fold input.fasta results/ --use-msa-server
```

### Antibody-Antigen Complex

```bash
# input.fasta
>heavy_chain
EVQLVESGGGLVQPGGSLRLSCAASGFTFSSYAMSWVRQAPGKGLEWVSAISGSGGSTY
>light_chain
DIQMTQSPSSLSASVGDRVTITCRASQSISSYLNWYQQKPGKAPKLLIYAASSLQSGVP
>antigen
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE

chai-lab fold input.fasta results/ --use-msa-server
```

---

## Best Practices

1. **Use MSA server for better accuracy**: `--use-msa-server` improves predictions
2. **Provide templates when available**: Improves accuracy for homologs
3. **Use constraints for known interactions**: Guide the model with experimental data
4. **Generate multiple samples**: Use `--num-samples 5` for diversity
5. **Check confidence scores**: pLDDT > 70 and pTM > 0.5 indicate reliable predictions

---

## Troubleshooting

### Invalid Sequence Characters

```
Error: Invalid amino acid code 'X' at position 45
```
- Replace unknown residues with most similar amino acid
- Or use `X` only for truly unknown positions

### SMILES Parsing Error

```
Error: Could not parse SMILES string
```
- Validate SMILES with RDKit or online validator
- Ensure proper escaping of special characters
- Check for balanced parentheses and brackets

### Memory Issues

```
Error: CUDA out of memory
```
- Reduce sequence length or number of chains
- Use smaller GPU batch size
- Try on GPU with more memory (A100 80GB recommended)
