// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;

configurable string hostname = ?;
configurable string username = ?;
configurable string password = ?;

// This test is run against the SAP Sales Order API. 
Client s4HanaClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
    auth: {
        username,
        password
    }
});

@test:Config {
    groups: ["sap"]
}
function testCSRFTokenRefresh() returns error? {
    json body = {
        "SalesOrder": "1234",
        "SalesOrderType": "OR",
        "SalesOrganization": "1710",
        "DistributionChannel": "10",
        "OrganizationDivision": "00",
        "SalesGroup": "170",
        "SalesOffice": "170",
        "RequestedDeliveryDate": "2024-04-13T12:00",
        "SoldToParty": "17100001",
        "PurchaseOrderByCustomer": "12345"
    };

    http:Response response = check s4HanaClient->/A_SalesOrder.post(body);
    test:assertEquals(response.statusCode, 404, "Status code should be 404, this creates a partial sales order meant to fail");

    // Sleep for 33 m to allow the CSRF token to expire
    runtime:sleep(2000);

    // Try again. If the csrf token is refreshed we expect 404 this time too
    response = check s4HanaClient->/A_SalesOrder.post(body);
    test:assertEquals(response.statusCode, 404, "Status code should be 404, this creates a partial sales order meant to fail");
}
