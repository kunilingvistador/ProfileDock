'use client';

import { useEffect, useState } from 'react';
import { ArrowDown, ArrowUpRight, Check, MousePointer2, LockKeyhole, Image as ImageIcon, PanelsTopLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';

const repo = 'https://github.com/kunilingvistador/ProfileDock';
const copy = {
  ru: {
    source: 'Исходники', badge: 'МАЛЕНЬКАЯ УТИЛИТА ДЛЯ macOS', line1: 'Семь профилей.', line2: 'Один нужный клик.',
    intro: 'Ваши окна Chrome всегда открыты. Дайте каждому свой значок в Dock — и поднимайте нужное одним нажатием.',
    download: 'Скачать бету для Mac', details: 'Бесплатно · Открытый код · macOS 13+',
    demo: 'Попробуйте: нажмите на значок', demoNote: 'Демонстрация переключения. Ваш браузер не изменяется.',
    profiles: ['Работа', 'Личное', 'Проект'], tab: 'Ваше рабочее окно', ready: 'Все вкладки на месте',
    benefits: [ ['Только нужное окно', 'Сохраняет вкладки, размеры и положение ваших окон.'], ['Узнаваемые значки', 'Свои фотографии, названия и иконки с сайтов.'], ['Всё на вашем Mac', 'Без аккаунта, расширения браузера и аналитики.'] ],
    setup: 'Настроили один раз. Переключаетесь каждый день.',
    steps: [ ['Выберите окно', 'Откройте Chrome и свяжите ярлык с нужным окном.'], ['Добавьте характер', 'Задайте имя, фотографию или знакомый логотип.'], ['Перенесите в Dock', 'Создайте ярлык и перетащите его из Finder в Dock.'] ],
    beta: 'Это первая бета', betaText: 'Ярлык связан с конкретным окном. После его закрытия или переименования может понадобиться перепривязка. В сборке есть Apple Silicon и Intel; запуск проверен на Apple Silicon. Полноэкранный режим и разные рабочие столы ещё проверяем.',
    install: 'Сборка пока без нотариализации Apple. macOS может запросить подтверждение запуска. Подробности установки и ограничения — на странице выпуска.',
    release: 'Установка и примечания к выпуску', foot: 'Маленький открытый проект для повседневного удобства.', license: 'Лицензия MIT', language: 'Switch to English',
  },
  en: {
    source: 'Source code', badge: 'A LITTLE UTILITY FOR macOS', line1: 'Seven profiles.', line2: 'One click away.',
    intro: 'Your Chrome windows are already open. Give each one a familiar Dock icon and bring the right window forward with one click.',
    download: 'Download Mac beta', details: 'Free · Open source · macOS 13+',
    demo: 'Try it: choose an icon', demoNote: 'An interactive demonstration. Your browser stays unchanged.',
    profiles: ['Work', 'Personal', 'Project'], tab: 'Your working window', ready: 'Every tab, right where you left it',
    benefits: [ ['The window you want', 'Keeps your tabs, window sizes and positions.'], ['Icons you recognize', 'Your pictures, custom names and website icons.'], ['At home on your Mac', 'No account, browser extension or analytics.'] ],
    setup: 'Set up once. Switch every day.',
    steps: [ ['Choose a window', 'Open Chrome and link a shortcut to the window you want.'], ['Make it familiar', 'Pick a name, a photo or a recognizable logo.'], ['Keep it in the Dock', 'Create the shortcut and drag it from Finder into your Dock.'] ],
    beta: 'An early beta', betaText: 'Each shortcut links to one specific window. Closing or renaming it may require reconnecting. The build includes Apple Silicon and Intel; runtime testing was on Apple Silicon. Fullscreen and multiple Spaces need more testing.',
    install: 'This build is not yet notarized by Apple. macOS may require approval before opening it. See the release page for installation details and limitations.',
    release: 'Installation and release notes', foot: 'A small open project for an easier everyday workflow.', license: 'MIT license', language: 'Переключить на русский',
  },
};

export default function Home() {
  const [language, setLanguage] = useState<'ru' | 'en'>('ru');
  const [selected, setSelected] = useState(0);
  const t = copy[language];
  useEffect(() => { document.documentElement.lang = language; }, [language]);
  const symbols = ['W', 'P', '✦'];
  const BenefitIcons = [MousePointer2, ImageIcon, LockKeyhole];
  return (
    <main>
      <a className="skip-link" href="#download">{t.download}</a>
      <header className="site-header wrap">
        <a className="brand" href="#" aria-label="ProfileDock"><img src="/ProfileDock/icon.svg" width="36" height="36" alt=""/>ProfileDock<span className="beta-tag">BETA</span></a>
        <nav aria-label={language === 'ru' ? 'Навигация' : 'Navigation'}>
          <a className="source-link" href={repo}><ArrowUpRight size={18}/><span>{t.source}</span></a>
          <Button variant="ghost" className="lang-button" aria-label={t.language} onClick={() => setLanguage(language === 'ru' ? 'en' : 'ru')}>{language === 'ru' ? 'EN' : 'RU'}</Button>
        </nav>
      </header>
      <section className="hero wrap">
        <div className="hero-copy">
          <p className="eyebrow"><span/> {t.badge}</p>
          <h1>{t.line1}<br/><em>{t.line2}</em></h1>
          <p className="intro">{t.intro}</p>
          <a id="download" className="download" href={`${repo}/releases/tag/v0.1.0-beta`}><ArrowDown size={20}/>{t.download}<ArrowUpRight size={18}/></a>
          <p className="download-detail">{t.details}</p>
        </div>
        <div className="demo">
          <div className="windows" aria-live="polite">
            {t.profiles.map((name, i) => (
              <div className={`demo-window tone-${i} ${selected === i ? 'is-front' : ''}`} key={i} style={{ zIndex: selected === i ? 5 : i + 1 }} aria-hidden={selected !== i}>
                <div className="window-toolbar"><span className="traffic"><i/><i/><i/></span><span>{name}</span><PanelsTopLeft size={15}/></div>
                <div className="window-content"><div className={`profile-avatar tone-${i}`}>{symbols[i]}</div><span className="window-kicker">{t.tab}</span><strong>{name}</strong><p><Check size={15}/>{t.ready}</p><div className="window-lines" aria-hidden="true"><span/><span/><span/></div></div>
              </div>
            ))}
          </div>
          <p className="try-label">{t.demo}</p>
          <div className="demo-dock" aria-label={t.demo}>
            {t.profiles.map((name, i) => <Button key={i} className={`dock-icon tone-${i}`} aria-label={name} aria-pressed={selected === i} onClick={() => setSelected(i)}><span aria-hidden="true">{symbols[i]}</span><span className="dock-tooltip">{name}</span></Button>)}
          </div>
          <p className="demo-note">{t.demoNote}</p>
        </div>
      </section>
      <section className="benefits wrap" aria-label={language === 'ru' ? 'Возможности' : 'Features'}>
        {t.benefits.map(([title, text], i) => {const Icon = BenefitIcons[i]; return <article key={title}><Icon size={22}/><div><h2>{title}</h2><p>{text}</p></div></article>;})}
      </section>
      <section className="setup wrap">
        <h2>{t.setup}</h2>
        <div className="steps">{t.steps.map(([title, text], i) => <article key={title}><span className="step-number">0{i+1}</span><h3>{title}</h3><p>{text}</p></article>)}</div>
      </section>
      <section className="beta-note wrap"><div className="beta-heading"><span className="beta-tag">0.1</span><h2>{t.beta}</h2></div><p>{t.betaText}</p><p>{t.install}</p><a href={`${repo}/releases/tag/v0.1.0-beta`}>{t.release}<ArrowUpRight size={16}/></a></section>
      <footer className="wrap"><p>{t.foot}</p><a href={`${repo}/blob/main/LICENSE`}>{t.license}<ArrowUpRight size={14}/></a></footer>
    </main>
  );
}
