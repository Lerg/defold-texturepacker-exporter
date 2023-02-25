# Defold Exporter For TexturePacker

This is a custom exporter of TexturePacker project for the Defold game engine.

The exporter supports trimming sprites of unused transparent regions greatly reducing texture size.
It also detects duplicate frames in animations.

The exporter generates a native Atlas file for Defold and it supports setting Defold properties for the whole atlas or each animation.

Due to the fact that Defold packs images on it's own the resulting spritesheet has to be split up into individual images.

This can be achieved with a special editor script that you can install from here
https://github.com/Lerg/defold-editor-script-spritesheet

## Settings

Select `Prepend folder name`.

Don't select `Multipack`.

Don't set TexturePacker's `Extrude`, `Border padding`, `Shape Padding`. Defold has it own settings.

## Animations

Put each animation into it's folder. The folder name is the animation name.
Filenames don't matter, they just have to be sequential.

Each animation can have it's own settings such as playback or FPS.

To set values put a comma separated list of pairs `animation_name:value`. The first value without `animation_name` acts as a default.
Example, FPS:

`60, idle: 15, run:30,jump :45`

Whitespace is ignored.

---