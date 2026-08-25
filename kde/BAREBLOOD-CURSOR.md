# BAREBLOOD cursor theme

This dotfiles repository keeps only the BAREBLOOD cursor theme. It does not
install or retain the complete BAREBLOOD desktop theme.

## Source

- Upstream: https://github.com/v1ewp0rt/BAREBLOOD
- Pinned commit: `c07661344a6a401aa07c2e1bd3c0932ba1bf0f73`
- Upstream path: `.local/share/icons/BAREBLOOD-cursor`
- Managed target: `~/.local/share/icons/BAREBLOOD-cursor`

The cursor files are fetched directly from the pinned upstream archive by
chezmoi using `.chezmoiexternal.toml`. The archive is verified with SHA-256,
and the files in the installed cursor theme match that pinned revision.

## License

The upstream repository does not currently declare a license. For that reason,
this repository records only the source reference and checksum; it does not
redistribute the cursor binaries.

## Updating

To update the cursor theme:

1. Select and review a new upstream commit.
2. Replace the commit in the archive URL in `.chezmoiexternal.toml`.
3. Download that archive and update its `checksum.sha256` value.
4. Run `chezmoi --refresh-externals apply`.
