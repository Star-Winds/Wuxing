extends Control

@onready var formation_name_label: Label = $CenterContainer/VBoxContainer/FormationNameLabel
@onready var formation_color_rect: ColorRect = $CenterContainer/VBoxContainer/FormationColorRect
@onready var description_label: Label = $CenterContainer/VBoxContainer/DescriptionLabel
@onready var accept_button: Button = $CenterContainer/VBoxContainer/AcceptButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var _formation: FormationData

func _ready() -> void:
	_formation = preload("res://Resources/Formations/base_formation.tres")
	if not _formation:
		push_error("BossRewardUI: 阵法资源未找到！")
		accept_button.text = "继续"
		return

	title_label.text = "获得五行阵法"
	formation_name_label.text = _formation.formation_name
	description_label.text = _formation.description

	formation_color_rect.color = _formation.element_color
	modulate = Color.WHITE

	accept_button.pressed.connect(_on_accept_pressed)


func _on_accept_pressed() -> void:
	GameManager.active_formation = _formation
	print("【BossReward】获得阵法: ", _formation.formation_name)

	GameManager.current_world += 1
	GameManager.generate_new_world()

	if GameManager.current_world > 3:
		GameManager.switch_to_scene(GameManager.game_win_scene)
	else:
		GameManager.switch_to_scene(GameManager.map_scene)
