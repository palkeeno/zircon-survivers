# ジルパワーシステム設計プラン

## 1. 概要

### 1.1 ジルパワーとは
キャラクター固有のスキルシステムで、プレイヤーがボタンを押すことで能動的に発動できる特殊能力。既存の「アビリティ」システムとは独立した新しい機能。

### 1.2 ジルパワーの種類

| 種類 | 名称 | 説明 | 制約 |
|------|------|------|------|
| 1 | アクティブ・ジルパワー | いつでも使用可能。クールタイム制 | キャラクターによって0個以上 |
| 2 | アルティメット・ジルパワー | 「意志」リソースを消費する強力な技 | 全キャラクター必須（1個以上） |
| 3 | パッシブ・ジルパワー | 常に効果が適用される受動スキル | キャラクターによって0個以上 |

### 1.3 キャラクター構成
- **アルティメット(2)**: 必須。すべてのキャラクターが1つ以上保持
- **アクティブ(1)とパッシブ(3)**: 任意。片方のみ、両方、または複数持つことも可能
- 将来的に複数のアクティブ/パッシブを持つキャラクターも登場する可能性あり

---

## 2. システム設計

### 2.1 意志（Will）システム

#### 2.1.1 概要
アルティメット・ジルパワーを発動するためのリソース。敵を倒すことで獲得。

#### 2.1.2 仕様
- **獲得方法**: 敵を1体倒すごとに敵の種類に応じた量を獲得
  - 通常敵: 1～3ポイント(敵の強さに応じて)
  - ミニボス: 10～20ポイント
  - ボス: 50～100ポイント
  - 敵の `will_value` プロパティで個別設定可能
- **表示**: アルティメットボタンに「%」表示でゲージが貯まる形式(0～100%)
- **消費**: アルティメット発動時に蓄積している意志100%をすべて消費し、0%になる
- **上限**: 100%が上限。100%に達している状態では、それ以上の意志は獲得しない（オーバーフローしない）
- **初期値**: ゲーム開始時は0%

#### 2.1.3 実装箇所
- `GameManager.gd`: 意志の蓄積と管理、パーセント計算、上限チェック
- `Enemy.gd`: 死亡時に `will_value` を付与(デフォルト1、敵ごとに設定)
- `ZirPowerButton.gd`: アルティメットボタンに%表示とゲージ

#### 2.1.4 意志の内部管理
```gdscript
# GameManagerでの管理例
var will_points: int = 0           # 実際の意志ポイント
var will_max_points: int = 200     # アルティメット発動に必要なポイント（メテオストライク）

func get_will_percent() -> int:
    return int(floor(float(will_points) / float(will_max_points) * 100.0))

func is_will_full() -> bool:
    return will_points >= will_max_points
```

---

### 2.2 ジルパワー定義システム

#### 2.2.1 データ構造（C#）

```csharp
// ZirPowerDef.cs - ジルパワー定義
public class ZirPowerDef
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public ZirPowerType Type { get; set; }
    public string IconPath { get; set; }
    
    // アクティブ/アルティメット用
    public float Cooldown { get; set; }           // アクティブのクールタイム（秒）
    public int WillCost { get; set; }             // アルティメットの意志コスト
    
    // 実行スクリプト/シーンへの参照
    public string ExecutionScriptPath { get; set; }  // GDScriptパス
    public string EffectScenePath { get; set; }      // エフェクトシーン
    
    // パッシブ用
    public Dictionary<string, object> PassiveModifiers { get; set; }
}

public enum ZirPowerType
{
    Active,      // アクティブ・ジルパワー
    Ultimate,    // アルティメット・ジルパワー
    Passive      // パッシブ・ジルパワー
}
```

#### 2.2.2 データベース
- `csharp/Loadout/ZirPowerDatabase.cs`: 全ジルパワーの定義を管理
- `csharp/Loadout/CharacterDef.cs`: キャラクター定義（後述）

---

### 2.3 キャラクター定義システム

#### 2.3.1 データ構造（C#）

```csharp
// CharacterDef.cs - キャラクター定義
public class CharacterDef
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public string PortraitPath { get; set; }
    public string PlayerScenePath { get; set; }   // 専用プレイヤーシーン（将来）
    
    // 基礎ステータス修正
    public float BaseSpeed { get; set; } = 200f;
    public float BaseMaxHP { get; set; } = 100f;
    public float BaseArmor { get; set; } = 0f;
    
    // ジルパワー構成
    public List<string> ActiveZirPowers { get; set; }    // アクティブIDリスト
    public List<string> UltimateZirPowers { get; set; }  // アルティメットIDリスト（必須）
    public List<string> PassiveZirPowers { get; set; }   // パッシブIDリスト
    
    // 初期装備（オプション）
    public string StartingWeapon { get; set; }
}
```

#### 2.3.2 データベース
- `csharp/Loadout/CharacterDatabase.cs`: 全キャラクターの定義を管理

---

### 2.4 ジルパワーマネージャー

#### 2.4.1 概要
プレイヤーのジルパワー状態を管理するコンポーネント。

#### 2.4.2 実装箇所
- `csharp/Loadout/ZirPowerManager.cs`: C#でロジック管理
- `Player.gd`: GDScriptから呼び出し可能なインターフェース

#### 2.4.3 主な機能
- 現在のキャラクターのジルパワー一覧を保持
- アクティブ/アルティメットの発動可否チェック
- クールタイム管理
- 意志の消費
- パッシブ効果の適用

#### 2.4.4 C# クラス構造案

```csharp
public partial class ZirPowerManager : Node
{
    private string _currentCharacterId;
    private Dictionary<string, float> _cooldowns;  // ZirPowerId -> 残りクールタイム
    private Dictionary<string, ZirPowerInstance> _activeZirPowers;
    
    public void InitializeForCharacter(string characterId);
    public bool CanActivateZirPower(string zirPowerId);
    public void ActivateZirPower(string zirPowerId);
    public float GetCooldownProgress(string zirPowerId);
    public List<ZirPowerInstance> GetAllZirPowers();
}
```

---

### 2.5 UI設計

#### 2.5.1 HUD への追加要素

**ジルパワーボタン配置**
- **アクティブボタン**: 画面右下に横並びで配置
  - 基本は1個だが、複数ある場合は横に並べる
  - クールタイム残り時間をオーバーレイ表示
  - 使用不可時は暗転/グレーアウト
  
- **アルティメットボタン**: アクティブボタンの少し上に配置
  - ボタン内に「〇%」と表示(小数点切り捨て)
  - ゲージがボタンの中で下から上に貯まっていく視覚表現
  - 100%到達時:
    - ボタンが軽く振動(アニメーション)
    - 光るエフェクト
    - 発動可能状態に
  - 発動後は0%にリセット

**ボタンレイアウト案**
```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│                    [ULT]    │ ← アルティメット(65%表示、ゲージ付き)
│  [ジョイスティック]    [A1][A2]  │ ← アクティブ(横並び)
│                             │
└─────────────────────────────┘

A1, A2: アクティブ・ジルパワー(複数ある場合)
ULT: アルティメット・ジルパワー
```

**100%到達時の演出**
- アニメーション: ボタンが0.3秒間、軽く振動(scale変化)
- エフェクト: 光のパーティクルまたはグロー効果
- サウンド: チャージ完了SE

#### 2.5.2 新規UIコンポーネント
- `scripts/ui/ZirPowerButton.gd`: ジルパワーボタン(再利用可能)
  - アクティブ用: クールタイム表示
  - アルティメット用: %表示、ゲージ、到達演出
- `scripts/ui/CharacterSelectScreen.gd`: キャラクター選択画面(将来実装)
- `HUD.gd` に上記を統合

#### 2.5.3 キャラクター選択画面(将来実装)
- `scripts/ui/CharacterSelectScreen.gd`
- キャラクターポートレート、名前、説明
- ジルパワー一覧のプレビュー
- 選択確定ボタン

---

### 2.6 ジルパワー実行システム

#### 2.6.1 実行フロー
1. プレイヤーがUIボタンをタップ/クリック
2. `ZirPowerButton` が `ZirPowerManager.ActivateZirPower(id)` を呼び出し
3. `ZirPowerManager` が発動条件チェック（クールタイム、意志コスト）
4. GDScriptの実行関数を呼び出し、または専用シーンをインスタンス化
5. エフェクト/効果の適用
6. クールタイム/意志消費の処理

#### 2.6.2 実装パターン

**パターンA: GDScript関数ベース**
- `scripts/zirpowers/` に各ジルパワー用のスクリプトを配置
- 例: `scripts/zirpowers/FireBlast.gd`
- `execute(player: Player, target_pos: Vector2)` メソッドを実装

**パターンB: シーンベース**
- 武器システムと同様、シーンをインスタンス化
- 例: `scenes/zirpowers/FireBlast.tscn`
- プレイヤーまたはゲームワールドに追加

**推奨: ハイブリッド**
- 軽量なエフェクトはGDScript関数
- 複雑なエフェクトはシーン化
- ZirPowerDef で実行方法を指定

#### 2.6.3 実行スクリプト基底クラス

```gdscript
# scripts/zirpowers/ZirPowerBase.gd
extends Node
class_name ZirPowerBase

# 継承先で実装
func execute(player: Player, params: Dictionary) -> void:
    push_error("execute() must be implemented")

# オプション: エフェクト終了時のクリーンアップ
func cleanup() -> void:
    queue_free()
```

**ZirPowerButton での使用例**
```gdscript
# scripts/ui/ZirPowerButton.gd

func _on_button_pressed():
    if _type == ZirPowerType.Active:
        if _can_activate_active():
            player.activate_zirpower(zirpower_id)
            _start_cooldown()
    elif _type == ZirPowerType.Ultimate:
        if _can_activate_ultimate():
            player.activate_zirpower(zirpower_id)
            GameManager.consume_will_for_ultimate()

func _update_ultimate_display():
    var percent = GameManager.get_will_percent()
    _percent_label.text = "%d%%" % percent
    _gauge_fill.size.y = _gauge_bg.size.y * (percent / 100.0)
    
    # 100%到達演出
    if percent >= 100 and not _is_full_animation_playing:
        _play_full_animation()

func _play_full_animation():
    _is_full_animation_playing = true
    # 振動アニメーション
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
    # 光るエフェクト
    _glow_effect.visible = true
    # サウンド
    _play_charge_complete_sound()
```

---

## 3. 既存システムとの統合

### 3.1 GameManager への追加

```gdscript
# scripts/core/GameManager.gd に追加

# 意志システム
signal will_changed(current_percent: int)  # 0～100のパーセント値
signal will_full  # 100%到達時の通知
var will_points: int = 0
var will_max_points: int = 200  # アルティメット発動に必要なポイント（メテオストライク用）

func add_will(amount: int):
    # 既に100%に達している場合は追加しない
    if will_points >= will_max_points:
        return
    
    var old_percent = get_will_percent()
    will_points = min(will_points + amount, will_max_points)
    var new_percent = get_will_percent()
    
    if old_percent != new_percent:
        emit_signal("will_changed", new_percent)
    
    # 100%到達時の特別な通知(演出トリガー用)
    if old_percent < 100 and new_percent >= 100:
        emit_signal("will_full")

func consume_will_for_ultimate() -> bool:
    if will_points >= will_max_points:
        will_points = 0  # 100%をすべて消費して0%に
        emit_signal("will_changed", 0)
        return true
    return false

func get_will_percent() -> int:
    return int(floor(float(will_points) / float(will_max_points) * 100.0))

func is_will_full() -> bool:
    return will_points >= will_max_points

# 選択中のキャラクター(現在はイズミのみ)
var selected_character_id: String = "izumi"

func set_selected_character(character_id: String):
    selected_character_id = character_id
```

### 3.2 Enemy への追加

```gdscript
# scripts/entities/Enemy.gd にプロパティ追加
@export var will_value: int = 1  # この敵を倒した時に得られる意志ポイント

# die() メソッドに追加
func die():
    # ... 既存コード ...
    
    # 意志を付与
    if has_node("/root/GameManager"):
        get_node("/root/GameManager").add_will(will_value)
    
    # ... 既存コード ...
```

**敵ごとの will_value 設定例**:
- 通常の小型敵: 1
- 中型敵: 2～3
- ミニボス: 15
- ボス: 50～100

### 3.3 Player への追加

```gdscript
# scripts/entities/Player.gd に追加

var zirpower_manager: Node = null

func _ready():
    # ... 既存コード ...
    
    # ZirPowerManager を追加
    var ZirPowerManagerScript = load("res://csharp/Loadout/ZirPowerManager.cs")
    if ZirPowerManagerScript:
        zirpower_manager = ZirPowerManagerScript.new()
        add_child(zirpower_manager)
        var character_id = get_node("/root/GameManager").selected_character_id
        zirpower_manager.InitializeForCharacter(character_id)

# ジルパワー発動用の公開メソッド
func activate_zirpower(zirpower_id: String):
    if zirpower_manager:
        zirpower_manager.ActivateZirPower(zirpower_id)
```

### 3.4 パッシブ・ジルパワーの適用

既存の `LoadoutManager.RecomputeAndApplyPassives()` と統合するか、別システムとして独立させる。

**統合案**:
- `ZirPowerManager` がパッシブ効果を辞書形式で返す
- `Player.set_stat_modifiers()` に統合して適用

**独立案**:
- `ZirPowerManager` が独自に `Player` の変数を操作
- より柔軟だが管理が複雑

→ **推奨: 統合案**（既存システムと整合性を保つ）

---

## 4. 実装フェーズ

### フェーズ1: 基礎システム（意志とデータ構造）
**目標**: 意志システムの動作確認

1. `GameManager` に意志システムを追加
2. `Enemy` の死亡時に意志を付与
3. `HUD` に意志ゲージを追加（仮表示）
4. C# でデータ構造を定義
   - `ZirPowerDef.cs`
   - `CharacterDef.cs`
   - `ZirPowerDatabase.cs`
   - `CharacterDatabase.cs`

**検証ポイント**:
- 敵を倒すと意志が増える
- 意志%がアルティメットボタンに表示される

---

### フェーズ2: キャラクター定義とマネージャー
**目標**: イズミのジルパワー構成を管理

1. `ZirPowerManager.cs` を実装
2. イズミを定義
   - アクティブ: ダッシュ
   - アルティメット: メテオストライク
   - パッシブ: なし
3. `Player` に `ZirPowerManager` を統合
4. デバッグ用にコンソールで発動確認

**検証ポイント**:
- イズミのジルパワー構成が正しく読み込まれる
- クールタイム管理が機能する

---

### フェーズ3: UI実装(ボタンとゲージ)
**目標**: プレイヤーがボタンで発動可能にする

1. `ZirPowerButton.gd` を作成
2. `HUD` に右下配置でジルパワーボタンを追加
   - アクティブ: 右下横並び
   - アルティメット: その少し上
3. ボタンクリックで `Player.activate_zirpower()` を呼び出し
4. アクティブ: クールタイム表示とグレーアウト
5. アルティメット: %表示、ゲージ、100%到達演出

**検証ポイント**:
- ボタンを押すとジルパワーが発動する
- クールタイム中は再発動できない
- 意志が100%になると発動可能になり、ボタンが光る

---

### フェーズ4: イズミのジルパワー実装
**目標**: イズミ専用のジルパワーを作成

1. `ZirPowerBase.gd` 基底クラスを作成
2. **ダッシュ**(アクティブ)を実装
   - 効果: 短距離を瞬間移動し、無敵時間0.5秒
   - クールタイム: 10秒
   - パラメータ: 移動距離200、無敵時間0.5秒
3. **メテオストライク**(アルティメット)を実装
   - 効果: 画面全体に隕石を降らせ、全敵に大ダメージ
   - 意志コスト: 100%(200ポイント)
   - パラメータ: ダメージ300、ヒット数10、範囲全体
4. パッシブは実装しない(イズミはパッシブなし)

**検証ポイント**:
- ダッシュボタンを押すと瞬間移動+無敵が発動
- 意志が100%貯まるとメテオストライクが使用可能
- メテオストライクで画面全体にダメージ
- 100%到達後、それ以上意志は増えない

---

### フェーズ5: キャラクター選択画面(将来拡張用)
**目標**: キャラクター選択UIの基盤を作成(現在はイズミのみ)

1. `CharacterSelectScreen.gd` を実装(シンプル版)
2. イズミのキャラクター情報を表示
   - ポートレート
   - ジルパワー紹介(ダッシュ、メテオストライク)
3. 「決定」ボタンでゲーム開始
4. 将来的に複数キャラクター追加時に横スクロールで選択できる設計

**検証ポイント**:
- キャラクター選択画面が表示される
- イズミを選択してゲームが始まる
- UIが拡張可能な構造になっている

---

### フェーズ6: 調整と磨き上げ
**目標**: イズミのジルパワーをブラッシュアップ

1. 意志の獲得量調整(敵ごとの will_value バランス)
2. ダッシュとメテオストライクのパラメータ調整
3. アニメーションとエフェクトの改善
   - ダッシュの残像エフェクト
   - メテオストライクの隕石演出
   - 100%到達時の光エフェクト
4. ローカライゼーション対応(日英両方)
5. サウンドエフェクト追加

---

## 5. 技術的考慮事項

### 5.1 パフォーマンス
- ジルパワーエフェクトはオブジェクトプール可能にする
- 大量の敵を倒しても意志更新が重くならないよう配慮
- UI更新は必要最小限に抑える

### 5.2 保存データ
- キャラクター選択は `SaveDataManager` に統合
- 将来的にジルパワーのアップグレード/アンロックシステムも想定

### 5.3 テストとデバッグ
- デバッグ用のチートコマンドを用意
  - 意志を即座に満タンにする
  - クールタイムを無視する
  - 全キャラクター/ジルパワーをアンロック

### 5.4 拡張性
- ジルパワーのアップグレードシステム（将来）
- ジルパワーのシナジー効果
- キャラクター固有のパッシブとアビリティシステムの組み合わせ

---

## 6. ファイル構成（予定）

```
csharp/Loadout/
  ├── ZirPowerDef.cs              # ジルパワー定義
  ├── ZirPowerDatabase.cs         # ジルパワーデータベース
  ├── ZirPowerManager.cs          # ジルパワーマネージャー
  ├── CharacterDef.cs             # キャラクター定義
  └── CharacterDatabase.cs        # キャラクターデータベース

scripts/zirpowers/
  ├── ZirPowerBase.gd             # 基底クラス
  ├── Active/                     # アクティブ・ジルパワー
  │   ├── Dash.gd                 # ダッシュ
  │   └── ... (他のアクティブ)
  ├── Ultimate/                   # アルティメット・ジルパワー
  │   ├── MeteorStrike.gd         # メテオストライク
  │   └── ... (他のアルティメット)
  └── Passive/                    # パッシブ・ジルパワー
      └── ... (将来のパッシブ)

scripts/ui/
  ├── ZirPowerButton.gd           # ジルパワーボタン
  ├── CharacterSelectScreen.gd    # キャラクター選択画面
  └── HUD.gd                      # (既存、ジルパワーUI統合)

scenes/zirpowers/
  ├── Active/                     # アクティブ・ジルパワーシーン
  │   ├── Dash.tscn               # ダッシュシーン
  │   └── ... (他のアクティブ)
  ├── Ultimate/                   # アルティメット・ジルパワーシーン
  │   ├── MeteorStrike.tscn       # メテオストライクシーン
  │   └── ... (他のアルティメット)
  └── Passive/                    # パッシブ・ジルパワーシーン
      └── ... (将来のパッシブ)

scenes/ui/
  ├── ZirPowerButton.tscn         # ボタンシーン
  └── CharacterSelectScreen.tscn  # キャラクター選択画面

assets/zirpowers/
  ├── Active/                     # アクティブ用アイコン
  │   ├── dash_icon.png           # ダッシュアイコン
  │   └── ... (他のアクティブ)
  ├── Ultimate/                   # アルティメット用アイコン
  │   ├── meteor_strike_icon.png  # メテオストライクアイコン
  │   └── ... (他のアルティメット)
  └── Passive/                    # パッシブ用アイコン
      └── ... (将来のパッシブ)

docs/
  └── zirpower_system_planning_ja.md  # (このドキュメント)

docs/
  └── zirpower_system_planning_ja.md  # (このドキュメント)
```

---

## 7. イズミのジルパワー詳細仕様

### 7.1 キャラクター: イズミ (Izumi)

**基本情報**
- 名前: イズミ
- 説明: 機敏な動きと強力な範囲攻撃を持つバランス型キャラクター
- 初期武器: Magic Wand(マジックワンド)

**ジルパワー構成**
- アクティブ: ダッシュ × 1
- アルティメット: メテオストライク × 1
- パッシブ: なし

---

### 7.2 ダッシュ(アクティブ)

**基本情報**
- ID: `zirpower_dash`
- 名前: ダッシュ / Dash
- 種類: アクティブ・ジルパワー

**効果**
- プレイヤーの現在の向き(`_aim_dir`)に向かって瞬間移動
- 移動距離: 200ピクセル
- 移動中および移動後0.5秒間は無敵(フェーズ状態)
- 壁や障害物は無視して移動

**パラメータ**
- クールタイム: 10秒
- 移動距離: 200
- 無敵時間: 0.5秒
- ダメージ: なし(移動のみ)

**実装詳細**
```gdscript
# scripts/zirpowers/Dash.gd
func execute(player: Player, params: Dictionary) -> void:
    var direction = player.get_aim_direction()
    var distance = 200.0
    var new_pos = player.global_position + direction * distance
    
    # 瞬間移動
    player.global_position = new_pos
    
    # 無敵付与
    player.do_phase(0.5)
    
    # エフェクト: 残像、移動線など
    _spawn_dash_effect(player, direction)
```

**視覚効果**
- 移動前の位置に残像エフェクト
- 移動軌跡に光の線
- 移動後にパーティクル爆発

---

### 7.3 メテオストライク(アルティメット)

**基本情報**
- ID: `zirpower_meteor_strike`
- 名前: メテオストライク / Meteor Strike
- 種類: アルティメット・ジルパワー

**効果**
- 画面全体(または広範囲)に複数の隕石が降り注ぐ
- 各隕石は着弾地点に範囲ダメージ
- 総ヒット数10回(異なる位置にランダム配置)
- 1ヒットあたり300ダメージ

**パラメータ**
- 意志コスト: 100%(200ポイント)
- ヒット数: 10
- 1ヒットあたりダメージ: 300
- 着弾半径: 80ピクセル
- 発動時間: 2.5秒(隕石が次々降る)
- 落下間隔: 0.25秒ごと

**実装詳細**
```gdscript
# scripts/zirpowers/MeteorStrike.gd
func execute(player: Player, params: Dictionary) -> void:
    var hit_count = 10
    var damage = 300.0
    var radius = 80.0
    var interval = 0.25
    
    for i in range(hit_count):
        await get_tree().create_timer(interval * i).timeout
        _spawn_meteor(player, damage, radius)

func _spawn_meteor(player: Player, damage: float, radius: float):
    # ランダムな位置を決定(画面内、または敵の近く)
    var target_pos = _get_random_screen_position()
    
    # 隕石エフェクトを生成
    var meteor_scene = preload("res://scenes/zirpowers/MeteorEffect.tscn")
    var meteor = meteor_scene.instantiate()
    meteor.global_position = target_pos
    meteor.damage = damage
    meteor.radius = radius
    player.get_parent().add_child(meteor)
```

**視覚効果**
- 発動時: 空が一瞬暗くなる、または赤く染まる
- 隕石: 画面上部から落下するアニメーション
- 着弾: 爆発エフェクト、画面揺れ
- サウンド: 発動SE、落下音、爆発音

**戦略的用途**
- 大量の敵に囲まれた時の緊急脱出
- ボス戦での大ダメージソース
- 意志100%到達を見計らって温存・使用のタイミングを計る

---

## 8. 想定される課題と対策

### 8.1 バランス調整
- **課題**: ダッシュやメテオストライクが強すぎる/弱すぎる
- **対策**: プレイテストを重ねて意志獲得量、クールタイム、ダメージ値を調整。デバッグモードで高速検証

### 8.2 UI配置
- **課題**: モバイルで画面が狭い、ボタンが押しづらい
- **対策**: ボタンサイズを動的調整、右下配置を最適化、必要に応じてボタン位置を設定で変更可能に

### 8.3 意志の獲得バランス
- **課題**: アルティメットが使えなすぎる/使いすぎる
- **対策**: 敵ごとの will_value を調整。メテオストライクは200ポイント必要なので、1ゲームで2～3回使える程度を目安に
- **注意**: 100%到達後は意志が溢れないため、溜まったらすぐ使うか、ボス戦などのために温存するかの戦略性が生まれる

### 8.4 既存システムとの整合性
- **課題**: ジルパワーと武器/アビリティの役割が重複
- **対策**: ジルパワーは「緊急脱出」「大逆転」など特殊な用途に限定。通常戦闘は武器メイン

---

## 9. まとめ

このプランに従って段階的に実装することで、ジルパワーシステムを既存のゲームにスムーズに統合できます。

**現在の方針**:
- まずはイズミ1キャラクターのみ実装
- ダッシュとメテオストライクの2つのジルパワーに集中
- UIは右下配置、アルティメットに%表示とゲージ演出
- 敵ごとに異なる意志獲得量
- メテオストライクは200ポイント必要(100%到達で発動可能)
- 100%到達後は意志が溢れないため、戦略的に使用タイミングを判断

**次のステップ**:
1. このプランをレビュー・修正
2. フェーズ1から実装開始
3. 各フェーズごとに動作確認とフィードバック
4. イズミのジルパワーを磨き上げてから、次のキャラクター追加を検討

**重要なポイント**:
- 既存の武器/アビリティシステムを参考にしつつ、独立性を保つ
- 意志システムは%ベースで分かりやすく、上限100%でオーバーフローしない
- UI/UXはモバイルファーストで設計
- ファイル構成はActive/Ultimate/Passiveで明確に分類
- まずは1キャラクターで完成度を高め、後から拡張する設計

---

*このドキュメントは実装の進行に合わせて更新されます。*
