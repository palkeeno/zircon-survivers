using Godot;
using System;
using System.Collections.Generic;

namespace ZirconSurvivors.Loadout
{
    /// <summary>
    /// キャラクターデータベース
    /// </summary>
    public static class CharacterDatabase
    {
        private static Dictionary<string, CharacterDef>? _defs;

        public static CharacterDef? Get(string id)
        {
            if (_defs == null)
                _defs = Build();
            return _defs.GetValueOrDefault(id);
        }

        // GDScriptから呼ばれるメソッド（互換性のため）
        public static CharacterDef? GetCharacterDef(string id)
        {
            return Get(id);
        }

        public static Dictionary<string, CharacterDef> GetAll()
        {
            if (_defs == null)
                _defs = Build();
            return _defs;
        }

        private static Dictionary<string, CharacterDef> Build()
        {
            var defs = new Dictionary<string, CharacterDef>(StringComparer.Ordinal);

            // イズミ
            defs["izumi"] = new CharacterDef
            {
                Id = "izumi",
                Name = "Izumi",
                Description = "Balanced character with agile movement and powerful area attacks.",
                PortraitPath = "res://assets/characters/izumi_portrait.png",
                BaseSpeed = 200f,
                BaseMaxHP = 100f,
                BaseArmor = 0f,
                ActiveZirPowers = new List<string> { "zirpower_dash" },
                UltimateZirPowers = new List<string> { "zirpower_meteor_strike" },
                PassiveZirPowers = new List<string>(),  // パッシブなし
                StartingWeapon = "weapon_magic_wand"
            };

            return defs;
        }
    }
}
