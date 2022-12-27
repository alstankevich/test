@IsTest
public class PotentialDuplicateControllerTest {

    @IsTest
    private static void getPotentialDuplicateLeadsTest() {
        Lead masterLead = new Lead();
        masterLead.LastName = getRandomString();
        masterLead.Company = getRandomString();
        masterLead.Potential_Duplicate__c = true;

        Lead duplicateLead = new Lead();
        duplicateLead.LastName = getRandomString();
        duplicateLead.Company = getRandomString();
        duplicateLead.Potential_Duplicate__c = true;

        insert new List<Lead>{
                masterLead, duplicateLead
        };

        DuplicateRule duplicateRule = [
                SELECT Id, DeveloperName
                FROM DuplicateRule
                WHERE DeveloperName = 'Standard_Lead_Duplicate_Rule'
                LIMIT 1
        ];
        DuplicateRecordSet duplicateRecordSet = new DuplicateRecordSet();
        duplicateRecordSet.DuplicateRuleId = duplicateRule.Id;
        insert duplicateRecordSet;

        DuplicateRecordItem masterLeadItem = new DuplicateRecordItem();
        masterLeadItem.DuplicateRecordSetId = duplicateRecordSet.Id;
        masterLeadItem.RecordId = masterLead.Id;

        DuplicateRecordItem duplicateLeadItem = new DuplicateRecordItem();
        duplicateLeadItem.DuplicateRecordSetId = duplicateRecordSet.Id;
        duplicateLeadItem.RecordId = duplicateLead.Id;

        insert new List<DuplicateRecordItem>{
                masterLeadItem, duplicateLeadItem
        };

        Test.startTest();
        List<Lead> duplicateLeads = PotentialDuplicateController.getPotentialDuplicateLeads(duplicateLead.Id);

        Test.stopTest();

        System.assertEquals(1, duplicateLeads.size());
        System.assertEquals(masterLead.Id, duplicateLeads[0].Id);
    }

    @IsTest
    private static void setPotentialDuplicateFalseTest() {
        Lead lead = new Lead();
        lead.LastName = getRandomString();
        lead.Company = getRandomString();
        lead.Potential_Duplicate__c = true;
        insert lead;

        Test.startTest();
        PotentialDuplicateController.setPotentialDuplicateFalse(lead.Id);

        Test.stopTest();

        lead = [SELECT Id, Potential_Duplicate__c FROM Lead WHERE Id = :lead.Id];

        System.assertEquals(false, lead.Potential_Duplicate__c);
    }

    @IsTest
    private static void getSObjectRecordByIdWithAllAvailableFieldsTest() {
        Lead lead = new Lead();
        lead.LastName = getRandomString();
        lead.Company = getRandomString();
        lead.Email = getRandomEmail().toLowerCase();
        lead.Potential_Duplicate__c = true;
        insert lead;

        Test.startTest();
        List<Lead> leads = PotentialDuplicateController.getSObjectRecordByIdWithAllAvailableFields(Lead.class.getName(), lead.Id);

        Test.stopTest();

        System.assertEquals(1, leads.size());
        System.assertEquals(lead.LastName, leads[0].LastName);
        System.assertEquals(lead.Company, leads[0].Company);
        System.assertEquals(lead.Email, leads[0].Email);
        System.assertEquals(leads[0].Potential_Duplicate__c, true);
    }

    @IsTest
    private static void mergeLeadDuplicatesSuccessTest() {
        Lead masterLead = new Lead();
        masterLead.LastName = getRandomString();
        masterLead.Company = getRandomString();

        Lead duplicateLead = new Lead();
        duplicateLead.LastName = getRandomString();
        duplicateLead.Company = getRandomString();
        duplicateLead.Potential_Duplicate__c = true;
        duplicateLead.Phone = String.valueOf(getRandomIntegerWithLimit(100000000));
        duplicateLead.Email = getRandomEmail().toLowerCase();

        insert new List<Lead>{
                masterLead, duplicateLead
        };

        Task duplicateLeadTask = new Task();
        duplicateLeadTask.Subject = 'Call';
        duplicateLeadTask.WhoId = duplicateLead.Id;
        duplicateLeadTask.OwnerId = UserInfo.getUserId();
        insert duplicateLeadTask;

        Test.startTest();
        PotentialDuplicateController.mergeLeadDuplicates(duplicateLead.Id, masterLead.Id);

        Test.stopTest();

        List<Lead> duplicateLeads = [SELECT Id FROM Lead WHERE Id = :duplicateLead.Id];
        System.assertEquals(0, duplicateLeads.size());

        List<Lead> masterLeads = [SELECT Id, Phone, Email FROM Lead WHERE Id = :masterLead.Id];
        System.assertEquals(1, masterLeads.size());
        System.assertEquals(duplicateLead.Phone, masterLeads[0].Phone);
        System.assertEquals(duplicateLead.Email, masterLeads[0].Email);

        List<Task> leadTasks = [SELECT Id, WhoId FROM Task WHERE Id = :duplicateLeadTask.Id];
        System.assertEquals(1, leadTasks.size());
        System.assertEquals(masterLead.Id, leadTasks[0].WhoId);
    }

    @IsTest
    private static void mergeLeadDuplicatesErrorTest() {
        Lead masterLead = new Lead();
        masterLead.LastName = getRandomString();
        masterLead.Company = getRandomString();
        masterLead.Potential_Duplicate__c = true;
        insert masterLead;

        Boolean exceptionOccurred = false;
        Test.startTest();
        try {
            PotentialDuplicateController.mergeLeadDuplicates(masterLead.Id, masterLead.Id);
        } catch (Exception e) {
            System.debug(e.getMessage());
            exceptionOccurred = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionOccurred);
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

    private static String getRandomEmail() {
        String emailTemplate = '@test31.com';
        return getRandomString() + emailTemplate;
    }
}