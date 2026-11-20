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
