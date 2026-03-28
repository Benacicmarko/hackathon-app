import SwiftUI

// MARK: - Color palette (Stitch / Material dark)

enum FlowTheme {
    static let surface            = Color(hex: 0x131313)
    static let surfaceContainer   = Color(hex: 0x1C1B1B)
    static let surfaceContainerHi = Color(hex: 0x252424)
    static let surfaceContainerHi2 = Color(hex: 0x2E2D2D)
    static let onSurface          = Color(hex: 0xE5E2E1)
    static let onSurfaceVariant   = Color(hex: 0xC4C5D5)

    static let primary            = Color(hex: 0x00E475)
    static let onPrimary          = Color(hex: 0x003918)
    static let primaryDim         = Color(hex: 0x00C162)

    static let secondary          = Color(hex: 0xB5C4FF)
    static let secondaryContainer = Color(hex: 0x153EA3)

    static let outline            = Color(hex: 0x444653)
    static let error              = Color(red: 1, green: 0.4, blue: 0.45)
    static let warning            = Color(hex: 0xFFBB33)

    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDim],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hex color init

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let status: IntentStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch status {
        case .collectingPassengers: return FlowTheme.primary
        case .fullRouting:          return FlowTheme.warning
        case .confirmed:            return FlowTheme.onPrimary
        case .inProgress:           return .white
        case .cancelled:            return FlowTheme.onSurfaceVariant
        }
    }

    private var background: Color {
        switch status {
        case .collectingPassengers: return FlowTheme.primary.opacity(0.15)
        case .fullRouting:          return FlowTheme.warning.opacity(0.15)
        case .confirmed:            return FlowTheme.primary
        case .inProgress:           return FlowTheme.secondary
        case .cancelled:            return FlowTheme.outline.opacity(0.3)
        }
    }
}

// MARK: - Reusable card

struct FlowCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FlowTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Primary button style

struct FlowPrimaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .tracking(1.5)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(isDestructive ? .white : FlowTheme.onPrimary)
            .background(
                isDestructive
                    ? AnyShapeStyle(FlowTheme.error)
                    : AnyShapeStyle(FlowTheme.primaryGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: (isDestructive ? FlowTheme.error : FlowTheme.primary).opacity(0.2), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary button style

struct FlowSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(FlowTheme.primary)
            .background(FlowTheme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FlowTheme.primary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Section header

struct FlowSectionHeader: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(FlowTheme.onSurfaceVariant)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text field style

struct FlowTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .foregroundStyle(FlowTheme.onSurface)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(FlowTheme.surfaceContainerHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Empty state

struct FlowEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(FlowTheme.onSurfaceVariant.opacity(0.5))
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(FlowTheme.onSurfaceVariant.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Seat indicator

struct SeatIndicator: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < filled ? "person.fill" : "person")
                    .font(.system(size: 11))
                    .foregroundStyle(i < filled ? FlowTheme.primary : FlowTheme.outline)
            }
        }
    }
}

// MARK: - Date & time formatting helpers

enum FlowFormatters {
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let displayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let displayDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func dateOnlyString(from date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    static func iso8601String(from date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func parseISO(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }

    static func displayDate(_ string: String) -> String {
        guard let d = parseDate(string) else { return string }
        return displayDateFormatter.string(from: d)
    }

    static func displayTime(_ iso: String) -> String {
        guard let d = parseISO(iso) else { return iso }
        return displayTimeFormatter.string(from: d)
    }

    static func displayDateTime(_ iso: String) -> String {
        guard let d = parseISO(iso) else { return iso }
        return displayDateTimeFormatter.string(from: d)
    }

    static func parseDate(_ yyyyMMdd: String) -> Date? {
        dateOnlyFormatter.date(from: yyyyMMdd)
    }

    static func relativeDateLabel(_ yyyyMMdd: String) -> String {
        guard let date = parseDate(yyyyMMdd) else { return yyyyMMdd }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return displayDateFormatter.string(from: date)
    }
}
