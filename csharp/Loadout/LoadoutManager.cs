using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace zirconsurvivers.Loadout;

public partial class LoadoutManager : Node
{
    [Signal]
    public delegate void LoadoutChangedEventHandler();

    [Export] public int MaxWeapons { get; set; } = 4;
    [Export] public int MaxSpecials { get; set; } = 4;

    private readonly Random _rng = new();

    private readonly List<AbilityInstance> _weapons = new();
    private readonly List<AbilityInstance> _specials = new();

    // offerId -> offer
    private readonly Dictionary<string, Offer> _lastOffers = new(StringComparer.Ordinal);

    // abilityId -> cooldown remaining (auto-actives only)
    private readonly Dictionary<string, float> _autoCooldownRemaining = new(StringComparer.Ordinal);

    private Node? _player;

    public override void _Ready()
    {
        _player = GetParent();

        // Start with Magic Wand if nothing is registered yet.
        EnsureStartingWeapon();

        RecomputeAndApplyPassives();
        EmitSignal(SignalName.LoadoutChanged);
    }

    public override void _Process(double delta)
    {
        if (GetTree().Paused)
            return;

        TickAutoActives((float)delta);
    }

    public Godot.Collections.Array GetLoadoutSummary()
    {
        var weapons = new Godot.Collections.Array();
        foreach (var w in _weapons)
        {
            weapons.Add(new Godot.Collections.Dictionary
            {
                ["id"] = w.Def.Id,
                ["name"] = w.Def.Name,
                ["level"] = w.Level,
                ["icon_path"] = w.Def.IconPath ?? "",
            });
        }

        var specials = new Godot.Collections.Array();
        foreach (var s in _specials)
        {
            specials.Add(new Godot.Collections.Dictionary
            {
                ["id"] = s.Def.Id,
                ["name"] = s.Def.Name,
                ["level"] = s.Level,
                ["special_kind"] = s.Def.SpecialKind?.ToString() ?? "Passive",
                ["icon_path"] = s.Def.IconPath ?? "",
            });
        }

        return new Godot.Collections.Array { weapons, specials };
    }

    public Godot.Collections.Array GenerateOffers(int count = 4)
    {
        EnsureStartingWeapon();

        var offers = OfferGenerator.Generate(_rng, _weapons, _specials, MaxWeapons, MaxSpecials, count);

        _lastOffers.Clear();

        var ui = new Godot.Collections.Array();
        foreach (var offer in offers)
        {
            var def = AbilityDatabase.Get(offer.TargetAbilityId);

            // Stable offer id for UI click -> apply.
            var offerId = $"{offer.SlotKind}:{offer.Action}:{offer.TargetAbilityId}";
            _lastOffers[offerId] = offer;

            var isUpgrade = offer.Action == OfferAction.Upgrade;

            ui.Add(new Godot.Collections.Dictionary
            {
                ["offer_id"] = offerId,
                ["slot_kind"] = offer.SlotKind.ToString(),
                ["action"] = offer.Action.ToString(),
                ["target_id"] = offer.TargetAbilityId,
                ["name"] = def.Name,
                ["desc"] = isUpgrade ? $"Upgrade (random): {def.Description}" : def.Description,
                ["is_upgrade"] = isUpgrade,
                ["special_kind"] = def.SpecialKind?.ToString() ?? "",
                ["icon_path"] = def.IconPath ?? "",
            });
        }

        // Enforce at least 1 weapon and 1 special in UI (safety check).
        // If generation failed to meet it (shouldn't), we patch by swapping.
        if (ui.Count >= 2)
        {
            var hasWeapon = false;
            var hasSpecial = false;

            for (var i = 0; i < ui.Count; i++)
            {
                if (ui[i].Obj is not Godot.Collections.Dictionary d)
                    continue;

                var slotKind = d.TryGetValue("slot_kind", out var v) ? v.AsString() : "";
                if (slotKind == AbilitySlotKind.Weapon.ToString())
                    hasWeapon = true;
                else if (slotKind == AbilitySlotKind.Special.ToString())
                    hasSpecial = true;
            }

            if (!hasWeapon)
                ui[0] = ForceOffer(AbilitySlotKind.Weapon);
            if (!hasSpecial)
                ui[1] = ForceOffer(AbilitySlotKind.Special);
        }

        return ui;
    }

    public void ApplyOffer(string offerId)
    {
        if (!_lastOffers.TryGetValue(offerId, out var offer))
            return;

        if (offer.SlotKind == AbilitySlotKind.Weapon)
        {
            if (offer.Action == OfferAction.Acquire)
                AcquireWeapon(offer.TargetAbilityId);
            else
                UpgradeWeapon(offer.TargetAbilityId);
        }
        else
        {
            if (offer.Action == OfferAction.Acquire)
                AcquireSpecial(offer.TargetAbilityId);
            else
                UpgradeSpecial(offer.TargetAbilityId);
        }

        RecomputeAndApplyPassives();
        EmitSignal(SignalName.LoadoutChanged);
    }

    private Godot.Collections.Dictionary ForceOffer(AbilitySlotKind kind)
    {
        var fallbackId = kind == AbilitySlotKind.Weapon ? "weapon_magic_wand" : "passive_might";
        var offerId = $"{kind}:{OfferAction.Acquire}:{fallbackId}";
        _lastOffers[offerId] = Offer.Acquire(kind, fallbackId);
        var def = AbilityDatabase.Get(fallbackId);
        return new Godot.Collections.Dictionary
        {
            ["offer_id"] = offerId,
            ["slot_kind"] = kind.ToString(),
            ["action"] = OfferAction.Acquire.ToString(),
            ["target_id"] = fallbackId,
            ["name"] = def.Name,
            ["desc"] = def.Description,
            ["is_upgrade"] = false,
            ["special_kind"] = def.SpecialKind?.ToString() ?? "",
        };
    }

    private void EnsureStartingWeapon()
    {
        if (_weapons.Count > 0)
            return;

        // Register Magic Wand as starting weapon.
        _weapons.Add(new AbilityInstance(AbilityDatabase.Get("weapon_magic_wand")));

        // Ensure player has the node.
        var scenePath = AbilityDatabase.Get("weapon_magic_wand").WeaponScenePath;
        if (_player != null && scenePath != null)
            _player.CallDeferred("ensure_weapon_scene", scenePath, "weapon_magic_wand");
    }

    private void AcquireWeapon(string abilityId)
    {
        if (_weapons.Count >= MaxWeapons)
        {
            UpgradeWeapon(abilityId);
            return;
        }

        if (_weapons.Any(w => w.Def.Id == abilityId))
        {
            UpgradeWeapon(abilityId);
            return;
        }

        var def = AbilityDatabase.Get(abilityId);
        _weapons.Add(new AbilityInstance(def));

        if (_player != null && def.WeaponScenePath != null)
            _player.CallDeferred("add_weapon_scene", def.WeaponScenePath, def.Id);
    }

    private void UpgradeWeapon(string abilityId)
    {
        var inst = _weapons.FirstOrDefault(w => w.Def.Id == abilityId);
        if (inst == null)
        {
            // If not owned, treat as acquire.
            AcquireWeapon(abilityId);
            return;
        }

        inst.LevelUp();

        var applied = inst.ApplyRandomUpgrade(_rng);
        if (_player != null && applied != null)
        {
            // Let GDScript apply concrete effects to weapon nodes.
            _player.CallDeferred("apply_weapon_upgrade", inst.Def.Id, applied.Id, inst.GetStacks(applied.Id));
        }
    }

    private void AcquireSpecial(string abilityId)
    {
        if (_specials.Count >= MaxSpecials)
        {
            UpgradeSpecial(abilityId);
            return;
        }

        if (_specials.Any(s => s.Def.Id == abilityId))
        {
            UpgradeSpecial(abilityId);
            return;
        }

        var def = AbilityDatabase.Get(abilityId);
        _specials.Add(new AbilityInstance(def));

        if (def.SpecialKind == SpecialAbilityKind.AutoActive)
            _autoCooldownRemaining[abilityId] = GetAutoCooldown(def, _specials.First(s => s.Def.Id == abilityId));
    }

    private void UpgradeSpecial(string abilityId)
    {
        var inst = _specials.FirstOrDefault(s => s.Def.Id == abilityId);
        if (inst == null)
        {
            AcquireSpecial(abilityId);
            return;
        }

        inst.LevelUp();

        inst.ApplyRandomUpgrade(_rng);

        if (inst.Def.SpecialKind == SpecialAbilityKind.AutoActive)
            _autoCooldownRemaining[abilityId] = GetAutoCooldown(inst.Def, inst);
    }

    private void RecomputeAndApplyPassives()
    {
        if (_player == null)
            return;

        // Aggregate passive modifiers.
        var damageMult = 1.0f;
        var cooldownMult = 1.0f;
        var armorBonus = 0.0f;
        var maxHpBonus = 0.0f;
        var regenPerSec = 0.0f;
        var magnetMult = 1.0f;

        foreach (var s in _specials)
        {
            if (s.Def.SpecialKind != SpecialAbilityKind.Passive)
                continue;

            switch (s.Def.Id)
            {
                case "passive_might":
                    damageMult *= 1.0f + 0.07f * s.GetStacks("might_up");
                    break;
                case "passive_haste":
                    cooldownMult *= 1.0f - 0.05f * s.GetStacks("haste_up");
                    break;
                case "passive_armor":
                    armorBonus += 1.5f * s.GetStacks("armor_up");
                    break;
                case "passive_vitality":
                    maxHpBonus += 10.0f * s.GetStacks("hp_up");
                    break;
                case "passive_regen":
                    regenPerSec += 0.35f * s.GetStacks("regen_up");
                    break;
                case "passive_magnet":
                    magnetMult *= 1.0f + 0.2f * s.GetStacks("magnet_up");
                    break;
            }
        }

        if (cooldownMult < 0.2f) cooldownMult = 0.2f;

        var dict = new Godot.Collections.Dictionary
        {
            ["damage_mult"] = damageMult,
            ["cooldown_mult"] = cooldownMult,
            ["armor_bonus"] = armorBonus,
            ["max_hp_bonus"] = maxHpBonus,
            ["regen_per_sec"] = regenPerSec,
            ["magnet_mult"] = magnetMult,
        };

        _player.CallDeferred("set_stat_modifiers", dict);
    }

    private void TickAutoActives(float delta)
    {
        if (_player == null)
            return;

        // Auto actives are affected by haste passive.
        var cooldownMult = 1.0f;
        var haste = _specials.FirstOrDefault(s => s.Def.Id == "passive_haste");
        if (haste != null)
            cooldownMult *= 1.0f - 0.05f * haste.GetStacks("haste_up");
        if (cooldownMult < 0.2f) cooldownMult = 0.2f;

        foreach (var inst in _specials)
        {
            if (inst.Def.SpecialKind != SpecialAbilityKind.AutoActive)
                continue;

            var id = inst.Def.Id;
            if (!_autoCooldownRemaining.ContainsKey(id))
                _autoCooldownRemaining[id] = GetAutoCooldown(inst.Def, inst) * cooldownMult;

            _autoCooldownRemaining[id] -= delta;
            if (_autoCooldownRemaining[id] > 0)
                continue;

            TriggerAutoActive(inst);
            _autoCooldownRemaining[id] = GetAutoCooldown(inst.Def, inst) * cooldownMult;
        }
    }

    private float GetAutoCooldown(AbilityDef def, AbilityInstance inst)
    {
        var cd = def.BaseCooldownSec;
        var cdDown = inst.GetStacks("cd_down");
        if (cdDown > 0)
            cd *= MathF.Pow(0.92f, cdDown);
        return MathF.Max(3f, cd);
    }

    private void TriggerAutoActive(AbilityInstance inst)
    {
        if (_player == null)
            return;

        var radius = 120f + 25f * inst.GetStacks("radius_up");
        var power = 1.0f + 0.35f * inst.GetStacks("power_up");
        var damage = 12f * (1.0f + 0.25f * inst.GetStacks("dmg_up"));
        var duration = 1.2f + 0.35f * inst.GetStacks("duration_up");

        switch (inst.Def.Id)
        {
            case "auto_knockback_pulse":
                _player.CallDeferred("do_knockback_pulse", radius, power);
                break;
            case "auto_nova":
                _player.CallDeferred("do_nova", radius, damage);
                break;
            case "auto_phase":
                _player.CallDeferred("do_phase", duration);
                break;
            case "auto_vacuum":
                _player.CallDeferred("do_vacuum", radius);
                break;
            case "auto_slow_zone":
                var slowStrength = 0.25f + 0.1f * inst.GetStacks("power_up");
                var zoneDuration = 3.0f + 0.5f * inst.GetStacks("duration_up");
                _player.CallDeferred("do_slow_zone", radius, slowStrength, zoneDuration);
                break;
        }
    }
}
