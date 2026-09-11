import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum MemoryType { photo, audio }

class MemoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String relationship;
  final MemoryType type;
  final String? audioDuration;
  final IconData placeholderIcon;
  final Color accentColor;

  const MemoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.relationship,
    required this.type,
    this.audioDuration,
    required this.placeholderIcon,
    required this.accentColor,
  });
}

class MemoryGalleryScreen extends StatelessWidget {
  const MemoryGalleryScreen({super.key});

  static const List<MemoryItem> _mockMemories = [
    MemoryItem(
      id: 'mem_1',
      title: 'Zara Begum',
      subtitle: 'Birthday celebration with family',
      relationship: 'Granddaughter',
      type: MemoryType.photo,
      placeholderIcon: Icons.celebration_rounded,
      accentColor: AppColors.terracotta,
    ),
    MemoryItem(
      id: 'mem_2',
      title: 'Voice from Priya',
      subtitle: '"Good morning Baba, take your medicines!"',
      relationship: 'Daughter',
      type: MemoryType.audio,
      audioDuration: '0:45 min',
      placeholderIcon: Icons.mic_rounded,
      accentColor: AppColors.mugaGold,
    ),
    MemoryItem(
      id: 'mem_3',
      title: 'Family at Shillong',
      subtitle: 'Spring holiday in the gardens',
      relationship: 'Family Vacation',
      type: MemoryType.photo,
      placeholderIcon: Icons.nature_people_rounded,
      accentColor: AppColors.sageGreen,
    ),
    MemoryItem(
      id: 'mem_4',
      title: 'Voice from Rohit',
      subtitle: '"Have a peaceful walk in the garden"',
      relationship: 'Son',
      type: MemoryType.audio,
      audioDuration: '1:10 min',
      placeholderIcon: Icons.record_voice_over_rounded,
      accentColor: AppColors.mugaGold,
    ),
    MemoryItem(
      id: 'mem_5',
      title: 'Meera & Aarav',
      subtitle: 'Golden jubilee portrait',
      relationship: 'Anniversary Memory',
      type: MemoryType.photo,
      placeholderIcon: Icons.favorite_rounded,
      accentColor: AppColors.terracotta,
    ),
    MemoryItem(
      id: 'mem_6',
      title: 'Children Laughing',
      subtitle: 'Zara & Kabir singing songs together',
      relationship: 'Grandchildren',
      type: MemoryType.audio,
      audioDuration: '0:30 min',
      placeholderIcon: Icons.music_note_rounded,
      accentColor: AppColors.sageGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 32, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Home',
        ),
        title: Text(
          'Family & Memories',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemCount: _mockMemories.length,
          itemBuilder: (context, index) {
            final item = _mockMemories[index];
            return _MemoryThumbnailCard(
              item: item,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemoryDetailScreen(
                      memories: _mockMemories,
                      initialIndex: index,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MemoryThumbnailCard extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onTap;

  const _MemoryThumbnailCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAudio = item.type == MemoryType.audio;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.relationship}, ${isAudio ? "Audio message" : "Photo memory"}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media visual frame / icon banner
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: item.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.accentColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          item.placeholderIcon,
                          size: 52,
                          color: item.accentColor,
                        ),
                        // Badge in corner for type
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAudio ? Icons.volume_up_rounded : Icons.photo_camera_rounded,
                                  size: 16,
                                  color: AppColors.inkSoft,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAudio ? 'Voice' : 'Photo',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Name / Title
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),

                // Relationship label
                Text(
                  item.relationship,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen one-at-a-time memory viewer with swipe or tap to go back.
class MemoryDetailScreen extends StatefulWidget {
  final List<MemoryItem> memories;
  final int initialIndex;

  const MemoryDetailScreen({
    super.key,
    required this.memories,
    required this.initialIndex,
  });

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAudio() {
    setState(() {
      _isPlayingAudio = !_isPlayingAudio;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 32, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Gallery',
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.memories.length}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.memories.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _isPlayingAudio = false; // Reset play state on swipe
            });
          },
          itemBuilder: (context, index) {
            final item = widget.memories[index];
            return _buildSingleMemoryView(item);
          },
        ),
      ),
    );
  }

  Widget _buildSingleMemoryView(MemoryItem item) {
    final isAudio = item.type == MemoryType.audio;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Visual Card
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isAudio
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large Play / Pause button (no scrubber per spec)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleAudio,
                          borderRadius: BorderRadius.circular(50),
                          child: Ink(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.terracotta,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.terracotta.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isPlayingAudio ? 'Playing voice note...' : 'Tap to play voice',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (item.audioDuration != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Duration: ${item.audioDuration}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: item.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.placeholderIcon,
                            size: 100,
                            color: item.accentColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Family Photograph',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: item.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Memory details card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Text(
                        item.relationship,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
