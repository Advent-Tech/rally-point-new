import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_colors.dart';
import '../blocs/walkie/walkie_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../../data/models/walkie_model.dart';

/// Shows a walkie-talkie bottom sheet
void showWalkieBottomSheet(BuildContext context, {String? teamId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WalkieBottomSheet(teamId: teamId),
  );
}

class WalkieBottomSheet extends StatefulWidget {
  final String? teamId;

  const WalkieBottomSheet({super.key, this.teamId});

  @override
  State<WalkieBottomSheet> createState() => _WalkieBottomSheetState();
}

class _WalkieBottomSheetState extends State<WalkieBottomSheet> {
  late WalkieBloc _walkieBloc;
  final TextEditingController _messageController = TextEditingController();
  WalkieMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _walkieBloc = WalkieBloc();
    _loadChannels();
  }

  void _setReplyingTo(WalkieMessage? message) {
    setState(() => _replyingTo = message);
    if (message != null) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replying to ${message.senderName}'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Cancel',
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ),
      );
    }
  }

  void _loadChannels() {
    String? teamId = widget.teamId;
    String? userId;
    String? userName;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      teamId ??= authState.user.teamId;
      userId = authState.user.id;
      userName = authState.user.fullName; // Use fullName to get proper display name
    }

    if (teamId != null) {
      _walkieBloc.add(WalkieLoadChannels(
        teamId: teamId,
        userId: userId,
        userName: userName,
      ));
    }
  }

  @override
  void dispose() {
    _walkieBloc.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocProvider.value(
      value: _walkieBloc,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.speaker_phone,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Walkie Talkie',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        BlocBuilder<WalkieBloc, WalkieState>(
                          builder: (context, state) {
                            String subtitle = 'Connecting...';
                            if (state is WalkieInChannel) {
                              subtitle = '${state.participants.length} online';
                            } else if (state is WalkieChannelsLoaded) {
                              subtitle = '${state.channels.length} channels';
                            } else if (state is WalkieError) {
                              subtitle = 'Error';
                            }
                            return Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  BlocBuilder<WalkieBloc, WalkieState>(
                    builder: (context, state) {
                      if (state is WalkieInChannel) {
                        return IconButton(
                          icon: Icon(
                            state.isMuted ? Icons.mic_off : Icons.mic,
                            color: state.isMuted ? AppColors.error : null,
                          ),
                          onPressed: () {
                            _walkieBloc.add(const WalkieToggleMute());
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: BlocBuilder<WalkieBloc, WalkieState>(
                builder: (context, state) {
                  if (state is WalkieLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is WalkieError) {
                    return _buildErrorView(state.message);
                  }

                  if (state is WalkieChannelsLoaded) {
                    return _buildChannelList(state.channels, isDark);
                  }

                  if (state is WalkieInChannel) {
                    return _buildActiveChannel(state, isDark, bottomPadding);
                  }

                  return _buildEmptyView(isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChannels,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speaker_phone,
            size: 48,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No Team Assigned',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(List<WalkieChannel> channels, bool isDark) {
    if (channels.isEmpty) {
      return _buildEmptyView(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _ChannelTile(
          channel: channel,
          isDark: isDark,
          onTap: () {
            _walkieBloc.add(WalkieJoinChannel(
              channelId: channel.id,
              channelName: channel.name,
            ));
          },
        );
      },
    );
  }

  Widget _buildActiveChannel(WalkieInChannel state, bool isDark, double bottomPadding) {
    return Column(
      children: [
        // Current speaker indicator
        if (state.currentSpeaker != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.success.withAlpha(30),
            child: Row(
              children: [
                _PulsatingDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${state.currentSpeaker!.displayName} is speaking...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Participants
        if (state.participants.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.participants.length,
              itemBuilder: (context, index) {
                final participant = state.participants[index];
                return _ParticipantChip(participant: participant, isDark: isDark);
              },
            ),
          ),

        // Messages
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet\nHold the button to talk',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    // With reverse: true, index 0 = bottom of list, so use direct index for newest at bottom
                    final message = state.messages[index];
                    return _CompactMessageTile(
                      message: message,
                      isDark: isDark,
                      onPlay: (message.messageType == 'voice' || message.messageType == 'audio') && message.audioUrl != null
                          ? () => _walkieBloc.add(WalkiePlayMessage(messageId: message.id))
                          : null,
                      onReply: _setReplyingTo,
                    );
                  },
                ),
        ),

        // Audio level indicator when speaking
        if (state.isSpeaking)
          _AudioLevelIndicator(audioLevel: state.audioLevel),

        // Reply indicator
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to ${_replyingTo!.senderName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _setReplyingTo(null),
                  child: const Icon(Icons.close, size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),

        // Push-to-talk button
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
          child: Row(
            children: [
              // Leave button
              IconButton(
                onPressed: () => _walkieBloc.add(const WalkieLeaveChannel()),
                icon: const Icon(Icons.exit_to_app),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.withAlpha(30),
                ),
              ),
              const SizedBox(width: 12),
              // PTT button
              Expanded(
                child: _CompactPTTButton(
                  isSpeaking: state.isSpeaking,
                  isMuted: state.isMuted,
                  onStartSpeaking: () => _walkieBloc.add(const WalkieStartSpeaking()),
                  onStopSpeaking: () => _walkieBloc.add(const WalkieStopSpeaking()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final WalkieChannel channel;
  final bool isDark;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  channel.channelType == 'team' ? Icons.groups : Icons.speaker_phone,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: channel.isActive ? AppColors.success : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${channel.participantCount} online',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final WalkieParticipant participant;
  final bool isDark;

  const _ParticipantChip({required this.participant, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: participant.isSpeaking
                      ? Border.all(color: AppColors.success, width: 2)
                      : null,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withAlpha(50),
                  child: Text(
                    participant.displayName.isNotEmpty
                        ? participant.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (participant.isMuted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 48,
            child: Text(
              participant.displayName.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMessageTile extends StatefulWidget {
  final WalkieMessage message;
  final bool isDark;
  final VoidCallback? onPlay;
  final void Function(WalkieMessage)? onReply;

  const _CompactMessageTile({
    required this.message,
    required this.isDark,
    this.onPlay,
    this.onReply,
  });

  @override
  State<_CompactMessageTile> createState() => _CompactMessageTileState();
}

class _CompactMessageTileState extends State<_CompactMessageTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && mounted) setState(() => _duration = dur);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position == Duration.zero || _position >= _duration) {
        // Start from beginning
        final audioUrl = widget.message.audioUrl;
        debugPrint('WalkiePlayback: Attempting to play: $audioUrl');
        if (audioUrl != null && audioUrl.isNotEmpty) {
          try {
            // Check if it's a local file path or a URL
            if (audioUrl.startsWith('/') || audioUrl.startsWith('file://')) {
              // Local file path
              final filePath = audioUrl.startsWith('file://')
                  ? audioUrl.substring(7)
                  : audioUrl;
              debugPrint('WalkiePlayback: Playing local file: $filePath');
              await _player.setFilePath(filePath);
            } else if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
              // Web URL (Supabase)
              debugPrint('WalkiePlayback: Playing from URL: $audioUrl');
              await _player.setUrl(audioUrl);
            } else {
              // Assume it's a local path
              debugPrint('WalkiePlayback: Playing as local path: $audioUrl');
              await _player.setFilePath(audioUrl);
            }
            debugPrint('WalkiePlayback: Duration loaded: ${_player.duration}');
            await _player.play();
            debugPrint('WalkiePlayback: Playback started');
          } catch (e, stackTrace) {
            debugPrint('WalkiePlayback: Error playing audio: $e');
            debugPrint('WalkiePlayback: Stack trace: $stackTrace');
          }
        } else {
          debugPrint('WalkiePlayback: No audio URL available');
        }
      } else {
        await _player.play();
      }
    }
    // Also call parent callback for global state
    widget.onPlay?.call();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onReply != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onReply?.call(widget.message);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha(50),
              child: Text(
                widget.message.senderName.isNotEmpty
                    ? widget.message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.message.senderName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(widget.message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildContent(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.message.messageType == 'voice' ||
        widget.message.messageType == 'audio') {
      final totalDuration = _duration.inMilliseconds > 0
          ? _duration
          : Duration(milliseconds: widget.message.audioDurationMs ?? 0);
      final progress = totalDuration.inMilliseconds > 0
          ? (_position.inMilliseconds / totalDuration.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;

      return GestureDetector(
        onTap: _togglePlayback,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isPlaying
                ? AppColors.primary.withAlpha(40)
                : AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
            border: _isPlaying
                ? Border.all(color: AppColors.primary.withAlpha(100))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isPlaying
                          ? AppColors.primary
                          : AppColors.primary.withAlpha(150),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.withAlpha(50),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Duration text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isPlaying || _position > Duration.zero
                                  ? _formatDuration(_position)
                                  : '00:00',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              widget.message.formattedDuration,
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
              // Tap to reply hint
              if (widget.onReply != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Long press to reply',
                    style: TextStyle(
                      fontSize: 9,
                      color: (widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withAlpha(150),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (widget.message.messageType == 'alert') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.message.text ?? 'Alert',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.grey.withAlpha(30)
            : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.message.text ?? '',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _CompactPTTButton extends StatefulWidget {
  final bool isSpeaking;
  final bool isMuted;
  final VoidCallback onStartSpeaking;
  final VoidCallback onStopSpeaking;

  const _CompactPTTButton({
    required this.isSpeaking,
    required this.isMuted,
    required this.onStartSpeaking,
    required this.onStopSpeaking,
  });

  @override
  State<_CompactPTTButton> createState() => _CompactPTTButtonState();
}

class _CompactPTTButtonState extends State<_CompactPTTButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_CompactPTTButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _pulseController.repeat(reverse: true);
      _startRecordingTimer();
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _pulseController.stop();
      _pulseController.reset();
      _stopRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingSeconds = 0;
  }

  String get _formattedDuration {
    final minutes = _recordingSeconds ~/ 60;
    final seconds = _recordingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onPressStart() {
    if (widget.isMuted || _isPressed) return;
    setState(() => _isPressed = true);
    HapticFeedback.mediumImpact();
    widget.onStartSpeaking();
  }

  void _onPressEnd() {
    if (widget.isMuted || !_isPressed) return;
    setState(() => _isPressed = false);
    HapticFeedback.lightImpact();
    widget.onStopSpeaking();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || widget.isSpeaking;

    return Listener(
      onPointerDown: (_) => _onPressStart(),
      onPointerUp: (_) => _onPressEnd(),
      onPointerCancel: (_) => _onPressEnd(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSpeaking ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.isMuted
                    ? null
                    : LinearGradient(
                        colors: isActive
                            ? [AppColors.error, AppColors.error.withRed(200)]
                            : [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: widget.isMuted ? Colors.grey : null,
                borderRadius: BorderRadius.circular(28),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.error.withAlpha(150),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(50),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.isMuted
                          ? Icons.mic_off
                          : (isActive ? Icons.mic : Icons.mic_none),
                      key: ValueKey(isActive),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isMuted
                            ? 'Muted'
                            : (isActive ? 'Recording...' : 'Hold to talk'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isActive)
                        Text(
                          _formattedDuration,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PulsatingDot extends StatefulWidget {
  @override
  State<_PulsatingDot> createState() => _PulsatingDotState();
}

class _PulsatingDotState extends State<_PulsatingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withAlpha((128 * _controller.value).toInt()),
                blurRadius: 8 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Audio level indicator with animated bars
class _AudioLevelIndicator extends StatefulWidget {
  final double audioLevel;

  const _AudioLevelIndicator({required this.audioLevel});

  @override
  State<_AudioLevelIndicator> createState() => _AudioLevelIndicatorState();
}

class _AudioLevelIndicatorState extends State<_AudioLevelIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use actual audio level, but ensure minimum visibility when recording
    final displayLevel = widget.audioLevel > 0.01 ? widget.audioLevel : 0.0;
    final hasSignal = displayLevel > 0.05;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasSignal
            ? AppColors.success.withAlpha(20)
            : (isDark ? Colors.grey[850] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSignal
              ? AppColors.success.withAlpha(100)
              : Colors.grey.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          // Mic icon with pulse
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasSignal
                      ? AppColors.success
                      : AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (hasSignal ? AppColors.success : AppColors.error)
                          .withAlpha((100 * _animController.value).toInt()),
                      blurRadius: 8 * _animController.value,
                      spreadRadius: 2 * _animController.value,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Level bars and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSignal ? 'Recording...' : 'No audio detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: hasSignal ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                // Audio level bars
                Row(
                  children: List.generate(20, (index) {
                    final threshold = index / 20;
                    final isActive = displayLevel > threshold;
                    // Animate bars when no signal to show recording is active
                    final animatedActive = !hasSignal &&
                        index < 3 &&
                        _animController.value > (index * 0.3);

                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _getBarColor(index / 20)
                              : (animatedActive
                                  ? Colors.grey.withAlpha(100)
                                  : Colors.grey.withAlpha(30)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSignal
                      ? 'Level: ${(displayLevel * 100).toInt()}%'
                      : 'Speak into microphone',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(double level) {
    if (level < 0.5) return AppColors.success;
    if (level < 0.75) return Colors.orange;
    return AppColors.error;
  }
}
