import Foundation
import SQLite3

protocol DatabaseConnecting: Sendable {
    @discardableResult
    func execute(_ sql: String, bindings: [DatabaseBinding]) throws -> Int
    func query(_ sql: String, bindings: [DatabaseBinding]) throws -> [[String: DatabaseValue]]
    func transaction(_ block: () throws -> Void) throws
}

enum DatabaseBinding: Sendable, Equatable {
    case null
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    init(_ value: Int) {
        self = .integer(Int64(value))
    }

    init(_ value: Int64) {
        self = .integer(value)
    }

    init(_ value: Double) {
        self = .double(value)
    }

    init(_ value: String) {
        self = .text(value)
    }

    init(_ value: Data) {
        self = .blob(value)
    }
}

enum DatabaseValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    var intValue: Int? {
        switch self {
        case .integer(let value):
            return Int(value)
        case .double(let value):
            return Int(value)
        case .text(let value):
            return Int(value)
        case .null, .blob:
            return nil
        }
    }

    var int64Value: Int64? {
        switch self {
        case .integer(let value):
            return value
        case .double(let value):
            return Int64(value)
        case .text(let value):
            return Int64(value)
        case .null, .blob:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .integer(let value):
            return Double(value)
        case .double(let value):
            return value
        case .text(let value):
            return Double(value)
        case .null, .blob:
            return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .text(let value):
            return value
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .null, .blob:
            return nil
        }
    }
}

enum DatabaseError: Error, Sendable {
    case openFailed(String)
    case executionFailed(String)
    case queryFailed(String)
    case transactionFailed(String)
    case connectionClosed
}

final class DatabaseConnection: DatabaseConnecting, @unchecked Sendable {
    private let path: String
    private var database: OpaquePointer?

    init(path: String) throws {
        self.path = path
        try open()
    }

    deinit {
        close()
    }

    @discardableResult
    func execute(_ sql: String, bindings: [DatabaseBinding] = []) throws -> Int {
        guard let database else {
            throw DatabaseError.connectionClosed
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.executionFailed(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, database: database)

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw DatabaseError.executionFailed(errorMessage(database))
        }

        return Int(sqlite3_changes(database))
    }

    func query(_ sql: String, bindings: [DatabaseBinding] = []) throws -> [[String: DatabaseValue]] {
        guard let database else {
            throw DatabaseError.connectionClosed
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, database: database)

        var rows: [[String: DatabaseValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: DatabaseValue] = [:]
            let columnCount = sqlite3_column_count(statement)
            for index in 0..<columnCount {
                let key = String(cString: sqlite3_column_name(statement, index))
                row[key] = value(at: index, in: statement)
            }
            rows.append(row)
        }

        let resultCode = sqlite3_errcode(database)
        if resultCode != SQLITE_OK && resultCode != SQLITE_DONE && resultCode != SQLITE_ROW {
            throw DatabaseError.queryFailed(errorMessage(database))
        }

        return rows
    }

    func transaction(_ block: () throws -> Void) throws {
        guard let database else {
            throw DatabaseError.connectionClosed
        }

        guard sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.transactionFailed(errorMessage(database))
        }

        do {
            try block()
            guard sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                _ = sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
                throw DatabaseError.transactionFailed(errorMessage(database))
            }
        } catch {
            _ = sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func open() throws {
        guard database == nil else {
            return
        }

        let directory = (path as NSString).deletingLastPathComponent
        if !directory.isEmpty && !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { errorMessage($0) } ?? "Unable to open database"
            sqlite3_close(handle)
            throw DatabaseError.openFailed(message)
        }

        database = handle
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=NORMAL")
        try execute("PRAGMA busy_timeout=3000")
        try execute("PRAGMA foreign_keys=ON")
    }

    private func close() {
        guard let database else {
            return
        }
        sqlite3_close(database)
        self.database = nil
    }

    private func bind(_ bindings: [DatabaseBinding], to statement: OpaquePointer?, database: OpaquePointer) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32

            switch binding {
            case .null:
                result = sqlite3_bind_null(statement, index)
            case .integer(let value):
                result = sqlite3_bind_int64(statement, index, value)
            case .double(let value):
                result = sqlite3_bind_double(statement, index, value)
            case .text(let value):
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                result = sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, transient)
            case .blob(let value):
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                result = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), transient)
                }
            }

            guard result == SQLITE_OK else {
                throw DatabaseError.executionFailed(errorMessage(database))
            }
        }
    }

    private func value(at index: Int32, in statement: OpaquePointer?) -> DatabaseValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            guard let pointer = sqlite3_column_text(statement, index) else {
                return .null
            }
            return .text(String(cString: pointer))
        case SQLITE_BLOB:
            guard let pointer = sqlite3_column_blob(statement, index) else {
                return .null
            }
            let count = Int(sqlite3_column_bytes(statement, index))
            return .blob(Data(bytes: pointer, count: count))
        case SQLITE_NULL:
            return .null
        default:
            return .null
        }
    }

    private func errorMessage(_ database: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(database))
    }
}
