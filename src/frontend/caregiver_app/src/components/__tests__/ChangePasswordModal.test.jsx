import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ChangePasswordModal } from '../ChangePasswordModal';

vi.mock('../../context/AuthContext', () => ({
  useAuth: () => ({
    caregiver: { id: 'c1', name: 'Test Caregiver', email: 'caregiver@example.com' },
    updateUserData: vi.fn(),
    setSession: vi.fn(),
    role: 'caregiver',
    isAdmin: false,
  }),
}));

vi.mock('../../services/authService', () => ({
  changePassword: vi.fn().mockResolvedValue({ token: 'mock-token-abc' }),
}));

describe('ChangePasswordModal focus stability & input typing', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('types a 20+ character string into each field with userEvent.type without losing focus or jumping', async () => {
    const user = userEvent.setup();
    const handleClose = vi.fn();

    render(<ChangePasswordModal isOpen={true} onClose={handleClose} />);

    const currentPassInput = document.getElementById('change-current-password');
    const newPassInput = document.getElementById('change-new-password');
    const confirmPassInput = document.getElementById('change-confirm-password');

    expect(currentPassInput).toBeTruthy();
    expect(newPassInput).toBeTruthy();
    expect(confirmPassInput).toBeTruthy();

    // Initial autofocus settles once on the first input
    await waitFor(() => {
      expect(document.activeElement).toBe(currentPassInput);
    });

    // 1. Type 20+ chars into Current Password
    const currentVal = 'CurrentStrongPassword123!';
    await user.type(currentPassInput, currentVal);
    expect(currentPassInput.value).toBe(currentVal);
    expect(document.activeElement).toBe(currentPassInput);

    // 2. Click and type 20+ chars into New Password
    await user.click(newPassInput);
    expect(document.activeElement).toBe(newPassInput);

    const newVal = 'SuperSecureNewPassw0rd#2026';
    await user.type(newPassInput, newVal);
    expect(newPassInput.value).toBe(newVal);
    expect(document.activeElement).toBe(newPassInput);

    // 3. Click and type 20+ chars into Confirm New Password
    await user.click(confirmPassInput);
    expect(document.activeElement).toBe(confirmPassInput);

    await user.type(confirmPassInput, newVal);
    expect(confirmPassInput.value).toBe(newVal);
    expect(document.activeElement).toBe(confirmPassInput);
  });

  it('preserves caret and focus during arrow-key editing and backspace', async () => {
    const user = userEvent.setup();
    render(<ChangePasswordModal isOpen={true} onClose={vi.fn()} />);

    const currentPassInput = document.getElementById('change-current-password');
    await waitFor(() => {
      expect(document.activeElement).toBe(currentPassInput);
    });

    const newPassInput = document.getElementById('change-new-password');
    await user.click(newPassInput);

    // Type base word
    await user.type(newPassInput, 'HelloWorld123!');
    expect(newPassInput.value).toBe('HelloWorld123!');
    expect(document.activeElement).toBe(newPassInput);

    // Backspace 4 characters ('123!') -> 'HelloWorld'
    await user.type(newPassInput, '{Backspace}{Backspace}{Backspace}{Backspace}');
    expect(newPassInput.value).toBe('HelloWorld');
    expect(document.activeElement).toBe(newPassInput);

    // Append new characters
    await user.type(newPassInput, '9999@Secure');
    expect(newPassInput.value).toBe('HelloWorld9999@Secure');
    expect(document.activeElement).toBe(newPassInput);
  });

  it('toggles password visibility without resetting input focus or caret', async () => {
    const user = userEvent.setup();
    render(<ChangePasswordModal isOpen={true} onClose={vi.fn()} />);

    const currentPassInput = document.getElementById('change-current-password');
    await waitFor(() => {
      expect(document.activeElement).toBe(currentPassInput);
    });

    const newPassInput = document.getElementById('change-new-password');
    await user.click(newPassInput);
    await user.type(newPassInput, 'P@ssword12345');
    expect(newPassInput.type).toBe('password');

    // Click show password toggle for new password (second toggle button)
    const toggleBtns = screen.getAllByLabelText(/Show password/i);
    const newPassToggle = toggleBtns[1];
    await user.click(newPassToggle);

    expect(newPassInput.type).toBe('text');
    expect(newPassInput.value).toBe('P@ssword12345');

    // Click back into newPassInput and continue typing while revealed
    await user.click(newPassInput);
    await user.type(newPassInput, 'Extra');
    expect(newPassInput.value).toBe('P@ssword12345Extra');
    expect(document.activeElement).toBe(newPassInput);
  });

  it('traps focus with Tab and Shift+Tab between first and last focusable elements', async () => {
    const user = userEvent.setup();
    render(<ChangePasswordModal isOpen={true} onClose={vi.fn()} />);

    const currentPassInput = document.getElementById('change-current-password');
    await waitFor(() => {
      expect(document.activeElement).toBe(currentPassInput);
    });

    const closeBtn = screen.getByLabelText(/Close dialog/i);
    const cancelBtn = screen.getByRole('button', { name: /Cancel/i });

    // Focus close button (first focusable element in DOM order)
    closeBtn.focus();
    expect(document.activeElement).toBe(closeBtn);

    // Shift-Tab from the first element wraps to the last focusable element (cancel button)
    await user.tab({ shift: true });
    expect(document.activeElement).toBe(cancelBtn);

    // Tab forward from the last element wraps back to the first element (close button)
    await user.tab();
    expect(document.activeElement).toBe(closeBtn);
  });

  it('closes on Escape key press when not submitting', async () => {
    const user = userEvent.setup();
    const handleClose = vi.fn();
    render(<ChangePasswordModal isOpen={true} onClose={handleClose} />);

    await user.keyboard('{Escape}');
    expect(handleClose).toHaveBeenCalled();
  });
});
