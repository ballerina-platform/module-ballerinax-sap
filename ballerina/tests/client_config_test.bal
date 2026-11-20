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

// Reports back the `Upgrade` header a client sends.
service /upgrade on new http:Listener(9404, httpVersion = http:HTTP_1_1) {
    resource function get .(http:Request req) returns string {
        string|http:HeaderNotFoundError upgrade = req.getHeader("Upgrade");
        return upgrade is string ? upgrade : "none";
    }
}

// Sets two cookies and reports back the cookies a client sends.
service /cookies on new http:Listener(9403) {
    resource function get set() returns http:Response {
        http:Response response = new;
        response.addCookie(new http:Cookie("first", "1", path = "/"));
        response.addCookie(new http:Cookie("second", "2", path = "/"));
        return response;
    }

    resource function get sent(http:Request req) returns string {
        string|http:HeaderNotFoundError cookies = req.getHeader("Cookie");
        return cookies is string ? cookies : "";
    }
}

@test:Config {}
function testCallerCookieConfigIsApplied() returns error? {
    Client limitedClient = check new ("http://localhost:9403/cookies", {
        auth: {username: "testuser", password: "testpassword"},
        cookieConfig: {enabled: false, maxCookiesPerDomain: 1}
    });
    http:Response _ = check limitedClient->get("/set");
    string sent = check limitedClient->get("/sent");
    // Cookies stay enabled even though the caller turned them off, and the caller's limit of one cookie applies.
    test:assertTrue(sent.startsWith("first=") || sent.startsWith("second="), string `Expected a cookie, the client sent: "${sent}"`);
    test:assertEquals(re `;`.split(sent).length(), 1, string `Expected one cookie, the client sent: ${sent}`);
}

@test:Config {}
function testCookiesAreEnabledByDefault() returns error? {
    Client defaultClient = check new ("http://localhost:9403/cookies", {
        auth: {username: "testuser", password: "testpassword"}
    });
    http:Response _ = check defaultClient->get("/set");
    string sent = check defaultClient->get("/sent");
    test:assertEquals(re `;`.split(sent).length(), 2, string `Expected both cookies, the client sent: ${sent}`);
}

@test:Config {}
function testHttp11IsTheDefault() returns error? {
    ConnectionConfig config = {auth: {username: "testuser", password: "testpassword"}};
    test:assertEquals(config.httpVersion, http:HTTP_1_1);

    Client defaultClient = check new ("http://localhost:9404/upgrade", config);
    string upgrade = check defaultClient->get("");
    test:assertEquals(upgrade, "none", "An HTTP/1.1 client must not ask to upgrade to h2c");
}

@test:Config {}
function testHttp2CanStillBeChosen() returns error? {
    Client http2Client = check new ("http://localhost:9404/upgrade", {
        auth: {username: "testuser", password: "testpassword"},
        httpVersion: http:HTTP_2_0
    });
    string upgrade = check http2Client->get("");
    test:assertEquals(upgrade, "h2c", "An HTTP/2 client on an http:// URL asks to upgrade");
}
