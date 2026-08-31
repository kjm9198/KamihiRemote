import Foundation

/// Defines dynamic contextual states of the pointer.
public enum CursorInteractionState: Equatable {
    case defaultState
    case hoveringLink
    case clicking
    case dragging
    case textEditing
    case resizing(edge: String)
    case busy
}
