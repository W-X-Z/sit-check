import Foundation
import SQLite3

public enum StoreError: Error, CustomStringConvertible {
    case sqlite(String)

    public var description: String {
        switch self {
        case .sqlite(let message): return "SQLite: \(message)"
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 로컬 SQLite 파일 하나 (NFR-02). 외부 의존성 없이 시스템 SQLite3를 쓴다.
/// 영상과 프레임별 좌표는 저장하지 않고, 분 단위 요약 수치만 남긴다.
public final class Store {
    private var db: OpaquePointer?
    public let path: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 스키마 버전 (PRAGMA user_version)
    public static let schemaVersion = 2

    /// - Parameter path: 파일 경로. 테스트에서는 ":memory:"
    public init(path: String) throws {
        self.path = path
        if path != ":memory:" {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        encoder.outputFormatting = [.sortedKeys]
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SitCheck", isDirectory: true).appendingPathComponent("sitcheck.sqlite")
    }

    // MARK: - Schema

    private func migrate() throws {
        try exec("""
        PRAGMA journal_mode = WAL;
        CREATE TABLE IF NOT EXISTS sit_bout (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_at REAL NOT NULL,
            end_at REAL NOT NULL,
            duration_min REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS nudge (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            at REAL NOT NULL,
            rule_id TEXT NOT NULL,
            stretch_ids TEXT NOT NULL,
            action TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS stretch_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            at REAL NOT NULL,
            stretch_id TEXT NOT NULL,
            tighter_side TEXT,
            symptom TEXT NOT NULL DEFAULT 'none',
            nudge_id INTEGER REFERENCES nudge(id) ON DELETE SET NULL
        );
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_nudge_at ON nudge(at);
        CREATE INDEX IF NOT EXISTS idx_stretch_log_at ON stretch_log(at);
        """)

        if try userVersion() < 2 {
            try addColumnIfMissing(table: "sit_bout", column: "end_reason", type: "TEXT")
            try addColumnIfMissing(table: "nudge", column: "feedback", type: "TEXT")
            try addColumnIfMissing(table: "nudge", column: "detail", type: "TEXT")
            try exec("""
            CREATE TABLE IF NOT EXISTS posture_minute (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                start_at REAL NOT NULL,
                end_at REAL NOT NULL,
                label TEXT,
                mode TEXT NOT NULL,
                frame_cap INTEGER,
                frames INTEGER NOT NULL,
                face_frames INTEGER NOT NULL,
                analysis_ms REAL,
                cpu_pct REAL,
                bout_start_at REAL,
                settings_version INTEGER NOT NULL DEFAULT 0,
                stats TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS posture_event (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                at REAL NOT NULL,
                rule_id TEXT NOT NULL,
                variant TEXT NOT NULL,
                mode TEXT NOT NULL,
                actionable INTEGER NOT NULL,
                detail TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS checkin (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                at REAL NOT NULL,
                question TEXT NOT NULL,
                answer TEXT NOT NULL,
                still_minutes REAL,
                drift_score REAL
            );
            CREATE INDEX IF NOT EXISTS idx_posture_minute_start ON posture_minute(start_at);
            CREATE INDEX IF NOT EXISTS idx_posture_event_at ON posture_event(at);
            CREATE INDEX IF NOT EXISTS idx_checkin_at ON checkin(at);
            PRAGMA user_version = 2;
            """)
        }
    }

    public func userVersion() throws -> Int {
        try query("PRAGMA user_version", []) { stmt in Int(sqlite3_column_int64(stmt, 0)) }.first ?? 0
    }

    private func addColumnIfMissing(table: String, column: String, type: String) throws {
        let columns = try query("PRAGMA table_info(\(table))", []) { stmt in columnText(stmt, 1) ?? "" }
        if !columns.contains(column) {
            try exec("ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
        }
    }

    // MARK: - Writes

    public func insert(_ bout: SitBout) throws {
        try run(
            "INSERT INTO sit_bout (start_at, end_at, duration_min, end_reason) VALUES (?, ?, ?, ?)",
            [.double(bout.start.timeIntervalSince1970), .double(bout.end.timeIntervalSince1970), .double(bout.durationMinutes),
             bout.endReason.map { Value.text($0.rawValue) } ?? Value.null]
        )
    }

    @discardableResult
    public func insert(_ nudge: NudgeRecord) throws -> Int64 {
        try run(
            "INSERT INTO nudge (at, rule_id, stretch_ids, action, feedback, detail) VALUES (?, ?, ?, ?, ?, ?)",
            [.double(nudge.at.timeIntervalSince1970), .text(nudge.rule.rawValue),
             .text(nudge.stretchIDs.joined(separator: ",")), .text(nudge.action.rawValue),
             nudge.feedback.map { Value.text($0.rawValue) } ?? Value.null,
             nudge.detail.map { Value.text($0) } ?? Value.null]
        )
        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    public func insert(_ log: StretchLog) throws -> Int64 {
        try run(
            "INSERT INTO stretch_log (at, stretch_id, tighter_side, symptom, nudge_id) VALUES (?, ?, ?, ?, ?)",
            [.double(log.at.timeIntervalSince1970), .text(log.stretchID),
             log.tighterSide.map { Value.text($0.rawValue) } ?? Value.null, .text(log.symptom.rawValue),
             log.nudgeID.map { Value.int($0) } ?? Value.null]
        )
        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    public func insert(_ minute: PostureMinute) throws -> Int64 {
        let stats = String(decoding: try encoder.encode(minute.stats), as: UTF8.self)
        try run(
            """
            INSERT INTO posture_minute (start_at, end_at, label, mode, frame_cap, frames, face_frames, analysis_ms, cpu_pct,
                                        bout_start_at, settings_version, stats)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [.double(minute.start.timeIntervalSince1970), .double(minute.end.timeIntervalSince1970),
             minute.label.map { Value.text($0) } ?? Value.null, .text(minute.mode.rawValue),
             minute.frameCap.map { Value.int($0 ? 1 : 0) } ?? Value.null,
             .int(Int64(minute.frames)), .int(Int64(minute.faceFrames)),
             minute.analysisMs.map { Value.double($0) } ?? Value.null,
             minute.cpuPercent.map { Value.double($0) } ?? Value.null,
             minute.boutStart.map { Value.double($0.timeIntervalSince1970) } ?? Value.null,
             .int(Int64(minute.settingsVersion)), .text(stats)]
        )
        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    public func insert(_ event: PostureEventRecord) throws -> Int64 {
        let detail = String(decoding: try encoder.encode(event.detail), as: UTF8.self)
        try run(
            "INSERT INTO posture_event (at, rule_id, variant, mode, actionable, detail) VALUES (?, ?, ?, ?, ?, ?)",
            [.double(event.at.timeIntervalSince1970), .text(event.rule.rawValue), .text(event.variant),
             .text(event.mode.rawValue), .int(event.actionable ? 1 : 0), .text(detail)]
        )
        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    public func insert(_ checkIn: CheckInRecord) throws -> Int64 {
        try run(
            "INSERT INTO checkin (at, question, answer, still_minutes, drift_score) VALUES (?, ?, ?, ?, ?)",
            [.double(checkIn.at.timeIntervalSince1970), .text(checkIn.question), .text(checkIn.answer.rawValue),
             checkIn.stillMinutes.map { Value.double($0) } ?? Value.null,
             checkIn.driftScore.map { Value.double($0) } ?? Value.null]
        )
        return sqlite3_last_insert_rowid(db)
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let json = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        try run("INSERT INTO settings (key, value) VALUES ('app', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(json)])
    }

    public func loadSettings() throws -> AppSettings {
        let rows = try query("SELECT value FROM settings WHERE key = 'app'", []) { stmt in columnText(stmt, 0) ?? "" }
        guard let json = rows.first, let data = json.data(using: .utf8) else { return .default }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
    }

    /// 전체 삭제 (설정은 유지)
    public func deleteAllRecords() throws {
        try exec("""
        DELETE FROM stretch_log; DELETE FROM nudge; DELETE FROM sit_bout;
        DELETE FROM posture_minute; DELETE FROM posture_event; DELETE FROM checkin;
        """)
    }

    // MARK: - Reads

    public func bouts(since: Date) throws -> [SitBout] {
        try query("SELECT start_at, end_at, end_reason FROM sit_bout WHERE end_at >= ? ORDER BY start_at", [.double(since.timeIntervalSince1970)]) { stmt in
            SitBout(start: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                    end: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                    endReason: columnText(stmt, 2).flatMap(BoutEndReason.init(rawValue:)))
        }
    }

    public func nudges(since: Date) throws -> [NudgeRecord] {
        try query("SELECT id, at, rule_id, stretch_ids, action, feedback, detail FROM nudge WHERE at >= ? ORDER BY at, id",
                  [.double(since.timeIntervalSince1970)]) { stmt in
            NudgeRecord(
                id: sqlite3_column_int64(stmt, 0),
                at: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                rule: NudgeRule(rawValue: columnText(stmt, 2) ?? "") ?? .longSitting,
                stretchIDs: (columnText(stmt, 3) ?? "").split(separator: ",").map(String.init),
                action: NudgeAction(rawValue: columnText(stmt, 4) ?? "") ?? .dismiss,
                feedback: columnText(stmt, 5).flatMap(NudgeFeedback.init(rawValue:)),
                detail: columnText(stmt, 6)
            )
        }
    }

    /// 처방 이력 (오래된 것부터). 스트레칭이 없는 카드(카메라 카드, 아이콘)는 뺀다.
    public func recentPrescriptions(limit: Int = 20) throws -> [[String]] {
        let rows = try query("SELECT stretch_ids FROM nudge WHERE rule_id != 'R4' AND stretch_ids != '' ORDER BY at DESC, id DESC LIMIT ?",
                             [.int(Int64(limit))]) { stmt in
            (columnText(stmt, 0) ?? "").split(separator: ",").map(String.init)
        }
        return rows.reversed()
    }

    public func stretchLogs(since: Date) throws -> [StretchLog] {
        try query("SELECT id, at, stretch_id, tighter_side, symptom, nudge_id FROM stretch_log WHERE at >= ? ORDER BY at, id", [.double(since.timeIntervalSince1970)]) { stmt in
            StretchLog(
                id: sqlite3_column_int64(stmt, 0),
                at: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                stretchID: columnText(stmt, 2) ?? "",
                tighterSide: columnText(stmt, 3).flatMap(Side.init(rawValue:)),
                symptom: columnText(stmt, 4).flatMap(Symptom.init(rawValue:)) ?? .none,
                nudgeID: sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 5)
            )
        }
    }

    /// 분 단위 자세 요약 (시간 순서)
    public func postureMinutes(since: Date, until: Date = .distantFuture) throws -> [PostureMinute] {
        try fetchMinutes(where: "start_at >= ? AND start_at < ?",
                         [.double(since.timeIntervalSince1970), .double(min(until.timeIntervalSince1970, 1e12))])
    }

    /// 특정 실험 라벨이 붙은 분 요약 (기간 제한 없음)
    public func postureMinutes(label: String) throws -> [PostureMinute] {
        try fetchMinutes(where: "label = ?", [.text(label)])
    }

    private func fetchMinutes(where condition: String, _ values: [Value]) throws -> [PostureMinute] {
        let decoder = self.decoder
        return try query("""
            SELECT id, start_at, end_at, label, mode, frames, face_frames, analysis_ms, cpu_pct, bout_start_at,
                   settings_version, stats, frame_cap
            FROM posture_minute WHERE \(condition) ORDER BY start_at, id
            """, values) { stmt in
            let statsJSON = columnText(stmt, 11) ?? "{}"
            let stats = (try? decoder.decode([String: FeatureStat].self, from: Data(statsJSON.utf8))) ?? [:]
            return PostureMinute(
                id: sqlite3_column_int64(stmt, 0),
                start: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                end: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                label: columnText(stmt, 3),
                mode: AnalysisMode(rawValue: columnText(stmt, 4) ?? "") ?? .face,
                frameCap: columnDouble(stmt, 12).map { $0 != 0 },
                frames: Int(sqlite3_column_int64(stmt, 5)),
                faceFrames: Int(sqlite3_column_int64(stmt, 6)),
                stats: stats,
                analysisMs: columnDouble(stmt, 7),
                cpuPercent: columnDouble(stmt, 8),
                boutStart: columnDouble(stmt, 9).map { Date(timeIntervalSince1970: $0) },
                settingsVersion: Int(sqlite3_column_int64(stmt, 10))
            )
        }
    }

    public func postureEvents(since: Date) throws -> [PostureEventRecord] {
        let decoder = self.decoder
        return try query("SELECT id, at, rule_id, variant, mode, actionable, detail FROM posture_event WHERE at >= ? ORDER BY at, id",
                         [.double(since.timeIntervalSince1970)]) { stmt in
            let detailJSON = columnText(stmt, 6) ?? "{}"
            return PostureEventRecord(
                id: sqlite3_column_int64(stmt, 0),
                at: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                rule: NudgeRule(rawValue: columnText(stmt, 2) ?? "") ?? .stillness,
                variant: columnText(stmt, 3) ?? "",
                mode: PostureAlertMode(rawValue: columnText(stmt, 4) ?? "") ?? .shadow,
                actionable: sqlite3_column_int64(stmt, 5) != 0,
                detail: (try? decoder.decode([String: Double].self, from: Data(detailJSON.utf8))) ?? [:]
            )
        }
    }

    public func checkIns(since: Date) throws -> [CheckInRecord] {
        try query("SELECT id, at, question, answer, still_minutes, drift_score FROM checkin WHERE at >= ? ORDER BY at, id",
                  [.double(since.timeIntervalSince1970)]) { stmt in
            CheckInRecord(
                id: sqlite3_column_int64(stmt, 0),
                at: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                question: columnText(stmt, 2) ?? "",
                answer: CheckInAnswer(rawValue: columnText(stmt, 3) ?? "") ?? .dismissed,
                stillMinutes: columnDouble(stmt, 4),
                driftScore: columnDouble(stmt, 5)
            )
        }
    }

    // MARK: - CSV export

    /// 테이블별 CSV 파일을 `directory`에 쓴다. 시각은 로컬 시간 ISO 8601.
    @discardableResult
    public func exportCSV(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .current
        fmt.formatOptions = [.withInternetDateTime]
        func ts(_ d: Date) -> String { fmt.string(from: d) }
        func num(_ v: Double?, _ digits: Int = 4) -> String { v.map { String(format: "%.\(digits)f", $0) } ?? "" }
        let all = Date(timeIntervalSince1970: 0)

        var files: [URL] = []
        func write(_ name: String, header: [String], rows: [[String]]) throws {
            let url = directory.appendingPathComponent(name)
            let lines = ([header] + rows).map { $0.map(csvEscape).joined(separator: ",") }
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }

        try write("sit_bout.csv", header: ["start_at", "end_at", "duration_min", "end_reason"],
                  rows: try bouts(since: all).map { [ts($0.start), ts($0.end), String(format: "%.1f", $0.durationMinutes), $0.endReason?.rawValue ?? ""] })
        try write("nudge.csv", header: ["id", "at", "rule_id", "stretch_ids", "action", "feedback", "detail"],
                  rows: try nudges(since: all).map { ["\($0.id ?? 0)", ts($0.at), $0.rule.rawValue, $0.stretchIDs.joined(separator: " "),
                                                     $0.action.rawValue, $0.feedback?.rawValue ?? "", $0.detail ?? ""] })
        try write("stretch_log.csv", header: ["at", "stretch_id", "tighter_side", "symptom", "nudge_id"],
                  rows: try stretchLogs(since: all).map { [ts($0.at), $0.stretchID, $0.tighterSide?.rawValue ?? "", $0.symptom.rawValue, $0.nudgeID.map(String.init) ?? ""] })

        let features: [PostureFeature] = [.faceX, .faceY, .faceWidth, .roll, .yaw, .pitch, .eyeDistance, .shoulderY, .neckRatio, .shoulderWidth]
        try write("posture_minute.csv",
                  header: ["start_at", "end_at", "label", "mode", "frame_cap", "frames", "face_frames", "analysis_ms", "cpu_pct", "bout_start_at", "settings_version"]
                    + features.flatMap { ["\($0.rawValue)_median", "\($0.rawValue)_mad", "\($0.rawValue)_p10", "\($0.rawValue)_p90"] },
                  rows: try postureMinutes(since: all).map { m in
                      [ts(m.start), ts(m.end), m.label ?? "", m.mode.rawValue, m.frameCap.map { $0 ? "1" : "0" } ?? "", "\(m.frames)", "\(m.faceFrames)",
                       num(m.analysisMs, 1), num(m.cpuPercent, 2), m.boutStart.map(ts) ?? "", "\(m.settingsVersion)"]
                          + features.flatMap { f -> [String] in
                              guard let s = m[f] else { return ["", "", "", ""] }
                              return [num(s.median), num(s.mad), num(s.p10), num(s.p90)]
                          }
                  })
        try write("posture_event.csv", header: ["at", "rule_id", "variant", "mode", "actionable", "detail"],
                  rows: try postureEvents(since: all).map { e in
                      let detail = e.detail.keys.sorted().map { "\($0)=\(num(e.detail[$0], 3))" }.joined(separator: " ")
                      return [ts(e.at), e.rule.rawValue, e.variant, e.mode.rawValue, e.actionable ? "1" : "0", detail]
                  })
        try write("checkin.csv", header: ["at", "question", "answer", "still_minutes", "drift_score"],
                  rows: try checkIns(since: all).map { [ts($0.at), $0.question, $0.answer.rawValue, num($0.stillMinutes, 1), num($0.driftScore, 2)] })
        return files
    }

    // MARK: - SQLite helpers

    private enum Value {
        case int(Int64), double(Double), text(String), null
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw StoreError.sqlite(message)
        }
    }

    private func prepare(_ sql: String, _ values: [Value]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        for (i, value) in values.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case .int(let v): sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): sqlite3_bind_double(stmt, idx, v)
            case .text(let v): sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case .null: sqlite3_bind_null(stmt, idx)
            }
        }
        return stmt
    }

    private func run(_ sql: String, _ values: [Value]) throws {
        let stmt = try prepare(sql, values)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, _ values: [Value], map: (OpaquePointer?) -> T) throws -> [T] {
        let stmt = try prepare(sql, values)
        defer { sqlite3_finalize(stmt) }
        var result: [T] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                result.append(map(stmt))
            } else if rc == SQLITE_DONE {
                break
            } else {
                throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
        }
        return result
    }
}

private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL, let c = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: c)
}

private func columnDouble(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
    sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, index)
}

private func csvEscape(_ field: String) -> String {
    guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
