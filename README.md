# ZeeKota Backpage

`zeekota_backpage` is a modular ESX FiveM resource for burner-phone driven drug dealing with recurring clients, server-authoritative sales, persistent messages, statistics, configurable drugs, customer archetypes, meetup locations, and an in-game admin dashboard.

The gameplay loop is built around going live on a ZeeKota Backpage phone app, receiving customer messages, accepting meetups, selling or sampling configured products, and building a permanent client list over time.

## Dependencies

Required:

- `es_extended`
- `ox_inventory`
- `oxmysql`

Optional:

- `ox_target`
- `cd_dispatch`
- `qs-dispatch`
- `ps-dispatch`
- `ox_lib` only if you choose to route notifications through it

## Installation Order

1. Copy `zeekota_backpage` into your server resources folder.
2. Import `sql/install.sql` into your database.
3. Confirm the existing ox_inventory item `burnerphone` exists.
4. Add the resource to your server config after the required dependencies:

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure zeekota_backpage
```

5. Restart the server or run `refresh` then `ensure zeekota_backpage`.

## Burner Phone Item

The script uses the existing item name:

```lua
burnerphone
```

If your item already exists, do not rename it. The resource registers an ESX usable item and also exposes an ox_inventory item export.

Optional ox_inventory item example:

```lua
['burnerphone'] = {
    label = 'Burner Phone',
    weight = 350,
    stack = false,
    close = true,
    client = {
        export = 'zeekota_backpage.useBurnerPhone'
    }
}
```

## Configuration

Edit `config.lua` for emergency defaults and first-boot values:

- framework and inventory resource names
- admin command and allowed groups
- phone prop, animation, and control settings
- session timing, cooldowns, request limits, and police requirements
- payment type, account, or item
- default drugs
- default customer archetypes
- default meetup locations
- dispatch, notification, logging, and risk options

After the SQL is installed, most gameplay settings can be managed from `/zeekotabackpageadmin`.

## Admin Dashboard

Default command:

```text
/zeekotabackpageadmin
```

Aliases:

```text
/backpageadmin
/zkbackpageadmin
/zkadmin
```

Server-side permission check:

```lua
ESX.GetPlayerFromId(source).getGroup() == 'admin'
```

`superadmin` is also enabled by default through `Config.Admin.Groups`.

Admin sections:

- Overview
- Drug Manager
- Customer Archetype Manager
- Meetup Location Manager
- Settings Manager
- Player Data Manager
- Logs

Admin actions are validated server-side for every callback.

Meetup locations can be created from the admin's current position. In `/zeekotabackpageadmin` > Meetup Locations, use `Get Current Location` to prefill coordinates, area, and heading, then review the label/risk before saving.

## Payment

Default payment is ESX account money:

```lua
Config.Payment = {
    Type = 'account',
    Account = 'black_money',
    Item = 'money'
}
```

Supported values:

- `account`
- `cash`
- `item`

For item payments, set `Type = 'item'` and `Item` to a valid ox_inventory item.

## Dispatch

Set `Config.Dispatch.Provider` to one of:

- `disabled`
- `cd_dispatch`
- `qs-dispatch`
- `ps-dispatch`
- `custom`

For custom dispatch:

```lua
Config.Dispatch.Provider = 'custom'
Config.Dispatch.CustomEvent = 'your_resource:server:yourDispatchEvent'
```

Alerts use configured chance, drug risk, archetype risk, zone risk, police jobs, delay, and blip radius. Exact coordinates are only sent when `Config.Dispatch.ExposeExactCoords = true`.

## Target Support

Default interaction is the ZeeKota Press E prompt.

```lua
Config.Interaction.Type = 'zeekota'
Config.Interaction.Key = 38
Config.Interaction.Distance = 2.0
Config.Interaction.TargetSupport = true
Config.Interaction.TargetResource = 'ox_target'
```

To use ox_target for customer interaction:

```lua
Config.Interaction.Type = 'target'
```

The selling interaction opens only from the customer interaction prompt/target selection after the ped exists. Accepting a meetup only marks the route and spawns the customer.

## Notifications

Default notifications use the resource NUI toast system. Other options:

```lua
Config.Notifications.Provider = 'zeekota'
Config.Notifications.Provider = 'ox_lib'
Config.Notifications.Provider = 'esx'
Config.Notifications.Provider = 'custom'
```

For custom notifications:

```lua
Config.Notifications.CustomEvent = 'your_resource:client:notify'
```

## Live Request Timing

By default, live dealers receive the first customer message after 30-60 seconds, then another request attempt every 30-60 seconds while live.

```lua
Config.Session.MinFirstRequestDelay = 30
Config.Session.MaxFirstRequestDelay = 60
Config.Session.MinRequestDelay = 30
Config.Session.MaxRequestDelay = 60
Config.Session.NoRequestChance = 0
```

The scheduler only pauses when the session ends, the pending request limit is full, or the player has no request-eligible product. Request eligibility checks the configured item, current inventory, reputation requirement, enabled state, and customer archetype compatibility.

## Adding Drugs

Use `/zeekotabackpageadmin` > Drug Manager, or edit defaults in `config.lua` before first boot.

Minimum fields:

```lua
{
    id = 'weed_bag',
    item = 'weed_bag',
    label = 'Bagged Weed',
    enabled = true,
    minQuantity = 1,
    maxQuantity = 5,
    minPrice = 95,
    maxPrice = 145,
    sampleQuantity = 1,
    sampleClientChanceBonus = 18,
    maxExtraUnits = 3,
    risk = 12
}
```

New drugs automatically appear in request generation, the interaction UI, client statistics, and admin tools.

Customer-facing request text resolves the item label from `ox_inventory` first. The configured `label` is used as a fallback, while `item` remains the internal spawn/item name used for inventory checks and removals. Existing-customer message templates can use `{drug}` and `{quantity}` placeholders.

## Adding Archetypes

Use `/zeekotabackpageadmin` > Customer Archetypes.

Example fields:

```lua
{
    id = 'casual',
    label = 'Casual User',
    pedModels = { 'a_m_y_hipster_01' },
    preferredDrugs = { 'weed_bag' },
    minQuantity = 1,
    maxQuantity = 4,
    budgetMultiplier = 1.0,
    patience = 600,
    acquisitionModifier = 4,
    risk = 10
}
```

## Adding Meetup Locations

Use `/zeekotabackpageadmin` > Meetup Locations.

Admins can add their current coordinates, edit coordinates, teleport to points, test-spawn customers, disable points, or delete points without editing code.

## Exports

Server:

```lua
exports.zeekota_backpage:GetDealerReputation(identifier)
exports.zeekota_backpage:GetDealerClients(identifier)
exports.zeekota_backpage:IsDealerLive(source)
exports.zeekota_backpage:CancelDealerSession(source)
exports.zeekota_backpage:AddDealerReputation(identifier, amount, reason)
```

Client:

```lua
exports.zeekota_backpage:OpenBackpage()
exports.zeekota_backpage:CloseBackpage()
exports.zeekota_backpage:IsBackpageOpen()
exports.zeekota_backpage:HasActiveMeetup()
```

ox_inventory item export:

```lua
client = {
    export = 'zeekota_backpage.useBurnerPhone'
}
```

## Events

Server-side events emitted:

```text
zeekota_backpage:server:dealerLive
zeekota_backpage:server:dealerOffline
zeekota_backpage:server:saleCompleted
zeekota_backpage:server:clientGained
zeekota_backpage:server:reputationChanged
```

Client-side events used by the resource:

```text
zeekota_backpage:client:openPhoneFromItem
zeekota_backpage:client:openAdmin
zeekota_backpage:client:forceClose
zeekota_backpage:client:notify
zeekota_backpage:client:syncState
zeekota_backpage:client:newRequest
zeekota_backpage:client:requestUpdated
zeekota_backpage:client:meetupStarted
zeekota_backpage:client:meetupEnded
```

## Security Model

The server owns:

- request generation
- requested drug and quantity
- offered price
- meetup location
- inventory checks and item removal
- payment award
- client acquisition rolls
- loyalty and reputation changes
- admin permission checks
- duplicate transaction locks
- distance checks

The client never submits price, reward, loyalty, reputation, or sale outcome values.

## Database Tables

Installed by `sql/install.sql`:

- `zeekota_backpage_settings`
- `zeekota_backpage_drugs`
- `zeekota_backpage_archetypes`
- `zeekota_backpage_locations`
- `zeekota_backpage_players`
- `zeekota_backpage_clients`
- `zeekota_backpage_conversations`
- `zeekota_backpage_messages`
- `zeekota_backpage_transactions`
- `zeekota_backpage_admin_logs`

Player data is stored by ESX character identifier, not server ID.

## Troubleshooting

Phone does not open:

- Confirm `burnerphone` exists in ox_inventory.
- Confirm the player actually has the item.
- Confirm `zeekota_backpage` starts after `es_extended`, `ox_inventory`, and `oxmysql`.
- Check for death, cuff, ragdoll, swimming, or other blocked states.

No requests arrive:

- Confirm the player has at least one request-eligible product. The item must exist in inventory, be enabled, meet reputation requirements, and match at least one enabled archetype.
- Confirm police requirements are met.
- Confirm the session is live and has not reached `Config.Session.MaxSimultaneousRequests`.
- Check server console/admin logs for `request_generation_failed` or `request_generation_error` if `Config.Debug = true`.
- Confirm drugs are enabled in `/zeekotabackpageadmin`.

Sales fail:

- Confirm the player has the requested quantity.
- Confirm payment configuration is valid.
- Confirm the player is close to the customer.
- Check server console logs for validation failures.

Admin command denied:

- Confirm the ESX group is `admin` or is listed in `Config.Admin.Groups`.
- Permission is validated server-side.

## Debug Mode

Set:

```lua
Config.Debug = true
```

Also enable:

```lua
Config.Logging.Console = true
Config.Logging.LogSuspiciousEvents = true
```

## Upgrade Notes

1. Back up the database.
2. Replace the resource folder.
3. Review `config.lua` for new defaults.
4. Apply any new SQL migrations if provided in a future release.
5. Use `/zeekotabackpageadmin` > Settings > Refresh Cache.

## File Tree

```text
zeekota_backpage/
|-- fxmanifest.lua
|-- config.lua
|-- shared/
|   |-- constants.lua
|   |-- locales.lua
|   `-- utils.lua
|-- client/
|   |-- main.lua
|   |-- phone.lua
|   |-- interactions.lua
|   |-- meetups.lua
|   |-- animations.lua
|   |-- peds.lua
|   `-- admin.lua
|-- server/
|   |-- main.lua
|   |-- sessions.lua
|   |-- requests.lua
|   |-- transactions.lua
|   |-- clients.lua
|   |-- statistics.lua
|   |-- configuration.lua
|   |-- security.lua
|   |-- admin.lua
|   `-- database.lua
|-- bridge/
|   |-- framework.lua
|   |-- inventory.lua
|   |-- dispatch.lua
|   |-- target.lua
|   `-- notifications.lua
|-- web/
|   |-- index.html
|   |-- css/
|   |-- js/
|   |-- assets/
|   `-- sounds/
|-- locales/
|   `-- en.lua
|-- sql/
|   `-- install.sql
`-- README.md
```
