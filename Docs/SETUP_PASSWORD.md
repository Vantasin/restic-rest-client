# Keychain Password Setup

`setup_password.sh` manages two different secrets:

1. The REST server HTTP password supplied by the server admin
2. The restic repository password used to encrypt repository contents

Both flows update `restic.env` so later `source restic.env` calls pick up the
matching Keychain entries.

## REST Server Password

Use this when the server admin gives you the base per-user REST URL plus the
REST username/password. Run `make configure` first so `restic.env` already has
the base URL and username populated and local defaults selected for the
repository name and host label.

From the repo root:

```bash
./setup_password.sh --rest-server
```

Makefile alternative:

```bash
make setup-rest-server-password
```

This flow:

- stores the admin-provided password in Keychain when the entry does not exist
- skips cleanly when the Keychain entry already exists
- updates `RESTIC_REST_PASSWORD` in `restic.env`

That makes `./setup_password.sh --rest-server` and
`make setup-rest-server-password` safe to rerun during a repeat setup pass.

Default Keychain names:

- account: `restic-rest-client-rest-server`
- service: `restic-rest-client-rest-server`

If the server admin changes the password, replace the existing Keychain entry
explicitly:

```bash
./setup_password.sh --rest-server --replace
```

Makefile alternative:

```bash
make setup-rest-server-password-replace
```

## Repository Password

Use this when the client is creating the repository and needs a new random
restic password before `make init-repo`.

From the repo root:

```bash
./setup_password.sh --repository
```

Makefile alternative:

```bash
make setup-repository-password
```

This flow:

- generates a random password with `openssl rand -hex`
- stores it in Keychain under an account/service name
- updates `RESTIC_PASSWORD_COMMAND` in `restic.env`
- verifies the Keychain entry and the `restic.env` update

If the Keychain entry already exists, the command skips cleanly and only
repairs the `RESTIC_PASSWORD_COMMAND` line in `restic.env` if needed. That
makes `./setup_password.sh --repository` and
`make setup-repository-password` safe to rerun.

Default Keychain names:

- account: `restic-rest-client-repository`
- service: `restic-rest-client-repository`

Optional overrides:

```bash
./setup_password.sh --repository --account restic-rest-client-work --service restic-rest-client-work --length 32
```

## Rotation

Rotate the repository password:

```bash
./setup_password.sh --repository --rotate
```

Makefile alternative:

```bash
make setup-repository-password-rotate
```

Rotation requires:

- `restic` installed locally
- the repository reachable through the current REST URL
- no running restic processes

The script verifies repository access before rotating the password. If the
repository password changes successfully but the follow-up Keychain update
fails, the script attempts to roll the repository password back to the previous
value. If rollback also fails, it keeps recovery temp files and prints their
paths so you can finish recovery manually.

If you rotate the repository password, update any other machines that access
the same repository.

## Verify

```bash
security find-generic-password -a restic-rest-client-rest-server -s restic-rest-client-rest-server -w
security find-generic-password -a restic-rest-client-repository -s restic-rest-client-repository -w
rg -n "RESTIC_REST_PASSWORD|RESTIC_PASSWORD_COMMAND" restic.env
```

Because restic consumes REST server auth via `RESTIC_REST_PASSWORD`, the script
writes a Keychain command substitution into `restic.env` for that variable.
The repository password still uses `RESTIC_PASSWORD_COMMAND`.

## Back Up The Repository Password

Store the repository password in your password manager or another encrypted
backup. On macOS:

```bash
security find-generic-password -a restic-rest-client-repository -s restic-rest-client-repository -w | pbcopy
```

Clear the clipboard afterward:

```bash
printf "" | pbcopy
```
