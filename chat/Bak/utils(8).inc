IFNDEF UTILS_HEADER
UTILS_HEADER PROTO

include 		masm32rt.inc
include 		ws2_32.inc
includelib 		masm32.lib
includelib 		ws2_32.lib

;=================== STRUCTURE ===================


.const
ERR_TITLE               db 'ERROR',0 
SOCKET_ERR          	db 'ERROR When Create Socket!', 0
ERROR_CONNECT           db 'ERROR When Connect To Server!', 0
debug                   db 'DEBUG', 0
MODE                    dd 1

;==================== Function ====================

CreateSocketForServer		PROTO,
	:DWORD

ConnectSocketForClient       PROTO,
	:DWORD,:PTR BYTE

ENDIF