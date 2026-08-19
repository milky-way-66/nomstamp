import SwiftUI
import PhotosUI
import FoodMapDomain

/// UC-1 — photograph the food and store it.
///
/// Three steps, in the order the meal happens: **camera → rating → confirm**. The camera opens
/// on the first frame, because the tap that got here was "add a meal", not "fill in a form"
/// (FR-1.10). The score is the one question worth interrupting for. Everything else — place,
/// time — the app works out for itself (FR-1.11) and shows on the confirm step, where the user
/// changes only what is wrong.
struct AddMealView: View {
    let dependencies: AppDependencies
    /// Set when arriving from a place's "I ate here" (UC-6).
    let preselected: Place?
    let onSaved: () -> Void

    private enum Step {
        case capture
        case rate
        case confirm
    }

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .capture

    @State private var photoData: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    @State private var target: MealTarget?
    @State private var targetName: String = ""
    @State private var isResolvingPlace = false
    @State private var context: MealContext?

    /// FR-1.4 — set only once the user edits the time by hand; until then the
    /// photo's EXIF time (or the clock) wins.
    @State private var editedEatenAt: Date?

    @State private var dishName = ""
    @State private var rating: Int?
    @State private var note = ""
    @State private var isShowingDetails = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch step {
            case .capture: captureStep
            case .rate: rateStep
            case .confirm: confirmStep
            }
        }
        .task {
            // Arriving from "I ate here" (UC-6): the place is already known.
            if let preselected, target == nil {
                target = .existingPlace(preselected.id)
                targetName = preselected.name
            }
        }
    }

    // MARK: - Step 1 — the camera

    private var captureStep: some View {
        InAppCameraView(
            onCapture: { data in
                photoData.append(data)
                advanceAfterCapture()
            },
            // Backing out of the very first shot means backing out of the meal.
            onClose: {
                if photoData.isEmpty {
                    dismiss()
                } else {
                    step = .confirm
                }
            }
        ) {
            captureAlternatives
        }
    }

    /// The library is a peer of the shutter, not a rival: photographing later, from a picture
    /// you already took, is a first-class path (UC-1 / 1a).
    private var captureAlternatives: some View {
        HStack(spacing: Theme.Space.regular) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Choose from library")
            .accessibilityIdentifier("choosePhotoButton")

            if AppDependencies.isUITesting {
                Button {
                    photoData.append(dependencies.testPhotoData())
                    advanceAfterCapture()
                } label: {
                    Image(systemName: "photo")
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                }
                .accessibilityLabel("Use a test photo")
                .accessibilityIdentifier("useTestPhotoButton")
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                photoData.append(contentsOf: await PhotoLibraryLoader.load(items))
                pickerItems = []
                advanceAfterCapture()
            }
        }
    }

    /// The first photo earns the rating question; later ones just rejoin the confirm step.
    private func advanceAfterCapture() {
        let isFirst = photoData.count <= 1
        step = isFirst ? .rate : .confirm
        Task { await resolveContext() }
    }

    // MARK: - Step 2 — how was it?

    private var rateStep: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // A bar rather than a lone button at the foot of the screen: back to the
                // camera on one side, past the question on the other.
                HStack {
                    Button {
                        step = .capture
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    }
                    .accessibilityLabel("Back to the camera")
                    .accessibilityIdentifier("backToCameraButton")

                    Spacer()

                    Button {
                        step = .confirm
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    }
                    .accessibilityLabel("Skip the rating")
                    .accessibilityIdentifier("skipRatingButton")
                }
                .padding(.horizontal, Theme.Space.tight)
                .padding(.top, Theme.Space.tight)

                Spacer(minLength: Theme.Space.regular)

                VStack(spacing: Theme.Space.loose) {
                    if let data = photoData.last, let image = UIImage(data: data) {
                        // The photograph just taken is the subject of this screen, so it fills
                        // the width at the same ratio as everywhere else, rather than being
                        // square-cropped into a 208 pt tile (ADR-003).
                        Color.clear
                            .aspectRatio(Theme.photoAspect, contentMode: .fit)
                            .overlay(
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
                            )
                            .padding(.horizontal, Theme.screenMargin)
                    }

                    VStack(spacing: Theme.Space.snug) {
                        Text("How was it?")
                            .font(Theme.display(.title3))
                            .foregroundStyle(Theme.ink)

                        // A tap answers the question and moves on — the score is still editable
                        // on the confirm step, so there is nothing to lock in here (UC-7).
                        StarRatingView(rating: rating, onSelect: { score in
                            rating = score
                            step = .confirm
                        }, size: 32)
                    }
                }
                .padding(.horizontal, Theme.screenMargin)

                // Weighted so the block sits a little above centre, where the eye lands,
                // rather than marooned with equal air above and below.
                Spacer(minLength: Theme.Space.regular)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Step 3 — confirm what the app worked out

    private var confirmStep: some View {
        NavigationStack {
            Form {
                photosSection
                placeSection
                ratingSection
                detailsSection
            }
            .listSectionSpacing(Theme.Space.snug)
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
            .alert("Couldn't save", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canSave: Bool {
        !photoData.isEmpty && target != nil
    }

    private var photosSection: some View {
        Section {
            HStack(spacing: Theme.Space.tight) {
                ForEach(Array(photoData.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photoData.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                }
                                .padding(3)
                                .accessibilityLabel("Remove this photo")
                            }
                    }
                }

                Button {
                    step = .capture
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 68, height: 68)
                        .foregroundStyle(Theme.jade)
                        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Another photo")
                .accessibilityIdentifier("takePhotoButton")

                Spacer(minLength: 0)
            }
            .listRowInsets(EdgeInsets(top: Theme.Space.tight, leading: Theme.screenMargin, bottom: Theme.Space.tight, trailing: Theme.screenMargin))
        }
    }

    private var placeSection: some View {
        Section {
            NavigationLink {
                PlacePickerView(
                    dependencies: dependencies,
                    around: context?.coordinate
                ) { picked, name in
                    target = picked
                    targetName = name
                }
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.lacquer)
                    // The placeholder is a localized key; a chosen or suggested name is the
                    // provider's own text and stays verbatim.
                    if targetName.isEmpty {
                        // Two separate `Text`s, not a ternary: a ternary of two literals is a
                        // `String`, which skips the catalog and ships untranslated.
                        if isResolvingPlace {
                            Text("Finding where you are…")
                                .font(Theme.label(.body))
                                .foregroundStyle(Theme.inkSecondary)
                                .lineSpacing(Theme.minimumLineSpacing)
                        } else {
                            Text("Choose the place")
                                .font(Theme.label(.body))
                                .foregroundStyle(Theme.inkSecondary)
                                .lineSpacing(Theme.minimumLineSpacing)
                        }
                    } else {
                        Text(targetName)
                            .font(Theme.display(.body))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(Theme.minimumLineSpacing)
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityIdentifier("placeRow")
        }
    }

    /// UC-7 — the score, in the same control that displays it.
    private var ratingSection: some View {
        Section {
            HStack {
                Text("How was it?")
                    .font(Theme.label(.body))
                    .foregroundStyle(Theme.ink)
                Spacer()
                StarRatingView(rating: rating, onSelect: { score in
                    rating = (rating == score) ? nil : score
                }, size: 19)
            }
        }
    }

    /// The long tail: useful, but never in the way of Save.
    private var detailsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isShowingDetails) {
                TextField("Dish name", text: $dishName)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)

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

                if editedEatenAt != nil {
                    Button("Use the photo's time") { editedEatenAt = nil }
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.lacquer)
                }
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("Dish, note and time")
                        .font(Theme.label(.body))
                        .foregroundStyle(Theme.ink)
                }
            }
            .accessibilityIdentifier("mealDetailsDisclosure")

            if let context, context.derivedFromPhoto {
                Label(
                    "Using the time and place from your photo",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(Theme.label(.footnote))
                .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    // MARK: - Deriving what the user does not have to type

    /// Reads the coordinate and time from the photo (or the current fix), then names the place.
    private func resolveContext() async {
        context = await dependencies.suggestContext.execute(photoData: photoData)

        // "I ate here" already knows the place; never overrule the user's own choice either.
        guard preselected == nil, target == nil else { return }

        isResolvingPlace = true
        defer { isResolvingPlace = false }
        // The accuracy travels with the coordinate: a fix too coarse to tell neighbouring shops
        // apart leaves the place unset rather than guessing wrong (FR-1.13).
        if let suggestion = await dependencies.suggestPlace.execute(
            around: context?.coordinate,
            accuracy: context?.accuracy
        ) {
            target = suggestion.target
            targetName = suggestion.name
        }
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
