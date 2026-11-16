# QBCore Antilag & 2-Step Launch Control

A complete overhaul and expansion of the original Antilag script for **FiveM (QBCore)**. Instead of relying on a static vehicle whitelist, this version turns Antilag and 2-Step Launch Control into a **useable tuning item** with **database persistence**, **Entity State Bags**, a **dynamic NUI status display**, and **functional launch traction mechanics**.

> **Credits:** Based on the original script by [yorick2002](https://github.com/yorick2002). Completely reworked, expanded, and optimized for QBCore by **Thomas**.

---

## Features

- **Useable Tuning Item (`antilag_kit`):** Players can install the kit directly on their current vehicle from the driver's seat.
- **Database & State Bag Persistence:** Installation status is saved in `player_vehicles` and synced via FiveM Entity State Bags across server restarts and garage respawns.
- **2-Step Launch Control with Grip Boost:**
  - Hold **Shift** + **W / S** while stationary to build boost at the configured `LaunchRPM`.
  - After **2 seconds** of charging, the NUI indicator switches from **Red** to **Green**.
  - Releasing the launch temporarily increases low-speed traction (`fLowSpeedTractionLossMult`) for 1.5 seconds for a hard launch off the line.
- **Antilag System:** Produces realistic exhaust flames and custom distance-attenuated backfire audio when lifting off the throttle at high RPM.
- **Dynamic NUI HUD:** Displays `ANTILAG: OFF`, `ANTILAG: ON`, and blinking `LAUNCH ACTIVE` states only when sitting in an equipped vehicle.

---

## Installation

### 1. Database
Execute the included `sql.sql` file in your database to add the persistence column to `player_vehicles`:
```sql
ALTER TABLE `player_vehicles` ADD COLUMN `antilag_installed` TINYINT(1) NOT NULL DEFAULT 0;

```

### 2. QBCore Shared Item

Add the item to your `qb-core/shared/items.lua` and place `antilag_kit.png` inside your inventory's `html/images/` folder:

```lua
['antilag_kit'] = {
    ['name'] = 'antilag_kit',
    ['label'] = 'Antilag / 2-Step Kit',
    ['weight'] = 1000,
    ['type'] = 'item',
    ['image'] = 'antilag_kit.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'Installs a 2-Step Launch Control and Antilag module onto your vehicle.'
},

```

### 3. Garage Persistence (`qb-garages`)

To ensure vehicles retain their Antilag state when taken out of a garage, add the following snippet inside your `qb-garage:server:spawnvehicle` callback in `qb-garages/server/main.lua` right after the vehicle is spawned and the plate is set:

```lua
local result = MySQL.query.await('SELECT antilag_installed FROM player_vehicles WHERE TRIM(UPPER(plate)) = ?', { QBCore.Shared.Trim(string.upper(plate)) })
if result[1] and (result[1].antilag_installed == 1 or result[1].antilag_installed == true) then
    Entity(veh).state:set('has_antilag_installed', true, true)
end

```

### 4. Server Config

Add `ensure v2rp-2step` (or your chosen folder name) to your `server.cfg`.

---

## Usage & Controls

* **Install Kit:** Sit in the driver's seat of a vehicle and use the `antilag_kit` item.
* **Toggle Antilag:** Type `/antilag` in chat to switch Antilag ON or OFF.
* **Activate 2-Step Launch Control:** Hold **Left Shift** + **W** (or **S**) while below the launch RPM threshold. Wait 2 seconds until the HUD indicator turns green, then release to launch.

---

## Configuration (`config/config.lua`)

| Option | Default | Description |
| --- | --- | --- |
| `explosionSpeed` | `350` | Maximum delay (in ms) between antilag backfires. |
| `RPM` | `0.65` | Minimum RPM ratio (`0.0` – `1.0`) required to trigger antilag on throttle lift. |
| `LaunchRPM` | `4000.0` | Target RPM limiter during 2-Step Launch Control. |
| `flameSize` | `1.2` | Scale of the exhaust flame particles. |
| `flameDuration` | `400` | Duration (in ms) of long antilag flames. |
