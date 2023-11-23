include utils.inc

includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
;includelib riched20.lib

;================== FUNCTION ==================

;----------------------------------------------
; MainWin:Create Main Window
;     args1:hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args2:hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args3:CmdLine:LPSTR,CmdShow:DWORD
;     args4:CmdShow:DWORD
;     ret:0 if the window closed successfully
;----------------------------------------------
MainWin						PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; MainWinProc:Handle Main Window Message
;     args1:hWin:HWND,
;     args2:uMsg:UINT,
;     args3:wParam:WPARAM,
;     args4:lParam:LPARAM
;     ret:0 if the message handled successfully
;----------------------------------------------
MainWinProc					PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; Login:Create Login Dialog
;     args1:hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args2:hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
;     args3:CmdLine:LPSTR,CmdShow:DWORD
;     args4:CmdShow:DWORD
;     ret:0 if the window closed successfully
;----------------------------------------------
Login						PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; LoginProc:Handle Login Dialog Message
;     args1:hWin:HWND,
;     args2:uMsg:UINT,
;     args3:wParam:WPARAM,
;     args4:lParam:LPARAM
;     ret:0 if the message handled successfully
;----------------------------------------------
LoginProc					PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; LoginProc:Handle Add Dialog Message
;     args1:hWin:HWND,
;     args2:uMsg:UINT,
;     args3:wParam:WPARAM,
;     args4:lParam:LPARAM
;     ret:0 if the message handled successfully
;----------------------------------------------
AddProc 					PROTO ,
	:DWORD,:DWORD,:DWORD,:DWORD

;----------------------------------------------
; DelFriend:Delete Friend 
;     args:None
;     ret:None
;----------------------------------------------
DelFriend 					PROTO

;----------------------------------------------
; SendRequest:Send request to Server
;     args1:sign:DWORD,
;	  args2:target:PTR BYTE,
;	  args3:text:PTR BYTE
;     ret:0 if the message handled successfully
;----------------------------------------------
SendRequest PROTO,
	:DWORD,:PTR BYTE,:PTR BYTE

;----------------------------------------------
; SendLoginRequest:Send login request to Server
;     args:None
;     ret:1 if login successfully,
;		  otherwise return 0
;----------------------------------------------
SendLoginRequest    		PROTO 

;----------------------------------------------
; SendRegisterRequest:Send register request to Server
;     args:None
;     ret:1 if register successfully,
;		  otherwise return 0
;----------------------------------------------
SendRegisterRequest 		PROTO

;----------------------------------------------
; CommunicateWithServer:Listen SERVER_MSG from server 
;     args:None
;     ret:None
;----------------------------------------------
CommunicateWithServer   	PROTO

;----------------------------------------------
; HandleRecvServerMsg:Handle SERVER_MSG from server 
;     args:None
;     ret:None
;----------------------------------------------
HandleRecvServerMsg      	PROTO

;----------------------------------------------
; UpdateFriendList:Get friendlist from server 
;     args:None
;     ret:None
;----------------------------------------------
UpdateFriendList			PROTO

;----------------------------------------------
; GetChatHistory:Get chat history from server 
;     args:None
;     ret:None
;----------------------------------------------
GetChatHistory 				PROTO

;----------------------------------------------
; UpdateChatHistory:Update chat history in chatbox 
;     args:msg:PTR BYTE
;     ret:None
;----------------------------------------------
UpdateChatHistory 			PROTO,
	:PTR BYTE

;----------------------------------------------
; ChooseFile:choose file to send
;     args:send file target
;     ret:None
;----------------------------------------------
ChooseFile					PROTO,
	:PTR BYTE

;----------------------------------------------
; SendFile:send the file chFileName
;     args:None
;     ret:None
;----------------------------------------------
SendFile					PROTO

;----------------------------------------------
; ReceiveFile:send the file chFileName
;     args:None
;     ret:None
;----------------------------------------------
ReceiveFile					PROTO

;==================	MACRO =================
IDD_LOGIN			equ 1000
IDC_LUNAME          equ 1002
IDC_LPASSWD         equ 1005
IDC_LOGINBUTTON     equ 1006
IDC_REGBUTTON       equ 1007
IDC_IPADDRESS		equ 1019 

IDD_MAIN            equ 1001
IDC_MCHATBOX        equ 1008
IDC_MSENDBOX        equ 1009
IDC_MSENDBTN        equ 1010
IDC_MFRIENDLIST     equ 1011
IDC_MADDFRIENDBTN   equ 1012
IDC_MDELFRIENDBTN	equ 1020
IDC_MFILEBTN		equ 1021

IDD_ADD             equ 1013
IDC_FRIENDNAME      equ 1015
IDC_ADDBTN          equ 1016

ID_TIMER            equ 1017
IDI_ICON            equ 1018

lower               equ 65535     ; 0xFFFF
higher              equ 4294901760; 0xFFFF0000


DEFAULT_PORT        equ 22910

;================== MACRO ==================
@ConnectServerIfNoConnection  MACRO
	.IF connfd == -1
		invoke ConnectSocketForClient,DEFAULT_PORT, ADDR DEFAULT_IP
		mov connfd,eax
	.ENDIF
ENDM

@CloseSocket	MACRO
	invoke closesocket,connfd
	mov connfd,-1
ENDM

@MAKEIPADDRESS MACRO a, b, c, d
    mov eax, a
    shl eax, 24
    mov ecx, b
    shl ecx, 16
    or eax, ecx
    mov ecx, c
    shl ecx, 8
    or eax, ecx
    mov ecx, d
    or eax, ecx
ENDM

@SetServerIP  MACRO
	
	invoke SendMessage,IPhWnd,IPM_GETADDRESS,0,ADDR ipAddress
	
	mov eax, ipAddress
    movzx ebx, al
    movzx ecx, ah
    shr eax, 16
    movzx edx, al
    movzx esi, ah
	
	invoke wsprintf, ADDR DEFAULT_IP,ADDR ipFormat,esi, edx, ecx, ebx
	
ENDM

.const
;------------------ FILE ------------------------
operation				db  "open",0
filePath				db  "file",0
fileBreak				db  "\",0
fileTitle				db  "Select a file",0
fileFilter 				db  "All Files (*.*)", 0, "*.*", 0, 
							"Text Files (*.txt)", 0, "*.txt", 0, 
            				"Image Files (*.jpg;*.jpeg;*.png)", 0, "*.jpg;*.jpeg;*.png", 0,
            				"Document Files (*.doc;*.docx;*.pdf)", 0, "*.doc;*.docx;*.pdf", 0,
            				0
fileRead				db  "rb",0
            
;------------------ SKIN ------------------------
SkinDllName				db	"Skin.dll",0
SkinFuncName			db	"SkinH_AttachEx",0
SkinName				db	"asus.she",0

;------------------- DLL ------------------------
RichEditDll				db	"RichEd20.dll",0

;------------------ WINDOW ----------------------
LoginClassName			db 'LOGINCLASS',0
MainClassName           db 'MAINWINCLASS',0
dlgName					db 'Login',0
mainName                db 'Client',0

;-------------------- IP ------------------------
ipFormat				db '%d.%d.%d.%d',0

;------------------- TIPS -----------------------
TP_ALREADYLOGIN			db 'The user is already login!',0
TP_REGISTERED           db 'The user is already registered, please login!', 0
TP_WRONGPASSWD     		db 'Wrong password! Please retry!',0
TP_REGISTERSUCCESS      db 'Register Success! Please Login!', 0
TP_LOGINFAILED          db 'Login Failed, Please register first!', 0
TP_SERVERSTOP           db 'The Server Stop, Client will close!',0
TP_UNAMEBLANK           db 'The Username Cannot be Blank!',0
TP_PASSWDBLANK          db 'The Password Cannot be Blank!',0
TP_ADDUSERNOTEXISTS     db 'The user you search does not exists!',0
TP_ADDSUCCESS           db 'Add Friend Success',0
TP_CANTADDSELF          db 'You cannot add yourself as a friend',0
TP_FRIENDEXISTS         db 'That friend is already exists',0
TP_DELSUCCESS			db 'Delete Friend Success',0
TP_NULL                 db 0,0
TP_FILENOTEXIST			db 'The file is not exists',0
.data

hInstance				dd ?      		 	;handle of process
hRichEditDll            dd ?     		  	;dll handle
CommandLine				dd ?     		  	;command handle
	
LoginhWnd				dd ?      		 	;login window handle
UserhWnd                dd ?      		 	;username input
PasshWnd                dd ?				;password input
IPhWnd					dd ?				;IPADDRESS

MainhWnd                dd ?				;main window handle
chathWnd                dd ?  				;chat history box handle
sendhWnd				dd ?				;send box handle
sendBtnhWnd				dd ?				;send button handle
listhWnd				dd ?				;friend list handle
addBtnhWnd 				dd ?				;add friend button handle

AddhWnd					dd ?				;add window handle
frNamehWnd              dd ?				;friend name input
addSearchhWnd           dd ?				;add button handle

ipAddress               dd ?
chFileName				db 256 dup(?)

connfd 					dd -1				;connect socket
LOGINFLAG               dd 0				;if login open main window
UserName                db 128 dup(0), 0
PassWord                db 128 dup(0), 0

;------------------ BUFFER ----------------------
textBuffer              db 8192 dup(0), 0
CurrentDir				db 256 dup(0), 0
fileFormat				db "%s\%s",0

;------------------ SOCKET ---------------------- 
DEFAULT_IP              db 20 dup(0)