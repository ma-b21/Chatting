include 		utils.inc

.code
CreateSocketForServer		PROC, port:DWORD
	
	LOCAL @addr:sockaddr_in
	LOCAL @listenfd:DWORD
	LOCAL implementInfo: WSADATA
	
	invoke WSAStartup, 101h, ADDR implementInfo
	invoke socket,AF_INET, SOCK_STREAM, 0
	.IF eax == -1
		invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
		ret
	.ENDIF
	mov @listenfd, eax
	
	invoke crt_memset, ADDR @addr, 0, SIZEOF @addr
	mov @addr.sin_family, AF_INET
	mov @addr.sin_addr, INADDR_ANY
	
	invoke htons,port
	mov @addr.sin_port,ax
	
	invoke bind,@listenfd,ADDR @addr,SIZEOF @addr
	.IF eax == -1
		invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
		ret
	.ENDIF
	mov eax, @listenfd
	
CreateSocketForServer	ENDP

ConnectSocketForClient   	PROC, port:DWORD, ip:PTR BYTE
	
	LOCAL @addr:sockaddr_in
	LOCAL @connfd:DWORD
	LOCAL implementInfo: WSADATA
	
	invoke WSAStartup, 101h, ADDR implementInfo
	invoke socket,AF_INET, SOCK_STREAM,IPPROTO_TCP
	.IF eax == -1
		invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
		ret
	.ENDIF
	mov @connfd, eax
	
	invoke crt_memset,ADDR @addr, 0, SIZEOF @addr
	mov @addr.sin_family,AF_INET
	invoke htons,port
	mov @addr.sin_port,ax
	invoke inet_addr,ip
	mov @addr.sin_addr,eax
	
	invoke connect,@connfd,ADDR @addr,SIZEOF @addr
	.IF eax < 0
		invoke MessageBox,NULL,OFFSET SOCKET_ERR,OFFSET ERR_TITLE,MB_OK
		ret
	.ENDIF
	
	mov eax,@connfd
	ret

ConnectSocketForClient ENDP
END