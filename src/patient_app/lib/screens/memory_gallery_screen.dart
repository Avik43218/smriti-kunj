import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/memory_item.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';

class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  List<MemoryItem> _memories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeId = SessionService.instance.patientId;
      final patientId = activeId.isNotEmpty
          ? activeId
          : (await ActivityDatabaseService.instance.getActivePatientId() ?? '');

      if (patientId.isEmpty) {
        final cached = await ActivityDatabaseService.instance.getPatientMemories('');
        if (mounted) {
          setState(() {
            _memories = cached;
            _isLoading = false;
          });
        }
        return;
      }

      final items = await ApiService.instance.fetchPatientMemories(patientId);
      if (mounted) {
        setState(() {
          _memories = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final cached = await ActivityDatabaseService.instance.getPatientMemories(
          SessionService.instance.patientId,
        );
        setState(() {
          _memories = cached;
          _isLoading = false;
          if (cached.isEmpty) {
            _errorMessage = 'Could not load memories. Pull down to retry.';
          }
        });
      }
    }
  }

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
        child: RefreshIndicator(
          color: AppColors.terracotta,
          onRefresh: _loadMemories,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.terracotta),
                )
              : _memories.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: AppColors.terracotta.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.photo_library_outlined,
                                      size: 42,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _errorMessage ?? 'No memories added yet',
                                    textAlign: TextAlign.center,
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your caregiver can add family photos and familiar voices from their dashboard.',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppColors.inkSoft,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _memories.length,
                      itemBuilder: (context, index) {
                        final item = _memories[index];
                        return _MemoryThumbnailCard(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemoryDetailScreen(
                                  memories: _memories,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
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

  Widget _buildThumbnailContent() {
    if (item.type == MemoryType.photo && item.photoUrl != null && item.photoUrl!.isNotEmpty) {
      final url = item.photoUrl!;
      if (url.startsWith('data:image')) {
        try {
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildFallbackContent(),
            ),
          );
        } catch (_) {
          return _buildFallbackContent();
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildFallbackContent(),
          ),
        );
      }
    }
    return _buildFallbackContent();
  }

  Widget _buildFallbackContent() {
    return Icon(
      item.placeholderIcon,
      size: 52,
      color: item.accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = item.audioUrl != null && item.audioUrl!.isNotEmpty;
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;
    final isAudio = item.type == MemoryType.audio || !hasPhoto;

    final String badgeLabel;
    final IconData badgeIcon;
    if (isAudio) {
      badgeLabel = 'Voice';
      badgeIcon = Icons.volume_up_rounded;
    } else if (hasAudio) {
      badgeLabel = 'Photo+Voice';
      badgeIcon = Icons.record_voice_over_rounded;
    } else {
      badgeLabel = 'Photo';
      badgeIcon = Icons.photo_camera_rounded;
    }

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
                        Positioned.fill(
                          child: _buildThumbnailContent(),
                        ),
                        // Badge in corner for type
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  badgeIcon,
                                  size: 16,
                                  color: AppColors.inkSoft,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  badgeLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
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

  Widget _buildPhotoDetail(MemoryItem item) {
    if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
      final url = item.photoUrl!;
      if (url.startsWith('data:image')) {
        try {
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildFallbackPhotoDetail(item),
            ),
          );
        } catch (_) {
          return _buildFallbackPhotoDetail(item);
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildFallbackPhotoDetail(item),
          ),
        );
      }
    }
    return _buildFallbackPhotoDetail(item);
  }

  Widget _buildFallbackPhotoDetail(MemoryItem item) {
    return Container(
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
    );
  }

  Widget _buildAudioPlayerCard(MemoryItem item, {bool compact = false}) {
    return Container(
      height: compact ? 110 : 320,
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
      child: compact
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleAudio,
                      borderRadius: BorderRadius.circular(30),
                      child: Ink(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.terracotta.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPlayingAudio ? 'Playing voice message...' : 'Tap to hear voice clip',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personal message from ${item.title}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large Play / Pause button
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
            ),
    );
  }

  Widget _buildSingleMemoryView(MemoryItem item) {
    final hasAudio = item.audioUrl != null && item.audioUrl!.isNotEmpty;
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;
    final isAudioOnly = item.type == MemoryType.audio || !hasPhoto;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Visual Card
          if (isAudioOnly)
            _buildAudioPlayerCard(item)
          else ...[
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
              child: _buildPhotoDetail(item),
            ),
            if (hasAudio) ...[
              const SizedBox(height: 16),
              _buildAudioPlayerCard(item, compact: true),
            ],
          ],
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
