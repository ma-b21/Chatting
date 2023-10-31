IFNDEF UTILS_HEADER
UTILS_HEADER PROTO

include 		masm32rt.inc
include 		ws2_32.inc
includelib 		masm32.lib
includelib 		ws2_32.lib

;=================== STRUCTURE ===================
CLIENT_MSG    	STRUCT
	C_Sign		dd ?
	C_Target   	db 128  dup(0)
	C_Text    	db 8192 dup(0)
CLIENT_MSG 		ENDS

SERVER_MSG 		STRUCT
	S_Sign		dd ?
	S_Text      db 8192 dup(0)
SERVER_MSG 		ENDS

CLIENT 			STRUCT
	Sockfd		dd ?
	UserName    db 128  dup(0)
	IsUsed		dd 0
CLIENT 			ENDS


;===================== MACRRO ======================
;--------------------- C_SIGN ----------------------
C_LOGIN                	equ	800h
C_REGISTER        		equ 801h

;--------------------- S_SIGN ----------------------
S_LOGINOK               equ 802h
S_LOGINREJECT           equ 803h

;===================== CONST =======================
.const
ERR_TITLE               db 'ERROR',0 
SOCKET_ERR          	db 'ERROR When Create Socket!', 0
ERROR_CONNECT           db 'ERROR When Connect To Server!', 0
debug                   db 'DEBUG', 0
printint                db '%d',0
MODE                    dd 1

;==================== Function =====================

CreateSocketForServer		PROTO,
	:DWORD

ConnectSocketForClient       PROTO,
	:DWORD,:PTR BYTE

ENDIF