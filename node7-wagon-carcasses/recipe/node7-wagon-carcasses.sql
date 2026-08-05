CREATE TABLE IF NOT EXISTS `node7_wagon_carcasses` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `wagonid` VARCHAR(16) NOT NULL,
    `owner_citizenid` VARCHAR(50) NOT NULL,
    `loaded_by` VARCHAR(50) NOT NULL,
    `animal_model` BIGINT NOT NULL,
    `animal_model_name` VARCHAR(64) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `group_name` VARCHAR(32) NOT NULL,
    `slot` INT UNSIGNED NOT NULL,
    `live_net_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` VARCHAR(20) NOT NULL DEFAULT 'loaded',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `node7_wagon_carcasses_slot_unique` (`wagonid`, `slot`),
    KEY `node7_wagon_carcasses_wagon_index` (`wagonid`),
    KEY `node7_wagon_carcasses_live_index` (`live_net_id`),
    CONSTRAINT `node7_wagon_carcasses_wagon_fk`
        FOREIGN KEY (`wagonid`) REFERENCES `node7_wagons` (`wagonid`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
