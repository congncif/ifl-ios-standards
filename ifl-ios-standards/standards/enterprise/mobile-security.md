# Mobile Security

Owner: Security Owner  
Requirement: `ENT-SECURITY`  
Profile: `core`  
Rationale: `ADR-0002`

## 1. Purpose

Protect customer and enterprise assets across authentication, local storage, networking, external input, embedded web content, build inputs, and operational logging. This chapter consumes the canonical data classification owned by `DATA-CLASS-001`; it does not create or rename data classes.

## 2. Applicability

Apply this chapter to every production iOS target, extension, SDK integration, backend-facing adapter, deep-link entry point, WebView, credential store, analytics or logging path, and build process that can access product data. Reassess applicability when assets, trust boundaries, authentication flows, external entry points, third-party SDKs, or regulated-data use changes.

## 3. Non-negotiable rules

- `MSEC-THREAT-001`: maintain an owned threat model for security-relevant scope and material changes.
- `MSEC-AUTH-001`: minimize and protect authentication material throughout issuance, use, refresh, revocation, and logout.
- `MSEC-KEYCHAIN-001`: store credentials only in Keychain with classification-appropriate accessibility and access control.
- `MSEC-NET-001`: use platform trust evaluation; prohibit trust-all behavior and govern pinning as an expiring exception.
- `MSEC-INPUT-001`: treat external input and deep links as untrusted, canonicalize them, validate an allowlisted contract, and fail closed.
- `MSEC-WEB-001`: allowlist WebView origins and navigation, isolate bridges, and validate every bridge message.
- `MSEC-SECRET-001`: exclude deployable secrets from source and application bundles and provide rotation and revocation.
- `MSEC-LOG-001`: redact structured events deterministically from the `DATA-CLASS-001` classification before emission.

## 4. Decision guidance

Start with the product-data classification and threat model, then select controls for the asset and boundary. Prefer platform capabilities over custom cryptography or trust stacks. Use Keychain only for small security-sensitive values, not as a general database. Use normal platform TLS validation unless a reviewed threat model demonstrates that pinning's operational failure modes are justified. Reject malformed or unknown external input rather than guessing intent.

Security-sensitive tradeoffs, legal risk, trust-policy exceptions, or acceptance of residual high risk require named human authority. An Agent may identify options and consequences but must not approve risk, invent organization policy, or weaken a control to make implementation easier.

## 5. Implementation patterns

### Threat model and assets

Record the protected assets, `DATA-CLASS-001` classes, entry points, trust boundaries, attacker capabilities, abuse cases, mitigations, residual risk, accountable owner, and next review event. Link each control to a concrete abuse case. Revisit the model before adding authentication modes, external inputs, WebViews, SDK data access, or new storage and network paths.

### Authentication and Keychain

Keep access credentials short-lived when the system supports it. Persist only the minimum material needed to restore an authenticated session. Select Keychain accessibility from the asset's lifecycle and background-access needs, and add user-presence or device-bound access control when the threat model requires it. Clear related credentials, in-memory state, caches, and pending work on logout or revocation.

### Network trust

Use URLSession and platform trust evaluation by default. Never accept arbitrary certificates, hostnames, or challenge dispositions. If pinning is approved, define pin set, backup pins, rotation, expiry, outage recovery, telemetry without sensitive content, and a removal decision. A pinning exception cannot silently become permanent architecture.

### External input and WebView

Parse deep links and universal links into a typed request only after canonicalization and allowlist validation of scheme, host, path, parameter names, value bounds, and authorization context. WebViews use the minimum origin set, disable unnecessary capabilities, keep privileged content separate from untrusted content, expose narrow bridge handlers, and decode bridge messages into closed typed payloads.

### Secrets and logging

Inject environment-specific secrets through an organization-approved secret channel; do not place them in source, fixtures, xcconfig committed to the repository, generated Swift, plist resources, or application assets. Structured logging starts from an allowlist of operational fields. Apply deterministic redaction before interpolation, serialization, buffering, sampling, transport, or crash attachment.

## 6. Compliant and non-compliant examples

Compliant:

- A deep link parser rejects unknown hosts, duplicate security-sensitive parameters, oversized values, and unauthorized destinations before dispatch.
- A credential store uses a documented Keychain accessibility class selected from the data classification and session requirements.
- A WebView bridge accepts one versioned message type and rejects unknown operations and origins.
- An event records an opaque operation identifier and outcome after classified fields have been removed or transformed by the redaction policy.

Non-compliant:

- A URLSession challenge handler returns `.useCredential` for every server trust challenge.
- Tokens are stored in UserDefaults, SQLite plaintext, logs, screenshots, or application resources.
- A route opens any URL received through push notification or pasteboard without validation.
- A WebView exposes a generic JavaScript bridge capable of invoking arbitrary native selectors.
- A logging call interpolates a request or domain object and attempts redaction after serialization.

## 7. Anti-patterns

- Creating a second security-owned data taxonomy instead of consuming `DATA-CLASS-001`.
- Treating obfuscation, base64 encoding, or a hard-coded encryption key as secret protection.
- Disabling trust validation in development code that can enter a production target.
- Pinning without backup, rotation, expiry, or outage recovery.
- Validating only the deep-link scheme while trusting host, path, and parameters.
- Using a WebView as a privileged application shell with unrestricted navigation and bridges.
- Blocklisting sensitive log keys while allowing arbitrary objects by default.

## 8. Verification

The single final joined AI consistency review confirms that every security Rule has matching chapter, ADR, profile, ownership, and dependency references; that Security consumes `DATA-CLASS-001`; and that examples and guidance do not permit trust-all networking, plaintext credentials, unvalidated input, unrestricted WebViews, bundled secrets, or post-emission redaction. Executable security code remains subject to the consuming repository's ordinary unit, integration, and platform tests; CI operation is outside this plugin.

## 9. Exceptions

Security exceptions are human-authorized, time-bounded records. Each record identifies the exact Rule, asset and data class, affected versions and boundaries, threat and residual risk, compensating controls, accountable owner, approving authority, expiry, review event, and removal plan. Expired or ownerless exceptions are invalid. Network-trust and credential-protection exceptions cannot be auto-approved by an Agent.

## 10. Migration and adoption

Inventory authentication material, Keychain use, trust handlers, external inputs, WebViews, embedded secrets, and logging sinks. Classify the data they touch through `DATA-CLASS-001`. Remove trust-all and plaintext paths first, then close unvalidated entry points and unrestricted bridges, migrate secrets to managed delivery, and introduce deterministic allowlist-based logging. Track temporary compatibility behavior as an exception with a removal release.

## 11. Ownership

The Security Owner owns this chapter, threat-model quality, control interpretation, and exception review. The Data Lifecycle Owner owns `DATA-CLASS-001`. Feature owners own their assets and remediation. Platform owners provide approved Keychain, trust, input-validation, WebView, secret-delivery, and redaction primitives. Legal, Privacy, and release authorities retain their own approval boundaries.

## 12. Metrics

Track threat-model coverage for security-relevant surfaces, age of open high-risk findings, exception count and days to expiry, credential stores by approved accessibility policy, trust-policy exceptions, externally reachable input handlers with typed validation, WebView bridge inventory, detected source or bundle secrets, and structured event schemas covered by deterministic redaction. Metrics must not collect the sensitive values they measure.

## 13. Review cadence

Review at least quarterly and before release when authentication, sensitive-data classes, trust boundaries, public entry points, WebViews, secret delivery, logging schemas, or security-relevant SDKs change. Review active exceptions before expiry and immediately after a credible incident, credential compromise, trust outage, or material platform-security change.
