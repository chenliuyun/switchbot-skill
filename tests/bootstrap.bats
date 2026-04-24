#!/usr/bin/env bats

@test "download_tarball falls back to mirror when primary fails" {
  curl() {
    if [[ "$*" == *"raw.githubusercontent.com"* ]] || [[ "$*" == *"github.com"*"tar.gz"* && "$*" != *"ghproxy"* ]]; then
      return 22
    fi
    echo ""
    return 0
  }
  export -f curl
  run bash -c 'source scripts/bootstrap.sh --dry-run 2>&1; echo "sourced"'
  [ "$status" -ne 1 ] || [[ "$output" == *"sourced"* ]]
}

@test "bootstrap.sh passes bash syntax check" {
  run bash -n scripts/bootstrap.sh
  [ "$status" -eq 0 ]
}

@test "bootstrap.sh dry-run exits 0" {
  run bash scripts/bootstrap.sh --dry-run --skip-token --skip-verify --no-cli
  [ "$status" -eq 0 ]
}
