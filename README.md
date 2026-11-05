# HunterSuite

**The complete Hunter toolkit for WoW Forever.** Also runs on Burning Crusade Anniversary.

One addon, one clean modern look: your pet, your Auto Shot, your range and every reminder a Hunter needs.

[Download on CurseForge](https://www.curseforge.com/wow/addons/huntersuite-beta) · [Changelog](CHANGELOG.md) · [Report a bug](https://github.com/sniffingpickles/HunterSuite/issues)

## Features

### Pet card
- Portrait, health and mood (Happy / Content / Unhappy) on one card.
- **Left-click feeds** the best food in your bags. **Right-click casts Mend Pet.**
- The game tells HunterSuite what your pet will eat. **Smart** mode uses the cheapest food that still gives full happiness, skips food that's too low level, and finishes small stacks first.
- Glows when your pet is unhappy or below your Mend Pet threshold.
- Shows up in combat whenever you need it, and stays out of the way when your pet is happy.

### Pet missing or dead
- A card appears the moment your pet is gone, even mid-fight.
- Left-click casts **Call Pet**, right-click casts **Revive Pet**.
- Hidden while mounted or on a flight path.

### Auto Shot timer
- Built on Forever's native swing timer, so it's accurate without the combat log.
- Shows the **0.5s aim window**: amber when you must stand still, red if you're still moving.
- Casts are drawn onto the bar and turn red when they'll clip your shot.
- Also shows a global cooldown line, how late your last shot was, and a flash on every shot.

### Range and dead zone
- **Melee**, **Dead zone** (inside 8 yards), **In range** or **Too far**, with a yard estimate.
- Docks beside the Auto Shot bar or stands on its own.

### Reminders
All reminders share one tidy stack. Right-click one to dismiss it.
- **No aspect**, and **Cheetah or Pack still on in combat**.
- **Growl on** in dungeons and raids, and **Growl off** while solo.
- **Track Humanoids** in battlegrounds, or whenever no tracking is active.

### Ammo, traps and stings
- **Ammo counter** with low and critical warnings and "~N minutes of shooting left". Hidden for thrown weapons and wands.
- **Trap timers:** arming, then the time left before each trap despawns.
- **Sting and Hunter's Mark** countdowns above enemy nameplates.

### Burning Crusade clients
- **Weaving Bar:** a Steady Shot rotation guide based on diziet559's rotation tools.
- **Auto-mark** enemy pets in battlegrounds.

## Settings and layout

- `/hs` opens the settings window. Its overview page has a switch for every module, and every option is a click away.
- `/hs edit` (or **Edit layout**) turns on edit mode:
  - Drag any frame; it snaps to a grid (hold Shift to place freely).
  - Arrow keys nudge the selected frame (Shift moves 10px).
  - Right-click a frame to reset it.
- Choose an accent colour, font, bar texture, HUD scale and shadows under **Appearance**. Fonts from EllesmereUI or SharedMedia are picked up automatically.

## Commands

| Command | |
|---|---|
| `/hs` | Settings window |
| `/hs edit` | Edit mode |
| `/hs feed` | Show which food the pet card will use |
| `/hs test` | Preview the alerts |
| `/hs diag` | Copyable client report (please include it in bug reports) |
| `/hs reset` | Reset all settings (asks first) |

**Key bindings:** Esc → Options → Key Bindings → AddOns → HunterSuite has **Feed Pet** and **Mend Pet**.

**Macro:**
```
#showtooltip Feed Pet
/click HunterSuiteFeedButton
```
Use `/click HunterSuiteFeedButton RightButton` for Mend Pet.

## Install

- **CurseForge app:** search for *HunterSuite*.
- **Manual:** download the zip from [CurseForge](https://www.curseforge.com/wow/addons/huntersuite-beta/files) or [GitHub releases](https://github.com/sniffingpickles/HunterSuite/releases). Extract the `HunterSuite` folder into your client's AddOns folder, for example `World of Warcraft\_forever_\Interface\AddOns` for WoW Forever. Restart the game after adding a new addon.

## WoW Forever notes

Forever runs the modern engine. Addons can't read the combat log, and in combat, encounters and PvP the game hides buff, cooldown and health details from addons. HunterSuite is built around that:
- Swing timing comes from the native swing timer.
- Aspect and sting timers follow your own casts.
- The pet cards use secure buttons that keep working in combat.
- Anything exact (food choice, aspect checks) is re-read the moment combat ends.

Auto-marking enemy pets is off on Forever, because raid marks are hidden during PvP matches.

## Upgrading from 3.x

- Your module on/off choices and main options carry over.
- Frame positions reset because every frame was redesigned. Use `/hs edit` to place them.

## Releasing

Push a version tag. The GitHub Action packages the addon, creates the GitHub release and uploads the file to CurseForge:

```
git tag -a v4.0.1 -m "HunterSuite 4.0.1"
git push origin v4.0.1
```

Write the release notes in `CHANGELOG.md` before tagging. The upload needs a `CF_API_TOKEN` repository secret (a token from [CurseForge](https://authors.curseforge.com/#/settings/api-tokens)).

---

**Author:** muggles · **Twitch:** [twitch.tv/muggles](https://twitch.tv/muggles)
