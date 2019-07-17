for /R %%A IN (*.xmcpcheck) do (

	If %%~zA equ 0 del "%%A"
	
)