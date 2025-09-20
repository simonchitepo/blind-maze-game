import 'package:flutter/material.dart';
import '../services/score_service.dart';

class LeaderboardScreen extends StatelessWidget {
  /// The current player's name, so we can highlight their row.
  final String playerName;

  const LeaderboardScreen({super.key, required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFEDEDF7)),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.leaderboard_rounded,
                      color: Color(0xFF7FD3FF), size: 26),
                  const SizedBox(width: 10),
                  const Text(
                    'LEADERBOARD',
                    style: TextStyle(
                      color: Color(0xFFEDEDF7),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // Live indicator dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF39FF14).withOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF39FF14),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Global ranking · unique cells explored per life',
                style: TextStyle(
                  color: Color(0xFF888899),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // ── Live list via Firestore stream ────────────────────────────
              Expanded(
                child: StreamBuilder<List<LeaderboardEntry>>(
                  stream: ScoreService.leaderboardStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7FD3FF),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _ErrorState(error: snapshot.error.toString());
                    }

                    final entries = snapshot.data ?? [];

                    if (entries.isEmpty) return const _EmptyState();

                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (ctx, i) => _EntryTile(
                        rank: i + 1,
                        entry: entries[i],
                        isMe: entries[i].playerName == playerName,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              color: Color(0xFF444455), size: 64),
          SizedBox(height: 16),
          Text(
            'No scores yet',
            style: TextStyle(
              color: Color(0xFF888899),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Explore cells to claim rank #1!',
            style: TextStyle(
              color: Color(0xFF555566),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF444455), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Could not load leaderboard',
            style: TextStyle(
              color: Color(0xFF888899),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Showing cached scores if available',
            style: TextStyle(
              color: const Color(0xFF555566).withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _EntryTile({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : rank == 3
        ? const Color(0xFFCD7F32)
        : null;

    final bg = isMe
        ? const Color(0x227FD3FF)
        : const Color(0x1617171F);

    final border = isMe
        ? Border.all(color: const Color(0x887FD3FF))
        : Border.all(color: const Color(0x22FFFFFF));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 36,
            child: Center(
              child: medalColor != null
                  ? Icon(Icons.emoji_events_rounded,
                  color: medalColor, size: 22)
                  : Text(
                '#$rank',
                style: const TextStyle(
                  color: Color(0xFF888899),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Player colour dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: entry.playerColor,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: entry.playerColor.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              entry.playerName,
              style: TextStyle(
                color: isMe
                    ? const Color(0xFF7FD3FF)
                    : const Color(0xFFEDEDF7),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Score with level badge (optional)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatScore(entry.score),
                style: TextStyle(
                  color: medalColor ??
                      (isMe
                          ? const Color(0xFF7FD3FF)
                          : const Color(0xFFEDEDF7)),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.level > 0) ...[
                    Text(
                      'Lvl ${entry.level}',
                      style: const TextStyle(
                        color: Color(0xFF666677),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Text(
                    'pts',
                    style: TextStyle(
                      color: Color(0xFF888899),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }
}