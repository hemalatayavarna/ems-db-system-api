%dw 2.0
output application/json
---
{
  "code": Mule::p('error.response.code'),
  "description": error.description replace /\"/ with "",
  "correlationId": correlationId,
  "additionalDetails": error.errorMessage.payload default ""
}