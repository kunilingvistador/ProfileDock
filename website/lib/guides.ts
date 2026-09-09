import { workRU, workEN, permissionRU, permissionEN } from "./guides-foundation";
import type { ContentMetadata, SiteLanguage } from "./seo";

export const guideSlugs = ["chrome-profile-shortcuts-mac-dock", "chrome-shortcut-existing-window", "switch-chrome-profiles-keyboard-mac", "separate-work-personal-chrome-profiles-mac", "chrome-automation-permission-mac"] as const;
export type GuideSlug = (typeof guideSlugs)[number];

type GuideSection = {
  id: string;
  title: string;
  paragraphs?: string[];
  steps?: { title: string; body: string }[];
  points?: { title: string; body: string }[];
};
export type Guide = {
  slug: GuideSlug;
  title: string;
  shortTitle: string;
  description: string;
  summary: string;
  category: string;
  takeaway: string;
  sections: GuideSection[];
  sources: { title: string; href: string }[];
};

export const guideCopy = {
  ru: {
    hubTitle: "Профили Chrome на Mac: инструкции для удобного Dock",
    hubDescription: "Профили Chrome на Mac: отдельные значки в Dock, переключение с клавиатуры и восстановление привязки окна. Практические инструкции ProfileDock.",
    heading: "Профили Chrome на Mac:\nDock, хоткеи и помощь.",
    intro: "Разделите работу и личное, выберите удобный способ переключения и разберитесь с разрешениями. Пять практических инструкций — от первого профиля до хоткеев.",
    hub: "Инструкции", home: "Главная", skip: "Перейти к содержанию", nav: "Навигация",
    download: "Скачать для Mac", source: "Код на GitHub", read: "Читать инструкцию", toc: "В этой статье",
    published: "9 сентября 2026", version: "Проверено по ProfileDock 0.1.6 beta", related: "Следующий полезный шаг",
    sources: "Источники и подробности", privacy: "Данные и разрешения", allGuides: "Все инструкции",
    ctaTitle: "Свои окна. Свой Dock.", ctaBody: "Бесплатно, с открытым кодом. Для Google Chrome на macOS 13 и новее.",
    beta: "Бета-сборка без нотариализации Apple. Инструкция установки есть в описании выпуска.",
    feedback: "Не получилось? Опишите проблему на GitHub", feedbackHint: "Укажите версию macOS, Chrome и ProfileDock. Не прикладывайте личные страницы, адреса аккаунтов или несокрытые заголовки окон.",
    figureCaption: "Настоящий интерфейс ProfileDock с демонстрационными ярлыками. Название и картинка помогают узнать выбранное окно.",
    figureAlt: "ProfileDock с тремя демонстрационными ярлыками Studio, Personal и Research и кнопками переключения окон.",
  },
  en: {
    hubTitle: "Chrome Profiles on Mac: Practical Dock Guides",
    hubDescription: "Chrome profiles on Mac: separate Dock icons, keyboard shortcuts, and fixes for lost window connections. Practical ProfileDock setup and troubleshooting guides.",
    heading: "Chrome profiles on Mac:\nDock, hotkeys and help.",
    intro: "Separate work and personal browsing, choose a way to switch, and understand permissions. Five practical guides, from your first profile to hotkeys.",
    hub: "Guides", home: "Home", skip: "Skip to content", nav: "Navigation",
    download: "Download for Mac", source: "Source on GitHub", read: "Read the guide", toc: "In this guide",
    published: "September 9, 2026", version: "Checked against ProfileDock 0.1.6 beta", related: "One useful next step",
    sources: "Sources and further reading", privacy: "Data and permissions", allGuides: "All guides",
    ctaTitle: "Your windows. Your Dock.", ctaBody: "Free and open source. For Google Chrome on macOS 13 or later.",
    beta: "This beta is not notarized by Apple. Read the installation steps in the release notes.",
    feedback: "Still stuck? Describe the problem on GitHub", feedbackHint: "Include your macOS, Chrome, and ProfileDock versions. Do not attach private pages, account addresses, or unredacted window titles.",
    figureCaption: "The real ProfileDock interface with sample shortcuts. A familiar name and picture help identify your chosen window.",
    figureAlt: "ProfileDock showing three sample shortcuts, Studio, Personal, and Research, with window-switching controls.",
  },
} satisfies Record<SiteLanguage, Record<string, string>>;

const setupRU: Guide = {
  slug: "chrome-profile-shortcuts-mac-dock",
  title: "Как добавить профили Chrome отдельными ярлыками в Dock на Mac",
  shortTitle: "Свои профили — отдельными значками в Dock",
  description: "Пошаговая настройка ProfileDock: выберите открытое окно Chrome, добавьте имя и фотографию, закрепите ярлык в Dock. Разрешения, обновления и ограничения.",
  category: "Настройка",
  summary: "Выберите окно, дайте ярлыку имя и картинку, закрепите его в Dock. Подробно — от первого разрешения macOS до обновления приложения.",
  takeaway: "Ярлык ProfileDock возвращает выбранное открытое окно Chrome. Он связан с одним окном, а не автоматически со всеми окнами профиля.",
  sections: [
    { id: "before-you-start", title: "Когда отдельный ярлык действительно удобен", paragraphs: [
      "Если вы весь день держите открытыми рабочую почту, личный профиль и несколько проектов, похожие окна Chrome легко перепутать. Постоянная картинка в Dock помогает возвращаться к одной и той же задаче без поиска в стопке окон.",
      "Начните со встроенных возможностей: кнопка профиля справа вверху Chrome переключает профили; Mission Control показывает открытые окна Mac. Если этого достаточно, дополнительное приложение не требуется. ProfileDock полезен, когда хочется закрепить конкретные рабочие окна отдельными узнаваемыми значками.",
      "В одном профиле может быть несколько окон. Для каждого можно создать свой ярлык. Это не отдельная установка Chrome: окна остаются частью Google Chrome и не становятся самостоятельными приложениями в Command–Tab.",
    ] },
    { id: "install", title: "1. Подготовьте Chrome и установите ProfileDock", paragraphs: [
      "Нужны Google Chrome и macOS 13 или новее. Откройте обычное окно нужного профиля. Инкогнито не подходит для постоянной привязки.",
      "Скачайте ZIP из раздела Releases на GitHub, распакуйте и перенесите ProfileDock в постоянное место, например в «Программы». Версия 0.1.6 — ранняя бета с локальной подписью, без нотариализации Apple. macOS может запросить отдельное подтверждение запуска: следуйте инструкции именно в описании выпуска.",
      "Если macOS не может проверить разработчика, после попытки запуска можно открыть «Системные настройки → Конфиденциальность и безопасность» и подтвердить запуск именно этого приложения кнопкой «Всё равно открыть». Делайте это только для доверенной копии с официальной страницы проекта. Сообщения о вредоносном или повреждённом приложении требуют отдельной проверки; этот шаг не предназначен для их обхода. Инструкция Apple приведена в источниках ниже.",
      "Откройте ProfileDock, нажмите «Подключить Chrome» и разрешите управление Google Chrome в запросе macOS. Приложение работает в строке меню; через его значок можно снова открыть панель настройки.",
    ] },
    { id: "choose-window", title: "2. Выберите окно и проверьте его", steps: [
      { title: "Создайте первый ярлык", body: "Нажмите «Создать первый ярлык». Если ярлыки уже есть, используйте «Добавить». В поле «Открытое окно» выберите нужное окно Chrome." },
      { title: "Покажите окно перед сохранением", body: "Нажмите «Показать окно», проверьте профиль и нужные вкладки в Chrome, затем вернитесь к настройке. Это особенно важно, если два окна имеют одинаковые заголовки." },
      { title: "Дайте понятное имя", body: "Например: «Работа», «Личное», «Проект». Поле «Имя и фото из профиля» необязательно: оно подставляет оформление, но не меняет выбранное окно. Нажмите «Создать ярлык»." },
    ] },
    { id: "make-it-yours", title: "3. Добавьте картинку, которую легко узнать", paragraphs: [
      "В меню ярлыка откройте «Настроить ярлык…». Можно выбрать фотографию или файл изображения. Через «Взять значок сайта…» можно загрузить иконку сайта.",
      "Проверьте картинку в маленьком размере. Крупное лицо, простая форма или контрастный логотип различимее, чем скриншот с мелким текстом. Для нескольких ярлыков выбирайте разные силуэты и цвета, а не только разные подписи.",
      "Загрузка значка обращается к выбранному сайту: он видит IP-адрес и запрошенный URL. Cookies Chrome и данные профиля не передаются. В целях ограничения запросов поддерживаются только HTTPS и загрузки с того же хоста; некоторые сайты хранят значки на другом домене и не подойдут. В этом случае выберите файл изображения.",
    ] },
    { id: "add-to-dock", title: "4. Закрепите ярлык в Dock", steps: [
      { title: "Создайте приложение-ярлык", body: "Нажмите «Создать ярлык для Dock» рядом с настроенным ярлыком. ProfileDock покажет его в Finder." },
      { title: "Перетащите его в Dock", body: "Поместите значок в область приложений Dock, рядом с другими приложениями. Оставьте сам файл ярлыка на его исходном месте: Dock ссылается на него." },
      { title: "Проверьте переключение", body: "Перейдите в другое окно и нажмите новый значок. Привязанное окно Chrome должно выйти на передний план; свёрнутое окно восстановится. Повторите настройку для других постоянных окон." },
    ] },
    { id: "keyboard-shortcuts", title: "Необязательно: добавьте сочетание клавиш", paragraphs: [
      "В карточке ярлыка нажмите «Назначить сочетание», затем поле записи. Нажмите клавишу с минимум двумя модификаторами, включая Command или Control, например ⌥⌘1, и сохраните. Сочетание возвращает то же привязанное окно; при смене имени, картинки или окна оно сохраняется.",
      "ProfileDock должен быть запущен в строке меню. После завершения приложения сочетания перестают действовать до следующего запуска. Общий выключатель находится в дополнительных действиях. Во время настройки сочетания приостановлены. Известные конфликты показываются при записи или сохранении; все команды других приложений заранее обнаружить нельзя."
    ] },
    { id: "everyday-use", title: "Что меняется в повседневной работе", paragraphs: [
      "Команда переключения ищет имя, которое ProfileDock присвоил окну при настройке. Она не создаёт новые вкладки, не выбирает другую вкладку и не меняет размер окна. Профильная картинка — ориентир для вас; сама связь ведёт к выбранному окну.",
      "Если окно закрыли, переименовали или Chrome не восстановил его после перезапуска, выберите «Привязать другое окно…», проверьте новое окно кнопкой «Показать окно» и нажмите «Привязать окно». Существующий значок в Dock можно оставить. Новое окно того же профиля не получает старую связь автоматически.",
      "Полноэкранный режим, Spaces, Stage Manager, несколько мониторов и скрытие Chrome целиком ещё требуют более широких проверок. Бета не гарантирует одинаковое поведение фокуса во всех сочетаниях этих режимов.",
    ] },
    { id: "updates-and-permissions", title: "Обновления и доступ к данным", paragraphs: [
      "Обновления пока ручные: скачайте новый выпуск, завершите ProfileDock, замените приложение и один раз откройте новую копию. Она зарегистрирует своё местоположение и обновит совместимые существующие ярлыки. Имена, картинки и привязки хранятся локально. Если переместили приложение, один раз откройте его из нового места.",
      "ProfileDock не отправляет данные Chrome разработчикам. Локально он читает названия профилей, подписи аккаунтов, которые могут содержать email, аватары, имена и заголовки обычных окон. Содержимое вкладок, историю, пароли и cookies приложение не читает.",
      "Разрешение macOS «Автоматизация» шире переключения окон: отдельного права «только окна» нет. Отозвать его можно в «Системные настройки → Конфиденциальность и безопасность → Автоматизация»; после этого переключение перестанет работать. Само переключение обходится без интернета.",
    ] },
  ],
  sources: [
    { title: "Google: создание и переключение профилей Chrome", href: "https://support.google.com/chrome/answer/2364824?hl=ru" },
    { title: "Apple: безопасное открытие приложений на Mac", href: "https://support.apple.com/ru-ru/102445" },
    { title: "Apple: Mission Control на Mac", href: "https://support.apple.com/ru-ru/guide/mac-help/mh35798/mac" },
    { title: "ProfileDock 0.1.6 beta: выпуск и установка", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
    { title: "ProfileDock: проверка приватности и ограничения", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
  ],
};

const setupEN: Guide = {
  slug: "chrome-profile-shortcuts-mac-dock",
  title: "How to add Chrome profile shortcuts to the Mac Dock",
  shortTitle: "Give each profile a familiar Dock icon",
  description: "Set up ProfileDock step by step: choose an open Chrome window, add a name and photo, and keep its shortcut in the Mac Dock. Permissions, updates, and limits.",
  category: "Setup",
  summary: "Choose a window, give its shortcut a name and picture, and add it to the Dock. From the first macOS permission to your next app update.",
  takeaway: "A ProfileDock shortcut returns to your chosen open Chrome window. It connects to one window, not automatically to every window in a profile.",
  sections: [
    { id: "before-you-start", title: "When a dedicated shortcut helps", paragraphs: [
      "If you keep work email, a personal profile, and several projects open all day, similar Chrome windows can be hard to tell apart. A permanent Dock picture gives you a familiar way back to the same task without searching through a stack of windows.",
      "Start with the built-in options: Chrome’s profile button at the top right switches profiles; Mission Control shows your open Mac windows. If those controls are enough, you do not need another app. ProfileDock helps when you want to pin specific working windows as separate, recognizable icons.",
      "One profile can have several windows, each with its own shortcut. This is not a separate Chrome installation: the windows remain part of Google Chrome and do not become independent Chrome entries in Command–Tab.",
    ] },
    { id: "install", title: "1. Prepare Chrome and install ProfileDock", paragraphs: [
      "You need Google Chrome and macOS 13 or later. Open an ordinary window in the profile you want to reach. Incognito windows cannot become persistent shortcuts.",
      "Download the ZIP from GitHub Releases, unpack it, and put ProfileDock in a stable location such as Applications. Version 0.1.6 is an early, ad-hoc-signed beta without Apple notarization. macOS may require manual approval to open it; follow the instructions in that release’s notes.",
      "For an unidentified-developer warning, after trying to open the app, System Settings → Privacy & Security may offer Open Anyway for that app. Use it only for a trusted copy from the official project. A warning about malware or a damaged app needs separate investigation; these steps are not a way around those warnings. Apple’s instructions are linked below.",
      "Open ProfileDock, click “Connect Chrome,” and allow it to control Google Chrome when macOS asks. ProfileDock runs in the menu bar; use its icon to reopen the setup panel.",
    ] },
    { id: "choose-window", title: "2. Choose and check the window", steps: [
      { title: "Create your first shortcut", body: "Click “Create first shortcut.” If you already have shortcuts, use “Add.” Select the Chrome window you want in the “Open window” picker." },
      { title: "Show it before saving", body: "Click “Show window,” check the profile and tabs in Chrome, then return to setup. This matters especially when two windows share the same title." },
      { title: "Give it a clear name", body: "For example: “Work,” “Personal,” or a project name. “Name and photo from profile” is optional: it supplies appearance information without changing your selected window. Click “Create shortcut.”" },
    ] },
    { id: "make-it-yours", title: "3. Choose a picture you can recognize", paragraphs: [
      "Open “Edit shortcut…” from the shortcut menu. You can choose a photo or image file. “Use a website icon…” lets you download a site’s icon.",
      "Check the picture at a small size. A large face, simple shape, or high-contrast logo is easier to recognize than a screenshot full of tiny text. Give your shortcuts different silhouettes and colors as well as different names.",
      "Fetching an icon contacts the chosen website, which sees your IP address and requested URL. Your Chrome cookies and profile data are not sent. Requests are limited to HTTPS and the same host; sites that keep their icons on another domain may not work. Choose an image file in that case.",
    ] },
    { id: "add-to-dock", title: "4. Keep the shortcut in your Dock", steps: [
      { title: "Create the shortcut app", body: "Click “Create Dock shortcut” next to the shortcut you configured. ProfileDock shows it in Finder." },
      { title: "Drag it into the Dock", body: "Place the icon in the application area of your Dock, beside your other apps. Leave the actual shortcut file in its original location: the Dock refers to that file." },
      { title: "Try switching", body: "Go to another window and click the new icon. Your connected Chrome window should come forward; a minimized window will be restored. Repeat for your other permanent working windows." },
    ] },
    { id: "keyboard-shortcuts", title: "Optional: add a keyboard shortcut", paragraphs: [
      "Click Set hotkey on a shortcut card, then the recording field. Press a key with at least two modifiers including Command or Control, for example Option–Command–1, and save. It returns the same connected window and survives changes to its name, picture or window connection.",
      "ProfileDock must be running in the menu bar. Quitting the app disables its hotkeys until the next launch. More options contains a switch to pause all hotkeys. They are paused while the hotkey editor is open. Known conflicts appear during recording or saving; commands in every other app cannot all be detected in advance."
    ] },
    { id: "everyday-use", title: "What happens in everyday use", paragraphs: [
      "The switching command looks for the name ProfileDock assigned to the window during setup. It does not create tabs, select another tab, or resize the window. The profile picture is a visual cue for you; the connection points to your selected window.",
      "If the window was closed, renamed, or not restored after a Chrome restart, use “Choose another window…,” check the replacement with “Show window,” and click “Link window.” Your existing Dock icon can stay in place. A new window in the same profile does not automatically inherit the old connection.",
      "Fullscreen, Spaces, Stage Manager, multiple monitors, and hiding Chrome as a whole still need broader testing. The beta does not guarantee identical focus behavior in every combination of these modes.",
    ] },
    { id: "updates-and-permissions", title: "Updates and access to your data", paragraphs: [
      "Updates are manual for now: download the new release, quit ProfileDock, replace the app, and open the new copy once. It registers its location and refreshes compatible existing helpers. Names, pictures, and connections stay stored locally. If you move the app, open it from its new location once.",
      "ProfileDock does not send Chrome data to its developers. Locally, it reads profile names, account labels that may contain an email address, avatars, and ordinary-window names or titles. It does not read tab contents, browsing history, passwords, or cookies.",
      "macOS Automation permission is broader than switching windows: there is no separate window-only permission. You can revoke it under System Settings → Privacy & Security → Automation, which stops switching. Window switching itself works without an internet connection.",
    ] },
  ],
  sources: [
    { title: "Google: create and switch Chrome profiles", href: "https://support.google.com/chrome/answer/2364824?hl=en" },
    { title: "Apple: safely open apps on your Mac", href: "https://support.apple.com/en-us/102445" },
    { title: "Apple: Mission Control on Mac", href: "https://support.apple.com/en-us/guide/mac-help/mh35798/mac" },
    { title: "ProfileDock 0.1.6 beta: release and installation", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
    { title: "ProfileDock: privacy review and remaining limits", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
  ],
};

const troubleshootRU: Guide = {
  slug: "chrome-shortcut-existing-window",
  title: "Почему ярлык профиля Chrome не возвращает нужное открытое окно",
  shortTitle: "Почему открывается не то окно — и как это исправить",
  description: "Запуск профиля Chrome и возврат к его открытому окну — разные действия. Разберите причину, проверьте привязку и восстановите ярлык ProfileDock в Dock.",
  category: "Если что-то пошло не так",
  summary: "Профиль, окно и ярлык — не одно и то же. Разберитесь, почему поднимается другое окно и как восстановить связь, сохранив значок в Dock.",
  takeaway: "Запуск правильного профиля ещё не выбирает конкретное окно. Чтобы возвращаться к одной рабочей задаче, ярлыку нужна связь именно с этим окном.",
  sections: [
    { id: "profile-or-window", title: "Профиль и окно — две разные цели", paragraphs: [
      "Представьте: рабочая таблица уже открыта, но после нажатия на ярлык Chrome поверх остальных оказывается другое окно. Важен не только аккаунт, под которым запускается браузер. В одном профиле могут одновременно жить несколько окон, а все профили принадлежат одному приложению Chrome.",
      "Ярлык, который запускает профиль, может решать задачу открытия браузера, но сам по себе не устанавливает связь с вашей таблицей. Общий значок Chrome в Dock тоже представляет приложение целиком. Если нужен просто другой аккаунт, достаточно меню профилей Chrome. Если нужно конкретное уже открытое окно, требуется выбор окна.",
      "ProfileDock связывает отдельный ярлык с существующим обычным окном. Переключение поднимает эту цель; команда не создаёт пустые окна или новые вкладки. Это полезно, когда рабочие окна остаются открытыми весь день.",
    ] },
    { id: "how-binding-works", title: "Что запоминает ProfileDock", paragraphs: [
      "При настройке вы выбираете окно и можете проверить его кнопкой «Показать окно». ProfileDock присваивает ему уникальное имя и сохраняет связь. Следующее нажатие ищет окно по этому имени; свёрнутое окно восстанавливается.",
      "Обычный заголовок вкладки может меняться при переходах между сайтами. Привязка использует отдельное имя окна, а не текст активной страницы. Поэтому переход на другую страницу сам по себе не должен разорвать связь.",
      "Поле «Имя и фото из профиля» подставляет оформление ярлыка. Оно не выбирает окно вместо вас, не проверяет за вас аккаунт в его вкладках и не переключает сразу все окна одного профиля.",
    ] },
    { id: "diagnose", title: "Проверьте симптом", points: [
      { title: "Поднимается другое существующее окно", body: "Возможно, при настройке выбрано другое окно или в Dock остался прежний ярлык запуска Chrome. Сначала откройте менеджер ProfileDock и проверьте цель там. Одинаковые заголовки — повод показать окно перед повторной привязкой." },
      { title: "ProfileDock не находит окно", body: "Окно могли закрыть, переименовать или не восстановить после перезапуска Chrome. Новый экземпляр окна того же профиля не получает старую связь автоматически. Привяжите открытое окно заново." },
      { title: "Появляются пустое окно или новая вкладка", body: "Это не действие команды переключения ProfileDock. Проверьте, что нажимаете созданный им ярлык, а не старый ярлык запуска профиля. Посмотрите расположение файла через контекстное меню значка в Dock и сравните с тем, который показывает ProfileDock." },
      { title: "macOS запрещает управление Chrome", body: "Откройте «Системные настройки → Конфиденциальность и безопасность → Автоматизация» и проверьте разрешение Google Chrome для ProfileDock. Запрос относится к управлению приложением; универсальный доступ, запись экрана и полный доступ к диску не требуются." },
    ] },
    { id: "reconnect", title: "Восстановите связь без перестановки значка в Dock", steps: [
      { title: "Откройте нужное обычное окно Chrome", body: "Перейдите в нужный профиль, убедитесь, что видите правильную задачу. Затем откройте менеджер ProfileDock через его значок в строке меню." },
      { title: "Выберите «Привязать другое окно…»", body: "Откройте меню нужного ярлыка. Выберите окно в списке; если его ещё нет, нажмите «Обновить список окон»." },
      { title: "Проверьте и сохраните", body: "Нажмите «Показать окно», проверьте его в Chrome, вернитесь к настройке и нажмите «Привязать окно». Имя и картинка ярлыка сохранятся." },
      { title: "Попробуйте прежний значок", body: "Перейдите в другое окно и нажмите существующий ярлык в Dock. Если вы случайно использовали старый ярлык запуска Chrome, создайте верный через «Создать ярлык для Dock» и закрепите его." },
    ] },
    { id: "updates", title: "Если это началось после обновления или перемещения приложения", paragraphs: [
      "Убедитесь, что новая копия ProfileDock открывалась хотя бы один раз. Это регистрирует её местоположение для совместимых ярлыков. Ручное обновление: завершить приложение, заменить его новым выпуском и открыть новую копию.",
      "Не удаляйте исходный файл приложения-ярлыка, закреплённого в Dock. Значок Dock ссылается на этот файл; основной ProfileDock и созданные им ярлыки выполняют разные роли.",
      "Обновление ProfileDock не восстанавливает закрытое окно Chrome. Если приложение найдено, но окно отсутствует, исправляется именно привязка. При неоднозначной цели приложение сообщает о проблеме; выбирать произвольное окно как будто переключение удалось оно не должно.",
    ] },
    { id: "limits", title: "Когда нужна дополнительная проверка", paragraphs: [
      "Полноэкранные окна, разные Spaces, Stage Manager, несколько мониторов и скрытый целиком Chrome могут влиять на видимый результат переключения. Эти сочетания требуют более широких проверок; версия 0.1.6 остаётся бетой. Для диагностики сравните поведение того же окна в обычном режиме на текущем рабочем столе.",
      "Если проблема сохраняется, запишите версии macOS, Chrome и ProfileDock, а также состояние окна: обычное, свёрнутое, полноэкранное или на другом рабочем столе. Опишите, какое действие ожидали и что увидели. Не публикуйте реальные заголовки окон, email и содержимое рабочих страниц в отчёте об ошибке.",
      "ProfileDock бесплатен и открыт, работает с Google Chrome на macOS 13+. Он не превращает профили в отдельные приложения в Command–Tab. Бета пока без нотариализации Apple; перед установкой прочитайте примечания к выпуску.",
    ] },
    { id: "privacy", title: "Не путайте разрешение с передачей данных", paragraphs: [
      "Разрешение «Автоматизация» позволяет ProfileDock управлять Chrome локально. Технически оно шире переключения окон, и отдельного права «только окна» в macOS нет.",
      "Эта версия читает локальные имена профилей, подписи аккаунтов, аватары и заголовки обычных окон. Она не читает содержимое вкладок, историю, пароли или cookies и не отправляет данные Chrome разработчикам. Переключение работает без интернета. Необязательная загрузка значка сайта передаёт этому сайту IP-адрес и запрошенный URL; вместо неё можно выбрать файл.",
    ] },
  ],
  sources: [
    { title: "Google: управление профилями Chrome", href: "https://support.google.com/chrome/answer/2364824?hl=ru" },
    { title: "Apple: разрешение приложениям управлять другими приложениями", href: "https://support.apple.com/ru-ru/guide/mac-help/mchl108e1718/mac" },
    { title: "ProfileDock: архитектура привязки окон", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/ARCHITECTURE.md" },
    { title: "ProfileDock: приватность, проверки и ограничения", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
  ],
};

const troubleshootEN: Guide = {
  slug: "chrome-shortcut-existing-window",
  title: "Why a Chrome profile shortcut does not return to the right open window",
  shortTitle: "Why the wrong window appears — and how to fix it",
  description: "Launching a Chrome profile and returning to its open window are different actions. Find the cause, check the connection, and repair your ProfileDock shortcut.",
  category: "Troubleshooting",
  summary: "A profile, a window, and a shortcut are different things. Learn why another window comes forward and how to reconnect without replacing your Dock icon.",
  takeaway: "Launching the correct profile does not select a specific window. To return to the same working task, a shortcut needs a connection to that window.",
  sections: [
    { id: "profile-or-window", title: "A profile and a window are different targets", paragraphs: [
      "Imagine your work spreadsheet is already open, but clicking a Chrome shortcut brings another window to the front. The account used to launch the browser is only part of the story. A single profile can contain several open windows, and all profiles belong to the same Chrome application.",
      "A shortcut that launches a profile may solve the problem of opening the browser, but it does not by itself establish a connection to your spreadsheet. The general Chrome Dock icon also represents the whole app. To switch accounts, start with Chrome’s profile menu. To reach a specific existing window, you need to choose that window.",
      "ProfileDock connects a separate shortcut to an existing ordinary window. Switching brings that target forward; the command does not create blank windows or new tabs. This helps when your working windows stay open all day.",
    ] },
    { id: "how-binding-works", title: "What ProfileDock remembers", paragraphs: [
      "During setup, you select a window and can check it with “Show window.” ProfileDock assigns it a unique name and saves the connection. Your next click looks for that named window; a minimized window is restored.",
      "The ordinary tab title may change when you visit another website. The connection uses a separate window name, rather than the text of the active page. Navigating to another page should therefore not break the connection by itself.",
      "“Name and photo from profile” supplies the shortcut’s appearance. It does not choose a window for you, verify the account inside its tabs, or switch all windows of the same profile at once.",
    ] },
    { id: "diagnose", title: "Start with the symptom", points: [
      { title: "A different existing window comes forward", body: "You may have selected another window during setup, or the Dock may still contain an older Chrome launch shortcut. First check the target inside the ProfileDock manager. Matching titles are a reason to show the window before reconnecting it." },
      { title: "ProfileDock cannot find the window", body: "The window may have been closed, renamed, or not restored after restarting Chrome. A new window in the same profile does not automatically inherit the old connection. Reconnect an open window." },
      { title: "A blank window or a new tab appears", body: "This is not an action performed by ProfileDock’s switching command. Check that you are clicking its generated shortcut, rather than an older profile-launch shortcut. Use the Dock icon’s context menu to inspect its file location and compare it with the file ProfileDock reveals." },
      { title: "macOS denies control of Chrome", body: "Open System Settings → Privacy & Security → Automation and check Google Chrome permission for ProfileDock. This is permission to control an app; Accessibility, Screen Recording, and Full Disk Access are not required." },
    ] },
    { id: "reconnect", title: "Reconnect without rearranging your Dock", steps: [
      { title: "Open the right ordinary Chrome window", body: "Go to the correct profile and check that the intended task is visible. Then open the ProfileDock manager from its menu-bar icon." },
      { title: "Choose “Choose another window…”", body: "Open the menu for the shortcut you want to repair. Select the window from the list; if it is missing, click “Refresh windows.”" },
      { title: "Check and save", body: "Click “Show window,” check it in Chrome, return to setup, and click “Link window.” The shortcut keeps its name and picture." },
      { title: "Try the existing icon", body: "Go to another window and click your existing Dock shortcut. If you were accidentally using an older Chrome launch shortcut, use “Create Dock shortcut” to create the correct one and pin it." },
    ] },
    { id: "updates", title: "If it started after updating or moving the app", paragraphs: [
      "Make sure the new copy of ProfileDock has been opened at least once. That registers its location for compatible shortcuts. A manual update means quitting the app, replacing it with the new release, and opening the new copy.",
      "Do not delete the original helper app that you pinned to the Dock. The Dock icon refers to that file; the main ProfileDock app and the shortcuts it creates serve different roles.",
      "Updating ProfileDock cannot restore a closed Chrome window. If the app is found but the window is missing, repair the window connection. An ambiguous target is reported as a problem; the app should not choose an arbitrary window and treat that as a successful switch.",
    ] },
    { id: "limits", title: "When further testing is needed", paragraphs: [
      "Fullscreen windows, separate Spaces, Stage Manager, multiple monitors, and hiding Chrome as a whole can affect the visible result. Those combinations need broader testing; version 0.1.6 remains a beta. To diagnose a problem, compare the same window in ordinary mode on the current desktop.",
      "If the problem continues, record your macOS, Chrome, and ProfileDock versions and the window’s state: ordinary, minimized, fullscreen, or on another desktop. Describe what you expected and what appeared. Do not publish real window titles, email addresses, or the contents of work pages in a bug report.",
      "ProfileDock is free and open source, for Google Chrome on macOS 13 or later. It does not turn profiles into independent apps in Command–Tab. The beta is not yet notarized by Apple; read the release notes before installing.",
    ] },
    { id: "privacy", title: "Permission is different from sending data", paragraphs: [
      "Automation permission lets ProfileDock control Chrome locally. It is technically broader than switching windows, and macOS has no separate window-only permission.",
      "This version reads local profile names, account labels, avatars, and ordinary-window titles. It does not read tab contents, history, passwords, or cookies, and does not send Chrome data to its developers. Switching works offline. The optional site-icon downloader exposes your IP address and requested URL to that website; you can choose an image file instead.",
    ] },
  ],
  sources: [
    { title: "Google: manage Chrome profiles", href: "https://support.google.com/chrome/answer/2364824?hl=en" },
    { title: "Apple: allow apps to control other apps", href: "https://support.apple.com/en-us/guide/mac-help/mchl108e1718/mac" },
    { title: "ProfileDock: window-connection architecture", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/ARCHITECTURE.md" },
    { title: "ProfileDock: privacy, checks, and remaining limits", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
  ],
};

const hotkeysRU: Guide = {
  slug: "switch-chrome-profiles-keyboard-mac",
  title: "Как переключать профили Chrome на Mac с клавиатуры",
  shortTitle: "Нужное окно Chrome — сочетанием клавиш",
  description: "Назначьте хоткей открытому окну профиля Chrome на Mac. Настройка ProfileDock, встроенное меню профилей, занятые сочетания и работа после перезапуска.",
  category: "Сочетания клавиш",
  summary: "Рабочая почта, личный профиль и проекты могут открываться поверх других окон по своим сочетаниям. Разберём встроенный способ Chrome и настройку прямого перехода через ProfileDock.",
  takeaway: "Для прямого перехода сохраните нужное окно в ProfileDock и назначьте ему, например, Option + Command + 1. Сочетание работает из других приложений, пока ProfileDock запущен.",
  sections: [
    { id: "built-in", title: "Что уже умеет Chrome без дополнительного приложения", paragraphs: [
      "В Chrome на Mac сочетание Command + Shift + M открывает доступ к меню профиля. Оттуда можно выбрать другого пользователя. Это встроенный способ, с которого удобно начать, если переключаться приходится редко.",
      "Для постоянных переходов к одному выбранному окну можно назначить отдельное сочетание в ProfileDock. Например, одно — рабочей почте, другое — личному окну. Это особенно полезно, когда окна нескольких профилей уже открыты и лежат друг за другом.",
      "Профиль и окно — разные вещи. В одном профиле Chrome может быть несколько окон. ProfileDock связывает сочетание с сохранённым ярлыком конкретного окна; оно не поднимает автоматически все окна этого профиля и не создаёт отдельное приложение Chrome.",
    ] },
    { id: "assign", title: "Как назначить горячую клавишу окну", steps: [
      { title: "Подготовьте ярлык", body: "Установите ProfileDock 0.1.6 beta или новее, подключите Chrome и сохраните нужное обычное окно. Если ярлык уже есть, создавать его заново не нужно. Проверьте выбранное окно кнопкой переключения на карточке." },
      { title: "Запишите сочетание", body: "На карточке нажмите «Назначить сочетание», затем поле записи. Нажмите клавишу вместе как минимум с двумя модификаторами, включая Command или Control. Например, Option + Command + 1. Option на некоторых клавиатурах подписан Alt." },
      { title: "Сохраните и проверьте", body: "Нажмите «Сохранить», перейдите в другое приложение и нажмите выбранное сочетание на клавиатуре. Должно появиться связанное окно Chrome. Для следующего ярлыка выберите другую комбинацию, например Option + Command + 2." },
    ] },
    { id: "choose", title: "Какие сочетания выбрать", paragraphs: [
      "Начните с одного или двух часто используемых окон. Цифры с одинаковыми модификаторами проще запомнить, чем разные комбинации для каждого проекта. Примеры здесь не назначаются автоматически и могут оказаться заняты в вашей системе.",
      "Поддерживаются буквы, цифры, обычные знаки пунктуации, пробел и стрелки. Fn, мультимедийные клавиши, Tab, Escape и комбинации только из модификаторов не подходят. Escape завершает запись, а Tab переводит фокус к следующему элементу настройки.",
      "При смене раскладки привязка остаётся на той же физической клавише, а отображаемый символ меняется. Для начала цифра часто понятнее буквы: проверьте результат на тех раскладках, которыми действительно пользуетесь.",
    ] },
    { id: "not-working", title: "Если хоткей не срабатывает", points: [
      { title: "ProfileDock завершён", body: "Откройте приложение снова. Закрытие окна настройки оставляет хоткеи активными, а команда «Завершить ProfileDock» отключает их. В версии 0.1.6 автоматический запуск при входе в macOS не добавлен." },
      { title: "Открыто окно записи или сочетания отключены", body: "На время редактирования приложение приостанавливает свои хоткеи. Сохраните изменения или нажмите «Отмена». В дополнительных действиях проверьте, включены ли сочетания клавиш." },
      { title: "Комбинация занята", body: "ProfileDock сообщает о повторе внутри приложения, известных системных сочетаниях и отказе macOS зарегистрировать хоткей. Выберите другой вариант или повторите регистрацию через дополнительные действия. Обнаружить все команды всех сторонних приложений невозможно." },
      { title: "Целевое окно закрыто", body: "Хоткей использует ту же привязку, что и ярлык в Dock. Откройте нужное окно Chrome и выберите «Привязать другое окно…» в меню ярлыка. Пустое окно взамен закрытого автоматически не создаётся." },
    ] },
    { id: "keep-settings", title: "Что происходит после обновления и переименования", paragraphs: [
      "Сочетание хранится локально у сохранённого ярлыка. Переименование, новая фотография и перепривязка окна его не сбрасывают. При перезапуске ProfileDock перечитывает назначения; занятое другим приложением сочетание может потребовать замены или повторной регистрации.",
      "Удалить комбинацию можно в её настройке: выберите удаление сочетания и сохраните. Сам ярлык в Dock продолжит работать. Удаление всего ярлыка убирает и его назначение.",
    ] },
    { id: "privacy-and-checks", title: "Разрешения и проверенные сценарии", paragraphs: [
      "ProfileDock регистрирует выбранные комбинации в macOS. Поле записи обрабатывает нажатия внутри своего окна настройки; приложение не записывает глобальный поток вводимого текста. Для управления окном Chrome остаётся прежнее разрешение Automation.",
      "Для версии 0.1.6 на одном Mac проверили физическое нажатие из другого приложения, сохранение после перезапуска и восстановление свёрнутого тестового окна. Это не проверка всех клавиатур, Spaces, полноэкранных режимов или Secure Input. Если поведение отличается, опишите шаги и версии программ в GitHub, скрыв личные данные.",
    ] },
  ],
  sources: [
    { title: "Google: сочетания клавиш Chrome для Mac", href: "https://support.google.com/chrome/answer/157179?hl=ru" },
    { title: "ProfileDock: настройка, ограничения и хранение хоткеев", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/HOTKEYS.md" },
    { title: "ProfileDock 0.1.6: результаты проверок и скачивание", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};

const hotkeysEN: Guide = {
  slug: "switch-chrome-profiles-keyboard-mac",
  title: "Switch Chrome Profiles on Mac with Keyboard Shortcuts",
  shortTitle: "A keyboard shortcut for your chosen Chrome window",
  description: "Assign a hotkey to an existing Chrome profile window on Mac. ProfileDock setup, Chrome’s built-in profile menu, shortcut conflicts and restart behaviour.",
  category: "Keyboard shortcuts",
  summary: "Give your work, personal and project windows their own key combinations. Start with Chrome’s built-in profile menu, then set up direct window switching with ProfileDock.",
  takeaway: "Save your chosen window in ProfileDock and assign a combination such as Option + Command + 1. It works from other apps while ProfileDock is running.",
  sections: [
    { id: "built-in", title: "Start with Chrome’s built-in profile menu", paragraphs: [
      "In Chrome on Mac, Command + Shift + M gives you access to the profile menu, where you can choose another user. Try this built-in route first if you only switch occasionally.",
      "For repeated trips to a particular open window, ProfileDock lets you assign a dedicated combination. One can bring forward your work mail, another your personal window. This is useful when several profile windows are already open behind each other.",
      "A profile can contain multiple windows. ProfileDock connects a hotkey to the saved shortcut for one chosen window. It does not automatically bring forward every window in that profile or turn Chrome into separate applications.",
    ] },
    { id: "assign", title: "Assign a hotkey to an existing window", steps: [
      { title: "Prepare a saved shortcut", body: "Install ProfileDock 0.1.6 beta or later, connect Chrome and save the ordinary window you want. If its shortcut already exists, keep it. Use the switch button on the card to check that it selects the right window." },
      { title: "Record a combination", body: "Click Set hotkey on the card, then click the recording field. Press a supported key with at least two modifiers, including Command or Control. Option + Command + 1 is one example. Some keyboards label Option as Alt." },
      { title: "Save and try it", body: "Save, switch to another app, and press the combination on your physical keyboard. The connected Chrome window should come forward. Choose a different combination for the next shortcut, such as Option + Command + 2." },
    ] },
    { id: "choose", title: "Choose combinations you can remember", paragraphs: [
      "Begin with one or two windows you use frequently. Number keys with the same modifiers can be easier to remember than a different pattern for every project. The examples here are not assigned automatically and may already be in use on your Mac.",
      "Supported keys include letters, digits, ordinary punctuation, Space and arrows. Fn, media keys, Tab, Escape and modifier-only combinations are not assignable. Escape ends recording; Tab moves focus through the editor.",
      "Changing keyboard layout keeps the same physical key assigned while the displayed character changes. A number can be a clearer starting point than a letter. Check the result with the layouts you actually use.",
    ] },
    { id: "not-working", title: "If the keyboard shortcut does not work", points: [
      { title: "ProfileDock has quit", body: "Launch it again. Closing the manager window keeps hotkeys active; Quit ProfileDock stops them. Version 0.1.6 does not automatically launch at login." },
      { title: "The recorder is open or hotkeys are paused", body: "ProfileDock pauses its hotkeys during editing. Save or cancel the editor. In More options, check that keyboard shortcuts are enabled." },
      { title: "The combination is in use", body: "ProfileDock reports duplicates, exposed system shortcuts and macOS registration failures. Choose another combination or retry registration from More options. No conflict check can discover every shortcut mechanism used by every other app." },
      { title: "The target window was closed", body: "Hotkeys use the same connection as Dock shortcuts. Open your intended Chrome window and choose Reconnect window from the shortcut menu. A missing target does not automatically create a blank replacement window." },
    ] },
    { id: "keep-settings", title: "Keep assignments through updates and renaming", paragraphs: [
      "The combination is saved locally against the shortcut. Renaming it, changing its photo or reconnecting its window keeps the assignment. ProfileDock reloads assignments when it launches; a combination taken by another app may need a different key or a registration retry.",
      "To remove a combination, open its editor, choose Remove hotkey and save. Its Dock shortcut continues to work. Removing the whole saved shortcut also removes its assignment.",
    ] },
    { id: "privacy-and-checks", title: "Permissions and tested behaviour", paragraphs: [
      "ProfileDock registers the chosen combinations with macOS. The recorder handles keys inside its own focused editor; the app does not record a global stream of typed text. Window switching still uses the existing Chrome Automation permission.",
      "For version 0.1.6, testing on one Mac covered a physical keypress from another app, persistence after restarting ProfileDock, and restoring a minimized test window. This does not establish behaviour on every keyboard, Space, full-screen setup or Secure Input session. If your result differs, report the steps and app versions on GitHub without private account details or window contents.",
    ] },
  ],
  sources: [
    { title: "Google: Chrome keyboard shortcuts for Mac", href: "https://support.google.com/chrome/answer/157179?hl=en" },
    { title: "ProfileDock: hotkey settings, storage and limitations", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/HOTKEYS.md" },
    { title: "ProfileDock 0.1.6: validation results and download", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};

export const guides: Record<SiteLanguage, Record<GuideSlug, Guide>> = {
  ru: { "chrome-profile-shortcuts-mac-dock": setupRU, "chrome-shortcut-existing-window": troubleshootRU, "switch-chrome-profiles-keyboard-mac": hotkeysRU, "separate-work-personal-chrome-profiles-mac": workRU, "chrome-automation-permission-mac": permissionRU },
  en: { "chrome-profile-shortcuts-mac-dock": setupEN, "chrome-shortcut-existing-window": troubleshootEN, "switch-chrome-profiles-keyboard-mac": hotkeysEN, "separate-work-personal-chrome-profiles-mac": workEN, "chrome-automation-permission-mac": permissionEN },
};

export function guideMetadata(language: SiteLanguage, slug?: GuideSlug): ContentMetadata {
  if (!slug) return { title: `${guideCopy[language].hubTitle} | ProfileDock`, description: guideCopy[language].hubDescription, path: "guides/" };
  const guide = guides[language][slug];
  return { title: `${guide.title} | ProfileDock`, description: guide.description, path: `guides/${slug}/`, article: true };
}

export function guidePath(language: SiteLanguage, slug?: GuideSlug): string {
  return `/ProfileDock/${language === "en" ? "en/" : ""}guides/${slug ? `${slug}/` : ""}`;
}
