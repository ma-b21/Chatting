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

	LOCAL @hicon:HICON
	
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

	.WHILE SERVER_STATE != 0
		invoke accept,serverListenfd,NULL,NULL
		mov @clientConnfd,eax
        
        .IF SERVER_STATE == 0
        	.BREAK
        .ENDIF
		.IF eax == -1
			invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
			.CONTINUE
		.ENDIF
        
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
		push ecx
		invoke RtlZeroMemory,ADDR [edi].UserName,128
		invoke SendServerResponse,[edi].Sockfd,S_SERVERSTOP,NULL
		invoke closesocket,[edi].Sockfd
		pop ecx
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

	.WHILE SERVER_STATE != 0
		invoke select, 0, ADDR @sockfdSet, NULL, NULL, ADDR @timeout
		
        .IF eax == 0
            .CONTINUE
        .ENDIF
        
        invoke HandleRecvClientMsg,connfd
	.ENDW
	
	invoke closesocket,connfd
	ret

CommunicateWithClient ENDP

HandleRecvClientMsg     PROC, connfd:DWORD

	LOCAL @fileHandle:DWORD
	LOCAL @dataLen:DWORD
	
	invoke RtlZeroMemory, OFFSET READSOCKETBUFFER, SIZEOF READSOCKETBUFFER
	invoke recv, connfd, OFFSET READSOCKETBUFFER, SIZEOF READSOCKETBUFFER, 0
	push eax
	invoke MessageBox,NULL,OFFSET debug,NULL,MB_OK
	pop eax
	
	mov esi, OFFSET READSOCKETBUFFER
	ASSUME esi: PTR CLIENT_MSG
	.IF eax != SOCKET_ERROR 
		.IF [esi].C_Sign == C_LOGIN
			invoke HandleLogin, connfd, esi
		.ELSEIF [esi].C_Sign == C_LOGOUT
			invoke HandleLogout, connfd
		.ELSEIF [esi].C_Sign == C_REGISTER
			invoke HandleRegister, connfd, esi
		.ELSEIF [esi].C_Sign == C_GETFRIEND
			invoke wsprintf, OFFSET HD_STRINGBUFFER, OFFSET FRIENDPATH,ADDR [esi].C_Target

    		; Open File Named FILE
    		invoke CreateFile, OFFSET HD_STRINGBUFFER, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    		.IF eax == INVALID_HANDLE_VALUE
        		invoke SendServerResponse,connfd,0,NULL
        		ret
    		.ENDIF
    		; Save the file handle
    		mov @fileHandle, eax 

    		; Read file contents
    		invoke ReadFile, @fileHandle, OFFSET READFILEBUFFER, 8192, ADDR @dataLen, NULL
    		.IF eax == FALSE
    			invoke CloseHandle, @fileHandle
        		invoke SendServerResponse,connfd,0,NULL
        		ret  ; Failed to handle file
    		.ENDIF
    		; Close file handler
    		invoke CloseHandle, @fileHandle
    
    		; Add '\0' to the end
    		mov eax, OFFSET READFILEBUFFER  ; 将 @fileContent 的地址放入 eax
    		add eax, @dataLen
    		mov BYTE PTR [eax], 0
    		invoke SendServerResponse,connfd,0,OFFSET READFILEBUFFER
<<<<<<< Updated upstream
=======
    	.ELSEIF [esi].C_Sign == C_ADDFRIEND
    		invoke HandleAddFriend, connfd, esi
    	.ELSEIF [esi].C_Sign == C_SENDMSG
    		invoke HandleSendMsg,connfd,esi
    	.ELSEIF [esi].C_Sign == C_GETHISTORY
    		invoke HandleHistory,connfd,esi
    	.ELSEIF [esi].C_Sign == C_DELFRIEND
    		invoke HandleDelFriend,connfd,esi
>>>>>>> Stashed changes
		.ENDIF
	.ENDIF

@Ret:	
	assume esi:nothing
	ret
		
HandleRecvClientMsg           ENDP

HandleLogout PROC,connfd:DWORD
	
    
    mov edi,OFFSET CLIENTLIST
	ASSUME edi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
		.IF [edi].IsUsed != 0
			mov eax,[edi].Sockfd
			.IF connfd == eax
				mov [edi].IsUsed,0
				push eax
				push ecx
				push edi
				invoke RtlZeroMemory,ADDR [edi].UserName,128
				invoke closesocket,connfd
				invoke UpdateClientList
				pop edi
				pop ecx
				pop eax
				.BREAK
			.ENDIF
		.ENDIF
		add edi,TYPE CLIENT
		inc ecx
	.ENDW
	
	
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
		
		invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET FRIENDPATH,ADDR [esi].C_Target
		invoke CreateFile,OFFSET HD_STRINGBUFFER,GENERIC_READ or GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL
		invoke CloseHandle,eax
		
		invoke SendServerResponse,connfd,S_REGISTEROK,NULL
	.ELSE
		invoke SendServerResponse,connfd,S_REGERRUSEREXISTS,NULL
	.ENDIF
	
	ret

HandleRegister ENDP

<<<<<<< Updated upstream
=======
HandleAddFriend PROC,connfd:DWORD,msg:PTR CLIENT_MSG
	
	LOCAL @findData:WIN32_FIND_DATA
	LOCAL @hFind:HANDLE
	LOCAL @isUserExists:DWORD
	LOCAL @dataLen:DWORD
	
	mov @isUserExists,0
	
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG

	invoke FindFirstFile,OFFSET SEARCHFRIEND,ADDR @findData
	mov @hFind,eax
	
	
	mov eax,0
	.REPEAT
		mov ebx,@findData.dwFileAttributes
		and ebx,FILE_ATTRIBUTE_DIRECTORY
		
		.IF ebx == 0
			invoke lstrcmp,ADDR @findData.cFileName,ADDR [esi].C_Text
			.IF eax == 0
				mov @isUserExists,1
				.BREAK
			.ENDIF
		.ENDIF
		
		invoke FindNextFile,@hFind,ADDR @findData
	.UNTIL eax == 0

	invoke FindClose,@hFind
	
	
	.IF @isUserExists == 0
		invoke SendServerResponse,connfd,S_ADDERRNOUSER,NULL
	.ELSE
		invoke wsprintf,OFFSET BUFFER,OFFSET FRIENDPATH,ADDR [esi].C_Target
		invoke CreateFile,OFFSET BUFFER,GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
		mov @hFind,eax
		invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET NEWFRIEND,ADDR [esi].C_Text

    	; Read file contents
    	invoke ReadFile, @hFind, OFFSET READFILEBUFFER, 8192, ADDR @dataLen, NULL
    
    	; Add '\0' to the end
    	mov eax, OFFSET READFILEBUFFER  
    	add eax, @dataLen
    	mov BYTE PTR [eax], 0
    	
    	invoke FindString,OFFSET READFILEBUFFER, OFFSET HD_STRINGBUFFER
    	
    	
    	.IF eax != 0
    		invoke SendServerResponse,connfd,S_ADDFRIENDEXISTS,NULL
			invoke CloseHandle,@hFind
    	.ELSE
    		
			invoke SetFilePointer,@hFind,0,NULL,FILE_END
			invoke lstrlen,OFFSET HD_STRINGBUFFER
			mov @dataLen,eax
			invoke WriteFile,@hFind,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
			invoke CloseHandle,@hFind
			
			;对方好友
			invoke wsprintf,OFFSET BUFFER,OFFSET FRIENDPATH,ADDR [esi].C_Text
			invoke CreateFile,OFFSET BUFFER,GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
			mov @hFind,eax
			invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET NEWFRIEND,ADDR [esi].C_Target
			invoke SetFilePointer,@hFind,0,NULL,FILE_END
			invoke lstrlen,OFFSET HD_STRINGBUFFER
			mov @dataLen,eax
			invoke WriteFile,@hFind,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
			invoke CloseHandle,@hFind
			
    		invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Target,ADDR [esi].C_Text
			invoke CreateFile,OFFSET HD_STRINGBUFFER,GENERIC_READ or GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL
			invoke CloseHandle,eax
			
			invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Text,ADDR [esi].C_Target
			invoke CreateFile,OFFSET HD_STRINGBUFFER,GENERIC_READ or GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL
			invoke CloseHandle,eax
			
			;通知对方被加为好友
			@LOCK_SHARE_VAR
        	
    		mov edi,OFFSET CLIENTLIST
			ASSUME edi:PTR CLIENT
			mov ecx,0
			.WHILE ecx < MAX_CONNECT
				push ecx
				
				invoke lstrcmp,ADDR[esi].C_Text,ADDR [edi].UserName
				.IF eax == 0
					invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET ADDEDASFRIEND,ADDR [esi].C_Target
					invoke SendServerResponse,[edi].Sockfd,S_UAREADDED,OFFSET HD_STRINGBUFFER
					.BREAK
				.ENDIF
				
				pop ecx
				add edi,TYPE CLIENT
				inc ecx
			.ENDW
			
			@UNLOCK_SHARE_VAR
			
			invoke SendServerResponse,connfd,S_ADDOK,NULL
    	.ENDIF
	
	.ENDIF
	ASSUME esi:nothing
	ret

HandleAddFriend ENDP

HandleDelFriend PROC,connfd:DWORD,msg:PTR CLIENT_MSG
	
	LOCAL @hFind:HANDLE
	LOCAL @dataLen:DWORD
	LOCAL @nameLen:DWORD
	LOCAL @namePos:DWORD
	
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG
	
	invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Target,ADDR [esi].C_Text
	invoke DeleteFile,OFFSET HD_STRINGBUFFER
	invoke CloseHandle,eax
	
	invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Text,ADDR [esi].C_Target
	invoke DeleteFile,OFFSET HD_STRINGBUFFER
	invoke CloseHandle,eax
	
	invoke wsprintf,OFFSET BUFFER,OFFSET FRIENDPATH,ADDR [esi].C_Target
	invoke CreateFile,OFFSET BUFFER,GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	mov @hFind,eax
	;HD_stringbuffer = newfriend name
	invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET NEWFRIEND,ADDR [esi].C_Text
	invoke lstrlen,OFFSET HD_STRINGBUFFER
	mov @nameLen,eax
	; Read file contents
	invoke ReadFile, @hFind, OFFSET READFILEBUFFER, 8192, ADDR @dataLen, NULL
	
	mov eax, OFFSET READFILEBUFFER  
	add eax, @dataLen
	mov BYTE PTR [eax], 0
	
	invoke FindPosition,OFFSET READFILEBUFFER, OFFSET HD_STRINGBUFFER
	mov @namePos,eax
	invoke FindString,OFFSET READFILEBUFFER, OFFSET HD_STRINGBUFFER
	invoke lstrcpy, OFFSET HD_STRINGBUFFER, ADDR [eax]
	invoke lstrlen,OFFSET HD_STRINGBUFFER
	dec eax
	mov @dataLen,eax
	
	invoke SetFilePointer,@hFind,@namePos,NULL,FILE_BEGIN
	invoke WriteFile,@hFind,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
	invoke CloseHandle,@hFind
	
	@LOCK_SHARE_VAR
    	
	mov edi,OFFSET CLIENTLIST
	ASSUME edi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
		push ecx
		
		invoke lstrcmp,ADDR[esi].C_Text,ADDR [edi].UserName
		.IF eax == 0
			invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET UNFRIENDED,ADDR [esi].C_Target
			invoke SendServerResponse,[edi].Sockfd,S_UNFRIENDED,OFFSET HD_STRINGBUFFER
			.BREAK
		.ENDIF
		
		pop ecx
		add edi,TYPE CLIENT
		inc ecx
	.ENDW
	
	@UNLOCK_SHARE_VAR
	invoke SendServerResponse,connfd,S_DELOK,NULL
	
	ASSUME esi:nothing
	ret

HandleDelFriend endp
HandleSendMsg PROC,connfd:DWORD,msg:PTR CLIENT_MSG
	
	LOCAL @source[128]:BYTE
	LOCAL @fileHandle:DWORD
	LOCAL @dataLen:DWORD
	LOCAL @targetSocket:DWORD
	LOCAL @new_msg:CLIENT_MSG
	
	mov @targetSocket,-1
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG
	
	@LOCK_SHARE_VAR
        	
    mov edi,OFFSET CLIENTLIST
	ASSUME edi:PTR CLIENT
	mov ecx,0
	.WHILE ecx < MAX_CONNECT
		push ecx
		mov eax,connfd
				
		.IF eax == [edi].Sockfd
			invoke lstrcpy,ADDR @source,ADDR [edi].UserName
		.ENDIF
		
		invoke lstrcmp,ADDR [esi].C_Target,ADDR [edi].UserName
		.IF eax == 0
			push [edi].Sockfd
			pop @targetSocket 
		.ENDIF
				
		pop ecx
		add edi,TYPE CLIENT
		inc ecx
	.ENDW
			
	@UNLOCK_SHARE_VAR
	
	;source chat History
	invoke wsprintf,OFFSET BUFFER,OFFSET CHATHISTORY,ADDR @source,ADDR [esi].C_Target
	
	invoke CreateFile,OFFSET BUFFER,GENERIC_WRITE,FILE_SHARE_WRITE,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	mov @fileHandle,eax
	invoke SetFilePointer,@fileHandle,0,NULL,FILE_END
	
	invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET SENTENCE,ADDR @source,ADDR [esi].C_Text
	invoke lstrlen,OFFSET HD_STRINGBUFFER
	mov @dataLen,eax
		
	invoke WriteFile,@fileHandle,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
		
	invoke CloseHandle,@fileHandle
	
	;target chat history
	invoke wsprintf,OFFSET BUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Target,ADDR @source
	
	invoke CreateFile,OFFSET BUFFER,GENERIC_WRITE,FILE_SHARE_WRITE,NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	mov @fileHandle,eax
	invoke SetFilePointer,@fileHandle,0,NULL,FILE_END
		
	invoke wsprintf,OFFSET HD_STRINGBUFFER,OFFSET SENTENCE,ADDR @source,ADDR [esi].C_Text
	invoke lstrlen,OFFSET HD_STRINGBUFFER
	mov @dataLen,eax
		
	invoke WriteFile,@fileHandle,OFFSET HD_STRINGBUFFER,@dataLen,NULL,NULL
		
	invoke CloseHandle,@fileHandle
	
	;forward message
	
	.IF @targetSocket != -1
		mov @new_msg.C_Sign,C_GETHISTORY
		invoke lstrcpy,ADDR @new_msg.C_Target,ADDR @source
		invoke lstrcpy,ADDR @new_msg.C_Text,ADDR [esi].C_Target
		
		invoke HandleHistory,@targetSocket,ADDR @new_msg
	.ENDIF
	
	ASSUME esi:nothing
	ret

HandleSendMsg ENDP

HandleHistory PROC,connfd:DWORD,msg:PTR CLIENT_MSG

	LOCAL @fileHandle:DWORD
	LOCAL @dataLen:DWORD
	
	mov  esi,msg
	ASSUME esi: PTR CLIENT_MSG
	;Get history filename
	invoke wsprintf,OFFSET BUFFER,OFFSET CHATHISTORY,ADDR [esi].C_Target,ADDR [esi].C_Text
	
	invoke CreateFile, OFFSET BUFFER, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    ; Save the file handle
    mov @fileHandle, eax 

    ; Read file contents
    invoke ReadFile, @fileHandle, OFFSET READFILEBUFFER, 8192, ADDR @dataLen, NULL
    ; Close file handler
    invoke CloseHandle, @fileHandle
    
    ; Add '\0' to the end
    mov eax, OFFSET READFILEBUFFER  ; 将 @fileContent 的地址放入 eax
    add eax, @dataLen
    mov BYTE PTR [eax], 0
    
    invoke SendServerResponse,connfd,S_FORWARDMSG,OFFSET READFILEBUFFER
	
	ASSUME esi:nothing
	ret

HandleHistory ENDP

>>>>>>> Stashed changes
SendServerResponse PROC,connfd:DWORD,sign:DWORD,text:PTR BYTE

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

FindPosition PROC uses esi edi ecx edx,sourceString:DWORD, searchString:DWORD
    
    mov esi, sourceString  
    mov edi, searchString
    mov ecx, 0
    mov edx, 0  
    @@Loop:
        mov al, [esi]
        mov bl, [edi]
        .IF bl == 0
            .IF ecx == 0
                mov eax, 0
            .ELSE
                mov eax, edx
         		ret
            .ENDIF
            ret
        .ELSEIF al == 0
        	mov eax, 0
        	ret
        .ELSEIF al != bl
        	add edx, 1
            mov ecx, 0
            mov edi, searchString
            inc esi
        .ELSE
            inc esi 
            inc edi
            inc ecx
        .ENDIF
        jmp @@Loop
        
FindPosition ENDP

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
    
    ; Add '\0' to the end
    mov eax, OFFSET READFILEBUFFER  ; 将 @fileContent 的地址放入 eax
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
