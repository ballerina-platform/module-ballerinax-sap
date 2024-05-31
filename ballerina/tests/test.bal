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
import ballerina/test;
import ballerinax/sap.mock as _;

Client sapClient = check new (
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
    dependsOn: [testTokenFetch]
}
function testTokenRefreshAfterExpiry() returns error? {
    http:Response response = check sapClient->post("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
    response = check sapClient->post("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {
    dependsOn: [testTokenRefreshAfterExpiry]
}
function testPostRemote() returns error? {
    http:Response response = check sapClient->/A_SalesOrder.post("testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {
    dependsOn: [testPostRemote]
}
function testHeadRemote() returns error? {
    http:Response response = check sapClient->/.head();
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {
    dependsOn: [testHeadRemote]
}
function testHeadResource() returns error? {
    http:Response response = check sapClient->head("");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testGetFunction() returns error? {
    http:Response response = check sapClient->get("/A_SalesOrder");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testGetRemote() returns error? {
    http:Response response = check sapClient->/A_SalesOrder();
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPatchFunction() returns error? {
    http:Response response = check sapClient->patch("/A_SalesOrder/1", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPatchRemote() returns error? {
    http:Response response = check sapClient->/A_SalesOrder/'1.patch("testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPutFunction() returns error? {
    http:Response response = check sapClient->put("/A_SalesOrder/1", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testPutRemote() returns error? {
    http:Response response = check sapClient->/A_SalesOrder/'1.put("testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testDeleteFunction() returns error? {
    http:Response response = check sapClient->delete("/A_SalesOrder", "testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testDeleteRemote() returns error? {
    http:Response response = check sapClient->/A_SalesOrder.delete("testPayload");
    test:assertEquals(response.statusCode, 200, "Status code should be 200");
}

@test:Config {}
function testOptionsRemote() returns error? {
    int intPath = 1;
    http:Response response = check sapClient->/[intPath].options(head = "testPayload");
    test:assertEquals(response.statusCode, 404, "Status code should be 404");
}

@test:Config {}
function testOptionsResource() returns error? {
    json|error response = sapClient->options("");
    test:assertTrue(response is error, "Status code should be 500");
}
