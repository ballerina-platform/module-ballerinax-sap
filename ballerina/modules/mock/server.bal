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

    int tokenVersion = 0;
    boolean rejectNextPost = false;

    resource function head .() returns http:Response {
        http:Response res = new;
        self.tokenVersion = self.tokenVersion + 1;
        string token = string `token${self.tokenVersion}`;
        res.setHeader("X-CSRF-TOKEN", token);
        http:Cookie cookie = new http:Cookie("session", string `session${self.tokenVersion}`, {path: "/"});
        res.addCookie(cookie);
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
        http:Response res = new;
        if self.rejectNextPost {
            self.rejectNextPost = false;
            res.statusCode = 403;
            res.addHeader("X-CSRF-TOKEN", "Required");
        } else {
            res.statusCode = 200;
            res.setPayload("Sales Order Created");
        }
        return res;
    }

    resource function post triggerTokenExpiry(http:Request req) returns http:Response {
        self.rejectNextPost = true;
        http:Response res = new;
        res.statusCode = 200;
        return res;
    }

}
