/**
 * Utility functions and i18n dictionary for paired device QR code generation and export.
 */

/**
 * Builds the standard deep-link payload for the patient pairing QR code.
 * Format: smritikunj://pair?code=<PAIRED_DEVICE_CODE>
 * 
 * Never contains personal identifiable data (no name, ID, or DOB).
 *
 * @param {string} code - The 6-character pairing code
 * @returns {string} The standardized pairing deep link, or empty string if invalid.
 */
export function buildPairingQrPayload(code) {
  if (!code || typeof code !== 'string') {
    return '';
  }
  const cleanCode = code.replace(/^PAIR-/, '').trim();
  if (!cleanCode) {
    return '';
  }
  return `smritikunj://pair?code=${cleanCode}`;
}

/**
 * Exports an SVG element to a high-resolution 1024x1024 PNG on a crisp white background.
 * Purely client-side with no external services or network calls.
 *
 * @param {SVGElement} svgElement - The SVG DOM node
 * @param {string} filename - The target filename for download
 * @returns {Promise<void>}
 */
export async function downloadQrSvgAsPng(svgElement, filename = 'smriti-kunj-pairing.png') {
  if (!svgElement) return;

  try {
    const serializer = new XMLSerializer();
    let svgString = serializer.serializeToString(svgElement);

    // Ensure xmlns is present for standalone rendering
    if (!svgString.match(/^<svg[^>]+xmlns="http:\/\/www\.w3\.org\/2000\/svg"/)) {
      svgString = svgString.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"');
    }

    const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
    const URL = window.URL || window.webkitURL || window;
    const blobURL = URL.createObjectURL(svgBlob);

    const image = new Image();
    image.crossOrigin = 'anonymous';

    await new Promise((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = (err) => reject(err);
      image.src = blobURL;
    });

    // Create 1024x1024 canvas for crisp print/scan quality
    const canvas = document.createElement('canvas');
    const targetDimension = 1024;
    canvas.width = targetDimension;
    canvas.height = targetDimension;
    const ctx = canvas.getContext('2d');

    if (!ctx) {
      throw new Error('Canvas 2D context unavailable');
    }

    // Fill background with clean solid white
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, targetDimension, targetDimension);

    // Draw SVG scaled to target dimension with a pleasant quiet margin
    const margin = 64;
    const drawSize = targetDimension - (margin * 2);
    ctx.drawImage(image, margin, margin, drawSize, drawSize);

    URL.revokeObjectURL(blobURL);

    // Trigger download
    const pngUrl = canvas.toDataURL('image/png');
    const downloadLink = document.createElement('a');
    downloadLink.download = filename;
    downloadLink.href = pngUrl;
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
  } catch (error) {
    console.error('Failed to export QR code PNG:', error);
    throw error;
  }
}

export const PAIRING_QR_I18N = {
  en: {
    scanCaption: 'Scan with the patient tablet to pair',
    securityHint: "Only show this to the patient's tablet.",
    copy: 'Copy',
    copied: 'Copied!',
    downloadPng: 'Download QR',
    downloading: 'Downloading...',
    devicePaired: 'Device paired',
    showAnyway: 'Show pairing QR anyway',
    hideAnyway: 'Hide pairing QR',
    codeUnavailable: 'Pairing code not available yet',
    enlargeQr: 'Enlarge pairing QR code',
    modalTitle: 'Device Pairing QR Code',
    modalDesc: "Scan this code directly with the patient's tablet screen or camera to complete setup.",
    close: 'Close dialog',
  },
  as: {
    scanCaption: 'সংযুক্ত কৰিবলৈ ৰোগীৰ টেবলেটৰ পৰা স্কেন কৰক',
    securityHint: "কেৱল ৰোগীৰ টেবলেটতহে এইটো প্ৰদৰ্শন কৰক।",
    copy: 'কপি কৰক',
    copied: 'কপি কৰা হ’ল!',
    downloadPng: 'QR ডাউনলোড কৰক',
    downloading: 'ডাউনলোড হৈ আছে...',
    devicePaired: 'ডিভাইচ সংযুক্ত হৈ আছে',
    showAnyway: 'তথাপিও সংযোগী QR ক’ড চাওক',
    hideAnyway: 'QR ক’ড লুকুৱাওক',
    codeUnavailable: 'সংযোগী ক’ড এতিয়াও উপলব্ধ নহয়',
    enlargeQr: 'ডাঙৰকৈ QR ক’ড চাওক',
    modalTitle: 'ডিভাইচ সংযোগৰ QR ক’ড',
    modalDesc: "সংযোগ সম্পূৰ্ণ কৰিবলৈ ৰোগীৰ টেবলেটৰ পৰা পোনপটীয়াকৈ স্কেন কৰক।",
    close: 'ডায়ালগ বন্ধ কৰক',
  },
  bn: {
    scanCaption: 'যুক্ত করতে রোগীর ট্যাবলেট দিয়ে স্ক্যান করুন',
    securityHint: 'শুধুমাত্র রোগীর ট্যাবলেটেই এটি প্রদর্শন করুন।',
    copy: 'কপি করুন',
    copied: 'কপি করা হয়েছে!',
    downloadPng: 'QR ডাউনলোড করুন',
    downloading: 'ডাউনলোড হচ্ছে...',
    devicePaired: 'ডিভাইস সংযুক্ত আছে',
    showAnyway: 'তবুও পেয়ারিং QR দেখুন',
    hideAnyway: 'QR কোড লুকান',
    codeUnavailable: 'পেয়ারিং কোড এখনও উপলব্ধ নয়',
    enlargeQr: 'বড় করে QR কোড দেখুন',
    modalTitle: 'ডিভাইস পেয়ারিং QR কোড',
    modalDesc: 'সেটআপ সম্পন্ন করতে রোগীর ট্যাবলেট স্ক্রিন দিয়ে সরাসরি স্ক্যান করুন।',
    close: 'ডায়ালগ বন্ধ করুন',
  },
};
