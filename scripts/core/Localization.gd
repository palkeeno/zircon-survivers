extends Node

signal language_changed(lang_code: String)

const LANG_JA := "ja"
const LANG_EN := "en"

# Default language is Japanese per project requirement.
var current_language: String = LANG_JA

const UI_TEXT := {
	"ui.resume": {
		LANG_JA: "ゲーム再開",
		LANG_EN: "Resume",
	},
	"ui.back_to_start": {
		LANG_JA: "スタートに戻る",
		LANG_EN: "Back to Start",
	},
	"ui.language": {
		LANG_JA: "言語",
		LANG_EN: "Language",
	},
	"ui.details": {
		LANG_JA: "詳細を見る",
		LANG_EN: "Details",
	},
	"ui.confirm": {
		LANG_JA: "決定",
		LANG_EN: "Confirm",
	},
	"ui.description": {
		LANG_JA: "説明",
		LANG_EN: "Description",
	},
	"ui.stats": {
		LANG_JA: "能力値",
		LANG_EN: "Stats",
	},
	"ui.upgrades": {
		LANG_JA: "強化",
		LANG_EN: "Upgrades",
	},
	"ui.cooldown": {
		LANG_JA: "クールダウン",
		LANG_EN: "Cooldown",
	},
	"ui.offer_upgrade": {
		LANG_JA: "強化",
		LANG_EN: "Upgrade",
	},
}

const ABILITY_TEXT := {
	# Weapons
	"weapon_magic_wand": {
		LANG_EN: {
			"name": "Magic Wand",
			"desc": "Nearest enemy targeting shots.",
			"desc_full": "Automatically fires magic shots that target the nearest enemy.",
		},
		LANG_JA: {
			"name": "マジックワンド",
			"desc": "最も近い敵を狙って弾を放つ。",
			"desc_full": "自動で最寄りの敵を狙って魔弾を発射する武器。発射数・貫通・爆発などの強化と相性が良い。",
		},
	},
	"weapon_holy_aura": {
		LANG_EN: {
			"name": "Holy Aura",
			"desc": "Damages enemies around you.",
			"desc_full": "Continuously damages enemies around you.",
		},
		LANG_JA: {
			"name": "ホーリーオーラ",
			"desc": "周囲の敵にダメージを与える。",
			"desc_full": "自分の周囲にダメージ領域を展開し、近づいた敵を継続的に削る。範囲を広げると安定しやすい。",
		},
	},
	"weapon_targeted_strike": {
		LANG_EN: {
			"name": "Targeted Strike",
			"desc": "Creates a damaging zone at a nearby enemy.",
			"desc_full": "Creates a damaging zone at a nearby enemy position.",
		},
		LANG_JA: {
			"name": "ターゲットストライク",
			"desc": "近くの敵の位置にダメージゾーンを生成する。",
			"desc_full": "周囲の敵を狙い、その足元にダメージゾーンを展開する。範囲や発動頻度を伸ばすと集団処理が得意。",
		},
	},
	"weapon_nova_burst": {
		LANG_EN: {
			"name": "Nova Burst",
			"desc": "Detonates a huge blast around you at long intervals.",
			"desc_full": "Detonates a huge blast around you. Powerful, but triggers at long intervals.",
		},
		LANG_JA: {
			"name": "ノヴァバースト",
			"desc": "長い間隔で周囲に大爆発を起こす。",
			"desc_full": "一定間隔で自身の周囲に大爆発を発生させる。発動は遅いが一掃力が高く、威力・範囲・クールダウン短縮で伸びる。",
		},
	},
	"weapon_shockwave": {
		LANG_EN: {
			"name": "Shockwave",
			"desc": "Chain lightning jumps between nearby enemies.",
			"desc_full": "Unleashes chain lightning that jumps between nearby enemies.",
		},
		LANG_JA: {
			"name": "ショックウェーブ",
			"desc": "連鎖する稲妻が近くの敵へ跳ねる。",
			"desc_full": "敵へ稲妻を放ち、近くの敵へ連鎖してダメージを与える。連鎖距離・連鎖回数を伸ばすと集団戦で強い。",
		},
	},
	"weapon_orbit_boomerang": {
		LANG_EN: {
			"name": "Comet Boomerang",
			"desc": "Boomerangs orbit around you on a comet-like path.",
			"desc_full": "Boomerangs orbit around you on a comet-like path. More boomerangs can create additional angled orbits.",
		},
		LANG_JA: {
			"name": "コメットブーメラン",
			"desc": "彗星のような軌道でブーメランが周回する。",
			"desc_full": "ブーメランが彗星のような軌道で周回し、触れた敵に継続ダメージを与える。数が増えると別角度の周回軌道が追加されることがある。",
		},
	},
	"weapon_piercing_beam": {
		LANG_EN: {
			"name": "Piercing Beam",
			"desc": "Fires a beam towards the nearest enemy.",
			"desc_full": "Fires a piercing beam towards the nearest enemy, reaching the screen edge.",
		},
		LANG_JA: {
			"name": "貫通ビーム",
			"desc": "最寄りの敵へ画面端まで届くビームを放つ。",
			"desc_full": "最寄りの敵の方向へ、画面端まで貫通するビームを発射する。幅や発射数を伸ばすと殲滅力が上がる。",
		},
	},
	"weapon_fire_bottle": {
		LANG_EN: {
			"name": "Fire Bottle",
			"desc": "Throws a bottle that leaves a burning area.",
			"desc_full": "Throws a bottle that creates a burning area on impact.",
		},
		LANG_JA: {
			"name": "ファイアボトル",
			"desc": "投擲して燃焼エリアを残す。",
			"desc_full": "ボトルを投げ、着弾地点に燃焼エリアを生成する。持続・範囲・ヒット間隔を伸ばすと足止めと削りが強化される。",
		},
	},
	"weapon_twin_claw": {
		LANG_EN: {
			"name": "Twin Claw",
			"desc": "Slashes forward and backward at the same time.",
			"desc_full": "Slashes forward and backward at the same time.",
		},
		LANG_JA: {
			"name": "ツインクロー",
			"desc": "前後同時に斬撃を放つ。",
			"desc_full": "前方と後方へ同時に斬撃を放つ近接寄りの武器。範囲や発動頻度、斬撃数の強化で手数が伸びる。",
		},
	},

	# Specials (Passive)
	"passive_might": {
		LANG_EN: {
			"name": "Might",
			"desc": "Increases all weapon damage.",
			"desc_full": "Increases all weapon damage.",
		},
		LANG_JA: {
			"name": "マイト",
			"desc": "すべての武器ダメージが上昇する。",
			"desc_full": "全武器のダメージを底上げするパッシブ。序盤から終盤まで腐りにくい。",
		},
	},
	"passive_armor": {
		LANG_EN: {
			"name": "Armor",
			"desc": "Reduces contact damage.",
			"desc_full": "Reduces contact damage taken from enemies.",
		},
		LANG_JA: {
			"name": "アーマー",
			"desc": "接触ダメージを軽減する。",
			"desc_full": "敵との接触などで受けるダメージを軽減するパッシブ。被弾が多い構成の保険になる。",
		},
	},
	"passive_vitality": {
		LANG_EN: {
			"name": "Vitality",
			"desc": "Increases max HP.",
			"desc_full": "Increases your maximum HP.",
		},
		LANG_JA: {
			"name": "バイタリティ",
			"desc": "最大HPが増える。",
			"desc_full": "最大HPを増やすパッシブ。耐久力を上げて事故死を減らす。",
		},
	},
	"passive_regen": {
		LANG_EN: {
			"name": "Regeneration",
			"desc": "Regenerates HP over time.",
			"desc_full": "Regenerates HP over time.",
		},
		LANG_JA: {
			"name": "リジェネレーション",
			"desc": "時間経過でHPが回復する。",
			"desc_full": "時間経過でHPを自動回復するパッシブ。長期戦でじわじわ効く。",
		},
	},
	"passive_haste": {
		LANG_EN: {
			"name": "Haste Matrix",
			"desc": "All weapons attack faster.",
			"desc_full": "All weapons attack faster by reducing cooldowns.",
		},
		LANG_JA: {
			"name": "ヘイストマトリクス",
			"desc": "全武器の攻撃が速くなる。",
			"desc_full": "全武器のクールダウンを短縮して攻撃頻度を上げるパッシブ。手数を増やしたい構成向け。",
		},
	},
	"passive_magnet": {
		LANG_EN: {
			"name": "Magnet",
			"desc": "Increases pickup range.",
			"desc_full": "Increases pickup range for loot and experience.",
		},
		LANG_JA: {
			"name": "マグネット",
			"desc": "回収範囲が広がる。",
			"desc_full": "経験値やドロップの回収範囲を広げるパッシブ。安全な位置取りを維持しやすくなる。",
		},
	},

	# Specials (AutoActive)
	"auto_phase": {
		LANG_EN: {
			"name": "Phase Cloak",
			"desc": "Periodically becomes untouchable for a short time.",
			"desc_full": "Periodically grants brief invincibility.",
		},
		LANG_JA: {
			"name": "フェイズクローク",
			"desc": "一定間隔で短時間無敵になる。",
			"desc_full": "一定間隔で短時間、無敵状態になる自動発動スキル。持続時間や発動頻度を伸ばすと生存力が上がる。",
		},
	},
	"auto_vacuum": {
		LANG_EN: {
			"name": "Vacuum",
			"desc": "Periodically pulls in loot from far away.",
			"desc_full": "Periodically pulls in loot from a wide area.",
		},
		LANG_JA: {
			"name": "バキューム",
			"desc": "一定間隔で遠くのドロップを引き寄せる。",
			"desc_full": "一定間隔で広範囲のドロップを引き寄せる自動発動スキル。範囲や発動頻度を伸ばすと回収が快適になる。",
		},
	},
	"auto_slow_zone": {
		LANG_EN: {
			"name": "Frost Zone",
			"desc": "Periodically creates a slow field for enemies.",
			"desc_full": "Periodically creates a frost field that slows enemies.",
		},
		LANG_JA: {
			"name": "フロストゾーン",
			"desc": "一定間隔で敵を減速させるフィールドを作る。",
			"desc_full": "一定間隔で減速フィールドを展開し、範囲内の敵の動きを鈍らせる。範囲・持続・効果量の強化で安全性が上がる。",
		},
	},
}

func _ready() -> void:
	# Ensure we start in Japanese.
	set_language(LANG_JA)

func set_language(lang_code: String) -> void:
	var normalized := lang_code
	if normalized != LANG_JA and normalized != LANG_EN:
		normalized = LANG_JA
	if current_language == normalized:
		return
	current_language = normalized
	# If later you add TranslationServer resources, this will start working automatically.
	TranslationServer.set_locale(current_language)
	emit_signal("language_changed", current_language)

func get_language() -> String:
	return current_language

func t(key: String, fallback: String = "") -> String:
	if UI_TEXT.has(key):
		var by_lang: Dictionary = UI_TEXT[key]
		if by_lang.has(current_language):
			return str(by_lang[current_language])
		if by_lang.has(LANG_EN):
			return str(by_lang[LANG_EN])
	return fallback

func ability_name(ability_id: String, fallback: String = "") -> String:
	return _ability_field(ability_id, "name", fallback)

func ability_desc(ability_id: String, fallback: String = "") -> String:
	return _ability_field(ability_id, "desc", fallback)

func ability_desc_full(ability_id: String, fallback: String = "") -> String:
	return _ability_field(ability_id, "desc_full", fallback)

func _ability_field(ability_id: String, field: String, fallback: String) -> String:
	if not ABILITY_TEXT.has(ability_id):
		return fallback
	var by_lang: Dictionary = ABILITY_TEXT[ability_id]
	var table: Dictionary = by_lang.get(current_language, by_lang.get(LANG_EN, {}))
	if table.has(field):
		return str(table[field])
	return fallback
