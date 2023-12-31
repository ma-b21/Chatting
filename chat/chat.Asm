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
	invoke GetModuleFileName,NULL,OFFSET CurrentDir,256
	invoke PathRemoveFileSpec,OFFSET CurrentDir
	
	invoke CreateDirectory,OFFSET filePath,NULL
	invoke lstrcat,OFFSET CurrentDir,OFFSET fileBreak
	invoke lstrcat,OFFSET CurrentDir,OFFSET filePath
	
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
	
	LOCAL @selectItem:DWORD
	LOCAL @targetName[128]:BYTE
	LOCAL @hicon:HICON
	
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
	
		;load icon
		invoke LoadIcon,hInstance,IDI_ICON
		mov @hicon,eax
		invoke SendMessage,hWin,WM_SETICON,ICON_BIG,@hicon
		invoke SendMessage,hWin,WM_SETICON,ICON_SMALL,@hicon
		
		;set richedit
		invoke SendMessage,chathWnd,EM_SETEVENTMASK,0,ENM_LINK
		invoke SendMessage,chathWnd,EM_AUTOURLDETECT,TRUE,0
		
	.ELSEIF eax == WM_COMMAND
		mov eax,wParam
		and eax,lower
		
		.IF eax == IDC_MADDFRIENDBTN
			invoke InitCommonControls
			invoke DialogBoxParam,hInstance,IDD_ADD,NULL,OFFSET AddProc,NULL
		.ELSEIF eax == IDC_MDELFRIENDBTN
			invoke DelFriend
		.ELSEIF eax == IDC_MSENDBTN
			invoke SendMessage,listhWnd,LB_GETCURSEL,0,0
			.IF eax == LB_ERR
				xor eax, eax
				ret
			.ENDIF
			mov @selectItem,eax
			invoke SendMessage,listhWnd,LB_GETTEXT,@selectItem,ADDR @targetName
			invoke SendMessage,sendhWnd,WM_GETTEXT,8192,OFFSET textBuffer
			
			invoke SendRequest,C_SENDMSG,ADDR @targetName,OFFSET textBuffer
			invoke Sleep,50
			
			invoke SendRequest,C_GETHISTORY,OFFSET UserName,ADDR @targetName
			invoke SendMessage,sendhWnd,WM_SETTEXT,0,OFFSET TP_NULL
		.ELSEIF eax == IDC_MFRIENDLIST
			mov eax,wParam
			and eax,higher
			shr eax,16
			.IF eax == LBN_SELCHANGE
				invoke GetChatHistory
			.ENDIF
		
		.ELSEIF eax == IDC_MFILEBTN
			invoke SendMessage,listhWnd,LB_GETCURSEL,0,0
			.IF eax == LB_ERR
				xor eax, eax
				ret
			.ENDIF
			mov @selectItem,eax
			invoke SendMessage,listhWnd,LB_GETTEXT,@selectItem,ADDR @targetName
			
			invoke ChooseFile,ADDR @targetName
		.ENDIF
	
	.ELSEIF eax == WM_NOTIFY
		mov eax,wParam
		and eax,lower
		mov esi,lParam
        assume esi:ptr NMHDR
        .IF eax == IDC_MCHATBOX && [esi].code == EN_LINK
            ; RichEdit 控件接收到 EN_LINK 消息
            ; 处理链接点击事件
            mov esi, lParam
            assume esi:ptr ENLINK
            .IF [esi].msg == WM_LBUTTONDOWN
            	invoke SendMessage,chathWnd,EM_SETSEL,[esi].chrg.cpMin,[esi].chrg.cpMax
            	; 链接被点击
            	mov ebx, [esi].chrg.cpMin ; 获取链接起始位置
            	mov edx, [esi].chrg.cpMax ; 获取链接结束位置
            	sub edx, ebx ; 计算链接长度
				inc edx
            	; 分配内存保存链接文本
            	invoke GlobalAlloc, GMEM_FIXED, edx ; 加 1 是为了 null 终止符
            	mov edi, eax
            	
            	
            	.IF edi != NULL
                	; 获取链接文本
                	invoke SendMessage, chathWnd, EM_GETSELTEXT, 0, edi
                	; 设置 null 终止符
                	mov BYTE PTR [edi + edx], 0

                	; 此时 edi 指向包含链接文本的内存块
                	; 可以在这里处理链接文本
                	add edi,7
                	
                	invoke wsprintf,OFFSET textBuffer,OFFSET fileFormat,OFFSET CurrentDir,edi
                	
					invoke ShellExecute,NULL,OFFSET operation,OFFSET textBuffer,0,0,SW_SHOWNORMAL
    				.IF eax <= 32
    					invoke MessageBox,MainhWnd,OFFSET TP_FILENOTEXIST,OFFSET mainName,MB_OK
    				.ENDIF

                ; 释放分配的内存
                invoke GlobalFree, edi
            	invoke SendMessage,chathWnd,EM_SETSEL,-1,-1
            .ENDIF

            
                ; 链接被点击
                ;
            .ENDIF
            assume esi:nothing
        .ENDIF
        assume esi:nothing
	
	.ELSEIF eax == WM_CLOSE
		;invoke KillTimer,MainhWnd,ID_TIMER
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

	LOCAL @hicon:HICON
	LOCAL @temp:DWORD
	LOCAL @ipAddress:DWORD
	
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
		invoke GetDlgItem,LoginhWnd,IDC_IPADDRESS
		mov IPhWnd, eax
		
		;set default ip
		@MAKEIPADDRESS 127,0,0,1
		mov @temp,eax
		invoke SendMessage,IPhWnd,IPM_SETADDRESS,0,@temp
		
		;load icon
		invoke LoadIcon,hInstance,IDI_ICON
		mov @hicon,eax
		invoke SendMessage,hWin,WM_SETICON,ICON_BIG,@hicon
		invoke SendMessage,hWin,WM_SETICON,ICON_SMALL,@hicon
		
		;set richedit
		invoke SendMessage,chathWnd,EM_SETEVENTMASK,0,ENM_LINK
		invoke SendMessage,chathWnd,EM_AUTOURLDETECT,TRUE,NULL
		
	.ELSEIF eax == WM_COMMAND
		
		mov eax, wParam
		.IF eax == IDC_LOGINBUTTON
			@SetServerIP
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
			@SetServerIP
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

	LOCAL @FriendName[128]:BYTE

	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		push	hWin
		pop		AddhWnd
		
		invoke GetDlgItem,AddhWnd,IDC_FRIENDNAME
		mov frNamehWnd, eax
		invoke GetDlgItem,AddhWnd,IDC_ADDBTN
		mov addSearchhWnd, eax
		
		;load skin
		invoke LoadLibrary, offset SkinDllName
		invoke GetProcAddress, eax, offset SkinFuncName
		push NULL
		push offset SkinName
		call eax
		
	.ELSEIF eax == WM_COMMAND
		mov eax,wParam
		.IF eax == IDC_ADDBTN
			invoke SendMessage,frNamehWnd,WM_GETTEXT,128,ADDR @FriendName
			invoke lstrcmp,OFFSET UserName,ADDR @FriendName
			.IF eax == 0
				invoke DestroyWindow,hWin
				invoke MessageBox,MainhWnd,OFFSET TP_CANTADDSELF,OFFSET mainName,MB_OK or MB_APPLMODAL
				invoke SendMessage,MainhWnd,WM_COMMAND,IDC_MADDFRIENDBTN,0
				xor eax,eax
				ret
			.ENDIF
			invoke SendRequest,C_ADDFRIEND,OFFSET UserName,ADDR @FriendName
			invoke DestroyWindow,hWin
		.ENDIF
		
	.ELSEIF eax==WM_CLOSE
		invoke DestroyWindow,hWin
	.ELSE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret

AddProc ENDP

DelFriend PROC

	LOCAL @selectItem:DWORD
	LOCAL @targetName[128]:BYTE
	
	invoke SendMessage,listhWnd,LB_GETCURSEL,0,0
	.IF eax == LB_ERR
		ret
	.ENDIF
	mov @selectItem,eax
	invoke SendMessage,listhWnd,LB_GETTEXT,@selectItem,ADDR @targetName
	invoke SendRequest,C_DELFRIEND,OFFSET UserName,ADDR @targetName
	
	ret
DelFriend ENDP

SendRequest PROC,sign:DWORD,target:PTR BYTE,text:PTR BYTE

	LOCAL @msg:CLIENT_MSG
	
	push sign
	pop @msg.C_Sign
	
	invoke lstrcpy,ADDR @msg.C_Target,target
	invoke lstrcpy,ADDR @msg.C_Text,text
	
	invoke send,connfd,ADDR @msg,TYPE CLIENT_MSG,0
	mov eax,0
	ret

SendRequest ENDP

SendLoginRequest  PROC
	
	LOCAL @login_msg:CLIENT_MSG
	LOCAL @recv_msg:SERVER_MSG
	mov @login_msg.C_Sign, C_LOGIN
	
	invoke SendMessage,UserhWnd,WM_GETTEXT,128,ADDR @login_msg.C_Target
	invoke SendMessage,PasshWnd,WM_GETTEXT,128,ADDR @login_msg.C_Text
	
	invoke lstrlen,ADDR @login_msg.C_Target
	.IF eax == 0
		invoke MessageBox,LoginhWnd,OFFSET TP_UNAMEBLANK,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
		ret
	.ENDIF
	invoke lstrlen,ADDR @login_msg.C_Text
	.IF eax == 0
		invoke MessageBox,LoginhWnd,OFFSET TP_PASSWDBLANK,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
		ret
	.ENDIF
	
	invoke send,connfd,ADDR @login_msg,SIZEOF @login_msg,0
	
	invoke recv,connfd,ADDR @recv_msg,SIZEOF @recv_msg,0
	.IF @recv_msg.S_Sign == S_LOGINOK
		invoke lstrcpy,OFFSET UserName,ADDR @login_msg.C_Target
		invoke lstrcpy,OFFSET PassWord,ADDR @login_msg.C_Text
		mov eax,1
	.ELSEIF @recv_msg.S_Sign == S_LOGERRLOGED
		invoke MessageBox,LoginhWnd,OFFSET TP_ALREADYLOGIN,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
	.ELSEIF @recv_msg.S_Sign == S_LOGERRPASSWD
		invoke MessageBox,LoginhWnd,OFFSET TP_WRONGPASSWD,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
	.ELSEIF @recv_msg.S_Sign == S_LOGERRNOUSER
		invoke MessageBox,LoginhWnd,OFFSET TP_LOGINFAILED,OFFSET dlgName,MB_OK or MB_APPLMODAL
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
	
	invoke lstrlen,ADDR @reg_msg.C_Target
	.IF eax == 0
		invoke MessageBox,LoginhWnd,OFFSET TP_UNAMEBLANK,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
		ret
	.ENDIF
	invoke lstrlen,ADDR @reg_msg.C_Text
	.IF eax == 0
		invoke MessageBox,LoginhWnd,OFFSET TP_PASSWDBLANK,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,0
		ret
	.ENDIF
	
	invoke send,connfd,ADDR @reg_msg,SIZEOF @reg_msg,0
	invoke recv,connfd,ADDR @recv_msg,SIZEOF @recv_msg,0
	.IF @recv_msg.S_Sign == S_REGISTEROK
		invoke MessageBox,LoginhWnd,OFFSET TP_REGISTERSUCCESS,OFFSET dlgName,MB_OK or MB_APPLMODAL
		mov eax,1
	.ELSEIF @recv_msg.S_Sign == S_REGERRUSEREXISTS
		invoke MessageBox,LoginhWnd,OFFSET TP_REGISTERED,OFFSET dlgName,MB_OK or MB_APPLMODAL
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
			invoke MessageBox,MainhWnd,OFFSET TP_SERVERSTOP,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke SendMessage,MainhWnd,WM_CLOSE,NULL,NULL
			invoke SendMessage,MainhWnd,WM_DESTROY,NULL,NULL
		.ELSEIF @server_msg.S_Sign == S_ADDERRNOUSER
			invoke MessageBox,MainhWnd,OFFSET TP_ADDUSERNOTEXISTS,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke SendMessage,MainhWnd,WM_COMMAND,IDC_MADDFRIENDBTN,0
		.ELSEIF @server_msg.S_Sign == S_ADDOK
			invoke MessageBox,MainhWnd,OFFSET TP_ADDSUCCESS,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke UpdateFriendList
		.ELSEIF @server_msg.S_Sign == S_ADDFRIENDEXISTS
			invoke MessageBox,MainhWnd,OFFSET TP_FRIENDEXISTS,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke SendMessage,MainhWnd,WM_COMMAND,IDC_MADDFRIENDBTN,0
		.ELSEIF @server_msg.S_Sign == S_UAREADDED
			invoke MessageBox,MainhWnd,ADDR @server_msg.S_Text,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke UpdateFriendList
		.ELSEIF @server_msg.S_Sign == S_FORWARDMSG1
			invoke UpdateChatHistory,ADDR @server_msg.S_Text
			invoke GetChatHistoryRec
		.ELSEIF @server_msg.S_Sign == S_FORWARDMSG2
			invoke UpdateChatHistory,ADDR @server_msg.S_Text
		.ELSEIF @server_msg.S_Sign == S_DELOK
			invoke MessageBox,MainhWnd,OFFSET TP_DELSUCCESS,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke UpdateFriendList
		.ELSEIF @server_msg.S_Sign == S_UNFRIENDED
			invoke MessageBox,MainhWnd,ADDR @server_msg.S_Text,OFFSET mainName,MB_OK or MB_APPLMODAL
			invoke UpdateFriendList
		.ELSEIF @server_msg.S_Sign == S_FILECONFIRM
			invoke SendFile
		.ELSEIF @server_msg.S_Sign == S_SENDFILE
			invoke lstrcpy,OFFSET chFileName,OFFSET CurrentDir
			invoke lstrcat,OFFSET chFileName,OFFSET fileBreak
			invoke lstrcat,OFFSET chFileName,ADDR @server_msg.S_Text
			invoke ReceiveFile
		.ELSEIF @server_msg.S_Sign == S_USERNOTONLINE
			invoke MessageBox,MainhWnd,OFFSET TP_FILESENDFAIL,OFFSET mainName,MB_OK
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
	
	invoke SendMessage,listhWnd,LB_RESETCONTENT,0,0
	
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

GetChatHistory PROC
	
	LOCAL @selectItem:DWORD
	LOCAL @targetName[128]:BYTE
	
	invoke SendMessage,listhWnd,LB_GETCURSEL,0,0
	.IF eax == LB_ERR
		ret
	.ENDIF
	mov @selectItem,eax
	invoke SendMessage,listhWnd,LB_GETTEXT,@selectItem,ADDR @targetName
	invoke SendRequest,C_GETHISTORY,OFFSET UserName,ADDR @targetName
	
	ret

GetChatHistory ENDP

GetChatHistoryRec PROC
	
	LOCAL @selectItem:DWORD
	LOCAL @targetName[128]:BYTE
	
	invoke SendMessage,listhWnd,LB_GETCURSEL,0,0
	.IF eax == LB_ERR
		ret
	.ENDIF
	mov @selectItem,eax
	invoke SendMessage,listhWnd,LB_GETTEXT,@selectItem,ADDR @targetName
	invoke SendRequest,C_GETHISTORYREC,OFFSET UserName,ADDR @targetName
	
	ret

GetChatHistoryRec ENDP

UpdateChatHistory PROC, msg:PTR BYTE

    LOCAL @dataLen:DWORD

    ; 获取聊天窗口文本长度
    invoke GetWindowTextLength, chathWnd
    mov @dataLen, eax

    ; 发送EM_SETTEXTEX消息
    invoke SendMessage, chathWnd, EM_SETSEL, 0, @dataLen
    invoke SendMessage, chathWnd, EM_REPLACESEL, 0, msg ; 替换当前选择的文本

    ; 滚动到底部
    invoke SendMessage, chathWnd, EM_SCROLL, SB_BOTTOM, 0
    
    ret
UpdateChatHistory ENDP

ChooseFile  PROC, target:PTR BYTE

    LOCAL @ofn:OPENFILENAME
    ;LOCAL @chFileName[256]:BYTE
    
    invoke RtlZeroMemory,ADDR @ofn,SIZEOF @ofn
    
    mov @ofn.lStructSize, SIZEOF @ofn
    mov @ofn.hwndOwner,NULL
    mov @ofn.lpstrFile,OFFSET chFileName
    mov @ofn.nMaxFile, SIZEOF chFileName
    mov @ofn.lpstrFilter, OFFSET fileFilter
    mov @ofn.lpstrTitle, OFFSET fileTitle
    mov @ofn.Flags, OFN_PATHMUSTEXIST or OFN_FILEMUSTEXIST
    
    invoke GetOpenFileName, ADDR @ofn
    
    .IF eax == FALSE
        invoke MessageBox, MainhWnd, OFFSET TP_FILENOTEXIST, OFFSET mainName, MB_OK
    .ELSE
        invoke PathFindFileName,OFFSET chFileName
        mov esi,eax
        invoke wsprintf,OFFSET textBuffer,OFFSET fileFormat,OFFSET CurrentDir,esi
        invoke CopyFile,OFFSET chFileName,OFFSET textBuffer,FALSE
        invoke SendRequest,C_SENDFILE,target,esi
             
    .ENDIF
    
    ret
ChooseFile ENDP

SendFile	PROC
	
	LOCAL @handle:HANDLE
	LOCAL @bytesRead:DWORD
	LOCAL @bytesSent:DWORD
	LOCAL @dataSocket:DWORD
	
	invoke CreateFile,OFFSET chFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
	mov @handle,eax
	
	invoke ConnectSocketForClient,DEFAULT_DATAPORT, ADDR DEFAULT_IP
	mov @dataSocket,eax
	
	.WHILE TRUE
		invoke RtlZeroMemory,OFFSET textBuffer,8192
		invoke ReadFile,@handle,OFFSET textBuffer,8192,ADDR @bytesRead,NULL
		.IF @bytesRead == 0
			.BREAK
		.ENDIF
		invoke send,@dataSocket,OFFSET textBuffer,@bytesRead,0
	.ENDW
	
	invoke closesocket,@dataSocket
	invoke CloseHandle,@handle
	
	invoke Sleep,300
	invoke GetChatHistory
	
	
	ret

SendFile ENDP

ReceiveFile PROC
	
	LOCAL @handle:HANDLE
	LOCAL @bytesRecv:DWORD
	LOCAL @dataSocket:DWORD
	LOCAL @bytesWrit:DWORD
	
	invoke CreateFile,OFFSET chFileName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	mov @handle,eax
	
	invoke ConnectSocketForClient,DEFAULT_DATAPORT, ADDR DEFAULT_IP
	mov @dataSocket,eax
	
	.WHILE TRUE
	
		invoke RtlZeroMemory,OFFSET textBuffer,8192
		invoke recv,@dataSocket,OFFSET textBuffer,8192,0
		mov @bytesRecv,eax
		
		.IF @bytesRecv == 0 || @bytesRecv < 0
			.BREAK
		.ENDIF
		
		invoke WriteFile,@handle,OFFSET textBuffer,@bytesRecv,ADDR @bytesWrit,NULL
	
	.ENDW
	
	invoke CloseHandle,@handle
	invoke closesocket,@dataSocket
	
	ret

ReceiveFile ENDP

end Main
