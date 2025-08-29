extends Node2D

# --- Particles (Only CPU) ---
@onready var particles: Array[CPUParticles2D] = [
	$finish/green,
	$finish/yellow,
	$finish/red
	# Add more CPUParticles2D here if needed
]

# --- Labels ---
@onready var finish_labels: Array[Label] = [
	$labels/finish,
	$labels/finish2
]

# --- Audio ---
@onready var end_music: AudioStreamPlayer2D = $"PhantomCamera2D/music/end music"
@onready var background_music: AudioStreamPlayer2D = $"PhantomCamera2D/music/background music"

var tween_duration: float = 0.5

func _ready():
	# Hide all labels at start
	for label in finish_labels:
		label.modulate = Color.TRANSPARENT
	
	# Play background music if not already playing
	if not background_music.playing:
		background_music.play()

func _on_area_2d_body_entered(body: Node2D):
	if body.is_in_group("player"):
		# Stop background music, play finish music
		background_music.stop()
		end_music.play()
		
		# Emit all CPU particles
		for particle in particles:
			particle.emitting = true
		
		# Fade in all labels (simultaneously)
		var tween = create_tween()
		for label in finish_labels:
			tween.parallel().tween_property(label, "modulate", Color.WHITE, tween_duration)
