<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Elenchus architecture map and completion dashboard -->
<!-- Last updated: 2026-02-20 -->

# Elenchus — Project Topology

## System Architecture

```
              ┌─────────────────────────────────┐
              │         STATISTEASE (Julia)      │
              │  Computes statistical results    │
              └──────────────┬──────────────────┘
                             │ JSON transaction
                             ▼
              ┌─────────────────────────────────┐
              │          ELENCHUS (Octave)       │
              │   Independent Neurosymbolic      │
              │   Statistical Auditor            │
              │                                  │
              │  ┌───────────────────────────┐   │
              │  │ PHASE 1: Numerical        │   │
              │  │ (Octave recomputation)    │   │
              │  └─────────┬─────────────────┘   │
              │  ┌─────────▼─────────────────┐   │
              │  │ PHASE 2: Ontological      │   │
              │  │ (Prolog + DeepProbLog)    │   │
              │  └─────────┬─────────────────┘   │
              │  ┌─────────▼─────────────────┐   │
              │  │ PHASE 3: Interpretation   │   │
              │  │ (Prolog + Octave)         │   │
              │  └─────────┬─────────────────┘   │
              │  ┌─────────▼─────────────────┐   │
              │  │ LOGTALK KNOWLEDGE BASE    │   │
              │  │ (learns, self-tracks)     │   │
              │  └───────────────────────────┘   │
              └──────────────┬──────────────────┘
                             │ Audit report
                             ▼
              ┌─────────────────────────────────┐
              │           USER                   │
              │  Sees BOTH result and audit      │
              └──────────────┬──────────────────┘
                             │ (on disagreement)
                             ▼
              ┌─────────────────────────────────┐
              │      ECHIDNA (Arbitrator)        │
              │  Formal proof verification       │
              │  GraphQL API — neutral ground    │
              └─────────────────────────────────┘
```

## Three-Body Governance

```
         StatistEase ◄──────────── echidna ──────────────► Elenchus
         (computes)                 (arbitrates)            (audits)
              │                        ▲                       │
              └────────── disagree? ───┘────── disagree? ──────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
NUMERICAL VERIFICATION (Octave)
  Descriptive stats verify          ██████████ 100%    Full cross-check
  t-test verify (Welch)             ██████████ 100%    Independent computation
  ANOVA verify                      ██████████ 100%    SS decomposition
  Chi-square verify                 ██████████ 100%    Expected freq + Cramer's V
  Pearson correlation verify        ██████████ 100%    Fisher z CI
  Regression verify (OLS)           ██████████ 100%    Normal equations
  Mann-Whitney verify               ██████████ 100%    Rank computation
  Kruskal-Wallis verify             ██████████ 100%    H-statistic

ONTOLOGICAL REASONING (Prolog)
  Statistical test ontology          ██████████ 100%    Stevens scales + prereqs
  DeepProbLog probabilistic rules    ██████████ 100%    Confidence scoring
  P-value / effect size reasoning    ██████████ 100%    ASA 2016 + Cohen 1988

AUDIT ENGINE
  Three-phase pipeline               ██████████ 100%    Num + onto + interp
  Governance model                   ██████████ 100%    Auditor, non-blocking
  Logtalk knowledge base             ██████████ 100%    Learning + self-tracking
  StatistEase bridge                 ██████████ 100%    JSON transaction reader

PLANNED
  echidna arbitration                ░░░░░░░░░░   0%    GraphQL integration
  Tests                              ░░░░░░░░░░   0%    Not yet written

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ████████░░  80%    Core audit engine complete
```

## Key Dependencies

```
GNU Octave ──► Elenchus ──► SWI-Prolog ──► Logtalk
                  │
                  ├──► StatistEase (JSON read-only)
                  └──► echidna (arbitration, planned)
```
