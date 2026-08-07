# node7-wagon-carcasses

Unlimited persistent storage for processed animal carcasses in NODE7 owned wagons.

## Behavior

- Human NPCs are strictly blacklisted by an animal-model whitelist.
- Only dead animal peds can be loaded.
- Only already-skinned/fully-looted carcasses can be stored; intact animals are rejected to prevent reward duplication.
- Loading captures the carcass model, exact metaped components, outfit, quality, and damage state.
- After the server reserves the record, the original world carcass is consumed instead of being kept as a hidden network entity.
- No hunting rewards or inventory items are created by loading or unloading.
- `Stored Carcasses` opens through `node7-menu`.
- Selecting a stored animal lets the player unload it onto the ground behind the wagon.
- Unloading always creates a fresh visible dead-animal entity behind the wagon.
- Resource and full-server restarts preserve database records without restoring stale hidden entities.
- Carcass records persist independently in `node7_wagon_carcasses`.
- Wagon ownership, shared keys, lock state, network ID, distance, animal model, and death state are server validated.

## Dependencies

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure node7-core
ensure node7-menu
ensure node7-wagons
ensure node7-wagon-carcasses
```

No modification to `node7-core`, `node7-hunting`, or `node7-wagons` is required. `node7-hunting` is not a dependency and receives no events, exports, state changes, or reward instructions from this resource.

## Rear target options

- Store Animal Carcass
- Stored Carcasses

The existing `node7-wagons` rear target continues to handle inventory storage and wagon actions.

## Capacity

Carcass storage is unlimited and database-backed. The physical carcass is consumed when stored and recreated visibly when unloaded, preventing stale invisible entities after resource or server restarts. Normal item-storage slots and weight remain owned by `node7-inventory`.

## Butcher integration

Server exports are available for a later butcher resource:

```lua
local carcasses = exports['node7-wagon-carcasses']:GetWagonCarcasses(wagonid)
local removed = exports['node7-wagon-carcasses']:RemoveWagonCarcass(wagonid, recordId)
```

## Loading carcasses

At the rear ox_target marker, select **Store Animal Carcass**. The resource accepts the dead animal currently carried by the player. It also accepts a valid dead animal placed on the ground directly beside the rear marker. Human NPCs and non-whitelisted peds are always rejected.

## Carried carcass detection

Version 1.0.2 reads Rockstar's active carry slot, the attached-carriable itemset, and the carcass carrier. A short cache preserves the exact entity while the rear ox_target option is selected.

### Physical attachment behavior

Version 2.1.1 only accepts carcasses that have already been skinned. It stores the processed state plus metaped appearance, quality, and damage data. Unloading rebuilds the same skinned carcass and restores only the native processed state needed for that carcass. It does not run or replace any skinning or reward code.


## v2.0.0

- Unlimited carcass records per owned wagon.
- Stored carcasses no longer remain as hidden physical entities.
- Fresh visible carcasses are recreated on unload.
- Resource and full-server restarts clear stale live network IDs and legacy hidden entities.

## v2.0.1 visibility repair

Recreated RedM animal peds now receive their required metaped outfit variation before death. The world-carcass visibility marker is replicated so a carcass remains rendered when it streams to another client or network ownership changes.


## Anti-duplication processing

`Config.RequireSkinnedCarcass = true` is enabled by default. Players must skin an animal before storing it. The unloaded animal remains fully looted and cannot be skinned again for another reward. Records from older versions are migrated as processed/skinned for safety.
