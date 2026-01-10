## 物理レイヤー定数
## 
## 当たり判定のレイヤー/マスク設定に使用するビットマスク値を定義します。
## レイヤー番号 N のビットマスク値は 2^(N-1) = 1 << (N-1) です。
##
## 使用例:
##   area.collision_mask = PhysicsLayers.ENEMY
##   body.collision_layer = PhysicsLayers.WORLD
extends Node

# Layer 1: 壁、床、障害物（地形）
const WORLD: int = 1          # 1 << 0

# Layer 2: プレイヤーキャラクター
const PLAYER: int = 2         # 1 << 1

# Layer 3: 敵キャラクター
const ENEMY: int = 4          # 1 << 2

# Layer 4: プレイヤーの弾・攻撃
const PLAYER_PROJECTILE: int = 8   # 1 << 3

# Layer 5: ドロップアイテム（XP、コイン等）
const LOOT: int = 16          # 1 << 4

# Layer 6: 敵の弾・攻撃（将来用）
const ENEMY_PROJECTILE: int = 32   # 1 << 5

# Layer 7: トリガー・センサー（将来用）
const TRIGGER: int = 64       # 1 << 6

# Layer 8: ダメージ受け領域（将来用）
const HURTBOX: int = 128      # 1 << 7

## レイヤーなし（当たり判定を無効化）
const NONE: int = 0
