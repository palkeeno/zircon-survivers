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
            IconPath = "res://assets/weapons/magic_wand.png",
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
            IconPath = "res://assets/weapons/holy_aura.png",
            Weight = 10,
            Upgrades = new[]
            {
                U("radius_up", "Bigger Aura", "Aura radius increases.", 8),
            }
        };

        defs["weapon_targeted_strike"] = new AbilityDef
        {
            Id = "weapon_targeted_strike",
            Name = "Targeted Strike",
            Description = "Creates a damaging zone at a nearby enemy.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/TargetedStrike.tscn",
            IconPath = "res://assets/weapons/targeted_strike.png",
            Weight = 10,
            Upgrades = new[]
            {
                U("dmg_up", "Damage Up", "Strike damage increases.", 10),
                U("cd_down", "Haste", "Strikes more frequently.", 10),
                U("radius_up", "Bigger Strike", "Strike radius increases.", 8),
                U("count_up", "Extra Target", "Targets +1 additional enemy.", 5),
            }
        };

        defs["weapon_nova_burst"] = new AbilityDef
        {
            Id = "weapon_nova_burst",
            Name = "Nova Burst",
            Description = "Detonates a huge blast around you at long intervals.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/NovaBurst.tscn",
            IconPath = "res://assets/weapons/nova_burst.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "Stronger Nova", "Explosion damage increases.", 10),
                U("radius_up", "Bigger Nova", "Explosion radius increases.", 8),
                U("cd_down", "Faster Nova", "Triggers more often.", 10),
            }
        };

        defs["weapon_shockwave"] = new AbilityDef
        {
            Id = "weapon_shockwave",
            Name = "Shockwave",
            Description = "Chain lightning jumps between nearby enemies.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/Shockwave.tscn",
            IconPath = "res://assets/weapons/shockwave.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "More Voltage", "Lightning damage increases.", 10),
                U("cd_down", "Faster Sparks", "Triggers more often.", 10),
                U("range_up", "Longer Chain", "Chain range increases.", 8),
                U("jumps_up", "Extra Jumps", "Hits +1 additional enemy.", 6),
                U("fork", "Fork", "Adds an extra chain.", 3),
            }
        };

        defs["weapon_orbit_boomerang"] = new AbilityDef
        {
            Id = "weapon_orbit_boomerang",
            Name = "Comet Boomerang",
            Description = "Boomerangs orbit around you on a comet-like path. More boomerangs also add new angled orbits.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/OrbitBoomerang.tscn",
            IconPath = "res://assets/weapons/orbit_boomerang.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "Sharper Edge", "Orbit hit damage increases.", 10),
                U("count_up", "More Boomerangs", "Adds +1 orbiting boomerang (may create a new orbit).", 7),
                U("radius_up", "Wider Orbit", "Orbit size increases.", 8),
                U("speed_up", "Faster Orbit", "Orbit speed increases.", 8),
                U("tick_up", "More Hits", "Hits more frequently.", 7),
            }
        };

        defs["weapon_piercing_beam"] = new AbilityDef
        {
            Id = "weapon_piercing_beam",
            Name = "Piercing Beam",
            Description = "Fires a beam towards the nearest enemy, reaching the screen edge.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/PiercingBeam.tscn",
            IconPath = "res://assets/weapons/piercing_beam.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "More Power", "Beam damage increases.", 10),
                U("cd_down", "Faster Beam", "Fires more often.", 10),
                U("width_up", "Wider Beam", "Beam width increases.", 7),
                U("bounce_up", "Ricochet", "Beam bounces +1 time off walls.", 6),
                U("count_up", "Extra Beam", "Fires +1 beam.", 5),
            }
        };

        defs["weapon_fire_bottle"] = new AbilityDef
        {
            Id = "weapon_fire_bottle",
            Name = "Fire Bottle",
            Description = "Throws a bottle that leaves a burning area.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/FireBottle.tscn",
            IconPath = "res://assets/weapons/fire_bottle.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "Hotter Flames", "Burn damage increases.", 10),
                U("cd_down", "Faster Throws", "Throws more often.", 10),
                U("radius_up", "Bigger Fire", "Burning area radius increases.", 8),
                U("duration_up", "Longer Burn", "Burning lasts longer.", 7),
                U("tick_up", "Faster Burn", "Burn hits more frequently.", 7),
                U("count_up", "Extra Bottle", "Throws +1 bottle.", 5),
            }
        };

        defs["weapon_twin_claw"] = new AbilityDef
        {
            Id = "weapon_twin_claw",
            Name = "Twin Claw",
            Description = "Slashes forward and backward at the same time.",
            SlotKind = AbilitySlotKind.Weapon,
            WeaponScenePath = "res://scenes/weapons/TwinClaw.tscn",
            IconPath = "res://assets/weapons/twin_claw.png",
            Weight = 8,
            Upgrades = new[]
            {
                U("dmg_up", "Stronger Claws", "Slash damage increases.", 10),
                U("cd_down", "Faster Slashes", "Slashes more often.", 10),
                U("radius_up", "Wider Slash", "Slash size increases.", 8),
                U("count_up", "Extra Slash", "Adds +1 slash per trigger.", 5),
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
            IconPath = "res://assets/abilities/might.png",
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
            IconPath = "res://assets/abilities/armor.png",
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
            IconPath = "res://assets/abilities/vitality.png",
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
            IconPath = "res://assets/abilities/regeneration.png",
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
            IconPath = "res://assets/abilities/auto_haste.png",
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
            // Icon not provided
            Weight = 8,
            Upgrades = new[]
            {
                U("magnet_up", "Stronger Magnet", "Pickup range increases.", 10),
            }
        };

        // Specials (AutoActive)

        defs["auto_phase"] = new AbilityDef
        {
            Id = "auto_phase",
            Name = "Phase Cloak",
            Description = "Periodically becomes untouchable for a short time.",
            SlotKind = AbilitySlotKind.Special,
            SpecialKind = SpecialAbilityKind.AutoActive,
            BaseCooldownSec = 24f,
            IconPath = "res://assets/abilities/phase_cloak.png",
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
            // Icon not provided
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
            IconPath = "res://assets/abilities/frozen_zone.png",
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
