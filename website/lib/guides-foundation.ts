import type { Guide } from "./guides";

export const workRU: Guide = {
  slug: "separate-work-personal-chrome-profiles-mac",
  title: "Как разделить рабочий и личный Chrome на Mac",
  shortTitle: "Работа и личное — в разных профилях",
  description: "Как настроить рабочий и личный профили Chrome на Mac, не путать аккаунты и возвращаться к нужному окну через меню, Dock или сочетание клавиш.",
  category: "Организация",
  summary: "Два узнаваемых профиля, понятные названия и один способ переключения. Начните со встроенного Chrome; отдельные значки и хоткеи добавляйте по необходимости.",
  takeaway: "Профиль разделяет данные браузера, окно показывает текущую задачу, а ярлык ProfileDock возвращает одно выбранное окно. Эти три вещи связаны, но не заменяют друг друга.",
  sections: [
    { id: "profile-or-account", title: "Профиль, аккаунт и окно: в чём разница", paragraphs: [
      "Допустим, в одном окне открыты личная почта и покупки, а в другом — рабочие документы. Если оба окна принадлежат одному профилю Chrome, само наличие двух окон ещё не разделяет их браузерные данные. Новая вкладка тоже не создаёт отдельный профиль.",
      "Профили Chrome хранят свои закладки, историю, пароли и настройки отдельно. Аккаунт Google — это учётная запись: переключение аккаунта внутри сайта не равнозначно переключению профиля браузера. Синхронизация с аккаунтом — отдельная настройка Chrome.",
      "Для начала достаточно двух профилей: «Работа» и «Личное». Профиль на каждый сайт обычно усложняет выбор. Создавайте третий, когда появляется самостоятельный контекст: например, другой проект с отдельными входами и закладками.",
    ] },
    { id: "set-up", title: "Настройте два профиля и проверьте результат", steps: [
      { title: "Сохраните привычный профиль", body: "Оставьте текущий профиль для того контекста, в котором уже используете его чаще всего. Не удаляйте старые профили ради аккуратности: для начала это не требуется." },
      { title: "Добавьте второй", body: "В меню профиля Chrome справа вверху выберите добавление профиля. Задайте короткое имя и отличающийся цвет. Вход в Chrome не обязателен; решение о сохранении данных в аккаунте примите отдельно." },
      { title: "Откройте по одной знакомой странице", body: "Например, личную почту в одном профиле и рабочий календарь в другом. На каждом сайте проверьте, в какой аккаунт выполнен вход. Не ориентируйтесь только на похожие аватары." },
      { title: "Сделайте контрольное переключение", body: "Перейдите между профилями несколько раз. Проверьте имя в меню Chrome, нужный аккаунт на сайте и набор вкладок. Только после этого закрепляйте повседневный способ переключения." },
    ] },
    { id: "recognize", title: "Сделайте окна узнаваемыми с первого взгляда", paragraphs: [
      "Назовите контексты так, как думаете о них в течение дня: «Работа», «Дом», «Клиент». Длинный email трудно быстро прочитать в меню, а одинаковые портреты легко перепутать. Сочетание короткого имени и различимого изображения даёт два независимых ориентира.",
      "Для рабочего значка можно использовать простой символ проекта, для личного — фотографию. Проверьте их в обычном размере Dock, а не только крупно в редакторе. Если различие держится исключительно на оттенке, добавьте разную форму: это помогает и при слабом зрении, и на маленьком экране.",
      "Перед отправкой сообщения или правкой рабочего документа всё равно проверяйте аккаунт на самом сайте. Оформление помогает ориентироваться, но не подтверждает личность отправителя.",
    ] },
    { id: "choose-switching", title: "Выберите один удобный способ переключения", points: [
      { title: "Меню Chrome — для редких переключений", body: "Начните с кнопки профиля в браузере. Это встроенный способ, для которого не нужно устанавливать ProfileDock или выдавать ему разрешения." },
      { title: "Отдельные значки Dock — для постоянно открытых окон", body: "Если оба окна весь день находятся друг за другом, сохраните каждое в ProfileDock, проверьте кнопкой «Показать окно», затем создайте ярлыки для Dock. Каждый ярлык поднимает выбранное окно, а не все окна профиля." },
      { title: "Хоткеи — для частых переходов из других приложений", body: "Назначьте двум сохранённым ярлыкам разные сочетания, например Option + Command + 1 и Option + Command + 2, если они свободны. Начните с двух комбинаций; ProfileDock должен оставаться запущенным." },
    ] },
    { id: "daily-check", title: "Что проверить на следующий день", paragraphs: [
      "После обычного рабочего дня станет понятно, хватает ли двух окон. Не создавайте дубликаты ярлыков только потому, что открылась ещё одна вкладка. Если в рабочем профиле нужны два самостоятельных окна, назовите их по задачам — например, «Работа · почта» и «Работа · документы».",
      "Если связанное окно закрыли и ярлык больше его не находит, откройте нужное окно Chrome и выберите «Переподключить окно» в меню ярлыка. В ProfileDock 0.1.6 такой ярлык не создаёт пустое окно автоматически. Имя, картинку и хоткей можно сохранить при переподключении.",
      "Профили удобны для порядка, но не защищают данные от другого человека, который пользуется той же учётной записью Mac: он может переключить профиль. Для совместного компьютера рассмотрите отдельные учётные записи macOS. На рабочем Mac сначала проверьте правила вашей организации.",
    ] },
  ],
  sources: [
    { title: "Google: создание и использование профилей Chrome", href: "https://support.google.com/chrome/answer/2364824?hl=ru" },
    { title: "Google: сохранение информации Chrome в аккаунте", href: "https://support.google.com/chrome/answer/165139?hl=ru" },
    { title: "ProfileDock: настройка хоткеев и ограничения", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/HOTKEYS.md" },
  ],
};

export const workEN: Guide = {
  slug: "separate-work-personal-chrome-profiles-mac",
  title: "Separate Work and Personal Chrome Profiles on Mac",
  shortTitle: "Keep work and personal browsing separate",
  description: "Set up work and personal Chrome profiles on Mac, recognize the right account, and choose between Chrome’s menu, separate Dock shortcuts and hotkeys.",
  category: "Organization",
  summary: "Two recognizable profiles, clear names and one reliable way to switch. Start with Chrome’s own controls, then add Dock shortcuts or hotkeys when they help.",
  takeaway: "A profile separates browser data, a window holds your current task, and a ProfileDock shortcut returns to one chosen window. They are connected, but serve different purposes.",
  sections: [
    { id: "profile-or-account", title: "A profile, an account and a window are different", paragraphs: [
      "Imagine personal mail and shopping in one window, with work documents in another. If both windows belong to the same Chrome profile, having two windows does not separate their browser data. Opening another tab does not create a profile either.",
      "Chrome profiles keep their own bookmarks, history, passwords and settings. A Google account is a login: changing accounts inside a website is different from switching browser profiles. Saving browser information to an account is a separate Chrome setting.",
      "Start with two profiles called Work and Personal. A profile for every website can make the choice harder. Add a third when you have a distinct context, such as another project with its own logins and bookmarks.",
    ] },
    { id: "set-up", title: "Set up two profiles and check the result", steps: [
      { title: "Keep your familiar profile", body: "Use your existing profile for the context it already serves most often. There is no need to delete old profiles just to begin organizing your browser." },
      { title: "Add a second profile", body: "Open Chrome’s profile menu at the top right and choose to add a profile. Give it a short name and a different color. Signing into Chrome is optional; decide separately whether to save information to an account." },
      { title: "Open one familiar page in each", body: "Try personal mail in one and a work calendar in the other. Check the signed-in account on each website. Similar account pictures are easy to confuse." },
      { title: "Try switching before you save shortcuts", body: "Move between the profiles a few times. Check the name in Chrome’s menu, the account on the website and the tabs you expect. Then choose your everyday switching method." },
    ] },
    { id: "recognize", title: "Make the windows recognizable at a glance", paragraphs: [
      "Name each context the way you think about it during the day: Work, Home or Client. A long email address is hard to scan in a menu, and matching portraits are easy to confuse. A short name and a distinctive image give you two independent cues.",
      "Try a simple project symbol for work and a photo for personal browsing. Check them at your normal Dock size, rather than only in a large editor preview. If the difference depends entirely on color, use different shapes as well; this also helps on small screens and with reduced vision.",
      "Before sending a message or editing a work document, still check the account on the website itself. A familiar icon helps you navigate but does not establish who you are signed in as.",
    ] },
    { id: "choose-switching", title: "Choose one comfortable way to switch", points: [
      { title: "Chrome’s menu for occasional switching", body: "Start with the browser’s profile button. It is built in and does not require installing ProfileDock or granting it any permissions." },
      { title: "Separate Dock icons for windows you keep open", body: "If both windows spend the day behind each other, save each in ProfileDock, verify the target with Show window, and create Dock shortcuts. Each shortcut raises its chosen window, not every window in the profile." },
      { title: "Hotkeys for frequent trips from other apps", body: "Assign different combinations to the saved shortcuts, such as Option + Command + 1 and Option + Command + 2 if available. Start with two combinations. ProfileDock must remain running." },
    ] },
    { id: "daily-check", title: "Check your setup after a normal working day", paragraphs: [
      "A day of ordinary use will show whether two windows are enough. Do not duplicate a shortcut just because you opened another tab. If your work profile needs two independent windows, name them by task: Work · Mail and Work · Documents, for example.",
      "If you close the connected window and its shortcut can no longer find it, open the intended Chrome window and use Reconnect window in the shortcut menu. ProfileDock 0.1.6 does not automatically create a blank replacement. Reconnecting can keep the shortcut’s name, image and hotkey.",
      "Profiles help with organization, but do not protect your browsing from another person using the same Mac login: they can switch profiles. Consider separate macOS user accounts for a shared computer. On a work-managed Mac, check your organization’s rules first.",
    ] },
  ],
  sources: [
    { title: "Google: create and use Chrome profiles", href: "https://support.google.com/chrome/answer/2364824?hl=en" },
    { title: "Google: save Chrome information to your account", href: "https://support.google.com/chrome/answer/165139?hl=en" },
    { title: "ProfileDock: hotkey setup and limitations", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/HOTKEYS.md" },
  ],
};

export const permissionRU: Guide = {
  slug: "chrome-automation-permission-mac",
  title: "Разрешение на управление Google Chrome на Mac: зачем оно ProfileDock",
  shortTitle: "Что означает «управлять Google Chrome»",
  description: "Что разрешает Automation на Mac, зачем ProfileDock управляет Chrome, какие данные читает приложение и как отключить разрешение в настройках macOS.",
  category: "Разрешения",
  summary: "Разберитесь с запросом macOS до первого переключения. Что разрешает система, что делает текущий код ProfileDock и где можно отозвать доступ.",
  takeaway: "Разрешение Automation шире команды «поднять окно». ProfileDock использует его для работы с окнами, но macOS не ограничивает выданный доступ только этой операцией.",
  sections: [
    { id: "why-prompt", title: "Почему появляется этот запрос", paragraphs: [
      "ProfileDock должен обратиться к Chrome, чтобы показать список окон, связать ярлык с выбранным окном и затем вернуть его поверх других. Такое взаимодействие между приложениями macOS контролирует через разрешение Automation — «Автоматизация».",
      "Запрос при подключении Chrome относится к приложению, которое хочет им управлять. Это не вход в Google, не установка расширения и не передача разработчику вашего аккаунта. Перед подтверждением проверьте название запрашивающего приложения и источник скачанной сборки.",
      "Отказ не удаляет профили и вкладки Chrome. Однако ProfileDock не сможет выполнять переключение окон, пока соответствующее разрешение выключено. Вы можете принять решение позже в настройках macOS.",
    ] },
    { id: "reads", title: "Какие данные использует ProfileDock", points: [
      { title: "Окна Chrome", body: "Приложение получает идентификаторы, имена и заголовки обычных окон, чтобы вы могли выбрать нужное. Оно задаёт имя привязки, меняет состояние сворачивания и поднимает выбранное окно. Заголовок может содержать личную информацию, например название документа." },
      { title: "Локальные сведения о профилях", body: "Названия, подписи аккаунтов — часто email — и фотографии помогают оформить ярлык. Они читаются из файлов Chrome отдельно от Automation. Отключение Automation само по себе не запрещает такое чтение файлов." },
      { title: "Настройки ярлыков", body: "Имена, изображения, привязки и назначенные сочетания сохраняются на вашем Mac. ProfileDock не шифрует их собственным отдельным паролем; ваши резервные копии и выбранные синхронизируемые папки могут включать эти файлы." },
    ] },
    { id: "does-not-read", title: "Чего нет в проверенном коде", paragraphs: [
      "В коде управления Chrome нет чтения содержимого страниц, паролей, cookies, истории или адресов вкладок; он не запускает JavaScript внутри страниц. В приложении для Mac нет аналитики, аккаунта ProfileDock, сервера для загрузки данных Chrome или автоматической отправки отчётов разработчикам.",
      "Это описание реализованного поведения, а не утверждение, что macOS технически запрещает приложению получить любые другие данные. ProfileDock не изолирован App Sandbox, а разрешение Automation само по себе не является разрешением исключительно на фокус окна. Исходники и подробный разбор доступны по ссылкам ниже.",
      "Хоткеи регистрируют выбранные сочетания. ProfileDock не записывает весь ввод с клавиатуры; поле настройки принимает нажатия внутри своего активного редактора. Для этой функции не добавлялся глобальный перехват набираемого текста.",
    ] },
    { id: "network", title: "Когда всё-таки происходит сетевой запрос", paragraphs: [
      "Обычное переключение окна работает локально. Если вы сами выбираете «Взять значок сайта…», приложение обращается к указанному HTTPS-сайту за значком. Сайт видит запрос и IP-адрес; cookies и содержимое профиля Chrome с этим запросом не передаются. Можно выбрать картинку из файла и не использовать загрузку значка.",
      "Сайт ProfileDock — отдельная среда: на нём есть Google Analytics и настройка отключения в разделе «Аналитика этого сайта». Это не аналитика приложения для Mac и не доступ сайта к вашим профилям Chrome. Переходы на GitHub также являются обращениями к внешнему сайту.",
    ] },
    { id: "revoke", title: "Как проверить или отключить разрешение", steps: [
      { title: "Откройте настройки macOS", body: "Перейдите в «Системные настройки → Конфиденциальность и безопасность → Автоматизация». Найдите ProfileDock и вложенный переключатель Google Chrome." },
      { title: "Измените разрешение", body: "Выключите доступ, если не хотите разрешать управление окнами, или включите его, если ранее отказали и теперь хотите пользоваться переключением. Названия пунктов могут различаться в зависимости от языка macOS." },
      { title: "Проверьте результат", body: "Вернитесь в ProfileDock и попробуйте показать выбранное окно. При выключенном разрешении управление работать не должно. Если приложения ещё нет в списке, сначала запустите его и попробуйте подключить Chrome, чтобы macOS обработала запрос." },
    ] },
    { id: "trust", title: "На что ориентироваться перед установкой", paragraphs: [
      "Скачивайте сборку со страницы Releases официального репозитория и сверяйте версию с её описанием. ProfileDock 0.1.6 beta пока не имеет нотариализации Apple. Открытый код и опубликованные результаты тестов помогают проверке, но не заменяют независимый аудит безопасности.",
      "Если сообщаете о проблеме, достаточно описать действие, ошибку и версии macOS, Chrome и ProfileDock. Сначала скройте личные заголовки, имена аккаунтов и содержимое страниц на снимке экрана. Для разбора переключения не нужны пароль, cookies или полная папка профиля.",
    ] },
  ],
  sources: [
    { title: "Apple: управление доступом приложений к другим приложениям", href: "https://support.apple.com/ru-ru/guide/mac-help/mchl108e1718/mac" },
    { title: "ProfileDock: подробный разбор данных, сети и границ разрешений", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
    { title: "ProfileDock: исходный код управления окнами Chrome", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/Sources/ProfileDock/ChromeService.swift" },
    { title: "ProfileDock 0.1.6 beta: официальная сборка", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};

export const permissionEN: Guide = {
  slug: "chrome-automation-permission-mac",
  title: "Allow Control of Google Chrome on Mac: ProfileDock Permissions Explained",
  shortTitle: "What “control Google Chrome” means",
  description: "Understand the macOS Automation prompt, why ProfileDock controls Chrome windows, what data the app reads, and how to revoke access in System Settings.",
  category: "Permissions",
  summary: "Understand the macOS prompt before your first switch: what the system permits, what ProfileDock’s current code does, and where to turn access off.",
  takeaway: "Automation permission is broader than “bring a window forward.” ProfileDock uses it for window operations, but macOS does not restrict the grant to that one action.",
  sections: [
    { id: "why-prompt", title: "Why the prompt appears", paragraphs: [
      "ProfileDock needs to ask Chrome for its windows, connect a shortcut to your chosen window, and later bring that window forward. macOS controls this interaction between applications through Automation permission.",
      "The prompt when connecting Chrome refers to the app asking to control it. It is not a Google login, an extension installation or a transfer of your account to the developer. Before accepting, check the requesting app’s name and where you obtained your copy.",
      "Declining does not delete Chrome profiles or tabs. However, ProfileDock cannot switch windows while its relevant permission is disabled. You can change your decision later in macOS settings.",
    ] },
    { id: "reads", title: "What data ProfileDock uses", points: [
      { title: "Chrome windows", body: "The app obtains identifiers, names and titles of ordinary windows so you can choose a target. It sets a connection name, changes minimized state and brings the chosen window forward. A window title can contain personal information, such as a document name." },
      { title: "Local profile information", body: "Names, account labels — often email addresses — and photos help you customize a shortcut. They are read from Chrome files separately from Automation. Revoking Automation alone does not block these file reads." },
      { title: "Shortcut settings", body: "Names, images, connections and assigned combinations stay on your Mac. ProfileDock does not encrypt them with a separate app password; your own backups and chosen synced folders may include these files." },
    ] },
    { id: "does-not-read", title: "What the reviewed code does not do", paragraphs: [
      "The Chrome automation code does not read page contents, passwords, cookies, history or tab URLs, and does not execute JavaScript inside pages. The Mac app has no analytics, ProfileDock account, server for uploading Chrome data or automatic reporting to the developers.",
      "This describes implemented behavior, rather than claiming that macOS technically prevents access to every other kind of data. ProfileDock is not App Sandbox confined, and Automation is not a focus-only permission. Source code and a detailed review are linked below.",
      "Hotkeys register the combinations you choose. ProfileDock does not record everything you type; the recording field handles keys within its own focused editor. This feature did not add a global typed-text monitor.",
    ] },
    { id: "network", title: "When a network request does happen", paragraphs: [
      "Ordinary window switching works locally. If you choose Get website icon, the app contacts the HTTPS website you supply to obtain an icon. The site sees a request and your IP address; Chrome cookies and profile contents do not accompany it. You can choose an image file instead of fetching a website icon.",
      "The ProfileDock website is a separate environment: it uses Google Analytics and offers an off switch in Website analytics. This is not analytics inside the Mac app and does not give the website access to your Chrome profiles. Opening GitHub also contacts an external website.",
    ] },
    { id: "revoke", title: "Check or revoke the permission", steps: [
      { title: "Open macOS settings", body: "Go to System Settings → Privacy & Security → Automation. Find ProfileDock and its nested Google Chrome switch." },
      { title: "Change the permission", body: "Turn access off if you do not want to allow window control, or on if you declined earlier and now want to use switching. Labels may vary with your macOS language." },
      { title: "Check the result", body: "Return to ProfileDock and try showing the chosen window. With permission disabled, window control should not work. If the app is not listed yet, launch it and try connecting Chrome so macOS can process its request." },
    ] },
    { id: "trust", title: "What to check before installing", paragraphs: [
      "Download from Releases in the official repository and match the version to its release notes. ProfileDock 0.1.6 beta is not yet notarized by Apple. Open source and published test results support inspection, but do not replace an independent security audit.",
      "For a problem report, describe the action, error and versions of macOS, Chrome and ProfileDock. Redact private titles, account names and page contents before sharing a screenshot. Troubleshooting window switching does not require a password, cookies or your complete profile folder.",
    ] },
  ],
  sources: [
    { title: "Apple: allow apps to control other apps", href: "https://support.apple.com/guide/mac-help/mchl108e1718/mac" },
    { title: "ProfileDock: data, networking and permission boundaries", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/docs/PRIVACY-AND-SECURITY.md" },
    { title: "ProfileDock: Chrome window-control source code", href: "https://github.com/kunilingvistador/ProfileDock/blob/main/Sources/ProfileDock/ChromeService.swift" },
    { title: "ProfileDock 0.1.6 beta: official download", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};
