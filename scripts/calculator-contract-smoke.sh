#!/usr/bin/env bash
set -euo pipefail

SOURCE="iOS/DesktopUtilityCenter.swift"
KEYBOARD="iOS/Desktop/Controller/DesktopHardwareKeyboardReceiver.swift"
APP="iOS/KamihiDesktopApp.swift"
POINTER="iOS/Desktop/Apps/Calculator/DesktopCalculatorHitRegistry.swift"
SESSION="iOS/Desktop/DesktopSessionExtensions.swift"

fail() {
  echo "Calculator contract failed: $1" >&2
  exit 1
}

[[ -f "$SOURCE" ]] || fail "missing $SOURCE"
[[ -f "$KEYBOARD" ]] || fail "missing $KEYBOARD"
[[ -f "$APP" ]] || fail "missing $APP"
[[ -f "$POINTER" ]] || fail "missing $POINTER"
[[ -f "$SESSION" ]] || fail "missing $SESSION"

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

# Hardware keyboard Calculator routing must stay local and transport-independent.
grep -Fq 'desktop.activeWindow?.title == "Calculator"' "$KEYBOARD" || fail "Calculator hardware-keyboard focus route missing"
grep -Fq 'routeCalculatorText(text)' "$KEYBOARD" || fail "Calculator hardware-keyboard text router missing"
grep -Fq 'DesktopCalculatorStore.shared.backspace()' "$KEYBOARD" || fail "Calculator hardware delete routing missing"
grep -Fq 'calculator.evaluate()' "$KEYBOARD" || fail "Calculator equals/return routing missing"
grep -Fq 'case "*", "×":' "$KEYBOARD" || fail "hardware multiply mapping missing"
grep -Fq 'case "/", "÷":' "$KEYBOARD" || fail "hardware divide mapping missing"
grep -Fq 'case "-", "−":' "$KEYBOARD" || fail "hardware subtract mapping missing"
grep -Fq 'desktop.wantsPhoneKeyboard || desktop.activeWindow?.title == "Calculator"' "$APP" || fail "frontmost Calculator does not keep hardware receiver active"

# Phone-controlled software pointer must hit the real rendered keypad geometry,
# not approximate fixed coordinates that drift after window resize or on iPad.
grep -Fq '.desktopCalculatorHitTarget(.toolbarClear, containerSize: calculatorGeo.size)' "$SOURCE" || fail "toolbar clear geometry reporting missing"
grep -Fq '.desktopCalculatorHitTarget(.key(key), containerSize: calculatorGeo.size)' "$SOURCE" || fail "keypad geometry reporting missing"
grep -Fq '.coordinateSpace(name: "desktopCalculatorContent")' "$SOURCE" || fail "Calculator local coordinate space missing"
grep -Fq 'DesktopCalculatorHitRegistry.shared.update(' "$SOURCE" || fail "Calculator hit registry update missing"
grep -Fq 'func hitTest(at normalizedPoint: CGPoint)' "$POINTER" || fail "Calculator hit testing missing"
grep -Fq 'func handleCalculatorClick(at point: CGPoint, in frame: CGRect)' "$POINTER" || fail "Calculator pointer handler missing"
grep -Fq 'if window.title == "Calculator" {' "$SESSION" || fail "Calculator top-window click dispatch missing"
grep -Fq 'handleCalculatorClick(at: cursor, in: frame)' "$SESSION" || fail "Calculator software-pointer click routing missing"
grep -Fq 'window.title != "Calculator"' "$SESSION" || fail "Calculator context clicks still fall through to WebKit"

# Guard against reintroducing the unsafe integral formatting shortcut.
if grep -Fq 'value.rounded() == value ? String(Int(value))' "$SOURCE"; then
  fail "unsafe unbounded Double-to-Int formatting returned"
fi

echo "Calculator reliability contract passed"
