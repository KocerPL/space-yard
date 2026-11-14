class_name MissionEvent
extends Node
## One transmission of a Mission, which plays its MissionEvent children in tree order.

## Key of the lines in the dialog box's JSON.
@export var transmission := ""
## Plays with the text. Without it, the text stays up for the Mission's reading time.
@export var voice: AudioStream
## Seconds to wait after the previous event ends (after the start, for the first one).
@export var delay := 0.0
## Also waits until the rover is inside this POI. The POI stays hidden until it's the target, and hides once reached.
@export var poi: Poi
## Not part of the sequence: plays when the rover has stood still for the Mission's idle_after seconds.
@export var idle := false
