using System;
using System.Collections.Generic;

namespace zirconsurvivers.Loadout;

public sealed class AbilityDef
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required string Description { get; init; }

    public required AbilitySlotKind SlotKind { get; init; }

    /// <summary>Only used when SlotKind == Special.</summary>
    public SpecialAbilityKind? SpecialKind { get; init; }

    /// <summary>Scene path for weapons. Null for non-weapon abilities.</summary>
    public string? WeaponScenePath { get; init; }

    public float BaseCooldownSec { get; init; } = 0f;

    /// <summary>Optional icon image path (res://...). If null, UI shows text only.</summary>
    public string? IconPath { get; init; }

    /// <summary>Relative weight for random offer selection.</summary>
    public int Weight { get; init; } = 10;

    public IReadOnlyList<UpgradeDef> Upgrades { get; init; } = Array.Empty<UpgradeDef>();
}

public sealed class UpgradeDef
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required string Description { get; init; }

    /// <summary>Maximum times this upgrade can be applied. Use int.MaxValue for unlimited.</summary>
    public int MaxStacks { get; init; } = 1;

    /// <summary>Optional tags for game-side effect routing.</summary>
    public IReadOnlyDictionary<string, float> Scalars { get; init; } = new Dictionary<string, float>();
}
