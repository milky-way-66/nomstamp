import SwiftUI
import FoodMapDomain

/// UC-8 — the ceremony, which is four steps and has to survive a noisy restaurant.
///
/// The shape matters more than any one screen. There is **no role**: neither reader is the one
/// who shows and the other the one who scans. Both see the same list, both tap each other, both
/// see the same four letters, both write a name. Flows of this kind fail in practice when one
/// person has to work out which half of the ceremony they are performing (ADR-009).
struct AddFriendView: View {
    let dependencies: AppDependencies

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .looking
    @State private var nearby: [NearbyReader] = []
    @State private var assignedName = ""
    @State private var refusal: CircleRefusal?
    @FocusState private var nameFocused: Bool

    private enum Step: Equatable {
        case looking
        case confirming(NearbyReader, word: String, result: HandshakeResult)
        case naming(HandshakeResult)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .looking: looking
                case .confirming(_, let word, _): confirming(word: word)
                case .naming: naming
                }
            }
            .background(Theme.paper)
            .navigationTitle(Text("Add friend"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel") }
                }
            }
            .task { await scan() }
            .alert(
                Text("Can't add them"),
                isPresented: Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })
            ) {
                Button { refusal = nil } label: { Text("OK") }
            } message: {
                switch refusal {
                case .full:
                    Text("Eight friends is the most. Remove someone first.")
                case .alreadyConnected:
                    Text("They are already on your map.")
                case .notInPerson, .none:
                    // The one refusal that is a physical fact rather than a policy.
                    Text("They moved out of range. Sit closer and try again.")
                }
            }
        }
    }

    // MARK: - 1. Who is here

    private var looking: some View {
        VStack(spacing: Theme.Space.loose) {
            if nearby.isEmpty {
                ProgressView()
                Text("Looking for phones in the room…")
                    .font(Theme.label())
                    .foregroundStyle(Theme.inkSecondary)
                Text("They need this screen open too.")
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                List(nearby, id: \.ephemeralID) { reader in
                    Button {
                        Task { await handshake(with: reader) }
                    } label: {
                        HStack {
                            // The name they assert, plainly marked as theirs to claim. It is a
                            // suggestion for the next step and is never what gets stored.
                            Text(reader.assertedName)
                                .font(Theme.label(.body))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            SignalBars(strength: reader.proof.signalStrength)
                        }
                    }
                    .listRowBackground(Theme.paperRaised)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.screenMargin)
    }

    // MARK: - 2. The matching word

    private func confirming(word: String) -> some View {
        VStack(spacing: Theme.Space.loose) {
            Spacer()

            Text(word)
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .kerning(8)
                .foregroundStyle(Theme.ink)
                .accessibilityLabel(Text("Matching word"))
                .accessibilityValue(word.map(String.init).joined(separator: " "))

            // Symmetric on purpose: the same four letters on both phones, so neither reader has
            // a role to work out (TC-8-06).
            Text("Both phones should show these four letters. If they don't, stop — someone else is answering.")
                .font(Theme.label())
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                if case .confirming(_, _, let result) = step {
                    step = .naming(result)
                    nameFocused = true
                }
            } label: {
                Text("They match")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.screenMargin)
    }

    // MARK: - 3. Naming, which is what completes the connection

    private var naming: some View {
        VStack(alignment: .leading, spacing: Theme.Space.regular) {
            Text("What do you call them?")
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.ink)

            TextField(text: $assignedName) {
                Text("Name")
            }
            .textFieldStyle(.roundedBorder)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit(connect)

            // This is the whole impersonation defence, and it is a product decision rather than a
            // cryptographic one: no string anyone else chose is ever drawn on this device, so
            // there is nothing for a fingerprint to defend in everyday use (FR-10.6).
            Text("This is your name for them and stays on your phone. They never see it, and they can't change it.")
                .font(Theme.label(.footnote))
                .foregroundStyle(Theme.inkSecondary)

            Spacer()

            Button(action: connect) {
                Text("Add to my map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(assignedName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Theme.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Doing it

    private func scan() async {
        guard let proximity = dependencies.proximity else { return }
        while !Task.isCancelled, case .looking = step {
            nearby = (try? await proximity.nearbyReaders()) ?? []
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func handshake(with reader: NearbyReader) async {
        guard let handshake = dependencies.handshake,
              let identity = dependencies.peerIdentity,
              let result = try? await handshake.exchange(with: reader)
        else { return }
        let word = VerificationWord.derive(
            identity.publicKey,
            result.key,
            using: dependencies.digest
        )
        step = .confirming(reader, word: word, result: result)
    }

    private func connect() {
        guard case .naming(let result) = step else { return }
        do {
            try dependencies.friends.connectFriend(
                key: result.key,
                named: assignedName.trimmingCharacters(in: .whitespaces),
                proof: result.proof
            )
            dismiss()
        } catch let refused as CircleRefusal {
            refusal = refused
        } catch {
            refusal = .notInPerson
        }
    }
}

/// Signal strength as three bars. Not a number: dBm is not a thing to show a person, and the
/// only question the reader has is *is this the phone across the table or the one behind me*.
private struct SignalBars: View {
    let strength: Int

    private var filled: Int {
        switch strength {
        case (-45)...: return 3
        case (-55)..<(-45): return 2
        default: return 1
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { bar in
                Capsule()
                    .fill(bar <= filled ? Theme.ink : Theme.rule)
                    .frame(width: 3, height: CGFloat(bar) * 4 + 3)
            }
        }
        .accessibilityHidden(true)
    }
}
