# SwiftUI UI Rules for TreasuryOps

These rules govern all SwiftUI code written in this project. They are extracted **only** from `../xcode-27-system-prompts` — the Xcode 27 beta 5 AI-assistant system prompts and reference docs shipped inside `Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework`, published by Apple. They supersede any conflicting general SwiftUI knowledge.

Deployment target is **iOS 27.0** (`IPHONEOS_DEPLOYMENT_TARGET = 27.0`), so every SDK 27 API below applies unconditionally — no `#available`/`if #available` gating needed for them.

Sources: `swiftui-specialist*`, `swiftui-whats-new-27*`, `AdditionalDocumentation/SwiftUI-Implementing-Liquid-Glass-Design.md`, `AdditionalDocumentation/SwiftUI-New-Toolbar-Features.md`, `AdditionalDocumentation/Implementing-Assistive-Access-in-iOS.md`.

## View structure

- When a view has distinct sections (header/list/footer, content+counter, sidebar+detail), factor each section into its own `View` struct with narrow inputs — never a `private var section: some View` computed property or `@ViewBuilder` helper. Computed properties share the parent's invalidation boundary, so an unrelated state change re-evaluates every section; a separate `View` type only re-evaluates when its own inputs change. This applies to every `*DetailView`-shaped screen (header, gallery/list, description, footer/actions).
- Small fragments reused 2–3 times with no independent invalidation story can stay as computed properties — the rule targets factoring done to manage body length or "organize" the file.
- `init` runs every time the parent's body re-evaluates. Treat it as a cheap copy of already-prepared inputs into stored properties — never decode JSON, format dates, hit the filesystem, or allocate large structures there.
- Don't wrap a single concrete child in `Group { OneView() }` — it adds a type-checking cost to every chained modifier for no behavioral benefit. `Group` around a `ForEach`, a tuple of siblings, or an `if`/`else` is fine (it's not a single concrete child there).

## Data flow

- Value-type view inputs (`struct`s) are compared field-by-field: a view that takes a whole struct invalidates on **any** field change, even fields it never reads. Pass views only the fields they actually read (or forward to a subview) — never a full model struct "just in case."
- Large decoded payloads (big structs, arrays, nested JSON) are expensive to field-compare on every body evaluation. Either break the payload into small per-view structs, or hold it in an `@Observable` model and pass the model (reference comparison is cheap; per-property observation scopes invalidation further) — but watch the `@Observable` compound-property trap below.
- Always mark `@State` properties `private`.
- Use `@Observable` (not `ObservableObject`) for model classes — per-property tracking scopes invalidation to exactly the views that read the changed property.
- Mark `@Observable` classes `@MainActor` unless the project sets main-actor default isolation. Views read models on the main actor; unmarked models are reachable from any thread and background writes can race with reads.
- `@Observable` is not supported on `actor` types.
- Make stored property *types* on `@Observable` models `Equatable` where practical — the generated setter skips invalidation when the new value equals the old one, but only when it can compare them.
- Per-property tracking is at the **property** level, not the field/element level:
  - A stored `struct` property on an `@Observable` model creates a dependency on the whole struct when any field of it is read — flatten frequently-read struct fields into individual properties on the model instead.
  - A stored `Array`/`Dictionary`/`Set` property creates a dependency on the whole collection when any element is read.
  - A **computed** property still transitively depends on whatever it reads internally — renaming the access point doesn't narrow the dependency. Cache derived values as their own stored property, kept in sync via `didSet`, instead of a computed property that reads a wide collection.
- When a `ForEach` row reaches back into the model by index/key, every row depends on the whole collection. Pass each row only the field(s) it displays, or (for rows that read several fields) a **persisted** per-element `@Observable` instance — never a freshly-constructed one per body evaluation.
- Use KeyPath/subscript-based `Binding`s (`$model[someKey: x]`), not closure-based `Binding(get:set:)` — closures allocate on every body evaluation and can trigger unnecessary invalidation. Don't invent a subscript for an argument-less projection; use a plain computed property instead.
- If a dependency (`@Environment`, `@Binding`, an `@Observable` property) is read **only** for `.onChange` side effects — not rendering — and the enclosing view's body is non-trivial, extract the dependency + `.onChange` into a dedicated `ViewModifier` so only that modifier re-evaluates, not the expensive parent body.
- `@Entry` is the default way to declare custom `EnvironmentValues`/`Transaction`/`ContainerValues`/`FocusedValues` entries — prefer it over hand-written `EnvironmentKey` conformances, and call out the manual form as a top-line refactor when reviewing.

## Environment

- Never store closures (or a struct wrapping a closure) in a **custom** `@Entry`/`EnvironmentKey`/`FocusedValueKey`. Closures can't be reliably compared, so every reader invalidates on every write. Fix by defunctionalizing into a struct with `callAsFunction` (stateless/self-contained actions) or moving the behavior into an `@Observable` model (shared/coordinated state). This does **not** apply to framework-provided action types (`OpenURLAction`, `DismissAction`, `RefreshAction`, etc.) — those are meant to wrap closures.
- An `@Entry` (or manual `EnvironmentKey`) default must be **stable**: the same result on every read. `@Entry var model = Model()` and `static var defaultValue: T { Model() }` re-allocate on every fallback read, invalidating readers on every unrelated environment write. Fix with a `static let`-backed default, a manual key using `static let defaultValue`, or an `Optional` defaulting to `nil`. Literals, `nil`, enum cases, and references to a stable (`static`/module-level) instance are already stable — don't "fix" those defensively.
- If a reader checks the default for an "empty"/"absence" sentinel (`.id.isEmpty`, `== .none`, etc.), that's an absence check in disguise — use the `Optional` + `if let` fix, not a stable-instance workaround.
- Never route high-frequency values (scroll offset, drag position, live window size, per-frame animation progress, timers) through the environment — every write re-checks every environment reader in the subtree. Store them in an `@Observable` model and expose coarsened booleans/thresholds (e.g. `isWide`) instead of the raw value; for per-row visibility in a scrolling list, give each row its own `@Observable` item model rather than a shared offset/set that every row reads.
- Remove `@Environment(\.key)`/`@FocusedValue(\.key)` declarations that the view's body never reads — each one is a live subscription that re-evaluates the view on every write to that key. The type-form `@Environment(Model.self)` has no such cost when unused (observation is per-property), so removing it is dead-code cleanup, not a perf fix.

## ForEach / List / Table / Picker / OutlineGroup identity

- Identity must be **stable** (same id across body evaluations) and **unique**. Never use `.indices`, `\.offset`, or `id: \.self` on a value that isn't genuinely identity-like — reordering/filtering breaks the mapping and resets row state.
- `.enumerated()` is fine for getting a position alongside an element; just don't use the offset as the `id` — key off the element's own identity (`id: \.element.id`).
- Don't construct `Identifiable` values with a fresh `let id = UUID()` inside `body` — every body evaluation produces new ids and `ForEach` sees "the whole collection replaced." Synthesize ids once, in the model layer.
- Prefer `Identifiable` conformance on element types over always passing an explicit `id:` key path.
- Keep the `id` small and cheap to hash (`UUID`, `Int`, short `String`, `URL`) — never `id: \.self` on a large `Hashable` struct; that rehashes every field on every diff.
- An element's `id` must not change while the view showing it is alive — never derive `id` from a mutable/editable field (e.g. `var id: String { title }`); editing destroys and recreates the row, losing focus/state.
- Don't sort/filter/map inline inside `ForEach(...)` — that recomputes on every unrelated body evaluation. Cache the derived array in the model (recompute in `didSet`/mutators) or in `@State` updated via `.onChange`.
- Prefer **unary** row views in `List` (a single top-level container like `VStack`/`HStack`/`ZStack` wrapping any internal `switch`/`if`) — a row whose body branches at the top level (bare `switch`, top-level `if` with no `else`, or returns `AnyView`) defeats `List`'s id-templating fast path and forces SwiftUI to evaluate every row's body just to diff ids. Don't "fix" this by flattening branches into one shape with conditional modifiers — wrap in a container instead. Diagnose with the `-LogForEachSlowPath YES` launch argument.

## Conditional modifiers

- Never write an `.if(condition) { transform($0) } else { self }`-style `@ViewBuilder` conditional modifier — the two branches are different view types, so SwiftUI treats a condition toggle as replacing the view entirely: state resets, animations break. Use a ternary inside the modifier argument instead (`.foregroundStyle(isHighlighted ? .red : .primary)`).
- When ternary branches are different `ShapeStyle` types that won't unify (e.g. `.primary` vs `.tint`), wrap both in `AnyShapeStyle(...)` rather than branching the whole view. `AnyShapeStyle` is a cheap value-type erasure and is the correct tool here — it is not the discouraged `AnyView` pattern. Don't assume a style ternary fails to compile just because the style names differ (e.g. `isOn ? .yellow : .primary` compiles fine); only reach for `AnyShapeStyle` when it actually doesn't type-check.

## Localization

- Use String Catalogs (`.xcstrings`); don't create `.strings` files if the project already has a catalog.
- `Text`, `Button`, `.navigationTitle`, etc. auto-localize string literals — never wrap literals in `NSLocalizedString`, `String(localized:)`, or `LocalizedStringKey(_:)` at the call site.
- A `String` variable passed to `Text` is **not** localized (it hits the `StringProtocol` overload). To display one of a known set of localized strings, model it as an enum/type exposing `LocalizedStringResource`, not a raw `String`.
- Use string interpolation for compound strings (`Text("Error: \(msg)")`), never `+` concatenation or gluing separately-localized `Text` fragments — word order varies by language.
- Never transform case at runtime (`.textCase`, `.localizedUppercase` for a *localized* string) — bake the desired case into the string so translators can adjust per language. (User-typed input should display as-is.)
- Use `Text`'s `format:`/`.formatted()` for dates, numbers, currency, and lists — never hardcoded `DateFormatter`/`NumberFormatter` patterns or manual `joined(separator:)`.
- Use `.leading`/`.trailing`, never `.left`/`.right` (RTL). Don't hardcode text frame widths/heights. Use text styles (`.body`, `.title`, …), not fixed point sizes.
- Read `@Environment(\.locale)`, not `Locale.current`, inside views.
- Outside views, use `String(localized:)`, never `NSLocalizedString` with interpolation or `String(format:)`.
- Non-view types carrying user-facing text should type it `LocalizedStringResource`, not `String`, so resolution happens at display time.
- Add a `comment:` for ambiguous strings and describe interpolation placeholders by position, not Swift variable name.

## Animation

- Use the `@Animatable` macro on custom `View`/`Shape` types instead of hand-writing `animatableData`. Use `@AnimatableIgnored` for properties that shouldn't animate.
- Only write `animatableData` by hand when interpolation needs custom logic (clamping, normalization) — use `AnimatableValues` (deployment target ≥ 26) rather than `AnimatablePair` (this project's target is 27, so use `AnimatableValues`).

## Soft-deprecated APIs — never use in new code

Scoping rule: only flag/fix soft-deprecated usage in code you are directly editing. Don't scan unrelated views in the same file and don't volunteer migration of views the user didn't ask about.

Never write new code using these (non-exhaustive, most relevant to a forms/list-heavy financial app):
- `NavigationView` → `NavigationStack` / `NavigationSplitView`
- `Alert` / `.alert(isPresented:)` / `.alert(item:)` (Alert-returning) → `.alert(_:isPresented:presenting:actions:)` or the new `.alert(_:item:actions:)` (see SDK 27 section)
- `ActionSheet` / `.actionSheet(...)` → `.confirmationDialog(...)`
- `.foregroundColor(_:)` → `.foregroundStyle(_:)`
- `.accentColor(_:)` → asset-catalog accent color or `.tint(_:)`
- `.cornerRadius(_:antialiased:)` → `.clipShape(...)` / `.fill(...)`
- `.edgesIgnoringSafeArea(_:)` → `.ignoresSafeArea(_:edges:)`
- `.navigationBarItems(leading:trailing:)` → `.toolbar { ... }` with `.topBarLeading`/`.topBarTrailing`
- `ToolbarItemPlacement.navigationBarLeading`/`.navigationBarTrailing` → `.topBarLeading`/`.topBarTrailing`
- `.navigationBarTitle(...)` → `.navigationTitle(_:)` (+ `.navigationBarTitleDisplayMode` if needed)
- `.navigationBarHidden(_:)` → `.toolbar(.hidden)`
- `.statusBar(hidden:)` / `.statusBarHidden(_:)` → `.toolbarVisibility(_:for: .statusBar)`
- `.tabItem { }` → `Tab(title:image:value:content:)`-based `TabView` content
- `.searchable(text:placement:prompt:suggestions:)` (closure-based suggestions) → `.searchable` + `.searchSuggestions`
- `.view.accessibility(label:)/(hint:)/(value:)/(hidden:)/(identifier:)/(addTraits:)/...` → the dedicated `accessibilityLabel(_:)`, `accessibilityHint(_:)`, `accessibilityValue(_:)`, `accessibilityHidden(_:)`, `accessibilityIdentifier(_:)`, `accessibilityAddTraits(_:)`, etc.
- `TextField`/`SecureField` initializers with `onCommit`/`onEditingChanged` → `.onSubmit(of:_:)` + `FocusState`/`.focused(_:equals:)`
- `Section(header:footer:content:)`-style trailing-content initializers → `Section(content:header:footer:)`
- `Font.system(_:design:)` / `Font.system(size:weight:design:)` old orderings → `Font.system(_:design:weight:)` / `Font.system(size:weight:design:)` current form
- `.overlay(_:alignment:)` / `.background(_:alignment:)` (View-argument form) → the `content:` trailing-closure form
- `EnvironmentValues.presentationMode` → `\.isPresented` / `\.dismiss`
- `RotationGesture`/`MagnificationGesture` → `RotateGesture`/`MagnifyGesture`

For anything not listed here, check the API's `@available` attribute for `deprecated: 100000.0` before using it, or ask before relying on memory.

When a view you're editing already uses a soft-deprecated API: **keep it as-is** in your code output, and offer to migrate as a separate follow-up — don't silently rewrite it as part of an unrelated feature/bugfix.

## SDK 27 APIs to prefer

- **`@State` is now a macro.** Don't assign an `@State` property both at declaration and again early in a custom `init` before other stored properties are set — that's now a compile error ("used before being initialized"), not just bad style. Drop the declaration-site default and set it only in `init`.
- **Toolbars**: use `visibilityPriority(.high/.low)` on `ToolbarItem`/`ToolbarItemGroup` to control what overflows first; `ToolbarOverflowMenu { }` for items that should always live in the overflow menu; `.topBarPinnedTrailing` for an item that must never overflow; `.toolbarMinimizeBehavior(_:for:)` to minimize a bar on scroll; `ForEach` now works directly inside a `toolbar { }` builder for data-driven toolbar items. For a user-customizable toolbar, use `.toolbar(id:)` with per-item `ToolbarItem(id:)` and `ToolbarSpacer(.fixed/.flexible)`. Use `.searchToolbarBehavior(.minimize)` to collapse a search field to a button in constrained toolbars, and `DefaultToolbarItem(kind: .search, placement:)` to reposition it. Use `ToolbarItemPlacement.largeSubtitle` to put custom content in the nav-bar subtitle area (it overrides `.navigationSubtitle(_:)`).
- **Swipe actions outside `List`**: mark the scrollable container (`ScrollView` + `LazyVStack`/`LazyVGrid`/stack) with `.swipeActionsContainer()`, keep `.swipeActions(edge:allowsFullSwipe:content:)` on each row as before. Use the `onPresentationChanged:` overload to react when a row's actions are revealed/hidden.
- **Per-item alerts/dialogs**: prefer `.confirmationDialog(_:item:titleVisibility:actions:message:)` / `.alert(_:item:actions:message:)` (a `Binding<T?>`, no `Identifiable` required) over a separate `isPresented: Bool` + `presenting:` pair, or the old `Alert`-returning `alert(item:)`, whenever the dialog/alert acts on a specific tapped/pending value.
- **`AsyncImage`** now applies standard HTTP caching automatically — no code change needed. Use `AsyncImage(request:)` with a `URLRequest` for a per-image `cachePolicy`, and `.asyncImageURLSession(_:)` to supply a custom `URLSession`/`URLCache` (memory/disk capacity) for a subtree.
- **`@ContentBuilder` unification gotchas**: if `.overlay(...)`/`.background(...)` with a `ShapeStyle` expression using `.opacity()`/`.blendMode()` becomes "ambiguous use of ...", switch to the trailing-closure form (`.overlay { Color.blue.opacity(0.3) }`). An empty `Group { }` (including one made empty by `#if`) needs an explicit `EmptyContent()`/`EmptyView()` when MapKit is anywhere in the module. Don't spell `TupleView` in generic constraints for SDK-27-only code — use `TupleContent`.

## Liquid Glass

Use Liquid Glass for chrome and floating controls — the system's iOS 26/27 visual material (blurs and reflects content behind it, reacts to touch).

- Basic: `.glassEffect()` (regular glass in a capsule by default); `.glassEffect(in: .rect(cornerRadius:))` / `.circle` to change shape; `.glassEffect(.regular.tint(color).interactive())` to tint and make touch-reactive.
- When applying glass to **multiple** nearby views, wrap them in `GlassEffectContainer(spacing:)` — this is required for correct blending/morphing performance, not optional polish. Smaller `spacing` merges effects only when views are closer together.
- Use `.glassEffectUnion(id:namespace:)` to merge glass effects across views that aren't siblings in one stack.
- For morphing transitions when glass views appear/disappear, give each a stable `.glassEffectID(_:in:)` inside a shared `@Namespace`, and change the hierarchy inside `withAnimation`.
- Buttons: `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` for the standard glass button styles — prefer these over manually reconstructing the look with `.background(.thinMaterial)`.
- Apply `.glassEffect()` after other appearance-affecting modifiers in the chain. Keep glass shapes/variants consistent across the app.

## Accessibility / Assistive Access

- A financial app should support Assistive Access for users with cognitive disabilities: add `UISupportsAssistiveAccess` to Info.plist, and provide a dedicated, deliberately simplified `AssistiveAccess { }` scene (added alongside the main `WindowGroup` in the `App` body) rather than relying on the standard UI scaling up.
- Design that scene around: one or two essential flows only (e.g. "check balance," "log an expense" — not the full feature set), large/clearly-spaced tappable controls, no hidden gestures or timed interactions, multiple representations of information (icon + text, not text alone), and confirmations before any destructive/irreversible action.
- Use `.assistiveAccessNavigationIcon(systemImage:)` (or an `Image`) on the navigation title for the Assistive Access scene.
- Detect Assistive Access in regular views via `@Environment(\.accessibilityAssistiveAccessEnabled)` when conditional UI is genuinely needed, rather than duplicating logic.
- Preview with `#Preview(traits: .assistiveAccess)`; verify with Xcode's Accessibility Inspector and on-device via Settings > Accessibility > Assistive Access.
