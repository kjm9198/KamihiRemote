#!/usr/bin/env bash
set -euo pipefail

SOURCE="iOS/DesktopUtilityCenter.swift"
PERSISTENCE="iOS/Desktop/Apps/Calculator/DesktopCalculatorPersistence.swift"
KEYBOARD="iOS/Desktop/Controller/DesktopHardwareKeyboardReceiver.swift"
CONTROLLER="iOS/Desktop/Controller/DesktopControllerView.swift"
APP="iOS/KamihiDesktopApp.swift"
POINTER="iOS/Desktop/Apps/Calculator/DesktopCalculatorHitRegistry.swift"
SESSION="iOS/Desktop/DesktopSessionExtensions.swift"
LIFECYCLE="iOS/Desktop/Debug/DesktopCalculatorLifecycleSmoke.swift"
SIM_SMOKE="scripts/apple-integration-smoke.sh"

fail() {
  echo "Calculator contract failed: $1" >&2
  exit 1
}

[[ -f "$SOURCE" ]] || fail "missing $SOURCE"
[[ -f "$PERSISTENCE" ]] || fail "missing $PERSISTENCE"
[[ -f "$KEYBOARD" ]] || fail "missing $KEYBOARD"
[[ -f "$CONTROLLER" ]] || fail "missing $CONTROLLER"
[[ -f "$APP" ]] || fail "missing $APP"
[[ -f "$POINTER" ]] || fail "missing $POINTER"
[[ -f "$SESSION" ]] || fail "missing $SESSION"
[[ -f "$LIFECYCLE" ]] || fail "missing $LIFECYCLE"
[[ -f "$SIM_SMOKE" ]] || fail "missing $SIM_SMOKE"

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

# Calculator value must survive a real app-process restart through small,
# calculator-owned UserDefaults state. Corrupt/oversized state is rejected.
grep -Fq 'kamihi.desktop.calculator.expression' "$PERSISTENCE" || fail "persisted expression key missing"
grep -Fq 'kamihi.desktop.calculator.result' "$PERSISTENCE" || fail "persisted result key missing"
grep -Fq 'DesktopCalculatorStore.shared' "$PERSISTENCE" || fail "Calculator persistence is not attached to the local store"
grep -Fq 'value.count <= 256' "$PERSISTENCE" || fail "persisted expression size bound missing"
grep -Fq 'value.count <= 64' "$PERSISTENCE" || fail "persisted result size bound missing"
grep -Fq 'DesktopCalculatorPersistence.shared.activate()' "$APP" || fail "Calculator persistence is not activated during app launch"
grep -Fq 'persistenceVerifyLaunchArgument' "$LIFECYCLE" || fail "process-restart verification launch argument missing"
grep -Fq 'KAMIHI_CALCULATOR_PROCESS_RESTART_OK' "$LIFECYCLE" || fail "process-restart runtime success marker missing"
grep -Fq 'run_calculator_process_restart_smoke' "$SIM_SMOKE" || fail "simulator process-restart gate missing"
grep -Fq -- '-KamihiCalculatorPersistenceVerifySmoke' "$SIM_SMOKE" || fail "process-restart relaunch argument missing"

# Hardware keyboard Calculator routing must stay local and transport-independent.
grep -Fq 'desktop.activeWindow?.title == "Calculator"' "$KEYBOARD" || fail "Calculator hardware-keyboard focus route missing"
grep -Fq 'routeCalculatorText(text)' "$KEYBOARD" || fail "Calculator hardware-keyboard text router missing"
grep -Fq 'DesktopCalculatorStore.shared.backspace()' "$KEYBOARD" || fail "Calculator hardware delete routing missing"
grep -Fq 'calculator.evaluate()' "$KEYBOARD" || fail "Calculator equals/return routing missing"
grep -Fq 'case "*", "×":' "$KEYBOARD" || fail "hardware multiply mapping missing"
grep -Fq 'case "/", "÷":' "$KEYBOARD" || fail "hardware divide mapping missing"
grep -Fq 'case "-", "−":' "$KEYBOARD" || fail "hardware subtract mapping missing"
grep -Fq 'desktop.wantsPhoneKeyboard || desktop.activeWindow?.title == "Calculator"' "$APP" || fail "frontmost Calculator does not keep hardware receiver active"

# Phone software keyboard must also stay Calculator-local instead of falling
# through the generic WebKit typing route.
grep -Fq 'activeWindowTitle == "Calculator" ? .numbersAndPunctuation : .default' "$CONTROLLER" || fail "Calculator phone keyboard type missing"
grep -Fq 'case "Calculator": return "Enter calculation…"' "$CONTROLLER" || fail "Calculator phone keyboard placeholder missing"
grep -Fq 'if activeWindowTitle == "Calculator" {' "$CONTROLLER" || fail "Calculator phone keyboard ownership missing"
grep -Fq 'DesktopCalculatorStore.shared.evaluate()' "$CONTROLLER" || fail "Calculator phone Return/equals routing missing"
grep -Fq 'DesktopCalculatorStore.shared.backspace()' "$CONTROLLER" || fail "Calculator phone delete routing missing"
grep -Fq 'routeCalculatorText(String(newChars.dropFirst(common)))' "$CONTROLLER" || fail "Calculator phone text routing missing"
grep -Fq 'case "*", "×":' "$CONTROLLER" || fail "phone multiply mapping missing"
grep -Fq 'case "/", "÷":' "$CONTROLLER" || fail "phone divide mapping missing"
grep -Fq 'case "-", "−":' "$CONTROLLER" || fail "phone subtract mapping missing"

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
