import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { PairingQrPanel } from '../PairingQrPanel';
import { PairingQrModal } from '../PairingQrModal';

describe('PairingQrPanel', () => {
  it('renders QR SVG and printed code when code is available and unpaired', () => {
    render(<PairingQrPanel code="552785" patientId="patient-1" isLinked={false} />);

    expect(screen.getByText('552785')).toBeTruthy();
    expect(screen.getByText('Scan with the patient tablet to pair')).toBeTruthy();
    expect(screen.getByText("Only show this to the patient's tablet.")).toBeTruthy();

    const svg = screen.getByRole('img', { name: /QR code for pairing code 5 5 2 7 8 5/i });
    expect(svg).toBeTruthy();
  });

  it('does not render QR SVG when code is empty or missing', () => {
    render(<PairingQrPanel code="" patientId="patient-1" isLinked={false} />);

    expect(screen.getByText('Pairing code not available yet')).toBeTruthy();
    expect(screen.queryByRole('img', { name: /QR code/i })).toBeNull();
  });

  it('shows paired device status when isLinked is true, and reveals QR upon clicking disclosure', async () => {
    const user = userEvent.setup();
    render(
      <PairingQrPanel
        code="552785"
        patientId="patient-1"
        isLinked={true}
        deviceName="Grandma Tablet"
        lastSynced="Today at 10:30 AM"
      />
    );

    expect(screen.getByText('Device paired')).toBeTruthy();
    expect(screen.getByText('Grandma Tablet')).toBeTruthy();
    expect(screen.getByText(/Today at 10:30 AM/)).toBeTruthy();

    // QR SVG should not be visible initially
    expect(screen.queryByRole('img', { name: /QR code/i })).toBeNull();

    // Click "Show pairing QR anyway"
    const disclosureBtn = screen.getByRole('button', { name: /Show pairing QR anyway/i });
    await user.click(disclosureBtn);

    // Now QR code should be visible
    expect(screen.getByRole('img', { name: /QR code for pairing code 5 5 2 7 8 5/i })).toBeTruthy();
    expect(screen.getByText('552785')).toBeTruthy();
  });

  it('renders translated text when language is Assamese or Bengali', () => {
    const { rerender } = render(
      <PairingQrPanel code="552785" language="as" isLinked={false} />
    );
    expect(screen.getByText('সংযুক্ত কৰিবলৈ ৰোগীৰ টেবলেটৰ পৰা স্কেন কৰক')).toBeTruthy();

    rerender(<PairingQrPanel code="552785" language="bn" isLinked={false} />);
    expect(screen.getByText('যুক্ত করতে রোগীর ট্যাবলেট দিয়ে স্ক্যান করুন')).toBeTruthy();
  });
});

describe('PairingQrModal', () => {
  it('renders modal with enlarged QR and closes upon clicking close button', async () => {
    const user = userEvent.setup();
    const handleClose = vi.fn();

    render(
      <PairingQrModal
        isOpen={true}
        onClose={handleClose}
        code="552785"
        patientId="patient-1"
        patientName="Anjali Sharma"
      />
    );

    expect(screen.getByText('Device Pairing QR Code')).toBeTruthy();
    expect(screen.getByText('Anjali Sharma')).toBeTruthy();
    expect(screen.getByRole('img', { name: /Enlarged QR code/i })).toBeTruthy();

    const closeBtn = screen.getByRole('button', { name: /Close dialog/i });
    await user.click(closeBtn);

    expect(handleClose).toHaveBeenCalledTimes(1);
  });
});
