using Godot;
using System.Collections.Generic;

namespace ZirconSurvivors.Loadout
{
    public enum ZirPowerType
    {
        Active,      // アクティブ・ジルパワー
        Ultimate,    // アルティメット・ジルパワー
        Passive      // パッシブ・ジルパワー
    }

    /// <summary>
    /// ジルパワー定義
    /// </summary>
    public class ZirPowerDef
    {
        public required string Id { get; set; }
        public required string Name { get; set; }
        public required string Description { get; set; }
        public ZirPowerType Type { get; set; }
        public required string IconPath { get; set; }
        
        // アクティブ/アルティメット用
        public float Cooldown { get; set; }           // アクティブのクールタイム（秒）
        public int WillCost { get; set; }             // アルティメットの意志コスト
        
        // 実行スクリプト/シーンへの参照
        public string? ExecutionScriptPath { get; set; }  // GDScriptパス
        public string? EffectScenePath { get; set; }      // エフェクトシーン
        
        // パッシブ用
        public Dictionary<string, object>? PassiveModifiers { get; set; }
    }
}
