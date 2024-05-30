# Send reminder on approval pending sales orders

This example illustrates the use of the `sap:Client` in Ballerina to interact with S/4HANA APIs. Specifically, it demonstrates how to send a reminder email for sales orders that are pending approval.

## Prerequisites

### 1. Setup S/4HANA API

Refer to the [Setup Guide](https://central.ballerina.io/ballerinax/sap/latest#setup-guide) for necessary credentials (hostname, username, password).

### 2. Setup Gmail API

Refer to the [Setup Guide](https://central.ballerina.io/ballerinax/googleapis.gmail/latest#setup-guide) for necessary credentials (client ID, secret, tokens).

### 3. Configuration

Configure SAP and Gmail API credentials in `Config.toml` in the example directory:

```toml
hostname="<Hostname>"
username="<Username>"
password="<Password>"
refreshToken="<Refresh Token>"
clientId="<Client Id>"
clientSecret="<Client Secret>"
recipient="<Recipient Email Address>"
```

## Run the Example

Execute the following command to run the example:

```bash
bal run
```