import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onMarkRead;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(notification.type);

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: AppColors.success,
        child: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Mark Read',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Mark as read — don't actually dismiss
          HapticFeedback.lightImpact();
          onMarkRead?.call();
          return false;
        }
        // Delete
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => onDismiss?.call(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead
                ? null
                : typeColor.withAlpha(isDark ? 15 : 10),
            border: Border(
              left: BorderSide(
                color: typeColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(context, typeColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                        ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              height: 1.3,
                            ),
                      ),
                    ],
                    // Walkie audio player
                    if (notification.type == 'walkie' &&
                        _hasAudioUrl(notification))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _WalkieAudioPlayer(
                          audioUrl: notification.data['audio_url'] as String,
                          duration: notification.data['audio_duration_ms'] as int?,
                          isDark: isDark,
                        ),
                      ),
                    // Type label
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(isDark ? 30 : 20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getTypeLabel(notification.type),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasAudioUrl(NotificationModel notification) {
    final url = notification.data['audio_url'];
    return url is String && url.isNotEmpty;
  }

  Widget _buildIcon(BuildContext context, Color typeColor) {
    final iconData = _getTypeIcon(notification.type);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [typeColor, typeColor.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: typeColor.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(iconData, color: Colors.white, size: 20),
    );
  }

  static Color _getTypeColor(String type) {
    return switch (type) {
      'chat' => AppColors.primary,
      'walkie' => AppColors.warning,
      'territory' || 'geofence' => AppColors.success,
      'delivery' => AppColors.accent,
      'prayer' => AppColors.secondary,
      'survey' => AppColors.info,
      'team' => AppColors.primaryDark,
      'session' => AppColors.successDark,
      _ => AppColors.textSecondaryLight,
    };
  }

  static IconData _getTypeIcon(String type) {
    return switch (type) {
      'geofence' => Icons.location_on,
      'territory' => Icons.map,
      'prayer' => Icons.volunteer_activism,
      'delivery' => Icons.local_shipping,
      'survey' => Icons.assignment,
      'team' => Icons.group,
      'walkie' => Icons.speaker_phone,
      'chat' => Icons.chat_bubble,
      'session' => Icons.timer,
      _ => Icons.notifications,
    };
  }

  static String _getTypeLabel(String type) {
    return switch (type) {
      'geofence' => 'Location',
      'territory' => 'Territory',
      'prayer' => 'Prayer',
      'delivery' => 'Donation',
      'survey' => 'Survey',
      'team' => 'Team',
      'walkie' => 'Walkie',
      'chat' => 'Chat',
      'session' => 'Session',
      _ => 'General',
    };
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

/// Inline audio player for walkie notifications.
class _WalkieAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration;
  final bool isDark;

  const _WalkieAudioPlayer({
    required this.audioUrl,
    this.duration,
    required this.isDark,
  });

  @override
  State<_WalkieAudioPlayer> createState() => _WalkieAudioPlayerState();
}

class _WalkieAudioPlayerState extends State<_WalkieAudioPlayer>
    with SingleTickerProviderStateMixin {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _progressSub;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(milliseconds: widget.duration ?? 0);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressSub?.cancel();
    if (_player != null) {
      _player!.closePlayer();
      _player = null;
    }
    super.dispose();
  }

  Future<FlutterSoundPlayer> _ensurePlayer() async {
    if (_player == null) {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      await _player!.setSubscriptionDuration(
          const Duration(milliseconds: 100));
      _progressSub = _player!.onProgress!.listen((e) {
        if (mounted) {
          setState(() {
            _position = e.position;
            if (e.duration.inMilliseconds > 0) {
              _totalDuration = e.duration;
            }
          });
        }
      });
    }
    return _player!;
  }

  Future<void> _togglePlayback() async {
    if (_hasError) return;

    if (_isPlaying) {
      await _player?.pausePlayer();
      _pulseController.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_player != null && _player!.isPaused) {
      await _player!.resumePlayer();
      _pulseController.repeat(reverse: true);
      if (mounted) setState(() => _isPlaying = true);
      return;
    }

    try {
      final player = await _ensurePlayer();
      await player.startPlayer(
        fromURI: widget.audioUrl,
        whenFinished: () {
          _pulseController.stop();
          _pulseController.reset();
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        },
      );
      _pulseController.repeat(reverse: true);
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: _isPlaying
              ? LinearGradient(
                  colors: [
                    AppColors.warning.withAlpha(35),
                    AppColors.warning.withAlpha(15),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: _isPlaying
              ? null
              : (widget.isDark
                  ? AppColors.warning.withAlpha(20)
                  : AppColors.warning.withAlpha(15)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isPlaying
                ? AppColors.warning.withAlpha(100)
                : AppColors.warning.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            // Play/pause button
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale =
                    _isPlaying ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: _hasError
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.warning, AppColors.warningDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _hasError ? AppColors.error : null,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isPlaying)
                          BoxShadow(
                            color: AppColors.warning.withAlpha(80),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Icon(
                      _hasError
                          ? Icons.error_outline
                          : (_isPlaying ? Icons.pause : Icons.play_arrow),
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            // Waveform + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform bars
                  SizedBox(
                    height: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(24, (i) {
                        // Simulated waveform heights
                        final heights = [
                          0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.3, 0.95,
                          0.5, 0.7, 0.4, 0.85, 0.6, 0.75, 0.5, 0.9,
                          0.35, 0.8, 0.55, 0.7, 0.4, 0.6, 0.3, 0.5,
                        ];
                        final barProgress = i / 24;
                        final isPlayed = barProgress <= progress;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            height: 20 * heights[i],
                            decoration: BoxDecoration(
                              color: isPlayed
                                  ? AppColors.warning
                                  : (widget.isDark
                                      ? AppColors.warning.withAlpha(50)
                                      : AppColors.warning.withAlpha(40)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Duration text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPlaying || _position > Duration.zero
                            ? _fmt(_position)
                            : 'Tap to play',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _isPlaying
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _isPlaying
                              ? AppColors.warningDark
                              : (widget.isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                      Text(
                        _fmt(_totalDuration),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
