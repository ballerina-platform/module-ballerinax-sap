## Overview

[SAP](https://www.sap.com/india/index.html) is a global leader in enterprise resource planning (ERP) software. Beyond ERP, SAP offers a diverse range of solutions including human capital management (HCM), customer relationship management (CRM), enterprise performance management (EPM), product lifecycle management (PLM), supplier relationship management (SRM), supply chain management (SCM), business technology platform (BTP), and the SAP AppGyver programming environment for businesses.

The `ballerinax/sap` package provides an `HTTP` client for interfacing with APIs across SAP's product suite. This client comes with built-in SAP system-complient CSRF token authentication.

## Setup guide

In this guide, we'll be utilizing the `S/4HANA` Sales Order API to showcase the capabilities of the SAP Client.

### Step 1: Login 

1. Sign in to your S/4HANA dashboard.

### Step 2: Create a Communication System

1. Under the `Communication Management` section, click on the `Display Communications Scenario` title.

    ![Communication Systems](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-1-communications-system.png)

2. In the top right corner of the screen, click `New`.

    ![Click New](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-2-create-new.png)

3. Give a system id.

    ![System Id](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-3-system-id.png)

4. Give the hostname as your S/4HANA hostname.

    ![Give Hostname](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-4-give-hostname.png)

5. Add `Users` for `Inbound Communication`.

    ![Add User](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-5-add-user.png)
   
6. Select the `Authentication Method` and `User`.

    ![Select User](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/2-6-select-user.png)

7. Click Save.

### Step 3: Create a Communication Arrangement

1. Under the `Communication Management` section, click on the `Display Communications Scenario` title.

    ![Display Scenarios](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-1-display-scenarios.png)

2. In the search bar, type `Sales Order Integration` and select the corresponding scenario from the results.

    ![Search Sales Order](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-2-search-sales-order.png)

3. In the top right corner of the screen, click on `Create Communication Arrangement`.

    ![Click Create Arrangement](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-3-click-create-arrangement.png)

4. Enter a unique name for the arrangement.

    ![Give Arrangement Name](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-4-give-arrangement-name.png)

5. Choose an existing `Communication System` from the dropdown menu and save your arrangement.

    ![Select Existing Communication Arrangement](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-5-select-communication-system.png)

6. The hostname (`<unique id>-api.s4hana.cloud.sap`) will be displayed in the top right corner of the screen.

    ![View Hostname](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-sap/main/docs/setup/3-6-view-hostname.png)

## Quickstart

To use the `sap` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the module

Import the `sap` module.

```ballerina
import ballerinax/sap;
```

### Step 2: Instantiate a new connector

```ballerina
configurable string hostname = ?;
configurable string username = ?;
configurable string password = ?;

sap:Client sapClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
    auth: {
        username,
        password
    }
});
```

### Step 3: Invoke the connector operation

Now, utilize the available connector operations.

```ballerina
json salesOrderList = check sapClient->/A_SalesOrder();
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `sap` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-sap/tree/master/examples), covering use cases like accessing S/4HANA Sales Order (A2X) API.

1. [Send a reminder on approval of pending orders](https://github.com/ballerina-platform/module-ballerinax-sap/tree/main/examples/pending-order-reminder) - This example illustrates the use of the `sap:Client` in Ballerina to interact with S/4HANA APIs. Specifically, it demonstrates how to send a reminder email for sales orders that are pending approval.
