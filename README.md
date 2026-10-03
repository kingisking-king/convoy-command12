# Convoy Command

A 3D convoy-defense game. Build a column, drive it through an ambush, and get the cargo trucks to the drop.

Three missions, each harder than the last:

1. **Dust Road** — open desert, infantry and technicals
2. **Pine Cut** — forest road, RPG teams and a tank
3. **High Pass** — mountain switchbacks, helicopters and armor

You win a mission when at least one cargo truck reaches the drop. You lose if every cargo truck is destroyed. Contract pay is added to your war chest and spent on the next column.

## Play on Windows

Download `ConvoyCommand-Windows-x64.zip` from the GitHub release (or from the pull request artifacts). Unzip it and double-click `ConvoyCommand.exe`.

- Windows 10 or 11, 64-bit
- Nothing else to install
- The game is one executable. Your campaign is saved next to your user profile and resumes from the main menu.

## Controls

### Menus

- Click **Campaign**, **Continue**, or **New Campaign**
- **F11** fullscreen
- **M** mute
- **Esc** back, or quit from the main menu

### Build phase

An angled camera looks down a wide yard at the start of the route. Place vehicles anywhere in that yard. The formation keeps that shape while it drives.

- **1–6** select Cargo, Humvee, APC, Tank, Anti-Air, or Repair
- **Left click** an empty cell to place the selected unit
- **Left click** a vehicle to select it, then drag it to another cell
- **Right click** removes a vehicle
- **R** rotates the selected vehicle
- **Q** loads a suggested wedge you can still edit
- **Enter** deploys
- The side panel names the convoy, picks camo, upgrades armor / weapon / speed, rearranges Line / Wedge / Box, and saves presets
- **Right-drag** orbits the camera, **mouse wheel** zooms
- **A / D** orbit, **W / S** zoom, **F** resets the camera

You must bring at least one cargo truck, and the formation has to fit the budget. Flank the cargo or put guns ahead of it. Anti-air is for helicopters. A repair truck patches the most damaged neighbor and prefers cargo. Do not put a cargo truck in front of the guns.

### Drive phase

Friendly guns fire on their own. You run the camera and three support abilities.

- **Right-drag** orbits, **mouse wheel** zooms, **F** snaps back behind the column
- **A / D** orbit, **W / S** zoom
- **Q** smoke — a thick drifting cloud; hostiles miss more for a few seconds
- **E** airstrike — a jet lines up on the densest group, then hits it. It does not damage your trucks
- **R** field repair — a burst of healing
- **Esc** pause

The minimap is the route. Yellow is cargo, green is escorts, red is hostiles.

## Units

| Unit | Role |
| --- | --- |
| Cargo Truck | The payload. Cheap, unarmed |
| Humvee | Fast mounted gun |
| APC | Armor and an autocannon |
| Tank | Heavy cannon, poor against aircraft |
| Anti-Air | Rapid guns, best against helicopters |
| Repair Truck | Heals a nearby vehicle, cargo first |

Hostiles are infantry, technicals, RPG teams, tanks, and helicopters. Helicopters ignore most of a tank's gun. Bring anti-air on the third mission.

## Grades and pay

- **S** — every cargo truck delivered, no escort lost
- **A** — every cargo truck delivered
- **B** — at least one cargo truck delivered
- **Fail** — every cargo truck destroyed

On a win you get salvage for part of the column, a contract fee, and bonuses for delivered cargo and kills. On a loss the war chest is unchanged.

## Develop

The project is Godot 4.7. The Windows player is a normal export with the data packed inside the exe.

Headless mission checks (quick columns must win, cargo with no escorts must lose):

```bash
godot --headless --path . -s res://tests/sim_test.gd
```

Export (Godot 4.7.2 and the matching Windows export templates):

```bash
tools/export_windows.sh
```

Vehicle, soldier, and nature meshes include CC0 models from Kenney (see CREDITS). Tanks, APCs, and helicopters are authored triangle meshes with camo textures.

Sound effects are generated, not recorded:

```bash
python3 tools/make_sfx.py
```
