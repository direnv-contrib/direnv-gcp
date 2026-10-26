#!/usr/bin/env bats

# Tests for lib/gcp_project.sh (use_gcp_project)
#
# Requires bats-core: https://github.com/bats-core/bats-core and direnv
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

@test "exports the project for gcloud and the client libraries" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset CLOUDSDK_CORE_PROJECT GOOGLE_CLOUD_PROJECT
    use_gcp_project my-project
    echo "gcloud=$CLOUDSDK_CORE_PROJECT libs=$GOOGLE_CLOUD_PROJECT"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "gcloud=my-project libs=my-project" ]]
}

@test "overrides a project that is already set" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    export CLOUDSDK_CORE_PROJECT="old-project" GOOGLE_CLOUD_PROJECT="old-project"
    use_gcp_project new-project
    echo "gcloud=$CLOUDSDK_CORE_PROJECT libs=$GOOGLE_CLOUD_PROJECT"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "gcloud=new-project libs=new-project" ]]
}

@test "the status line names the project" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_gcp_project my-project
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_gcp_project: my-project"* ]]
}

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_gcp_project
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_gcp_project project-id"* ]]
}

@test "an empty project id fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_gcp_project ""
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_gcp_project project-id"* ]]
}

@test "more than one argument fails and sets nothing" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset CLOUDSDK_CORE_PROJECT GOOGLE_CLOUD_PROJECT
    use_gcp_project one two
    echo "after=${CLOUDSDK_CORE_PROJECT:-unset}"
  '
  [[ "$output" == *"usage: use_gcp_project project-id"* ]]
  [[ "${lines[-1]}" == "after=unset" ]]
}
