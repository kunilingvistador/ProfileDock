# Comparable tools and ProfileDock's scope

Research date: **7 September 2026**. This is a design reference, not a claim that ProfileDock is the first or best product in this category.

The comparison uses official product pages, documentation, release notes and public repository metadata. Competitor applications were **not installed or tested**. “Advertised” means a vendor documents the behavior; “not documented” means it was not found in the reviewed sources. Absence from this comparison is not proof that a feature is unavailable.

## Where ProfileDock fits

ProfileDock focuses on recognizable Dock shortcuts for **existing Chrome windows**. Its intended default is to focus one selected window without creating a blank window, resizing other windows, or minimizing other profiles. A missing or ambiguous target should produce a useful repair path.

Separate Dock shortcuts, custom images, and browser-profile tools already exist. The product opportunity is a small, freely reusable tool with straightforward setup, conservative switching and understandable recovery. This combination needs compatibility and usability testing; it is not a proven competitive advantage.

## Direct alternatives

| Capability | ProfileDock's intended scope | Chrome Hopping | DockSpark | Parall |
|---|---|---|---|---|
| Interaction | Click a distinct Dock shortcut | Menu bar, Dock apps, Spotlight | Hover a browser's Dock icon, choose a profile | Launch an independent instance from its Dock shortcut |
| Target | One explicitly bound existing window | All windows of the chosen profile | Browser profile; precise window-selection behavior not documented | Separate app instance; data isolation where supported |
| Placement | Preserve existing geometry | Advertised centering, 80% sizing, movement to cursor's display | Exact geometry policy not documented | Exact geometry policy not documented |
| Target absent | Explain and help repair | Launch the closed profile | Open profile/private window | Launch the configured instance |
| Appearance | Custom visible name and icon | Colored generated icons | Names, label colors and ordering | Custom icons, labels and effects |
| Breadth | Chrome first | Chrome | Several browser families | Browsers and many other macOS apps |

### Chrome Hopping

Chrome Hopping already offers automatic profile discovery, native Dock launchers, Spotlight access and keyboard cycling. Its grouping and window-placement behavior deliberately differs from ProfileDock's focus on preserving an existing arrangement. It advertises macOS 12+, Python 3.10+, Accessibility and Full Disk Access, and free personal use under PolyForm Noncommercial 1.0.0. We could not retrieve the linked repository/license file during this review, so these observations come from its product page. [Chrome Hopping](https://amirtito.com/chrome_hopping/)

### DockSpark

DockSpark offers a native hover panel, visual profile management, private-window actions, local configuration and support for several browsers. Its current site specifies macOS 14+. It requests Accessibility for Dock hovering and other permissions when needed, and uses TelemetryDeck usage analytics. [Features and FAQ](https://dockspark.app/en), [Chrome setup](https://dockspark.app/en/guide/chrome-profiles)

The current pricing page lists a one-time launch price of $4.99 for one Mac. Older documentation still describes a free beta; prices should be checked again before making a purchase decision. Its release notes describe permission recovery, preserved custom display names, data migration, signed/notarized downloads and updates. These are useful quality benchmarks for a distributable utility. [Pricing](https://dockspark.app/en/pricing), [release notes](https://dockspark.app/en/release-notes)

### Parall

Parall has a broader purpose: independent instances with their own Dock identity and data where supported. It includes custom names, images and icon labels, plus website, command, file and folder shortcuts. Its site advertises local operation without automatic telemetry or background services. Custom Dock pictures are therefore not a unique ProfileDock feature. [Parall](https://parall.app/)

The FAQ documents relevant lifecycle limits: generated shortcuts require regeneration to receive Parall fixes; some target applications can replace a custom Dock icon at runtime; using shortcuts alongside the original application can impose launch-order requirements. These are vendor-disclosed behaviors, not results of our testing. Parall's public repository is documentation and reserves all rights; being hosted on GitHub does not make an implementation open source. [FAQ](https://parall.app/faq/), [repository](https://github.com/JulyIghor/Parall)

## Adjacent products

**Choosy** and **Velja** mainly route links to a chosen browser or profile. Choosy offers prompts, routing rules, extensions and a URL API. Velja also supports source-app/domain rules, native-app routing, keyboard interaction and scripting. These products address a useful adjacent problem. Link routing need not be part of ProfileDock's first release, and the reviewed pages do not establish equivalent single-existing-window behavior. [Choosy](https://choosy.app/), [Velja](https://sindresorhus.com/velja)

## Requirements this comparison informs

- Keep one-window focus predictable; never guess between duplicate bindings or silently open a blank window.
- Separate a shortcut's display label, persistent identity and window binding. A Chrome window name is **not** proof of browser-profile membership.
- Make setup, icon selection, renaming and rebinding usable without Terminal.
- Centralize switching behavior so existing shortcuts benefit from fixes instead of retaining obsolete embedded scripts.
- Preserve custom appearance and working Dock references through edits and updates.
- Request only the permissions needed for a chosen feature. Existing-window focus does not itself require reading Chrome's profile folders or monitoring Dock hover.
- Test missing windows, duplicate names, revoked permissions, rapid activation, minimized windows and application restarts.
- Explicitly test or document limitations for Spaces, fullscreen, Stage Manager, multiple displays, supported macOS versions and CPU architectures.
- Provide reproducible builds and an honest install path. An ad-hoc signed local application is not equivalent to a Developer ID signed and notarized download.

All-window grouping, automatic launch of closed profiles, URL routing, other browsers and app-instance isolation expand the compatibility surface. They should follow evidence of demand rather than becoming prerequisites for the focused initial experience.

## Implementation provenance

No competitor implementation was downloaded or copied for this comparison. Chrome Hopping advertises a noncommercial license with purpose restrictions; it should not be silently relicensed as permissive open source. Parall reserves rights in its repository. ProfileDock should use its own implementation and documented platform interfaces with a clear license. [PolyForm Noncommercial terms](https://polyformproject.org/licenses/noncommercial/1.0.0), [Parall license notice](https://github.com/JulyIghor/Parall)

This document is a product comparison, not a runtime benchmark or a comprehensive legal analysis. Claims marked as intended ProfileDock behavior must be checked against the release's actual implementation and compatibility notes.
