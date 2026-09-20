import React, { useState, useRef } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Copy, Check, Download, ShieldAlert, ChevronDown, ChevronUp, Smartphone, QrCode } from 'lucide-react';
import { buildPairingQrPayload, downloadQrSvgAsPng, PAIRING_QR_I18N } from '../utils/pairingQr';

/**
 * PairingQrPanel
 * 
 * Displays a crisp, reliably scannable client-side SVG QR code for the paired device code.
 * Follows accessibility guidelines, responsive stacking, dark/light contrast rules, and print styles.
 */
export const PairingQrPanel = ({
  code,
  patientId,
  isLinked = false,
  lastSynced = null,
  deviceName = 'Patient Device',
  language = 'en',
  isLoading = false,
  onEnlarge = null,
}) => {
  const [copied, setCopied] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [showAnyway, setShowAnyway] = useState(false);
  const qrSvgRef = useRef(null);

  const t = PAIRING_QR_I18N[language] || PAIRING_QR_I18N.en;
  const cleanCode = (code || '').replace(/^PAIR-/, '').trim();
  const payload = buildPairingQrPayload(cleanCode);

  // Accessible spaced digits for screen-reader pronunciation
  const spacedCode = cleanCode ? cleanCode.split('').join(' ') : '';
  const qrAriaLabel = cleanCode ? `QR code for pairing code ${spacedCode}` : 'Pairing QR code';

  const handleCopy = async () => {
    if (!cleanCode) return;
    try {
      if (navigator?.clipboard?.writeText) {
        await navigator.clipboard.writeText(cleanCode);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = cleanCode;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy pairing code:', err);
    }
  };

  const handleDownload = async () => {
    if (!qrSvgRef.current) return;
    try {
      setDownloading(true);
      const filename = `smriti-kunj-pairing-${patientId || cleanCode || 'device'}.png`;
      await downloadQrSvgAsPng(qrSvgRef.current, filename);
    } catch (err) {
      console.error('Failed to download QR PNG:', err);
    } finally {
      setDownloading(false);
    }
  };

  // Loading skeleton state
  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center p-4 bg-cream/40 dark:bg-ink-soft/20 rounded-2xl border border-border/70 dark:border-ink-soft/30 min-h-[260px] animate-pulse">
        <div className="w-44 h-44 bg-border/40 dark:bg-ink-soft/40 rounded-2xl mb-3" />
        <div className="w-32 h-4 bg-border/40 dark:bg-ink-soft/40 rounded mb-2" />
        <div className="w-24 h-6 bg-border/40 dark:bg-ink-soft/40 rounded" />
      </div>
    );
  }

  // Already paired state - calm status card with disclosure
  if (isLinked && !showAnyway) {
    return (
      <div className="flex flex-col items-center justify-center text-center p-5 bg-sage/5 dark:bg-sage/10 rounded-2xl border border-sage/30">
        <div className="w-12 h-12 rounded-full bg-sage/20 text-sage flex items-center justify-center mb-3">
          <Smartphone className="w-6 h-6" />
        </div>
        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-sage/15 text-sage text-xs font-bold mb-2">
          <span className="w-2 h-2 rounded-full bg-sage animate-pulse" />
          <span>{t.devicePaired}</span>
        </div>
        <p className="text-sm font-semibold text-ink dark:text-cream mb-1">
          {deviceName}
        </p>
        {lastSynced && (
          <p className="text-xs text-ink-soft dark:text-cream/70 mb-4">
            Last Synced: {lastSynced}
          </p>
        )}

        {cleanCode && (
          <button
            type="button"
            onClick={() => setShowAnyway(true)}
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-terracotta hover:text-terracotta-dark dark:hover:text-terracotta/90 transition-colors focus:outline-hidden focus-visible:ring-2 focus-visible:ring-terracotta/50 rounded-md py-1 px-2 cursor-pointer"
          >
            <span>{t.showAnyway}</span>
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
    );
  }

  // Missing code state
  if (!cleanCode || !payload) {
    return (
      <div className="flex flex-col items-center justify-center text-center p-6 bg-cream/40 dark:bg-ink-soft/20 rounded-2xl border border-border/80 dark:border-ink-soft/30 min-h-[220px]">
        <QrCode className="w-10 h-10 text-ink-soft/40 dark:text-cream/30 mb-2" />
        <p className="text-xs sm:text-sm font-semibold text-ink-soft dark:text-cream/70">
          {t.codeUnavailable}
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center text-center">
      {/* Paired disclosure hide button if currently expanded */}
      {isLinked && showAnyway && (
        <div className="mb-3 w-full flex justify-end">
          <button
            type="button"
            onClick={() => setShowAnyway(false)}
            className="inline-flex items-center gap-1 text-[11px] font-semibold text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream transition-colors cursor-pointer"
          >
            <span>{t.hideAnyway}</span>
            <ChevronUp className="w-3 h-3" />
          </button>
        </div>
      )}

      {/* Crisp White QR Tile - White background in both light and dark themes */}
      <div className="relative group">
        <div
          className="relative bg-white p-3.5 sm:p-4 rounded-2xl shadow-sm border border-terracotta/20 dark:border-terracotta/30 transition-transform duration-200"
          style={{ backgroundColor: '#FFFFFF' }}
        >
          {/* Subtle cultural terracotta corner accents */}
          <span className="absolute top-1.5 left-1.5 w-2 h-2 border-t-2 border-l-2 border-terracotta/40 rounded-tl-sm pointer-events-none" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 border-t-2 border-r-2 border-terracotta/40 rounded-tr-sm pointer-events-none" />
          <span className="absolute bottom-1.5 left-1.5 w-2 h-2 border-b-2 border-l-2 border-terracotta/40 rounded-bl-sm pointer-events-none" />
          <span className="absolute bottom-1.5 right-1.5 w-2 h-2 border-b-2 border-r-2 border-terracotta/40 rounded-br-sm pointer-events-none" />

          <QRCodeSVG
            ref={qrSvgRef}
            value={payload}
            size={176}
            level="M"
            bgColor="#FFFFFF"
            fgColor="#0F172A"
            includeMargin={true}
            marginSize={4}
            role="img"
            aria-label={qrAriaLabel}
            className="block select-none"
          />
        </div>

        {/* Optional Enlarge overlay button on hover/focus for convenience */}
        {onEnlarge && (
          <button
            type="button"
            onClick={onEnlarge}
            aria-label={t.enlargeQr}
            title={t.enlargeQr}
            className="absolute inset-0 w-full h-full rounded-2xl bg-ink/10 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity flex items-center justify-center cursor-pointer print:hidden"
          >
            <span className="px-2.5 py-1 rounded-full bg-ink/80 text-white text-[11px] font-semibold backdrop-blur-xs shadow-md">
              {t.enlargeQr}
            </span>
          </button>
        )}
      </div>

      {/* Caption under tile */}
      <p className="mt-3 text-xs font-semibold text-ink-soft dark:text-cream/80 max-w-[220px] leading-relaxed">
        {t.scanCaption}
      </p>

      {/* Code Text & Action Buttons */}
      <div className="mt-2.5 flex items-center gap-2">
        <code className="font-mono text-sm sm:text-base font-extrabold tracking-widest text-ink dark:text-cream bg-cream/70 dark:bg-ink-soft/40 px-2.5 py-1 rounded-lg border border-border/80 dark:border-ink-soft/40 select-all">
          {cleanCode}
        </code>

        {/* Copy Button - Accessible 44px min target */}
        <button
          type="button"
          onClick={handleCopy}
          aria-label={copied ? t.copied : `${t.copy} ${cleanCode}`}
          className="min-w-[44px] min-h-[44px] inline-flex items-center justify-center p-2 rounded-xl bg-cream/70 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream border border-border/80 dark:border-ink-soft/40 transition-colors focus:outline-hidden focus-visible:ring-2 focus-visible:ring-terracotta cursor-pointer select-none print:hidden"
          title={copied ? t.copied : t.copy}
        >
          {copied ? (
            <Check className="w-4 h-4 text-sage stroke-[2.5]" />
          ) : (
            <Copy className="w-4 h-4" />
          )}
        </button>

        {/* Download PNG Button - Accessible 44px min target */}
        <button
          type="button"
          onClick={handleDownload}
          disabled={downloading}
          aria-label={downloading ? t.downloading : t.downloadPng}
          className="min-w-[44px] min-h-[44px] inline-flex items-center justify-center p-2 rounded-xl bg-terracotta/10 hover:bg-terracotta/20 dark:bg-terracotta/20 dark:hover:bg-terracotta/30 text-terracotta border border-terracotta/30 transition-colors focus:outline-hidden focus-visible:ring-2 focus-visible:ring-terracotta cursor-pointer select-none disabled:opacity-50 print:hidden"
          title={t.downloadPng}
        >
          <Download className="w-4 h-4" />
        </button>
      </div>

      {/* Security note */}
      <p className="mt-2 text-[11px] text-ink-soft/80 dark:text-cream/60 flex items-center gap-1">
        <ShieldAlert className="w-3 h-3 text-terracotta/70 shrink-0" />
        <span>{t.securityHint}</span>
      </p>
    </div>
  );
};
