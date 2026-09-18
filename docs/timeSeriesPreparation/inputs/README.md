# Inputs to the concept — archived, not authoritative

These files are the material `../CONCEPT.md` was written from. They are kept
byte-identical to what the owner supplied on 2026-09-18, so every reference
into them stays checkable.

**None of them is an authority.** Where one of them and the concept
disagree, the concept is right.

| file | sha256 | status |
|---|---|---|
| `HANDOVER_AccelCal_v3.md` | `834b0423555c6bd1193ce53f7c385d2ca0db61bba75b00794a1c396f6ee3811b` | Part I (panel review F1–F8, D1–D11, I.5) **stands** and is cited by id. Parts II–V are **superseded** by the concept (section 10 maps every WP). Do not implement from it. |
| `AccelBiasScaleToolbox_v2.4.2.zip` | `6ea670432d7b17e4cb9f817c45cfddc4ff4d7eb69bd2c44c172c046628d55fa5` | Legacy source to **port from**, never to put on the path: it vendors a pre-v1 `readGraceFoL1b`. |
| `sigtools_v1.3.1.zip` | `8df39cd623075527b6a834a88de21de94476119bc185e70e74d522590088f55a` | **Becomes part of timeSeriesPreparation** (X-01 import, X-02 conventions). Its HANDOFF.md is the record of its verification history (209 tests on R2026a Update 3, as stated there). |

**Measured, not declared**
- The v3 handover says it reviewed AccelBiasScaleToolbox v2.5.0, but that
  zip's `CHANGELOG.md` tops out at **v2.4.2** and contains no
  `linkGraceReading`.
- sigtools has 26 function files and about 5 000 lines.
  - 24 of the 26 files have no `arguments` block.
  - Its error identifiers carry no toolbox prefix.
  - Four functions contain plotting code: `allanVariance`, `plotPowerSpectrum`,
    `psd2arma`, `tsCheckResiduals`.
  - The Lyapunov solver exists in four local copies (its HANDOFF §4 says so).

**Gate safety.** Zip files are never unpacked inside this repository.
`testSourceIntegrity` walks `**/*.m`, and about 110 foreign `.m` files would
reach it and `docsrc/auditHelp.py`.
