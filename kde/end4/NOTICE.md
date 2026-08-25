# end4 licensing and provenance

This directory is a locally customized snapshot of desktop configuration and
Quickshell code derived from these projects:

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland), primarily
  under `quickshell/ii` and the surrounding end4 configuration.
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC), under
  `quickshell/end4-pC`. The vendored working tree was based on commit
  `226c8c46397b4931a883206bc7d0dbe993621465` on the local `kde-port` branch
  and includes local changes.

Both upstream projects are distributed under GNU GPL version 3. A copy is in
`LICENSE`; the original end4-pC copy is also retained at
`quickshell/end4-pC/LICENSE`. This license notice is scoped to `kde/end4` and
does not set a license for the rest of the dotfiles repository.

## Bundled third-party material

- `modules/common/functions/fuzzysort.js` in both Quickshell trees is from
  [farzher/fuzzysort](https://github.com/farzher/fuzzysort), MIT license. See
  `licenses/fuzzysort-MIT.txt`.
- Those files contain a modified excerpt from
  [lemire/FastPriorityQueue.js](https://github.com/lemire/FastPriorityQueue.js),
  Apache License 2.0. See `licenses/Apache-2.0.txt`.
- `scripts/thumbnails/thumbgen.py` in both Quickshell trees is from
  [difference-engine/thumbnail-generator-ubuntu](https://github.com/difference-engine/thumbnail-generator-ubuntu),
  MIT license, copyright 2019 Functional Paradigms Pvt Ltd. See
  `licenses/thumbnail-generator-MIT.txt`.
- The rounded-polygon shape widgets retain their local Apache License 2.0
  copies. The common text is also in `licenses/Apache-2.0.txt`.
- `quickshell/end4-pC/assets/fonts/MaterialSymbolsRounded.ttf` is from
  [Google Material Symbols](https://github.com/google/material-design-icons),
  Apache License 2.0. See `licenses/Apache-2.0.txt`.
- Most SVGs in `quickshell/ii/assets/icons/fluent` are from
  [Microsoft Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons),
  MIT license. See `licenses/fluentui-system-icons-MIT.txt`. The modified
  `start-here`, `system-search`, and `task-view` icon variants are separately
  attributed as CC BY 4.0 in that directory's `README.md`; the license text is
  in `licenses/CC-BY-4.0.txt`.
- `matugen/templates/ags/sourceviewtheme.xml` retains its LGPL 2.0-or-later
  header and modification notice. See `licenses/LGPL-2.0-or-later.txt`.
- The Fedora and Bootstrap SVGs retain their license and copyright notices
  inside the files.

`services/MprisController.qml` in both Quickshell trees retains the upstream
notice that its original author permitted redistribution but did not publish a
standard license. Redistribution is documented as permitted; modification and
relicensing rights are less explicit than for the other components.
