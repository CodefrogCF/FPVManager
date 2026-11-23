# R34 – JavaScript test regression hotfix

This patch addresses the four failing JavaScript tests reported after applying the R34 southern-building restoration patch over R33.1.

- Restores the historical `tool/scenery/r28_1/restoration_report.json` that both the R27 forebuilding test and the R28 scan-fit test import.
- Bundles `tool/scenery/r29/refinement_R29_report.json`, which the R34 forebuilding test also imports. This avoids an additional missing-module error in installations without the original R29 report.
- Updates `test/js/scenery_r33_bridge_height_match.test.cjs` to expect the visually confirmed BKG default offset of **-16.90 m**, while retaining the separate-provider, persistence, and preview-mode checks. It also retains the R33.1 ground-to-ground calibration regressions.

No runtime JavaScript, Flutter, terrain, original scan GLB, physical FPC collision mesh or catalog configuration is changed by this patch.

## Install

Extract into the FPVManager repository root **after** R34, overwriting the test file when prompted.

```powershell
node --test test/js/*.test.cjs
```

## Verification

Reconstructed workspace: R33.1 project + R34 patch + historical R28 scan-fit test. Result: **949 passed, 0 failed**. Your local test count may differ if additional test files exist (your reported run had 950, including 4 failures).
