import XCTest

final class TodoListTests: XCTestCase {
    func testAddTrimsAndIgnoresBlank() {
        var list = TodoList()
        list.add("  buy milk ")
        list.add("   ")
        XCTAssertEqual(list.items.map(\.title), ["buy milk"])
    }

    func testToggleAndRemove() {
        var list = TodoList()
        list.add("a"); list.add("b")
        let id = list.items[0].id
        list.toggle(id)
        XCTAssertTrue(list.items[0].done)
        list.remove(id)
        XCTAssertEqual(list.items.map(\.title), ["b"])
    }
}
