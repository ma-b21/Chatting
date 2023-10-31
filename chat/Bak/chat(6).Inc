include utils.inc

includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib riched20.lib

;================== FUNCTION ==================

;----------------------------------------------
; MainWin:Create Main Window
;     args1:hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args2:hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args3:CmdLine:LPSTR,CmdShow:DWORD
;     args4:CmdShow:DWORD
;     ret:0 if the window closed successfully
;----------------------------------------------
MainWin				PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; MainWinProc:Handle Main Window Message
;     args1:hWin:HWND,
;     args2:uMsg:UINT,
;     args3:wParam:WPARAM,
;     args4:lParam:LPARAM
;     ret:0 if the message handled successfully
;----------------------------------------------
MainWinProc			PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; Login:Create Login Dialog
;     args1:hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args2:hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args3:CmdLine:LPSTR,CmdShow:DWORD
;     args4:CmdShow:DWORD
;     ret:0 if the window closed successfully
;----------------------------------------------
Login				PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; LoginProc:Handle Login Dialog Message
;     args1:hWin:HWND,
;     args2:uMsg:UINT,
;     args3:wParam:WPARAM,
;     args4:lParam:LPARAM
;     ret:0 if the message handled successfully
;----------------------------------------------
LoginProc			PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

SendRequest PROTO,
	:DWORD,:PTR BYTE,:PTR BYTE

SendLoginRequest    PROTO 

	
;==================	MACRO =================
IDD_LOGIN			equ 1000
IDC_LUNAME          equ 1002
IDC_LPASSWD         equ 1005
IDC_LOGINBUTTON     equ 1006
IDC_REGBUTTON       equ 1007 

IDD_MAIN            equ 1001

lower               equ 65535     ; 0xFFFF
higher              equ 4294901760; 0xFFFF0000


DEFAULT_PORT        equ 22910

.const
;------------------ SKIN ------------------------
SkinDllName				db	"Skin.dll",0
SkinFuncName			db	"SkinH_AttachEx",0
SkinName				db	"asus.she",0

;------------------- DLL ------------------------
RichEditDll				db	"RichEd20.dll",0
VideoDll                db  "quartz.dll",0

;------------------ WINDOW ----------------------
LoginClassName			db 'LOGINCLASS',0
MainClassName           db 'MAINWINCLASS',0
dlgName					db 'Login',0

;------------------ STRING ----------------------
INFOPREFIX              db 'User:',0        
FILE                	db 'USERINFO', 0 ; The user info is like "User:uname|passwd\r\n"
CONNECTOR               db '|', 0
LINEBREAK               db 0dh,0ah, 0

;------------------ SOCKET ---------------------- 
DEFAULT_IP              db '127.0.0.1', 0

;------------------- TIPS -----------------------
TP_ALREADYLOGIN			db 'The user is already login!',0
TP_REGISTERED           db 'The user is already registered, please login!', 0
TP_WRONGPASSWD     		db 'Wrong password!Please retry!',0
TP_REGISTERFAILED       db 'Fail to register for the user!', 0
TP_REGISTERSUCCESS      db 'Register Success!', 0
TP_LOGINFAILED          db 'Login Failed, Please register first!', 0

.data

hInstance				dd ?
hRichEditDll            dd ?
CommandLine				dd ?

LoginhWnd				dd ?
UserhWnd                dd ?
PasshWnd                dd ?
MainhWnd                dd ?


connfd 					dd ?
LOGINFLAG               dd 0
ReadBuffer              db 1024 dup(0), 0
WriteBuffer             db 1024 dup(0), 0
UserName                db 128 dup(0), 0
PassWord                db 128 dup(0), 0

errcode                 dd ?
errmessage              db 128 dup(0)