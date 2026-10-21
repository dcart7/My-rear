import Foundation
import Observation
import SwiftUI

enum AppColor {
    static let navy = Color(red: 0.07, green: 0.18, blue: 0.31)
    static let blue = Color(red: 0.19, green: 0.49, blue: 0.72)
    static let paleBlue = Color(red: 0.91, green: 0.96, blue: 0.99)
    static let orange = Color(red: 0.93, green: 0.51, blue: 0.18)
    static let canvas = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let surface = Color(red: 0.98, green: 0.98, blue: 1.00)
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var note: String = ""
    var isDone = false
}

struct ChecklistCategory: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var symbol: String
    var items: [ChecklistItem]
}

struct EmergencyContact: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var phone = ""
    var type = "Родина"
    var note = ""
}

struct FamilyPlan: Codable, Equatable {
    var name = ""
    var meetingPlace = ""
    var backupPlace = ""
    var outsideContact = ""
    var agreements = ""
    var needs = ""
}

struct CommunityReport: Codable, Identifiable, Equatable {
    var id = UUID()
    var category: String
    var area: String
    var message: String
    var createdAt = Date()
}

struct AppSnapshot: Codable {
    var plan: [ChecklistCategory]
    var bag: [ChecklistItem]
    var outage: [ChecklistItem]
    var contacts: [EmergencyContact]
    var family: FamilyPlan
}

@MainActor @Observable
final class AppStore {
    var plan: [ChecklistCategory]
    var bag: [ChecklistItem]
    var outage: [ChecklistItem]
    var contacts: [EmergencyContact]
    var family: FamilyPlan
    var reports: [CommunityReport]

    private let fileURL: URL
    private let reportsFileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("miy-tyl-data.json")
        reportsFileURL = directory.appendingPathComponent("miy-tyl-reports.json")
        reports = (try? Data(contentsOf: reportsFileURL)).flatMap { try? JSONDecoder().decode([CommunityReport].self, from: $0) } ?? []
        if let data = try? Data(contentsOf: fileURL), let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data) {
            plan = snapshot.plan; bag = snapshot.bag; outage = snapshot.outage; contacts = snapshot.contacts; family = snapshot.family
        } else {
            plan = Self.defaultPlan; bag = Self.defaultBag; outage = Self.defaultOutage; contacts = []; family = FamilyPlan()
        }
    }

    var planTotal: Int { plan.reduce(0) { $0 + $1.items.count } }
    var planDone: Int { plan.reduce(0) { $0 + $1.items.filter(\.isDone).count } }
    var progress: Int { percentage(done: planDone, total: planTotal) }
    var bagProgress: Int { percentage(done: bag.filter(\.isDone).count, total: bag.count) }
    var outageProgress: Int { percentage(done: outage.filter(\.isDone).count, total: outage.count) }

    func toggle(_ item: ChecklistItem, in categoryID: UUID? = nil, list: ListKind = .plan) {
        switch list {
        case .bag: update(&bag, item)
        case .outage: update(&outage, item)
        case .plan:
            guard let categoryID, let categoryIndex = plan.firstIndex(where: { $0.id == categoryID }), let itemIndex = plan[categoryIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
            plan[categoryIndex].items[itemIndex].isDone.toggle()
        }
        save()
    }

    func addTask(title: String, to categoryID: UUID) { guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let index = plan.firstIndex(where: { $0.id == categoryID }) else { return }; plan[index].items.append(ChecklistItem(title: title)); save() }
    func deleteContact(_ contact: EmergencyContact) { contacts.removeAll { $0.id == contact.id }; save() }
    func addReport(category: String, area: String, message: String) { let cleanMessage = String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)); let cleanArea = String(area.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); guard !cleanMessage.isEmpty, !cleanArea.isEmpty else { return }; reports.insert(CommunityReport(category: category, area: cleanArea, message: cleanMessage), at: 0); reports = Array(reports.prefix(100)); save() }
    func save() { let snapshot = AppSnapshot(plan: plan, bag: bag, outage: outage, contacts: contacts, family: family); guard let data = try? JSONEncoder().encode(snapshot) else { return }; try? data.write(to: fileURL, options: [.atomic, .completeFileProtection]); if let reportData = try? JSONEncoder().encode(reports) { try? reportData.write(to: reportsFileURL, options: [.atomic, .completeFileProtection]) } }
    func resetBag() { bag = bag.map { ChecklistItem(id: $0.id, title: $0.title, note: $0.note, isDone: false) }; save() }
    func exportJSON() -> String { guard let data = try? JSONEncoder().encode(AppSnapshot(plan: plan, bag: bag, outage: outage, contacts: contacts, family: family)) else { return "{}" }; return String(decoding: data, as: UTF8.self) }
    func importJSON(_ data: Data) -> Bool { guard let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data), snapshot.plan.count <= 30, snapshot.bag.count <= 100, snapshot.outage.count <= 100, snapshot.contacts.count <= 100 else { return false }; plan = snapshot.plan; bag = snapshot.bag; outage = snapshot.outage; contacts = snapshot.contacts; family = snapshot.family; save(); return true }

    enum ListKind { case plan, bag, outage }
    private func update(_ list: inout [ChecklistItem], _ item: ChecklistItem) { guard let index = list.firstIndex(where: { $0.id == item.id }) else { return }; list[index].isDone.toggle() }
    private func percentage(done: Int, total: Int) -> Int { total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded()) }

    static let defaultPlan: [ChecklistCategory] = [
        category("Документи", "doc.text", ["Зробити копії документів", "Підготувати документи в одному чохлі", "Зберегти важливі номери офлайн"]),
        category("Запаси води та їжі", "drop", ["Перевірити запас питної води", "Підготувати продукти тривалого зберігання", "Перевірити термін придатності запасів"]),
        category("Медикаменти й аптечка", "cross.case", ["Оновити домашню аптечку", "Перевірити особисті ліки", "Додати засоби першої допомоги"]),
        category("Зв’язок, освітлення та живлення", "bolt.fill", ["Зарядити павербанк", "Перевірити ліхтарик і батарейки", "Записати важливі контакти на папері"]),
        category("Одяг і необхідні речі", "bag", ["Підготувати сезонний одяг і взуття", "Скласти засоби гігієни", "Підготувати рюкзак для швидкого виходу"]),
        category("Тварини, діти та додаткова підтримка", "person.2", ["Підготувати речі для домашніх тварин", "Врахувати потреби дітей", "Узгодити допомогу людям, які її потребують"])
    ]
    static let defaultBag = ["Документи та їхні копії", "Вода й продукти тривалого зберігання", "Аптечка та необхідні медикаменти", "Телефон, зарядний пристрій і павербанк", "Ліхтарик і запасні батарейки", "Одяг і засоби особистої гігієни", "Готівка та банківські картки", "Речі для дітей", "Речі для домашніх тварин"].map { ChecklistItem(title: $0) }
    static let defaultOutage = ["Зарядити телефони та павербанки", "Перевірити освітлення та батарейки", "Набрати запас питної води", "Переконатися, що продукти безпечно зберігаються", "Підготувати важливі документи офлайн", "Узгодити альтернативний спосіб зв’язку", "Підготувати речі для дітей і тварин"].map { ChecklistItem(title: $0) }
    private static func category(_ title: String, _ symbol: String, _ titles: [String]) -> ChecklistCategory { ChecklistCategory(title: title, symbol: symbol, items: titles.map { ChecklistItem(title: $0) }) }
}
