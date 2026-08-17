#!/usr/bin/env bats

setup() {
  VALIDATOR="$BATS_TEST_DIRNAME/../scripts/validate-version.sh"
}

@test "release versions accept valid stable and prerelease SemVer" {
  run "$VALIDATOR" "0.1.0"
  [ "$status" -eq 0 ]

  run "$VALIDATOR" "1.2.3-rc.1"
  [ "$status" -eq 0 ]

  run "$VALIDATOR" "10.20.30-alpha-1"
  [ "$status" -eq 0 ]
}

@test "release versions reject leading-zero numeric identifiers" {
  run "$VALIDATOR" "01.2.3"
  [ "$status" -ne 0 ]

  run "$VALIDATOR" "1.02.3"
  [ "$status" -ne 0 ]

  run "$VALIDATOR" "1.2.03"
  [ "$status" -ne 0 ]

  run "$VALIDATOR" "1.2.3-01"
  [ "$status" -ne 0 ]
}

@test "release versions reject malformed prerelease identifiers" {
  run "$VALIDATOR" "1.2.3-"
  [ "$status" -ne 0 ]

  run "$VALIDATOR" "1.2.3-alpha..1"
  [ "$status" -ne 0 ]

  run "$VALIDATOR" "1.2.3-alpha_1"
  [ "$status" -ne 0 ]
}
