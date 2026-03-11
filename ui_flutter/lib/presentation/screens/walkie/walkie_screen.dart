import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../../core/network/api_client.dart';
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
  WalkieMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _walkieBloc = WalkieBloc();
    _initializeWalkie();
  }

  Future<void> _initializeWalkie() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      String? teamId = authState.user.teamId;

      // If user is a team leader but has no teamId, fetch their led team
      if (teamId == null && authState.user.isTeamLeader) {
        teamId = await _fetchLedTeamId(authState.user.id);
      }

      if (teamId != null) {
        _walkieBloc.add(
          WalkieLoadChannels(
            teamId: teamId,
            userId: authState.user.id,
            userName: authState.user.fullName,
          ),
        );
      }
    }
  }

  Future<String?> _fetchLedTeamId(String leaderId) async {
    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.get('/api/teams?leader_id=$leaderId');
      if (response.statusCode == 200) {
        final data = response.data;
        final teams = data is List ? data : data['teams'] ?? [];
        if (teams.isNotEmpty) {
          return teams[0]['id']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  void _setReplyingTo(WalkieMessage? message) {
    setState(() => _replyingTo = message);
    if (message != null) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _walkieBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _walkieBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speaker_phone,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Walkie Talkie',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
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
          ],
        ),
        body: BlocBuilder<WalkieBloc, WalkieState>(
          builder: (context, state) {
            if (state is WalkieLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is WalkieError) {
              return _buildErrorView(state.message, isDark);
            }

            if (state is WalkieChannelsLoaded) {
              return _buildChannelList(state.channels, isDark);
            }

            if (state is WalkieInChannel) {
              return _buildActiveChannel(state, isDark);
            }

            return _buildEmptyView(isDark);
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Error',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _initializeWalkie(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.speaker_phone,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Team Assigned',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Join a team to access walkie-talkie channels',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(List<WalkieChannel> channels, bool isDark) {
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.speaker_phone,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Channels Available',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your team has no walkie-talkie channels yet',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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
          isDark: isDark,
          onTap: () {
            _walkieBloc.add(
              WalkieJoinChannel(
                channelId: channel.id,
                channelName: channel.name,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveChannel(WalkieInChannel state, bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.participants.length,
              itemBuilder: (context, index) {
                final participant = state.participants[index];
                return _ParticipantChip(
                  participant: participant,
                  isDark: isDark,
                );
              },
            ),
          ),

        const Divider(height: 1),

        // Messages list
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hold the button to talk',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        state.messages[state.messages.length - 1 - index];
                    return _CompactMessageTile(
                      message: message,
                      isDark: isDark,
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
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

        // Push-to-talk area
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomPadding),
          child: Row(
            children: [
              // Leave channel button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.withAlpha(40)
                      : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: () => _walkieBloc.add(const WalkieLeaveChannel()),
                  icon: const Icon(Icons.exit_to_app, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // PTT button
              Expanded(
                child: _CompactPTTButton(
                  isSpeaking: state.isSpeaking,
                  isMuted: state.isMuted,
                  onStartSpeaking: () =>
                      _walkieBloc.add(const WalkieStartSpeaking()),
                  onStopSpeaking: () =>
                      _walkieBloc.add(const WalkieStopSpeaking()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Reusable sub-widgets ---

class _ChannelCard extends StatelessWidget {
  final WalkieChannel channel;
  final bool isDark;
  final VoidCallback onTap;

  const _ChannelCard({
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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getChannelIcon(channel.channelType),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: channel.isActive
                                ? AppColors.success
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${channel.participantCount} online',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
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

class _ParticipantChip extends StatelessWidget {
  final WalkieParticipant participant;
  final bool isDark;

  const _ParticipantChip({required this.participant, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: participant.isSpeaking
                      ? Border.all(color: AppColors.success, width: 2)
                      : null,
                ),
                child: CircleAvatar(
                  radius: 19,
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
                            fontSize: 14,
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
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 50,
            child: Text(
              participant.displayName.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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
  final void Function(WalkieMessage)? onReply;

  const _CompactMessageTile({
    required this.message,
    required this.isDark,
    this.onReply,
  });

  @override
  State<_CompactMessageTile> createState() => _CompactMessageTileState();
}

class _CompactMessageTileState extends State<_CompactMessageTile> {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _progressSub;

  @override
  void dispose() {
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

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
          ? (_position.inMilliseconds / totalDuration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
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
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
                color: AppColors.success.withAlpha(
                  (128 * _controller.value).toInt(),
                ),
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
    final displayLevel = widget.audioLevel > 0.01 ? widget.audioLevel : 0.0;
    final hasSignal = displayLevel > 0.05;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasSignal
            ? AppColors.success.withAlpha(20)
            : (isDark ? Colors.grey.withAlpha(20) : Colors.grey.withAlpha(15)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSignal
              ? AppColors.success.withAlpha(100)
              : Colors.grey.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasSignal ? AppColors.success : AppColors.error,
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
                child: const Icon(Icons.mic, color: Colors.white, size: 20),
              );
            },
          ),
          const SizedBox(width: 12),
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
                Row(
                  children: List.generate(20, (index) {
                    final threshold = index / 20;
                    final isActive = displayLevel > threshold;
                    final animatedActive =
                        !hasSignal &&
                        index < 3 &&
                        _animController.value > (index * 0.3);

                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        height: 14,
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
