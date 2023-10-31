IFNDEF SERVER_HEADER
SERVER_HEADER PROTO

include utils.inc

includelib kernel32.lib
includelib user32.lib
includelib Comctl32.lib
includelib shell32.lib

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

;------------------- BUFFER -----------------------
USERFORM                db "User:%s|",0

;------------------ SOCKET -----------------------
DEFAULT_PORT            equ 22910
MAX_CONNECT             equ 100

;------------------- STRING ----------------------
FILE                	db 'USERINFO', 0 ; The user info is like "User:uname|passwd\r\n"
LINEBREAK               db 0dh,0ah, 0


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

hclientList             dd ?

serverListenfd          dd ?

;=================== FUNCTION ====================

DlgProc					PROTO,
	:HWND,:UINT,:WPARAM,:LPARAM

StartServer     		PROTO,
	:DWORD

CommunicateWithClient   PROTO,
	:DWORD	

HandleRecvClientMsg           PROTO,
	:DWORD

StopServer 				PROTO

FindPassword 			PROTO,
	:PTR BYTE,:PTR BYTE

FindString 				PROTO,
	:DWORD,:DWORD
	
HandleLogin     		PROTO,
	:DWORD,:PTR CLIENT_MSG

SendServerResponse      PROTO,
	:DWORD,:DWORD,:PTR BYTE
	
UpdateClientList 		PROTO
ENDIF