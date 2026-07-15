---
name: Wildwood Adventure
colors:
  surface: '#fff8f0'
  surface-dim: '#ebd9ab'
  surface-bright: '#fff8f0'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff3d8'
  surface-container: '#ffedbe'
  surface-container-high: '#f9e7b8'
  surface-container-highest: '#f3e1b3'
  on-surface: '#231b00'
  on-surface-variant: '#434840'
  inverse-surface: '#3a2f0f'
  inverse-on-surface: '#fff0cb'
  outline: '#74796f'
  outline-variant: '#c3c8bd'
  surface-tint: '#4a6640'
  primary: '#38532f'
  on-primary: '#ffffff'
  primary-container: '#4f6b45'
  on-primary-container: '#caeabb'
  inverse-primary: '#b0d0a2'
  secondary: '#6a5d3b'
  on-secondary: '#ffffff'
  secondary-container: '#f0deb3'
  on-secondary-container: '#6f613f'
  tertiary: '#7d3802'
  on-tertiary: '#ffffff'
  tertiary-container: '#9b4f1b'
  on-tertiary-container: '#ffdac6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#cbecbc'
  primary-fixed-dim: '#b0d0a2'
  on-primary-fixed: '#082104'
  on-primary-fixed-variant: '#334d2a'
  secondary-fixed: '#f3e1b6'
  secondary-fixed-dim: '#d6c59c'
  on-secondary-fixed: '#231a02'
  on-secondary-fixed-variant: '#514626'
  tertiary-fixed: '#ffdbc9'
  tertiary-fixed-dim: '#ffb68c'
  on-tertiary-fixed: '#321200'
  on-tertiary-fixed-variant: '#753400'
  background: '#fff8f0'
  on-background: '#231b00'
  surface-variant: '#f3e1b3'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '800'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Quicksand
    fontSize: 18px
    fontWeight: '600'
    lineHeight: '1.5'
  body-md:
    fontFamily: Quicksand
    fontSize: 16px
    fontWeight: '500'
    lineHeight: '1.5'
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: '1.2'
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1.2'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  gutter: 16px
  margin-mobile: 16px
  margin-tablet: 32px
  margin-desktop: 48px
---

## Brand & Style

The design system is built to evoke a sense of cozy wonder, adventure, and community within a whimsical forest setting. The target audience is young explorers who value creativity, social interaction, and a "home away from home" atmosphere.

The visual style is **Tactile / Skeuomorphic** with a heavy influence from hand-painted textures and "low-poly" smoothness. UI elements should feel like physical objects found in a woodland workshop—carved wood, parchment, and soft fabrics. The emotional response should be one of warmth and safety, achieved through soft lighting effects, rounded corners, and a saturated, earthy color palette.

## Colors

The palette is derived from the natural elements of a sun-drenched forest. 

- **Forest Green (#4F6B45):** Used for primary actions, success states, and lush UI backgrounds.
- **Earth Brown (#6B5E3C):** Used for structural elements like borders, headers, and heavy containers to ground the UI.
- **Cream (#EBD9AB):** The primary surface color, acting as "parchment" or "canvas" for information.
- **Muted Orange (#D98048):** Reserved for notifications, special discovery markers, and warm highlights.
- **Golden Yellow (#F6D77A):** Used for currency, stars, and celebratory UI feedback.
- **Slate Blue (#6FA0B1):** Used for secondary utility items, night-mode transitions, or water-related icons.

## Typography

This design system utilizes **Plus Jakarta Sans** for headlines and labels to maintain a friendly, modern, and highly legible appearance. **Quicksand** is used for body text to take advantage of its rounded terminals, which reinforce the "whimsical" and "soft" nature of the game world.

- **Headlines:** Should always use high-weight variations. On larger displays, apply a subtle dark-brown text shadow (2px) to enhance the "carved" look.
- **Body:** Keeps a slightly heavier weight (500-600) than standard web text to ensure readability against textured, parchment-style backgrounds.
- **Mobile Scaling:** Headline sizes should scale down by 20% on mobile devices, ensuring high-impact titles do not crowd the viewport.

## Layout & Spacing

The layout follows a **Fluid Grid** model to accommodate the varied aspect ratios of Roblox players (from mobile phones to ultra-wide monitors).

- **Spacing Rhythm:** Based on an 8px base unit. 
- **Safe Zones:** Use generous margins (48px on desktop) to ensure UI elements do not interfere with the 3D character view.
- **Reflow Rules:** On mobile, side-panels should transform into full-screen overlays with a "bottom-sheet" slide animation to maintain the tactile feel.
- **Padding:** Containers should use generous internal padding (min 24px) to avoid a cramped "technical" look, favoring a spacious, "breathable" forest vibe.

## Elevation & Depth

Visual hierarchy is established through **Tonal Layers** and **Tactile Shadows**. 

- **Surfaces:** Use "Cream" as the base surface. Higher-elevation elements (like modal pop-ups) use a slightly lighter cream with a subtle "paper" texture overlay.
- **Shadows:** Avoid pure black. Use a "Dark Earth Brown" (#4A3F29) for shadows with a high blur radius (12-20px) and low opacity (20%). This mimics the soft, ambient occlusion found in a forest canopy.
- **Inner Glows:** Buttons and active containers use a soft inner glow (Golden Yellow) to suggest they are "magical" or "illuminated" by the game's warm lighting.

## Shapes

The shape language is consistently **Rounded**. There are no sharp corners in this design system, mirroring the "smooth low-poly" 3D assets of the game.

- **Standard Elements:** Use a 0.5rem radius.
- **Large Containers/Cards:** Use a 1rem radius to feel substantial yet soft.
- **Interactive Elements:** Buttons and tags should lean towards "pill-shaped" (2rem+) to encourage clicking and interaction.

## Components

- **Buttons:** Primary buttons use Forest Green with an Earth Brown bottom border (3px) to create a 3D "pressed" effect. Text is always white or cream.
- **Chips/Tags:** Used for resource counts (wood, gold). These feature a Slate Blue or Muted Orange background with a small icon prefix.
- **Input Fields:** Styled like carved wooden slots. Earth Brown stroke (2px) with a Cream inset background and Quicksand placeholder text.
- **Cards:** Used for shop items and quest logs. Cards feature a hand-painted border texture and a subtle Golden Yellow glow on hover.
- **Inventory Slots:** Square-ish slots with highly rounded corners (0.75rem), using a "Dark Earth Brown" inset shadow to make items look like they are sitting inside a wooden tray.
- **Progress Bars:** Thick, rounded bars. The background is Earth Brown, and the fill is a gradient of Forest Green to Golden Yellow, resembling a growing vine or sunbeam.