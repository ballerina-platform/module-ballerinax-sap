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

import ballerina/io;
import ballerina/os;
import ballerinax/googleapis.gmail;
import ballerinax/sap;

configurable string hostname = os:getEnv("HOSTNAME");
configurable string username = os:getEnv("USERNAME");
configurable string password = os:getEnv("PASSWORD");

configurable boolean sendEmail = false;
configurable string refreshToken = os:getEnv("REFRESH_TOKEN");
configurable string clientId = os:getEnv("CLIENT_ID");
configurable string clientSecret = os:getEnv("CLIENT_SECRET");
configurable string recipient = os:getEnv("RECIPIENT");

type Wrapper record {
    SalesOrderList d;
};

type SalesOrderList record {
    SalesOrder[] results;
};

type SalesOrder record {
    string SalesOrder?;
    string? CreatedByUser?;
    string? SalesDocApprovalStatus?;
};

public function main() returns error? {

    // Create sap:Client to access the SAP OData API.
    sap:Client sapClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
        auth: {
            username,
            password
        }
    });

    // Invoke the API
    Wrapper salesOrders = check sapClient->/A_SalesOrder();

    // Filter the sales orders that are in approval status.
    SalesOrder[] salesOrderList = salesOrders.d.results;
    SalesOrder[] remiderSalesOrders = salesOrderList.filter(salesOrder => salesOrder?.SalesDocApprovalStatus == "In Approval");

    // Send reminder email to the customer.
    if sendEmail {
        check sendReminderEmail(remiderSalesOrders);
    } else {
        io:println(string `Pending Sales Orders: ${remiderSalesOrders.length()}`);
        io:println("To send reminder emails, set the 'sendEmail' configuration to 'true'.");
    }
}

function sendReminderEmail(SalesOrder[] remiderSalesOrders) returns error? {

    if remiderSalesOrders.length() == 0 {
        io:println("No pending orders to send reminders.");
        return;
    }

    gmail:Client gmail = check new ({
        auth: {
            refreshToken,
            clientId,
            clientSecret
        }
    });

    string ordersTable = "<table border='1'><tr><th>Sales Order Id</th><th>Created By</th></tr>";
    foreach SalesOrder sOrder in remiderSalesOrders {
        ordersTable += string `<tr><td>${sOrder.SalesOrder ?: ""}</td><td>${sOrder?.CreatedByUser ?: ""}</td></tr>`;
    }
    ordersTable += "</table>";

    // Compose the email message.
    string htmlContent = string `<html>
    <head>
    </head>
    <body>
        <p>Dear Customer,</p>
        <p>This is a gentle reminder regarding the Sales Orders that are still pending approval. 
        We kindly request you to review and approve the following orders at your earliest convenience to avoid any delays in processing.</p>
        <p>${ordersTable}</p>
        <p>We appreciate your prompt attention to this matter.</p>
        <p>Best Regards,</p>
        <p>SAP Admin Team</p>
    </body>
    </html>`;

    gmail:MessageRequest message = {
        to: [recipient],
        subject: "Pending Sales Orders Reminder",
        bodyInHtml: htmlContent
    };

    // Send the email message.
    gmail:Message sendResult = check gmail->/users/me/messages/send.post(message);
    io:println("Email sent. Message ID: " + sendResult.id);
}
