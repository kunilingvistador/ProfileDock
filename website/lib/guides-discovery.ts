import type { Guide } from "./guides";

export const accountsRU: Guide = {
  slug: "chrome-profiles-vs-google-accounts",
  published: "2026-10-08",
  title: "Профиль Chrome и аккаунт Google: в чём разница на Mac",
  shortTitle: "Профиль Chrome или второй аккаунт Google?",
  description: "Два Gmail в одном Chrome или отдельные профили? Разберитесь с аккаунтами, окнами и профилями на Mac и выберите удобную организацию работы.",
  category: "Основы",
  summary: "Вход во второй Google-аккаунт меняет доступ к сервисам Google. Отдельный профиль Chrome помогает организовать браузерный контекст. Выбор зависит от того, нужны ли вам две почты или два самостоятельных рабочих пространства.",
  takeaway: "Для редкого перехода между двумя Gmail начните с меню аккаунта на сайте. Для работы и личного с разными закладками и настройками используйте профили Chrome. Ещё одно окно само по себе не создаёт профиль.",
  sections: [
    { id: "three-things", title: "Три похожих действия с разным результатом", points: [
      { title: "Добавить аккаунт на сайте Google", body: "У одного профиля браузера может быть несколько входов в Google. Аватар внутри Gmail или другой страницы Google помогает выбрать аккаунт сервиса; имя профиля Chrome от этого не становится другим." },
      { title: "Открыть ещё одно окно", body: "Вы получаете дополнительное место для вкладок. Проверьте меню профиля в панели Chrome: два окна с одним именем профиля не являются двумя отдельными браузерными контекстами." },
      { title: "Создать профиль Chrome", body: "У профиля отдельные закладки, история, пароли и настройки. Вход в Google и сохранение данных в аккаунте — дополнительный выбор, который не следует путать с самим созданием профиля." },
    ] },
    { id: "choose", title: "Выберите по задаче, а не по числу адресов почты", paragraphs: [
      "Представьте, что вам раз в неделю нужно проверить вторую почту, а остальные вкладки и закладки остаются теми же. Начните с переключателя аккаунтов Google: организация всего браузера ради этого может быть лишней.",
      "Другой сценарий: утром вы открываете рабочую почту, календарь и документы, а вечером — личные покупки и поездки. Здесь два профиля с короткими именами «Работа» и «Личное» дают более понятный порядок. Значки и цвета становятся подсказками, куда вы возвращаетесь.",
      "Если у вас несколько клиентов, сначала отделите контекст одного клиента и проверьте, помогает ли это в течение дня. Не создавайте семь новых профилей сразу. Чем больше вариантов в меню, тем важнее ясные имена и привычная последовательность переключения.",
    ], links: [{ title: "Настроить рабочий и личный профили в четыре шага", slug: "separate-work-personal-chrome-profiles-mac" }] },
    { id: "wrong-account", title: "Почему ссылка может открыться не в том аккаунте", paragraphs: [
      "Google описывает ситуации, когда при нескольких входах применяются настройки аккаунта по умолчанию. Во многих случаях это аккаунт, в который вы вошли первым. Новое окно браузера не сообщает сервису, какой аккаунт вы намеревались использовать.",
      "Перед важным действием проверьте аккаунт внутри самого сайта: у аватара Chrome и аватара страницы Google разные роли. Если документ недоступен, сначала посмотрите выбранный аккаунт и приглашение к документу. Переключение профиля не выдаёт дополнительных прав на чужой файл.",
      "Не удаляйте профиль, не очищайте браузерные данные и не выходите сразу из всех аккаунтов только ради этой проверки. Сначала определите, где именно возникла путаница: в сервисе Google, в профиле Chrome или в выбранном окне.",
    ] },
    { id: "check", title: "Проверьте свою организацию без переноса данных", steps: [
      { title: "Посмотрите имя профиля Chrome", body: "В привычном окне откройте меню профиля в панели браузера. Запишите для себя, какой контекст здесь должен быть: работа, личное или конкретный клиент." },
      { title: "Проверьте аккаунт на одной знакомой странице", body: "Откройте почту или календарь и посмотрите аватар или подпись аккаунта внутри страницы. Сравните результат с тем, что вы ожидали от этого окна." },
      { title: "Повторите во втором окне", body: "Если профиль один и тот же, решите, достаточно ли переключателя аккаунтов. Если нужны разные наборы закладок и настроек, перейдите к инструкции создания отдельных профилей." },
      { title: "Проверьте ежедневный маршрут", body: "Перейдите в другое приложение и вернитесь к работе. Оцените, легко ли найти нужное окно и проверить аккаунт. Дополнительные ярлыки нужны только там, где этот поиск мешает." },
    ] },
    { id: "dock", title: "Где помогает ProfileDock", paragraphs: [
      "ProfileDock не создаёт Google-аккаунты и не управляет входом в Gmail. Он помогает вернуться к одному уже открытому окну Chrome через отдельный значок Dock или назначенное сочетание клавиш. Сначала настройте сами профили и проверьте аккаунты, затем подключайте окна.",
      "В версии 0.1.6 beta ярлык связан с конкретным окном. Если его закрыли, новое окно нужно переподключить. Картинка и название ярлыка помогают узнавать задачу, но не подтверждают, какой аккаунт сейчас выбран на сайте.",
    ], links: [{ title: "Почему у нескольких профилей один значок в Dock", slug: "chrome-profiles-one-dock-icon-mac" }] },
    { id: "shared-mac", title: "Если Mac используют несколько человек", paragraphs: [
      "Профили Chrome помогают навести порядок, но человек с доступом к той же учётной записи Mac может переключить профиль. Для общего компьютера рассмотрите отдельные учётные записи macOS. На устройстве организации сначала уточните её правила работы с аккаунтами.",
    ] },
  ],
  sources: [
    { title: "Google: несколько аккаунтов одновременно и аккаунт по умолчанию", href: "https://support.google.com/accounts/answer/1721977?hl=ru" },
    { title: "Google: управление профилями Chrome", href: "https://support.google.com/chrome/answer/2364824?hl=ru" },
    { title: "ProfileDock: поведение и ограничения приложения", href: "https://github.com/kunilingvistador/ProfileDock#readme" },
  ],
};

export const accountsEN: Guide = {
  slug: "chrome-profiles-vs-google-accounts",
  published: "2026-10-08",
  title: "Chrome Profiles vs Google Accounts on Mac: Which Do You Need?",
  shortTitle: "A Chrome profile or another Google account?",
  description: "Two Gmail accounts in one Chrome profile or separate browser profiles? Understand accounts, windows and profiles on Mac, and choose a practical setup.",
  category: "Basics",
  summary: "A second Google login changes which Google services you can access. A separate Chrome profile organizes a browser context. Choose based on whether you need two inboxes or two everyday workspaces.",
  takeaway: "For occasional trips between two Gmail accounts, start with the account menu on the website. For work and personal browsing with different bookmarks and settings, use Chrome profiles. Another window alone does not create a profile.",
  sections: [
    { id: "three-things", title: "Three similar actions with different results", points: [
      { title: "Add an account on a Google website", body: "One browser profile can have several Google sign-ins. The picture inside Gmail or another Google page selects a service account; it does not change the Chrome profile’s identity." },
      { title: "Open another window", body: "You get more room for tabs. Check the profile menu in Chrome’s toolbar: two windows showing the same profile name are not two separate browser contexts." },
      { title: "Create a Chrome profile", body: "A profile has its own bookmarks, history, passwords and settings. Signing into Google and saving browser information to an account is an additional choice, separate from creating the profile." },
    ] },
    { id: "choose", title: "Choose by task, not by the number of email addresses", paragraphs: [
      "Imagine checking a second inbox once a week while keeping the same tabs and bookmarks. Start with Google’s account switcher. Reorganizing the whole browser for that occasional visit may add work without helping your routine.",
      "Now imagine opening work mail, calendars and documents each morning, then personal shopping and travel pages in the evening. Two profiles named Work and Personal give those tasks a clearer home. Distinct names and colors help you recognize where you are returning.",
      "For several clients, separate one client’s context first and try it for a day. Do not create seven new profiles at once. As the menu grows, clear names and a predictable switching routine matter more.",
    ], links: [{ title: "Set up work and personal profiles in four steps", slug: "separate-work-personal-chrome-profiles-mac" }] },
    { id: "wrong-account", title: "Why a link can open under the wrong account", paragraphs: [
      "Google describes situations where multiple sign-ins cause settings from the default account to apply. Often that is the account you signed into first. A new browser window does not tell the service which account you intended to use.",
      "Before an important action, check the account inside the website. Chrome’s toolbar picture and a Google page’s account picture serve different purposes. If a document is unavailable, check the selected account and its invitation first. Switching profiles does not grant access to someone else’s file.",
      "Do not delete a profile, clear browser data or sign out of every account just to investigate. First identify where the confusion occurs: the Google service, Chrome’s profile or the window you selected.",
    ] },
    { id: "check", title: "Check your setup without moving your data", steps: [
      { title: "Check Chrome’s profile name", body: "In a familiar window, open the profile menu in the browser toolbar. Decide which context this window should serve: work, personal browsing or one client." },
      { title: "Check the account on one familiar page", body: "Open mail or a calendar and look at the account picture or label inside the page. Compare it with the account you expected that window to use." },
      { title: "Repeat in the second window", body: "If both windows use the same profile, decide whether the website’s account switcher is enough. If you want separate bookmarks and settings, follow the guide to creating separate profiles." },
      { title: "Try your everyday route", body: "Switch to another app and return to work. See how easily you can find the intended window and check its account. Add shortcuts where that search gets in your way." },
    ] },
    { id: "dock", title: "Where ProfileDock helps", paragraphs: [
      "ProfileDock does not create Google accounts or manage Gmail sign-ins. It helps you return to one existing Chrome window through a dedicated Dock icon or an assigned key combination. Set up your profiles and check the accounts first, then connect the windows.",
      "In version 0.1.6 beta, a shortcut connects to one specific window. After closing it, reconnect a replacement window. Its name and picture help you recognize a task but do not establish which account a website currently uses.",
    ], links: [{ title: "Why several Chrome profiles share one Dock icon", slug: "chrome-profiles-one-dock-icon-mac" }] },
    { id: "shared-mac", title: "If several people share the Mac", paragraphs: [
      "Chrome profiles organize browsing, but someone using the same Mac login can switch profiles. Consider separate macOS user accounts for a shared computer. On an organization’s device, check its account rules first.",
    ] },
  ],
  sources: [
    { title: "Google: multiple sign-ins and the default account", href: "https://support.google.com/accounts/answer/1721977?hl=en" },
    { title: "Google: manage Chrome profiles", href: "https://support.google.com/chrome/answer/2364824?hl=en" },
    { title: "ProfileDock: app behavior and limitations", href: "https://github.com/kunilingvistador/ProfileDock#readme" },
  ],
};

export const dockRU: Guide = {
  slug: "chrome-profiles-one-dock-icon-mac",
  published: "2026-10-08",
  title: "Почему у профилей Chrome на Mac один значок в Dock",
  shortTitle: "Несколько профилей, один значок Chrome",
  description: "Профили Chrome на Mac остаются за одним значком приложения. Как выбрать нужное окно встроенными средствами или добавить отдельные ярлыки в Dock.",
  category: "Dock на Mac",
  summary: "Профиль Chrome — контекст внутри браузера. Обычный значок Chrome в Dock ведёт к приложению. Разберём способы найти нужное окно и случаи, когда удобнее закрепить собственный ярлык.",
  takeaway: "Имена и аватары профилей помогают внутри Chrome, но обычный значок приложения в Dock не выбирает конкретный профиль. Для прямого возврата к открытому окну можно создать отдельное приложение-ярлык в ProfileDock.",
  sections: [
    { id: "one-app", title: "Что выбирает значок Chrome", paragraphs: [
      "Почта рабочего профиля, личные вкладки и окно клиента могут одновременно быть открыты в Google Chrome. Это разные контексты одного браузера. Сам значок Chrome не хранит ваш выбор «всегда показывать рабочую почту».",
      "В документации Apple Dock описан как способ открывать приложения и другие объекты. Добавление обычного значка Chrome закрепляет приложение. Чтобы узнаваемая картинка выбирала определённое окно, ей нужна отдельная команда переключения.",
      "У ProfileDock такую команду содержит небольшое приложение-ярлык. Его можно закрепить в Dock и назвать «Работа» или «Личное». При этом сами окна продолжают принадлежать Chrome; это не две независимые установки браузера.",
    ] },
    { id: "built-in", title: "Попробуйте встроенные способы", points: [
      { title: "Меню профилей Chrome", body: "Откройте кнопку профиля в панели браузера и выберите нужный профиль. Подходит, если переходите между контекстами несколько раз в день и легко узнаёте их имена." },
      { title: "Mission Control", body: "Покажите открытые окна и выберите нужное по содержимому. Полезно, когда вы помните вид документа, а не название его профиля. Расположение окон может различаться на разных рабочих столах." },
      { title: "Меню значка Dock", body: "Нажмите значок Chrome, удерживая Control, и посмотрите доступные команды и список окон. Встроенный выбор может оказаться достаточным без дополнительной настройки." },
    ], links: [{ title: "Сочетания клавиш для частых переключений", slug: "switch-chrome-profiles-keyboard-mac" }] },
    { id: "dedicated", title: "Когда отдельный значок удобнее", paragraphs: [
      "Возьмите две постоянные задачи: рабочая почта и личный браузер. Если оба окна весь день стоят друг за другом, выбираемая заранее картинка сокращает поиск. Это особенно заметно, когда в каждом окне похожая почта, календарь или стартовая страница.",
      "Ярлык стоит называть по задаче, если в одном профиле несколько окон: «Работа · почта» и «Работа · документы». Так две похожие картинки не обещают один и тот же результат. Для первого опыта достаточно двух часто используемых окон.",
      "ProfileDock 0.1.6 beta возвращает одно выбранное существующее окно. Он не выбирает все окна профиля и не создаёт пустую замену при потере связи. Это важно, если вам нужен запуск закрытого профиля, а не возврат к постоянно открытому окну.",
    ] },
    { id: "try", title: "Проверьте один ярлык перед настройкой остальных", steps: [
      { title: "Откройте нужное обычное окно", body: "В Chrome выберите профиль и оставьте в нём знакомую страницу. Если у профиля несколько окон, заранее решите, какое хотите возвращать. Инкогнито не подходит для постоянной связи." },
      { title: "Сохраните и проверьте цель", body: "В ProfileDock подключите Chrome, создайте ярлык и выберите окно. Нажмите «Показать окно» перед сохранением, чтобы убедиться, что привязка ведёт туда, куда вы ожидаете." },
      { title: "Выберите узнаваемое оформление", body: "Дайте короткое имя и добавьте фотографию, логотип или файл изображения. Проверьте, различима ли картинка в обычном размере Dock, а не только в большом редакторе." },
      { title: "Закрепите и нажмите из другого приложения", body: "Создайте ярлык для Dock и перетащите показанный в Finder файл в область приложений Dock. Оставьте файл в его постоянном месте. Перейдите в другое приложение и нажмите ярлык: проверьте выбранное окно и его вкладки." },
    ], links: [{ title: "Полная инструкция: установка, разрешения и настройка Dock", slug: "chrome-profile-shortcuts-mac-dock" }] },
    { id: "avoid", title: "Чего не стоит делать ради второго значка", paragraphs: [
      "Не копируйте папку данных профиля и не создавайте новую пустую среду только для красивого значка. Сначала выберите требуемое поведение: открыть профиль или показать уже открытое окно. Похожая картинка у двух ярлыков ещё не означает одинаковую команду.",
      "Если у вас уже есть скрипт или Automator-ярлык, проверьте его результат: вернулись ли ваши вкладки или появилось новое окно? ProfileDock полезен именно для связи с выбранным существующим окном. Он не переносит аккаунты и не требует повторного входа ради создания ярлыка.",
    ] },
    { id: "after-close", title: "Закрытие окна, перезапуск и обновление", paragraphs: [
      "После закрытия связанного окна может понадобиться «Переподключить окно» в меню ярлыка. Откройте нужное окно, проверьте его и сохраните новую связь. Имя, картинку, сочетание клавиш и существующий значок Dock можно сохранить.",
      "После обновления ProfileDock один раз откройте новую копию приложения, чтобы зарегистрировать её местоположение. Полноэкранный режим, несколько Spaces, Stage Manager и мониторы всё ещё требуют более широких проверок. Для таких конфигураций бета не обещает одинаковое поведение во всех случаях.",
    ], links: [{ title: "Если ярлык не находит прежнее окно", slug: "chrome-shortcut-existing-window" }] },
  ],
  sources: [
    { title: "Apple: использование Dock на Mac", href: "https://support.apple.com/ru-ru/guide/mac-help/mh35859/mac" },
    { title: "Apple: открытые окна в Mission Control", href: "https://support.apple.com/ru-ru/guide/mac-help/mh35798/mac" },
    { title: "Google: переключение профилей Chrome", href: "https://support.google.com/chrome/answer/2364824?hl=ru" },
    { title: "ProfileDock 0.1.6 beta: загрузка и ограничения", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};

export const dockEN: Guide = {
  slug: "chrome-profiles-one-dock-icon-mac",
  published: "2026-10-08",
  title: "Why Chrome Profiles Share One Dock Icon on Mac",
  shortTitle: "Several profiles, one Chrome icon",
  description: "Multiple Chrome profiles on Mac still use one browser app icon. Find the right window with built-in tools or add separate shortcuts to your Dock.",
  category: "Mac Dock",
  summary: "A Chrome profile is a context inside the browser. The ordinary Chrome Dock icon selects the app. Compare ways to find a window and decide when a dedicated shortcut helps.",
  takeaway: "Profile names and pictures help inside Chrome, but its ordinary Dock icon does not select a particular profile. For a direct return to an existing window, ProfileDock can create a separate shortcut app.",
  sections: [
    { id: "one-app", title: "What the Chrome icon selects", paragraphs: [
      "Work mail, personal tabs and a client window can all be open in Google Chrome at once. They are different contexts within one browser. The Chrome icon itself does not store an instruction to always show your work inbox.",
      "Apple describes the Dock as a way to open apps and other items. Keeping an ordinary Chrome icon there pins the app. A familiar picture needs its own switching command to select a particular window.",
      "ProfileDock places that command in a small shortcut app. You can keep it in the Dock and name it Work or Personal. The actual windows still belong to Chrome; these are not independent browser installations.",
    ] },
    { id: "built-in", title: "Try the built-in choices first", points: [
      { title: "Chrome’s profile menu", body: "Open the profile button in the browser toolbar and select a profile. It can be enough when you switch a few times a day and recognize your profile names easily." },
      { title: "Mission Control", body: "Show open windows and select the one you recognize by its contents. This helps when you remember a document’s appearance rather than its profile name. Windows can be arranged across different desktops." },
      { title: "The Dock icon’s menu", body: "Control-click Chrome’s icon and inspect its available commands and window list. That built-in choice may be enough without adding another setup." },
    ], links: [{ title: "Keyboard shortcuts for frequent switching", slug: "switch-chrome-profiles-keyboard-mac" }] },
    { id: "dedicated", title: "When a dedicated icon helps", paragraphs: [
      "Consider two everyday tasks: work mail and personal browsing. If their windows spend the day stacked behind each other, a picture chosen in advance makes the target easier to find. It is especially helpful when both windows show similar inboxes, calendars or start pages.",
      "Name shortcuts by task when one profile has several windows: Work · Mail and Work · Documents. Two similar pictures should not suggest the same destination. Start with just two windows you return to frequently.",
      "ProfileDock 0.1.6 beta returns one selected existing window. It does not select every window in a profile or create a blank replacement when the connection is lost. Consider that distinction if you want to launch a closed profile rather than return to a window you keep open.",
    ] },
    { id: "try", title: "Try one shortcut before setting up the rest", steps: [
      { title: "Open the intended ordinary window", body: "Select the profile in Chrome and keep a familiar page open. If that profile has several windows, decide which one you want to return to. Incognito is unsuitable for a persistent connection." },
      { title: "Save and check the target", body: "Connect Chrome in ProfileDock, create a shortcut and choose the window. Use Show window before saving to verify that the connection selects the destination you expect." },
      { title: "Choose recognizable styling", body: "Give it a short name and add a photo, logo or image file. Check the picture at your normal Dock size, not just in a large editor preview." },
      { title: "Pin it and try from another app", body: "Create its Dock shortcut and drag the file shown in Finder into the Dock’s app area. Keep that file in its permanent location. Switch to another app and click the shortcut; check the selected window and its tabs." },
    ], links: [{ title: "Full setup: installation, permissions and Dock shortcuts", slug: "chrome-profile-shortcuts-mac-dock" }] },
    { id: "avoid", title: "What to avoid just to get another icon", paragraphs: [
      "Do not copy a profile’s data folder or build a new empty browser environment just for a second picture. First choose the behavior you need: opening a profile or showing an existing window. Two similar-looking shortcuts can issue different commands.",
      "If you already have a script or Automator shortcut, check its result: did your tabs return, or did a new window appear? ProfileDock serves the particular case of connecting to one existing window. Creating a shortcut does not move your accounts or require signing into them again.",
    ] },
    { id: "after-close", title: "Closing a window, restarting and updating", paragraphs: [
      "After closing a connected window, you may need Reconnect window in the shortcut menu. Open the intended replacement, verify it and save the new connection. You can keep the shortcut’s name, image, key combination and existing Dock icon.",
      "After updating ProfileDock, open the new copy once to register its location. Fullscreen, multiple Spaces, Stage Manager and multiple displays still need broader testing. The beta does not promise identical behavior across all those setups.",
    ], links: [{ title: "If a shortcut cannot find its previous window", slug: "chrome-shortcut-existing-window" }] },
  ],
  sources: [
    { title: "Apple: use the Dock on Mac", href: "https://support.apple.com/guide/mac-help/mh35859/mac" },
    { title: "Apple: open windows in Mission Control", href: "https://support.apple.com/guide/mac-help/mh35798/mac" },
    { title: "Google: switch Chrome profiles", href: "https://support.google.com/chrome/answer/2364824?hl=en" },
    { title: "ProfileDock 0.1.6 beta: download and limitations", href: "https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta" },
  ],
};
