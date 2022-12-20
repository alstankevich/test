trigger DuplicateRecordSetTrigger on DuplicateRecordSet (after insert) {

    if(Trigger.isAfter){
        if(Trigger.isInsert){
            List<DuplicateRecordItem> relatedItems = [
                    SELECT Id, RecordId, DuplicateRecordSetId
                    FROM DuplicateRecordItem
                    WHERE DuplicateRecordSetId IN :Trigger.newMap.keySet()
            ];

            List<Id> duplicatedLeadsIds = new List<Id>();
            Map<Id, Id> leadIdToSetId = new Map<Id, Id>();
            for(DuplicateRecordItem item : relatedItems){
                if (item.RecordId.getSobjectType() == Lead.getSObjectType()) {
                    duplicatedLeadsIds.add(item.RecordId);
                    leadIdToSetId.put(item.RecordId, item.DuplicateRecordSetId);
                }
            }

            if(duplicatedLeadsIds.isEmpty()) return;

            List<Lead> leadsToProcess = [//Potential_Duplicate__c
                    SELECT Id, OwnerId
                    FROM Lead
                    WHERE Id IN :duplicatedLeadsIds
                    ORDER BY CreatedDate DESC
            ];

            Map<Id, List<Lead>> setIdToLeads = new Map<Id, List<Lead>>();
            for(Lead lead : leadsToProcess){
                if(setIdToLeads.containsKey(leadIdToSetId.get(lead.Id))){
                    setIdToLeads.get(leadIdToSetId.get(lead.Id)).add(lead);
                }else{
                    setIdToLeads.put(
                        leadIdToSetId.get(lead.Id),
                        new List<Lead>{lead}
                    );
                }
            }

            List<Lead> leadsToUpdate = new List<Lead>();
            for(Id setId : setIdToLeads.keySet()){
                for(Integer i = 0; i < setIdToLeads.get(setId).size() - 1; i++){
//                    setIdToLeads.get(setId).get(i).Potential_Duplicate__c = true;
                    setIdToLeads.get(setId).get(i).OwnerId = setIdToLeads.get(setId).get(setIdToLeads.get(setId).size()).OwnerId;
                    leadsToUpdate.add(setIdToLeads.get(setId).get(i));
                }
            }

            update leadsToUpdate;

        }
    }


}
