"use client";

import AnalyticsControl from "./AnalyticsControl";
import { useState } from "react";
import {
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  Check,
  ChevronDown,
  Download,
  CodeXml,
  Image as ImageIcon,
  LockKeyhole,
  MousePointer2,
  PanelsTopLeft,
} from "lucide-react";

const repo = "https://github.com/kunilingvistador/ProfileDock";
const release = `${repo}/releases`;
const copy = {
  ru: {
    language: "Switch to English",
    nav: ["Как работает", "Вопросы"],
    source: "Код на GitHub",
    skip: "Перейти к содержанию",
    badge: "CHROME × macOS",
    line1: "Профили Chrome.",
    line2: "Отдельно в Dock.",
    intro:
      "Закрепите каждый профиль отдельным ярлыком в Dock. Нажмите на его значок, чтобы вернуться к выбранному открытому окну Chrome.",
    download: "Скачать для Mac",
    see: "Посмотреть, как работает",
    details: "Бесплатно · Открытый код · macOS 13+",
    betaHint: "Бета-версия. При установке нужно подтверждение macOS.",
    demoBadge: "Попробуйте прямо здесь",
    demoTitle: "Три профиля. Три ярлыка.",
    demo: "Нажмите на значок в Dock",
    dockCaption: "Каждый ярлык закрепляется отдельно",
    switchTo: "Показать окно профиля",
    demoNote: "Это демонстрация — ваш Chrome остаётся как есть.",
    profiles: ["Работа", "Личное", "Проект"],
    tab: "Ваше открытое окно",
    ready: "Вкладки остаются на месте",
    active: "На переднем плане:",
    benefits: [
      ["Сразу в нужное окно", "Без поиска в стопке окон. Ярлык поднимает то, которое вы выбрали."],
      [
        "Значки с характером",
        "Ваше фото, логотип проекта или значок сайта. У каждого ярлыка — своё имя и изображение.",
      ],
      ["Без лишних настроек", "Работает с обычным Chrome. Без расширения, регистрации и подписки."],
    ],
    appKicker: "НЕБОЛЬШОЕ ПРИЛОЖЕНИЕ. БОЛЬШЕ ПОРЯДКА.",
    appTitle: "Все ваши окна.\nНа своих местах.",
    appIntro:
      "Одна спокойная панель для настройки. А для ежедневного переключения — привычный Dock.",
    appPoints: [
      [
        "Проверьте перед привязкой",
        "Посмотрите выбранное окно Chrome, прежде чем сохранить ярлык.",
      ],
      ["Сделайте своим", "Имя и изображение настраиваются рядом с каждым ярлыком."],
      ["Вернитесь без путаницы", "Закрыли окно? Выберите новое для того же ярлыка."],
    ],
    screenshot:
      "Интерфейс ProfileDock: три демонстрационных ярлыка Studio, Personal и Research с настройками и кнопками переключения.",
    screenshotNote: "Настоящий интерфейс приложения · демонстрационные данные",
    setupKicker: "ТРИ ПРОСТЫХ ШАГА",
    setupTitle: "Один раз настроить.\nКаждый день пользоваться.",
    steps: [
      [
        "Выберите окно",
        "Откройте нужный профиль в Chrome. В ProfileDock нажмите «Добавить» и выберите его окно.",
      ],
      [
        "Добавьте свой значок",
        "Дайте ярлыку понятное имя. Выберите фотографию или возьмите иконку с сайта.",
      ],
      [
        "Закрепите в Dock",
        "Нажмите «Создать ярлык для Dock» и перетащите готовое приложение из Finder в Dock.",
      ],
    ],
    installTitle: "Перед первым запуском",
    installText:
      "Скачайте ZIP со страницы выпуска, распакуйте и перенесите ProfileDock в «Программы». Сборка пока без нотариализации Apple: если macOS блокирует запуск, следуйте инструкции в выпуске. Разрешите ProfileDock управлять Chrome, когда система попросит.",
    installLink: "Открыть инструкцию установки",
    faqKicker: "ХОРОШИЕ ВОПРОСЫ",
    faqTitle: "Что стоит знать.",
    faq: [
      ["Можно переключаться с клавиатуры?", "Да. В версии 0.1.6 можно назначить каждому ярлыку свою комбинацию, например ⌥⌘1. Она возвращает то же открытое окно. ProfileDock должен быть запущен в строке меню; назначение необязательное и сохраняется при обновлении."],
      [
        "Это переключатель профилей Chrome или окон?",
        "ProfileDock привязывает каждый ярлык к конкретному открытому окну Chrome. Поэтому можно держать разные профили — или несколько окон одного профиля — и выбирать нужное через Dock.",
      ],
      [
        "Будут открываться пустые окна или новые вкладки?",
        "При переключении приложение поднимает уже привязанное окно. Оно не создаёт пустое окно и не добавляет вкладки. Если окно закрыто или связь потеряна, ProfileDock предложит выбрать другое.",
      ],
      [
        "Что случится после закрытия окна или перезапуска Chrome?",
        "Может понадобиться перепривязать ярлык к новому окну. Выберите «Привязать другое окно» в меню ярлыка: имя и картинка сохранятся. Автоматическое восстановление всех сессий пока не поддерживается.",
      ],
      [
        "Какие Mac поддерживаются?",
        "Системное требование — macOS 13 и новее. Универсальная сборка содержит версии для Apple Silicon и Intel. Сборка и основные тесты проверяются на macOS 15 и 26 обеих архитектур; работа с реальными окнами Chrome проверена на Apple Silicon. macOS 13–14, полноэкранный режим и разные Spaces требуют дополнительных проверок.",
      ],
      [
        "Какие разрешения и данные нужны?",
        "Для выбора окна приложение локально читает имена профилей, подписи аккаунтов, фото и заголовки окон. macOS даёт широкое разрешение на управление Chrome; оно не ограничено только переключением. Вы можете отозвать его в разделе «Конфиденциальность и безопасность → Автоматизация».",
      ],
      [
        "Получают ли разработчики данные моего Chrome?",
        "ProfileDock не отправляет нам данные профилей и окон. В приложении нет аккаунта, сервера для сбора данных или аналитики. Содержимое открытых страниц, пароли, cookies и история не читаются. Отдельная сетевая функция — загрузка значка сайта по вашей команде; вместо неё можно выбрать файл.",
      ],
      [
        "Это отдельный браузер? Работает с Safari или Edge?",
        "Это небольшая утилита для обычного Google Chrome на Mac. Safari, Edge и другие браузеры пока не поддерживаются. Ярлыки не превращают профили в независимые приложения Chrome в Cmd–Tab.",
      ],
      [
        "Сколько это стоит и куда отправить пожелание?",
        "ProfileDock бесплатен, код открыт по лицензии MIT. Ошибки и предложения можно оставить в GitHub Issues по ссылке ниже. Проект в бете, и реальные сценарии использования помогают выбрать следующие улучшения.",
      ],
    ],
    closing: "Меньше искать.\nПроще переключаться.",
    closingText: "Маленькое удобство, которое остаётся с вами весь день.",
    feedback: "Предложить улучшение",
    privacy: "Приложение работает локально.",
    privacyLabel: "Данные и разрешения",
    privacyTitle: "Ваш браузер.\nВаши данные.",
    privacyIntro: "ProfileDock не отправляет данные Chrome разработчикам. Доступ нужен самому приложению на вашем Mac, чтобы находить и поднимать окна.",
    privacyPoints: [
      ["Что читается на Mac", "Имена профилей, подписи аккаунтов (в том числе email), фото профилей и заголовки окон помогают выбрать нужное окно. Содержимое открытых страниц, пароли, cookies и история посещений не читаются."],
      ["Что сохраняется", "Имена ярлыков, привязки окон и картинки — в локальной папке данных и созданных ярлыках. У ProfileDock нет облачного аккаунта, аналитики или автоматической отправки этих данных."],
      ["Когда нужен интернет", "Для переключения — не нужен. При загрузке значка сайта этот сайт получает ваш IP-адрес и запрошенный адрес. Cookies Chrome и данные профилей не передаются. Можно выбрать картинку из файла."],
      ["Что разрешает macOS", "Automation даёт управление Chrome, а не отдельное разрешение только на переключение. Открытый код позволяет проверить, как оно используется. Доступ можно выключить в настройках macOS; переключение перестанет работать."],
    ],
    privacyReport: "Что именно проверено",
    privacyHost: "Этот сайт размещён на GitHub Pages. GitHub записывает IP-адреса посетителей для безопасности сервиса. Это отдельно от работы приложения.",
    foot: "Сделано для тех, у кого больше одного окна.",
    license: "Лицензия MIT",
  },
  en: {
    language: "Переключить на русский",
    nav: ["How it works", "Questions"],
    source: "Source on GitHub",
    skip: "Skip to content",
    badge: "CHROME × macOS",
    line1: "Chrome profiles.",
    line2: "Each in your Dock.",
    intro:
      "Give every profile its own Dock shortcut. Click its icon to bring your chosen open Chrome window back to the front.",
    download: "Download for Mac",
    see: "See how it works",
    details: "Free · Open source · macOS 13+",
    betaHint: "Beta software. macOS approval is needed during installation.",
    demoBadge: "Give it a try",
    demoTitle: "Three profiles. Three shortcuts.",
    demo: "Click an icon in the Dock",
    dockCaption: "Pin each shortcut separately",
    switchTo: "Show the profile window",
    demoNote: "Just a demonstration. Your Chrome stays unchanged.",
    profiles: ["Work", "Personal", "Project"],
    tab: "Your open window",
    ready: "Your tabs stay right where they are",
    active: "In front:",
    benefits: [
      [
        "Straight to your window",
        "Skip the stack of windows. Your shortcut brings forward the one you chose.",
      ],
      [
        "Icons with personality",
        "Your photo, project logo or website icon. Each shortcut has its own name and picture.",
      ],
      [
        "A simple fit",
        "Works with regular Chrome. No extension, account or subscription to set up.",
      ],
    ],
    appKicker: "A SMALL APP. A LITTLE MORE ORDER.",
    appTitle: "Every window.\nIn its own place.",
    appIntro: "One quiet panel to set things up. Your familiar Dock for everyday switching.",
    appPoints: [
      ["Check before you connect", "Preview the chosen Chrome window before saving its shortcut."],
      ["Make it yours", "The name and picture are easy to change beside every shortcut."],
      ["Reconnect without confusion", "Closed a window? Choose a new one for the same shortcut."],
    ],
    screenshot:
      "The ProfileDock app with three demo shortcuts, Studio, Personal and Research, and visible customization and switching actions.",
    screenshotNote: "Actual app interface · demo data",
    setupKicker: "THREE SIMPLE STEPS",
    setupTitle: "Set it up once.\nEnjoy it every day.",
    steps: [
      [
        "Choose a window",
        "Open the profile you want in Chrome. Click Add in ProfileDock and select its window.",
      ],
      [
        "Pick a familiar icon",
        "Give your shortcut a useful name. Choose a photo or fetch an icon from a website.",
      ],
      [
        "Keep it in the Dock",
        "Click Create Dock shortcut, then drag the generated app from Finder into your Dock.",
      ],
    ],
    installTitle: "Before your first launch",
    installText:
      "Download the ZIP from the release page, unzip it and move ProfileDock to Applications. This build is not yet notarized by Apple. If macOS blocks it, follow the release instructions. Allow ProfileDock to control Chrome when macOS asks.",
    installLink: "Read the installation guide",
    faqKicker: "GOOD QUESTIONS",
    faqTitle: "A few things to know.",
    faq: [
      ["Can I switch using the keyboard?", "Yes. Version 0.1.6 lets you assign a combination such as Option–Command–1 to each shortcut. It returns the same existing window. ProfileDock must be running in the menu bar; assignments are optional and persist across updates."],
      [
        "Does it switch Chrome profiles or windows?",
        "Each shortcut connects to a specific open Chrome window. You can keep different profiles, or several windows of the same profile, and choose the one you want from the Dock.",
      ],
      [
        "Will it open empty windows or new tabs?",
        "Switching brings forward the window you already connected. It does not create an empty window or add tabs. If the window is closed or the connection is lost, ProfileDock helps you choose another one.",
      ],
      [
        "What happens after I close a window or restart Chrome?",
        "You may need to reconnect the shortcut to a new window. Choose “Choose another window” in the shortcut menu; its name and picture stay the same. Automatic restoration of all sessions is not supported yet.",
      ],
      [
        "Which Macs does it support?",
        "The minimum requirement is macOS 13. The universal build includes Apple Silicon and Intel. Builds and core tests run on both architectures with macOS 15 and 26; live Chrome window behavior has been tested on Apple Silicon. macOS 13–14, fullscreen and multiple Spaces need more testing.",
      ],
      [
        "What permissions and data does it need?",
        "To help you choose a window, the app reads local profile names, account labels, pictures and window titles. macOS grants broad control of Chrome, not a permission limited to switching. You can revoke it in Privacy & Security → Automation.",
      ],
      [
        "Do the developers receive my Chrome data?",
        "ProfileDock does not send us profile or window data. The app has no account, data-collection server or analytics. It does not read open page contents, passwords, cookies or browsing history. An optional network feature fetches a website icon at your request; you can choose a file instead.",
      ],
      [
        "Is this another browser? Does it work with Safari or Edge?",
        "It is a small utility for regular Google Chrome on Mac. Safari, Edge and other browsers are not supported yet. Shortcuts do not turn profiles into independent Chrome apps in Cmd–Tab.",
      ],
      [
        "What does it cost? Where can I suggest something?",
        "ProfileDock is free and open source under the MIT license. Report a bug or suggest an improvement in GitHub Issues using the link below. It is in beta, and real workflows help shape what comes next.",
      ],
    ],
    closing: "Less window hunting.\nMore familiar switching.",
    closingText: "A small convenience that stays with you all day.",
    feedback: "Suggest an improvement",
    privacy: "The Mac app works locally.",
    privacyLabel: "Data and permissions",
    privacyTitle: "Your browser.\nYour data.",
    privacyIntro: "ProfileDock does not send Chrome data to its developers. The app on your Mac needs access to find and bring forward your windows.",
    privacyPoints: [
      ["What it reads on your Mac", "Profile names, account labels (including email addresses), profile pictures and window titles help you choose a window. It does not read open page contents, passwords, cookies or browsing history."],
      ["What it saves", "Shortcut names, window bindings and pictures stay in the local data folder and the shortcuts you create. ProfileDock has no cloud account, analytics or automatic upload of this data."],
      ["When it uses the internet", "Switching works offline. If you fetch a website icon, that site receives your IP address and the requested address. Chrome cookies and profile data are not sent. You can choose an image file instead."],
      ["What macOS permits", "Automation grants control of Chrome, rather than a permission limited to switching. The open source shows how it is used. You can revoke access in macOS settings; switching will stop working."],
    ],
    privacyReport: "Read what was checked",
    privacyHost: "This website is hosted on GitHub Pages. GitHub logs visitors’ IP addresses for service security. This is separate from the app’s operation.",
    foot: "Made for people with more than one window.",
    license: "MIT license",
  },
};
const profileImages = ["work", "personal", "project"];

function ProfileAvatar({ index }: { index: number }) {
  return (
    <img
      src={`/ProfileDock/profiles/${profileImages[index]}.svg`}
      width="128"
      height="128"
      alt=""
      draggable={false}
    />
  );
}

function ChromeMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <circle cx="24" cy="24" r="22" fill="#f7c64b" />
      <path d="M24 24H46A22 22 0 0 0 5 13Z" fill="#ed6a5e" />
      <path d="M24 24 5 13a22 22 0 0 0 19 33l11-19Z" fill="#63ab75" />
      <circle cx="24" cy="24" r="10" fill="#69a8ee" stroke="#fff" strokeWidth="3" />
    </svg>
  );
}
const BenefitIcons = [MousePointer2, ImageIcon, LockKeyhole];

export default function Landing({ initialLanguage }: { initialLanguage: "ru" | "en" }) {
  const [selected, setSelected] = useState(0);
  const t = copy[initialLanguage];
  const home = initialLanguage === "ru" ? "/ProfileDock/" : "/ProfileDock/en/";
  return (
    <>
      <a className="skip-link" href="#content">
        {t.skip}
      </a>
      <header className="site-header wrap">
        <a className="brand" href={home} aria-label="ProfileDock">
          <img src="/ProfileDock/icon.svg" width="34" height="34" alt="" />
          ProfileDock<span className="beta-tag">BETA</span>
        </a>
        <nav aria-label={initialLanguage === "ru" ? "Навигация" : "Navigation"}>
          <a className="nav-section" href="#how-it-works">
            {t.nav[0]}
          </a>
          <a className="nav-section" href="#questions">
            {t.nav[1]}
          </a>
          <a className="nav-section" href={`${home}guides/`}>
            {initialLanguage === "ru" ? "Инструкции" : "Guides"}
          </a>
          <a className="source-link" href={repo} aria-label={t.source}>
            <CodeXml size={19} aria-hidden="true" />
            <span>GitHub</span>
          </a>
          <a
            className="lang-button"
            href={initialLanguage === "ru" ? "/ProfileDock/en/" : "/ProfileDock/"}
            hrefLang={initialLanguage === "ru" ? "en" : "ru"}
            lang={initialLanguage === "ru" ? "en" : "ru"}
            aria-label={t.language}
          >
            {initialLanguage === "ru" ? "EN" : "RU"}
          </a>
        </nav>
      </header>
      <main id="content">
        <section className="hero wrap" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow">
              <span className="status-dot" />
              {t.badge}
            </p>
            <h1 id="hero-title">
              {t.line1}
              <br />
              <em>{t.line2}</em>
            </h1>
            <p className="intro">{t.intro}</p>
            <div className="hero-actions">
              <a className="button button-primary" href={release}>
                <ArrowDown size={19} aria-hidden="true" />
                {t.download}
              </a>
              <a className="text-link" href="#how-it-works">
                {t.see}
                <ArrowRight size={17} aria-hidden="true" />
              </a>
            </div>
            <p className="download-detail">{t.details}</p>
            <a className="beta-hint" href="#install">
              {t.betaHint}
            </a>
          </div>
          <div className="demo-stage">
            <div className="demo-topline">
              <span className="demo-tag">
                <MousePointer2 size={13} aria-hidden="true" />
                {t.demoBadge}
              </span>
              <span className="demo-count" aria-hidden="true">
                01 — 03
              </span>
            </div>
            <h2 className="demo-title">{t.demoTitle}</h2>
            <div className="windows" aria-hidden="true">
              {t.profiles.map((name, i) => {
                return (
                  <div
                    className={`demo-window tone-${i} ${selected === i ? "is-front" : ""}`}
                    key={i}
                    style={{ zIndex: selected === i ? 5 : i + 1 }}
                  >
                    <div className="window-toolbar">
                      <span className="traffic">
                        <i />
                        <i />
                        <i />
                      </span>
                      <span>{name}</span>
                      <PanelsTopLeft size={14} />
                    </div>
                    <div className="window-content">
                      <div className={`profile-avatar tone-${i}`}>
                        <ProfileAvatar index={i} />
                      </div>
                      <span className="window-kicker">{t.tab}</span>
                      <strong>{name}</strong>
                      <p>
                        <Check size={14} />
                        {t.ready}
                      </p>
                      <div className="window-lines">
                        <span />
                        <span />
                        <span />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <p className="try-label">{t.demo}</p>
            <div className="demo-dock" role="group" aria-label={t.demo}>
              <div className="dock-chrome" aria-hidden="true">
                <ChromeMark />
                <span>Chrome</span>
              </div>
              <span className="dock-divider" aria-hidden="true" />
              {t.profiles.map((name, i) => {
                return (
                  <button
                    type="button"
                    key={i}
                    className={`dock-profile tone-${i}`}
                    aria-label={`${t.switchTo}: ${name}`}
                    aria-pressed={selected === i}
                    onClick={() => setSelected(i)}
                  >
                    <span className="dock-icon">
                      <ProfileAvatar index={i} />
                    </span>
                    <span className="dock-name">{name}</span>
                  </button>
                );
              })}
            </div>
            <p className="dock-caption">{t.dockCaption}</p>
            <p className="demo-current" role="status" aria-live="polite">
              {t.active} <strong>{t.profiles[selected]}</strong>
            </p>
            <p className="demo-note">{t.demoNote}</p>
          </div>
        </section>
        <section
          className="benefits wrap"
          aria-label={initialLanguage === "ru" ? "Возможности ProfileDock" : "ProfileDock features"}
        >
          {t.benefits.map(([title, text], i) => {
            const Icon = BenefitIcons[i];
            return (
              <article key={title}>
                <span className="feature-icon">
                  <Icon size={22} strokeWidth={1.7} aria-hidden="true" />
                </span>
                <h2>{title}</h2>
                <p>{text}</p>
              </article>
            );
          })}
        </section>
        <section className="product-section" aria-labelledby="product-title">
          <div className="wrap product-grid">
            <div className="product-copy">
              <p className="eyebrow">{t.appKicker}</p>
              <h2 id="product-title">{t.appTitle}</h2>
              <p className="section-intro">{t.appIntro}</p>
              <div className="product-points">
                {t.appPoints.map(([title, text]) => (
                  <div key={title}>
                    <Check size={17} aria-hidden="true" />
                    <div>
                      <h3>{title}</h3>
                      <p>{text}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <figure className="app-figure">
              <div className="app-image-wrap">
                <img
                  src="/ProfileDock/app-preview.jpg"
                  width="940"
                  height="692"
                  loading="lazy"
                  decoding="async"
                  alt={t.screenshot}
                />
              </div>
              <figcaption>{t.screenshotNote}</figcaption>
            </figure>
          </div>
        </section>
        <section className="setup wrap" id="how-it-works" aria-labelledby="setup-title">
          <p className="eyebrow">{t.setupKicker}</p>
          <h2 id="setup-title">{t.setupTitle}</h2>
          <div className="steps">
            {t.steps.map(([title, text], i) => (
              <article key={title}>
                <span className="step-number">0{i + 1}</span>
                <h3>{title}</h3>
                <p>{text}</p>
              </article>
            ))}
          </div>
          <aside className="install-note" id="install">
            <Download size={23} strokeWidth={1.6} aria-hidden="true" />
            <div>
              <h3>{t.installTitle}</h3>
              <p>{t.installText}</p>
              <a className="text-link" href={release}>
                {t.installLink}
                <ArrowUpRight size={16} aria-hidden="true" />
              </a>
            </div>
          </aside>
        </section>
        <section className="privacy-section wrap" id="privacy" aria-labelledby="privacy-title">
          <div className="privacy-heading">
            <span className="feature-icon"><LockKeyhole size={24} aria-hidden="true" /></span>
            <p className="eyebrow">{t.privacyLabel}</p>
            <h2 id="privacy-title">{t.privacyTitle}</h2>
            <p className="section-intro">{t.privacyIntro}</p>
          </div>
          <div className="privacy-grid">
            {t.privacyPoints.map(([title, body]) => (
              <article key={title}>
                <h3>{title}</h3>
                <p>{body}</p>
              </article>
            ))}
          </div>
          <div className="privacy-footnote">
            <a className="text-link" href={`${repo}/blob/main/docs/PRIVACY-AND-SECURITY.md`}>
              {t.privacyReport}<ArrowUpRight size={16} aria-hidden="true" />
            </a>
            <p>{t.privacyHost} <a href="https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection">GitHub Pages ↗</a></p>
          </div>
        </section>
        <section className="wrap website-analytics-note" id="website-analytics" aria-labelledby="website-analytics-title">
          <h2 id="website-analytics-title">{initialLanguage === "ru" ? "Аналитика этого сайта" : "Analytics on this website"}</h2>
          <p>{initialLanguage === "ru" ? "На сайте по умолчанию используется Google Analytics 4. Измеряются посещения страниц и нажатия на ссылки скачивания. Это не подтверждение установки приложения. Google получает страницу, источник перехода, данные браузера и устройства и cookie-идентификатор; IP-адрес используется при обработке запроса." : "This website uses Google Analytics 4 by default. It measures page visits and clicks on download links, not completed app installations. Google receives page and referral details, browser and device information and a cookie identifier; your IP address is used when processing the request."}</p>
          <p>{initialLanguage === "ru" ? "Мы исключаем параметры и фрагменты адресов страниц и передаём только домен источника перехода. Рекламные сигналы и персонализация отключены. Ниже можно отключить аналитику в этом браузере: дальнейшая отправка остановится, cookies этого счётчика будут удалены, страница перезагрузится. Выбор сохраняется в браузере. Ранее сохранённый отказ продолжает действовать. Уже отправленные данные этим действием не удаляются. Данные профилей и окон Chrome сюда не поступают: в приложении для Mac аналитики нет." : "We exclude page query strings and fragments and send only the referral origin. Advertising signals and personalization are disabled. You can turn off analytics in this browser below: further sending stops, this tracker’s cookies are cleared and the page reloads. Your choice is saved in this browser, and a previously saved refusal is respected. This does not delete data already sent. Chrome profile and window data is not collected here; the Mac app has no analytics."}</p>
          <div id="website-analytics-controls"><AnalyticsControl language={initialLanguage} /></div>
          <a className="text-link" href="https://policies.google.com/privacy">{initialLanguage === "ru" ? "Политика конфиденциальности Google" : "Google Privacy Policy"}</a>
        </section>
        <section className="guides-teaser wrap" aria-labelledby="guides-title">
          <div className="guides-teaser-heading">
            <div>
              <p className="eyebrow">{initialLanguage === "ru" ? "ПОЛЕЗНО ПОД РУКОЙ" : "A LITTLE GUIDANCE"}</p>
              <h2 id="guides-title">{initialLanguage === "ru" ? "Настроить один раз.\nРазобраться без спешки." : "Set it up.\nMake it familiar."}</h2>
            </div>
            <a className="text-link" href={`${home}guides/`}>{initialLanguage === "ru" ? "Все инструкции" : "All guides"}<ArrowUpRight size={17} aria-hidden="true" /></a>
          </div>
          <div className="guides-teaser-grid">
            <article>
              <h3>{initialLanguage === "ru" ? "Профили Chrome отдельными ярлыками в Dock" : "Chrome profile shortcuts in your Mac Dock"}</h3>
              <p>{initialLanguage === "ru" ? "Выберите окно, проверьте привязку и добавьте свой значок. Пошаговая инструкция для первого запуска." : "Choose a window, check the connection and pick an icon. A step-by-step guide for your first shortcut."}</p>
              <a className="text-link" href={`${home}guides/chrome-profile-shortcuts-mac-dock/`}>{initialLanguage === "ru" ? "Настроить ярлык" : "Set up a shortcut"}<ArrowRight size={17} aria-hidden="true" /></a>
            </article>
            <article>
              <h3>{initialLanguage === "ru" ? "Как вернуться к нужному открытому окну" : "Return to the right existing window"}</h3>
              <p>{initialLanguage === "ru" ? "Почему запуск профиля и переключение окна отличаются. Что делать после закрытия окна или перезапуска Chrome." : "Why launching a profile and switching windows differ. What to do after closing a window or restarting Chrome."}</p>
              <a className="text-link" href={`${home}guides/chrome-shortcut-existing-window/`}>{initialLanguage === "ru" ? "Проверить привязку" : "Check the connection"}<ArrowRight size={17} aria-hidden="true" /></a>
            </article>
            <article>
              <h3>{initialLanguage === "ru" ? "Переключение профилей Chrome с клавиатуры" : "Switch Chrome profiles with a keyboard shortcut"}</h3>
              <p>{initialLanguage === "ru" ? "Назначьте сочетание нужному окну. Настройка, занятые клавиши и работа после перезапуска." : "Assign a combination to your chosen window. Setup, conflicts and what happens after a restart."}</p>
              <a className="text-link" href={`${home}guides/switch-chrome-profiles-keyboard-mac/`}>{initialLanguage === "ru" ? "Настроить хоткей" : "Set up a hotkey"}<ArrowRight size={17} aria-hidden="true" /></a>
            </article>
          </div>
          <p className="guide-comparison-note">{initialLanguage === "ru" ? "Начинаете с нуля? " : "Starting from scratch? "}<a className="text-link" href={`${home}guides/separate-work-personal-chrome-profiles-mac/`}>{initialLanguage === "ru" ? "Разделите работу и личное" : "Separate work and personal browsing"}</a>{initialLanguage === "ru" ? ". Есть вопрос о доступе? " : ". Unsure about access? "}<a className="text-link" href={`${home}guides/chrome-automation-permission-mac/`}>{initialLanguage === "ru" ? "Разберитесь с разрешением Chrome" : "Understand Chrome permissions"}</a>.</p>
        </section>
        <section className="faq-section wrap" id="questions" aria-labelledby="faq-title">
          <div className="faq-heading">
            <p className="eyebrow">{t.faqKicker}</p>
            <h2 id="faq-title">{t.faqTitle}</h2>
            <a className="text-link" href={`${repo}/issues`}>
              {t.feedback}
              <ArrowUpRight size={16} aria-hidden="true" />
            </a>
          </div>
          <div className="faq-list">
            {t.faq.map(([question, answer]) => (
              <details key={question}>
                <summary>
                  {question}
                  <ChevronDown size={18} aria-hidden="true" />
                </summary>
                <p>{answer}</p>
              </details>
            ))}
          </div>
        </section>
        <section className="closing wrap" aria-labelledby="closing-title">
          <div>
            <img src="/ProfileDock/icon.svg" alt="" width="48" height="48" loading="lazy" />
            <h2 id="closing-title">{t.closing}</h2>
            <p>{t.closingText}</p>
          </div>
          <div className="closing-action">
            <a className="button button-primary" href={release}>
              <ArrowDown size={19} aria-hidden="true" />
              {t.download}
            </a>
            <a className="privacy-link" href="#privacy">
              <LockKeyhole size={13} aria-hidden="true" />
              {t.privacy}
            </a>
          </div>
        </section>
      </main>
      <footer className="wrap">
        <div>
          <a className="footer-brand" href={home}>
            ProfileDock
          </a>
          <p>{t.foot}</p>
        </div>
        <div className="footer-links">
          <a href={`${home}guides/`}>{initialLanguage === "ru" ? "Инструкции" : "Guides"}</a>
          <a href="#privacy">{t.privacyLabel}</a>
          <a href={`${repo}/issues`}>{t.feedback}</a>
          <a href={`${repo}/blob/main/LICENSE`}>{t.license}</a>
          <a href={repo} aria-label={t.source}>
            <CodeXml size={18} aria-hidden="true" />
            GitHub
          </a>
        </div>
      </footer>
    </>
  );
}
