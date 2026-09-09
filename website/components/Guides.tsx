import type { ReactNode } from "react";
import { ArrowRight, ArrowUpRight, BookOpen, Check, Download, LifeBuoy } from "lucide-react";
import { guideCopy, guideMetadata, guidePath, guides, guideSlugs, type Guide, type GuideSlug } from "@/lib/guides";
import { guideDataFor, languageURLs, releaseURL, repositoryURL, serializeJSONLD, type SiteLanguage } from "@/lib/seo";

function GuideShell({ language, slug, children }: { language: SiteLanguage; slug?: GuideSlug; children: ReactNode }) {
  const t = guideCopy[language];
  const otherLanguage = language === "ru" ? "en" : "ru";
  const home = language === "ru" ? "/ProfileDock/" : "/ProfileDock/en/";
  return <>
    <a className="skip-link" href="#content">{t.skip}</a>
    <header className="site-header guide-header wrap">
      <a className="brand" href={home} aria-label="ProfileDock">
        <img src="/ProfileDock/icon.svg" width="34" height="34" alt="" />
        ProfileDock<span className="beta-tag">BETA</span>
      </a>
      <nav aria-label={t.nav}>
        <a className="guide-nav-home" href={home}>{t.home}</a>
        <a href={guidePath(language)} aria-current={!slug ? "page" : undefined}>{t.hub}</a>
        <a className="lang-button" href={guidePath(otherLanguage, slug)} hrefLang={otherLanguage} lang={otherLanguage}
          aria-label={language === "ru" ? "Read this page in English" : "Читать эту страницу на русском"}>{otherLanguage.toUpperCase()}</a>
      </nav>
    </header>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: serializeJSONLD(guideDataFor(language, guideMetadata(language, slug))) }} />
    <main id="content" className="guide-main wrap">
      <nav className="guide-breadcrumbs" aria-label={language === "ru" ? "Хлебные крошки" : "Breadcrumb"}>
        <ol>
          <li><a href={home}>ProfileDock</a></li>
          <li>{slug ? <a href={guidePath(language)}>{t.hub}</a> : <span aria-current="page">{t.hub}</span>}</li>
          {slug && <li><span aria-current="page">{guides[language][slug].category}</span></li>}
        </ol>
      </nav>
      {children}
      <section className="guide-download" aria-labelledby="guide-download-title">
        <div><h2 id="guide-download-title">{t.ctaTitle}</h2><p>{t.ctaBody}</p></div>
        <div className="guide-download-action">
          <a className="button button-primary" href={releaseURL}><Download size={17} aria-hidden="true" />{t.download}</a>
          <p>{t.beta}</p>
        </div>
      </section>
    </main>
    <footer className="guide-footer wrap">
      <a className="footer-brand" href={home}>ProfileDock</a>
      <div className="footer-links">
        <a href={guidePath(language)}>{t.hub}</a>
        <a href={`${home}#privacy`}>{t.privacy}</a>
        <a href={repositoryURL}>GitHub <ArrowUpRight size={13} aria-hidden="true" /></a>
      </div>
    </footer>
  </>;
}

function GuideCard({ language, guide }: { language: SiteLanguage; guide: Guide }) {
  const isSetup = guide.slug === "chrome-profile-shortcuts-mac-dock";
  const Icon = isSetup ? BookOpen : LifeBuoy;
  return <article className="guide-card">
    <div className={`guide-card-icon ${isSetup ? "" : "guide-card-icon-peach"}`}><Icon size={24} aria-hidden="true" /></div>
    <p className="guide-category">{guide.category}</p>
    <h2><a href={guidePath(language, guide.slug)}>{guide.shortTitle}</a></h2>
    <p>{guide.summary}</p>
    <a className="text-link" href={guidePath(language, guide.slug)}>{guideCopy[language].read}<ArrowRight size={16} aria-hidden="true" /></a>
  </article>;
}

export function GuideHub({ language }: { language: SiteLanguage }) {
  const t = guideCopy[language];
  return <GuideShell language={language}>
    <section className="guide-hub-intro">
      <p className="eyebrow">CHROME × macOS · {t.hub.toUpperCase()}</p>
      <h1>{t.heading}</h1>
      <p>{t.intro}</p>
    </section>
    <div className="guide-card-grid">{guideSlugs.map(slug => <GuideCard key={slug} language={language} guide={guides[language][slug]} />)}</div>
    <div className="guide-hub-note"><Check size={18} aria-hidden="true" /><p>{t.version}. <a href={`${languageURLs[language]}#privacy`}>{t.privacy}<ArrowUpRight size={13} aria-hidden="true" /></a></p></div>
  </GuideShell>;
}

export function GuideArticle({ language, slug }: { language: SiteLanguage; slug: GuideSlug }) {
  const guide = guides[language][slug];
  const t = guideCopy[language];
  const related = guides[language][guideSlugs.find(other => other !== slug)!];
  return <GuideShell language={language} slug={slug}>
    <article className="guide-article">
      <header className="guide-article-heading">
        <p className="eyebrow">{guide.category}</p>
        <h1>{guide.title}</h1>
        <p className="guide-lead">{guide.summary}</p>
        <div className="guide-byline"><time dateTime="2026-09-09">{t.published}</time><span>{t.version}</span></div>
      </header>
      <div className="guide-reading-layout">
        <aside className="guide-toc" aria-label={t.toc}>
          <p>{t.toc}</p>
          <nav><ol>{guide.sections.map(section => <li key={section.id}><a href={`#${section.id}`}>{section.title}</a></li>)}</ol></nav>
          <a className="guide-toc-privacy" href={`${languageURLs[language]}#privacy`}>{t.privacy}<ArrowUpRight size={13} aria-hidden="true" /></a>
        </aside>
        <div className="guide-prose">
          <p className="guide-takeaway">{guide.takeaway}</p>
          {guide.sections.map((section, index) => <div key={section.id}>
            <section id={section.id} aria-labelledby={`${section.id}-heading`}>
              <h2 id={`${section.id}-heading`}>{section.title}</h2>
              {section.paragraphs?.map(paragraph => <p key={paragraph}>{paragraph}</p>)}
              {section.steps && <ol className="guide-steps">{section.steps.map(step => <li key={step.title}><h3>{step.title}</h3><p>{step.body}</p></li>)}</ol>}
              {section.points && <div className="guide-symptoms">{section.points.map(point => <div key={point.title}><h3>{point.title}</h3><p>{point.body}</p></div>)}</div>}
            </section>
            {slug === "chrome-profile-shortcuts-mac-dock" && index === 2 && <figure className="guide-figure">
              <img src="/ProfileDock/app-preview.jpg" alt={t.figureAlt} width="940" height="692" loading="lazy" />
              <figcaption>{t.figureCaption}</figcaption>
            </figure>}
          </div>)}
          <section className="guide-sources" aria-labelledby="guide-sources-title">
            <h2 id="guide-sources-title">{t.sources}</h2>
            <ul>{guide.sources.map(source => <li key={source.href}><a href={source.href}>{source.title}<ArrowUpRight size={13} aria-hidden="true" /></a></li>)}</ul>
          </section>
          <div className="guide-feedback"><a href={`${repositoryURL}/issues/new/choose`}>{t.feedback}<ArrowUpRight size={14} aria-hidden="true" /></a><p>{t.feedbackHint}</p></div>
          <aside className="guide-related" aria-labelledby="guide-related-title">
            <p className="guide-category" id="guide-related-title">{t.related}</p>
            <h2><a href={guidePath(language, related.slug)}>{related.shortTitle}<ArrowRight size={20} aria-hidden="true" /></a></h2>
            <p>{related.summary}</p>
            <a className="text-link" href={guidePath(language)}>{t.allGuides}<ArrowRight size={15} aria-hidden="true" /></a>
          </aside>
        </div>
      </div>
    </article>
  </GuideShell>;
}
