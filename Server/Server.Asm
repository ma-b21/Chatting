.386
.model flat, stdcall
option casemap :none

include Server.inc

.code

start:

	invoke GetModuleHandle,NULL
	mov		hInstance,eax
	
	invoke CreateMutex, NULL, FALSE, NULL
    mov hMutex, eax
    
    invoke InitCommonControls
	invoke DialogBoxParam,hInstance,IDD_DIALOG1,NULL,addr DlgProc,NULL
	
	invoke ExitProcess,0

;########################################################################

DlgProc PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.IF eax == WM_INITDIALOG
		;init the handles
		push hWin
		pop dhWnd
		invoke GetDlgItem,dhWnd,IDC_LIST
		mov listhWnd, eax
		invoke GetDlgItem,dhWnd,IDC_BUTTON
		mov btnhWnd, eax
		
		; Load Skin
		invoke LoadLibrary, offset SkinDllName
		invoke GetProcAddress, eax, offset SkinFuncName
		push NULL
		push offset SkinName
		call eax
		
		;Disallow window size changes
		invoke GetWindowLong,dhWnd,GWL_STYLE
		xor eax, WS_MAXIMIZEBOX
		xor eax, WS_SIZEBOX
		invoke SetWindowLong,dhWnd, GWL_STYLE, eax
		
		mov SERVER_STATE, 0
		invoke SetWindowText,btnhWnd,OFFSET BTN_DOWNTEXT
		
	.ELSEIF eax == WM_COMMAND
		mov eax, wParam
		.IF eax == IDC_BUTTON
			.IF SERVER_STATE == 0
				inc SERVER_STATE
				invoke SetWindowText,btnhWnd,OFFSET BTN_UPTEXT
				invoke CreateThread,NULL,0,OFFSET StartServer,DEFAULT_PORT,0,NULL
				;TODO
			.ELSE
				mov SERVER_STATE, 0
				invoke SetWindowText,btnhWnd,OFFSET BTN_DOWNTEXT
				invoke StopServer
			.ENDIF
		.ENDIF
	.ELSEIF eax == WM_CLOSE
		invoke EndDialog,hWin,0
	.ELSE
		mov		eax,FALSE
		ret
	.ENDIF
	mov		eax,TRUE
	ret

DlgProc ENDP

StartServer PROC, port:DWORD

	LOCAL @clientConnfd:DWORD
	
	invoke CreateSocketForServer,port
	mov serverListenfd, eax
	
	invoke listen,serverListenfd,MAX_CONNECT
	.IF eax == -1
		invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
		ret
	.ENDIF
	
	.WHILE TRUE
		invoke accept,serverListenfd,NULL,NULL
		.IF SERVER_STATE == 0
			.BREAK
		.ENDIF
		.IF eax == -1
			invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
			.CONTINUE
		.ENDIF
		
		mov @clientConnfd,eax
		invoke CreateThread,NULL,0,OFFSET CommunicateWithClient,@clientConnfd,0,NULL
	.ENDW
	
	invoke closesocket,serverListenfd
	ret	
StartServer ENDP

StopServer PROC
	
	invoke closesocket,serverListenfd
	@LOCK_SHARE_VAR
        	
    mov edi,OFFSET CLIENTLIST
	ASSUME edi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
	
		mov [edi].IsUsed,0
		invoke RtlZeroMemory,ADDR [edi].UserName,128
		invoke closesocket,[edi].Sockfd
		
		add edi,TYPE CLIENT
		inc ecx
	.ENDW
	
	@UNLOCK_SHARE_VAR
	invoke UpdateClientList
	ret

StopServer ENDP

CommunicateWithClient   PROC, connfd:DWORD
	LOCAL @sockfdSet:fd_set
	LOCAL @timeout: timeval
	LOCAL @msg:CLIENT_MSG
	LOCAL @bytesAvailable:DWORD
	
	invoke crt_memcpy,ADDR @sockfdSet.fd_array,ADDR connfd,TYPE DWORD
	mov    @sockfdSet.fd_count, 1
    mov    @timeout.tv_sec, 0
    mov    @timeout.tv_usec, 200*1000

	.WHILE TRUE
    	invoke ioctlsocket, connfd, FIONREAD, ADDR @bytesAvailable
    	.IF eax == SOCKET_ERROR
    		
        	@LOCK_SHARE_VAR
        	
        	mov edi,OFFSET CLIENTLIST
			ASSUME edi:PTR CLIENT
			mov ecx,0
			.WHILE ecx < MAX_CONNECT
				.IF [edi].IsUsed != 0
					mov eax,[edi].Sockfd
					.IF connfd == eax
						mov [edi].IsUsed,0
						invoke RtlZeroMemory,ADDR [edi].UserName,128
						invoke closesocket,connfd
						invoke UpdateClientList
						.BREAK
					.ENDIF
				.ENDIF
				add edi,TYPE CLIENT
				inc ecx
			.ENDW
			
			@UNLOCK_SHARE_VAR
        	.BREAK
    	.ENDIF
    	
		invoke select, 0, ADDR @sockfdSet, NULL, NULL, ADDR @timeout
        .IF eax == 0
            .CONTINUE
        .ENDIF
        
        invoke HandleRecvClientMsg,connfd
	.ENDW
	
	invoke closesocket,connfd
	ret

CommunicateWithClient ENDP

HandleRecvClientMsg           PROC, connfd:DWORD

	invoke RtlZeroMemory, OFFSET READSOCKETBUFFER, SIZEOF READSOCKETBUFFER
	invoke recv, connfd, OFFSET READSOCKETBUFFER, SIZEOF READSOCKETBUFFER, 0
	mov esi, OFFSET READSOCKETBUFFER
	ASSUME esi: PTR CLIENT_MSG
	.IF eax != SOCKET_ERROR 
		.IF [esi].C_Sign == C_LOGIN
			invoke HandleLogin, connfd, esi
		.ELSEIF [esi].C_Sign == C_LOGOUT
			invoke HandleLogout, connfd
		.ELSEIF [esi].C_Sign == C_REGISTER
			invoke HandleRegister, connfd, esi
		.ENDIF
	.ENDIF

@Ret:	
	assume esi:nothing
	ret
		
HandleRecvClientMsg           ENDP

HandleLogout PROC,connfd:DWORD
	
	@LOCK_SHARE_VAR
        	
    mov edi,OFFSET CLIENTLIST
	ASSUME edi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
		.IF [edi].IsUsed != 0
			mov eax,[edi].Sockfd
			.IF connfd == eax
				mov [edi].IsUsed,0
				invoke RtlZeroMemory,ADDR [edi].UserName,128
				invoke closesocket,connfd
				invoke UpdateClientList
				.BREAK
			.ENDIF
		.ENDIF
		add edi,TYPE CLIENT
		inc ecx
	.ENDW
	
	@UNLOCK_SHARE_VAR
	
	ret

HandleLogout ENDP

HandleLogin PROC,connfd:DWORD,msg:PTR CLIENT_MSG
	
	LOCAL @loged:DWORD
	
	mov @loged,0
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG
	invoke FindPassword,ADDR [esi].C_Target,ADDR [esi].C_Text
	.IF eax == 1
		@LOCK_SHARE_VAR
		
		mov edi,OFFSET CLIENTLIST
		ASSUME edi:PTR CLIENT
		mov ecx,0
		.WHILE ecx < MAX_CONNECT
			.IF [edi].IsUsed != 0
				push ecx
				invoke crt_strcmp,ADDR [esi].C_Target,ADDR [edi].UserName
				pop ecx
				.IF eax == 0
					mov @loged,1
					.BREAK
				.ENDIF
			.ENDIF
			add edi,TYPE CLIENT
			inc ecx
		.ENDW
		
		.IF @loged == 0
			invoke SendServerResponse,connfd,S_LOGINOK,NULL
		.ELSE
			invoke SendServerResponse,connfd,S_LOGERRLOGED,NULL
			@UNLOCK_SHARE_VAR
			ret
		.ENDIF
		mov edi,OFFSET CLIENTLIST
		ASSUME edi:PTR CLIENT
		mov ecx,0
		.WHILE ecx < MAX_CONNECT
			.IF [edi].IsUsed == 0
				.BREAK
			.ELSE
				add edi,TYPE CLIENT
				inc ecx
			.ENDIF
		.ENDW
		
		mov [edi].IsUsed, 1
		push connfd
		pop [edi].Sockfd
		invoke lstrcpy,ADDR [edi].UserName,ADDR [esi].C_Target
		@UNLOCK_SHARE_VAR
		invoke UpdateClientList
		
	.ELSEIF eax == 0
		invoke SendServerResponse,connfd,S_LOGERRPASSWD,NULL
	.ELSEIF eax == -1
		invoke SendServerResponse,connfd,S_LOGERRNOUSER,NULL
	.ENDIF

	ASSUME esi:nothing
	ret

HandleLogin ENDP

HandleRegister PROC,connfd:DWORD,msg:PTR CLIENT_MSG
	
	LOCAL @fileHandle:DWORD
	LOCAL @dataLen:DWORD
	
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG
	
	invoke FindPassword,ADDR [esi].C_Target,ADDR [esi].C_Text
	.IF eax == -1
		
		invoke CreateFile,OFFSET FILE,GENERIC_WRITE,FILE_SHARE_WRITE,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
		mov @fileHandle,eax
		invoke SetFilePointer,@fileHandle,0,NULL,FILE_END
		
		invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET REGFORM,ADDR [esi].C_Target,ADDR [esi].C_Text
		invoke lstrlen,OFFSET HD_STRINGBUFFER
		mov @dataLen,eax
		
		invoke WriteFile,@fileHandle,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
		
		invoke CloseHandle,@fileHandle
		
		invoke SendServerResponse,connfd,S_REGISTEROK,NULL
	.ELSE
		invoke SendServerResponse,connfd,S_REGERRUSEREXISTS,NULL
	.ENDIF
	
	ret

HandleRegister ENDP

SendServerResponse      PROC,connfd:DWORD,sign:DWORD,text:PTR BYTE

	LOCAL @msg:SERVER_MSG
	
	mov eax, sign
	mov @msg.S_Sign, eax
	
	invoke lstrcpy,ADDR @msg.S_Text,text
	
	invoke send,connfd,ADDR @msg,SIZEOF @msg,0
	
	ret

SendServerResponse      ENDP

FindString PROC uses esi edi ecx,sourceString:DWORD, searchString:DWORD
    
    mov esi, sourceString  
    mov edi, searchString
    mov ecx, 0  
    @@Loop:
        mov al, [esi]
        mov bl, [edi]
        .IF bl == 0
            .IF ecx == 0
                mov eax, 0
            .ELSE
                mov eax, esi
         		ret
            .ENDIF
            ret
        .ELSEIF al == 0
        	mov eax, 0
        	ret
        .ELSEIF al != bl
            mov ecx, 0
            mov edi, searchString
            inc esi
        .ELSE
            inc esi 
            inc edi
            inc ecx
        .ENDIF
        jmp @@Loop
        
FindString ENDP

FindPassword PROC, uname:PTR BYTE, password:PTR BYTE
    
    LOCAL @fileHandle:DWORD
    LOCAL @dataLen:DWORD
    LOCAL @passwd[128]:BYTE
    
    
    invoke crt_sprintf, OFFSET HD_STRINGBUFFER,OFFSET USERFORM,uname 

    ; Open File Named FILE
    invoke CreateFile, OFFSET FILE, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        ; If file does not exist, create the file and return 0
        invoke CreateFile, OFFSET FILE, GENERIC_WRITE, FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
        mov @fileHandle, eax 
        invoke CloseHandle, @fileHandle
        mov eax, 0
        ret
    .ENDIF
    ; Save the file handle
    mov @fileHandle, eax 

    ; Read file contents
    invoke ReadFile, @fileHandle, OFFSET READFILEBUFFER, 8192, ADDR @dataLen, NULL
    .IF eax == FALSE
    	invoke CloseHandle, @fileHandle
        mov eax, 0
        ret  ; Failed to handle file
    .ENDIF
    ; Close file handler
    invoke CloseHandle, @fileHandle
    
    ;return 0 when the info file is empty
    .IF @dataLen == 0
        mov eax, 0
        ret
    .ENDIF

    ; Add '\0' to the end
    mov eax, OFFSET READFILEBUFFER  ; �� @fileContent �ĵ�ַ���� eax
    add eax, @dataLen
    mov BYTE PTR [eax], 0
    invoke FindString,OFFSET READFILEBUFFER, OFFSET HD_STRINGBUFFER
    
    .IF eax == 0
    	mov eax, -1
    	ret
    .ENDIF
    
    lea ebx,@passwd
    .WHILE BYTE PTR [eax] != 0dh
    	mov cl, [eax]
    	mov [ebx], cl
    	inc ebx
    	inc eax
    .ENDW
    mov BYTE PTR [ebx], 0
    
    
    invoke lstrcmp,ADDR @passwd,password
    .IF eax != 0
    	mov eax, 0
    .ELSE
    	mov eax, 1	
    .ENDIF
	
    ret
FindPassword ENDP

UpdateClientList PROC
	
	LOCAL @clientnum:DWORD
	mov @clientnum, 0
	@LOCK_SHARE_VAR
	invoke SendMessage,listhWnd,LB_RESETCONTENT,0,0
	mov esi,OFFSET CLIENTLIST
	ASSUME esi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
		.IF [esi].IsUsed != 0
			inc @clientnum
			push ecx
			invoke SendMessage,listhWnd,LB_ADDSTRING,0,ADDR [esi].UserName
			pop ecx
		.ENDIF
		inc ecx
		add esi,TYPE CLIENT
	.ENDW
	
	ASSUME esi:nothing
	@UNLOCK_SHARE_VAR
	ret

UpdateClientList ENDP

end start