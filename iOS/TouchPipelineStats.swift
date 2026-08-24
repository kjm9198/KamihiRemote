import Foundation

struct TouchPipelineStats: Equatable {
    var touchActive = false
    var touchCount = 0
    var x = 0.0
    var y = 0.0
    var dx = 0.0
    var dy = 0.0
    var packetsSent = 0
    var moveSent = 0
    var movePerSecond = 0
    var activeFingers = 0
}
