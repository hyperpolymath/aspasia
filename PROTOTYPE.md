<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

# ⚠️ Prototype status, disclaimers & how this fits the ethics work

> **Aspasia is an early-stage research prototype, not a product.** It
> explores one idea — an *independent neurosymbolic auditor* that
> cross-checks statistical work (Octave + Prolog) — and shares it openly so
> others can test it and push back.

## What "prototype" means here

- **Experimental.** Interfaces, the ABI/FFI surface, config formats and the
  audit rules themselves are provisional and may change or be abandoned.
- **Unproven.** The auditor has not itself been independently validated.
  Coverage is partial; there are statistical situations it does not yet
  understand.
- **No warranty.** Provided "as is", with no warranty of any kind, to the
  extent permitted by the licence. See `LICENSE` / `NOTICE`.

## Auditing disclaimer (please read)

Aspasia's whole job is to make you *more confident* in a result. That makes
it dangerous to over-trust — a wrong audit is worse than no audit.

- **The auditor is not an oracle.** A green verdict from Aspasia is *not*
  proof that an analysis is correct, that the right test was chosen, or that
  an interpretation is sound. A single unverified checker is itself a single
  point of failure — the very problem it was built to address.
- **Keep a human statistician in the loop.** Do not use Aspasia to sign off
  consequential decisions (clinical, financial, legal, safety) unattended.
- **Correcting the corrector cuts both ways.** Aspasia can be confidently
  wrong for exactly the same reasons the LLM it audits can be. Treat its
  output as a *second opinion to investigate*, not a ruling.

## Interest and collaboration warmly welcome

This is shared to *invite scrutiny*, not to advertise a finished thing.

- Open an **issue** or **discussion** with counter-examples, cases it gets
  wrong, or "an auditor should also check…".
- Critique of the **ethics framing** (below) is especially valued.
- See `CONTRIBUTING`, `CODE_OF_CONDUCT` and `EXHIBIT-A-ETHICAL-USE.txt`
  before contributing.

## Where the ethics thinking lives

Auditing statistics is an *ethics* practice — it is about not misleading
people with numbers, and about honest uncertainty. The estate develops that
reasoning in dedicated sibling projects, and Aspasia defers to them:

| Project | Role in the ethics picture |
|---|---|
| [**Phronesis**](https://github.com/hyperpolymath/phronesis) | A "practical wisdom" language — the estate's substrate for normative reasoning, distinct from a model's raw knowledge. |
| [**Phronesiser**](https://github.com/hyperpolymath/phronesiser) | Adds **normative ethical constraints** to AI agents via Phronesis — the home for *what a responsible verdict owes the person receiving it*. |
| [**Vexometer**](https://github.com/hyperpolymath/vexometer) | The **interaction-ethics / UX** side: an "Irritation Surface Analyser" for the human cost of tools. An auditor that nags or undermines confidence badly is itself a harm — this is how that cost gets named. |
| [**Palimpsest License**](https://github.com/hyperpolymath/palimpsest-license) | The ethical-use licence family this repo ships under; see also this repo's own `EXHIBIT-A-ETHICAL-USE.txt` for the concrete ethical-use expectations. |

For the ethics rationale specifically, start with **Phronesiser** (the
*normative* side) and **Vexometer** (the *human-experience* side); this
repo's `EXHIBIT-A-ETHICAL-USE.txt` grounds both in licence terms.
