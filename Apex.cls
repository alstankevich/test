public without sharing class PotentialDuplicateController {

    @AuraEnabled
    public static List<Lead> getPotentialDuplicateLeads(Id recordId) {
        List<Lead> duplicateLeads = new List<Lead>();
        Set<Id> duplicateRecordSetIds = new Set<Id>();
        Set<Id> duplicateLeadIds = new Set<Id>();

        if (recordId != null) {
            for (DuplicateRecordItem duplicateItem : [
                    SELECT Id, DuplicateRecordSetId
                    FROM DuplicateRecordItem
                    WHERE RecordId = :recordId
            ]) {
                duplicateRecordSetIds.add(duplicateItem.DuplicateRecordSetId);
            }

            for (DuplicateRecordItem duplicateRecordItem : [
                    SELECT Id, RecordId
                    FROM DuplicateRecordItem
                    WHERE DuplicateRecordSetId IN :duplicateRecordSetIds
            ]) {
                if (duplicateRecordItem.RecordId.getSobjectType() == Lead.getSObjectType()) {
                    duplicateLeadIds.add(duplicateRecordItem.RecordId);
                }
            }
            if (!duplicateLeadIds.isEmpty()) {
                duplicateLeads = [
                        SELECT Id, Name, Title, Company, Phone, Email, Status, Potential_Duplicate__c
                        FROM Lead
                        WHERE Id IN :duplicateLeadIds
                ];
                //AND Id != :recordId
            }
        }
        return duplicateLeads;
    }

    @AuraEnabled
    public static void setPotentialDuplicateFalse(Id recordId) {
        if (recordId != null) {
            Lead lead = [SELECT Id, Name, Potential_Duplicate__c FROM Lead WHERE Id = :recordId];
            lead.Potential_Duplicate__c = false;
            lead.Merge_Process_Done__c = true;
            update lead;
        }
    }

    @AuraEnabled
    public static void mergeLeadDuplicates(Id recordId, Id masterId) {
        List<Lead> duplicates = getSObjectRecordByIdWithAllAvailableFields(Lead.class.getName(), recordId);
        List<Lead> masterLeads = getSObjectRecordByIdWithAllAvailableFields(Lead.class.getName(), masterId);

        if (!duplicates.isEmpty() && !masterLeads.isEmpty()) {
            Lead duplicate = duplicates.get(0);
            Lead master = masterLeads.get(0);

            Map<String, SObjectField> fields = SObjectType.Lead.fields.getMap();
            Map<String, Object> duplicateLeadValues = duplicate.getPopulatedFieldsAsMap();
            for (String field : duplicateLeadValues.keySet()) {
                if (master.get(field) == null && fields.get(field).getDescribe().isUpdateable()) {
                    master.put(field, duplicateLeadValues.get(field));
                }
            }
            // Merge accounts into master
            Database.MergeResult mergeResult = Database.merge(master, duplicate, false);

            if (mergeResult.isSuccess()) {
                // Get the master ID from the result and validate it
                System.debug('Master record ID: ' + mergeResult.getId());

                // Get the IDs of the merged records and display them
                List<Id> mergedIds = mergeResult.getMergedRecordIds();
                System.debug('IDs of merged records: ' + mergedIds);

                // Get the ID of the re-parented record and validate that this the contact ID.
                System.debug('Re-parented record ID: ' + mergeResult.getUpdatedRelatedIds());
            } else {
                String errorMessage = '';
                for (Database.Error err : mergeResult.getErrors()) {
                    errorMessage += errorMessage;
                    System.debug(err.getMessage());
                }
                throw new AuraHandledException('Something went wrong: ' + errorMessage);
            }
        } else {
            throw new AuraHandledException('Unfortunately, there was a problem. Please try again. ' +
                    'If the problem continues, get in touch with your administrator!');
        }
    }

    @TestVisible
    private static List<SObject> getSObjectRecordByIdWithAllAvailableFields(String objectAPIName, String recordId) {
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap = schemaMap.get(objectAPIName).getDescribe().fields.getMap();
        List<String> fieldsToQuery = new List<String>();
        String soqlQuery = 'SELECT ' ;
        for (String s : fieldMap.keySet()) {
            if (fieldMap.get(s).getDescribe().isAccessible() && fieldMap.get(s).getDescribe().isUpdateable()) {
                fieldsToQuery.add(s);
            }
        }
        soqlQuery += String.join(fieldsToQuery, ',');
        soqlQuery += ' FROM ' + objectAPIName + ' WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\'';
        List<SObject> records = Database.query(soqlQuery);
        return records;
    }
}
