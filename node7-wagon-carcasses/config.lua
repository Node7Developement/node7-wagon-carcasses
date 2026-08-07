Config = {}

Config.Version = '2.1.1'
Config.Debug = false

Config.Interaction = {
    scanDistance = 40.0,
    scanInterval = 1000,
    zoneUpdateInterval = 700,
    zoneRadius = 1.55,
    targetDistance = 3.0,
    serverDistance = 7.0,
    moveThreshold = 0.65,
    headingThreshold = 8.0,
    rearFallback = -2.2,
    rearExtra = 0.35,
    rearHeight = 0.45,
    drawSprite = true,
    allowGroundLoad = true,
    groundLoadDistance = 3.25,
}


-- Stored carcasses stay hidden and collisionless at one compact anchor on the
-- absolute rear edge of the wagon. The original entity is retained so the
-- menu can unload that same carcass later without blocking seats or movement.
Config.HiddenStorage = {
    enabled = true,
    hidden = true,
    x = 0.0,
    rearInset = 0.10,
    bottomLift = 0.34,
    slotSpacing = 0.015,
    pitch = 0.0,
    roll = 0.0,
    yaw = 0.0,
    resecureInterval = 1000,
}

-- Carcass storage is database-backed and intentionally unlimited. Physical
-- carcass entities are consumed when stored and recreated only when unloaded.
-- This avoids engine entity limits and stale invisible carcasses after restarts.
Config.UnlimitedStorage = true
Config.StorageMode = 'virtual'

-- Read-only storage rule: only carcasses already skinned by the existing
-- hunting system may enter storage. This resource never performs skinning,
-- grants rewards, removes pelts, or changes node7-hunting behavior.
Config.RequireSkinnedCarcass = true

-- Normalized wagon-space layout. The client scales these positions using the
-- current wagon model dimensions, so carts and wagons do not need hard-coded
-- world coordinates. x/y/z values are percentages of the model bounds.
Config.SlotLayout = {
    { x = 0.30, y = 0.18, z = 0.60, rz =  90.0 },
    { x = 0.70, y = 0.18, z = 0.60, rz = -90.0 },
    { x = 0.30, y = 0.34, z = 0.62, rz =  90.0 },
    { x = 0.70, y = 0.34, z = 0.62, rz = -90.0 },
    { x = 0.30, y = 0.50, z = 0.64, rz =  90.0 },
    { x = 0.70, y = 0.50, z = 0.64, rz = -90.0 },
    { x = 0.30, y = 0.66, z = 0.66, rz =  90.0 },
    { x = 0.70, y = 0.66, z = 0.66, rz = -90.0 },
    { x = 0.30, y = 0.80, z = 0.68, rz =  90.0 },
    { x = 0.70, y = 0.80, z = 0.68, rz = -90.0 },
}

Config.RestoreRequestCooldown = 10000
Config.PendingLoadTimeoutSeconds = 90
Config.PendingUnloadTimeoutSeconds = 45

-- Strict animal whitelist for wagon carcass storage. Human NPC models are
-- not present and cannot enter this system.
Config.Animals = {
    A_C_ALLIGATOR_01 = { label = 'Alligator', group = 'reptile' },
    A_C_ALLIGATOR_03 = { label = 'Small Alligator', group = 'reptile' },
    A_C_ARMADILLO_01 = { label = 'Armadillo', group = 'small' },
    A_C_BADGER_01 = { label = 'Badger', group = 'small' },
    A_C_BAT_01 = { label = 'Bat', group = 'small' },
    A_C_BEARBLACK_01 = { label = 'Black Bear', group = 'bear' },
    A_C_BEAR_01 = { label = 'Bear', group = 'bear' },
    A_C_BEAVER_01 = { label = 'Beaver', group = 'small' },
    A_C_BIGHORNRAM_01 = { label = 'Bighorn Ram', group = 'deer' },
    A_C_BLUEJAY_01 = { label = 'Bluejay', group = 'bird' },
    A_C_BOAR_01 = { label = 'Boar', group = 'boar' },
    A_C_BUCK_01 = { label = 'Buck', group = 'deer' },
    A_C_BULL_01 = { label = 'Bull', group = 'large' },
    A_C_CALIFORNIACONDOR_01 = { label = 'California Condor', group = 'bird' },
    A_C_CARDINAL_01 = { label = 'Cardinal', group = 'bird' },
    A_C_CAROLINAPARAKEET_01 = { label = 'Carolina Parakeet', group = 'bird' },
    A_C_CEDARWAXWING_01 = { label = 'Cedar Waxwing', group = 'bird' },
    A_C_CHIPMUNK_01 = { label = 'Chipmunk', group = 'small' },
    A_C_CORMORANT_01 = { label = 'Cormorant', group = 'bird' },
    A_C_COUGAR_01 = { label = 'Cougar', group = 'predator' },
    A_C_COW = { label = 'Cow', group = 'large' },
    A_C_COYOTE_01 = { label = 'Coyote', group = 'predator' },
    A_C_CRANEWHOOPING_01 = { label = 'Whooping Crane', group = 'bird' },
    A_C_CROW_01 = { label = 'Crow', group = 'bird' },
    A_C_DEER_01 = { label = 'Deer', group = 'deer' },
    A_C_DUCK_01 = { label = 'Duck', group = 'bird' },
    A_C_EAGLE_01 = { label = 'Eagle', group = 'bird' },
    A_C_EGRET_01 = { label = 'Egret', group = 'bird' },
    A_C_ELK_01 = { label = 'Elk', group = 'large' },
    A_C_FOX_01 = { label = 'Fox', group = 'small' },
    A_C_FROGBULL_01 = { label = 'Bullfrog', group = 'small' },
    A_C_GILAMONSTER_01 = { label = 'Gila Monster', group = 'reptile' },
    A_C_GOAT_01 = { label = 'Goat', group = 'small' },
    A_C_GOOSECANADA_01 = { label = 'Canada Goose', group = 'bird' },
    A_C_HAWK_01 = { label = 'Hawk', group = 'bird' },
    A_C_HERON_01 = { label = 'Heron', group = 'bird' },
    A_C_IGUANADESERT_01 = { label = 'Desert Iguana', group = 'reptile' },
    A_C_IGUANA_01 = { label = 'Iguana', group = 'reptile' },
    A_C_JAVELINA_01 = { label = 'Javelina', group = 'boar' },
    A_C_LIONMANGY_01 = { label = 'Mangy Lion', group = 'predator' },
    A_C_LOON_01 = { label = 'Loon', group = 'bird' },
    A_C_MOOSE_01 = { label = 'Moose', group = 'large' },
    A_C_MUSKRAT_01 = { label = 'Muskrat', group = 'small' },
    A_C_ORIOLE_01 = { label = 'Oriole', group = 'bird' },
    A_C_OWL_01 = { label = 'Owl', group = 'bird' },
    A_C_OX_01 = { label = 'Ox', group = 'large' },
    A_C_PANTHER_01 = { label = 'Panther', group = 'predator' },
    A_C_PARROT_01 = { label = 'Parrot', group = 'bird' },
    A_C_PELICAN_01 = { label = 'Pelican', group = 'bird' },
    A_C_PHEASANT_01 = { label = 'Pheasant', group = 'bird' },
    A_C_PIGEON = { label = 'Pigeon', group = 'bird' },
    A_C_PIG_01 = { label = 'Pig', group = 'boar' },
    A_C_POSSUM_01 = { label = 'Opossum', group = 'small' },
    A_C_PRAIRIECHICKEN_01 = { label = 'Prairie Chicken', group = 'bird' },
    A_C_PRONGHORN_01 = { label = 'Pronghorn', group = 'deer' },
    A_C_QUAIL_01 = { label = 'Quail', group = 'bird' },
    A_C_RABBIT_01 = { label = 'Rabbit', group = 'small' },
    A_C_RACCOON_01 = { label = 'Raccoon', group = 'small' },
    A_C_RAT_01 = { label = 'Rat', group = 'small' },
    A_C_RAVEN_01 = { label = 'Raven', group = 'bird' },
    A_C_REDFOOTEDBOOBY_01 = { label = 'Red-footed Booby', group = 'bird' },
    A_C_ROBIN_01 = { label = 'Robin', group = 'bird' },
    A_C_ROSEATESPOONBILL_01 = { label = 'Roseate Spoonbill', group = 'bird' },
    A_C_SEAGULL_01 = { label = 'Seagull', group = 'bird' },
    A_C_SHEEP_01 = { label = 'Sheep', group = 'small' },
    A_C_SKUNK_01 = { label = 'Skunk', group = 'small' },
    A_C_SNAKEBLACKTAILRATTLE_01 = { label = 'Rattlesnake', group = 'reptile' },
    A_C_SNAKEFERDELANCE_01 = { label = 'Snake', group = 'reptile' },
    A_C_SNAKEREDBOA10FT_01 = { label = 'Large Boa', group = 'reptile' },
    A_C_SNAKEREDBOA_01 = { label = 'Boa', group = 'reptile' },
    A_C_SNAKEWATER_01 = { label = 'Water Snake', group = 'reptile' },
    A_C_SNAKE_01 = { label = 'Snake', group = 'reptile' },
    A_C_SONGBIRD_01 = { label = 'Songbird', group = 'bird' },
    A_C_SPARROW_01 = { label = 'Sparrow', group = 'bird' },
    A_C_SQUIRREL_01 = { label = 'Squirrel', group = 'small' },
    A_C_TOAD_01 = { label = 'Toad', group = 'small' },
    A_C_TURKEYWILD_01 = { label = 'Wild Turkey', group = 'bird' },
    A_C_TURKEY_01 = { label = 'Turkey', group = 'bird' },
    A_C_TURKEY_02 = { label = 'Turkey', group = 'bird' },
    A_C_TURTLESEA_01 = { label = 'Sea Turtle', group = 'reptile' },
    A_C_TURTLESNAPPING_01 = { label = 'Snapping Turtle', group = 'reptile' },
    A_C_VULTURE_01 = { label = 'Vulture', group = 'bird' },
    A_C_WOLF = { label = 'Wolf', group = 'predator' },
    A_C_WOLF_MEDIUM = { label = 'Wolf', group = 'predator' },
    A_C_WOLF_SMALL = { label = 'Wolf', group = 'predator' },
    A_C_WOODPECKER_01 = { label = 'Woodpecker', group = 'bird' },
    A_C_WOODPECKER_02 = { label = 'Woodpecker', group = 'bird' },
}
