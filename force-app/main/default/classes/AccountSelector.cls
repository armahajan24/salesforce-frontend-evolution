/**
 * Selector for Account records used by the Account 360 dashboard.
 * WITH USER_MODE enforces object/field-level security; `inherited sharing`
 * defers to the calling class's sharing mode (all callers here are `with sharing`).
 */
public inherited sharing class AccountSelector {
    private static final Integer SEARCH_LIMIT = 20;

    public static List<Account> searchByName(String searchTerm) {
        // No escapeSingleQuotes() here: :likeTerm is a bind variable, so Apex
        // already parameterizes it safely - escaping on top of that would
        // double-escape a literal apostrophe (e.g. "O'Reilly") and break the match.
        String likeTerm = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, Industry, Phone, BillingCity, BillingState, Owner.Name
            FROM Account
            WHERE Name LIKE :likeTerm
            WITH USER_MODE
            ORDER BY Name
            LIMIT :SEARCH_LIMIT
        ];
    }

    public static Account getById(Id accountId) {
        List<Account> results = [
            SELECT Id, Name, Industry, Phone, BillingCity, BillingState, Owner.Name
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }
}
