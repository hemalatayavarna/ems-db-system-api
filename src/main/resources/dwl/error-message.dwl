%dw 2.0
output application/json
var errorPayload = payload
---
{
	"error": {
		"systemContext": p('system.context'),
		"payload": errorPayload,
		"dateTimestamp": (now() as DateTime) >> p('property.timezone'),
		"code": (vars.httpStatus default 500) as String,
		"scope": "",
		"message": if ( sizeOf( errorPayload.additionalDetails ) > 1024 ) errorPayload.additionalDetails[0 to 1023] else errorPayload.additionalDetails default "",
		"description": errorPayload.description default "",
		"refId": "",
		"localId": "",
		"SIFObjectName": "",
		"correlationId": correlationId
	}
}