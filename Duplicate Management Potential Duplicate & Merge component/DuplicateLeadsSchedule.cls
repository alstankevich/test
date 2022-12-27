global class DuplicateLeadsSchedule implements Schedulable {
   global void execute(SchedulableContext SC) {
      Database.executeBatch(new DuplicateLeadsBatch(), 200);
   }
}
