---
name: Clinical Excellence Premium
colors:
  surface: '#f8fafb'
  surface-dim: '#d8dadb'
  surface-bright: '#f8fafb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f5'
  surface-container: '#eceeef'
  surface-container-high: '#e6e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#40484b'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#eff1f2'
  outline: '#70787c'
  outline-variant: '#c0c8cb'
  surface-tint: '#306576'
  primary: '#003441'
  on-primary: '#ffffff'
  primary-container: '#0f4c5c'
  on-primary-container: '#87bbce'
  inverse-primary: '#9acee1'
  secondary: '#4a6364'
  on-secondary: '#ffffff'
  secondary-container: '#cde8e9'
  on-secondary-container: '#50696a'
  tertiary: '#472800'
  on-tertiary: '#ffffff'
  tertiary-container: '#673c00'
  on-tertiary-container: '#fd9e1a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b6ebfe'
  primary-fixed-dim: '#9acee1'
  on-primary-fixed: '#001f28'
  on-primary-fixed-variant: '#114d5d'
  secondary-fixed: '#cde8e9'
  secondary-fixed-dim: '#b1cbcd'
  on-secondary-fixed: '#051f20'
  on-secondary-fixed-variant: '#334b4c'
  tertiary-fixed: '#ffdcbc'
  tertiary-fixed-dim: '#ffb86b'
  on-tertiary-fixed: '#2c1700'
  on-tertiary-fixed-variant: '#683d00'
  background: '#f8fafb'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  headline-xl:
    fontFamily: PingFang SC, Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: PingFang SC, Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: '1.3'
  headline-md:
    fontFamily: PingFang SC, Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: PingFang SC, Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: PingFang SC, Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-md:
    fontFamily: PingFang SC, Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.01em
  headline-xl-mobile:
    fontFamily: PingFang SC, Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: '1.2'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 32px
  gutter: 24px
  card-padding: 24px
  section-gap: 48px
---

## Brand & Style

The design system is engineered for a high-end medical education platform, catering to healthcare professionals and medical students who demand precision, clarity, and a sense of prestige. The brand personality is authoritative yet approachable, blending clinical rigor with a modern, fluid digital experience.

The design style leans into **Modern Professionalism** with a heavy influence from **iOS-style Glassmorphism** and **Soft UI**. By moving away from a flat, clinical aesthetic, the system employs layered depth, high-quality typography, and generous negative space to evoke a "concierge-level" educational experience. The goal is to reduce cognitive load while maintaining an atmosphere of institutional excellence.

## Colors

The palette is anchored by **Deep Teal (#0F4C5C)**, representing stability and clinical expertise. To elevate the "premium" feel, we introduce a sophisticated neutral scale that leans slightly cool to maintain a sterile, clean environment.

- **Primary (Deep Teal):** Used for key actions, navigation headers, and authoritative branding elements.
- **Secondary (Soft Azure):** Used for light backgrounds of active states and highlights, providing a gentle contrast to the deep primary.
- **Surface Neutrals:** We use `#F8FAFB` for the main canvas and `#FFFFFF` for elevated cards, ensuring a clear distinction between the workspace and the content.
- **Semantic Accents:** Functional colors (success, error, warning) are desaturated and softened to prevent them from feeling "alarming" in a high-stress medical context.

## Typography

Typography is the cornerstone of clinical precision. This design system utilizes **PingFang SC** as the primary typeface for all Chinese text to ensure native clarity on Apple devices and high-end displays. It is paired with **Plus Jakarta Sans** for numerical data and English headings to provide a modern, geometric flair.

The hierarchy is intentionally steep. Large headlines use a semi-bold weight to establish clear entry points for reading. Body text maintains a generous line-height (1.6) to improve legibility during long-form medical case studies. For mobile devices, headline sizes are scaled down to prevent excessive word-breaking while maintaining the bold "editorial" feel.

## Layout & Spacing

The layout philosophy follows a **Fixed-Fluid Hybrid** model. On desktop, content is centered within a 1280px max-width container to maintain focus. On tablet and mobile, the layout shifts to a fluid grid with generous margins.

- **Desktop:** 12-column grid, 24px gutters, 32px side margins.
- **Mobile:** 4-column grid, 16px gutters, 20px side margins.

Spacing is based on a **4px base unit**. To achieve the "premium" aesthetic, the design system mandates significant whitespace between logical sections (48px+) and emphasizes internal padding within cards (24px) to ensure content never feels cramped.

## Elevation & Depth

Depth is conveyed through **Tonal Layering** and **Ambient Shadows**. This design system avoids harsh drop shadows in favor of multi-layered, low-opacity blurs that mimic natural light.

1.  **Level 0 (Base):** The canvas background (#F8FAFB).
2.  **Level 1 (Cards/Surfaces):** Pure white surfaces with a soft "Looming Shadow" (0px 4px 20px rgba(15, 76, 92, 0.04)).
3.  **Level 2 (Interaction/Popovers):** Elements that float above the grid use a more defined shadow and a subtle 1px border (#E0FBFC) to maintain crispness without high contrast.

Background blurs (20px-30px) are used for navigation bars and modal overlays to create a sense of vertical space and transparency, typical of premium medical software.

## Shapes

The shape language is defined by **High-Radius Curvature**. To achieve a soft, modern feel, the system moves away from traditional 8px corners toward a more organic 16px (standard) and 24px (large) radius.

- **Standard Elements (Buttons, Inputs):** 12px or 16px radius.
- **Container Elements (Cards, Modals):** 24px radius.
- **Feature Elements:** Occasional use of fully rounded (pill) shapes for status indicators and tags.

This curvature is designed to feel friendly and human-centric, counterbalancing the coldness often associated with medical data.

## Components

### Buttons
Primary buttons utilize the Deep Teal fill with white text and a 16px corner radius. Secondary buttons should use a subtle Azure tint (#E0FBFC) with Teal text. Hover states should involve a slight lift (elevation increase) rather than just a color change.

### Cards
Cards are the primary content vessel. They must feature 24px internal padding and 24px corner radius. The border should be non-existent or a very faint 1px stroke in a secondary color to define the edge against white backgrounds.

### Inputs & Selectors
Form fields use a soft grey background (#F1F3F5) with a 12px radius. On focus, the border transitions to Deep Teal with a subtle outer glow. Label text (Chinese) should be positioned above the field in a Medium weight.

### Chips & Tags
Used for medical categories or status. These should be pill-shaped with 32px radius and utilize low-saturation background colors to keep the UI from feeling cluttered.

### Lists
List items should have generous vertical padding (16px) and be separated by soft dividers or subtle tonal shifts rather than heavy lines. Each item should have a 12px radius on hover to indicate interactivity.