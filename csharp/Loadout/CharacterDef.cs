using Godot;
using System.Collections.Generic;

namespace ZirconSurvivors.Loadout
{
    /// <summary>
    /// キャラクター定義
    /// </summary>
    public class CharacterDef
    {
        public required string Id { get; set; }
        public required string Name { get; set; }
        public required string Description { get; set; }
        public required string PortraitPath { get; set; }
        public string? PlayerScenePath { get; set; }   // 専用プレイヤーシーン（将来）
        
        // 基礎ステータス修正
        public float BaseSpeed { get; set; } = 200f;
        public float BaseMaxHP { get; set; } = 100f;
        public float BaseArmor { get; set; } = 0f;
        
        // ジルパワー構成
        public required List<string> ActiveZirPowers { get; set; }    // アクティブIDリスト
        public required List<string> UltimateZirPowers { get; set; }  // アルティメットIDリスト（必須）
        public required List<string> PassiveZirPowers { get; set; }   // パッシブIDリスト
        
        // 初期装備（オプション）
        public string? StartingWeapon { get; set; }
    }
}
