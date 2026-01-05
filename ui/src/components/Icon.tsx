import React from 'react';
import { FontAwesome, MaterialIcons, Feather } from '@expo/vector-icons';

interface IconProps {
  name: string;
  size?: number;
  color?: string;
  style?: any;
}

const Icon: React.FC<IconProps> = ({ name, size = 24, color = '#000', style }) => {
  // Map icon names to appropriate icon libraries
  const getIconComponent = () => {
    // FontAwesome icons
    const fontAwesomeIcons = [
      'home', 'user', 'users', 'map', 'map-o', 'location-pin', 'book', 'heart',
      'star', 'settings', 'cog', 'bell', 'search', 'plus', 'minus', 'edit',
      'trash', 'save', 'share', 'download', 'upload', 'refresh', 'sync',
      'check', 'times', 'close', 'arrow-left', 'arrow-right', 'arrow-up', 'arrow-down',
      'chevron-left', 'chevron-right', 'chevron-up', 'chevron-down',
      'bars', 'menu', 'ellipsis-v', 'ellipsis-h', 'info', 'warning', 'exclamation',
      'question', 'envelope', 'phone', 'calendar', 'clock-o', 'time',
      'eye', 'eye-slash', 'lock', 'unlock', 'key', 'shield',
      'camera', 'image', 'video', 'music', 'file', 'folder',
      'link', 'external-link', 'bookmark', 'tag', 'tags',
      'shopping-cart', 'credit-card', 'money', 'gift',
      'car', 'plane', 'ship', 'bicycle', 'bus',
      'wifi', 'signal', 'battery', 'power-off',
      'sun-o', 'moon-o', 'cloud', 'umbrella',
      'male', 'female', 'child', 'group',
      'graduation-cap', 'briefcase', 'building', 'hospital',
      'pencil', 'stop', 'user-plus'
    ];

    // Material Icons
    const materialIcons = [
      'notifications', 'notification-important', 'account-circle', 'dashboard',
      'trending-up', 'trending-down', 'trending-flat', 'analytics',
      'assessment', 'bar-chart', 'pie-chart', 'timeline',
      'location-on', 'location-off', 'my-location', 'place',
      'directions', 'navigation', 'explore', 'map',
      'contact-phone', 'contact-mail', 'contacts', 'person',
      'people', 'group', 'supervisor-account', 'account-box',
      'work', 'business', 'domain', 'store',
      'school', 'library-books', 'book', 'bookmark',
      'favorite', 'favorite-border', 'thumb-up', 'thumb-down',
      'share', 'send', 'mail', 'message',
      'chat', 'comment', 'feedback', 'rate-review',
      'visibility', 'visibility-off', 'remove-red-eye',
      'security', 'verified-user', 'lock', 'lock-open',
      'vpn-key', 'fingerprint', 'face', 'account-balance-wallet',
      'payment', 'shopping-cart', 'add-shopping-cart', 'store-mall-directory',
      'local-offer', 'local-atm', 'local-grocery-store',
      'flight', 'hotel', 'restaurant', 'local-cafe',
      'local-hospital', 'local-pharmacy', 'local-gas-station',
      'wifi', 'signal-cellular-4-bar', 'battery-full', 'power',
      'brightness-high', 'brightness-low', 'wb-sunny', 'wb-cloudy',
      'help', 'help-outline', 'info', 'info-outline',
      'warning', 'error', 'error-outline', 'check-circle',
      'cancel', 'highlight-off', 'clear', 'close',
      'add', 'remove', 'add-circle', 'remove-circle',
      'edit', 'delete', 'save', 'file-download',
      'file-upload', 'refresh', 'sync', 'update'
    ];

    // Feather icons
    const featherIcons = [
      'activity', 'airplay', 'alert-circle', 'alert-octagon', 'alert-triangle',
      'align-center', 'align-justify', 'align-left', 'align-right',
      'anchor', 'aperture', 'archive', 'arrow-down', 'arrow-down-circle',
      'arrow-down-left', 'arrow-down-right', 'arrow-left', 'arrow-left-circle',
      'arrow-right', 'arrow-right-circle', 'arrow-up', 'arrow-up-circle',
      'arrow-up-left', 'arrow-up-right', 'at-sign', 'award',
      'bar-chart', 'bar-chart-2', 'battery', 'battery-charging',
      'bell', 'bell-off', 'bluetooth', 'bold', 'book', 'book-open',
      'bookmark', 'box', 'briefcase', 'calendar', 'camera', 'camera-off',
      'cast', 'check', 'check-circle', 'check-square', 'chevron-down',
      'chevron-left', 'chevron-right', 'chevron-up', 'chevrons-down',
      'chevrons-left', 'chevrons-right', 'chevrons-up', 'chrome',
      'circle', 'clipboard', 'clock', 'cloud', 'cloud-drizzle',
      'cloud-lightning', 'cloud-off', 'cloud-rain', 'cloud-snow',
      'code', 'codepen', 'codesandbox', 'coffee', 'columns',
      'command', 'compass', 'copy', 'corner-down-left', 'corner-down-right',
      'corner-left-down', 'corner-left-up', 'corner-right-down', 'corner-right-up',
      'corner-up-left', 'corner-up-right', 'cpu', 'credit-card',
      'crop', 'crosshair', 'database', 'delete', 'disc',
      'dollar-sign', 'download', 'download-cloud', 'droplet', 'edit',
      'edit-2', 'edit-3', 'external-link', 'eye', 'eye-off',
      'facebook', 'fast-forward', 'feather', 'figma', 'file',
      'file-minus', 'file-plus', 'file-text', 'film', 'filter',
      'flag', 'folder', 'folder-minus', 'folder-plus', 'framer',
      'frown', 'gift', 'git-branch', 'git-commit', 'git-merge',
      'git-pull-request', 'github', 'gitlab', 'globe', 'grid',
      'hard-drive', 'hash', 'headphones', 'heart', 'help-circle',
      'hexagon', 'home', 'image', 'inbox', 'info',
      'instagram', 'italic', 'key', 'layers', 'layout',
      'life-buoy', 'link', 'link-2', 'linkedin', 'list',
      'loader', 'lock', 'log-in', 'log-out', 'mail',
      'map', 'map-pin', 'maximize', 'maximize-2', 'meh',
      'menu', 'message-circle', 'message-square', 'mic', 'mic-off',
      'minimize', 'minimize-2', 'minus', 'minus-circle', 'minus-square',
      'monitor', 'moon', 'more-horizontal', 'more-vertical', 'mouse-pointer',
      'move', 'music', 'navigation', 'navigation-2', 'octagon',
      'package', 'paperclip', 'pause', 'pause-circle', 'pen-tool',
      'percent', 'phone', 'phone-call', 'phone-forwarded', 'phone-incoming',
      'phone-missed', 'phone-off', 'phone-outgoing', 'pie-chart', 'play',
      'play-circle', 'plus', 'plus-circle', 'plus-square', 'pocket',
      'power', 'printer', 'radio', 'refresh-ccw', 'refresh-cw',
      'repeat', 'rewind', 'rotate-ccw', 'rotate-cw', 'rss',
      'save', 'scissors', 'search', 'send', 'server',
      'settings', 'share', 'share-2', 'shield', 'shield-off',
      'shopping-bag', 'shopping-cart', 'shuffle', 'sidebar', 'skip-back',
      'skip-forward', 'slack', 'slash', 'sliders', 'smartphone',
      'smile', 'speaker', 'square', 'star', 'stop-circle',
      'sun', 'sunrise', 'sunset', 'tablet', 'tag',
      'target', 'terminal', 'thermometer', 'thumbs-down', 'thumbs-up',
      'toggle-left', 'toggle-right', 'tool', 'trash', 'trash-2',
      'triangle', 'truck', 'tv', 'twitch', 'twitter',
      'type', 'umbrella', 'underline', 'unlock', 'upload',
      'upload-cloud', 'user', 'user-check', 'user-minus', 'user-plus',
      'user-x', 'users', 'video', 'video-off', 'voicemail',
      'volume', 'volume-1', 'volume-2', 'volume-x', 'watch',
      'wifi', 'wifi-off', 'wind', 'x', 'x-circle',
      'x-octagon', 'x-square', 'youtube', 'zap', 'zap-off',
      'zoom-in', 'zoom-out'
    ];

    // Custom icon mappings for common names
    const iconMappings: { [key: string]: { library: string; name: string } } = {
      // Common mappings
      'close': { library: 'MaterialIcons', name: 'close' },
      'menu': { library: 'Feather', name: 'menu' },
      'home': { library: 'Feather', name: 'home' },
      'user': { library: 'Feather', name: 'user' },
      'users': { library: 'Feather', name: 'users' },
      'team': { library: 'Feather', name: 'users' },
      'map': { library: 'Feather', name: 'map' },
      'location-pin': { library: 'Feather', name: 'map-pin' },
      'book': { library: 'Feather', name: 'book' },
      'activity': { library: 'Feather', name: 'activity' },
      'profile': { library: 'Feather', name: 'user' },
      'settings': { library: 'Feather', name: 'settings' },
      'notifications': { library: 'MaterialIcons', name: 'notifications' },
      'trending-up': { library: 'MaterialIcons', name: 'trending-up' },
      'trending-down': { library: 'MaterialIcons', name: 'trending-down' },
      'trending-flat': { library: 'MaterialIcons', name: 'trending-flat' },
      'visit': { library: 'Feather', name: 'home' },
      'contact': { library: 'Feather', name: 'user' },
      'bar-chart': { library: 'Feather', name: 'bar-chart' },
      'chart': { library: 'Feather', name: 'bar-chart-2' },
      'bible': { library: 'Feather', name: 'book' },
      'history': { library: 'Feather', name: 'clock' },
      'logout': { library: 'Feather', name: 'log-out' },
      'people': { library: 'MaterialIcons', name: 'people' },
      'comment': { library: 'MaterialIcons', name: 'comment' },
      'add': { library: 'MaterialIcons', name: 'add' },
      'message': { library: 'MaterialIcons', name: 'message' },
    };

    // Check if we have a custom mapping
    if (iconMappings[name]) {
      const mapping = iconMappings[name];
      switch (mapping.library) {
        case 'FontAwesome':
          return <FontAwesome name={mapping.name as any} size={size} color={color} style={style} />;
        case 'MaterialIcons':
          return <MaterialIcons name={mapping.name as any} size={size} color={color} style={style} />;
        case 'Feather':
          return <Feather name={mapping.name as any} size={size} color={color} style={style} />;
      }
    }

    // Try to find the icon in each library
    if (featherIcons.includes(name)) {
      return <Feather name={name as any} size={size} color={color} style={style} />;
    }
    
    if (materialIcons.includes(name)) {
      return <MaterialIcons name={name as any} size={size} color={color} style={style} />;
    }
    
    if (fontAwesomeIcons.includes(name)) {
      return <FontAwesome name={name as any} size={size} color={color} style={style} />;
    }

    // Fallback to a default icon if not found
    console.warn(`Icon "${name}" not found, using default help icon`);
    return <Feather name="help-circle" size={size} color={color} style={style} />;
  };

  return getIconComponent();
};

export default Icon;
