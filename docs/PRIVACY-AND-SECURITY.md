# Приватность и безопасность ProfileDock

Состояние на **8 сентября 2026 года**. Этот обзор сопоставляет опубликованную **0.1.4 beta, build 9** — [изменения `639fb3d`](https://github.com/kunilingvistador/ProfileDock/commit/639fb3d), [объединённая версия `d6447b1`](https://github.com/kunilingvistador/ProfileDock/commit/d6447b1d89580310d5b5b726bb9cc76110ec5a7d) — и **кандидат 0.1.5, build 11**, [точный код `addbc13`](https://github.com/kunilingvistador/ProfileDock/commit/addbc132f018310a713642cac32c3e58e08e9c9b). **0.1.5 ещё не опубликована**. Проверки кандидата и границы подтверждений приведены в [VALIDATION.md](VALIDATION.md).

ProfileDock не отправляет данные Chrome разработчикам: в проверенном коде нет аккаунта ProfileDock, сервера приложения, аналитики или автоматической отправки отчётов. Переключение окон работает локально. Однако приложение читает некоторые личные метаданные, а получение значка сайта — отдельное, необязательное сетевое действие. «Локально» не означает «приложение технически не может получить доступ к другим данным».

## Что приложение читает и меняет

| Данные или действие | Для чего используются | Что сохраняется |
| --- | --- | --- |
| Названия профилей, поле аккаунта — часто email — и путь к аватару из локальных файлов Chrome | Чтобы было проще узнать профиль в интерфейсе | Список находится в памяти. В настройках ярлыка может сохраняться имя каталога профиля, например `Profile 1`; выбранная картинка сохраняется отдельно |
| ID окна, его заданное пользователем имя, полный заголовок, режим и состояние сворачивания | Список открытых окон, выбор и проверка привязки | Снимок окон находится в памяти; имя привязки сохраняется в настройках |
| Название и картинка, выбранные для ярлыка | Карточка приложения и значок в Dock | Локальные JSON/PNG-файлы и ресурсы созданного `.app` |
| Имена, пути и метаданные совместимых старых ярлыков; ссылки на приложения из настроек Dock | Импорт и обновление собственных ярлыков | Пути ярлыков и, при миграции, резервные копии |
| Заданное имя выбранного окна Chrome | Привязка ярлыка к существующему окну | Изменяется свойство Chrome `given name`; обычно добавляется маркер `PD-…` |
| Состояние сворачивания и порядок выбранного окна | Поднять нужное существующее окно | Окно разворачивается и перемещается вперёд; Chrome получает запрос активации |

Для обнаружения профилей приложение загружает файл `~/Library/Application Support/Google/Chrome/Local State` целиком и извлекает нужные поля `profile.info_cache`. Это не чтение только нескольких байтов файла. Аватар берётся из `Google Profile Picture.png` соответствующего профиля. Подробности реализации — в [AppModel](../Sources/ProfileDock/AppModel.swift) и [ProfileDiscovery](../Sources/ProfileDockCore/ProfileDiscovery.swift).

В проверенном [ChromeService](../Sources/ProfileDock/ChromeService.swift) нет запросов URL вкладок, содержимого страниц, истории, cookies или паролей и нет выполнения JavaScript в Chrome. Переключение не создаёт вкладки или окна. При этом **заголовок окна сам может содержать личную информацию**: название документа, переписки, сайта или аккаунта. Код не делает из заголовка безопасные или обезличенные данные.

**Инкогнито в 0.1.4:** приватные окна нельзя привязать или переключить через ProfileDock, но общий список сначала запрашивал их имена и заголовки, а затем интерфейс исключал их из выбора. Эти данные могли попадать в память приложения. В рабочем исправлении для 0.1.5 список сначала проверяет `mode` и пропускает инкогнито до явного чтения ID, имени, заголовка и свёрнутости. Полный AppleScript после изменения успешно скомпилирован; обработчики для этой проверки не выполнялись. Это ещё не проверка выпущенного пакета.

## Что означает разрешение Automation

Разрешение «ProfileDock → Google Chrome» позволяет приложению отправлять Chrome Apple Events. macOS не показывает отдельные переключатели «только поднять окно», «читать заголовок» и «читать URL». Текст запроса объясняет назначение, но сам по себе не ограничивает команды этим назначением. [Apple: управление другими приложениями](https://support.apple.com/guide/mac-help/allow-apps-to-automate-and-control-other-apps-mchl108e1718/mac), [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events).

Словарь Chrome предлагает больше возможностей, чем использует ProfileDock: чтение и изменение URL вкладок, доступ к закладкам, сохранение страниц и другие команды. JavaScript через Apple Events имеет дополнительную проверку разрешения в Chrome; ProfileDock его не требует и не включает. Поэтому корректное утверждение — **«проверенный код этого не делает»**, а не «выданное разрешение этого никогда не позволит». [Словарь Chromium](https://chromium.googlesource.com/chromium/src.git/+/lkgr/chrome/browser/ui/cocoa/applescript/scripting.sdef), [реализация команд вкладки](https://raw.githubusercontent.com/chromium/chromium/main/chrome/browser/ui/cocoa/applescript/tab_applescript.mm).

Опубликованная сборка не использует App Sandbox. Это обычное приложение macOS с файловым доступом в пределах прав текущего пользователя и системных ограничений. Отозвать управление Chrome можно в **Системных настройках → Конфиденциальность и безопасность → Автоматизация**. Это остановит разрешённые Apple Events, но не удалит сохранённые картинки и настройки и не запретит отдельное чтение доступного файла `Local State`.

## Когда используется сеть

Для переключения окон соединение с сервером ProfileDock не требуется. Сетевые запросы внутри приложения появляются, когда пользователь выбирает **получение значка по адресу сайта**.

Приложение загружает указанный адрес, при необходимости читает HTML для поиска значка, затем скачивает изображение. Сервер получает IP-адрес соединения, запрошенный путь и параметры URL; запрос обозначен User-Agent `ProfileDock/0.1 (site icon request)`. Это отдельная загрузка, а не чтение уже открытой страницы Chrome. Адреса с секретами в пути или параметрах не нужны для выбора значка: достаточно публичного адреса сайта.

В **0.1.4** используется временная URLSession с отключёнными cookies. Код не берёт cookies и авторизацию из профиля Chrome. Однако он допускает HTTP, переходы и значки с других сайтов; отдельное отключение URLSession credential storage и строгая проверка каждого перенаправления отсутствуют. Поэтому нельзя обещать, что запрос всегда ограничен одним публичным HTTPS-сервером.

**В рабочей ветке для 0.1.5 добавлено усиление:** HTTPS на стандартном порту, ограничения адресов, значки и перенаправления в пределах исходного origin — схемы, хоста и порта, — отключённые cookies, credential storage и кэш сессии. Перенаправления проверяются до следующего запроса; обычная проверка сертификатов TLS не отключается. Эти ограничения ещё не относятся к опубликованной 0.1.4. Даже проверка хоста **не гарантирует изоляцию на уровне DNS**: доменное имя может разрешиться во внутренний адрес. Загрузка собственного изображения из файла позволяет вообще обойтись без этой сетевой функции. Реализация: [FaviconService](../Sources/ProfileDock/FaviconService.swift), [FaviconDiscovery](../Sources/ProfileDockCore/FaviconDiscovery.swift), [FaviconURLPolicy](../Sources/ProfileDockCore/FaviconURLPolicy.swift).

В pending-версии входные изображения проходят ограничение размера и декодируются в один растр не более 512 × 512. Создаётся новый PNG без копирования исходных GPS/дат и другой metadata; ImageIO может добавить собственные поля. Этот путь применяется к значкам сайта, выбранным файлам, аватарам и сохранённым картинкам. Он уменьшает объём обрабатываемых данных, но не заменяет безопасность системного декодера. [SafeIconImage](../Sources/ProfileDockCore/SafeIconImage.swift), [IconService](../Sources/ProfileDock/IconService.swift).

Сайт проекта — отдельный ресурс на GitHub Pages. В проверенном коде сайта нет собственной аналитики, однако GitHub сообщает, что **записывает IP посетителей Pages в целях безопасности**, даже без входа в GitHub. Посещение сайта и загрузка релиза не равны отправке приложением данных Chrome. [Документация GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection).

## Где остаются данные

Основная папка — `~/Library/Application Support/ProfileDock/`:

| Путь | Содержимое |
| --- | --- |
| `shortcuts.json` | UUID, название ярлыка, имя привязки окна, необязательный каталог профиля и имя файла картинки, дата создания |
| `Icons/` | Сохранённые картинки ярлыков |
| `Launchers/` | Созданные приложения-ярлыки с именами, картинками, UUID и путём к ProfileDock |
| `controller-location.json` | Путь к последней явно открытой копии ProfileDock |
| `launcher-locations.json` | Пути совместимых ярлыков, которые приложение отслеживает для обновления |
| `Legacy Backups/` | Резервные копии старых ярлыков при миграции, включая прежние скрипты, картинки, метаданные и исходные пути |

У этих данных **нет собственного шифрования ProfileDock**. Настройки читаются как JSON, картинки — обычные файлы. Файловые права и защита диска macOS — отдельные механизмы; приложение не создаёт хранилище секретов. Имена и картинки также видны в Finder/Dock и могут оставаться в ярлыках вне основной папки. В UserDefaults хранится подсказка для интерфейса о ранее выданном разрешении; настоящим разрешением управляет macOS.

В рабочей ветке 0.1.5 добавлен [PrivateStorage](../Sources/ProfileDockCore/PrivateStorage.swift): права `0700` для основной папки и управляемых `Icons`/`Launchers`, `0600` для новых и заменяемых файлов данных; проверка владельца, типа и символьных ссылок, запись через файловые дескрипторы с атомарной заменой. Старые файлы не получают рекурсивное изменение прав, оригиналы резервных копий не переписываются. Это не шифрование и не защита от другой программы, работающей с тем же UID пользователя. На опубликованную 0.1.4 эти новые проверки не распространяются.

Если пользователь синхронизирует папку с ярлыками через iCloud или другой сервис либо делает резервные копии, эти имена, пути и изображения могут попасть туда. Это не синхронизация ProfileDock, но всё равно возможная копия личных данных. Удаление карточки из приложения не является очисткой всех файлов, значков Dock, резервных копий или имени окна Chrome.

## Диагностика и границы доверия

По умолчанию приложение не отправляет телеметрию и не пишет постоянный журнал переключений. В памяти есть ограниченный буфер измерений. Для разработки отдельно включается локальный журнал в `/private/tmp/ProfileDock-Performance-<UID>/`: фиксированные названия этапов, PID процесса, время и числовые длительности/результаты. В текущих вызовах нет названий профилей, окон, URL, UUID ярлыков или содержимого страниц. Файлы не отправляются автоматически, но времена запусков тоже являются информацией об использовании. [PerformanceTrace](../Sources/ProfileDockCore/PerformanceTrace.swift).

Открытый исходный код делает поведение проверяемым. Проверка подписи и SHA-256 помогает сопоставить файл с конкретной сборкой, но не доказывает отсутствие уязвимостей. Опубликованная 0.1.4 подписана **ad hoc и не нотарифицирована Apple**; такая подпись не удостоверяет независимым сертификатом личность издателя. Проверки сборки и запусков описаны в [RELEASE.md](RELEASE.md). Этот обзор — анализ кода и его границ, а не независимый пентест, сертификация или гарантия против заражённой сборки и вредоносной программы, уже работающей под вашей учётной записью.

## English summary

ProfileDock 0.1.4 beta does not upload Chrome data to its developers and has no account, backend or analytics. It locally loads Chrome profile metadata, optional avatars and window names/titles. Its Chrome automation does not request tab URLs, page contents, history, cookies or passwords. However, the macOS Automation grant is broader than these operations, and the app is not App Sandbox confined.

Settings, icons and exported shortcuts are not encrypted by ProfileDock and may enter your own synced folders or backups. Optional favicon fetching contacts the supplied website; 0.1.4 does not constrain all requests to one HTTPS origin. Release candidate **0.1.5, build 11** adds network/storage hardening and incognito-title minimization; its source CI and local package checks passed, but it is **not yet published**. Revoking Automation does not prevent separate filesystem metadata reads. Diagnostics are local and opt-in. GitHub Pages logs visitor IPs. Open source, hashes and the current ad-hoc signature are not a security guarantee; the published release and candidate are not notarized.

## Техническое приложение: проверенные границы

Ссылки ниже ведут к исходникам этой ветки и могут включать ещё не выпущенные изменения. Для воспроизведения поведения 0.1.4 используйте указанные в начале коммиты. Версионная граница особенно важна для списка инкогнито, сетевой загрузки и декодирования изображений.

| Область | Код и наблюдение |
| --- | --- |
| Метаданные профиля | [AppModel.swift](../Sources/ProfileDock/AppModel.swift), `loadProfiles`; [ProfileDiscovery.swift](../Sources/ProfileDockCore/ProfileDiscovery.swift), `decode`: чтение `Local State`, использование `name`, `user_name`, каталогов `Default`/`Profile N`, стандартного PNG аватара |
| Доступ к Chrome | [ChromeService.swift](../Sources/ProfileDock/ChromeService.swift), `listWindows`, `bindWindow`, `previewWindow`, `focusWindow`: только перечисленные выше чтения и изменения окна. В `execute` пользовательские строки передаются как `NSAppleEventDescriptor`, а не подставляются в текст AppleScript |
| Приватные окна | В 0.1.4 фильтрация списка происходила после чтения. Pending-исправление пропускает приватные строки раньше. Проверка режима и поиск по `given name` всё ещё могут обращаться к объектам приватных окон; это минимизация содержимого, не изоляция на уровне разрешения |
| Точность привязки | [Models.swift](../Sources/ProfileDockCore/Models.swift), `WindowMatcher`, и `ChromeService.focusWindow`: уникальное заданное имя, исключение инкогнито, отказ при отсутствии/дубликате. Имя можно изменить в Chrome; это не криптографическая привязка и не граница доступа между профилями |
| Внешний вызов | [Models.swift](../Sources/ProfileDockCore/Models.swift), `ShortcutRoute`, и [main.swift](../Sources/ProfileDock/main.swift): `profiledock://focus/<UUID>` выбирает уже сохранённый ярлык, `show` открывает интерфейс. Схема не является аутентификацией отправителя; знающий UUID может запросить переключение, но не передать AppleScript или произвольный URL Chrome |
| Ярлык-посредник | [ProfileDockLauncher/main.swift](../Sources/ProfileDockLauncher/main.swift) передаёт UUID контроллеру, сам не управляет Chrome. [ControllerLocation.swift](../Sources/ProfileDockCore/ControllerLocation.swift) проверяет структуру приложения; совпадение bundle ID не является проверкой доверенного издателя |
| Хранилище и импорт | [ShortcutStore.swift](../Sources/ProfileDockCore/ShortcutStore.swift), [LauncherMaintenance.swift](../Sources/ProfileDock/LauncherMaintenance.swift), [LauncherExporter.swift](../Sources/ProfileDock/LauncherExporter.swift): локальные JSON/изображения/ярлыки, чтение Dock, резервные копии миграции. Старый скрипт разбирается для поддерживаемой привязки, а не исполняется при импорте |
| Сеть и изображения | [FaviconService.swift](../Sources/ProfileDock/FaviconService.swift), [FaviconDiscovery.swift](../Sources/ProfileDockCore/FaviconDiscovery.swift), [IconService.swift](../Sources/ProfileDock/IconService.swift): необязательные запросы сайта и декодирование недоверенных изображений; сетевые и ресурсные ограничения нужно проверять отдельно от отсутствия телеметрии |
| Разрешения и пакет | [scripts/build.py](../scripts/build.py): `NSAppleEventsUsageDescription`; для сборки с Developer ID — entitlement `com.apple.security.automation.apple-events`. App Sandbox не включён; выпуск 0.1.4 использует ad-hoc подпись |
| Диагностика | [PerformanceTrace.swift](../Sources/ProfileDockCore/PerformanceTrace.swift), `record`, и места его вызова: локальная опция, фиксированные этапы и числовые значения. Ошибки Chrome отображаются локально; их текст не является обезличенным по определению |

### Проверки кандидата 0.1.5, build 11

Изменённый AppleScript списка окон прошёл компиляцию без исполнения обработчиков. Для правил favicon и изображений локально выполнены 11 тестовых методов со 118 проверками на фикстурах без сетевых запросов; Swift typecheck прошёл. Это не испытание произвольных внешних сайтов или всех системных декодеров. [CI 34235067293](https://github.com/kunilingvistador/ProfileDock/actions/runs/34235067293) для точного кода кандидата прошёл все 5 заданий: четыре сочетания macOS 15/26 и arm64/x86_64, а также сборку сайта. На каждом Mac прошли 77 XCTest-тестов, 13 Python-тестов и 8 сценариев совместимости со 134 проверками, без ошибок; также проверены собранные пакеты. Проверки файлового хранилища описаны отдельно в [LOCAL-STORAGE-AUDIT.md](LOCAL-STORAGE-AUDIT.md).

Финальный локальный ZIP 0.1.5 (11) отдельно распакован в новый временный каталог: SHA-256, CRC, обе универсальные программы и deep strict signature прошли проверку. Проверены окно приватности приложения, переход RU → EN к разделу приватности сайта и сохранность четырёх старых ярлыков, настроек и порядка Dock. Хеш архива и точные границы — в [VALIDATION.md](VALIDATION.md). Это проверка локального кандидата, а не скачанного публичного релиза; публикация и последующая проверка скачанного архива ещё предстоят.

### Зависимости сайта: отдельно от приложения на Mac

Нативное приложение написано на Swift и **не содержит npm-зависимостей сайта**. Сайт собирается в статические HTML/CSS/JS-файлы для GitHub Pages: сервер React Server Components, Node image optimizer и Cloudflare Workers там не развёрнуты. Серверные и инструментальные findings поэтому нельзя автоматически считать утечкой из приложения или доступной атакой на опубликованный Pages-сайт. При изменении способа размещения эту оценку нужно повторить.

В рабочей ветке обновлены React/React DOM/React Server DOM Webpack до `19.2.8`, Vinext до `1.0.0-beta.9`, Vite до `8.2.2` и необходимый peer `@vitejs/plugin-rsc` до `0.5.34`; для транзитивных `esbuild` и `undici` зафиксированы исправленные версии `0.28.1` и `7.29.1`. Выбор подтверждён npm-метаданными и сообщениями разработчиков: [React](https://github.com/react/react/security/advisories/GHSA-wx67-qw84-cm4g), [Vite](https://github.com/vitejs/vite/security/advisories/GHSA-fx2h-pf6j-xcff), [esbuild](https://github.com/evanw/esbuild/security/advisories/GHSA-g7r4-m6w7-qqqr), [undici](https://github.com/nodejs/undici/security/advisories/GHSA-4cwx-7wf7-3272). Версии и overrides находятся в [package.json](../website/package.json) и [package-lock.json](../website/package-lock.json).

После обновления `npm audit --omit=dev` вернул **0 известных находок** вместо 6. Полный `npm audit` вернул **5 high записей** в оставленной dev-цепочке Cloudflare: `ws`, `sharp` и зависимые от них `miniflare`, `wrangler`, `@cloudflare/vite-plugin`. Это пять записей графа, а не пять независимых первопричин. `ws` имеет [раскрытие неинициализированной памяти](https://github.com/websockets/ws/security/advisories/GHSA-58qx-3vcg-4xpx) и [исчерпание памяти](https://github.com/websockets/ws/security/advisories/GHSA-96hv-2xvq-fx4p); `sharp` затронут [уязвимостями libvips](https://github.com/lovell/sharp/security/advisories/GHSA-f88m-g3jw-g9cj). Эти пакеты не используются страницами или текущим Vite-конфигом, но остаются установленными инструментами разработки; их нельзя объявлять исправленными. Обновление всей Cloudflare-цепочки в эту ограниченную правку не вошло.

Статическая сборка, TypeScript `--noEmit` и проверка SEO прошли: русская и английская страницы, sitemap и 44 локальные ссылки на ресурсы. Сгенерированный сайт из этой проверки ещё не опубликован. Нулевой ответ одного режима `npm audit` означает только отсутствие известных ему находок в проверенном графе на эту дату, а не отсутствие всех уязвимостей.

Проверка исходников не охватывает все особенности macOS, Chrome, DNS/прокси, облачных копий и процессов того же пользователя. Проверки кандидата не заменяют проверку будущего опубликованного архива или независимый аудит безопасности.
