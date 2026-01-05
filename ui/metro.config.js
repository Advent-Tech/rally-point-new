const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Add support for CSS
config.resolver.assetExts.push('css');

// Remove svg from assetExts (we'll handle it with transformer)
config.resolver.assetExts = config.resolver.assetExts.filter((ext) => ext !== 'svg');

// Add svg to sourceExts
config.resolver.sourceExts.push('svg');

module.exports = config;
