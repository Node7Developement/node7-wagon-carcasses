## 2.1.1

- Removed `node7-hunting` as a dependency.
- Removed all hunting-named state bags and integration markers.
- Wagon storage now performs only a read-only native processed/skinned check.
- Skinning animations, rewards, pelts, inventory handling, and harvest claims remain entirely owned by `node7-hunting`.
- Unloaded carcasses retain their saved skinned appearance and native fully-looted state without invoking hunting code.

# 2.1.0

- Requires carcasses to be skinned/fully looted before storage.
- Preserves metaped component tags, outfit hash, quality, and damage cleanliness.
- Restores unloaded animals as fully looted before making them usable in the world.
- Adds replicated wagon-owned processed-state markers for storage validation.
- Verifies the replacement network entity before committing an unload.
- Rolls back an unverified unload instead of duplicating the database record.
- Migrates legacy records as processed to prevent fresh skinning rewards.

# 2.0.1

- Fixed recreated animal carcasses rendering invisible after resource or full-server restarts.
- Applies RedM metaped outfit initialization before the recreated animal is killed.
- Replicates a world-carcass visibility state so every streaming client rebuilds the animal appearance.
- Added a low-frequency tracked-entity visibility guard for network-owner migration and stale alpha state.

# 2.0.0

- Removed all per-wagon carcass capacity limits.
- Converted storage to unlimited database-backed records.
- Consumes the world carcass only after the server reserves the record.
- Recreates a fresh visible carcass on unload.
- Clears stale network IDs and legacy hidden entities after restarts.

# Versions

## 1.0.5

- Fixed unloaded carcasses remaining invisible after leaving wagon storage.
- Removes the carcass from the managed stored registry before detaching it.
- Replicates an explicit visible state instead of leaving stale hidden state bags.
- Prevents loose world carcasses from being hidden unless physically attached to a wagon.
- Reapplies normal visibility, collision, gravity, damage, ragdoll, and dynamic state during network ownership migration.

## 1.0.4

- Stored carcasses are fully invisible while loaded.
- Moved all stored entities to one compact anchor on the absolute rear edge of the wagon.
- Disabled collision, gravity, ragdoll, and loose physics while stored.
- Added replicated hidden-state handling so nearby clients do not see stored carcasses.
- Restores visibility and normal physics before unloading.

## 1.0.3

- Fixed carried carcasses dropping before wagon attachment.
- Uses the native carried-entity placement task before securing the same entity.
- Disables carcass ragdoll, gravity, dynamics, and collision only while stored.
- Verifies attachment across multiple frames and repairs only loaded carcasses once per second.

## 1.0.2

- Fixed native carried-carcass registration.
- Added a short carry cache so selecting the rear ox_target option cannot lose the carried entity.
- Corrected itemset conversion to `_GET_PED_FROM_INDEXED_ITEM`.
- Added strict carrier-native fallbacks and robust dead-carcass validation.

## 1.0.1

- Added an always-visible rear `Store Animal Carcass` ox_target action.
- Added reliable carried-carcass detection through Rockstar's direct carry native, attached-carriable itemsets, carrier checks, and a strict animal whitelist.
- Added optional loading of a dead animal placed on the ground beside the wagon rear.
- Properly detaches Rockstar's carriable state before attaching the same carcass entity to the wagon.
- Keeps human NPCs completely excluded.

## 1.0.0

- Initial independent NODE7 wagon-carcass resource.
- Physical same-entity load and unload flow.
- Persistent restore after wagon despawn or restart.
- Strict animal-only validation.
- `ox_target` rear actions and `node7-menu` stored-carcass list.
