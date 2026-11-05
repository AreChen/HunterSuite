# HunterSuite

The complete Hunter toolkit for **WoW Forever** (also runs on Burning Crusade Anniversary). One addon, one consistent look, all the tools a Hunter actually uses.

## What you get

### Pet card
- Portrait, health and mood (Happy / Content / Unhappy) on one card.
- **Left-click feeds** the best food in your bags. **Right-click casts Mend Pet.**
- The game tells HunterSuite what your pet will eat (`C_PetInfo.CanPetEatItem`). Food too far below your pet's level is skipped.
- **Smart** food choice uses the cheapest food that still gives full happiness, and finishes small stacks first.
- Glows when your pet is unhappy or below your Mend Pet threshold. In combat the health colour is still worked out by the client, even though health is secret.
- Visibility is driven by a secure state driver, so the card appears mid-fight when you need it.

### Pet missing
- A "No pet" or "Your pet is dead" card that appears the moment it matters, even in combat.
- Left-click casts Call Pet, right-click casts Revive Pet.
- Hidden while mounted or on a flight path.

### Auto Shot timer
- Built on Forever's native swing events (`PLAYER_SWING`). No combat log needed.
- Shows the 0.5s **aim window**: the bar turns amber when you must stand still and red if you are still moving.
- Casts are projected onto the swing, and turn red when they will clip your shot.
- Also shows a global cooldown line, how late your last shot was, and a flash on every shot.

### Range and dead zone
- Melee, **Dead zone** (inside 8 yd), In range, or Too far.
- Uses the client's swing-range checks, with yard estimates from LibRangeCheck.
- Docks next to the Auto Shot bar or stands alone.

### Reminders (one tidy stack)
- **No aspect**, and **Cheetah or Pack still on in combat**.
- **Growl on** in dungeons and raids, and **Growl off** while solo.
- **Track Humanoids** in battlegrounds, or a warning whenever no tracking is active.
- Right-click any alert to dismiss or snooze it.

### Ammo, traps, stings
- Ammo counter with low and critical warnings and a "~N minutes of shooting left" estimate. Hidden for thrown weapons and wands.
- Trap timers: arming, then the time left before each trap despawns.
- Sting and Hunter's Mark countdowns above enemy nameplates.

### TBC clients
- Weaving Bar: a Steady Shot rotation guide based on diziet559's rotation tools.
- Auto-mark enemy pets in battlegrounds.

## Moving things around

Type `/hs edit`, or click **Edit layout** in settings. In edit mode:
- Drag any frame. It snaps to the grid; hold Shift to place it freely.
- Arrow keys nudge the selected frame (Shift moves 10px).
- Right-click a frame to reset it.
- Esc or **Done** leaves edit mode.

## Commands

| Command | |
|---|---|
| `/hs` | Settings window |
| `/hs edit` | Edit mode |
| `/hs feed` | Show which food the pet card will use |
| `/hs test` | Preview the alerts |
| `/hs diag` | Copyable client and API report (paste this into bug reports) |
| `/hs reset` | Reset all settings (asks first) |

**Key bindings:** Esc → Options → Key Bindings → AddOns → HunterSuite has *Feed Pet* and *Mend Pet*.
**Macro:** `/click HunterSuiteFeedButton` feeds your pet. Use `/click HunterSuiteFeedButton RightButton` for Mend Pet.

## WoW Forever notes

Forever runs the modern (12.x) engine, and that engine restricts what addons can see:
- **Combat log:** addons can't read it at all.
- **In combat, encounters and PvP:** aura data, cooldowns and health come back as secret values.

HunterSuite is built for this:
- Swing timing comes from the native swing timer.
- Aspect and sting state come from your own casts.
- The pet card and pet-missing card use secure state drivers.
- Anything exact (food choice, aspect checks) is re-read the moment combat ends.

Auto-marking enemy pets is off on Forever, because raid marks are hidden during PvP matches.

## Upgrading from 3.x

- Your module on/off choices and main options carry over.
- Frame positions reset because every frame was redesigned. Use `/hs edit` to place them.
