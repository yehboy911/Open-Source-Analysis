# HTML Rendering Preferences

## Design System
- **Style:** GitHub README-inspired, monochrome minimalist
- **Font:** System font stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif`)
- **Code Font:** `"SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace`

## Color Palette
| Token | Light Mode | Dark Mode |
|---|---|---|
| Background | `#ffffff` | `#0d1117` |
| Surface | `#f6f8fa` | `#161b22` |
| Border | `#d0d7de` | `#30363d` |
| Text Primary | `#1f2328` | `#e6edf3` |
| Text Secondary | `#656d76` | `#8b949e` |
| Accent (links) | `#0969da` | `#58a6ff` |
| Code Background | `#eff1f3` | `#1b1f24` |

## Layout Rules
- Max content width: `960px`, centered with `margin: 0 auto`
- Line height: `1.6` for body text
- Heading scale: h1 `2em`, h2 `1.5em`, h3 `1.25em`
- Paragraph spacing: `16px` margin-bottom
- Table borders: `1px solid` using Border token, no outer border collapse

## Component Defaults
- **Tables:** Full-width, alternating row shading using Surface token
- **Code blocks:** Rounded corners (`6px`), padding `16px`, horizontal scroll on overflow
- **Blockquotes:** Left border `3px solid` Accent, padding-left `16px`
- **Links:** Accent color, no underline on hover

## Do NOT Use
- Background gradients or shadows
- Multi-color schemes or brand palette
- Icon libraries (keep it text-only unless explicitly requested)
- Animations or transitions
