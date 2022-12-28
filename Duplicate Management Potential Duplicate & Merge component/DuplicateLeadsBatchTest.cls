@IsTest
public class DuplicateLeadsBatchTest {

    private static final Id BUSINESS_LEAD_RECORD_TYPE = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Business').getRecordTypeId();


    @TestSetup
    static void setupData() {

        DuplicateRule duplicateRule = [
                SELECT Id, MasterLabel
                FROM DuplicateRule
                WHERE MasterLabel = 'Business Lead Duplicate Rule'
                LIMIT 1
        ];

        Lead leadMaster = new Lead(
                FirstName = 'Test First Name',
                LastName = 'Test Last Name',
                Company = 'Test Company',
                Email = 'test@email.com',
                Phone = '1234567890',
                Status = 'Open - Not Contacted',
                Primary_Product_of_Interest__c = 'TestProduct',
                RecordTypeId = BUSINESS_LEAD_RECORD_TYPE
        );

        insert leadMaster;

        Lead leadDuplicate = new Lead(
                LastName = 'Test Last Name',
                Email = 'test@email.com',
                Status = 'Open - Not Contacted',
                Website = 'www.test.com',
                Company = 'Test Company',
                Primary_Product_of_Interest__c = 'TestProduct',
                RecordTypeId = BUSINESS_LEAD_RECORD_TYPE
        );

        insert leadDuplicate;

        DuplicateRecordSet drs = new DuplicateRecordSet(
                DuplicateRuleId = duplicateRule.Id
        );

        insert drs;

        DuplicateRecordItem dri = new DuplicateRecordItem(
                DuplicateRecordSetId = drs.Id,
                RecordId = leadDuplicate.Id
        );

        insert dri;

        DuplicateRecordItem dri2 = new DuplicateRecordItem(
                DuplicateRecordSetId = drs.Id,
                RecordId = leadMaster.Id
        );

        insert dri2;

    }


    @IsTest
    static void testBehavior() {

        Test.startTest();

        DuplicateLeadsBatch batch = new DuplicateLeadsBatch();
        Database.executeBatch(batch);

        Test.stopTest();

    }
}
