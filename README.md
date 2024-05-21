# Ballerina SAP Connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/ci.yml)
[![Trivy](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/trivy-scan.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerinax-sap/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerinax-sap)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-sap/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-sap.svg)](https://github.com/ballerina-platform/module-ballerinax-sap/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/sap.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fsap)

[SAP](https://www.sap.com/india/index.html) is a global leader in enterprise resource planning (ERP) software. Beyond ERP, SAP offers a diverse range of solutions including human capital management (HCM), customer relationship management (CRM), enterprise performance management (EPM), product lifecycle management (PLM), supplier relationship management (SRM), supply chain management (SCM), business technology platform (BTP), and the SAP AppGyver programming environment for businesses.

The `ballerinax/sap` package provides an `HTTP` client for interfacing with APIs across SAP's product suite. This client comes with built-in SAP system complient CSRF token authentication.

## Setup guide

In this guide, we'll be utilizing the `S/4HANA` Sales Order API to showcase the capabilities of the SAP Client.

### Step 1: Login 

1. Sign in to your S/4HANA dashboard.

### Step 2: Create Communication System

1. Under the `Communication Management` section, click on the `Display Communications Scenario` title.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-1-communications-system.png alt="Communication Systems" width="50%">

2. In the top right corner of the screen, click `New`.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-2-create-new.png alt="Click New" width="50%">

3. Give a system id.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-3-system-id.png alt="System Id" width="50%">

4. Give the hostname as your S/4HANA hostname.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-4-give-hostname.png alt="Give Hostname" width="50%">

5. Add Users for Inbound Communication.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-5-add-user.png alt="Add User" width="50%">
   
6. Select Authentication Method and User.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/2-6-select-user.png alt="Select User" width="50%">

7. Click Save.

### Step 3: Create Communication Arrangement

1. Under the `Communication Management` section, click on the `Display Communications Scenario` title.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-1-display-scenarios.png alt="Display Scenarios" width="50%">

2. In the search bar, type `Sales Order Integration` and select the corresponding scenario from the results.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-2-search-sales-order.png alt="Search Sales Order" width="50%">

3. In the top right corner of the screen, click on `Create Communication Arrangement`.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-3-click-create-arrangement.png alt="Click Create Arrangement" width="50%">

4. Enter a unique name for the arrangement.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-4-give-arrangement-name.png alt="Give Arrangement Name" width="50%">


5. Choose an existing `Communication System` from the dropdown menu and save your arrangement.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-5-select-communication-system.png alt="Select Existing Communication Arrangement" width="50%">

6. The hostname (`<unique id>-api.s4hana.cloud.sap`) will be displayed in the top right corner of the screen.

   <img src=https://github.com/ballerina-platform/module-ballerinax-sap/blob/main/docs/setup/3-6-view-hostname.png alt="View Hostname" width="50%">


## Quickstart

To use the `sap` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the module

Import the `sap` module.

```ballerina
import ballerinax/sap;
```

### Step 2: Instantiate a new connector

```ballerina
sap:HttpClient sapClient = check new("https://<hostname>/sap/opu/odata/sap/API_SALES_ORDER_SRV", {
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

## Issues and projects

The **Issues** and **Projects** tabs are disabled for this repository as this is part of the Ballerina library. To report bugs, request new features, start new discussions, view project boards, etc., visit the Ballerina library [parent repository](https://github.com/ballerina-platform/ballerina-library).

This repository only contains the source code for the package.

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 17. You can download it from either of the following sources:

   * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
   * [OpenJDK](https://adoptium.net/)

    > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

    > **Note**: Ensure that the Docker daemon is running before executing any tests.

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environment:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

   Tip: The following groups of test cases are available.
   Groups | Environment
   ---| ---
   mock | Mock server
   sap | SAP S/4HANA API

5. To debug package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`sap` package](https://lib.ballerina.io/ballerinax/sap/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
