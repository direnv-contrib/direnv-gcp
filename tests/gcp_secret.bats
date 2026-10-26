#!/usr/bin/env bats

# Tests for lib/gcp_secret.sh (use_gcp_secret)
#
# Requires bats-core: https://github.com/bats-core/bats-core, direnv and jq
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# ---------------------------------------------------------------------------
# Loading secrets
# ---------------------------------------------------------------------------

@test "a JSON secret exports one uppercased variable per key" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "{\"username\":\"alice\",\"pass-word\":\"hunter2\",\"port\":5432}"; }
    use_gcp_secret db-creds
    echo "USERNAME=$USERNAME PASS_WORD=$PASS_WORD PORT=$PORT"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "USERNAME=alice PASS_WORD=hunter2 PORT=5432" ]]
}

@test "a plain secret is named after the secret id" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "postgres://example/db"; }
    use_gcp_secret db-url
    echo "DB_URL=$DB_URL"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_URL=postgres://example/db" ]]
}

@test "NAME=secret-id exports the raw secret string under that name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "{\"username\":\"alice\"}"; }
    use_gcp_secret DB_CREDS=db-creds
    echo "$DB_CREDS"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == '{"username":"alice"}' ]]
}

@test "several secrets can be loaded in one call" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() {
      case "$*" in
        *--secret=first*) echo "one" ;;
        *--secret=second*) echo "two" ;;
      esac
    }
    use_gcp_secret first second
    echo "FIRST=$FIRST SECOND=$SECOND"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "FIRST=one SECOND=two" ]]
}

@test "the latest version is read by default" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "args: $*" >&2; echo "v"; }
    use_gcp_secret my-secret
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: secrets versions access latest --secret=my-secret"* ]]
}

@test "secret@version reads that version" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "args: $*" >&2; echo "v"; }
    use_gcp_secret my-secret@3
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: secrets versions access 3 --secret=my-secret"* ]]
}

@test "NAME=secret@version combines an explicit name with a version" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "args: $*" >&2; echo "pinned"; }
    use_gcp_secret TOKEN=my-secret@7
    echo "TOKEN=$TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: secrets versions access 7 --secret=my-secret"* ]]
  [[ "${lines[-1]}" == "TOKEN=pinned" ]]
}

@test "a trailing newline in the payload is not part of the value" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { printf "value\n\n"; }
    use_gcp_secret my-secret
    printf "[%s]\n" "$MY_SECRET"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "[value]" ]]
}

@test "the status line reports how many variables were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "{\"a\":\"1\",\"b\":\"2\"}"; }
    use_gcp_secret x
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_gcp_secret: loaded 2 variable(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_gcp_secret
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_gcp_secret [NAME=]secret-id[@version]"* ]]
}

@test "fails when gcloud is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "gcloud" ]] && type "$1" &>/dev/null; }
    use_gcp_secret db-url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"gcloud not found"* ]]
}

@test "fails when jq is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { :; }
    has() { [[ "$1" != "jq" ]] && type "$1" &>/dev/null; }
    use_gcp_secret db-url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"jq not found"* ]]
}

@test "fails when the secret cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { return 1; }
    use_gcp_secret missing
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read missing"* ]]
}

@test "fails on an empty secret id or version" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "v"; }
    use_gcp_secret NAME=@2
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid secret 'NAME=@2'"* ]]

  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "v"; }
    use_gcp_secret my-secret@
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid secret 'my-secret@'"* ]]
}

@test "fails on a key that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    gcloud() { echo "{\"1bad\":\"v\"}"; }
    use_gcp_secret x
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1BAD'"* ]]
}
