//
//  ModelExtensions.swift
//  StreamyyyApp
//
//  Common model extensions for all models
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Common Model Extensions
extension PersistentModel {
    
    // MARK: - Timestamps
    public var createdAtFormatted: String {
        if let createdAt = self.value(forKey: "createdAt") as? Date {
            return createdAt.formatted(.dateTime.month(.abbreviated).day().year())
        }
        return "Unknown"
    }
    
    public var updatedAtFormatted: String {
        if let updatedAt = self.value(forKey: "updatedAt") as? Date {
            return updatedAt.formatted(.dateTime.month(.abbreviated).day().year())
        }
        return "Unknown"
    }
    
    public var timeAgoFormatted: String {
        if let createdAt = self.value(forKey: "createdAt") as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: createdAt, relativeTo: Date())
        }
        return "Unknown"
    }
    
    // MARK: - Identifiable Support
    public var modelId: String {
        return self.value(forKey: "id") as? String ?? UUID().uuidString
    }
    
    // MARK: - Validation
    public func hasValidId() -> Bool {
        guard let id = self.value(forKey: "id") as? String else { return false }
        return !id.isEmpty && UUID(uuidString: id) != nil
    }
    
    // MARK: - Metadata Support
    public func getMetadataValue(_ key: String) -> String? {
        guard let metadata = self.value(forKey: "metadata") as? [String: String] else { return nil }
        return metadata[key]
    }
    
    public func setMetadataValue(_ key: String, _ value: String?) {
        guard var metadata = self.value(forKey: "metadata") as? [String: String] else { return }
        metadata[key] = value
        self.setValue(metadata, forKey: "metadata")
        
        if self.respondsToSelector(NSSelectorFromString("setUpdatedAt:")) {
            self.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    // MARK: - Archiving Support
    public var isArchived: Bool {
        return self.value(forKey: "isArchived") as? Bool ?? false
    }
    
    public func archive() {
        self.setValue(true, forKey: "isArchived")
        self.setValue(Date(), forKey: "archivedAt")
        
        if self.respondsToSelector(NSSelectorFromString("setUpdatedAt:")) {
            self.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    public func unarchive() {
        self.setValue(false, forKey: "isArchived")
        self.setValue(nil, forKey: "archivedAt")
        
        if self.respondsToSelector(NSSelectorFromString("setUpdatedAt:")) {
            self.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    // MARK: - Soft Delete Support
    public var isDeleted: Bool {
        return self.value(forKey: "isDeleted") as? Bool ?? false
    }
    
    public func softDelete() {
        self.setValue(true, forKey: "isDeleted")
        self.setValue(Date(), forKey: "deletedAt")
        
        if self.respondsToSelector(NSSelectorFromString("setUpdatedAt:")) {
            self.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    public func restore() {
        self.setValue(false, forKey: "isDeleted")
        self.setValue(nil, forKey: "deletedAt")
        
        if self.respondsToSelector(NSSelectorFromString("setUpdatedAt:")) {
            self.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    // MARK: - Export Support
    public func exportToDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                if let value = child.value as? String {
                    dict[label] = value
                } else if let value = child.value as? Int {
                    dict[label] = value
                } else if let value = child.value as? Double {
                    dict[label] = value
                } else if let value = child.value as? Bool {
                    dict[label] = value
                } else if let value = child.value as? Date {
                    dict[label] = value.timeIntervalSince1970
                } else if let value = child.value as? [String: String] {
                    dict[label] = value
                } else if let value = child.value as? [String] {
                    dict[label] = value
                }
            }
        }
        
        return dict
    }
}

// MARK: - Collection Extensions
extension Collection where Element: PersistentModel {
    
    // MARK: - Filtering
    public func active() -> [Element] {
        return self.filter { model in
            guard let isActive = model.value(forKey: "isActive") as? Bool else { return true }
            return isActive
        }
    }
    
    public func archived() -> [Element] {
        return self.filter { model in
            guard let isArchived = model.value(forKey: "isArchived") as? Bool else { return false }
            return isArchived
        }
    }
    
    public func notArchived() -> [Element] {
        return self.filter { model in
            guard let isArchived = model.value(forKey: "isArchived") as? Bool else { return true }
            return !isArchived
        }
    }
    
    public func deleted() -> [Element] {
        return self.filter { model in
            guard let isDeleted = model.value(forKey: "isDeleted") as? Bool else { return false }
            return isDeleted
        }
    }
    
    public func notDeleted() -> [Element] {
        return self.filter { model in
            guard let isDeleted = model.value(forKey: "isDeleted") as? Bool else { return true }
            return !isDeleted
        }
    }
    
    // MARK: - Sorting
    public func sortedByCreatedAt(_ ascending: Bool = true) -> [Element] {
        return self.sorted { lhs, rhs in
            guard let lhsDate = lhs.value(forKey: "createdAt") as? Date,
                  let rhsDate = rhs.value(forKey: "createdAt") as? Date else { return false }
            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }
    }
    
    public func sortedByUpdatedAt(_ ascending: Bool = true) -> [Element] {
        return self.sorted { lhs, rhs in
            guard let lhsDate = lhs.value(forKey: "updatedAt") as? Date,
                  let rhsDate = rhs.value(forKey: "updatedAt") as? Date else { return false }
            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }
    }
    
    // MARK: - Grouping
    public func groupedByCreatedDate() -> [String: [Element]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return Dictionary(grouping: self) { element in
            guard let createdAt = element.value(forKey: "createdAt") as? Date else { return "Unknown" }
            return formatter.string(from: createdAt)
        }
    }
    
    public func groupedByMonth() -> [String: [Element]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        return Dictionary(grouping: self) { element in
            guard let createdAt = element.value(forKey: "createdAt") as? Date else { return "Unknown" }
            return formatter.string(from: createdAt)
        }
    }
    
    // MARK: - Statistics
    public func createdToday() -> [Element] {
        let calendar = Calendar.current
        let today = Date()
        
        return self.filter { element in
            guard let createdAt = element.value(forKey: "createdAt") as? Date else { return false }
            return calendar.isDate(createdAt, inSameDayAs: today)
        }
    }
    
    public func createdThisWeek() -> [Element] {
        let calendar = Calendar.current
        let today = Date()
        
        return self.filter { element in
            guard let createdAt = element.value(forKey: "createdAt") as? Date else { return false }
            let weekOfYear = calendar.component(.weekOfYear, from: createdAt)
            let currentWeek = calendar.component(.weekOfYear, from: today)
            let year = calendar.component(.year, from: createdAt)
            let currentYear = calendar.component(.year, from: today)
            
            return weekOfYear == currentWeek && year == currentYear
        }
    }
    
    public func createdThisMonth() -> [Element] {
        let calendar = Calendar.current
        let today = Date()
        
        return self.filter { element in
            guard let createdAt = element.value(forKey: "createdAt") as? Date else { return false }
            let month = calendar.component(.month, from: createdAt)
            let currentMonth = calendar.component(.month, from: today)
            let year = calendar.component(.year, from: createdAt)
            let currentYear = calendar.component(.year, from: today)
            
            return month == currentMonth && year == currentYear
        }
    }
    
    // MARK: - Batch Operations
    public func batchUpdate(_ updateBlock: (Element) -> Void) {
        self.forEach { element in
            updateBlock(element)
        }
    }
    
    public func batchArchive() {
        self.forEach { element in
            element.archive()
        }
    }
    
    public func batchUnarchive() {
        self.forEach { element in
            element.unarchive()
        }
    }
    
    public func batchDelete() {
        self.forEach { element in
            element.softDelete()
        }
    }
    
    public func batchRestore() {
        self.forEach { element in
            element.restore()
        }
    }
}

// MARK: - Date Extensions
extension Date {
    
    // MARK: - Relative Time
    public var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    public var timeAgoFull: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // MARK: - Formatting
    public var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    public var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    public var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    public var shortDateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    // MARK: - Comparison
    public func isSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    public func isSameWeek(as date: Date) -> Bool {
        let calendar = Calendar.current
        let selfWeek = calendar.component(.weekOfYear, from: self)
        let dateWeek = calendar.component(.weekOfYear, from: date)
        let selfYear = calendar.component(.year, from: self)
        let dateYear = calendar.component(.year, from: date)
        
        return selfWeek == dateWeek && selfYear == dateYear
    }
    
    public func isSameMonth(as date: Date) -> Bool {
        let calendar = Calendar.current
        let selfMonth = calendar.component(.month, from: self)
        let dateMonth = calendar.component(.month, from: date)
        let selfYear = calendar.component(.year, from: self)
        let dateYear = calendar.component(.year, from: date)
        
        return selfMonth == dateMonth && selfYear == dateYear
    }
    
    // MARK: - Business Logic
    public var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    public var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    public var isThisWeek: Bool {
        return isSameWeek(as: Date())
    }
    
    public var isThisMonth: Bool {
        return isSameMonth(as: Date())
    }
    
    public var isInPast: Bool {
        return self < Date()
    }
    
    public var isInFuture: Bool {
        return self > Date()
    }
    
    // MARK: - Age Calculation
    public func age(from date: Date = Date()) -> TimeInterval {
        return date.timeIntervalSince(self)
    }
    
    public func ageInDays(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: date)
        return components.day ?? 0
    }
    
    public func ageInWeeks(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: self, to: date)
        return components.weekOfYear ?? 0
    }
    
    public func ageInMonths(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: date)
        return components.month ?? 0
    }
    
    public func ageInYears(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self, to: date)
        return components.year ?? 0
    }
}

// MARK: - String Extensions
extension String {
    
    // MARK: - Validation
    public var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    public var isValidURL: Bool {
        return URL(string: self) != nil
    }
    
    public var isValidUsername: Bool {
        let usernameRegex = "^[A-Za-z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: self)
    }
    
    public var isValidPhoneNumber: Bool {
        let phoneRegex = "^\\+?[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }
    
    // MARK: - Formatting
    public var truncated: String {
        return self.count > 50 ? String(self.prefix(50)) + "..." : self
    }
    
    public func truncated(to length: Int) -> String {
        return self.count > length ? String(self.prefix(length)) + "..." : self
    }
    
    public var capitalized: String {
        return self.prefix(1).capitalized + self.dropFirst()
    }
    
    public var initials: String {
        let components = self.components(separatedBy: " ")
        return components.compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }
    
    // MARK: - Utilities
    public var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
    
    public func contains(_ string: String, caseSensitive: Bool = false) -> Bool {
        if caseSensitive {
            return self.contains(string)
        } else {
            return self.lowercased().contains(string.lowercased())
        }
    }
    
    public func distance(to string: String) -> Int {
        // Simple Levenshtein distance implementation
        let a = Array(self)
        let b = Array(string)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]) + 1
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    public func similarity(to string: String) -> Double {
        let distance = Double(self.distance(to: string))
        let maxLength = Double(max(self.count, string.count))
        return maxLength == 0 ? 1.0 : (maxLength - distance) / maxLength
    }
}

// MARK: - Array Extensions
extension Array {
    
    // MARK: - Safe Access
    public subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    // MARK: - Chunking
    public func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    // MARK: - Unique
    public func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen: Set<T> = []
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}

// MARK: - Dictionary Extensions
extension Dictionary {
    
    // MARK: - Merging
    public func merging(_ other: Dictionary, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows -> Dictionary {
        return try self.merging(other, uniquingKeysWith: combine)
    }
    
    public func merging(_ other: Dictionary) -> Dictionary {
        return self.merging(other) { (_, new) in new }
    }
    
    // MARK: - Filtering
    public func filterKeys(_ isIncluded: (Key) -> Bool) -> Dictionary {
        return Dictionary(uniqueKeysWithValues: filter { isIncluded($0.key) })
    }
    
    public func filterValues(_ isIncluded: (Value) -> Bool) -> Dictionary {
        return Dictionary(uniqueKeysWithValues: filter { isIncluded($0.value) })
    }
    
    // MARK: - Mapping
    public func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> Dictionary<T, Value> {
        return Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
    
    public func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> Dictionary<T, Value> {
        return Dictionary<T, Value>(uniqueKeysWithValues: compactMap { key, value in
            guard let newKey = transform(key) else { return nil }
            return (newKey, value)
        })
    }
}

// MARK: - Color Extensions
extension Color {
    
    // MARK: - Hex Support
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public var hexString: String {
        guard let components = self.cgColor?.components else { return "#000000" }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255))
    }
    
    // MARK: - Brightness
    public func lighter(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    public func darker(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 + percentage)
    }
    
    // MARK: - Theme Colors
    public static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
    
    public static var systemBackground: Color {
        return Color(.systemBackground)
    }
    
    public static var systemSecondaryBackground: Color {
        return Color(.secondarySystemBackground)
    }
    
    public static var systemTertiaryBackground: Color {
        return Color(.tertiarySystemBackground)
    }
}

// MARK: - View Extensions
extension View {
    
    // MARK: - Conditional Modifiers
    @ViewBuilder
    public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    public func ifLet<Value, Content: View>(_ optionalValue: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = optionalValue {
            transform(self, value)
        } else {
            self
        }
    }
    
    // MARK: - Common Modifiers
    public func cardStyle() -> some View {
        self
            .padding()
            .background(Color.systemBackground)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
    
    public func primaryButton() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    public func secondaryButton() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(8)
    }
    
    public func badgeStyle(color: Color = .blue) -> some View {
        self
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    // MARK: - Debug Helpers
    public func debug() -> Self {
        #if DEBUG
        print("Debug: \(Self.self)")
        #endif
        return self
    }
    
    public func debugFrame(_ color: Color = .red) -> some View {
        #if DEBUG
        return self.overlay(
            Rectangle()
                .stroke(color, lineWidth: 1)
        )
        #else
        return self
        #endif
    }
}