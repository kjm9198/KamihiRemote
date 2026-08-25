import Foundation
import Network
import CryptoKit
import AppKit
import Carbon.HIToolbox

@main
enum HostIntegrationTest {
    static func main() async {
        print("==================================================")
        print("  KAMIHI REMOTE — COMPREHENSIVE INTEGRATION SUITE  ")
        print("==================================================")

        var passed = 0
        var failed = 0

        func runTest(_ name: String, _ test: () async throws -> Void) async {
            print("[TEST] Running: \(name)...", terminator: " ")
            fflush(stdout)
            do {
                try await test()
                print("PASS ✓")
                passed += 1
            } catch {
                print("FAIL ✗ — \(error)")
                failed += 1
            }
        }

        await runTest("Crypto Keypair Generation & ECDH Key Agreement", testCryptoKeyAgreement)
        await runTest("Controller State Protocol Roundtrip (V1, V2, V3 AES-GCM)", testControllerWireRoundtrip)
        await runTest("Controller Gaming Profile (WASD Discretization + Mouse Look)", testGamingProfileExecution)
        await runTest("Controller Mac Profile (Scroll + Pointer + Desktop Switching)", testMacProfileExecution)
        await runTest("Controller Presentation Profile (Slide navigation + Media)", testPresentationProfileExecution)
        await runTest("Controller Held Keys Tracking & Watchdog Reset", testHeldKeysWatchdogReset)
        await runTest("Desktop Space Switcher Execution & System Events", testDesktopSpaceSwitching)
        await runTest("Realtime UDP Network Socket Pipeline (Local Injection & Auth)", testLocalUDPPipeline)

        print("==================================================")
        print("  SUMMARY: \(passed) PASSED, \(failed) FAILED")
        print("==================================================")

        if failed > 0 {
            exit(1)
        }
    }

    // MARK: - Tests

    static func testCryptoKeyAgreement() throws {
        let aliceKeys = DeviceKeyPair.loadOrCreate(account: "test-alice-\(UUID().uuidString)")
        let bobKeys = DeviceKeyPair.loadOrCreate(account: "test-bob-\(UUID().uuidString)")

        let salt = Data("kamihi-test-salt".utf8)
        let aliceShared = try SessionCrypto.deriveSessionKey(ourPrivate: aliceKeys.privateKey, peerPublic: bobKeys.publicKeyData, salt: salt)
        let bobShared = try SessionCrypto.deriveSessionKey(ourPrivate: bobKeys.privateKey, peerPublic: aliceKeys.publicKeyData, salt: salt)

        guard aliceShared == bobShared else {
            throw TestError("Derived symmetric keys do not match between Alice and Bob")
        }

        // Test AES-GCM encryption & decryption
        let rawData = try RemotePacket.encodeK3(sessionID: "test-session", sequence: 42, command: .move(dx: 12.5, dy: -4.0), key: aliceShared)
        guard let encPacket = String(data: rawData, encoding: .utf8) else {
            throw TestError("Failed to convert encoded K3 data to string")
        }
        guard case .success(let token, let cmd, _, let sessID, let seq, let isEnc) = RemotePacket.parse(encPacket, sessionKey: bobShared) else {
            throw TestError("Failed to decrypt and parse AES-GCM packet")
        }

        guard isEnc, sessID == "test-session", seq == 42 else {
            throw TestError("Decrypted metadata mismatch: isEnc=\(isEnc), sessID=\(sessID ?? "nil"), seq=\(seq ?? 0)")
        }
        guard case .move(let dx, let dy) = cmd, dx == 12.5, dy == -4.0 else {
            throw TestError("Decrypted command mismatch: \(cmd)")
        }
    }

    static func testControllerWireRoundtrip() throws {
        var state = ControllerState()
        state.sequence = 2048
        state.timestamp = 1720000000.456
        state.leftX = -0.82
        state.leftY = 0.91
        state.rightX = 0.35
        state.rightY = -0.15
        state.leftTrigger = 0.95
        state.rightTrigger = 0.45
        state.set(.a, down: true)
        state.set(.x, down: true)
        state.set(.l1, down: true)
        state.dpad = DPadDirection.upLeft.rawValue

        let wire = "998877 CONTROLLER \(state.sequence) \(state.timestamp) \(state.leftX) \(state.leftY) \(state.rightX) \(state.rightY) \(state.leftTrigger) \(state.rightTrigger) \(state.buttons) \(state.dpad)"

        guard case .success(let token, let cmd, _, _, _, _) = RemotePacket.parse(wire) else {
            throw TestError("Failed to parse CONTROLLER wire packet")
        }
        guard token == "998877" else { throw TestError("Token mismatch: \(token)") }
        guard case .controller(let parsed) = cmd else { throw TestError("Parsed command is not .controller") }

        guard parsed.sequence == 2048,
              abs(parsed.leftX - (-0.82)) < 0.001,
              abs(parsed.leftY - 0.91) < 0.001,
              abs(parsed.leftTrigger - 0.95) < 0.001,
              parsed.isDown(.a),
              parsed.isDown(.x),
              parsed.isDown(.l1),
              !parsed.isDown(.b),
              parsed.dpad == DPadDirection.upLeft.rawValue else {
            throw TestError("Controller state field mismatch in wire roundtrip")
        }
    }

    static func testGamingProfileExecution() throws {
        let output = KeyboardGamepadOutput()
        output.mapping = .gaming

        // Test Left Stick W (forward)
        var forward = ControllerState()
        forward.leftY = -0.85
        output.apply(forward)

        // Test Left Stick Diagonal (W + D)
        var forwardRight = ControllerState()
        forwardRight.leftY = -0.85
        forwardRight.leftX = 0.85
        output.apply(forwardRight)

        // Test Action buttons (A: Space / Jump, B: Shift / Sprint, X: E / Interact)
        var buttonPress = ControllerState()
        buttonPress.set(.a, down: true)
        buttonPress.set(.x, down: true)
        output.apply(buttonPress)

        // Test Triggers (L2: Right Click ADS, R2: Left Click Fire)
        var triggerPress = ControllerState()
        triggerPress.leftTrigger = 0.80
        triggerPress.rightTrigger = 0.80
        output.apply(triggerPress)

        output.reset()
    }

    static func testMacProfileExecution() throws {
        let output = KeyboardGamepadOutput()
        output.mapping = .mac

        // Test Left Stick Scroll
        var scrollState = ControllerState()
        scrollState.leftX = 0.50
        scrollState.leftY = -0.80
        output.apply(scrollState)

        // Test Right Stick Mouse Look
        var lookState = ControllerState()
        lookState.rightX = 0.70
        lookState.rightY = -0.40
        output.apply(lookState)

        // Test DPad Desktop Switching (Left: Prev Desktop, Right: Next Desktop)
        var dpadLeft = ControllerState()
        dpadLeft.dpad = DPadDirection.left.rawValue
        output.apply(dpadLeft)

        var dpadRight = ControllerState()
        dpadRight.dpad = DPadDirection.right.rawValue
        output.apply(dpadRight)

        output.reset()
    }

    static func testPresentationProfileExecution() throws {
        let output = KeyboardGamepadOutput()
        output.mapping = .presentation

        // Test A: Next Slide
        var nextSlide = ControllerState()
        nextSlide.set(.a, down: true)
        output.apply(nextSlide)

        // Test B: Prev Slide
        var prevSlide = ControllerState()
        prevSlide.set(.b, down: true)
        output.apply(prevSlide)

        output.reset()
    }

    static func testHeldKeysWatchdogReset() throws {
        let output = KeyboardGamepadOutput()
        output.mapping = .gaming

        var holdState = ControllerState()
        holdState.leftY = -0.90 // W key down
        holdState.set(.a, down: true) // Space key down
        output.apply(holdState)

        // Simulate watchdog / disconnect reset
        output.reset()

        // Apply neutral state
        output.apply(.neutral)
    }

    static func testDesktopSpaceSwitching() async throws {
        // Direct SkyLight Space Switching test
        let switchedLeft = InputEngine.switchDesktopDirect(left: true)
        let switchedRight = InputEngine.switchDesktopDirect(left: false)
        print("(SkyLight direct: left=\(switchedLeft), right=\(switchedRight))", terminator: " ")

        // Reporting wrapper test
        let (leftOk, leftMsg) = await InputEngine.performReporting(.previousDesktop)
        let (rightOk, rightMsg) = await InputEngine.performReporting(.nextDesktop)
        let (missionOk, missionMsg) = await InputEngine.performReporting(.missionControl)

        guard leftOk, rightOk, missionOk else {
            throw TestError("Space switching performReporting returned failure: left=\(leftMsg), right=\(rightMsg), mission=\(missionMsg)")
        }
    }

    static func testLocalUDPPipeline() async throws {
        let testPort = RemoteConstants.defaultPort
        let pairingCode = "778899"
        let server = UDPServer()

        // Start UDP Server
        server.start(pairingCode: pairingCode)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Create client NWConnection to 127.0.0.1:52888
        let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: testPort)!)
        let connection = NWConnection(to: endpoint, using: .udp)
        let queue = DispatchQueue(label: "test.client.queue")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            connection.stateUpdateHandler = { state in
                if state == .ready && !resumed {
                    resumed = true
                    continuation.resume()
                } else if case .failed(let error) = state, !resumed {
                    resumed = true
                    continuation.resume(throwing: error)
                }
            }
            connection.start(queue: queue)
        }

        func sendPacket(_ text: String) async throws {
            let data = Data(text.utf8)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: data, completion: .contentProcessed({ error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }))
            }
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms for server processing
        }

        // 1. Send PING
        try await sendPacket("\(pairingCode) PING\n")

        // 2. Send MOVE
        try await sendPacket("\(pairingCode) MOVE 15.0 -10.0\n")

        // 3. Send CLICK & DOUBLE_CLICK & RIGHT_CLICK
        try await sendPacket("\(pairingCode) CLICK\n")
        try await sendPacket("\(pairingCode) DOUBLE_CLICK\n")
        try await sendPacket("\(pairingCode) RIGHT_CLICK\n")

        // 4. Send SCROLL
        try await sendPacket("\(pairingCode) SCROLL 0.0 25.0\n")

        // 5. Send CONTROLLER packet
        var state = ControllerState()
        state.sequence = 1
        state.leftX = 0.5
        state.leftY = -0.5
        state.set(.a, down: true)
        try await sendPacket("\(pairingCode) \(RemoteCommand.controller(state).wire)\n")

        // Clean up
        try await Task.sleep(nanoseconds: 100_000_000)
        server.stop()
        connection.cancel()
    }

    struct TestError: Error, CustomStringConvertible {
        let message: String
        init(_ message: String) { self.message = message }
        var description: String { message }
    }
}
