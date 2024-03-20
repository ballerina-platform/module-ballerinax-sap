// Copyright (c) 2024, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/test;
import ballerinax/sap.mock as _;

HttpClient sapClient = check new (
    url = "http://localhost:9093/API_SALES_ORDER_SRV",
    config = {
        auth: {
            username: "testuser",
            password: "testpassword"
        }
    }
);

@test:Config {}
function testTokenFetch() returns error? {
    http:Response response = check sapClient->post("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {
    enable: false,
    dependsOn: [testTokenFetch]
}
function testTokenRefreshAfterExpiry() returns error? {
    http:Response response = check sapClient->post("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
    response = check sapClient->post("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testGetFunction() returns error? {
    http:Response response = check sapClient->get("/A_SalesOrder");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPatchFunction() returns error? {
    http:Response response = check sapClient->patch("/A_SalesOrder/1", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPutFunction() returns error? {
    http:Response response = check sapClient->put("/A_SalesOrder/1", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testDeleteFunction() returns error? {
    http:Response response = check sapClient->delete("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}
