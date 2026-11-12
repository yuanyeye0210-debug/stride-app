import SwiftUI

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack {
            tab(0) { NavigationStack { TodayView() } }
            tab(1) { NavigationStack { TrainingHomeView() } }
            tab(2) { NavigationStack { ProgressViewScreen() } }
            tab(3) { NavigationStack { MeView() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            tabBar
        }
    }

    private func tab<Content: View>(_ tag: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(selection == tag ? 1 : 0)
            .allowsHitTesting(selection == tag)
            .accessibilityHidden(selection != tag)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            item("主页", "sun.horizon.fill", 0)
            item("计划", "calendar", 1)
            item("记录", "chart.line.uptrend.xyaxis", 2)
            item("自己", "person.crop.circle", 3)
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

    private func item(_ title: String, _ icon: String, _ tag: Int) -> some View {
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
