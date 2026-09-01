# FatCat Product Identity and Trust Design

## Decision

FatCat is the product. The Electron client is the primary application, the
native macOS app is the embodied pet, and the root Vite app is an internal
avatar renderer/lab only. Peppa, Peppa Anywhere, Prepst, and local companion
MVP are retired identities.

The rename is comprehensive across package metadata, app display names,
bundle identifiers, Swift targets and symbols, Python module names, storage
namespaces, scripts, active documentation, and user-facing copy. Historical
migration code may mention old names only when reading or retiring existing
data; no new state uses those namespaces.

## Product surfaces

Electron is the primary chat application and the canonical place to explain
Hermes connection state, approvals, tool progress, and verification. The
native app remains a small floating FatCat pet that connects to the same
Hermes session. The Vite avatar build is available only through an explicit
development script and is labeled as an internal lab.

The product path does not expose the retired companion dashboard. The avatar
lab has no agent, memory, planning, or action claims.

## Trust language and event behavior

Every status is explicit: Demo, Native, Hermes connected, or Unavailable.
Privacy copy describes actual behavior rather than absolute guarantees. The
Electron adapter renders all generic Hermes lifecycle events, including
permission/proposal, approval, action result, and verification events. Activity
identity is based on event IDs and stable tool/proposal IDs, so repeated event
kinds sharing a request ID cannot overwrite one another.

The avatar pause contract is functional: paused state stops animation updates,
and the control callback updates the state that owns the renderer.

## Compatibility and storage

New storage uses FatCat namespaces. A one-time migration reads only the old
package/storage keys required to retire them, removes legacy content, and
records a versioned marker. It never imports old local memories into Hermes.
Existing Hermes session IDs remain the only durable conversation handles.

## Verification

Tests enforce the identity boundary, migration behavior, truthful status
labels, pause behavior, generic event rendering, collision-proof activity IDs,
and the root Electron typecheck/smoke scripts. The complete project matrix is
run before integration.
