import SwiftUI

/// Apple requires a parental gate before purchases in Kids apps.
struct ParentalGate: View {
    let onPass: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var a = Int.random(in: 3...9)
    @State private var b = Int.random(in: 3...9)
    @State private var answer = ""
    @State private var shake = false

    var body: some View {
        VStack(spacing: 28) {
            Text("Ask a grown-up")
                .font(.title2.weight(.bold))
            Text("To continue, please solve:")
                .foregroundStyle(.secondary)

            Text("\(a) × \(b) = ?")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .modifier(Shake(animatableData: shake ? 1 : 0))

            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .frame(width: 160)
                .padding(.vertical, 10)
                .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            Button("Continue") { check() }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding(36)
    }

    private func check() {
        if Int(answer) == a * b {
            onPass()
            dismiss()
        } else {
            answer = ""
            a = Int.random(in: 3...9); b = Int.random(in: 3...9)
            withAnimation(.default) { shake.toggle() }
        }
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = 8 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
