import SwiftUI

/// Whose readings the tab shows. Only there once a second person has been added
/// (Pro, in Settings): with one person it would be noise.
struct PersonPicker: ToolbarContent {
    @Environment(AppSettings.self) private var settings

    var body: some ToolbarContent {
        if !settings.people.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Show readings for", selection: Binding(
                        get: { settings.activePersonID },
                        set: { settings.activePersonID = $0 }
                    )) {
                        Text(settings.ownerName).tag(UUID?.none)
                        ForEach(settings.people) { person in
                            Text(person.name).tag(UUID?.some(person.id))
                        }
                    }
                } label: {
                    Label(settings.activeName, systemImage: "person.crop.circle")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Person: \(settings.activeName)")
            }
        }
    }
}
