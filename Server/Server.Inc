IFNDEF SERVER_HEADER
SERVER_HEADER PROTO

include utils.inc

includelib kernel32.lib
includelib user32.lib
includelib Comctl32.lib
includelib shell32.lib

;=================== FUNCTION ====================
;----------------------------------------------
; DlgProc: Handle the event message
;     args1:hWin:HWND,
;	  args2:uMsg:UINT,
;	  args3:wParam:WPARAM,
;	  args4:lParam:LPARAM
;     ret:0
;----------------------------------------------
DlgProc					PROTO,
	:HWND,:UINT,:WPARAM,:LPARAM

;----------------------------------------------
; StartServer: Start server at 0.0.0.0:port
;     args1:port:DWORD
;     ret:0
;----------------------------------------------
StartServer     		PROTO,
	:DWORD

;----------------------------------------------
; CommunicateWithClient:Listen CLIENT_MSG from Client through connfd 
;     args:connfd:DWORD
;     ret:None
;----------------------------------------------
CommunicateWithClient   PROTO,
	:DWORD	

;----------------------------------------------
; HandleRecvClientMsg:Handle CLIENT_MSG from clinet 
;     args:connfd:DWORD
;     ret:None
;----------------------------------------------
HandleRecvClientMsg     PROTO,
	:DWORD

;----------------------------------------------
; StopServer:Stop server and send message to all clients to close 
;     args:None
;     ret:None
;----------------------------------------------
StopServer 				PROTO

;----------------------------------------------
; FindPassword PROC, 
;	  args1:uname:PTR BYTE, 
;	  args2:password:PTR BYTE
;	  ret:(-1, NO USER NAMED uname)
;         (0, PASSWORD incorrect)
;		  (1, PASSWORD correct)
;----------------------------------------------
FindPassword 			PROTO,
	:PTR BYTE,:PTR BYTE
	
;----------------------------------------------
; FindString:like strstr
;	  args1:sourceString:DWORD, 
;	  args2:searchString:DWORD
;	  ret:(0, searchString not in source String)
;		  (The address of the first occurrence of the searchString in the sourceString )
;----------------------------------------------
FindString 				PROTO,
	:DWORD,:DWORD

;----------------------------------------------
; HandleLogin:handle login message from client through connfd
;	  args1:connfd:DWORD,
;	  args2:msg:PTR CLIENT_MSG
;	  ret:None
;----------------------------------------------
HandleLogin     		PROTO,
	:DWORD,:PTR CLIENT_MSG

;----------------------------------------------
; SendServerResponse:Send response through connfd,With S_sign sign and S_Text text
;	  args1:connfd:DWORD,
;	  args2:sign:DWORD,
;	  args3:text:PTR BYTE
;	  ret:None
;----------------------------------------------
SendServerResponse      PROTO,
	:DWORD,:DWORD,:PTR BYTE

;----------------------------------------------
; HandleLogout:When receive Logout request delete the client in CLIENTLIST
;	  args1:connfd:DWORD,
;	  ret:None
;----------------------------------------------
HandleLogout 			PROTO,
	:DWORD	

;----------------------------------------------
; HandleRegister:handle register message from client through connfd
;	  args1:connfd:DWORD,
;	  args2:msg:PTR CLIENT_MSG
;	  ret:None
;----------------------------------------------
HandleRegister 			PROTO,
	:DWORD,:PTR CLIENT_MSG

;----------------------------------------------
; HandleAddFriend:handle add friend message from client through connfd
;	  args1:connfd:DWORD,
;	  args2:msg:PTR CLIENT_MSG
;	  ret:None
;----------------------------------------------
HandleAddFriend 		PROTO,
	:DWORD,:PTR CLIENT_MSG

;----------------------------------------------
; UpdateClientList:update the CLIENTLIST
;	  args:None
;	  ret:None
;----------------------------------------------
UpdateClientList 		PROTO

;================= MACRO ==================
@LOCK_SHARE_VAR         MACRO
	invoke WaitForSingleObject, hMutex, INFINITE
ENDM

@UNLOCK_SHARE_VAR      	MACRO
	invoke ReleaseMutex, hMutex
ENDM
;=================== CONST ====================
.const
;------------------- SKIN ------------------------
SkinDllName				db	"Skin.dll",0
SkinFuncName			db	"SkinH_AttachEx",0
SkinName				db	"asus.she",0

;------------------ WINDOW -----------------------
IDD_DIALOG1				equ 1100
IDC_LIST            	equ 1101
IDC_BUTTON          	equ 1102

;------------------ BUTTON -----------------------
BTN_UPTEXT              db "STOP SERVER", 0
BTN_DOWNTEXT            db "START SERVER", 0


;------------------ SOCKET -----------------------
DEFAULT_PORT            equ 22910
MAX_CONNECT             equ 100

;------------------- STRING ----------------------
FILE                	db 'USERINFO', 0 ; The user info is like "User:uname|passwd\r\n"
LINEBREAK               db 0dh,0ah, 0
USERFORM                db "User:%s|",0
REGFORM                 db "User:%s|%s",0dh,0ah,0
FRIENDPATH              db '.\\FRIENDS\\%s',0
NEWFRIEND               db '%s,',0
SEARCHFRIEND            db '.\\FRIENDS\\*.*',0   

;==================== DATA =====================
.data
SERVER_STATE           	dd 0
CLIENTLIST 				CLIENT 100 dup(<>)
;------------------- BUFFER -----------------------
READSOCKETBUFFER        db 8192 dup(0)
HD_STRINGBUFFER         db 1024 dup(0)
READFILEBUFFER          db 8192 dup(0)

.data?

hInstance			   	dd ?
dhWnd                  	dd ?
listhWnd               	dd ?
btnhWnd                	dd ?

hMutex             		HANDLE NULL

serverListenfd          dd ?

ENDIF