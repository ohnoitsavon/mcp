for /R %%A IN (*.xmcpcheck) do (

	If %%~zA equ 0 del "%%A"

	If %%~zA gtr 0 (
		echo The following file has an error! >>ERRORS.log		
		echo %%~dpA%%~nA >>ERRORS.log
		echo. >>ERRORS.log
	) 

	ren "%%A" "%%~nA".log
	
)