import css from "./styles.css?raw"

const sansStack = 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'

describe("styles", () => {
  it("uses the kora_theme heading font with the body stack as fallback", () => {
    expect(css).toContain(`font-family: var(--font-heading, var(--font-sans, ${sansStack}));`)
  })

  it("does not hardcode font stacks outside theme variables", () => {
    const declarations = css.match(/font-family:[^;]+;/g) ?? []
    expect(declarations.length).toBeGreaterThan(0)
    for (const declaration of declarations) expect(declaration).toMatch(/^font-family: var\(--font-/)
  })
})
