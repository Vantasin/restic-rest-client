.PHONY: help install install-force uninstall setup-password setup-password-rotate install-hooks verify

help:
	@echo "Targets:"
	@echo "  make install         Generate config and install launchd + newsyslog (prune only when enabled)"
	@echo "  make install-force   Overwrite existing files during install"
	@echo "  make uninstall       Remove launchd + newsyslog and local config"
	@echo "  make install-hooks   Configure this clone to use repo-managed git hooks"
	@echo "  make verify         Run fast repo-wide consistency checks"
	@echo "  make setup-password  Generate and store Keychain password"
	@echo "  make setup-password-rotate  Rotate existing Keychain password"

install:
	./bootstrap.sh --install

install-force:
	./bootstrap.sh --install --force

uninstall:
	./bootstrap.sh --uninstall

install-hooks:
	git config core.hooksPath githooks

verify:
	./verify_repo.sh

setup-password:
	./setup_password.sh

setup-password-rotate:
	./setup_password.sh --rotate
