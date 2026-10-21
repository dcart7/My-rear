import SwiftUI
import UniformTypeIdentifiers
import MapKit

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(selectedTab: $selectedTab) }.tabItem { Label("Головна", systemImage: "house.fill") }.tag(0)
            NavigationStack { PlanView() }.tabItem { Label("Мій план", systemImage: "checklist") }.tag(1)
            NavigationStack { BagView() }.tabItem { Label("Валіза", systemImage: "archivebox.fill") }.tag(2)
            NavigationStack { ContactsView() }.tabItem { Label("Контакти", systemImage: "person.crop.circle") }.tag(3)
            NavigationStack { SettingsView() }.tabItem { Label("Налаштування", systemImage: "gearshape.fill") }.tag(4)
        }
        .tint(AppColor.blue)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: Int
    @State private var showingInfo = false
    @State private var showingSafety = false
    @State private var showingCommunity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderView(eyebrow: "ОГЛЯД ГОТОВНОСТІ", title: "Твоя готовність —\nтвоя опора.", subtitle: "Підготуйся заздалегідь. Збережи важливе. Подбай про себе та близьких.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickLink(title: "Мій план безпеки", value: "\(store.progress)% готовності", icon: "checkmark.shield.fill", color: .blue) { selectedTab = 1 }
                    QuickLink(title: "Тривожна валіза", value: "\(store.bagProgress)% зібрано", icon: "archivebox.fill", color: .orange) { selectedTab = 2 }
                    QuickLink(title: "Мої контакти", value: store.contacts.isEmpty ? "Додайте важливих людей" : "\(store.contacts.count) збережено", icon: "person.2.fill", color: .green) { selectedTab = 3 }
                    QuickLink(title: "Підготовка до відключень", value: "\(store.outageProgress)% виконано", icon: "bolt.fill", color: .purple) { selectedTab = 2 }
                }
                ReadinessCard { selectedTab = 1 }
                TodayCard()
                ImportantNotice()
                Button { showingInfo = true } label: { Label("Важлива інформація", systemImage: "book.closed.fill").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(.bordered)
                Button { showingSafety = true } label: { Label("Тривоги та карта", systemImage: "map.fill").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(.borderedProminent)
                Button { showingCommunity = true } label: { Label("Повідомити про проблему", systemImage: "bubble.left.and.exclamationmark.bubble.right").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 18)
        }
        .scrollIndicators(.hidden)
        .background(AppColor.canvas.ignoresSafeArea())
        .navigationTitle("Мій тил")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingInfo) { InformationView() }
        .sheet(isPresented: $showingSafety) { SafetyCenterView() }
        .sheet(isPresented: $showingCommunity) { CommunityReportsView() }
    }
}

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @State private var expanded: Set<UUID> = []

    var body: some View {
        List {
            Section { ProgressRow(title: "Загальна готовність", value: store.progress) }
            ForEach(store.plan) { category in
                Section {
                    DisclosureGroup(isExpanded: Binding(get: { expanded.contains(category.id) }, set: { $0 ? expanded.insert(category.id) : expanded.remove(category.id) })) {
                        ForEach(category.items) { item in TaskToggle(item: item) { store.toggle(item, categoryID: category.id) } }
                        Button { addTask(to: category.id) } label: { Label("Додати власне завдання", systemImage: "plus") }
                    } label: { Label { VStack(alignment: .leading) { Text(category.title).font(.headline); Text("\(category.items.filter { $0.isDone }.count) з \(category.items.count) виконано").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: category.symbol).foregroundStyle(AppColor.blue) } }
                }
            }
        }
        .navigationTitle("Мій план")
    }

    private func addTask(to id: UUID) { let alert = UIAlertController(title: "Нове завдання", message: nil, preferredStyle: .alert); alert.addTextField { $0.placeholder = "Назва завдання" }; alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel)); alert.addAction(UIAlertAction(title: "Додати", style: .default) { _ in store.addTask(title: alert.textFields?.first?.text ?? "", to: id) }); UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController?.present(alert, animated: true) }
}

struct BagView: View {
    @Environment(AppStore.self) private var store
    @State private var showingReset = false
    var body: some View {
        List { Section { ProgressRow(title: "Підготовка валізи", value: store.bagProgress) }; Section { ForEach(store.bag) { item in TaskToggle(item: item) { store.toggle(item, list: .bag) } } }; Section { Button { showingReset = true } label: { Label("Скинути виконання", systemImage: "arrow.counterclockwise") }.foregroundStyle(.orange) } }
            .navigationTitle("Тривожна валіза")
            .toolbar { ShareLink(item: store.exportJSON()) { Image(systemName: "square.and.arrow.up") } }
            .confirmationDialog("Скинути всі позначки валізи?", isPresented: $showingReset, titleVisibility: .visible) { Button("Скинути", role: .destructive) { store.resetBag() } }
    }
}

struct ContactsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingEditor = false
    @State private var editing: EmergencyContact?

    var body: some View {
        List {
            if store.contacts.isEmpty {
                ContentUnavailableView("Контактів ще немає", systemImage: "person.crop.circle.badge.plus", description: Text("Додайте людей, яким зможете зателефонувати."))
            }
            ForEach(store.contacts) { contact in
                HStack {
                    Image(systemName: "person.circle.fill").font(.title2).foregroundStyle(AppColor.blue)
                    VStack(alignment: .leading) {
                        Text(contact.name).font(.headline)
                        Text(contact.type).font(.caption).foregroundStyle(.secondary)
                        if let url = phoneURL(contact.phone) { Link(contact.phone, destination: url) }
                    }
                    Spacer()
                    Button { editing = contact; showingEditor = true } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                }
            }
            .onDelete { offsets in offsets.map { store.contacts[$0] }.forEach(store.deleteContact) }
        }
        .navigationTitle("Мої контакти")
        .toolbar { Button { editing = nil; showingEditor = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingEditor) { ContactEditor(contact: editing) }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingImporter = false
    @State private var importMessage: String?
    @State private var showingInfo = false
    var body: some View {
        Form {
            Section("Сімейний план") { TextField("Ім’я користувача", text: Bindable(store).family.name); TextField("Місце зустрічі № 1", text: Bindable(store).family.meetingPlace); TextField("Альтернативне місце", text: Bindable(store).family.backupPlace); TextField("Контакт в іншому місті", text: Bindable(store).family.outsideContact); TextField("Домовленості", text: Bindable(store).family.agreements, axis: .vertical); TextField("Особливі потреби", text: Bindable(store).family.needs, axis: .vertical) }
            Section("Дані на пристрої") { ShareLink(item: store.exportJSON()) { Label("Експортувати JSON", systemImage: "square.and.arrow.up") }; Button { showingImporter = true } label: { Label("Імпортувати JSON", systemImage: "square.and.arrow.down") }; Text("Персональні дані зберігаються локально у захищеному файлі застосунку. Не зберігайте тут паролі, PIN-коди чи банківські дані.").font(.footnote).foregroundStyle(.secondary) }
            Section("Довідка") { Button { showingInfo = true } label: { Label("Важлива інформація", systemImage: "book.closed") }; Text("Застосунок не замінює офіційні повідомлення та вказівки відповідних служб.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Налаштування")
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in importFile(result) }
        .alert("Імпорт", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) { Button("OK") {} } message: { Text(importMessage ?? "") }
        .sheet(isPresented: $showingInfo) { InformationView() }
        .onChange(of: store.family) { _, _ in store.save() }
    }
    private func importFile(_ result: Result<[URL], Error>) { guard case .success(let urls) = result, let url = urls.first else { return }; guard url.startAccessingSecurityScopedResource() else { importMessage = "Не вдалося отримати доступ до файлу."; return }; defer { url.stopAccessingSecurityScopedResource() }; do { let data = try Data(contentsOf: url); importMessage = store.importJSON(data) ? "Дані успішно імпортовано." : "Формат файлу некоректний." } catch { importMessage = "Не вдалося прочитати файл." } }
}

struct ContactEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var contact: EmergencyContact
    init(contact: EmergencyContact?) { _contact = State(initialValue: contact ?? EmergencyContact()) }
    var body: some View { NavigationStack { Form { TextField("Ім’я", text: $contact.name); TextField("Номер телефону", text: $contact.phone).keyboardType(.phonePad); Picker("Тип", selection: $contact.type) { ForEach(["Родина", "Друзі", "Лікар", "Інші важливі контакти"], id: \.self, content: Text.init) }; TextField("Примітки", text: $contact.note, axis: .vertical) }.navigationTitle(contact.name.isEmpty ? "Новий контакт" : "Контакт").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Зберегти") { if let index = store.contacts.firstIndex(where: { $0.id == contact.id }) { store.contacts[index] = contact } else { store.contacts.append(contact) }; store.save(); dismiss() }.disabled(contact.name.trimmingCharacters(in: .whitespaces).isEmpty || contact.phone.trimmingCharacters(in: .whitespaces).isEmpty) } } } }
}

struct InformationView: View { var body: some View { NavigationStack { List { InfoSection(title: "Як підготуватися до евакуації", text: "Підготуйте документи, ліки, воду, заряджений телефон і домовтеся з близькими про зв’язок."); InfoSection(title: "Як зібрати тривожну валізу", text: "Оберіть міцну сумку, врахуйте сезон і потреби кожного члена сім’ї."); InfoSection(title: "Як підготуватися до відключення", text: "Зарядіть пристрої, підготуйте освітлення, воду, їжу та альтернативний спосіб зв’язку."); InfoSection(title: "Діти та домашні тварини", text: "Підготуйте знайомі речі, корм, воду, переноску або повідець."); Section { Label("У разі безпосередньої небезпеки дотримуйтеся вказівок відповідних служб та офіційних повідомлень.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) } }.navigationTitle("Важлива інформація") } } }

struct HeaderView: View { let eyebrow: String; let title: String; let subtitle: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(eyebrow).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(title).font(.system(size: 33, weight: .bold, design: .rounded)).foregroundStyle(AppColor.navy); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) } } }
struct QuickLink: View { let title: String; let value: String; let icon: String; let color: Color; let action: () -> Void; var body: some View { Button(action: action) { VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(color); Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.navy).multilineTextAlignment(.leading); Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2) }.frame(maxWidth: .infinity, minHeight: 105, alignment: .leading).padding(16).background(.thinMaterial, in: .rect(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.55), lineWidth: 0.8) } } } }
struct ReadinessCard: View { @Environment(AppStore.self) private var store; let action: () -> Void; var body: some View { VStack(alignment: .leading, spacing: 14) { HStack { Label("Моя готовність", systemImage: "checkmark.shield.fill").font(.headline); Spacer(); Button("Відкрити план", action: action).font(.caption.weight(.semibold)) }; HStack(spacing: 18) { ProgressCircle(value: store.progress); VStack(alignment: .leading, spacing: 6) { Text("\(store.planDone) із \(store.planTotal) завдань виконано").font(.subheadline.weight(.semibold)); Text(store.progress >= 70 ? "Чудовий темп. Перевірте, чи все актуально." : "Маленькі кроки створюють відчуття опори.").font(.caption).foregroundStyle(.secondary) } } }.padding(18).background(AppColor.paleBlue, in: .rect(cornerRadius: 18)) } }
struct TodayCard: View { @Environment(AppStore.self) private var store; var body: some View { VStack(alignment: .leading, spacing: 4) { Text("Що варто зробити сьогодні").font(.headline); ForEach(store.plan.flatMap(\.items).filter { !$0.isDone }.prefix(3)) { item in TaskToggle(item: item) { for category in store.plan where category.items.contains(item) { store.toggle(item, categoryID: category.id) } } } }.padding(18).background(.background, in: .rect(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary) } } }
struct ImportantNotice: View { var body: some View { Label("У разі безпосередньої небезпеки дотримуйтеся вказівок відповідних служб та офіційних повідомлень.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.1), in: .rect(cornerRadius: 12)) } }
struct ProgressRow: View { let title: String; let value: Int; var body: some View { VStack(alignment: .leading, spacing: 8) { HStack { Text(title).font(.subheadline.weight(.semibold)); Spacer(); Text("\(value)%").font(.subheadline.weight(.bold)).foregroundStyle(AppColor.blue) }; ProgressView(value: Double(value), total: 100) } } }
struct ProgressCircle: View { let value: Int; var body: some View { ZStack { Circle().stroke(.white.opacity(0.8), lineWidth: 9); Circle().trim(from: 0, to: CGFloat(value) / 100).stroke(AppColor.blue, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90)); Text("\(value)%").font(.headline.weight(.bold)) }.frame(width: 78, height: 78) } }
struct TaskToggle: View { let item: ChecklistItem; let action: () -> Void; var body: some View { Button(action: action) { Label { Text(item.title).strikethrough(item.isDone).foregroundStyle(item.isDone ? .secondary : .primary) } icon: { Image(systemName: item.isDone ? "checkmark.square.fill" : "square").foregroundStyle(item.isDone ? AppColor.blue : .secondary) } }.buttonStyle(.plain).padding(.vertical, 4) } }
struct SafetyCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var backendURL = (Bundle.main.object(forInfoDictionaryKey: "MiyTylAPIBaseURL") as? String) ?? ""
    @State private var regionID = "16"
    @State private var status = "Дані ще не завантажено"
    @State private var isLoading = false
    private let service = AirAlertService()
    private let ukraine = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 49.0, longitude: 31.5), span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 20))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Map(initialPosition: .region(ukraine)) { Marker("Україна", coordinate: CLLocationCoordinate2D(latitude: 49.0, longitude: 31.5)) }.frame(height: 220).clipShape(.rect(cornerRadius: 16))
                    Label(status, systemImage: status.contains("актив") ? "exclamationmark.triangle.fill" : "shield.checkered").foregroundStyle(status.contains("актив") ? .red : .secondary)
                    Text("Рекомендовано використовувати backend-проксі. Токен alerts.in.ua не зберігається в застосунку.").font(.footnote).foregroundStyle(.secondary)
                    TextField("URL backend-проксі", text: $backendURL).textInputAutocapitalization(.never).keyboardType(.URL).textFieldStyle(.roundedBorder)
                    SecureField("API-токен", text: $token).textFieldStyle(.roundedBorder)
                    TextField("ID області", text: $regionID).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button { refresh() } label: { Label(isLoading ? "Оновлення…" : "Оновити дані", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled((token.isEmpty && backendURL.isEmpty) || isLoading)
                    Text("У разі безпосередньої небезпеки дотримуйтеся офіційних повідомлень відповідних служб.").font(.caption).foregroundStyle(.orange)
                }.padding()
            }.navigationTitle("Тривоги та карта").toolbar { Button("Готово") { dismiss() } }
        }
    }

    private func refresh() { guard let id = Int(regionID) else { return }; isLoading = true; Task { do { let result: AlertStatus; if let base = URL(string: backendURL), !backendURL.isEmpty { result = try await service.fetchFromBackend(baseURL: base, regionID: id) } else { guard let base = URL(string: "https://api.alerts.in.ua"), !token.isEmpty else { throw URLError(.userAuthenticationRequired) }; result = try await service.fetchStatus(baseURL: base, bearerToken: token, regionID: id) }; status = result.status == "active" ? "Активна тривога: \(result.locationTitle)" : "Активних тривог не зафіксовано"; await LiveActivityManager.shared.update(region: result.locationTitle, status: result.status) } catch { status = "Не вдалося отримати дані. Перевірте backend, токен або з’єднання." }; isLoading = false }
    }
}

struct CommunityReportsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category = "Немає світла"
    @State private var area = ""
    @State private var message = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Локальні повідомлення") { ForEach(store.reports) { report in VStack(alignment: .leading, spacing: 4) { Text(report.category).font(.headline); Text(report.message).font(.subheadline); Text(report.area).font(.caption).foregroundStyle(.secondary) } } }
                Section("Додати повідомлення") { Picker("Категорія", selection: $category) { ForEach(["Немає світла", "Немає води", "Проблема зі зв’язком", "Інше"], id: \.self, content: Text.init) }; TextField("Район або населений пункт без точної адреси", text: $area); TextField("Що сталося?", text: $message, axis: .vertical); Button("Опублікувати локально") { store.addReport(category: category, area: area, message: message); area = ""; message = "" }.disabled(area.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty) }
                Section { Text("Це локальна дошка на цьому пристрої. Для публічної соціальної мережі потрібні окремий сервер, модерація, правила спільноти, скарги, видалення контенту та захист персональних даних.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Спільнота").toolbar { Button("Готово") { dismiss() } }
        }
    }
}

struct InfoSection: View { let title: String; let text: String; var body: some View { Section(title) { Text(text).font(.subheadline).foregroundStyle(.secondary) } } }

private func phoneURL(_ phone: String) -> URL? { let sanitized = phone.filter { $0.isNumber || $0 == "+" }; return sanitized.isEmpty ? nil : URL(string: "tel://\(sanitized)") }
