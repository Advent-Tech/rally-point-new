import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    _walkieBloc = WalkieBloc();
    _loadChannels();
  }

  void _loadChannels() {
    String? teamId = widget.teamId;
    String? userId;
    String? userName;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      teamId ??= authState.user.teamId;
      userId = authState.user.id;
      userName = authState.user.displayName;
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
                    final message = state.messages[state.messages.length - 1 - index];
                    return _CompactMessageTile(
                      message: message,
                      isDark: isDark,
                      onPlay: message.messageType == 'voice' && message.audioUrl != null
                          ? () => _walkieBloc.add(WalkiePlayMessage(messageId: message.id))
                          : null,
                    );
                  },
                ),
        ),

        // Audio level indicator when speaking
        if (state.isSpeaking)
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.audioLevel.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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

class _CompactMessageTile extends StatelessWidget {
  final WalkieMessage message;
  final bool isDark;
  final VoidCallback? onPlay;

  const _CompactMessageTile({
    required this.message,
    required this.isDark,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withAlpha(50),
            child: Text(
              message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _buildContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.messageType == 'voice') {
      return GestureDetector(
        onTap: onPlay,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                message.formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.messageType == 'alert') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              message.text ?? 'Alert',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      );
    }

    return Text(
      message.text ?? '',
      style: const TextStyle(fontSize: 13),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _CompactPTTButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: isMuted ? null : (_) => onStartSpeaking(),
      onTapUp: isMuted ? null : (_) => onStopSpeaking(),
      onTapCancel: isMuted ? null : onStopSpeaking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: isMuted
              ? Colors.grey
              : (isSpeaking ? AppColors.error : AppColors.primary),
          borderRadius: BorderRadius.circular(26),
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: AppColors.error.withAlpha(100),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMuted ? Icons.mic_off : (isSpeaking ? Icons.mic : Icons.mic_none),
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isMuted ? 'Muted' : (isSpeaking ? 'Release to send' : 'Hold to talk'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
