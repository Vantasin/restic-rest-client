# Keychain Password Setup

`setup_password.sh` generates a strong random password, stores it in macOS
Keychain, and writes `RESTIC_PASSWORD_COMMAND` into `restic.env`.

This script manages the restic repository password, not the REST server
password. The REST server password remains part of the local repository URL in
`restic-repository.txt`.

## What It Does

- generates a random password with `openssl rand -hex`
- stores it in Keychain under an account/service name
- updates `restic.env` with the matching `RESTIC_PASSWORD_COMMAND`
- verifies the Keychain entry and the `restic.env` update

## Usage

From the repo root:

```bash
./setup_password.sh
```

Makefile alternative:

```bash
make setup-password
```

Default Keychain names:

- account: `restic-rest-client-macbook`
- service: `restic-rest-client-macbook`

Optional overrides:

```bash
./setup_password.sh --account restic-rest-client-work --service restic-rest-client-work --length 32
```

If a Keychain entry already exists, the script stops unless you pass
`--rotate`:

```bash
./setup_password.sh --rotate
```

## Verify

```bash
security find-generic-password -a restic-rest-client-macbook -s restic-rest-client-macbook -w
rg -n "RESTIC_PASSWORD_COMMAND" restic.env
```

## Rotation

Run the script again to rotate the repository password, update the Keychain
entry, and update `restic.env`:

```bash
./setup_password.sh --rotate
```

Makefile alternative:

```bash
make setup-password-rotate
```

Rotation requires:

- `restic` installed locally
- the repository reachable through the current REST URL
- no running restic processes

The script verifies repository access before rotating the password.

If you rotate credentials, remember to update any other machines that access
the same repository.

## Back Up The Password

Store the password in your password manager or another encrypted backup. On
macOS:

```bash
security find-generic-password -a restic-rest-client-macbook -s restic-rest-client-macbook -w | pbcopy
```

Clear the clipboard afterward:

```bash
printf "" | pbcopy
```
