global without sharing class LeadRoundRobinBatch implements Database.Batchable<sObject> {

    private List<Id> leadsIdsToProcess;

    global LeadRoundRobinBatch(List<Id> leadsIdsToProcess){
        this.leadsIdsToProcess = leadsIdsToProcess;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<Id> leadIds = this.leadsIdsToProcess;
        String query = 'SELECT Id, Status, Lead_Owner_Type__c FROM Lead WHERE Id IN :leadIds';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Lead> leadsToRoundRobin) {
        Set<String> ownerTypes = getOwnerTypes(leadsToRoundRobin);
        Map<Id, User> usersMap = getUsersMap(ownerTypes);
        if(usersMap.keySet().isEmpty()) return;
        AggregateResult[] groupedLeads = getGroupedLeads(usersMap);
        Map<String, List<RRUser>> leadOwnerTypeToUsers = getLeadOwnerTypeToUsers(groupedLeads, usersMap);
        if(leadOwnerTypeToUsers.keySet().isEmpty()) return;
        roundRobinLeads(leadsToRoundRobin, leadOwnerTypeToUsers);

        update leadsToRoundRobin;
    }

    private Set<String> getOwnerTypes(List<Lead> leadsToRoundRobin) {
        Set<String> ownerTypes = new Set<String>();
        for (Lead l : leadsToRoundRobin) {
            if (l.Lead_Owner_Type__c != null) {
                ownerTypes.add(l.Lead_Owner_Type__c);
            }
        }
        return ownerTypes;
    }

    private void roundRobinLeads(List<Lead> leadsToRoundRobin, Map<String, List<RRUser>> leadOwnerTypeToUsers) {
        for (Lead l : leadsToRoundRobin) {
            if(l.Lead_Owner_Type__c != null){
                leadOwnerTypeToUsers.get(l.Lead_Owner_Type__c).sort(); //should be l.LOB
                l.OwnerId = leadOwnerTypeToUsers.get(l.Lead_Owner_Type__c).get(0).ownerId;
            }
        }
    }

    private Map<String, List<RRUser>> getLeadOwnerTypeToUsers(AggregateResult[] groupedLeads, Map<Id, User> usersMap) {
        Map<String, List<RRUser>> leadTypeToUsers = new Map<String, List<RRUser>>();
        System.debug(groupedLeads);
        for (AggregateResult ar : groupedLeads) {
            String userType = usersMap.get((Id) ar.get('OwnerId')).Type__c;  //TBD

            RRUser usr = new RRUser(
                    (Id) ar.get('OwnerId'),
                    (Integer) ar.get('leadCount')
            );

            if (leadTypeToUsers.containsKey(userType)) {
                leadTypeToUsers.get(userType).add(usr);
            } else {
                leadTypeToUsers.put(userType, new List<RRUser>{
                        usr
                });
            }
        }

        addUsersWithNoLeads(usersMap, leadTypeToUsers);

        return leadTypeToUsers;
    }

    private void addUsersWithNoLeads(Map<Id, User> usersMap, Map<String, List<RRUser>> leadTypeToUsers) {
        for (Id usrId : usersMap.keySet()) {
            Boolean userAdded = isUserAdded(leadTypeToUsers, usrId);
            if (!userAdded) {
                RRUser usr = new RRUser(usrId, 0);
                if (leadTypeToUsers.containsKey(usersMap.get(usrId).Type__c)) {
                    leadTypeToUsers.get(usersMap.get(usrId).Type__c).add(usr);
                } else {
                    leadTypeToUsers.put(usersMap.get(usrId).Type__c, new List<RRUser>{
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
                WHERE Type__c IN :ownerTypes   //TBD
                AND IsActive = true
        ]);
        return usersMap;
    }

    global void finish(Database.BatchableContext BC) {
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
