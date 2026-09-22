/**
 * Data access for the Account 360 dashboard.
 *
 * Multi-Framework apps cannot invoke @AuraEnabled Apex methods, @wire, or
 * lightning/uiRecordApi (they run outside the LWC/Aura runtime entirely). The
 * Data SDK's `dataSdk.fetch()` is the documented way to reach an Apex REST
 * (@RestResource) endpoint from here, which is what AccountDashboardRestResource.cls
 * exists for on the Apex side - this file talks to that endpoint, not to
 * AccountDashboardController (the Aura/LWC one), because React cannot reach it.
 */
import { createDataSDK } from '@salesforce/platform-sdk';

export interface AccountOption {
  id: string;
  name: string;
}

export interface AccountSummary {
  id: string;
  name: string;
  industry: string | null;
  phone: string | null;
  ownerName: string | null;
  billingCity: string | null;
  billingState: string | null;
}

export interface ContactRow {
  id: string;
  name: string;
  title: string | null;
  email: string | null;
  phone: string | null;
}

export interface OpportunityRow {
  id: string;
  name: string;
  stageName: string;
  amount: number;
  closeDate: string | null;
}

export interface DashboardResult {
  account: AccountSummary;
  contacts: ContactRow[];
  opportunities: OpportunityRow[];
  pipelineTotal: number;
}

const REST_BASE = '/services/apexrest/AccountDashboard';

async function apexFetch(path: string, init?: RequestInit): Promise<Response> {
  const sdk = await createDataSDK();
  if (!sdk.fetch) {
    throw new Error('This environment does not support server requests.');
  }
  return sdk.fetch(path, init);
}

async function parseErrorResponse(response: Response): Promise<string> {
  try {
    const body = await response.json();
    if (body && typeof body.error === 'string') {
      return body.error;
    }
  } catch {
    // response body wasn't JSON - fall through to the generic message
  }
  return 'An unexpected error occurred. Please try again.';
}

export async function getOpportunityStages(): Promise<string[]> {
  const response = await apexFetch(`${REST_BASE}/stages`);
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
  return response.json();
}

export async function searchAccounts(searchTerm: string): Promise<AccountOption[]> {
  if (!searchTerm.trim()) {
    return [];
  }
  const response = await apexFetch(`${REST_BASE}/search?term=${encodeURIComponent(searchTerm)}`);
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
  return response.json();
}

export async function getDashboard(accountId: string): Promise<DashboardResult> {
  const response = await apexFetch(`${REST_BASE}/${encodeURIComponent(accountId)}`);
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
  return response.json();
}

export async function updateOpportunityStage(opportunityId: string, stageName: string): Promise<void> {
  const response = await apexFetch(`${REST_BASE}/${encodeURIComponent(opportunityId)}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ opportunityId, stageName }),
  });
  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }
}
