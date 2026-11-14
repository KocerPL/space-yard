extends Control

@onready var box = $DialogBox

@onready var btn1 = $Button
@onready var btn2 = $Button2
@onready var btn3 = $Button3

@onready var next_line_btn = $NextLine

func _ready():
	btn1.pressed.connect(btn_1_press)
	btn2.pressed.connect(btn_2_press)
	btn3.pressed.connect(btn_3_press)
	
	next_line_btn.pressed.connect(next_line)

func next_line():
	box.next_line()

func btn_1_press():
	box.start_dialog("test")

func btn_2_press():
	box.start_dialog("test 2")

func btn_3_press():
	box.start_dialog("invalid text")
