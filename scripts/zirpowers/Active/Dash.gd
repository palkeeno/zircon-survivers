extends Node

## ダッシュスキル
## プレイヤーを瞬間移動させ、0.5秒間無敵にする

func execute(player: CharacterBody2D) -> void:
	if not player:
		print("Error: Player is null in Dash.execute")
		return
	
	# 移動方向を取得（現在の入力方向）
	# Playerと同じ入力システム（ui_left/right/up/down）を使用
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# ジョイスティック入力も考慮
	if direction.length_squared() < 0.01:
		# Playerの_joystickを取得
		var joystick = player.get("_joystick")
		if joystick and joystick.has_method("get_output"):
			direction = joystick.call("get_output")
	
	# 入力がない場合は現在の向き（velocity）を使用
	if direction.length_squared() < 0.01:
		if player.velocity.length_squared() > 0.01:
			direction = player.velocity.normalized()
		else:
			# 向きも速度もない場合は右向きにダッシュ
			direction = Vector2.RIGHT
	
	direction = direction.normalized()
	
	# ダッシュ距離
	var dash_distance: float = 200.0
	var new_position := player.global_position + direction * dash_distance
	
	# 画面外に出ないようにクランプ
	var vp := player.get_viewport()
	if vp:
		var screen_rect := vp.get_visible_rect()
		var cam := player.get_viewport().get_camera_2d()
		if cam:
			var cam_pos := cam.global_position
			var half_size := screen_rect.size * 0.5
			new_position.x = clampf(new_position.x, cam_pos.x - half_size.x + 20.0, cam_pos.x + half_size.x - 20.0)
			new_position.y = clampf(new_position.y, cam_pos.y - half_size.y + 20.0, cam_pos.y + half_size.y - 20.0)
	
	# 瞬間移動
	player.global_position = new_position
	
	# 無敵状態を付与（0.5秒）
	_grant_invincibility(player, 0.5)
	
	# エフェクト（簡易的な残像）
	_spawn_dash_effect(player)
	
	print("Dash executed! New position: ", new_position)


func _grant_invincibility(player: CharacterBody2D, duration: float) -> void:
	# Playerに無敵状態フラグがあればそれを使用
	if "is_invincible" in player:
		player.is_invincible = true
	
	# 視覚的フィードバック（点滅）
	var original_modulate := player.modulate
	player.modulate = Color(0.5, 0.5, 1.0, 0.7)
	
	# タイマーで無敵解除
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	player.add_child(timer)
	timer.timeout.connect(func():
		if "is_invincible" in player:
			player.is_invincible = false
		player.modulate = original_modulate
		timer.queue_free()
	)
	timer.start()


func _spawn_dash_effect(player: CharacterBody2D) -> void:
	# 簡易的な残像エフェクト
	# Sprite2D または AnimatedSprite2D を探す
	var sprite = player.get_node_or_null("Sprite2D")
	var animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	
	var ghost: Node2D = null
	
	if sprite and sprite is Sprite2D:
		ghost = Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.scale = sprite.scale
	elif animated_sprite and animated_sprite is AnimatedSprite2D:
		# AnimatedSprite2Dの場合は現在のフレームのテクスチャを取得
		var sprite_frames = animated_sprite.sprite_frames
		if sprite_frames:
			var anim_name = animated_sprite.animation
			if sprite_frames.has_animation(anim_name):
				var frame_idx = animated_sprite.frame
				var frame_texture = sprite_frames.get_frame_texture(anim_name, frame_idx)
				if frame_texture:
					var ghost_sprite = Sprite2D.new()
					ghost_sprite.texture = frame_texture
					ghost_sprite.scale = animated_sprite.scale
					ghost = ghost_sprite
	
	if not ghost:
		# スプライトがない場合は色付きの円で代用
		ghost = Node2D.new()
		var circle = ColorRect.new()
		circle.size = Vector2(40, 40)
		circle.position = Vector2(-20, -20)
		circle.color = Color(0.5, 0.5, 1.0, 0.5)
		ghost.add_child(circle)
	
	ghost.global_position = player.global_position
	ghost.modulate = Color(0.5, 0.5, 1.0, 0.5)
	
	# ゲームシーンに追加
	var game_scene = player.get_tree().current_scene
	if game_scene:
		game_scene.add_child(ghost)
		
		# フェードアウトして消す
		var tween := game_scene.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tween.tween_callback(ghost.queue_free)
