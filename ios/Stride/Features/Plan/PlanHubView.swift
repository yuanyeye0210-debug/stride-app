import SwiftUI

enum PlanSubTab: String, CaseIterable, Identifiable {
    case schedule = "计划"
    case calendar = "日历"
    case templates = "模板"
    case exercises = "动作库"

    var id: String { rawValue }
}

struct PlanHubView: View {
    @EnvironmentObject private var store: AppStore

    @State private var subTab: PlanSubTab = .schedule
    @Namespace private var planSubTabNS
    @State private var calendarMonth: Date = Date()
    @State private var showQuickSession = false
    @State private var showCardioRun = false
    @State private var showCustomTemplatesSheet = false
    @State private var showCreateTemplate = false

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg.ignoresSafeArea()

            Group {
                switch subTab {
                case .schedule:
                    PlanScheduleView(
                        onCreateTemplate: { showCreateTemplate = true },
                        onQuickStart: { showQuickSession = true }
                    )
                case .calendar:
                    PlanCalendarView(month: $calendarMonth)
                case .templates:
                    TemplateLibraryView(onCreateTemplate: { showCreateTemplate = true })
                case .exercises:
                    ExerciseVideoLibraryView(embeddedInPlanHub: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy(duration: 0.24), value: subTab)

            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showQuickSession) {
            SessionView(draft: .empty())
        }
        .sheet(isPresented: $showCardioRun) {
            RunCaptureView()
        }
        .sheet(isPresented: $showCustomTemplatesSheet) {
            MyCustomTemplatesSheet(onCreateNew: {
                showCustomTemplatesSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showCreateTemplate = true
                }
            })
            .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreateTemplate) {
            CreateTemplateSheet()
                .strideSheetDetents([.medium, .large])
        }
    }

    // MARK: - 顶部液态玻璃 3 段胶囊与上下文控制区

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(PlanSubTab.allCases) { item in
                    let active = subTab == item
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            subTab = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 13.5, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? Color.white : Color.white.opacity(0.68))
                            .lineLimit(1)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .background {
                                if active {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.20))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                                        )
                                        .matchedGeometryEffect(id: "planSubTabCapsule", in: planSubTabNS)
                                }
                            }
                    }
                    .buttonStyle(StridePressButtonStyle(scale: 0.95, pressedOpacity: 0.9, haptic: nil))
                }
            }
            .padding(4)
            .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            .sensoryFeedback(.selection, trigger: subTab)

            Spacer()

            trailingControls
        }
        .padding(.horizontal, Metrics.page)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var trailingControls: some View {
        switch subTab {
        case .schedule:
            HStack(spacing: 8) {
                Button {
                    showCardioRun = true
                } label: {
                    Text("有氧")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 15)
                        .frame(height: 42)
                        .liquidGlassCapsule(tint: Color.black.opacity(0.45))
                }
                .buttonStyle(.stridePress)

                Button {
                    showQuickSession = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Palette.yellow))
                }
                .buttonStyle(.strideShimmer(glow: Palette.yellow))
                .accessibilityLabel("快速新建训练")
            }

        case .calendar:
            HStack(spacing: 8) {
                Button {
                    if let prev = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth) {
                        calendarMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.coralHi)
                        .frame(width: 34, height: 34)
                        .liquidGlassCapsule(tint: Color.black.opacity(0.45))
                }
                .buttonStyle(.stridePress)

                Text(monthTitle(calendarMonth))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())

                Button {
                    if !isCurrentOrFutureMonth(calendarMonth),
                       let next = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth) {
                        calendarMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isCurrentOrFutureMonth(calendarMonth) ? Palette.coralHi.opacity(0.32) : Palette.coralHi)
                        .frame(width: 34, height: 34)
                        .liquidGlassCapsule(tint: Color.black.opacity(0.45))
                }
                .buttonStyle(.stridePress)
                .disabled(isCurrentOrFutureMonth(calendarMonth))
            }
            .sensoryFeedback(.selection, trigger: calendarMonth)

        case .templates:
            Button {
                showCustomTemplatesSheet = true
            } label: {
                Image(systemName: "rectangle.stack.person.crop")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .frame(width: 42, height: 42)
                    .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            }
            .buttonStyle(.stridePress)
            .accessibilityLabel("我的自定义模板")

        case .exercises:
            Button {
                showQuickSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.yellow))
            }
            .buttonStyle(.stridePress)
            .accessibilityLabel("快速新建训练")
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func isCurrentOrFutureMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        let a = cal.dateComponents([.year, .month], from: date)
        let b = cal.dateComponents([.year, .month], from: Date())
        return (a.year ?? 0, a.month ?? 0) >= (b.year ?? 0, b.month ?? 0)
    }
}
