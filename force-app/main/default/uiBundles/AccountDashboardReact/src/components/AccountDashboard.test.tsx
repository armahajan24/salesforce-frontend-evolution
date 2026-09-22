import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import AccountDashboard from './AccountDashboard';
import * as api from '../api/accountDashboard';

vi.mock('../api/accountDashboard', () => ({
  searchAccounts: vi.fn(),
  getDashboard: vi.fn(),
  getOpportunityStages: vi.fn(),
  updateOpportunityStage: vi.fn(),
}));

const DASHBOARD_RESULT = {
  account: {
    id: '001000000000001',
    name: 'Acme Rockets',
    industry: 'Technology',
    phone: '415-555-0100',
    ownerName: 'Jane Owner',
    billingCity: 'San Francisco',
    billingState: 'CA',
  },
  contacts: [
    { id: '003000000000001', name: 'Jane Doe', title: 'CTO', email: 'jane@example.com', phone: '415-555-0200' },
  ],
  opportunities: [
    { id: '006000000000001', name: 'Deal A', stageName: 'Prospecting', amount: 1000, closeDate: '2026-12-01' },
    { id: '006000000000002', name: 'Deal B', stageName: 'Closed Won', amount: 5000, closeDate: '2026-11-01' },
  ],
  pipelineTotal: 6000,
};

describe('AccountDashboard', () => {
  beforeEach(() => {
    vi.mocked(api.getOpportunityStages).mockResolvedValue(['Prospecting', 'Closed Won']);
  });

  it('shows a no-results message when a search returns nothing', async () => {
    vi.mocked(api.searchAccounts).mockResolvedValue([]);
    render(<AccountDashboard />);

    fireEvent.click(screen.getByText('Search'));

    await waitFor(() => expect(screen.getByText('No matching Accounts.')).toBeInTheDocument());
  });

  it('loads and displays the dashboard for a selected Account', async () => {
    vi.mocked(api.searchAccounts).mockResolvedValue([{ id: '001000000000001', name: 'Acme Rockets' }]);
    vi.mocked(api.getDashboard).mockResolvedValue(DASHBOARD_RESULT);

    render(<AccountDashboard />);
    fireEvent.click(screen.getByText('Search'));
    await waitFor(() => screen.getByLabelText('Select an Account'));

    fireEvent.change(screen.getByLabelText('Select an Account'), { target: { value: '001000000000001' } });

    await waitFor(() => expect(screen.getByText('Acme Rockets')).toBeInTheDocument());
    expect(screen.getByText('Jane Doe')).toBeInTheDocument();
    expect(screen.getByTestId('pipeline-total').textContent).toContain('6000');
  });

  it('filters Opportunities by Stage and recalculates the pipeline total', async () => {
    vi.mocked(api.searchAccounts).mockResolvedValue([{ id: '001000000000001', name: 'Acme Rockets' }]);
    vi.mocked(api.getDashboard).mockResolvedValue(DASHBOARD_RESULT);

    render(<AccountDashboard />);
    fireEvent.click(screen.getByText('Search'));
    await waitFor(() => screen.getByLabelText('Select an Account'));
    fireEvent.change(screen.getByLabelText('Select an Account'), { target: { value: '001000000000001' } });
    await waitFor(() => screen.getByText('Acme Rockets'));

    fireEvent.change(screen.getByLabelText('Filter by Stage'), { target: { value: 'Prospecting' } });

    await waitFor(() => expect(screen.getByTestId('pipeline-total').textContent).toContain('1000'));
    expect(screen.queryByText('Deal B')).not.toBeInTheDocument();
  });

  it('shows a safe error message when the dashboard fails to load', async () => {
    vi.mocked(api.searchAccounts).mockResolvedValue([{ id: '001000000000001', name: 'Acme Rockets' }]);
    vi.mocked(api.getDashboard).mockRejectedValue(
      new Error('The selected Account could not be found or is not accessible.')
    );

    render(<AccountDashboard />);
    fireEvent.click(screen.getByText('Search'));
    await waitFor(() => screen.getByLabelText('Select an Account'));
    fireEvent.change(screen.getByLabelText('Select an Account'), { target: { value: '001000000000001' } });

    await waitFor(() => expect(screen.getByTestId('error-alert')).toBeInTheDocument());
    expect(screen.getByTestId('error-alert').textContent).toContain('could not be found or is not accessible');
  });

  it('updates the Opportunity Stage and reloads the dashboard', async () => {
    vi.mocked(api.searchAccounts).mockResolvedValue([{ id: '001000000000001', name: 'Acme Rockets' }]);
    vi.mocked(api.getDashboard).mockResolvedValue(DASHBOARD_RESULT);
    vi.mocked(api.updateOpportunityStage).mockResolvedValue(undefined);

    render(<AccountDashboard />);
    fireEvent.click(screen.getByText('Search'));
    await waitFor(() => screen.getByLabelText('Select an Account'));
    fireEvent.change(screen.getByLabelText('Select an Account'), { target: { value: '001000000000001' } });
    await waitFor(() => screen.getByText('Acme Rockets'));

    fireEvent.change(screen.getByLabelText('Opportunity'), { target: { value: '006000000000001' } });
    fireEvent.change(screen.getByLabelText('New Stage'), { target: { value: 'Closed Won' } });
    fireEvent.click(screen.getByText('Update Stage'));

    await waitFor(() =>
      expect(api.updateOpportunityStage).toHaveBeenCalledWith('006000000000001', 'Closed Won')
    );
  });
});
