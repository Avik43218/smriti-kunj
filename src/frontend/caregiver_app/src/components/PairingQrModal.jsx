import React, { useState, useRef } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { X, Copy, Check, Download, ShieldAlert, Smartphone } from 'lucide-react';
import { Modal } from './Modal';
import { buildPairingQrPayload, downloadQrSvgAsPng, PAIRING_QR_I18N } from '../utils/pairingQr';

/**
 * PairingQrModal
 * 
 * Accessible enlarged QR code dialog for scanning across a table or high-DPI viewing.
 * Powered by the shared Portal Modal with trapped focus and scroll lock.
 */
export const PairingQrModal = ({
  isOpen,
  onClose,
  code,
  patientId,
  patientName,
  language = 'en',
}) => {
  const [copied, setCopied] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const qrSvgRef = useRef(null);

  const t = PAIRING_QR_I18N[language] || PAIRING_QR_I18N.en;
  const cleanCode = (code || '').replace(/^PAIR-/, '').trim();
  const payload = buildPairingQrPayload(cleanCode);

  const spacedCode = cleanCode ? cleanCode.split('').join(' ') : '';
  const qrAriaLabel = cleanCode ? `Enlarged QR code for pairing code ${spacedCode}` : 'Pairing QR code';

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

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      titleId="pairing-qr-modal-title"
      descriptionId="pairing-qr-modal-desc"
      maxWidth="max-w-md"
    >
      <div className="p-6">
        {/* Header */}
        <div className="flex items-start justify-between gap-3 pb-4 border-b border-border/80 dark:border-ink-soft/40">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-terracotta/10 dark:bg-terracotta/20 text-terracotta flex items-center justify-center shrink-0">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <h3
                id="pairing-qr-modal-title"
                className="text-base sm:text-lg font-bold text-ink dark:text-cream leading-snug"
              >
                {t.modalTitle}
              </h3>
              {patientName && (
                <p className="text-xs text-ink-soft dark:text-cream/70 font-medium">
                  {patientName}
                </p>
              )}
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label={t.close}
            className="p-1.5 rounded-lg text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/40 transition-colors cursor-pointer select-none"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Description */}
        <p
          id="pairing-qr-modal-desc"
          className="mt-3 text-xs sm:text-sm text-ink-soft dark:text-cream/80 text-center"
        >
          {t.modalDesc}
        </p>

        {/* QR Code Container */}
        <div className="mt-5 flex flex-col items-center">
          {cleanCode && payload ? (
            <div
              className="relative bg-white p-5 rounded-2xl shadow-sm border border-terracotta/25 dark:border-terracotta/35 select-none"
              style={{ backgroundColor: '#FFFFFF' }}
            >
              {/* Subtle terracotta corners */}
              <span className="absolute top-2 left-2 w-3 h-3 border-t-2 border-l-2 border-terracotta/50 rounded-tl-sm pointer-events-none" />
              <span className="absolute top-2 right-2 w-3 h-3 border-t-2 border-r-2 border-terracotta/50 rounded-tr-sm pointer-events-none" />
              <span className="absolute bottom-2 left-2 w-3 h-3 border-b-2 border-l-2 border-terracotta/50 rounded-bl-sm pointer-events-none" />
              <span className="absolute bottom-2 right-2 w-3 h-3 border-b-2 border-r-2 border-terracotta/50 rounded-br-sm pointer-events-none" />

              <QRCodeSVG
                ref={qrSvgRef}
                value={payload}
                size={260}
                level="M"
                bgColor="#FFFFFF"
                fgColor="#0F172A"
                includeMargin={true}
                marginSize={4}
                role="img"
                aria-label={qrAriaLabel}
                className="block max-w-[min(70vw,260px)] max-h-[min(70vw,260px)]"
              />
            </div>
          ) : (
            <div className="p-8 text-center text-sm font-semibold text-ink-soft dark:text-cream/60">
              {t.codeUnavailable}
            </div>
          )}

          {/* Caption */}
          <p className="mt-3 text-xs font-semibold text-ink-soft dark:text-cream/80 text-center">
            {t.scanCaption}
          </p>

          {/* Large Code & Actions */}
          <div className="mt-3 flex items-center gap-2">
            <code className="font-mono text-base sm:text-lg font-extrabold tracking-widest text-ink dark:text-cream bg-cream/70 dark:bg-ink-soft/40 px-3.5 py-1.5 rounded-lg border border-border/80 dark:border-ink-soft/40 select-all">
              {cleanCode}
            </code>

            {/* Copy Button */}
            <button
              type="button"
              onClick={handleCopy}
              aria-label={copied ? t.copied : `${t.copy} ${cleanCode}`}
              className="min-w-[44px] min-h-[44px] inline-flex items-center justify-center p-2 rounded-xl bg-cream/70 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream border border-border/80 dark:border-ink-soft/40 transition-colors focus:outline-hidden focus-visible:ring-2 focus-visible:ring-terracotta cursor-pointer select-none"
              title={copied ? t.copied : t.copy}
            >
              {copied ? (
                <Check className="w-4 h-4 text-sage stroke-[2.5]" />
              ) : (
                <Copy className="w-4 h-4" />
              )}
            </button>

            {/* Download Button */}
            <button
              type="button"
              onClick={handleDownload}
              disabled={downloading}
              aria-label={downloading ? t.downloading : t.downloadPng}
              className="min-w-[44px] min-h-[44px] inline-flex items-center justify-center p-2 rounded-xl bg-terracotta/10 hover:bg-terracotta/20 dark:bg-terracotta/20 dark:hover:bg-terracotta/30 text-terracotta border border-terracotta/30 transition-colors focus:outline-hidden focus-visible:ring-2 focus-visible:ring-terracotta cursor-pointer select-none disabled:opacity-50"
              title={t.downloadPng}
            >
              <Download className="w-4 h-4" />
            </button>
          </div>

          {/* Security note */}
          <p className="mt-3 text-xs text-ink-soft/80 dark:text-cream/60 flex items-center gap-1.5 text-center">
            <ShieldAlert className="w-3.5 h-3.5 text-terracotta/80 shrink-0" />
            <span>{t.securityHint}</span>
          </p>
        </div>
      </div>
    </Modal>
  );
};
