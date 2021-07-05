build-win:
	if not exist "dist" mkdir "dist"
	del ".\dist\*" /Q
	REM cmd "/C for /R .\src %F in (*) do copy /Y "%F" ".\dist\""
	cmd "/C for /R .\src %F in (*) do xcopy "%F" ".\dist" /Y /EXCLUDE:no_dist.txt

build-linux:
	rm -r ./dist/*
	find ./src/ -not -name '*.bin' -type f -exec cp {} ./dist \;
