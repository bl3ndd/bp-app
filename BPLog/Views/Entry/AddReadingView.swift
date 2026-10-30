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
    @FocusState private var focus: Field?

    @AppStorage("lastArm") private var lastArm = Arm.left.rawValue
    @AppStorage("lastPosition") private var lastPosition = Position.sitting.rawValue

    private enum Field { case systolic, diastolic, pulse, note }

    static let tagOptions = ["After coffee", "Stressed", "After exercise", "Took medication", "Headache", "Felt dizzy"]

    private var isImported: Bool { editing?.source == .health }
    private var sys: Int? { Int(systolic) }
    private var dia: Int? { Int(diastolic) }
    private var pul: Int? { pulse.isEmpty ? nil : Int(pulse) }
    private var isValid: Bool {
        guard let sys, let dia else { return false }
        return ReadingLimits.isValid(systolic: sys, diastolic: dia, pulse: pul)
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
        if let typing, !EntryInput.isComplete(typing) { return nil }
        return ReadingLimits.problem(systolic: sys, diastolic: dia, pulse: pul)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        numberField("Systolic", hint: "Top", text: $systolic, field: .systolic, next: .diastolic)
                        Text("/").font(AppFont.number(34)).foregroundStyle(AppColors.textSecondary)
                        numberField("Diastolic", hint: "Bottom", text: $diastolic, field: .diastolic, next: .pulse)
                        numberField("Pulse", hint: "Optional", text: $pulse, field: .pulse, next: nil)
                    }
                    .disabled(isImported)
                    if let sys, let dia, isValid {
                        let category = BPCategory.classify(systolic: sys, diastolic: dia)
                        CategoryBadge(category: category)
                        CategoryNote(category: category)
                    } else if let shownProblem {
                        Text(shownProblem)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.stage2)
                    }
                } footer: {
                    if isImported {
                        Text("From Apple Health. Edit the numbers in the app that recorded them.")
                    }
                }

                Section("When and how") {
                    DatePicker("Date & time", selection: $date, in: ...Date())
                        .disabled(isImported)
                    Picker("Arm", selection: $arm) {
                        ForEach(Arm.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Position", selection: $position) {
                        ForEach(Position.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(Self.tagOptions, id: \.self) { tag in
                            let on = tags.contains(tag)
                            Button {
                                if on { tags.remove(tag) } else { tags.insert(tag) }
                            } label: {
                                Text(tag)
                                    .font(.body.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(on ? .white : AppColors.textPrimary)
                                    .background(Capsule().fill(on ? AppColors.accent : AppColors.bgInput))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Note") {
                    TextField("Anything worth remembering", text: $note, axis: .vertical)
                        .focused($focus, equals: .note)
                }
            }
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
                    .padding()
                    .background(.bar)
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear(perform: load)
        }
    }

    private func numberField(_ title: String, hint: String, text: Binding<String>, field: Field, next: Field?) -> some View {
        VStack(spacing: 4) {
            TextField("—", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(AppFont.number(field == .pulse ? 28 : 40))
                .focused($focus, equals: field)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgInput))
                .onChange(of: text.wrappedValue) { _, new in
                    let clean = EntryInput.sanitize(new)
                    if clean != new { text.wrappedValue = clean }
                    if EntryInput.isComplete(clean), focus == field { focus = next }
                }
                .accessibilityLabel(title)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
            Text(hint).font(.caption).foregroundStyle(AppColors.textSecondary)
        }
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
            reading.systolic = sys
            reading.diastolic = dia
            reading.pulse = pul
            reading.date = date
        } else {
            reading = Reading(date: date, systolic: sys, diastolic: dia, pulse: pul)
            context.insert(reading)
            ReviewService.recordReading(reading.category)
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
        if settings.healthEnabled, reading.source == .manual {
            let value = reading.value
            let meta = HealthMeta(reading)
            Task {
                if let id = previous?.id, let oldDate = previous?.date {
                    await HealthService.delete(healthKitID: id, date: oldDate)
                }
                reading.healthKitID = await HealthService.save(value, meta: meta)
                try? context.save()
            }
        }
        dismiss()
    }
}
