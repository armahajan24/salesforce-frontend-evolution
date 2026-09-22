/**
 * Shared response shapes for the Account 360 dashboard, used identically by the
 * Visualforce, Aura, LWC, and React (Apex REST) implementations so that all four
 * UIs render the exact same data shape.
 *
 * Every member is a real Apex property ({ get; set; }), not a bare public field.
 * Visualforce's expression language cannot resolve a bare public field one level
 * deep (e.g. "accountSummary.name") - it requires an actual property accessor,
 * even though @AuraEnabled/JSON serialization work fine with either form. This
 * was discovered by deploying the Visualforce page against a bare-field version
 * of this class; see docs/ai-experiment-log.md.
 */
public with sharing class AccountDashboardDTO {
    public class AccountOption {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String name { get; set; }
    }

    public class AccountSummary {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String industry { get; set; }
        @AuraEnabled
        public String phone { get; set; }
        @AuraEnabled
        public String ownerName { get; set; }
        @AuraEnabled
        public String billingCity { get; set; }
        @AuraEnabled
        public String billingState { get; set; }
    }

    public class ContactRow {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String title { get; set; }
        @AuraEnabled
        public String email { get; set; }
        @AuraEnabled
        public String phone { get; set; }
    }

    public class OpportunityRow {
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String stageName { get; set; }
        @AuraEnabled
        public Decimal amount { get; set; }
        @AuraEnabled
        public Date closeDate { get; set; }
    }

    public class DashboardResult {
        @AuraEnabled
        public AccountSummary account { get; set; }
        @AuraEnabled
        public List<ContactRow> contacts { get; set; }
        @AuraEnabled
        public List<OpportunityRow> opportunities { get; set; }
        @AuraEnabled
        public Decimal pipelineTotal { get; set; }
    }
}
