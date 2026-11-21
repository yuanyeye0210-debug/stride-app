import SwiftUI

struct PlanCalendarView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var month: Date

    @State private var selectedDate: Date = Date()
    @State private var detailSession: WorkoutSession?
    @State private var showSettings = false

    private let cal = Calendar.current
    private let monFirstNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if store.state.calendarShowEffort {
                        effortLegend
                    }

                    calendarGrid

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.7)

                    dayDetailSection
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 64)
                .padding(.bottom, Metrics.floatingTabBottomInset + 66)
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                    Text("日历设置")
                        .font(.system(size: 13.5, weight: .semibold))
                }
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .liquidGlassCapsule(tint: Color.black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(.bottom, Metrics.floatingTabBottomInset + 8)
        }
        .sheet(item: $detailSession) { session in
            SessionDetailView(session: session)
        }
        .sheet(isPresented: $showSettings) {
            CalendarSettingsSheet()
        }
    }

    // MARK: - 耗能四色图例

    private var effortLegend: some View {
        HStack(spacing: 12) {
            Text("耗能")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textDim)

            ForEach(WorkoutIntensity.allCases) { item in
                HStack(spacing: 4) {
                    Circle().fill(item.color).frame(width: 7, height: 7)
                    Text(item.rawValue)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 全宽月历网格

    private var calendarGrid: some View {
        let cells = monthCells(for: month)
        return VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(monFirstNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.coralHi)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 12) {
                ForEach(cells.indices, id: \.self) { idx in
                    if let d = cells[idx] {
                        calendarDayCell(d)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
        }
    }

    private func calendarDayCell(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isFuture = cal.startOfDay(for: date) > cal.startOfDay(for: Date())
        let dayNum = cal.component(.day, from: date)

        let daySessions = store.state.sessions.filter { cal.isDate($0.date, inSameDayAs: date) }
        let ringColors: [Color] = daySessions.map {
            store.state.calendarShowEffort ? $0.inferredIntensity.color : Palette.indigo
        }
        let labelText: String = {
            guard let first = daySessions.first else { return "" }
            let extra = daySessions.count > 1 ? " +\(daySessions.count - 1)" : ""
            return first.title + extra
        }()

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if !daySessions.isEmpty {
                        SegmentedEffortRing(colors: ringColors)
                            .frame(width: 34, height: 34)
                    }

                    if isToday {
                        Circle()
                            .fill(Palette.coralHi)
                            .frame(width: 28, height: 28)
                    } else if isSelected {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                    }

                    Text("\(dayNum)")
                        .font(.system(size: 13.5, weight: isToday || !daySessions.isEmpty ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isToday ? Color.white : (isFuture ? Palette.textFaint : Palette.text))
                }
                .frame(height: 36)

                Text(labelText.isEmpty ? " " : labelText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Palette.coralHi.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func monthCells(for monthDate: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: monthDate),
              let range = cal.range(of: .day, in: .month, for: monthDate) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingEmpty = (firstWeekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(d)
            }
        }
        return cells
    }

    // MARK: - 日历下方单日详情区

    private var dayDetailSection: some View {
        let daySessions = store.state.sessions.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedDayHeading)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.coralHi)

            if daySessions.isEmpty {
                Text("这天没有训练")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.vertical, 12)
            } else {
                ForEach(daySessions) { session in
                    Button {
                        detailSession = session
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(session.inferredIntensity.color)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text("\(session.durationSec / 60) 分钟 · \(session.totalSets) 组 · \(Int(session.totalVolume)) kg · \(session.inferredIntensity.rawValue)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.textFaint)
                        }
                        .padding(14)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedDayHeading: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        let prefix = cal.isDateInToday(selectedDate) ? "今天 · " : ""
        return prefix + f.string(from: selectedDate)
    }
}

private struct CalendarSettingsSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    Toggle(isOn: $store.state.calendarShowEffort) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("按耗能强度显示四色圆环")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.text)
                            Text("根据 RPE 与组数将每次训练渲染为轻松 / 适中 / 困难 / 竭尽全力色环")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textDim)
                        }
                    }
                    .tint(Palette.coralHi)
                    .padding(16)
                    .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("日历设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.coralHi)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
