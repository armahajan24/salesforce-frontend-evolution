import { useEffect, useMemo, useState } from 'react';
import { Button } from './ui/button';
import { Alert, AlertDescription } from './ui/alert';
import { Spinner } from './ui/spinner';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from './ui/table';
import {
  searchAccounts,
  getDashboard,
  getOpportunityStages,
  updateOpportunityStage,
  type AccountOption,
  type DashboardResult,
} from '../api/accountDashboard';

/**
 * Account 360 mini-dashboard - React (Salesforce Multi-Framework) implementation.
 *
 * Deliberately mirrors the Visualforce/Aura/LWC implementations feature-for-feature
 * (same fields, same filter/update behavior, same states), reading and writing
 * through AccountDashboardRestResource.cls instead of the @AuraEnabled controller
 * the other three share - see src/api/accountDashboard.ts for why.
 */
export default function AccountDashboard() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchAttempted, setSearchAttempted] = useState(false);
  const [accountOptions, setAccountOptions] = useState<AccountOption[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState('');

  const [dashboard, setDashboard] = useState<DashboardResult | null>(null);
  const [stageOptions, setStageOptions] = useState<string[]>([]);
  const [stageFilter, setStageFilter] = useState('All');

  const [editingOpportunityId, setEditingOpportunityId] = useState('');
  const [newStageValue, setNewStageValue] = useState('');

  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  useEffect(() => {
    getOpportunityStages()
      .then(setStageOptions)
      .catch(() => {
        // Non-fatal: only the "New Stage" picker is affected.
      });
  }, []);

  const filteredOpportunities = useMemo(() => {
    if (!dashboard) return [];
    return stageFilter === 'All'
      ? dashboard.opportunities
      : dashboard.opportunities.filter((row) => row.stageName === stageFilter);
  }, [dashboard, stageFilter]);

  const pipelineTotal = useMemo(
    () => filteredOpportunities.reduce((sum, row) => sum + (row.amount || 0), 0),
    [filteredOpportunities]
  );

  async function handleSearch() {
    setIsLoading(true);
    setErrorMessage('');
    try {
      const options = await searchAccounts(searchTerm);
      setAccountOptions(options);
      setSearchAttempted(true);
      setSelectedAccountId('');
      setDashboard(null);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'An unexpected error occurred.');
    } finally {
      setIsLoading(false);
    }
  }

  async function loadDashboard(accountId: string) {
    if (!accountId) return;
    setIsLoading(true);
    setErrorMessage('');
    try {
      const result = await getDashboard(accountId);
      setDashboard(result);
      setStageFilter('All');
    } catch (error) {
      setDashboard(null);
      setErrorMessage(error instanceof Error ? error.message : 'An unexpected error occurred.');
    } finally {
      setIsLoading(false);
    }
  }

  function handleAccountSelect(accountId: string) {
    setSelectedAccountId(accountId);
    loadDashboard(accountId);
  }

  async function handleUpdateStage() {
    if (!editingOpportunityId || !newStageValue) {
      setErrorMessage('Select an Opportunity and a Stage before updating.');
      return;
    }
    setIsLoading(true);
    setErrorMessage('');
    try {
      await updateOpportunityStage(editingOpportunityId, newStageValue);
      setEditingOpportunityId('');
      setNewStageValue('');
      await loadDashboard(selectedAccountId);
    } catch (error) {
      setIsLoading(false);
      setErrorMessage(error instanceof Error ? error.message : 'An unexpected error occurred.');
    }
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <h1 className="text-2xl font-bold mb-4">Account 360 - React (Multi-Framework)</h1>

      {errorMessage && (
        <Alert variant="destructive" className="mb-4" data-testid="error-alert">
          <AlertDescription>{errorMessage}</AlertDescription>
        </Alert>
      )}

      {isLoading && (
        <div className="mb-4 flex items-center gap-2 text-sm text-muted-foreground" data-testid="loading-indicator">
          <Spinner /> Loading...
        </div>
      )}

      <div className="flex gap-2 mb-4 items-end">
        <div className="flex-1">
          <label htmlFor="search-input" className="block text-sm font-medium mb-1">
            Search Accounts by Name
          </label>
          <input
            id="search-input"
            className="w-full border rounded-md px-3 py-1.5 text-sm"
            placeholder="e.g. Acme"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <Button onClick={handleSearch}>Search</Button>
      </div>

      {accountOptions.length > 0 && (
        <div className="mb-4">
          <label htmlFor="account-select" className="block text-sm font-medium mb-1">
            Select an Account
          </label>
          <select
            id="account-select"
            className="w-full border rounded-md px-3 py-1.5 text-sm"
            value={selectedAccountId}
            onChange={(e) => handleAccountSelect(e.target.value)}
          >
            <option value="">-- Search results --</option>
            {accountOptions.map((opt) => (
              <option key={opt.id} value={opt.id}>
                {opt.name}
              </option>
            ))}
          </select>
        </div>
      )}
      {searchAttempted && accountOptions.length === 0 && (
        <p className="text-sm text-muted-foreground mb-4">No matching Accounts.</p>
      )}

      {dashboard && (
        <>
          <div className="border rounded-lg p-4 mb-4">
            <h2 className="text-xl font-semibold">{dashboard.account.name}</h2>
            <p>Industry: {dashboard.account.industry}</p>
            <p>Phone: {dashboard.account.phone}</p>
            <p>Owner: {dashboard.account.ownerName}</p>
            <p>
              Billing City/State: {dashboard.account.billingCity}, {dashboard.account.billingState}
            </p>
          </div>

          <div className="border rounded-lg p-4 mb-4">
            <h3 className="text-lg font-semibold mb-2">Contacts</h3>
            {dashboard.contacts.length === 0 ? (
              <p className="text-sm text-muted-foreground">No Contacts for this Account.</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Title</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>Phone</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {dashboard.contacts.map((c) => (
                    <TableRow key={c.id}>
                      <TableCell>{c.name}</TableCell>
                      <TableCell>{c.title}</TableCell>
                      <TableCell>{c.email}</TableCell>
                      <TableCell>{c.phone}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </div>

          <div className="border rounded-lg p-4 mb-4">
            <h3 className="text-lg font-semibold mb-2">Opportunities</h3>
            <div className="mb-3">
              <label htmlFor="stage-filter" className="block text-sm font-medium mb-1">
                Filter by Stage
              </label>
              <select
                id="stage-filter"
                className="border rounded-md px-3 py-1.5 text-sm"
                value={stageFilter}
                onChange={(e) => setStageFilter(e.target.value)}
              >
                <option value="All">All Stages</option>
                {stageOptions.map((stage) => (
                  <option key={stage} value={stage}>
                    {stage}
                  </option>
                ))}
              </select>
            </div>

            {filteredOpportunities.length === 0 ? (
              <p className="text-sm text-muted-foreground">No Opportunities match the current filter.</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Stage</TableHead>
                    <TableHead>Amount</TableHead>
                    <TableHead>Close Date</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredOpportunities.map((o) => (
                    <TableRow key={o.id}>
                      <TableCell>{o.name}</TableCell>
                      <TableCell>{o.stageName}</TableCell>
                      <TableCell>{o.amount}</TableCell>
                      <TableCell>{o.closeDate}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}

            <p className="text-lg font-semibold mt-3 mb-4" data-testid="pipeline-total">
              Total Pipeline (filtered): {pipelineTotal}
            </p>

            <div className="border rounded-lg p-3 bg-muted/30">
              <h4 className="font-semibold mb-2">Update an Opportunity's Stage</h4>
              <div className="flex gap-2 flex-wrap items-end">
                <select
                  aria-label="Opportunity"
                  className="border rounded-md px-3 py-1.5 text-sm"
                  value={editingOpportunityId}
                  onChange={(e) => setEditingOpportunityId(e.target.value)}
                >
                  <option value="">-- Select an Opportunity --</option>
                  {filteredOpportunities.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.name} ({o.stageName})
                    </option>
                  ))}
                </select>
                <select
                  aria-label="New Stage"
                  className="border rounded-md px-3 py-1.5 text-sm"
                  value={newStageValue}
                  onChange={(e) => setNewStageValue(e.target.value)}
                >
                  <option value="">-- Select a Stage --</option>
                  {stageOptions.map((stage) => (
                    <option key={stage} value={stage}>
                      {stage}
                    </option>
                  ))}
                </select>
                <Button onClick={handleUpdateStage}>Update Stage</Button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
