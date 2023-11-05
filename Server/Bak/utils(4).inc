IFNDEF UTILS_HEADER
UTILS_HEADER PROTO

include 		masm32rt.inc
include 		ws2_32.inc
includelib 		masm32.lib
includelib 		ws2_32.lib

;==================== Function =====================
;----------------------------------------------
; CreateSocketForServer:
;     args1:port:DWORD
;     ret:the listenfd if the socket created and bind successfully,
;		  otherwise return -1
;----------------------------------------------
CreateSocketForServer		PROTO,
	:DWORD

;----------------------------------------------
; CreateSocketForServer:
;     args1:port:DWORD
;	  args2:ip:PTR BYTE
;     ret: the connected socket to ip:port,
;		   otherwise return -1
;----------------------------------------------
ConnectSocketForClient       PROTO,
	:DWORD,:PTR BYTE
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
C_LOGOUT                equ 805h
C_GETFRIEND             equ 810h
C_ADDFRIEND             equ 811h
C_SENDMSG               equ 816h

;--------------------- S_SIGN ----------------------
S_LOGINOK               equ 802h
S_LOGERRPASSWD          equ 803h
S_LOGERRLOGED			equ 804h
S_LOGERRNOUSER          equ 806h
S_REGISTEROK            equ 807h
S_REGERRUSEREXISTS      equ 808h
S_SERVERSTOP            equ 809h
S_ADDERRNOUSER          equ 812h
S_ADDOK					equ 813h
S_ADDFRIENDEXISTS       equ 814h
S_UAREADDED             equ 815h

;===================== CONST =======================
.const
ERR_TITLE               db 'ERROR',0 
SOCKET_ERR          	db 'ERROR When Create Socket!', 0
ERROR_CONNECT           db 'ERROR When Connect To Server!', 0
debug                   db 'DEBUG', 0
printint                db 'num:%d|',0
MODE                    dd 1

ENDIF