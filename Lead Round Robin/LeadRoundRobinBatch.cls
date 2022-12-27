global without sharing class LeadRoundRobinBatch implements Database.Batchable<sObject> {

    private List<Id> leadsIdsToProcess;

    global LeadRoundRobinBatch(List<Id> leadsIdsToProcess){
        this.leadsIdsToProcess = leadsIdsToProcess;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<Id> leadIds = this.leadsIdsToProcess;
        String query = 'SELECT Id, Status, Type__c FROM Lead WHERE Id IN :leadIds';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Lead> leadsToRoundRobin) {
        Map<String, List<Lead>> leadTypeToLeadsMap = getLeadTypeToLeadsMap(leadsToRoundRobin);
        Map<String, List<String>> mapping = getOwnersMapping(new List<String>(leadTypeToLeadsMap.keySet()));
        Set<String> ownerTypes = getOwnerTypes(mapping);
        Map<Id, User> usersMap = getUsersMap(ownerTypes);
        if(usersMap.keySet().isEmpty()) return;
        AggregateResult[] groupedLeads = getGroupedLeads(usersMap);
        Map<String, List<RRUser>> leadTypeToUsers = getLeadTypeToUsers(groupedLeads, usersMap, mapping);
        if(leadTypeToUsers.keySet().isEmpty()) return;
        roundRobinLeads(leadsToRoundRobin, leadTypeToUsers);

        update leadsToRoundRobin;
    }

    private void roundRobinLeads(List<Lead> leadsToRoundRobin, Map<String, List<RRUser>> leadTypeToUsers) {
        for (Lead l : leadsToRoundRobin) {
            System.debug(leadTypeToUsers);
            System.debug(l.Type__c);
            leadTypeToUsers.get(l.Type__c).sort(); //should be l.LOB
            l.OwnerId = leadTypeToUsers.get(l.Type__c).get(0).ownerId;
        }
    }

    private Map<String, List<RRUser>> getLeadTypeToUsers(AggregateResult[] groupedLeads, Map<Id, User> usersMap, Map<String, List<String>> mapping) {
        Map<String, List<RRUser>> leadTypeToUsers = new Map<String, List<RRUser>>();
        System.debug(groupedLeads);
        for (AggregateResult ar : groupedLeads) {
            String userType = usersMap.get((Id) ar.get('OwnerId')).Type__c;  //TBD
            String leadType = getLeadTypeByUserType(userType, mapping);

            RRUser usr = new RRUser(
                    (Id) ar.get('OwnerId'),
                    (Integer) ar.get('leadCount')
            );

            if (leadTypeToUsers.containsKey(leadType)) {
                leadTypeToUsers.get(leadType).add(usr);
            } else {
                leadTypeToUsers.put(leadType, new List<RRUser>{
                        usr
                });
            }
        }

        addUsersWithNoLeads(usersMap, leadTypeToUsers, mapping);

        return leadTypeToUsers;
    }

    private void addUsersWithNoLeads(Map<Id, User> usersMap, Map<String, List<RRUser>> leadTypeToUsers, Map<String, List<String>> mapping) {
        for (Id usrId : usersMap.keySet()) {
            Boolean userAdded = isUserAdded(leadTypeToUsers, usrId);
            if (!userAdded) {
                String leadType = getLeadTypeByUserType(usersMap.get(usrId).Type__c, mapping); //TBD
                RRUser usr = new RRUser(usrId, 0);
                if (leadTypeToUsers.containsKey(leadType)) {
                    leadTypeToUsers.get(leadType).add(usr);
                } else {
                    leadTypeToUsers.put(leadType, new List<RRUser>{
                            usr
                    });
                }
            }
        }
    }

    private Boolean isUserAdded(Map<String, List<RRUser>> leadTypeToUsers, Id usrId) {
        Boolean userAdded = false;
        for (String leadType : leadTypeToUsers.keySet()) {
            for (RRUser usr : leadTypeToUsers.get(leadType)) {
                if (usr.ownerId == usrId) {
                    userAdded = true;
                    break;
                }
            }
        }
        return userAdded;
    }

    private AggregateResult[] getGroupedLeads(Map<Id, User> usersMap) {
        AggregateResult[] groupedLeads = [
                SELECT OwnerId, COUNT(Id) leadCount
                FROM Lead
                WHERE OwnerId IN :usersMap.keySet()
                GROUP BY OwnerId
        ];
//        AND Status = 'New'                             //TBD
        System.debug(groupedLeads);
        return groupedLeads;
    }

    private String getLeadTypeByUserType(String userType, Map<String, List<String>> mapping) {
        for(String leadType : mapping.keySet()){
            if(mapping.get(leadType).contains(userType)){
                return leadType;
            }
        }
        return null;
    }

    private Map<Id, User> getUsersMap(Set<String> ownerTypes) {
        Map<Id, User> usersMap = new Map<Id, User>([
                SELECT Id, Type__c                    //TBD
                FROM User
                WHERE Type__c IN :ownerTypes          //TBD
        ]);
        return usersMap;
    }

    private Set<String> getOwnerTypes(Map<String, List<String>> mapping) {
        Set<String> ownerTypes = new Set<String>();
        for (String key : mapping.keySet()) {
            ownerTypes.addAll(mapping.get(key));
        }
        return ownerTypes;
    }

    private Map<String, List<Lead>> getLeadTypeToLeadsMap(List<Lead> leadsToRoundRobin) {
        Map<String, List<Lead>> leadTypeToLeadsMap = new Map<String, List<Lead>>();
        for (Lead l : leadsToRoundRobin) {
            if (leadTypeToLeadsMap.containsKey(l.Type__c)) { //TBD
                leadTypeToLeadsMap.get(l.Type__c).add(l); //TBD
            } else {
                leadTypeToLeadsMap.put(l.Type__c, new List<Lead>{l}); //TBD
            }
        }
        return leadTypeToLeadsMap;
    }

    global void finish(Database.BatchableContext BC) {
    }

    private static Map<String, List<String>> getOwnersMapping(List<String> lobs){
        Map<String, List<String>> mapping = new Map<String, List<String>>();
        List<RR_User_Type__mdt> mappingTypes = getMappingTypes(lobs);

        for(RR_User_Type__mdt usrType : mappingTypes){
            if(mapping.containsKey(usrType.RR_Lead_Type__r.Value__c)){
                mapping.get(usrType.RR_Lead_Type__r.Value__c).add(usrType.Value__c);
            }else{
                mapping.put(usrType.RR_Lead_Type__r.Value__c, new List<String>{usrType.Value__c});
            }
        }

        return mapping;
    }

    private static List<RR_User_Type__mdt> getMappingTypes(List<String> lobs) {
        List<RR_User_Type__mdt> mappingTypes = [
                SELECT Id, Value__c, RR_Lead_Type__r.Value__c
                FROM RR_User_Type__mdt
                WHERE RR_Lead_Type__r.Value__c IN :lobs
        ];
        return mappingTypes;
    }

    private class RRUser implements Comparable{
        public String ownerId{get;set;}
        public Integer leadsCount{get;set;}

        public RRUser(){
            this.leadsCount = 0;
        }

        public RRUser(String ownerId, Integer leadsCount){
            this();
            this.ownerId = ownerId;
            this.leadsCount = leadsCount != null ? leadsCount : 0;
        }

        public Integer compareTo(Object compareTo) {
            RRUser compareToRRUser = (RRUser)compareTo;
            if (leadsCount == compareToRRUser.leadsCount) return 0;
            if (leadsCount > compareToRRUser.leadsCount) return 1;
            return -1;
        }
    }
}
