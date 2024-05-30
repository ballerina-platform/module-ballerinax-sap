# Examples

The `sap` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-sap/tree/master/examples), covering use cases like accessing S/4HANA Sales Order (A2X) API.

1. [Send a reminder on approval of pending orders](https://github.com/ballerina-platform/module-ballerinax-sap/tree/main/examples/pending-order-reminder) - This example illustrates the use of the `sap:Client` in Ballerina to interact with S/4HANA APIs. Specifically, it demonstrates how to send a reminder email for sales orders that are pending approval.

## Prerequisites

Each example includes detailed steps.

## Running an Example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the Examples with the Local Module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
