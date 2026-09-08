import Combine
import Foundation

@MainActor
final class DesktopCalculatorPersistence {
    static let shared = DesktopCalculatorPersistence()

    private enum Keys {
        static let expression = "kamihi.desktop.calculator.expression"
        static let result = "kamihi.desktop.calculator.result"
    }

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private(set) var isActive = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activate() {
        guard !isActive else { return }
        isActive = true

        let calculator = DesktopCalculatorStore.shared

        if let storedExpression = defaults.string(forKey: Keys.expression),
           Self.isValidExpression(storedExpression) {
            calculator.expression = storedExpression
        } else if defaults.object(forKey: Keys.expression) != nil {
            defaults.removeObject(forKey: Keys.expression)
        }

        if let storedResult = defaults.string(forKey: Keys.result),
           Self.isValidResult(storedResult) {
            calculator.result = storedResult
        } else if defaults.object(forKey: Keys.result) != nil {
            defaults.removeObject(forKey: Keys.result)
        }

        calculator.$expression
            .dropFirst()
            .sink { [weak self] expression in
                guard let self else { return }
                if Self.isValidExpression(expression) {
                    self.defaults.set(expression, forKey: Keys.expression)
                } else {
                    self.defaults.removeObject(forKey: Keys.expression)
                }
            }
            .store(in: &cancellables)

        calculator.$result
            .dropFirst()
            .sink { [weak self] result in
                guard let self else { return }
                if Self.isValidResult(result) {
                    self.defaults.set(result, forKey: Keys.result)
                } else {
                    self.defaults.removeObject(forKey: Keys.result)
                }
            }
            .store(in: &cancellables)
    }

    private static func isValidExpression(_ value: String) -> Bool {
        guard value.count <= 256 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.+−×÷()")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isValidResult(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        if value == "Error" { return true }
        let allowed = CharacterSet(charactersIn: "0123456789.+-eE")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
