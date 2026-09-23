import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { PatientDetails } from '../PatientDetails';
import { RegisterPatient } from '../RegisterPatient';
import * as patientService from '../../services/patientService';
import * as gameSessionService from '../../services/gameSessionService';
import * as reminderService from '../../services/reminderService';

vi.mock('../../services/patientService', () => ({
  getPatientById: vi.fn(),
  updatePatient: vi.fn().mockResolvedValue({}),
  deletePatient: vi.fn().mockResolvedValue(true),
  registerPatient: vi.fn().mockResolvedValue({ id: 'p999' }),
  getCareStatusConfig: vi.fn().mockReturnValue({ label: 'Normal', badgeClass: 'bg-sage' }),
  CARE_STATUS: {},
}));

vi.mock('../../services/gameSessionService', () => ({
  getGameSessions: vi.fn().mockResolvedValue([]),
  DOMAIN_CONFIG: {},
  formatSessionDate: vi.fn().mockReturnValue('Sep 20, 2026'),
}));

vi.mock('../../services/reminderService', () => ({
  fetchReminders: vi.fn().mockResolvedValue(null),
}));

describe('Emergency Contact UI & Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('PatientDetails Emergency Contact Card', () => {
    it('renders both primary and alternative contacts with badges and phone numbers', async () => {
      patientService.getPatientById.mockResolvedValue({
        id: 'p1',
        name: 'Suresh Verma',
        age: 72,
        gender: 'Male',
        dateOfBirth: '1954-03-14',
        diagnosis: 'Mild Cognitive Impairment (MCI)',
        healthIssue: 'Baseline active',
        careStatus: 'normal',
        emergencyContact: {
          name: 'Priya Verma',
          relationship: 'Daughter (Primary Guardian)',
          phone: '+91 98765 43210',
        },
        alternativeEmergencyContact: {
          name: 'Dr. Rahul Sen',
          relationship: 'Family Physician',
          phone: '+91 91234 56789',
        },
      });

      render(
        <MemoryRouter initialEntries={['/patients/p1']}>
          <Routes>
            <Route path="/patients/:id" element={<PatientDetails />} />
          </Routes>
        </MemoryRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('Suresh Verma')).toBeTruthy();
      });

      // Check card heading
      expect(screen.getByRole('region', { name: /Emergency Contacts/i })).toBeTruthy();
      expect(screen.getByText('2 Contacts Configured')).toBeTruthy();

      // Check Primary Contact
      expect(screen.getByText('Priya Verma')).toBeTruthy();
      expect(screen.getByText('Daughter (Primary Guardian)')).toBeTruthy();
      expect(screen.getByText('+91 98765 43210')).toBeTruthy();
      expect(screen.getByText('Primary')).toBeTruthy();

      // Check Alternative Contact
      expect(screen.getByText('Dr. Rahul Sen')).toBeTruthy();
      expect(screen.getByText('Family Physician')).toBeTruthy();
      expect(screen.getByText('+91 91234 56789')).toBeTruthy();
      expect(screen.getByText('Alternative')).toBeTruthy();

      // Verify "Edit Details" button is REMOVED from the card
      expect(screen.queryByTitle(/Edit emergency contact details/i)).toBeNull();
      expect(screen.queryByText(/Edit Details/i)).toBeNull();

      // Verify Call and Copy buttons are REMOVED for clean web-based layout
      expect(screen.queryByTitle(/Call Primary Emergency Contact/i)).toBeNull();
      expect(screen.queryByTitle(/Call Alternative Emergency Contact/i)).toBeNull();
      expect(screen.queryByTitle(/Copy phone number/i)).toBeNull();
      expect(screen.queryByText('Call')).toBeNull();
      expect(screen.queryByText('Copy')).toBeNull();

      // Verify manage note
      expect(screen.getByText('Manage via Edit Profile')).toBeTruthy();
    });

    it('renders calm empty state when alternative emergency contact is absent', async () => {
      patientService.getPatientById.mockResolvedValue({
        id: 'p2',
        name: 'Kamala Das',
        age: 68,
        gender: 'Female',
        diagnosis: "Early Stage Alzheimer's",
        healthIssue: 'Baseline active',
        careStatus: 'normal',
        emergencyContact: {
          name: 'Arun Das',
          relationship: 'Husband',
          phone: '+91 98111 22233',
        },
        alternativeEmergencyContact: null,
      });

      render(
        <MemoryRouter initialEntries={['/patients/p2']}>
          <Routes>
            <Route path="/patients/:id" element={<PatientDetails />} />
          </Routes>
        </MemoryRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('Kamala Das')).toBeTruthy();
      });

      // Primary contact is displayed
      expect(screen.getByText('Arun Das')).toBeTruthy();
      expect(screen.getByText('Primary')).toBeTruthy();

      // Alternative contact is absent, calm empty state is shown
      expect(screen.getByText('No alternative contact added')).toBeTruthy();
      expect(screen.getByText('Add a secondary responder anytime via Edit Profile above.')).toBeTruthy();

      // No duplicate Edit Details button in the card
      expect(screen.queryByText('Edit Details')).toBeNull();
    });
  });

  describe('RegisterPatient Alternative Emergency Contact', () => {
    it('allows toggling alternative contact and validates duplicate phone number', async () => {
      const user = userEvent.setup();

      render(
        <MemoryRouter initialEntries={['/patients/new']}>
          <Routes>
            <Route path="/patients/new" element={<RegisterPatient />} />
          </Routes>
        </MemoryRouter>
      );

      // Initially "Add Alternative Emergency Contact (Optional)" button is present
      const addAltBtn = screen.getByRole('button', { name: /Add Alternative Emergency Contact/i });
      expect(addAltBtn).toBeTruthy();

      // Click to expand alternative contact fields
      await user.click(addAltBtn);

      // Now inputs for alternative contact should appear
      const altNameInput = screen.getByLabelText(/Contact Name/i, { selector: '#alt-emergency-name' });
      const altRelInput = screen.getByLabelText(/Relationship/i, { selector: '#alt-emergency-rel' });
      const altPhoneInput = screen.getByLabelText(/Phone Number/i, { selector: '#alt-emergency-phone' });

      expect(altNameInput).toBeTruthy();
      expect(altRelInput).toBeTruthy();
      expect(altPhoneInput).toBeTruthy();

      // Fill in primary contact phone
      const primaryPhoneInput = screen.getByLabelText(/Phone Number \*/i, { selector: '#emergency-phone' });
      await user.type(primaryPhoneInput, '9876543210');

      // Fill patient name, age, dob
      const nameInput = screen.getByLabelText(/Full Name \*/i, { selector: '#patient-name' });
      await user.type(nameInput, 'Anil Gupta');

      const ageInput = screen.getByLabelText(/Age \*/i, { selector: '#patient-age' });
      await user.type(ageInput, '75');

      // Fill in same phone number in alternative contact
      await user.type(altNameInput, 'Sunil Gupta');
      await user.type(altRelInput, 'Brother');
      await user.type(altPhoneInput, '9876543210');

      // Attempt to register
      const submitBtn = screen.getByRole('button', { name: /Register Patient/i });
      await user.click(submitBtn);

      // Should show duplicate phone validation error
      expect(
        screen.getByText(/Alternative contact cannot have the same phone number as primary contact/i)
      ).toBeTruthy();

      // Test "Remove" button resets alternative fields and collapses
      const removeBtn = screen.getByRole('button', { name: /Remove/i });
      await user.click(removeBtn);

      expect(screen.queryByLabelText(/Contact Name/i, { selector: '#alt-emergency-name' })).toBeNull();
      expect(screen.getByRole('button', { name: /Add Alternative Emergency Contact/i })).toBeTruthy();
    });
  });
});
