import Foundation
import SwiftUI

// MARK: - 动作库

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "胸"
    case back = "背"
    case legs = "腿"
    case shoulders = "肩"
    case arms = "手臂"
    case core = "核心"
    case cardio = "有氧"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .chest: return Palette.pink
        case .back: return Palette.blue
        case .legs: return Palette.amber
        case .shoulders: return Palette.purple
        case .arms: return Palette.green
        case .core: return Palette.red
        case .cardio: return Palette.blue
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell = "杠铃"
    case dumbbell = "哑铃"
    case machine = "器械"
    case cable = "绳索"
    case bodyweight = "自重"

    var id: String { rawValue }
}

struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var group: MuscleGroup
    var equipment: Equipment
    var isTimed: Bool = false
    var met: Double = 5.0
    var cue: String = ""
}

// MARK: - 训练

struct SetEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var weight: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var rpe: Double? = nil
    var done: Bool = false

    var volume: Double { weight * Double(reps) }
}

struct LoggedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseID: UUID
    var name: String
    var group: MuscleGroup = .chest
    var isTimed: Bool = false
    var restSec: Int = 90
    var sets: [SetEntry] = []
    var note: String = ""

    var doneSets: [SetEntry] { sets.filter(\.done) }
    var volume: Double { doneSets.reduce(0) { $0 + $1.volume } }
    var topWeight: Double { doneSets.map(\.weight).max() ?? 0 }
}

enum SessionKind: String, Codable, CaseIterable, Identifiable {
    case strength = "力量"
    case run = "跑步"
    case ride = "骑行"
    case mobility = "拉伸"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .run: return "figure.run"
        case .ride: return "bicycle"
        case .mobility: return "figure.flexibility"
        }
    }
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var title: String
    var kind: SessionKind = .strength
    var exercises: [LoggedExercise] = []
    var durationSec: Int = 0
    var kcal: Int = 0
    var note: String = ""
    var syncedToWatch: Bool = false
    var writtenToHealth: Bool = false

    var totalVolume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.doneSets.count } }
}

// MARK: - 饮食

struct FoodItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct FoodEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var meal: Meal = .lunch
    var items: [FoodItem] = []
    var photoName: String? = nil
    var recognizedByAI: Bool = false

    var kcal: Double { items.reduce(0) { $0 + $1.kcal } }
    var protein: Double { items.reduce(0) { $0 + $1.protein } }
    var carbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var fat: Double { items.reduce(0) { $0 + $1.fat } }
}

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

// MARK: - 教练

enum ChatRole: String, Codable {
    case user, coach
}

struct ChatTurn: Identifiable, Codable, Hashable {
    var id = UUID()
    var role: ChatRole
    var text: String
    var date: Date = Date()
}

// MARK: - 足迹

struct GeoPoint: Codable, Hashable {
    var lat: Double
    var lon: Double
}

struct RouteRun: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var title: String = "夜跑"
    var distanceM: Double = 0
    var durationSec: Int = 0
    var points: [GeoPoint] = []
    var styleRaw: String = RouteArtStyle.neon.rawValue
    var templateRaw: String = ShareTemplate.card.rawValue

    var paceSecPerKm: Int {
        guard distanceM > 50 else { return 0 }
        return Int(Double(durationSec) / (distanceM / 1000.0))
    }

    var style: RouteArtStyle {
        get { RouteArtStyle(rawValue: styleRaw) ?? .neon }
        set { styleRaw = newValue.rawValue }
    }
}

enum RouteArtStyle: String, Codable, CaseIterable, Identifiable {
    case neon, ink, gradient, dots, contour, aurora

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neon: return "霓虹"
        case .ink: return "墨线"
        case .gradient: return "渐变"
        case .dots: return "点阵"
        case .contour: return "等高线"
        case .aurora: return "极光"
        }
    }

    var isPremium: Bool {
        switch self {
        case .neon, .ink, .gradient: return false
        case .dots, .contour, .aurora: return true
        }
    }

    var colors: [Color] {
        switch self {
        case .neon: return [Color(hex: 0x5CE08F), Color(hex: 0x2AD4C8)]
        case .ink: return [.white, Color(hex: 0xB9BCC4)]
        case .gradient: return [Color(hex: 0xFFB86B), Color(hex: 0xFF5E8A)]
        case .dots: return [Color(hex: 0x6BA8FF), Color(hex: 0xB48CFF)]
        case .contour: return [Color(hex: 0x8CE99A), Color(hex: 0x3F8F52)]
        case .aurora: return [Color(hex: 0x7BEDA9), Color(hex: 0x6BA8FF), Color(hex: 0xB48CFF)]
        }
    }
}

enum ShareTemplate: String, Codable, CaseIterable, Identifiable {
    case card, story, minimal, poster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "卡片"
        case .story: return "故事"
        case .minimal: return "极简"
        case .poster: return "海报"
        }
    }

    var isPremium: Bool { self != .card }
}

// MARK: - 每日概览

struct DailySnapshot: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = Date()
    var steps: Int = 0
    var activeKcal: Int = 0
    var exerciseMin: Int = 0
    var restingHR: Int = 0
    var weightKg: Double = 0

    func progress(goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(activeKcal) / Double(goal))
    }
}

struct WeekVolume: Identifiable, Hashable {
    let week: Date
    let volume: Double
    var id: Date { week }
}

// MARK: - 训练计划
struct PlannedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var note: String = ""
}

struct PlannedDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var weekday: Int            // 1...7
    var title: String
    var focus: MuscleGroup?
    var exercises: [PlannedExercise] = []
    var rest: Bool = false
}

struct TrainingPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt: Date = Date()
    var goal: Goal = .recomp
    var weeks: Int = 4
    var days: [PlannedDay] = []
    var generatedBy: String = "progressive-engine"
}

// MARK: - 用户

enum Goal: String, Codable, CaseIterable, Identifiable {
    case cut = "减脂"
    case recomp = "重塑"
    case bulk = "增肌"
    case endurance = "耐力"

    var id: String { rawValue }

    var kcalFactor: Double {
        switch self {
        case .cut: return -0.15
        case .recomp: return 0
        case .bulk: return 0.10
        case .endurance: return 0.03
        }
    }

    var proteinPerKg: Double {
        switch self {
        case .cut: return 2.2
        case .recomp: return 2.0
        case .bulk: return 1.9
        case .endurance: return 1.7
        }
    }
}

enum Experience: String, Codable, CaseIterable, Identifiable {
    case beginner = "入门"
    case intermediate = "进阶"
    case advanced = "老手"

    var id: String { rawValue }
}

struct Profile: Codable, Hashable {
    var nickname: String = "YG"
    var goal: Goal = .recomp
    var experience: Experience = .intermediate
    var daysPerWeek: Int = 4
    var heightCm: Double = 178
    var weightKg: Double = 76
    var age: Int = 30
    var sexMale: Bool = true
    var dailyKcalGoal: Int = 2200
    var weeklyWorkoutsGoal: Int = 4

    var bmr: Double {
        // Mifflin-St Jeor
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sexMale ? base + 5 : base - 161
    }

    var tdee: Double { bmr * 1.45 }

    var kcalTarget: Int { Int((tdee * (1 + goal.kcalFactor)).rounded()) }

    var proteinTarget: Int { Int((weightKg * goal.proteinPerKg).rounded()) }
}

// MARK: - 会员

struct MembershipState: Codable, Hashable {
    var planID: String = "max.monthly"
    var tier: Tier = .max
    var startedAt: Date = Date()
    var renewsAt: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    var isTrial: Bool = false
}

struct QuotaBook: Codable, Hashable {
    var counters: [String: Int] = [:]

    func key(_ scope: String, _ date: Date = Date()) -> String {
        "\(scope)|\(Self.fmt.string(from: date))"
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func used(_ scope: String, _ date: Date = Date()) -> Int {
        counters[key(scope, date)] ?? 0
    }

    mutating func bump(_ scope: String, _ date: Date = Date()) {
        counters[key(scope, date), default: 0] += 1
    }

    mutating func reset(_ scope: String, _ date: Date = Date()) {
        counters[key(scope, date)] = 0
    }
}

// MARK: - 饮水

struct WaterDay: Codable, Hashable, Identifiable {
    var id = UUID()
    var day: String
    var ml: Int
}

enum WaterLog {
    static let defaultGoalMl = 1800
    static let stepMl = 500
    static let cupMl = 200

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func adjusted(_ ml: Int, delta: Int) -> Int {
        max(0, ml + delta)
    }

    static func cups(_ ml: Int) -> Int {
        ml / cupMl
    }

    static func percent(_ ml: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return Int((Double(ml) / Double(goal) * 100).rounded())
    }

    static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var parts: [String] = []
        var rest = digits
        while rest.count > 3 {
            parts.insert(String(rest.suffix(3)), at: 0)
            rest.removeLast(3)
        }
        if !rest.isEmpty { parts.insert(rest, at: 0) }
        return parts.joined(separator: ",")
    }
}

// MARK: - 持久化根

struct AppState: Codable {
    var profile = Profile()
    var exercises: [Exercise] = []
    var sessions: [WorkoutSession] = []
    var foods: [FoodEntry] = []
    var runs: [RouteRun] = []
    var chats: [ChatTurn] = []
    var snapshots: [DailySnapshot] = []
    var plan: TrainingPlan?
    var membership = MembershipState()
    var quotas = QuotaBook()
    var seeded = false
    var waterDays: [WaterDay] = []
    var waterGoalMl: Int = WaterLog.defaultGoalMl
    var lastWeekPlan: [PlannedDay] = []
    var planUndo: [PlannedDay]? = nil
    var weekStamp: Int = 0

    enum CodingKeys: String, CodingKey {
        case profile, exercises, sessions, foods, runs, chats, snapshots, plan, membership, quotas, seeded
        case waterDays, waterGoalMl, lastWeekPlan, planUndo, weekStamp
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? Profile()
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        sessions = try c.decodeIfPresent([WorkoutSession].self, forKey: .sessions) ?? []
        foods = try c.decodeIfPresent([FoodEntry].self, forKey: .foods) ?? []
        runs = try c.decodeIfPresent([RouteRun].self, forKey: .runs) ?? []
        chats = try c.decodeIfPresent([ChatTurn].self, forKey: .chats) ?? []
        snapshots = try c.decodeIfPresent([DailySnapshot].self, forKey: .snapshots) ?? []
        plan = try c.decodeIfPresent(TrainingPlan.self, forKey: .plan)
        membership = try c.decodeIfPresent(MembershipState.self, forKey: .membership) ?? MembershipState()
        quotas = try c.decodeIfPresent(QuotaBook.self, forKey: .quotas) ?? QuotaBook()
        seeded = try c.decodeIfPresent(Bool.self, forKey: .seeded) ?? false
        waterDays = try c.decodeIfPresent([WaterDay].self, forKey: .waterDays) ?? []
        waterGoalMl = try c.decodeIfPresent(Int.self, forKey: .waterGoalMl) ?? WaterLog.defaultGoalMl
        lastWeekPlan = try c.decodeIfPresent([PlannedDay].self, forKey: .lastWeekPlan) ?? []
        planUndo = try c.decodeIfPresent([PlannedDay].self, forKey: .planUndo)
        weekStamp = try c.decodeIfPresent(Int.self, forKey: .weekStamp) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profile, forKey: .profile)
        try c.encode(exercises, forKey: .exercises)
        try c.encode(sessions, forKey: .sessions)
        try c.encode(foods, forKey: .foods)
        try c.encode(runs, forKey: .runs)
        try c.encode(chats, forKey: .chats)
        try c.encode(snapshots, forKey: .snapshots)
        try c.encodeIfPresent(plan, forKey: .plan)
        try c.encode(membership, forKey: .membership)
        try c.encode(quotas, forKey: .quotas)
        try c.encode(seeded, forKey: .seeded)
        try c.encode(waterDays, forKey: .waterDays)
        try c.encode(waterGoalMl, forKey: .waterGoalMl)
        try c.encode(lastWeekPlan, forKey: .lastWeekPlan)
        try c.encodeIfPresent(planUndo, forKey: .planUndo)
        try c.encode(weekStamp, forKey: .weekStamp)
    }
}
