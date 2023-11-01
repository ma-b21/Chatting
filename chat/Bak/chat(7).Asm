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

MainWin PROC, hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	
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

MainWinProc PROC,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	
	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		;get window handle
		push	hWin
		pop		MainhWnd
		
		;load skin
		invoke LoadLibrary, offset SkinDllName
		invoke GetProcAddress, eax, offset SkinFuncName
		push NULL
		push offset SkinName
		call eax
		
		;get module handle
		invoke GetDlgItem,MainhWnd,IDC_MCHATBOX
		mov chathWnd, eax
		invoke GetDlgItem,MainhWnd,IDC_MSENDBOX
		mov sendhWnd, eax
		invoke GetDlgItem,MainhWnd,IDC_MSENDBTN
		mov sendBtnhWnd, eax
		invoke GetDlgItem,MainhWnd,IDC_MFRIENDLIST
		mov listhWnd, eax
		invoke GetDlgItem,MainhWnd,IDC_MADDFRIENDBTN
		mov addBtnhWnd, eax
		
		;get friend list
		invoke UpdateFriendList
		invoke CreateThread,NULL,0,OFFSET CommunicateWithServer,NULL,0,NULL
	.ELSEIF eax == WM_COMMAND
		mov eax,wParam
		
		.IF eax == IDC_MADDFRIENDBTN
			invoke InitCommonControls
			invoke DialogBoxParam,hInstance,IDD_ADD,NULL,OFFSET AddProc,NULL
		.ENDIF
		
	.ELSEIF eax == WM_CLOSE
		invoke SendRequest,C_LOGOUT,NULL,NULL
		invoke DestroyWindow,hWin
		invoke PostQuitMessage,NULL
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

MainWinProc ENDP

Login PROC ,hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	
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

LoginProc PROC uses ebx,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
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
			@ConnectServerIfNoConnection
			mov eax,0
			.IF connfd != -1
				invoke SendLoginRequest
			.ENDIF
			.IF eax == 1
				inc LOGINFLAG
				invoke DestroyWindow,hWin
				invoke PostQuitMessage,0
			.ENDIF
			
		.ELSEIF eax == IDC_REGBUTTON
			@ConnectServerIfNoConnection
			.IF connfd != -1
				invoke SendRegisterRequest
			.ENDIF
			
		.ENDIF
		
	.ELSEIF eax==WM_CLOSE
		invoke DestroyWindow,hWin
		invoke PostQuitMessage,NULL
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

LoginProc ENDP

AddProc PROC uses ebx,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		push	hWin
		pop		AddhWnd
		
		invoke GetDlgItem,AddhWnd,IDC_FRIENDNAME
		mov frNamehWnd, eax
		invoke GetDlgItem,AddhWnd,IDC_ADDBTN
		mov addSearchhWnd, eax
		
	.ELSEIF eax == WM_COMMAND
		
	.ELSEIF eax==WM_CLOSE
		invoke DestroyWindow,hWin
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

AddProc ENDP

SendRequest PROC,sign:DWORD,target:PTR BYTE,text:PTR BYTE

	LOCAL @msg:CLIENT_MSG
	
	push sign
	pop @msg.C_Sign
	
	invoke lstrcpy,ADDR @msg.C_Target,target
	invoke lstrcpy,ADDR @msg.C_Text,text
	
	invoke send,connfd,ADDR @msg,TYPE CLIENT_MSG,0
	.IF eax == -1
	.endif
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
		invoke lstrcpy,OFFSET UserName,ADDR @login_msg.C_Target
		invoke lstrcpy,OFFSET PassWord,ADDR @login_msg.C_Text
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

SendRegisterRequest ENDP

CommunicateWithServer   PROC

	LOCAL @sockfdSet:fd_set
	LOCAL @timeout: timeval
	LOCAL @bytesAvailable:DWORD
	
	invoke crt_memcpy,ADDR @sockfdSet.fd_array,ADDR connfd,TYPE DWORD
	mov    @sockfdSet.fd_count, 1
    mov    @timeout.tv_sec, 0
    mov    @timeout.tv_usec, 200*1000
	
	.WHILE TRUE
		.IF connfd == -1
			.BREAK
		.ENDIF
		invoke select, 0, ADDR @sockfdSet, NULL, NULL, ADDR @timeout
        .IF eax == 0
            .CONTINUE
        .ENDIF
        
        invoke HandleRecvServerMsg
	.ENDW
	
	@CloseSocket
	ret

CommunicateWithServer ENDP

HandleRecvServerMsg  PROC
	
	LOCAL @server_msg:SERVER_MSG
	
	invoke recv, connfd, ADDR @server_msg, SIZEOF @server_msg, 0
	.IF eax != SOCKET_ERROR 
		.IF @server_msg.S_Sign == S_SERVERSTOP
			invoke MessageBox,MainhWnd,OFFSET TP_SERVERSTOP,OFFSET mainName,MB_OK
			invoke SendMessage,MainhWnd,WM_CLOSE,NULL,NULL
			invoke SendMessage,MainhWnd,WM_DESTROY,NULL,NULL
		.ENDIF
	.ENDIF
	ret

HandleRecvServerMsg ENDP

UpdateFriendList PROC
	
	LOCAL @friend_msg:CLIENT_MSG
	LOCAL @recv_msg:SERVER_MSG
	LOCAL @dataLen:DWORD
	LOCAL @friendName[128]:BYTE
	
	mov @dataLen,0
	
	mov @friend_msg.C_Sign, C_GETFRIEND
	invoke lstrcpy,ADDR @friend_msg.C_Target,OFFSET UserName
	
	invoke send,connfd,ADDR @friend_msg,SIZEOF @friend_msg,0
	invoke recv,connfd,ADDR @recv_msg,SIZEOF @recv_msg,0
	
	invoke lstrlen,ADDR @recv_msg.S_Text
	mov @dataLen,eax
	
	mov ecx,0
	lea esi,@recv_msg.S_Text
	mov edi,esi
	mov edx,0
	ASSUME esi:PTR BYTE
	.WHILE ecx < @dataLen
		.IF [esi] == ','
			push ecx
			push edx
			push esi
			push edi
				mov [esi],0
				invoke lstrcpy,ADDR @friendName,edi
				invoke SendMessage,listhWnd,LB_ADDSTRING,0,ADDR @friendName
			pop edi
			pop esi
			pop edx
			pop ecx
			mov edx,-1
			mov edi,esi
			add edi,TYPE BYTE

		.ENDIF
		inc ecx
		inc edx
		add esi,TYPE BYTE
	.ENDW
	
	ret

UpdateFriendList ENDP

end Main
