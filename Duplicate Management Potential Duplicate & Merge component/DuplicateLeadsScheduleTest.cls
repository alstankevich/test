@IsTest
private class DuplicateLeadsScheduleTest {
    @IsTest
    static void testBehavior() {

        Test.startTest();
        DuplicateLeadsSchedule duplicateLeadsSchedule = new DuplicateLeadsSchedule();
        String sch = '0 0 23 * * ?';
        System.schedule('Test status Check', sch, duplicateLeadsSchedule );
        Test.stopTest();

    }
}
