/**
 * Selector and single-field mutator for Opportunity records related to an Account.
 * Row-capped at 200 per the requirement's documented pagination limitation.
 */
public inherited sharing class OpportunitySelector {
    public class InvalidStageException extends Exception {
    }

    private static final Integer ROW_LIMIT = 200;

    public static List<Opportunity> getByAccountId(Id accountId) {
        return [
            SELECT Id, Name, StageName, Amount, CloseDate
            FROM Opportunity
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CloseDate DESC
            LIMIT :ROW_LIMIT
        ];
    }

    public static void updateStage(Id opportunityId, String newStageName) {
        // StageName is not configured as a restricted picklist in every org, so an
        // invalid value would otherwise save silently instead of failing loudly -
        // validate explicitly rather than relying on picklist restriction alone.
        if (!isActiveStage(newStageName)) {
            throw new InvalidStageException('"' + newStageName + '" is not a valid Opportunity Stage.');
        }
        Opportunity opp = new Opportunity(Id = opportunityId, StageName = newStageName);
        Database.update(opp, AccessLevel.USER_MODE);
    }

    private static Boolean isActiveStage(String stageName) {
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == stageName) {
                return true;
            }
        }
        return false;
    }
}
