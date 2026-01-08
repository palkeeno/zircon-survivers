using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace ZirconSurvivors.Loadout
{
    /// <summary>
    /// ジルパワーマネージャー
    /// プレイヤーのジルパワー状態を管理
    /// </summary>
    public partial class ZirPowerManager : Node
    {
        private string? _currentCharacterId;
        private Dictionary<string, float> _cooldowns = new Dictionary<string, float>();  // ZirPowerId -> 残りクールタイム
        private Dictionary<string, ZirPowerDef> _activeZirPowers = new Dictionary<string, ZirPowerDef>();
        
        private Node? _player;

        public override void _Ready()
        {
            _player = GetParent();
        }

        public override void _Process(double delta)
        {
            // クールタイムを減少
            var keys = _cooldowns.Keys.ToList();
            foreach (var key in keys)
            {
                _cooldowns[key] -= (float)delta;
                if (_cooldowns[key] <= 0)
                {
                    _cooldowns.Remove(key);
                }
            }
        }

        /// <summary>
        /// キャラクターのジルパワーを初期化
        /// </summary>
        public void InitializeForCharacter(string characterId)
        {
            _currentCharacterId = characterId;
            _activeZirPowers.Clear();
            _cooldowns.Clear();

            var characterDef = CharacterDatabase.Get(characterId);
            if (characterDef == null)
            {
                GD.PrintErr($"Character {characterId} not found in database");
                return;
            }

            // アクティブジルパワーを登録
            if (characterDef.ActiveZirPowers != null)
            {
                foreach (var powerId in characterDef.ActiveZirPowers)
                {
                    var powerDef = ZirPowerDatabase.Get(powerId);
                    if (powerDef != null)
                    {
                        _activeZirPowers[powerId] = powerDef;
                    }
                }
            }

            // アルティメットジルパワーを登録
            if (characterDef.UltimateZirPowers != null)
            {
                foreach (var powerId in characterDef.UltimateZirPowers)
                {
                    var powerDef = ZirPowerDatabase.Get(powerId);
                    if (powerDef != null)
                    {
                        _activeZirPowers[powerId] = powerDef;
                    }
                }
            }

            GD.Print($"ZirPowerManager initialized for {characterId} with {_activeZirPowers.Count} powers");
        }

        /// <summary>
        /// ジルパワーが発動可能かチェック
        /// </summary>
        public bool CanActivateZirPower(string zirPowerId)
        {
            if (!_activeZirPowers.ContainsKey(zirPowerId))
                return false;

            var powerDef = _activeZirPowers[zirPowerId];

            // クールタイムチェック（アクティブ用）
            if (powerDef.Type == ZirPowerType.Active)
            {
                if (_cooldowns.ContainsKey(zirPowerId))
                    return false;
            }

            // 意志コストチェック（アルティメット用）
            if (powerDef.Type == ZirPowerType.Ultimate)
            {
                var gameManager = GetNode<Node>("/root/GameManager");
                if (gameManager != null && gameManager.HasMethod("is_will_full"))
                {
                    return (bool)gameManager.Call("is_will_full");
                }
                return false;
            }

            return true;
        }

        /// <summary>
        /// ジルパワーを発動
        /// </summary>
        public void ActivateZirPower(string zirPowerId)
        {
            if (!CanActivateZirPower(zirPowerId))
            {
                GD.Print($"Cannot activate {zirPowerId}");
                return;
            }

            var powerDef = _activeZirPowers[zirPowerId];
            GD.Print($"Activating ZirPower: {powerDef.Name} ({zirPowerId})");

            // 意志を消費（アルティメット用）
            if (powerDef.Type == ZirPowerType.Ultimate)
            {
                var gameManager = GetNode<Node>("/root/GameManager");
                if (gameManager != null && gameManager.HasMethod("consume_will_for_ultimate"))
                {
                    gameManager.Call("consume_will_for_ultimate");
                }
            }

            // 実行スクリプトをロードして実行
            if (!string.IsNullOrEmpty(powerDef.ExecutionScriptPath))
            {
                var script = GD.Load<GDScript>(powerDef.ExecutionScriptPath);
                if (script != null)
                {
                    var instance = (GodotObject)script.New();
                    if (instance != null && instance.HasMethod("execute") && _player != null)
                    {
                        instance.Call("execute", _player);
                    }
                }
                else
                {
                    GD.PrintErr($"Failed to load script: {powerDef.ExecutionScriptPath}");
                }
            }

            // クールタイムを設定（アクティブ用）
            if (powerDef.Type == ZirPowerType.Active)
            {
                _cooldowns[zirPowerId] = powerDef.Cooldown;
            }
        }

        /// <summary>
        /// クールタイムの進行度を取得（0.0～1.0）
        /// </summary>
        public float GetCooldownProgress(string zirPowerId)
        {
            if (!_activeZirPowers.ContainsKey(zirPowerId))
                return 1.0f;

            var powerDef = _activeZirPowers[zirPowerId];
            if (powerDef.Type != ZirPowerType.Active)
                return 1.0f;

            if (!_cooldowns.ContainsKey(zirPowerId))
                return 1.0f;  // Ready

            float remaining = _cooldowns[zirPowerId];
            float total = powerDef.Cooldown;
            return 1.0f - (remaining / total);
        }

        /// <summary>
        /// すべてのジルパワーを取得
        /// </summary>
        public List<ZirPowerDef> GetAllZirPowers()
        {
            return _activeZirPowers.Values.ToList();
        }

        /// <summary>
        /// すべてのジルパワーをGDScript互換の配列で取得
        /// </summary>
        public Godot.Collections.Array<Godot.Collections.Dictionary<string, Variant>> GetAllZirPowersForGDScript()
        {
            var result = new Godot.Collections.Array<Godot.Collections.Dictionary<string, Variant>>();
            foreach (var power in _activeZirPowers.Values)
            {
                var dict = new Godot.Collections.Dictionary<string, Variant>
                {
                    { "id", power.Id },
                    { "name", power.Name },
                    { "type", (int)power.Type },
                    { "cooldown", power.Cooldown },
                    { "will_cost", power.WillCost },
                    { "icon_path", power.IconPath ?? "" },
                    { "execution_script_path", power.ExecutionScriptPath ?? "" }
                };
                result.Add(dict);
            }
            return result;
        }

        /// <summary>
        /// 特定のジルパワー定義を取得
        /// </summary>
        public ZirPowerDef? GetZirPowerDef(string zirPowerId)
        {
            return _activeZirPowers.GetValueOrDefault(zirPowerId);
        }

        /// <summary>
        /// 特定のジルパワー定義をGDScript互換のDictionaryで取得
        /// </summary>
        public Godot.Collections.Dictionary<string, Variant>? GetZirPowerDefForGDScript(string zirPowerId)
        {
            if (!_activeZirPowers.TryGetValue(zirPowerId, out var power))
                return null;
            
            return new Godot.Collections.Dictionary<string, Variant>
            {
                { "id", power.Id },
                { "name", power.Name },
                { "type", (int)power.Type },
                { "cooldown", power.Cooldown },
                { "will_cost", power.WillCost },
                { "icon_path", power.IconPath ?? "" },
                { "execution_script_path", power.ExecutionScriptPath ?? "" }
            };
        }
    }
}
