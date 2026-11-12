import SwiftUI

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        Group {
            switch selection {
            case 0:
                NavigationStack { TodayView() }
            case 1:
                NavigationStack { TrainingHomeView() }
            case 2:
                NavigationStack { ProgressViewScreen() }
            default:
                NavigationStack { MeView() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tab("主页", "sun.horizon.fill", 0)
            tab("计划", "calendar", 1)
            tab("记录", "chart.line.uptrend.xyaxis", 2)
            tab("自己", "person.crop.circle", 3)
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Palette.card)
                .overlay(Capsule(style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        )
        .padding(.horizontal, 28)
        .padding(.bottom, 4)
    }

    private func tab(_ title: String, _ icon: String, _ tag: Int) -> some View {
        let on = selection == tag
        return Button {
            selection = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(on ? Color.black : Palette.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(on ? Color.white : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
