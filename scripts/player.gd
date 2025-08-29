extends CharacterBody2D

@export var move_speed = 120.0
@export var jump_sideway_speed = 250.0
@export var max_jump_charge = 1.5
@export var min_jump_force = 100.0
@export var max_jump_force = 700.0
@export var shake_intensity = 2.0  # Screen shake strength

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $sounds/jump_sound
@onready var land_sound: AudioStreamPlayer2D = $sounds/land_sound
@onready var bump_sound: AudioStreamPlayer2D = $sounds/bump_sound


@onready var left_ray_cast_2d: RayCast2D = $Node/LeftRayCast2D
@onready var right_ray_cast_2d: RayCast2D = $Node/RightRayCast2D

@onready var charge_particles: CPUParticles2D = $particles/charge_particles
@onready var land_particles: CPUParticles2D = $particles/land_particles

@onready var camera: Camera2D = get_viewport().get_camera_2d()  # Get current camera
@export var min_wall_bounce_force := 1.0
@export var max_wall_bounce_force := 2.5
@export var wall_bounce_vertical_boost := 300.0  # Extra upward force when bouncing off walls

var jump_charge = 0.0
var is_charging = false
var locked_direction = 0
var was_on_floor = true


var consecutive_bounces := 0
var last_bounce_time := 0.0
var bounce_cooldown := 0.1  # Seconds between bounce effects



func _physics_process(delta):
	# Apply gravity
	velocity.y += 1000.0 * delta
	
	# Handle charging jump
	if Input.is_action_pressed("jump") and is_on_floor():
		if not is_charging:
			start_charging()
		
		jump_charge = min(jump_charge + delta*3, max_jump_charge)
		velocity.x = 0
		# Update the locked direction continuously while charging
		locked_direction = Input.get_axis("left", "right")
		update_charge_effect()  # Visual/audio feedback
	
	# Release jump
	elif Input.is_action_just_released("jump") and is_charging:
		release_jump()
	
	# Normal movement
	elif is_on_floor() and not is_charging:
		handle_movement()
	
	# Simple wall/obstacle collision - just reverse x direction
	if not is_on_floor():
		detect_wall_collisions(delta)	
	# Move the character
	move_and_slide()
	
	# Landing detection
	var now_on_floor = is_on_floor()
	if not was_on_floor and now_on_floor:
		land()
	was_on_floor = now_on_floor
	
	update_animations()

func detect_wall_collisions(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Only check for bounces if we're not in cooldown
	if current_time - last_bounce_time > bounce_cooldown:
		var test_distance = max(10, abs(velocity.x) * delta * 0.5)
		var collision = move_and_collide(Vector2(test_distance * sign(velocity.x), 0), true)
		
		if collision:
			var normal = collision.get_normal()
			if abs(normal.x) > 0.7:  # Wall collision
				consecutive_bounces += 1
				last_bounce_time = current_time
				
				# Calculate decay factor (reduces bounce strength after multiple bounces)
				var bounce_decay = clamp(1.0 - (consecutive_bounces * 0.3), 0.3, 1.0)
				
				# Dynamic bounce force with decay
				var charge_ratio = jump_charge / max_jump_charge
				var bounce_force = lerp(1.0, 1.8, charge_ratio) * bounce_decay
				
				locked_direction = sign(normal.x)
				velocity.x = locked_direction * jump_sideway_speed * bounce_force
				
				# Add slight vertical stabilization
				velocity.y = min(velocity.y, -50 * bounce_decay)
				
				# Visual feedback scaled by bounce strength
				screen_shake(0.1 * bounce_force)
				bump_sound.global_position = global_position
				bump_sound.play()
				
	else:
		# Reset bounce count if we haven't bounced recently
		if current_time - last_bounce_time > 1.0:
			consecutive_bounces = 0



func start_charging():
	charge_particles.global_position = global_position
	is_charging = true
	locked_direction = Input.get_axis("left", "right")
	animated_sprite.play("charge")
	charge_particles.emitting = true

func release_jump():
	var jump_power = lerp(min_jump_force, max_jump_force, jump_charge / max_jump_charge)
	velocity.y = -jump_power
	velocity.x = locked_direction * jump_sideway_speed
	jump_sound.global_position = global_position  # Sync with player
	jump_sound.play()
	screen_shake(jump_charge * 0.3)
	animated_sprite.play("jump")
	charge_particles.emitting = false
	jump_charge = 0.0
	is_charging = false


func handle_movement():
	var direction = Input.get_axis("left", "right")
	velocity.x = direction * move_speed

func land():
	land_sound.global_position = global_position
	land_sound.play()
	land_particles.global_position = global_position
	land_particles.emitting = true
	screen_shake(0.2)
	animated_sprite.scale.x = 1.0 
	animated_sprite.scale.y = 1.0 
	animated_sprite.play("land")

func update_animations():
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif is_charging:
		animated_sprite.play("charge")
	elif abs(velocity.x) > 0:
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x < 0
	else:
		animated_sprite.play("idle")

func screen_shake(duration: float = 0.1):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	var strength = shake_intensity * jump_charge
	var original_offset = camera.offset
	
	for i in range(3):
		camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength))
		await get_tree().create_timer(duration / 3.0).timeout
	
	camera.offset = original_offset

func update_charge_effect():
	animated_sprite.scale.x = 1.0 + jump_charge * 0.2
	animated_sprite.scale.y = 1.0 - jump_charge * 0.1
	charge_particles.speed_scale = 1.0 + jump_charge * 2.0
