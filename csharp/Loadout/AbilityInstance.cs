using System;
using System.Collections.Generic;
using System.Linq;

namespace zirconsurvivers.Loadout;

public sealed class AbilityInstance
{
    public AbilityInstance(AbilityDef def)
    {
        Def = def ?? throw new ArgumentNullException(nameof(def));
    }

    public AbilityDef Def { get; }
    public int Level { get; private set; } = 1;

    // upgradeId -> stacks
    private readonly Dictionary<string, int> _upgradeStacks = new();

    public IReadOnlyDictionary<string, int> UpgradeStacks => _upgradeStacks;

    public void LevelUp() => Level += 1;

    public bool CanApplyAnyUpgrade()
    {
        if (Def.Upgrades.Count == 0) return false;
        return Def.Upgrades.Any(u => GetStacks(u.Id) < u.MaxStacks);
    }

    public int GetStacks(string upgradeId)
        => _upgradeStacks.TryGetValue(upgradeId, out var stacks) ? stacks : 0;

    public UpgradeDef? ApplyRandomUpgrade(Random rng)
    {
        if (Def.Upgrades.Count == 0) return null;

        // Prefer upgrades that are not maxed.
        var candidates = Def.Upgrades
            .Where(u => GetStacks(u.Id) < u.MaxStacks)
            .ToList();

        if (candidates.Count == 0) return null;

        var chosen = candidates[rng.Next(candidates.Count)];
        _upgradeStacks[chosen.Id] = GetStacks(chosen.Id) + 1;
        return chosen;
    }
}
