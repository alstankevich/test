@IsTest
private class LeadRoundRobinBatchTest {

    @TestSetup
    private static void setup() {
        createUsersWithType('BciCapital-Franchise', 2);
    }


    @IsTest
    static void testBehavior() {

        List<User> users = [SELECT Id, Alias FROM User WHERE Type__c = 'BciCapital-Franchise'];

        Lead lead = new Lead();
        lead.LastName = getRandomString();
        lead.Company = getRandomString();
        lead.Lead_Owner_Type__c = 'BciCapital-Franchise';
        lead.OwnerId = users.get(users.size()-1).Id;
        lead.Email = 'test1@ema.il';
        lead.Phone = '+20948324';
        lead.Status = 'New';

        Lead lead2 = new Lead();
        lead2.LastName = getRandomString();
        lead2.Company = getRandomString();
        lead2.Lead_Owner_Type__c = 'BciCapital-Franchise';
        lead2.OwnerId = users.get(users.size()-1).Id;
        lead2.Email = 'test2@ema.il';
        lead2.Phone = '+20897430924';
        lead2.Status = 'New';

        Lead lead3 = new Lead();
        lead3.LastName = getRandomString();
        lead3.Company = getRandomString();
        lead3.Lead_Owner_Type__c = 'BciCapital-Franchise';
        lead3.Title = 'test title';
        lead3.Email = 'test3@ema.il';
        lead3.Phone = '+534987594';
        lead3.Status = 'New';

        Test.startTest();
        insert new List<Lead>{
                lead, lead2, lead3
        };
        Test.stopTest();

        Lead expectedLead = [SELECT Id, Title, Lead_Owner_Type__c, OwnerId FROM Lead WHERE Lead_Owner_Type__c = 'BciCapital-Franchise' AND Title = 'test title' LIMIT 1];

        System.assertEquals(expectedLead.OwnerId, users[0].Id);

    }

    private static void createUsersWithType(String type, Integer count) {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        List<User> users = new List<User>();

        while (users.size() < count) {
            Blob b = Crypto.generateAesKey(128);
            String h = EncodingUtil.convertToHex(b);
            String uid = h.substring(0,8);
            User u = new User(Alias = uid, Email= uid + '@myorg.com',
                    EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                    LocaleSidKey='en_US', ProfileId = p.Id,
                    TimeZoneSidKey='America/New_York', UserName= uid + '@myorg.com',
                    Type__c = type
            );
            users.add(u);
        }
        insert(users);
    }

    private static String getRandomString() {
        return getRandomString(20);
    }

    private static String getRandomString(Integer stringLength) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randomString = '';
        // Name field limited by 40 chars
        while (randomString.length() < stringLength) {
            Integer idx = getRandomIntegerWithLimit(chars.length());
            randomString += chars.substring(idx, idx + 1);
        }
        return randomString;
    }

    private static Integer getRandomIntegerWithLimit(Integer upperLimit) {
        return Math.mod(Math.abs(Crypto.getRandomInteger()), upperLimit);
    }
}
