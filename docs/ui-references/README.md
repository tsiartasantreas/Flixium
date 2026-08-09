# Netflix UI Reference Capture

Per spec §6.5, before building any UI (Phase 2) we screenshot the real Netflix app and annotate each screen. These become the **visual acceptance criteria** — a screen ships only when it is near-indistinguishable from its reference, except the accent color.

## How to capture

1. **Phone (Android):** Install Netflix from the Play Store on a test device. Sign in. Screenshot each screen listed below in both light and dark (Netflix defaults to dark — dark is the target).
2. **TV (Android TV / Fire TV):** Install Netflix on your Fire TV stick. Use ADB screencap for full-fidelity captures:
   ```bash
   adb connect <TV_IP>:5555
   adb exec-out screencap -p > docs/ui-references/tv/<screen>.png
   ```
3. **Annotate:** for each capture, mark (in an image editor or via overlay): typography sizes, spacing, card dimensions, focus state. Save the annotated copy alongside the raw one.

## Legal
- These captures are **internal design references only**. Never ship them in the app, the repo README, or any public asset. The repo's `.gitignore` should exclude the raw PNGs if the repo becomes public — keep them in a private subfolder or out of git entirely. (A `.gitignore` rule is added below.)
- Clone **UX/layout only**. No Netflix wordmark, logo, or artwork appears in our product.

## Screen checklist (map to spec §8.1)
### Mobile
- [ ] Home (hero + rows)
- [ ] Browse / category grid
- [ ] Title detail (with Episodes tab)
- [ ] Player (VOD controls)
- [ ] Live / channel zapper
- [ ] My List
- [ ] Profile switcher ("Who's watching?")
- [ ] Settings
- [ ] Search

### TV (10-foot)
- [ ] Home (left-rail nav + hero + rows)
- [ ] Title detail modal
- [ ] Player (TV controls)
- [ ] Live EPG grid (adapted)
- [ ] Profile switcher
- [ ] Settings

## Acceptance gate
For each screen, create a side-by-side (reference | our impl) before marking the P2 task done. If a reviewer can't tell which is which at a glance (modulo accent color), it passes.
