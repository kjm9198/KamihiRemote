#!/usr/bin/env bash
set -euo pipefail

SOURCE="iOS/DesktopUtilityCenter.swift"

fail() {
  echo "Calculator contract failed: $1" >&2
  exit 1
}

[[ -f "$SOURCE" ]] || fail "missing $SOURCE"

grep -Fq 'private static let binaryOperators: Set<Character>' "$SOURCE" || fail "binary operator normalization missing"
grep -Fq 'appendDecimalPoint()' "$SOURCE" || fail "decimal de-duplication path missing"
grep -Fq 'appendOperator(character)' "$SOURCE" || fail "operator replacement path missing"
grep -Fq 'unmatchedOpeningParentheses' "$SOURCE" || fail "parenthesis validation missing"
grep -Fq 'value >= Double(Int.min)' "$SOURCE" || fail "lower Int conversion bound missing"
grep -Fq 'value <= Double(Int.max)' "$SOURCE" || fail "upper Int conversion bound missing"
grep -Fq 'reserve Error for an explicit equals evaluation' "$SOURCE" || fail "in-progress expression recovery contract missing"
grep -Fq '.accessibilityLabel(accessibilityLabel(for: key))' "$SOURCE" || fail "keypad accessibility labels missing"
grep -Fq '.accessibilityValue(calculator.result)' "$SOURCE" || fail "result accessibility value missing"

# Division-by-zero and malformed expressions must remain explicit equals errors.
grep -Fq 'if token == "/" && rhs == 0 { return nil }' "$SOURCE" || fail "division-by-zero parser guard missing"
grep -Fq 'result = "Error"' "$SOURCE" || fail "explicit evaluation error state missing"

# Guard against reintroducing the unsafe integral formatting shortcut.
if grep -Fq 'value.rounded() == value ? String(Int(value))' "$SOURCE"; then
  fail "unsafe unbounded Double-to-Int formatting returned"
fi

echo "Calculator reliability contract passed"
