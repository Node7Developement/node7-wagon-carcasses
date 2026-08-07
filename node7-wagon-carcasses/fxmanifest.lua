fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'node7-wagon-carcasses'
author 'NODE7 Development Studios'
description 'Independent physical animal-carcass storage for NODE7 owned wagons.'
version '2.0.1'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/main.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'node7-core',
    'node7-menu',
    'node7-hunting',
    'node7-wagons'
}
