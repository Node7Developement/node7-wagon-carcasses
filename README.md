[README.md](https://github.com/user-attachments/files/30810866/README.md)
# node7-wagon-carcasses

Unlimited persistent animal-carcass storage for NODE7 owned wagons.

## Behavior

- Human NPCs are strictly blacklisted by an animal-model whitelist.
- Only dead animal peds can be loaded.
- Loading uses the exact carcass entity currently carried by the player or placed beside the rear target.
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
ensure node7-hunting
ensure node7-wagons
ensure node7-wagon-carcasses
```

No modification to `node7-core`, `node7-hunting`, or `node7-wagons` is required.

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

Version 2.0.1 stores each carcass as an unlimited database record. The original world carcass is consumed only after the server reserves the record, and unloading creates a fresh fully visible physical carcass behind the wagon. This avoids stale hidden entities and network-ID reuse after resource or full-server restarts.


## v2.0.0

- Unlimited carcass records per owned wagon.
- Stored carcasses no longer remain as hidden physical entities.
- Fresh visible carcasses are recreated on unload.
- Resource and full-server restarts clear stale live network IDs and legacy hidden entities.

## v2.0.1 visibility repair

Recreated RedM animal peds now receive their required metaped outfit variation before death. The world-carcass visibility marker is replicated so a carcass remains rendered when it streams to another client or network ownership changes.
