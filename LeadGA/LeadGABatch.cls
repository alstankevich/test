global without sharing class LeadGABatch implements Database.Batchable<sObject>{
    private List<Id> leadsIdsToProcess;
    private GA_Setup__c apiSetup;
    private final String GA_ID = 'GA_ID';
    private final String LEAD_ID = 'LEAD_ID';
    private final String HTTP_METHOD = 'POST';
    private final String CONTENT_TYPE_LABEL = 'Content-Type';
    private final String CONTENT_TYPE_VALUE = 'application/json';
    private final String HTTP_BODY_TEMPLATE = '{"client_id": "GA_ID","user_id": "LEAD_ID","events":[{"name":"lead_conversion","params":{}}]}';


    global LeadGABatch(List<Id> leadsIdsToProcess){
        this.leadsIdsToProcess = leadsIdsToProcess;
        this.apiSetup = GA_Setup__c.getOrgDefaults();
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<Id> leadIds = this.leadsIdsToProcess;
        String query = 'SELECT Id, Google_Analytics_Id__c ' +
                'FROM Lead ' +
                'WHERE Id IN :leadIds ' +
                'AND IsConverted = TRUE ' +
                'AND Google_Analytics_Id__c != null';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Lead> leadsToSendToGA) {
        for(Lead lead : leadsToSendToGA){
            if(lead.Google_Analytics_Id__c != null){
                    makeRequest(lead.Google_Analytics_Id__c, lead.Id);
            }
        }
    }

    private void makeRequest(String googleAnalyticsId, String leadId){
        HttpRequest req = new HttpRequest();
        req.setMethod(HTTP_METHOD);
        req.setHeader(CONTENT_TYPE_LABEL,CONTENT_TYPE_VALUE);
        req.setEndpoint(apiSetup.Endpoint__c);
        req.setBody(HTTP_BODY_TEMPLATE.replace(GA_ID, googleAnalyticsId).replace(LEAD_ID, leadId));
        Http binding = new Http();
        HttpResponse res = binding.send(req);
    }

    global void finish(Database.BatchableContext BC) {
    }
}
