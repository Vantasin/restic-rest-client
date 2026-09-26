#!/bin/zsh
set -euo pipefail
REPO_DIR="${0:A:h:h}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
# Load production helpers without running bootstrap's command dispatcher.
set -- --generate
source <(sed '/^if \[\[ "$do_generate" == "true"/,$d' "$REPO_DIR/bootstrap.sh" | sed '/^source "\$SCRIPT_DIR\/lib\/install.sh"/d')
source "$REPO_DIR/lib/install.sh"
SCRIPT_DIR="$TEST_ROOT/repo"
HOME_DIR="$TEST_ROOT/home"
MANAGED_BASELINES="$SCRIPT_DIR/.install-state/baselines"
NEWSYSLOG_DEST="$TEST_ROOT/rotation.conf"
mkdir -p "$SCRIPT_DIR/launchd" "$SCRIPT_DIR/newsyslog" "$HOME_DIR/Library/LaunchAgents" "$TEST_ROOT/loaded"
cp "$REPO_DIR"/launchd/*.example "$SCRIPT_DIR/launchd/"
cp "$REPO_DIR/newsyslog/$NEWSYSLOG_TEMPLATE_NAME" "$SCRIPT_DIR/newsyslog/"
print 'export RESTIC_PRUNE_ENABLED=true' > "$SCRIPT_DIR/restic.env"
print 'personal include' > "$SCRIPT_DIR/restic-include-macos.txt"
print 'personal exclusion' > "$SCRIPT_DIR/restic-exclude-macos.txt"
FAIL_LOAD=false
FAIL_VALIDATE=false
sudo() { if [[ "$1" == -v ]]; then return 0; fi; "$@"; }
newsyslog() { [[ "$FAIL_VALIDATE" == false ]]; }
launchctl() {
  local label="${2:t}"
  case "$1" in
    print) [[ -f "$TEST_ROOT/loaded/$label" ]] ;;
    bootout) rm -f "$TEST_ROOT/loaded/$label" ;;
    load)
      label="${label%.plist}"
      if [[ "$FAIL_LOAD" == true && "$label" == "$CHECK_LABEL" ]]; then FAIL_LOAD=false; return 1; fi
      touch "$TEST_ROOT/loaded/$label"
      ;;
    *) return 1 ;;
  esac
}
assert_equal() { cmp -s "$1" "$2" || { print "FAIL: $1 differs from $2"; exit 1; }; }
snapshot_files() {
  local target="$1"
  mkdir -p "$target"
  cp -R "$SCRIPT_DIR/." "$target/repo"
  cp -R "$HOME_DIR/." "$target/home"
  cp "$NEWSYSLOG_DEST" "$target/rotation.conf"
}
assert_snapshot() {
  diff -r "$1/repo" "$SCRIPT_DIR"
  diff -r "$1/home" "$HOME_DIR"
  assert_equal "$1/rotation.conf" "$NEWSYSLOG_DEST"
}
run_install_transaction
[[ -f "$MANAGED_BASELINES/newsyslog.conf" ]]
[[ $(awk '/daemon_check.log/ {n++} END {print n}' "$NEWSYSLOG_DEST") == 1 ]]
snapshot_files "$TEST_ROOT/first"
run_install_transaction
assert_snapshot "$TEST_ROOT/first"
print 'PASS: fresh install and repeat install'

# Older installations lack baselines and the check rotation rule.
rm -rf "$MANAGED_BASELINES"
sed '/daemon_check.log/d' "$NEWSYSLOG_DEST" > "$TEST_ROOT/old.conf"
mv "$TEST_ROOT/old.conf" "$NEWSYSLOG_DEST"
print '# operator comment' >> "$NEWSYSLOG_DEST"
run_install_transaction
[[ $(awk '/daemon_check.log/ {n++} END {print n}' "$NEWSYSLOG_DEST") == 1 ]]
[[ $(tail -n 2 "$NEWSYSLOG_DEST" | head -n 1) == '# operator comment' ]]
print 'PASS: legacy missing-rule migration'

# Unmodified files automatically follow template changes.
sed -i '' 's/<integer>23<\//<integer>22<\//' "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME.example"
run_install_transaction
rg -q '<integer>22</integer>' "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
print 'PASS: unmodified managed asset upgrade'

# Edits in installed assets survive; rotation overrides and comments survive.
sed -i '' 's/<integer>22<\//<integer>21<\//' "$HOME_DIR/Library/LaunchAgents/$PRUNE_PLIST_NAME"
sed -i '' '/daemon_backup.log/s/5120/10240/' "$NEWSYSLOG_DEST"
run_install_transaction
rg -q '<integer>21</integer>' "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
rg -q 'daemon_backup.log.*10240' "$NEWSYSLOG_DEST"
print 'PASS: customized installed plist and rotation rule preserved'

# Conflicting template updates fail before changing installed or local files.
sed -i '' 's/<integer>22<\//<integer>20<\//' "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME.example"
snapshot_files "$TEST_ROOT/conflict"
if run_install_transaction; then print 'FAIL: expected conflict'; exit 1; fi
assert_snapshot "$TEST_ROOT/conflict"
sed -i '' 's/<integer>20<\//<integer>22<\//' "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME.example"
print 'PASS: conflicting template update leaves files unchanged'

snapshot_files "$TEST_ROOT/rollback"
FAIL_LOAD=true
if run_install_transaction; then print 'FAIL: expected load failure'; exit 1; fi
assert_snapshot "$TEST_ROOT/rollback"
for label in "$BACKUP_LABEL" "$CHECK_LABEL" "$PRUNE_LABEL" "$LOGCLEANUP_LABEL"; do
  [[ -f "$TEST_ROOT/loaded/$label" ]]
done
print 'PASS: load failure rolls back local, installed and baseline files plus loaded state'
FAIL_VALIDATE=true
if run_install_transaction; then print 'FAIL: expected validation failure'; exit 1; fi
assert_snapshot "$TEST_ROOT/rollback"
FAIL_VALIDATE=false
print 'PASS: validation failure leaves files unchanged'
[[ $(cat "$SCRIPT_DIR/restic.env") == 'export RESTIC_PRUNE_ENABLED=true' ]]
[[ $(cat "$SCRIPT_DIR/restic-exclude-macos.txt") == 'personal exclusion' ]]
[[ $(cat "$SCRIPT_DIR/restic-include-macos.txt") == 'personal include' ]]
print 'PASS: personal configuration untouched'

# Prune transitions remove/recreate only the optional installed agent.
print 'export RESTIC_PRUNE_ENABLED=false' > "$SCRIPT_DIR/restic.env"
run_install_transaction
[[ ! -e "$HOME_DIR/Library/LaunchAgents/$PRUNE_PLIST_NAME" ]]
[[ ! -e "$TEST_ROOT/loaded/$PRUNE_LABEL" ]]
print 'export RESTIC_PRUNE_ENABLED=true' > "$SCRIPT_DIR/restic.env"
run_install_transaction
[[ -f "$HOME_DIR/Library/LaunchAgents/$PRUNE_PLIST_NAME" ]]
[[ -f "$TEST_ROOT/loaded/$PRUNE_LABEL" ]]
print 'PASS: prune disable and re-enable'

# Divergent local and installed overrides must not silently win over each other.
sed -i '' 's/<integer>21<\//<integer>19<\//' "$HOME_DIR/Library/LaunchAgents/$PRUNE_PLIST_NAME"
snapshot_files "$TEST_ROOT/divergent"
if run_install_transaction; then print 'FAIL: expected divergent override conflict'; exit 1; fi
assert_snapshot "$TEST_ROOT/divergent"
print 'PASS: divergent overrides leave files unchanged'

# Force reconciles managed assets to defaults (personal config regeneration
# belongs to bootstrap's dispatcher, outside this transaction helper).
force=true
run_install_transaction
assert_equal "$MANAGED_BASELINES/$PRUNE_PLIST_NAME" "$SCRIPT_DIR/launchd/$PRUNE_PLIST_NAME"
assert_equal "$MANAGED_BASELINES/newsyslog.conf" "$NEWSYSLOG_DEST"
force=false
print 'PASS: forced managed-asset reconciliation'

# Duplicate managed rotation rules are rejected before mutation.
awk '/daemon_backup.log/ {print}' "$NEWSYSLOG_DEST" >> "$TEST_ROOT/duplicate-rule"
cat "$TEST_ROOT/duplicate-rule" >> "$NEWSYSLOG_DEST"
snapshot_files "$TEST_ROOT/duplicate"
if run_install_transaction; then print 'FAIL: expected duplicate rotation conflict'; exit 1; fi
assert_snapshot "$TEST_ROOT/duplicate"
print 'PASS: duplicate managed rotation rules rejected'
