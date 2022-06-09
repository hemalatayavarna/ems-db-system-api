%dw 2.0
output application/json
---
{
  "code": Mule::p('error.response.code'),
  "description": Mule::p('http.response.internal.server.title'),
  "correlationId":correlationId,
  "additionalDetails": error.description replace /\"/ with ""
}