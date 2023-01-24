global without sharing class LeadRoundRobinBatch implements Database.Batchable<sObject> {

    private List<Id> leadsIdsToProcess;
    private final List<String> allowedStatuses = new List<String>{'Converted', 'Do Not Pursue'};

    global LeadRoundRobinBatch(List<Id> leadsIdsToProcess){
        this.leadsIdsToProcess = leadsIdsToProcess;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<Id> leadIds = this.leadsIdsToProcess;
        List<String> statusList = allowedStatuses;
        System.debug(leadsIdsToProcess);
        String query = 'SELECT Id, Status, UltiPro_Team__c, UltiPro_LOB__c FROM Lead WHERE Id IN :leadIds AND Status NOT IN :statusList AND (UltiPro_Team__c != NULL OR UltiPro_LOB__c != NULL)';
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
            if (l.UltiPro_Team__c != null) {
                ownerTypes = processOwnerTypeString(l.UltiPro_Team__c, ownerTypes);
            }else if(l.UltiPro_LOB__c != null){
                ownerTypes = processOwnerTypeString(l.UltiPro_LOB__c, ownerTypes);
            }

        }
        return ownerTypes;
    }

    private Set<String> processOwnerTypeString(String ownerTypeString, Set<String> ownerTypes) {
        List<String> types = ownerTypeString.split(',');
        for (String type : types) {
            if (type != '') {
                ownerTypes.add(type);
            }
        }
        return ownerTypes;
    }

    private void roundRobinLeads(List<Lead> leadsToRoundRobin, Map<String, List<RRUser>> leadOwnerTypeToUsers) {
        for (Lead l : leadsToRoundRobin) {
            if(l.UltiPro_Team__c != null){
                String mostAvailableType = getMostAvailableType(l.UltiPro_Team__c, leadOwnerTypeToUsers);

                leadOwnerTypeToUsers.get(mostAvailableType).sort();
                l.OwnerId = leadOwnerTypeToUsers.get(mostAvailableType).get(0).ownerId;
                leadOwnerTypeToUsers.get(mostAvailableType).get(0).leadsCount++;
            }else if(l.UltiPro_LOB__c != null){
                String mostAvailableType = getMostAvailableType(l.UltiPro_LOB__c, leadOwnerTypeToUsers);

                leadOwnerTypeToUsers.get(mostAvailableType).sort();
                l.OwnerId = leadOwnerTypeToUsers.get(mostAvailableType).get(0).ownerId;
                leadOwnerTypeToUsers.get(mostAvailableType).get(0).leadsCount++;
            }
        }
    }

    private String getMostAvailableType(String typesString, Map<String, List<RRUser>> leadOwnerTypeToUsers) {
        List<String> types = typesString.split(',');
        String mostAvailableType = types.get(0);
        leadOwnerTypeToUsers.get(mostAvailableType).sort();
        Integer mostAvailableLeadsCount = leadOwnerTypeToUsers.get(mostAvailableType).get(0).leadsCount;

        for (String type : types) {
            leadOwnerTypeToUsers.get(type).sort();

            if (leadOwnerTypeToUsers.get(type).get(0).leadsCount < mostAvailableLeadsCount) {
                mostAvailableType = type;
                mostAvailableLeadsCount = leadOwnerTypeToUsers.get(type).get(0).leadsCount;
            }
        }
        return mostAvailableType;
    }

    private Map<String, List<RRUser>> getLeadOwnerTypeToUsers(AggregateResult[] groupedLeads, Map<Id, User> usersMap) {
        Map<String, List<RRUser>> leadTypeToUsers = new Map<String, List<RRUser>>();
        System.debug(groupedLeads);
        for (AggregateResult ar : groupedLeads) {
            String userTeam = usersMap.get((Id) ar.get('OwnerId')).UltiPro_Team__c;
            String userLOB = usersMap.get((Id) ar.get('OwnerId')).UltiPro_LOB__c;

            RRUser usr = new RRUser(
                    (Id) ar.get('OwnerId'),
                    (Integer) ar.get('leadCount')
            );

            if(userTeam != null){
                leadTypeToUsers = processLeadTypeToUsers(leadTypeToUsers, userTeam, usr);
            }
            if(userLOB != null){
                leadTypeToUsers = processLeadTypeToUsers(leadTypeToUsers, userLOB, usr);
            }
        }

        addUsersWithNoLeads(usersMap, leadTypeToUsers);

        return leadTypeToUsers;
    }

    private Map<String, List<RRUser>> processLeadTypeToUsers(Map<String, List<RRUser>> leadTypeToUsers, String typeVal, RRUser usr) {
        if (leadTypeToUsers.containsKey(typeVal)) {
            leadTypeToUsers.get(typeVal).add(usr);
        } else {
            leadTypeToUsers.put(typeVal, new List<RRUser>{
                    usr
            });
        }
        return leadTypeToUsers;
    }

    private void addUsersWithNoLeads(Map<Id, User> usersMap, Map<String, List<RRUser>> leadTypeToUsers) {
        for (Id usrId : usersMap.keySet()) {
            Boolean userAdded = isUserAdded(leadTypeToUsers, usrId);
            if (!userAdded) {
                RRUser usr = new RRUser(usrId, 0);
                if(usersMap.get(usrId).UltiPro_Team__c != null){
                    leadTypeToUsers = processLeadTypeToUsers(leadTypeToUsers, usersMap.get(usrId).UltiPro_Team__c, usr);
                }
                if(usersMap.get(usrId).UltiPro_LOB__c != null){
                    leadTypeToUsers = processLeadTypeToUsers(leadTypeToUsers, usersMap.get(usrId).UltiPro_LOB__c, usr);
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
        List<String> statusList = allowedStatuses;
        AggregateResult[] groupedLeads = [
                SELECT OwnerId, COUNT(Id) leadCount
                FROM Lead
                WHERE OwnerId IN :usersMap.keySet()
                AND Status NOT IN :statusList
                GROUP BY OwnerId
        ];
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
                SELECT Id, UltiPro_Team__c, UltiPro_LOB__c
                FROM User
                WHERE (UltiPro_Team__c IN :ownerTypes OR UltiPro_LOB__c IN :ownerTypes)
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
