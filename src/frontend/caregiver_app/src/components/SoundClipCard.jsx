import React, { useState, useRef, useEffect } from 'react';
import { Volume2, VolumeX, Trash2, Play, Pause, Music } from 'lucide-react';
import { ConfirmDeleteModal } from './ConfirmDeleteModal';

/**
 * Format time in seconds to mm:ss format
 */
const formatTime = (timeInSeconds) => {
  if (isNaN(timeInSeconds) || !isFinite(timeInSeconds) || timeInSeconds <= 0) {
    return '0:00';
  }
  const minutes = Math.floor(timeInSeconds / 60);
  const seconds = Math.floor(timeInSeconds % 60);
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
};

/**
 * SoundClipCard
 *
 * Custom brand-styled audio player for uploaded memory sound clips.
 * Replaces native HTML5 controls with a terracotta-accented custom UI.
 *
 * Props:
 *   sound    {Object}   - { id, caption, audioUrl }
 *   onDelete {Function} - Callback with sound.id when remove button is clicked
 */
export const SoundClipCard = ({ sound, onDelete }) => {
  const audioRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [pendingDelete, setPendingDelete] = useState(false);

  // Reset playback when audio source changes
  useEffect(() => {
    setIsPlaying(false);
    setCurrentTime(0);
    setDuration(0);
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
    }
  }, [sound?.audioUrl]);

  if (!sound) return null;

  const togglePlay = () => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
    } else {
      audioRef.current.play().catch((err) => {
        console.error('Audio playback error:', err);
      });
    }
  };

  const toggleMute = () => {
    if (!audioRef.current) return;
    const nextMuted = !isMuted;
    audioRef.current.muted = nextMuted;
    setIsMuted(nextMuted);
  };

  const handleTimeUpdate = () => {
    if (audioRef.current) {
      setCurrentTime(audioRef.current.currentTime);
    }
  };

  const handleLoadedMetadata = () => {
    if (audioRef.current) {
      setDuration(audioRef.current.duration || 0);
    }
  };

  const handleEnded = () => {
    setIsPlaying(false);
    setCurrentTime(0);
    if (audioRef.current) {
      audioRef.current.currentTime = 0;
    }
  };

  const handleSeekChange = (e) => {
    const seekTo = parseFloat(e.target.value);
    setCurrentTime(seekTo);
    if (audioRef.current) {
      audioRef.current.currentTime = seekTo;
    }
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <div className="bg-cream/60 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-card p-3.5 space-y-3 transition-all hover:shadow-2xs group">
      {/* Hidden native audio element for playback orchestration */}
      <audio
        ref={audioRef}
        src={sound.audioUrl}
        onTimeUpdate={handleTimeUpdate}
        onLoadedMetadata={handleLoadedMetadata}
        onDurationChange={handleLoadedMetadata}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
        onEnded={handleEnded}
        preload="metadata"
        className="hidden"
      />

      {/* Header: Title / Caption & Delete Button */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <div className="w-7 h-7 rounded-full bg-cream dark:bg-ink-soft/40 border border-border/60 dark:border-ink-soft/30 flex items-center justify-center text-terracotta shrink-0">
            <Music className="w-3.5 h-3.5" />
          </div>
          <h4 className="text-xs sm:text-sm font-bold text-ink dark:text-cream truncate" title={sound.caption}>
            {sound.caption}
          </h4>
        </div>

        {onDelete && (
          <button
            type="button"
            onClick={() => setPendingDelete(true)}
            aria-label={`Delete sound clip: ${sound.caption}`}
            className="p-1.5 text-ink-soft/70 hover:text-terracotta dark:text-cream/60 dark:hover:text-terracotta rounded-md hover:bg-cream dark:hover:bg-ink-soft/40 transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta shrink-0"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        )}
      </div>

      {/* Custom Brand-Styled Player Container */}
      <div className="bg-surface/90 dark:bg-ink/40 border border-border/70 dark:border-ink-soft/30 rounded-lg p-2.5 flex items-center gap-3">
        {/* Play / Pause Button */}
        <button
          type="button"
          onClick={togglePlay}
          aria-label={isPlaying ? `Pause sound: ${sound.caption}` : `Play sound: ${sound.caption}`}
          className="w-8 h-8 rounded-full bg-terracotta text-cream flex items-center justify-center hover:bg-terracotta/90 active:scale-95 transition-all shadow-2xs shrink-0 outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta/50"
        >
          {isPlaying ? (
            <Pause className="w-3.5 h-3.5 fill-current" />
          ) : (
            <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
          )}
        </button>

        {/* Progress Bar & Seek Slider */}
        <div className="flex-1 flex flex-col justify-center gap-1 min-w-0">
          <div className="relative flex items-center group/track py-1">
            {/* Background Track */}
            <div className="w-full h-1.5 bg-cream/80 dark:bg-ink-soft/50 border border-border/60 dark:border-ink-soft/30 rounded-full overflow-hidden relative">
              {/* Progress Fill */}
              <div
                className="h-full bg-terracotta transition-all duration-75"
                style={{ width: `${progressPercent}%` }}
              />
            </div>

            {/* Custom Interactive Seek Overlay (Accessible input range) */}
            <input
              type="range"
              min="0"
              max={duration || 0}
              step="0.1"
              value={currentTime}
              onChange={handleSeekChange}
              aria-label={`Seek audio position for ${sound.caption}`}
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
            />
          </div>

          {/* Time Display */}
          <div className="flex items-center justify-between text-[10px] font-mono text-ink-soft/80 dark:text-cream/60 select-none">
            <span>{formatTime(currentTime)}</span>
            <span>{formatTime(duration)}</span>
          </div>
        </div>

        {/* Mute / Unmute Toggle */}
        <button
          type="button"
          onClick={toggleMute}
          aria-label={isMuted ? 'Unmute sound' : 'Mute sound'}
          className="p-1.5 text-ink-soft/70 hover:text-ink dark:text-cream/60 dark:hover:text-cream rounded-md hover:bg-cream dark:hover:bg-ink-soft/40 transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta shrink-0"
        >
          {isMuted ? (
            <VolumeX className="w-4 h-4 text-terracotta" />
          ) : (
            <Volume2 className="w-4 h-4" />
          )}
        </button>
      </div>

      {/* Confirm delete dialog */}
      {pendingDelete && (
        <ConfirmDeleteModal
          message={`Delete "${sound.caption}"? The audio clip will be permanently removed.`}
          onConfirm={() => {
            setPendingDelete(false);
            onDelete(sound.id);
          }}
          onCancel={() => setPendingDelete(false)}
        />
      )}
    </div>
  );
};

export default SoundClipCard;

