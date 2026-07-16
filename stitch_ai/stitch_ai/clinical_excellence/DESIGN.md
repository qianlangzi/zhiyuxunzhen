---
name: Clinical Excellence
colors:
  surface: '#f9f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f9f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e2e4'
  on-surface: '#191c1d'
  on-surface-variant: '#40484b'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#70787c'
  outline-variant: '#c0c8cb'
  surface-tint: '#306576'
  primary: '#003441'
  on-primary: '#ffffff'
  primary-container: '#0f4c5c'
  on-primary-container: '#87bbce'
  inverse-primary: '#9acee1'
  secondary: '#5a5f62'
  on-secondary: '#ffffff'
  secondary-container: '#dce0e3'
  on-secondary-container: '#5e6366'
  tertiary: '#2d3031'
  on-tertiary: '#ffffff'
  tertiary-container: '#434647'
  on-tertiary-container: '#b2b4b5'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b6ebfe'
  primary-fixed-dim: '#9acee1'
  on-primary-fixed: '#001f28'
  on-primary-fixed-variant: '#114d5d'
  secondary-fixed: '#dfe3e6'
  secondary-fixed-dim: '#c3c7ca'
  on-secondary-fixed: '#171c1f'
  on-secondary-fixed-variant: '#43474a'
  tertiary-fixed: '#e1e3e4'
  tertiary-fixed-dim: '#c5c7c8'
  on-tertiary-fixed: '#191c1d'
  on-tertiary-fixed-variant: '#454748'
  background: '#f9f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e2e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  medical-data:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 20px
  stack-gap-sm: 8px
  stack-gap-md: 16px
  stack-gap-lg: 24px
  section-margin: 40px
---

## Brand & Style

This design system is engineered for high-stakes medical education, prioritizing cognitive clarity, authority, and emotional calm. The aesthetic is a refined evolution of iOS minimalism, stripped of decorative excess to ensure the medical content remains the primary focus.

The experience is defined by:
- **Clinical Precision:** Every element aligns to a rigorous grid, mirroring the discipline of medical practice.
- **High-End Utility:** Luxe whitespace and exquisite typesetting create an atmosphere of premium academic exclusivity.
- **Identity Dualism:** Subtle yet distinct color-coding differentiates Student and Teacher environments without breaking the overall cohesive clinical aesthetic.
- **Micro-interactions:** Transitions should be snappy and linear (150ms-250ms), suggesting efficiency and reliability.

## Colors

The palette is anchored by **Deep Teal Blue**, a color chosen for its association with medical stability and institutional trust. 

- **Surface Strategy:** Use **Paper White** for primary content containers and **Mist Gray** for global backgrounds to create a "layered paper" effect that reduces eye strain during long study sessions.
- **Functional Accents:** **Emerald** and **Coral Red** are reserved strictly for status-driven feedback (correct/incorrect answers, critical alerts).
- **Identity Tints:** Use **Light Cyan** (Student) and **Deep Gold** (Teacher) sparingly—primarily for profile avatars, progress bars, and subtle role-based badges to provide environmental context.

## Typography

The typography system prioritizes legibility of complex medical terminology. 

- **Primary Stack:** Inter is used as a highly legible alternative to SF Pro, providing a neutral, systematic feel for both English and numeric data. It should be paired with **PingFang SC** for Chinese characters to maintain a native iOS feel.
- **Data Clarity:** **JetBrains Mono** is utilized for medical lab values, dosages, and diagnostic codes to ensure every character is distinct and unambiguous.
- **Hierarchy:** Use heavy weight (600+) for headlines to create clear section breaks, while keeping body text at a comfortable 17px for long-form case studies.

## Layout & Spacing

This design system follows a strict 4px baseline grid. On mobile, it utilizes a fluid layout with generous horizontal margins (20px) to prevent content from feeling cramped.

- **Whitespace:** Use whitespace as a functional tool to separate distinct medical concepts. Increase `section-margin` to 40px between unrelated content blocks.
- **Component Padding:** Elements within cards should maintain a consistent 16px internal padding. 
- **Grids:** For tablet views, transition to a 12-column grid; for mobile, use a single-column stack with 16px vertical gutters between cards.

## Elevation & Depth

To maintain a professional, clinical look, this design system avoids heavy drop shadows. Depth is communicated through **Tonal Layering** and **Subtle Outlines**.

- **Surface Tiers:** Use the contrast between **Mist Gray** (Level 0) and **Paper White** (Level 1) to denote interactable areas.
- **Borders:** All cards and input fields must use a 1px solid border in a slightly darker shade of Mist Gray (#D1D9DE) instead of a shadow.
- **Active State:** When an element is pressed, use a subtle 2% inner darken or a 1px border weight increase to Deep Teal Blue. 
- **Modals:** For high-priority overlays, use a backdrop blur (20px) with a 40% opacity black tint to focus the user's attention.

## Shapes

The shape language is "Soft-Precision." It balances the friendliness required for learning with the sharpness expected in a professional environment.

- **Corner Radius:** A standard 12px (`rounded-lg`) radius is applied to all primary cards and buttons. Smaller components like tags or checkboxes use a 4px (`rounded-sm`) radius.
- **Icons:** Use linear icons with a consistent 2px stroke weight. Avoid filled icons unless indicating an "active" bottom navigation state.

## Components

### Buttons
- **Primary:** Deep Teal Blue background with White text. 12px rounded corners.
- **Secondary:** Transparent background with a 1px Deep Teal Blue border.
- **Ghost:** Text-only for low-priority actions, using Deep Teal Blue with medium weight.

### Cards
- Always **Paper White** background with a 1px Mist Gray border. No shadow.
- Internal padding of 16px or 20px depending on content density.

### Input Fields
- Background is **Mist Gray** (50% opacity) or White.
- Label text uses `label-caps` style sitting 8px above the input.
- Focus state: Border changes to Deep Teal Blue with a 1px thickness.

### Medical Chips
- Use for tags like "Cardiology" or "Emergency."
- 4px corner radius.
- Light Teal background with Deep Teal Blue text for Students; Light Gold background with Deep Gold text for Teachers.

### List Items
- 64px minimum height for touch targets.
- Separated by 1px Mist Gray dividers that inset 20px from the left to align with text.