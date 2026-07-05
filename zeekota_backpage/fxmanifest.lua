fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'zeekota_backpage'
author 'ZeeKota Scripts'
description 'Server-authoritative ESX burner-phone drug dealing and client-network resource'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_inventory',
    'oxmysql'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/assets/*',
    'web/sounds/*'
}

shared_scripts {
    'config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/locales.lua',
    'locales/*.lua'
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/notifications.lua',
    'bridge/target.lua',
    'client/main.lua',
    'client/animations.lua',
    'client/peds.lua',
    'client/meetups.lua',
    'client/interactions.lua',
    'client/phone.lua',
    'client/admin.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/dispatch.lua',
    'bridge/notifications.lua',
    'server/database.lua',
    'server/security.lua',
    'server/configuration.lua',
    'server/statistics.lua',
    'server/clients.lua',
    'server/requests.lua',
    'server/sessions.lua',
    'server/transactions.lua',
    'server/admin.lua',
    'server/main.lua'
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'sql/*.sql',
    'README.md'
}
