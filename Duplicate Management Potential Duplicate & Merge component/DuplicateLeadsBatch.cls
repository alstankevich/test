global without sharing class DuplicateLeadsBatch implements Database.Batchable<sObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, OwnerId, Potential_Duplicate__c FROM Lead WHERE CreatedDate = TODAY AND Potential_Duplicate__c = false AND Merge_Process_Done__c = false';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Lead> leads) {
        List<Id> leadsIds = getLeadsIds(leads);
        List<Id> drSetIds = getDrSetIds(leadsIds);
        List<DuplicateRecordItem> relatedItems = getRelatedItems(drSetIds);

        List<Id> duplicatedLeadsIds = new List<Id>();
        Map<Id, Id> leadIdToSetId = new Map<Id, Id>();
        for(DuplicateRecordItem item : relatedItems){
            if (item.RecordId.getSobjectType() == Lead.getSObjectType()) {
                duplicatedLeadsIds.add(item.RecordId);
                leadIdToSetId.put(item.RecordId, item.DuplicateRecordSetId);
            }
        }

        if(duplicatedLeadsIds.isEmpty()) return;

        List<Lead> leadsToProcess = getLeadsToProcess(duplicatedLeadsIds);
        Map<Id, List<Lead>> setIdToLeads = getSetIdToLeads(leadsToProcess, leadIdToSetId);

        List<Lead> leadsToUpdate = getLeadsToUpdate(setIdToLeads);
        if(!leadsToUpdate.isEmpty()) update leadsToUpdate;

    }

    private List<Lead> getLeadsToUpdate(Map<Id, List<Lead>> setIdToLeads) {
        List<Lead> leadsToUpdate = new List<Lead>();
        for (Id setId : setIdToLeads.keySet()) {
            for (Integer i = 0; i < setIdToLeads.get(setId).size() - 1; i++) {
                setIdToLeads.get(setId).get(i).Potential_Duplicate__c = true;
                setIdToLeads.get(setId).get(i).OwnerId = setIdToLeads.get(setId).get(setIdToLeads.get(setId).size()).OwnerId;
                leadsToUpdate.add(setIdToLeads.get(setId).get(i));
            }
        }
        return leadsToUpdate;
    }

    private Map<Id, List<Lead>> getSetIdToLeads(List<Lead> leadsToProcess, Map<Id, Id> leadIdToSetId) {
        Map<Id, List<Lead>> setIdToLeads = new Map<Id, List<Lead>>();
        for (Lead lead : leadsToProcess) {
            if (setIdToLeads.containsKey(leadIdToSetId.get(lead.Id))) {
                setIdToLeads.get(leadIdToSetId.get(lead.Id)).add(lead);
            } else {
                setIdToLeads.put(
                        leadIdToSetId.get(lead.Id),
                        new List<Lead>{
                                lead
                        }
                );
            }
        }
        return setIdToLeads;
    }

    private List<Lead> getLeadsToProcess(List<Id> duplicatedLeadsIds) {
        List<Lead> leadsToProcess = [//Potential_Duplicate__c
                SELECT Id, OwnerId
                FROM Lead
                WHERE Id IN :duplicatedLeadsIds
                AND Merge_Process_Done__c = false
                ORDER BY CreatedDate DESC
        ];
        return leadsToProcess;
    }

    private List<DuplicateRecordItem> getRelatedItems(List<Id> drSetIds) {
        List<DuplicateRecordItem> relatedItems = [
                SELECT Id, RecordId, DuplicateRecordSetId
                FROM DuplicateRecordItem
                WHERE DuplicateRecordSetId IN :drSetIds
        ];
        return relatedItems;
    }

    private List<Id> getDrSetIds(List<Id> leadsIds) {
        List<Id> drSetIds = new List<Id>();
        for (DuplicateRecordItem drItem : [
                SELECT Id, DuplicateRecordSetId
                FROM DuplicateRecordItem
                WHERE RecordId IN :leadsIds
        ]) {
            drSetIds.add(drItem.DuplicateRecordSetId);
        }
        return drSetIds;
    }

    private List<Id> getLeadsIds(List<Lead> leads) {
        List<Id> leadsIds = new List<Id>();
        for (Lead lead : leads) {
            leadsIds.add(lead.Id);
        }
        return leadsIds;
    }

    global void finish(Database.BatchableContext BC) {
        // execute any post-processing operations like sending email
    }
}
