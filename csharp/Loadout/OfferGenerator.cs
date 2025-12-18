using System;
using System.Collections.Generic;
using System.Linq;

namespace zirconsurvivers.Loadout;

public static class OfferGenerator
{
    public static List<Offer> Generate(
        Random rng,
        IReadOnlyList<AbilityInstance> ownedWeapons,
        IReadOnlyList<AbilityInstance> ownedSpecials,
        int maxWeapons,
        int maxSpecials,
        int offerCount = 4)
    {
        if (offerCount < 2)
            throw new ArgumentOutOfRangeException(nameof(offerCount), "offerCount must be >= 2");

        var offers = new List<Offer>(offerCount);

        // Must include at least one weapon and one special.
        offers.Add(PickOne(rng, AbilitySlotKind.Weapon, BuildPool(AbilitySlotKind.Weapon, ownedWeapons, maxWeapons), ownedWeapons));
        offers.Add(PickOne(rng, AbilitySlotKind.Special, BuildPool(AbilitySlotKind.Special, ownedSpecials, maxSpecials), ownedSpecials));

        while (offers.Count < offerCount)
        {
            var canWeapon = BuildPool(AbilitySlotKind.Weapon, ownedWeapons, maxWeapons).Count > 0;
            var canSpecial = BuildPool(AbilitySlotKind.Special, ownedSpecials, maxSpecials).Count > 0;

            AbilitySlotKind kind;
            if (canWeapon && canSpecial)
                kind = rng.NextDouble() < 0.5 ? AbilitySlotKind.Weapon : AbilitySlotKind.Special;
            else if (canWeapon)
                kind = AbilitySlotKind.Weapon;
            else if (canSpecial)
                kind = AbilitySlotKind.Special;
            else
                break;

            var next = PickOne(
                rng,
                kind,
                BuildPool(
                    kind,
                    kind == AbilitySlotKind.Weapon ? ownedWeapons : ownedSpecials,
                    kind == AbilitySlotKind.Weapon ? maxWeapons : maxSpecials),
                kind == AbilitySlotKind.Weapon ? ownedWeapons : ownedSpecials);

            // Avoid duplicate target ids.
            if (offers.Any(o => o.TargetAbilityId == next.TargetAbilityId && o.SlotKind == next.SlotKind))
                continue;

            offers.Add(next);
        }

        // If we couldn't fill, fall back to upgrades only.
        while (offers.Count < offerCount)
        {
            var upgradeOnly = PickUpgradeOnly(rng, ownedWeapons, ownedSpecials);
            if (upgradeOnly == null)
                break;
            if (offers.Any(o => o.TargetAbilityId == upgradeOnly.TargetAbilityId && o.SlotKind == upgradeOnly.SlotKind))
                continue;
            offers.Add(upgradeOnly);
        }

        return offers;
    }

    private static Offer? PickUpgradeOnly(Random rng, IReadOnlyList<AbilityInstance> ownedWeapons, IReadOnlyList<AbilityInstance> ownedSpecials)
    {
        var upgradable = new List<(AbilitySlotKind kind, AbilityInstance inst)>();
        upgradable.AddRange(ownedWeapons.Where(w => w.CanApplyAnyUpgrade()).Select(w => (AbilitySlotKind.Weapon, w)));
        upgradable.AddRange(ownedSpecials.Where(s => s.CanApplyAnyUpgrade()).Select(s => (AbilitySlotKind.Special, s)));
        if (upgradable.Count == 0) return null;

        var (kind, inst) = upgradable[rng.Next(upgradable.Count)];
        return Offer.Upgrade(kind, inst.Def.Id);
    }

    private static Offer PickOne(Random rng, AbilitySlotKind kind, List<string> pool, IReadOnlyList<AbilityInstance> owned)
    {
        if (pool.Count == 0)
        {
            // No available choices (e.g. slots full + nothing upgradable). Fall back to any upgradable.
            var upgradable = owned.FirstOrDefault(i => i.CanApplyAnyUpgrade());
            if (upgradable != null)
                return Offer.Upgrade(kind, upgradable.Def.Id);

            // Last resort: offer something stable.
            return kind == AbilitySlotKind.Weapon
                ? Offer.Acquire(kind, "weapon_magic_wand")
                : Offer.Acquire(kind, "passive_might");
        }

        var chosenId = WeightedPick(rng, pool);
        var isOwned = owned.Any(i => i.Def.Id == chosenId);
        return isOwned ? Offer.Upgrade(kind, chosenId) : Offer.Acquire(kind, chosenId);
    }

    private static List<string> BuildPool(AbilitySlotKind kind, IReadOnlyList<AbilityInstance> owned, int maxSlots)
    {
        var defs = AbilityDatabase.All.Values.Where(d => d.SlotKind == kind).ToList();

        var hasSlot = owned.Count < maxSlots;
        var result = new List<string>();

        foreach (var def in defs)
        {
            var isOwned = owned.Any(o => o.Def.Id == def.Id);
            if (isOwned)
            {
                // Offer upgrade only if it can still upgrade.
                var inst = owned.First(o => o.Def.Id == def.Id);
                if (inst.CanApplyAnyUpgrade())
                    result.Add(def.Id);
            }
            else
            {
                if (hasSlot)
                    result.Add(def.Id);
            }
        }

        return result;
    }

    private static string WeightedPick(Random rng, List<string> ids)
    {
        var total = 0;
        foreach (var id in ids)
            total += Math.Max(1, AbilityDatabase.Get(id).Weight);

        var roll = rng.Next(total);
        foreach (var id in ids)
        {
            roll -= Math.Max(1, AbilityDatabase.Get(id).Weight);
            if (roll < 0)
                return id;
        }

        return ids[0];
    }
}

public sealed class Offer
{
    private Offer(OfferAction action, AbilitySlotKind slotKind, string targetAbilityId)
    {
        Action = action;
        SlotKind = slotKind;
        TargetAbilityId = targetAbilityId;
    }

    public OfferAction Action { get; }
    public AbilitySlotKind SlotKind { get; }
    public string TargetAbilityId { get; }

    public static Offer Acquire(AbilitySlotKind slotKind, string abilityId) => new(OfferAction.Acquire, slotKind, abilityId);
    public static Offer Upgrade(AbilitySlotKind slotKind, string abilityId) => new(OfferAction.Upgrade, slotKind, abilityId);
}
