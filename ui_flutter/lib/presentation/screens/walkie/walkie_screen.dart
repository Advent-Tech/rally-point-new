import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/walkie/walkie_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/models/walkie_model.dart';

class WalkieScreen extends StatefulWidget {
  const WalkieScreen({super.key});

  @override
  State<WalkieScreen> createState() => _WalkieScreenState();
}

class _WalkieScreenState extends State<WalkieScreen> {
  late WalkieBloc _walkieBloc;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _walkieBloc = WalkieBloc();

    // Load channels for current team
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final teamId = authState.user.teamId;
      if (teamId != null) {
        _walkieBloc.add(WalkieLoadChannels(
          teamId: teamId,
          userId: authState.user.id,
          userName: authState.user.fullName,
        ));
      }
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
    return BlocProvider.value(
      value: _walkieBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Walkie Talkie'),
          actions: [
            BlocBuilder<WalkieBloc, WalkieState>(
              builder: (context, state) {
                if (state is WalkieInChannel) {
                  return IconButton(
                    icon: Icon(
                      state.isMuted ? Icons.mic_off : Icons.mic,
                      color: state.isMuted ? Colors.red : null,
                    ),
                    onPressed: () {
                      _walkieBloc.add(const WalkieToggleMute());
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocBuilder<WalkieBloc, WalkieState>(
          builder: (context, state) {
            if (state is WalkieLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is WalkieError) {
              return _buildErrorView(state.message);
            }

            if (state is WalkieChannelsLoaded) {
              return _buildChannelList(state.channels);
            }

            if (state is WalkieInChannel) {
              return _buildActiveChannel(state);
            }

            return _buildEmptyView();
          },
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated && authState.user.teamId != null) {
                  _walkieBloc.add(WalkieLoadChannels(
                    teamId: authState.user.teamId!,
                    userId: authState.user.id,
                    userName: authState.user.fullName,
                  ));
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speaker_phone,
            size: 64,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Team Assigned',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Join a team to access walkie-talkie channels',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(List<WalkieChannel> channels) {
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.speaker_phone,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Channels Available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your team has no walkie-talkie channels yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _ChannelCard(
          channel: channel,
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

  Widget _buildActiveChannel(WalkieInChannel state) {
    return Column(
      children: [
        // Channel header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.speaker_phone,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.channel.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${state.participants.length} participants online',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _walkieBloc.add(const WalkieLeaveChannel());
                },
              ),
            ],
          ),
        ),

        // Current speaker indicator
        if (state.currentSpeaker != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.success.withAlpha(30),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withAlpha(128),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${state.currentSpeaker!.displayName} is speaking...',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

        // Participants row
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: state.participants.length,
            itemBuilder: (context, index) {
              final participant = state.participants[index];
              return _ParticipantAvatar(participant: participant);
            },
          ),
        ),

        const Divider(height: 1),

        // Messages list
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              // With reverse: true, index 0 = bottom of screen.
              // Messages are stored oldest-first, so reverse the index to show newest at bottom.
              final message = state.messages[state.messages.length - 1 - index];
              return _MessageBubble(message: message);
            },
          ),
        ),

        // Text message input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      _walkieBloc.add(WalkieSendTextMessage(text: text));
                      _messageController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    _walkieBloc.add(WalkieSendTextMessage(
                      text: _messageController.text,
                    ));
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ),

        // Push-to-talk button
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: _PushToTalkButton(
            isSpeaking: state.isSpeaking,
            isMuted: state.isMuted,
            onStartSpeaking: () {
              _walkieBloc.add(const WalkieStartSpeaking());
            },
            onStopSpeaking: () {
              _walkieBloc.add(const WalkieStopSpeaking());
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final WalkieChannel channel;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getChannelIcon(channel.channelType),
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                          style: Theme.of(context).textTheme.bodySmall,
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

  IconData _getChannelIcon(String channelType) {
    switch (channelType) {
      case 'team':
        return Icons.groups;
      case 'group':
        return Icons.group;
      case 'direct':
        return Icons.person;
      default:
        return Icons.speaker_phone;
    }
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final WalkieParticipant participant;

  const _ParticipantAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: participant.isSpeaking
                      ? Border.all(color: AppColors.success, width: 3)
                      : null,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withAlpha(50),
                  backgroundImage: participant.avatarUrl != null
                      ? NetworkImage(participant.avatarUrl!)
                      : null,
                  child: participant.avatarUrl == null
                      ? Text(
                          participant.displayName.isNotEmpty
                              ? participant.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
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
                    child: const Icon(
                      Icons.mic_off,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              participant.displayName,
              style: Theme.of(context).textTheme.bodySmall,
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

class _MessageBubble extends StatefulWidget {
  final WalkieMessage message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _progressSub;

  bool get _isVoice =>
      widget.message.messageType == 'voice' ||
      widget.message.messageType == 'audio';

  @override
  void dispose() {
    _progressSub?.cancel();
    if (_player != null) {
      _player!.closePlayer();
      _player = null;
    }
    super.dispose();
  }

  /// Lazily open player only on tap — avoids AudioFocus conflicts with recording
  Future<FlutterSoundPlayer> _ensurePlayer() async {
    if (_player == null) {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
      _progressSub = _player!.onProgress!.listen((e) {
        if (mounted) {
          setState(() {
            _position = e.position;
            _duration = e.duration;
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
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_player != null && _player!.isPaused) {
      await _player!.resumePlayer();
      if (mounted) setState(() => _isPlaying = true);
      return;
    }

    final audioUrl = widget.message.audioUrl;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        final player = await _ensurePlayer();
        await player.startPlayer(
          fromURI: audioUrl,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
        );
        if (mounted) setState(() => _isPlaying = true);
      } catch (e) {
        if (mounted) setState(() => _hasError = true);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withAlpha(50),
            backgroundImage: widget.message.senderAvatar != null
                ? NetworkImage(widget.message.senderAvatar!)
                : null,
            child: widget.message.senderAvatar == null
                ? Text(
                    widget.message.senderName.isNotEmpty
                        ? widget.message.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.message.senderName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(widget.message.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildMessageContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (_isVoice) {
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hasError
                      ? AppColors.error
                      : (_isPlaying
                          ? AppColors.primary
                          : AppColors.primary.withAlpha(150)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasError
                      ? Icons.error_outline
                      : (_isPlaying ? Icons.pause : Icons.play_arrow),
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.withAlpha(50),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPlaying || _position > Duration.zero
                              ? _formatDuration(_position)
                              : '00:00',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          widget.message.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    if (widget.message.messageType == 'alert') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              widget.message.text ?? 'Alert',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      widget.message.text ?? '',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _PushToTalkButton extends StatelessWidget {
  final bool isSpeaking;
  final bool isMuted;
  final VoidCallback onStartSpeaking;
  final VoidCallback onStopSpeaking;

  const _PushToTalkButton({
    required this.isSpeaking,
    required this.isMuted,
    required this.onStartSpeaking,
    required this.onStopSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTapDown: isMuted ? null : (_) => onStartSpeaking(),
        onTapUp: isMuted ? null : (_) => onStopSpeaking(),
        onTapCancel: isMuted ? null : onStopSpeaking,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: isMuted
                ? Colors.grey
                : (isSpeaking ? AppColors.error : AppColors.primary),
            borderRadius: BorderRadius.circular(32),
            boxShadow: isSpeaking
                ? [
                    BoxShadow(
                      color: AppColors.error.withAlpha(128),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMuted
                    ? Icons.mic_off
                    : (isSpeaking ? Icons.mic : Icons.mic_none),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isMuted
                    ? 'Muted'
                    : (isSpeaking ? 'Release to send' : 'Hold to talk'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
