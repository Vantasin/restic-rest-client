.PHONY: help bootstrap bootstrap-force configure init-repo install install-and-watch install-force uninstall install-hooks verify backup prune logcleanup watch-backup-log restore-latest unlock-stale-locks test-email test-success-email test-failure-email test-warning-email test-lock-failure-email setup-rest-server-password setup-rest-server-password-replace setup-repository-password setup-repository-password-rotate setup-password setup-password-rotate

help:
	@echo "Targets:"
	@echo "  make bootstrap       Generate local gitignored config from templates"
	@echo "  make bootstrap-force Overwrite existing local config files"
	@echo "  make configure       Populate the required REST settings in restic.env"
	@echo "  make init-repo       Initialize the configured repository and verify access"
	@echo "  make install         Generate config and install launchd + newsyslog (prune only when enabled)"
	@echo "  make install-and-watch Install launchd + newsyslog, then follow the install-triggered backup log output until that run reaches a terminal outcome"
	@echo "  make install-force   Overwrite existing files during install"
	@echo "  make uninstall       Remove launchd + newsyslog and generated local config"
	@echo "  make install-hooks   Configure this clone to use repo-managed git hooks"
	@echo "  make verify          Run fast repo-wide consistency checks"
	@echo "  make backup          Run a backup now"
	@echo "  make prune           Run prune when client-side maintenance is enabled"
	@echo "  make logcleanup      Delete old per-run logs"
	@echo "  make watch-backup-log Follow only new output from the launchd backup daemon log"
	@echo "  make restore-latest  Restore the latest snapshot into ~/restic-restore"
	@echo "  make unlock-stale-locks Remove stale repository locks when no restic process is active"
	@echo "  make test-email      Send a generic notification-path test email"
	@echo "  make test-success-email Send a success-style test email"
	@echo "  make test-failure-email Send a failure-style test email"
	@echo "  make test-warning-email Send a warning-style test email"
	@echo "  make test-lock-failure-email Send a repository-lock failure test email"
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

install-and-watch:
	./install_and_watch.sh

install-force:
	./bootstrap.sh --install --force

uninstall:
	./bootstrap.sh --uninstall

install-hooks:
	git config core.hooksPath githooks

verify:
	./verify_repo.sh

backup:
	./run_backup.sh

prune:
	./run_backup.sh prune

logcleanup:
	./run_backup.sh logcleanup

watch-backup-log:
	./watch_backup_log.sh

restore-latest:
	./restore_latest.sh

unlock-stale-locks:
	./unlock_stale_locks.sh

test-email:
	./run_backup.sh test-email

test-success-email:
	./run_backup.sh test-success-email

test-failure-email:
	./run_backup.sh test-failure-email

test-warning-email:
	./run_backup.sh test-warning-email

test-lock-failure-email:
	./run_backup.sh test-lock-failure-email

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
