[README.md](https://github.com/user-attachments/files/30765389/README.md)
# node7-wagon-carcasses














Independent physical animal-carcass storage for NODE7 owned wagons.

## Behavior

- Human NPCs are strictly blacklisted by an animal-model whitelist.
- Only dead animal peds can be loaded.
- Loading uses the exact carcass entity currently carried by the player.
- The original carcass entity is hidden, collisionless, and locked to a compact rear wagon anchor.
- No hunting rewards or inventory items are created by loading or unloading.
- `Stored Carcasses` opens through `node7-menu`.
- Selecting a stored animal lets the player unload it onto the ground behind the wagon.
- During the same live session, unloading detaches the original carcass entity.
- A carcass is recreated only when the original entity no longer exists after wagon storage, streaming cleanup, or a restart.
- Carcass records persist independently in `node7_wagon_carcasses`.
- Wagon ownership, shared keys, lock state, network ID, distance, animal model, death state, and capacity are server validated.

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

Carcass capacity is configured independently in `config.lua`. Normal item-storage slots and weight remain owned by `node7-inventory`.

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

Version 1.0.5 keeps the original carcass hidden only while it is confirmed attached and registered as stored. Unloading removes the record from the stored registry first, clears the replicated hidden state, restores full visibility and physics, and places the same carcass behind the wagon.
