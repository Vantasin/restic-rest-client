# Installer regression tests

Run `zsh tests/install.sh` on macOS. The suite uses temporary files and mocked
sudo/launchctl/newsyslog commands; it never installs live agents or runs restic.
It covers fresh installs, legacy upgrades, managed-template updates, preserved
customizations, conflicts, repeat installs, validation failure, and rollback.
It also covers prune transitions, divergent overrides, forced managed-asset
reconciliation, and duplicate rotation-rule rejection. Force regeneration of
personal config is handled by the bootstrap dispatcher, outside this suite.
