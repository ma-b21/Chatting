.386
.model flat,stdcall
option casemap:none

include chat.inc

.code
Main PROC
	invoke GetModuleHandle,NULL
	mov    hInstance,eax
	invoke GetCommandLine
	invoke InitCommonControls
	mov	   CommandLine,eax
	invoke LoadLibrary, offset RichEditDll
	mov hRichEditDll, eax
	
	invoke Login,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
	.IF LOGINFLAG != 0
		invoke MainWin,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
	.ENDIF
	invoke ExitProcess,eax
	ret
Main ENDP

MainWin PROC,
	hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	
	;Local variable, store window structure and msg structure 
	LOCAL	@wc:WNDCLASSEX
	LOCAL	@msg:MSG

	;init the window
	mov		@wc.cbSize,sizeof WNDCLASSEX
	mov		@wc.style,CS_HREDRAW or CS_VREDRAW
	mov		@wc.lpfnWndProc,OFFSET MainWinProc
	mov		@wc.cbClsExtra,NULL
	mov		@wc.cbWndExtra,DLGWINDOWEXTRA
	push	hInst
	pop		@wc.hInstance
	mov		@wc.hbrBackground,COLOR_BTNFACE+1
	mov		@wc.lpszClassName,OFFSET MainClassName
	invoke LoadIcon,NULL,IDI_APPLICATION
	mov		@wc.hIcon,eax
	mov		@wc.hIconSm,eax
	invoke LoadCursor,NULL,IDC_ARROW
	mov		@wc.hCursor,eax
	invoke RegisterClassEx,ADDR @wc
	invoke CreateDialogParam,hInstance,IDD_MAIN,NULL,ADDR MainWinProc,NULL
	invoke ShowWindow,MainhWnd,SW_SHOWNORMAL
	invoke UpdateWindow,MainhWnd
	
	;Disallow window size changes
	invoke GetWindowLong,MainhWnd,GWL_STYLE
	xor eax, WS_MAXIMIZEBOX
	xor eax, WS_SIZEBOX
	invoke SetWindowLong,MainhWnd, GWL_STYLE, eax
	
	;Message Loop
	.while TRUE
		invoke GetMessage,ADDR @msg,NULL,0,0
	  .BREAK .IF !eax
		invoke TranslateMessage,ADDR @msg
		invoke DispatchMessage,ADDR @msg
	.endw
	mov		eax,@msg.wParam
	ret

MainWin ENDP

MainWinProc PROC,
	hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	
	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		push	hWin
		pop		MainhWnd
		
		invoke LoadLibrary, offset SkinDllName
		invoke GetProcAddress, eax, offset SkinFuncName
		push NULL
		push offset SkinName
		call eax
	.ELSEIF eax==WM_CLOSE
		invoke SendRequest,C_LOGOUT,NULL,NULL
		invoke closesocket,connfd
		invoke DestroyWindow,hWin
	.ELSEIF uMsg==WM_DESTROY
		invoke PostQuitMessage,NULL
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

MainWinProc ENDP

Login PROC ,
	hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	
	;Local variable, store window structure and msg structure 
	LOCAL	@wc:WNDCLASSEX
	LOCAL	@msg:MSG

	;init the login window
	mov		@wc.cbSize,sizeof WNDCLASSEX
	mov		@wc.style,CS_HREDRAW or CS_VREDRAW
	mov		@wc.lpfnWndProc,OFFSET LoginProc
	mov		@wc.cbClsExtra,NULL
	mov		@wc.cbWndExtra,DLGWINDOWEXTRA
	push	hInst
	pop		@wc.hInstance
	mov		@wc.hbrBackground,COLOR_BTNFACE+1
	mov		@wc.lpszClassName,OFFSET LoginClassName
	invoke LoadIcon,NULL,IDI_APPLICATION
	mov		@wc.hIcon,eax
	mov		@wc.hIconSm,eax
	invoke LoadCursor,NULL,IDC_ARROW
	mov		@wc.hCursor,eax
	invoke RegisterClassEx,addr @wc
	invoke CreateDialogParam,hInstance,IDD_LOGIN,NULL,addr LoginProc,NULL
	invoke ShowWindow,LoginhWnd,SW_SHOWNORMAL
	invoke UpdateWindow,LoginhWnd
	
	;Disallow window size changes
	invoke GetWindowLong,LoginhWnd,GWL_STYLE
	xor eax, WS_MAXIMIZEBOX
	xor eax, WS_SIZEBOX
	invoke SetWindowLong,LoginhWnd, GWL_STYLE, eax
	;Message Loop
	.while TRUE
		invoke GetMessage,addr @msg,NULL,0,0
	  .BREAK .IF !eax
		invoke TranslateMessage,addr @msg
		invoke DispatchMessage,addr @msg
	.endw
	mov		eax,@msg.wParam
	ret

Login ENDP

LoginProc PROC uses ebx,
    hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	
	LOCAL @fileHandle:DWORD
	LOCAL @writeBytes:DWORD
	LOCAL @passwd[128]:BYTE
	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		push	hWin
		pop		LoginhWnd
		
		invoke LoadLibrary, offset SkinDllName
		invoke GetProcAddress, eax, offset SkinFuncName
		push NULL
		push offset SkinName
		call eax
		
		invoke GetDlgItem,LoginhWnd,IDC_LUNAME
		mov UserhWnd, eax
		invoke GetDlgItem,LoginhWnd,IDC_LPASSWD
		mov PasshWnd, eax
	.ELSEIF eax == WM_COMMAND
		
		mov eax, wParam
		.IF eax == IDC_LOGINBUTTON
		
			invoke ConnectSocketForClient,DEFAULT_PORT, ADDR DEFAULT_IP
			mov connfd,eax
			invoke SendLoginRequest
			.IF eax == 1
				inc LOGINFLAG
				invoke DestroyWindow,hWin
				invoke PostQuitMessage,NULL
			.ENDIF
			
		.ELSEIF eax == IDC_REGBUTTON
		
			
			
		.ENDIF
		
	.ELSEIF eax==WM_CLOSE
		invoke DestroyWindow,hWin
	.ELSEIF eax==WM_DESTROY
		invoke PostQuitMessage,NULL
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

LoginProc ENDP

SendRequest PROC,sign:DWORD,target:PTR BYTE,text:PTR BYTE

	LOCAL @msg:CLIENT_MSG
	
	push sign
	pop @msg.C_Sign
	
	invoke lstrcpy,ADDR @msg.C_Target,target
	invoke lstrcpy,ADDR @msg.C_Text,text
	
	invoke send,connfd,ADDR @msg,TYPE CLIENT_MSG,0
	ret

SendRequest ENDP

SendLoginRequest  PROC
	
	LOCAL @login_msg:CLIENT_MSG
	LOCAL @recv_msg:SERVER_MSG
	
	mov @login_msg.C_Sign, C_LOGIN
	invoke SendMessage,UserhWnd,WM_GETTEXT,128,ADDR @login_msg.C_Target
	invoke SendMessage,PasshWnd,WM_GETTEXT,128,ADDR @login_msg.C_Text
	
	invoke send,connfd,ADDR @login_msg,SIZEOF @login_msg,0
	invoke recv,connfd,ADDR @recv_msg,SIZEOF @recv_msg,0
	.IF @recv_msg.S_Sign == S_LOGINOK
		mov eax,1
	.ELSEIF @recv_msg.S_Sign == S_LOGERRLOGED
		invoke MessageBox,LoginhWnd,OFFSET TP_ALREADYLOGIN,OFFSET dlgName,MB_OK
		mov eax,0
	.ELSEIF @recv_msg.S_Sign == S_LOGERRPASSWD
		invoke MessageBox,LoginhWnd,OFFSET TP_WRONGPASSWD,OFFSET dlgName,MB_OK
		mov eax,0
	.ELSEIF @recv_msg.S_Sign == S_LOGERRNOUSER
		invoke MessageBox,LoginhWnd,OFFSET TP_LOGINFAILED,OFFSET dlgName,MB_OK
		mov eax,0
	.ENDIF
	ret

SendLoginRequest ENDP

SendRegisterRequest PROC
	
	LOCAL @reg_msg:CLIENT_MSG
	LOCAL @recv_msg:SERVER_MSG
	
	mov @reg_msg.C_Sign, C_REGISTER
	invoke SendMessage,UserhWnd,WM_GETTEXT,128,ADDR @reg_msg.C_Target
	invoke SendMessage,PasshWnd,WM_GETTEXT,128,ADDR @reg_msg.C_Text
	
	invoke send,connfd,ADDR @reg_msg,SIZEOF @reg_msg,0
	invoke recv,connfd,ADDR @recv_msg,SIZEOF @recv_msg,0
	.IF @recv_msg.S_Sign == S_REGISTEROK
		invoke MessageBox,LoginhWnd,OFFSET TP_REGISTERSUCCESS,OFFSET dlgName,MB_OK
		mov eax,1
	.ELSEIF @recv_msg.S_Sign == S_REGERRUSEREXISTS
		invoke MessageBox,LoginhWnd,OFFSET TP_REGISTERED,OFFSET dlgName,MB_OK
		mov eax,0
	.ENDIF
	ret
	ret

SendRegisterRequest ENDP
end Main
