import SwiftUI

// MARK: - SpeakIT Dropdown Option Row
/// Reusable row component for dropdown menus that strictly enforces placing the
/// selection checkmark (tick icon) on the far RIGHT edge with title/icon on the left.
struct SpeakITDropdownOptionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    var accentColor: Color = Color.speakitPrimary
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? accentColor : Color.speakitTextSecondary)
                        .frame(width: 16)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? accentColor : Color.speakitTextPrimary)
                        .lineLimit(1)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(Color.speakitTextTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 16)
                
                // Tick icon placed strictly on the far RIGHT
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpeakIT Dropdown Container
/// An anchored popover container that encapsulates dropdown presentation state
/// and ensures native popover presentation across all iOS devices.
struct SpeakITDropdownContainer<Label: View, Content: View>: View {
    let label: () -> Label
    let content: (Binding<Bool>) -> Content

    @State private var isPresented: Bool = false

    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping (Binding<Bool>) -> Content
    ) {
        self.label = label
        self.content = content
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            isPresented.toggle()
        }) {
            label()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            content($isPresented)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - SpeakIT Dropdown Menu
/// Generic dropdown menu for a typed list of options. Renders all options with
/// checkmarks on the RIGHT side.
struct SpeakITDropdownMenu<T: Hashable, Label: View>: View {
    @Binding var selection: T
    let options: [T]
    let title: (T) -> String
    var subtitle: ((T) -> String?)? = nil
    var icon: ((T) -> String?)? = nil
    var accentColor: Color = Color.speakitPrimary
    var minWidth: CGFloat = 160
    var onSelected: ((T) -> Void)? = nil
    let label: () -> Label

    init(
        selection: Binding<T>,
        options: [T],
        title: @escaping (T) -> String,
        subtitle: ((T) -> String?)? = nil,
        icon: ((T) -> String?)? = nil,
        accentColor: Color = Color.speakitPrimary,
        minWidth: CGFloat = 160,
        onSelected: ((T) -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._selection = selection
        self.options = options
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accentColor = accentColor
        self.minWidth = minWidth
        self.onSelected = onSelected
        self.label = label
    }

    var body: some View {
        SpeakITDropdownContainer {
            label()
        } content: { isPresented in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = (selection == option)
                        SpeakITDropdownOptionRow(
                            title: title(option),
                            subtitle: subtitle?(option),
                            icon: icon?(option),
                            isSelected: isSelected,
                            accentColor: accentColor
                        ) {
                            selection = option
                            onSelected?(option)
                            isPresented.wrappedValue = false
                        }

                        if option != options.last {
                            Divider()
                                .padding(.horizontal, 10)
                                .opacity(0.4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minWidth: minWidth)
            .frame(maxHeight: min(CGFloat(options.count * 44 + 10), 320))
            .background(Color.speakitCardSurface)
        }
    }
}
