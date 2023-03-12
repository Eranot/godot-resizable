@tool
extends Control

enum HANDLE {
	TOP = 1, 
	BOTTOM = 2, 
	LEFT = 4, 
	RIGHT = 8, 
	TOP_LEFT = 16, 
	TOP_RIGHT = 32, 
	BOTTOM_LEFT = 64, 
	BOTTOM_RIGHT = 128
} 

enum MODE {
	SIZE, MINIMUM_SIZE
}

## Whether the resizing behaviour is active or not
@export 
var active: bool = true

## Resize mode. If set to SIZE, the parent node's size will be changed and position may also change. 
## If set to MINIMUM_SIZE, the parent node's minimum size will be changed. Position will not be changed.
@export 
var mode: MODE = MODE.SIZE

## Thickness of the line where the mouse has to be to be able to start the resizing
@export 
var border_width: int = 6

## Minimum size that the parent node will be
@export 
var min_size: Vector2 = Vector2(0, 0)

## Maximum size that the parent node will be
@export 
var max_size: Vector2 = Vector2(0, 0)

## Keeps the parent from being resized beyond the viewport.
@export
var clamp_to_viewport: bool = false

## Whether each of the handles are active or not
@export_flags("TOP", "BOTTOM", "LEFT", "RIGHT", "TOP_LEFT", "TOP_RIGHT", "BOTTOM_LEFT", "BOTTOM_RIGHT") 
var active_handles = 255

var initial_resize_position = null
var initial_parent_size = null
var initial_parent_position = null
var handle_being_resized = null

@onready var parent = get_parent()


func _enter_tree():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent):
	if not active:
		return
	
	if event is InputEventMouseMotion:
		_on_mouse_move(event)
			
	elif event is InputEventMouseButton:
		_on_mouse_click(event)


func _on_mouse_move(event):
	var handle = handle_being_resized if handle_being_resized != null else get_hovered_handle()
		
	if handle != null:
		var is_handle_active = active_handles & handle
		if not is_handle_active:
			return
	
	if(handle == HANDLE.TOP_LEFT or handle == HANDLE.BOTTOM_RIGHT):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_FDIAGSIZE)
		get_viewport().set_input_as_handled()
	elif(handle == HANDLE.BOTTOM_LEFT or handle == HANDLE.TOP_RIGHT):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BDIAGSIZE)
		get_viewport().set_input_as_handled()
	elif(handle == HANDLE.TOP or handle == HANDLE.BOTTOM):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_VSIZE)
		get_viewport().set_input_as_handled()
	elif(handle == HANDLE.LEFT or handle == HANDLE.RIGHT):
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_HSIZE)
		get_viewport().set_input_as_handled()
	
	if(initial_resize_position): # If the resizing is in progress
		if(mode == MODE.SIZE):
			parent.size = _get_new_size(parent.size)
			parent.position = _get_new_position(parent.position, parent.size)
		elif(mode == MODE.MINIMUM_SIZE):
			parent.custom_minimum_size = _get_new_size(parent.custom_minimum_size)


func _on_mouse_click(event):
	var handle = get_hovered_handle()
		
	if handle != null:
		var is_handle_active = active_handles & handle
		if not is_handle_active:
			return
	
	if event.is_pressed() and handle != null and not initial_resize_position:
		initial_resize_position = get_global_mouse_position()
		initial_parent_size = parent.size if mode == MODE.SIZE else parent.custom_minimum_size
		initial_parent_position = parent.position
		handle_being_resized = handle
	elif not event.is_pressed():
		initial_resize_position = null
		handle_being_resized = null


# Returns the new position of the parent node, based on the mouse position
func _get_new_size(size: Vector2):
	var new_size = size
		
	var is_corner_active = active_handles & handle_being_resized
	if not is_corner_active:
		return new_size
	
	if handle_being_resized == HANDLE.BOTTOM_RIGHT:
		new_size = initial_parent_size + (_get_mouse_position() - initial_resize_position)
	elif handle_being_resized == HANDLE.TOP_LEFT:
		new_size = initial_parent_size - (_get_mouse_position() - initial_resize_position)
	elif handle_being_resized == HANDLE.TOP_RIGHT:
		var x = initial_parent_size.x + (_get_mouse_position().x - initial_resize_position.x)
		var y = initial_parent_size.y - (_get_mouse_position().y - initial_resize_position.y)
		new_size = Vector2(x, y)
	elif handle_being_resized == HANDLE.BOTTOM_LEFT:
		var x = initial_parent_size.x - (_get_mouse_position().x - initial_resize_position.x)
		var y = initial_parent_size.y + (_get_mouse_position().y - initial_resize_position.y)
		new_size = Vector2(x, y)
	elif handle_being_resized == HANDLE.LEFT:
		var x = initial_parent_size.x - (_get_mouse_position().x - initial_resize_position.x)
		new_size = Vector2(x, new_size.y)
	elif handle_being_resized == HANDLE.RIGHT:
		var x = initial_parent_size.x + (_get_mouse_position().x - initial_resize_position.x)
		new_size = Vector2(x, new_size.y)
	elif handle_being_resized == HANDLE.BOTTOM:
		var y = initial_parent_size.y + (_get_mouse_position().y - initial_resize_position.y)
		new_size = Vector2(new_size.x, y)
	elif handle_being_resized == HANDLE.TOP:
		var y = initial_parent_size.y - (_get_mouse_position().y - initial_resize_position.y)
		new_size = Vector2(new_size.x, y)
	
	return _respect_min_max_size(new_size)

func _get_mouse_position() -> Vector2:
	return get_global_mouse_position().clamp(Vector2.ZERO,\
		get_viewport_rect().size) if clamp_to_viewport else get_global_mouse_position()

# Returns the new position of the parent node, based on the new size of the parent node and in which handle is being resized
func _get_new_position(position: Vector2, size: Vector2):
	if handle_being_resized == HANDLE.TOP_LEFT or handle_being_resized == HANDLE.LEFT:
		position = initial_parent_position - (size - initial_parent_size)
	elif handle_being_resized == HANDLE.TOP_RIGHT or handle_being_resized == HANDLE.RIGHT or  handle_being_resized == HANDLE.TOP:
		var x = initial_parent_position.x
		var y = initial_parent_position.y - (size.y - initial_parent_size.y)
		position = Vector2(x, y)
	elif handle_being_resized == HANDLE.BOTTOM_LEFT:
		var x = initial_parent_position.x - (size.x - initial_parent_size.x)
		var y = initial_parent_position.y
		position = Vector2(x, y)
	
	return position


# Returns the handle that is hovered by the mouse. If the mouse is not hovering any handle, returns null.
func get_hovered_handle():
	var mouse_position: Vector2 = get_global_mouse_position()
	var is_near_y_top = _is_near(mouse_position.y, parent.global_position.y)
	var is_near_x_left = _is_near(mouse_position.x, parent.global_position.x)
	var is_near_y_bottom = _is_near(mouse_position.y, parent.global_position.y + parent.get_global_rect().size.y)
	var is_near_x_right = _is_near(mouse_position.x, parent.global_position.x + parent.get_global_rect().size.x)
	
	if is_near_y_top and is_near_x_left:
		return HANDLE.TOP_LEFT
		
	if is_near_y_bottom and is_near_x_left:
		return HANDLE.BOTTOM_LEFT
	
	if is_near_y_top and is_near_x_right:
		return HANDLE.TOP_RIGHT
		
	if is_near_y_bottom and is_near_x_right:
		return HANDLE.BOTTOM_RIGHT
	
	var is_inside_container = mouse_position.x >= parent.global_position.x - border_width \
		and mouse_position.x <= parent.global_position.x + parent.size.x + border_width \
		and mouse_position.y >= parent.global_position.y - border_width \
		and mouse_position.y <= parent.global_position.y + parent.size.y + border_width
	
	if is_near_y_top and is_inside_container:
		return HANDLE.TOP
		
	if is_near_y_bottom and is_inside_container:
		return HANDLE.BOTTOM
		
	if is_near_x_left and is_inside_container:
		return HANDLE.LEFT
		
	if is_near_x_right and is_inside_container:
		return HANDLE.RIGHT
	
	return null


# Returns if the values are near eachother, based on the border_width
func _is_near(value1, value2):
	return abs(value1 - value2) <= border_width


# Returns the new size, respecting the min and max size
func _respect_min_max_size(new_size):
	if(min_size.x != 0 and new_size.x < min_size.x):
		new_size.x = min_size.x
	if(min_size.y != 0 and new_size.y < min_size.y):
		new_size.y = min_size.y
	if(max_size.x != 0 and new_size.x > max_size.x):
		new_size.x = max_size.x
	if(max_size.y != 0 and new_size.y > max_size.y):
		new_size.y = max_size.y
	
	return new_size
