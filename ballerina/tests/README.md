# Running Tests

The SAP connector supports two test environments. The primary environment is a mock server, specifically designed to handle CSRF token expiry. The secondary environment utilizes the S/4HANA Sales Order (A2X) API. Each environment has a unique set of compatible tests that can be executed independently.

Test Groups | Environment
---| ---
mock | Mock server 
sap | S/4HANA API

**Note**: By default, the Gradle build enables tests for both environments. However, in GitHub workflows, the S/4HANA environment tests are disabled due to the lack of continuous access to the S/4HANA environment.

## Running Tests in the Mock Server Only

```sh
bal test --disable-groups sap
```

```sh
./gradlew clean build -Pdisable=sap
```

## Running Tests in S/4HANA API Only

**Note**: The test case designed to handle the CSRF token expiry scenario may take approximately 35 minutes to run due to the configuration in S/4HANA setup.

### Prerequisites

### 1. Setup the S/4HANA API

Refer to the [Setup Guide](https://central.ballerina.io/ballerinax/sap/latest#setup-guide) for the necessary credentials (hostname, username, password).

### 2. Configuration

Create a `Config.toml` file in the tests directory and add your authentication credentials.

```toml
hostname="<Hostname>"
username="<Username>"
password="<Password>"
```

### 3. Run tests

```sh
bal test --groups sap
```

```sh
./gradlew clean build -Pgroups=sap
```
