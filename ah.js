({
    getColumnDefinitions: function () {
        return [
            {
                label: "Name",
                fieldName: "linkName",
                type: "url",
                typeAttributes: {label: {fieldName: "Name"}, target: "_blank"}
            },
            {label: "Title", fieldName: "Title", type: "text"},
            {label: "Company", fieldName: "Company", type: "text"},
            {label: "Phone", fieldName: "Phone", type: "text"},
            {label: "Email", fieldName: "Email", type: "text"},
            {label: "Status", fieldName: "Status", type: "text"}
        ];
    },

    handleMergeErrors: function (component, event, response) {
        const errors = response.getError();
        if (errors) {
            if (errors[0] && errors[0].message) {
                console.log("Error message: " + errors[0].message);
            }
            this.openAlert(component, event, errors[0].message);
        } else {
            console.log("Unknown error");
        }
    },

    openAlert: function (component, event, message) {
        this.LightningAlert.open({
            message: message,
            theme: 'error',
            label: 'Error!',
        }).then(function () {
            console.log('alert is closed');
        });
    },

    showToast: function (component, event) {
        const toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            message: 'Merge has been completed successfully!',
            type: 'success'
        });
        toastEvent.fire();
    },

    navigateToRecord: function (component, event) {
        const recordId = component.get("v.masterId");

        const navigationEvent = $A.get("e.force:navigateToSObject");
        navigationEvent.setParams({
            recordId: recordId,
            slideDevName: "view"
        });
        navigationEvent.fire();
    }
});