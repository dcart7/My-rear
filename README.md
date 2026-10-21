# 🇺🇦 Мій тил

**Мій тил** — нативний iOS-застосунок українською мовою для особистої підготовки до надзвичайних ситуацій. Він допомагає організувати чеклісти, тривожну валізу, важливі контакти та сімейні домовленості в одному приватному просторі.

Застосунок не є джерелом оперативних сповіщень і не замінює офіційні повідомлення відповідних служб.

## Основні можливості

- Персональний план безпеки з категоріями та прогресом.
- Інтерактивна тривожна валіза з можливістю скинути виконання.
- Чекліст підготовки до можливих відключень електроенергії.
- Важливі контакти з нативним переходом до телефонного дзвінка.
- Сімейний план: місця зустрічі, контакт в іншому місті, домовленості та особливі потреби.
- Довідкові рекомендації щодо евакуації, зв’язку, відключень, дітей і домашніх тварин.
- Експорт і імпорт персональних даних у JSON через системний share sheet та Files.
- Повна робота основних функцій без інтернету.
- Нижня Tab-навігація, адаптована під iPhone та iPad.
- Live Activity для обраної області на Lock Screen і Dynamic Island.
- Нативний центр «Тривоги та карта» на MapKit у компактному вікні.
- Окремий extension target для Live Activities.

## Технології

- Swift 5.10.
- SwiftUI для інтерфейсу.
- Observation (`@Observable`) для стану застосунку.
- `Codable` для контрольованого JSON-формату.
- Application Support + `NSFileProtectionComplete` для локального зберігання.
- `fileImporter` і `ShareLink` для обміну резервними копіями.
- SF Symbols для системних іконок.
- Deployment target: iOS 17.0+.
- Privacy Manifest без трекінгу та без збирання персональних даних.
- ActivityKit + WidgetKit для Live Activities.
- MapKit для інтерактивної карти.
- `URLSession` + `async/await` для мережевої інтеграції.
- Apple Material surfaces, safe-area layout і системна типографіка для iPhone/iPad.

Зовнішні SDK, аналітика, реклама, авторизація та серверна база даних не використовуються.

## Структура

```text
MiyTylApp/
├── project.yml
└── MiyTyl/
    ├── MiyTylApp.swift
    ├── AppStore.swift
    ├── ContentView.swift
    ├── AlertModels.swift
    ├── Info.plist
    └── PrivacyInfo.xcprivacy
MiyTylLiveActivity/
├── LiveActivity.swift
└── Info.plist
```

У репозиторії залишено лише нативний Swift/Xcode-проєкт.

## Запуск у Xcode

Потрібні macOS, Xcode 15.4+ та iOS Simulator або фізичний пристрій з iOS 17+.

Якщо встановлено XcodeGen:

```bash
cd MiyTylApp
xcodegen generate
open MiyTyl.xcodeproj
```

Альтернативно можна створити iOS App у Xcode з назвою `MiyTyl`, deployment target iOS 17.0, додати файли з каталогу `MiyTyl/` і вибрати `MiyTylApp.swift` як точку входу.

Перед запуском на пристрої потрібно налаштувати власний Apple Developer Team і Bundle Identifier `ua.miytyl.app`.

## Публікація в App Store

1. Відкрийте `MiyTylApp/MiyTyl.xcodeproj` у Xcode.
2. Увімкніть автоматичне підписання для `MiyTyl` і `MiyTylLiveActivity` та виберіть свою Team.
3. Замініть `ua.miytyl.app` і `ua.miytyl.app.live-activity` на власні унікальні Bundle ID, якщо вони вже зайняті.
4. Перевірте `Marketing Version` `1.0.0` і `Current Project Version` `1`.
5. Запустіть застосунок на фізичному iPhone та перевірте імпорт/експорт, телефонні посилання, Dynamic Island і Live Activity.
6. Виберіть `Any iOS Device (arm64)` → `Product` → `Archive`.
7. У Organizer виконайте `Validate App`, виправте попередження signing/privacy, потім `Distribute App` → `App Store Connect`.
8. У App Store Connect додайте назву, опис, ключові слова, категорію, скриншоти для iPhone/iPad, privacy answers і age rating.

У проєкт уже включено AppIcon asset catalog для iPhone/iPad, `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption = NO` та Live Activity extension. Apple Developer Team, сертифікати, provisioning profiles і App Store Connect metadata потрібно додати у власному акаунті.

## Приватність і безпека

- Реєстрація не потрібна.
- Дані залишаються на пристрої та зберігаються у файлі Application Support із захистом файлів iOS.
- Застосунок не надсилає контакти, адреси чи сімейний план на сервер.
- Імпорт JSON перевіряє структуру та обмежує кількість записів.
- Експорт виконується лише після дії користувача через системний share sheet.
- Не зберігайте в застосунку паролі, PIN-коди, банківські дані або іншу інформацію, яка не потрібна для плану безпеки.
- Для локальних повідомлень використовуйте лише район або населений пункт, без точної домашньої адреси.
- Live-дані тривог і публічні соціальні повідомлення не вбудовані у цю offline-first версію, щоб не зберігати секрети та не створювати неперевірені сповіщення.
- У репозиторій не повинні потрапляти сертифікати, provisioning profiles, `.env`-файли або ключі підпису.

## Обмеження першої версії

- Інтеграцію з alerts.in.ua потрібно додавати через окремий backend-проксі без секретів у клієнті.
- Немає синхронізації між пристроями та хмарного акаунта.
- Універсального державного API відключень за адресою немає: інтеграція має бути окремою для конкретного оператора мережі та регіону.
- Оперативну інформацію потрібно перевіряти через офіційні канали служб.

## Тривоги, Live Activities і карта

Клієнт використовує API-адаптер для `alerts.in.ua`, який вимагає персональний токен. У production рекомендовано використовувати власний backend-проксі, щоб не розкривати токен у клієнтському застосунку. Live Activity запускається лише після отримання даних і не замінює офіційні сповіщення.

Джерела:

- [ActivityKit — Apple Developer](https://developer.apple.com/documentation/ActivityKit)
- [Liquid Glass — Apple Developer](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [alerts.in.ua API Documentation](https://devs.alerts.in.ua/)

## Перевірка перед App Store

1. Перевірити навігацію на iPhone SE, iPhone 15/16 та iPad.
2. Перевірити збереження після перезапуску застосунку.
3. Перевірити імпорт валідного та пошкодженого JSON.
4. Перевірити телефонні посилання на фізичному iPhone.
5. Перевірити VoiceOver, Dynamic Type, контраст і роботу без інтернету.
6. Додати іконки App Store, launch screen та налаштувати signing у Xcode.
7. Перевірити App Privacy у App Store Connect: застосунок не збирає дані та не трекає користувача.
8. Перевірити Live Activity на Lock Screen і Dynamic Island на сумісному iPhone.
9. Не додавати API-токени, адреси користувачів або приватні ключі до Git.

## Внесок у проєкт

Ідеї та повідомлення про помилки вітаються. Створюйте Issue з описом проблеми, версією iOS і кроками відтворення. Не додавайте до Issue номери телефонів, адреси чи інші персональні дані.

---

**Мій тил — підготуйся заздалегідь. Подбай про себе та близьких.** 🇺🇦
