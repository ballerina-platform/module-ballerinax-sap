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

service /API_SALES_ORDER_SRV on new http:Listener(9093) {

    int headCount = 0;
    int postCount = 0;

    resource function head .() returns http:Response {
        http:Response res = new;
        if self.headCount == 0 {
            http:Cookie cookie1 = new http:Cookie("session", "session1", {path: "/"});
            res.setHeader("X-CSRF-TOKEN", "token1");
            res.addCookie(cookie1);
        } else {
            res.setHeader("X-CSRF-TOKEN", "token2");
        }
        self.headCount = self.headCount + 1;
        return res;
    }

    resource function options .() returns http:Response|http:InternalServerError {
        return http:INTERNAL_SERVER_ERROR;
    }

    resource function get A_SalesOrder() returns http:Response {
        http:Response res = new;
        res.setPayload("Sales Order");
        return res;
    }

    resource function delete A_SalesOrder(http:Request req) returns http:Response {
        http:Response res = new;
        res.setPayload("Deleted Sales Order");
        return res;
    }

    resource function patch A_SalesOrder/[string salesOrder](http:Request req) returns http:Response {
        http:Response res = new;
        res.setPayload("Sales Order Updated");
        return res;
    }

    resource function put A_SalesOrder/[string salesOrder](http:Request req) returns http:Response {
        http:Response res = new;
        res.setPayload("Sales Order Updated");
        return res;

    }

    resource function post A_SalesOrder(http:Request req) returns http:Response {
        http:Cookie[] cookies = req.getCookies();
        http:Response res = new;
        if self.postCount == 0 {
            if cookies.length() == 1 && cookies[0].name == "session" && cookies[0].value == "session1" {
                res.statusCode = 200;
                res.setPayload("Sales Order Created");
            } else {
                res.statusCode = 403;
            }
        } else if self.postCount == 1 {
            if cookies.length() == 1 && cookies[0].name == "session" && cookies[0].value == "session1" {
                res.statusCode = 200;
            } else {
                res.statusCode = 403;
                res.addHeader("X-CSRF-TOKEN", "Required");
                res.addCookie(new http:Cookie("session", "session1", {path: "/"}));
            }
        } else if self.postCount == 2 {
            if cookies.length() == 1 && cookies[0].name == "session" && cookies[0].value == "session1" {
                res.statusCode = 403;
                res.addHeader("X-CSRF-TOKEN", "Required");
                res.addCookie(new http:Cookie("session", "session2", {path: "/"}));
            } else {
                res.statusCode = 400;
            }
        } else {
            if cookies.length() == 1 && cookies[0].name == "session" && cookies[0].value == "session2" {
                res.statusCode = 200;
                res.setPayload("Sales Order Created");
            } else {
                res.statusCode = 403;
                res.addHeader("X-CSRF-TOKEN", "Required");
            }
        }
        self.postCount = self.postCount + 1;
        return res;
    }

}
