using Godot;
using System;
using System.Collections.Generic;

namespace ZirconSurvivors.Loadout
{
    /// <summary>
    /// ジルパワーデータベース
    /// </summary>
    public static class ZirPowerDatabase
    {
        private static Dictionary<string, ZirPowerDef>? _defs;

        public static ZirPowerDef? Get(string id)
        {
            if (_defs == null)
                _defs = Build();
            return _defs.GetValueOrDefault(id);
        }

        // GDScriptから呼ばれるメソッド（互換性のため）
        public static ZirPowerDef? GetZirPowerDef(string id)
        {
            return Get(id);
        }

        public static Dictionary<string, ZirPowerDef> GetAll()
        {
            if (_defs == null)
                _defs = Build();
            return _defs;
        }

        private static Dictionary<string, ZirPowerDef> Build()
        {
            var defs = new Dictionary<string, ZirPowerDef>(StringComparer.Ordinal);

            // ダッシュ（アクティブ）
            defs["zirpower_dash"] = new ZirPowerDef
            {
                Id = "zirpower_dash",
                Name = "Dash",
                Description = "Instantly teleport forward and become invincible briefly.",
                Type = ZirPowerType.Active,
                Cooldown = 10f,
                IconPath = "res://assets/zirpowers/Active/dash_icon.png",
                ExecutionScriptPath = "res://scripts/zirpowers/Active/Dash.gd"
            };

            // メテオストライク（アルティメット）
            defs["zirpower_meteor_strike"] = new ZirPowerDef
            {
                Id = "zirpower_meteor_strike",
                Name = "Meteor Strike",
                Description = "Rain down meteors across the screen dealing massive damage.",
                Type = ZirPowerType.Ultimate,
                WillCost = 200,
                IconPath = "res://assets/zirpowers/Ultimate/meteor_strike_icon.png",
                ExecutionScriptPath = "res://scripts/zirpowers/Ultimate/MeteorStrike.gd"
            };

            return defs;
        }
    }
}
