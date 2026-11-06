import SwiftUI

/// A to-do list kept in this app's UserDefaults. Nothing leaves the Mac.
@MainActor @Observable
final class TodoModule: IslandModule {
    static let id = "todo"
    static let title = "To-do"
    private static let key = "todo.list"

    private(set) var list: TodoList
    var tab: IslandTab { .todo }
    var expanded: AnyView? { AnyView(TodoView(module: self)) }

    init() {
        list = UserDefaults.standard.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(TodoList.self, from: $0) } ?? TodoList()
    }

    func start() {}
    func stop() {}

    func add(_ title: String) { change { $0.add(title) } }
    func toggle(_ id: UUID) { change { $0.toggle(id) } }
    func remove(_ id: UUID) { change { $0.remove(id) } }

    private func change(_ edit: (inout TodoList) -> Void) {
        edit(&list)
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: Self.key)
    }
}
