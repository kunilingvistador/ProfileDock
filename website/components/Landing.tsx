"use client";

import { useState } from "react";
import {
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  BriefcaseBusiness,
  Check,
  ChevronDown,
  Download,
  CodeXml,
  Image as ImageIcon,
  Layers3,
  LockKeyhole,
  MousePointer2,
  PanelsTopLeft,
  UserRound,
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
    line1: "Нужный профиль.",
    line2: "С первого клика.",
    intro:
      "У каждого окна Chrome — свой значок в Dock. Нажмите на знакомую картинку и вернитесь к своим вкладкам.",
    download: "Скачать для Mac",
    see: "Посмотреть, как работает",
    details: "Бесплатно · Открытый код · macOS 13+",
    betaHint: "Бета-версия. При установке нужно подтверждение macOS.",
    demoBadge: "Попробуйте прямо здесь",
    demo: "Какое окно поднимем?",
    demoNote: "Это демонстрация — ваш Chrome остаётся как есть.",
    profiles: ["Работа", "Личное", "Проект"],
    tab: "Ваше открытое окно",
    ready: "Вкладки остаются на месте",
    active: "На переднем плане:",
    benefits: [
      ["Сразу в нужное окно", "Без поиска в стопке окон. Ярлык поднимает то, которое вы выбрали."],
      [
        "Значки с характером",
        "Ваша фотография или знакомый логотип. Легче узнать — быстрее выбрать.",
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
        "Нужно системное разрешение на управление Google Chrome. Настройки и изображения сохраняются локально; аналитики и аккаунта нет. Когда вы сами выбираете иконку сайта, приложение обращается к этому сайту и к адресам иконок, указанным на его странице.",
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
    privacy: "Локальные настройки. Без аналитики.",
    foot: "Сделано для тех, у кого больше одного окна.",
    license: "Лицензия MIT",
  },
  en: {
    language: "Переключить на русский",
    nav: ["How it works", "Questions"],
    source: "Source on GitHub",
    skip: "Skip to content",
    badge: "CHROME × macOS",
    line1: "The right profile.",
    line2: "One familiar click.",
    intro:
      "Give each Chrome window its own icon in the Dock. Click a familiar face and get back to your tabs.",
    download: "Download for Mac",
    see: "See how it works",
    details: "Free · Open source · macOS 13+",
    betaHint: "Beta software. macOS approval is needed during installation.",
    demoBadge: "Give it a try",
    demo: "Which window comes forward?",
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
        "Your photo or a familiar logo. Easier to recognize, quicker to choose.",
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
        "It needs macOS permission to control Google Chrome. Settings and images are stored locally, with no analytics or account. If you choose to fetch a website icon, the app contacts that site and the icon addresses listed on its page.",
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
    privacy: "Local settings. No analytics.",
    foot: "Made for people with more than one window.",
    license: "MIT license",
  },
};
const ProfileIcons = [BriefcaseBusiness, UserRound, Layers3];
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
            <div className="windows" aria-hidden="true">
              {t.profiles.map((name, i) => {
                const Icon = ProfileIcons[i];
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
                        <Icon size={27} strokeWidth={1.7} />
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
              {t.profiles.map((name, i) => {
                const Icon = ProfileIcons[i];
                return (
                  <button
                    type="button"
                    key={i}
                    className={`dock-icon tone-${i}`}
                    aria-label={name}
                    aria-pressed={selected === i}
                    onClick={() => setSelected(i)}
                  >
                    <Icon size={29} strokeWidth={1.7} aria-hidden="true" />
                    <span className="dock-tooltip" aria-hidden="true">
                      {name}
                    </span>
                  </button>
                );
              })}
            </div>
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
            <span>
              <LockKeyhole size={13} aria-hidden="true" />
              {t.privacy}
            </span>
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
