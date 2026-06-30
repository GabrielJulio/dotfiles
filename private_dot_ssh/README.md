# SSH

This folder maps to ~/.ssh through chezmoi.

This public repo should only track safe templates/docs.

Allowed:
- config.tmpl
- README.md
- .keep

Forbidden:
- private keys
- public keys tied to real infrastructure
- known_hosts
- client hostnames
- internal IPs
- VPN/server details
