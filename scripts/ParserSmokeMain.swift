import Foundation

@main
enum ParserSmokeMain {
    static func main() {
        let passed = RemotePacket.runSelfChecks()
        guard passed else {
            fputs("parser self-checks failed\n", stderr)
            exit(1)
        }
        print("parser self-checks passed")
    }
}
