// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org).
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

// Echoes the `Accept` header the server received, so the tests can see what the client sent.
service /echo on new http:Listener(9402) {
    resource function head .() returns http:Response {
        http:Response response = new;
        response.setHeader(SAP_CSRF_HEADER, "echo-csrf-token");
        return response;
    }

    resource function get accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);

    resource function post accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);

    resource function put accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);

    resource function patch accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);

    resource function delete accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);

    resource function options accept(http:Request req) returns string|error => req.getHeader(ACCEPT_HEADER);
}

final Client echoClient = check new ("http://localhost:9402/echo", {
    auth: {username: "testuser", password: "testpassword"},
    httpVersion: http:HTTP_1_1
});

@test:Config {}
function testDefaultAcceptIsJson() returns error? {
    string received = check echoClient->get("/accept");
    test:assertEquals(received, "application/json");
    received = check echoClient->post("/accept", "payload");
    test:assertEquals(received, "application/json");
}

@test:Config {}
function testCallerAcceptIsKept() returns error? {
    map<string> headers = {"Accept": "application/atom+xml"};
    string received = check echoClient->get("/accept", headers);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->post("/accept", "payload", headers);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->put("/accept", "payload", headers);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->patch("/accept", "payload", headers);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->delete("/accept", "payload", headers);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->options("/accept", headers);
    test:assertEquals(received, "application/atom+xml");
}

@test:Config {}
function testCallerAcceptIsMatchedCaseInsensitively() returns error? {
    string received = check echoClient->get("/accept", {"accept": "application/xml"});
    test:assertEquals(received, "application/xml");
    received = check echoClient->post("/accept", "payload", {"ACCEPT": "application/xml"});
    test:assertEquals(received, "application/xml");
}

@test:Config {}
function testCallerHeaderMapIsNotModified() returns error? {
    map<string> withAccept = {"Accept": "application/atom+xml"};
    string _ = check echoClient->get("/accept", withAccept);
    string _ = check echoClient->post("/accept", "payload", withAccept);
    test:assertEquals(withAccept, {"Accept": "application/atom+xml"});

    map<string> withoutAccept = {"X-Request-Id": "42"};
    string _ = check echoClient->get("/accept", withoutAccept);
    string _ = check echoClient->put("/accept", "payload", withoutAccept);
    http:Response _ = check echoClient->head("/", withoutAccept);
    test:assertEquals(withoutAccept, {"X-Request-Id": "42"});
}

@test:Config {}
function testReadOnlyHeaderMapIsAccepted() returns error? {
    final map<string> & readonly headers = {"Accept": "application/xml"};
    string received = check echoClient->get("/accept", headers);
    test:assertEquals(received, "application/xml");
    received = check echoClient->post("/accept", "payload", headers);
    test:assertEquals(received, "application/xml");
    http:Response response = check echoClient->head("/", headers);
    test:assertEquals(response.statusCode, 200);

    final map<string> & readonly noAccept = {"X-Request-Id": "42"};
    received = check echoClient->get("/accept", noAccept);
    test:assertEquals(received, "application/json");
}
