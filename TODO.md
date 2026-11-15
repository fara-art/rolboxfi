# Owner's bug / wish list (collected 2026-11-15, fix in one pass)

1. [done] ui_upgrades icon ID typo (117562118988324).
2. [done] Shop window is too big (covers the whole screen) — make it a bit smaller.
3. [done] Roll reel: star name + odds UNDER the star, not to the right. Move the reel lower so it doesn't cover
   the "x2 LUCK" bar and the "New in the Index" toast.
4. [done] Expeditions pay too much: keep 1/2/4/8 h, cut cash x4 (1 h pays like 15 min used to). (Owner wrote it
   ambiguously: "дольше … на 1 час делай на 15 мин" — confirm if he meant longer timers instead.)
5. [done] Constellations window: hover (tap on phone) a star → tooltip with name + odds. The "+10%" bonus text is cut off on the right.
6. [done] Pets give more luck, also cheap ones, scaling with rarity: ~1/2 +10%, 1/100 +20%, 1/1M +40%, 1/1B +55%.
7. [done] Pets: inventory button "EQUIP" (instead of PET); tap a pet in the pets panel → card with its bonuses + "UNEQUIP"
   (now it unequips instantly on tap).
8. [done] Inventory / "Place a star" list not in order: sort by real rarity (Items.chance incl. mutation), rarest first
   (seasonal stars currently jump to the top because of their index).
9. [done] Mutation upgrade costs 5 identical stars (now 1). Forge stays 5.
10. [done] Shop rail: pressing CODES doesn't scroll to codes (the last section can't scroll to the top) — jump must
    work for the bottom sections (scroll to the end / add bottom padding). Highlight follows the click.
11. [done] Gamepass cards: description sits on the buy button — move it higher.
12. [done] Buttons often need two clicks to work (everywhere!). Likely: re-render on every state update destroys the
    button under the cursor between press and release → don't rebuild windows on every state push (only when
    data that the window shows changed), or keep buttons and update text.
13. [done] Roll rewards window: old clover and coin icons — use the new boost_luck / coins_small art.
14. [done] Placing on a pedestal ("Place a star") and the inventory: always in order, and the list must not flicker /
    re-sort after every roll (same fix as 12: no full rebuild every state update).
15. [done] Rebirth must reset pets (unequip → they are lost like the inventory) and expeditions (cancelled, stars lost).
16. [done] Rebirth luck: total luck (everything: passes, pets, upgrades…) x2 after 1st rebirth, x4 after 2nd, x6, x8 …
    (= x2·rebirths, ONE multiplier: 1st rebirth x2, 2nd x4, 3rd x6 — confirmed by owner; replaces x(1+0.5r)).
17. [done] Upgrades: "MAX" button — spend all cash on the selected upgrade (buy as many levels as affordable).
18. [done] Offline income: when a player comes back, pay income for the time away (cap it, e.g. 8–12 h, maybe x0.5).
19. [done] Forge mutation upgrade doesn't work ("не могу апгрейднуть в фордже") — investigate (maybe the copies/cost check,
    or the seasonal guard, or the button needing 2 clicks).
20. [ideas sent to owner] Think of a unique "hook" for the game that no other RNG game has (idea list for the owner, no code yet).
