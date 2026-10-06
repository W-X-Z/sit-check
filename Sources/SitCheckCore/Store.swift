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
/// 영상과 원본 좌표는 저장하지 않는다. v0.1은 sit_bout, nudge, stretch_log, settings 4개 테이블만 쓴다.
public final class Store {
    private var db: OpaquePointer?
    public let path: String

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
        PRAGMA user_version = 1;
        """)
    }

    // MARK: - Writes

    public func insert(_ bout: SitBout) throws {
        try run(
            "INSERT INTO sit_bout (start_at, end_at, duration_min) VALUES (?, ?, ?)",
            [.double(bout.start.timeIntervalSince1970), .double(bout.end.timeIntervalSince1970), .double(bout.durationMinutes)]
        )
    }

    @discardableResult
    public func insert(_ nudge: NudgeRecord) throws -> Int64 {
        try run(
            "INSERT INTO nudge (at, rule_id, stretch_ids, action) VALUES (?, ?, ?, ?)",
            [.double(nudge.at.timeIntervalSince1970), .text(nudge.rule.rawValue),
             .text(nudge.stretchIDs.joined(separator: ",")), .text(nudge.action.rawValue)]
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
        try exec("DELETE FROM stretch_log; DELETE FROM nudge; DELETE FROM sit_bout;")
    }

    // MARK: - Reads

    public func bouts(since: Date) throws -> [SitBout] {
        try query("SELECT start_at, end_at FROM sit_bout WHERE end_at >= ? ORDER BY start_at", [.double(since.timeIntervalSince1970)]) { stmt in
            SitBout(start: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                    end: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)))
        }
    }

    public func nudges(since: Date) throws -> [NudgeRecord] {
        try query("SELECT id, at, rule_id, stretch_ids, action FROM nudge WHERE at >= ? ORDER BY at, id", [.double(since.timeIntervalSince1970)]) { stmt in
            NudgeRecord(
                id: sqlite3_column_int64(stmt, 0),
                at: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                rule: NudgeRule(rawValue: columnText(stmt, 2) ?? "") ?? .longSitting,
                stretchIDs: (columnText(stmt, 3) ?? "").split(separator: ",").map(String.init),
                action: NudgeAction(rawValue: columnText(stmt, 4) ?? "") ?? .dismiss
            )
        }
    }

    /// 처방 이력 (오래된 것부터)
    public func recentPrescriptions(limit: Int = 20) throws -> [[String]] {
        let rows = try query("SELECT stretch_ids FROM nudge WHERE rule_id != 'R4' ORDER BY at DESC, id DESC LIMIT ?", [.int(Int64(limit))]) { stmt in
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

    // MARK: - CSV export

    /// 테이블별 CSV 파일을 `directory`에 쓴다. 시각은 로컬 시간 ISO 8601.
    @discardableResult
    public func exportCSV(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .current
        fmt.formatOptions = [.withInternetDateTime]
        func ts(_ d: Date) -> String { fmt.string(from: d) }
        let all = Date(timeIntervalSince1970: 0)

        var files: [URL] = []
        func write(_ name: String, header: [String], rows: [[String]]) throws {
            let url = directory.appendingPathComponent(name)
            let lines = ([header] + rows).map { $0.map(csvEscape).joined(separator: ",") }
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }

        try write("sit_bout.csv", header: ["start_at", "end_at", "duration_min"],
                  rows: try bouts(since: all).map { [ts($0.start), ts($0.end), String(format: "%.1f", $0.durationMinutes)] })
        try write("nudge.csv", header: ["id", "at", "rule_id", "stretch_ids", "action"],
                  rows: try nudges(since: all).map { ["\($0.id ?? 0)", ts($0.at), $0.rule.rawValue, $0.stretchIDs.joined(separator: " "), $0.action.rawValue] })
        try write("stretch_log.csv", header: ["at", "stretch_id", "tighter_side", "symptom", "nudge_id"],
                  rows: try stretchLogs(since: all).map { [ts($0.at), $0.stretchID, $0.tighterSide?.rawValue ?? "", $0.symptom.rawValue, $0.nudgeID.map(String.init) ?? ""] })
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

private func csvEscape(_ field: String) -> String {
    guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
