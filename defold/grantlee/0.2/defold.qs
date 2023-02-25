/*function introspect(value, name, indent) {
	indent = indent || '';
	name = name || '';
	if (value === null) {
		return indent+name+' = null';
	}
	var objType = typeof value;
	var info = indent+name+' = ';
	if (objType === 'undefined') {
		return info+'undefined\n';
	} else if (objType === 'object') {
		var propInfo = '';
		var prop;
		for (prop in value) {
			if(prop !== 'objectName') {
				var p = introspect(value[prop], prop, indent+'    ');
				if(p !== '') {
					propInfo += p +'\n';
				}
			}
		}
		if(propInfo==='') {
			info += '{'+value+'}';
		} else {
			info += '{\n' + propInfo +indent+'}';
		}
	} else if (objType === 'function') {
		return '';
	} else {
		info+=value;
	}
	return info;
}*/

function ensureInt(value) {
	const intValue = parseInt(value, 10);
	return isNaN(intValue) ? 0 : intValue;
}

function ident(count) {
	return '  '.repeat(count);
}

function quote(str) {
	return '"' + str + '"';
}

function field(fieldName, value, identLevel = 0, isQuoted = false) {
	return ident(identLevel) + fieldName + ': ' + (isQuoted ? quote(value) : value);
}

function extractAnimations(context, data) {
	let animations = new Map();
	let aliases = new Map();
	let rootPath = '/' + context.assetsPath.replace('{atlas_name}', context.atlasName);
	for (let i = 0; i < data.allSprites.length; ++i) {
		let sprite = data.allSprites[i];
		const spriteName = sprite.trimmedName;
		const nameAndFrame = spriteName.split('/');
		if (nameAndFrame.length > 1) {
			// Store in the animation.
			const animationName = nameAndFrame[0];
			if (!animations.has(animationName)) {
				animations.set(animationName, []);
			}
			let animation = animations.get(animationName);
			let animationPath = rootPath.replace('{animation_name}', animationName) + '/';
			sprite.imagePath = animationPath + animation.length.toString() + '.png'; // Remember the path so we can construct a correct filename.

			// Find a duplicate sprite.
			for (let j = 0; j < sprite.aliasList.length; ++j) {
				const aliasSprite = sprite.aliasList[j];
				aliases.set(aliasSprite.trimmedName, sprite);
			}
			if (aliases.has(spriteName)) {
				sprite = aliases.get(spriteName);
			}

			animation.push(sprite);
		}
	}
	return animations;
}

function exportImage(output, imagePath, sprite, trimMode, identLevel) {
	output.push(
		field('image', imagePath, identLevel, true),
		//field('sprite', sprite.trimmedName, identLevel, true),
		field('sprite_trim_mode', trimMode, identLevel)
	);
	if (sprite.trimmed) {
		output.push(
			field('source_position_x', sprite.sourceRect.x, identLevel),
			field('source_position_y', sprite.sourceRect.y, identLevel),
			field('source_width', sprite.untrimmedSize.width, identLevel),
			field('source_height', sprite.untrimmedSize.height, identLevel)
		);
	}
}

function getAnimationSettingOrDefault(context, animationSettings, name) {
	return animationSettings.has(name) ? animationSettings.get(name) : context.animationDefaultSettings[name];
}

function exportAnimation(context, output, animationName, animation) {
	let animationSettings = new Map();
	if (context.animationSettings.has(animationName)) {
		animationSettings = context.animationSettings.get(animationName);
	}
	let trimMode = getAnimationSettingOrDefault(context, animationSettings, 'trim');

	output.push('animations {');
	let identLevel = 1;
	output.push(field('id', animationName, identLevel, true));
	for (let i = 0; i < animation.length; ++i) {
		let sprite = animation[i];
		output.push(ident(identLevel) + 'images {');
		exportImage(output, sprite.imagePath, sprite, trimMode, identLevel + 1);
		output.push(ident(identLevel) + '}');
	}

	let flip = getAnimationSettingOrDefault(context, animationSettings, 'flip');
	output.push(
		field('playback', getAnimationSettingOrDefault(context, animationSettings, 'playback'), identLevel),
		field('fps', getAnimationSettingOrDefault(context, animationSettings, 'fps'), identLevel),
		field('flip_horizontal', (flip == 'h' || flip == 'hv') ? 1 : 0, identLevel),
		field('flip_vertical', (flip == 'v' || flip == 'hv') ? 1 : 0, identLevel)
	);
	output.push('}');
}

function trimValueToDefoldTrimMode(value) {
	if (value >= 4 && value <= 8) {
		return 'SPRITE_TRIM_MODE_' + value.toString();
	} else {
		return 'SPRITE_TRIM_MODE_OFF';
	}
}

const allowedPlaybackValues = ['none', 'once_forward', 'once_backward', 'once_ping_pong', 'loop_forward', 'loop_backward', 'loop_ping_pong'];
function playbackValueToDefoldPlayback(value) {
	value = value.toLowerCase();
	if (allowedPlaybackValues.includes(value)) {
		return 'PLAYBACK_' + value.toUpperCase();
	} else {
		return 'PLAYBACK_ONCE_FORWARD';
	}
}

function parseAnimationSetting(name, value) {
	switch (name) {
		case 'trim': return trimValueToDefoldTrimMode(ensureInt(value));
		case 'playback': return playbackValueToDefoldPlayback(value);
		case 'fps': return Math.abs(ensureInt(value));
		case 'flip':
			value = value.toLowerCase();
			if (value == 'h' || value == 'v' || value == 'hv') {
				return value;
			} else {
				return '';
			}
	}
	return '';
}

function parseAnimationSettings(context, properties) {
	// Format
	// default, animation_name:value, animation_other:value
	const propertyNames = ['animations_trim', 'animations_playback', 'animations_fps', 'animations_flip'];
	for (let i = 0; i < propertyNames.length; ++i) {
		const propertyName = propertyNames[i];
		const propertyValue = properties[propertyName];
		const shortPropertyName = propertyName.split('_')[1];
		const settings = propertyValue.split(',');
		for (let j = 0; j < settings.length; ++j) {
			const setting = settings[j];
			const animationNameAndValue = setting.split(':');
			if (j == 0 && animationNameAndValue.length == 1) {
				context.animationDefaultSettings[shortPropertyName] = parseAnimationSetting(shortPropertyName, animationNameAndValue[0].trim());
			} else if (animationNameAndValue.length == 2) {
				const animationName = animationNameAndValue[0].trim();
				const value = parseAnimationSetting(shortPropertyName, animationNameAndValue[1].trim());
				if (!context.animationSettings.has(animationName)) {
					context.animationSettings.set(animationName, new Map());
				}
				context.animationSettings.get(animationName).set(shortPropertyName, value);
			}
		}
	}
}

function ExportData(data) {
	let context = {
		atlasName: data.texture.trimmedName,
		assetsPath: data.exporterProperties.assets_path,
		animationSettings: new Map(),
		animationDefaultSettings: {
			trim: 'SPRITE_TRIM_MODE_OFF',
			playback: 'PLAYBACK_ONCE_FORWARD',
			fps: 60,
			flip: ''
		}
	};
	parseAnimationSettings(context, data.exporterProperties);

	let output = [];

	const animations = extractAnimations(context, data);
	for (let [animationName, animation] of animations) {
		exportAnimation(context, output, animationName, animation);
	}

	output.push(
		field('margin', ensureInt(data.exporterProperties.margin)),
		field('extrude_borders', ensureInt(data.exporterProperties.extrude_borders)),
		field('inner_padding', ensureInt(data.exporterProperties.inner_padding)),
		''
	);

	return output.join('\n');
}

ExportData.filterName = 'ExportData';
Library.addFilter('ExportData');
