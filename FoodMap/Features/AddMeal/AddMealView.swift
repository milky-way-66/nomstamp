import SwiftUI
import PhotosUI
import FoodMapDomain

/// UC-1 — photograph the food and store it. The core loop, so it stays short: photos, place,
/// save. Everything else is optional (NFR-4.1).
struct AddMealView: View {
    let dependencies: AppDependencies
    /// Set when arriving from a place's "I ate here" (UC-6).
    let preselected: Place?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var photoData: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false

    @State private var target: MealTarget?
    @State private var targetName: String = ""
    @State private var context: MealContext?

    /// FR-1.4 — set only once the user edits the time by hand; until then the
    /// photo's EXIF time (or the clock) wins.
    @State private var editedEatenAt: Date?

    @State private var dishName = ""
    @State private var rating: Int?
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                photosSection
                placeSection
                timeSection
                detailsSection
                if let context, context.derivedFromPhoto {
                    Section {
                        Label(
                            "Using the time and place from your photo",
                            systemImage: "clock.arrow.circlepath"
                        )
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Add a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("saveMealButton")
                        .disabled(!canSave || isSaving)
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { data in photoData.append(data) }
                    .ignoresSafeArea()
            }
            .alert("Couldn't save", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await prepare() }
            .onChange(of: pickerItems) { _, items in
                Task {
                    photoData.append(contentsOf: await PhotoLibraryLoader.load(items))
                    pickerItems = []
                    await refreshContext()
                }
            }
        }
    }

    private var canSave: Bool {
        !photoData.isEmpty && target != nil
    }

    private var photosSection: some View {
        Section("The food") {
            if !photoData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photoData.enumerated()), id: \.offset) { index, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            photoData.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.5))
                                        }
                                        .padding(3)
                                    }
                            }
                        }
                    }
                }
            }

            if AppDependencies.isUITesting {
                Button {
                    photoData.append(dependencies.testPhotoData())
                    Task { await refreshContext() }
                } label: {
                    Label("Use a test photo", systemImage: "photo")
                }
                .accessibilityIdentifier("useTestPhotoButton")
            }

            if CameraPicker.isAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera.fill")
                }
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
        }
    }

    private var placeSection: some View {
        Section("Where") {
            NavigationLink {
                PlacePickerView(
                    dependencies: dependencies,
                    around: context?.coordinate
                ) { picked, name in
                    target = picked
                    targetName = name
                }
            } label: {
                HStack {
                    Text(targetName.isEmpty ? "Choose the place" : targetName)
                        .font(targetName.isEmpty ? Theme.label(.body) : Theme.display(.body))
                        .foregroundStyle(targetName.isEmpty ? Theme.inkSecondary : Theme.ink)
                        .lineSpacing(Theme.minimumLineSpacing)
                    Spacer()
                }
            }
        }
    }

    /// FR-1.4 — the time is suggested, never imposed.
    private var timeSection: some View {
        Section("When") {
            DatePicker(
                "Eaten at",
                selection: Binding(
                    get: { editedEatenAt ?? context?.eatenAt ?? Date() },
                    set: { editedEatenAt = $0 }
                ),
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("eatenAtPicker")
            .font(Theme.label(.body))

            if editedEatenAt != nil {
                Button("Use the photo's time") { editedEatenAt = nil }
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.lacquer)
            }
        }
    }

    private var detailsSection: some View {
        Section("Optional") {
            TextField("Dish name", text: $dishName)
            Picker("Rating", selection: Binding(
                get: { rating ?? 0 },
                set: { rating = $0 == 0 ? nil : $0 }
            )) {
                Text("None").tag(0)
                ForEach(1...5, id: \.self) { value in
                    Text(String(repeating: "★", count: value)).tag(value)
                }
            }
            TextField("Note", text: $note, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private func prepare() async {
        if let preselected {
            target = .existingPlace(preselected.id)
            targetName = preselected.name
        }
        await refreshContext()
    }

    private func refreshContext() async {
        context = await dependencies.suggestContext.execute(photoData: photoData)
    }

    private func save() {
        guard let target else { return }
        isSaving = true
        do {
            try dependencies.logMeal.execute(
                LogMealRequest(
                    target: target,
                    photoData: photoData,
                    dishName: dishName.isEmpty ? nil : dishName,
                    rating: rating,
                    note: note.isEmpty ? nil : note,
                    eatenAt: editedEatenAt ?? context?.eatenAt
                )
            )
            onSaved()
            dismiss()
        } catch {
            // The use case rolls back, so nothing partial was written (FR-1.8).
            errorMessage = "\(error.localizedDescription) Nothing was saved — you can try again."
            isSaving = false
        }
    }
}
