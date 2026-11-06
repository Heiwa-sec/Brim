import SwiftUI

struct TodoView: View {
    let module: TodoModule
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 8) {
            TextField("Add a task", text: $draft)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .glassEffect(in: .capsule)
                .onSubmit { module.add(draft); draft = "" }
            if module.list.items.isEmpty {
                Text("Nothing to do").font(.callout).foregroundStyle(.white.opacity(0.5)).frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) { ForEach(module.list.items) { row($0) } }
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button { module.toggle(item.id) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle").font(.system(size: 15))
            }
            .accessibilityLabel(item.done ? "Mark not done" : "Mark done")
            Text(item.title).lineLimit(1).strikethrough(item.done).opacity(item.done ? 0.45 : 1)
            Spacer()
            Button { module.remove(item.id) } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityLabel("Delete")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6).padding(.vertical, 3)
    }
}
