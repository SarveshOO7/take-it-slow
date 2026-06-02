import SwiftUI
import FamilyControls

/// Wraps FamilyActivityPicker in a navigation sheet with Done / Cancel buttons.
struct FamilyActivityPickerView: View {
    @Binding var selection: FamilyActivitySelection
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Block These Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { onDone() }
                            .fontWeight(.semibold)
                    }
                }
        }
    }
}
