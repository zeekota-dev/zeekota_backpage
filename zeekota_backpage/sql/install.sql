CREATE TABLE IF NOT EXISTS `zeekota_backpage_settings` (
  `key` varchar(80) NOT NULL,
  `value` longtext NULL,
  `type` varchar(20) NOT NULL DEFAULT 'string',
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_drugs` (
  `id` varchar(64) NOT NULL,
  `item` varchar(64) NOT NULL,
  `label` varchar(80) NOT NULL,
  `icon` varchar(48) NOT NULL DEFAULT '',
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `min_quantity` int NOT NULL DEFAULT 1,
  `max_quantity` int NOT NULL DEFAULT 1,
  `min_price` int NOT NULL DEFAULT 0,
  `max_price` int NOT NULL DEFAULT 0,
  `sample_quantity` int NOT NULL DEFAULT 1,
  `sample_bonus` int NOT NULL DEFAULT 0,
  `extra_bonus` int NOT NULL DEFAULT 0,
  `max_extra_units` int NOT NULL DEFAULT 0,
  `reputation_requirement` int NOT NULL DEFAULT 0,
  `risk` int NOT NULL DEFAULT 0,
  `supported_archetypes` longtext NULL,
  `data` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_item` (`item`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_archetypes` (
  `id` varchar(64) NOT NULL,
  `label` varchar(80) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `ped_models` longtext NULL,
  `preferred_drugs` longtext NULL,
  `data` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_locations` (
  `id` varchar(64) NOT NULL,
  `label` varchar(96) NOT NULL,
  `area` varchar(64) NOT NULL DEFAULT '',
  `x` double NOT NULL DEFAULT 0,
  `y` double NOT NULL DEFAULT 0,
  `z` double NOT NULL DEFAULT 0,
  `heading` double NOT NULL DEFAULT 0,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `risk` int NOT NULL DEFAULT 0,
  `data` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_area_enabled` (`area`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_players` (
  `identifier` varchar(96) NOT NULL,
  `display_name` varchar(96) NOT NULL DEFAULT '',
  `handle` varchar(64) NOT NULL DEFAULT '',
  `reputation` int NOT NULL DEFAULT 0,
  `total_drugs_sold` int NOT NULL DEFAULT 0,
  `total_transactions` int NOT NULL DEFAULT 0,
  `total_money_made` int NOT NULL DEFAULT 0,
  `total_samples_given` int NOT NULL DEFAULT 0,
  `total_customers_contacted` int NOT NULL DEFAULT 0,
  `total_clients_gained` int NOT NULL DEFAULT 0,
  `requests_accepted` int NOT NULL DEFAULT 0,
  `requests_declined` int NOT NULL DEFAULT 0,
  `successful_sales` int NOT NULL DEFAULT 0,
  `failed_sales` int NOT NULL DEFAULT 0,
  `rejected_offers` int NOT NULL DEFAULT 0,
  `expired_requests` int NOT NULL DEFAULT 0,
  `average_sale_value` int NOT NULL DEFAULT 0,
  `largest_sale` int NOT NULL DEFAULT 0,
  `total_live_time` int NOT NULL DEFAULT 0,
  `drug_stats` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`),
  KEY `idx_handle` (`handle`),
  KEY `idx_reputation` (`reputation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_clients` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(96) NOT NULL,
  `customer_key` varchar(64) NOT NULL,
  `alias` varchar(96) NOT NULL,
  `avatar` varchar(12) NOT NULL DEFAULT 'ZK',
  `archetype_id` varchar(64) NOT NULL DEFAULT '',
  `archetype_label` varchar(96) NOT NULL DEFAULT '',
  `loyalty` int NOT NULL DEFAULT 0,
  `preferred_drug` varchar(64) NOT NULL DEFAULT '',
  `total_purchases` int NOT NULL DEFAULT 0,
  `total_spent` int NOT NULL DEFAULT 0,
  `last_purchase_at` int unsigned NOT NULL DEFAULT 0,
  `average_order_size` int NOT NULL DEFAULT 0,
  `reliability` int NOT NULL DEFAULT 100,
  `risk_rating` int NOT NULL DEFAULT 0,
  `status` varchar(24) NOT NULL DEFAULT 'active',
  `blocked` tinyint(1) NOT NULL DEFAULT 0,
  `metadata` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_identifier_customer` (`identifier`, `customer_key`),
  KEY `idx_identifier_loyalty` (`identifier`, `loyalty`),
  KEY `idx_blocked` (`blocked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_conversations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(96) NOT NULL,
  `customer_key` varchar(64) NOT NULL,
  `alias` varchar(96) NOT NULL,
  `avatar` varchar(12) NOT NULL DEFAULT 'ZK',
  `is_client` tinyint(1) NOT NULL DEFAULT 0,
  `status` varchar(24) NOT NULL DEFAULT 'pending',
  `request_id` varchar(64) NULL,
  `last_message` varchar(255) NOT NULL DEFAULT '',
  `unread_count` int NOT NULL DEFAULT 0,
  `active_meetup` tinyint(1) NOT NULL DEFAULT 0,
  `expires_at` int unsigned NOT NULL DEFAULT 0,
  `deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  `updated_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_identifier_updated` (`identifier`, `updated_at`),
  KEY `idx_request` (`request_id`),
  KEY `idx_customer` (`identifier`, `customer_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_messages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `conversation_id` int unsigned NOT NULL,
  `identifier` varchar(96) NOT NULL,
  `sender` varchar(24) NOT NULL,
  `body` varchar(255) NOT NULL,
  `kind` varchar(24) NOT NULL DEFAULT 'message',
  `metadata` longtext NULL,
  `expires_at` int unsigned NOT NULL DEFAULT 0,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_conversation_created` (`conversation_id`, `created_at`),
  KEY `idx_identifier_created` (`identifier`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_transactions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `transaction_id` varchar(64) NOT NULL,
  `identifier` varchar(96) NOT NULL,
  `customer_key` varchar(64) NOT NULL DEFAULT '',
  `request_id` varchar(64) NOT NULL DEFAULT '',
  `drug` varchar(64) NOT NULL DEFAULT '',
  `paid_quantity` int NOT NULL DEFAULT 0,
  `sample_quantity` int NOT NULL DEFAULT 0,
  `extra_quantity` int NOT NULL DEFAULT 0,
  `payment` int NOT NULL DEFAULT 0,
  `payment_type` varchar(24) NOT NULL DEFAULT '',
  `client_gained` tinyint(1) NOT NULL DEFAULT 0,
  `loyalty_change` int NOT NULL DEFAULT 0,
  `reputation_change` int NOT NULL DEFAULT 0,
  `meetup_location` varchar(64) NOT NULL DEFAULT '',
  `outcome` varchar(24) NOT NULL DEFAULT '',
  `metadata` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_transaction_id` (`transaction_id`),
  KEY `idx_identifier_created` (`identifier`, `created_at`),
  KEY `idx_request` (`request_id`),
  KEY `idx_outcome` (`outcome`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `zeekota_backpage_admin_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `category` varchar(32) NOT NULL,
  `action` varchar(64) NOT NULL,
  `identifier` varchar(96) NOT NULL DEFAULT '',
  `player_name` varchar(96) NOT NULL DEFAULT '',
  `server_id` int NOT NULL DEFAULT 0,
  `metadata` longtext NULL,
  `created_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_category_created` (`category`, `created_at`),
  KEY `idx_identifier_created` (`identifier`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
