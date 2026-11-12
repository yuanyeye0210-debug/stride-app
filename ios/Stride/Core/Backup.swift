import Foundation

// MARK: - 备份信封
//
// v1.2 备份格式：一个带版本号的信封包着现有的 AppState。
// 信封只加包装层，不改数据模型；导入时也接受裸 AppState JSON（兼容旧导出）。
// 编解码沿用 AppStore 的 ISO8601 编码器/解码器，与 state.json 同一套。

enum BackupError: LocalizedError, Equatable {
    case invalidFile
    case unsupportedVersion(Int)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "这个文件不是有效的备份，换一个文件再试。"
        case .unsupportedVersion(let v):
            return "这个备份是新版本（v\(v)），当前 App 读不了，请先更新 App。"
        case .validationFailed(let reason):
            return "备份里的数据不对：\(reason)"
        }
    }
}

struct BackupEnvelope: Codable {
    var schemaVersion: Int
    var app: String
    var exportedAt: Date
    var state: AppState

    init(state: AppState, exportedAt: Date = Date()) {
        self.schemaVersion = Backup.currentSchemaVersion
        self.app = Backup.appIdentifier
        self.exportedAt = exportedAt
        self.state = state
    }
}

/// 启动时发现的数据问题。只做提醒，不自动删数据。
enum DataIssue: Equatable {
    case corruptFileQuarantined(quarantinedName: String)
    /// 文件能解码，但个别字段超出合理范围，已按合理值修正，记录都在。
    case fieldsClamped([String])
    /// 文件损坏且隔离失败，原文件已保留，本次启动不保存新数据。
    case corruptFileKept
}

enum Backup {

    static let currentSchemaVersion = 1
    static let appIdentifier = "stride"

    // MARK: - 编解码
    //
    // 与 AppStore.state.json 同一套 ISO8601 编解码，但这里自带一份，
    // 不调用 @MainActor 的 AppStore.encoder()/decoder()，避免隔离问题。

    static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    static func encode(_ state: AppState, exportedAt: Date = Date()) throws -> Data {
        try encoder().encode(BackupEnvelope(state: state, exportedAt: exportedAt))
    }

    /// 先看是不是信封（有 schemaVersion 就按信封处理，版本不对直接报错）；
    /// 没有 schemaVersion 再按裸 AppState 解，两种都失败就是无效文件。
    /// 信封的 app 字段若在，必须是 "stride"；信封体损坏时统一报无效文件，
    /// 不把原始 DecodingError 透给用户。
    static func decode(_ data: Data) throws -> AppState {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = object["schemaVersion"] as? Int {
            if let app = object["app"] as? String, app != appIdentifier {
                throw BackupError.invalidFile
            }
            guard version == currentSchemaVersion else {
                throw BackupError.unsupportedVersion(version)
            }
            do {
                let envelope = try decoder().decode(BackupEnvelope.self, from: data)
                try validate(envelope.state)
                return envelope.state
            } catch let error as BackupError {
                throw error
            } catch {
                throw BackupError.invalidFile
            }
        }
        guard let state = try? decoder().decode(AppState.self, from: data) else {
            throw BackupError.invalidFile
        }
        try validate(state)
        return state
    }

    // MARK: - 校验（只做底线，不做业务判断）

    /// 校验用的合理范围。注意：启动时只用它做“导入 hygiene”，
    /// 不用它判断文件是否损坏——见 AppStore.init 的分流。
    static let validWeightKg = 20.0...300.0
    static let validHeightCm = 100.0...250.0

    static func validate(_ state: AppState) throws {
        let p = state.profile
        guard validWeightKg.contains(p.weightKg) else {
            throw BackupError.validationFailed("体重 \(p.weightKg)kg 不在合理范围")
        }
        guard validHeightCm.contains(p.heightCm) else {
            throw BackupError.validationFailed("身高 \(p.heightCm)cm 不在合理范围")
        }
        guard p.dailyKcalGoal > 0 else {
            throw BackupError.validationFailed("每日热量目标必须是正数")
        }
        guard state.waterGoalMl > 0 else {
            throw BackupError.validationFailed("饮水目标必须是正数")
        }
    }

    /// 把越界字段钳制回合理范围，返回修正后的 state 与被修正的字段名。
    /// 只修正字段，不丢任何记录；配合启动加载与资料保存两处用。
    static func clamped(_ state: AppState) -> (AppState, [String]) {
        var next = state
        var fixed: [String] = []
        if !validWeightKg.contains(next.profile.weightKg) {
            next.profile.weightKg = min(max(next.profile.weightKg, validWeightKg.lowerBound), validWeightKg.upperBound)
            fixed.append("体重")
        }
        if !validHeightCm.contains(next.profile.heightCm) {
            next.profile.heightCm = min(max(next.profile.heightCm, validHeightCm.lowerBound), validHeightCm.upperBound)
            fixed.append("身高")
        }
        if next.profile.dailyKcalGoal <= 0 {
            next.profile.dailyKcalGoal = 2200
            fixed.append("每日热量目标")
        }
        if next.waterGoalMl <= 0 {
            next.waterGoalMl = WaterLog.defaultGoalMl
            fixed.append("饮水目标")
        }
        return (next, fixed)
    }

    /// 资料保存时用的钳制（与 clamped 共用同一套范围）。
    static func clampProfile(_ profile: Profile) -> Profile {
        var next = profile
        next.weightKg = min(max(next.weightKg, validWeightKg.lowerBound), validWeightKg.upperBound)
        next.heightCm = min(max(next.heightCm, validHeightCm.lowerBound), validHeightCm.upperBound)
        if next.dailyKcalGoal <= 0 { next.dailyKcalGoal = 2200 }
        return next
    }

    // MARK: - 文件名（毫秒 + UTC 日期，同一秒内多次操作也不撞名；可复现）

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f
    }()

    private static func dayFormatter(timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// 导出文件名默认用设备时区（用户看到的日期就是本地日期）；
    /// 测试传 UTC 时区可复现。
    static func exportFileName(date: Date = Date(), timeZone: TimeZone = .current) -> String {
        "stride-backup-\(dayFormatter(timeZone: timeZone).string(from: date)).json"
    }

    static func quarantineName(date: Date = Date()) -> String {
        "state.corrupt-\(fileDateFormatter.string(from: date)).json"
    }

    static func backupBeforeImportName(date: Date = Date()) -> String {
        "state.backup-before-import-\(fileDateFormatter.string(from: date)).json"
    }
}
