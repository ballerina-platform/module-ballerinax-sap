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

    // Echoes any header by name, or an empty string when the request does not have it.
    resource function get header/[string name](http:Request req) returns string => headerOf(req, name);

    resource function post header/[string name](http:Request req) returns string => headerOf(req, name);

    // Echoes every value of a header, joined with commas.
    resource function post headers/[string name](http:Request req) returns string {
        string[]|http:HeaderNotFoundError values = req.getHeaders(name);
        return values is string[] ? string:'join(",", ...values) : "";
    }
}

// A header record whose field is sent under another name.
type ApiKeyHeaders record {|
    @http:Header {name: "X-Api-Key"}
    string apiKey;
|};

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

@test:Config {}
function testDefaultAcceptForEveryMethod() returns error? {
    string received = check echoClient->put("/accept", "payload");
    test:assertEquals(received, "application/json");
    received = check echoClient->patch("/accept", "payload");
    test:assertEquals(received, "application/json");
    received = check echoClient->delete("/accept", "payload");
    test:assertEquals(received, "application/json");
    received = check echoClient->options("/accept");
    test:assertEquals(received, "application/json");
    // The resource-function forms share the same behaviour.
    received = check echoClient->/accept;
    test:assertEquals(received, "application/json");
    received = check echoClient->/accept.post("payload");
    test:assertEquals(received, "application/json");
    received = check echoClient->/accept(headers = {"Accept": "application/xml"});
    test:assertEquals(received, "application/xml");
}

@test:Config {}
function testEmptyAcceptFallsBackToJson() returns error? {
    string received = check echoClient->get("/accept", {"Accept": []});
    test:assertEquals(received, "application/json");
    received = check echoClient->get("/accept", {"accept": ""});
    test:assertEquals(received, "application/json");
    received = check echoClient->post("/accept", "payload", {"Accept": []});
    test:assertEquals(received, "application/json");
}

@test:Config {}
function testEmptyAcceptValueDoesNotHideARealOne() returns error? {
    string received = check echoClient->get("/accept", {"Accept": ["", "application/atom+xml"]});
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->post("/accept", "payload", {"Accept": "", "accept": "application/atom+xml"});
    test:assertEquals(received, "application/atom+xml");
}

@test:Config {}
function testHeaderRecordNamesAreResolved() returns error? {
    ApiKeyHeaders headers = {apiKey: "secret"};
    string received = check echoClient->get("/header/X-Api-Key", headers);
    test:assertEquals(received, "secret", "The @http:Header name was not used on GET");
    received = check echoClient->post("/header/X-Api-Key", "payload", headers);
    test:assertEquals(received, "secret", "The @http:Header name was not used on POST");
}

@test:Config {}
function testAcceptOnRequestMessageIsKept() returns error? {
    http:Request request = new;
    request.setTextPayload("payload");
    request.setHeader("Accept", "application/atom+xml");
    string received = check echoClient->post("/accept", request);
    test:assertEquals(received, "application/atom+xml");
    received = check echoClient->put("/accept", request);
    test:assertEquals(received, "application/atom+xml");

    // A header map still wins over the request, as it does for `http:Client`.
    received = check echoClient->post("/accept", request, {"Accept": "application/xml"});
    test:assertEquals(received, "application/xml");
}

@test:Config {}
function testRequestMessageIsLeftAsTheCallerSetIt() returns error? {
    http:Request request = new;
    request.setTextPayload("payload");
    request.setHeader("Accept", "application/atom+xml");
    request.setHeader("X-Request-Id", "42");
    string _ = check echoClient->post("/accept", request, {"Accept": "application/xml"});
    test:assertEquals(check request.getHeader("Accept"), "application/atom+xml", "The caller's Accept was replaced on the request");
    test:assertEquals(check request.getHeader("X-Request-Id"), "42");
    test:assertFalse(request.hasHeader(SAP_CSRF_HEADER), "The CSRF token was left on the caller's request");

    http:Request plain = new;
    plain.setTextPayload("payload");
    string _ = check echoClient->post("/accept", plain);
    test:assertFalse(plain.hasHeader(SAP_CSRF_HEADER), "The CSRF token was left on the caller's request");
    test:assertFalse(plain.hasHeader("Accept"), "The default Accept was left on the caller's request");
    // Nothing the HTTP client adds on the way reaches the caller's request either.
    test:assertFalse(plain.hasHeader("Authorization"), "The credentials were left on the caller's request");
    test:assertFalse(plain.hasHeader("Cookie"), "The session cookie was left on the caller's request");

    http:Request typed = new;
    typed.setTextPayload("payload", "text/plain");
    string sent = check echoClient->post("/header/Content-Type", typed, mediaType = "application/xml");
    test:assertEquals(sent, "application/xml");
    test:assertEquals(typed.getContentType(), "text/plain", "The media type was written to the caller's request");
    test:assertEquals(check typed.getTextPayload(), "payload");
}

@test:Config {}
function testHeaderMapReplacesTheRequestHeader() returns error? {
    http:Request request = new;
    request.setTextPayload("payload");
    request.setHeader("sap-client", "100");
    // An array value replaces the header of the request too, so the request goes to one SAP client only.
    string received = check echoClient->post("/headers/sap-client", request, {"sap-client": ["200"]});
    test:assertEquals(received, "200");
    received = check echoClient->post("/headers/sap-client", request, {"SAP-Client": "300"});
    test:assertEquals(received, "300");
    received = check echoClient->post("/headers/sap-client", request);
    test:assertEquals(received, "100");
}

@test:Config {}
function testRequestCacheControlIsKept() returns error? {
    http:RequestCacheControl cacheControl = new;
    cacheControl.noCache = true;
    http:Request request = new;
    request.setTextPayload("payload");
    request.cacheControl = cacheControl;
    string received = check echoClient->post("/header/Cache-Control", request);
    test:assertEquals(received, "no-cache", "The cache control directives of the request were not sent");
}
