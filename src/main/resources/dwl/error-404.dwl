%dw 2.0
output application/json
---
{
  "code": Mule::p('error.response.code'),
  "description":  Mule::p('http.response.not.found.title'),
  "correlationId": correlationId,
  "additionalDetails": error.description replace /\"/ with ""
}