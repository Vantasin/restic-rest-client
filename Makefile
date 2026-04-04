.PHONY: help bootstrap bootstrap-force configure init-repo install install-force uninstall install-hooks verify setup-rest-server-password setup-rest-server-password-replace setup-repository-password setup-repository-password-rotate setup-password setup-password-rotate

help:
	@echo "Targets:"
	@echo "  make bootstrap       Generate local gitignored config from templates"
	@echo "  make bootstrap-force Overwrite existing local config files"
	@echo "  make configure       Populate the required REST settings in restic.env"
	@echo "  make init-repo       Initialize the configured repository and verify access"
	@echo "  make install         Generate config and install launchd + newsyslog (prune only when enabled)"
	@echo "  make install-force   Overwrite existing files during install"
	@echo "  make uninstall       Remove launchd + newsyslog and generated local config"
	@echo "  make install-hooks   Configure this clone to use repo-managed git hooks"
	@echo "  make verify          Run fast repo-wide consistency checks"
	@echo "  make setup-rest-server-password      Ensure the REST server password is configured in Keychain"
	@echo "  make setup-rest-server-password-replace Replace the existing REST server password in Keychain"
	@echo "  make setup-repository-password       Ensure the restic repository password is configured in Keychain"
	@echo "  make setup-repository-password-rotate Rotate the existing restic repository password"

bootstrap:
	./bootstrap.sh --generate

bootstrap-force:
	./bootstrap.sh --generate --force

configure:
	./configure_env.sh

init-repo:
	./init_repo.sh

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

setup-rest-server-password:
	./setup_password.sh --rest-server

setup-rest-server-password-replace:
	./setup_password.sh --rest-server --replace

setup-repository-password:
	./setup_password.sh --repository

setup-repository-password-rotate:
	./setup_password.sh --repository --rotate

setup-password:
	./setup_password.sh --repository

setup-password-rotate:
	./setup_password.sh --repository --rotate
