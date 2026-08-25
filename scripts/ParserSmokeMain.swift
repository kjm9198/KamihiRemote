import Foundation

@main
enum ParserSmokeMain {
    static func main() {
        let packetOk = RemotePacket.runSelfChecks()
        guard packetOk else {
            fputs("packet self-checks failed\n", stderr)
            exit(1)
        }
        let cryptoOk = SessionCrypto.runSelfChecks()
        guard cryptoOk else {
            fputs("crypto self-checks failed\n", stderr)
            exit(1)
        }
        let gestureOk = GestureEngineTests.runSelfChecks()
        guard gestureOk else {
            fputs("gesture self-checks failed\n", stderr)
            exit(1)
        }
        print("ALL SELF-CHECKS PASSED (Packets, Crypto, Gestures & Controller)")
    }
}
