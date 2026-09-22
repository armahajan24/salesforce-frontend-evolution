/**
 * Selector for Contact records related to an Account, capped at 200 rows
 * per the requirement's documented row-cap limitation.
 */
public inherited sharing class ContactSelector {
    private static final Integer ROW_LIMIT = 200;

    public static List<Contact> getByAccountId(Id accountId) {
        return [
            SELECT Id, Name, Title, Email, Phone
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY Name
            LIMIT :ROW_LIMIT
        ];
    }
}
