using System;
using System.Collections.Generic;

namespace zirconsurvivers.Loadout;

public static class AbilityDatabase
{
    private static readonly Dictionary<string, AbilityDef> _defs = Build();

    public static IReadOnlyDictionary<string, AbilityDef> All => _defs;

    public static AbilityDef Get(string id)
    {
        if (!_defs.TryGetValue(id, out var def))
            throw new KeyNotFoundException($"Unknown ability id: {id}");
        return def;
    }

    private static Dictionary<string, AbilityDef> Build()
    {
        // NOTE: アイデアは暫定。後でResource/JSON化してもOK。
        var defs = new Dictionary<string, AbilityDef>(StringComparer.Ordinal);

        // Weapons
        defs["weapon_magic_wand"] = new AbilityDef
        {
            Id = "weapon_magic_wand",
            Name = "Magic Wand",
            Description = "Nearest enemy targeting shots.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/MagicWand.tscn",
            Weight = 10,
            Upgrades = new[]
            {
                U("dmg_up", "Damage Up", "Projectile damage increases.", 10),
                U("cd_down", "Haste", "Shoots more frequently.", 10),
                U("count_up", "Extra Shot", "Shoots +1 projectile.", 5),
                U("size_up", "Bigger Shots", "Projectiles become larger.", 6),
                U("pierce_up", "Piercing", "Projectiles pierce +1.", 4),
                U("explosion", "Explosive", "Projectiles explode on hit.", 1),
            }
        };

        defs["weapon_holy_aura"] = new AbilityDef
        {
            Id = "weapon_holy_aura",
            Name = "Holy Aura",
            Description = "Damages enemies around you.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/HolyAura.tscn",
            Weight = 10,
            Upgrades = new[]
            {
                U("dmg_up", "Damage Up", "Aura damage increases.", 10),
                U("radius_up", "Bigger Aura", "Aura radius increases.", 8),
                U("tick_up", "Faster Ticks", "Aura hits more frequently.", 8),
            }
        };

        defs["weapon_targeted_strike"] = new AbilityDef
        {
            Id = "weapon_targeted_strike",
            Name = "Targeted Strike",
            Description = "Creates a damaging zone at a nearby enemy.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/TargetedStrike.tscn",
            Weight = 10,
            Upgrades = new[]
            {
                U("dmg_up", "Damage Up", "Strike damage increases.", 10),
                U("cd_down", "Haste", "Strikes more frequently.", 10),
                U("radius_up", "Bigger Strike", "Strike radius increases.", 8),
                U("count_up", "Extra Strike", "Creates +1 zone.", 5),
            }
        };

        // Specials (Passive)
        defs["passive_might"] = new AbilityDef
        {
            Id = "passive_might",
            Name = "Might",
            Description = "Increases all weapon damage.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 10,
            Upgrades = new[]
            {
                U("might_up", "More Might", "Damage bonus increases.", 10),
            }
        };

        defs["passive_armor"] = new AbilityDef
        {
            Id = "passive_armor",
            Name = "Armor",
            Description = "Reduces contact damage.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 10,
            Upgrades = new[]
            {
                U("armor_up", "More Armor", "Damage reduction increases.", 10),
            }
        };

        defs["passive_vitality"] = new AbilityDef
        {
            Id = "passive_vitality",
            Name = "Vitality",
            Description = "Increases max HP.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 10,
            Upgrades = new[]
            {
                U("hp_up", "More HP", "Max HP increases.", 10),
            }
        };

        defs["passive_regen"] = new AbilityDef
        {
            Id = "passive_regen",
            Name = "Regeneration",
            Description = "Regenerates HP over time.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 8,
            Upgrades = new[]
            {
                U("regen_up", "Faster Regen", "Regeneration increases.", 10),
            }
        };

        defs["passive_haste"] = new AbilityDef
        {
            Id = "passive_haste",
            Name = "Haste Matrix",
            Description = "All weapons attack faster.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 8,
            Upgrades = new[]
            {
                U("haste_up", "More Haste", "Cooldown reduction increases.", 10),
            }
        };

        defs["passive_magnet"] = new AbilityDef
        {
            Id = "passive_magnet",
            Name = "Magnet",
            Description = "Increases pickup range.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.Passive,
            Weight = 8,
            Upgrades = new[]
            {
                U("magnet_up", "Stronger Magnet", "Pickup range increases.", 10),
            }
        };

        // Specials (AutoActive)
        defs["auto_knockback_pulse"] = new AbilityDef
        {
            Id = "auto_knockback_pulse",
            Name = "Shockwave",
            Description = "Periodically knocks back nearby enemies.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 10f,
            Weight = 8,
            Upgrades = new[]
            {
                U("radius_up", "Wider Shockwave", "Shockwave radius increases.", 6),
                U("power_up", "Stronger Shockwave", "Knockback power increases.", 8),
                U("cd_down", "Faster Shockwave", "Triggers more often.", 8),
            }
        };

        defs["auto_nova"] = new AbilityDef
        {
            Id = "auto_nova",
            Name = "Nova Burst",
            Description = "Periodically explodes around you.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 14f,
            Weight = 8,
            Upgrades = new[]
            {
                U("radius_up", "Bigger Nova", "Explosion radius increases.", 6),
                U("dmg_up", "Stronger Nova", "Explosion damage increases.", 10),
                U("cd_down", "Faster Nova", "Triggers more often.", 8),
            }
        };

        defs["auto_phase"] = new AbilityDef
        {
            Id = "auto_phase",
            Name = "Phase Cloak",
            Description = "Periodically becomes untouchable for a short time.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 24f,
            Weight = 6,
            Upgrades = new[]
            {
                U("duration_up", "Longer Phase", "Invincibility lasts longer.", 4),
                U("cd_down", "Faster Phase", "Triggers more often.", 6),
            }
        };

        defs["auto_vacuum"] = new AbilityDef
        {
            Id = "auto_vacuum",
            Name = "Vacuum",
            Description = "Periodically pulls in loot from far away.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 18f,
            Weight = 6,
            Upgrades = new[]
            {
                U("radius_up", "Wider Vacuum", "Vacuum radius increases.", 6),
                U("cd_down", "Faster Vacuum", "Triggers more often.", 6),
            }
        };

        defs["auto_slow_zone"] = new AbilityDef
        {
            Id = "auto_slow_zone",
            Name = "Frost Zone",
            Description = "Periodically creates a slow field for enemies.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 16f,
            Weight = 6,
            Upgrades = new[]
            {
                U("radius_up", "Wider Zone", "Zone radius increases.", 6),
                U("duration_up", "Longer Zone", "Zone lasts longer.", 4),
                U("power_up", "Stronger Slow", "Slow effect increases.", 4),
                U("cd_down", "Faster Zone", "Triggers more often.", 6),
            }
        };

        return defs;
    }

    private static UpgradeDef U(string id, string name, string desc, int maxStacks)
        => new() { Id = id, Name = name, Description = desc, MaxStacks = maxStacks };
}
