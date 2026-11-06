import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}

/// The to-do items and the three things you can do to them. Pure, so it is tested without the app.
struct TodoList: Codable, Equatable {
    private(set) var items: [TodoItem] = []

    mutating func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { items.append(TodoItem(title: trimmed)) }
    }

    mutating func toggle(_ id: UUID) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].done.toggle() }
    }

    mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }
}
