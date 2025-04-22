extends Node

func use_auto_layout(scene_to_ignore):
	var scenes = SB.storyboard_view.container.get_children()
	
	var scenes_to_ignore = []
	
	for node in SB.storyboard_view.multiselect.selected:
		if node.parent is SBScene:
			scenes_to_ignore.append(node.parent)
	
	var iterations = 2
	for i in range(iterations):
		var forces = {}
		for scene in scenes:
			forces[scene] = Vector2.ZERO
			
			for scene2 in scenes:
				if scene != scene2:
					forces[scene] += calculate_repulsive_force(scene, scene2)
					
			for jump in scene.sb_jumps_container.get_children():
				var scene2 = jump.jump_to
				forces[scene] += calculate_attractive_force(scene, scene2)
		
			for scene3 in scenes:
				if scene3 != scene:
					for jump in scene3.sb_jumps_container.get_children():
						if jump.jump_to == scene:
							forces[scene] += calculate_attractive_force(scene, scene3)
		
		for scene in scenes:
			if scene in scenes_to_ignore:
				continue
			scene.position += forces[scene] * 0.05
	
	for scene in scenes:
		for jump in scene.sb_jumps_container.get_children():
			jump.check_and_adjust_border_points(true)
	
	for scene in SB.storyboard_view.container.get_children():
		scene.request_update()
		for jump in scene.sb_jumps_container.get_children():
			jump.request_update()

func apply_auto_layout(on_all=false):
	var container = SB.storyboard_view.container
	
	var scenes = container.get_children()
	var scenes_for_layout = []
	
	var start_positions = []
	var end_positions = []
	var position = Vector2(0, 0)
	var spacing = Vector2(500, 250)
	var columns = max(int(scenes.size()/2), 1)
	for i in range(scenes.size()-1, -1, -1):
		if scenes[i].position == Vector2.ZERO or check_pos_against_other_scenes(scenes[i]):
			scenes[i].position = position
			scenes_for_layout.append(scenes[i])
		position.x += spacing.x
		if (i + 1) % columns == 0:
			position.x = 0
			position.y += spacing.y
	
	if on_all:
		scenes_for_layout = scenes
	
	for scene in scenes_for_layout:
		end_positions.append(scene.position)
		start_positions.append(scene.position)
	
	var iterations = 1000
	for i in range(iterations):
		var forces = {}
		for scene in scenes_for_layout:
			forces[scene] = Vector2.ZERO
			
			for scene2 in scenes:
				if scene != scene2:
					forces[scene] += calculate_repulsive_force(scene, scene2)
					
			for jump in scene.sb_jumps_container.get_children():
				var scene2 = jump.jump_to
				forces[scene] += calculate_attractive_force(scene, scene2)
		
			for scene3 in scenes:
				if scene3 != scene:
					for jump in scene3.sb_jumps_container.get_children():
						if jump.jump_to == scene:
							forces[scene] += calculate_attractive_force(scene, scene3)
		
		var j = 0
		for scene in scenes_for_layout:
			end_positions[j] += forces[scene] * 0.05
			j += 1
			scene.position += forces[scene] * 0.05
	
	var tween = SB.create_tween()
	var i = 0
	for scene in scenes_for_layout:
		scene.position = start_positions[i]
		tween.parallel().tween_property(scene, "position", end_positions[i], 1.5)
		i += 1
	tween.tween_callback(on_layout_animation_complete)

func on_layout_animation_complete():
	for scene in SB.storyboard_view.container.get_children():
		for jump in scene.sb_jumps_container.get_children():
			jump.check_and_adjust_border_points(true)
	
	for scene in SB.storyboard_view.container.get_children():
		scene.request_update()
		for jump in scene.sb_jumps_container.get_children():
			jump.request_update()

func calculate_repulsive_force(scene1, scene2) -> Vector2:
	var direction = scene1.position - scene2.position
	var distance = direction.length()
	
	if distance == 0:
		distance = 0.1
	
	var max_repulsion_distance = 450
	if distance > max_repulsion_distance:
		return Vector2.ZERO
	
	var repulsion_constant = 40000
	var force_magnitude = (repulsion_constant / distance) * pow((max_repulsion_distance - distance) / max_repulsion_distance, 2)
	force_magnitude = min(force_magnitude, 70)
	var repulsive_force = direction.normalized() * force_magnitude
	
	return repulsive_force

func calculate_attractive_force(scene1, scene2) -> Vector2:
	var direction = scene2.position - scene1.position
	var distance = direction.length()
	var ideal_distance = 350
	
	var attractive_force = direction.normalized() * (distance - ideal_distance)
	
	return attractive_force

func check_pos_against_other_scenes(scene_to_check):
	var container = SB.storyboard_view.container
	var scenes = container.get_children()
	for scene in scenes:
		if scene == scene_to_check:
			continue
		
		if scene.position == scene_to_check.position:
			return true
	
	return false
