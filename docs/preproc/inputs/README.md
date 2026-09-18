# Inputs to the preprocessing concept — archived, not authoritative

These two files are the material `../CONCEPT_PREPROCESSING.md` was written
from. They are kept byte-identical to what the owner supplied on
2026-09-18 so that every reference into them stays checkable. **Neither is
an authority.** Where they and the concept disagree, the concept is right.

| file | sha256 | status |
|---|---|---|
| `HANDOVER_AccelCal_v3.md` | `834b0423555c6bd1193ce53f7c385d2ca0db61bba75b00794a1c396f6ee3811b` | Part I (panel review F1–F8, D1–D11, I.5 limitations) **stands** and is cited by id. Parts II–V are **superseded** by the concept (section 10 maps every WP). Do not implement from it. |
| `AccelBiasScaleToolbox_v2.4.2.zip` | `6ea670432d7b17e4cb9f817c45cfddc4ff4d7eb69bd2c44c172c046628d55fa5` | Legacy source to **port from**, never to put on the path (it vendors a pre-v1 `readGraceFoL1b` and would shadow nothing but confuse everything). Unzip into a scratch folder outside the repository. |

**Measured, not declared:** the handover says it reviewed v2.5.0; the zip's
`CHANGELOG.md` tops out at **v2.4.2** and contains no `linkGraceReading`.
The review findings F1–F7 were checked against this zip's source and hold;
F8 (vendored reader) is visibly present in `src/io/`.

The `.zip` is not an `.m` file, so `testSourceIntegrity` (which walks
`**/*.m`) and `docsrc/auditHelp.py` never see it. Unpacking it inside the
repository would put ~40 foreign `.m` files in front of both gates.
