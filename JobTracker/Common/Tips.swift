import TipKit

/// #6 — TipKit hints surfaced at the right moments.
/// Each Tip is shown once and dismissed with either an interaction or the built-in close.

struct KanbanDragTip: Tip {
    var title: Text { Text("Drag to move") }
    var message: Text? { Text("Drop a card in another column to change status. Haptics confirm the move.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct SwipeToPromoteTip: Tip {
    var title: Text { Text("Swipe to promote") }
    var message: Text? { Text("Swipe right on an application to jump to any pipeline stage.") }
    var image: Image? { Image(systemName: "arrow.right.circle") }
}

struct QuickAddTip: Tip {
    var title: Text { Text("Quick Add from text") }
    var message: Text? { Text("Paste a sentence like \"Apple iOS Engineer Munich applied today\" and we'll extract the fields.") }
    var image: Image? { Image(systemName: "sparkles") }
}

enum TipKitSetup {
    static func configure() {
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
}
