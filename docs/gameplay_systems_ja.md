# Zircon Survivors 現状仕様メモ（プレイヤー/敵/武器/アビリティ/レベルアップ）

このドキュメントは、現状の実装（GDScript + C#）に基づく仕様の整理です。ゲームデザインの理想形ではなく「いま動いている挙動」を優先して記載します。

- 主な実装箇所
  - プレイヤー: `scripts/entities/Player.gd`
  - 敵: `scripts/entities/Enemy.gd`
  - 経験値アイテム: `scripts/objects/XPGem.gd`
  - レベルアップUI: `scripts/ui/LevelUpScreen.gd`
  - HUD: `scripts/ui/HUD.gd`
  - ゲーム状態/ポーズ: `scripts/core/GameManager.gd`
  - ロードアウト/オファー/アビリティ定義: `csharp/Loadout/*.cs`

---

## 1. プレイヤー仕様

### 1.1 基本ステータス
`Player.gd` の代表値:

- `speed` (初期: 200.0)
- `max_hp` (初期: 100.0)
- `armor` (初期: 0.0) … 敵接触ダメージを「敵1体ごと」に減算
- `pickup_range` (初期: 50.0) … XP/loot の吸い寄せ範囲（MagnetAreaの半径）

初期値は `_base_speed/_base_max_hp/_base_pickup_range/_base_armor` に保存され、パッシブなどの再計算時に「base + 修正」で再適用されます。

### 1.2 操作と照準
- 移動入力は
  1) ジョイスティック（`_joystick.get_output()`）優先
  2) キーボード（`Input.get_vector()`）
- 直近の移動方向が `_aim_dir` として保存され、武器側が参照可能（例: `get_aim_direction()`）

### 1.3 HP / 死亡
- `current_hp` が 0 以下で死亡。
- 死亡時は `player_died` をemitし、`GameManager.trigger_game_over()` を呼び、プレイヤー自身は `queue_free()`。

### 1.4 シールド（盾スタック）
- `shield_charges` が 1 以上のとき、`take_damage()` はダメージを受けずに盾を 1 消費して終了。
- `shield_changed(charges)` シグナルでUIへ反映。

### 1.5 接触ダメージ（敵に触れている間）
プレイヤーは起動時に `Hurtbox`(Area2D) を生成して敵レイヤーと衝突し、接触中の敵を `_touching_enemies` に保持します。

- 侵入時 (`_on_hurtbox_body_entered`)
  - 即時で 1 回ダメージ
  - `dmg = enemy.damage (なければ 10.0)`
  - `take_damage(max(0, dmg - armor))`
- 継続ダメージ (`_process`)
  - 0.1 秒ごと（10 tick / sec）
  - 接触中の全敵について `max(0, enemy.damage - armor)` を合計した `total_damage` を与える

### 1.6 回復・リジェネ
- `heal(amount)` で即時回復（`max_hp`でクランプ）。
- パッシブ由来のリジェネは `_regen_per_sec` に蓄積され、`_process` 内で `current_hp += _regen_per_sec * delta`。

### 1.7 経験値取得（MagnetArea）
- 起動時に `MagnetArea`(Area2D) を生成し、Loot 레イヤー（mask=16）を検知。
- `area_entered` で対象が `collect()` を持つ場合は `area.collect(self)` を呼ぶ。
  - XPジェムは `collect()` された後、プレイヤーに向かってホーミングします（詳細は後述）。

### 1.8 “フェーズ”（無敵）
- `do_phase(duration)` により `_is_phased = true`。
- `_process` で `_phase_timer` を減算し、0以下で解除。
- フェーズ中は `take_damage()` が即 return（無敵）。

---

## 2. 敵キャラクター仕様

### 2.1 基本ステータスとAI
`Enemy.gd` の代表値:

- `speed` (初期: 100.0)
- `damage` (初期: 10.0) … プレイヤー接触ダメージ源
- `hp` (初期: 10.0) … Max HPとして扱い、`spawn()` で `current_hp = hp`

AI:
- `GameManager.player_reference` を追跡対象に保持し、`_physics_process` で単純追尾。
- ノックバック速度 `_knockback_velocity` を加算し、`knockback_drag` で 0 へ減衰。

### 2.2 被弾/死亡
- `take_damage(amount)` で `current_hp` を減算。
- 0以下で `die()`。

プール運用:
- 撃破後は `PoolManager.return_instance(self, scene_file_path)` があればプールへ返却（なければ `queue_free()`）。
- 撃破直後にプールへ戻すと「敵配下のダメージ数字」も消えるため、ダメージ数字ノードを親CanvasItem側へreparentして表示継続する処理があります。

### 2.3 ドロップ（XP/コイン/アイテム）
- XP: `xp_value` を値として `xp_gem_scene` をドロップ。
- コイン: 通常は `coin_drop_chance` (初期 5%) で 1枚。ボスは `boss_coin_drop_count` (初期 10) 枚。
- アイテム:
  - 通常敵: `item_drop_chance` (初期 0.5%) で最大1個
  - ミニボス: 1個確定
  - ボス: Magnet 1個確定 + 追加で通常確率でもう1個（Heart/Shieldのみ）

アイテム抽選重み:
- Heart: 45
- Shield: 45
- Magnet: 10（かなり低い）

---

## 3. 経験値アイテム（XPGem）

実装: `scripts/objects/XPGem.gd`

- `spawn(pos, xp_value)`
  - 座標・値をセットして当たり判定を有効化
- `collect(target)`
  - `_target` をセットし、以降 `Area2D` 自身が `_physics_process` でターゲットへホーミング
- `_physics_process`
  - `_velocity` を `move_toward(direction * speed * 2.0, speed * 5.0 * delta)` で加速
  - プレイヤー中心の半径 20px（距離二乗 < 400）に入ると `_collect()`
- `_collect()`
  - `_target.add_experience(value)` を呼ぶ
  - その後 `_despawn()` で当たり判定を無効化し、プールへ返却（なければ `queue_free()`）

---

## 4. プレイヤーレベルアップ（経験値テーブルとポーズ）

### 4.1 プレイヤーの経験値・レベル
`Player.gd`:

- `experience` 初期 0
- `level` 初期 1
- `next_level_xp` 初期 5

経験値取得:
- `add_experience(amount)`
  - `experience += amount`
  - `xp_changed(current, next)` をemit
  - `_check_level_up()`

レベルアップ判定:
- `experience >= next_level_xp` なら
  - `experience -= next_level_xp`（あふれ分は持ち越し）
  - `level += 1`
  - `next_level_xp = int(next_level_xp * 1.2) + 5`
  - `level_up(new_level)` と `xp_changed(current,next)` をemit
  - `GameManager.trigger_level_up_choice()`

連続レベルアップ:
- レベルアップ選択画面から復帰（GameManagerの `game_paused(false)`）時に `_check_level_up()` を再実行し、経験値が足りていれば連続で次のレベルアップへ進みます。

### 4.2 レベルアップ中のゲーム停止
`GameManager.gd`:

- `trigger_level_up_choice()`
  - `current_state = LEVEL_UP`
  - `get_tree().paused = true`
  - `level_up_choice_requested` をemit

`LevelUpScreen.gd`:
- `process_mode = PROCESS_MODE_ALWAYS`（ポーズ中でもUIは動く）
- `level_up_choice_requested` を受けて表示し、オファー生成
- 選択後は
  - `LoadoutManager.ApplyOffer()` を呼ぶ
  - `get_tree().paused = false`
  - `GameManager.resume_game()`

---

## 5. ロードアウト/アビリティ（C#）

### 5.1 スロット種別
- `Weapon`（武器）
- `Special`（スペシャル）
  - `Passive`（常時効果）
  - `AutoActive`（一定間隔で自動発動）

`LoadoutManager` の上限（Export）:
- `MaxWeapons = 4`
- `MaxSpecials = 4`

### 5.2 オファー（レベルアップ時の提示）生成
実装: `OfferGenerator.Generate()`

- 1回のレベルアップで `offerCount` 個（UI側は 4）提示
- ルール:
  - 最低1つは Weapon、最低1つは Special を含める
  - 空きスロットがある場合は「未所持=Acquire」「所持済=Upgrade」
  - スロットが満杯のときは Acquire できないため、Upgrade 可能なもののみが候補
  - 候補は `AbilityDatabase.Weight` による重み付き抽選
  - 同じターゲットIDの重複提示は避ける

### 5.3 “Upgrade” はランダム
`LoadoutManager.UpgradeWeapon()`:
- `AbilityInstance.LevelUp()`（レベルだけ上がる。効果は下の upgrades で決まる）
- `ApplyRandomUpgrade(rng)` で「その武器の upgradeId をランダムに 1 stack 増やす」
- 実際のパラメータ反映は `Player.apply_weapon_upgrade(abilityId, upgradeId, stacks)` に委譲

※UI上の表示も「Upgrade (random)」表記になっています。

### 5.4 パッシブ（Special/Passive）の集計と適用
`LoadoutManager.RecomputeAndApplyPassives()` が specials を走査して集計し、`Player.set_stat_modifiers(dict)` を呼びます。

現状の係数（stacks は該当upgradeIdのスタック数）:

- `passive_might` : `damageMult *= 1 + 0.07 * stacks(might_up)`
- `passive_haste` : `cooldownMult *= 1 - 0.05 * stacks(haste_up)`
  - `cooldownMult` は下限 0.2
- `passive_armor` : `armorBonus += 1.5 * stacks(armor_up)`
- `passive_vitality` : `maxHpBonus += 10.0 * stacks(hp_up)`
- `passive_regen` : `regenPerSec += 0.35 * stacks(regen_up)`
- `passive_magnet` : `magnetMult *= 1 + 0.2 * stacks(magnet_up)`

`Player.set_stat_modifiers()`:
- `armor = base_armor + armorBonus`
- `max_hp` は増減分を `current_hp` にも加算して“割合維持”に近い挙動
- `pickup_range = base_pickup_range * magnetMult`（MagnetArea半径にも反映）
- 武器側には `owner_damage_mult` と `owner_cooldown_mult` を注入

### 5.5 AutoActive（Special/AutoActive）
`LoadoutManager._Process` でポーズ中は停止し、`TickAutoActives(delta)` を回します。

- 発動間隔（クールダウン）
  - ベース: `AbilityDef.BaseCooldownSec`
  - upgrade `cd_down` を持つ場合: `cd *= 0.92^stacks(cd_down)`
  - 最小: 3秒
  - さらに `passive_haste` により `cooldownMult *= 1 - 0.05*stacks(haste_up)`（下限0.2）

発動時の Player 側呼び出し:
- `auto_phase` → `Player.do_phase(duration)`
- `auto_vacuum` → `Player.do_vacuum(radius)`
- `auto_slow_zone` → `Player.do_slow_zone(radius, slowStrength, zoneDuration)`

`auto_slow_zone` は対象敵の `speed` を一時的に書き換え、Timerで元に戻します（敵側に `base_speed` meta がない場合は保存します）。

---

## 6. 武器（Weapon）とアップグレード反映

### 6.1 武器基底クラス
`Weapon.gd`:

- 代表パラメータ
  - `cooldown`, `damage`
  - `shots_per_fire`, `projectile_scale`, `projectile_pierce`, `projectile_explosion_radius`
- プレイヤー由来の乗算
  - `owner_damage_mult`（パッシブMight等）
  - `owner_cooldown_mult`（パッシブHaste等）
- 発射
  - `_process` で cooldown が空いたら `_try_shoot()`（各武器でoverride）
  - クールダウン実効値は `cooldown * owner_cooldown_mult`

### 6.2 “武器強化”の適用方式（重要）
`Player.apply_weapon_upgrade()` は、武器ノードに保存した `base_*` 値から「スタック数に応じて決定論的に再計算」して反映します。

- 例: ダメージ上昇が複利（`pow(1.1, stacks)`）の場合、
  - 1回強化→ +10%
  - 2回強化→ +21%（base×1.1×1.1）

### 6.3 武器一覧（AbilityDatabase定義）と強化の実数式

#### Magic Wand (`weapon_magic_wand`)
- シーン: `res://scenes/weapons/MagicWand.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `count_up`: `shots_per_fire = base_shots + stacks`
  - `size_up`: `projectile_scale = base_scale * 1.08^stacks`
  - `pierce_up`: `projectile_pierce = base_pierce + stacks`
  - `explosion`: `projectile_explosion_radius = 70`（stacks>0のとき）

#### Holy Aura (`weapon_holy_aura`)
- シーン: `res://scenes/weapons/HolyAura.tscn`
- 強化:
  - `radius_up`: `aura_radius = base_radius * 1.12^stacks`

#### Targeted Strike (`weapon_targeted_strike`)
- シーン: `res://scenes/weapons/TargetedStrike.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `radius_up`: `strike_radius = base_radius * 1.08^stacks`
  - `count_up`: `strikes_per_fire = base_count + stacks`

#### Nova Burst (`weapon_nova_burst`)
- シーン: `res://scenes/weapons/NovaBurst.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.13^stacks`
  - `cd_down`: `cooldown = max(0.25, base_cd * 0.92^stacks)`
  - `radius_up`: `nova_radius = base_radius * 1.08^stacks`

#### Shockwave (`weapon_shockwave`)
- シーン: `res://scenes/weapons/Shockwave.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `range_up`: `start_range/chain_range = base * 1.08^stacks`
  - `jumps_up`: `max_jumps = base_jumps + stacks`
  - `fork`: `forks = clamp(base_forks + stacks, 0..2)`

#### Comet Boomerang (`weapon_orbit_boomerang`)
- シーン: `res://scenes/weapons/OrbitBoomerang.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `count_up`: `boomerang_count = base_count + stacks`
  - `radius_up`: `semi_major = base_a * 1.08^stacks`
  - `speed_up`: `angular_speed = base_speed * 1.10^stacks` / `orbit_rotation_speed = base_rot * 1.08^stacks`
  - `tick_up`: `tick_interval = max(0.05, base_tick * 0.90^stacks)`

#### Piercing Beam (`weapon_piercing_beam`)
- シーン: `res://scenes/weapons/PiercingBeam.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `width_up`: `beam_width = base_w * 1.08^stacks`
  - `bounce_up`: `max_bounces = base_bounces + stacks`
  - `count_up`: `beams_per_fire = base_cnt + stacks`

#### Fire Bottle (`weapon_fire_bottle`)
- シーン: `res://scenes/weapons/FireBottle.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `radius_up`: `burn_radius = base_radius * 1.08^stacks`
  - `duration_up`: `burn_duration = base_dur * 1.10^stacks`
  - `tick_up`: `burn_tick_interval = max(0.05, base_tick * 0.90^stacks)`
  - `count_up`: `bottles_per_fire = base_cnt + stacks`

#### Twin Claw (`weapon_twin_claw`)
- シーン: `res://scenes/weapons/TwinClaw.tscn`
- 強化:
  - `dmg_up`: `damage = base_damage * 1.1^stacks`
  - `cd_down`: `cooldown = max(0.05, base_cd * 0.92^stacks)`
  - `radius_up`: `claw_radius = base_radius * 1.08^stacks`
  - `count_up`: `slashes_per_fire = base_cnt + stacks`

---

## 7. スペシャル（Special）一覧（AbilityDatabase）

### 7.1 Passive
- Might (`passive_might`) : 全武器ダメージ増加（LoadoutManagerが `damage_mult` として注入）
- Haste Matrix (`passive_haste`) : 全武器CD短縮（`cooldown_mult`。下限0.2あり）
- Armor (`passive_armor`) : 接触ダメージ軽減（`armor` に加算）
- Vitality (`passive_vitality`) : 最大HP増加
- Regeneration (`passive_regen`) : 毎秒回復
- Magnet (`passive_magnet`) : `pickup_range` 増加（MagnetArea半径拡大）

### 7.2 AutoActive
- Phase Cloak (`auto_phase`) : 一定間隔で無敵（フェーズ）
- Vacuum (`auto_vacuum`) : 一定間隔で範囲内のlootを `collect()` させて吸い寄せ
- Frost Zone (`auto_slow_zone`) : 一定間隔で範囲内の敵の `speed` を減衰し、一定時間後に復帰

---

## 8. UI上の見え方（参考）

- HUD は `Player` の `hp_changed/xp_changed/level_up/shield_changed` と `LoadoutManager.LoadoutChanged` を購読し、HP/XP/LV/装備アイコンを更新。
- レベルアップ画面は C# から生成されたオファーをそのままボタン化し、押下で `ApplyOffer` を呼び出します。

---

## 付録: 「どこを直すと仕様が変わるか」早見

- 経験値テーブル（必要XPの増え方）: `Player._check_level_up()`
- レベルアップ時ポーズ: `GameManager.trigger_level_up_choice()`
- オファーの出し方/重み: `OfferGenerator.Generate()` と `AbilityDatabase.Weight`
- どのアップグレードがあるか/上限: `AbilityDatabase` と `UpgradeDef.MaxStacks`
- アップグレードが何を変えるか（数式）: `Player.apply_weapon_upgrade()` と各 `_apply_*_upgrade()`
- パッシブの係数: `LoadoutManager.RecomputeAndApplyPassives()`
- AutoActive の効果: `LoadoutManager.TriggerAutoActive()` と `Player.do_*()`
