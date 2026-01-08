extends Node

## メテオストライク（ウルティメット）
## ランダムな位置に10個の隕石を降らせ、範囲ダメージを与える

const METEOR_COUNT: int = 10
const METEOR_DAMAGE: float = 100.0
const METEOR_RADIUS: float = 80.0

func execute(player: CharacterBody2D) -> void:
	if not player:
		print("Error: Player is null in MeteorStrike.execute")
		return
	
	print("Meteor Strike activated!")
	
	# 画面全体の範囲を取得
	var vp := player.get_viewport()
	if not vp:
		print("Error: No viewport found")
		return
	
	var screen_rect := vp.get_visible_rect()
	var cam := vp.get_camera_2d()
	var spawn_area := screen_rect
	
	if cam:
		# カメラの位置を基準に範囲を計算
		var cam_pos := cam.global_position
		var half_size := screen_rect.size * 0.5
		spawn_area = Rect2(cam_pos - half_size, screen_rect.size)
	
	# 隕石を順次生成（0.1秒間隔）
	for i in range(METEOR_COUNT):
		_spawn_meteor_delayed(player, spawn_area, i * 0.1)


func _spawn_meteor_delayed(player: CharacterBody2D, spawn_area: Rect2, delay: float) -> void:
	var timer := Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	player.add_child(timer)
	
	timer.timeout.connect(func():
		_spawn_meteor(player, spawn_area)
		timer.queue_free()
	)
	timer.start()


func _spawn_meteor(player: CharacterBody2D, spawn_area: Rect2) -> void:
	# ランダムな位置を選択
	var random_pos := Vector2(
		randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
		randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
	)
	
	# 隕石ノードを作成
	var meteor := Node2D.new()
	meteor.name = "Meteor"
	meteor.global_position = random_pos
	
	# 視覚エフェクト（赤い円）
	var visual := _create_meteor_visual()
	meteor.add_child(visual)
	
	# ゲームシーンに追加
	var game_scene := player.get_tree().current_scene
	if game_scene:
		game_scene.add_child(meteor)
		
		# 警告表示（0.3秒）→ 着弾
		_show_warning(meteor, visual)
		
		# 0.3秒後に着弾処理
		var impact_timer := Timer.new()
		impact_timer.wait_time = 0.3
		impact_timer.one_shot = true
		meteor.add_child(impact_timer)
		
		impact_timer.timeout.connect(func():
			_meteor_impact(meteor, random_pos, game_scene)
			impact_timer.queue_free()
		)
		impact_timer.start()


func _create_meteor_visual() -> Node2D:
	var container := Node2D.new()
	
	# 外側の円（警告）
	var warning_circle := _create_circle(METEOR_RADIUS, Color(1.0, 0.5, 0.0, 0.3))
	container.add_child(warning_circle)
	
	# 内側の円（コア）
	var core_circle := _create_circle(METEOR_RADIUS * 0.3, Color(1.0, 0.2, 0.0, 0.7))
	container.add_child(core_circle)
	
	return container


func _create_circle(radius: float, color: Color) -> Polygon2D:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 32
	
	for i in range(segments):
		var angle := (i / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	circle.polygon = points
	circle.color = color
	return circle


func _show_warning(meteor: Node2D, visual: Node2D) -> void:
	# 点滅アニメーション
	var game_scene := meteor.get_tree().current_scene
	if not game_scene:
		return
	
	var tween := game_scene.create_tween()
	tween.set_loops(3)
	tween.tween_property(visual, "modulate:a", 0.3, 0.1)
	tween.tween_property(visual, "modulate:a", 1.0, 0.1)


func _meteor_impact(meteor: Node2D, impact_pos: Vector2, game_scene: Node) -> void:
	# 範囲内の敵にダメージ
	var enemies := game_scene.get_tree().get_nodes_in_group("enemies")
	var hit_count := 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		
		var distance: float = enemy.global_position.distance_to(impact_pos)
		if distance <= METEOR_RADIUS:
			# ダメージを与える
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", METEOR_DAMAGE)
				hit_count += 1
			elif enemy.has_method("hit"):
				enemy.call("hit", METEOR_DAMAGE)
				hit_count += 1
	
	print("Meteor hit %d enemies at position %v" % [hit_count, impact_pos])
	
	# 着弾エフェクト（拡大して消える）
	_spawn_impact_effect(meteor, game_scene)
	
	# 隕石ノードを削除
	meteor.queue_free()


func _spawn_impact_effect(meteor: Node2D, game_scene: Node) -> void:
	# 爆発エフェクト（赤い円が拡大して消える）
	var explosion := Node2D.new()
	explosion.global_position = meteor.global_position
	
	var explosion_visual := _create_circle(METEOR_RADIUS * 0.5, Color(1.0, 0.3, 0.0, 0.8))
	explosion.add_child(explosion_visual)
	
	game_scene.add_child(explosion)
	
	var tween := game_scene.create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(2.0, 2.0), 0.3)
	tween.tween_property(explosion_visual, "modulate:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)
