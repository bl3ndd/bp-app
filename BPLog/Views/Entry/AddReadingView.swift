import SwiftUI
import SwiftData

/// New reading, or edit of an existing one. Readings imported from Health keep
/// their numbers read-only — the cuff's app owns them; tags and note stay editable.
struct AddReadingView: View {
    var editing: Reading?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var pulse = ""
    @State private var date = Date()
    @State private var arm = Arm.left
    @State private var position = Position.sitting
    @State private var tags: Set<String> = []
    @State private var note = ""
    @State private var saved = false
    @State private var confirmingDelete = false
    @FocusState private var focus: Field?

    @AppStorage("lastArm") private var lastArm = Arm.left.rawValue
    @AppStorage("lastPosition") private var lastPosition = Position.sitting.rawValue

    private enum Field { case systolic, diastolic, pulse, note }

    static let tagOptions = ["After coffee", "Stressed", "After exercise", "Took medication", "Headache", "Felt dizzy"]

    private var isImported: Bool { editing?.source == .health }
    private var sys: Int? { Int(systolic) }
    private var dia: Int? { Int(diastolic) }
    private var pul: Int? { pulse.isEmpty ? nil : Int(pulse) }
    /// Imported numbers are read-only and belong to the cuff's app: never block saving tags or a note on them.
    private var isValid: Bool {
        guard let sys, let dia else { return false }
        return isImported || ReadingLimits.isValid(systolic: sys, diastolic: dia, pulse: pul)
    }

    /// Held back while the focused number is still being typed: "20" may be on its way somewhere.
    private var shownProblem: String? {
        guard let sys, let dia else { return nil }
        let typing: String? = switch focus {
        case .systolic: systolic
        case .diastolic: diastolic
        case .pulse: pulse
        default: nil
        }
        // An empty focused field isn't "being typed": moving on to an empty Pulse must show the error.
        if let typing, !typing.isEmpty, !EntryInput.isComplete(typing) { return nil }
        return ReadingLimits.problem(systolic: sys, diastolic: dia, pulse: pul)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 10) {
                        valueRow("Top number", sub: "Systolic", text: $systolic, field: .systolic, next: .diastolic)
                        valueRow("Bottom number", sub: "Diastolic", text: $diastolic, field: .diastolic, next: .pulse)
                        valueRow("Pulse", sub: "Optional", unit: "bpm", text: $pulse, field: .pulse, next: nil)
                    }
                    .disabled(isImported)
                    if isImported {
                        caption("From Apple Health. Edit the numbers in the app that recorded them.")
                    }
                    if let sys, let dia, isValid {
                        resultCard(.classify(systolic: sys, diastolic: dia))
                    } else if let shownProblem {
                        Text(shownProblem)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.stage2)
                    }

                    sectionTitle("When and how")
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            DatePicker("Date & time", selection: $date, in: ...Date())
                                .font(.body.weight(.medium))
                                .disabled(isImported)
                            Divider()
                            Text("Arm").font(.body.weight(.medium)).foregroundStyle(AppColors.textPrimary)
                            SegmentedChips(options: Arm.allCases, selection: $arm) { $0.rawValue.capitalized }
                            Text("Position").font(.body.weight(.medium)).foregroundStyle(AppColors.textPrimary)
                            SegmentedChips(options: Position.allCases, selection: $position) { $0.rawValue.capitalized }
                        }
                    }

                    sectionTitle("Tags")
                    CardView {
                        FlowLayout(spacing: 8) {
                            ForEach(Self.tagOptions, id: \.self) { tag in
                                let on = tags.contains(tag)
                                Button {
                                    if on { tags.remove(tag) } else { tags.insert(tag) }
                                } label: {
                                    Text(tag)
                                        .font(.body.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .foregroundStyle(on ? .white : AppColors.textPrimary)
                                        .background(Capsule().fill(on ? AppColors.accentFill : AppColors.bgInput))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }

                    sectionTitle("Note")
                    CardView {
                        TextField("Anything worth remembering", text: $note, axis: .vertical)
                            .font(.body)
                            .focused($focus, equals: .note)
                    }

                    // A visible way to delete: swipe-to-delete in History is easy to miss.
                    if editing != nil {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete Reading", systemImage: "trash")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.stage2)
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.bgApp)
            .navigationTitle(editing == nil ? "Add Reading" : "Edit Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save Reading", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isValid)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(AppColors.bgApp)
            }
            .sensoryFeedback(.success, trigger: saved)
            .confirmationDialog("Delete this reading?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Reading", role: .destructive) {
                    if let editing { ReadingActions.delete([editing], context: context, settings: settings) }
                    dismiss()
                }
            } message: {
                Text("It will be removed from your history. This can't be undone.")
            }
            .onAppear(perform: load)
        }
    }

    /// Full-width row: what to type on the left, a big number on the right.
    /// Easier than narrow side-by-side fields at large text sizes.
    private func valueRow(_ title: String, sub: String, unit: String? = nil, text: Binding<String>, field: Field, next: Field?) -> some View {
        let focused = focus == field
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                Text(sub).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 8)
            TextField("—", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(AppFont.number(field == .pulse ? 40 : 52))
                .foregroundStyle(AppColors.textPrimary)
                .focused($focus, equals: field)
                .frame(maxWidth: 170)
                .onChange(of: text.wrappedValue) { _, new in
                    let clean = EntryInput.sanitize(new)
                    if clean != new { text.wrappedValue = clean }
                    // Move on after this keystroke is fully handled: switching focus inside it
                    // delivered the same key to the next field too ("80" left a "0" in Pulse).
                    if EntryInput.isComplete(clean), focus == field {
                        Task { @MainActor in focus = next }
                    }
                }
                // UI tests and VoiceOver find the fields by these names.
                .accessibilityLabel(field == .pulse ? "Pulse" : sub)
            if let unit {
                Text(unit).font(.headline).foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 84)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.bgCard))
        .overlay(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous)
            .strokeBorder(focused ? AppColors.accent : AppColors.separator, lineWidth: focused ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { focus = field }
    }

    /// The live result: category in its color, where it sits on the scale, and the Low note if it applies.
    private func resultCard(_ category: BPCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This reading is").font(.subheadline).foregroundStyle(AppColors.textSecondary)
            Text(category.title).font(.title2.bold()).foregroundStyle(category.color)
            CategoryScale(category: category, showsLabels: true)
            CategoryNote(category: category)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(category.color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous)
            .strokeBorder(category.color.opacity(0.35), lineWidth: 1))
        .animation(.default, value: category)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.top, 6)
            .padding(.leading, 4)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(AppColors.textSecondary)
    }

    private func load() {
        guard let r = editing else {
            arm = Arm(rawValue: lastArm) ?? .left
            position = Position(rawValue: lastPosition) ?? .sitting
            focus = .systolic
            return
        }
        systolic = String(r.systolic)
        diastolic = String(r.diastolic)
        pulse = r.pulse.map(String.init) ?? ""
        date = r.date
        arm = r.arm
        position = r.position
        tags = Set(r.tags)
        note = r.note
    }

    private func save() {
        guard let sys, let dia, isValid else { return }
        let reading: Reading
        let previous = editing.map { (id: $0.healthKitID, date: $0.date) }
        if let editing {
            reading = editing
            Analytics.track(.readingEdited)
            reading.systolic = sys
            reading.diastolic = dia
            reading.pulse = pul
            reading.date = date
        } else {
            reading = Reading(date: date, systolic: sys, diastolic: dia, pulse: pul, personID: settings.activePersonID)
            context.insert(reading)
            ReviewService.recordReading(reading.category)
            Analytics.track(.readingAdded)
        }
        reading.arm = arm
        reading.position = position
        reading.tags = Self.tagOptions.filter(tags.contains)
        reading.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        lastArm = arm.rawValue
        lastPosition = position.rawValue
        saved.toggle()

        // Our own writes are mirrored to Health; an edit replaces the old sample.
        // Apple Health is the owner's: other people's readings stay in the app.
        if settings.healthEnabled, reading.source == .manual, reading.personID == nil {
            let value = reading.value
            let meta = HealthMeta(reading)
            let readingID = reading.id
            Task {
                if let id = previous?.id, let oldDate = previous?.date {
                    await HealthService.delete(healthKitID: id, date: oldDate)
                }
                guard let newID = await HealthService.save(value, meta: meta) else { return }
                // The reading may have been deleted while Health was saving: then
                // take the copy back out instead of writing to a deleted model.
                let match = FetchDescriptor<Reading>(predicate: #Predicate { $0.id == readingID })
                if let current = try? context.fetch(match).first {
                    current.healthKitID = newID
                    try? context.save()
                } else {
                    await HealthService.delete(healthKitID: newID, date: value.date)
                }
            }
        }
        dismiss()
    }
}
