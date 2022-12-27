trigger LeadTrigger on Lead (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    if(Trigger.isInsert){
        if(Trigger.isBefore){}

        if(Trigger.isAfter){
            Database.executeBatch(new LeadRoundRobinBatch(
                    new List<Id>(Trigger.newMap.keySet())
            ), 200);
        }
    }

}