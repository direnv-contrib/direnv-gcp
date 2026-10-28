# direnv-gcp

> Google Cloud for direnv — load Secret Manager secrets into your environment and pick the project per directory.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/direnv-contrib/direnv-gcp/actions/workflows/ci.yml/badge.svg)](https://github.com/direnv-contrib/direnv-gcp/actions/workflows/ci.yml)

Stop copying secrets into `.env` files. `direnv-gcp` adds two functions to your `.envrc`: `use gcp_secret` reads Google Secret Manager secrets when you enter a directory and exports them as environment variables, and `use gcp_project` points `gcloud` and the client libraries at the right project for that directory.

## Requirements

- [direnv](https://direnv.net) (`direnv`)
- [jq](https://jqlang.org) (`jq`)
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (`gcloud`), signed in with an account that can access the secrets

**macOS (Homebrew):**

```bash
brew install direnv jq
brew install --cask gcloud-cli
```

**Nix:**

```bash
nix profile install nixpkgs#direnv nixpkgs#jq nixpkgs#google-cloud-sdk
```

## Installation

direnv loads every `*.sh` file in `~/.config/direnv/lib/` before it evaluates a `.envrc`, so installing means making the files in `lib/` available there.

### Using Nix

Add the flake as an input:

```nix
inputs.direnv-gcp.url = "github:direnv-contrib/direnv-gcp";
```

With Home Manager, import the module and enable it under `programs.direnv.contrib`, next to direnv itself. It sources the scripts from direnv's standard library, so `programs.direnv.enable` must be on:

```nix
imports = [ inputs.direnv-gcp.homeModules.default ];

programs.direnv = {
  enable = true;
  contrib.gcp.enable = true;
};
```

Without Home Manager, install the package, which places the scripts in `share/direnv-gcp`:

```nix
environment.systemPackages = [ inputs.direnv-gcp.packages.${system}.default ];
```

Then source them from the standard library with a loop in `~/.config/direnv/lib/direnv-gcp.sh`, pointing at the package path:

```bash
for lib in /path/to/direnv-gcp/share/direnv-gcp/*.sh; do
  source "$lib"
done
```

### Manual

```bash
git clone https://github.com/direnv-contrib/direnv-gcp.git ~/.local/share/direnv-gcp
mkdir -p ~/.config/direnv/lib
ln -s ~/.local/share/direnv-gcp/lib/*.sh ~/.config/direnv/lib/
```

### Pinned in a project

To use a helper without installing anything, pin it in a project's `.envrc` with direnv's `source_url`. This also works for teammates and CI, which only need direnv. Ask direnv for the hash of the file, then put it in the `.envrc`:

```bash
direnv fetchurl https://raw.githubusercontent.com/direnv-contrib/direnv-gcp/v0.1.0/lib/gcp_secret.sh
```

```bash
source_url "https://raw.githubusercontent.com/direnv-contrib/direnv-gcp/v0.1.0/lib/gcp_secret.sh" "sha256-…"
use gcp_secret db-creds
```

Replace `v0.1.0` with the release you want. direnv refuses to load a file whose content does not match the hash, so a tag that is later changed cannot swap the code under you.

## Usage

Call the helpers from a `.envrc` with direnv's `use`. Each helper is a function named `use_<name>`, and `use <name>` calls it:

```bash
use gcp_project my-project            # gcloud and client libraries use this project

use gcp_secret db-creds               # JSON secret: one variable per key
use gcp_secret DB_URL=db-url          # the raw secret string, with an explicit name
use gcp_secret api-token@3            # a specific version, the default is latest
```

### use gcp_secret

| Argument | Result |
|----------|--------|
| `db-creds`, a JSON object | One variable per key, uppercased. Non-string values are exported as JSON |
| `db-url`, a plain string | One variable named after the secret id, `DB_URL` |
| `NAME=db-url` | The raw secret string, exported as `NAME` |
| `db-url@3` | Version 3 of the secret. Without `@`, the latest version is read |

Variable names are uppercased, and characters outside `A-Z`, `0-9` and `_` become `_`. The secret is read with `gcloud secrets versions access`, so it uses the project in `CLOUDSDK_CORE_PROJECT`, which `use gcp_project` sets, or else the project of the active gcloud configuration.

### use gcp_project

Sets `CLOUDSDK_CORE_PROJECT`, which `gcloud` reads, and `GOOGLE_CLOUD_PROJECT`, which the client libraries read. Both override the active gcloud configuration for that directory.

## Credentials

The helpers use whatever account `gcloud` is signed in with. Run `gcloud auth login` once, or set up a service account the way you already do for gcloud.

## Behavior

- A failed read or a name that is not a valid variable name stops the call and returns status 1 with an error message. Variables exported by earlier arguments in the same call stay set.
- A trailing newline in a secret is not part of the exported value.
- Values are exported into the environment of that directory. Anything that runs there can read them, and direnv's `.envrc` trust model applies, so review a `.envrc` before you run `direnv allow`.
- A `.envrc` that uses these functions contains secret names and project ids only, never the values, so it is safe to commit.

## Development

```bash
nix develop
bats tests/
```

The tests stub `gcloud` with a shell function and load direnv's own standard library, so they run without Google Cloud access.

## The direnv-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| [direnv-aws](https://github.com/direnv-contrib/direnv-aws) | AWS Secrets Manager and SSM Parameter Store for direnv |
| [direnv-az](https://github.com/direnv-contrib/direnv-az) | Azure Key Vault and subscription selection for direnv |
| **direnv-gcp** ← you are here | Google Secret Manager and project selection for direnv |
| [direnv-op](https://github.com/direnv-contrib/direnv-op) | 1Password secrets and items for direnv |

## License

[MIT](LICENSE) — Copyright (c) 2026 direnv-contrib

<!-- markdownlint-disable-file MD013 -->
