import Foundation

struct HostPipelineStats: Equatable {
    var packetsReceived = 0
    var packetsPerSecond = 0
    var movePackets = 0
    var movePacketsPerSecond = 0
    var accepted = 0
    var rejected = 0
    var lastRejection = "—"
    var lastCommand = "—"
    var lastDx = "—"
    var lastDy = "—"
    var cgEventsPosted = 0
    var lastPacketAt = "—"
    var lastTestResult = "—"
    var clientIP = "—"
    var lastRawPacket = "—"
    var lastParsed = "—"
    var droppedStale = 0
    var rttMilliseconds = 0
    var sessionID = "—"
    var reconnects = 0
}
