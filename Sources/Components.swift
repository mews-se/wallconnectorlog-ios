import SwiftUI

// The icon exactly as shipped, read from the bundle so no view drifts from the
// home screen. The catalog compiles it under the names listed in CFBundleIcons;
// asking for "AppIcon" itself comes back empty.
enum AppIcon {
    static let image: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }()
}

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = .primary
    var valueTint: Color?
    // A second line under the value for a figure that belongs to it, like
    // the cost of an amount of energy.
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(valueTint ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CardRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(verbatim: title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(verbatim: title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(verbatim: message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try again", action: retry)
                .buttonStyle(.bordered)
        }
        .padding(.top, 80)
        .padding(.horizontal)
    }
}
