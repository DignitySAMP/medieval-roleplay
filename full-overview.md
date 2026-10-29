# Medieval Roleplay, the full overview

This is every system in the gamemode, grouped by area. Staff commands are listed under the system they belong to. The short version is in the [README](README.md).

## Characters

Accounts and login
 - One account per player name. The SA-MP name has to be 3 to 20 letters or digits. If it isn't, the player is told to reconnect with another name and gets kicked. Passwords are 6 to 64 characters and hashed with bcrypt at cost 12 (two bcrypt threads).
 - On connect the player goes into a private virtual world (100000 plus their id). They see a fixed night-time camera over the Talmberg castle and village, with the logo up. The camera is re-applied 150, 500, 1000 and 2000 ms after every scene change, because the client drops camera calls right after a spectate toggle or a spawn.
 - The login only starts once the client says it has finished downloading models, with a 30 second fallback timeout. If the database isn't ready yet, it retries every 400 ms.
 - A player who isn't on the open.mp launcher first gets a warning panel about exploits in other clients. Everyone then gets a welcome panel. It says the server is set in a fictional kingdom in the 1200s and that roleplay has to be historical. A short summary is also left in chat so you can read it back.
 - Existing accounts get a password dialog with 3 tries. Three wrong passwords and you're kicked. Leaving the dialog asks for confirmation and then kicks you.
 - New accounts pick a password twice (the two entries have to match) and then take the roleplay quiz. The account row is only created once the quiz is passed, so a failed quiz leaves no account behind.
 - Every login, failed password, registration, quiz failure and quiz ban is written to an auth log table with the account, name, event and IP.
 - The staff level and loremaster flag are re-read from the database when a character loads, so a promotion applies without a relog.
 - The account carries an admin level (0 none, 1 trial, 2 mod, 3 admin, 4 manager) and a loremaster flag. Loremasters hand out culture unlock points (see Cultures and languages). Managers count as loremasters too.
 - Bans are checked by the staff module right after authentication. A quiz ban is stored against the IP address.
 - Staff: /loremaster <player> toggles the loremaster rank (manager).
 - This repository still runs the "test stage" (account-teststage.pwn). Every real player is treated as manager level and nothing of it is saved. Remove that file and its single call in Account_GetAdminLevel before a public launch.
 - The accounts table has an email column and a whitelist column. The whitelist value is set to approved on registration, but nothing in the gamemode reads either of them. I never got to wiring that up.

Roleplay quiz
 - A new account answers 8 questions drawn at random from a pool of 42 and needs 5 right. The order of the three answers is shuffled for each question. You get one panel per question and click the answer.
 - The questions cover in character versus out of character, metagaming (Discord, streams, /b), powergaming, playing fear, consent before intimate or cruel scenes, character death and revenge, going away or logging off to dodge a scene, staying in period (no phones, no elections, period names), using /me and /do properly, reporting bugs and rule breaks, and riding a horse through a crowd.
 - A failed quiz is logged with the score. The same name or the same IP has to wait 30 minutes before trying again. The player sees the score and the wait and then gets disconnected.
 - Three failures within 12 hours (counted by name or by IP) ban the IP for good. The ban text points to the Discord invite for appeals. Passing clears the earlier failures.
 - The staff module writes the quiz ban into the bans table and tells the staff who are on. A banned player who comes back sees a "Banned" panel and gets kicked.
 - Staff: /quizreset <name> (manager) clears the failed tries for that name and for every IP it used. It also lifts any quiz ban on those addresses.

Sessions, away and idle logout
 - Every player moves through a session state machine with the states connecting, auth_register, auth_login, character_select, character_create, spawning, playing, dead, deceased and disconnecting. Other modules hook the state change.
 - Activity counts when the player does something. Travel only counts when it gets somewhere (10 metres in 5 minutes, sampled every 30 seconds, so walking in circles doesn't count). Talking, using a panel, swinging a weapon, working at a station, praying, being blessed, using an emote near another player and paired emotes all count too.
 - After 5 minutes without activity the nametag shows "(away)". Away players can't be hit by melee attacks or projectiles, and they earn no talent time.
 - After 15 minutes idle the player gets a warning two minutes before and is then logged out with the character saved. The limit is 30 minutes in a rented room or lying in a bed.

Character slots and selection
 - Each account has 2 character slots. The select panel lists each slot with the character name and the date it was last played, or "Empty slot", or "Deceased". Dead characters can't be played.
 - A Graveyard button shows up as soon as the account has at least one dead character (see Graveyard).
 - Characters are saved by the periodic player save, on a forced save at logout or character switch, and when the player leaves the playing state. Position, interior, world, health, warmth, hunger, thirst and the weapon and shield in hand are stored. Positions inside the private scene worlds (login, creator, tutorial) are never saved.
 - A module can override one spawn (the tutorial island does this) and a fly-mode landing can put a character at a chosen spot. A saved interior with a ground-level z is reset to the open world. Every spawn fades in from black over 3.5 seconds while the character gets up from the ground, and the camera is put behind the player.
 - The class selection screen is never shown. After a death the client's class request goes straight to a respawn.
 - Other systems register busy checks (up to 24) with the character module, so emotes, interaction and similar systems know when a character is mid-action. Anything that isn't on foot counts as busy.

Character creator
 - A new character goes through a death warning, identity, nature (attributes), marks (traits), trade (lifestyle) and a summary, in that order. The scene is a frozen ped on a creator spot with the camera in front of it.
 - Death warning. A panel explains that every character has one life, that each death takes one off the life clock, that the clock depends on age, that a grave illness costs two, and that at zero the character is marked by death and the next death is permanent. The button unlocks after 3 seconds.
 - Identity. Sex (man or woman), look, given name, family name, age, culture and origin. Names are letters only, capital first, 3 to 20 characters, and the full name has to be unique on the server. You change the look with the left and right keys and confirm with Space. There are 45 starter looks for men and 9 for women. 140 ped skins are registered in total (starter looks, role skins such as knights, priests, bandits and kings, and child skins).
 - Ages on offer are 16, 18, 20, 25, 30, 35, 40, 45, 50, 55 and 60.
 - Attributes. Five attributes (Willpower, Craftmanship, Intelligence, Honor and Grace, Piety), each 1 to 5, with 10 points in total, so 5 are free to spend. Clicking an attribute adds a point. At the cap it falls back to 1, and "Start over" resets everything to 1.
 - Origins. Village peasant (+1 Willpower, 20 pfennig), Town burgher (+1 Honor and Grace, 60 pfennig), Forest folk (+1 Craftmanship, 15 pfennig), Monastery ward (+1 Piety, 10 pfennig), Soldier's child (+1 Willpower, 30 pfennig), Foreigner (+1 Intelligence, 40 pfennig). The bonus is added on top of the chosen points, so a stat can end at 6. The economy module hands over the pfennig when the character is created.
 - Traits. Two of sixteen (see Traits). Clicking a taken trait drops it again, and a third pick is refused.
 - Lifestyle. Farmhand, Kitchen hand, Apprentice, Novice or Recruit. Each is a start location (a farm, a tavern kitchen, a craftsman's bench, the chapel, the guard post). It's stored as the saved position of the new character and of heirs.
 - Every new character starts on the tutorial island and reaches their lifestyle spawn after finishing it.
 - Origin, culture and lifestyle decide the starting coin, the attribute bonus, the spawn, the language and the character panel text. No other system reads them yet.

Cultures and languages
 - 86 cultures in 22 culture groups (North Germanic, Central Germanic, West Germanic, Latin, Iberian, Byzantine, Celtic, Finno Ugric, Baltic, Altaic, Arabic, East Slavic, West Slavic, South Slavic, Magyar, Iranian, African, Israelite, Indo Aryan, Dravidian, Tibeto Burman, Chinese), each with its own colour. Every culture has a written paragraph about its ways. It shows on the character panel when the player clicks their people.
 - Only four cultures are open to a new account (German, Bohemian, Polish, Hungarian). The others are locked until a culture unlock point is spent. An unlock is permanent and applies to every character on the account. The picker shows "x of y open" for each group, and a locked culture offers to spend a point if the player has one.
 - Staff and loremasters use /cultureunlock <player> [points] to give culture unlock points (loremasters and managers). Points and unlocks are stored per account.
 - Languages. There are 23, which are Common and one tongue per culture group. Everyone knows Common and the tongue of their own culture group and nothing else. /language switches between the two.
 - Speech in a tongue (say, shout, whisper) reaches everyone in range. A listener who doesn't know it sees the words scrambled letter by letter, with spaces and punctuation left in place. The line also names the tongue.
 - A character can't learn another language.

Death, life clock and ageing
 - Each character has a life clock that is set from their age. Under 30 it is 5 deaths, 30 to 44 is 4, 45 to 54 is 3, 55 to 64 is 2, older is 1. Willpower 5 adds one. A baptised heir starts with one extra.
 - Characters age with the calendar. One year of age passes every 30 in-game days (a game day is 5 real hours, 3 by day and 2 by night). The clock is lowered when the character ages into a lower bracket, and the player gets a birthday message.
 - A blessing from the faith module can hold the ageing back by a number of minutes.
 - A death takes 1 off the clock, or 2 when the cause was an illness. After a death the character respawns 5 seconds later at the chapel (one is defined, at the Novice start). They wake with hunger and thirst at 50 and warmth reset, with a notice that they come to at the chapel weak and hungry. All wounds are cleared on death.
 - At 0 the character is marked by death and a buff says so. A last rites anointing from the faith module adds a "Last rites" buff, which is removed on the next death.
 - Dying with the clock at 0 is permanent. The slot is freed and the character moves to the Graveyard with the cause of death, the age at death and the in-game date.
 - A marked character can retire instead of waiting. Click the Age line on the character panel and confirm twice. A retired character ends the same way, with no farewell delay, and the estate passes in full.
 - Staff: /lifeclock <player> <deaths left> (admin).

Heirs, spouse and children
 - A character is wed through the faith module. They ask for the banns at the monastery church altar and the priest weds them once the banns have been read. The spouse is an NPC of the opposite sex, 16 to 60, with random attributes and one trait, and dies of old age between 55 and 75. There is no player to player marriage.
 - Staff: /spouse <player> <given name> [age] (admin) weds a character straight away.
 - The Family tab on the character panel shows the spouse, a countdown while a child is on the way, and up to 4 children. "Try for a child" is refused when there is no spouse, a child is already on the way, the household has 4 children, or the mother is over 45. A child is born 6 days later and the player names it in a dialog.
 - Children grow four times as fast as adults and come of age at 18, about 135 in-game days after birth. At that point their stats are rolled from both parents (the average with a small random spread), and each parent trait is passed on with a 30 percent chance. A few clashing pairs are rejected (Glutton and Frugal, Early riser and Heavy sleeper, Soft-hearted and Cold-blooded).
 - When a character dies for good or retires, the player is offered the grown children as heir. The heir takes the freed slot as an 18 year old with the family name, culture, origin and lifestyle, the child's traits and stats with +1 on the parent's strongest attribute, and a random starter skin. Every trade level is halved (minimum 1). The estate pays 75 percent of the parent's coin (all of it on retirement) and is claimed on the heir's first load.
 - A player whose children are too young is told to come back through the Graveyard once one comes of age.

Graveyard
 - The Graveyard on the character list shows the last 8 dead or retired characters. Opening one shows age, date and cause of death, whether they died absolved, culture and origin, starting trade, traits, attributes and children. If a slot is free and a grown child hasn't been chosen yet, the grave offers to choose an heir.

Tutorial island
 - Every new character spawns in a private virtual world (200000 plus their id) on a baked copy of the original tutorial island, with a palisade, mud roads and a letter on a table. The realm map is switched off for that player while they're there. A donkey waits at the stables.
 - The steps are walking to the weapon rack, opening the bag, taking a club, drawing it, swinging in all four directions, sheathing it, raising the fists, throwing a shove, a hook and a kick, dodging backwards and sideways, introducing yourself with H, walking to the camp, opening crafting, building a station, placing it, roasting a fish, reading the four tabs of the character panel, mounting the donkey and riding to the exit.
 - Eleven briefing panels explain the steps. The step is saved on the character, and a returning player resumes at the nearest checkpoint. A burnt fish is replaced.
 - On completion the player gets a water skin, the screen fades out, and the character wakes at their lifestyle spawn. A last briefing points to the village families, errands, Bohuslav the trader at Talmberg market and the notice boards.
 - Newcomer's warmth. For the first 60 minutes of active play time the cold can't touch the character. A buff with a countdown shows it.
 - Staff: /tutskip skips the tutorial (manager).

Character panel
 - Opened with Sprint + Walk together (Space + left Alt) while on foot and out of combat, work and the saddle, or from the bag under Character. It stores nothing and only reads the other systems.
 - Tabs are You, Health, Skills, Buffs, Family and a Ledger button that hands over to the economy ledger.
 - You shows name, age, people, upbringing, life, the church rank if there is one, a pip bar for each attribute, the group line (filled in by the groups module) and both traits with their text.
 - Health shows health, stamina, fed, hydrated and warmth, the temperature outside, cleanliness, load, rest, the bleeding rate, the worst wound on each body part, and the illnesses with their current cue. An undiagnosed illness shows as "You feel ...".
 - Skills shows the talent points to spend and the level of every trade the character has practised.
 - Every line can be clicked to read a longer explanation.

Buffs
 - Up to 12 buffs per player, each with a key, a name, a text and an optional timer. The character panel lists them all. Three HUD slots show the ones with a timer, sorted by time left, with a bar. They refresh every 15 seconds.
 - Used by traits, fatigue, carrying, the newcomer's warmth, kind heart and remorse, the life clock mark and last rites, and others.

Needs (hunger and thirst)
 - Hunger and thirst run from 100 to 0 and are saved on the character. Hunger falls 4 points per in-game hour and thirst 6 (an in-game hour is about 12 real minutes). Sprinting or working drains 50 percent faster and standing still 33 percent slower. Heat doubles thirst and freezing doubles hunger.
 - Below 20 the character gets a message and the stamina cap drops to 50. At 0 the character loses health, about 2 per in-game minute, with the source "starvation" or "thirst".
 - Food and drink are used from the bag (N) in portions, bites and sips. A meal plays an eating or drinking animation for 2.5 seconds with the item model in hand. Eating is refused with the guard up or while still eating. Ale also feeds a little hunger. Item stars change the amount.
 - Illness changes how fast the needs drain. Hardy, Glutton, Wanderer and Willpower change the hunger rate.

Vitals (health and stamina)
 - Health and stamina run from 0 to 100 and are kept by the server. The engine health is only a display mirror, so a client can't change it, and a drop to 0 kills the character on purpose.
 - Stamina is spent by the combat and work systems. It comes back at 25 per second once 3 seconds have passed without spending. The regeneration rate is scaled by traits and the time of day.
 - Several independent stamina caps apply and the lowest wins. They come from hunger or thirst, illness, a torso wound, fatigue and the remorse mood. Illness can also lower the health limit.
 - A blood overlay fades in below 75 health. The HUD shows bars for health, stamina, hunger, thirst and warmth.

Warmth
 - Warmth runs from -1000 to 1000 and is saved on the character. The bands are Freezing (-600 and below), Cold (below -200), Fine, Warm (above 200) and Hot (600 and above). There are screen effects for cold and heat, and messages when the band changes.
 - It drifts towards what the weather asks for. The calendar gives the temperature at the player's position. Each 3 degrees under 18 C needs one more layer of clothing, and the character wears 6 layers by default (12 at most). The drift per second is the gap between the layers needed and the layers worn. Standing near a lit fire speeds up recovery.
 - Freezing costs 0.2 health per second. Entering Freezing gives the Chills illness, and chills still in Freezing at the next in-game hour turn into frostbite. Entering Hot gives heatstroke. Hardy needs one more layer, and Thick-skinned warms and cools at half speed.
 - Cold breath. Below 5 C outdoors the character's breath shows as a puff on the head.
 - Staff: /warm toggles cold immunity, and /breath cycles cold breath between automatic, always and off (trial).

Fatigue and sleep
 - Fatigue runs from 0 to 100 and is saved. Tired from 50 (stamina cap 85, slightly clumsier at work) and Exhausted from 80 (stamina cap 70, clumsier again, and a 1 percent chance each hour of catching a cold).
 - It rises each in-game hour by 2.5 by day and 3.5 by night, plus 1 while riding. Finished work adds 3 and blows taken add 0.5 each (at most 6 per hour). Being away for an hour or more counts as a night's sleep and clears it on login.
 - Each real minute it eases by 2 while sitting or lying, by 2 more beside a fire and by 1 inside a house or inn. A meal eases it by 3.
 - Sleeping. Lie down (Walk + N, Lying) and after 8 seconds in a bed, or 30 seconds on the ground, the screen fades and the character wakes with fatigue brought down to a floor that depends on the bed. Own bed 0, a borrowed bed 10, straw 25, the bare ground 40, and 10 worse for cold or wet weather outdoors. Sleeping in an own or borrowed bed also counts as rest for illnesses.
 - Staff: /fatigue [0-100] shows or sets your fatigue (trial).

Hygiene
 - Dirt runs from 0 to 100 and is saved. It rises by 1 every 3 minutes of play, by 4 after each finished work task, by 3 for each wound and by 20 when pelted in the pillory.
 - Grimy from 35, Stinks from 60, Reeks from 85. From Stinks the nametag shows a cue and flies follow the character (1 fly object at Stinks, 3 at Reeks). Traders charge 15 percent more at Stinks and 30 percent more at Reeks. Families won't seat a character who reeks, and several NPCs comment on the smell.
 - A character is washed at a washtub (the market, the church village, the guardhouse) or in a river, handled by the yard module.
 - Staff: /dirt [0-100] reads or sets your dirt (trial).
 - There is a help entry called "Why do flies follow me?".

Wounds
 - Six body parts (head, torso, left and right arm, left and right leg) and four wound kinds (cut, stab, bruise, broken bone), each at three severities (graze, open, grave). Up to 12 wounds per character, saved with a flag set.
 - Melee hits pick the body part from the swing direction and whether the attacker is behind. Arrows hit the head at 25 damage or more, the torso at 15 or more and an arm otherwise. Damage under 5 is a graze, under 10 open, otherwise grave. Daggers, spears and bows stab, blunt weapons bruise (or break a limb from 9 damage), the rest cut. A fall of 15 damage bruises a leg, 25 hurts it more and 40 breaks it. Blocking a blow of 8 or more bruises the left arm.
 - Cuts and stabs bleed. The rate depends on kind and severity, eases off as health falls, and a bandage stops it at once. Blood pools appear on the ground for 60 seconds, and the bleeding character drops up to 25 puddles that follow them.
 - Effects. A torso wound caps stamina. A hurt weapon arm weakens swings (down to 70 percent, 50 percent if broken). A broken left arm can't block. A broken leg that isn't splinted makes the character stumble and fall when running (hold Walk to limp along) and forces them off a horse.
 - Healing only runs while a wound isn't bleeding. It takes 10 minutes of play for a graze, 1 hour for an open wound and 4 hours for a grave one. Stubborn slows it. Resting in an infirmary bed doubles it. Stitching or setting a bone at the infirmary halves it.
 - Open cuts and stabs can fester. A bandage and cleaning (water, ale, beer or mead from the bag) lower the odds a great deal. A festering wound won't heal and brings the Infected wound illness until a lay brother or sister at the monastery infirmary lances it.
 - A broken bone that is splinted heals straight. An unsplinted one leaves a crooked limb mark, and a grave cut or stab leaves a scar.
 - Bandage and splint items from the bag open a picker for yourself or any player in reach. A bandage also gives back a little health.
 - Staff: /woundme [part 0-5] [kind 0-3] [severity 1-3] and /unwound (admin).

Bleeding (injury)
 - A short bleeding state with the blood puddle trail. A bleeding wound starts it, and a bandage, a revive or leaving the playing state stops it. It lasts at most 60 seconds if the character isn't struck down.

Ailments
 - Twenty ailments with one to five stages each. They are chills, frostbite, heatstroke, flux, sting swelling, lingering wound, broken bone, dust lung, alcoholism, cough, fever, ague, rotten teeth, infected wound, scurvy, plague, pox, melancholy, madness and poppy hunger.
 - Each stage has a cue shown over the head, a first-person line, a length in in-game days and effects. The effects are a stamina limit, a health limit, multipliers on how fast hunger and thirst drain, a work penalty and an hourly health drain. Some stages knock the character down, and some spread to players within 3 metres (10 percent per in-game hour). The last stage of heatstroke, flux, fever, infected wound, scurvy and plague is lethal.
 - Progress is turned each in-game day. Care slows an illness. Hunger and thirst of 50 or more, a comfortable warmth, Willpower 4 or more, treatment and sleeping in a bed each count. With enough care the illness steps back a stage, and with too little its severity grows. A lethal stage at severity 50 or more kills.
 - Some illnesses leave a permanent mark when they end (scar, lost fingers, crooked limb, pockmarks, missing teeth). Lost fingers and a crooked limb add a work penalty. Rotten teeth that run their course turn into a fever from an abscess. A wound that reaches the infection threshold turns into gangrene.
 - Sources are cold and heat, exhaustion, dirty or festering wounds and pestilence events. Illnesses are saved and survive relogs. A healer's diagnosis turns "You feel ..." into the real name on the character panel.
 - Staff (manager): /ailment <player> <0-19>, /ails <player>, /ailturn <player>, /treat <player> <ailment> [quality 1-5], /cure <player> <ailment>.

Traits
 - Sixteen traits, two per character. They are Hardy, Devout, Glutton, Thick-skinned, Silver tongue, Thief's hands, Early riser, Brawler, Frugal, Keen eye, Soft-hearted, Stubborn, Bookish, Wanderer, Cold-blooded and Heavy sleeper.
 - Implemented effects. Hardy gets hungry 20 percent slower and needs one more layer against the cold. Glutton gets 25 percent more from food and gets hungry 25 percent faster. Thick-skinned takes 15 percent less damage and warms at half speed. Early riser regains stamina 30 percent faster by day and 30 percent slower at night. Brawler hits 15 percent harder and blocks cost 50 percent more. Frugal gets 15 percent less from food. Keen eye gets one extra from 1 in 4 wild gathers. Stubborn has 50 percent longer to be helped up when struck down and heals 25 percent slower. Bookish finds work at a station more forgiving but tires faster when gathering. Wanderer gets hungry and thirsty 20 percent slower while walking. Devout has a priest's blessing last 50 percent longer. Thief's hands finds key sequences and tool-less work easier. Heavy sleeper regains stamina faster at night and slower until midday. Silver tongue gets 10 percent better prices from traders. Cold-blooded gets 20 stamina back for finishing off someone who is down.
 - Soft-hearted. Helping someone to their feet gives a 10 minute "Kind heart" buff (stamina comes back 30 percent faster). Striking someone down or finishing them gives a 10 minute "Remorse" buff that caps stamina at 90.
 - Willpower above 2 also cuts hunger by 5 percent per point.
 - Every trait with an effect is listed as a buff on the character panel. There is a help entry, "What do my traits do?".
 - The creator text for Devout (sins weigh double), Thief's hands (sin creeps in), Keen eye (sleep badly), Cold-blooded (mercy does not shake you) and Heavy sleeper (slow mornings) promises more than the effects table does. Only the effects listed above are wired. I never got to the rest.

Carrying
 - Everything has a weight. The carry limit is 25 kg plus 3 kg per point of Willpower, plus 4 kg for a satchel or 10 kg for a backpack in the bag. Over the limit the character can't sprint. Over one and a half times the limit they can only walk, and breaking that pace winds them for 1.5 seconds. Nothing is ever refused.
 - Bulky loads (logs, sacks, barrels, stone blocks, coffers, carcasses) are carried in the arms or on the shoulder, with a model attached and a carrying pose. One load means no sprint, jump or weapon, and two or more mean walking only. Crouch puts a load down at your feet, a blow knocks it out of your arms, and drawing a weapon drops it.
 - Satchels, backpacks and belt pouches show on the back and open as containers from the bag, with the contents stored by container id. Baskets and creels show in the left hand and hold produce and fish.
 - A buff names the current state (Heavy, Overloaded, Arms full, Staggering).
 - Staff: /carrydebug shows weight, limit, band and pace (trial).

Chat and roleplay commands
 - Ranges are say 20 m, shout 40 m, whisper 3 m, low voice 5 m and actions 20 m. The text colour fades with distance. Speech gets an automatic capital letter and full stop (an exclamation mark when shouting). Normal chat is a say, with a chat bubble over the head for 8 seconds and a talking gesture. Chat only reaches players in the same interior and world, and only characters who have spawned can talk.
 - Names. A listener only sees a name for a character they've been introduced to. Everyone else is "A stranger" (see Nametags and introductions).
 - /me and /melow (5 m) are actions, /do describes the scene, /ame and /amy show a line over the head only, and /my is a possessive action ("Name's hands shake"). /doing puts a line under the nametag for 5 minutes, and on its own it clears the line.
 - /to, /lowto, /lowerto and /shoutto speak to chosen player ids (up to 5, as in /to 3,7 Good day) and show who is addressed. A target who is out of range is refused.
 - /s and /shout shout. /w and /whisper whisper to one player within 3 m. /addwhisper adds or removes someone in a whisper group of up to 8, and /gw and /groupwhisper whisper to the group. People nearby see that a whisper happened but not the text.
 - /b, /blow and /blower are out of character chat (20 m and 5 m), shown with the account name and id. /pm sends a private out of character message (one second between messages) and /re answers the last one. /dod sends a private /do to one person anywhere.

Nametags and introductions
 - The default SA-MP nametags are switched off. Each viewer sees a floating label with the name they know and the player id, from 12 metres. A stranger shows as "A stranger (id)".
 - Pressing H introduces your character to everyone within 5 metres who doesn't know them yet. Known names are stored for each pair of characters in the database and survive relogs. Chat lines and labels expand names for each viewer.
 - A second label above the name shows cues. These are an illness or wound cue, law status, hygiene (stinks, reeks), group livery and the away flag.
 - The SA-MP scoreboard and join messages are rewritten for each client, so a playing character shows under their character name, with underscores for spaces.

Emotes and animations
 - The emote panel opens with Walk + N (left Alt + N) or /animations and /anims. There are 404 variants over 137 commands in 13 categories (Sitting, Lying, Leaning, Kneel and pray, Gestures, Greetings, Standing, Working, Dancing, Music, Fighting stances, Reactions, Miscellaneous). You can type a command with a variant number or pick it in the panel. Each category has its own help entry listing its commands.
 - Up to 6 favourites can be pinned to the top of the panel and are saved on the character.
 - Emotes play in place. They stop when the player moves, jumps or sprints, with /sa or /stopanim, or by pressing Walk + N again. They can't be used riding, in a cart, in a menu or while busy. Some are chains of animation pieces, such as sitting down and then looping.
 - Paired emotes ask the nearest person you're facing within 2.5 metres and wait up to 20 seconds. The other player answers with Walk + N. They are /handshake, /hug, /kiss 7 (embrace and kiss), /pairbow, /pairdance, /support (a shoulder to lean on), /carryperson and /private.
 - Carrying a person needs a target who is down or bound, and needs no consent. A private moment is only between a man and a woman who both agree. It blacks out both screens for 6 seconds and posts "steps away with them for a private moment" in chat.
 - Music. A lute, flute or drum from the bag plays a musician's pose with the instrument in hand and an action line in chat. Listeners within 8 metres get a "Press Y to tip" prompt for 1, 2 or 5 pfennig, paid straight to the musician. An inn pays a musician who plays inside it 1 pfennig every 2 minutes, up to 20 a day.
 - Staff: /emote <number> plays an emote by number (trial).

Friends
 - A friends list for each account, up to 50 names. /addfriend <id or name> (online players only), /unfriend <name or id> (offline names work too) and /friends to list who is online. On login the player sees which friends are on, and those friends are told when they arrive.

## The world

Calendar and moon
 - The realm has its own calendar. 12 months of 30 days, starting at year 1200. The months are Wolf, Snow, Lenten, Egg, Milk, Hay, Mead, Grain, Harvest, Hunter's, Frost and Yule.
 - Time runs on its own clock. It's saved to the database about a quarter of a second after each change, so the date survives restarts. A fresh database starts on 1 Wolf 1200 at 06:00.
 - A game day is 5 real hours. Daytime (06:00 to 20:00) takes 3 real hours, so a game minute is about 12.9 real seconds. Night (20:00 to 06:00) takes 2 real hours, so a game minute is 12 real seconds.
 - Seasons follow the months. Winter is Yule, Wolf and Snow. Spring is Lenten, Egg and Milk. Summer is Hay, Mead and Grain. Autumn is Harvest, Hunter's and Frost.
 - Every player gets their own sky time and weather. Sunrise and sunset move with the season (winter 08:00 to 16:30, spring 06:30 to 19:00, summer 05:00 to 21:00, autumn 07:00 to 18:00) and the sky clock is stretched to match. If you're in the login or character creator scene you keep your night.
 - The base sky weather is a fixed id per season (winter 4, spring 2, summer 1, autumn 7). Disasters can override it for a while.
 - Temperature is worked out per position. Base is -5 C in winter, 10 spring, 24 summer, 12 autumn. Afternoon (12:00 to 15:00) adds 4. Deep night (22:00 to 05:00) takes off 6 and the other night hours take off 3. Winter takes off another 2. Altitude above 300 m takes off 1 degree per 100 m. Storms and floods add a chill outdoors. Indoors the value is clamped between 12 and 18. The warmth, fatigue and breath-fog systems read this, and so does the character panel.
 - The moon has 8 phases on a 29.53 day cycle, counted from the calendar epoch. The HUD shows the phase name next to the month's moon ("Wolf Moon"), a season disc, and the full date in the HUD title.
 - There's a calendar module that other systems hook into. It announces every hour, dawn (06:00), nightfall (20:00), new day, new season, new moon phase and manual date changes. NPC routines, fires, markets, crops, herbs and errands all hang off these.
 - Staff: /setdate <day 1-30> <month 1-12> <year> <hour> [minute] and /skiphours <1..720>.
 - There's a helper that gives a crop growth factor by moon phase (1.5 at full, 1.2 waxing, 0.8 waning, 1.0 new). I never wired it up. Nothing outside the calendar calls it yet.

Seasons and the look of the land
 - The map changes with the calendar. In autumn the trees turn and the roads get leaf cover. In winter snow settles on the ground, the roofs and the pines, and the rivers can freeze.
 - Autumn has two stages. Stage 1 runs through Harvest and Hunter's. Stage 2 (late autumn) is Frost. Both swap the foliage models and lay leaves on the roads.
 - Winter snow depends on how long it has actually snowed, not on the date. Every real minute of snowfall in winter adds one minute to a saved counter. The ground stages come at 1, 10, 40, 90 and 240 minutes of snow. Outside winter the counter resets to zero.
 - 32 overlay objects step up or down one stage at a time. They are ground snow patches (with a deep-snow version), roof snow, pine snow and leafy roads. Each piece changes every 20 seconds, two pieces per second at most, so the change creeps in slowly and never pops.
 - 454 tree models swap live between summer, autumn, late autumn and winter variants, 12 per second. The distant LOD chunks change to match.
 - From snow stage 4 (90 minutes of snow) the creek, mill pond, brook, lake and swamp pools turn to ice. The ice has real collision, so you can walk on it. Fishing and washing in the river stop working until it thaws. Wells and the monastery spring never freeze.
 - The radar map recolours with the seasons too (autumn tints, snow stages, frozen water).
 - The seasonal workshop decals (muddy or autumn ground around the workshop sites) follow the same look.
 - /season with no argument prints the current look and stage (staff). /season auto, /season none, /season autumn <1-2> and /season winter <0-5> force a look until you set it back to auto.

Weather and snowfall
 - In winter it snows at random. Each real minute there's a 1 in 30 chance a snowfall starts, and it lasts 15 to 45 minutes. It never snows on its own outside winter.
 - Snow is a falling-snow effect that follows the player's camera. It doesn't show indoors, in the login scene, or inside registered shelters. The churches are registered as shelters, up to 8 boxes in total.
 - Snowfall time builds up the snow on the ground (see Seasons). It also slows fires, since fire growth drops by 3 per tick while it snows.
 - Staff: /snow on (15 minutes of snow, then back to automatic), /snow off and /snow auto.

Light, torches and fires you can carry
 - Torch. Carry a torch in the bag and click it to light it. It sits in the left hand with a flame effect and burns for 20 minutes of real time, counted as wear on the item. Click the lit torch to put it out or plant it in the ground. A torch you put out keeps its wear, and the most worn stub in the bag is the one lit next. When it burns out it's thrown away. Put your shield away first, because the torch needs the left hand.
 - To light anything you need a flame. That's flint in the bag, a lit torch of your own, a lit brazier, bonfire or candle within 2.5 m, a lit station within 2.5 m, or another player's lit torch within 2.5 m.
 - A planted torch stands in the ground (the Y prompt shows the minutes left) and anyone can pull it back out with Y. Planting needs open ground and doesn't work indoors.
 - Lantern. It hangs from the belt and frees both hands. It burns candles. A tallow candle gives half an hour and a wax candle an hour. A lantern with no candle left tells you so, and you can reload it from the bag.
 - You can also set a candle down lit on a surface in front of you. Tallow lasts 30 minutes and wax 60, and the model shrinks to a stub when a quarter is left. A candle that burns out is removed straight away.
 - Braziers and bonfires are kept fires. They're saved in the database with their remaining fuel. A brazier takes charcoal (2 hours) or firewood (1 hour). A bonfire takes firewood only (20 minutes a log). Stand next to one and press Y to add fuel or to light a cold one (you need a flame). A fire holds at most 12 hours of fuel. When it goes out a bonfire shows ash and a brazier shows cold coals.
 - Three braziers are placed on the map at first boot. Staff place more.
 - Lit torches, lanterns and fires are warm too. You count as warmed for the cold system if you stand within 4 m of a fuelled fire, 3 m of a lit station, or 7 m of the hearth in a house with a lit fire.
 - 25 flame spots on the map (torches, braziers, sconces) and 63 flame spots on specific models (houses, stations, props) are drawn as real flames. Stations with a fire only show their flame while they're alight.
 - At night a moon object is placed in each player's sky outdoors, in the shape of the current phase. It rises and sets with the clock. It's hidden indoors and in other worlds.
 - Staff: /light brazier, /light bonfire, /light fuel <minutes>, /light out, /light remove, /light list, /light kit (torches, lantern, candles, flint, firewood), /light tune (torch grip fitting) and /light moon (prints the moon's position, and /light moon 1 hides or shows it).

Fire
 - 44 buildings can burn. They're the village houses of Talmberg, the church village and the hamlets, the farms, the mountain inn and three stables. Each has a roof point where the flames show and a door where people stand.
 - A building is sound, smoking, burning or gutted. Heat runs from 0 to 100. A new fire starts at heat 20 (15 if it spread from a neighbour). It smokes under 40, burns from 40 and roars from 80. Every 5 seconds it grows by 3, plus 2 in summer, plus drought and storm wind, minus rain and damp, minus 3 while snow falls. At heat 60 it can throw sparks to a building within 16 m (8 percent each tick). At full heat for a minute (12 ticks) the building is gutted.
 - A fire can start in a few ways. An unwatched hearth (about 1 in 14000 per game hour per lit hearth in a house with nobody inside). A dropped lit torch next to a building (25 percent). Lightning from a storm. Sparks from next door. Arson by a player (hold walk and press Y at a building with a lit torch in hand, which also counts as a crime in the law system). Or staff.
 - A tiled roof doesn't catch from sparks, lightning or torches, and fire spreads half as readily on it. A neglected building catches more readily (see Construction).
 - When a fire starts the crier announces it, the church bell rings for everyone within 300 m, and flames, smoke and a glow appear on the roof (more flames as it grows). Inside a burning house, smoke damages players (2 per tick) and they cough. Standing in the flames burns you (4).
 - Fighting it. Take a bucket to a trough, a well, a spring or the river and press Y to fill it (2.5 seconds). Then press Y within 9 m of the fire to throw. A throw takes 9 heat off. People throwing within 4 seconds of each other build a chain, up to 3 extra, each adding 4. Throw it out and the last flames hiss out.
 - A gutted house can't be entered, what was in its chests is lost, and the work stations inside it stop. Anyone can pay the county at the door to rebuild it, 1 gulden for a house or 10 groschen for a stable. The carpenters rebuild it by the next dawn. A rebuilt or burnt building changes the condition of the building (see Construction).
 - Gutted state is saved, so a house stays burnt across restarts.
 - Staff: /fire list, /fire start|out|gut|rebuild|paid <building key or near> and /fire heat <key or near> <0-100>.

Disasters
 - There are four events. A storm, a flood, a drought and a pestilence. Only one can run at a time.
 - Every dawn the season's odds are rolled (per thousand, winter/spring/summer/autumn). Storm 0/40/60/50, flood 0/25/0/30, drought 0/0/150/0 (rolled only on the first dawn of a season and lasting the season), pestilence 10/10/15/10. Severity is 1 to 3, with 1 in 10 severe and 3 in 10 middling.
 - The crier warns 15 real minutes before it starts ("signs in the sky"). He announces the start and he announces the end. Storms last 20 to 40 minutes, floods 45 to 90 and pestilence 10 to 15 hours.
 - Storm. Swaps the sky to storm weather and chills everyone outdoors (4 degrees plus severity). Each minute there's a 2 percent plus severity chance of lightning hitting a random standing roof and setting it alight. At its start it wears down every building's condition (3 per severity point). Wind makes fires grow faster.
 - Flood. Swaps the sky to heavy rain, chills outdoors by 3 degrees and dampens fires. Roads don't turn to mud yet, even though the help text says they do.
 - Drought. Fires grow faster and traders raise their prices by 10 percent per severity point.
 - Pestilence. Every 10 minutes each player inside the town limits has a 1.5 percent chance per severity point of falling ill with fever or flux. Severity 3 can also give plague.
 - Staff: /disaster info, /disaster start <storm|flood|drought|pestilence> [severity 1-3] [minutes] [warning minutes], /disaster stop, /disaster strike and /disaster sicken.

Construction and building upkeep
 - Every one of the 44 fire-capable buildings has a condition from 0 to 100, and it's saved. Every second dawn it loses 1. A storm takes 3 per severity point and a fire takes 20. A rebuild resets it to 100. Under 60 is "damaged" and under 30 is "poor". Below 60 the building catches fire more easily (1 extra percent per 3 points below).
 - Repairs. Stand by the walls of a damaged building and press Y to set the work out. It's posted on the notice boards as "Work wanted". Anyone can bring the materials to the building's stockpile (a container at the site) and take turns at the work. Each turn takes 8 seconds. It's a work scene with no minigame, and it costs stamina and fatigue. Whoever labours gets trade practice, and their turns are counted per character.
 - Repair stages scale with the damage (one unit per 25 points). You mend the frame (2 planks and 1 nails per turn, needs a hammer and carpenter skill). You patch the thatch (3 straw) or patch the roof (2 tiles) depending on the roof. And you point the walls (1 stone block and 1 unclean water, needs a chisel and mining skill).
 - Tend the roof. This is a second kind of work that gives the building a tended roof. It has four stages. Clear worn roofing (labour only), lath the roof (planks and nails), mix mortar (water, labour only) and repair the covering (4 tiles). The building looks the same afterwards. Only the realm's ruler or duke, a priest (for church buildings) or someone who holds a room in the house can order it. A tended roof stops fires from lightning and torches and halves spreading.
 - Works are limited to 16 at a time. Leftover materials stay in the stockpile to be taken back. The project can be stopped, and a fire that guts the building abandons it.
 - The work notice goes up on the Realm, Church or Players tab depending on who set it out, and stays up five days.
 - Staff: /build list, /build condition <key or near> <0-100>, /build tile|thatch <key or near>, /build repair|tileroof <key or near>, /build turn <key or near>, /build finish|stop <key or near> and /build decay <amount>.

The crier and realm news
 - Systems post news into one table. Mass, weddings, baptisms, ordinations and funerals (faith), fires, omens and disasters, decrees and wanted notices (law and realm), tournaments and the seasonal fair (events), seasonal duties and more all call the crier.
 - Each piece of news becomes a notice for three days on the matching board tab. Faith goes to Church, events and weather go to Events, everything else goes to Realm. The same table keeps a log of past news.
 - A crier NPC stands by the Talmberg market board. He calls out a new notice in public chat with a shouting animation, one notice every 20 seconds. The first time a notice is cried, every online player also gets it as a chat line, "The crier calls in Talmberg". Notices are queued again at Terce and Vespers and are cried at most three times each.

Notice boards
 - Three boards stand at the Talmberg market, the church village and the guardhouse. Stand within 2.4 m and press Y.
 - The tabs are Realm, Church, Players, Events and Work. Realm, Church and Events carry the crier's news and staff notices. Work carries errands and contracts (see Errands). Players is for the players.
 - Anyone can pin a notice under Players. It's a heading and up to 4 lines of 41 characters, for 2 pfennig. It stays up for 3 days (a notice day is 5 real hours, so 15 real hours). The crier calls it out.
 - Notice titles are 41 characters and the text is 256. 64 notices fit at once. Expired ones are removed.
 - Staff: /notice realm|church|events [heading]: [text], /notice list, /notice cancel [id] and /notice board.

Letters and couriers
 - Writing needs parchment, an ink pot and a quill, and a character who can write. Literacy is checked, and illiterate characters are told to find someone to write for them. Stand at a courier's table facing it and press Y, or use the parchment from the bag. Address the letter, then click a line to write it. A letter is up to 8 lines of 41 characters and the heading is the addressee. A line that's too long is cut. Every 4 lines use up some ink.
 - Fold it when you're done. You can seal a folded letter with a signet ring and wax (a cake of wax is used up every 3 seals). Whoever opens a sealed letter breaks the seal, and the letter is then marked opened. Tearing a page up gives the parchment back for another try. If the ink runs dry the letter is unreadable.
 - Reading needs the ability to read.
 - Hand it to someone yourself, or give it to a courier at the table in Talmberg or the church village for 3 pfennig. Give the recipient's full name. The letter arrives within 10 real minutes (the courier round runs every 30 seconds, 25 letters at a time). If the recipient is online it appears in their bag. Otherwise it waits in their claims. The addressee must be a living character.
 - Two courier NPCs stand at the tables.
 - Staff: /letter kit (gives a writing kit), /letter write and /letter deliver (makes every letter on the road arrive at once).

Market
 - Talmberg market opens every Saturday, 09:00 to 16:00 by the calendar (a 7 day week counted from the epoch, running across months). The seasonal fair opens it too.
 - When the market is closed the stall bodies stand empty with no goods. When it opens, 49 props appear. That's three stalls (produce, cloth, meat and fish), a bread table, a pottery display, and stacks of barrels, a chest and sacks.
 - Opening the market starts the market traders and the market visitor NPCs, and closing it stops them again. Traders flagged as market traders only appear while it's open.
 - Staff can override the market open or closed (the events tools use this).
 - The market stall station (a player-built stall, see Stations) is a stub. I never finished selling from it.

Washing and drinking water
 - There are seven spots. Three washing troughs (Talmberg market, church village, guardhouse), the monastery spring, a holy water stoup at the parish church door and two wells (Talmberg market and church village).
 - A trough holds two washes. A wash takes 4.5 seconds, restores hygiene fully and draws one level out of the trough. Troughs and the spring refill by one level per game hour. Washing in a river works too, but it only restores 50 percent of hygiene and does nothing when the water is frozen.
 - The spring gives a drink of 25 thirst and then runs low until it refills. The wells give 25 thirst, or fill a partly empty water skin if you carry one. Wells never freeze or run dry.
 - The stoup is a roleplay spot. Press Y and you dip your fingers and cross yourself with an /me line.

Graves, crypt and funerals
 - A character who dies for good is buried by the system. They go to the nearest graveyard with a free plot (23 plots in the parish churchyard, staff can mark more, for example at the monastery). The grave shows name, birth and death dates, age and cause of death.
 - When the plots are full the dead are laid in a niche in the crypt under the parish church. A crypt has up to 6 chambers of 72 niches (8 banks of 9) and grows a chamber at a time. The crypt is its own interior with stairs down from a door by the church. Up to 4 crypts exist.
 - A fresh grave has a wooden marker and a mound that settles over 3 days. Staff can change a marker to a headstone or a cross.
 - Visiting. Stand at the grave or niche and press Y. You can light a candle (needs a candle and a flame), lay a posy of wildflowers (once per day per character per grave) or say a prayer, which shows as an /me kneeling line.
 - Funeral. The bell tolls and the crier names the day. About 90 real minutes later the priest (Father Anselm, an NPC) holds the funeral at the grave or crypt door and reads the Requiem aeternam line by line, one every 6 seconds. Players within 25 m see the lines. A reminder goes out 10 minutes before. Funerals that nobody could hold within 6 hours are dropped. Up to 32 can be pending.
 - Staff: /grave plot <yard>, remove, list, bury <character id>, settle, marker <wood|headstone|cross>, funeral and exhume. And /crypt place <key>, enter, grow, fill <count>, list and remove.

Errands, duties, contracts and the ledger
 - Errands. Six giver types post errands each dawn. They are the innkeeper (2 of them), priest, yard master (3), reeve, bailiff and herdsman. Each giver holds up to 3 open errands and each lives 2 days. A hand picks up to 3 at a time and delivers in person at the giver. The reward is 75 percent of the goods' worth at the stars asked, paid from the county treasury (an empty treasury posts no errands). A character can make 6 deliveries a day. About 38 errand types exist, some by season (cabbages in summer and autumn, fish except in winter, seed corn in spring only).
 - Goodwill. Every delivery builds goodwill with that giver (up to 30). Better errands need goodwill (higher stars, and pricier goods such as cheese, honey, iron bars, ale barrels). Delivering goods two stars above what's asked gives a bonus.
 - Seasonal duties. Each season asks something of every hand. Spring is seed and fences for the reeve. Summer is hay for the herdsman and moon-picked herbs for the priest (full moon only). Autumn is harvest days for the reeve and the tithe for the priest. Winter is firewood for the chapel and the gaol and cured meat for the castle. Feast days add bread for the priest while a festival runs. Duties pay a quarter of the goods' worth from the treasury and give goodwill. The tithe pays nothing. Missing a duty is noted when the season turns. A missed tithe stands as a debt that can still be paid late. The crier announces each season's duties.
 - Contracts. On the Work tab of any board a player posts a request for goods with a quantity (up to 40), minimum stars and a pay (up to 2400 pfennig). The coin leaves the poster's purse at once and is held. Anyone can deliver at any board. The goods go to the poster (bag or claim) and the coin goes to the deliverer. After 4 days an undelivered contract is returned. The poster can take an open contract back. 40 contracts at most.
 - A character carries at most 3 errands and contracts together.
 - The ledger (in the character panel). Your tasks lists accepted errands, family parcels and contracts with destination, reward and time left. Suggested shows open errands within 200 m, contracts and duties. Your goals holds up to 8 goals written in your own words with an optional date. Suggestions from the tutorial or NPCs can be kept as goals or dismissed. A header line shows the daily chores and the next new or full moon.
 - Craftsman's warrant. With no count in office, the steward at the ducal fortress grants a warrant for a trade by trial. You deliver three errands of one trade at three stars or better within a season, reach level 5 in that trade and pay the county's petition fee. Merchant, clergy and arms trades aren't covered.
 - Roadside foraging. Seven spots between Talmberg and the monastery are kept stocked with berry bushes, herb patches, windfalls and digging ground.
 - Staff: /orders list, roll, expire, clear, goodwill <player> <n>, daily <player>, duties <player> and warrant <player> <trade>.

Workshops
 - 30 workshop sites are dressed with 338 objects. They are a smithy, bakehouse, tailor, carpenter's yard, wheelwright, brewhouse, cooper, tannery, landing, reed yard, mine, mason, woodcutter's clearing, apiary, orchard, herb garden, potter, wood yard, butcher, kennel, stable, barns, sheepfold, mill, coast, hill, abbey and ducal sites. Each belongs to a house or household.
 - 18 of the buildings (shells) have real collision. Ground decals at the sites change with the autumn look. The tailor's shop is an interior with four props.
 - The sites define 190 named work spots, each with a position and an animation. Fixed stations use them, and two-person spots (anvil striker and smith) are paired. Props near a spot are kept clear of nodes.

Crafting stations
 - There are 30 station kinds. The fire stations are campfire, hearth, oven, forge, bloomery, kiln, charcoal clamp, smokehouse and herbalist's table. The others are anvil, workbench, chopping block, table, desk, wheel, loom, frame, vat, press, millstones, hand quern, hanging hook, well, altar, skep, henhouse, butter churn, cheese press, market stall and herald's table.
 - Players build stations from materials, and they also exist fixed in the world. Open the bag (N) and go to Crafting. The tabs are Stations (what you can build and what it needs), Talents and By hand. Learning a station costs talent points, and you earn a point for every half hour played. Each station tells you its materials. A campfire needs 2 firewood and 2 stone blocks, an oven 8 clay, 6 stone blocks and 2 planks, a forge 8 stone blocks, 2 charcoal and an iron bar, an anvil an iron bloom, an oak log and a hammer.
 - Placing. The player puts a ghost on flat ground and drags it into place with the gizmo. Stations keep 3 m apart. Building has a 60 second cooldown. A character can own 2 stations.
 - Fuel. A built station runs on fuel or upkeep. Fire stations burn firewood (1 hour), charcoal (2 hours) or kindling (20 minutes). The others take rope (2 hours), nails (1 hour) or linen (2 hours). Up to 12 hours can be stored, one kind at a time. Every minute of real time burns a minute, and each finished piece of work burns 10 more minutes. When the fuel runs out a fire station burns out and a cold one falls apart, and the owner gets half the materials back in claims.
 - If the owner stays offline for an hour the station is packed up and everything goes to claims. When staff take a station down, everything is returned.
 - Sharing. The owner can invite up to 8 other characters within 5 m to use the station. Others can't use it. The owner can pack it up by hand.
 - A station inside a burned building can't be used until the building is rebuilt.
 - Working. Work is a scene and there's no menu. The screen fades, the character walks to the spot and a panel with glyphs appears. Each recipe has stages and each stage is one of five challenges. You press the shown keys in order (3 to 7 long, shorter at higher level). Or you press SPACE on a rhythm beat 6 times. Or you hold SPACE to keep a marker inside a band. Or you press SPACE as a moving mark crosses the sweet spot. Or you simply wait. Each stage has a 12 second limit. Hold N to walk away, which gives the materials back. Fail badly and the batch is ruined and the materials are gone.
 - The stage scores add up to 1 to 5 stars. A perfect run adds a star. The station caps the stars (a campfire and a hand quern cap at 3). Higher level and tiredness change how wide the good bands are.
 - Trade levels. There are 23 trades (including water, orchard, herdsman, butcher, miller, baker, brewer, beekeeper, tavern, woodcutting, mining, smith, carpenter, tailor, potter, herbalist, physician, faith, hunting, chandler, fishing, scribe and merchant). Each finished work gives 10 practice per star. A level needs 100 practice times the level, up to level 10, saved per character. Level 10 needs a masterpiece. Talents can raise or limit the cap. A guild trainer can add a bonus percent to practice.
 - Work uses the recipes in the jobs system and drains stamina. A "poached" event is raised if you work a licensed trade without a licence.
 - By hand. Without a tool you can make crude versions. They're the crude axe, flint knife, digging stick, stone pick, woven basket, kindling (3) and a splint. They work for jobs at up to 3 stars and each use has a 1 in 6 chance of the tool falling apart.
 - Effects. Stations show flames, steam, smoke, sparks and embers during work, in short bursts. A hide-props option (Crafting, Stations, Props around stations) turns off up to 8 dressing props per station for that player. Props are placed to fit the ground.
 - The butter churn and cheese press are learned under herdsman. The herbalist's table makes remedies, ink and poisons.
 - Staff: /station (a menu for placing, supplying, fuelling, deleting stations and giving talent points), /node (node tools) and /workpanel (preview the work panel).

Gathering nodes and herbs
 - There are 19 node kinds. Felled trunk, old stump, windfall, fruit bush, rock outcrop, ore seam, clay pit, digging ground, bog pool, field strip, herb patch, wild hive, swarm, tanning pit, fishing spot, and four kinds of dead game to dress (deer, boar, wolf, bear). Each has a stock (1 to 6 uses) and refills over time (fruit bushes and windfalls 24 hours, trunks 72, seams 120, fishing spots 2).
 - Nodes sit at 1483 spots read from the map, by habitat (forest, edge, rock, wet, meadow, village). At boot and every 5 to 15 minutes the game tops wild nodes back up to a target per kind (140 herb patches, 42 windfalls, 36 trunks, 30 outcrops and so on). It keeps them 8 m apart, 5 m from stations and 60 m from players. A harvested node lingers for a minute. Winter cuts the herb target to a quarter. After a character works a node, it gives them nothing for 20 minutes.
 - Sparks mark nodes that still have something to take. Trunks, herbs, fruit bushes, seams, outcrops, clay and hives only show sparks to characters who learned that trade's eye talent (Woodsman's eye, Herbalist's eye, Prospector's eye).
 - Herb patches grow 34 species, by habitat, season, moon and weight. The healing herbs are yarrow, plantain, comfrey, willow bark, chamomile, St John's wort, nettle, valerian, water mint, wormwood, mugwort, betony, agrimony, elder and wild garlic. The poisons and look-alikes are nightshade, hemlock, foxglove, henbane, wild carrot, mayweed, dwarf elder, lily of the valley, autumn crocus, cow parsley and death caps. Poppy, dyer's weld, bilberries, wild cherry, ceps and field mushrooms are food or dye or crafting.
 - Look-alikes. Under herbalist level 3 a poisonous plant is shown with the name of the plant it resembles, and you only learn what you picked once it's in your bag. Poisonous and useless herbs don't go into remedies.
 - Moon herbs. Moonwort only appears on full-moon nights from spring to autumn. Wolfsbane only appears on the full moon of Wolf month (January) at night in rock or wet places. Both wither at dawn.
 - Around each herb patch the game scatters 3 to 6 decorative plants (some of them mimicking the real herb) and herb drifts.
 - Staff can refill nodes, clear a character's node cooldowns and delete nodes with /node.

Map
 - The whole map comes from a shared handoff file. Stock San Andreas is stripped (2500 m around the origin and an edge area) so only the realm map shows. New characters first stand in the village square.
 - Objects stream out to 9999 m, with 750 visible at once. Buildings, vegetation (hard-alpha) and ground decals use different base models for flags. 842 LOD objects in 119 chunks cover the distance. They're swapped when seasons change models, and they hide the detail objects they replace.
 - Collision runs on ColAndreas. Map models with collision are loaded at boot. Rays answer height and surface questions for the rest of the gamemode.
 - Radar. The stock radar is replaced by a drawn map made of gangzones, up to 1000 of them, built at boot from the collision on a 10 m grid (150 by 170 cells). Colours show sea, low ground, foothills, hills, high ground, peaks, buildings, fortifications and water, with a ring and an outside zone. Autumn, snow and ice recolour it. It shows when a character spawns.
 - Staff: /near (nearest map objects), /cols (collision pieces around you), /hide <id...> (toggle a model off to find what blocks), /ray (ray down to check the ground), /raydump (rays at every probe in a file), /fw, /up and /dn (nudge yourself), /walllog (logs invisible walls you push against), /flymode (fly the camera), /pos (position or camera) and /mapzones (switch the drawn map on or off, admin).
 - A navigation dump of all streamed objects runs 15 seconds after boot when a sentinel file exists.

Models and the model registry
 - Every custom model is registered at boot through one table. That's 1302 constants grouped by category (workshops, interiors, herbs, fishing, meals, tools, materials, clothing, games, produce, food, yard, village, light, carrying, gear, prizes, furniture, writing, carts, crypt, bait). Objects and skins are added with their dff and txd and a base model for flags. A refused id is logged with the file name.
 - Clients are held at the model download. Streamed objects are switched off per player until they finish downloading, then everything is rebuilt.
 - Skins must be in the 20001 to 30000 range.

Attachments
 - Held and carried things are attached to bones. That covers torches, lantern, loads, instruments, buckets, baskets, backpacks, satchels, logs, sacks, barrels, stones, coffers, tabards, a breath effect, lute, flute, drum and lances.
 - 23 presets cover these. A saved fit overrides any attachment's offset, rotation and scale for that model and bone. The server filters every SetPlayerAttachedObject call and applies the saved fit, so one fix reaches every system at once. Up to 128 fits are stored in the database.
 - Staff: /attach <name or model id> [bone 1-18] (opens the editor on you), /attach seen (lists models fitted so far), /attach reset <name or model> [bone], and /attachoff (removes the attachment). Clicking the disk saves a fit for everyone.

Placement
 - It's a shared tool for placing objects. It starts the gizmo (object edit) for a player, returns whether the edit was saved, and checks the result against the collision. It catches floating, sunk into the ground, going through a wall, or tipped over (more than 10 degrees by default). It can snap an object to the surface below.
 - Player-built stations and house furniture use it.

Falling and /stuck
 - Falling under the map is detected with rays. A player who is below the lowest surface for 2 samples (3 over open void) is put back where they last stood on solid ground. Swimming anywhere over the map counts as being under the map, because the San Andreas sea lies beneath the whole world. Falling through the floor of an interior is caught too, and it puts the player back inside.
 - /stuck is for anyone caught in the scenery. It works once the character is in the world and has a 120 second cooldown. It's refused when you're bound, serving a sentence or in a fight (it always works when you're actually under the map).
 - Staff: /falltest [drop] drops you under the ground to test it.

## Work, trade and the bag

Trades, occupations and rungs
 - There are 24 trades. Farming, Water carrying, Orchard keeping, Herding, Butchery, Milling, Baking, Brewing, Beekeeping, Cooking, Woodcutting, Mining, Smithing, Carpentry, Tailoring, Pottery, Herbalism, Physic, Faith, Hunting, Chandlery, Fishing, Scribing and Trade (the merchant's trade).
 - 40 occupations (titles) sit on four rungs. Each one points at a trade or at none. The peasant rung (9) has Farmhand, Kitchen hand, Apprentice, Novice, Recruit, Water carrier, Herd boy, Digger and Town crier. The craftsman rung (22) has Farmer, Orchard keeper, Herdsman, Beekeeper, Butcher, Chandler, Scribe, Baker, Miller, Brewer, Smith, Carpenter, Tailor, Potter, Forester, Charcoal burner, Miner, Fisherman, Herbalist, Hunter, Mason and Thatcher. The burgher rung (6) has Innkeeper, Merchant, Physician, Priest, Monk and Guard. The noble rung (3) has Count, Duke and Bishop.
 - Occupations are just data in this module. The ducal orders system looks them up by name and rung.
 - On boot the module logs how many trades, occupations and recipes it loaded (24, 40 and 198).

Recipes
 - Every piece of work in the game is a recipe row. There are 198 of them, 176 normal ones and 22 level nine masterpieces. A recipe names its trade, a level from 1 to 9, an optional tool you need from the bag, and one attribute that governs it (Willpower, Craftmanship, Intelligence, Honor and Grace, or Piety). It also has a stamina cost, up to four inputs, one output, the kind of station or gathering node it's done at, and up to eight challenge stages.
 - Stamina cost is 10 per attempt and 20 for masterpieces. Each input has an item, an amount and a minimum star quality. Inputs can be a group, so "Fish" takes any bait and "Salt fish" takes any fish.
 - Six challenge kinds make up the stages. Sequence (press the keys shown), Rhythm (press Space when it lights), Hold (keep the red mark in the green), Timing (press Space as the mark passes the green), Walk (shares the Hold controls) and Wait (stand by, with N held to walk away). A stage can also be flagged optional or branching. The workstation system runs the challenge itself.
 - The recipe's attribute decides how forgiving the challenge is. An attribute of 4 or more adds a star to the result. The star rating of the output item comes from how well the stages were scored.
 - Level 9 recipes are the masterpieces. There are 22 of them, spread over 17 trades. Level 10 in a trade that has a masterpiece needs one to be made first, so a player who hasn't mastered it is capped at level 9 there.
 - Camera shots and animations for the work scene are in a scene table. Only Stew (8 stages) and Fish (6 stages) have hand set camera angles, distances, props and animations. Every other recipe uses default shots that alternate left and right, and a fallback animation picked by the stage's challenge kind. The animation libraries are preloaded on boot.
 - Farming (8). Sow a strip (L1, hoe, one seed), Tend the strip (L1, hoe, water skin), Harvest grain (L1, sickle, 4 sheaves), Harvest vegetables (L1, hoe, 6 cabbages), Thresh (L2, flail, 4 sheaves into 2 wheat), Harvest flax (L2, 4 flax), Pick hops (L3, ladder, 3 hops) and the masterpiece A perfect harvest (L9, sickle, 6 seed).
 - Water carrying (3). Draw water (L1, bucket, 4 unclean water at a well), Deliver a barrel (L1, yoke, one barrel to a workplace) and Boil water (L1, pot, 4 unclean water and a firewood bundle into 4 clean water).
 - Orchard keeping (3). Pick fruit (L1, 8 apples at a fruit bush), Press cider (L3, 12 apples into 6 cider at the press) and Prune (L2, knife).
 - Herding (8). Milk (L1, pail, 3 milk at a cow), Churn butter (L2, 4 milk into 2 butter), Make cheese (L4, 6 milk and a salt into 2 cheese at the cheese press), Shear (L2, shears, 2 fleece at a sheep), Collect eggs (L1, basket, 6 eggs at a henhouse), Feed the herd (L1, 4 hay), Breed (L5) and the masterpiece A prize beast raised (L9, oats feed and hay).
 - Butchery (6). Slaughter (L2, cleaver, one carcass), Skin (L2, knife), Joint (L3, cleaver, a skinned carcass into 6 beef cuts), Sausages (L4, grinder, 4 pork and salt into 8 sausages), Cure and smoke (L5, 4 beef, salt and firewood into 4 cured meat at a hook) and the masterpiece A beast jointed whole (L9).
 - Milling (5). Set the sails (L1), Grind flour (L1, 2 wheat into 2 flour), Grind malt (L3, 2 barley into 2 malt), Dress the stones (L5, pickaxe) and the masterpiece Stones dressed, flour bolted (L9, chisel).
 - Baking (9). Wheat loaves (L1, flour, clean water and salt into 6 bread), Rye loaves (L2, 6 rye loaves), Trenchers (L1, one flour into 12), Hardtack (L2, 8), Fruit pie (L3, 4 pies), Meat pie (L4, 4 pies), Feast cake (L7, flour, eggs, butter and honey into 2), Hand quern (L1, one wheat into one flour at a quern) and the masterpiece The count's feast cake (L9).
 - Brewing (6). Ale to the vat (L1, cauldron, malt and clean water), Beer to the vat (L3, adds hops), Mead to the vat (L4, tub, 4 honey and clean water), Small beer (L1, tub, a fermented vat into 20 small beer), Barrel the vat (L1, mallet, a vat and an empty barrel into a barrel of ale) and the masterpiece Aged strong beer (L9).
 - Beekeeping (5). Take wild honey (L1, smoke pot, 2 honey at a wild hive), Take honey (L2, 3 honey at a skep), Make a skep (L2, 4 straw), Catch a swarm (L4, skep) and the masterpiece Mead of one's own honey (L9).
 - Cooking (10). Roast fish and Roast small game (L1, at a campfire), Roast venison and Roast boar (L2, campfire), Stew (L1, cauldron, 4 cabbage, clean water and 2 beef into 4 stew at a hearth), Pottage (L1, pot, 4 turnips), Porridge (L1, pot, 2 oats), Fish dish (L2, pan, 2 fish and butter into 2 dishes), Roast (L3, spit, 3 pork and firewood into 4 roasts) and Serve (L1, tray, at a table).
 - Woodcutting (10). Gather branches (L1), Snap off branches (L1), Fell a small tree (L1, axe, a softwood log), Cut a dead stump (L2, an oak log), Buck (L1, saw, one log into 4), Split (L1, axe, 2 logs into 4 firewood at the chopping block), Plant a sapling (L3, shovel, wild seed), Charcoal clamp (L3, shovel, 10 logs into 6 charcoal), Strip bark (L2, 2 bark) and Tap resin (L2, one resin).
 - Mining (9). Dig clay and Dig sand (L1, shovel, 3 each at a clay pit), Quarry stone (L2, pickaxe and wedges, 2 stone blocks), Bog iron (L2, sieve, 3 at a bog), Mine ore (L3, pickaxe, 2 iron ore at a seam), Mine silver (L6, 2 silver ore), Pick up flint (L1, 2), Gather loose stones (L1, one stone block) and Gather sling stones (L1, 6 sling stones).
 - Smithing (27). Smelt a bloom (L3, 4 iron ore and 4 charcoal into an iron bar at a bloomery). Tools and parts are Nails (L1), Knife (L1), Hoe head and Sickle (L2), Axe head (L3), Pick head (L4), Scythe blade (L6), Horseshoes (L2), Lock and key (L4, file), Cauldron and Iron pot (L3). Arms are Dagger (L2), Spear (L3), Broadsword (L5), Winged mace (L5), Bastard sword (L7), Great axe (L7) and the Shield boss (L3, makes a shield). Armour is Helmet (L5), Mail shirt (L7, 6 iron bars) and Plate set (L8, 8 iron bars). Also Repair (L1), Farrier (L2, shoes a mount), Signet ring (L7, graver, one silver ore) and the masterpieces A folded-steel longsword and A fitted mail shirt (L9).
 - Carpentry (25). Planks, Beam, Hafts and Staves (L1 to L2, cut from logs), Chair (L2), Table (L3), Chest (L3, needs a lock), Bed (L4), Barrel (L3), Tub (L2), Bucket and Pail (L1), Wheel (L5), Handcart (L5, 12 planks and 2 wheels), Horse cart (L7, 30 planks and 4 wheels), Bow (L3), Crossbow (L7), Arrows (L1, 10 per batch), Bolts (L3), Sling (L1), Dice (L1) and the masterpieces A lord's chest, A watertight tun, A cart with matched wheels and A yew longbow (L9).
 - Tailoring (19). Card and spin and Spin flax (L1, thread), Weave wool and Weave linen (L2, at a loom), Tan (L2, hides, bark and water at a tan pit), Parchment (L3, at a frame), Dye cloth (L4) and Repair clothes (L1). Garments are Linen shirt and Hood (L1), Wool tunic and Gloves (L2), Cloak and Boots (L3), Gambeson (L4), Leather armour (L5) and Fur-lined coat (L6). The masterpieces are A noble's fur-lined coat and Fine vellum (L9).
 - Pottery (7). Bowls and Mugs (L1, 2 clay into 6 at the wheel), Jugs (L2), Storage jar (L4), Roof tiles and Bricks (L1, moulds, 4 clay into 12 at the kiln) and the masterpiece A glazed storage set (L9).
 - Herbalism (10). Forage (L1, knife, 3 herbs), Bandages (L1, shears, linen into 4), Poultice (L1), Tincture (L3, herbs and ale), Ink (L2, oak galls, bog iron and water), Poison (L5, nightshade), Opiate draught (L5, poppy), Rare remedy (L6), Examine and treat (L1, uses a poultice on a patient) and the masterpiece A rare remedy (L9).
 - Physic (6). Pull a tooth (L1, pliers), Stitch a wound (L2, needle and thread), Bleed (L2, lancet), Set a bone (L3, splint), Amputate a finger (L5, bone saw) and the masterpiece A bone set straight (L9). All of them are done on a patient.
 - Faith (2). Pray (L1, uses a candle at an altar) and Say mass (L1, at an altar).
 - Scribing (3). Copy a book (L3, quill, 4 parchment and ink), Paint a deck (L2, makes a deck of cards) and the masterpiece An illuminated book (L9).
 - Hunting (8). Field-dress (L1), Dress a boar (L2), Skin a wolf (L2), Dress a bear (L4), Set a snare (L1), Set a foothold (L2), Dig a pit (L3) and the masterpiece A stag taken clean (L9). See the hunting section.
 - Chandlery (4). Tallow candles (L1, 2 fat into 8), Wax candles (L3), Soap (L2, fat, ash and water) and the masterpiece Candles for the feast (L9).
 - Fishing (4). Fish (L1, rod and bait), Salt fish (L1, tub, 4 fish and salt), Smoke fish (L2, at a smokehouse) and the masterpiece A record catch (L9). See the fishing section.
 - Trade (1). Sign the roll (L1, done at the herald's table).
 - Some recipe rows carry a "wait hours" value (6 for the vat, 12 for mead and tanning, 8 for pottery). I never wired anything up to read it, so it does nothing yet.

Talents
 - The talent tree has 35 nodes. It decides which stations a character can build and use, how high each trade can be levelled, and which hidden gathering spots they can see.
 - 30 nodes are station nodes (Campfire, Hearth, Serving table, Smokehouse, Well, Hand quern, Oven, Millstones, Vat, Press, Chopping block, Charcoal clamp, Workbench, Hanging hook, Loom, Parchment frame, Scribe's desk, Henhouse, Skep, Herbalist's table, Butter churn, Cheese press, Market stall, Herald's table, Forge, Anvil, Bloomery, Potter's wheel, Kiln and Altar). Each one belongs to one trade and has a parent node you have to own first.
 - 5 nodes are "eyes" that reveal gathering spots you can't see otherwise. Woodsman's eye shows trunks, stumps and windfall. Herbalist's eye shows herb patches and fruit bushes. Prospector's eye shows outcrops and seams. Digger's eye shows clay pits, ground and bogs. Beekeeper's eye shows wild hives and swarms.
 - The Campfire node is the root and it's free. Everything else is bought with talent points.
 - You earn a talent point for every 30 minutes of active play. Idle time doesn't count. The player is told when one is earned and where to spend it (bag, Crafting, Talents).
 - The first purchase costs 2 points and every purchase after that costs one more (2, 3, 4 and so on).
 - The trade level cap is 2 plus 2 for every node you own in that trade, up to level 10. So buying a node also raises the ceiling of its trade.
 - Points, active minutes and unlocked nodes are saved per character in the talent_points and talent_unlocks tables.
 - Staff get an option in the /station test menu that gives them 10 talent points.

Fishing
 - Players need a fishing rod and bait in the bag. Bait is worms, grubs, maggots, bread, any raw meat cut (beef, pork, mutton, venison, boar) or a small fish.
 - Holding a rod makes ripples show on fishing spots. Stand on the bank facing a spot and press Y. Spots are saved gathering nodes, and the module places 2 starter spots once on a fresh database.
 - A cast has six stages. Bait, cast, wait, strike, reel and land. The rod model, the bobber and a stretched line object change with each stage. The bobber floats on the real water height and dips when a fish bites, with a bite sound.
 - The wait lasts 5 to 30 seconds. It's shorter around dawn and dusk (about 60 percent) and longer under a new moon (125 percent). It never goes over 30 seconds.
 - If nothing in the water will take the bait right now, the player waits out the full time and the strike stage fails with a message that nothing took the bait.
 - The strike window is 4 seconds. A missed strike or a failed reel loses the fish and the bait.
 - Reel difficulty rises with the fish's weight on a log scale. Fish of 100 g or less are trivial and heavier fish get harder. Landing a fish gives a short pose with the catch held in the hand.
 - What bites is rolled from a table of 37 breeds. A breed only counts if the water type, the season and the bait match. The water types are river, pond, lake and sea. The sea is found by ray casting for water. The other three come from a 1 m grid with 34,334 cells in 38 bodies of water (19,720 lake, 7,815 river, 6,796 pond).
 - Rarity weights are 100 common, 40 uncommon, 12 rare and 3 very rare. A peak season triples the weight. Fish that feed at dawn and dusk or at night get double weight in their window and half weight outside it. Some breeds get double weight at full moon, and every breed is cut by a quarter at new moon.
 - Weight in grams is picked between each breed's minimum and maximum, leaning towards the small end. The catch message gives grams or kilograms.
 - The rod breeds are gudgeon, bleak, roach, rudd, dace, perch, ruffe, crucian carp, bream, chub, tench, carp, barbel, grayling, trout, brown trout, pike, zander, burbot, catfish, eel, lamprey, salmon, sturgeon and sea trout (rivers and sea), plus the sea breeds herring, sardine, anchovy, mackerel, cod, sea bass, tuna and swordfish.
 - Crayfish, freshwater mussel, shrimp and lobster exist as items, but they have no bait entry so the rod can never roll them.
 - Lamprey and sturgeon are marked as lord's fish, and the catcher is told that by law they belong to the count. That's only a message.
 - Small breeds also count as bait. Every fish spoils one hour after landing, see freshness.
 - Quality in stars comes from how well the challenge went. A full bag sends the fish to Claims.
 - Each cast wears the rod by 2, so a rod snaps after about 50 casts. The heaviest fish of every breed is kept in a records table, and the catcher is told when they beat it.
 - In winter rivers, ponds and lakes freeze. Nobody can start fishing there, and a player who is already fishing is stopped with a message when the water freezes. The sea never freezes.
 - Staff: /fishspot (Trial level). It places a fishing spot on the water in front of them, up to 16 m out.

Hunting, licences and traps
 - A hunting licence, a woodcutting licence and a mining licence are sold per season by the steward in the ducal fortress. A licence is valid for one in-game season and you pay for it with coin that goes to the county treasury. The price is a county policy setting. Licences are saved per character.
 - Hunting game without a licence, killing a protected species, or hunting in a closed season is poaching. It commits the poaching crime if anyone sees it. Which species are protected and which seasons are closed are county policies. Herd animals are never judged by this rule, and wolves and bears need no licence. A bear can still be protected by policy.
 - Felling trees or mining without that licence also raises the poaching crime, with a warning shown at most once every 10 minutes.
 - The steward also pays the wolf bounty. You hand over wolf pelts for a county set amount each, paid from the treasury, and the pelts go into the treasury.
 - A kill leaves a carcass in the world, up to 24 at once, and the oldest is removed when more appear. Carcasses use a species model that is fitted to the slope of the ground, floats on water, and carries a "A dead (species)" label.
 - Small game (hare, rabbit, fox, pheasant, duck, heron) is picked up with Y. The kill gives its meat, feathers or pelt directly.
 - Deer, boar, wolf and bear are dressed with a knife where they fell. That's a work node scene (open, gut, skin, portion). Dressing gives venison, boar meat or a pelt, plus antlers, tusks, fat and bone depending on the species. A clean kill, one wound only, is worth an extra star.
 - You can also shoulder a big carcass with Walk plus Y and take it to a butcher to be jointed. It goes into the bag as a heavy carcass item (3 stars for a clean kill, 2 otherwise) that keeps the species and sex.
 - A body left lying rots away after 15 minutes. The remains of a dressed one are gone 15 minutes after dressing.
 - Hunting practice is earned for kills (double for a one wound kill), for setting traps, and for taking up small game.
 - Traps come in three kinds. A snare takes hares, rabbits, foxes and pheasants and kills them outright. A foothold trap holds deer, boar, wolves and bears until it is dealt with. A pit, dug with a shovel from the bag, holds boar, wolves and bears.
 - Setting a snare or foothold takes 4 seconds and a pit 9 seconds. Moving away cancels it. A player can have 6 traps set and the world holds 64. Traps can't be set within 4 m of another trap or indoors.
 - Bait draws game within 40 m towards a baited trap.
 - A foothold trap also catches any player other than its owner who steps within 1 m of it. They take 10 damage, are frozen on the ground, and work free after 5 minutes unless someone pries it open.
 - Pressing Y near a trap opens a panel with the options that apply. Set it again, spring it, bait it, prise the jaws open, or take it up (a pit is filled in instead). Springing or taking up another player's trap commits theft.
 - Traps and their state are saved in the traps table and come back after a restart. Old kills are cleared on boot.
 - Staff: /hunt (Admin level) with info, carcass <species> [female], licence <hunting|woodcutting|mining> (toggles the licence), trap <snare|foothold|pit> and traps clear.

Coins and payments
 - Money is carried as coins in the bag. The coins are pfennig (1), groschen (12 pfennig) and gulden (240 pfennig). A coin stack holds up to 100 coins.
 - Prices everywhere are in pfennig and shown as a mix such as "1 gulden 3 groschen 5 pfennig". With nothing, the text is "No coin".
 - The payment code takes coin from the bag and from any coin purse container in it. It spends the small coins first and hands change back automatically. It tells the player when they're short of coin, or when there's no room for the change or in the receiving container.
 - A payment can go into a container such as a till or the treasury. If the container's slots are full of loose small coins, it melts them into the fewest, largest coins to make room.
 - Coin that can't fit in a bag is sent to Claims, including for characters who are offline.
 - Every payment, gift, change and starting grant is written to the coin_ledger table with the source, amount and the characters involved.
 - New characters get starting coin by origin. Monastery ward gets 10 pfennig, Forest folk 15, Village peasant 20, Soldier's child 30, Foreigner 40 and Town burgher 60.
 - Coin breaking and making works for the trader, with a 1 pfennig fee. See the trader section.
 - Staff: /givecoin <player> <pfennig> (Management level).

Player to player trading
 - Stand within 2 m of another player, face them (45 degree cone) and press Walk plus Y (left Alt plus Y). The other player gets a prompt that lasts 30 seconds. You can't ask a player who is already trading or busy with another panel.
 - Both players see their own bag and what each side offers. You can offer up to 8 different item lines per side. Click an item in the bag to add one, and click it in the offer to take one back.
 - Coin is added in steps with the +1, +10 and +100 pfennig buttons, capped at what the player carries.
 - Each side presses Accept. Any change by either side after that clears both accepts. When both accepts stand, the swap happens in one go.
 - The swap checks first that both sides still hold everything. Stars, freshness, wear and item data travel with the goods. If a bag is full the rest goes to Claims.
 - The trade is called off if the players move more than 5 m apart or into different worlds, if one disconnects, or if one backs out.

Traders (NPC merchants)
 - Traders are NPC actors that buy almost any item and sell a short list of imports. Press Y next to one while they're open. Up to 16 traders can exist. Two are placed on a fresh database (Bohuslav and Kunes), and staff can place more.
 - They keep day hours and are packed up at night, back at dawn. At night a message says the market is closed.
 - A trader pays 40 percent of an item's base value, scaled up by its star rating (100, 100, 130, 170, 220 and 300 percent for 1 to 5 stars). Character traits and hygiene change the offer. Traders don't buy items with no base value, coins, containers or items that are partly used up.
 - Each trader only has 2,000 pfennig to spend per day, refreshed every 24 hours. When the purse is empty the trader tells the player to come back tomorrow.
 - The shelf sells iron bars, salt, spice, seed, rope, halter and rope, parchment, water skins, four special dice (weighted, heavy, lucky and devil's) and rotten cabbage, at 150 percent of base value.
 - Traders also fill a water skin for 1 pfennig and break or make coins (one bigger coin into smaller ones, or smaller ones into a bigger coin) for a 1 pfennig fee.
 - A bad harvest or other scarcity event raises the price of food and drink, both what the trader pays and what is charged, until it passes.
 - Members of a craft guild who sell goods of their own trade at or above the guild's quality mark get a bonus on the trader's offer.
 - Each trader's day purse and position are saved in the traders table.
 - Staff: /trader place <name>, /trader remove (nearest within 3 m) and /trader list (Trial level).

Inventory (the bag)
 - The bag opens with N while on foot, out of combat and not riding. It holds 18 slots in a grid of tiles at the bottom right, with a purse line showing total coin and a footer showing the selected item, its freshness and wear.
 - Clicking an item shows its actions. Eat for food, Drink for drinks, Open for containers, Carry it or Put away for weapons, Strap it on or Put away for shields, and Use for everything else. Every item can also be examined and dropped, and given to a nearby player.
 - Examine shows the kind (Weapon, Shield, Food, Drink, Tool, Coin, Container, Material, Clothing or Curio), quality in stars, the amount carried, what the item is worth, how many minutes of freshness are left, and percent worn.
 - Give hands over one item at a time, with its stars, freshness and wear, to a player within 2 m. It lists up to 8 nearby players to choose from. If their bag is full the giver keeps it.
 - Items stack up to 5 per slot (coins up to 100). Weapons, shields, containers, tools and clothing don't stack, and each instance keeps its own wear and data.
 - Quality is 1 to 5 stars. Price is scaled by stars (100, 100, 130, 170, 220 and 300 percent).
 - Food and drink have portions, worked out from value (15 per portion, 1 to 4 portions). A half eaten item is marked as started. You can't drop it, hand it over, sell it or put it in a container until it's finished.
 - Weapons and shields in the bag are the carried gear. Using one equips it, and the choice is saved and restored on login. A ranged weapon is told it uses ammunition from the bag.
 - Other modules add buttons to the bag (up to 4 beside Close). This module adds Claims.
 - Everything is saved in the character_items table, including stars, used portions, freshness, wear and an item data field. New rows are written in the background so a pickup never waits for the database.
 - Group lookups let recipes and rules accept any member of a group of items (for example any bait, or any fish).
 - Staff: /giveitem <player> <amount> <stars 1-5> <item name> (Management level).

Item catalogue
 - There are 364 item definitions, plus weapons, shields, three coins and dynamic containers. The kinds are Food (21), Drink (8), Tool (70), Misc (66), Material (187) and Clothing (12).
 - Each definition has a name, a model, a food or use value, a shop price in pfennig and a stacking flag. Examples are bread at 1, a cleaver at 18, a mail shirt at 1,440 and a plate set at 6,000.
 - The catalogue covers crops, produce and animal goods, meats, fish (37 breeds plus rare and spoiled fish), woods, ores, cloth and leather, tools for every trade, furniture, light sources, dice and cards, letters and parcels, musical instruments (lute, flute and drum), horse gear, 30 herbs and mushrooms, 22 masterpiece prize items, and the carried containers.
 - The 30 herbs run from yarrow, plantain, comfrey and willow bark through to hemlock, foxglove, wolfsbane, death caps and wild cherries. Several are poisonous.
 - Item weights, bulk flags and load values are a generated table with one entry per item.
 - Every item has an icon. Icons come from six sheets (food, goods, fish, tools, gear and arms) with a fallback for unknown items. The in-world model comes from the delivered model set, with stock models used for items that have none.

Containers and carried bags
 - Containers are lists of item slots saved in the containers and container_items tables, owned by something in the world. There are 14 owner types. Store (30 slots), till (10), county treasury (20), reserve (12), chest (8), coin purse (3), bag (8), coffer (30), cart (16), saddlebag (6), carried bag (6), group treasury (12), group store (24) and building site stockpile (16). Up to 256 are loaded at a time and a container can have up to 32 slots.
 - Containers in the bag are opened with the Open action. Click an item inside to take it into the bag, or choose "Put something in" and click an item in the bag to store it. Items keep their stars, freshness, wear and data when they move.
 - Carried bags are real items that hold other items in their own container. The belt pouch has 3 slots, the basket and creel 6, the woven basket 4, the satchel 6 and the backpack 10. They refuse bulky goods and other containers.
 - A belt pouch takes coin, herbs, bait, seed, salt, small tools and the like. A basket takes produce, herbs, eggs and bread. A creel only takes fish and bait. A satchel and a backpack take anything small.
 - I never added anything that creates the coin purse and bag container types, so coin is still held loose in the bag.

Weight and carrying
 - Every item has a weight in grams. Coins weigh 5 g each. Weapons are 1,500 g and shields 4,000 g. Containers weigh their own weight plus their contents.
 - The carry limit is 25 kg, plus 3 kg for every point of Willpower, plus 10 kg for a backpack or 4 kg for a satchel (the larger one counts).
 - Over the limit is Heavy. Over one and a half times the limit is Overloaded. What those bands do to movement is handled by the carrying system.
 - Bulky items, such as coffers, are carried in the hands, and the heaviest bulky item decides the model shown in the hands. The weight and bulk tables are generated from the catalogue.

Dropped items
 - Drop puts the whole slot on the ground one metre in front of the player, with a model and a label such as "Bread x4". Up to 500 drops exist at once.
 - Press Walk (left Alt) next to a drop, within 2 m, to pick it up. The stars, freshness, wear and data come back with it. A full bag shows a message and leaves the item.
 - Drops are saved in the dropped_items table and are restored on boot. Hunting loot that doesn't fit in the bag lands on the ground as a drop. Drops don't expire.

Claims
 - When something is given to a character whose bag has no room, it goes to Claims instead of being lost. Trades, fishing, coin payouts, hunting loot and other rewards all use this, and it works for characters who are offline.
 - Claims are kept for 14 days. On login the player gets a summary, and items with 2 days or less left are flagged in red.
 - The bag's Claims button lists up to 24 entries, with Take all or one at a time. Anything that still doesn't fit stays in the list.
 - Expired claims are purged at every in-game day.

Freshness and wear
 - Perishable items remember when they were made. Right now only fish are perishable. Every fish breed, rare fish and plain fish go off 1 hour after landing and turn into spoiled fish.
 - The bag is checked once a minute and again on login. Spoiled stacks are swapped for spoiled fish and the player is told to cook fish within an hour. Cooking, salting and smoking avoid it.
 - Stacks keep the oldest freshness when they merge. The freshness is shown in the bag footer and the examine panel as minutes left or "going off".
 - Items carry wear from 0 to 100 percent. Fishing rods are worn by use and are destroyed at 100. The wear shows in the footer and the examine panel.

## Villagers, animals, horses and roads

The paths and pedestrians components
 - Two first-party open.mp components sit under every walking villager, animal and bandit. Their headers are copied into legacy/ and included from bootstrap/includes.pwn as <paths> and <pedestrians>. The binaries are built in the server image and aren't in this repository's components/ folder. That folder only holds the stock components like Actors, NPCs and Recordings. So the NPC systems need both installed next to them.
 - Paths is a node graph with an A* search. It has two layers, PATHS_LAYER_PED (0) and PATHS_LAYER_CAR (1). The natives cover finding a route (Paths_Find, Paths_Cancel, Paths_MoveNpc, Paths_StopNpc, Paths_IsNpcMoving, Paths_GetNpcRequest), reading the graph (Paths_ClosestNode, Paths_NodePos, Paths_RandomNode, Paths_NodeDistance, Paths_NodeLinkCount, Paths_NodeLink, Paths_NodeSpeedClass, Paths_NodeCount), editing it at run time (Paths_AddNode, Paths_AddLink, Paths_LoadCustom, Paths_SetBlocked, Paths_IsBlocked), no-spawn areas, and tuning (worker threads, queue limit, level tolerance, point range, Paths_Pending).
 - Paths answers with the result codes PATHS_OK, NO_START_NODE, NO_TARGET_NODE, UNREACHABLE, LEVEL_MISMATCH, LAST_MILE_BLOCKED, QUEUE_FULL, CANCELLED, BAD_ARGS, NPC_GONE and MOVE_REJECTED. Find and MoveNpc give back a request id above zero. If the request never reached the queue, they give back the negated reason. The callbacks are OnPathsFound(requestid, pathid, success, reason), OnPathsNpcArrive and OnPathsNpcFail.
 - The gamemode only calls a few things from Paths. Those are Paths_LoadCustom (loads scriptfiles/paths/mrp-paths.txt), Paths_Find, Paths_ClosestNode, Paths_NodePos, Paths_NodeLinkCount, Paths_NodeLink and the OnPathsFound callback. The graph file has 1489 nodes, 2751 links and 138 home nodes. A script generates it from the map. Nobody edits it by hand.
 - Pedestrians is the engine behind streamed ambient people, animals and bandits. It creates, streams, walks, damages and kills its pedestrians (its own API calls them actors) and runs their state machine (WALKING, PANIC, FALLEN, STOPPED, DEAD). The gamemode configures it and reacts to callbacks. Walkers_Setup sets a pool of 60 pedestrians, 8 per player, a 150 m streaming distance and an ambient spawn density of 0. So nobody appears at random.
 - The pedestrian natives the gamemode uses are SpawnPedestrianAt(skin, x, y, z, angle, kind), DespawnPedestrian, IsValidPedestrian, GetPedestrianPos, GetPedestrianKind, SetPedestrianKind, SetPedestrianBody, SetPedestrianHealth, GetPedestrianHealth, SetPedestrianTarget, SetPedestrianSpeed, StopPedestrian, ResumePedestrian, PedestrianFleeFrom, SetPedestrianFacingAngle, GetPedestrianFacingAngle, ApplyPedestrianAnim, GetPedestriansInRange, GetPedestrianSex, GetClosestPedestrianID, PedestrianPathProbe, Path_ReloadNodes, Path_AddMaleSkin, Path_AddFemaleSkin, Path_SetSpawnDensity, Path_SetMaxActorsInPool, Path_SetMaxActorsPerPlayer, Path_SetStreamingDistance, Path_SetUseColAndreas and TogglePedInInterior.
 - The pedestrian callbacks the gamemode handles are OnPedestrianSpawn, OnPedestrianReachTarget, OnPedestrianPathFailed, OnPedestrianGetDamage (it carries the weapon id and the damage amount) and OnPedestrianDeath. The header also declares gang zones and gang skins, tear gas, pack hostility, panic, punch, vehicle hit and aim callbacks. I don't use any of those.
 - Navigation meshes are the newest part of Pedestrians. The server reads scriptfiles/nav/people.bin, deer.bin, sheep.bin and people-interior.bin (Recast and Detour, 64 m tiles, baked offline from the map collision). SetPedestrianTarget routes along the mesh of the pedestrian's body type. PED_BODY_PEOPLE is 0, PED_BODY_DEER is 1 for deer, boar, bears and cattle, and PED_BODY_SHEEP is 2 for everything smaller. With no route the pedestrian just stands there and OnPedestrianPathFailed fires. A body type with no mesh file walks in a straight line.
 - The Rider natives are the third piece. They're described under NPC riders below.

Actors (the villager layer)
 - Every named non-player you can click on is an actor. The module keeps up to 260 of them (200 plus the 60 pedestrian pool). Each has a key, a role, a sex, a skin, a name, a title, a place, a world and an interior. Named actors are stored in the actors table and keep their death timer across restarts. Pedestrians that a player walks up to get registered as actors on the spot, so you can talk to any walker.
 - There are two kinds. Static actors stand in place on an animation. Walker actors take a pedestrian body when they leave their spot and walk to a target. So one villager can cross the map and still be the same person.
 - 28 roles are defined. Farmer, herdsman, goodwife, child, elder, craftsman, baker, innkeeper, merchant, woodsman, fisherman, clerk, healer, miller, labourer, servant, villager, trader, priest, crier, gaoler, guard, yard master, stablehand, courier, bandit, reeve and bailiff.
 - Talking works the same everywhere. Face someone within 2.2 m (4 m for a villager walking down the road, who steps round you) and an infobox prompt shows. Press Y and a menu opens with the options for that person. Other modules add rows with the Actors_OnMenuBuild hook. The rows from this part are Trade (traders), Play a game (the regulars), Buy a coach seat (the coachman), the horse keeper rows, the family rows and Talk with him or her. Other systems add errands and warrants, the herald, the county steward, the hunting licence clerk, monks, the courier and the charter desk. At most 12 rows fit.
 - The talk menu won't open while you're bound, serving a sentence, in combat mode, riding, in a dialogue, at a family table, at an infirmary prompt or otherwise busy.
 - Hurting an actor is a crime. The first hit on a living actor is assault and a kill is murder. Each one counts the witnesses within 25 m. A hurt actor flees for 8 seconds. In a private interior it cowers for 4 seconds instead. Actors also add themselves to the witness count when the law system asks who saw a crime.
 - A dead actor lies as a corpse for 60 seconds. After 30 minutes it comes back with a new random skin of the same sex. Staff can mark an actor invulnerable.
 - Villagers remark on a player who smells. When the hygiene system marks you as stinking, or as reeking, anyone standing within 4 m can say a line like "God's teeth, you could do with a wash". That has a 35 percent chance and happens at most once every 75 seconds for that player. A reeking character is also refused at a family table.
 - Each actor shows a name and title label (visible within 10 m) and a speech bubble that lasts 6 seconds and carries 12 m. Actors_Say and Actors_Do are the calls other modules use to make someone speak or act.
 - Staff: /actor list | info | kill | revive | say [text] | go [key] (trial level and above). The list counts actors registered, standing, walking and dead.

Walkers (people on the roads)
 - Walkers are the household members, road wardens and other villagers you see walking between home, work, church and market. They're pedestrians on the node graph. Each keeps to one side of the road, at an offset worked out from its id. A traffic check every quarter second stops a walker behind another one walking the same way, so people don't stack up.
 - Routes follow the road graph and finish on the navigation mesh. A walker that can't find a route fails the leg and stands. A walker goes indoors by despawning at a home node. With the random density at 0, the only people outdoors are the ones the families, patrols, market visitors and bandits create.
 - A walker pauses while a player talks to it and carries on after goodbye.
 - Staff: /walkers (how many are out, graph size, day or night), /navwalk (send the nearest villager to x y z), /navspawn (place a villager that stays, kind 2), /navtalk (hold or release the nearest villager like the talk menu), /navflee (scare the nearest animal away), /navprobe (route length on a mesh body), /navstats (mesh and crowd counters to the log), /navcam (the camera follows a pedestrian) and /navcls (clear the chat). All trial level.

Church hours
 - The day is split into the canonical hours and the hour name shows beside the date at the top of the screen. In summer Prime is 06:00, Terce 09:00, Sext 11:00, Nones 13:00, Vespers 18:00 and Compline 20:00, with Matins at 02:00 and Lauds at 05:00. In winter there's no Terce or Nones. Prime is 08:00, Sext 12:00, Vespers 16:00 and Compline 20:00.
 - Two church bells ring at fixed positions. A player outdoors within 450 m gets a short message like "The church bell rings for Terce". Matins and Lauds ring only at the second bell.
 - The hours drive other systems. Families sit down to dinner after Sext and to supper after Vespers, go to mass on Sunday, and anchor their day plans on the hours. Other modules hook Routine_OnKeyframe (the notices board does). The HUD hour disc follows the current hour.
 - Staff: /hours. It shows the hour and fires the current keyframe again (trial level).

Families and households
 - Every house in the villages has a family. The seed data covers 41 households with 131 members, 145 table topics, 164 errands, 10 graces, 22 meal questions, 422 meal conversations with 1570 lines, 1332 answers, and 134 voices with 2144 voice lines and 188 trade rows. A script generates the data from the map layouts.
 - Each member is an actor with a name, a role, an age band (child, youth, adult, elder) and a skin picked from age-appropriate lists. Households have a wealth level, a trade, a piety level and a stock of stores from 0 to 100.
 - Members follow a daily plan. 99 day templates cover the people (farmer, grandmother, farmer's wife, child, weaver, baker, carpenter, innkeeper, potter, herdsman, orchard keeper, mason, forester, charcoal burner, tailor, merchant, cooper, brewer, alewife, smith, wheelwright, bowyer, herbalist, chandler, fisherman, thatcher, butcher, tanner, beekeeper, cottar, shepherd, hunter, miner, miller, barber-surgeon and more). Each template has a plan for every weekday. 24 kinds of spot are used. Bed, home, family table, yard, doorstep, fields, forest, water, square, market, church, work, well, wash, garden, tavern, visiting kin, helping a neighbour, spinning circle, play, church lesson, pond, forage and sickbed. There are 37 workplaces and 7 villages.
 - The plan changes with the kind of day. There are seven kinds, workday, Sunday, market day, feast day, rainy day, snowy day and harvest. A feast day beats Sunday, Sunday beats snow, snow beats rain, rain beats market day, and the harvest (year days 221 to 260) replaces an ordinary workday. Rain and snow keep most people indoors.
 - Saturday is market day. The stalls are staffed from 09:00 to 16:00, with setup starting half an hour earlier. On Fridays and the fasts (Lent, Passiontide, Advent) you get fish and plain bread on the table. On Sundays and feast days wealthier houses serve roast fowl and poorer houses a wheat loaf. Everyone gets honey cakes.
 - Nearly everyone goes to mass on Sunday and feast days. Up to 8 people per church are assigned and they leave about 7 minutes before the service (the faith module runs the mass).
 - On most afternoons after Nones the wives of neighbouring houses sit by one house's door and spin together (10 circles, one host a day, each wife joins every other day). In rain or snow they spin at home. Children play on the green and have a church lesson with the priest on Sundays.
 - People fall ill. About 2.2 percent of members start an illness on any given day and it lasts one to three days. A sick member stays in bed and someone from the household sits at the bedside at Terce, after Nones and before Vespers. If you ask what they're up to, you get a sick answer. Foragers walk to a herb or mushroom node that still has stock in the open world.
 - To find out what someone is doing, talk to them and ask "What are you up to?". The answer is built from their current plan (place, time, reason). Under Village the panel lists up to 6 "Where can I find the X?" questions for trades in the same village. The answer gives a compass direction and where that person is now.
 - A player can eat with a family. Dinner starts 15 minutes after the Sext bell and supper 15 minutes after Vespers. Ask a family member if you can eat with them before the meal starts (Y menu row "Ask to eat with the family"), or press Y at a free seat once the table is laid. These are the rules in the code
    - A reeking character is turned away
    - A house with no guest stool, or a full table, turns you away (4 guests at most)
    - Anyone renting a room in that house is always welcome
    - Favour 20 or more eats free. Below that, a poor house (wealth 1 or less) asks 2 pfennig for the pot once, and a house with negative favour for you says it doesn't know you well enough
    - After the grace (10 different graces exist) press Y for each of six bites. They talk to you between bites, so answer before the next one
    - Each bite gives you half the dish's hunger and thirst value. Cleaning the plate gives +3 favour and the Well fed buff for 30 minutes (hunger and thirst topped up by 1 every 150 seconds). Getting up early costs 2 favour.
 - Meals use 28 dish groups with hunger and thirst values (pottage 30, stew 40, roast on pewter 45, rye bread 15, ale 35 thirst and so on). A household with stores under 30 serves only pottage and rye bread. Dish props go on the table and get eaten down in three stages. The table talk offers three reaction choices (Nod along, Ask them to say more for +1, Change the subject for -1) plus the favour carried by each meal answer.
 - Favour toward a household is stored per character from -100 to 100 in the household_favour table. A family greets you by name from 15. It grows from errands, clean plates and good answers. Delivering a parcel to a house gives that house +2.
 - Errands are the work villagers hand out. Ask "Do you have any work for me?" or use the Y menu row "Ask if there's work". There are two kinds, collect (bring N of an item) and deliver (carry a parcel to a named person at another house). A character holds one errand at a time. Each errand pays coin and favour and has a 6 hour real-time cooldown per player. Only collect errands whose item you can get in the world are offered. Progress is saved in errand_progress. You give an errand up from the same menu.
 - Until a character has played 2 hours, family errands pay double (the Newcomer's wages buff shows the time left, so a 4 pfennig errand pays 8). A message appears when it ends.
 - Household stores are never changed by play. Only staff change them.
 - Staff: /family list | info | go [house] | meal [dinner|supper|end] | favour [n] | stores [n] | errands | freeze | refresh | foul [0|1|-1]. And /days kind | who [name] | where [member] | sick [member] [on|off|auto] | workshops [on|off] | dump | list. Both are trial level.

Dialogue
 - Press Y on a villager and pick Talk with him or Talk with her to open the Conversation panel. The camera moves to a framed spot in front of the talker. It's checked against walls and other players, or it uses the old fixed spot if staff switch to classic. The panel has topic groups Greeting, Work, Family, Village and Their trade, three lines per page, and Previous, Next, Topics and Goodbye buttons. ESC also ends it.
 - What you pick is spoken in chat as your own line, so players nearby hear it. Standard topics include "Good day to you.", "Who are you?", "Thank you.", "Do you have any work for me?", "What are you up to?", "Can I eat here?", "Tell me about your family.", "Any news in the village?", "What do you think of the weather?", "Where is the inn?", "Where is the church?", "Are the roads safe?", "What happens to thieves here?", "What do you sell?", "How much does it cost?" and "I'd like to trade with you." Each of the 28 roles also has its own trade question, like "How are the crops this season?" for a farmer or "How goes the watch?" for a guard. Household members add questions about their own table and the trade rows they sell.
 - Answers come from the seeded answer tables, picked by voice and variant. Some are filled in live, like compass directions to the inn or church, the weather, the speaker's own name and current fees. There are six voice traits, so two villagers answer the same question differently.
 - A topic can start an action. Work opens the errand offer, Can I eat here opens the meal request, and a trader's trade line opens the trade panel (the stall must be open and you must be within reach). There's a 3 second gap between lines.
 - An optional external dialogue service can answer instead of the canned lines. It's configured in scriptfiles/dialogue.ini (url, enabled, staff_only) and it's staff only unless staff_only is set to 0. When it's on, the gamemode posts a JSON body over HTTP. The body has the actor key, name, title and role, the player's character id and name, the line, a stored memory summary and the context (date, hour, season, weather, place and a smell remark). The reply carries an intent, the spoken line and a memory note. The intents acted on are work, meal, sell, guard (the villager looks ready to shout for the guard) and farewell. If the service is off, the player isn't allowed, the request fails, takes more than 15 seconds, or answers capped, limited or error, the canned line is used.
 - A short memory per actor and character (512 characters) is kept in the actor_memory table and sent with the next request. It's only written when the service answers.
 - The conversation ends if you walk out of range, after 180 seconds with nothing said, or when the villager becomes unavailable.
 - Staff: /dialogue status | reload | staffonly [0|1] | memory | camera [classic|fixed|scan] (trial level). Status shows the sent, model, canned and failed counts and the last error.

Animals
 - 16 species live in the world. Farm animals are cattle, sheep, goats, pigs and chickens. Game animals are red deer, roe deer, wild boar, hare, rabbit, fox, pheasant, duck and heron. Predators are wolves and bears. Each has its own health, walk and run speed, flee radius, damage, pack size, active time (day, night or always), a spawn weight, and a male and female skin where both exist. Every body is a custom model with a matching carcass model for hunting.
 - The herdsman's animals are always there while someone is near. 25 beasts stand in three pastures and graze as herds. One that gets slaughtered comes back after 10 minutes.
 - Wild animals appear at 66 seeded places (32 forest, 20 meadow, 12 water, 2 dens) when a player comes within 130 m and nobody is within 50 m. At most 40 animals exist at once, one group per place, with a random group size up to the species' pack size. Species are weighted by habitat and by the hour. Foxes and wolves are out at night. Wolves are also out all day in winter, at triple weight. Bears live at the dens. Animals despawn when nobody is within 145 m.
 - Behaviour is a state machine. Calm animals graze, walk with the herd leader or, at night with nobody near, lie down. When an animal notices a player it goes alert (head up, staring), then wary, then it flees along its own mesh, runs its set distance, slows and looks back. Game bolts from a shot or thud within about 20 m and lifts its head up to 45 m. If you crouch, you can get twice as close before game notices you.
 - A wounded boar charges whoever hurt it. A bear defends its den and attacks anyone within 12 m of it while it is within 14 m of home. Wolves hunt at night, and all day in winter, and go for a lone player within 28 m. They give up after 30 seconds or 60 m from where they began, rest 15 seconds, never chase into town, and a wolf that loses its target walks home. Pack mates within 60 m join the same target.
 - A bite lands every 1.5 seconds within 1.8 m and does the species' damage (wolf 9, boar 12, bear 22).
 - The hunting module uses Animals_OnKilled to place the carcass. It handles traps, bait and held animals through the animal calls. Each species carries a protected flag the realm module can read.
 - Staff: /animals list | wild 0|1 | spawn <species> [count] | clear | kill | hurt | species (admin level). wild turns the random wild spawns on or off.

NPC riders
 - A mounted NPC is a real open.mp NPC that carries the horse's animation frames on its spine. It uses the same rig a mounted player uses. It moves along the ped graph or along a list of points. Gait speeds are walk 2.4, run 6.0 and gallop 9.0 metres per second, times the type's speed factor (0.7 for donkeys).
 - The Rider natives (Rider_Create, Rider_SetGait, Rider_MoveTo, Rider_SetRoute, Rider_Stop, Rider_SetSpeed, Rider_IsMoving, Rider_IsValid, Rider_GetRoutePoint, Rider_GetPos, Rider_Destroy, Rider_Count and the OnRiderArrive callback) come from the same component family. The gamemode wraps them in NpcRiders_Create, NpcRiders_Ride, NpcRiders_RideRoute and NpcRiders_Destroy and keeps a table of 8 riders. There's a server-wide NPC budget of 25. When it's full, a new rider is refused with a log line.
 - Each rider is registered as an actor with the title Coachman, so a player can talk to it. The public coach and the hired coachmen use them.

Market visitors
 - While the Saturday market is open, six shoppers stand around the market square, 10 m from its centre, each in a different starter skin. They're actors titled Shopper that players can talk to, held still by the walker pause. They're removed when the market closes. The module checks every 30 seconds. This is just scenery.

Mounts (riding)
 - Riding is built from attached objects. A horse is a set of animation frame models (57 idle, 29 walk, 17 gallop and 19 sprint frames per type) attached to the player's spine while the player plays the bike-riding animation. 15 mount types exist. Four are named horses (Chestnut Appaloosa, Tennessee Walker, Dapple Mustang, Dutch Warmblood), one is a donkey (no gallop, 0.7 speed, its own walk and sprint frames) and ten are coat variants (Bay, Dark Bay, Chestnut, Black, Flea-bitten Grey, Dun, Palomino Dun, Piebald, Blue Roan, Strawberry Roan).
 - Mount and dismount with F. Stand within 1.5 m of the horse's left or right side and press F. The character plays the jump-on animation and is mounted after 0.8 seconds, with a 5 second cooldown. You can't mount below 15 health. A horse that is wild, a foal, held or someone else's tells you why you can't (see Horses). Pressing F again dismounts you beside the horse. A module can register a dismount check. The jousting events use one so a rider can't get off mid bout.
 - Riding uses the normal movement keys. Forward is a trot. The walk key slows to 0.4 of that and back moves slowly. Left and right turn 6 degrees per update (15 above 105 ping). Hold the jump key with forward to gallop at 1.5 times the trot. Gallop is refused above 105 ping, for donkeys, and for a horse that can't gallop.
 - Stamina drains one point per update while galloping. The pool is 100 by default and follows the horse's stamina trait. Below 15 you drop out of the gallop and can't gallop again until stamina is back to 65. It recovers while trotting and standing.
 - Terrain is handled with ColAndreas ray casts. The rider is held 1.25 m above the ground and climbs slopes with a velocity lift, so the horse follows the ground. The allowed height band shrinks with ping.
 - Water is no place for riding. Riding in water gives a warning once a second, the third warning throws you off, and 10 seconds clear of water forgives the count.
 - Anything that changes your animation (an emote, an interaction, a teleport that doesn't keep the mount) dismounts you. So does going out of play or leaving. A mounted character counts as busy for the character system.
 - Other modules can slow the ride with Mount_SetSpeedScale (a cart behind the horse, mud on the road).
 - Seat and stand poses are stored per mount type in the database (mount_seats and mount_stands). Staff tune them in game with the attached-object gizmo.
 - Staff: /mountseat [idle|walk|gallop|sprint] while riding and /mountstand beside a parked mount (both admin level). /horse <type 0 to 14> spawns a plain horse two metres in front of you. There's no staff gate on it in the code.

Jousting hooks on mounts
 - The mounts module exports what the tournament events use. A rider can be given a lane (a start and an end point). The horse is steered along it with a small sideways push back onto the line (gain 0.08, limit 0.06), and left and right are ignored while a lane is set.
 - A lance model attaches to the right hand in several poses (upright, lowering, lowered, sagging, broken stub), with a helm-aware aim. The fit follows the attachment editor values for the right hand and updates live when staff change them.
 - Mount_Throw knocks a rider off with an animation and optional damage. The contests call it when a lance lands. The events module (not described here) runs the actual contest.

Horses (ownership, care and breeding)
 - A horse is a row in the horses table with an owner character, a name, type, sex (mare, stallion, gelding), breed, parents, birth day, ten gene loci, bond, hunger, thirst, condition, shoes, lameness, sickness, pregnancy and location. At most 64 horses exist in the world at once. A character may own 2 grown horses. Horse events (born, tamed, bought, sold, stabled, retrieved, covered, foaled, gelded, read, stolen, inherited, died, shod, sold on) are logged in horse_events.
 - Horse time runs in game days. One game day is 5 real hours (180 minutes of daylight and 120 of night), and a game year is 360 days.
 - Getting a horse. Buy one from a horse trader (the keeper at the Talmberg horse yard or the outer stable), or tame a wild one in the meadows. The market traders sell the halter and rope you need to tame one or to lead a horse that isn't devoted to you yet.
 - Wild horses stand in two meadows (the low meadow and the high meadow, 4 spots each, so 8 wild horses). Walk up with a halter and rope in your bag and press Y. Taming is a four stage scene (keep it calm, gentle it, halter and blanket it, the first ride). Each stage is a challenge (hold, rhythm, sequence, timing) and the horse's temper sets the difficulty. Success uses up the halter and makes the horse yours at bond 10 (15 on a good score). Then it asks you to name it with two to twenty letters.
 - A failed attempt makes the horse bolt and go wary for 10 minutes. You wait 3 minutes between attempts on any horse. Running or galloping within 25 m of a meadow spooks its herd for 60 seconds. A tamed horse's spot refills after 20 minutes and a fled one after 10. If you already own two horses, the wild one is let go.
 - Buying. A trader shows 4 horses a day, rerolled every game day (every 5 real hours), none fine in more than one stat. Breeds are weighted among Dutch Warmblood, Tennessee Walker, Chestnut Appaloosa, Dapple Mustang and Donkey, aged 3 to 10 years. The price starts from a breed base (Dutch 10 gulden, Tennessee 9, Appaloosa 6, Mustang 5, Donkey 3, mixed 5, wild 4). It adds 2 gulden for each fine stat, takes 1 off for each poor stat and 1 if inbred, halves for a horse of 20 years or more, and never goes below 1 gulden. One gulden is 240 pfennig. A bought horse arrives shod at bond 15. The ducal stable keeper doesn't trade.
 - Selling. A keeper buys your horse for half its retail value and refuses foals under 5 days. A sold horse is gone for good.
 - Looking after a horse. Within 3 m of your own horse, press Y to open its panel (tabs Horse, Kin, Traits, Care and Breeding). The Care tab has Feed it oats or hay, Water it, Groom it with straw, Shoe it, Lead it on a rope, Lend it for a day, Rename it, Saddlebags and Put a blanket on it. Feed, water, groom and shoe each run as a short challenge scene and take the item from your bag only when the scene ends well. Feed can be oats, oat feed or hay. Water can be clean or unclean.
 - Needs run on the clock. Hunger empties in 3 game days and thirst in 2. Oats and feed give 35 and hay 25 hunger, water gives 60 thirst. A hungry horse (under 20) has 70 percent stamina, and an empty one won't gallop. Condition falls 20 a day for each empty need, 10 a day in winter outdoors (half with a blanket) and 10 a day when sick. It rises 5 a day when hunger and thirst are both over 70 and 5 a day in a stable. A horse at condition 0 dies of neglect. Grooming adds 10 condition once a day. Needs are worked out from a stored time when someone looks, so nothing ticks for a horse nobody is watching. Riding hard doubles the hunger.
 - The owner is always told. The buff bar shows hungry, thirsty, lame and sick for their horse, and a message appears when it gets hungry or thin.
 - Shoes last 30 000 metres of riding. An unshod horse is 8 percent slower and each kilometre has a 3 percent chance of making it lame (2 game days, 40 percent slower, no gallop). Shoeing needs a set of horseshoes from a smith.
 - A thin horse in winter can fall sick (30, 15 or 5 percent a day by the health trait). Sickness lasts 3 game days, stops galloping and wears the horse down. A keeper treats it for 8 pfennig.
 - Bond runs from 0 to 100 in tiers of 20. They're Stranger, Wary, Familiar, Trusting and Devoted. It grows with riding (up to 6 a day, one per game hour ridden), feeding (2 each, 4 a day at most), grooming (3, once a day) and answering a call (1 a day). It falls by 1 a day after 10 days untouched, 2 a day while starving, 1 when you drive a spent horse (up to 3 a day) and 2 when it bolts. A new owner starts at 15 at most.
 - Bond has effects. Below Familiar a horse can throw you when you start to gallop (25, 15 or 8 percent by temper, halved at Wary). Below Familiar, or below Trusting with a skittish temper, a horse panics when you're hit, throws you and bolts. A devoted horse stands over a fallen rider and the rest run off. Leading a horse needs a halter in your bag unless it's Devoted.
 - Calling. Hold F for 0.7 seconds with no horse near. Your last ridden horse (or your first grown one) walks to you from out of sight behind you if it can hear you. That range is 30, 60, 100, 150 or 250 m by tier. It doesn't hear you indoors, while someone rides it, or while it's stabled. 10 second cooldown.
 - Leading. Choose Lead it on a rope and the horse follows 3 m behind. It lets go if you lose it by 40 m, mount anything or open the panel. A foal always follows its mother.
 - Lending. Lend a horse to a person standing beside you for one game day. They can ride and call it without it counting as theft.
 - Theft. Anyone else who tries to mount an owned horse faces a refusal chance equal to its bond in percent ("shies away"). If it lets them on, it's a theft crime, the owner is told, and the owner can whistle it back. A horse also refuses an unknown rider simply by being a foal or by being held.
 - Saddlebags. An owner can buckle on saddlebags (6 slots, 10 for donkey panniers), a container that travels with the animal and shows as a model. A blanket and a halter show on the horse too.
 - Stables. Three stables exist, the outer stable, the ducal stable and the Talmberg horse yard. Each has a keeper actor (the keeper names are Ota Konar, Bara Konarova, Jira Podkoni and Mates Uzdar), 12 stalls and a hitching spot. Talk to the keeper for Stable a horse, Fetch a stabled horse, Buy a horse, Sell a horse and Doctoring and breeding. A stabled horse is safe from theft and winter, needs no water, and needs no feed if you pay for it. It costs 2 pfennig a game day, 5 with feed, collected when you fetch it. After 10 unpaid days it's sold on. The horse must be within 20 m of the keeper.
 - Keeper services. Read its blood (30 pfennig) shows hidden traits. Geld a stallion (12 pfennig, he can then never sire a foal). Treat sickness (8 pfennig). Offer a stallion at stud (the owner sets the fee in pfennig). Book a covering for a mare.
 - Genetics. Each horse has 10 gene loci with two alleles each. Four set speed, stamina, health and temper (poor, common or fine, shown as three words like Slow, Steady and Swift). Six set the coat (base colour, agouti, grey, roan, patches and dun) and pick one of the painted models. A horse can carry a weaker allele it doesn't show. A foal that shows poor in a stat proves that both parents carry it, and a keeper can read the hidden blood. Breed pools set the odds for each locus.
 - Stats in play. Speed tiers are 0.94, 1.0 and 1.06 of base, stamina 80, 100 and 125. Health sets sickness odds and lifespan. Temper sets the throw chance, the taming scene and whether the horse holds under fire. A horse of 20 years or more loses a step of speed and stamina, and inbreeding costs a step of health.
 - Breeding. A mare must be at least 20 game days old, in spring or summer, in season (3 days in each 12, staggered per mare), not in foal, not covered already this season, and fed (hunger 30 or more). Book the covering at a stable. Stallions at stud are listed with their fee (your own stallion is free) and each covers up to 8 mares a season. The fee is paid to the stallion's owner and is claimable if they're offline. A parent and child or full siblings are refused. A shared parent or grandparent gives an inbred foal.
 - Gestation is 11 game days. A mare more than 8 days along won't gallop. She foals where she stands and the owner is told to name the foal. The foal takes one allele from each parent with a 2 percent chance of one stat allele moving a step. A mare that went hungry drops a weak foal. A foal is grown 10 game days after birth and can only be ridden then. The foal's breed is the mare's if the sire is the same breed, otherwise mixed.
 - Aging. A horse lives about 25 years (plus or minus 3 for the health trait) and after that has a 5 percent chance a day to die. At 5 real hours a game day, 25 years is far beyond any normal playing time.
 - When a player logs out, their horses are saved and taken out of the world. On login they come back beside the owner. Time away counts as pasture, so a quarter of the usual decay and no death from neglect. Horses are saved every 5 minutes and on shutdown.
 - Death of the owner. The horses go to the heir with their bond capped at 15. With no heir the first stable holds them for 30 game days and then sells them on.
 - Horse HUD. While you ride a horse you own or borrowed, or stand within 8 m of your own, a small panel shows its name and bond tier, bars for stamina, hunger and condition, and a status line (Calm, Hungry, Tired, Nervous or Restless, plus extras like thirsty, cold, lame, sick, in foal or won't gallop).
 - Staff: /horses give [breed 0-5] | wild | info | bond <n> | needs <hunger> <thirst> <condition> | age <days> | foal | season | lame | sick | kill | stock | stats (trial level). give adds a horse straight to your character with no cap check.
 - In-game help covers getting a horse, caring for it, calling it, mounting, stables, breeding and traits.

Carts and wagons
 - Six cart kinds exist. A handcart (8 load slots) is pulled on foot. A horse cart (20 slots, 3 seats), a covered wagon (32 slots, 4 seats), a coach (4 seats), a village coach (6 seats) and a prisoner cart (4 seats, barred door) are hitched to a horse.
 - The handcart and horse cart are items. A carpenter makes a handcart at the yard (carpenter level 5, 12 planks, 2 wheels, 2 nails) and a horse cart (level 7, 30 planks, 4 wheels, 4 nails). Use the item from your bag to set it down outdoors. The wagon, coach, village coach and prisoner cart have no item. The only ones that exist in play are the county's prisoner cart at the guardhouse and the public coach. Staff can spawn the rest.
 - Press Y beside a cart for its menu. The rows depend on the cart and on you. Open the load, Pull it or Let go of it (handcart), Climb in or Climb down, Lock or Unlock the load (owner), Hire a coachman to drive you (owner of a coach or wagon), Take it apart (owner, empty load, handcart or horse cart only) and Look at the owner's stamp. Guards also get Put the bound prisoner in and Let the prisoners out.
 - Each cart has a load container, shown by a model on the bed once there are 4 or more logs, planks or beams, 4 stone blocks, 2 barrels or enough sacks of grain. A locked load opens only for its owner. Carts are saved in the carts table, position included.
 - Pulling a handcart means walking. Running makes you let go. The cart trails 1.75 m behind and swings up to 14 degrees to follow turns. A horse cart is hitched by riding to its shafts (within 3.2 m) and pressing Y. You unhitch with another Y or by getting off. Wheels turn with movement and the body tilts with the ground.
 - What a cart costs the horse in pace is a factor. Handcart 1.0, horse cart 0.85, wagon 0.75, coach and village coach 0.8, prisoner cart 0.85, and a load over half full slows it by another tenth.
 - A cart that isn't yours is stolen. Taking hold of it commits a theft crime once per cart. The county's carts have no owner and guards may handle them. Looking at the stamp shows the owner's name or the county mark.
 - Prisoners. A guard can put a bound player into the prisoner cart and the door is then barred from outside. A prisoner can't climb out. Anyone else who wrenches the bar off and lets the prisoners out commits the crime of freeing.
 - Staff: /cart spawn [handcart|cart|wagon|coach|village|prisoner] | list | remove (trial level).

Public coach and hired coachmen
 - By day a coach runs the road between Talmberg, the church village and the guardhouse (3 stops over a 292 point route). It stops 90 seconds at each, turns round at the ends and waits out the night at its stop. The driver is an NPC rider named Coachman Jan on a Dutch Warmblood.
 - Stand by the coach and press Y (menu row Buy a coach seat) and pick a stop ahead of you. The fare is 2 pfennig per stop travelled plus the county's toll for each toll bar on the leg, read from the county policy. The coachman pays the toll at the bar for you, out of your fare. He calls "All aboard for X!" and "X! The coach stops here a while." You climb down at the stop you paid for. A full coach asks you to wait for the next.
 - Hired coachmen. The owner of a coach or wagon can hire a coachman for 6 pfennig to drive them to Talmberg, the church village, the guardhouse, the monastery or the castle. The owner pays any toll on the way. He climbs on the box and drives along the road. Once you climb down he takes the cart back to where it stood. Two hired coachmen can run at once, otherwise you're told none is free. The fee is refunded if no coachman can be found.

Roads and waystones
 - Riders go faster on a road. A rider within 4.5 m of a node of the pedestrian graph is on the road and rides at 1.08 times pace. With a cart behind, the cart factor applies. Off the road in rain, storm or snow a cart's pace is also multiplied by 0.75. The scale is refreshed every half second.
 - Six waystones with painted sign arms stand at the crossroads between Talmberg, the church village, the monastery, the guardhouse and the castle. Each arm names a destination and a distance like "Guardhouse, half a mile".
 - Two road wardens, Hanus Strazny and Vojta Pochuzka, walk the 732 point main road loop from village to village, day and night. When nobody is watching they keep their place by timer instead of walking. A warden within 60 m makes bandits scatter, and bandits don't start an ambush within 150 m of one.
 - The county's prisoner cart is placed at the guardhouse on boot.
 - Staff: /roads, which shows whether you're on a road, whether it's muddy, your pace scale and the nearest waystone. /roads mud 1|0|-1 forces mud, clears it, or follows the weather. /roads bandits 1|-1 forces ambushes at the nearest stretch or turns the force off. Trial level.

Bandits
 - Three lonely stretches of the main road carry ambushes. At night (or at any hour when forced), passing within 60 m of one rolls a 35 percent chance, 55 percent in winter. A stretch then rests for 20 minutes and the player for 30 minutes, and a failed roll gives that player a 2 minute pause. No ambush starts if a road warden is within 150 m.
 - Two bandits (three in winter) step out ahead, 18 m or more in front. They close in, and at 6 m they say a line like "Halt! Your purse or your hide, traveller." The demand is a quarter of what you carry, at least 10 pfennig and at most one gulden (240).
 - Press Y within 20 seconds to Pay them or Refuse and fight. Paying makes them leave. Refusing, staying silent, not having the coin, or hitting a bandit first starts the fight. Riding or running more than 70 m away makes them give up.
 - In a fight a bandit hits every 1.5 seconds for 7 damage. A rider is dragged out of the saddle (thrown, 3 damage). When your health would fall to 20 or lower you're beaten down, a third of your purse is taken and the bandits run off. Bandits never kill.
 - Bandits have 60 health. A bandit you kill drops its share of the stolen purse as coins plus a crude axe, flint knife or knife.
 - At most two ambushes run at once, and each ends after 5 minutes. Disconnecting ends one. If road wardens come, the bandits scatter. Bandits are Pedestrians bodies of kind 40 in starter skins, not actors.

## Church, houses, law, the realm and groups

The monastery church and the daily mass
 - One church is built, the monastery church west of Talmberg. It stands in the open world and works as a weather shelter, so rain doesn't fall on players standing in it.
 - Mass runs three times a day at 14:00, 19:00 and 22:00 on the server clock (Brussels time). Bell notices go to every player in chat 15, 5 and 1 minutes before. The town crier announces it 15 minutes ahead.
 - A mass is a fixed sequence of 13 parts. Asperges, Kyrie, Gloria, the lesson, the homily, the banns (skipped when nobody has banns waiting), the Creed, Sanctus, the elevation, Pater Noster, Agnus Dei, the final blessing and the dismissal. Gloria is left out in Advent, Septuagesima, Lent and Passiontide.
 - The text is real liturgy, 52 texts and 956 lines. The fixed parts are bilingual. The priest's Latin line goes to chat for everyone inside and the English line pops up as a notification. The lesson is a scripture reading picked by liturgical season (25 readings). The homily is a sermon picked by season (12 homilies). The same one never gets picked twice in a row.
 - The liturgical season comes from the in-game calendar. Advent, Christmas, Epiphany, Septuagesima, Lent, Passiontide, Easter, Pentecost and after Pentecost, plus feast days on 25 December, 28 and 29 September and 1 and 2 November.
 - Father Anselm, an invulnerable actor, says the mass when no player does. Between masses he stays at the altar and changes what he does by the hour (praying, reading the missal, tending the candles). There's a label above him that shows it.
 - A player priest, prior or abbot (men only) can lead the mass instead. Stand within 2.5 m of the pulpit when the bell hour strikes, or open Anselm's menu at the altar and choose "Say mass now" (refused when the next mass is under 180 seconds away). The leader is put in vestments for the length of the mass, speaks the lines through /me and /say, and the town crier announces it. If the leader walks off or logs out, Anselm steps in and carries on.
 - Lines come 6 seconds apart. At the elevation a bell rings and everyone inside is told to kneel with Y. You get 20 seconds to kneel.
 - A blessing is given at the dismissal, but only to people who were inside the church at the end of the Kyrie and knelt at the elevation. Anyone else who stays is told what they missed.
 - Staff: /service (Trial admin) shows when the next mass is. "/service start" begins one now and "/service stop" ends it.

Blessings and age
 - A blessing lasts 2 hours of play (scaled by character traits) and only counts down while the character plays. It shows as a "Blessed" buff, wounds heal faster while it lasts, and it's saved every minute.
 - If you keep the blessing to its end, your character's age is held back. A mass led by a player priest holds back 3 days, a mass said by Anselm 2 days. Dying while blessed breaks it, and a broken blessing pays nothing at the end. A new blessing resets the timer. The payout can happen once per real day.
 - Total age held back by faith is capped at 3456 minutes (2.4 life days) per real day. That cap is shared between blessings and the kneeler prayer. The ageing and death rules themselves belong to the lineage system.

The kneelers and the paternoster beads
 - Two kneelers stand in the nave. Stand within 1.4 m and press Y to kneel and pray the beads. It's refused during a mass, in a fight, on a horse, at work or while downed.
 - The prayer is 12 beads. Bead 1 is the Pater Noster, beads 2 to 11 the Ave Maria and bead 12 the Gloria Patri. Each line takes 4 seconds, in Latin with the English as a notification. After "Amen" press Y to move to the next bead or N to stand up. Walking more than 1.5 m away, being hit, struck down, killed or leaving the game ends it.
 - Finishing all twelve beads holds back 1 day of age, for the first round each real day only. Later rounds say so and give nothing.

The clergy
 - Eight ranks. None, novice, lay brother or sister, brother or sister, deacon, priest, prior or prioress, abbot or abbess. Deacons and priests must be men. Titles follow sex (Father, Deacon, Prior or Prioress, Abbot or Mother, Brother or Sister).
 - The Church tab in the character panel shows the roster (14 rows, highest rank first). A prior or above can admit a nearby unchurched player as a novice (the player gets a panel and can decline). They can also set a lower member's place to novice, lay or brother, send a lower member away after a confirmation, or leave the Church themselves.
 - Holy orders (deacon, priest, prior, abbot) are only given by staff with /ordain. Novices, ordinations and new heads are announced by the town crier.
 - A priest, prior or abbot can say mass and marry. A deacon or above can baptise. A brother or above can examine the sick and give remedies. Only lay brothers and sisters cut, burn and stitch.
 - Staff: /ordain <player> <none|novice|lay|brother|sister|deacon|priest|prior|prioress|abbot|abbess> (Admin) sets any rank, holy orders included.

Baptism
 - A parent with an unbaptised child (a child in the family record who isn't grown) presses Y at the font while no mass or rite is running. With several children a panel asks which one. It's refused when a mass is under 180 seconds away.
 - The rite is a scripted exchange (Abrenuntio, Credo, Volo) and the parent answers for the child with Y. The priest is a nearby deacon or above, otherwise Father Anselm. The parent is placed in front of the font.
 - A baptised child is marked in the family record. If that child later carries the family on as heir, it gives one extra death on the life clock. The crier announces each baptism.

Banns and weddings
 - Open Father Anselm's menu at the altar and choose "Marriage and banns". Pick "Ask for banns", type the spouse's given name and choose their age from 18, 20, 22, 25, 30, 35 or 40. The spouse is an NPC from a village family.
 - Banns are read at the next three masses (up to three couples are read per mass). The crier announces them when they're asked for. You can withdraw them from the same menu.
 - After the third reading go back to the altar and pick "Be wed". The ceremony is about 25 lines and you speak the vows and the ring words by pressing Y. A player priest officiates when one stands close, otherwise Anselm. The spouse appears as an actor with a starter skin and is added to your family record, and the crier announces the wedding. A character can marry once. Weddings and baptisms are refused when a mass is under 180 seconds away.

The infirmary
 - An infirmary hall with 3 beds stands beside the church. Press Y by a free bed to lie down. In a bed wounds heal twice as fast, and 10 minutes of rest in a real day eases illness at the turn of the day. N gets you up. Walking off, being struck down, hit, killed or leaving the game gets you up too.
 - Brothers, sisters, deacons, priests, priors and abbots can press Y by a patient within 2 m to tend them. They can examine (this names every illness so it shows in the Health tab) and give a remedy (a poultice, salve, tincture or rare remedy from their bag, one per illness per day, quality follows the item's stars). A priest, prior or abbot can give the last rites.
 - Lay brothers and sisters do the cutting. Stitch a wound (needs a needle and a spool of thread, then it heals in half the time), set a bone (needs a splint, heals straight and in half the time) and lance a festering wound (needs a lancet and water or strong drink). A new lay brother is given a needle and a lancet.
 - Last rites go to a character who is close to death from an illness or is marked on the life clock. A sick player in a bed can ask for a priest with Y. The rite is scripted in Latin and English and the patient answers by pressing Y. Afterwards the character would die absolved, and the prayer eases the illness for that day.
 - Two NPC brothers work the infirmary when no player healer is online. Brother Hugh does first aid and Brother Osmund, the lay brother, does the cutting. Use their menu "Ask to be treated". You pay first, in pfennig. Look over 3, bind a bleeding wound 3, wash a wound 2, splint a bone 4, herb draught 6. The lay brother lances for 6, stitches for 6 and sets a bone for 8. The brother walks to your bed and treats each wound in turn as /me and speech. If you leave the bed early, the steps he didn't give are paid back.
 - Brother Hugh also gives slow free care to anyone lying in a bed while no healer is online. He first comes after 10 seconds, then every 60 seconds. He binds a bleeding wound, splints a bone, names illnesses or gives a plain herb draught of the lowest quality. He doesn't stitch, set or lance.
 - Church props are custom models (ids -3901 to -3910). The font, a pail, two kneelers, the open missal and the aspergillum stand in the church and the infirmary bed fills the hall.

Houses and rooms
 - 41 hand-built houses (village homes, farms, craft houses, the mountain inn). Each has its own interior in a hidden world. Together they hold 108 rooms, 111 beds, 197 seats, 63 chests and 106 candle slots. Wood racks and piles stand in 46 places. Doors have a prompt to go in, a knock and a way out.
 - A house is open from 06:00 to 21:00 game time. Outside those hours only tenants of a room in that house can walk in. Others can knock with Y, and a tenant inside can unbar the door for a minute. Leaving at night leaves the door unbarred for a minute behind you.
 - The hearth is lit between 05:00 and 22:00 game time. At night a house is dark unless a candle burns. Press Y at a candle slot to light one (wax candles are used first). You need a flame, which can be the hearth, flint or someone's light.
 - A house gutted by fire is shut and everyone inside is put out until it's rebuilt.

Renting a room
 - 11 rooms (lofts and guest chambers) are to let, and four of them have a rentable bed placed for the tenant. You can hold only one room. Go to the county register in the reeve's clerk's house in Talmberg, press Y and pick a room.
 - Rent is 60 pfennig plus 15 per wealth level of the house (60 to 120 pfennig) for one season. A season is 90 game days, about 18.75 real days. Paying another season adds to the time you already have. Rent paid is added to the village's county dues (see the realm).
 - A room has a chest, a bed and a door that opens for you at night. You can share it with exactly one other character who must stand next to you. They can use the chest and come and go at night.
 - A room goes back to the county when its paid time runs out or when its holder hasn't come back for 21 days. Everything in the chest and every piece of furniture goes to the holder's Claims in the bag. You can also give the room up from the room menu.
 - Staff: /house list, rooms, info <key>, go <key>, enter <key>, fire <key> on|off|auto, grant <room no.>, vacate <room no.>, kit (Trial admin).

Furnishing a room
 - The room menu (Y at the chest or bed inside) offers open your chest, lie on the bed, furnish, take up a piece, share, pay another season and give up the room.
 - Furniture is a chair, table, bed, chest, barrel, tub or storage jar, carried as items. "Furnish the room" starts a drag-arrows editor where you move the piece and save it, and it has to stand in the free area of your room. A room holds 12 pieces and the county 512. "Take up" lifts the nearest piece back into your bag.
 - Furniture is saved per room and is returned to Claims if the room is lost.

Duke, count and steward
 - One duchy and one county (Talmberg). The offices are duke, count and regent and only staff fill them. There's no election. If the count seat is empty or the count hasn't logged in for 7 days, the duke rules the county through the steward.
 - Ondrej Spravce, the steward, sits in the ducal seat (a fortress). His menu is the main interface. Everyone can read the decrees and the county's policy. The count (or the duke while the seat is vacant) can set policy, read the books and swear in or dismiss guards. The duke can set the bounds, issue decrees and raise the levy.
 - The county and the duchy each have a treasury. Both are real containers holding coin and grain.

County policies
 - 20 policy numbers, each with a default, a hard minimum and maximum and a step. Sales tax 10 percent, strip rent 72 pfennig, tithe 10 percent, petition fees (craftsman 12, higher rungs 60), market stall 24 a day, mill multure 62 per thousand, hunting, wood and mine licence 120 a season, land tax 240 a year, wolf bounty 6 a pelt, night curfew, light law, fine scale 100 percent (50 to 300), pillory length 15 minutes (5 to 60), weapons in town, sumptuary law, road toll 1 pfennig (0 to 12), banishment, protected species and closed hunting seasons.
 - The count moves a policy with Less, More and Proclaim. The value is clamped to the duke's bounds, written to a log and posted on the county's notice boards. The duke can narrow the bounds for every county.
 - The policies other systems read today are fine scale (every fine and bounty), pillory length (arrests), road toll, the light law, the hunting licence, wolf bounty, protected species, closed hunting seasons and the craftsman petition fee. I never wired up the rest. They're stored and shown, but nothing reads them yet.

Decrees, dues, levy and toll
 - The duke can issue five kinds of decree, a feast day, a closed season, a bounty, a ban or a call to arms, for 1, 3 or 7 days with free text. Each is posted on the boards and cried. Only the feast day does anything in code (it changes what the orders do and the dawn announcement). The others are just announcements.
 - Rents and tolls pile up as dues for each of three villages (Talmberg, the church village, the guardhouse hamlet). A sworn guard on duty stands at a village's collection point, presses Y and spends 5 seconds counting the dues. The coin goes into the guard's purse and is recorded as carried, so it can be robbed. It's delivered from the steward's menu.
 - Once per season the duke may raise a levy. Up to 20 percent of the county's coin and 10 percent of its grain moves to the duchy treasury and it's posted.
 - A toll bar guards the hollow way, the forest road south of Talmberg. Press Y beside the keeper to pay. The bar lifts and you have 60 seconds to pass. Guards and rulers pass free. Crossing the line unpaid on foot or horseback is toll evasion. The keeper shouts and any witnesses report it to the law. Coach fares include the toll, and the coachman or the hirer pays it at the bar.
 - When the light law is on, anyone in town at night without a light commits "going dark" once per night if seen.
 - Staff: /realm duke|count|regent <player> (0 clears), /realm policy <key> <value>, /realm dues <village 0-2> <coin>, /realm info (Manager).

Crimes, witnesses and the wanted roll
 - 13 crime kinds, each with a base fine, a wanted time and a default sentence. Murder (1200 pfennig, 7 days, gaol 120 minutes), assault (120, 3 days, pillory 20), theft (60, 3, stocks 20), poaching (48, 3, fine), poisoning (960, 7, gaol 90), breaking a decree (24), trespass (24), freeing a prisoner (240, gaol 30), bribery (120, stocks 15), escape (240, 7, gaol 60), arson (480, 7, gaol 90), going dark (12, no wanted time) and toll evasion (12, 3 days).
 - The code raises these today. Assault and murder (against players and NPC villagers), theft (carts, stealing a horse, hunting traps), poaching, arson, freeing a prisoner (pillory and carts), toll evasion, going dark and the gaol escape. Poisoning, trespass, bribery and breaking a decree exist as definitions, but I never wired them up. Nothing raises them yet.
 - A crime only counts if someone saw it. Witnesses are other players or NPC villagers with line of sight, up to 30 m by day and 12 m at night unless a light is lit nearby. Each witness gets a notification of who they saw. The same crime against the same victim within 5 minutes isn't logged twice.
 - A witnessed crime puts the offender on the roll of the wanted. The bounty is twice the fine (capped at 4800 pfennig) and grows with each crime, and the wanted time is 3 or 7 days. The roll is read at the gaol register.
 - Fines follow the county's fine scale of 50 to 300 percent.
 - Staff: /law appoint|duty|crime|wanted|clear|sentence|release|bind|untie|kit|pillory|stocks|removedevice|gaol|status (Trial admin). Crime and sentence forms take a name, for example "/law sentence <player> gaol <minutes>" with fine, pillory, stocks, gaol, flogging, branding, banishment or execution.

Guards, binding and arrest
 - The count (or the duke) swears in guards at the steward, ranked watchman, guard and sergeant. Go on duty at the gaol register by the guardhouse and take the county's arms. A watchman gets a club and two torches, a guard a spear and shield, a sergeant a sword and shield. The arms go back to the armoury when you go off duty or leave your post.
 - Anyone within 1.8 m of a downed or bound player who is a guard, or carries a rope, sees "Press Y to deal with them". A guard shackles. Anyone else uses up a rope to bind a downed person. A bound player has cuffed hands and a "hands bound" cue on their nametag. A character who is bound with nobody else around works the rope loose after a while.
 - A guard can arrest a bound or downed player and picks the gaol, the pillory, the stocks or a fine. A sergeant may also flog. If the target was wanted, the county pays the guard the bounty.
 - A private citizen takes a bound wanted person to the gaol register and hands them over. They get the bounty and the watch passes sentence by the county's table. A bound person who isn't on the roll is let go.
 - The register also lets you read the roll of the wanted and pay your own fine to clear your name.

Sentences, pillory, stocks and gaol
 - Sentences are fine, pillory, stocks, gaol, flogging, branding, banishment and execution. A fine is paid to the county, and a fine you can't pay becomes time in the stocks instead. Flogging takes up to 30 health (never below 15) and adds a scar count. Branding adds a mark shown on the nametag. Banishment and execution can only be given with the staff command.
 - Time served only counts while the player plays, except in gaol where offline time counts at half. Sentences are saved and picked up again at the next login.
 - A pillory and a stocks stand in Talmberg's square. Both lock a prisoner in place for the sentence. If both are taken the prisoner goes to the gaol. Press Y at a prisoner to throw a rotten cabbage (needs one in the bag, 12 m range, 1 damage), jeer, give a sip of water from a water skin, or let the prisoner out (a crime unless you're a guard on duty).
 - The gaol is under the guardhouse with 3 cells in its own hidden world. Visitors can walk down. A guard on duty unlocks a cell door with Y and it locks again when he walks away. A prisoner gets hungry, thirsty and cold like anyone, so visitors can bring food.
 - A prisoner can work at the cell's grate for 20 seconds per try, which loosens it by 8 to 16 percent plus half their willpower. At 100 percent the prisoner escapes behind the guardhouse and is wanted for escape. If a guard is within range the try fails, the grate loses 25 percent of its progress and 15 minutes are added to the sentence. Anyone can wedge a loosened grate tight again.
 - Devices are placed and removed by staff (/law pillory, /law stocks, /law removedevice) and saved. The two in the square are seeded from the map.

Group kinds and founding
 - A group is a roll of members with ranks, a treasury and a storehouse (both real containers). Up to 48 groups. A character can be sworn to at most 3 groups and only one of each kind. Seven kinds. Craft guild, household, mercenary band, outlaw band, religious order, county guard and the church. The county guard and the church are system groups. Their ranks come straight from the law and clergy ranks and nobody is put on their roll.
 - Founding happens at the steward's desk (ducal fortress), at a hideout or at the church door. Staff can also create groups.
 - Guild. Three players of one trade, all at level 4 or more and willing, ask for a charter. The fee is one gulden (240 pfennig) paid to the county. The founder becomes Guildmaster and the other two Masters. There's one guild per trade in the county. A ruler can revoke a charter and it's posted.
 - Household. Founded by a lord of the realm (count or duke), free. Mercenary band. Anyone, for 120 pfennig. Religious order. A prior or abbot at the parish church door, free. Outlaw band. Press Y at one of two cold fire pits deep in the woods to make camp, free. The pit lights up and the band's stores are kept there.
 - Names are 4 to 24 letters, spaces, apostrophes or hyphens, and must be unused.
 - A new group can hold 8 members until staff review it, then 20 for guilds and 30 for the rest.
 - Staff: /group list, info <id>, settings <id>, review <id>, add <id> <player> [rank], remove <id> <player>, piece <masterpiece id> pass|fail, contract <id> fulfilled|released, pose x y z rx ry rz (Admin). Create <player> <kind 0-4> <name> and disband <id> need Manager (a group's stores must be empty to disband).

Group ranks, treasury, halls and duty
 - Each group has up to six ranks with editable names and a permission set (invite, expel, set ranks, treasury, storehouse, contracts, notice board, hall and armoury, judge masterpieces). The head can add ranks below, rename them and change what each may do. Each kind has default rank names (Guildmaster, Lord, Captain, Chief, Master of the order and so on).
 - The group panel (character panel, Groups) holds the roll, invitations (a member with invite rights swears in someone standing within 6 m, who must agree), handing over the headship, striking a member, a treasury pay-out in pfennig to a member standing beside you, and a word to all members.
 - Staff switch features on per group. Duty, uniform, armoury, hall, wake at the hall, notice board, charter rules and contracts. Each kind starts with a default set (guilds get charter rules, bands contracts, orders uniform, the guard and church a hall and board, outlaw bands a hall).
 - A hall is a spot the group names its own and it can't sit on another group's hall. Standing there gives a menu with the storehouse, the treasury, the board, duty and, if enabled, "wake here when you come back".
 - Duty issues the rank's kit (up to four lines per rank, chosen by the head) out of the storehouse and takes it back on going off duty. Missing kit is written in the group's book. Kit still out when a player logged off on duty goes back to the store at their next login.
 - Livery is a tabard worn on the body in one of eight heraldic colours (madder red, weld yellow, woad blue, green, black, white, purple, russet). Orders call it a habit. Others see it as a cue under the nametag.
 - Notice boards (posts up to 144 characters) show members every post and the public only what was posted public.
 - /g sends an out-of-character word to every online member of the group chosen in the group panel.
 - Outlaw hideouts keep workstations and similar spots cleared around the fire pit.

Guilds, marks, training and masterpieces
 - A guild has a trade, a minimum star rating (default 4) and a price window (floor 50 to 100 percent, ceiling 100 to 200 percent of the trader's price). Goods of the guild's trade at or above its stars are sold under the guild's mark and fetch 15 percent more from traders.
 - A master of the guild standing within 15 m of a lower-ranked member who has a lower level makes that member practise 25 percent faster. A master here is level 8 or above, or someone who has mastered the trade.
 - Level 10 in a trade needs a masterpiece, which is the trade's longest recipe and opens at level 9. Make it at 5 stars and present it in the Masterpieces panel. Two judging masters (members with the judge permission who have mastered the trade, or the head) must pass it, and the maker can't judge their own. Two refusals fail it and the piece goes back to its maker at once or at the next login. Passing sets the trade as mastered for the maker even if they're offline.
 - In a trade with no guild, the steward judges a masterpiece against a fixed bar.
 - Staff can pass or fail any masterpiece.

Group contracts
 - A mercenary band can write contracts. A band member with a client beside them writes the terms (at least 8 characters) and a pay from 2 pfennig to 200 gulden. The client sees the terms and signs, paying half into the band's treasury at once.
 - To settle, the client stands beside a band member and pays the rest. If they refuse, the contract is marked disputed for staff. A band can also release a client, paying the upfront half back out of the treasury. Staff can close a contract.

Tournaments, the lists and the herald
 - The lists lie west of Talmberg. They have a tilt, an archers' line with butts at 20, 35 and 50 m, a herald's platform, some old village fence pieces and a separate sword ring. Hans Herold, the herald, stands there. His menu has "The order of the day", "Sign up for a contest", "Place a bet", "Appoint a herald" and "Declare a tournament".
 - A count or duke declares a tournament from Hans's menu. They pick which of the six contests are held, when it starts (in 1, 2, 4 or 8 hours), a purse taken from the county treasury (none, 120, 240, 480 or 960 pfennig) and an entry fee (none, 6, 12 or 24 pfennig). It posts a feast decree, a notice and a crier call. Only one tournament can be open at a time and four events in total.
 - Contests run one after the other. Once the start time has passed, the next contest begins 30 seconds after the last one ends. Reminders go out an hour ahead and shortly before. Up to 16 can enter a contest. If fewer than 2 enter, the contest is called off and a lone entrant is awarded it.
 - The purse is split evenly between contests, and each share is paid 60, 30 and 10 percent to first, second and third (a missing third goes to first). The share of an unrun contest goes back to the host. Entry fees go to the host when the event ends. The champion of the joust or the sword bout receives a 5-star circlet and the archery champion a 5-star golden arrow.
 - Bets are placed before a contest begins, 1 to 960 pfennig, on any entrant. Winners share the pool in proportion to their stake, less 10 percent for the host. If nobody backed the winner the host keeps the pool. A called-off contest returns the stakes. The bookmaker holds 64 bets.
 - Ten NPC villagers come to watch from the stands and cheer on hits, and they walk home after the event.
 - The host can appoint a nearby player as herald (staff-run events use the ruler). On the stand, press Y for the herald's panel to call the next pair, call time, accept a requested yield, stop the bout or hand the stand back to Hans. After 2 minutes idle or when the herald leaves the stand, Hans takes over again.
 - Staff: /event list | tourney <minutes> <contest keys> | sign <contest> | time | stop | end <slot> | fair | harvest | bonfires | market open|close|auto (Admin).

Tournament contests
 - Joust. Two riders at a time, ridden on horses over courses 15 m long. Hold forward to gallop, Y lowers the lance (0.4 seconds to come down, steady for 0.8 seconds, then it sags) and H switches the aim between shield (1 point) and helm (2 points, needs a steady gallop). Three courses, with up to two extra if tied, and the most points wins. Losing your seat loses the bout. Press F twice within 3 seconds to forfeit. A player with ping above 105 ms can only trot and can't score helm hits. A lone entrant is offered a bout against a sparring knight with no prize.
 - Quintain practice. Bring a horse to the west gate, press Y and gallop at the spinning quintain. A bad run lets the sandbag knock you from the saddle.
 - Archery. Three arrows from the line within 45 seconds. Each shot scores by how close it passes a butt (10, 7, 4 or 1 for the ring), multiplied by 1, 2 or 3 for the farther butts, with a random wind offset that's bigger when a weather override is active.
 - Sword bout and wrestling. Two at a time in the ring, with blunted weapons so nobody is hurt. A weapon blow or punch or kick scores 3, a hook 2, a shove 1, a blow from behind doubles, and a blocked blow scores nothing. First to 20 points wins. The herald calls time after 120 seconds (sword) or 60 seconds (wrestling), and a draw is settled by a coin toss. Staying outside the ring for 3 seconds loses the bout. Press N twice within 3 seconds to yield. A weapon taken up in the wrestling puts you out.
 - Log toss. One go of 20 seconds. A power bar rises and falls and you press Y when it tops out. Distance depends on timing and willpower.
 - Drinking match. Up to 12 rounds, one every 20 seconds. Each round raises your drunk level and every contestant has a chance to pass out. The chance rises each round and willpower lowers it. The last one standing wins and leaving the lists puts you out.
 - Best produce. Part of the harvest festival. You hand in one food or material from your bag and the judges rank the entries by stars, then by worth.

Fair, harvest festival and bonfires
 - A fair comes to Talmberg's square once per season at dawn and lasts 300 real minutes (one game day). Giacomo of Venice sells spice (18 pfennig), plant dye (10), dyed cloth (40) and salt (6), and buys food and materials at 120 percent of the usual trader price. Six visitors walk the square. The market stalls open with the fair (staff can override with "market open|close|auto").
 - A harvest festival is declared at dawn on the first of the tenth month. It runs the best-produce contest two hours later with a 120-pfennig purse from the county treasury (no purse if the treasury is short).
 - Bonfires are lit on the three village squares at dusk on 24 June (midsummer) and 21 December (midwinter).
 - A feast decree from the duke makes the day a feast day with an announcement at dawn.

Dice
 - Press the Games button in your bag (you need a set of dice) and pick who to play from the people next to you. Each puts the stake in the pot and the server holds it until the game ends. The winner takes all.
 - The game is a six-dice scoring game. Roll all six, click the dice that score to keep them, then bank the points or roll the rest. A roll with nothing that scores busts the whole turn. Keep all six and you roll all six again. A single 1 is worth 100 and a single 5 is 50. Three of a kind is the face times 100 (three 1s are 1000) and every extra die doubles it. Runs score 500 (1 to 5), 750 (2 to 6) and 1500 (1 to 6). The target is 1500, 3000 or 5000 points.
 - A turn lasts 30 seconds. If you do nothing the game rolls or banks your best dice for you.
 - Special dice in your bag play in place of plain ones, up to six, and everyone at the table sees which you use. A weighted die forces a 1 on 34 percent of rolls, a heavy die does the same with a 5, a devil's die counts a 6 as a 1 and a lucky die saves you from one bust per game by rolling again.
 - Staff: /dice give <plain|weighted|heavy|lucky|devil> [1-6] and /dice rig <six faces> (Trial admin) rigs the next roll at your table.

Lansquenet (cards)
 - Press Games with a deck of cards in the bag. The deck has 40 cards (suits Acorns, Bells, Hearts and Leaves, ranks 1 to 7, Farmer, King and Queen). Everyone puts in the stake and gets one card face up.
 - Each round you stay, raise by the stake (nobody puts in more than 100 pfennig in all), meet a raise or fold. Then three cards go to the discard pile and one is turned in the middle. Anyone whose card has the same value as the middle card wins the pot, and two matches share it. If the deck runs out the highest card wins (Queen, King, Farmer, then 7 down to 1, and on equal ranks Leaves beat Hearts, Hearts beat Bells and Bells beat Acorns).
 - A turn lasts 30 seconds. If you do nothing the game stays for you, or folds if you owe.
 - Staff: /cards give (Trial admin).

Game tables and the tavern regulars
 - Games aren't tied to a spot. A cloth is laid on the ground where the host stands. There are up to 4 seats per table and 24 tables at once. Stakes are 5, 10, 20, 50 or 100 pfennig.
 - You challenge people within 4 m. They have 30 seconds to answer, and someone who turns you down three times can't be asked by you again for 10 minutes. Walking more than 15 m away, going down or logging off forfeits your stake. The host can call a game off before it starts and everyone gets their stake back. After a restart, stakes from unfinished games are refunded.
 - Games and their results are saved (who played, stake, pot, winner and how each seat left).
 - Tavern regulars are NPC players who sit at tables. Stand next to one and press Y, then pick dice or Lansquenet. They bring their own dice and cards and bet from a daily purse. Careful regulars have 150 pfennig, even ones 200 and bold ones 300, and they play to a fixed style (when they bank, meet or raise). A regular whose purse is spent is done for the day. Once you have won 200 pfennig from the regulars in a day, they won't play you again until the next day.
 - Staff: /regular place <careful|even|bold> <name>, /regular remove, /regular list (Trial admin). Up to 32 regulars, saved with their seat.

## Combat, staff tools and the interface

Melee combat
 - Combat mode is on Y. Press it to draw your weapon, or raise your fists if your hands are empty. Press again to put it away. It refuses while you're struck down, riding, or while an interior is still loading. It switches itself off when you mount, get teleported or get struck down.
 - In combat mode your character always faces where the camera points. The stance animation depends on the weapon class. Sword stance for the hand-and-a-half and bastard swords, knife stance for short swords, daggers and spears, bat stance for blunt weapons, axes and great axes, and a gun-ready stance for bows, crossbows and slings.
 - Hold a direction and press left click to pick the swing. Forward is an overhead blow (25 stamina), back is a low blow (15 stamina), left and right are side cuts (20 stamina each). Each swing plays the matching animation and resolves 500 ms later. If you're out of stamina you get a hint and nothing happens.
 - A swing hits the nearest living character inside 1.5 m (every weapon has the same reach) who stands within a 27.5 degree cone in front of you and in the same virtual world. Players who are away from keyboard and players who are mid-dodge can't be hit.
 - Hit someone from behind and the damage doubles. That means within 10 degrees of their facing, with you facing them. NPCs count too.
 - Damage is the weapon's damage value times your wound penalty (a hurt sword arm hits softer) times the damage dealt and damage taken trait effects of both fighters. A player at full health can't be killed by a single melee hit. Damage is capped so the target is left at 1 health and struck down instead (see Struck down).
 - Hits on a character who is already struck down do nothing, unless you hold a real weapon. Then they become an execution (see Struck down).
 - Hits reach NPCs too. Townsfolk and animals answer a seek callback, so the nearest NPC in the arc takes the blow, with the same behind-the-back bonus. Every hit, felling and execution is announced to other systems. The law record, traits and the tournament code listen.
 - Players in a tournament bout are handled apart from normal fights. Blows resolve as tournament hits for the events module, damage is halved, and nobody can be struck down for real or finished off.
 - Putting a weapon on or taking it off drops you out of combat mode first, so you always start a fight from a clean stance.
 - Staff: /equip and /equipshield (management level, they're dev commands) put any weapon or shield on you by index. The usage line says 0 to 49 for weapons, but there are 51 weapons, so the sling is index 50.

Fists
 - With nothing in your hands, Y raises your fists. Left click alone is a shove (8 stamina, 0.5 damage, pushes the target back). Forward and left click is a punch (15 stamina, 3.0 damage). Left or right and left click is a hook (12 stamina, 2.5 damage). Back and left click is a kick (18 stamina, 3.5 damage). A fist blow resolves after 300 ms and reaches 1.3 m.
 - Fists never kill. A blow can't take the target below 10 health. The blow that would do it knocks them out instead. They're struck down for 30 seconds and wake at 15 health, or sooner if someone presses F next to them.
 - A kick, or any blow on a target with less than 15 stamina, knocks them to the ground for 4 seconds. A struck character who isn't in combat mode flinches with a hit animation that matches the side the blow came from.
 - The game's own fist-fighting animations are cleared for anyone who isn't in combat mode, so only this system throws punches.

Blocking, shields and dodging
 - Hold right click to block. It costs 15 stamina and the animation takes 350 ms before you can block again. A block only works against attackers inside a cone in front of you. That's 60 degrees bare handed, 80 degrees with a raised shield and 90 degrees in a shield wall. An attacker outside the cone hits you normally.
 - A good block plays a clang sound for both fighters (a shield sound if your shield is up), knocks the attacker back, costs them 20 stamina and deals them 2 to 4 damage. A defender without a raised shield also gets pushed back, loses 15 stamina and takes 1 to 2 damage. A defender behind a raised shield loses only 5 stamina and the shield takes the damage instead.
 - Shields have 100 resistance. Each blocked blow wears it down by the damage dealt (trait-adjusted). At zero the shield breaks, gets removed from the hand and the attacker is told "You broke their shield". A raised shield facing the shooter within 80 degrees also blocks arrows, bolts and stones, and they wear it down the same way.
 - F raises or lowers an equipped shield. Lowered, it sits on your back. Raised, it's on your left arm. H while the shield is up drops you into a shield wall. That's a crouched stance with the widest block cone, and it locks out attacking until you press H again. Press H without a raised shield and it tells you to press F first.
 - A broken left arm can't hold a block ("Your broken arm won't hold a block"). The wounds system also feeds a strike multiplier into this module, so a wounded right arm hits softer.
 - Dodging is Sprint (Space) held with a direction and nothing else. Back plus Sprint is a back step (15 stamina, a 500 ms window where you can't be hit, 500 ms cooldown). Left or right plus Sprint is a roll (35 stamina, you need more than 65 stamina to start it, 800 ms cooldown). You can't do the sideways roll while carrying a shield, unless you're using a great axe.
 - Parry strength and the length of the struck-down timer both scale with traits.

Struck down, knockouts and executions
 - A character whose health drops below 15 (and above 0) is struck down. They're frozen in a slumped animation, their name turns red, and they get 30 seconds (adjusted by traits) before they bleed out and die. Anything that lowers health that far does this, not only melee. Ailments can trigger it too.
 - Struck-down characters can be helped up. Anyone within 2 m who isn't in combat mode presses F and the fallen player is back on their feet with 30 to 40 percent health. Staff can do the same with /revive.
 - A fighter who holds a real weapon, is in combat mode and stands within 2 m of a struck-down character can finish them with a blow, after a 1.5 second grace period. The victim's health is set to zero as "executed", the attacker sees "You finished them", and the law and trait systems are told. Fists can't execute. Tournament fighters can't be executed.
 - A knockout (from fists or in a tournament) is a struck-down state that always ends in waking up. The player is told how many seconds are left, and wakes at 15 health with "You wake up, aching all over". A normal struck-down state that times out kills the character ("bled out").
 - Struck-down players can't enter combat mode, get dismounted if they're on a horse, and any half-finished ranged reload is interrupted.
 - Knockdown is a lighter state. It's a 4 second fall caused by kicks and exhaustion, with a get-up animation.

Weapons and shields
 - The weapon table holds 51 weapons. Each has a model, a type, a damage value and a reach. The types are long sword (the two bastard swords, 12.5), short sword (eight blades, 4.5 to 7.5), blunt (seven, 7.0 to 10.0), dagger (five knives, 3.0 to 4.5), axe (four one-handed axes and picks, 6.5 to 7.5), great axe (nine two-handed axes, 11.5 to 14.0) and spear (thirteen polearms, staves and forks, 3.0 to 7.5). On top of those there's the Rus Bow, the crossbow and the sling.
 - The full list is Hatchet, Iron Hammer, Rusty Pick, Steel Pick, Morningstar, Pear, Polehammer, Sledgehammer, Spiked Club, Spiked Mace, Winged Mace, Bardiche, Greatax, Battle Axe, Fighting Axe, Double Headed, Iron Axe, Pole Axe, Voulge, War Axe, Cleaver, Club, Dagger, Khyber Knife, Peasant Knife, Hand-and-a-Half Sword, Bastard Sword, Long Sword, Broadsword, Falchion, Longsword, Scimitar, Shashqa, Sickle, Viking Sword, Spear, Double Spear, Fork, Military Fork, Glaive, Heavy Lance, Wooden Staff, Iron Staff, Joust of Peace, Pike, Pitchfork, Scythe, Trident, Rus Bow, Crossbow, Sling.
 - Ten of them can be thrown (see Bows and thrown weapons). They are Hatchet, Iron Hammer, Rusty Pick, Steel Pick, Cleaver, Club, Dagger, Khyber Knife, Peasant Knife and Spear.
 - There are 24 shields in four shapes with six variants each. Round, small round, heater and square. The equipped weapon and shield are saved on the character (two columns on the characters table) and come back on login.
 - A sheathed weapon is drawn on the body. Long swords sit across the back. Short swords and daggers sit on the right thigh. A bow goes on the back with its quiver, a crossbow on the right thigh with a bolt quiver, and a sling on the left thigh with a stone pouch. When you draw the weapon the scabbard shows empty. There are eighteen scabbard and quiver models for the sword, dagger and bow families. Other weapons are drawn straight onto the thigh or back.
 - Weapons and shields go on and come off through the bag (the inventory module calls the equip functions). The combat code keeps the visuals, the saved hands and the stance in step.
 - Models for every weapon, scabbard, shield, bolt, stone and arrow are registered at boot with their textures.

Bows and thrown weapons
 - The Rus Bow shoots arrows. Y to draw, left click to loose. Each arrow comes out of the bag (one arrow per shot), costs 10 stamina, and you wait 2 seconds between shots. Hold right click to raise the aim. C toggles a crouched shooting stance while you're idle.
 - Arrows fly 45 m at 20 m/s along the camera's forward vector, so the shot goes where the crosshair points. A small cross is drawn in the middle of the screen while a ranged weapon is out. The flight is a moving object the player can watch, but the hit is decided the moment you release. The closest character within 0.7 m of the flight line (and 1.2 m of height) in the same world takes it. A collision ray cuts the flight short at walls and terrain.
 - A hit lands on a random body part for 25, 15, 15, 10 or 10 damage, times the weapon's ranged scale. That scale is its damage value divided by 5, so the bow is 1.0, the crossbow 1.6 and the sling 0.5. The target is struck down rather than killed outright, and any hit on someone who is mid-reload spoils the reload.
 - An arrow that misses, hits scenery or hits an NPC lands as a pickup on the ground and can be collected again. An arrow that hits a player is spent.
 - Throwing works like this. With a throwable weapon drawn, the Jump key throws it (20 stamina, 2 second cooldown). The weapon leaves the bag and your hand, flies up to 45 m, does its full melee damage on a hit and lands as a dropped item (at the victim's feet if it hit a player).
 - NPC actors in the line of flight take hits too, resolved through the same seek the melee code uses. Tournament fighters can't be hurt by projectiles.
 - At most 128 projectiles can be in flight at once.
 - There are help topics for the crossbow and the sling. The bow has no help topic.

Crossbows and slings
 - The crossbow has three stages. It starts slack. Left click cranks it, which takes 4 seconds and 15 stamina, and if you get hit during that time you lose your grip. Left click again lays a bolt on it (0.8 seconds, a bolt from the bag), then left click shoots. Each shot costs 4 stamina and spends one bolt. A bolt flies 60 m at 32 m/s, flatter and harder than an arrow. Bolts that miss stick in the ground where they land (set back 0.4 m and laid on the ground surface) and can be picked up.
 - The sling takes a stone from the bag when you left click (under a second), and the next left click swings and shoots. A stone costs 6 stamina, flies 32 m at 26 m/s and does half the damage of an arrow. Stones that miss lie where they land. The help text sends players to rock outcrops to gather stones.
 - The held model changes with each stage (slack, spanned and loaded for the crossbow, empty and loaded for the sling). The crank shows in the off hand while you wind it.
 - Run out of bolts and the crossbow stays spanned. Run out of stones and it tells you to gather some. Being knocked down, struck down or hit interrupts a half-finished reload with a short message.

Staff levels and roles
 - There are five staff levels stored on the account. They are player, assistant, moderator, admin and management. Commands are locked to a level. Anyone below it gets the normal unknown-command reply, so players can't find staff commands. The moderator level exists in the code but I never bound a command to it.
 - Two extra roles are stored in a staff_roles table, separate from the level. Loremaster can post crier notices. Faction team can seat the realm's offices. Management counts as faction team automatically.
 - Staff: /setstaff (management) takes a player and one of none, assistant, moderator, admin, management, loremaster or faction. The first five set the level. Loremaster and faction toggle that role.
 - Staff: /a is staff chat, shown to everyone at assistant level and above.
 - Staff: /duty toggles a duty flag. It shows in the staff panel list but changes nothing else in gameplay yet.
 - The two-person rule covers certain actions, like a ban over a week or a permanent one, and /seat. They first ask a second member of staff at the same level or higher to agree or refuse in a small panel. If nobody else is online the action goes through and gets logged as unchecked.
 - Every staff action is written to a staff_actions table with the staff account, action, target and detail.

Staff panel
 - Staff: /staff opens the panel for assistants and above. It lists the staff online (up to 12) with their level and duty state, shows the number of open reports, and has the entries Reports, A player... and a duty toggle.
 - "A player..." asks for a player id and opens an action menu. Inspect, Watch, Go to them and Warn, plus Bring them here, Freeze or Unfreeze, OOC jail or let out, Kick and Ban for admin and above. Each action asks for what it needs (reason, minutes, hours) through short text prompts.
 - Staff: /goto (assistant) puts you 1.5 m in front of a player in their world and interior. Staff command /gethere (admin) brings them to you.

Reports and tickets
 - Players ask for help from /help by choosing "Ask the staff, or report a problem". They write what's wrong (4 to 144 characters, out of character) and can give the id of a player the report is about. A player can have one open report at a time.
 - New reports are broadcast to all staff online as "[Report n] name: text" and stored in a tickets table with the states open, claimed and closed.
 - Staff: /reports lists the oldest ten unresolved reports, with a marker if the reporter is away. Opening a report offers Claim it, Answer the player (an out of character message to them), Go to the player and Close it. The reporter hears when their report is closed.

Inspect
 - Staff: /inspect <player> (assistant) shows a character sheet in a panel. It has account, character, staff level and age, health, hunger, thirst, warmth, fatigue and dirt, ailments, purse value and bag size with the first six items, the three best trades with levels, church title and lodging, wanted and guard status, groups, warning count with any OOC jail time left and a frozen marker, and exact position with world and interior. Every look is logged.

Warnings, kicks and bans
 - Staff: /warn <player> <reason> (assistant) puts a warning on the account's record and tells the player. Staff command /warnings <player> lists the latest ten with who gave them and how long ago.
 - Staff: /kick <player> <reason> (admin) tells the player and everyone on staff, then removes the player after 300 ms so the message arrives.
 - Staff: /ban <player> <hours> <reason> (admin). Zero hours is permanent. It bans the account and its address. A ban over 168 hours (one week), or a permanent one, needs a second member of staff to agree. Bans are checked on connect (by address) and again when the account logs in, with the reason and the hours left shown before the kick.
 - Staff: /unban <account name> (admin) lifts every ban on that account. Address-only bans from the roleplay quiz are lifted by the quiz reset command in the account module.
 - Players who fail the roleplay quiz too many times in the allowed window get a permanent address ban written here, and staff are told.
 - Warnings, bans and the staff log live in the warnings, bans and staff_actions tables.

OOC jail and freeze
 - Staff: /jail <player> <minutes> <reason> (admin) sends a player to a shut gaol cell in a virtual world of their own (9990 plus their player id). The sentence is stored, so it survives relogging. The server checks every 5 seconds and puts a wandering player back in, and the sentence ends by itself. Staff command /unjail lets them out.
 - Staff: /freeze and /unfreeze (admin) hold a player still and release them. Freezing isn't saved across a relog.

Staff repair and teleport tools
 - Staff: /heal [player] (admin) restores health to full, clears wounds and bleeding, revives a struck-down player, sets hunger and thirst to 80 and resets warmth. It also brings a freshly dead character back if their life clock hasn't run out. It defaults to yourself.
 - Staff: /revive [player] (admin) helps a struck-down player to their feet.
 - Staff: /unstick [player] (assistant) clears everything that can trap a character. Open panels and dialogs, work actions, horse scenes, emotes, prayer, sitting, riding, combat mode and freezing. Then it casts a ray to find the ground (searching up to 32 m away in rings of 2 m) and places the player 1 m above it.
 - Staff: /tp <x> <y> <z> [interior] [world] (assistant) teleports you. Leave interior or world out and you keep your current one. Coordinates are limited to plus or minus 20000.
 - Staff: /spec <player> (assistant) watches a player, and /spec again (or on the same player) stops. It remembers where you stood and returns you there, follows the target across interiors and worlds, and stops by itself with a message if the target leaves.
 - Staff: /logs (admin) shows the latest 14 entries of the staff log in a panel, with minutes ago, who and what.
 - Staff: /giveitem <player> <amount> <stars> <item name> (management) hands out an item or weapon by name (exact match first, then partial match, amount 1 to 100, stars 1 to 5). It tells you if the bag is full. Staff command /givecoin <player> <pfennig> (management) gives coin.
 - Staff: /crier <title>|<text> (loremaster or admin) posts a notice on the Events tab for the town crier, valid for three days.
 - Staff: /seat <duke|count|regent> [player id] (faction team or management) seats or strips an office of the realm, after the two-person rule.
 - Staff: /fx <blood|cold|heat|off> [alpha] and /uidemo <login|panel|off> (assistant) are screen effect and UI kit test tools.

Maintenance and shutdown
 - Staff: /maintenance <minutes 1 to 60> [reason], or /maintenance cancel (management) starts a restart countdown. Players are told at 10, 5, 3, 2 and 1 minutes, then at 30 and 10 seconds, with a chat line and a subtitle each time. Everyone is saved at every notice and at the end.
 - When the clock runs out everyone is frozen and saved, and anyone still connected is kicked after 3 seconds. Once the player list is empty (at least 8 seconds in) and the database queue has drained, the server writes maintenance.done to its script files folder and stops itself. A deploy script can watch for that file.
 - While a countdown or stop is pending, new connections are refused with a message and kicked after half a second. A running countdown has to be cancelled before another can start.
 - You can start the same countdown from outside. A file called maintenance.request in the script files folder is read every second. It holds a number of minutes and an optional reason, or the word cancel. The reason is limited to 95 plain characters, and the file is deleted once read.
 - Staff: /shutdown <minutes> (management) starts the same countdown for up to 30 minutes, and 0 calls it off. Both commands are written to the staff log.

Performance meter
 - Staff: /fps (management, listed as a dev command) shows a small FPS, ping and packet loss readout at the top right. The engine doesn't report a frame rate, so the FPS figure is estimated. I seed the client's drunk level at 2000 and read how fast it falls each update. The readout refreshes every 2.5 seconds and hides while a kit screen is open.
 - Staff: /fpscheck [hour] (management, dev) tours six fixed spots on the map at a fixed hour (noon by default) in clear weather. The spots are the first lag spot, a hilltop, Talmberg market, the monastery door, the swamp edge and the church green. At each spot it waits 5 seconds, then turns you through eight headings, sampling for 12 seconds each. It logs and prints the median FPS and the slowest tenth. Run it again to stop.

UI kit
 - All panels, menus, buttons and bars are built from textdraws on the engine's 640 by 448 canvas. The art is packed into a model texture file (panel box, header, logo, item plates, star rings), and helpers convert 1920 by 1080 pixel art into textdraw units.
 - A screen is a flow. A function builds panels (text, clickable rows, buttons, level bars, pip rows, item tiles, hit areas) and awaits Kit_Present. That returns the value of the row or button clicked, or a back value when the player presses ESC. There is one screen per player, and opening a new one ends the older flow quietly. The cancel echoes the client sends back after the kit itself closes the cursor are filtered out for 700 ms.
 - There are three layers per player. The clickable screen, a notice layer that stays up beside it (the tutorial and the infobox), and the HUD layer. Each holds up to 160 elements. Panels can be anchored to the centre, top, bottom or bottom right.
 - Panel art is drawn at a fixed alpha of 125. Text, accent, muted, good, pending and bad colours are shared constants so every screen matches. The Medieval Roleplay logo (a fire variant exists) can be shown above the login box.
 - Highlights work like this. A row or button the tutorial wants clicked glows and its label bounces on every screen with that title (up to four at once). The notice layer drops in from above with a bounce.
 - World labels can be hidden while a screen is open, and other modules are told when the kit appears or goes.
 - All dialogs use one colour palette and one set of button words. Back where there is a parent, Close at a root, Leave only where closing ends the session, Okay, Select, Continue. A kit message box (text and one button) and a "Leave the realm" confirmation exist for flows that need them.
 - Staff: /uidemo shows the logo or a test panel so I can tune the art in game.

HUD
 - The HUD is five thin bars at the bottom right on a panel. Health, stamina, hunger, thirst and warmth. Warmth shows blue below 35 percent, amber in the middle and red above 65 percent. Other systems feed values into it, and a kit screen such as the bag can set it aside and bring it back.
 - Three buff bars sit beside the map for temporary effects from the buffs module. The bars and buffs can bounce for attention until switched off.
 - A line under the engine clock shows the calendar date and is set by the calendar module (it starts as "The Realm").
 - Three discs at the left edge, above the radar, show the moon phase, the hour of the day and the season. They're small sprites swapped by the calendar and the daily routine.
 - A horse panel beside the radar shows the mount's name, a status line and three bars (stamina, hunger, condition) while you ride.
 - I marked the main HUD in the code as temporary art until I make a proper interface. The horse panel is a stand-in until there's a minimap.

Infobox
 - A notice box at the top right shows prompts and hints. It's three rows tall by default, with an optional expiry. A hint is a prompt that belongs to a nearby thing (a door, a workstation, a person). Only one prompt owner is allowed at a time, so overlapping hints don't fight.
 - Pressing Y in range triggers the prompt owner. Systems register themselves as "targets" with a distance, a refresh and a clear callback. Up to four can exist and the nearest one wins. Targets refresh every 500 ms and on every Y press. A winning target above the menu priority also takes over the Y key, so combat mode doesn't start while you're meant to interact.

Subtitles, dialogs and notices
 - Gui_Notify is the one way to tell a player something during play. It shows a subtitle at the bottom centre on the faded header art, about 46 characters per line. It stays up for 4 seconds or one second per 20 characters plus 2, whichever is longer. Lines that arrive within 1.5 seconds of each other stack, up to four lines. Notices are never chat lines and never dialogs, because dialogs take the mouse away mid-fight.
 - Dialog flows carry an epoch. A flow that wakes up after the player left, or after a newer screen replaced it, stops instead of acting. An open dialog or kit screen claims the keys that would otherwise act in the world behind it.

Progress bars, fades and screen effects
 - Progress bars. Up to 8 per player, filling right, left, up or down, used by the HUD and by other modules.
 - Screen fades. A full-screen box that changes colour over a number of steps and a set time, used for the fade in at spawn.
 - Screen effects. Three full-screen textures, blood, cold and heat. Blood grows as health drops. Cold and heat grow as warmth leaves its comfortable range. Staff can override them with /fx to tune them.

Help
 - /help opens a kit browser of sections. Getting started, Survival, Work and crafting, Combat, Faith, Family and death and Roleplay (each shown only when it has topics), then Commands and "Ask the staff, or report a problem". Rows are paged 15 at a time. At the time of this release 148 help topics are registered across modules, each a question with an answer up to 640 characters.
 - The Commands entry groups every command the player may use into categories (staff commands only show under "Staff tools" for staff). Opening a command shows its description and a note on how to read its usage.
 - /help <word> and /searchcmd <word> search topic questions and answers plus command names and descriptions, and list the matches in the same kit window. If nothing is found you get a one-line hint back.
 - Each module describes its commands with a short text (157 descriptions in the code, about 300 command handlers) and an optional gate. A gate is a function that can hide a command from players who don't have the right job or role. The help list respects level and gate, so nobody sees what they can't use. The table holds up to 384 descriptions.
 - Each topic carries a flag meant for periodic chat hints. The flag is stored, but I never wired it up. Nothing in the gamemode reads it yet except the tests.

Command handling
 - Every command passes one check before running. The player must be logged in, the command must exist and be enabled, the player's staff level must meet the command's flag, and its gate must pass. A command with no level flag defaults to management only, so a forgotten flag never exposes a command to players. Every typed command also counts as activity for the away detection.
 - An unknown command gets a "Did you mean" answer with up to three suggestions. They're found by prefix match (from two letters) and an edit distance. That allows no edits for 1 or 2 letter words, one edit up to 4 letters and two edits beyond. /commands and /cmds point to /help.
 - Command_Usage prints a usage line and the command's description, so a bare command explains itself.

## Under the hood

Boot chain
 - The entry file is gamemodes/mrp.pwn, which includes bootstrap/entry.pwn. That file pulls in libraries, definitions, MySQL, the utilities, the migration runner, the boot loader and the engine natives. Then it pulls in every module header in a fixed order (world, gui, account, commands, character, player and so on), then the server event bridge, and in test builds the test harness.
 - OnGameModeInit turns off interior enter and exit markers, stunt bonuses and automatic engine and lights, then calls Boot_Run. The pp-hooks layer lets every module add its own OnGameModeInit and other callbacks without editing the entry file.
 - Boot_Run connects, runs the migrations (below) and then runs the registered boot loaders one at a time. A loader is a public function that reads its tables and then calls Boot_LoaderDone. At the time of this release 38 loaders are registered (drops, horses, calendar, seasons, houses, groups, actors, carts, roads and so on). A loader can name another one it has to wait for. Fire waits for notices and fishing waits for work nodes, for example. If a loader never finishes, the loop warns how many are stuck and finishes anyway.
 - Boot ends by calling OnServerFinishLoading, which logs the version (0.1.0) and the slot count. If the database isn't ready, every loader is skipped and the server still opens with a warning.
 - Slots. SERVER_PLAYER_SLOTS is 100 and SERVER_NPC_SLOTS is 50, so MAX_PLAYERS is 150. The server's max_players setting has to match it or the server dies at boot. MAX_VEHICLES is 500.
 - It builds with the open.mp compiler 3.10.11 through sampctl, with an enlarged data area because of the amount of text in the script.
 - Libraries pulled in are the open.mp stdlib, the Incognito streamer, MapFix, crashdetect, PawnPlus with its MySQL bridge, a_mysql, sscanf2, Pawn.RakNet, SmartCMD, samp-bcrypt, pawn-json, ColAndreas, FileManager, a map parser, and the paths and pedestrians components.

MySQL and migrations
 - The database connection is read from mysql.ini, and a failed connect prints a fatal line. After connecting, a short probe polls up to 40 times at 250 ms until the accounts and characters tables exist, so logins are only accepted once the schema is up. It gives up after 10 seconds and accepts logins anyway with a warning.
 - Modules describe their schema in an OnMigrationRun hook with Migration_Add(key, sql). At the time of this release there are 171 Migration_Add calls in 52 module files, a few of them in loops, and the runner can hold 256. They create 119 tables and change them with 36 ALTER statements, plus a handful of data statements. The runner, the log queue and the event bridge add schema_migrations, seeders, server_log, activity_events and server_events themselves.
 - Each migration has a unique key. The runner reads the applied keys from schema_migrations, then runs only the unseen ones, one statement at a time through a callback chain. A failed statement is logged, skipped and retried on the next boot instead of stopping the server. The boot prints how many were applied, already in place and failed.
 - A schema_migrations table from an older version-keyed scheme is renamed to schema_migrations_legacy and never dropped. Seeders follow the same idea for one-time data fills (a key in the seeders table remembers them). The seeder hook exists and runs after the migrations, but I never registered a seeder in any module yet.
 - Saving. Every player is saved every 2 minutes, on disconnect, on every maintenance notice and on shutdown, through one Database_OnPlayerSave callback that each module hooks.
 - Queries use PawnPlus async queries with await, and strings are escaped with the %e format.

Base publics, timers, keys and utilities
 - bootstrap/natives.pwn declares a base public for every engine callback the gamemode uses (connect, spawn, death, key change, dialog response, vehicle, NPC, streamer and pedestrian callbacks), so hooks always have something to chain onto. Dialog responses are forwarded to a Dialog_OnResponse public. OnQueryError and the PawnPlus error handler are plain publics in mysql.pwn that log the failed query.
 - bootstrap/utility/perplayer.pwn adds per-viewer natives built on RakNet. You can set a name, skin, animation, attached object, chat bubble or vehicle colour and position for one viewer only.
 - A slice timer runs four times a second and calls each player's once-a-second tick in rotation, so the work is spread across quarter seconds. Timer_Declare and Timer_Start macros declare public timers.
 - The key system has five priorities (ambient 0, world 10, action 20, menu 30, scene 40), so overlapping uses of Y, F, H, Sprint and the mouse buttons get sorted out in one place. A module registers a check function per key and priority, and the dispatcher asks whether a higher context is busy before acting. Up to 192 contexts and 8 two-key chords can be registered.
 - Interior teleports go through a safe teleport. It holds the player until the destination interior shell has streamed in, then releases them, with a fallback timer.
 - Attached objects are mirrored in a cache and restored after the engine drops them when a scoped weapon is aimed and released.
 - Smaller helpers are animation library preloading (a module registers libraries and they get touched on spawn), chat message splitting at 144 characters with continuation markers, a nearby-players iterator fed by stream events, wrappers that batch streamer updates for objects and labels near players, a bitset helper, player state and movement name tables, a skin gender table, the command and help registries described above, and a PawnPlus string map helper.
 - Math and text helpers cover distance, angle normalising, facing, cooldown timestamps, weighted random, shuffle, thousands separators, durations, text wrapping and chat sanitising.

Logging and the event bridge
 - Log_Debug, Log_Info, Log_Warn and Log_Error write to a daily file in logs/ (log_YYYY-MM-DD.txt), to the server console at info and above, and to a server_log table. Players logged in as RCON admin also see them in game chat. That's warnings and errors by default, and everything after an RCON login.
 - Server log rows are pruned after 14 days once something external has marked them announced. The activity_events table (a stream of player-visible happenings a bot or website can relay) is pruned after 30 days. The check runs hourly.
 - A server_events table is polled every 5 seconds, up to 64 rows at a time. Each undelivered row (account, type, JSON payload) is marked delivered and passed to a ServerEvent_OnReceived public that modules hook, so a website or panel can push actions into the game.
