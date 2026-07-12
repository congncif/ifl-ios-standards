# TROUBLESHOOTING — symptom → cause → fix

> **Purpose**: high-traffic navigator that maps "something broke / something looks wrong" → "here's the most likely cause + the spec section that fixes it". Optimized for the recurring confusions seen across coder sessions; reduces churn on bugs that have already been diagnosed once.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a procedural runbook, same as `DECISION_TREES.md` / `BROWNFIELD_MIGRATION.md` / `ADOPTION.md`.
>
> **How to use**: bound impact first, then Ctrl-F for a phrase from the error, log, or symptom. Each entry is symptom → cause → fix → reference. If the symptom isn't here, use `DECISION_TREES.md` to identify the relevant pattern and re-read its spec's §Pitfalls.

---

## Impact-first investigation contract

Before changing code, establish the blast radius: affected user journey and severity, reproducibility,
first known bad boundary, modules and package edges, public IO/BoardID contracts, registrations and callers,
lifecycle/concurrency owners, stored or transmitted data, and affected UIKit/SwiftUI adapters. For a public
Board, the canonical runtime ID is exactly `pub.mod.<Module>.<Board>`; a literal mismatch or rename is a
runtime contract issue.

Then trace backward from the symptom to the first violated invariant. Inspect the definition and its
callers together; for activation failures, include BoardID, ServiceMap accessor, ModulePlugin registration,
LauncherPlugin/App installation, and any compatibility alias. For UI failures, compare the Presenter or
equivalent display-ready state and typed intents before inspecting rendering mechanics.

Make the fix as one smallest complete semantic slice and choose its rollback boundary before editing. A
rollback restores the last coherent contract, registration, caller route, and lifecycle ownership; it does
not discard unrelated work. If the impact expands or the assigned signal regresses, restore that boundary
and re-plan instead of stacking speculative fixes.

For executable changes, use only the consuming repository's native build/test commands. Assign one primary
signal and owner to each semantic slice or distinct risk boundary, run it after the complete slice, and do
not repeat unchanged green signals after mechanical steps. Documentation-only changes receive no runtime
gate; after all planned mutations, they wait for the plan's one final joined AI consistency review. Do not
create plugin-owned verifier/lint/smoke scripts, receipts, evidence ledgers, manifests, fingerprints, or
custom workflow state. The final joined review covers the complete candidate once and does not replace
required executable-code tests.

---

## Index

1. [Build / architecture-review findings](#1-build--architecture-review-findings)
2. [Runtime crashes & assertions](#2-runtime-crashes--assertions)
3. [Board lifecycle issues](#3-board-lifecycle-issues)
4. [Communication & bus issues](#4-communication--bus-issues)
5. [Navigation & context issues](#5-navigation--context-issues)
6. [Plugin & registration issues](#6-plugin--registration-issues)
7. [Cross-module dependency issues](#7-cross-module-dependency-issues)
8. [Test failures](#8-test-failures)
9. [Pod / project regeneration issues](#9-pod--project-regeneration-issues)

---

## 1. Build / architecture-review findings

### 1.1 review → `import UIKit` in Domain/

**Cause**: Domain layer leaked a UIKit type — most often `UIImage`, `UIColor`, or `UIViewController` snuck into a Domain `Result` / value object.
**Fix**: Move the UIKit-typed value to a Presenter ViewModel. Domain stays pure Swift.
**Ref**: `LAYERING.md`, `SERVICE_LAYER.md`.

### 1.2 review → vendor SDK in Application/

**Cause**: Application layer (UseCase / Repository protocols) imported `Alamofire` / `Moya` / `Firebase*` / `GoogleSignIn` / `GoogleMobileAds` directly.
**Fix**: Application defines a protocol; Infra/ implements it against the vendor SDK. Inject via Builder.
**Ref**: `LAYERING.md` §Application.

### 1.3 review → `import {Other}Plugins`

**Cause**: One module's `Sources/**` imported a sibling module's `Plugins` target. Cross-module access must flow through the IO target.
**Fix**: Replace with `import {Other}` (the IO target). If you need a type that only exists in `{Other}Plugins`, the type is in the wrong target — either it's construction wiring (stays in `Plugins`, never cross-module) or it's domain (move to `{Other}/IO/`).
**Ref**: `CROSS_MODULE_DI.md`, `IO_INTERFACE.md` §"Domain meaning vs construction wiring".

### 1.4 review → `IO-missing-public`

**Cause**: Top-level type declared in `{Module}/IO/**` without `public`/`open`.
**Fix**: Make the IO domain contract public. IO is the cross-module usage surface, so its top-level contract types must be public; `extension` blocks carry visibility on their members. Do not move App-boot provider configuration into IO merely because it must be public — that narrow construction surface belongs under `Sources/Plugins/**`.
**Ref**: `IO_INTERFACE.md` §Naming.

### 1.5 review → `Sources-has-public`

**Cause**: Public symbol declared under `Sources/Microboards/**` or `Sources/Services/**` — these are internal.
**Fix**: Drop the `public` modifier. `Sources/**` stays internal except the minimum App-boot construction surface under `Sources/Plugins/**`, such as LauncherPlugin init arguments and provider configurations. Keep that exception narrow: App composition may construct it, but sibling feature modules still import only IO and never another module's Plugins target.
**Ref**: `IO_INTERFACE.md` §"Domain meaning vs construction wiring".

### 1.6 review → BoardID literal doesn't match pattern

**Cause**: BoardID literal violates the naming contract. Two shapes:
- Public (declared in `IO/`): MUST be `pub.mod.<Module>.<Board>`.
- Internal (declared in `Sources/Microboards/`): MUST be `mod.<Module>.<Board>` or `mod.<Module>.<X>Provider`.

**Fix**: First map the literal's registrations, ServiceMap accessors, and all callers. Correct the owning module/Board segments and migrate the complete semantic slice. A public literal rename is **breaking at runtime**; coordinate all callers or preserve an intentional compatibility alias before removing the old route.
**Ref**: `IO_INTERFACE.md` §Naming.

### 1.7 review finds a spec missing a required section

**Cause**: A new spec under `standards/specs/` doesn't conform to the 12-section `SPEC_CONTRACT.md` template.
**Fix**: Add the missing sections, or classify the document under `SPEC_CONTRACT.md` as a non-pattern document when that is genuinely its role.
**Ref**: `SPEC_CONTRACT.md`, `SPEC_SYNC.md`.

### 1.8 Podspec lint: `s.dependency 'X', :path => '...'` rejected

**Cause**: `s.dependency` line includes `:path =>` — CocoaPods rejects this in podspecs.
**Fix**: Drop `:path =>` from podspec dependencies. Path resolution happens in the **Podfile**, never in podspecs. Podspec carries name + optional version only.
**Ref**: `MODULE_CREATION.md`, `PACKAGE_MANAGER.md`.

### 1.9 review → View derives product meaning / UIKit and SwiftUI disagree

**Cause**: Formatting, eligibility, retry, navigation, analytics, accessibility meaning, or error mapping moved into a `UIViewController`/`UIView` or SwiftUI `View`; or a hosting/interoperability adapter remapped the same feature differently per framework.
**Fix**: Restore the humble-View boundary. The Presenter or equivalent mapper produces one display-ready semantic state and typed intents. UIKit consumes it through its display port; SwiftUI consumes the same semantics through a `MainActor` presentation store. Views may own rendering mechanics and transient UX-local state only. Compare both adapters against the same input and remove semantic remapping from the bridge.
**Ref**: `ARCHITECTURE.md` §VIP, `VIP_COMPONENTS.md`, `MICROBOARD_UI.md`, `enterprise/swiftui-production.md`.

---

## 2. Runtime crashes & assertions

### 2.1 `Fatal error: Could not cast value of type 'X' to 'InternalYProviderConfiguration'`

**Cause**: An Extensible Provider's `LauncherPlugin` received a `ProviderConfiguration` that conforms to the public marker but NOT the internal factory protocol. Likely the App constructed an outside type that just adopts the marker protocol.
**Fix**: Every concrete provider config MUST conform to `Internal{Feature}ProviderConfiguration`, not just `{Feature}ProviderConfiguration`. The force-cast is intentional — adopting only the public marker is a programming error.
**Ref**: `EXTENSIBLE_PROVIDER.md` §Layer 2.

### 2.2 `Assertion failed: complete() called twice`

**Cause**: A Board called `complete()` after it had already completed. Common triggers: completion fires on both `Output` and a separate `flow` callback; a child Board's flow listener runs after the parent already completed; SDK callback fires twice.
**Fix**: Guard at-most-once. Either set a `hasCompleted` flag and early-return, or release the source of duplicate signals (unsubscribe / `detachObject`) on first completion. `BlockTaskBoard` never needs `complete()` — remove it if you added one.
**Ref**: `BOARDY_FOUNDATIONS.md` §Non-negotiable #5, `QUICK_REF.md` rule 12.

### 2.3 `BoardID not registered: pub.mod.<Module>.<Board>`

**Cause**: App tried to activate a Board whose canonical ID, `pub.mod.<Module>.<Board>`, is not registered. The LauncherPlugin may be absent, the ServiceType case may map to another ID, a move/rename may have left callers on the old literal, or a planned bridge may be missing.
**Fix**: Trace the full activation path before editing: caller literal/accessor → IO ServiceMap → `{Module}ModulePlugin` case and identifier → `{Module}LauncherPlugin` → App install list. Correct the smallest complete path; for a public move/rename, migrate all controlled callers or restore the compatibility alias. Then run the consuming repo's assigned activation signal once for the completed fix slice.
**Ref**: `PLUGINS_INTEGRATION.md` §ModulePlugin.

### 2.4 `Could not find module {Module}` (Swift compile error)

**Cause**: Adopting module not declared in the consumer's Podfile, OR consumer is importing the wrong target (`{Module}Plugins` instead of `{Module}`).
**Fix**: A sibling feature adds/imports the `{Module}` IO target only. App composition may additionally depend on `{Module}Plugins` solely to construct/install LauncherPlugin wiring; that exception is not a feature-to-feature dependency. After correcting the consuming repo's package declaration, use its normal project-regeneration/build command.
**Ref**: `QUICK_REF.md` §5, `CROSS_MODULE_DI.md`.

### 2.5 `EXC_BAD_ACCESS` on Board → Controller call

**Cause**: Board stored a strong reference to a Controller that has been deallocated, OR vice versa. Common: Board cached a `weak var` that was already released; or Board held `weak var view` while the View was the only thing keeping the VC alive.
**Fix**: Use buses, not stored controller references, for Board → Controller. Stored Controller references on Boards should be `weak` AND the Board should be defensive (`guard let controller else { return }`).
**Ref**: `BOARDY_FOUNDATIONS.md` §Board owns Controller, `COMMUNICATION.md`.

---

## 3. Board lifecycle issues

### 3.1 Board's `deinit` never fires

**Cause**: Retain cycle. Most common: closure captured `self` strongly inside `registerFlows()` or a bus subscription. Second most common: `attachObject(controller)` held a strong reference and `complete()` was never called.
**Fix**: Use `[weak self]` in every closure inside `registerFlows()` and bus subscriptions. If using `attachObject`, ensure `complete()` runs OR call `detachObject(_:)` when done.
**Ref**: `MICROBOARD_NONUI.md` §Attach context, `QUICK_REF.md` rule 13.

### 3.2 Board state leaks across activations

**Cause**: Board declared as `final class` with stored properties that aren't reset on `activate(...)`. Boardy reuses Board instances across activations.
**Fix**: Reset all per-activation state at the top of `activate(withGuaranteedInput:)`. Persistent state (subscribers, sharedRepository) is fine; per-activation state (latest input, current controller) must be reset.
**Ref**: `BOARDY_FOUNDATIONS.md` §Board lifecycle ≠ Controller lifecycle.

### 3.3 Two simultaneous activations cause duplicate Controllers / duplicate UI

**Cause**: The Board doesn't guard against double-activation but was designed as single-session.
**Fix**: Add an `isActive` flag set on activate / cleared on complete. Reject re-activate while active (or queue, depending on intent). Note: this guard is ONLY for explicit single-session Boards; concurrent-by-design Boards must support N activations without state sharing.
**Ref**: `QUICK_REF.md` rule 8, `MICROBOARD_NONUI.md`.

### 3.4 `BlockTaskBoard.executingType = .concurrent` — callbacks routed to wrong activation

**Cause**: Used `.flow.addTarget(self) { ... }` for routing. `.flow` is shared across concurrent activations of the same BlockTaskBoard — its closure fires for ALL of them.
**Fix**: Use parameter callbacks (`onSuccess:`, `onError:`) on each call site instead. They're activation-local.
**Ref**: `QUICK_REF.md` rule 14, `EXAMPLES_NONUI_BOARDS.md` §BlockTaskBoard.

---

## 4. Communication & bus issues

### 4.1 Bus subscriber fires for events that belong to a different Controller

**Cause**: Round-trip bus (Controller → Board → SDK → bus → Controller) without identity filter. Closing over a local controller variable does NOT filter — every subscriber sees every message.
**Fix**: Bus payload MUST carry source Controller. Subscriber: `guard target === payload.source else { return }`. This applies only to round-trips; Board-originated buses (child Board → Controller) use plain `Bus<Void>` and rely on `bus.connect(target:)`'s weak binding.
**Ref**: `BUS_PATTERNS.md` §Round-trip identity-filtered, `QUICK_REF.md` rule 13.

### 4.2 Bus subscriber receives the same message N times

**Cause**: Bus subscription was created N times — usually because `attachObject(controller)` ran on every activation without `detachObject` on completion, stacking subscribers.
**Fix**: Either subscribe once in Board `init` (lifecycle-long), or pair every `attachObject` with `detachObject` on complete. Never re-subscribe inside `activate()` without cleanup.
**Ref**: `COMMUNICATION.md`, `QUICK_REF.md` rule 13.

### 4.3 Board → child Board flow callback never fires

**Cause**: Parent didn't register `motherboard.serviceMap.mod{Child}Plugins.io{Child}.flow.addTarget(self) { ... }` in `registerFlows()`, OR the child emits via `sendOutput` but the parent listens for an `Action` (or vice versa).
**Fix**: Outputs are listened via `.flow.addTarget`. Actions are listened by the motherboard's action handler. Match the channel. `registerFlows()` MUST be called in Board `init`, NEVER in `activate()`.
**Ref**: `COMMUNICATION.md`, `QUICK_REF.md` rule 7.

### 4.4 ViewController calls Interactor for what's clearly navigation

**Cause**: Defaulting all VC → Board communication through Interactor, even when the intent is pure navigation that Interactor would only forward.
**Fix**: Use `{Board}ActionDelegate` on the ViewController for pure-navigation intents. `weak var actionDelegate` on VC; conformed by Board; declared in `{Board}Protocols.swift`. Interactor must NOT declare `actionDelegate`.
**Ref**: `QUICK_REF.md` rule 2 (exception clause), `VIP_COMPONENTS.md`.

---

## 5. Navigation & context issues

### 5.1 Viewless Board's Controller dies before its SDK callback returns

**Cause**: Controller was attached to the Board (last-resort context), Board completed, Controller deallocated — but SDK still had a callback pending.
**Fix**: Use a longer-lived context. Priority: (1) explicit `input.context` (caller-owned), (2) `rootViewController` (flow outlives single screens), (3) Board context (last resort, only when no owner exists).
**Ref**: `QUICK_REF.md` rule 13, `MICROBOARD_NONUI.md` §Attach context.

### 5.2 `rootViewController.show(_:)` doesn't position the VC where expected

**Cause**: Default `show()` uses the topmost VC's presentation logic. Custom positioning (sheet, popover, embedded) needs a different context or a custom `show(_:context:)` call.
**Fix**: Pass explicit `context:` to `show()`, OR if embedding into a Composable surface, use `putToComposer(elementAction: .update(element:))` instead.
**Ref**: `CONTEXT_NAVIGATION.md`, `COMPOSABLE_BOARD.md`.

### 5.3 ComposableBoard's child activates but doesn't appear

**Cause**: Child activated via `motherboard.serviceMap` instead of `composableBoard.serviceMap`. The child must inherit the composable's lifecycle and host surface — going through motherboard puts it on the root scope instead.
**Fix**: Activate via `composableBoard.serviceMap.io{Child}.activation.activate(with:)`.
**Ref**: `COMPOSABLE_BOARD.md` §Activation, `EXAMPLES_COMPOSABLE_BOARD.md`.

### 5.4 Back navigation skips a screen / lands on wrong screen

**Cause**: NavigationController stack mismatch. Boards don't own the nav stack — UIKit does — but they DO trigger pushes/pops via `show(_:)`. A Board completing while a child is still on the stack pops both.
**Fix**: Ensure parent Board completes AFTER child returns control. Use `returnHere` / `backToPrevious` patterns rather than ad-hoc `popViewController`.
**Ref**: `CONTEXT_NAVIGATION.md`.

---

## 6. Plugin & registration issues

### 6.1 `URLOpenerPlugin` registered but deep link doesn't fire

**Cause**: `URLOpenerPlugin` activated via the wrong ServiceMap. Openers live in `Sources/` so they go through `{Module}PluginsServiceMap` (internal), NOT the public IO ServiceMap.
**Fix**: Use `mod{Module}Plugins` to access the opener, not `mod{Module}`.
**Ref**: `PLUGINS_INTEGRATION.md` §URLOpener.

### 6.2 Module's boards aren't discoverable after `ifl-new-module`

**Cause**: The command creates only the IO/Plugins source boundary. The consuming repository has not
added those sources to its build/package graph, registered the Boards, or installed the module at the
app composition root.
**Fix**: Add the IO and Plugins source surfaces using a current neighbouring module, register each
Board with its canonical public ID, install the public Plugins composition type at app boot, and run
the repository-owned dependency/project generation step when applicable.
**Ref**: `MODULE_CREATION.md`, `PLUGINS_INTEGRATION.md`.

### 6.3 `sharedRepository` instance changes across activations

**Cause**: `sharedRepository` was created INSIDE a `BoardRegistration` closure (re-created every closure run) instead of as a stored property on the ModulePlugin struct.
**Fix**: Declare `let sharedRepository = SomeRepository()` as a stored property on `{Module}ModulePlugin`. Each closure references the same instance.
**Ref**: `PLUGINS_INTEGRATION.md` §Shared deps, `QUICK_REF.md` rule 10.

---

## 7. Cross-module dependency issues

### 7.1 Module A needs a type from Module B — where does it import from?

**Cause**: Decision: IO target (`B`) or Plugins target (`BPlugins`)?
**Fix**: Always IO. If the type isn't in `B/IO/`, the type is in the wrong target — either it's domain (move to IO/) or it's construction wiring (stays in `Plugins/`, NEVER cross-module). Cross-module Plugins import is a hard violation.
**Ref**: `DECISION_TREES.md` Tree §8, `CROSS_MODULE_DI.md`.

### 7.2 Provider configuration is `public` but client module can't import it

**Cause**: Provider config lives in `Sources/Plugins/` (correct — it's construction wiring), which is part of the implementation target `{Module}Plugins`, NOT the interface target `{Module}`. Clients can only import `{Module}`.
**Fix**: If a client module needs the config, it's a SIGN that the config is NOT actually construction wiring — re-check whether it's domain. If it really is construction wiring, only the App should reference it (App imports `{Module}Plugins` for LauncherPlugin construction; sibling modules don't).
**Ref**: `IO_INTERFACE.md` §"Domain meaning vs construction wiring", `EXTENSIBLE_PROVIDER.md`.

---

## 8. Test failures

### 8.1 Interactor test passes locally, fails in CI / on simulator

**Cause**: Test depended on mocked DB / network, but production wiring uses real implementations. Mock/prod divergence.
**Fix**: For Interactor-level tests, mock UseCases (Application layer protocols), not Repositories. Repositories should be tested at integration level with a real (in-memory or test) DB/network.
**Ref**: `TESTING.md`, `compact/TESTING.compact.md`.

### 8.2 Presenter test asserts ViewModel but ViewModel changed shape

**Cause**: Presenter maps Domain → ViewModel; ViewModel is the only Presenter output. When the View asks for a new field, Presenter changes, test asserts must update.
**Fix**: Re-snapshot the ViewModel in the Presenter test. Don't test Presenter through ViewController — Presenter is the only Domain → ViewModel mapper, so test it directly.
**Ref**: `VIP_COMPONENTS.md` §Presenter, `TESTING.md`.

### 8.3 Board test setup is fighting Boardy's lifecycle

**Cause**: Trying to test Board activation logic in a unit test by manually constructing the Board. Board is hard to unit-test in isolation — its real contract is "fan inputs to Interactor + listen for outputs".
**Fix**: Test the Interactor, not the Board. Board logic that's worth testing (flow routing, command dispatch) shows up as Interactor behavior. If Board has its own logic worth testing, it's probably a sign that the logic belongs in the Interactor or a UseCase.
**Ref**: `TESTING.md` §What to test.

---

## 9. Pod / project regeneration issues

### 9.1 New module / new board sources are not in the project

**Cause**: Thin scaffolders do not edit build/package configuration. An existing glob, project file,
package target, or dependency-generation step does not include the new IO/Sources paths.
**Fix**: Compare with a current neighbouring module, add the exact source paths and dependencies to
the repository-owned build surfaces, then run its normal dependency/project-generation command. For
CocoaPods this may be `pod install`; for other systems use their owned equivalent rather than a
plugin-supplied universal command.
**Ref**: `MODULE_CREATION.md`.

### 9.2 `pod install` fails with "Cannot find module" cycle

**Cause**: Circular cross-module dependency. Module A's podspec depends on B; B's podspec depends on A.
**Fix**: Break the cycle. Usually the shared types belong in a third module (or in DesignSystem / shared lib). Cross-module dep direction MUST be acyclic — see DECISION_TREES Tree §8.
**Ref**: `DECISION_TREES.md` Tree §8, `CROSS_MODULE_DI.md`.

### 9.3 Plugin skills/agents/specs are stale after a new version shipped

**Cause**: the installed `ifl-ios-standards` plugin is pinned to an old ref, or the local cache hasn't refreshed.
**Fix**: update the marketplace + reload.
- Claude Code: `claude plugin marketplace update ifl-ios-standards` then `/reload-plugins` (or restart). If pinned, re-add with the new tag: `claude plugin marketplace add congncif/ifl-ios-standards#vX.Y.Z`.
- Codex: `codex plugin marketplace upgrade ifl-ios-standards`, then start a new thread.
**Ref**: the plugin's `INSTALL.md` / `DEPLOY.md`.

---

## When this navigator doesn't help

If your symptom isn't here:

1. Identify the pattern in play (Board type, communication channel, layer) via `DECISION_TREES.md`.
2. Read that pattern's spec — every spec has a §Pitfalls section with the recurring traps.
3. Inspect the affected paths against the architecture rules and include them in the plan's one final joined AI review.
4. Check `17-anti-patterns.md` (rulebook) for the wider anti-pattern catalog.

If you've diagnosed a new symptom worth recording, add it here as a §X.Y entry following the symptom → cause → fix → ref shape. New entries belong in the section that matches the failure mode, not the affected module.
