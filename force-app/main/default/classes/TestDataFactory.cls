@IsTest
public class TestDataFactory {
    public static Account createAccount(String name) {
        // BillingState/BillingCountry deliberately omitted: this org enforces
        // state/country picklists tied to exact valid value pairs, and the
        // dashboard only displays these fields, it doesn't validate them.
        Account acc = new Account(Name = name, Industry = 'Technology', Phone = '415-555-0100', BillingCity = 'San Francisco');
        insert acc;
        return acc;
    }

    // Salesforce's standard Contact duplicate-detection rule matches on Email/Name,
    // so a per-test-run-unique suffix is required, not just a per-account-scoped
    // index - two different test methods (or two accounts in the same method)
    // producing "contact0@example.com" both would otherwise collide.
    private static Integer uniqueCounter = 0;

    private static Integer nextUniqueSuffix() {
        uniqueCounter++;
        return uniqueCounter;
    }

    public static List<Contact> createContacts(Id accountId, Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            Integer suffix = nextUniqueSuffix();
            contacts.add(
                new Contact(
                    AccountId = accountId,
                    FirstName = 'Test',
                    LastName = 'Contact ' + suffix,
                    Title = 'Manager',
                    Email = 'contact' + suffix + '@example-' + accountId + '.invalid',
                    Phone = '415-555-' + String.valueOf(Math.mod(suffix, 10000)).leftPad(4, '0')
                )
            );
        }
        insert contacts;
        return contacts;
    }

    public static List<Opportunity> createOpportunities(Id accountId, Integer count) {
        List<String> stages = new List<String>{ 'Prospecting', 'Qualification', 'Proposal/Price Quote', 'Closed Won' };
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            opps.add(
                new Opportunity(
                    AccountId = accountId,
                    Name = 'Test Opportunity ' + nextUniqueSuffix(),
                    StageName = stages[Math.mod(i, stages.size())],
                    Amount = 1000 * (i + 1),
                    CloseDate = Date.today().addDays(i)
                )
            );
        }
        insert opps;
        return opps;
    }

    /**
     * A user on the standard "Minimum Access - Salesforce" profile, which grants
     * no object permissions on Account/Contact/Opportunity. Used to exercise the
     * "permission/security failure" acceptance scenario (WITH USER_MODE /
     * AccessLevel.USER_MODE must reject this user with a safe error, not a crash).
     */
    public static User createMinimumAccessUser() {
        Profile minAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).right(6);
        User u = new User(
            FirstName = 'Restricted',
            LastName = 'TestUser' + suffix,
            Email = 'restricted' + suffix + '@example.invalid',
            Username = 'restricted' + suffix + '@example.invalid.test',
            Alias = 'ru' + suffix.right(4),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = minAccess.Id
        );
        insert u;
        return u;
    }
}
