({
    resetDuplicate: function (component, event, helper) {
        $A.util.addClass(component.find("merge_lead"), "slds-hide");

        const action = component.get("c.setPotentialDuplicateFalse");
        action.setParams({
            "recordId": component.get("v.recordId")
        });
        
        $A.enqueueAction(action);
        $A.get('e.force:refreshView').fire();
    },

    openModal: function (component, event, helper) {
        component.set("v.isModalOpen", true);
        component.set("v.isLoading", true);
        component.set("v.columns", helper.getColumnDefinitions());

        const action = component.get("c.getPotentialDuplicateLeads");
        action.setParams({
            "recordId": component.get("v.recordId")
        });
        action.setCallback(this, function (response) {
            const state = response.getState();
            console.log('state', state);
            if (state === "SUCCESS") {
                const records = response.getReturnValue();
                records.forEach(function (record) {
                    record.linkName = "/" + record.Id;
                });
                console.log('result', records);
                component.set('v.leads', records);
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    },

    closeModal: function (component, event, helper) {
        component.set("v.isModalOpen", false);
    },

    submitDetails: function (component, event, helper) {
        component.set("v.isModalOpen", false);
        component.set("v.isLoading", true);

        const action = component.get("c.mergeLeadDuplicates");
        action.setParams({
            "recordId": component.get("v.recordId"),
            "masterId": component.get("v.masterId"),
            "duplicateLeads": component.get("v.leads")
        });
        action.setCallback(this, function (response) {
            const state = response.getState();
            console.log('state: ', state);

            if (state === "SUCCESS") {
                helper.navigateToRecord(component, event);
                helper.showToast(component, event);
            } else if (state === "INCOMPLETE") {
                console.log("incomplete");
            } else if (state === "ERROR") {
                helper.handleMergeErrors(component, event, response);
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    },

    handleRowSelection: function (component, event, helper) {
        const selectedId = event.getParam('selectedRows')[0].Id;
        component.find("submit_button").set('v.disabled', false);
        component.set("v.masterId", selectedId);
        console.log('duplicateId: ', selectedId);
    }
});
